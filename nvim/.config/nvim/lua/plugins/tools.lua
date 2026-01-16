return {
  { "rhysd/git-messenger.vim" },
  {
    "rktjmp/fwatch.nvim",
    config = function()
      local fwatch = require("fwatch")
      -- Watch for .sand file changes and reload buffer
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.sand",
        callback = function()
          local bufnr = vim.api.nvim_get_current_buf()
          local filepath = vim.api.nvim_buf_get_name(bufnr)
          if filepath ~= "" and vim.fn.filereadable(filepath) == 1 then
            fwatch.watch(filepath, {
              on_event = vim.schedule_wrap(function()
                if vim.api.nvim_buf_is_valid(bufnr) then
                  vim.api.nvim_buf_call(bufnr, function()
                    vim.cmd("checktime")
                  end)
                end
              end),
            })
          end
        end,
      })
    end,
  },
  {
    "wallpants/github-preview.nvim",
    cmd = { "GithubPreviewToggle" },
    keys = { "<leader>mpt" },
    config = function(_, opts)
      local gpreview = require("github-preview")
      gpreview.setup(opts)
      local fns = gpreview.fns
      vim.keymap.set("n", "<leader>mpt", fns.toggle)
      vim.keymap.set("n", "<leader>mps", fns.single_file_toggle)
      vim.keymap.set("n", "<leader>mpd", fns.details_tags_toggle)
    end,
  },
  {
    "mistweaverco/kulala.nvim",
    keys = {
      { "<leader>Rs", desc = "Send request" },
      { "<leader>Ra", desc = "Send all requests" },
      { "<leader>Rb", desc = "Open scratchpad" },
    },
    ft = { "http", "rest" },
    opts = {
      -- your configuration comes here
      global_keymaps = true,
      global_keymaps_prefix = "<leader>R",
      kulala_keymaps_prefix = "",
    },
  },
  {
    "vimwiki/vimwiki",
    keys = {
      { "<leader>ww", desc = "Open vimwiki index" },
      { "<leader>wd", "<cmd>VimwikiMakeDiaryNote<cr>", desc = "Open vimwiki diary" },
      { "<leader>wi", "<cmd>VimwikiDiaryIndex<cr>", desc = "Open vimwiki diary index" },
    },
    init = function()
      vim.g.vimwiki_list = {
        {
          path = "~/vimwiki/",
          syntax = "markdown",
          ext = ".md",
          auto_diary_index = 1,
        },
      }
      vim.g.vimwiki_global_ext = 0 -- Don't hijack all .md files
    end,
  },
  {
    "sotte/presenting.nvim",
    opts = {
      -- fill in your options here
      -- see :help Presenting.config
    },
    cmd = { "Presenting" },
  },
}
