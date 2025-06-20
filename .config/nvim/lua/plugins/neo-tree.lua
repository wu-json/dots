return {
  "nvim-neo-tree/neo-tree.nvim",
  lazy = true,
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
