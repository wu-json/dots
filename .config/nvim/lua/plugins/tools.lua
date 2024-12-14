return {
  {
    "echasnovski/mini.nvim",
    version = "*",
    config = function()
      require("mini.surround").setup()
    end,
  },
  { "iamcco/markdown-preview.nvim" },
  { "rhysd/git-messenger.vim" },
}
