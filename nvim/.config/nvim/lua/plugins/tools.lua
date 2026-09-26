return {
  { "rhysd/git-messenger.vim" },
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    keys = {
      { "<leader>mm", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview (browser)" },
    },
  },
}
