local metadata = require("link-preview.metadata")
local data = metadata.parse(
  [[
  <title>Fallback &amp; title</title>
  <META CONTENT="A &amp; B" PROPERTY="og:title">
  <meta name='twitter:image' content='https://example.org/fallback.jpg'>
  <meta content='../cover.jpg?a=1&amp;b=2' property='og:image'>
]],
  "https://note.com/writer/n/article"
)
assert(data.title == "A & B")
assert(data.image == "https://note.com/writer/cover.jpg?a=1&b=2")
data = metadata.parse(
  [[
  <!-- <meta property="og:image" content="bad.jpg"> -->
  <script>const fake = '<meta property="og:image" content="bad.jpg">';</script>
  <base href="https://cdn.example.org/assets/">
  <meta property="og:image" content="file:///etc/passwd">
  <meta name="twitter:image" content="cover.jpg">
]],
  "https://example.org"
)
assert(data.image == "https://cdn.example.org/assets/cover.jpg")
assert(metadata.parse("<title>A &amp; B</title>", "https://example.org").title == "A & B")
data = metadata.parse(
  '<html><head><title>Head only</title></head><body><meta property="og:image" content="body.jpg"></body></html>',
  "https://example.org"
)
assert(data.title == "Head only" and data.image == nil, "metadata parsing must stop at the end of the head")
for _, literal in ipairs({
  [[<script>const closing = "</head>";</script>]],
  [[<!-- </head><meta property="og:image" content="bad.jpg"> -->]],
  [[<style>body::after { content: "</head>"; }</style>]],
  [[<meta name="description" content="The </head> tag">]],
}) do
  data = metadata.parse(
    "<html><head>"
      .. literal
      .. '<title>Actual title</title><meta property="og:image" content="/cover.jpg">'
      .. '</HEAD><body><meta property="twitter:image" content="/body.jpg"></body></html>',
    "https://example.org"
  )
  assert(data.title == "Actual title", "literal closing head tag hid the title: " .. literal)
  assert(data.image == "https://example.org/cover.jpg", "literal closing head tag hid the image: " .. literal)
end
assert(metadata.decode("&#65;&#x42;&quot;") == 'AB"')
assert(
  metadata.absolute("https://example.org/a/page", "//cdn.example.org/image.jpg") == "https://cdn.example.org/image.jpg"
)
for _, url in ipairs({
  "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30",
  "https://youtu.be/dQw4w9WgXcQ?si=abc",
  "https://m.youtube.com/shorts/dQw4w9WgXcQ",
  "https://youtube.com/live/dQw4w9WgXcQ",
  "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
}) do
  assert(metadata.youtube(url) == "https://i.ytimg.com/vi/dQw4w9WgXcQ/mqdefault.jpg", url)
end
assert(metadata.youtube("https://youtube.com.evil.org/watch?v=dQw4w9WgXcQ") == nil)
assert(metadata.youtube("https://youtube.com/watch?v=bad") == nil)

local base = "https://example.org/articles/page?lang=en#intro"
for _, case in ipairs({
  { "cover.jpg", "https://example.org/articles/cover.jpg" },
  { "../cover.jpg", "https://example.org/cover.jpg" },
  { "../../../../cover.jpg", "https://example.org/cover.jpg" },
  { "/img/a%20b.jpg?size=2#image", "https://example.org/img/a%20b.jpg?size=2#image" },
  { "./assets/../cover.jpg", "https://example.org/articles/cover.jpg" },
  { "images//cover.jpg", "https://example.org/articles/images//cover.jpg" },
  { "images//../cover.jpg", "https://example.org/articles/images/cover.jpg" },
  { "images//./cover.jpg", "https://example.org/articles/images//cover.jpg" },
  { "images//", "https://example.org/articles/images//" },
  { "images/.", "https://example.org/articles/images/" },
  { "images/..", "https://example.org/articles/" },
  { "?size=2", "https://example.org/articles/page?size=2" },
  { "#image", "https://example.org/articles/page?lang=en#image" },
  { "", "https://example.org/articles/page?lang=en" },
  { "data:image/png;base64,AAAA", false },
  { "javascript:alert(1)", false },
  { "file:///tmp/image.jpg", false },
}) do
  local actual = metadata.absolute(base, case[1])
  assert(actual == (case[2] or nil), case[1] .. ": " .. tostring(actual))
end
for _, case in ipairs({
  { "&amp;quot;", "&quot;" },
  { "&#x1F363;", "🍣" },
  { "&#xD800; &#1114112;", "&#xD800; &#1114112;" },
  { "&unknown;", "&unknown;" },
}) do
  assert(metadata.decode(case[1]) == case[2], case[1])
end
for _, case in ipairs({
  { "<meta property=og:image content=/cover.jpg>", "https://example.org/cover.jpg" },
  {
    '<meta property="og:image" content="/cdn-cgi/image/width=1200/https://images.example.org/cover.jpg">',
    "https://example.org/cdn-cgi/image/width=1200/https://images.example.org/cover.jpg",
  },
  {
    '<meta property="og:image" content=""><meta name="twitter:image" content="/fallback.jpg"/>',
    "https://example.org/fallback.jpg",
  },
  {
    '<meta property="og:image" content="   "><meta name="twitter:image" content="/fallback.jpg">',
    "https://example.org/fallback.jpg",
  },
  {
    '<meta property="og:image" content="/first.jpg"><meta property="og:image" content="/second.jpg">',
    "https://example.org/first.jpg",
  },
  {
    '<base href="/assets/"><base href="/ignored/"><meta property="og:image" content="cover.jpg">',
    "https://example.org/assets/cover.jpg",
  },
  {
    '<meta property="og:image" content="/cover.jpg?literal=&amp;amp;">',
    "https://example.org/cover.jpg?literal=&amp;",
  },
  { "<html><head><title>No image</title></head><body>Text</body></html>", false },
}) do
  local actual = metadata.parse(case[1], "https://example.org/page").image
  assert(actual == (case[2] or nil), case[1] .. ": " .. tostring(actual))
end
for _, url in ipairs({
  "https://youtube.com/watch?other=1#v=dQw4w9WgXcQ",
  "https://youtube.com/watch?other=1#section&v=dQw4w9WgXcQ",
  "https://youtube.com@evil.org/watch?v=dQw4w9WgXcQ",
  "https://youtube.com/playlist?list=dQw4w9WgXcQ",
  "file://youtube.com/watch?v=dQw4w9WgXcQ",
}) do
  assert(metadata.youtube(url) == nil, url)
end
