-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Sand stuffles
vim.filetype.add({
  extension = { sand = "sand", pkl = "pkl" },
})
