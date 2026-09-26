local M = {}
local metadata = require("link-preview.metadata")
local disk_cache = require("link-preview.cache")
local options = {
  filetypes = { "markdown", "markdown.mdx" },
  delay = 200,
  ttl = 3600,
  failure_ttl = 60,
  max_entries = 128,
  max_width = 40,
  max_height = 12,
  cache_dir = disk_cache.directory(),
}
local cache, pending = {}, {}
local generation = 0
local hover

M.url_at_cursor = require("link-preview.links").at_cursor

local function resolve(url, callback)
  local entry = cache[url]
  if entry and entry.expires > os.time() then
    return callback(entry.data)
  end
  entry = disk_cache.get(options.cache_dir, url)
  if entry then
    cache[url] = entry
    return callback(entry.data)
  end
  local thumbnail = metadata.youtube(url)
  if thumbnail then
    return callback({ title = "YouTube", image = thumbnail })
  end
  if pending[url] then
    table.insert(pending[url], callback)
    return
  end
  pending[url] = { callback }
  vim.system({
    "curl",
    "--globoff",
    "--silent",
    "--show-error",
    "--fail",
    "--location",
    "--compressed",
    "--max-redirs",
    "5",
    "--max-time",
    "8",
    "--max-filesize",
    "1048576",
    "--proto",
    "=http,https",
    "--proto-redir",
    "=http,https",
    "--user-agent",
    "Mozilla/5.0 (Neovim link preview)",
    "--write-out",
    "\n%{url_effective}",
    "--",
    url,
  }, { text = true, timeout = 10000 }, function(result)
    vim.schedule(function()
      local html, final_url = (result.stdout or ""):match("^(.*)\n([^\n]+)$")
      local ok, data = false, nil
      if result.code == 0 and html then
        ok, data = pcall(metadata.parse, html, final_url)
      end
      if result.code ~= 0 or not ok or type(data) ~= "table" then
        data = { title = url, unavailable = true }
      end
      if vim.tbl_count(cache) >= options.max_entries then
        cache = {}
      end
      cache[url] = { data = data, expires = os.time() + (data.unavailable and options.failure_ttl or options.ttl) }
      disk_cache.put(options.cache_dir, url, cache[url], options.max_entries)
      local callbacks = pending[url]
      pending[url] = nil
      for _, cb in ipairs(callbacks) do
        cb(data)
      end
    end)
  end)
end

function M.close()
  generation = generation + 1
  if hover then
    local previous = hover
    hover = nil
    if previous.img then
      previous.img:close()
    end
    previous.win:close()
  end
end

local function show(data, url)
  local snacks = require("snacks")
  local current = {}
  hover = current
  if not data.image then
    local title = vim.fn.strcharpart((data.title or "Link preview"):gsub("%c", " "), 0, 160)
    current.win = snacks.win({
      text = {
        title,
        "",
        data.image_error and "Preview image unavailable"
          or (data.unavailable and "Preview unavailable" or "No preview image available"),
      },
      relative = "cursor",
      row = 1,
      col = 0,
      width = options.max_width,
      height = 3,
      enter = false,
      focusable = false,
      border = "rounded",
      wo = { wrap = true },
    })
    return
  end
  local source = vim.api.nvim_get_current_win()
  local origin = vim.api.nvim_win_get_position(source)
  local cursor = vim.api.nvim_win_get_cursor(source)
  local screen = vim.fn.screenpos(source, cursor[1], cursor[2] + 1)
  local top, left = origin[1], origin[2]
  local bottom = math.min(top + vim.api.nvim_win_get_height(source), vim.o.lines - vim.o.cmdheight)
  local right = math.min(left + vim.api.nvim_win_get_width(source), vim.o.columns)
  local row = math.max(top, math.min(bottom - 1, screen.row - 1))
  local col = math.max(left, screen.col - 1)
  local below, above = bottom - row - 1, row - top
  local available = math.max(below, above)
  if right - left < 3 or available < 3 then
    hover = nil
    return
  end
  local win = snacks.win(snacks.win.resolve(snacks.image.config.doc, "snacks_image", {
    relative = "editor",
    anchor = "NW",
    border = "rounded",
    show = false,
    enter = false,
    focusable = false,
    wo = { winblend = snacks.image.terminal.env().placeholders and 0 or nil },
  }))
  current.win = win
  win:open_buf()
  local updated = false
  local img = snacks.image.image.new(data.image)
  if img:failed() then
    img:convert()
    img:run()
  end
  current.img = snacks.image.placement.new(win.buf, data.image, {
    inline = false,
    max_width = math.min(options.max_width, right - left - 2),
    max_height = math.min(options.max_height, available - 2),
    on_update_pre = function()
      if hover == current and current.img and not updated then
        updated = true
        local loc = current.img:state().loc
        win.opts.width, win.opts.height = loc.width, loc.height
        win.opts.col = math.max(left, math.min(col + 1, right - loc.width - 2))
        win.opts.row = below >= loc.height + 2 and row + 1 or row - loc.height - 2
        win:show()
      end
    end,
  })
  local deadline = vim.uv.now() + 10000
  local function check_image()
    if hover ~= current or updated then
      return
    end
    if current.img.img:failed() or vim.uv.now() >= deadline then
      local fallback = { title = data.title, image_error = true }
      if url then
        cache[url] = { data = fallback, expires = os.time() + options.failure_ttl }
        disk_cache.put(options.cache_dir, url, cache[url], options.max_entries)
      end
      M.close()
      show(fallback)
      return
    end
    vim.defer_fn(check_image, 100)
  end
  vim.defer_fn(check_image, 100)
end

function M.schedule()
  M.close()
  if not vim.tbl_contains(options.filetypes, vim.bo.filetype) or vim.fn.mode() ~= "n" then
    return
  end
  local token = generation
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local cursor, tick = vim.api.nvim_win_get_cursor(0), vim.api.nvim_buf_get_changedtick(0)
  local function valid()
    return generation == token
      and vim.api.nvim_get_current_buf() == buf
      and vim.api.nvim_get_current_win() == win
      and vim.fn.mode() == "n"
      and vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor)
      and vim.api.nvim_buf_get_changedtick(0) == tick
  end
  vim.defer_fn(function()
    if not valid() then
      return
    end
    local url = M.url_at_cursor()
    if url then
      resolve(url, function(data)
        if valid() then
          show(data, url)
        end
      end)
    end
  end, options.delay)
end

function M.resolve_image(_, src)
  return metadata.youtube(src)
end

function M.setup(opts)
  options = vim.tbl_extend("force", options, opts or {})
  M.close()
  local group = vim.api.nvim_create_augroup("MarkdownLinkPreview", { clear = true })
  if vim.fn.executable("curl") == 0 then
    vim.notify("Link previews require curl", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_create_autocmd(
    { "CursorMoved", "BufEnter", "WinEnter", "ModeChanged", "TextChanged", "VimResized", "WinResized" },
    {
      group = group,
      callback = M.schedule,
    }
  )
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "VimLeavePre" }, {
    group = group,
    callback = M.close,
  })
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function(event)
      if tonumber(event.match) == vim.api.nvim_get_current_win() then
        M.schedule()
      end
    end,
  })
end

return M
