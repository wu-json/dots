-- WezTerm lacks Kitty unicode placeholders, so Snacks draws images at fixed
-- screen positions that stay until the terminal is told to delete them.
-- Snacks misses that delete in three cases:
-- - hide() (image buffer left its window) only flags the image.
-- - update() returns early once the buffer is invalid, so a wiped buffer's
--   image is never deleted unless Snacks' BufWipeout autocmd ran.
-- - fzf-lua swaps and wipes preview buffers with autocmds ignored, so neither
--   that BufWipeout cleanup nor the BufWinLeave resize hook ever fires.
local M = {}

local placement = require("snacks.image.placement")
local terminal = Snacks.image.terminal
local live = setmetatable({}, { __mode = "k" }) ---@type table<snacks.image.Placement, true>

local function erase(p)
  if not terminal.env().placeholders then
    terminal.request({ a = "d", d = "i", i = p.img.id, p = p.id })
  end
end

local new, hide, del, update = placement.new, placement.hide, placement.del, placement.update

function placement.new(...)
  local p = new(...)
  live[p] = true
  return p
end

function placement:hide()
  if self:ready() then
    erase(self)
  end
  return hide(self)
end

function placement:del()
  erase(self)
  return del(self)
end

function placement:update()
  if not self.closed and not vim.api.nvim_buf_is_valid(self.buf) then
    return self:close()
  end
  return update(self)
end

-- Re-check every image after a window changed buffers without autocmds.
function M.refresh()
  for p in pairs(live) do
    if p.closed then
      live[p] = nil
    else
      p:update()
    end
  end
end

function M.patch_fzf()
  local base = require("fzf-lua.previewer.builtin").base
  local set_preview_buf = base.set_preview_buf
  function base:set_preview_buf(...)
    local ret = set_preview_buf(self, ...)
    M.refresh()
    return ret
  end
end

return M
