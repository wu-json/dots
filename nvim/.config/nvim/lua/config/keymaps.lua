-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

map("n", "<leader>E", "<cmd>Explore<cr>", { desc = "Open netrw explorer" })
map("n", "<leader>bo", "<cmd>BufOnly<cr>", { desc = "Delete all other buffers" })
map("n", "<leader>yp", "<cmd>let @+ = expand('%:p')<cr>", { desc = "Copy absolute path to clipboard" })

-- Render the current markdown file with glow into a read-only buffer that
-- keeps glow's colors but behaves like a normal buffer (motions, search, :bd).
map("n", "<leader>mg", function()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("glow: buffer has no file", vim.log.levels.WARN)
    return
  end
  local width = math.min(vim.api.nvim_win_get_width(0) - 4, 120)
  -- an explicit style keeps glow from dropping colors when piped (not a TTY)
  local result = vim.system({ "glow", "-s", vim.o.background, "-w", tostring(width), file }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify("glow failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
    return
  end
  local name = "glow://" .. vim.fn.fnamemodify(file, ":~:.")
  local existing = vim.fn.bufnr(name)
  if existing ~= -1 then
    vim.api.nvim_buf_delete(existing, { force = true })
  end
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  -- no swapfile: this is a throwaway render, and naming it glow:// while it's
  -- still a normal buffer would otherwise create one and trigger E325 prompts
  vim.bo[buf].swapfile = false
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
end, { desc = "Read markdown with glow" })
