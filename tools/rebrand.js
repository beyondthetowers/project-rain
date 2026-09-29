// tools/rebrand.js
//
// Renames Project Rain -> DECAY across the tree.
//
//   node tools/rebrand.js                       # dry run, prints the diff plan
//   node tools/rebrand.js --apply               # write it
//   node tools/rebrand.js --apply --internals   # also rename the aztup globals
//
// Deliberately NOT a blind global replace. The on-disk folder is a plain
// substring swap (it appears in 126 places, all inside string literals), but
// the title/watermark are format strings whose argument arity has to change
// with them, so those are anchored full-expression replacements.

const fs = require("fs");
const path = require("path");

const ROOT = "C:/Deepwoken cheat/project-rain-oss-master";

const argv = process.argv.slice(2);
const APPLY = argv.includes("--apply");
const INTERNALS = argv.includes("--internals");

const NAME = "DECAY";
const FOLDER = "Console";
const DOMAIN = "decay";

// ── replacement plan ───────────────────────────────────────────────────────
// order matters: the folder swap runs first so later anchors that contain it
// still match.

const replacements = [];

// 1. the on-disk folder. covers "Project Rain/...", "Project Rain\\...", the
//    bare folder name, and the string embedded inside queueonteleport blobs.
replacements.push({
    id: "folder",
    from: "Project Rain",
    to: FOLDER,
});

// 2. window title. source is:
//      string.format(LPH_ENCSTR("pr <font color=\"#%s\">nextgen</font>"), Library.AccentColor:ToHex())
//    one %s. the new title carries a user id, so the call grows an argument.
replacements.push({
    id: "title",
    from: 'string.format(LPH_ENCSTR("pr <font color=\\"#%s\\">nextgen</font>"), Library.AccentColor:ToHex())',
    to: `string.format(LPH_ENCSTR("${NAME} <font color=\\"#%s\\">// USER_%03d</font>"), Library.AccentColor:ToHex(), math.random(1, 999))`,
});

// 3. watermark, rich and raw. five format args, arity preserved.
replacements.push({
    id: "watermark-rich",
    from: "'project rain <font color=\"#%s\">nextgen</font> %i<font color=\"#%s\">fps</font> %i<font color=\"#%s\">ms</font>'",
    to: `'${NAME} // <font color="#%s">DECOMPOSING</font> %i<font color="#%s">fps</font> %i<font color="#%s">ms</font>'`,
});
replacements.push({
    id: "watermark-raw",
    from: '"project rain nextgen"',
    to: `"${NAME} // DECOMPOSING"`,
});

// 4. the credits string. returned by the HOOKED KeyHandler module, so the game
//    can read it out of memory. replace with a status line that says nothing.
replacements.push({
    id: "credits",
    from: 'made with <3 from uni, hon, temped, soggy!!!',
    to: 'STATUS: DECOMPOSING // 0x1F',
});

// 5. dead vendor host.
replacements.push({
    id: "domain",
    from: "project-rain.net",
    to: DOMAIN,
});

// 6. brand-prefixed identifiers. explicit list — a blanket /PR/ pass would eat
//    PROTOCOL and PREVIEW_PANEL_*.
for (const [from, to] of [
    ["PRWindow", "ConsoleWindow"],
    ["PR_registry", "CONSOLE_registry"],
    ["PR_BREAKER_IGNORE", "CONSOLE_BREAKER_IGNORE"],
    ["PR_DEBUG", "CONSOLE_DEBUG"],
    ["PR_ATTRIBUTION", "CONSOLE_ATTRIBUTION"],
    ["PR_PLAYER_CONTAINER", "CONSOLE_PLAYER_CONTAINER"],
    ["PRLegacyConvert", "DecayLegacyConvert"],
    ["PR_key_handler", "DECAY_key_handler"],
]) {
    replacements.push({ id: "id:" + from, from, to });
}

if (INTERNALS) {
    // ~1000 refs. cosmetic only — pure renaming, zero behaviour change.
    for (const [from, to] of [
        ["aztup_toggles", "decay_toggles"],
        ["aztup_options", "decay_options"],
        ["aztup", "decay"],
    ]) {
        replacements.push({ id: "internal:" + from, from, to, wordBoundary: true });
    }
}

// ── collect targets ────────────────────────────────────────────────────────
function walk(dir, out = []) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        if (e.name === ".git") continue;
        const full = path.join(dir, e.name);
        if (e.isDirectory()) walk(full, out);
        else out.push(full);
    }
    return out;
}

const targets = walk(path.join(ROOT, "src"))
    .filter((f) => f.endsWith(".lua"))
    .concat(walk(path.join(ROOT, "tools")).filter((f) => f.endsWith(".js") && !f.endsWith("rebrand.js")));

// ── apply ──────────────────────────────────────────────────────────────────
const totals = new Map();
const touched = new Set();
const writes = [];

for (const file of targets) {
    let src = fs.readFileSync(file, "utf8");
    const original = src;

    for (const r of replacements) {
        let next;
        if (r.wordBoundary) {
            next = src.replace(new RegExp("\\b" + r.from + "\\b", "g"), r.to);
        } else {
            next = src.split(r.from).join(r.to);
        }
        const hits = (src.length - next.length) === 0 && src === next ? 0 : undefined;
        if (next !== src) {
            // count occurrences of the source form in the pre-replacement text
            const count = r.wordBoundary
                ? (src.match(new RegExp("\\b" + r.from + "\\b", "g")) || []).length
                : src.split(r.from).length - 1;
            totals.set(r.id, (totals.get(r.id) || 0) + count);
            touched.add(file);
            src = next;
        }
    }

    if (src !== original) writes.push({ file, src });
}

console.log(`${APPLY ? "APPLYING" : "DRY RUN"} — Project Rain -> ${NAME} (folder "${FOLDER}")\n`);
console.log("replacement                        hits");
console.log("---------------------------------- ------");
for (const [id, n] of [...totals].sort((a, b) => b[1] - a[1])) {
    console.log(id.padEnd(34) + " " + n);
}
console.log("---------------------------------- ------");
console.log("files touched".padEnd(34) + " " + touched.size);

if (!APPLY) {
    console.log("\nnothing written. re-run with --apply");
} else {
    for (const { file, src } of writes) fs.writeFileSync(file, src);
    console.log("\nwritten.");
}

if (totals.get("domain")) {
    console.log(`\nNOTE: the vendored host became "${DOMAIN}" — that host does not exist.`);
    console.log("      src/init.lua fetches https://files." + DOMAIN + "/configs/premade.json on first run;");
    console.log("      it is pcall'd so it degrades to no default config. point it at your own or drop it.");
}
if (!INTERNALS) {
    console.log("\nNOTE: aztup / aztup_toggles / aztup_options left alone (--internals to rename).");
}
