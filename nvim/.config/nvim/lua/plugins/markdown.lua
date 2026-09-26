local function markdown_highlights()
  local headings = {
    { fg = "#B6C7D8", bg = "#28333C" },
    { fg = "#7EB3CE", bg = "#243039" },
    { fg = "#B6C7D8", bg = "#222B33" },
    { fg = "#B6C7D8", bg = "#20272E" },
    { fg = "#B6C7D8", bg = "#1E242A" },
    { fg = "#B6C7D8", bg = "#1C2126" },
  }
  for level, color in ipairs(headings) do
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level, { fg = color.fg, bold = true })
    vim.api.nvim_set_hl(0, "RenderMarkdownH" .. level .. "Bg", {
      fg = color.fg,
      bg = color.bg,
      bold = true,
    })
  end
end

return {
  { "bullets-vim/bullets.vim" },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    init = function()
      markdown_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("MarkdownTheme", { clear = true }),
        callback = markdown_highlights,
      })
    end,
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
