-- nvim --headless -u NONE -l tests/link_preview.lua
-- Requires installed html, markdown, and markdown_inline Tree-sitter parsers.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim/.config/nvim")
local preview = require("config.link-preview")
local metadata = require("config.link-preview.metadata")
local disk_cache = require("config.link-preview.cache")
local cache_dir = vim.fn.tempname()
local cache_url = "https://example.org/cache-test"
disk_cache.put(cache_dir, cache_url, { data = { title = "Cached" }, expires = os.time() + 60 }, 128)
assert(disk_cache.get(cache_dir, cache_url).data.title == "Cached")
disk_cache.put(cache_dir, cache_url, { data = { title = "Expired" }, expires = os.time() - 1 }, 128)
assert(disk_cache.get(cache_dir, cache_url) == nil, "expired entry was reused")
vim.fn.writefile({ "broken json" }, cache_dir .. "/" .. vim.fn.sha256(cache_url) .. ".json")
assert(disk_cache.get(cache_dir, cache_url) == nil, "corrupt entry was reused")
for i = 1, 5 do
  disk_cache.put(cache_dir, cache_url .. i, { data = { title = tostring(i) }, expires = os.time() + 60 }, 2)
end
assert(#vim.fn.glob(cache_dir .. "/*.json", false, true) == 2, "disk cache exceeded entry limit")
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
data = metadata.parse(
  '<html><head><title>Head only</title></head><body><meta property="og:image" content="body.jpg"></body></html>',
  "https://example.org"
)
assert(data.title == "Head only" and data.image == nil, "metadata parsing must stop at the end of the head")
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
local image_resolver
for _, plugin in ipairs(dofile("nvim/.config/nvim/lua/plugins/markdown.lua")) do
  if plugin[1] == "folke/snacks.nvim" then
    image_resolver = plugin.opts.image.resolve
  end
end
assert(image_resolver, "YouTube image embeds need a Snacks resolver")
for _, url in ipairs({
  "https://www.youtube.com/watch?v=7IUshdNnzuw",
  "https://www.youtube.com/watch?v=JAo99RBfmT4&list=PLvd5bo3J-_kq4FcYVCOK6ZR87dCGDqrSH&index=3",
  "https://www.youtube.com/watch?v=t2SahnNVULA&t=12s",
}) do
  local id = url:match("[?&]v=([^&]+)")
  assert(image_resolver("recipe.md", url) == "https://i.ytimg.com/vi/" .. id .. "/hqdefault.jpg")
end
assert(image_resolver("recipe.md", "images/dish.png") == nil, "local images must retain default resolution")
assert(image_resolver("recipe.md", "https://example.org/image.png") == nil)
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
  { "![](https://www.youtube.com/watch?v=7IUshdNnzuw)", 18, false },
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
preview.setup({ delay = 10, cache_dir = cache_dir })
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
-- Reload the module to simulate a new Neovim session with an empty memory cache.
package.loaded["config.link-preview"] = nil
preview = require("config.link-preview")
preview.setup({ delay = 10, cache_dir = cache_dir })
local before_reload = shown
preview.schedule()
assert(vim.wait(300, function()
  return shown == before_reload + 1
end))
assert(#requests == 2, "fresh session did not use the disk cache")
preview.close()
-- CursorMoved is followed by WinScrolled when moving across the screen edge.
-- Scrolling must restart the delay instead of cancelling the preview forever.
local before_scroll = shown
preview.schedule()
vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(vim.api.nvim_get_current_win()) })
assert(
  vim.wait(300, function()
    return shown == before_scroll + 1
  end),
  "scrolling cancelled the hover without rescheduling it"
)
preview.close()
local before_mode = shown
vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "i:n" })
assert(
  vim.wait(300, function()
    return shown == before_mode + 1
  end),
  "returning to normal mode did not restart the hover"
)
preview.close()
-- Verify the image popup sizes once, cleans up its placement, and ignores late updates.
local update, image_closed, image_shown = nil, 0, 0
local placement_options
local image_failed, fallback_text = false, nil
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
    resolve = function(_, _, opts)
      assert(opts.relative == "editor" and opts.anchor == "NW", "image float must use stable screen coordinates")
      return {}
    end,
  }, {
    __call = function(_, opts)
      fallback_text = opts.text
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
        placement_options = opts
        assert(src == "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        update = opts.on_update_pre
        return {
          img = {
            failed = function()
              return image_failed
            end,
          },
          state = function()
            return { loc = { width = math.min(40, opts.max_width), height = math.min(15, opts.max_height) } }
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
-- A narrow split must contain both the border and the image, even near its edge.
vim.cmd("vsplit")
buffer({ "https://youtu.be/dQw4w9WgXcQ" }, 1, 24)
vim.cmd("redraw")
update = nil
preview.schedule()
assert(vim.wait(300, function()
  return update ~= nil
end))
update()
local source_pos = vim.api.nvim_win_get_position(0)
local source_width = vim.api.nvim_win_get_width(0)
local source_height = vim.api.nvim_win_get_height(0)
assert(placement_options.max_width <= source_width - 2)
assert(image_win.opts.col >= source_pos[2])
assert(image_win.opts.col + image_win.opts.width + 2 <= source_pos[2] + source_width)
assert(image_win.opts.row >= source_pos[1])
assert(image_win.opts.row + image_win.opts.height + 2 <= source_pos[1] + source_height)
preview.close()
-- A failed image never reaches on_update_pre; it must still produce a popup.
image_failed, update = true, nil
preview.schedule()
assert(
  vim.wait(500, function()
    return fallback_text ~= nil
  end),
  "failed image left the popup hidden"
)
assert(fallback_text[1] == "YouTube" and fallback_text[3] == "Preview image unavailable")
preview.close()
-- Late failures must not reopen a popup after moving away.
fallback_text, update = nil, nil
buffer({ "https://youtu.be/dQw4w9WgXcQ?t=1" }, 1, 8)
preview.schedule()
assert(vim.wait(300, function()
  return update ~= nil
end))
preview.close()
vim.wait(150)
assert(fallback_text == nil, "failed image reopened a dismissed preview")
vim.fn.delete(cache_dir, "rf")
print("Link preview detection, lifecycle, and cache tests passed")
vim.cmd("qa!")
