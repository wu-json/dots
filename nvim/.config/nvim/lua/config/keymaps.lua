-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

map("n", "<leader>E", "<cmd>Explore<cr>", { desc = "Open netrw explorer" })
map("n", "<leader>bo", "<cmd>BufOnly<cr>", { desc = "Delete all other buffers" })
map("n", "<leader>yp", "<cmd>let @+ = expand('%:p')<cr>", { desc = "Copy absolute path to clipboard" })

map("n", "<leader>p", function()
  Snacks.zen({
    toggles = { dim = false, git_signs = false, mini_diff_signs = false },
    win = {
      width = 90,
      wo = {
        wrap = true,
        linebreak = true,
        breakindent = true,
        spell = true,
        number = false,
        relativenumber = false,
        signcolumn = "no",
        foldcolumn = "0",
        cursorline = false,
        colorcolumn = "",
        list = false,
      },
    },
  })
end, { desc = "Toggle Prose Mode" })
