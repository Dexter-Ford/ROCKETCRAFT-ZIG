const std = @import("std");

pub const max_parts: usize = 16;

pub const Required = struct {
    pub const command: u32 = 1 << 0;
    pub const service: u32 = 1 << 1;
    pub const propulsion: u32 = 1 << 2;
    pub const fuel: u32 = 1 << 3;
    pub const lander: u32 = 1 << 4;
    pub const heat: u32 = 1 << 5;
    pub const life: u32 = 1 << 6;
    pub const nav: u32 = 1 << 7;
    pub const all: u32 = command | service | propulsion | fuel | lander | heat | life | nav;
};

pub const PartKind = enum(u8) {
    command_pod,
    service_module,
    fuel_tank,
    basic_engine,
    landing_leg,
    heat_shield,
    life_support,
    navigation,
};

pub const PartSpec = struct {
    name: [*:0]const u8,
    short_name: [*:0]const u8,
    mass_kg: f64,
    cost: i32,
    fuel_kg: f64,
    thrust_n: f64,
    isp_s: f64,
    required_mask: u32,
};

pub const Stack = struct {
    items: [max_parts]PartKind,
    count: usize,

    pub fn init() Stack {
        return .{
            .items = [_]PartKind{.command_pod} ** max_parts,
            .count = 0,
        };
    }

    pub fn clear(self: *Stack) void {
        self.count = 0;
    }

    pub fn add(self: *Stack, kind: PartKind) bool {
        if (self.count >= max_parts) return false;
        self.items[self.count] = kind;
        self.count += 1;
        return true;
    }

    pub fn removeLast(self: *Stack) ?PartKind {
        if (self.count == 0) return null;
        self.count -= 1;
        return self.items[self.count];
    }
};

pub fn spec(kind: PartKind) PartSpec {
    return switch (kind) {
        .command_pod => .{
            .name = "Command Pod",
            .short_name = "POD",
            .mass_kg = 500.0,
            .cost = 5_000,
            .fuel_kg = 0.0,
            .thrust_n = 0.0,
            .isp_s = 0.0,
            .required_mask = Required.command,
        },
        .service_module => .{
            .name = "Starter Service Module",
            .short_name = "SRV",
            .mass_kg = 260.0,
            .cost = 7_500,
            .fuel_kg = 0.0,
            .thrust_n = 0.0,
            .isp_s = 0.0,
            .required_mask = Required.service,
        },
        .fuel_tank => .{
            .name = "Small Fuel Tank",
            .short_name = "FUEL",
            .mass_kg = 300.0,
            .cost = 2_000,
            .fuel_kg = 500.0,
            .thrust_n = 0.0,
            .isp_s = 0.0,
            .required_mask = Required.fuel,
        },
        .basic_engine => .{
            .name = "Basic Engine",
            .short_name = "ENG",
            .mass_kg = 200.0,
            .cost = 8_000,
            .fuel_kg = 0.0,
            .thrust_n = 150_000.0,
            .isp_s = 280.0,
            .required_mask = Required.propulsion,
        },
        .landing_leg => .{
            .name = "Landing Leg",
            .short_name = "LEG",
            .mass_kg = 100.0,
            .cost = 1_000,
            .fuel_kg = 0.0,
            .thrust_n = 0.0,
            .isp_s = 0.0,
            .required_mask = Required.lander,
        },
        .heat_shield => .{
            .name = "Ablative Heat Shield",
            .short_name = "HEAT",
            .mass_kg = 180.0,
            .cost = 6_500,
            .fuel_kg = 0.0,
            .thrust_n = 0.0,
            .isp_s = 0.0,
            .required_mask = Required.heat,
        },
        .life_support => .{
            .name = "Life Support Canister",
            .short_name = "LIFE",
            .mass_kg = 140.0,
            .cost = 5_500,
            .fuel_kg = 0.0,
            .thrust_n = 0.0,
            .isp_s = 0.0,
            .required_mask = Required.life,
        },
        .navigation => .{
            .name = "Radio Guidance Unit",
            .short_name = "NAV",
            .mass_kg = 75.0,
            .cost = 4_800,
            .fuel_kg = 0.0,
            .thrust_n = 0.0,
            .isp_s = 0.0,
            .required_mask = Required.nav,
        },
    };
}

pub fn totalMass(stack: *const Stack) f64 {
    var mass: f64 = 0.0;
    for (0..stack.count) |i| {
        const part = spec(stack.items[i]);
        mass += part.mass_kg + part.fuel_kg;
    }
    return mass;
}

pub fn totalCost(stack: *const Stack) i32 {
    var cost: i32 = 0;
    for (0..stack.count) |i| {
        cost += spec(stack.items[i]).cost;
    }
    return cost;
}

pub fn requiredMask(stack: *const Stack) u32 {
    var mask: u32 = 0;
    for (0..stack.count) |i| {
        mask |= spec(stack.items[i]).required_mask;
    }
    return mask;
}

pub fn hasKind(stack: *const Stack, kind: PartKind) bool {
    for (0..stack.count) |i| {
        if (stack.items[i] == kind) return true;
    }
    return false;
}

pub fn isLaunchable(stack: *const Stack) bool {
    if (stack.count < 3) return false;
    if (!hasKind(stack, .command_pod)) return false;
    if (!hasKind(stack, .fuel_tank)) return false;
    if (!hasKind(stack, .basic_engine)) return false;
    return stack.items[stack.count - 1] == .basic_engine;
}

pub fn loadStarterPreset(stack: *Stack) void {
    stack.clear();
    _ = stack.add(.command_pod);
    _ = stack.add(.navigation);
    _ = stack.add(.life_support);
    _ = stack.add(.heat_shield);
    _ = stack.add(.service_module);
    _ = stack.add(.fuel_tank);
    _ = stack.add(.landing_leg);
    _ = stack.add(.basic_engine);
}

pub fn addMissing(stack: *Stack) void {
    if (!hasKind(stack, .command_pod)) _ = stack.add(.command_pod);
    if (!hasKind(stack, .navigation)) _ = stack.add(.navigation);
    if (!hasKind(stack, .life_support)) _ = stack.add(.life_support);
    if (!hasKind(stack, .heat_shield)) _ = stack.add(.heat_shield);
    if (!hasKind(stack, .service_module)) _ = stack.add(.service_module);
    if (!hasKind(stack, .fuel_tank)) _ = stack.add(.fuel_tank);
    if (!hasKind(stack, .landing_leg)) _ = stack.add(.landing_leg);
    if (!hasKind(stack, .basic_engine)) _ = stack.add(.basic_engine);
    repairOrder(stack);
}

pub fn repairOrder(stack: *Stack) void {
    var out = Stack.init();
    const order = [_]PartKind{
        .command_pod,
        .navigation,
        .life_support,
        .heat_shield,
        .service_module,
        .fuel_tank,
        .landing_leg,
        .basic_engine,
    };

    for (order) |kind| {
        for (0..stack.count) |i| {
            if (stack.items[i] == kind) _ = out.add(kind);
        }
    }
    stack.* = out;
}

test "starter preset is launchable and has all mission categories" {
    var stack = Stack.init();
    loadStarterPreset(&stack);
    try std.testing.expect(isLaunchable(&stack));
    try std.testing.expectEqual(Required.all, requiredMask(&stack));
}
