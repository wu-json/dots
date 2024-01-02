return {
  {
    "EdenEast/nightfox.nvim",
    opts = {
      options = {
        transparent = true,
      },
      groups = {
        all = {
          NormalFloat = { fg = "fg1", bg = "NONE" },
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "nightfox",
    },
  },
  {
    "rcarriga/nvim-notify",
    opts = {
      background_colour = "#000000",
    },
  },
}
