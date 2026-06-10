// Minimal UTF-8 decoder/iterator for the RocketCraft text stack.
// Designed to be cheap: no allocations, no codepoint tables, no lookups.
// Only forward iteration over a byte slice and a single-codepoint decode.
//
// Supports RFC 3629 (1-4 byte sequences). Replacement codepoint 0xFFFD is
// returned when the input is malformed; the caller can decide whether to
// render a placeholder or skip the byte.

const std = @import("std");

pub const Replacement = 0xFFFD;
pub const MaxBytesPerCodepoint = 4;

/// Decodes the next codepoint starting at `bytes[i]`.
///
/// `i` is updated in-place to point past the consumed bytes (1..=4).
/// On malformed input `i` is advanced by 1 to keep the iterator un-stuck
/// and the replacement codepoint is returned.
pub fn nextCodepoint(bytes: []const u8, i: *usize) u21 {
    const start = i.*;
    if (start >= bytes.len) return Replacement;
    const b0 = bytes[start];

    if (b0 < 0x80) {
        i.* = start + 1;
        return b0;
    }

    // Multi-byte sequences must lead with 10xxxxxx which is impossible for
    // a continuation byte at the lead position. The high-bit pattern below
    // matches RFC 3629 lead bytes only.
    if ((b0 & 0b1110_0000) == 0b1100_0000) {
        if (start + 1 >= bytes.len) {
            i.* = start + 1;
            return Replacement;
        }
        const b1 = bytes[start + 1];
        if ((b1 & 0b1100_0000) != 0b1000_0000) {
            i.* = start + 1;
            return Replacement;
        }
        const cp: u21 = (@as(u21, b0 & 0x1F) << 6) | @as(u21, b1 & 0x3F);
        if (cp < 0x80) {
            i.* = start + 1;
            return Replacement;
        }
        i.* = start + 2;
        return cp;
    }

    if ((b0 & 0b1111_0000) == 0b1110_0000) {
        if (start + 2 >= bytes.len) {
            i.* = start + 1;
            return Replacement;
        }
        const b1 = bytes[start + 1];
        const b2 = bytes[start + 2];
        if (((b1 & 0b1100_0000) != 0b1000_0000) or ((b2 & 0b1100_0000) != 0b1000_0000)) {
            i.* = start + 1;
            return Replacement;
        }
        const cp: u21 = (@as(u21, b0 & 0x0F) << 12) |
            (@as(u21, b1 & 0x3F) << 6) |
            @as(u21, b2 & 0x3F);
        if (cp < 0x800) {
            i.* = start + 1;
            return Replacement;
        }
        // Surrogates (U+D800..U+DFFF) are not valid Unicode scalar values.
        if (cp >= 0xD800 and cp <= 0xDFFF) {
            i.* = start + 1;
            return Replacement;
        }
        i.* = start + 3;
        return cp;
    }

    if ((b0 & 0b1111_1000) == 0b1111_0000) {
        if (start + 3 >= bytes.len) {
            i.* = start + 1;
            return Replacement;
        }
        const b1 = bytes[start + 1];
        const b2 = bytes[start + 2];
        const b3 = bytes[start + 3];
        if (((b1 & 0b1100_0000) != 0b1000_0000) or
            ((b2 & 0b1100_0000) != 0b1000_0000) or
            ((b3 & 0b1100_0000) != 0b1000_0000))
        {
            i.* = start + 1;
            return Replacement;
        }
        const cp: u21 = (@as(u21, b0 & 0x07) << 18) |
            (@as(u21, b1 & 0x3F) << 12) |
            (@as(u21, b2 & 0x3F) << 6) |
            @as(u21, b3 & 0x3F);
        if (cp < 0x10000 or cp > 0x10FFFF) {
            i.* = start + 1;
            return Replacement;
        }
        i.* = start + 4;
        return cp;
    }

    // Lead byte is 10xxxxxx (stray continuation) or 11111xxx (reserved).
    i.* = start + 1;
    return Replacement;
}

/// Returns the number of UTF-8 bytes the given codepoint occupies.
pub fn codepointLen(cp: u21) u3 {
    if (cp < 0x80) return 1;
    if (cp < 0x800) return 2;
    if (cp < 0x10000) return 3;
    return 4;
}

/// Returns true when `cp` is in the Basic Latin range (0x20..=0x7E).
/// Used by the text renderer to choose between the embedded ASCII bitmap
/// font (zero cost) and the TTF fallback for everything else (Thai, etc).
pub fn isAsciiPrintable(cp: u21) bool {
    return cp >= 0x20 and cp <= 0x7E;
}

/// Returns true when `cp` is a Thai script codepoint (U+0E00..U+0E7F).
/// Used to detect when the TTF glyph cache must be used.
pub fn isThai(cp: u21) bool {
    return cp >= 0x0E00 and cp <= 0x0E7F;
}

/// Counts the codepoints (not bytes) in a UTF-8 string.
pub fn codepointCount(bytes: []const u8) usize {
    var i: usize = 0;
    var count: usize = 0;
    while (i < bytes.len) : (count += 1) {
        _ = nextCodepoint(bytes, &i);
    }
    return count;
}

test "ascii decoding" {
    var i: usize = 0;
    try std.testing.expectEqual(@as(u21, 'A'), nextCodepoint("A", &i));
    try std.testing.expectEqual(@as(usize, 1), i);

    i = 0;
    try std.testing.expectEqual(@as(u21, 'Z'), nextCodepoint("Zig", &i));
    try std.testing.expectEqual(@as(usize, 1), i);
}

test "thai decoding" {
    // U+0E2A U+0E32 U+0E22 = "สาย" (3 codepoints, 9 bytes in UTF-8)
    const text = "สาย";
    var i: usize = 0;
    try std.testing.expect(nextCodepoint(text, &i) == 0x0E2A); // ส
    try std.testing.expect(nextCodepoint(text, &i) == 0x0E32); // า
    try std.testing.expect(nextCodepoint(text, &i) == 0x0E22); // ย
    try std.testing.expectEqual(@as(usize, text.len), i);
}

test "malformed bytes yield replacement and advance one byte" {
    const bad = [_]u8{ 0xFF, 0xC3 };
    var i: usize = 0;
    try std.testing.expectEqual(@as(u21, Replacement), nextCodepoint(&bad, &i));
    try std.testing.expectEqual(@as(usize, 1), i);
    try std.testing.expectEqual(@as(u21, Replacement), nextCodepoint(&bad, &i));
    try std.testing.expectEqual(@as(usize, 2), i);
}

test "codepointLen matches encoding" {
    try std.testing.expectEqual(@as(u3, 1), codepointLen('A'));
    try std.testing.expectEqual(@as(u3, 3), codepointLen(0x0E2A)); // Thai 'ส'
    try std.testing.expectEqual(@as(u3, 4), codepointLen(0x1F600)); // emoji
}
