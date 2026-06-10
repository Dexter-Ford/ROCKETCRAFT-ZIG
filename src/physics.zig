const std = @import("std");
const config = @import("config.zig");
const rocket_mod = @import("rocket.zig");

pub const max_orbit_points: usize = 96;

pub const OrbitInfo = struct {
    valid: bool = false,
    bound: bool = false,
    eccentricity: f64 = 0.0,
    specific_energy: f64 = 0.0,
    angular_momentum: f64 = 0.0,
    semi_major_axis_m: f64 = 0.0,
    apoapsis_m: f64 = 0.0,
    periapsis_m: f64 = 0.0,
    apoapsis_altitude_m: f64 = 0.0,
    periapsis_altitude_m: f64 = 0.0,
    period_s: f64 = 0.0,
};

pub const Body = struct {
    name: [*:0]const u8,
    mass_kg: f64,
    radius_m: f64,
    atmosphere_m: f64,

    pub fn mu(self: *const Body) f64 {
        return config.gravity_g * self.mass_kg;
    }
};

pub const earth = Body{
    .name = "Earth",
    .mass_kg = config.earth_mass,
    .radius_m = config.earth_radius_m,
    .atmosphere_m = config.earth_atmosphere_m,
};

pub fn step(r: *rocket_mod.Rocket, body: *const Body, dt: f64) void {
    if (dt <= 0.0) return;
    const steps: usize = 4;
    const h = dt / @as(f64, @floatFromInt(steps));

    for (0..steps) |_| {
        applyGravity(r, body, h);
        applyDrag(r, body, h);
        rocket_mod.update(r, h, body.radius_m);
    }

    if (isOrbit(r, body)) {
        r.flags |= rocket_mod.VesselFlags.orbit;
    }
}

pub fn applyGravity(r: *rocket_mod.Rocket, body: *const Body, dt: f64) void {
    const dist2 = r.x * r.x + r.y * r.y;
    const mass = r.mass();
    if (dist2 < 1.0 or mass <= 0.0) return;

    const dist = @sqrt(dist2);
    const accel = body.mu() / dist2;
    r.vx += -accel * r.x / dist * dt;
    r.vy += -accel * r.y / dist * dt;
}

pub fn applyDrag(r: *rocket_mod.Rocket, body: *const Body, dt: f64) void {
    const altitude_m = r.altitude(body.radius_m);
    const rho = atmosphereDensity(altitude_m, body.atmosphere_m);
    const speed2 = r.vx * r.vx + r.vy * r.vy;
    const mass = r.mass();
    if (rho <= 0.0 or speed2 < 0.01 or mass <= 0.0) return;

    const speed = @sqrt(speed2);
    const force = 0.5 * rho * speed2 * config.drag_coefficient * config.rocket_cross_section_m2;
    const accel_dt = force / mass * dt;
    r.vx -= accel_dt * r.vx / speed;
    r.vy -= accel_dt * r.vy / speed;
    r.flags |= rocket_mod.VesselFlags.in_atmosphere;
}

pub fn atmosphereDensity(altitude_m: f64, atmosphere_m: f64) f64 {
    if (altitude_m < 0.0 or atmosphere_m <= 0.0 or altitude_m > atmosphere_m * 3.0) {
        return 0.0;
    }
    return config.surface_air_density * @exp(-altitude_m / (atmosphere_m / 5.0));
}

pub fn isOrbit(r: *const rocket_mod.Rocket, body: *const Body) bool {
    return r.altitude(body.radius_m) > 100_000.0 and r.speed() > 2_200.0;
}

pub fn orbitInfo(r: *const rocket_mod.Rocket, body: *const Body) OrbitInfo {
    const rx = r.x;
    const ry = r.y;
    const vx = r.vx;
    const vy = r.vy;
    const radius = @sqrt(rx * rx + ry * ry);
    const speed = @sqrt(vx * vx + vy * vy);
    const mu = body.mu();
    if (radius < 1.0 or mu <= 0.0) return .{};

    const energy = 0.5 * speed * speed - mu / radius;
    const h = rx * vy - ry * vx;
    const rv = rx * vx + ry * vy;
    const ex = (speed * speed - mu / radius) * rx / mu - rv * vx / mu;
    const ey = (speed * speed - mu / radius) * ry / mu - rv * vy / mu;
    const e = @sqrt(ex * ex + ey * ey);

    var info = OrbitInfo{
        .valid = true,
        .bound = false,
        .eccentricity = e,
        .specific_energy = energy,
        .angular_momentum = h,
    };

    if (@abs(h) > 1e-9 and e > 1e-9) {
        const periapsis = (h * h / mu) / (1.0 + e);
        info.periapsis_m = periapsis;
        info.periapsis_altitude_m = periapsis - body.radius_m;
    }

    if (energy < 0.0 and e < 1.0) {
        const a = -mu / (2.0 * energy);
        const apoapsis = a * (1.0 + e);
        const periapsis = a * (1.0 - e);
        const period = 6.283185307179586 * @sqrt((a * a * a) / mu);
        info.bound = true;
        info.semi_major_axis_m = a;
        info.apoapsis_m = apoapsis;
        info.periapsis_m = periapsis;
        info.apoapsis_altitude_m = apoapsis - body.radius_m;
        info.periapsis_altitude_m = periapsis - body.radius_m;
        info.period_s = period;
    }

    return info;
}

pub fn predictOrbit(r: *const rocket_mod.Rocket, body: *const Body, out_points: *[max_orbit_points]rocket_mod.Vec2) usize {
    const rx = r.x;
    const ry = r.y;
    const vx = r.vx;
    const vy = r.vy;
    const dist = @sqrt(rx * rx + ry * ry);
    const speed = @sqrt(vx * vx + vy * vy);
    const mu = body.mu();
    if (dist < 1.0 or mu <= 0.0) return 0;

    const energy = 0.5 * speed * speed - mu / dist;
    const h = rx * vy - ry * vx;
    if (@abs(energy) < 1e-6 or energy >= 0.0) return 0;

    const semi_major = -mu / (2.0 * energy);
    const e_sq = 1.0 + 2.0 * energy * h * h / (mu * mu);
    const eccentricity = @sqrt(@max(0.0, e_sq));
    if (!std.math.isFinite(semi_major) or semi_major <= 0.0) return 0;
    if (!std.math.isFinite(eccentricity) or eccentricity >= 1.0) return 0;

    const rv = rx * vx + ry * vy;
    const ex = (speed * speed - mu / dist) * rx / mu - rv * vx / mu;
    const ey = (speed * speed - mu / dist) * ry / mu - rv * vy / mu;
    const omega = std.math.atan2(ey, ex);

    const mean_motion = @sqrt(mu / (semi_major * semi_major * semi_major));
    if (!std.math.isFinite(mean_motion) or mean_motion <= 0.0) return 0;
    const period = 6.283185307179586 * (1.0 / mean_motion);
    if (!std.math.isFinite(period) or period <= 0.0) return 0;

    const dt = period / @as(f64, @floatFromInt(max_orbit_points));
    for (0..max_orbit_points) |i| {
        out_points[i] = orbitalPosition(semi_major, eccentricity, omega, @as(f64, @floatFromInt(i)) * dt, mu);
    }
    return max_orbit_points;
}

fn solveKepler(mean_anomaly: f64, eccentricity: f64) f64 {
    const tau = 6.283185307179586;
    var mean = mean_anomaly - @floor(mean_anomaly / tau) * tau;
    if (mean < 0.0) mean += tau;
    if (eccentricity < 1e-12) return mean;

    var eccentric_anomaly = if (eccentricity < 0.8) mean else 3.141592653589793;
    for (0..50) |_| {
        const f = eccentric_anomaly - eccentricity * @sin(eccentric_anomaly) - mean;
        const fp = 1.0 - eccentricity * @cos(eccentric_anomaly);
        const delta = -f / fp;
        eccentric_anomaly += delta;
        if (@abs(delta) < 1e-6) break;
    }
    return eccentric_anomaly;
}

fn orbitalPosition(a: f64, e: f64, omega: f64, t: f64, mu: f64) rocket_mod.Vec2 {
    const n = @sqrt(mu / (a * a * a));
    const eccentric_anomaly = solveKepler(n * t, e);
    const sin_e = @sin(eccentric_anomaly);
    const cos_e = @cos(eccentric_anomaly);
    const sqrt_term = @sqrt(@max(0.0, 1.0 - e * e));
    const nu = std.math.atan2(sqrt_term * sin_e, cos_e - e);
    const radius = a * (1.0 - e * cos_e);
    const x_p = radius * @cos(nu);
    const y_p = radius * @sin(nu);
    const cos_w = @cos(omega);
    const sin_w = @sin(omega);
    return .{
        .x = x_p * cos_w - y_p * sin_w,
        .y = x_p * sin_w + y_p * cos_w,
    };
}

test "orbit prediction skips degenerate launchpad state" {
    var r = rocket_mod.Rocket.init(config.earth_radius_m);
    var points: [max_orbit_points]rocket_mod.Vec2 = undefined;
    try std.testing.expectEqual(@as(usize, 0), predictOrbit(&r, &earth, &points));
}
