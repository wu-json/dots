return {
  {
    "folke/noice.nvim",
    opts = {
      -- noice's hover handler fires `vim.notify("No information available")`
      -- whenever an LSP hover returns no contents. tsgo legitimately returns
      -- null on some positions, so this fires constantly. Silencing the notify
      -- only — the real hover popup still shows when there is content.
      lsp = { hover = { silent = true } },
    },
  },
}
