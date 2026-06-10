# RocketCraft Zig

RocketCraft Zig is a low-level rewrite scaffold for the current RocketCraft loop:

- Title -> Town -> Hangar -> Launch
- static rocket part stack
- packed vessel status flags
- procedural launch physics
- procedural Raylib AudioStream music and SFX
- Stardew-like day clock
- flight mission rewards
- achievement bitmasks
- compact story flags and NPC morale
- low-level town map with buildings, zones, collision, player, and NPC schedules
- LDtk town map loading with packed collision rectangles
- streamed `.ogg` background music selection
- Raylib rendering through Zig `@cImport`

The project is intentionally small and C-port friendly. Gameplay state is kept in fixed-size structs and arrays; the hot launch path does not allocate heap objects.

## Requirements

- Zig 0.16 or newer installed and available in `PATH`
- Network access for the first build so Zig can fetch the pinned Raylib source dependency

## Run

```sh
zig build run
```

## Test

```sh
zig build test
```

## Release Builds

macOS native:

```sh
zig build -Doptimize=ReleaseSafe
```

Windows x86_64:

```sh
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-windows-gnu
```

Build artifacts are written to `zig-out/bin/`. Runtime assets live in `assets/` and should be copied next to the executable for packaged releases.

## Controls

- `Enter`: start
- `H`: hangar
- `L`: launch
- Town: `WASD`/arrow keys or click ground to walk, click buildings to interact, click NPC or press `E` to talk, `M` opens map
- Hangar: `M` add missing mission systems, `P` preset, `C` clear, `Backspace` remove last part
- Launch: `W/S` throttle, `A/D` rotate, `Space` ignition, `R` reset flight
- `Esc`: return

## Notes

This repository intentionally excludes local caches, save files, Aseprite editor sources, and compiled binaries. Keep generated release packages in `dist/`; that folder is ignored by Git.
