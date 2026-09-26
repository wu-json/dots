local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root .. "/nvim/.config/nvim")
vim.opt.rtp:prepend(vim.env.SNACKS_TEST_DIR or vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
require("snacks").setup({})
vim.o.hidden = true
vim.o.columns = 140

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")

-- Keep repository discovery outside these editor-state regression tests.
vim.system = function()
  return {
    wait = function()
      return { code = 0, stdout = directory .. "\n%Y-%m-%d.md\n" }
    end,
  }
end
require("config.keymaps")
local daily
for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
  if map.desc == "Open Daily Note" then
    daily = map.callback
  end
end
assert(daily, "daily note mapping was not registered")

local function assert_prose()
  assert(Snacks.zen.win and Snacks.zen.win:valid(), "prose window is missing")
  assert(vim.wo.wrap and vim.wo.linebreak and vim.wo.spell, "prose options were not applied")
  assert(not vim.wo.number and not vim.wo.relativenumber, "line numbers are still enabled")
  assert(vim.api.nvim_win_get_width(0) == 90, "prose window has the wrong width")
end

local function run()
  vim.api.nvim_cmd({ cmd = "edit", args = { directory .. "/" .. os.date("%Y-%m-%d.md") } }, {})
  local note = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(note, 0, -1, false, { "unsaved daily note" })
  daily()
  assert(vim.api.nvim_get_current_buf() == note, "daily shortcut replaced the note buffer")
  assert(vim.bo.modified and vim.api.nvim_get_current_line() == "unsaved daily note", "unsaved text was lost")
  assert_prose()
  local prose_window = vim.api.nvim_get_current_win()
  daily()
  assert(vim.api.nvim_get_current_win() == prose_window, "repeated shortcut recreated prose mode")
  Snacks.zen.win:close()

  for _, mode in ipairs({ "zoom", "zen" }) do
    vim.cmd.enew()
    vim.wo.wrap = false
    vim.wo.spell = false
    Snacks.zen[mode]()
    daily()
    assert(vim.api.nvim_get_current_buf() == note, mode .. " did not open the existing note")
    assert(vim.bo.modified and vim.api.nvim_get_current_line() == "unsaved daily note", "hidden note edits were lost")
    assert_prose()
    require("config.prose").toggle()
    assert(not (Snacks.zen.win and Snacks.zen.win:valid()), "prose toggle did not close the window")
  end
end

local ok, err = xpcall(run, debug.traceback)
vim.fn.delete(directory, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("Daily note regression tests passed")
vim.cmd("qa!")
