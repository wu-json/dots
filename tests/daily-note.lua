local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root .. "/nvim/.config/nvim")
vim.opt.rtp:prepend(vim.env.SNACKS_TEST_DIR or vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
require("snacks").setup({})
vim.o.hidden = true
vim.o.columns = 140
vim.g.mapleader = " "

local history_opened = false
local keys = {
  { "<leader>n", function() history_opened = true end, desc = "Notification History" },
}
for _, plugin in ipairs(require("plugins.aesthetics")) do
  if plugin[1] == "folke/snacks.nvim" then
    plugin.keys(plugin, keys)
  end
end
for _, key in ipairs(keys) do
  vim.keymap.set("n", key[1], key[2], { desc = key.desc })
end

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
directory = vim.uv.fs_realpath(directory)

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
assert(vim.fn.maparg("<leader>n", "n") == "", "notification history still consumes the daily note prefix")

local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end

local function assert_prose()
  assert(Snacks.zen.win and Snacks.zen.win:valid(), "prose window is missing")
  assert(vim.wo.wrap and vim.wo.linebreak and vim.wo.spell, "prose options were not applied")
  assert(not vim.wo.number and not vim.wo.relativenumber, "line numbers are still enabled")
  assert(vim.api.nvim_win_get_width(0) == 90, "prose window has the wrong width")
end

local function run()
  press("<leader>nh")
  assert(history_opened, "notification history shortcut did not run")
  history_opened = false
  press("<leader>nd")
  assert(not history_opened, "daily note shortcut opened notification history")
  assert(vim.api.nvim_buf_get_name(0) == directory .. "/" .. os.date("%Y-%m-%d.md"), "daily note shortcut did not open today's note")
  assert_prose()
  Snacks.zen.win:close()
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
