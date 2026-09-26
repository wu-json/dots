-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

map("n", "<leader>nd", function()
  local result = vim.system({
    "fish", "-c",
    '__daily_notes_dir; and printf "%s\\n" "$DAILY_NOTES_FORMAT"',
  }, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify(vim.trim(result.stderr), vim.log.levels.ERROR)
    return
  end
  local settings = vim.split(result.stdout, "\n", { plain = true })
  local directory, format = settings[1], settings[2]
  if not format or format == "" then
    vim.notify("Set the Fish universal variable DAILY_NOTES_FORMAT to the relative note date format.", vim.log.levels.WARN)
    return
  end

  local path = vim.fs.joinpath(directory, os.date(format))
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.api.nvim_cmd({ cmd = "edit", args = { path }, magic = { file = false, bar = false } }, {})
  require("config.prose").enable()
end, { desc = "Open Daily Note" })

map("n", "<leader>gd", function()
  Snacks.terminal({ "gh", "dash" }, { win = { position = "float" } })
end, { desc = "GitHub Dashboard" })

map("n", "<leader>E", "<cmd>Explore<cr>", { desc = "Open netrw explorer" })
map("n", "<leader>bo", "<cmd>BufOnly<cr>", { desc = "Delete all other buffers" })
map("n", "<leader>yp", "<cmd>let @+ = expand('%:p')<cr>", { desc = "Copy absolute path to clipboard" })

map("n", "<leader>p", function()
  require("config.prose").toggle()
end, { desc = "Toggle Prose Mode" })
