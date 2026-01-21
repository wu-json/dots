return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      setup = {
        -- Bazel LSP using starpls (Starlark Language Server)
        starpls = function()
          local lspconfig = require("lspconfig")
          local configs = require("lspconfig.configs")

          if not configs.starpls then
            configs.starpls = {
              default_config = {
                cmd = { "starpls" },
                filetypes = { "bzl", "starlark" },
                root_dir = lspconfig.util.root_pattern("WORKSPACE", "WORKSPACE.bazel", "MODULE.bazel", ".git"),
              },
            }
          end

          lspconfig.starpls.setup({})
        end,

        -- Buck2 LSP
        buck2_lsp = function()
          local lspconfig = require("lspconfig")
          local configs = require("lspconfig.configs")

          if not configs.buck2_lsp then
            configs.buck2_lsp = {
              default_config = {
                cmd = { "buck2", "lsp" },
                filetypes = { "bzl", "starlark" },
                root_dir = lspconfig.util.root_pattern(".buckconfig", ".buckroot", "BUCK", "TARGETS", ".git"),
              },
            }
          end

          lspconfig.buck2_lsp.setup({})
        end,

        -- Custom setup for sand LSP
        sand = function()
          local lspconfig = require("lspconfig")
          local configs = require("lspconfig.configs")

          if not configs.sand then
            configs.sand = {
              default_config = {
                cmd = { "sand", "lsp", "--stdio" },
                filetypes = { "sand" },
                root_dir = lspconfig.util.root_pattern("sand.mod.json"),
                handlers = {
                  ["window/showMessage"] = function(_, result)
                    local message = result.message or "Unknown message"
                    local message_type = result.type or 1

                    if message_type == 1 then
                      require("snacks").notify.error(message)
                    elseif message_type == 2 then
                      require("snacks").notify.warn(message)
                    elseif message_type == 3 then
                      require("snacks").notify.info(message)
                    elseif message_type == 4 then
                      require("snacks").notify(message)
                    else
                      require("snacks").notify(message)
                    end

                    return vim.NIL
                  end,
                },
              },
            }
          end

          lspconfig.sand.setup({})
        end,
      },
      servers = {
        gopls = {},
        pyright = {},
        ruff_lsp = {},
        rust_analyzer = {},
        tailwindcss = {},
        terraformls = {},
        yamlls = {},
        sand = {},
        starpls = {},
        buck2_lsp = {},

        -- These are all for TypeScript but we disable them because they are hella slow.
        -- Instead we opt to use typescript-tools: https://github.com/pmizio/typescript-tools.nvim
        tsserver = { enabled = false },
        ts_ls = { enabled = false },
        vtsls = { enabled = false },
      },
    },
  },
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("typescript-tools").setup({
        on_attach = function(client)
          -- Disable formatting from typescript-tools since lazyvim uses conform for
          -- formatting making this redundant: https://github.com/pmizio/typescript-tools.nvim/issues/288
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
      })
    end,
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
        "python",
        "rst",
        "starlark",
        "terraform",
        "toml",
        "yaml",
      })
      -- Configure custom sand parser
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.sand = {
        install_info = {
          url = "/Users/jasonwu/GitHub/forge/treesitter-sand",
          files = { "src/parser.c" },
          generate_requires_npm = false,
          requires_generate_from_grammar = false,
        },
        filetype = "sand",
        used_by = { "sand" },
      }
    end,
  },
  {
    -- Need this to set up biome v2
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        javascript = { "biome" },
        javascriptreact = { "biome" },
        typescript = { "biome" },
        typescriptreact = { "biome" },
        json = { "biome" },
        jsonc = { "biome" },
      },
      formatters = {
        biome = {
          command = "./node_modules/.bin/biome",
          args = { "format", "--stdin-file-path", "$FILENAME" },
          stdin = true,
          require_cwd = true, -- Requires biome.json in project root
        },
      },
    },
  },
  {
    "apple/pkl-neovim",
    lazy = true,
    ft = "pkl",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "L3MON4D3/LuaSnip",
    },
    build = function()
      require("pkl-neovim").init()
      vim.cmd("TSInstall pkl")
    end,
    config = function()
      require("luasnip.loaders.from_snipmate").lazy_load()
      vim.g.pkl_neovim = {
        start_command = { "pkl-lsp" },
        pkl_cli_path = "/Users/jasonwu/.local/share/aquaproj-aqua/bin/pkl",
      }
    end,
  },
}
