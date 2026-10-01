// tools/gen-textures.js
//
// Generates the FRUTIGER overlay textures as PNGs into assets/Textures/.
// Pure node — zlib for the deflate stream, hand-rolled CRC32 and chunk writer.
//
//   node tools/gen-textures.js
//
// Output is deterministic (fixed seeds) so rebuilds don't churn the repo.
//
// The set is built for Frutiger Aero: glass sheen, bubbles, a soft highlight
// band. The previous grain / scanline / scratch / vignette set belonged to a
// grunge theme and reads as damage rather than gloss on a light surface — the
// scanlines especially, which are the opposite of the aesthetic.
//
// These get picked up by tools/bundle.js like any other asset, inlined as
// base64(zstd(bytes)), written to Frutiger/Textures/ at runtime and loaded with
// getcustomasset. See src/utility/frutiger/theme.lua.

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = "C:/Deepwoken cheat/project-rain-oss-master/assets/Textures";

// ── deterministic rng ──────────────────────────────────────────────────────
function mulberry32(seed) {
    return function () {
        seed |= 0;
        seed = (seed + 0x6d2b79f5) | 0;
        let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// ── png ────────────────────────────────────────────────────────────────────
const CRC_TABLE = (() => {
    const table = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        table[n] = c;
    }
    return table;
})();

function crc32(buf) {
    let c = -1;
    for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
    return (c ^ -1) >>> 0;
}

function chunk(type, data) {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length, 0);
    const typeBuf = Buffer.from(type, "ascii");
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
    return Buffer.concat([length, typeBuf, data, crc]);
}

function encodePNG(width, height, pixels) {
    const stride = width * 4;
    const raw = Buffer.alloc((stride + 1) * height);
    for (let y = 0; y < height; y++) {
        raw[y * (stride + 1)] = 0;
        Buffer.from(pixels.buffer, pixels.byteOffset + y * stride, stride).copy(raw, y * (stride + 1) + 1);
    }

    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(width, 0);
    ihdr.writeUInt32BE(height, 4);
    ihdr[8] = 8;
    ihdr[9] = 6;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;

    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        chunk("IHDR", ihdr),
        chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
        chunk("IEND", Buffer.alloc(0)),
    ]);
}

function blank(w, h) {
    return new Uint8Array(w * h * 4);
}

// source-over, so overlapping bubbles composite the way they should
function blend(px, w, x, y, r, g, b, a) {
    if (a <= 0) return;
    const i = (y * w + x) * 4;
    const dstA = px[i + 3] / 255;
    const srcA = Math.min(a, 255) / 255;
    const outA = srcA + dstA * (1 - srcA);
    if (outA <= 0) return;
    px[i] = Math.round((r * srcA + px[i] * dstA * (1 - srcA)) / outA);
    px[i + 1] = Math.round((g * srcA + px[i + 1] * dstA * (1 - srcA)) / outA);
    px[i + 2] = Math.round((b * srcA + px[i + 2] * dstA * (1 - srcA)) / outA);
    px[i + 3] = Math.round(outA * 255);
}

// ── textures ───────────────────────────────────────────────────────────────

// Glass sheen. A bright band across the top, fading out by ~40%, plus a faint
// secondary highlight lower down. This is the single most "Aero" element -- it
// is what makes a flat fill read as a curved glass panel. Stretched, not tiled.
function gloss() {
    const w = 8, h = 128;
    const px = blank(w, h);
    for (let y = 0; y < h; y++) {
        const t = y / (h - 1);
        let a = Math.pow(1 - Math.min(t / 0.40, 1), 1.6) * 150;
        a += Math.pow(1 - Math.min(Math.abs(t - 0.62) / 0.16, 1), 2) * 26;
        for (let x = 0; x < w; x++) {
            blend(px, w, x, y, 255, 255, 255, a);
        }
    }
    return encodePNG(w, h, px);
}

// Bubbles. A soft translucent disc, a brighter rim, and a specular dot up and
// to the left -- the stock Frutiger bubble.
function bubbles() {
    const w = 256, h = 256;
    const px = blank(w, h);
    const rnd = mulberry32(0xb0bb1e);

    for (let i = 0; i < 24; i++) {
        const cx = rnd() * w;
        const cy = rnd() * h;
        const radius = 6 + rnd() * 26;
        const tinted = rnd() > 0.75;

        const x0 = Math.max(0, Math.floor(cx - radius - 2));
        const x1 = Math.min(w - 1, Math.ceil(cx + radius + 2));
        const y0 = Math.max(0, Math.floor(cy - radius - 2));
        const y1 = Math.min(h - 1, Math.ceil(cy + radius + 2));

        for (let y = y0; y <= y1; y++) {
            for (let x = x0; x <= x1; x++) {
                const dx = x - cx, dy = y - cy;
                const d = Math.sqrt(dx * dx + dy * dy) / radius;
                if (d > 1.15) continue;

                if (d < 1) {
                    const body = (1 - d) * (1 - d) * 40;
                    blend(px, w, x, y, tinted ? 150 : 255, tinted ? 225 : 255, 255, body);
                }

                const rim = Math.pow(1 - Math.min(Math.abs(d - 0.93) / 0.11, 1), 2) * 105;
                blend(px, w, x, y, 255, 255, 255, rim);
            }
        }

        const hx = cx - radius * 0.35, hy = cy - radius * 0.38, hr = radius * 0.22;
        for (let y = Math.floor(hy - hr); y <= Math.ceil(hy + hr); y++) {
            for (let x = Math.floor(hx - hr); x <= Math.ceil(hx + hr); x++) {
                if (x < 0 || y < 0 || x >= w || y >= h) continue;
                const dx = x - hx, dy = y - hy;
                const d = Math.sqrt(dx * dx + dy * dy) / hr;
                if (d > 1) continue;
                blend(px, w, x, y, 255, 255, 255, (1 - d) * (1 - d) * 170);
            }
        }
    }
    return encodePNG(w, h, px);
}

// Sweep band: a soft, slightly tilted highlight that is transparent at both
// ends. Drawn moving down the panel for the slow shine pass.
function sheen() {
    const w = 256, h = 96;
    const px = blank(w, h);
    for (let y = 0; y < h; y++) {
        const t = y / (h - 1);
        const band = Math.pow(1 - Math.min(Math.abs(t - 0.5) / 0.5, 1), 2.2) * 120;
        for (let x = 0; x < w; x++) {
            const skew = (x / w - 0.5) * 0.30;
            const a = Math.max(0, band * (1 - Math.abs(skew) * 2.2));
            blend(px, w, x, y, 255, 255, 255, a);
        }
    }
    return encodePNG(w, h, px);
}

// Frost: very fine, very faint white speckle. This is what sells frosted glass
// -- a surface with nothing on it reads as flat transparency, and a little
// diffusion makes it read as a pane. Kept at single-digit alpha on purpose: the
// grunge theme used grain at 4-5x this strength and it read as dirt.
function frost() {
    const w = 128, h = 128;
    const px = blank(w, h);
    const rnd = mulberry32(0xf0057);
    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const v = rnd();
            // clustered faint speckle, cool-tinted rather than neutral grey
            const a = v > 0.55 ? (v - 0.55) * 34 : 0;
            if (a <= 0) continue;
            blend(px, w, x, y, 226, 244, 255, a);
        }
    }
    return encodePNG(w, h, px);
}

// Orb: a round radial white gradient, bright centre fading to nothing at the
// rim. The single most useful primitive for this style -- it serves as the
// specular highlight on toggles and slider knobs, a soft glow behind the
// selected sidebar tab, and the faint white blobs that make glass read as
// liquid rather than flat.
function orb() {
    const w = 128, h = 128;
    const px = blank(w, h);
    const cx = (w - 1) / 2, cy = (h - 1) / 2;
    const radius = w / 2;
    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const dx = x - cx, dy = y - cy;
            const d = Math.sqrt(dx * dx + dy * dy) / radius;
            if (d > 1) continue;
            // soft falloff, not linear -- a linear ramp reads as a flat disc
            const a = Math.pow(1 - d, 2.4) * 255;
            blend(px, w, x, y, 255, 255, 255, a);
        }
    }
    return encodePNG(w, h, px);
}

// ── write ──────────────────────────────────────────────────────────────────
const textures = { gloss, bubbles, sheen, frost, orb };

if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

// remove the previous grunge set so nothing stale gets inlined
for (const stale of ["grain", "scanline", "scratch", "vignette", "stain"]) {
    const file = path.join(OUT, stale + ".png");
    if (fs.existsSync(file)) {
        fs.unlinkSync(file);
        console.log(`removed stale ${stale}.png`);
    }
}

for (const [name, fn] of Object.entries(textures)) {
    const buf = fn();
    fs.writeFileSync(path.join(OUT, name + ".png"), buf);
    console.log(`${name.padEnd(10)} ${buf.length.toString().padStart(7)} bytes`);
}

console.log(`\nwritten to ${OUT}`);
