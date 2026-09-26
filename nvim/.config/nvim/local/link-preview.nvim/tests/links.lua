local preview = require("link-preview")
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

for _, case in ipairs({
  { '[**label**](https://example.org/note "title")', 4, "https://example.org/note" },
  { "[label](<https://example.org/a%20b>)", 3, "https://example.org/a%20b" },
  { "[label](https://example.org/a\\(b\\))", 3, "https://example.org/a(b)" },
  { "[label](https://example.org/?a=1&amp;b=2)", 3, "https://example.org/?a=1&b=2" },
  { "https://one.example/a https://two.example/b", 25, "https://two.example/b" },
  { "https://one.example/a gap https://two.example/b", 22, false },
  { "https://example.org/one_(two_(three)).", 10, "https://example.org/one_(two_(three))" },
  { "![label](https://example.org/photo.jpg)", 3, false },
  { "[mail](mailto:someone@example.org)", 3, false },
  { "    https://example.org/code", 10, false },
}) do
  buffer({ case[1] }, 1, case[2])
  local actual = preview.url_at_cursor()
  assert(actual == (case[3] or nil), case[1] .. ": " .. tostring(actual))
end
buffer({ "```lua", 'local url = "https://example.org/code"', "```" }, 2, 20)
assert(preview.url_at_cursor() == nil)
buffer({ "[a label", "with a newline](https://example.org/multiline)" }, 1, 3)
assert(preview.url_at_cursor() == "https://example.org/multiline")

for _, delimiter in ipairs({ "*", "**", "***", "_", "__", "~~" }) do
  local url = "https://example.org/article"
  local line = delimiter .. url .. delimiter
  for col = #delimiter, #delimiter + #url - 1 do
    buffer({ line }, 1, col)
    assert(preview.url_at_cursor() == url, line .. " at column " .. col)
  end
  buffer({ line }, 1, #delimiter + #url)
  assert(preview.url_at_cursor() == nil, "closing formatting delimiter must not be part of the URL")
end
for _, url in ipairs({ "https://example.org/a_b_", "https://example.org/a*", "https://example.org/a~" }) do
  buffer({ url }, 1, 10)
  assert(preview.url_at_cursor() == url, "literal URL punctuation must be preserved: " .. url)
end
buffer({ "**https://example.org/article**after" }, 1, 10)
assert(preview.url_at_cursor() == "https://example.org/article")
buffer({ "**https://example.org/article**after" }, 1, 31)
assert(preview.url_at_cursor() == nil, "text after a formatted URL must not trigger a preview")
buffer({ "**a multiline", "https://example.org/article**" }, 2, 10)
assert(preview.url_at_cursor() == "https://example.org/article")
