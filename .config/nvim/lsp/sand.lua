return {
  name = "sand",
  cmd = { "sand", "--stdio" },
  filetypes = { "sand" },
  root_markers = { ".sand" },
  handlers = {
    -- Surface messages from LSP as notifications
    ["window/showMessage"] = function(_, result)
      local message = result.message or "Unknown message"
      local message_type = result.type or 1

      if message_type == 1 then -- Error
        require("snacks").notify.error(message)
      elseif message_type == 2 then -- Warning
        require("snacks").notify.warn(message)
      elseif message_type == 3 then -- Info
        require("snacks").notify.info(message)
      elseif message_type == 4 then -- Log
        require("snacks").notify(message)
      else
        require("snacks").notify(message)
      end

      return vim.NIL
    end,
  },
}
