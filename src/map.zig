const std = @import("std");

pub const world_width: f32 = 1680.0;
pub const world_height: f32 = 1040.0;
pub const ground_y: f32 = 205.0;
pub const tile_size: i32 = 32;
pub const max_buildings: usize = 32;
pub const max_zones: usize = 16;
pub const max_collision_rects: usize = 2048;

pub const Vec2f = struct {
    x: f32,
    y: f32,
};

pub const RectF = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn contains(self: RectF, point_x: f32, point_y: f32) bool {
        return point_x >= self.x and point_x <= self.x + self.w and point_y >= self.y and point_y <= self.y + self.h;
    }

    pub fn center(self: RectF) Vec2f {
        return .{ .x = self.x + self.w * 0.5, .y = self.y + self.h * 0.5 };
    }
};

pub const BuildingAction = enum(u8) {
    hangar,
    house,
    bob_home,
    jenkins_home,
    research,
    chen_home,
    shop,
    contracts,
    maria_home,
};

pub const Building = struct {
    name: [*:0]const u8,
    rect: RectF,
    action: BuildingAction,
    color_r: u8,
    color_g: u8,
    color_b: u8,
};

pub const ZoneId = enum(u8) {
    hangar_area,
    research_zone,
    supply_zone,
    mission_zone,
    plaza,
};

pub const Zone = struct {
    id: ZoneId,
    name: [*:0]const u8,
    rect: RectF,
    color_r: u8,
    color_g: u8,
    color_b: u8,
};

pub const CollisionRect = struct {
    rect: RectF,
};

pub const TileKind = enum(u8) {
    grass,
    dirt,
    cobblestone,
    wood,
    water,
};

pub const TownMap = struct {
    buildings: [max_buildings]Building,
    building_count: usize,
    zones: [max_zones]Zone,
    zone_count: usize,
    collision_rects: [max_collision_rects]CollisionRect,
    collision_count: usize,
    ldtk_loaded: bool,

    pub fn init() TownMap {
        return .{
            .buildings = [_]Building{emptyBuilding()} ** max_buildings,
            .building_count = 0,
            .zones = [_]Zone{emptyZone()} ** max_zones,
            .zone_count = 0,
            .collision_rects = [_]CollisionRect{.{ .rect = .{ .x = 0.0, .y = 0.0, .w = 0.0, .h = 0.0 } }} ** max_collision_rects,
            .collision_count = 0,
            .ldtk_loaded = false,
        };
    }

    pub fn loadLdtkFromSlice(self: *TownMap, source: []const u8) bool {
        var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, source, .{}) catch return false;
        defer parsed.deinit();

        var next = TownMap.init();
        const levels = jsonArray(objectGet(parsed.value, "levels") orelse return false) orelse return false;
        if (levels.len == 0) return false;

        next.loadLdtkLevel(levels[0]);
        next.ldtk_loaded = true;
        self.* = next;
        return true;
    }

    pub fn isWalkable(self: *const TownMap, x: f32, y: f32) bool {
        const min_x: f32 = if (self.ldtk_loaded) 0.5 else 8.0;
        const max_x: f32 = if (self.ldtk_loaded) world_width - 0.5 else world_width - 8.0;
        const min_y: f32 = if (self.ldtk_loaded) 0.5 else ground_y;
        const max_y: f32 = if (self.ldtk_loaded) world_height - 0.5 else world_height - 8.0;
        if (x < min_x or x > max_x or y < min_y or y > max_y) return false;
        for (0..self.collision_count) |i| {
            if (self.collision_rects[i].rect.contains(x, y)) return false;
        }
        for (0..self.building_count) |i| {
            const r = inflate(self.buildings[i].rect, 8.0, 10.0);
            if (r.contains(x, y)) return false;
        }
        return true;
    }

    pub fn clampToWalkable(self: *const TownMap, x: f32, y: f32) Vec2f {
        const min_x: f32 = if (self.ldtk_loaded) 0.5 else 12.0;
        const max_x: f32 = if (self.ldtk_loaded) world_width - 0.5 else world_width - 12.0;
        const min_y: f32 = if (self.ldtk_loaded) 0.5 else ground_y + 12.0;
        const max_y: f32 = if (self.ldtk_loaded) world_height - 0.5 else world_height - 12.0;
        const cx = std.math.clamp(x, min_x, max_x);
        const cy = std.math.clamp(y, min_y, max_y);
        if (self.isWalkable(cx, cy)) return .{ .x = cx, .y = cy };
        return .{ .x = 820.0, .y = 700.0 };
    }

    pub fn zoneAt(self: *const TownMap, x: f32, y: f32) ZoneId {
        for (0..self.zone_count) |i| {
            const zone = self.zones[i];
            if (zone.rect.contains(x, y)) return zone.id;
        }
        return .plaza;
    }

    pub fn zoneName(self: *const TownMap, id: ZoneId) [*:0]const u8 {
        for (0..self.zone_count) |i| {
            const zone = self.zones[i];
            if (zone.id == id) return zone.name;
        }
        return zoneNameFor(.plaza);
    }

    pub fn buildingAt(self: *const TownMap, x: f32, y: f32) ?usize {
        for (0..self.building_count) |i| {
            if (self.buildings[i].rect.contains(x, y)) return i;
        }
        return null;
    }

    pub fn tileAt(_: *const TownMap, x: f32, y: f32) TileKind {
        const plaza = RectF{ .x = 700, .y = 610, .w = 250, .h = 190 };
        if (distance2(x, y, 820.0, 700.0) <= 42.0 * 42.0) return .water;
        if (plaza.contains(x, y)) return .cobblestone;
        if (nearWoodPath(x, y)) return .wood;
        if (nearStonePath(x, y)) return .cobblestone;
        if (nearDirtPath(x, y)) return .dirt;
        return .grass;
    }

    fn loadLdtkLevel(self: *TownMap, level: std.json.Value) void {
        const layer_value = objectGet(level, "layerInstances") orelse return;
        const layers = jsonArray(layer_value) orelse return;

        for (layers) |layer| {
            const identifier = jsonString(objectGet(layer, "__identifier") orelse continue) orelse continue;
            if (std.mem.eql(u8, identifier, "Buildings")) {
                self.loadLdtkBuildings(layer);
            } else if (std.mem.eql(u8, identifier, "Zones")) {
                self.loadLdtkZones(layer);
            } else if (std.mem.startsWith(u8, identifier, "Collision")) {
                self.loadLdtkCollision(layer);
            }
        }
    }

    fn loadLdtkBuildings(self: *TownMap, layer: std.json.Value) void {
        const entities = jsonArray(objectGet(layer, "entityInstances") orelse return) orelse return;
        for (entities) |entity| {
            if (self.building_count >= max_buildings) return;
            const action = ldtkBuildingAction(entity) orelse continue;
            const r = ldtkEntityRect(entity) orelse continue;
            if (r.w <= 0.0 or r.h <= 0.0) continue;
            const index = self.building_count;
            self.buildings[index] = buildingFor(action, r);
            self.building_count += 1;
        }
    }

    fn loadLdtkZones(self: *TownMap, layer: std.json.Value) void {
        const entities = jsonArray(objectGet(layer, "entityInstances") orelse return) orelse return;
        for (entities) |entity| {
            if (self.zone_count >= max_zones) return;
            const id = ldtkZoneId(entity) orelse continue;
            const r = ldtkEntityRect(entity) orelse continue;
            if (r.w <= 0.0 or r.h <= 0.0) continue;
            const index = self.zone_count;
            self.zones[index] = zoneFor(id, r);
            self.zone_count += 1;
        }
    }

    fn loadLdtkCollision(self: *TownMap, layer: std.json.Value) void {
        if (jsonArray(objectGet(layer, "entityInstances") orelse .null)) |entities| {
            for (entities) |entity| {
                if (self.collision_count >= max_collision_rects) return;
                const r = ldtkEntityRect(entity) orelse continue;
                if (r.w <= 0.0 or r.h <= 0.0) continue;
                self.addCollision(r);
            }
        }

        if (jsonArray(objectGet(layer, "gridTiles") orelse .null)) |tiles| {
            const grid = jsonInt(objectGet(layer, "__gridSize") orelse .null) orelse tile_size;
            if (grid > 0) {
                for (tiles) |tile| {
                    if (self.collision_count >= max_collision_rects) return;
                    const px = jsonArray(objectGet(tile, "px") orelse continue) orelse continue;
                    if (px.len < 2) continue;
                    self.addCollision(.{
                        .x = @as(f32, @floatFromInt(jsonInt(px[0]) orelse 0)),
                        .y = @as(f32, @floatFromInt(jsonInt(px[1]) orelse 0)),
                        .w = @as(f32, @floatFromInt(grid)),
                        .h = @as(f32, @floatFromInt(grid)),
                    });
                }
            }
        }

        const csv = jsonArray(objectGet(layer, "intGridCsv") orelse return) orelse return;
        const grid = jsonInt(objectGet(layer, "__gridSize") orelse .null) orelse tile_size;
        const cwid = jsonInt(objectGet(layer, "__cWid") orelse .null) orelse 0;
        const offset_x = jsonInt(objectGet(layer, "pxTotalOffsetX") orelse .null) orelse 0;
        const offset_y = jsonInt(objectGet(layer, "pxTotalOffsetY") orelse .null) orelse 0;
        if (grid <= 0 or cwid <= 0) return;

        for (csv, 0..) |cell, i| {
            const value = jsonInt(cell) orelse 0;
            if (value == 0) continue;
            if (self.collision_count >= max_collision_rects) return;
            const ix = @as(i32, @intCast(i % @as(usize, @intCast(cwid))));
            const iy = @as(i32, @intCast(i / @as(usize, @intCast(cwid))));
            self.addCollision(.{
                .x = @as(f32, @floatFromInt(offset_x + ix * grid)),
                .y = @as(f32, @floatFromInt(offset_y + iy * grid)),
                .w = @as(f32, @floatFromInt(grid)),
                .h = @as(f32, @floatFromInt(grid)),
            });
        }
    }

    fn addCollision(self: *TownMap, r: RectF) void {
        if (self.collision_count >= max_collision_rects) return;
        self.collision_rects[self.collision_count] = .{ .rect = r };
        self.collision_count += 1;
    }
};

fn emptyBuilding() Building {
    return .{
        .name = "",
        .rect = .{ .x = 0.0, .y = 0.0, .w = 0.0, .h = 0.0 },
        .action = .house,
        .color_r = 0,
        .color_g = 0,
        .color_b = 0,
    };
}

fn emptyZone() Zone {
    return .{
        .id = .plaza,
        .name = "",
        .rect = .{ .x = 0.0, .y = 0.0, .w = 0.0, .h = 0.0 },
        .color_r = 0,
        .color_g = 0,
        .color_b = 0,
    };
}

fn buildingFor(action: BuildingAction, r: RectF) Building {
    const col = buildingColor(action);
    return .{
        .name = buildingName(action),
        .rect = r,
        .action = action,
        .color_r = col[0],
        .color_g = col[1],
        .color_b = col[2],
    };
}

fn buildingName(action: BuildingAction) [*:0]const u8 {
    return switch (action) {
        .hangar => "Rocket Hangar",
        .house => "Director House",
        .bob_home => "Bob's Place",
        .jenkins_home => "Jenkins Cabin",
        .research => "Research Lab",
        .chen_home => "Dr. Chen's Cottage",
        .shop => "Supply Depot",
        .contracts => "Mission Control",
        .maria_home => "Maria's Flat",
    };
}

fn buildingColor(action: BuildingAction) [3]u8 {
    return switch (action) {
        .hangar => .{ 92, 96, 104 },
        .house => .{ 220, 210, 195 },
        .bob_home => .{ 214, 190, 164 },
        .jenkins_home => .{ 196, 180, 150 },
        .research => .{ 218, 226, 232 },
        .chen_home => .{ 206, 224, 232 },
        .shop => .{ 150, 92, 56 },
        .contracts => .{ 66, 128, 196 },
        .maria_home => .{ 220, 210, 218 },
    };
}

fn zoneFor(id: ZoneId, r: RectF) Zone {
    const col = zoneColor(id);
    return .{
        .id = id,
        .name = zoneNameFor(id),
        .rect = r,
        .color_r = col[0],
        .color_g = col[1],
        .color_b = col[2],
    };
}

fn zoneNameFor(id: ZoneId) [*:0]const u8 {
    return switch (id) {
        .hangar_area => "Hangar District",
        .research_zone => "Research Ridge",
        .supply_zone => "Supply Yard",
        .mission_zone => "Mission Control",
        .plaza => "Central Plaza",
    };
}

fn zoneColor(id: ZoneId) [3]u8 {
    return switch (id) {
        .hangar_area => .{ 92, 96, 104 },
        .research_zone => .{ 120, 170, 210 },
        .supply_zone => .{ 156, 108, 64 },
        .mission_zone => .{ 66, 128, 196 },
        .plaza => .{ 92, 150, 86 },
    };
}

fn ldtkEntityRect(entity: std.json.Value) ?RectF {
    const px = jsonArray(objectGet(entity, "px") orelse return null) orelse return null;
    if (px.len < 2) return null;
    const width = jsonInt(objectGet(entity, "width") orelse .null) orelse 0;
    const height = jsonInt(objectGet(entity, "height") orelse .null) orelse 0;
    if (width <= 0 or height <= 0) return null;
    return .{
        .x = @as(f32, @floatFromInt(jsonInt(px[0]) orelse 0)),
        .y = @as(f32, @floatFromInt(jsonInt(px[1]) orelse 0)),
        .w = @as(f32, @floatFromInt(width)),
        .h = @as(f32, @floatFromInt(height)),
    };
}

fn ldtkBuildingAction(entity: std.json.Value) ?BuildingAction {
    if (fieldString(entity, "Action")) |value| {
        if (parseBuildingAction(value)) |action| return action;
    }
    if (fieldString(entity, "Kind")) |value| {
        if (parseBuildingAction(value)) |action| return action;
    }
    if (jsonString(objectGet(entity, "__identifier") orelse .null)) |identifier| {
        return parseBuildingAction(identifier);
    }
    return null;
}

fn ldtkZoneId(entity: std.json.Value) ?ZoneId {
    if (fieldString(entity, "ZoneId")) |value| {
        if (parseZoneId(value)) |id| return id;
    }
    if (fieldString(entity, "Kind")) |value| {
        if (parseZoneId(value)) |id| return id;
    }
    if (jsonString(objectGet(entity, "__identifier") orelse .null)) |identifier| {
        return parseZoneId(identifier);
    }
    return null;
}

fn fieldString(entity: std.json.Value, wanted: []const u8) ?[]const u8 {
    const fields = jsonArray(objectGet(entity, "fieldInstances") orelse return null) orelse return null;
    for (fields) |field| {
        const id = jsonString(objectGet(field, "__identifier") orelse continue) orelse continue;
        if (!std.mem.eql(u8, id, wanted)) continue;
        return jsonString(objectGet(field, "__value") orelse .null);
    }
    return null;
}

fn parseBuildingAction(raw: []const u8) ?BuildingAction {
    if (matchId(raw, "hangar") or matchId(raw, "RocketHangar") or matchId(raw, "Rocket_Hangar")) return .hangar;
    if (matchId(raw, "house") or matchId(raw, "DirectorHouse") or matchId(raw, "Director_House")) return .house;
    if (matchId(raw, "bob_home") or matchId(raw, "BobHome") or matchId(raw, "BobPlace") or matchId(raw, "Bob_s_Place")) return .bob_home;
    if (matchId(raw, "jenkins_home") or matchId(raw, "JenkinsHome") or matchId(raw, "JenkinsCabin") or matchId(raw, "Jenkins_Cabin")) return .jenkins_home;
    if (matchId(raw, "research") or matchId(raw, "ResearchLab") or matchId(raw, "Research_Lab")) return .research;
    if (matchId(raw, "chen_home") or matchId(raw, "ChenHome") or matchId(raw, "DrChenCottage") or matchId(raw, "Dr_Chen_Cottage")) return .chen_home;
    if (matchId(raw, "shop") or matchId(raw, "SupplyDepot") or matchId(raw, "Supply_Depot")) return .shop;
    if (matchId(raw, "contracts") or matchId(raw, "MissionControl") or matchId(raw, "Mission_Control")) return .contracts;
    if (matchId(raw, "maria_home") or matchId(raw, "MariaHome") or matchId(raw, "MariaFlat") or matchId(raw, "Maria_s_Flat")) return .maria_home;
    return null;
}

fn parseZoneId(raw: []const u8) ?ZoneId {
    if (matchId(raw, "hangar_area") or matchId(raw, "HangarArea") or matchId(raw, "Hangar_District")) return .hangar_area;
    if (matchId(raw, "research_zone") or matchId(raw, "ResearchZone") or matchId(raw, "Research_Ridge")) return .research_zone;
    if (matchId(raw, "supply_zone") or matchId(raw, "SupplyZone") or matchId(raw, "Supply_Yard")) return .supply_zone;
    if (matchId(raw, "mission_zone") or matchId(raw, "MissionZone") or matchId(raw, "Mission_Control")) return .mission_zone;
    if (matchId(raw, "plaza") or matchId(raw, "CentralPlaza") or matchId(raw, "Central_Plaza")) return .plaza;
    return null;
}

fn matchId(raw: []const u8, expected: []const u8) bool {
    return normalizedEq(raw, expected);
}

fn normalizedEq(a: []const u8, b: []const u8) bool {
    var ia: usize = 0;
    var ib: usize = 0;
    while (true) {
        while (ia < a.len and isIdSep(a[ia])) : (ia += 1) {}
        while (ib < b.len and isIdSep(b[ib])) : (ib += 1) {}
        if (ia >= a.len or ib >= b.len) return ia >= a.len and ib >= b.len;
        if (std.ascii.toLower(a[ia]) != std.ascii.toLower(b[ib])) return false;
        ia += 1;
        ib += 1;
    }
}

fn isIdSep(c: u8) bool {
    return c == '_' or c == '-' or c == ' ' or c == '\'' or c == '.' or c == ':';
}

fn objectGet(value: std.json.Value, key: []const u8) ?std.json.Value {
    if (value != .object) return null;
    return value.object.get(key);
}

fn jsonArray(value: std.json.Value) ?[]const std.json.Value {
    if (value != .array) return null;
    return value.array.items;
}

fn jsonString(value: std.json.Value) ?[]const u8 {
    return switch (value) {
        .string => |s| s,
        else => null,
    };
}

fn jsonInt(value: std.json.Value) ?i32 {
    return switch (value) {
        .integer => |i| if (i >= std.math.minInt(i32) and i <= std.math.maxInt(i32)) @as(i32, @intCast(i)) else null,
        .float => |f| if (f >= @as(f64, @floatFromInt(std.math.minInt(i32))) and f <= @as(f64, @floatFromInt(std.math.maxInt(i32)))) @as(i32, @intFromFloat(f)) else null,
        else => null,
    };
}

fn inflate(rect: RectF, dx: f32, dy: f32) RectF {
    return .{ .x = rect.x - dx, .y = rect.y - dy, .w = rect.w + dx * 2.0, .h = rect.h + dy * 2.0 };
}

fn distance2(ax: f32, ay: f32, bx: f32, by: f32) f32 {
    const dx = ax - bx;
    const dy = ay - by;
    return dx * dx + dy * dy;
}

fn nearDirtPath(x: f32, y: f32) bool {
    return nearSegmentList(x, y, &.{
        .{ .x = 820, .y = 700 }, .{ .x = 650, .y = 720 }, .{ .x = 430, .y = 735 },  .{ .x = 230, .y = 770 },
        .{ .x = 650, .y = 720 }, .{ .x = 910, .y = 795 }, .{ .x = 1120, .y = 850 }, .{ .x = 1330, .y = 960 },
    }, 42.0);
}

fn nearStonePath(x: f32, y: f32) bool {
    return nearSegmentList(x, y, &.{
        .{ .x = 820, .y = 700 }, .{ .x = 795, .y = 650 },  .{ .x = 725, .y = 650 },  .{ .x = 610, .y = 680 },
        .{ .x = 820, .y = 700 }, .{ .x = 1010, .y = 695 }, .{ .x = 1260, .y = 710 }, .{ .x = 1510, .y = 840 },
    }, 38.0);
}

fn nearWoodPath(x: f32, y: f32) bool {
    return nearSegmentList(x, y, &.{
        .{ .x = 820, .y = 700 }, .{ .x = 650, .y = 670 }, .{ .x = 475, .y = 675 }, .{ .x = 230, .y = 770 },
    }, 38.0);
}

fn nearSegmentList(x: f32, y: f32, points: []const Vec2f, radius: f32) bool {
    if (points.len < 2) return false;
    var i: usize = 1;
    while (i < points.len) : (i += 1) {
        if (distanceToSegment2(x, y, points[i - 1], points[i]) <= radius * radius) return true;
    }
    return false;
}

fn distanceToSegment2(x: f32, y: f32, a: Vec2f, b: Vec2f) f32 {
    const vx = b.x - a.x;
    const vy = b.y - a.y;
    const wx = x - a.x;
    const wy = y - a.y;
    const len2 = vx * vx + vy * vy;
    if (len2 <= 0.0001) return distance2(x, y, a.x, a.y);
    const t = std.math.clamp((wx * vx + wy * vy) / len2, 0.0, 1.0);
    const px = a.x + vx * t;
    const py = a.y + vy * t;
    return distance2(x, y, px, py);
}

test "empty town map allows plaza walking" {
    const town = TownMap.init();
    try std.testing.expectEqual(@as(usize, 0), town.building_count);
    try std.testing.expectEqual(@as(usize, 0), town.collision_count);
    try std.testing.expect(town.isWalkable(820.0, 700.0));
    try std.testing.expect(!town.isWalkable(4.0, 4.0));
}

test "ldtk buildings and collision block walking" {
    const sample =
        \\{
        \\  "levels": [{
        \\    "layerInstances": [
        \\      {
        \\        "__identifier": "Buildings",
        \\        "entityInstances": [{
        \\          "__identifier": "Building",
        \\          "px": [100, 220],
        \\          "width": 64,
        \\          "height": 96,
        \\          "fieldInstances": [{"__identifier": "Action", "__value": "hangar"}]
        \\        }]
        \\      },
        \\      {
        \\        "__identifier": "Zones",
        \\        "entityInstances": [{
        \\          "__identifier": "Zone",
        \\          "px": [0, 205],
        \\          "width": 200,
        \\          "height": 200,
        \\          "fieldInstances": [{"__identifier": "ZoneId", "__value": "plaza"}]
        \\        }]
        \\      },
        \\      {
        \\        "__identifier": "Collision",
        \\        "__gridSize": 32,
        \\        "__cWid": 3,
        \\        "pxTotalOffsetX": 0,
        \\        "pxTotalOffsetY": 205,
        \\        "intGridCsv": [0, 1, 0, 0, 0, 0]
        \\      }
        \\    ]
        \\  }]
        \\}
    ;

    var town = TownMap.init();
    try std.testing.expect(town.loadLdtkFromSlice(sample));
    try std.testing.expectEqual(@as(usize, 1), town.building_count);
    try std.testing.expectEqual(@as(usize, 1), town.zone_count);
    try std.testing.expectEqual(@as(usize, 1), town.collision_count);
    try std.testing.expect(!town.isWalkable(110.0, 230.0));
    try std.testing.expect(!town.isWalkable(48.0, 220.0));
    try std.testing.expect(town.isWalkable(48.0, 48.0));
    try std.testing.expect(town.isWalkable(48.0, world_height - 0.5));
    try std.testing.expectEqual(@as(f32, 48.0), town.clampToWalkable(48.0, 48.0).y);
    try std.testing.expect(town.clampToWalkable(48.0, 2000.0).y > world_height - 1.0);
    try std.testing.expectEqual(ZoneId.plaza, town.zoneAt(10.0, 220.0));
}
