return {
  "nvim-neo-tree/neo-tree.nvim",
  -- NOTE: (wu-json) I would love to lazy load this but there is a bug with this right now
  -- that causes an empty neo-tree on startup if we don't turn lazy loading off being tracked
  -- here: https://github.com/nvim-neo-tree/neo-tree.nvim/issues/1699
  lazy = false,
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        show_hidden_count = true,
        hide_dotfiles = false,
      },
    },
    window = { position = "right" },
  },
}
