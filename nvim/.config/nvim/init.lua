-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.filetype.add({
  extension = { pkl = "pkl" },
})

if vim.env.DAILY_NOTE_PROSE == "1" then
  vim.env.DAILY_NOTE_PROSE = nil
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      require("config.prose").enable()
    end,
  })
end
