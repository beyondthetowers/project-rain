// tools/lua-guard.js
//
// Refuses the build if any Lua module contains a JavaScript-style comment.
//
// This is not hypothetical. A node one-liner of mine inserted
//
//     local EDGE = Color3.fromRGB(255, 255, 255);   // soft white edge
//
// into chrome.lua while rebranding. "//" is not a Lua comment, so the bundle
// failed to PARSE. Every probe wraps loadstring in pcall, so the failure was
// silent: the client kept running the PREVIOUS injection, and four separate
// measurements came back byte-identical before anyone spotted it.
//
// A parse failure costs everything and reports nothing, so it gets a dedicated
// check rather than trusting review.
//
//   require("./lua-guard.js").check();   // throws on a hit

const fs = require("fs");
const path = require("path");

function walk(dir, extension, out) {
    out = out || [];
    if (!fs.existsSync(dir)) return out;

    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (entry.name === ".git") continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            walk(full, extension, out);
        } else if (full.endsWith(extension)) {
            out.push(full);
        }
    }
    return out;
}

// Is this line carrying a JS-style comment? String literals are blanked first so
// a "//" inside a string, or a URL, is not mistaken for one.
function hasJsComment(line) {
    // Order matters. Blank string literals, drop Lua's OWN comment, neutralise
    // URLs, and then a plain substring test is both correct and easy to reason
    // about. Two earlier versions proved the point:
    //
    //   - testing BEFORE stripping Lua's comment flagged `--//foo = 1`, which is
    //     legal Lua (a commented-out line that itself began with //)
    //   - requiring a non-space after the slashes then missed the real case,
    //     because a JS comment is always followed by a space: `x = 1; // note`
    const code = line
        .replace(/"[^"]*"/g, '""')
        .replace(/'[^']*'/g, "''")
        .replace(/--.*$/, "")
        .replace(/https?:\/\//g, "URL");

    return code.includes("//");
}

function check(root) {
    const dir = path.join(root || process.cwd(), "src");
    const problems = [];

    for (const file of walk(dir, ".lua")) {
        const lines = fs.readFileSync(file, "utf8").split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            if (hasJsComment(lines[i])) {
                problems.push({
                    file: path.relative(root || process.cwd(), file),
                    line: i + 1,
                    text: lines[i].trim(),
                });
            }
        }
    }

    if (problems.length > 0) {
        console.error("");
        console.error("REFUSING TO BUILD -- Lua has no // comment, but found:");
        for (const p of problems) {
            console.error("  " + p.file + ":" + p.line);
            console.error("    " + p.text);
        }
        console.error("");
        console.error("Use -- for a Lua comment.");
        console.error("");
        process.exit(1);
    }

    return true;
}

module.exports = { check, hasJsComment };

// allow `node tools/lua-guard.js` as a standalone check
if (require.main === module) {
    check(process.cwd());
    console.log("lua-guard: no javascript comments found in src/**/*.lua");
}
