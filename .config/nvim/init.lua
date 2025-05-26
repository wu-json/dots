-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Sand stuffles
vim.filetype.add({
  extension = { sand = "sand" },
})
vim.lsp.config("sand", {
  name = "sand",
  cmd = { "sand", "--stdio" },
  filetypes = { "sand" },
  root_markers = { ".sand" },
})
vim.lsp.enable("sand")
