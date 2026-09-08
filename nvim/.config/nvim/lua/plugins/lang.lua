return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        gopls = {},
        pyright = {
          -- Point pyright at the nearest `.venv`, walking up from the server root
          -- (nearest pyproject.toml) but never past the enclosing git repo. Covers
          -- per-subproject venvs and a shared uv-workspace venv at the repo root
          -- without repo-side config or a manual activate. Pyright itself never
          -- auto-detects `.venv`; it falls back to whatever `python3` is on PATH.
          on_init = function(client)
            local root = client.root_dir
            if not root then
              return
            end
            local repo = vim.fs.root(root, ".git")
            local venv = vim.fs.find(".venv", {
              path = root,
              upward = true,
              type = "directory",
              -- `stop` is exclusive, so pass the repo's parent to include the repo root itself.
              stop = vim.fs.dirname(repo or root),
            })[1]
            if not venv then
              return
            end
            client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
              python = { pythonPath = venv .. "/bin/python" },
            })
            client:notify("workspace/didChangeConfiguration", { settings = client.settings })
          end,
        },
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
