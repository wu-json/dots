local preview = require("link-preview")
local server = assert(vim.uv.new_tcp())
local clients, targets = {}, {}
local cache_dir = vim.fn.tempname()
local original_snacks = package.loaded.snacks
local shown

-- Exercise the actual curl invocation without depending on an external service.
assert(server:bind("127.0.0.1", 0))
assert(server:listen(16, function(err)
  assert(not err, err)
  local client = assert(vim.uv.new_tcp())
  clients[#clients + 1] = client
  assert(server:accept(client))
  local request = ""
  client:read_start(function(read_err, chunk)
    assert(not read_err, read_err)
    if not chunk then
      return
    end
    request = request .. chunk
    if request:find("\r\n\r\n", 1, true) then
      client:read_stop()
      targets[#targets + 1] = request:match("^GET (%S+) HTTP/")
      local body = "<title>Literal URL fetched</title>"
      client:write(
        "HTTP/1.1 200 OK\r\nContent-Length: " .. #body .. "\r\nConnection: close\r\n\r\n" .. body,
        function()
          client:close()
        end
      )
    end
  end)
end))

local ok, err = xpcall(function()
  package.loaded.snacks = {
    win = function(opts)
      shown = opts.text
      return { close = function() end }
    end,
  }
  preview.setup({ delay = 1, cache_dir = cache_dir })
  for _, target in ipairs({ "/?filter[tag]=lua", "/?choice={one,two}", "/?id=[1-2]" }) do
    shown, targets = nil, {}
    local url = "http://127.0.0.1:" .. server:getsockname().port .. target
    vim.cmd.enew()
    vim.bo.filetype = "markdown"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[preview](" .. url .. ")" })
    vim.api.nvim_win_set_cursor(0, { 1, 3 })
    preview.schedule()
    assert(vim.wait(3000, function()
      return shown ~= nil
    end), "fetch did not complete: " .. target)
    assert(shown[1] == "Literal URL fetched", "fetch failed for literal URL: " .. target)
    assert(#targets == 1 and targets[1] == target, "curl expanded or changed the URL: " .. target)
    preview.close()
  end
end, debug.traceback)

preview.close()
vim.api.nvim_del_augroup_by_name("MarkdownLinkPreview")
package.loaded.snacks = original_snacks
server:close()
for _, client in ipairs(clients) do
  if not client:is_closing() then
    client:close()
  end
end
vim.fn.delete(cache_dir, "rf")
assert(ok, err)
