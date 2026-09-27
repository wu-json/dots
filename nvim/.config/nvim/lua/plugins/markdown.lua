return {
  {
    "wu-json/link-preview.nvim",
    event = "VeryLazy",
    dependencies = { "folke/snacks.nvim" },
    opts = {},
  },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "html", "markdown", "markdown_inline" } } },
  { "bullets-vim/bullets.vim" },
  {
    "folke/snacks.nvim",
    opts = {
      styles = {
        snacks_image = {
          -- Keep the float and terminal image together as the cursor moves.
          relative = "editor",
          row = function(win)
            return math.max(0, math.min(vim.fn.screenrow(), vim.o.lines - vim.o.cmdheight - win.opts.height - 2))
          end,
          col = function(win)
            return math.max(0, math.min(vim.fn.screencol(), vim.o.columns - win.opts.width - 2))
          end,
        },
      },
      image = {
        enabled = true,
        resolve = function(_, src)
          return require("link-preview").resolve_image(nil, src)
        end,
        -- Show images at the cursor without rendering them inline while scrolling.
        doc = { inline = false, float = true, max_width = 40, max_height = 12 },
        math = { enabled = false },
      },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      heading = {
        width = "full",
        icons = {},
      },
      code = {
        disable_background = true,
        inline = false,
      },
      link = {
        hyperlink = "",
        custom = {},
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft.markdown = {}
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      for _, ft in ipairs({ "markdown", "markdown.mdx" }) do
        opts.formatters_by_ft[ft] = vim.tbl_filter(function(formatter)
          return formatter ~= "markdownlint-cli2"
        end, opts.formatters_by_ft[ft] or {})
      end
    end,
  },
}
