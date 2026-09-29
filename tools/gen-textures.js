// tools/gen-textures.js
//
// Generates the DECAY overlay textures as PNGs into assets/Textures/.
// Pure node — zlib for the deflate stream, hand-rolled CRC32 and chunk writer.
//
//   node tools/gen-textures.js
//
// Output is deterministic (fixed seed) so rebuilds don't churn the repo.
//
// These get picked up by tools/bundle.js like any other asset, inlined as
// base64(zstd(bytes)), written to Console/Textures/ at runtime and loaded with
// getcustomasset. See src/utility/console/theme.lua.

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

// pixels: Uint8Array of width*height*4
function encodePNG(width, height, pixels) {
    const stride = width * 4;
    const raw = Buffer.alloc((stride + 1) * height);
    for (let y = 0; y < height; y++) {
        raw[y * (stride + 1)] = 0; // filter: none
        Buffer.from(pixels.buffer, pixels.byteOffset + y * stride, stride).copy(raw, y * (stride + 1) + 1);
    }

    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(width, 0);
    ihdr.writeUInt32BE(height, 4);
    ihdr[8] = 8;   // bit depth
    ihdr[9] = 6;   // colour type: RGBA
    ihdr[10] = 0;  // compression
    ihdr[11] = 0;  // filter
    ihdr[12] = 0;  // interlace

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

function put(px, w, x, y, r, g, b, a) {
    const i = (y * w + x) * 4;
    px[i] = r;
    px[i + 1] = g;
    px[i + 2] = b;
    px[i + 3] = a;
}

// ── textures ───────────────────────────────────────────────────────────────

// Fine monochrome grain. Three octaves so it doesn't read as flat TV static.
function grain() {
    const w = 128, h = 128;
    const px = blank(w, h);
    const rnd = mulberry32(0x5eed);
    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const fine = rnd();
            const coarse = (Math.sin(x * 0.21) + Math.cos(y * 0.17) + 2) / 4;
            const v = fine * 0.7 + coarse * 0.3;
            // Neutral and light. The UI background is black now, so dark grain
            // would be invisible; this reads as faint white speckle.
            const g = Math.floor(150 + v * 105);
            put(px, w, x, y, g, g, g, Math.floor(8 + v * 40));
        }
    }
    return encodePNG(w, h, px);
}

// 4px tileable scanline: one dark row per 4.
function scanline() {
    const w = 4, h = 4;
    const px = blank(w, h);
    for (let x = 0; x < w; x++) {
        put(px, w, x, 0, 0, 0, 0, 0);
        put(px, w, x, 1, 0, 0, 0, 0);
        put(px, w, x, 2, 0, 0, 0, 0);
        put(px, w, x, 3, 210, 210, 210, 44);
    }
    return encodePNG(w, h, px);
}

// Sparse scratches and dust. Mostly transparent.
function scratch() {
    const w = 256, h = 256;
    const px = blank(w, h);
    const rnd = mulberry32(0xdead);
    for (let i = 0; i < 48; i++) {
        const x = Math.floor(rnd() * w);
        const len = Math.floor(24 + rnd() * 190);
        const y0 = Math.floor(rnd() * h);
        const a = Math.floor(14 + rnd() * 40);
        const bright = rnd() > 0.75;
        for (let y = y0; y < Math.min(y0 + len, h); y++) {
            const shade = bright ? 240 : 130;
            put(px, w, x, y, shade, shade, shade, a);
        }
    }
    for (let i = 0; i < 26; i++) {
        const y = Math.floor(rnd() * h);
        const len = Math.floor(20 + rnd() * 150);
        const x0 = Math.floor(rnd() * w);
        const a = Math.floor(10 + rnd() * 30);
        for (let x = x0; x < Math.min(x0 + len, w); x++) {
            put(px, w, x, y, 160, 160, 160, a);
        }
    }
    return encodePNG(w, h, px);
}

// Radial falloff. Black, alpha rises toward the edge.
function vignette() {
    const w = 256, h = 256;
    const px = blank(w, h);
    const cx = w / 2, cy = h / 2;
    const max = Math.sqrt(cx * cx + cy * cy);
    for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
            const dx = x - cx, dy = y - cy;
            const d = Math.sqrt(dx * dx + dy * dy) / max;
            const a = Math.max(0, Math.min(1, (d - 0.42) / 0.58));
            put(px, w, x, y, 6, 7, 5, Math.floor(a * a * 205));
        }
    }
    return encodePNG(w, h, px);
}

// Soft irregular blotches — damp, not clean.
function stain() {
    const w = 128, h = 128;
    const px = blank(w, h);
    const rnd = mulberry32(0xb10b);
    for (let i = 0; i < 9; i++) {
        const bx = rnd() * w, by = rnd() * h;
        const rad = 12 + rnd() * 30;
        const strength = 0.25 + rnd() * 0.5;
        for (let y = 0; y < h; y++) {
            for (let x = 0; x < w; x++) {
                const dx = x - bx, dy = y - by;
                const d = Math.sqrt(dx * dx + dy * dy) / rad;
                if (d > 1) continue;
                const falloff = (1 - d) * (1 - d) * strength;
                const idx = (y * w + x) * 4;
                const a = Math.min(255, px[idx + 3] + Math.floor(falloff * 120));
                put(px, w, x, y, 205, 205, 205, a);
            }
        }
    }
    return encodePNG(w, h, px);
}

// ── write ──────────────────────────────────────────────────────────────────
const textures = { grain, scanline, scratch, vignette, stain };

if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

for (const [name, fn] of Object.entries(textures)) {
    const buf = fn();
    const file = path.join(OUT, name + ".png");
    fs.writeFileSync(file, buf);
    console.log(`${name.padEnd(10)} ${buf.length.toString().padStart(7)} bytes`);
}

console.log(`\nwritten to ${OUT}`);
