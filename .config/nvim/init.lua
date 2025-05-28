-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Sand stuffles
vim.filetype.add({
  extension = { sand = "sand" },
})
vim.lsp.enable("sand")
