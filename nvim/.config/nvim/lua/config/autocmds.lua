-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Set filetype for sand files
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = "*.sand",
  callback = function()
    vim.bo.filetype = "sand"
  end,
})

-- Set filetype for Buck2 Starlark files
vim.filetype.add({
  extension = {
    bzl = "bzl",
  },
  filename = {
    ["BUCK"] = "bzl",
    ["TARGETS"] = "bzl",
  },
})

-- Register starlark treesitter parser for bzl filetype
vim.treesitter.language.register("starlark", "bzl")
