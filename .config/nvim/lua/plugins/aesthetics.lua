return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawabones",
    },
  },
  {
    "zenbones-theme/zenbones.nvim",
    init = function()
      vim.g.kanagawabones_transparent_background = true
    end,
    dependencies = {
      "rktjmp/lush.nvim",
    },
  },
  {
    "rcarriga/nvim-notify",
    opts = {
      background_colour = "#000000",
    },
  },
}
