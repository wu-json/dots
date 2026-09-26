-- nvim --headless -u NONE -l tests/link_preview.lua
-- Requires installed html, markdown, and markdown_inline Tree-sitter parsers.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim/.config/nvim")
local preview = require("config.link-preview")
local metadata = require("config.link-preview.metadata")
local data = metadata.parse(
  [[
  <title>Fallback &amp; title</title>
  <META CONTENT="A &amp; B" PROPERTY="og:title">
  <meta name='twitter:image' content='https://example.org/fallback.jpg'>
  <meta content='../cover.jpg?a=1&amp;b=2' property='og:image'>
]],
  "https://note.com/writer/n/article"
)
assert(data.title == "A & B")
assert(data.image == "https://note.com/writer/cover.jpg?a=1&b=2")
data = metadata.parse(
  [[
  <!-- <meta property="og:image" content="bad.jpg"> -->
  <script>const fake = '<meta property="og:image" content="bad.jpg">';</script>
  <base href="https://cdn.example.org/assets/">
  <meta property="og:image" content="file:///etc/passwd">
  <meta name="twitter:image" content="cover.jpg">
]],
  "https://example.org"
)
assert(data.image == "https://cdn.example.org/assets/cover.jpg")
assert(metadata.parse("<title>A &amp; B</title>", "https://example.org").title == "A & B")
assert(metadata.decode("&#65;&#x42;&quot;") == 'AB"')
assert(
  metadata.absolute("https://example.org/a/page", "//cdn.example.org/image.jpg") == "https://cdn.example.org/image.jpg"
)
for _, url in ipairs({
  "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30",
  "https://youtu.be/dQw4w9WgXcQ?si=abc",
  "https://m.youtube.com/shorts/dQw4w9WgXcQ",
  "https://youtube.com/live/dQw4w9WgXcQ",
  "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
}) do
  assert(metadata.youtube(url) == "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg", url)
end
assert(metadata.youtube("https://youtube.com.evil.org/watch?v=dQw4w9WgXcQ") == nil)
assert(metadata.youtube("https://youtube.com/watch?v=bad") == nil)
local function buffer(lines, row, col)
  vim.cmd.enew()
  vim.bo.filetype = "markdown"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.treesitter.get_parser(0, "markdown"):parse()
  vim.api.nvim_win_set_cursor(0, { row or 1, col or 3 })
end
for _, case in ipairs({
  { "[note](https://note.com/example)", 2, "https://note.com/example" },
  { "![image](https://example.org/image.png)", 18, false },
  { "`https://example.org/code`", 8, false },
  { "<https://example.org/auto>", 8, "https://example.org/auto" },
  { "See https://example.org/a_(b).", 12, "https://example.org/a_(b)" },
  {
    '<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>',
    25,
    "https://www.youtube.com/embed/dQw4w9WgXcQ",
  },
  { "[local](../notes.md)", 3, false },
}) do
  buffer({ case[1] }, 1, case[2])
  assert(preview.url_at_cursor() == (case[3] or nil), case[1] .. ": " .. tostring(preview.url_at_cursor()))
end
buffer({ "```", "https://example.org/code", "```" }, 2, 8)
assert(preview.url_at_cursor() == nil, "fenced code must not preview")

-- Stub network/rendering to exercise race handling without a graphics terminal.
local requests, shown, closed = {}, 0, 0
vim.system = function(_, _, callback)
  requests[#requests + 1] = callback
end
package.loaded.snacks = {
  win = function()
    shown = shown + 1
    return {
      close = function()
        closed = closed + 1
      end,
    }
  end,
}
preview.setup({ delay = 10 })
buffer({ "https://example.org/first", "https://example.org/second" }, 1, 8)
preview.schedule()
assert(vim.wait(300, function()
  return #requests == 1
end))
vim.api.nvim_win_set_cursor(0, { 2, 8 })
preview.schedule()
requests[1]({ code = 0, stdout = "<title>first</title>\nhttps://example.org/first" })
vim.wait(50)
assert(shown == 0, "stale response opened a popup")
assert(#requests == 2)
requests[2]({ code = 0, stdout = "<title>second</title>\nhttps://example.org/second" })
assert(vim.wait(300, function()
  return shown == 1
end))
preview.close()
assert(closed == 1, "popup was not closed")
preview.schedule()
assert(vim.wait(300, function()
  return shown == 2
end))
assert(#requests == 2, "cache hit fetched again")
preview.close()
-- Verify the image popup sizes once, cleans up its placement, and ignores late updates.
local update, image_closed, image_shown = nil, 0, 0
local image_win = {
  buf = 123,
  opts = {},
  open_buf = function() end,
  show = function()
    image_shown = image_shown + 1
  end,
  close = function() end,
}
package.loaded.snacks = {
  win = setmetatable({
    resolve = function()
      return {}
    end,
  }, {
    __call = function()
      return image_win
    end,
  }),
  image = {
    config = { doc = {} },
    terminal = {
      env = function()
        return {}
      end,
    },
    placement = {
      new = function(_, src, opts)
        assert(src == "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        update = opts.on_update_pre
        return {
          state = function()
            return { loc = { width = 40, height = 15 } }
          end,
          close = function()
            image_closed = image_closed + 1
          end,
        }
      end,
    },
  },
}
buffer({ "https://youtu.be/dQw4w9WgXcQ" }, 1, 8)
preview.schedule()
assert(vim.wait(300, function()
  return update ~= nil
end))
update()
update()
assert(image_shown == 1 and image_win.opts.width == 40 and image_win.opts.height == 15)
preview.close()
update()
assert(image_closed == 1 and image_shown == 1)
print("Link preview detection, lifecycle, and cache tests passed")
vim.cmd("qa!")
