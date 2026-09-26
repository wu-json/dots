local M = {}

function M.decode(text)
  local entities = { amp = "&", quot = '"', apos = "'", lt = "<", gt = ">", nbsp = " " }
  return (
    text:gsub("&(#?[%w]+);", function(entity)
      local number = entity:match("^#[xX](%x+)$")
      number = number and tonumber(number, 16) or tonumber(entity:match("^#(%d+)$"))
      if number and number > 0 and number <= 0x10FFFF and not (number >= 0xD800 and number <= 0xDFFF) then
        return vim.fn.nr2char(number)
      end
      return entities[entity] or "&" .. entity .. ";"
    end)
  )
end

function M.absolute(base, value)
  value = vim.trim(value)
  if value:match("^https?://[^/]+") then
    return value
  elseif value:match("^[%w+.-]+:") then
    return nil
  end
  local scheme, authority, path = base:match("^(https?)://([^/?#]+)(.*)$")
  if not scheme then
    return nil
  end
  if value:sub(1, 2) == "//" then
    return scheme .. ":" .. value
  end
  if value == "" or value:sub(1, 1) == "#" then
    return base:gsub("#.*$", "") .. value
  end
  path = path:gsub("[?#].*$", "")
  if value:sub(1, 1) == "?" then
    return scheme .. "://" .. authority .. path .. value
  end
  local joined = value:sub(1, 1) == "/" and value or (path:match("^(.*)/") or "") .. "/" .. value
  local pathname, suffix = joined:match("^([^?#]*)(.*)$")
  local parts = {}
  -- Empty segments are significant (for example, an image proxy's embedded URL).
  local segments = vim.split(pathname:sub(2), "/", { plain = true, trimempty = false })
  for i, part in ipairs(segments) do
    if part == ".." then
      table.remove(parts)
    elseif part ~= "." then
      parts[#parts + 1] = part
    end
    if i == #segments and (part == "." or part == "..") then
      parts[#parts + 1] = ""
    end
  end
  return scheme .. "://" .. authority .. "/" .. table.concat(parts, "/") .. suffix
end

function M.youtube(url)
  url = url:gsub("#.*$", "")
  local host, path = url:match("^https?://([^/]+)(/.*)$")
  if not host then
    return
  end
  host = host:lower()
  local video
  if host == "youtu.be" or host == "www.youtu.be" then
    video = path:match("^/([^/?#]+)")
  elseif
    vim.tbl_contains(
      { "youtube.com", "www.youtube.com", "m.youtube.com", "youtube-nocookie.com", "www.youtube-nocookie.com" },
      host
    )
  then
    if path:match("^/watch%?") then
      video = path:match("[?&]v=([^&#]+)")
    else
      local kind, id = path:match("^/([^/]+)/([^/?#]+)")
      if kind == "embed" or kind == "shorts" or kind == "live" then
        video = id
      end
    end
  end
  if video and #video == 11 and video:match("^[%w_-]+$") then
    return "https://i.ytimg.com/vi/" .. video .. "/mqdefault.jpg"
  end
end

function M.parse(html, url)
  local parser = vim.treesitter.get_string_parser(html, "html")
  local root = parser:parse()[1]:root()
  local query = vim.treesitter.query.parse("html", "[(start_tag) (self_closing_tag) (end_tag)] @tag")
  local meta, title, base = {}, nil, url
  local has_base = false
  for _, node in query:iter_captures(root, html) do
    local tag, attrs = nil, {}
    for child in node:iter_children() do
      if child:type() == "tag_name" then
        tag = vim.treesitter.get_node_text(child, html):lower()
      elseif child:type() == "attribute" then
        local name, value
        for attr in child:iter_children() do
          if attr:type() == "attribute_name" then
            name = vim.treesitter.get_node_text(attr, html):lower()
          elseif attr:type() == "attribute_value" then
            value = vim.treesitter.get_node_text(attr, html)
          elseif attr:type() == "quoted_attribute_value" then
            value = vim.treesitter.get_node_text(attr, html):sub(2, -2)
          end
        end
        if name and value then
          attrs[name] = M.decode(value)
        end
      end
    end
    if node:type() == "end_tag" then
      if tag == "head" then
        break
      end
    elseif tag == "meta" then
      local key = (attrs.property or attrs.name or ""):lower()
      attrs.content = attrs.content and vim.trim(attrs.content)
      if attrs.content and attrs.content ~= "" then
        meta[key] = meta[key] or attrs.content
      end
    elseif tag == "base" and attrs.href and not has_base then
      base, has_base = M.absolute(url, attrs.href) or url, true
    elseif tag == "title" and not title then
      local ending = node:parent():named_child(node:parent():named_child_count() - 1)
      if ending and ending:type() == "end_tag" then
        local _, _, first = node:end_()
        local _, _, last = ending:start()
        title = M.decode(html:sub(first + 1, last))
      end
    end
  end
  local result = { title = meta["og:title"] or title or url }
  for _, key in ipairs({ "og:image", "og:image:url", "twitter:image", "twitter:image:src" }) do
    if meta[key] then
      result.image = M.absolute(base, meta[key])
      if result.image then
        break
      end
    end
  end
  return result
end

return M
