# Frutiger

A Deepwoken client. Previously released as Project Rain, then rebuilt through an
intermediate rename; the tree, the build tooling and the single-file bundle are
all here.

## run it

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/beyondthetowers/project-rain/main/dist/frutiger.lua"))()
```

`dist/frutiger.lua` is a single self-contained chunk: it flattens the module
tree, installs a resolver for `@src/...` requires, inlines the assets, and does
not touch the filesystem except for the config folder.

`dist/loader.lua` is a thin fetcher for the same bundle -- it pulls the file and
runs it, and checks the raw URL actually returned Lua rather than a GitHub 404
page.

## layout

```
src/                    module tree
  init.lua              entry point
  luarmor_init_script   build-time primitives + legacy folder migration
  features/             movement, combat, visuals, exploits, removals, qol
  automation/           persistent farm tasks
  security/             anti-cheat layer
  utility/              UI library, deepwoken helpers, managers
  ui/                   tabs and components
assets/                 fonts, sounds, morph model, planner data
tools/
  bundle.js             flattens src/ into dist/
  gen-registry.js       regenerates src/features/loader.lua from the tree
  rebrand.js            rename tooling (dry-run by default)
  lua-guard.js          refuses a build containing a JS-style comment in Lua
dist/                   generated -- do not edit by hand
repro.lua               standalone detection-bisect harness
```

## building

```bash
node tools/gen-registry.js                              # after adding/removing feature modules
node tools/bundle.js                                    # -> dist/frutiger.lua
node tools/bundle.js --no-assets --out=dist/frutiger-lite.lua   # smaller, no embedded assets
```

`--out=` is what decides the filename; `--no-assets` only controls whether the
20 bundled assets are inlined.

`tools/gen-registry.js` rewrites `src/features/loader.lua` from scratch. If you
hand-edit that file, don't re-run the generator without stashing your changes.

`tools/bundle.js` refuses to emit if any module contains a `//` comment -- Lua
has none, and an invalid chunk fails silently under `pcall`. It also reports any
`@src/...` or `@assets/...` reference it cannot resolve; a missing asset shows up
there.

## upstream

This began as an open-source release of Project Rain. Large parts of the
original were stripped before publication -- the security layer, the feature
registry, several modules and scattered logic. Those have been reconstructed
here where possible; `git log` describes what was rebuilt and why.
