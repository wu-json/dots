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
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false,
    opts = {
      provider = "claude",
      claude = {
        endpoint = "https://api.anthropic.com",
        model = "claude-3-5-sonnet-20241022",
        temperature = 0,
        max_tokens = 4096,
      },
      vendors = {
        ollama = {
          __inherited_from = "openai",
          api_key_name = "",
          endpoint = "http://127.0.0.1:11434/v1",
          model = "deepseek-r1:14b",
          -- This is to let us parse out the "think" content. I stole this from: https://github.com/yetone/avante.nvim/issues/1115
          parse_stream_data = function(data, handler_opts)
            local json_data = vim.fn.json_decode(data)

            if json_data then
              -- Check for final message with "done: true"
              if json_data.done then
                handler_opts.on_complete(nil) -- Signal completion
                return
              end

              if json_data.message and json_data.message.content then
                local content = json_data.message.content

                -- Track and accumulate content after <think> tag
                if not handler_opts.in_think_block and content:match("<think>") then
                  handler_opts.in_think_block = true
                  return
                end

                if handler_opts.in_think_block and content:match("</think>") then
                  handler_opts.in_think_block = false
                  return
                end

                -- Only pass content when not in think block
                if not handler_opts.in_think_block and content ~= "" then
                  handler_opts.on_chunk(content)
                end
              end
            end
          end,
        },
      },
    },
    build = "make",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "echasnovski/mini.pick", -- for file_selector provider mini.pick
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
      "ibhagwan/fzf-lua", -- for file_selector provider fzf
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = { file_types = { "markdown", "Avante" } },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
