return {
  {
    "wu-json/chainsaw.nvim",
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "reze" },
  },
  {
    "j-hui/fidget.nvim",
  },
  {
    "folke/snacks.nvim",
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
                { "Loaded ", hl = "footer" },
                { stats.loaded .. "/" .. stats.count, hl = "special" },
                { " plugins in ", hl = "footer" },
                { ms .. "ms", hl = "special" },
              },
            }
          end,
        },
        preset = {
          keys = {
          { icon = " ", key = "f", desc = "ファイルを探す", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "新規ファイル", action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "テキストを探す", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "最近のファイル", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "c", desc = "設定", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
          { icon = " ", key = "s", desc = "セッション復元", section = "session" },
          { icon = " ", key = "x", desc = "Lazy エクストラ", action = ":LazyExtras" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "終了", action = ":qa" },
          },
          header = [[
 ⠀⠀⠀⠀⠀⠀⠀⠀⢰⡀⠀⠀⠀⠀⠀⠀⢠⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⢁⠀⠀⠀⠀⠀⠀⣸⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⢸⠀⠀⢰⡆⠀⠀⣿⠘⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢠⣿⠘⠀⠀⣾⢰⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠀⠀⠀⣿⢸⠀⠀⣿⠀⡆⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠀⣴⡇⣿⢸⢸⣼⣿⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢀⣴⡝⣼⣮⢣⣿⢸⡜⣵⣍⣪⣦⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣧⠰⡞⣿⢸⢷⠆⣿⣟⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣶⣆⠀⢻⡹⣆⠻⣟⣻⠟⣰⢏⡟⠀⣰⣶⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢢⢿⡷⣿⡀⣽⠮⡕⣿⣏⣫⠵⣏⢀⣿⢼⡟⡄⠀⠀⠀⠀⠀
⠀⠀⢀⣴⠾⢫⣿⣷⡝⣜⣟⣀⢐⣻⣟⡂⣀⣻⣻⢫⣾⣷⣍⡑⠄⡀⠀⠀
⢀⡴⠯⠑⠂⠉⠀⢈⣻⢸⣿⣿⣾⣹⢏⣷⣿⣿⡇⣏⠁⠀⠉⠙⠓⠮⢦⡀
⠀⠀⠀⠀⠀⠀⠀⣾⠏⠸⠀⠀⢉⣷⠺⡉⠀⠀⣿⡄⠰⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣸⢋⠔⠁⠀⠀⢸⣿⠀⠇⠀⠀⠈⠻⣆⢃⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢠⠓⠁⠀⠀⠀⠀⠀⣿⢰⠀⠀⠀⠀⠀⠈⢫⡄⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠊⠀⠀⠀⠀⠀⠀⠀⢹⡄⠀⠀⠀⠀⠀⠀⠀⠑⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
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
  -- { "rktjmp/lush.nvim", { dir = "/Users/jasonwu/GitHub/personal/chainsaw.nvim", lazy = true } },
  { "rktjmp/shipwright.nvim" },
}
