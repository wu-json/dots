-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

map("n", "<leader>E", "<cmd>Explore<cr>", { desc = "Open netrw explorer" })
map("n", "<leader>bo", "<cmd>BufOnly<cr>", { desc = "Delete all other buffers" })
map("n", "<leader>yp", "<cmd>let @+ = expand('%:p')<cr>", { desc = "Copy absolute path to clipboard" })

-- Read the current markdown file with glow in a terminal, taking over the
-- window; quitting glow (q) drops you back into the file.
map("n", "<leader>mg", function()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("glow: buffer has no file", vim.log.levels.WARN)
    return
  end
  local prev_buf = vim.api.nvim_get_current_buf()
  vim.cmd("enew")
  local term_buf = vim.api.nvim_get_current_buf()
  vim.bo[term_buf].bufhidden = "wipe"
  vim.fn.jobstart({ "glow", "--pager", file }, {
    term = true,
    on_exit = function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(term_buf) then
          return
        end
        for _, win in ipairs(vim.fn.win_findbuf(term_buf)) do
          if vim.api.nvim_buf_is_valid(prev_buf) then
            vim.api.nvim_win_set_buf(win, prev_buf)
          end
        end
      end)
    end,
  })
  vim.cmd("startinsert")
end, { desc = "Read markdown with glow" })
