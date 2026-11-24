# Site themes (wizard / space opera)

A runtime theme layer on top of Blowfish. Visitors get one dropdown in the header (half-circle icon)
with three groups: **Mode** (light / dark), **Theme** (wizard / opera) and **Layout** (full / minimal).
Choices are remembered in `localStorage`. On phones the same three groups sit at the bottom of the
hamburger menu. `?theme=opera` and `?density=minimal` force a choice for a single visit
(handy for sharing/previewing); both are then remembered.

| theme  | what it is |
|--------|------------|
| wizard | the existing look, unchanged (default) |
| opera  | dark = Andor grit + Alien Nostromo amber + Blade Runner haze; light = Dune bone/ink |

Mode and Layout work inside each theme. Blowfish's own moon/sun button is hidden on desktop
(the dropdown clicks it for you, so Blowfish's dark-mode logic is still the one doing the work).

### Layout: minimal

`html[data-density="minimal"]` shrinks hero images to thin strips (roughly a quarter to a third of their height):
the custom-layout hero boxes (Archives, Tags, Categories, Browse, Panoramic, Bike-trip), the Browse
tiles, the Blowfish post hero and the home background. Thumbnails, "Related" cards, the Panoramic
photo cards and the Categories grid are content and stay full size. The strip height is the `6.75rem`
(and `5.625rem` for posts) in the "MINIMAL layout" block of `themes.css`.

## Files

| file | purpose |
|------|---------|
| `data/themes.toml` | which themes exist, the default, the art **slots** and their fallbacks |
| `assets/css/themes.css` | all styling, under `html[data-theme="..."]`; palette, type, cards, hero, badges |
| `assets/js/theme.js` | picks theme + layout before first paint, swaps art, builds the header dropdown |
| `layouts/partials/theme-head.html` | emits config + CSS + JS (one line in `extend-head.html` calls it) |
| `layouts/partials/extend-head-uncached.html` | per-page art `<meta>` |
| `layouts/partials/theme-asset-url.html` | helper: resolves an `assets/` path to a URL |
| `layouts/partials/theme-art-path.html`, `theme-art-url.html` | helpers: find a theme's file for a slot; the layouts use `theme-art-url` for the default theme's art |
| `assets/img/<theme>/` | one folder of art per theme (`wizard/`, `opera/`), files named after the slots |
| `static/fonts/opera/` | self-hosted fonts (OFL), only fetched while opera is active |
| `config/_default/menus.en.toml` | Categories / Tags / Archives are children of an **Index** entry |

## Art: slots

Every theme keeps its images in `assets/img/<name>/`, named after a **slot**:

| slot | where it shows |
|------|----------------|
| `logo` | header logo |
| `archives`, `tags`, `categories`, `browse`, `panoramic`, `bike-trip` | hero banner of that section |
| `gazing` | hero banner of a single tag / category page |
| `tile-tags`, `tile-archives`, `tile-categories`, `tile-panoramic` | Browse page tiles (fall back to the matching hero slot) |
| `default-featured` | fallback image for posts without one |
| `hero-home` | home page background (only if the home page shows one) |

Any of png / jpg / webp / svg works (`archives.png`, `archives.svg`, ...). To replace a theme's art, overwrite the file.
A theme may leave slots out: it falls back to the slot's `[fallback]` in `data/themes.toml`, then to the default theme's art.

The layouts render the **default** theme's image with
`<img src="{{ partial "theme-art-url.html" "archives" }}" data-art-slot="archives">`; `assets/js/theme.js` swaps it for
the visitor's theme before first paint. Images Blowfish makes itself (no `data-art-slot`) are matched by a piece of their
`src` through the `[[match]]` entries in `data/themes.toml`.

## Using it

* **New hero image in a layout**: use the `<img src=... data-art-slot="...">` form above, add the slot name to `slots` in
  `data/themes.toml`, and drop `<slot>.png` into each theme's folder.
* **Per-page art**: add `featureimageopera = "img/opera/archives.png"` to front matter
  (Archives, Tags, Categories, Browse `_index.md`, or any post).
  Pages without it keep their existing image (e.g. your trip photos are never swapped).
* **Custom hero markup** that isn't Blowfish's: give the `<img>` `class="theme-art"`.
* **Add a theme** (say `noir`):
  1. put images in `assets/img/noir/` (named after the slots; any you skip fall back)
  2. in `data/themes.toml` add `"noir"` to `order` and a block `[noir]` with `label = "Noir"`
  3. copy an `html[data-theme="opera"]` block in `assets/css/themes.css` and rename it
  It then appears in the header dropdown automatically; test it with `?theme=noir`.
* **Requirements**: Hugo >= 0.156 (uses `hugo.Data`; Blowfish 2.104 already needs >= 0.158) and a browser with CSS `:has()`.
* **Mobile overflow fix** (all themes): `themes.css` pins the width of the layouts' hero boxes
  (`aspect-ratio` + `min-height` made them wider than a phone screen).
* **Revert**: delete the `{{ partial "theme-head.html" . }}` line from `extend-head.html`; to undo the
  menu change, move Categories / Tags / Archives back to top-level entries in `menus.en.toml`.
