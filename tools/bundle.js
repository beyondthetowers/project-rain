// tools/bundle.js
//
// Flattens the Project Rain module tree into one self-contained Lua chunk that
// can be run through loadstring / game:HttpGet.
//
// What it does:
//   - walks every .lua and .json under src/
//   - emits each as a factory in a __modules table
//   - installs a require() shim that resolves "@src/..." out of that table and
//     delegates everything else to the executor's real require
//   - replaces list_modules() with static lists computed from the tree
//   - pre-encodes assets/ as base64(zstd(bytes)) so inline_asset_b96 works with
//     no disk access
//   - runs @src/init
//
// Usage:
//   node tools/bundle.js                 -> dist/project-rain.lua
//   node tools/bundle.js --no-assets     -> skip asset embedding (much smaller)
//   node tools/bundle.js --out=path.lua

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const ROOT = "C:/Deepwoken cheat/project-rain-oss-master";
const SRC = path.join(ROOT, "src");
const ASSETS = path.join(ROOT, "assets");

const argv = process.argv.slice(2);
const EMBED_ASSETS = !argv.includes("--no-assets");
const OUT = (() => {
    const flag = argv.find((a) => a.startsWith("--out="));
    return flag ? flag.slice(6) : path.join(ROOT, "dist", "project-rain.lua");
})();

// ── helpers ────────────────────────────────────────────────────────────────

function walk(dir, out = []) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            walk(full, out);
        } else {
            out.push(full);
        }
    }
    return out;
}

function rel(p) {
    return path.relative(ROOT, p).split(path.sep).join("/");
}

function luaLongString(text) {
    // Pick a bracket level that cannot appear inside the payload.
    let level = 0;
    for (;;) {
        const close = "]" + "=".repeat(level) + "]";
        if (!text.includes(close) && !text.includes("[" + "=".repeat(level) + "[")) {
            break;
        }
        level += 1;
        if (level > 10) throw new Error("could not find a safe long-string level");
    }
    const eq = "=".repeat(level);
    return "[" + eq + "[" + text + "]" + eq + "]";
}

function luaString(text) {
    return JSON.stringify(text);
}

// ── module collection ──────────────────────────────────────────────────────

const allFiles = walk(SRC).filter((f) => f.endsWith(".lua") || f.endsWith(".json"));

const modules = [];        // { id, kind, file }
const moduleIds = new Set();

for (const file of allFiles) {
    const id = rel(file).replace(/\.(lua|json)$/, "");
    const kind = file.endsWith(".json") ? "json" : "lua";
    if (moduleIds.has(id)) continue;
    moduleIds.add(id);
    modules.push({ id, kind, file });
}

modules.sort((a, b) => a.id.localeCompare(b.id));

// ── globs ──────────────────────────────────────────────────────────────────

const globPatterns = ["automation/persistent_tasks/*", "features/auto-parry/data/effects/*",
                      "features/auto-parry/fallbacks/objects/*", "ui/tabs/*"];

const globTables = globPatterns.map((pattern) => {
    const dir = pattern.slice(0, pattern.lastIndexOf("/"));
    const prefix = "src/" + dir + "/";
    const matches = modules
        .filter((m) => m.id.startsWith(prefix) && !m.id.slice(prefix.length).includes("/"))
        .map((m) => "@" + m.id);
    return { pattern, matches };
});

// ── assets ─────────────────────────────────────────────────────────────────

const assets = [];
if (EMBED_ASSETS && fs.existsSync(ASSETS)) {
    for (const file of walk(ASSETS)) {
        const key = "@assets/" + rel(file).slice("assets/".length);
        const raw = fs.readFileSync(file);
        const compressed = zlib.zstdCompressSync(raw);
        assets.push({ key, b64: compressed.toString("base64") });
    }
    assets.sort((a, b) => a.key.localeCompare(b.key));
}

// ── emit ───────────────────────────────────────────────────────────────────

const chunks = [];

chunks.push(`--[[
    Project Rain — bundled build
    generated ${new Date().toISOString()}
    modules: ${modules.length}
    assets:  ${assets.length}
]]`);
chunks.push("");

// module factories
chunks.push("local __modules = {};");
chunks.push("local __cache = {};");
chunks.push("local __loaded = {};");
chunks.push("local __loading = {};");
chunks.push("local __real_require = require;");
chunks.push("");

for (const mod of modules) {
    const source = fs.readFileSync(mod.file, "utf8");
    chunks.push(`__modules[${luaString(mod.id)}] = function()`);
    if (mod.kind === "json") {
        chunks.push(`    return game:GetService("HttpService"):JSONDecode(${luaLongString(source)});`);
    } else {
        chunks.push(source.endsWith("\n") ? source : source + "\n");
    }
    chunks.push("end;");
    chunks.push("");
}

// module resolver
chunks.push(`local function __resolve(target)
    local key = target:gsub("^@", "");
    if __modules[key] then return key end;
    if __modules[key .. ".lua"] then return key .. ".lua" end;
    if __modules[key .. ".json"] then return key .. ".json" end;
    return nil;
end;

local function __require(target)
    if type(target) == "string" then
        local key = __resolve(target);
        if key then
            if __loaded[key] then return __cache[key] end;
            if __loading[key] then
                -- circular require: hand back whatever is cached so far
                return __cache[key];
            end;

            __loading[key] = true;
            local ok, result = pcall(__modules[key]);
            __loading[key] = nil;

            if not ok then
                error(string.format("[bundle] module %s failed: %s", key, tostring(result)), 0);
            end;

            __cache[key] = result;
            __loaded[key] = true;
            return result;
        end;
    end;

    return __real_require(target);
end;

require = __require;`);

// list_modules
chunks.push("");
chunks.push("local __module_lists = {");
for (const { pattern, matches } of globTables) {
    chunks.push(`    [${luaString(pattern)}] = {`);
    for (const m of matches) chunks.push(`        ${luaString(m)},`);
    chunks.push("    },");
}
chunks.push("};");
chunks.push("");
chunks.push(`list_modules = function(pattern)
    return __module_lists[pattern] or {};
end;`);

// assets
chunks.push("");
if (assets.length) {
    chunks.push("getgenv().__BUNDLED_ASSETS = {");
    for (const { key, b64 } of assets) {
        chunks.push(`    [${luaString(key)}] = ${luaString(b64)},`);
    }
    chunks.push("};");
} else {
    chunks.push("getgenv().__BUNDLED_ASSETS = getgenv().__BUNDLED_ASSETS or {};");
}

// run
chunks.push("");
chunks.push(`local __ok, __err = xpcall(__require, function(e)
    return tostring(e) .. "\\n" .. debug.traceback();
end, "@src/init");

if not __ok then
    warn("[bundle] init failed: " .. tostring(__err));
end;

return __ok;`);

const output = chunks.join("\n");

if (!fs.existsSync(path.dirname(OUT))) {
    fs.mkdirSync(path.dirname(OUT), { recursive: true });
}
fs.writeFileSync(OUT, output);

// ── verify every require() call site has a module ──────────────────────────

const referenced = new Set();
const refRe = /"@(src|assets)\/([^"]+)"/g;
for (const mod of modules) {
    if (mod.kind !== "lua") continue;
    const source = fs.readFileSync(mod.file, "utf8");
    let m;
    while ((m = refRe.exec(source)) !== null) {
        referenced.add(m[1] + "/" + m[2]);
    }
}

const missing = [];
for (const ref of referenced) {
    if (ref.startsWith("assets/")) {
        if (EMBED_ASSETS && !assets.some((a) => a.key === "@" + ref)) missing.push("@" + ref);
        continue;
    }
    if (!moduleIds.has(ref)) missing.push("@" + ref);
}

console.log(`modules:  ${modules.length}`);
console.log(`assets:   ${assets.length}${EMBED_ASSETS ? "" : " (disabled)"}`);
console.log(`globs:    ${globTables.map((g) => g.pattern + "=" + g.matches.length).join(", ")}`);
console.log(`out:      ${OUT}  ${(output.length / 1024 / 1024).toFixed(2)} MB`);
if (missing.length) {
    console.log(`\nUNRESOLVED REFERENCES (${missing.length}):`);
    for (const m of missing) console.log("  " + m);
} else {
    console.log("all references resolved");
}
