-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

map("n", "<leader>E", "<cmd>Explore<cr>", { desc = "Open netrw explorer" })
map("n", "<leader>bo", "<cmd>BufOnly<cr>", { desc = "Delete all other buffers" })
map("n", "<leader>yp", "<cmd>let @+ = expand('%:p')<cr>", { desc = "Copy absolute path to clipboard" })

-- Render the current markdown file with glow into a read-only buffer that
-- keeps glow's colors but behaves like a normal buffer (motions, search, :bd).
-- Re-renders whenever the file changes on disk, until the render is closed.
local glow_watchers = {} -- name -> fs_event handle; re-invoking replaces the watch
map("n", "<leader>mg", function()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("glow: buffer has no file", vim.log.levels.WARN)
    return
  end
  local name = "glow://" .. vim.fn.fnamemodify(file, ":~:.")
  local replacing = false -- a refresh swaps buffers; don't treat that as closing

  local function stop_watch()
    local w = glow_watchers[name]
    if w then
      w:stop()
      w:close()
      glow_watchers[name] = nil
    end
  end

  -- Terminal buffer content can't be edited in place, so every render (initial
  -- or refresh) builds a fresh buffer. A refresh points windows showing the old
  -- render at it, keeping their cursors; a hidden render stays hidden.
  local function render(show_win)
    local old = vim.fn.bufnr(name)
    local wins = {} -- windows showing the previous render, with their cursors
    if old ~= -1 then
      for _, win in ipairs(vim.fn.win_findbuf(old)) do
        wins[#wins + 1] = { win = win, cursor = vim.api.nvim_win_get_cursor(win) }
      end
    end
    local width = math.min(vim.api.nvim_win_get_width(wins[1] and wins[1].win or show_win or 0) - 4, 120)
    -- an explicit style keeps glow from dropping colors when piped (not a TTY)
    local result = vim.system({ "glow", "-s", vim.o.background, "-w", tostring(width), file }, { text = true }):wait()
    if result.code ~= 0 then
      vim.notify("glow failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
      return false
    end
    if old ~= -1 then
      replacing = true
      vim.api.nvim_buf_delete(old, { force = true })
      replacing = false
    end
    -- scratch: no swapfile, so naming the buffer glow:// can't trigger E325 prompts
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(buf, name)
    local chan = vim.api.nvim_open_term(buf, {})
    vim.api.nvim_chan_send(chan, (result.stdout:gsub("\n", "\r\n")))
    -- Map link positions from glow's OSC 8 hyperlink escapes (\27]8;id;url BEL),
    -- which carry the full url even where the visible text is hard-wrapped
    -- mid-link. The terminal buffer drops these escapes, so scraping visible
    -- text would truncate wrapped urls; parse the raw stdout instead.
    local links = {} -- links[lnum] = { { s = byte, e = byte, url = url }, ... }
    local lnum = 0
    for line in (result.stdout .. "\n"):gmatch("(.-)\n") do
      lnum = lnum + 1
      local ranges, url, start, pos, vis = {}, nil, nil, 1, 0
      while pos <= #line do
        local s, e, u = line:find("^\27]8;[^;\27\7]*;([^\27\7]*)\7", pos)
        if not s then
          s, e, u = line:find("^\27]8;[^;\27]*;([^\27]*)\27\\", pos)
        end
        if s then
          if url and start then
            ranges[#ranges + 1] = { s = start, e = vis, url = url }
          end
          url = u ~= "" and u or nil
          start = url and vis + 1 or nil
          pos = e + 1
        else
          s, e = line:find("^\27%[[^%a\27]*%a", pos) -- SGR color/style sequences
          if s then
            pos = e + 1
          else
            if line:byte(pos) ~= 27 then
              vis = vis + 1 -- visible byte; offsets match the terminal buffer text
            end
            pos = pos + 1
          end
        end
      end
      if url and start then
        ranges[#ranges + 1] = { s = start, e = vis, url = url }
      end
      if #ranges > 0 then
        links[lnum] = ranges
      end
    end
    -- nvim's mouse handling swallows clicks before the terminal emulator can
    -- detect URLs, so open the link under the cursor ourselves on click (and gx)
    local function open_url_at_cursor()
      local cur = vim.api.nvim_win_get_cursor(0)
      local col = cur[2] + 1
      for _, r in ipairs(links[cur[1]] or {}) do
        if col >= r.s and col <= r.e then
          vim.ui.open(r.url)
          return
        end
      end
    end
    vim.keymap.set("n", "<LeftRelease>", open_url_at_cursor, { buffer = buf, desc = "Open link under cursor" })
    vim.keymap.set("n", "gx", open_url_at_cursor, { buffer = buf, desc = "Open link under cursor" })
    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
      buffer = buf,
      once = true,
      callback = function()
        if not replacing then
          stop_watch()
        end
      end,
    })
    if #wins == 0 then
      if show_win then
        vim.api.nvim_win_set_buf(show_win, buf)
      end
    else
      for _, w in ipairs(wins) do
        if vim.api.nvim_win_is_valid(w.win) then
          vim.api.nvim_win_set_buf(w.win, buf)
          pcall(vim.api.nvim_win_set_cursor, w.win, { math.min(w.cursor[1], vim.api.nvim_buf_line_count(buf)), w.cursor[2] })
        end
      end
    end
    return true
  end

  if not render(vim.api.nvim_get_current_win()) then
    return
  end

  stop_watch() -- re-invoking on the same file replaces its previous watch
  local watcher = assert(vim.uv.new_fs_event())
  glow_watchers[name] = watcher
  local queued = false
  local on_event
  on_event = vim.schedule_wrap(function(err)
    if glow_watchers[name] ~= watcher then
      return -- superseded by a newer invocation, or already stopped
    end
    -- re-arm on every event: editors that save via rename orphan the old watch
    watcher:stop()
    if err or not watcher:start(file, {}, on_event) then
      stop_watch()
      return
    end
    if queued then
      return
    end
    queued = true
    vim.defer_fn(function() -- one save emits a burst of events; render once
      queued = false
      if glow_watchers[name] ~= watcher then
        return
      end
      if vim.fn.bufnr(name) == -1 then
        stop_watch() -- render buffer is gone; nothing left to refresh
        return
      end
      render()
    end, 100)
  end)
  watcher:start(file, {}, on_event)
end, { desc = "Read markdown with glow" })
