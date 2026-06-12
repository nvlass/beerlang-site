# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Static site for [beerlang.dev](https://beerlang.dev) — the Beerlang language homepage. Built with [Cryogen](https://cryogenweb.org), a Clojure static site generator. Pages are Markdown files with EDN front-matter; templates are Selmer (Django-style) HTML.

## Commands

Both Leiningen and tools.deps are supported.

**Build static output to `public/`:**
```bash
clojure -M:build
# or
lein run
```

**Dev server with live reload (slow mode — full recompile on any change):**
```bash
clojure -X:serve
# or
lein serve
```

**Dev server with fast mode (incremental, auto-refreshes browser):**
```bash
clojure -X:fast
# or
lein serve:fast
```

The server runs on port 3000 and opens a browser tab automatically.

## Architecture

```
content/
  config.edn          ← site-wide Cryogen config (theme, URLs, RSS, etc.)
  md/pages/           ← Markdown pages (EDN front-matter + Markdown body)
  css/                ← extra CSS/SCSS (currently unused)
  img/                ← site images copied to public/

themes/lotus/         ← active theme (set in content/config.edn as :theme "nucleus" — NOTE: currently mismatched; actual rendered theme is lotus)
  html/               ← Selmer templates
    base.html         ← outer shell: sidebar, nav, social icons, footer
    main.html         ← layout for :layout :main (home page, no title header)
    page.html         ← layout for :layout :page (standard content pages)
    home.html         ← layout for :layout :home (blog post list)
    post.html / post-content.html / prev-next.html ← blog post layouts
  css/                ← SCSS source; compiled to public/css/ on build
  config.edn          ← theme-level overrides (:sass-src, :resources)

public/               ← generated output; do NOT hand-edit (regenerated on every build)

src/cryogen/
  core.clj            ← `-main`: load plugins, compile, exit
  server.clj          ← dev server, file watcher, URL routing for clean URLs
```

## Page front-matter

Each `.md` file in `content/md/pages/` starts with an EDN map:

```clojure
{:title "Page Title"
 :layout :page          ; :main (home), :page (content), :home (post list)
 :page-index 1          ; controls sidebar nav ordering
 :navbar? true}         ; whether to appear in the sidebar nav
```

The home page (`index.md`) uses `:layout :main` and `:home? true`.

## Theme templating

Templates use [Selmer](https://github.com/yogthos/Selmer) (Django/Jinja2-like). Key variables available in all templates: `title`, `description`, `blog-prefix`, `index-uri`, `archives-uri`, `tags-uri`, `rss-uri`, `navbar-pages`, `author`, `today`.

- `{% extends "/html/base.html" %}` — inherit base layout
- `{% block content %}` — override the main content area
- `{% include "/html/fragment.html" %}` — include a partial
- `{% style "css/file.css" %}` / `{% script "js/file.js" %}` — asset helpers that prepend `blog-prefix`

## Active theme vs config

`content/config.edn` currently has `:theme "nucleus"` but the site uses the `lotus` theme. When changing the theme or adding SCSS, update `:theme` in `content/config.edn` to match the directory name under `themes/`.

The lotus theme compiles SCSS from `themes/lotus/css/` (controlled by `:sass-src ["css"]` in `themes/lotus/config.edn`). The sass binary must be on `$PATH` for SCSS compilation; plain CSS files are copied as-is without it.
