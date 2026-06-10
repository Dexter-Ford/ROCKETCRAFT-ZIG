// Lightweight multi-language text rendering for RocketCraft.
//
// Two-tier design:
//   1. Embedded 5x7 ASCII bitmap font (95 glyphs, ~500 bytes) for English.
//      Drawn one pixel at a time using rl.DrawPixel, no file I/O, no atlas.
//   2. A single loaded TTF font (32 KB subset, English + Thai) used for
//      any non-ASCII codepoint. Loaded once at startup and cached.
//
// drawText/measureText walk the UTF-8 input codepoint by codepoint and
// dispatch to the appropriate renderer. This keeps the hot path (English
// UI) extremely cheap while still supporting Thai dialogue/numbers/etc.

const std = @import("std");
const rl = @import("raylib.zig").rl;
const utf8 = @import("utf8.zig");

pub const AsciiGlyphW: u5 = 5;
pub const AsciiGlyphH: u5 = 7;
pub const AsciiSpacing: i32 = 1;
pub const TtfFallbackSize: c_int = 22;

const AsciiFirst: u8 = 0x20;
const AsciiLast: u8 = 0x7E;
const AsciiCount: usize = AsciiLast - AsciiFirst + 1; // 95

/// 5x7 bitmap font, one bit per pixel, column-major (LSB = top pixel).
/// Each glyph is 5 bytes; rows are read with the bit pattern packed
/// top-to-bottom. Index = codepoint - 0x20.
const AsciiFont = [AsciiCount][AsciiGlyphW]u8{
    // 0x20 ' '
    .{ 0x00, 0x00, 0x00, 0x00, 0x00 },
    // 0x21 '!'
    .{ 0x00, 0x00, 0x5F, 0x00, 0x00 },
    // 0x22 '"'
    .{ 0x00, 0x07, 0x00, 0x07, 0x00 },
    // 0x23 '#'
    .{ 0x14, 0x7F, 0x14, 0x7F, 0x14 },
    // 0x24 '$'
    .{ 0x24, 0x2A, 0x7F, 0x2A, 0x12 },
    // 0x25 '%'
    .{ 0x23, 0x13, 0x08, 0x64, 0x62 },
    // 0x26 '&'
    .{ 0x36, 0x49, 0x55, 0x22, 0x50 },
    // 0x27 '''
    .{ 0x00, 0x00, 0x07, 0x00, 0x00 },
    // 0x28 '('
    .{ 0x00, 0x1C, 0x22, 0x41, 0x00 },
    // 0x29 ')'
    .{ 0x00, 0x41, 0x22, 0x1C, 0x00 },
    // 0x2A '*'
    .{ 0x08, 0x2A, 0x1C, 0x2A, 0x08 },
    // 0x2B '+'
    .{ 0x08, 0x08, 0x3E, 0x08, 0x08 },
    // 0x2C ','
    .{ 0x00, 0x50, 0x30, 0x00, 0x00 },
    // 0x2D '-'
    .{ 0x08, 0x08, 0x08, 0x08, 0x08 },
    // 0x2E '.'
    .{ 0x00, 0x60, 0x60, 0x00, 0x00 },
    // 0x2F '/'
    .{ 0x20, 0x10, 0x08, 0x04, 0x02 },
    // 0x30 '0'
    .{ 0x3E, 0x51, 0x49, 0x45, 0x3E },
    // 0x31 '1'
    .{ 0x00, 0x42, 0x7F, 0x40, 0x00 },
    // 0x32 '2'
    .{ 0x42, 0x61, 0x51, 0x49, 0x46 },
    // 0x33 '3'
    .{ 0x21, 0x41, 0x45, 0x4B, 0x31 },
    // 0x34 '4'
    .{ 0x18, 0x14, 0x12, 0x7F, 0x10 },
    // 0x35 '5'
    .{ 0x27, 0x45, 0x45, 0x45, 0x39 },
    // 0x36 '6'
    .{ 0x3C, 0x4A, 0x49, 0x49, 0x30 },
    // 0x37 '7'
    .{ 0x01, 0x71, 0x09, 0x05, 0x03 },
    // 0x38 '8'
    .{ 0x36, 0x49, 0x49, 0x49, 0x36 },
    // 0x39 '9'
    .{ 0x06, 0x49, 0x49, 0x29, 0x1E },
    // 0x3A ':'
    .{ 0x00, 0x36, 0x36, 0x00, 0x00 },
    // 0x3B ';'
    .{ 0x00, 0x56, 0x36, 0x00, 0x00 },
    // 0x3C '<'
    .{ 0x00, 0x08, 0x14, 0x22, 0x41 },
    // 0x3D '='
    .{ 0x14, 0x14, 0x14, 0x14, 0x14 },
    // 0x3E '>'
    .{ 0x41, 0x22, 0x14, 0x08, 0x00 },
    // 0x3F '?'
    .{ 0x02, 0x01, 0x51, 0x09, 0x06 },
    // 0x40 '@'
    .{ 0x32, 0x49, 0x79, 0x41, 0x3E },
    // 0x41 'A'
    .{ 0x7E, 0x11, 0x11, 0x11, 0x7E },
    // 0x42 'B'
    .{ 0x7F, 0x49, 0x49, 0x49, 0x36 },
    // 0x43 'C'
    .{ 0x3E, 0x41, 0x41, 0x41, 0x22 },
    // 0x44 'D'
    .{ 0x7F, 0x41, 0x41, 0x22, 0x1C },
    // 0x45 'E'
    .{ 0x7F, 0x49, 0x49, 0x49, 0x41 },
    // 0x46 'F'
    .{ 0x7F, 0x09, 0x09, 0x01, 0x01 },
    // 0x47 'G'
    .{ 0x3E, 0x41, 0x41, 0x51, 0x32 },
    // 0x48 'H'
    .{ 0x7F, 0x08, 0x08, 0x08, 0x7F },
    // 0x49 'I'
    .{ 0x00, 0x41, 0x7F, 0x41, 0x00 },
    // 0x4A 'J'
    .{ 0x20, 0x40, 0x41, 0x3F, 0x01 },
    // 0x4B 'K'
    .{ 0x7F, 0x08, 0x14, 0x22, 0x41 },
    // 0x4C 'L'
    .{ 0x7F, 0x40, 0x40, 0x40, 0x40 },
    // 0x4D 'M'
    .{ 0x7F, 0x02, 0x04, 0x02, 0x7F },
    // 0x4E 'N'
    .{ 0x7F, 0x04, 0x08, 0x10, 0x7F },
    // 0x4F 'O'
    .{ 0x3E, 0x41, 0x41, 0x41, 0x3E },
    // 0x50 'P'
    .{ 0x7F, 0x09, 0x09, 0x09, 0x06 },
    // 0x51 'Q'
    .{ 0x3E, 0x41, 0x51, 0x21, 0x5E },
    // 0x52 'R'
    .{ 0x7F, 0x09, 0x19, 0x29, 0x46 },
    // 0x53 'S'
    .{ 0x46, 0x49, 0x49, 0x49, 0x31 },
    // 0x54 'T'
    .{ 0x01, 0x01, 0x7F, 0x01, 0x01 },
    // 0x55 'U'
    .{ 0x3F, 0x40, 0x40, 0x40, 0x3F },
    // 0x56 'V'
    .{ 0x1F, 0x20, 0x40, 0x20, 0x1F },
    // 0x57 'W'
    .{ 0x7F, 0x20, 0x18, 0x20, 0x7F },
    // 0x58 'X'
    .{ 0x63, 0x14, 0x08, 0x14, 0x63 },
    // 0x59 'Y'
    .{ 0x03, 0x04, 0x78, 0x04, 0x03 },
    // 0x5A 'Z'
    .{ 0x61, 0x51, 0x49, 0x45, 0x43 },
    // 0x5B '['
    .{ 0x00, 0x7F, 0x41, 0x41, 0x00 },
    // 0x5C '\'
    .{ 0x02, 0x04, 0x08, 0x10, 0x20 },
    // 0x5D ']'
    .{ 0x00, 0x41, 0x41, 0x7F, 0x00 },
    // 0x5E '^'
    .{ 0x04, 0x02, 0x01, 0x02, 0x04 },
    // 0x5F '_'
    .{ 0x40, 0x40, 0x40, 0x40, 0x40 },
    // 0x60 '`'
    .{ 0x00, 0x00, 0x03, 0x04, 0x00 },
    // 0x61 'a'
    .{ 0x20, 0x54, 0x54, 0x54, 0x78 },
    // 0x62 'b'
    .{ 0x7F, 0x48, 0x44, 0x44, 0x38 },
    // 0x63 'c'
    .{ 0x38, 0x44, 0x44, 0x44, 0x20 },
    // 0x64 'd'
    .{ 0x38, 0x44, 0x44, 0x48, 0x7F },
    // 0x65 'e'
    .{ 0x38, 0x54, 0x54, 0x54, 0x18 },
    // 0x66 'f'
    .{ 0x08, 0x7E, 0x09, 0x01, 0x02 },
    // 0x67 'g'
    .{ 0x08, 0x14, 0x54, 0x54, 0x3C },
    // 0x68 'h'
    .{ 0x7F, 0x08, 0x04, 0x04, 0x78 },
    // 0x69 'i'
    .{ 0x00, 0x44, 0x7D, 0x40, 0x00 },
    // 0x6A 'j'
    .{ 0x20, 0x40, 0x44, 0x3D, 0x00 },
    // 0x6B 'k'
    .{ 0x00, 0x7F, 0x10, 0x28, 0x44 },
    // 0x6C 'l'
    .{ 0x00, 0x41, 0x7F, 0x40, 0x00 },
    // 0x6D 'm'
    .{ 0x7C, 0x04, 0x18, 0x04, 0x78 },
    // 0x6E 'n'
    .{ 0x7C, 0x08, 0x04, 0x04, 0x78 },
    // 0x6F 'o'
    .{ 0x38, 0x44, 0x44, 0x44, 0x38 },
    // 0x70 'p'
    .{ 0x7C, 0x14, 0x14, 0x14, 0x08 },
    // 0x71 'q'
    .{ 0x08, 0x14, 0x14, 0x18, 0x7C },
    // 0x72 'r'
    .{ 0x7C, 0x08, 0x04, 0x04, 0x08 },
    // 0x73 's'
    .{ 0x48, 0x54, 0x54, 0x54, 0x20 },
    // 0x74 't'
    .{ 0x04, 0x3F, 0x44, 0x40, 0x20 },
    // 0x75 'u'
    .{ 0x3C, 0x40, 0x40, 0x20, 0x7C },
    // 0x76 'v'
    .{ 0x1C, 0x20, 0x40, 0x20, 0x1C },
    // 0x77 'w'
    .{ 0x3C, 0x40, 0x30, 0x40, 0x3C },
    // 0x78 'x'
    .{ 0x44, 0x28, 0x10, 0x28, 0x44 },
    // 0x79 'y'
    .{ 0x0C, 0x50, 0x50, 0x50, 0x3C },
    // 0x7A 'z'
    .{ 0x44, 0x64, 0x54, 0x4C, 0x44 },
    // 0x7B '{'
    .{ 0x00, 0x08, 0x36, 0x41, 0x00 },
    // 0x7C '|'
    .{ 0x00, 0x00, 0x7F, 0x00, 0x00 },
    // 0x7D '}'
    .{ 0x00, 0x41, 0x36, 0x08, 0x00 },
    // 0x7E '~'
    .{ 0x10, 0x08, 0x08, 0x10, 0x10 },
};

/// Rasterizer state for the multi-language text stack.
/// One instance per font size is enough for the whole game.
pub const TextState = struct {
    /// TTF font for non-ASCII (Thai, etc). May be invalid if the asset
    /// could not be loaded on this platform.
    ttf: rl.Font,
    ttf_base_size: c_int,
    /// TTF size used as a reference (pixel size). Other sizes are derived
    /// via rl.DrawTextEx at draw time.
    ttf_loaded: bool,

    pub fn zero() TextState {
        return .{
            .ttf = .{ .baseSize = 0, .glyphCount = 0, .glyphPadding = 0, .texture = .{
                .id = 0, .width = 0, .height = 0, .mipmaps = 0, .format = 0,
            }, .recs = null, .glyphs = null },
            .ttf_base_size = TtfFallbackSize,
            .ttf_loaded = false,
        };
    }

    /// Searches a small list of candidate paths and loads the first
    /// TTF that exists. Safe to call multiple times; only the first
    /// successful load is kept.
    pub fn initFromPaths(self: *TextState, paths: []const [*:0]const u8, base_size: c_int) void {
        if (self.ttf_loaded) return;
        for (paths) |path| {
            if (!rl.FileExists(path)) continue;
            const cp_count: c_int = 1024;
            const codepoints = blk: {
                var buf: [1024]c_int = undefined;
                var k: usize = 0;
                while (k < 256) : (k += 1) buf[k] = @as(c_int, @intCast(k));
                // Thai block
                k = 0;
                while (k < 128) : (k += 1) buf[256 + k] = @as(c_int, @intCast(0x0E00 + k));
                // Common punctuation/symbols
                k = 0;
                while (k < 128) : (k += 1) buf[384 + k] = @as(c_int, @intCast(0x2000 + k));
                // Hiragana/Katakana (often used in Thai games, e.g. manga-style)
                k = 0;
                while (k < 256) : (k += 1) buf[512 + k] = @as(c_int, @intCast(0x3040 + k));
                break :blk buf[0..@as(usize, @intCast(cp_count))];
            };
            const font = rl.LoadFontEx(path, base_size, codepoints.ptr, cp_count);
            if (rl.IsFontValid(font)) {
                rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_BILINEAR);
                self.ttf = font;
                self.ttf_base_size = base_size;
                self.ttf_loaded = true;
                return;
            }
        }
    }

    pub fn deinit(self: *TextState) void {
        if (self.ttf_loaded) {
            rl.UnloadFont(self.ttf);
            self.ttf_loaded = false;
        }
    }
};

/// Returns the on-screen width in pixels of the given UTF-8 text at the
/// given pixel size. ASCII is measured with the embedded font; everything
/// else uses the TTF. The returned width is rounded to the nearest pixel.
pub fn measureText(state: *const TextState, text: []const u8, size: i32) i32 {
    if (text.len == 0) return 0;

    // Hot path: all-ASCII (English UI). Avoid touching the TTF at all.
    if (isAllAscii(text)) {
        const scaled = @max(1, size);
        const char_w = (AsciiGlyphW + AsciiSpacing) * scaled;
        return @as(i32, @intCast(text.len)) * char_w;
    }

    if (!state.ttf_loaded) {
        // No TTF available; degrade to ASCII count for the printable
        // portion and use a per-non-ascii approximation.
        return fallbackMeasure(text, size);
    }

    const ttf_size = @as(f32, @floatFromInt(@max(1, size)));
    const m = rl.MeasureTextEx(state.ttf, text.ptr, ttf_size, 1.0);
    return @as(i32, @intFromFloat(m.x));
}

fn isAllAscii(text: []const u8) bool {
    for (text) |b| {
        if (b > 0x7E) return false;
    }
    return true;
}

fn fallbackMeasure(text: []const u8, size: i32) i32 {
    var i: usize = 0;
    var width: i32 = 0;
    const scaled = @max(1, size);
    while (i < text.len) {
        const cp = utf8.nextCodepoint(text, &i);
        if (cp == ' ') {
            width += 3 * scaled;
        } else if (utf8.isAsciiPrintable(cp)) {
            width += (AsciiGlyphW + AsciiSpacing) * scaled;
        } else {
            width += 5 * scaled;
        }
    }
    return width;
}

/// Draws a UTF-8 string at the given top-left pixel position.
/// ASCII is drawn from the embedded bitmap (very cheap); non-ASCII
/// codepoints are drawn from the cached TTF.
pub fn drawText(
    state: *const TextState,
    text: []const u8,
    x: i32,
    y: i32,
    size: i32,
    col: rl.Color,
) void {
    if (text.len == 0) return;

    // Hot path: all-ASCII.
    if (isAllAscii(text)) {
        drawAsciiBitmap(state, text, x, y, size, col);
        return;
    }

    if (!state.ttf_loaded) {
        // No TTF: still draw the ASCII portion pixel-perfect, then drop
        // the rest (better than nothing on a misconfigured platform).
        var i: usize = 0;
        var cx = x;
        const scaled = @max(1, size);
        while (i < text.len) {
            const start = i;
            const cp = utf8.nextCodepoint(text, &i);
            if (utf8.isAsciiPrintable(cp)) {
                drawAsciiGlyph(state, @as(u8, @intCast(cp)), cx, y, scaled, col);
                cx += (AsciiGlyphW + AsciiSpacing) * scaled;
            } else {
                // Render a small placeholder box to indicate the unknown
                // codepoint position.
                rl.DrawRectangle(cx + 1, y + 1, 4 * scaled, 5 * scaled, col);
                cx += 5 * scaled;
            }
            _ = start;
        }
        return;
    }

    const ttf_size = @as(f32, @floatFromInt(@max(1, size)));
    rl.DrawTextEx(state.ttf, text.ptr, .{ .x = @as(f32, @floatFromInt(x)), .y = @as(f32, @floatFromInt(y)) }, ttf_size, 1.0, col);
}

fn drawAsciiBitmap(
    state: *const TextState,
    text: []const u8,
    x: i32,
    y: i32,
    size: i32,
    col: rl.Color,
) void {
    const scaled = @max(1, size);
    var cx = x;
    for (text) |b| {
        if (b == ' ') {
            cx += 3 * scaled;
            continue;
        }
        if (b == '\t') {
            cx += 3 * scaled * 4;
            continue;
        }
        if (b < AsciiFirst or b > AsciiLast) {
            // Stray control char; render as a thin placeholder.
            rl.DrawRectangle(cx, y + @as(i32, @intCast(AsciiGlyphH)) * scaled - 1, 4 * scaled, scaled, col);
            cx += 4 * scaled;
            continue;
        }
        drawAsciiGlyph(state, b, cx, y, scaled, col);
        cx += (AsciiGlyphW + AsciiSpacing) * scaled;
    }
}

inline fn drawAsciiGlyph(
    state: *const TextState,
    cp: u8,
    x: i32,
    y: i32,
    scale: i32,
    col: rl.Color,
) void {
    _ = state;
    const idx: usize = cp - AsciiFirst;
    const glyph = AsciiFont[idx];
    var col_x: usize = 0;
    while (col_x < AsciiGlyphW) : (col_x += 1) {
        const bits = glyph[col_x];
        var row: usize = 0;
        while (row < AsciiGlyphH) : (row += 1) {
            if ((bits >> @intCast(row)) & 1 != 0) {
                if (scale == 1) {
                    rl.DrawPixel(x + @as(i32, @intCast(col_x)), y + @as(i32, @intCast(row)), col);
                } else {
                    rl.DrawRectangle(
                        x + @as(i32, @intCast(col_x)) * scale,
                        y + @as(i32, @intCast(row)) * scale,
                        scale,
                        scale,
                        col,
                    );
                }
            }
        }
    }
}

/// Convenience wrapper that takes a null-terminated C string (the style
/// the rest of the Zig codebase uses everywhere).
pub fn drawTextZ(
    state: *const TextState,
    text: [*:0]const u8,
    x: i32,
    y: i32,
    size: i32,
    col: rl.Color,
) void {
    drawText(state, std.mem.span(text), x, y, size, col);
}

pub fn measureTextZ(state: *const TextState, text: [*:0]const u8, size: i32) i32 {
    return measureText(state, std.mem.span(text), size);
}

// ----- tests -----

test "AsciiFont covers printable ASCII" {
    try std.testing.expectEqual(AsciiCount, AsciiFont.len);
    try std.testing.expect(AsciiFont['A' - AsciiFirst][0] != 0);
    try std.testing.expect(AsciiFont[' ' - AsciiFirst][0] == 0);
    try std.testing.expect(AsciiFont['Z' - AsciiFirst][0] != 0);
    try std.testing.expect(AsciiFont['0' - AsciiFirst][0] != 0);
}

test "measureText ascii path uses no TTF" {
    const s = TextState.zero();
    const w = measureText(&s, "HELLO", 16);
    try std.testing.expect(w > 0);
    // 5 chars * (5 + 1) * 16 = 480
    try std.testing.expectEqual(@as(i32, 480), w);
}

test "fallbackMeasure handles UTF-8 gracefully" {
    const s = TextState.zero();
    const w = measureText(&s, "ABสาย", 10);
    try std.testing.expect(w > 0);
}
