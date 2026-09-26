-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

if vim.env.DAILY_NOTE_PROSE == "1" then
  vim.env.DAILY_NOTE_PROSE = nil
  vim.schedule(function()
    require("config.prose").enable()
  end)
end
