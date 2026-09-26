local M = {}
local metadata = require("link-preview.metadata")

local function http(url)
  return url and url:match("^https?://") and url or nil
end

function M.at_cursor()
  local parsed, parser = pcall(vim.treesitter.get_parser, 0)
  if parsed and parser then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    parser:parse({ row - 1, row })
  end
  local block_ok, block = pcall(vim.treesitter.get_node, { ignore_injections = true })
  while block_ok and block do
    if block:type() == "fenced_code_block" or block:type() == "indented_code_block" then
      return nil
    end
    block = block:parent()
  end
  local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = false })
  local url, inline
  while ok and node do
    local kind = node:type()
    if kind == "image" or kind == "code_span" or kind == "fenced_code_block" or kind == "indented_code_block" then
      return nil
    end
    if kind == "inline_link" then
      for child in node:iter_children() do
        if child:type() == "link_destination" then
          url = vim.treesitter.get_node_text(child, 0):gsub("^<", ""):gsub(">$", "")
        end
      end
    elseif kind == "uri_autolink" then
      url = vim.treesitter.get_node_text(node, 0):gsub("^<", ""):gsub(">$", "")
    elseif kind == "inline" then
      inline = node
    end
    node = node:parent()
  end
  if url then
    return http(metadata.decode((url:gsub("\\([%p])", "%1"))))
  end
  local line, col = vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1
  if inline then
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local query = vim.treesitter.query.parse("markdown_inline", "(emphasis_delimiter) @delimiter")
    for _, delimiter in query:iter_captures(inline, 0, row, row + 1) do
      local _, first, _, last = delimiter:range()
      line = line:sub(1, first) .. string.rep(" ", last - first) .. line:sub(last + 1)
    end
  end
  local start = 1
  while true do
    local first, last = line:find("https?://[^%s<>\"']+", start)
    if not first then
      return nil
    end
    local candidate = line:sub(first, last):gsub("[.,;!?]+$", "")
    for _, pair in ipairs({ { "(", ")" }, { "[", "]" } }) do
      local _, opens = candidate:gsub(vim.pesc(pair[1]), "")
      local _, closes = candidate:gsub(vim.pesc(pair[2]), "")
      while closes > opens and candidate:sub(-1) == pair[2] do
        candidate = candidate:sub(1, -2)
        closes = closes - 1
      end
    end
    if col >= first and col < first + #candidate then
      return candidate:gsub("&amp;", "&")
    end
    start = last + 1
  end
end

return M
