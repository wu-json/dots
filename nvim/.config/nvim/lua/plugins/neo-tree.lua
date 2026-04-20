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
    commands = {
      open_in_obsidian = function(state)
        local node = state.tree:get_node()
        local filepath = node:get_id()

        if vim.fn.executable("obsidian") == 0 then
          vim.notify("obsidian CLI not found in PATH", vim.log.levels.ERROR)
          return
        end

        local vault_path = vim.fn.trim(vim.fn.system({ "obsidian", "vault", "info=path" }))
        if vim.v.shell_error ~= 0 or vault_path == "" then
          vim.notify("Could not resolve Obsidian vault path", vim.log.levels.ERROR)
          return
        end

        local abs = vim.fn.fnamemodify(filepath, ":p")
        local root = vault_path:gsub("/+$", "") .. "/"
        if abs:sub(1, #root) ~= root then
          vim.notify(("File is not inside the Obsidian vault (%s)"):format(vault_path), vim.log.levels.WARN)
          return
        end

        local rel = abs:sub(#root + 1)
        vim.system({ "obsidian", "open", "path=" .. rel }, { detach = true })
        if vim.fn.has("mac") == 1 then
          vim.system({ "open", "-a", "Obsidian" }, { detach = true })
        end
        vim.notify(("Opened in Obsidian: %s"):format(rel))
      end,
      copy_selector = function(state)
        local node = state.tree:get_node()
        local filepath = node:get_id()
        local filename = node.name
        local modify = vim.fn.fnamemodify

        local vals = {
          ["BASENAME"] = modify(filename, ":r"),
          ["EXTENSION"] = modify(filename, ":e"),
          ["FILENAME"] = filename,
          ["PATH (CWD)"] = modify(filepath, ":."),
          ["PATH (HOME)"] = modify(filepath, ":~"),
          ["PATH"] = filepath,
          ["URI"] = vim.uri_from_fname(filepath),
        }

        local options = vim.tbl_filter(function(val)
          return vals[val] ~= ""
        end, vim.tbl_keys(vals))
        if vim.tbl_isempty(options) then
          vim.notify("No values to copy", vim.log.levels.WARN)
          return
        end
        table.sort(options)
        vim.ui.select(options, {
          prompt = "Choose to copy to clipboard:",
          format_item = function(item)
            return ("%s: %s"):format(item, vals[item])
          end,
        }, function(choice)
          local result = vals[choice]
          if result then
            vim.notify(("Copied: `%s`"):format(result))
            vim.fn.setreg("+", result)
          end
        end)
      end,
    },
    window = {
      position = "right",
      mappings = {
        Y = "copy_selector",
        O = "open_in_obsidian",
      },
    },
  },
}
