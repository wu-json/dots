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
        sourcekit = { mason = false },
        tailwindcss = {},
        terraformls = {},
        yamlls = {},

        vtsls = { enabled = false },
        tsgo = {},
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "go",
        "gomod",
        "gowork",
        "gosum",
        "hcl",
        "pkl",
        "python",
        "rst",
        "swift",
        "toml",
        "yaml",
      })
    end,
  },
  {
    "apple/pkl-neovim",
    lazy = true,
    ft = "pkl",
    init = function()
      vim.g.pkl_neovim = {
        start_command = { "pkl-lsp" },
        pkl_cli_path = "/Users/jasonwu/.local/share/aquaproj-aqua/bin/pkl",
      }
    end,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "L3MON4D3/LuaSnip",
    },
    config = function()
      require("luasnip.loaders.from_snipmate").lazy_load()
      require("pkl-neovim").init()
    end,
  },
}
