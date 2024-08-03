return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "kanagawa" },
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    config = function()
      require("kanagawa").setup({
        compile = true,
        transparent = true,
        colors = {
          theme = {
            all = {
              ui = { bg_gutter = "none", float = { bg = "none" } },
            },
          },
        },
        overrides = function(colors)
          local theme = colors.theme
          return {
            NormalFloat = { bg = "none" },
            FloatBorder = { bg = "none" },
            FloatTitle = { bg = "none" },
            TelescopeTitle = { fg = theme.ui.special, bg = "none", bold = true },
            TelescopeBorder = { bg = "none" },
            TelescopePromptNormal = { bg = "none" },
            TelescopePromptBorder = { fg = "none", bg = "none" },
            TelescopeResultsNormal = { fg = "none", bg = "none" },
            TelescopeResultsBorder = { fg = "none", bg = "none" },
            TelescopePreviewNormal = { bg = "none" },
            TelescopePreviewBorder = { bg = "none", fg = "none" },
          }
        end,
      })
    end,
  },
  {
    "rcarriga/nvim-notify",
    opts = {
      background_colour = "#000000",
    },
  },
}
