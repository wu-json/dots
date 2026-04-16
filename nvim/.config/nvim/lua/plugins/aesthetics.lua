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
