// Single source of truth for the @cImport of raylib.h.
//
// Zig treats @cImport in each file as its own anonymous cimport unit, which
// means the resulting struct types (e.g. rl.Color) are nominally distinct
// across files even though they describe the same C struct. Centralising
// the import here lets every module share the same `rl` namespace and
// the same struct types.
pub const rl = @cImport({
    @cInclude("raylib.h");
});
