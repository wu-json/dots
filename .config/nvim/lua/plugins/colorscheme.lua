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
    "rose-pine/neovim",
    name = "rose-pine",
    opts = {
      styles = { transparency = true },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },
  {
    "rcarriga/nvim-notify",
    opts = {
      background_colour = "#000000",
    },
  },
}
