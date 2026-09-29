# DECAY

A Deepwoken client. Previously released as Project Rain; renamed and rebuilt.

Nothing about the original release is required to run this — the module tree,
the build tooling and the single-file bundle are all in here.

## run it

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/<repo>/main/dist/decay.lua"))()
```

`dist/decay.lua` is a single self-contained chunk: it flattens the module tree,
installs a resolver for `@src/...` requires, inlines the assets, and does not
touch the filesystem except for the config folder.

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
dist/                   generated — do not edit by hand
repro.lua               standalone detection-bisect harness
```

## building

```bash
node tools/gen-registry.js                 # after adding/removing feature modules
node tools/bundle.js                       # -> dist/decay.lua
node tools/bundle.js --no-assets           # -> dist/decay-lite.lua, much smaller
```

`tools/gen-registry.js` rewrites `src/features/loader.lua` from scratch. If you
hand-edit that file, don't re-run the generator without stashing your changes.

## upstream

This began as an open-source release of Project Rain. Large parts of the
original were stripped before publication — the security layer, the feature
registry, several modules and scattered logic. Those have been reconstructed
here where possible; `git log` describes what was rebuilt and why.
