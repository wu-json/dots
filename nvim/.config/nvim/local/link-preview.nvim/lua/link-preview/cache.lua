local M = {}

function M.directory()
  local root = vim.env.TMPDIR or vim.env.TEMP or "/tmp"
  return vim.fs.joinpath(root, "nvim-link-preview-" .. vim.fn.sha256(vim.fn.expand("~")):sub(1, 12))
end

local function filename(dir, url)
  return vim.fs.joinpath(dir, vim.fn.sha256(url) .. ".json")
end

function M.get(dir, url)
  local path = filename(dir, url)
  local ok, entry = pcall(function()
    local stat = vim.uv.fs_stat(path)
    if not stat or stat.size > 65536 then
      return
    end
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  if ok and type(entry) == "table" and type(entry.expires) == "number" and entry.expires > os.time() then
    local data = entry.data
    if
      type(data) == "table"
      and type(data.title) == "string"
      and (data.image == nil or type(data.image) == "string")
    then
      return entry
    end
  end
  vim.uv.fs_unlink(path)
end

function M.put(dir, url, entry, max_entries)
  pcall(function()
    vim.fn.mkdir(dir, "p", tonumber("700", 8))
    local encoded = vim.json.encode(entry)
    if #encoded > 65536 then
      return
    end
    local path = filename(dir, url)
    local temporary = path .. "." .. vim.fn.getpid()
    vim.fn.writefile({ encoded }, temporary)
    local renamed = vim.uv.fs_rename(temporary, path)
    if not renamed then
      vim.uv.fs_unlink(temporary)
      return
    end
    local files = {}
    for name, kind in vim.fs.dir(dir) do
      if kind == "file" and name:match("^%x+%.json$") then
        local file = vim.fs.joinpath(dir, name)
        local stat = vim.uv.fs_stat(file)
        if stat then
          files[#files + 1] = { path = file, time = stat.mtime.sec }
        end
      end
    end
    table.sort(files, function(a, b)
      if a.time == b.time then
        return a.path < b.path
      end
      return a.time < b.time
    end)
    for i = 1, #files - max_entries do
      vim.uv.fs_unlink(files[i].path)
    end
  end)
end

return M
