return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        gopls = {},
        pyright = {},
        ruff_lsp = {},
        rust_analyzer = {},
        svelte = {},
        tailwindcss = {},
        terraformls = {},
        yamlls = {},
      },
    },
  },
  {
    "akinsho/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim", -- optional for vim.ui.select
    },
    config = function()
      require("flutter-tools").setup({
        closing_tags = { enabled = false },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "go",
        "gomod",
        "gowork",
        "gosum",
        "hcl",
        "python",
        "rst",
        "svelte",
        "terraform",
        "toml",
        "yaml",
      },
    },
  },
}
