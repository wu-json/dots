return {
  {
    "ibhagwan/fzf-lua",
    opts = function()
      require("config.image").patch_fzf()
    end,
  },
}
