local M = {}
local metadata = require("config.link-preview.metadata")
local options = { delay = 200, ttl = 3600, max_entries = 128, max_width = 60, max_height = 20 }
local cache, pending = {}, {}
local generation = 0
local hover

local function http(url)
  return url and url:match("^https?://") and url or nil
end

-- Use the syntax tree so hovering the label works too, and images/code are excluded.
function M.url_at_cursor()
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
  local url
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
    end
    node = node:parent()
  end
  if url then
    return http(metadata.decode(url))
  end
  -- Bare URLs and HTML iframe src URLs (including YouTube embeds).
  local line, col = vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2] + 1
  local start = 1
  while true do
    local first, last = line:find("https?://[^%s<>\"']+", start)
    if not first then
      return nil
    end
    local candidate = line:sub(first, last):gsub("[.,;!?]+$", "")
    -- Strip unmatched closing delimiters, preserving parentheses inside URLs.
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

local function resolve(url, callback)
  local thumbnail = metadata.youtube(url)
  if thumbnail then
    return callback({ title = "YouTube", image = thumbnail })
  end
  local entry = cache[url]
  if entry and entry.expires > os.time() then
    return callback(entry.data)
  end
  if pending[url] then
    table.insert(pending[url], callback)
    return
  end
  pending[url] = { callback }
  vim.system({
    "curl",
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
      cache[url] = { data = data, expires = os.time() + (data.unavailable and 60 or options.ttl) }
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

local function show(data)
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
  -- Cursor-relative floats can be shifted by Neovim at the screen edge after
  -- Snacks has positioned the terminal image. Use explicit, bounded coordinates.
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
  -- Snacks writes conversion errors into the image buffer, but this float is
  -- hidden until the first successful render. Surface failures ourselves.
  local deadline = vim.uv.now() + 10000
  local function check_image()
    if hover ~= current or updated then
      return
    end
    if current.img.img:failed() or vim.uv.now() >= deadline then
      M.close()
      show({ title = data.title, image_error = true })
      return
    end
    vim.defer_fn(check_image, 100)
  end
  vim.defer_fn(check_image, 100)
end

function M.schedule()
  M.close()
  if not vim.tbl_contains({ "markdown", "markdown.mdx" }, vim.bo.filetype) or vim.fn.mode() ~= "n" then
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
          show(data)
        end
      end)
    end
  end, options.delay)
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
        -- A cursor move can scroll the source window after scheduling a hover.
        -- Restart the delay at the new viewport instead of cancelling it.
        M.schedule()
      end
    end,
  })
end

return M
