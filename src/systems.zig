const std = @import("std");
const config = @import("config.zig");
const physics = @import("physics.zig");
const rocket_mod = @import("rocket.zig");

pub const npc_count: usize = 4;

pub const StoryFlags = struct {
    pub const intro_done: u32 = 1 << 0;
    pub const first_launch_done: u32 = 1 << 1;
    pub const orbit_achieved: u32 = 1 << 2;
    pub const bob_secret_funds: u32 = 1 << 3;
    pub const jenkins_secret: u32 = 1 << 4;
};

pub const TimeSystem = struct {
    day: i32,
    hour: i32,
    minute: f32,
    time_speed: f32,
    day_length_seconds: f32,
    paused: bool,

    pub fn init() TimeSystem {
        return .{
            .day = 1,
            .hour = 6,
            .minute = 0.0,
            .time_speed = 1.0,
            .day_length_seconds = 600.0,
            .paused = false,
        };
    }

    pub fn update(self: *TimeSystem, dt: f32) bool {
        if (self.paused) return false;
        const day_span_minutes: f32 = 20.0 * 60.0;
        const minutes_per_second = day_span_minutes / @max(60.0, self.day_length_seconds);
        self.minute += dt * minutes_per_second * self.time_speed;
        var rolled = false;
        while (self.minute >= 60.0) {
            self.minute -= 60.0;
            self.hour += 1;
            if (self.hour >= 24) self.hour -= 24;
            if (self.hour == 2) {
                self.startNextDay();
                rolled = true;
                break;
            }
        }
        return rolled;
    }

    pub fn startNextDay(self: *TimeSystem) void {
        self.day += 1;
        self.hour = 6;
        self.minute = 0.0;
    }

    pub fn lightLevel(self: *const TimeSystem) f32 {
        if (self.hour >= 6 and self.hour < 12) {
            return (@as(f32, @floatFromInt(self.hour - 6)) + self.minute / 60.0) / 6.0;
        }
        if (self.hour >= 12 and self.hour < 18) {
            return 1.0 - (@as(f32, @floatFromInt(self.hour - 12)) + self.minute / 60.0) / 6.0;
        }
        return 0.2;
    }
};

pub const MissionFlags = struct {
    pub const liftoff: u32 = 1 << 0;
    pub const tower_clear: u32 = 1 << 1;
    pub const mach_one: u32 = 1 << 2;
    pub const thin_air: u32 = 1 << 3;
    pub const space: u32 = 1 << 4;
    pub const orbit: u32 = 1 << 5;
};

pub const MissionResult = struct {
    newly_completed: u32,
    reward: i32,
    primary_name: [*:0]const u8,
};

pub const MissionTracker = struct {
    completed: u32,
    funds: i32,

    pub fn init() MissionTracker {
        return .{ .completed = 0, .funds = 0 };
    }

    pub fn reset(self: *MissionTracker) void {
        self.completed = 0;
        self.funds = 0;
    }

    pub fn update(self: *MissionTracker, r: *const rocket_mod.Rocket, body: *const physics.Body, orbit: physics.OrbitInfo) MissionResult {
        const altitude = r.altitude(body.radius_m);
        const speed = r.speed();
        var newly: u32 = 0;
        var reward: i32 = 0;
        var name: [*:0]const u8 = "";

        self.check(MissionFlags.liftoff, altitude > 5.0 and speed > 1.0, "Liftoff", 1_000, &newly, &reward, &name);
        self.check(MissionFlags.tower_clear, altitude >= 100.0, "Tower Clear", 1_500, &newly, &reward, &name);
        self.check(MissionFlags.mach_one, speed >= 343.0, "Mach 1", 3_000, &newly, &reward, &name);
        self.check(MissionFlags.thin_air, altitude >= 10_000.0, "Thin Air", 5_000, &newly, &reward, &name);
        self.check(MissionFlags.space, altitude >= body.atmosphere_m, "Space", 15_000, &newly, &reward, &name);
        self.check(MissionFlags.orbit, orbit.bound and orbit.periapsis_altitude_m > body.atmosphere_m, "Orbit", 50_000, &newly, &reward, &name);

        self.funds += reward;
        return .{ .newly_completed = newly, .reward = reward, .primary_name = name };
    }

    fn check(self: *MissionTracker, flag: u32, condition: bool, name: [*:0]const u8, amount: i32, newly: *u32, reward: *i32, primary_name: *[*:0]const u8) void {
        if ((self.completed & flag) != 0 or !condition) return;
        self.completed |= flag;
        newly.* |= flag;
        reward.* += amount;
        if (primary_name.*[0] == 0) primary_name.* = name;
    }
};

pub const AchievementFlags = struct {
    pub const first_launch: u32 = 1 << 0;
    pub const first_orbit: u32 = 1 << 1;
    pub const rich: u32 = 1 << 2;
    pub const veteran: u32 = 1 << 3;
    pub const high_morale: u32 = 1 << 4;
};

pub const AchievementResult = struct {
    unlocked: u32,
    reward: i32,
    name: [*:0]const u8,
};

pub const AchievementSystem = struct {
    unlocked: u32,
    launch_count: u32,
    orbit_count: u32,

    pub fn init() AchievementSystem {
        return .{ .unlocked = 0, .launch_count = 0, .orbit_count = 0 };
    }

    pub fn checkLaunch(self: *AchievementSystem) AchievementResult {
        self.launch_count += 1;
        return self.unlock(AchievementFlags.first_launch, "Lift Off!", 500);
    }

    pub fn checkOrbit(self: *AchievementSystem) AchievementResult {
        self.orbit_count += 1;
        return self.unlock(AchievementFlags.first_orbit, "Around We Go", 2_000);
    }

    pub fn checkSession(self: *AchievementSystem, money: i32, day: i32, npc_morale: *const [npc_count]i32) AchievementResult {
        if (money >= 100_000) {
            const result = self.unlock(AchievementFlags.rich, "Space Tycoon", 0);
            if (result.unlocked != 0) return result;
        }
        if (day >= 112) {
            const result = self.unlock(AchievementFlags.veteran, "Veteran Director", 0);
            if (result.unlocked != 0) return result;
        }
        var high = true;
        for (npc_morale) |value| {
            if (value < 10) {
                high = false;
                break;
            }
        }
        if (high) return self.unlock(AchievementFlags.high_morale, "Dream Team", 0);
        return .{ .unlocked = 0, .reward = 0, .name = "" };
    }

    fn unlock(self: *AchievementSystem, flag: u32, name: [*:0]const u8, reward: i32) AchievementResult {
        if ((self.unlocked & flag) != 0) {
            return .{ .unlocked = 0, .reward = 0, .name = "" };
        }
        self.unlocked |= flag;
        return .{ .unlocked = flag, .reward = reward, .name = name };
    }
};

pub const StoryState = struct {
    flags: u32,
    reputation: i32,
    research_points: i32,
    npc_morale: [npc_count]i32,

    pub fn init() StoryState {
        return .{
            .flags = StoryFlags.intro_done,
            .reputation = 0,
            .research_points = 0,
            .npc_morale = [_]i32{ 5, 5, 5, 5 },
        };
    }

    pub fn applyNewDay(self: *StoryState, time: *const TimeSystem, money: *i32) [*:0]const u8 {
        if (time.day == 2 and (self.flags & StoryFlags.bob_secret_funds) == 0 and money.* < 10_000) {
            self.flags |= StoryFlags.bob_secret_funds;
            money.* += 5_000;
            self.adjustMorale(1, 1);
            return "Bob left emergency hangar funds. +$5,000";
        }
        if (time.day == 5 and (self.flags & StoryFlags.jenkins_secret) == 0) {
            self.flags |= StoryFlags.jenkins_secret;
            self.research_points += 1;
            self.adjustMorale(3, 1);
            return "Jenkins shared an old guidance note. +1 research";
        }
        return "";
    }

    pub fn markOrbit(self: *StoryState) void {
        self.flags |= StoryFlags.orbit_achieved;
        self.reputation += 3;
        self.research_points += 5;
    }

    fn adjustMorale(self: *StoryState, npc_index: usize, delta: i32) void {
        if (npc_index >= npc_count) return;
        self.npc_morale[npc_index] = std.math.clamp(self.npc_morale[npc_index] + delta, 0, 10);
    }
};

test "mission tracker completes early launch milestones" {
    var tracker = MissionTracker.init();
    var r = rocket_mod.Rocket.init(config.earth_radius_m);
    r.x += 120.0;
    r.vx = 10.0;
    const result = tracker.update(&r, &physics.earth, .{});
    try std.testing.expect((result.newly_completed & MissionFlags.liftoff) != 0);
    try std.testing.expect((result.newly_completed & MissionFlags.tower_clear) != 0);
}
