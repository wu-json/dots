local M = {}
local prose_win

function M.toggle()
  prose_win = Snacks.zen({
    toggles = { dim = false, git_signs = false, mini_diff_signs = false },
    win = {
      width = 90,
      wo = {
        wrap = true,
        linebreak = true,
        breakindent = true,
        spell = true,
        number = false,
        relativenumber = false,
        signcolumn = "no",
        foldcolumn = "0",
        cursorline = false,
        colorcolumn = "",
        list = false,
      },
    },
  })
end

function M.enable()
  local win = Snacks.zen.win
  if win and win:valid() then
    if win == prose_win then
      return
    end
    win:close()
  end
  M.toggle()
end

return M
