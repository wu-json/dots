# link-preview.nvim

Markdown link previews using Snacks images, Open Graph metadata, and YouTube thumbnails.

Requires Neovim 0.10+, curl, Snacks with image support, and the HTML, Markdown,
and Markdown-inline Tree-sitter parsers. Image display also requires ImageMagick
and a terminal supported by Snacks.

Add this directory to Neovim's runtime path, then call:

```lua
require("link-preview").setup({ delay = 200, max_width = 40, max_height = 12 })
```

For YouTube image embeds, set Snacks' `image.resolve` option to
`require("link-preview").resolve_image`. Other image URLs return `nil` so Snacks
can resolve them normally.

Options also include `filetypes`, `ttl`, `failure_ttl`, `max_entries`, and
`cache_dir`. Defaults are Markdown/MDX, 3600 seconds, 60 seconds, 128 entries,
and a per-user temp directory. Previewing a link fetches its page and image.

Run offline tests from this directory:

```sh
nvim --headless -u NONE -l tests/run.lua
nvim --headless -u NONE -l tests/retry.lua
```

The tests require the Tree-sitter parsers above. The retry test uses the installed
Snacks image cache class from `stdpath("data")/lazy/snacks.nvim`; set
`SNACKS_TEST_DIR` to use another checkout. Rendering and image conversion are stubbed; check actual
image display in a supported terminal. This directory can be moved into its own
repository; the dots integration only supplies the local plugin path and options.

CI runs this suite on pull requests and pushes to `main` when plugin code/tests,
the Markdown configuration, the Neovim lockfile, or the CI workflow/setup script change.
It uses one Linux job with pinned Neovim and parser versions, the lockfile’s Snacks
revision, and cancels superseded
runs. Documentation-only changes do not trigger it.
