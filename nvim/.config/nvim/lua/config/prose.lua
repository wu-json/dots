local M = {}

function M.toggle()
  Snacks.zen({
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
  if not (Snacks.zen.win and Snacks.zen.win:valid()) then
    M.toggle()
  end
end

return M
