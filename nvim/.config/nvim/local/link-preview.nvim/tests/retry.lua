local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local snacks_dir = vim.env.SNACKS_TEST_DIR or vim.fn.stdpath("data") .. "/lazy/snacks.nvim"
local image_file = vim.fn.tempname()
local cache_dir = vim.fn.tempname()
local now = os.time()
os.time = function()
  return now
end
local attempts, shown, fallbacks = 0, 0, 0
local failed = true
local snacks = {
  image = {
    config = { doc = {} },
    terminal = {
      env = function()
        return {}
      end,
      request = function() end,
    },
    convert = {
      convert = function(opts)
        local conversion = { file = image_file, meta = {} }
        function conversion:run()
          attempts = attempts + 1
          vim.schedule(function()
            self.finished, self.failure = true, failed
            if not failed then
              vim.fn.writefile({ "image" }, image_file)
            end
            opts.on_done(self)
          end)
        end
        function conversion:done()
          return self.finished
        end
        function conversion:error()
          return self.failure
        end
        return conversion
      end,
    },
  },
  util = {
    base64 = function(value)
      return value
    end,
  },
}
_G.Snacks = snacks
package.loaded.snacks = snacks
snacks.image.image = dofile(snacks_dir .. "/lua/snacks/image/image.lua")
snacks.win = setmetatable({
  resolve = function(_, _, opts)
    return opts
  end,
}, {
  __call = function(_, opts)
    if opts.text then
      fallbacks = fallbacks + 1
    end
    return {
      buf = 1,
      opts = {},
      open_buf = function() end,
      close = function() end,
      show = function()
        shown = shown + 1
      end,
    }
  end,
})
snacks.image.placement = {
  new = function(_, src, opts)
    local placement = { img = snacks.image.image.new(src) }
    function placement:state()
      return { loc = { width = 20, height = 5 } }
    end
    function placement:close()
      self.img:del(self.id)
    end
    function placement:error() end
    function placement:update()
      opts.on_update_pre()
    end
    placement.img:place(placement)
    if placement.img:ready() then
      vim.schedule(function()
        placement:update()
      end)
    end
    return placement
  end,
}
local preview = require("link-preview")
preview.url_at_cursor = function()
  return "https://youtu.be/dQw4w9WgXcQ"
end
vim.bo.filetype = "markdown"
preview.setup({ delay = 1, failure_ttl = 60, cache_dir = cache_dir })
preview.schedule()
assert(
  vim.wait(500, function()
    return fallbacks == 1
  end),
  "initial failure did not show fallback"
)
local first_attempts = attempts
assert(first_attempts == 1, "initial hover converted more than once")
failed = false
preview.schedule()
assert(
  vim.wait(500, function()
    return fallbacks == 2
  end),
  "failure cache was not reused"
)
assert(attempts == first_attempts, "image retried before failure TTL expired")
now = now + 61
preview.schedule()
assert(
  vim.wait(500, function()
    return shown == 1
  end),
  "image did not recover after failure TTL expired"
)
assert(attempts == first_attempts + 1, "expired failure did not retry conversion exactly once")
preview.close()
preview.schedule()
assert(
  vim.wait(500, function()
    return shown == 2
  end),
  "successful image was not reused"
)
assert(attempts == first_attempts + 1, "successful image was converted again")
preview.close()
vim.fn.delete(image_file)
vim.fn.delete(cache_dir, "rf")
print("Link preview image retry tests passed")
vim.cmd("qa!")
