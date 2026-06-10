const std = @import("std");
const config = @import("config.zig");
const parts = @import("parts.zig");

pub const VesselFlags = struct {
    pub const thrusting: u32 = 1 << 0;
    pub const in_atmosphere: u32 = 1 << 1;
    pub const landed: u32 = 1 << 2;
    pub const out_of_fuel: u32 = 1 << 3;
    pub const crashed: u32 = 1 << 4;
    pub const orbit: u32 = 1 << 5;
};

pub const Vec2 = struct {
    x: f64,
    y: f64,

    pub fn length(self: Vec2) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
};

pub const Rocket = struct {
    x: f64,
    y: f64,
    vx: f64,
    vy: f64,
    throttle: f64,
    angle_deg: f64,
    dry_mass_kg: f64,
    fuel_kg: f64,
    fuel_capacity_kg: f64,
    max_thrust_n: f64,
    weighted_isp: f64,
    flags: u32,

    pub fn init(planet_radius_m: f64) Rocket {
        return .{
            .x = planet_radius_m,
            .y = 0.0,
            .vx = 0.0,
            .vy = 0.0,
            .throttle = 0.0,
            .angle_deg = 0.0,
            .dry_mass_kg = 0.0,
            .fuel_kg = 0.0,
            .fuel_capacity_kg = 0.0,
            .max_thrust_n = 0.0,
            .weighted_isp = 0.0,
            .flags = VesselFlags.landed,
        };
    }

    pub fn mass(self: *const Rocket) f64 {
        return self.dry_mass_kg + self.fuel_kg;
    }

    pub fn speed(self: *const Rocket) f64 {
        return @sqrt(self.vx * self.vx + self.vy * self.vy);
    }

    pub fn altitude(self: *const Rocket, planet_radius_m: f64) f64 {
        return @sqrt(self.x * self.x + self.y * self.y) - planet_radius_m;
    }

    pub fn isp(self: *const Rocket) f64 {
        if (self.max_thrust_n <= 0.0) return 0.0;
        return self.weighted_isp / self.max_thrust_n;
    }

    pub fn fuelPercent(self: *const Rocket) f64 {
        if (self.fuel_capacity_kg <= 0.0) return 0.0;
        return clamp(self.fuel_kg / self.fuel_capacity_kg, 0.0, 1.0) * 100.0;
    }
};

pub fn buildFromStack(stack: *const parts.Stack, planet_radius_m: f64) Rocket {
    var r = Rocket.init(planet_radius_m);
    for (0..stack.count) |i| {
        const part = parts.spec(stack.items[i]);
        r.dry_mass_kg += part.mass_kg;
        r.fuel_kg += part.fuel_kg;
        r.fuel_capacity_kg += part.fuel_kg;
        r.max_thrust_n += part.thrust_n;
        r.weighted_isp += part.thrust_n * part.isp_s;
    }
    return r;
}

pub fn update(r: *Rocket, dt: f64, planet_radius_m: f64) void {
    const current_mass = r.mass();
    if (dt <= 0.0 or current_mass <= 0.0) return;

    r.throttle = clamp(r.throttle, 0.0, 1.0);
    r.flags &= ~(VesselFlags.thrusting | VesselFlags.out_of_fuel);

    const thrust = r.max_thrust_n * r.throttle;
    if (thrust > 0.0) {
        if (r.fuel_kg > 0.0 and r.isp() > 0.0) {
            const radial_len = @max(@sqrt(r.x * r.x + r.y * r.y), 1.0);
            const radial_x = r.x / radial_len;
            const radial_y = r.y / radial_len;
            const angle = degreesToRadians(r.angle_deg);
            const cos_a = @cos(angle);
            const sin_a = @sin(angle);
            const dir_x = radial_x * cos_a - radial_y * sin_a;
            const dir_y = radial_x * sin_a + radial_y * cos_a;
            const accel_dt = thrust / current_mass * dt;

            r.vx += dir_x * accel_dt;
            r.vy += dir_y * accel_dt;

            const fuel_need = thrust / (r.isp() * config.g0_mps2) * dt;
            r.fuel_kg = @max(0.0, r.fuel_kg - fuel_need);
            r.flags |= VesselFlags.thrusting;
            if (r.fuel_kg <= 0.000001) {
                r.fuel_kg = 0.0;
                r.flags |= VesselFlags.out_of_fuel;
            }
        } else {
            r.throttle = 0.0;
            r.flags |= VesselFlags.out_of_fuel;
        }
    }

    r.x += r.vx * dt;
    r.y += r.vy * dt;

    const dist2 = r.x * r.x + r.y * r.y;
    if (dist2 < planet_radius_m * planet_radius_m) {
        const dist = @max(@sqrt(dist2), 1.0);
        const scale = planet_radius_m / dist;
        r.x *= scale;
        r.y *= scale;

        const nx = r.x / planet_radius_m;
        const ny = r.y / planet_radius_m;
        const radial_v = r.vx * nx + r.vy * ny;
        if (radial_v < 0.0) {
            r.vx -= radial_v * nx;
            r.vy -= radial_v * ny;
        }
        r.flags |= VesselFlags.landed;
    } else {
        r.flags &= ~VesselFlags.landed;
    }
}

pub fn clamp(value: f64, lo: f64, hi: f64) f64 {
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
}

pub fn degreesToRadians(value: f64) f64 {
    return value * 0.017453292519943295;
}

test "rocket builds from static stack without heap allocation" {
    var stack = parts.Stack.init();
    parts.loadStarterPreset(&stack);
    const r = buildFromStack(&stack, config.earth_radius_m);
    try std.testing.expect(r.mass() > 0.0);
    try std.testing.expect(r.max_thrust_n > 0.0);
    try std.testing.expect(r.fuel_kg > 0.0);
}
