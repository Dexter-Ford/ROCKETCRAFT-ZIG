const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const config = @import("config.zig");

const tau: f32 = 6.283185307179586;
const pcm_len: usize = config.audio_frames * config.audio_channels;
pub const max_music_tracks: usize = 16;
pub const music_path_bytes: usize = 260;
pub const music_label_bytes: usize = 64;

const music_dirs = [_][*:0]const u8{
    "assets/Music",
    "assets",
    "../Game asset/Music:Sound",
    "../../Game asset/Music:Sound",
};

pub const AudioMode = enum(u8) {
    title,
    town,
    hangar,
    launch,
};

pub const AudioState = struct {
    stream: rl.AudioStream,
    music: rl.Music,
    pcm: [pcm_len]i16,
    track_paths: [max_music_tracks][music_path_bytes]u8,
    track_labels: [max_music_tracks][music_label_bytes]u8,
    track_path_lens: [max_music_tracks]usize,
    track_label_lens: [max_music_tracks]usize,
    melody_phase: f32,
    bass_phase: f32,
    arp_phase: f32,
    pad_phase: f32,
    beep_phase: f32,
    song_time: f32,
    beep_time: f32,
    beep_hz: f32,
    ignition_time: f32,
    explosion_time: f32,
    noise_seed: u32,
    track_count: usize,
    selected_music: usize,
    ready: bool,
    music_ready: bool,
    music_enabled: bool,
    muted: bool,
    music_volume: f32,
    sfx_volume: f32,

    pub fn zero() AudioState {
        return .{
            .stream = undefined,
            .music = undefined,
            .pcm = [_]i16{0} ** pcm_len,
            .track_paths = [_][music_path_bytes]u8{[_]u8{0} ** music_path_bytes} ** max_music_tracks,
            .track_labels = [_][music_label_bytes]u8{[_]u8{0} ** music_label_bytes} ** max_music_tracks,
            .track_path_lens = [_]usize{0} ** max_music_tracks,
            .track_label_lens = [_]usize{0} ** max_music_tracks,
            .melody_phase = 0.0,
            .bass_phase = 0.0,
            .arp_phase = 0.0,
            .pad_phase = 0.0,
            .beep_phase = 0.0,
            .song_time = 0.0,
            .beep_time = 0.0,
            .beep_hz = 840.0,
            .ignition_time = 0.0,
            .explosion_time = 0.0,
            .noise_seed = 0x4d3a2b1c,
            .track_count = 0,
            .selected_music = 0,
            .ready = false,
            .music_ready = false,
            .music_enabled = true,
            .muted = false,
            .music_volume = 1.0,
            .sfx_volume = 1.0,
        };
    }

    pub fn init(self: *AudioState) void {
        rl.InitAudioDevice();
        if (!rl.IsAudioDeviceReady()) {
            self.ready = false;
            return;
        }
        rl.SetAudioStreamBufferSizeDefault(@as(c_int, @intCast(config.audio_frames)));
        self.stream = rl.LoadAudioStream(config.sample_rate, 16, config.audio_channels);
        self.ready = true;
        rl.PlayAudioStream(self.stream);
        self.scanMusicTracks();
    }

    pub fn deinit(self: *AudioState) void {
        self.unloadMusic();
        if (self.ready) {
            rl.UnloadAudioStream(self.stream);
            self.ready = false;
        }
        if (rl.IsAudioDeviceReady()) {
            rl.CloseAudioDevice();
        }
    }

    pub fn click(self: *AudioState) void {
        self.beep_time = 0.10;
        self.beep_hz = 840.0;
        self.beep_phase = 0.0;
    }

    pub fn confirm(self: *AudioState) void {
        self.beep_time = 0.08;
        self.beep_hz = 660.0;
        self.beep_phase = 0.0;
    }

    pub fn errorTone(self: *AudioState) void {
        self.beep_time = 0.14;
        self.beep_hz = 180.0;
        self.beep_phase = 0.0;
    }

    pub fn ignition(self: *AudioState) void {
        self.ignition_time = 1.35;
        self.explosion_time = 0.34;
        self.noise_seed ^= 0xa53c91eb;
    }

    pub fn explosion(self: *AudioState) void {
        self.explosion_time = 0.82;
        self.noise_seed ^= 0x7f4a7c15;
    }

    pub fn applyMusicSettings(self: *AudioState, enabled: bool, index: usize, volume: f32) void {
        self.music_enabled = enabled;
        self.setMusicVolume(volume);
        if (self.track_count == 0) return;
        const safe_index = if (index < self.track_count) index else 0;
        if (safe_index != self.selected_music or !self.music_ready) {
            self.selectMusic(safe_index);
        } else {
            self.applyMusicPlayback();
        }
    }

    pub fn setMusicEnabled(self: *AudioState, enabled: bool) void {
        self.music_enabled = enabled;
        self.applyMusicPlayback();
    }

    pub fn setMusicVolume(self: *AudioState, volume: f32) void {
        self.music_volume = clamp(volume, 0.0, 1.0);
        if (self.music_ready) {
            rl.SetMusicVolume(self.music, self.music_volume);
        }
    }

    pub fn selectMusic(self: *AudioState, index: usize) void {
        if (index >= self.track_count) return;
        self.unloadMusic();
        self.selected_music = index;
        const len = self.track_path_lens[index];
        if (len == 0 or len >= music_path_bytes) return;
        self.music = rl.LoadMusicStream(self.track_paths[index][0..len :0].ptr);
        self.music_ready = rl.IsMusicValid(self.music);
        if (!self.music_ready) return;
        self.music.looping = true;
        rl.SetMusicVolume(self.music, self.music_volume);
        self.applyMusicPlayback();
    }

    pub fn currentMusicLabel(self: *const AudioState) [*:0]const u8 {
        if (self.track_count == 0 or self.selected_music >= self.track_count) return "No .ogg tracks found";
        const len = self.track_label_lens[self.selected_music];
        return self.track_labels[self.selected_music][0..len :0].ptr;
    }

    pub fn update(self: *AudioState, mode: AudioMode, throttle: f32, fuel_kg: f64) void {
        if (!self.ready or self.muted) return;

        if (self.music_ready) {
            if (self.music_enabled) {
                if (!rl.IsMusicStreamPlaying(self.music)) {
                    rl.PlayMusicStream(self.music);
                }
                rl.SetMusicVolume(self.music, self.music_volume);
                rl.UpdateMusicStream(self.music);
            } else if (rl.IsMusicStreamPlaying(self.music)) {
                rl.PauseMusicStream(self.music);
            }
        }

        rl.SetAudioStreamVolume(self.stream, 1.0);
        while (rl.IsAudioStreamProcessed(self.stream)) {
            self.fillStream(mode, throttle, fuel_kg);
            rl.UpdateAudioStream(self.stream, &self.pcm, @as(c_int, @intCast(config.audio_frames)));
        }
    }

    fn fillStream(self: *AudioState, mode: AudioMode, throttle: f32, fuel_kg: f64) void {
        const title_melody = [_]f32{ 261.63, 329.63, 392.00, 523.25, 392.00, 329.63, 293.66, 329.63, 261.63, 349.23, 440.00, 587.33, 523.25, 440.00, 392.00, 329.63 };
        const town_melody = [_]f32{ 392.00, 440.00, 523.25, 659.25, 587.33, 523.25, 440.00, 392.00, 329.63, 392.00, 440.00, 493.88, 523.25, 493.88, 440.00, 392.00 };
        const hangar_melody = [_]f32{ 146.83, 174.61, 220.00, 261.63, 220.00, 174.61, 196.00, 220.00, 164.81, 196.00, 246.94, 293.66, 246.94, 220.00, 196.00, 174.61 };
        const launch_melody = [_]f32{ 220.00, 277.18, 329.63, 415.30, 440.00, 415.30, 329.63, 277.18, 246.94, 311.13, 369.99, 466.16, 493.88, 466.16, 369.99, 311.13 };
        const bass_notes = [_]f32{ 55.00, 55.00, 73.42, 82.41, 65.41, 65.41, 49.00, 55.00 };

        const dt: f32 = 1.0 / @as(f32, @floatFromInt(config.sample_rate));
        var i: usize = 0;
        while (i < config.audio_frames) : (i += 1) {
            const tempo: f32 = switch (mode) {
                .launch => 3.15,
                .town => 2.25,
                .hangar => 2.05,
                .title => 2.60,
            };
            self.song_time += dt;
            const step = @as(usize, @intFromFloat(self.song_time * tempo * 4.0)) & 15;
            const beat = @as(usize, @intFromFloat(self.song_time * tempo)) & 7;
            const local = fract(self.song_time * tempo * 4.0);
            var env = 1.0 - local;
            env *= env;

            const melody = switch (mode) {
                .title => &title_melody,
                .town => &town_melody,
                .hangar => &hangar_melody,
                .launch => &launch_melody,
            };

            const octave: f32 = if ((step & 3) == 3) @as(f32, 2.0) else @as(f32, 1.0);
            const melody_hz = melody[step] * octave;
            const bass_scale: f32 = if (mode == .launch) @as(f32, 0.75) else @as(f32, 1.0);
            const arp_scale: f32 = if ((beat & 1) != 0) @as(f32, 1.5) else @as(f32, 0.75);
            const bass_hz = bass_notes[beat] * bass_scale;
            const arp_hz = melody[(step + beat) & 15] * arp_scale;

            self.melody_phase = wrapPhase(self.melody_phase + melody_hz * dt);
            self.bass_phase = wrapPhase(self.bass_phase + bass_hz * dt);
            self.arp_phase = wrapPhase(self.arp_phase + arp_hz * dt);
            self.pad_phase = wrapPhase(self.pad_phase + (bass_hz * 0.5) * dt);

            var music = square(self.melody_phase) * 0.040 * env;
            music += triangle(self.arp_phase) * 0.030 * (0.35 + env * 0.65);
            music += @sin(self.pad_phase * tau) * 0.045;
            music += square(self.bass_phase) * 0.050;

            var sfx: f32 = 0.0;
            const beat_phase = fract(self.song_time * tempo);
            if (beat_phase < 0.16) {
                const k = 1.0 - beat_phase / 0.16;
                sfx += @sin((beat_phase * (62.0 + 170.0 * k)) * tau) * k * k * 0.22;
            }
            const snare_phase = fract(self.song_time * tempo + 0.5);
            if (snare_phase < 0.08 and (beat & 1) != 0) {
                const s = 1.0 - snare_phase / 0.08;
                sfx += self.noise() * s * 0.070;
            }

            if (mode == .launch and throttle > 0.01 and fuel_kg > 0.0) {
                const thrust = clamp(throttle, 0.0, 1.0);
                const rumble = @sin(self.song_time * tau * (19.0 + thrust * 11.0));
                sfx += self.noise() * 0.18 * thrust + rumble * 0.10 * thrust;
            }
            if (self.beep_time > 0.0) {
                self.beep_phase = wrapPhase(self.beep_phase + self.beep_hz * dt);
                sfx += @sin(self.beep_phase * tau) * (self.beep_time * 2.8);
                self.beep_time -= dt;
            }
            if (self.ignition_time > 0.0) {
                const k = clamp(self.ignition_time / 1.35, 0.0, 1.0);
                const grow = 1.0 - k;
                sfx += self.noise() * (0.08 + grow * 0.30);
                sfx += @sin(self.song_time * tau * (28.0 - grow * 14.0)) * grow * 0.26;
                self.ignition_time -= dt;
            }
            if (self.explosion_time > 0.0) {
                const k = clamp(self.explosion_time / 0.82, 0.0, 1.0);
                const boom = k * k;
                sfx += self.noise() * boom * 0.38;
                sfx += @sin(self.song_time * tau * (38.0 + 90.0 * k)) * boom * 0.28;
                self.explosion_time -= dt;
            }

            const procedural_music_gain: f32 = if (!self.music_enabled or self.music_ready) 0.0 else self.music_volume;
            var mixed = music * procedural_music_gain + sfx * self.sfx_volume;
            mixed = clamp(mixed, -0.95, 0.95);
            const sample = @as(i16, @intFromFloat(mixed * 32767.0));
            self.pcm[i * 2] = sample;
            self.pcm[i * 2 + 1] = sample;
        }
    }

    fn noise(self: *AudioState) f32 {
        self.noise_seed = self.noise_seed *% 1664525 +% 1013904223;
        const value = @as(f32, @floatFromInt((self.noise_seed >> 9) & 0x7fff)) / 16383.5;
        return value - 1.0;
    }

    fn applyMusicPlayback(self: *AudioState) void {
        if (!self.music_ready) return;
        if (self.music_enabled) {
            rl.ResumeMusicStream(self.music);
            if (!rl.IsMusicStreamPlaying(self.music)) {
                rl.PlayMusicStream(self.music);
            }
        } else {
            rl.PauseMusicStream(self.music);
        }
    }

    fn unloadMusic(self: *AudioState) void {
        if (!self.music_ready) return;
        rl.StopMusicStream(self.music);
        rl.UnloadMusicStream(self.music);
        self.music_ready = false;
    }

    fn scanMusicTracks(self: *AudioState) void {
        self.track_count = 0;
        for (music_dirs) |dir| {
            if (!rl.DirectoryExists(dir)) continue;
            const files = rl.LoadDirectoryFilesEx(dir, ".ogg", true);
            defer rl.UnloadDirectoryFiles(files);
            var i: usize = 0;
            while (i < files.count and self.track_count < max_music_tracks) : (i += 1) {
                self.addTrackFromCString(files.paths[i]);
            }
        }
    }

    fn addTrackFromCString(self: *AudioState, path: [*c]const u8) void {
        if (path == null or self.track_count >= max_music_tracks) return;
        const path_bytes = std.mem.span(path);
        if (path_bytes.len == 0 or path_bytes.len >= music_path_bytes) return;
        if (self.hasTrack(path_bytes)) return;
        const index = self.track_count;
        self.track_path_lens[index] = copyZ(music_path_bytes, &self.track_paths[index], path_bytes);
        const raw_label = std.mem.span(rl.GetFileNameWithoutExt(path));
        self.track_label_lens[index] = copyZ(music_label_bytes, &self.track_labels[index], raw_label);
        self.track_count += 1;
    }

    fn hasTrack(self: *const AudioState, path: []const u8) bool {
        var i: usize = 0;
        while (i < self.track_count) : (i += 1) {
            if (std.mem.eql(u8, self.track_paths[i][0..self.track_path_lens[i]], path)) return true;
        }
        return false;
    }
};

fn copyZ(comptime capacity: usize, dest: *[capacity]u8, source: []const u8) usize {
    const len = @min(source.len, capacity - 1);
    @memcpy(dest[0..len], source[0..len]);
    dest[len] = 0;
    if (len + 1 < capacity) {
        @memset(dest[len + 1 ..], 0);
    }
    return len;
}

fn fract(value: f32) f32 {
    return value - @floor(value);
}

fn wrapPhase(phase: f32) f32 {
    var p = phase;
    if (p >= 1.0) p -= @floor(p);
    if (p < 0.0) p += 1.0;
    return p;
}

fn square(phase: f32) f32 {
    return if (phase < 0.5) 1.0 else -1.0;
}

fn triangle(phase: f32) f32 {
    return 4.0 * @abs(phase - 0.5) - 1.0;
}

fn clamp(value: f32, lo: f32, hi: f32) f32 {
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
}

test "audio state keeps a fixed pcm buffer" {
    const audio = AudioState.zero();
    try std.testing.expectEqual(pcm_len, audio.pcm.len);
}
