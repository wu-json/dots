return {
  {
    "wu-json/perfect-blue.nvim",
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "perfect-blue" },
  },
  {
    "j-hui/fidget.nvim",
  },
  {
    "folke/snacks.nvim",
    init = function()
      -- The dashboard window is nowrap, so when a sidebar (e.g. neo-tree)
      -- squeezes it, vim scrolls it horizontally to keep the cursor visible.
      -- Snacks re-renders on resize but never resets the scroll, leaving the
      -- dashboard shifted left once the sidebar closes.
      vim.api.nvim_create_autocmd("User", {
        pattern = "SnacksDashboardUpdatePost",
        callback = function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
              vim.api.nvim_win_call(win, function()
                vim.fn.winrestview({ leftcol = 0 })
              end)
            end
          end
        end,
      })
    end,
    keys = function(_, keys)
      for _, key in ipairs(keys) do
        if key[1] == "<leader>n" then
          key[1] = "<leader>nh"
        end
      end
    end,
    opts = {
      dashboard = {
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          function()
            local stats = require("lazy.stats").stats()
            local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
            return {
              align = "center",
              text = {
                { "", hl = "footer" },
                { stats.loaded .. "/" .. stats.count, hl = "special" },
                { " プラグイン ", hl = "footer" },
                { ms .. "ms で起動", hl = "special" },
              },
            }
          end,
        },
        preset = {
          keys = {
            {
              icon = " ",
              key = "f",
              desc = "ファイルを探す",
              action = ":lua Snacks.dashboard.pick('files')",
            },
            { icon = " ", key = "n", desc = "新規ファイル", action = ":ene | startinsert" },
            {
              icon = " ",
              key = "g",
              desc = "テキストを探す",
              action = ":lua Snacks.dashboard.pick('live_grep')",
            },
            {
              icon = " ",
              key = "r",
              desc = "最近のファイル",
              action = ":lua Snacks.dashboard.pick('oldfiles')",
            },
            {
              icon = " ",
              key = "c",
              desc = "設定",
              action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
            },
            { icon = " ", key = "s", desc = "セッション復元", section = "session" },
            { icon = " ", key = "x", desc = "レイジー エクストラ", action = ":LazyExtras" },
            { icon = "󰒲 ", key = "l", desc = "レイジー", action = ":Lazy" },
            { icon = " ", key = "q", desc = "終了", action = ":qa" },
          },
          header = [[
  「人間が美のことばかり考えていると、
   知らず知らず、世界で一等暗い思想に
   ぶつかるものだ。人間というものは、
   そんな風に出来ているらしい。」

          — 三島由紀夫『金閣寺』
          ]],
        },
      },
      terminal = {
        win = {
          position = "float",
        },
      },
    },
  },
  {
    "rktjmp/lush.nvim",
    -- For testing local themes built with lush
    -- { dir = "/Users/jasonwu/GitHub/personal/chainsaw.nvim", lazy=true }
  },
  { "rktjmp/shipwright.nvim" },
}
