const std = @import("std");
const config = @import("config.zig");
const map_mod = @import("map.zig");
const systems = @import("systems.zig");

pub const npc_count: usize = 4;

pub const NpcFlags = struct {
    pub const facing_right: u32 = 1 << 0;
    pub const moving: u32 = 1 << 1;
    pub const active: u32 = 1 << 2;
};

pub const NpcKind = enum(u8) {
    chen,
    bob,
    maria,
    jenkins,
};

pub const Player = struct {
    x: f32,
    y: f32,
    target_x: f32,
    target_y: f32,
    speed: f32,

    pub fn init() Player {
        return .{ .x = 820.0, .y = 700.0, .target_x = 820.0, .target_y = 700.0, .speed = 120.0 };
    }
};

pub const Npc = struct {
    name: [*:0]const u8,
    role: [*:0]const u8,
    kind: NpcKind,
    x: f32,
    y: f32,
    target_x: f32,
    target_y: f32,
    work_x: f32,
    work_y: f32,
    home_x: f32,
    home_y: f32,
    evening_x: f32,
    evening_y: f32,
    color_r: u8,
    color_g: u8,
    color_b: u8,
    wait_time: f32,
    walk_frame: u8,
    anim_timer: f32,
    flags: u32,
    rng: u32,
};

pub const PeopleSystem = struct {
    player: Player,
    npcs: [npc_count]Npc,
    camera_x: f32,
    camera_y: f32,
    current_zone: map_mod.ZoneId,
    schedule_hour: i32,

    pub fn init() PeopleSystem {
        var people = PeopleSystem{
            .player = Player.init(),
            .npcs = [_]Npc{
                makeNpc("Dr. Chen", "Scientist", .chen, 1296, 712, 1296, 712, 1510, 848, 890, 725, 110, 210, 255, 1),
                makeNpc("Bob", "Engineer", .bob, 260, 780, 250, 780, 1330, 1000, 785, 745, 255, 170, 70, 2),
                makeNpc("Maria", "Mission Control", .maria, 725, 668, 725, 668, 1015, 678, 840, 735, 255, 110, 150, 3),
                makeNpc("Old Man Jenkins", "Old Man Jenkins", .jenkins, 835, 825, 900, 750, 368, 930, 900, 750, 180, 170, 140, 4),
            },
            .camera_x = 0.0,
            .camera_y = 0.0,
            .current_zone = .plaza,
            .schedule_hour = -1,
        };
        people.updateCamera();
        return people;
    }

    pub fn update(self: *PeopleSystem, town: *const map_mod.TownMap, time: *const systems.TimeSystem, story: *const systems.StoryState, dt: f32) void {
        self.updatePlayer(town, dt);
        self.updateSchedules(town, time, story);
        for (0..npc_count) |i| {
            updateNpc(&self.npcs[i], town, dt);
        }
        self.current_zone = town.zoneAt(self.player.x, self.player.y);
        self.updateCamera();
    }

    pub fn setPlayerTarget(self: *PeopleSystem, town: *const map_mod.TownMap, x: f32, y: f32) bool {
        if (!town.isWalkable(x, y)) return false;
        self.player.target_x = x;
        self.player.target_y = y;
        return true;
    }

    pub fn movePlayerDirect(self: *PeopleSystem, town: *const map_mod.TownMap, input_x: f32, input_y: f32, dt: f32) bool {
        const len2 = input_x * input_x + input_y * input_y;
        if (len2 <= 0.0001 or dt <= 0.0) return false;

        const inv_len = 1.0 / @sqrt(len2);
        const step_x = input_x * inv_len * self.player.speed * dt;
        const step_y = input_y * inv_len * self.player.speed * dt;
        var moved = false;

        const next_x = self.player.x + step_x;
        if (town.isWalkable(next_x, self.player.y)) {
            self.player.x = next_x;
            moved = true;
        }

        const next_y = self.player.y + step_y;
        if (town.isWalkable(self.player.x, next_y)) {
            self.player.y = next_y;
            moved = true;
        }

        if (moved) {
            self.player.target_x = self.player.x;
            self.player.target_y = self.player.y;
        }
        return moved;
    }

    pub fn nearestNpc(self: *const PeopleSystem, max_distance: f32) ?usize {
        var best: ?usize = null;
        var best_d2 = max_distance * max_distance;
        for (0..npc_count) |i| {
            const dx = self.npcs[i].x - self.player.x;
            const dy = self.npcs[i].y - self.player.y;
            const d2 = dx * dx + dy * dy;
            if (d2 <= best_d2) {
                best_d2 = d2;
                best = i;
            }
        }
        return best;
    }

    pub fn npcAt(self: *const PeopleSystem, world_x: f32, world_y: f32) ?usize {
        for (0..npc_count) |i| {
            const dx = self.npcs[i].x - world_x;
            const dy = self.npcs[i].y - world_y;
            if (dx * dx + dy * dy <= 18.0 * 18.0) return i;
        }
        return null;
    }

    pub fn screenToWorld(self: *const PeopleSystem, sx: f32, sy: f32) map_mod.Vec2f {
        return .{ .x = sx + self.camera_x, .y = sy + self.camera_y };
    }

    pub fn worldToScreen(self: *const PeopleSystem, wx: f32, wy: f32) map_mod.Vec2f {
        return .{ .x = wx - self.camera_x, .y = wy - self.camera_y };
    }

    fn updatePlayer(self: *PeopleSystem, town: *const map_mod.TownMap, dt: f32) void {
        const dx = self.player.target_x - self.player.x;
        const dy = self.player.target_y - self.player.y;
        const dist = @sqrt(dx * dx + dy * dy);
        if (dist < 2.0) return;
        const step = @min(dist, self.player.speed * dt);
        const nx = self.player.x + dx / dist * step;
        const ny = self.player.y + dy / dist * step;
        if (town.isWalkable(nx, ny)) {
            self.player.x = nx;
            self.player.y = ny;
        }
    }

    fn updateSchedules(self: *PeopleSystem, town: *const map_mod.TownMap, time: *const systems.TimeSystem, story: *const systems.StoryState) void {
        if (self.schedule_hour == time.hour) return;
        self.schedule_hour = time.hour;
        for (0..npc_count) |i| {
            const anchor = scheduleAnchor(&self.npcs[i], time, story);
            const target = town.clampToWalkable(anchor.x, anchor.y);
            self.npcs[i].target_x = target.x;
            self.npcs[i].target_y = target.y;
            self.npcs[i].wait_time = @min(self.npcs[i].wait_time, 0.4);
        }
    }

    fn updateCamera(self: *PeopleSystem) void {
        const target_x = self.player.x - @as(f32, @floatFromInt(config.screen_width)) * 0.5;
        const target_y = self.player.y - @as(f32, @floatFromInt(config.screen_height)) * 0.5;
        self.camera_x += (target_x - self.camera_x) * 0.16;
        self.camera_y += (target_y - self.camera_y) * 0.16;
        self.camera_x = std.math.clamp(self.camera_x, 0.0, map_mod.world_width - @as(f32, @floatFromInt(config.screen_width)));
        self.camera_y = std.math.clamp(self.camera_y, 0.0, map_mod.world_height - @as(f32, @floatFromInt(config.screen_height)));
    }
};

pub fn dialogueText(npc: *const Npc, time: *const systems.TimeSystem, story: *const systems.StoryState) [*:0]const u8 {
    return switch (npc.kind) {
        .chen => if ((story.flags & systems.StoryFlags.orbit_achieved) != 0)
            "Dr. Chen: The orbit plot finally looks clean. Keep the periapsis above the air."
        else
            "Dr. Chen: Build carefully. A good rocket starts as a good table of numbers.",
        .bob => if (time.hour < 9)
            "Bob: Coffee first, bolts second. That order saves lives."
        else
            "Bob: Engines like honesty. If it leaks, it is telling you something.",
        .maria => "Maria: Mission Control is listening. Give me good telemetry and I will give you calm.",
        .jenkins => if (story.research_points > 0)
            "Jenkins: Old notes still fly if you read them slowly."
        else
            "Jenkins: Measure twice, launch once. Then measure again because space is rude.",
    };
}

fn makeNpc(
    name: [*:0]const u8,
    role: [*:0]const u8,
    kind: NpcKind,
    x: f32,
    y: f32,
    work_x: f32,
    work_y: f32,
    home_x: f32,
    home_y: f32,
    evening_x: f32,
    evening_y: f32,
    r: u8,
    g: u8,
    b: u8,
    seed: u32,
) Npc {
    return .{
        .name = name,
        .role = role,
        .kind = kind,
        .x = x,
        .y = y,
        .target_x = x,
        .target_y = y,
        .work_x = work_x,
        .work_y = work_y,
        .home_x = home_x,
        .home_y = home_y,
        .evening_x = evening_x,
        .evening_y = evening_y,
        .color_r = r,
        .color_g = g,
        .color_b = b,
        .wait_time = 1.0 + @as(f32, @floatFromInt(seed)) * 0.35,
        .walk_frame = 0,
        .anim_timer = 0.0,
        .flags = NpcFlags.active | NpcFlags.facing_right,
        .rng = 0x1234abcd ^ seed,
    };
}

fn scheduleAnchor(npc: *const Npc, time: *const systems.TimeSystem, story: *const systems.StoryState) map_mod.Vec2f {
    const morale_index: usize = switch (npc.kind) {
        .chen => 0,
        .bob => 1,
        .maria => 2,
        .jenkins => 3,
    };
    const morale = story.npc_morale[morale_index];
    if (morale <= 1 and time.hour >= 8 and time.hour < 18) return .{ .x = npc.home_x, .y = npc.home_y };
    if (time.hour >= 8 and time.hour < 18) return .{ .x = npc.work_x, .y = npc.work_y };
    if (time.hour >= 18 and time.hour < 22) return .{ .x = npc.evening_x, .y = npc.evening_y };
    return .{ .x = npc.home_x, .y = npc.home_y };
}

fn updateNpc(npc: *Npc, town: *const map_mod.TownMap, dt: f32) void {
    if (npc.wait_time > 0.0) {
        npc.wait_time -= dt;
        npc.flags &= ~NpcFlags.moving;
        return;
    }

    const dx = npc.target_x - npc.x;
    const dy = npc.target_y - npc.y;
    const dist = @sqrt(dx * dx + dy * dy);
    if (dist < 5.0) {
        pickSmallWander(npc, town);
        npc.wait_time = 2.0 + random01(npc) * 3.0;
        npc.flags &= ~NpcFlags.moving;
        return;
    }

    if (@abs(dx) > 0.5) {
        if (dx > 0.0) npc.flags |= NpcFlags.facing_right else npc.flags &= ~NpcFlags.facing_right;
    }

    const speed: f32 = 58.0;
    const nx = npc.x + dx / dist * speed * dt;
    const ny = npc.y + dy / dist * speed * dt;
    if (town.isWalkable(nx, ny)) {
        npc.x = nx;
        npc.y = ny;
        npc.flags |= NpcFlags.moving;
        npc.anim_timer += dt;
        if (npc.anim_timer >= 0.12) {
            npc.anim_timer = 0.0;
            npc.walk_frame = (npc.walk_frame + 1) & 3;
        }
    } else {
        pickSmallWander(npc, town);
        npc.wait_time = 1.0 + random01(npc);
        npc.flags &= ~NpcFlags.moving;
    }
}

fn pickSmallWander(npc: *Npc, town: *const map_mod.TownMap) void {
    var attempts: usize = 0;
    while (attempts < 8) : (attempts += 1) {
        const ox = (random01(npc) - 0.5) * 90.0;
        const oy = (random01(npc) - 0.5) * 70.0;
        const tx = npc.target_x + ox;
        const ty = npc.target_y + oy;
        if (town.isWalkable(tx, ty)) {
            npc.target_x = tx;
            npc.target_y = ty;
            return;
        }
    }
}

fn random01(npc: *Npc) f32 {
    npc.rng = npc.rng *% 1664525 +% 1013904223;
    return @as(f32, @floatFromInt((npc.rng >> 8) & 0x00ff_ffff)) / 16_777_215.0;
}

test "people system keeps four npcs in static storage" {
    var people = PeopleSystem.init();
    const town = map_mod.TownMap.init();
    const start_x = people.player.x;

    try std.testing.expectEqual(npc_count, people.npcs.len);
    try std.testing.expect(people.player.x > 0.0);
    try std.testing.expect(people.movePlayerDirect(&town, 1.0, 0.0, 0.25));
    try std.testing.expect(people.player.x > start_x);
    try std.testing.expectEqual(people.player.x, people.player.target_x);
}
