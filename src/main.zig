const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

const config = @import("config.zig");
const audio_mod = @import("audio.zig");
const map_mod = @import("map.zig");
const people_mod = @import("people.zig");
const parts = @import("parts.zig");
const physics = @import("physics.zig");
const rocket_mod = @import("rocket.zig");
const systems = @import("systems.zig");

const Screen = enum(u8) {
    title,
    load_game,
    research,
    intro_cutscene,
    settings,
    town,
    hangar,
    mission_cutscene,
    launch,
};

const MissionCutsceneState = struct {
    beat_index: u8,
    beat_time_s: f32,
    last_audio_beat: u8,

    pub fn init() MissionCutsceneState {
        return .{
            .beat_index = 0,
            .beat_time_s = 0.0,
            .last_audio_beat = 255,
        };
    }
};

const SettingSlider = enum(u8) {
    none,
    music,
    sfx,
};

const ResolutionOption = struct {
    width: i32,
    height: i32,
    label: [*:0]const u8,
};

const resolution_options = [_]ResolutionOption{
    .{ .width = 1280, .height = 720, .label = "1280 x 720" },
    .{ .width = 1920, .height = 1080, .label = "1920 x 1080" },
};

const SettingsState = struct {
    music_volume: f32,
    sfx_volume: f32,
    music_enabled: bool,
    music_index: usize,
    fullscreen: bool,
    resolution_index: usize,
    dragging_slider: SettingSlider,

    pub fn init() SettingsState {
        return .{
            .music_volume = 1.0,
            .sfx_volume = 1.0,
            .music_enabled = true,
            .music_index = 0,
            .fullscreen = false,
            .resolution_index = 0,
            .dragging_slider = .none,
        };
    }
};

const save_slot_count: usize = 3;
const save_dir = "saves";
const save_magic: u32 = 0x315a4352; // RCZ1, little endian.
const save_version: u32 = 1;
const settings_magic: u32 = 0x31534352; // RCS1, little endian.
const settings_version: u32 = 1;
const settings_path = "saves/settings.rcsettings";

const TechFlags = struct {
    pub const engine_tuning: u32 = 1 << 0;
    pub const fuel_efficiency: u32 = 1 << 1;
    pub const guidance_cpu: u32 = 1 << 2;
    pub const crew_systems: u32 = 1 << 3;
};

const ResearchTech = struct {
    flag: u32,
    title: [*:0]const u8,
    subtitle: [*:0]const u8,
    cost: i32,
};

const research_catalog = [_]ResearchTech{
    .{ .flag = TechFlags.engine_tuning, .title = "Engine Tuning", .subtitle = "+12% launch thrust", .cost = 1 },
    .{ .flag = TechFlags.fuel_efficiency, .title = "Fuel Efficiency", .subtitle = "+8% effective ISP", .cost = 2 },
    .{ .flag = TechFlags.guidance_cpu, .title = "Guidance CPU", .subtitle = "Cleaner mission telemetry", .cost = 1 },
    .{ .flag = TechFlags.crew_systems, .title = "Crew Systems", .subtitle = "+1 morale for team", .cost = 2 },
};

const SaveSlotInfo = struct {
    present: bool,
    money: i32,
    day: i32,
    hour: i32,
    minute: i32,
    part_count: u8,
    research_points: i32,
    tech_flags: u32,

    pub fn empty() SaveSlotInfo {
        return .{
            .present = false,
            .money = 0,
            .day = 0,
            .hour = 0,
            .minute = 0,
            .part_count = 0,
            .research_points = 0,
            .tech_flags = 0,
        };
    }
};

const SaveBlob = extern struct {
    magic: u32,
    version: u32,
    money: i32,
    day: i32,
    hour: i32,
    minute: f32,
    story_flags: u32,
    reputation: i32,
    research_points: i32,
    npc_morale: [systems.npc_count]i32,
    achievements_unlocked: u32,
    launch_count: u32,
    orbit_count: u32,
    missions_completed: u32,
    missions_funds: i32,
    tech_flags: u32,
    stack_count: u8,
    stack_items: [parts.max_parts]u8,
    player_x: f32,
    player_y: f32,
    checksum: u32,
};

const SettingsBlob = extern struct {
    magic: u32,
    version: u32,
    music_enabled: u8,
    music_index: u8,
    fullscreen: u8,
    resolution_index: u8,
    music_volume: f32,
    sfx_volume: f32,
    checksum: u32,
};

const rocket_animation_paths = [_][*:0]const u8{
    "assets/Rocket_Animation.gif",
    "../Game asset/Rocket_Animation.gif",
    "../../Game asset/Rocket_Animation.gif",
};

const loader_animation_paths = [_][*:0]const u8{
    "assets/SceenLoader.gif",
    "assets/ScreenLoader.gif",
    "../Game asset/SceenLoader.gif",
    "../Game asset/ScreenLoader.gif",
    "../../Game asset/SceenLoader.gif",
    "../../Game asset/ScreenLoader.gif",
};

const main_menu_background_paths = [_][*:0]const u8{
    "assets/MainMenuBackground.png",
    "assets/MainMenuBackground.jpg",
    "assets/main_menu_background.png",
    "assets/main_menu_background.jpg",
    "../Game asset/MainMenuBackground.png",
    "../Game asset/MainMenuBackground.jpg",
    "../Game asset/main_menu_background.png",
    "../Game asset/main_menu_background.jpg",
    "../Game asset/Main_Menu_Background.png",
    "../Game asset/Main_Menu_Background.jpg",
    "../../Game asset/MainMenuBackground.png",
    "../../Game asset/MainMenuBackground.jpg",
};

const rocketcraft_logo_paths = [_][*:0]const u8{
    "assets/Logo/RocketCraft_Wordmark.png",
    "assets/RocketCraft_Wordmark.png",
    "../Game asset/Logo/RocketCraft_Wordmark.png",
    "../Game asset/RocketCraft_Wordmark.png",
    "../../Game asset/Logo/RocketCraft_Wordmark.png",
    "../../Game asset/RocketCraft_Wordmark.png",
};

const town_ldtk_paths = [_][*:0]const u8{
    "assets/ROCKETCRAFT.ldtk",
    "ROCKETCRAFT.ldtk",
    "../ROCKETCRAFT.ldtk",
    "../../ROCKETCRAFT.ldtk",
};

const chen_portrait_paths = [_][*:0]const u8{
    "assets/Dr.Chen.png",
    "assets/Characters/Dr.Chen.png",
    "../Game asset/Dr.Chen.png",
    "../Game asset/Characters/Dr.Chen.png",
    "../../Game asset/Dr.Chen.png",
    "../../Game asset/Characters/Dr.Chen.png",
};

const bob_portrait_paths = [_][*:0]const u8{
    "assets/Bob.png",
    "assets/Characters/Bob.png",
    "../Game asset/Bob.png",
    "../Game asset/Characters/Bob.png",
    "../../Game asset/Bob.png",
    "../../Game asset/Characters/Bob.png",
};

const maria_portrait_paths = [_][*:0]const u8{
    "assets/Maria.png",
    "assets/Characters/Maria.png",
    "../Game asset/Maria.png",
    "../Game asset/Characters/Maria.png",
    "../../Game asset/Maria.png",
    "../../Game asset/Characters/Maria.png",
};

const jenkins_portrait_paths = [_][*:0]const u8{
    "assets/Old_Man_Jenkins.png",
    "assets/Characters/Old_Man_Jenkins.png",
    "../Game asset/Old_Man_Jenkins.png",
    "../Game asset/Characters/Old_Man_Jenkins.png",
    "../../Game asset/Old_Man_Jenkins.png",
    "../../Game asset/Characters/Old_Man_Jenkins.png",
};

const hangar_building_paths = [_][*:0]const u8{
    "assets/Build/Rocket_Hangar.png",
    "assets/Build/Rocket Hunger.png",
    "../Game asset/Build/Rocket_Hangar.png",
    "../Game asset/Build/Rocket Hunger.png",
    "../../Game asset/Build/Rocket_Hangar.png",
    "../../Game asset/Build/Rocket Hunger.png",
};

const director_building_paths = [_][*:0]const u8{
    "assets/Build/Director_House.png",
    "../Game asset/Build/Director_House.png",
    "../../Game asset/Build/Director_House.png",
};

const bob_building_paths = [_][*:0]const u8{
    "assets/Build/Bob's_Place.png",
    "../Game asset/Build/Bob's_Place.png",
    "../../Game asset/Build/Bob's_Place.png",
};

const jenkins_building_paths = [_][*:0]const u8{
    "assets/Build/Jenkins_Cabin.png",
    "../Game asset/Build/Jenkins_Cabin.png",
    "../../Game asset/Build/Jenkins_Cabin.png",
};

const research_building_paths = [_][*:0]const u8{
    "assets/Build/Research_Lab.png",
    "../Game asset/Build/Research_Lab.png",
    "../../Game asset/Build/Research_Lab.png",
};

const chen_building_paths = [_][*:0]const u8{
    "assets/Build/Dr. Chen's_Cottage.png",
    "../Game asset/Build/Dr. Chen's_Cottage.png",
    "../../Game asset/Build/Dr. Chen's_Cottage.png",
};

const depot_building_paths = [_][*:0]const u8{
    "assets/Build/Supply_Depot.png",
    "../Game asset/Build/Supply_Depot.png",
    "../../Game asset/Build/Supply_Depot.png",
};

const mission_building_paths = [_][*:0]const u8{
    "assets/Build/Mission_Control.png",
    "../Game asset/Build/Mission_Control.png",
    "../../Game asset/Build/Mission_Control.png",
};

const maria_building_paths = [_][*:0]const u8{
    "assets/Build/Maria's_Flat.png",
    "../Game asset/Build/Maria's_Flat.png",
    "../../Game asset/Build/Maria's_Flat.png",
};

const StaticTexture = struct {
    texture: rl.Texture2D,
    ready: bool,

    pub fn zero() StaticTexture {
        return .{
            .texture = undefined,
            .ready = false,
        };
    }

    pub fn initFromPaths(self: *StaticTexture, paths: []const [*:0]const u8, filter: c_int) void {
        self.ready = loadTextureFromPaths(paths, &self.texture, filter);
    }

    pub fn deinit(self: *StaticTexture) void {
        if (self.ready) {
            rl.UnloadTexture(self.texture);
        }
        self.* = StaticTexture.zero();
    }
};

const BuildingTextures = struct {
    textures: [map_mod.max_buildings]rl.Texture2D,
    ready: [map_mod.max_buildings]bool,

    pub fn zero() BuildingTextures {
        return .{
            .textures = undefined,
            .ready = [_]bool{false} ** map_mod.max_buildings,
        };
    }

    pub fn init(self: *BuildingTextures) void {
        self.loadAction(.hangar, hangar_building_paths[0..]);
        self.loadAction(.house, director_building_paths[0..]);
        self.loadAction(.bob_home, bob_building_paths[0..]);
        self.loadAction(.jenkins_home, jenkins_building_paths[0..]);
        self.loadAction(.research, research_building_paths[0..]);
        self.loadAction(.chen_home, chen_building_paths[0..]);
        self.loadAction(.shop, depot_building_paths[0..]);
        self.loadAction(.contracts, mission_building_paths[0..]);
        self.loadAction(.maria_home, maria_building_paths[0..]);
    }

    pub fn deinit(self: *BuildingTextures) void {
        var i: usize = 0;
        while (i < self.ready.len) : (i += 1) {
            if (self.ready[i]) {
                rl.UnloadTexture(self.textures[i]);
            }
        }
        self.* = BuildingTextures.zero();
    }

    pub fn textureFor(self: *const BuildingTextures, action: map_mod.BuildingAction) ?rl.Texture2D {
        const index = buildingTextureIndex(action);
        if (index >= self.ready.len or !self.ready[index]) return null;
        return self.textures[index];
    }

    fn loadAction(self: *BuildingTextures, action: map_mod.BuildingAction, paths: []const [*:0]const u8) void {
        const index = buildingTextureIndex(action);
        if (index >= self.ready.len) return;
        self.ready[index] = loadTextureFromPaths(paths, &self.textures[index], rl.TEXTURE_FILTER_POINT);
    }
};

fn buildingTextureIndex(action: map_mod.BuildingAction) usize {
    return @as(usize, @intFromEnum(action));
}

const max_ldtk_tilesets: usize = 16;
const max_ldtk_visual_tiles: usize = 14000;
const ldtk_path_bytes: usize = 260;

const LdtkTilesetTexture = struct {
    uid: i32,
    tile_size: i32,
    texture: rl.Texture2D,
    ready: bool,
};

const LdtkVisualTile = struct {
    tileset_index: u8,
    px_x: f32,
    px_y: f32,
    src_x: f32,
    src_y: f32,
    size: f32,
};

const LdtkVisuals = struct {
    tilesets: [max_ldtk_tilesets]LdtkTilesetTexture,
    tileset_count: usize,
    tiles: [max_ldtk_visual_tiles]LdtkVisualTile,
    tile_count: usize,
    ready: bool,

    pub fn zero() LdtkVisuals {
        return .{
            .tilesets = [_]LdtkTilesetTexture{.{
                .uid = 0,
                .tile_size = 16,
                .texture = undefined,
                .ready = false,
            }} ** max_ldtk_tilesets,
            .tileset_count = 0,
            .tiles = [_]LdtkVisualTile{.{
                .tileset_index = 0,
                .px_x = 0.0,
                .px_y = 0.0,
                .src_x = 0.0,
                .src_y = 0.0,
                .size = 16.0,
            }} ** max_ldtk_visual_tiles,
            .tile_count = 0,
            .ready = false,
        };
    }

    pub fn initFromPaths(self: *LdtkVisuals, paths: []const [*:0]const u8) void {
        for (paths) |path| {
            if (!rl.FileExists(path)) continue;
            var data_size: c_int = 0;
            const data = rl.LoadFileData(path, &data_size);
            if (data == null) continue;
            defer rl.UnloadFileData(data);
            if (data_size <= 0) continue;

            const bytes: [*]const u8 = @ptrCast(data);
            if (self.loadFromSlice(bytes[0..@as(usize, @intCast(data_size))])) {
                self.ready = true;
                return;
            }
        }
    }

    pub fn deinit(self: *LdtkVisuals) void {
        var i: usize = 0;
        while (i < self.tileset_count) : (i += 1) {
            if (self.tilesets[i].ready) {
                rl.UnloadTexture(self.tilesets[i].texture);
            }
        }
        self.* = LdtkVisuals.zero();
    }

    fn loadFromSlice(self: *LdtkVisuals, source: []const u8) bool {
        var parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, source, .{}) catch return false;
        defer parsed.deinit();

        self.loadTilesets(parsed.value);
        self.loadVisualTiles(parsed.value);
        return self.tileset_count > 0 or self.tile_count > 0;
    }

    fn loadTilesets(self: *LdtkVisuals, root: std.json.Value) void {
        const defs = jObjectGet(root, "defs") orelse return;
        const tilesets = jArray(jObjectGet(defs, "tilesets") orelse return) orelse return;
        for (tilesets) |tileset| {
            if (self.tileset_count >= max_ldtk_tilesets) return;
            const rel_path = jString(jObjectGet(tileset, "relPath") orelse continue) orelse continue;
            const uid = jInt(jObjectGet(tileset, "uid") orelse .null) orelse continue;
            const tile_size = jInt(jObjectGet(tileset, "tileGridSize") orelse .null) orelse 16;
            const index = self.tileset_count;
            if (!loadRelTexture(rel_path, &self.tilesets[index].texture)) continue;
            self.tilesets[index] = .{
                .uid = uid,
                .tile_size = tile_size,
                .texture = self.tilesets[index].texture,
                .ready = true,
            };
            self.tileset_count += 1;
        }
    }

    fn loadVisualTiles(self: *LdtkVisuals, root: std.json.Value) void {
        const levels = jArray(jObjectGet(root, "levels") orelse return) orelse return;
        if (levels.len == 0) return;
        const layers = jArray(jObjectGet(levels[0], "layerInstances") orelse return) orelse return;
        var rev = layers.len;
        while (rev > 0) {
            rev -= 1;
            const layer = layers[rev];
            const identifier = jString(jObjectGet(layer, "__identifier") orelse continue) orelse continue;
            if (std.mem.startsWith(u8, identifier, "Collision") or std.mem.eql(u8, identifier, "Buildings") or std.mem.eql(u8, identifier, "Zones")) continue;
            const tileset_uid = jInt(jObjectGet(layer, "__tilesetDefUid") orelse .null) orelse continue;
            const tileset_index = self.tilesetIndex(tileset_uid) orelse continue;
            const grid_tiles = jArray(jObjectGet(layer, "gridTiles") orelse continue) orelse continue;
            for (grid_tiles) |tile| {
                if (self.tile_count >= max_ldtk_visual_tiles) return;
                const px = jArray(jObjectGet(tile, "px") orelse continue) orelse continue;
                const src = jArray(jObjectGet(tile, "src") orelse continue) orelse continue;
                if (px.len < 2 or src.len < 2) continue;
                const size = @as(f32, @floatFromInt(self.tilesets[tileset_index].tile_size));
                self.tiles[self.tile_count] = .{
                    .tileset_index = @as(u8, @intCast(tileset_index)),
                    .px_x = @as(f32, @floatFromInt(jInt(px[0]) orelse 0)),
                    .px_y = @as(f32, @floatFromInt(jInt(px[1]) orelse 0)),
                    .src_x = @as(f32, @floatFromInt(jInt(src[0]) orelse 0)),
                    .src_y = @as(f32, @floatFromInt(jInt(src[1]) orelse 0)),
                    .size = size,
                };
                self.tile_count += 1;
            }
        }
    }

    fn tilesetIndex(self: *const LdtkVisuals, uid: i32) ?usize {
        var i: usize = 0;
        while (i < self.tileset_count) : (i += 1) {
            if (self.tilesets[i].uid == uid) return i;
        }
        return null;
    }
};

const PortraitTextures = struct {
    chen: rl.Texture2D,
    bob: rl.Texture2D,
    maria: rl.Texture2D,
    jenkins: rl.Texture2D,
    chen_ready: bool,
    bob_ready: bool,
    maria_ready: bool,
    jenkins_ready: bool,

    pub fn zero() PortraitTextures {
        return .{
            .chen = undefined,
            .bob = undefined,
            .maria = undefined,
            .jenkins = undefined,
            .chen_ready = false,
            .bob_ready = false,
            .maria_ready = false,
            .jenkins_ready = false,
        };
    }

    pub fn init(self: *PortraitTextures) void {
        self.chen_ready = loadTextureFromPaths(chen_portrait_paths[0..], &self.chen, rl.TEXTURE_FILTER_POINT);
        self.bob_ready = loadTextureFromPaths(bob_portrait_paths[0..], &self.bob, rl.TEXTURE_FILTER_POINT);
        self.maria_ready = loadTextureFromPaths(maria_portrait_paths[0..], &self.maria, rl.TEXTURE_FILTER_POINT);
        self.jenkins_ready = loadTextureFromPaths(jenkins_portrait_paths[0..], &self.jenkins, rl.TEXTURE_FILTER_POINT);
    }

    pub fn deinit(self: *PortraitTextures) void {
        if (self.chen_ready) {
            rl.UnloadTexture(self.chen);
        }
        if (self.bob_ready) {
            rl.UnloadTexture(self.bob);
        }
        if (self.maria_ready) {
            rl.UnloadTexture(self.maria);
        }
        if (self.jenkins_ready) {
            rl.UnloadTexture(self.jenkins);
        }
        self.* = PortraitTextures.zero();
    }

    pub fn textureFor(self: *const PortraitTextures, kind: people_mod.NpcKind) ?rl.Texture2D {
        return switch (kind) {
            .chen => if (self.chen_ready) self.chen else null,
            .bob => if (self.bob_ready) self.bob else null,
            .maria => if (self.maria_ready) self.maria else null,
            .jenkins => if (self.jenkins_ready) self.jenkins else null,
        };
    }
};

const AnimatedGif = struct {
    image: rl.Image,
    texture: rl.Texture2D,
    frame_count: i32,
    frame_index: i32,
    frame_time_s: f32,
    frame_duration_s: f32,
    image_loaded: bool,
    ready: bool,

    pub fn zero() AnimatedGif {
        return .{
            .image = undefined,
            .texture = undefined,
            .frame_count = 0,
            .frame_index = 0,
            .frame_time_s = 0.0,
            .frame_duration_s = 1.0 / 18.0,
            .image_loaded = false,
            .ready = false,
        };
    }

    pub fn initFromPaths(self: *AnimatedGif, paths: []const [*:0]const u8, frame_duration_s: f32) void {
        if (self.ready) return;
        if (self.image_loaded) self.deinit();
        self.frame_duration_s = frame_duration_s;

        for (paths) |path| {
            if (!rl.FileExists(path)) continue;

            var frames: c_int = 0;
            const image = rl.LoadImageAnim(path, &frames);
            if (!rl.IsImageValid(image) or frames <= 0 or image.width <= 0 or image.height <= 0) {
                if (rl.IsImageValid(image)) rl.UnloadImage(image);
                continue;
            }

            if (image.format != rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8) {
                rl.UnloadImage(image);
                continue;
            }

            self.image = image;
            self.image_loaded = true;
            self.frame_count = @as(i32, @intCast(frames));
            self.frame_index = 0;
            self.frame_time_s = 0.0;
            self.frame_duration_s = frame_duration_s;
            self.texture = rl.LoadTextureFromImage(self.image);
            self.ready = rl.IsTextureValid(self.texture);
            if (self.ready) {
                rl.SetTextureFilter(self.texture, rl.TEXTURE_FILTER_BILINEAR);
                return;
            }

            self.deinit();
        }
    }

    pub fn deinit(self: *AnimatedGif) void {
        if (self.ready) {
            rl.UnloadTexture(self.texture);
        }
        if (self.image_loaded) {
            rl.UnloadImage(self.image);
        }
        self.* = AnimatedGif.zero();
    }

    pub fn update(self: *AnimatedGif, dt: f32) void {
        if (!self.ready or self.frame_count <= 1 or dt <= 0.0) return;

        self.frame_time_s += dt;
        while (self.frame_time_s >= self.frame_duration_s) {
            self.frame_time_s -= self.frame_duration_s;
            self.frame_index += 1;
            if (self.frame_index >= self.frame_count) self.frame_index = 0;
            self.uploadCurrentFrame();
        }
    }

    fn uploadCurrentFrame(self: *AnimatedGif) void {
        const frame_bytes = self.frameByteCount();
        if (frame_bytes == 0) return;
        const data = self.image.data orelse return;
        const pixels: [*]const u8 = @ptrCast(data);
        const offset = frame_bytes * @as(usize, @intCast(self.frame_index));
        rl.UpdateTexture(self.texture, pixels + offset);
    }

    fn frameByteCount(self: *const AnimatedGif) usize {
        if (!self.image_loaded or self.image.width <= 0 or self.image.height <= 0) return 0;
        return @as(usize, @intCast(self.image.width)) * @as(usize, @intCast(self.image.height)) * 4;
    }
};

const GameState = struct {
    screen: Screen,
    money: i32,
    time: systems.TimeSystem,
    town_map: map_mod.TownMap,
    people: people_mod.PeopleSystem,
    stack: parts.Stack,
    rocket: rocket_mod.Rocket,
    audio: audio_mod.AudioState,
    missions: systems.MissionTracker,
    achievements: systems.AchievementSystem,
    story: systems.StoryState,
    settings: SettingsState,
    cutscene: MissionCutsceneState,
    rocket_gif: AnimatedGif,
    loader_gif: AnimatedGif,
    portraits: PortraitTextures,
    buildings: BuildingTextures,
    ldtk_visuals: LdtkVisuals,
    menu_background: StaticTexture,
    logo: StaticTexture,
    tech_flags: u32,
    selected_save_slot: usize,
    save_slots: [save_slot_count]SaveSlotInfo,
    load_screen_time_s: f32,
    ui_time_s: f32,
    orbit_points: [physics.max_orbit_points]rocket_mod.Vec2,
    orbit_info: physics.OrbitInfo,
    orbit_count: usize,
    launch_time_s: f32,
    mission_paid: bool,
    notice: [160]u8,
    notice_len: usize,
    notice_timer_s: f32,
    quit_requested: bool,
    map_open: bool,
    dialogue_npc: i32,

    pub fn init() GameState {
        return .{
            .screen = .title,
            .money = config.starting_funds,
            .time = systems.TimeSystem.init(),
            .town_map = map_mod.TownMap.init(),
            .people = people_mod.PeopleSystem.init(),
            .stack = parts.Stack.init(),
            .rocket = rocket_mod.Rocket.init(config.earth_radius_m),
            .audio = audio_mod.AudioState.zero(),
            .missions = systems.MissionTracker.init(),
            .achievements = systems.AchievementSystem.init(),
            .story = systems.StoryState.init(),
            .settings = SettingsState.init(),
            .cutscene = MissionCutsceneState.init(),
            .rocket_gif = AnimatedGif.zero(),
            .loader_gif = AnimatedGif.zero(),
            .portraits = PortraitTextures.zero(),
            .buildings = BuildingTextures.zero(),
            .ldtk_visuals = LdtkVisuals.zero(),
            .menu_background = StaticTexture.zero(),
            .logo = StaticTexture.zero(),
            .tech_flags = 0,
            .selected_save_slot = 0,
            .save_slots = [_]SaveSlotInfo{SaveSlotInfo.empty()} ** save_slot_count,
            .load_screen_time_s = 0.0,
            .ui_time_s = 0.0,
            .orbit_points = [_]rocket_mod.Vec2{.{ .x = 0.0, .y = 0.0 }} ** physics.max_orbit_points,
            .orbit_info = .{},
            .orbit_count = 0,
            .launch_time_s = 0.0,
            .mission_paid = false,
            .notice = [_]u8{0} ** 160,
            .notice_len = 0,
            .notice_timer_s = 0.0,
            .quit_requested = false,
            .map_open = false,
            .dialogue_npc = -1,
        };
    }
};

pub fn main() void {
    var game = GameState.init();

    rl.InitWindow(config.screen_width, config.screen_height, "RocketCraft Zig");
    defer rl.CloseWindow();
    rl.SetExitKey(0);
    rl.SetTargetFPS(config.target_fps);
    const canvas = rl.LoadRenderTexture(config.screen_width, config.screen_height);
    defer rl.UnloadRenderTexture(canvas);
    rl.SetTextureFilter(canvas.texture, rl.TEXTURE_FILTER_BILINEAR);
    loadTownMapFromLdtk(&game);
    game.ldtk_visuals.initFromPaths(town_ldtk_paths[0..]);
    defer game.ldtk_visuals.deinit();
    game.rocket_gif.initFromPaths(rocket_animation_paths[0..], 1.0 / 18.0);
    defer game.rocket_gif.deinit();
    defer game.loader_gif.deinit();
    game.portraits.init();
    defer game.portraits.deinit();
    game.buildings.init();
    defer game.buildings.deinit();
    game.menu_background.initFromPaths(main_menu_background_paths[0..], rl.TEXTURE_FILTER_BILINEAR);
    defer game.menu_background.deinit();
    game.logo.initFromPaths(rocketcraft_logo_paths[0..], rl.TEXTURE_FILTER_BILINEAR);
    defer game.logo.deinit();
    loadSettingsFile(&game);
    game.audio.init();
    defer game.audio.deinit();
    syncAudioSettings(&game);

    while (!rl.WindowShouldClose() and !game.quit_requested) {
        const dt = rl.GetFrameTime();
        update(&game, dt);
        game.audio.update(audioMode(game.screen), @as(f32, @floatCast(game.rocket.throttle)), game.rocket.fuel_kg);

        rl.BeginTextureMode(canvas);
        render(&game);
        rl.EndTextureMode();

        rl.BeginDrawing();
        presentCanvas(canvas);
        rl.EndDrawing();
    }
}

fn update(game: *GameState, dt: f32) void {
    game.ui_time_s += dt;
    if (game.ui_time_s > 4096.0) game.ui_time_s = 0.0;
    game.rocket_gif.update(dt);
    if (game.screen == .load_game) game.loader_gif.update(dt);

    if (rl.IsKeyPressed(rl.KEY_F5)) {
        saveGameSlot(game, 0);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_F9)) {
        loadGameSlot(game, 0);
        return;
    }

    if (game.notice_timer_s > 0.0) {
        game.notice_timer_s -= dt;
        if (game.notice_timer_s <= 0.0) {
            game.notice_len = 0;
            game.notice[0] = 0;
        }
    }
    if ((game.screen == .town or game.screen == .hangar) and !game.map_open and game.dialogue_npc < 0) {
        if (game.time.update(dt)) {
            const story_notice = game.story.applyNewDay(&game.time, &game.money);
            if (story_notice[0] != 0) {
                setNotice(game, std.mem.span(story_notice));
                game.audio.confirm();
            }
        }
        applyAchievement(game, game.achievements.checkSession(game.money, game.time.day, &game.story.npc_morale));
    }

    switch (game.screen) {
        .title => {
            if (rl.IsKeyPressed(rl.KEY_ENTER)) {
                game.audio.click();
                game.screen = .town;
            }
            if (rl.IsKeyPressed(rl.KEY_L)) openLoadGame(game);
            if (rl.IsKeyPressed(rl.KEY_R)) {
                game.audio.click();
                game.screen = .research;
            }
            if (rl.IsKeyPressed(rl.KEY_H)) {
                game.audio.click();
                game.screen = .hangar;
            }
            if (rl.IsKeyPressed(rl.KEY_S)) {
                game.audio.click();
                game.screen = .settings;
            }
            if (rl.IsKeyPressed(rl.KEY_Q)) {
                game.audio.click();
                game.quit_requested = true;
            }
        },
        .load_game => updateLoadGame(game, dt),
        .research => updateResearch(game),
        .intro_cutscene => updateIntroCutscene(game, dt),
        .settings => updateSettings(game, dt),
        .town => updateTown(game, dt),
        .hangar => {
            if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
                game.audio.click();
                game.screen = .title;
            }
            if (rl.IsKeyPressed(rl.KEY_M)) addMissingSystems(game);
            if (rl.IsKeyPressed(rl.KEY_P)) loadPreset(game);
            if (rl.IsKeyPressed(rl.KEY_C)) clearBuild(game);
            if (rl.IsKeyPressed(rl.KEY_L)) beginLaunch(game);
            if (rl.IsKeyPressed(rl.KEY_BACKSPACE)) removeLastPart(game);
        },
        .mission_cutscene => updateMissionCutscene(game, dt),
        .launch => updateLaunch(game, dt),
    }
}

fn updateLoadGame(game: *GameState, dt: f32) void {
    game.load_screen_time_s += dt;
    if (game.load_screen_time_s > 2048.0) game.load_screen_time_s = 0.0;

    if (rl.IsKeyPressed(rl.KEY_ONE)) game.selected_save_slot = 0;
    if (rl.IsKeyPressed(rl.KEY_TWO)) game.selected_save_slot = 1;
    if (rl.IsKeyPressed(rl.KEY_THREE)) game.selected_save_slot = 2;

    if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_BACKSPACE)) {
        closeLoadGame(game);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_ENTER) or rl.IsKeyPressed(rl.KEY_SPACE)) {
        loadGameSlot(game, game.selected_save_slot);
    }
}

fn updateResearch(game: *GameState) void {
    if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_BACKSPACE)) {
        game.audio.click();
        game.screen = .title;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_F)) {
        fundResearch(game);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_ONE)) unlockResearch(game, 0);
    if (rl.IsKeyPressed(rl.KEY_TWO)) unlockResearch(game, 1);
    if (rl.IsKeyPressed(rl.KEY_THREE)) unlockResearch(game, 2);
    if (rl.IsKeyPressed(rl.KEY_FOUR)) unlockResearch(game, 3);
}

fn updateTown(game: *GameState, dt: f32) void {
    if (game.map_open) {
        if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_M)) {
            game.map_open = false;
            game.audio.click();
        }
        return;
    }

    if (game.dialogue_npc >= 0) {
        if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_ENTER) or rl.IsKeyPressed(rl.KEY_SPACE) or rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            game.dialogue_npc = -1;
            game.audio.confirm();
        }
        return;
    }

    if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
        game.audio.click();
        game.screen = .title;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_H)) {
        game.audio.click();
        game.screen = .hangar;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_L)) {
        beginLaunch(game);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_M)) {
        game.map_open = true;
        game.audio.click();
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_E)) {
        if (game.people.nearestNpc(64.0)) |index| {
            openNpcDialogue(game, index);
        }
        return;
    }

    _ = updateTownKeyboardMovement(game, dt);

    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
        const mouse = mousePosition();
        if (mouse.y <= @as(f32, @floatFromInt(config.screen_height - 86))) {
            const world = game.people.screenToWorld(mouse.x, mouse.y);
            if (game.people.npcAt(world.x, world.y)) |index| {
                openNpcDialogue(game, index);
                return;
            }
            if (game.town_map.buildingAt(world.x, world.y)) |index| {
                triggerTownAction(game, game.town_map.buildings[index].action);
                return;
            }
            if (game.people.setPlayerTarget(&game.town_map, world.x, world.y)) {
                game.audio.click();
            }
        }
    }

    game.people.update(&game.town_map, &game.time, &game.story, dt);
}

fn updateTownKeyboardMovement(game: *GameState, dt: f32) bool {
    var input_x: f32 = 0.0;
    var input_y: f32 = 0.0;

    if (rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT)) input_x -= 1.0;
    if (rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT)) input_x += 1.0;
    if (rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP)) input_y -= 1.0;
    if (rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN)) input_y += 1.0;

    return game.people.movePlayerDirect(&game.town_map, input_x, input_y, dt);
}

fn updateSettings(game: *GameState, dt: f32) void {
    _ = dt;
    if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_BACKSPACE)) {
        game.audio.click();
        game.settings.dragging_slider = .none;
        game.screen = .title;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_F)) {
        game.settings.fullscreen = !game.settings.fullscreen;
        applyDisplaySettings(game);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_R)) {
        game.settings.resolution_index = (game.settings.resolution_index + 1) % resolution_options.len;
        applyDisplaySettings(game);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_M)) {
        toggleMusicEnabled(game);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_T)) {
        cycleMusicTrack(game);
        return;
    }

    const mouse = mousePosition();
    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
        if (pointInRect(mouse, settingsSliderRect(.music))) {
            game.settings.dragging_slider = .music;
            setSettingSlider(game, .music, mouse.x);
            game.audio.click();
        } else if (pointInRect(mouse, settingsSliderRect(.sfx))) {
            game.settings.dragging_slider = .sfx;
            setSettingSlider(game, .sfx, mouse.x);
            game.audio.click();
        }
    }
    if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
        switch (game.settings.dragging_slider) {
            .music => setSettingSlider(game, .music, mouse.x),
            .sfx => setSettingSlider(game, .sfx, mouse.x),
            .none => {},
        }
    }
    if (rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
        if (game.settings.dragging_slider != .none) {
            saveSettingsFile(game);
        }
        game.settings.dragging_slider = .none;
    }
}

fn triggerTownAction(game: *GameState, action: map_mod.BuildingAction) void {
    game.audio.click();
    switch (action) {
        .hangar => game.screen = .hangar,
        .contracts => setTargetToZone(game, .mission_zone, "Mission Control marked."),
        .research => game.screen = .research,
        .shop => setTargetToZone(game, .supply_zone, "Supply Yard marked."),
        .house => setNotice(game, "Home system is not ported yet. House marker saved."),
        .bob_home => setNotice(game, "Bob is usually here before 8 AM and after dark."),
        .jenkins_home => setNotice(game, "Jenkins keeps old flight notes in this cabin."),
        .chen_home => setNotice(game, "Dr. Chen's cottage is quiet unless research runs late."),
        .maria_home => setNotice(game, "Maria's flat overlooks Mission Control."),
    }
}

fn setTargetToZone(game: *GameState, zone: map_mod.ZoneId, notice: []const u8) void {
    for (0..game.town_map.zone_count) |i| {
        const z = game.town_map.zones[i];
        if (z.id == zone) {
            const center = z.rect.center();
            const target = game.town_map.clampToWalkable(center.x, center.y);
            _ = game.people.setPlayerTarget(&game.town_map, target.x, target.y);
            setNotice(game, notice);
            return;
        }
    }
}

fn openNpcDialogue(game: *GameState, index: usize) void {
    if (index >= people_mod.npc_count) return;
    game.dialogue_npc = @as(i32, @intCast(index));
    game.audio.click();
}

fn updateLaunch(game: *GameState, dt: f32) void {
    if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
        game.audio.click();
        game.screen = .title;
        game.rocket.throttle = 0.0;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_R)) {
        resetLaunch(game);
    }
    if (rl.IsKeyPressed(rl.KEY_SPACE)) {
        game.rocket.throttle = if (game.rocket.throttle > 0.05) 0.0 else 1.0;
        if (game.rocket.throttle > 0.05) game.audio.ignition() else game.audio.click();
    }

    if (rl.IsKeyDown(rl.KEY_W)) {
        game.rocket.throttle = rocket_mod.clamp(game.rocket.throttle + @as(f64, dt) * 0.65, 0.0, 1.0);
    }
    if (rl.IsKeyDown(rl.KEY_S)) {
        game.rocket.throttle = rocket_mod.clamp(game.rocket.throttle - @as(f64, dt) * 0.65, 0.0, 1.0);
    }
    if (rl.IsKeyDown(rl.KEY_A)) {
        game.rocket.angle_deg -= @as(f64, dt) * 45.0;
    }
    if (rl.IsKeyDown(rl.KEY_D)) {
        game.rocket.angle_deg += @as(f64, dt) * 45.0;
    }
    if (game.rocket.angle_deg > 180.0 or game.rocket.angle_deg < -180.0) {
        var wrapped = game.rocket.angle_deg + 180.0;
        wrapped = wrapped - @floor(wrapped / 360.0) * 360.0;
        game.rocket.angle_deg = wrapped - 180.0;
    }

    physics.step(&game.rocket, &physics.earth, @as(f64, dt));
    game.orbit_info = physics.orbitInfo(&game.rocket, &physics.earth);
    game.orbit_count = physics.predictOrbit(&game.rocket, &physics.earth, &game.orbit_points);
    game.launch_time_s += dt;

    const mission_result = game.missions.update(&game.rocket, &physics.earth, game.orbit_info);
    if (mission_result.newly_completed != 0) {
        game.money += mission_result.reward;
        game.audio.confirm();
        setNoticeFmt(game, "Mission complete: {s} +${d}", .{ mission_result.primary_name, mission_result.reward });
    }

    if ((game.rocket.flags & rocket_mod.VesselFlags.orbit) != 0 and !game.mission_paid) {
        game.money += config.launch_reward;
        game.mission_paid = true;
        game.story.markOrbit();
        applyAchievement(game, game.achievements.checkOrbit());
        setNotice(game, "Orbit achieved. Contract paid.");
    }
}

fn updateMissionCutscene(game: *GameState, dt: f32) void {
    if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_SPACE) or rl.IsKeyPressed(rl.KEY_ENTER)) {
        completeMissionCutscene(game);
        return;
    }

    if (game.cutscene.last_audio_beat != game.cutscene.beat_index) {
        playCutsceneBeatAudio(game);
        game.cutscene.last_audio_beat = game.cutscene.beat_index;
    }

    game.cutscene.beat_time_s += dt;
    if (game.cutscene.beat_time_s >= cutsceneBeatDuration(game.cutscene.beat_index)) {
        game.cutscene.beat_index += 1;
        game.cutscene.beat_time_s = 0.0;
        if (game.cutscene.beat_index >= cutsceneBeatCount()) {
            completeMissionCutscene(game);
        }
    }
}

fn updateIntroCutscene(game: *GameState, dt: f32) void {
    if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_SPACE) or rl.IsKeyPressed(rl.KEY_ENTER)) {
        completeIntroCutscene(game);
        return;
    }

    if (game.cutscene.last_audio_beat != game.cutscene.beat_index) {
        playIntroBeatAudio(game);
        game.cutscene.last_audio_beat = game.cutscene.beat_index;
    }

    game.cutscene.beat_time_s += dt;
    if (game.cutscene.beat_time_s >= introBeatDuration(game.cutscene.beat_index)) {
        game.cutscene.beat_index += 1;
        game.cutscene.beat_time_s = 0.0;
        if (game.cutscene.beat_index >= introBeatCount()) {
            completeIntroCutscene(game);
        }
    }
}

fn playCutsceneBeatAudio(game: *GameState) void {
    switch (game.cutscene.beat_index) {
        0 => game.audio.confirm(),
        1 => game.audio.click(),
        2 => game.audio.ignition(),
        else => game.audio.click(),
    }
}

fn playIntroBeatAudio(game: *GameState) void {
    switch (game.cutscene.beat_index) {
        0 => game.audio.ignition(),
        1 => game.audio.errorTone(),
        2 => game.audio.confirm(),
        3 => game.audio.click(),
        else => game.audio.confirm(),
    }
}

fn introBeatCount() u8 {
    return 5;
}

fn introBeatDuration(index: u8) f32 {
    return switch (index) {
        0 => 3.4,
        1 => 2.8,
        2 => 3.4,
        3 => 4.4,
        else => 1.4,
    };
}

fn introBeatCaption(index: u8) [*:0]const u8 {
    return switch (index) {
        0 => "Orion Heavy failed in public, and the board stopped laughing.",
        1 => "The old team scattered. The launch notes survived.",
        2 => "A letter arrived: one town, one hangar, one impossible job.",
        3 => "RocketCraft needed a director. You got off the bus.",
        else => "Build. Launch. Prove them wrong.",
    };
}

fn cutsceneBeatCount() u8 {
    return 4;
}

fn cutsceneBeatDuration(index: u8) f32 {
    return switch (index) {
        0 => 3.2,
        1 => 3.4,
        2 => 2.8,
        else => 0.9,
    };
}

fn cutsceneBeatCaption(index: u8) [*:0]const u8 {
    return switch (index) {
        0 => "The town rolls its only rocket to the old pad.",
        1 => "Guidance, life support, and telemetry come online.",
        2 => "Main engine start. Commit to launch.",
        else => "Handing control to Mission Control.",
    };
}

fn render(game: *GameState) void {
    rl.ClearBackground(rgb(18, 22, 32));
    drawStars();

    switch (game.screen) {
        .title => drawTitle(game),
        .load_game => drawLoadGame(game),
        .research => drawResearch(game),
        .intro_cutscene => drawIntroCutscene(game),
        .settings => drawSettings(game),
        .town => drawTown(game),
        .hangar => drawHangar(game),
        .mission_cutscene => drawMissionCutscene(game),
        .launch => drawLaunch(game),
    }

    drawNotice(game);
}

fn drawTitle(game: *GameState) void {
    drawMainMenuBackdrop(game);

    drawMainMenuTitlePanel(game, rect(18, 24, 422, 138));
    drawMainMenuNews(game, rect(18, 582, 392, 86));
    drawMainMenuProgramPanel(game, rect(918, 50, 346, 250));
    drawMainMenuTeamPanel(game, rect(918, 320, 346, 334));
    drawMainMenuBottomBar(game);

    const menu = rect(18, 176, 392, 390);
    drawIronPanel(menu, rgb(78, 210, 230), 224);
    drawCenteredText("MAIN MENU", toI32(menu.x + menu.width * 0.5), toI32(menu.y + 26.0), 22, rgb(78, 210, 230));
    rl.DrawRectangleGradientH(toI32(menu.x + 76.0), toI32(menu.y + 42.0), toI32(menu.width - 152.0), 2, rgba(78, 210, 230, 0), rgba(78, 210, 230, 210));

    if (mainMenuButton(rect(42, 226, 344, 48), "NEW GAME", "Start a new space program", .rocket, rgb(42, 82, 150))) {
        newCampaign(game);
    }
    if (mainMenuButton(rect(42, 284, 344, 48), "LOAD GAME", "Continue your progress", .folder, rgb(52, 64, 84))) {
        openLoadGame(game);
    }
    if (mainMenuButton(rect(42, 342, 344, 48), "ROCKET HANGAR", "View and manage your rockets", .hangar, rgb(48, 92, 58))) {
        game.audio.click();
        game.screen = .hangar;
    }
    if (mainMenuButton(rect(42, 400, 344, 48), "RESEARCH", "Technologies and upgrades", .research, rgb(82, 60, 112))) {
        game.audio.click();
        game.screen = .research;
    }
    if (mainMenuButton(rect(42, 458, 344, 48), "SETTINGS", "Game options and preferences", .settings, rgb(98, 66, 36))) {
        game.audio.click();
        game.screen = .settings;
    }
    if (mainMenuButton(rect(42, 516, 344, 48), "QUIT", "Exit RocketCraft", .power, rgb(104, 42, 42))) {
        game.audio.click();
        game.quit_requested = true;
    }
}

const MenuIcon = enum(u8) {
    rocket,
    folder,
    hangar,
    research,
    settings,
    power,
};

fn drawMainMenuBackdrop(game: *GameState) void {
    if (game.menu_background.ready) {
        drawTextureCover(game.menu_background.texture, rect(0, 0, config.screen_width, config.screen_height), rgb(255, 255, 255));
        rl.DrawRectangleGradientV(0, 0, config.screen_width, config.screen_height, rgba(0, 0, 0, 55), rgba(0, 0, 0, 105));
    } else {
        drawCinematicSpace(game.ui_time_s * 0.45, rgb(4, 8, 18), rgb(20, 34, 50), rgb(78, 210, 230));
        drawPlaceholderSpaceCenter(game);
    }
    drawText("v0.7.1", config.screen_width - 68, 18, 16, rgb(210, 222, 238));
}

fn drawTextureCover(texture: rl.Texture2D, dest: rl.Rectangle, tint: rl.Color) void {
    const tw = @as(f32, @floatFromInt(texture.width));
    const th = @as(f32, @floatFromInt(texture.height));
    if (tw <= 0.0 or th <= 0.0) return;
    const scale = @max(dest.width / tw, dest.height / th);
    const draw_w = tw * scale;
    const draw_h = th * scale;
    const draw_dest = rect(dest.x + (dest.width - draw_w) * 0.5, dest.y + (dest.height - draw_h) * 0.5, draw_w, draw_h);
    rl.DrawTexturePro(texture, rect(0, 0, tw, th), draw_dest, .{ .x = 0.0, .y = 0.0 }, 0.0, tint);
}

fn drawTextureContain(texture: rl.Texture2D, dest: rl.Rectangle, tint: rl.Color) void {
    const tw = @as(f32, @floatFromInt(texture.width));
    const th = @as(f32, @floatFromInt(texture.height));
    if (tw <= 0.0 or th <= 0.0) return;
    const scale = @min(dest.width / tw, dest.height / th);
    const draw_w = tw * scale;
    const draw_h = th * scale;
    const draw_dest = rect(dest.x + (dest.width - draw_w) * 0.5, dest.y + (dest.height - draw_h) * 0.5, draw_w, draw_h);
    rl.DrawTexturePro(texture, rect(0, 0, tw, th), draw_dest, .{ .x = 0.0, .y = 0.0 }, 0.0, tint);
}

fn drawCircleGradient(x: anytype, y: anytype, radius: f32, inner: rl.Color, outer: rl.Color) void {
    rl.DrawCircleGradient(.{ .x = asF32(x), .y = asF32(y) }, radius, inner, outer);
}

fn drawPlaceholderSpaceCenter(game: *GameState) void {
    drawCircleGradient(516, 116, 68.0, rgba(210, 220, 236, 120), rgba(210, 220, 236, 0));
    rl.DrawCircle(516, 116, 34.0, rgba(154, 164, 178, 180));
    rl.DrawCircle(502, 108, 8.0, rgba(74, 82, 96, 130));
    rl.DrawCircle(528, 128, 6.0, rgba(74, 82, 96, 110));

    rl.DrawRectangleGradientV(0, 362, config.screen_width, 312, rgba(18, 18, 24, 20), rgba(9, 12, 18, 210));
    rl.DrawRectangle(0, 580, config.screen_width, 94, rgba(20, 28, 34, 230));
    var gx: i32 = 420;
    while (gx < 890) : (gx += 44) {
        rl.DrawLine(gx, 594, gx + 72, 674, rgba(78, 210, 230, 70));
    }
    var bx: i32 = 438;
    while (bx < 880) : (bx += 78) {
        const h = 34 + @mod(bx, 46);
        rl.DrawRectangle(bx, 580 - h, 54, h, rgb(24, 32, 42));
        rl.DrawRectangleLines(bx, 580 - h, 54, h, rgba(78, 210, 230, 70));
        rl.DrawRectangle(bx + 12, 590 - h, 8, 6, rgba(255, 212, 120, 150));
        rl.DrawRectangle(bx + 34, 604 - h, 8, 6, rgba(104, 176, 255, 150));
    }

    drawLaunchTower(642, 514, 142);
    drawLaunchTower(766, 500, 172);
    drawLaunchTower(842, 524, 122);
    drawCircleGradient(730, 468, 150.0, rgba(255, 170, 80, 62), rgba(255, 170, 80, 0));
    if (!drawRocketGif(game, 734.0, 486.0, 210.0, 0.0, rgb(230, 238, 248))) {
        drawCutsceneRocket(734, 476, 1.0, false, 0.0);
    }
}

fn drawLaunchTower(x: i32, y: i32, height: i32) void {
    rl.DrawRectangle(x - 10, y - height, 20, height, rgba(50, 58, 70, 210));
    var row = y - height + 12;
    while (row < y - 12) : (row += 24) {
        rl.DrawLine(x - 10, row, x + 10, row + 18, rgba(130, 140, 158, 130));
        rl.DrawLine(x + 10, row, x - 10, row + 18, rgba(130, 140, 158, 130));
    }
    rl.DrawCircle(x, y - height, 9.0, rgba(255, 212, 120, 180));
    drawCircleGradient(x, y - height, 26.0, rgba(255, 212, 120, 72), rgba(255, 212, 120, 0));
}

fn drawMainMenuTitlePanel(game: *GameState, r: rl.Rectangle) void {
    drawIronPanel(r, rgb(255, 212, 120), 214);
    if (game.logo.ready) {
        drawTextureContain(game.logo.texture, rect(r.x + 22.0, r.y + 18.0, r.width - 44.0, 62.0), rgb(255, 255, 255));
    } else {
        drawTextShadow("ROCKETCRAFT", toI32(r.x + 24.0), toI32(r.y + 22.0), 42, rgb(255, 236, 39));
    }
    drawText("Build it. Launch it. Explore beyond.", toI32(r.x + 72.0), toI32(r.y + 88.0), 18, rgb(238, 244, 252));
    drawText("Automation | Engineering | Space", toI32(r.x + 96.0), toI32(r.y + 114.0), 17, rgb(104, 176, 255));
}

fn drawIronPanel(r: rl.Rectangle, accent: rl.Color, alpha: u8) void {
    rl.DrawRectangleRec(rect(r.x + 6.0, r.y + 7.0, r.width, r.height), rgba(0, 0, 0, 116));
    rl.DrawRectangleRec(r, rgba(7, 13, 24, alpha));
    rl.DrawRectangleLinesEx(r, 2.0, rgba(94, 118, 154, 180));
    rl.DrawRectangleLinesEx(rect(r.x + 5.0, r.y + 5.0, r.width - 10.0, r.height - 10.0), 1.0, rgba(255, 255, 255, 28));
    rl.DrawRectangleGradientH(toI32(r.x + 18.0), toI32(r.y + 22.0), toI32(r.width - 36.0), 2, rgba(accent.r, accent.g, accent.b, 190), rgba(accent.r, accent.g, accent.b, 0));
}

fn mainMenuButton(r: rl.Rectangle, title: [*:0]const u8, subtitle: [*:0]const u8, icon: MenuIcon, fill: rl.Color) bool {
    const mouse = mousePosition();
    const hover = mouse.x >= r.x and mouse.x <= r.x + r.width and mouse.y >= r.y and mouse.y <= r.y + r.height;
    const body = if (hover) lighten(fill) else fill;
    rl.DrawRectangleRec(rect(r.x + 4.0, r.y + 5.0, r.width, r.height), rgba(0, 0, 0, 100));
    rl.DrawRectangleRec(r, rgba(body.r, body.g, body.b, 226));
    rl.DrawRectangleGradientH(toI32(r.x), toI32(r.y), toI32(r.width), toI32(r.height), rgba(255, 255, 255, if (hover) 48 else 24), rgba(0, 0, 0, 36));
    rl.DrawRectangleLinesEx(r, 2.0, if (hover) rgb(255, 212, 120) else rgba(110, 132, 168, 150));
    drawMenuIcon(icon, toI32(r.x + 39.0), toI32(r.y + r.height * 0.5), if (hover) rgb(255, 236, 160) else rgb(210, 222, 236));
    drawTextShadow(title, toI32(r.x + 86.0), toI32(r.y + 10.0), 22, rgb(245, 248, 255));
    drawText(subtitle, toI32(r.x + 86.0), toI32(r.y + 32.0), 15, rgb(176, 190, 214));
    return hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
}

fn drawMenuIcon(icon: MenuIcon, cx: i32, cy: i32, col: rl.Color) void {
    switch (icon) {
        .rocket => {
            rl.DrawTriangle(.{ .x = @as(f32, @floatFromInt(cx)), .y = @as(f32, @floatFromInt(cy - 23)) }, .{ .x = @as(f32, @floatFromInt(cx - 14)), .y = @as(f32, @floatFromInt(cy + 8)) }, .{ .x = @as(f32, @floatFromInt(cx + 14)), .y = @as(f32, @floatFromInt(cy + 8)) }, col);
            rl.DrawRectangle(cx - 8, cy + 6, 16, 18, col);
            rl.DrawTriangle(.{ .x = @as(f32, @floatFromInt(cx - 8)), .y = @as(f32, @floatFromInt(cy + 23)) }, .{ .x = @as(f32, @floatFromInt(cx)), .y = @as(f32, @floatFromInt(cy + 36)) }, .{ .x = @as(f32, @floatFromInt(cx + 8)), .y = @as(f32, @floatFromInt(cy + 23)) }, rgb(255, 156, 84));
        },
        .folder => {
            rl.DrawRectangle(cx - 20, cy - 10, 40, 25, col);
            rl.DrawRectangle(cx - 20, cy - 18, 18, 10, col);
            rl.DrawRectangleLines(cx - 20, cy - 10, 40, 25, rgba(0, 0, 0, 110));
        },
        .hangar => {
            rl.DrawTriangle(.{ .x = @as(f32, @floatFromInt(cx)), .y = @as(f32, @floatFromInt(cy - 22)) }, .{ .x = @as(f32, @floatFromInt(cx - 24)), .y = @as(f32, @floatFromInt(cy + 6)) }, .{ .x = @as(f32, @floatFromInt(cx + 24)), .y = @as(f32, @floatFromInt(cy + 6)) }, col);
            rl.DrawRectangle(cx - 16, cy + 5, 32, 22, col);
            rl.DrawRectangle(cx - 5, cy + 10, 10, 17, rgba(0, 0, 0, 115));
        },
        .research => {
            rl.DrawLineEx(.{ .x = @as(f32, @floatFromInt(cx - 10)), .y = @as(f32, @floatFromInt(cy - 18)) }, .{ .x = @as(f32, @floatFromInt(cx - 4)), .y = @as(f32, @floatFromInt(cy + 14)) }, 4.0, col);
            rl.DrawLineEx(.{ .x = @as(f32, @floatFromInt(cx + 10)), .y = @as(f32, @floatFromInt(cy - 18)) }, .{ .x = @as(f32, @floatFromInt(cx + 4)), .y = @as(f32, @floatFromInt(cy + 14)) }, 4.0, col);
            rl.DrawRectangle(cx - 16, cy + 13, 32, 6, col);
            rl.DrawCircle(cx, cy + 1, 6.0, rgba(104, 230, 255, 170));
        },
        .settings => {
            rl.DrawCircleLines(cx, cy, 18.0, col);
            var a: i32 = 0;
            while (a < 8) : (a += 1) {
                const ang = @as(f32, @floatFromInt(a)) * std.math.pi / 4.0;
                rl.DrawLine(cx + toI32(@cos(ang) * 15.0), cy + toI32(@sin(ang) * 15.0), cx + toI32(@cos(ang) * 24.0), cy + toI32(@sin(ang) * 24.0), col);
            }
            rl.DrawCircle(cx, cy, 5.0, col);
        },
        .power => {
            rl.DrawCircleLines(cx, cy + 4, 18.0, col);
            rl.DrawRectangle(cx - 3, cy - 20, 6, 22, col);
        },
    }
}

fn drawMainMenuProgramPanel(game: *GameState, r: rl.Rectangle) void {
    drawIronPanel(r, rgb(78, 210, 230), 222);
    drawText("CURRENT PROGRAM", toI32(r.x + 18.0), toI32(r.y + 18.0), 17, rgb(78, 210, 230));
    drawTextShadow("Untitled Program", toI32(r.x + 18.0), toI32(r.y + 54.0), 20, rgb(255, 236, 39));
    drawFormat("Parts: {d}", .{game.stack.count}, toI32(r.x + 18.0), toI32(r.y + 92.0), 17, rgb(210, 224, 244));
    drawFormat("Mass: {d} kg", .{@as(i32, @intFromFloat(parts.totalMass(&game.stack)))}, toI32(r.x + 18.0), toI32(r.y + 120.0), 17, rgb(210, 224, 244));
    drawFormat("Cost: ${d}", .{parts.totalCost(&game.stack)}, toI32(r.x + 18.0), toI32(r.y + 148.0), 17, rgb(210, 224, 244));
    drawFormat("Research: {d}", .{game.story.research_points}, toI32(r.x + 18.0), toI32(r.y + 176.0), 17, rgb(210, 224, 244));
    drawText(if (parts.isLaunchable(&game.stack)) "Ready to launch!" else "Needs pod, tank, engine", toI32(r.x + 18.0), toI32(r.y + 210.0), 18, if (parts.isLaunchable(&game.stack)) rgb(104, 230, 150) else rgb(255, 150, 110));
    const preview = rect(r.x + 204.0, r.y + 66.0, 128.0, 132.0);
    rl.DrawRectangleRec(preview, rgba(22, 34, 50, 180));
    rl.DrawRectangleLinesEx(preview, 1.5, rgba(104, 176, 255, 120));
    if (!drawRocketGif(game, preview.x + preview.width * 0.5, preview.y + preview.height * 0.56, 118.0, 0.0, rgb(255, 255, 255))) {
        drawCutsceneRocket(toI32(preview.x + preview.width * 0.5), toI32(preview.y + preview.height * 0.66), 0.52, false, 0.0);
    }
    if (smallMenuButton(rect(r.x + 190.0, r.y + 212.0, 130.0, 28.0), "VIEW DETAILS")) {
        game.audio.click();
        game.screen = .hangar;
    }
}

fn drawMainMenuTeamPanel(game: *GameState, r: rl.Rectangle) void {
    drawIronPanel(r, rgb(78, 210, 230), 222);
    drawText("YOUR TEAM", toI32(r.x + 18.0), toI32(r.y + 16.0), 17, rgb(78, 210, 230));
    drawTeamRow(game, &game.people.npcs[0], rect(r.x + 18.0, r.y + 48.0, r.width - 36.0, 60.0), "Research Lab");
    drawTeamRow(game, &game.people.npcs[1], rect(r.x + 18.0, r.y + 112.0, r.width - 36.0, 60.0), "Hangar");
    drawTeamRow(game, &game.people.npcs[2], rect(r.x + 18.0, r.y + 176.0, r.width - 36.0, 60.0), "Mission Control");
    drawTeamRow(game, &game.people.npcs[3], rect(r.x + 18.0, r.y + 240.0, r.width - 36.0, 60.0), "Plaza");
    _ = smallMenuButton(rect(r.x + 92.0, r.y + r.height - 36.0, 170.0, 28.0), "TEAM STATUS");
}

fn drawTeamRow(game: *GameState, npc: *const people_mod.Npc, r: rl.Rectangle, location: [*:0]const u8) void {
    rl.DrawRectangleRec(r, rgba(255, 255, 255, 8));
    rl.DrawLine(toI32(r.x), toI32(r.y + r.height), toI32(r.x + r.width), toI32(r.y + r.height), rgba(104, 176, 255, 42));
    const portrait = rect(r.x, r.y + 4.0, 50.0, 50.0);
    drawTeamPortrait(game, npc, portrait);
    drawTextShadow(npc.name, toI32(r.x + 64.0), toI32(r.y + 8.0), 17, rgb(255, 236, 39));
    drawText(npc.role, toI32(r.x + 64.0), toI32(r.y + 28.0), 14, rgb(190, 204, 226));
    rl.DrawCircle(toI32(r.x + 68.0), toI32(r.y + 48.0), 4.0, rgb(104, 230, 150));
    drawText(location, toI32(r.x + 80.0), toI32(r.y + 40.0), 14, rgb(104, 230, 150));
}

fn drawTeamPortrait(game: *GameState, npc: *const people_mod.Npc, r: rl.Rectangle) void {
    rl.DrawRectangleRec(r, rgba(18, 28, 44, 230));
    rl.DrawRectangleLinesEx(r, 1.0, rgba(104, 176, 255, 120));
    if (game.portraits.textureFor(npc.kind)) |texture| {
        rl.DrawTexturePro(
            texture,
            rect(0, 0, @as(f32, @floatFromInt(texture.width)), @as(f32, @floatFromInt(texture.height))),
            rect(r.x + 3.0, r.y + 3.0, r.width - 6.0, r.height - 6.0),
            .{ .x = 0.0, .y = 0.0 },
            0.0,
            rgb(255, 255, 255),
        );
    } else {
        drawFallbackPortrait(npc, rect(r.x + 4.0, r.y + 4.0, r.width - 8.0, r.height - 8.0));
    }
}

fn drawMainMenuNews(_: *GameState, r: rl.Rectangle) void {
    drawIronPanel(r, rgb(78, 210, 230), 220);
    drawText("SPACE CENTER NEWS", toI32(r.x + 18.0), toI32(r.y + 12.0), 16, rgb(78, 210, 230));
    drawCircleGradient(toI32(r.x + 58.0), toI32(r.y + 56.0), 30.0, rgba(104, 176, 255, 50), rgba(104, 176, 255, 0));
    rl.DrawCircle(toI32(r.x + 58.0), toI32(r.y + 56.0), 12.0, rgb(160, 190, 170));
    rl.DrawLine(toI32(r.x + 42.0), toI32(r.y + 42.0), toI32(r.x + 76.0), toI32(r.y + 70.0), rgb(226, 234, 244));
    drawTextShadow("New contracts available!", toI32(r.x + 112.0), toI32(r.y + 38.0), 15, rgb(255, 236, 39));
    drawText("Check Mission Control soon.", toI32(r.x + 112.0), toI32(r.y + 58.0), 14, rgb(210, 224, 244));
}

fn drawMainMenuBottomBar(game: *GameState) void {
    rl.DrawRectangle(0, 674, config.screen_width, 46, rgba(7, 13, 24, 236));
    rl.DrawRectangleLinesEx(rect(0, 674, config.screen_width, 46), 1.0, rgba(94, 118, 154, 150));
    drawFormat("Day {d}  {d}:{d:0>2}", .{ game.time.day, game.time.hour, @as(i32, @intFromFloat(game.time.minute)) }, 80, 690, 17, rgb(238, 244, 252));
    drawFormat("$ {d}", .{game.money}, 334, 690, 17, rgb(104, 230, 150));
    drawFormat("RP {d}", .{game.story.research_points}, 486, 690, 17, rgb(104, 176, 255));
    drawFormat("Parts {d}", .{game.stack.count}, 610, 690, 17, rgb(255, 212, 120));
    drawFormat("Ach {d}", .{@popCount(game.achievements.unlocked)}, 744, 690, 17, rgb(255, 156, 84));
    drawText("F5 save | F9 load", 856, 690, 16, rgb(176, 190, 214));
    _ = smallMenuButton(rect(1018, 684, 48, 26), "STAT");
    _ = smallMenuButton(rect(1078, 684, 48, 26), "TRO");
    _ = smallMenuButton(rect(1138, 684, 48, 26), "LOG");
}

fn smallMenuButton(r: rl.Rectangle, label: [*:0]const u8) bool {
    const mouse = mousePosition();
    const hover = mouse.x >= r.x and mouse.x <= r.x + r.width and mouse.y >= r.y and mouse.y <= r.y + r.height;
    rl.DrawRectangleRec(r, rgba(28, 50, 78, if (hover) 235 else 205));
    rl.DrawRectangleLinesEx(r, 1.5, if (hover) rgb(255, 212, 120) else rgba(104, 176, 255, 120));
    const tw = rl.MeasureText(label, 14);
    drawText(label, toI32(r.x + r.width * 0.5) - @divTrunc(tw, 2), toI32(r.y + 8.0), 14, rgb(210, 235, 255));
    return hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
}

fn drawLoadGame(game: *GameState) void {
    drawCinematicSpace(game.ui_time_s * 0.8, rgb(5, 9, 18), rgb(18, 34, 54), rgb(104, 176, 255));
    drawCircleGradient(930, 338, 242.0 + @sin(game.load_screen_time_s * 1.6) * 10.0, rgba(104, 176, 255, 80), rgba(104, 176, 255, 0));

    const panel = rect(72, 58, 1136, 604);
    drawGlassPanel(panel, rgb(104, 176, 255), 226);
    drawTextShadow("Load Game", 112, 92, 48, rgb(255, 236, 39));
    drawText("Select a mission record", 116, 148, 22, rgb(226, 234, 244));
    drawText("Binary save slots are active. F5 saves slot 1, F9 loads slot 1.", 116, 176, 17, rgb(154, 176, 210));

    const loader_box = rect(762, 126, 346, 346);
    drawGlassPanel(loader_box, rgb(78, 210, 230), 202);
    if (!drawAnimatedGif(&game.loader_gif, 935.0, 299.0, 316.0, 0.0, rgb(255, 255, 255))) {
        drawLoaderFallback(game, loader_box);
    }
    drawCenteredText("SceenLoader.gif", 935, 504, 20, rgb(176, 190, 214));

    if (drawSaveSlot(game, 0, "Autosave", rect(116, 226, 558, 88), rgb(82, 90, 112))) game.selected_save_slot = 0;
    if (drawSaveSlot(game, 1, "Manual Save", rect(116, 330, 558, 88), rgb(82, 90, 112))) game.selected_save_slot = 1;
    if (drawSaveSlot(game, 2, "Recovery", rect(116, 434, 558, 88), rgb(82, 90, 112))) game.selected_save_slot = 2;

    const scan = 0.5 + 0.5 * @sin(game.load_screen_time_s * 2.2);
    drawText("Scanning save directory", 792, 540, 18, rgb(176, 190, 214));
    drawProgressBar(rect(792, 570, 306, 10), scan, rgb(104, 176, 255));

    if (button(rect(116, 568, 218, 48), "Load Selected", rgb(82, 90, 112))) {
        loadGameSlot(game, game.selected_save_slot);
    }
    if (button(rect(360, 568, 178, 48), "Save Current", rgb(84, 116, 96))) {
        saveGameSlot(game, game.selected_save_slot);
    }
    if (button(rect(564, 568, 178, 48), "Back", rgb(92, 80, 84))) {
        closeLoadGame(game);
    }
    if (button(rect(770, 568, 178, 48), "New Game", rgb(70, 105, 170))) {
        game.loader_gif.deinit();
        newCampaign(game);
    }

    drawText("1-3 select | Enter load | F5 save slot 1 | F9 load slot 1 | Esc main menu", 116, 632, 17, rgb(150, 160, 180));
}

fn drawSaveSlot(game: *GameState, index: usize, title: [*:0]const u8, r: rl.Rectangle, accent: rl.Color) bool {
    const selected = game.selected_save_slot == index;
    const mouse = mousePosition();
    const hover = pointInRect(mouse, r);
    drawGlassPanel(r, if (selected) rgb(255, 212, 120) else accent, if (selected) 226 else 196);
    if (hover or selected) {
        rl.DrawRectangleRoundedLinesEx(rect(r.x - 3.0, r.y - 3.0, r.width + 6.0, r.height + 6.0), 0.055, 8, 1.5, if (selected) rgb(255, 212, 120) else rgb(104, 176, 255));
    }
    drawFormat("SLOT {d}", .{@as(i32, @intCast(index + 1))}, toI32(r.x + 20.0), toI32(r.y + 16.0), 16, rgb(154, 176, 210));
    drawTextShadow(title, toI32(r.x + 92.0), toI32(r.y + 18.0), 24, rgb(238, 244, 252));
    const info = game.save_slots[index];
    if (info.present) {
        drawFormat("Day {d} {d}:{d:0>2} | ${d} | Parts {d} | RP {d}", .{ info.day, info.hour, info.minute, info.money, info.part_count, info.research_points }, toI32(r.x + 92.0), toI32(r.y + 50.0), 16, rgb(176, 190, 214));
        drawText("READY", toI32(r.x + r.width - 102.0), toI32(r.y + 34.0), 18, rgb(120, 230, 150));
    } else {
        drawText("No save data", toI32(r.x + 92.0), toI32(r.y + 50.0), 18, rgb(176, 190, 214));
        drawText("EMPTY", toI32(r.x + r.width - 102.0), toI32(r.y + 34.0), 18, rgb(255, 150, 110));
    }
    return hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
}

fn drawLoaderFallback(game: *GameState, r: rl.Rectangle) void {
    const cx = toI32(r.x + r.width * 0.5);
    const cy = toI32(r.y + r.height * 0.5);
    var i: i32 = 0;
    while (i < 9) : (i += 1) {
        const phase = game.load_screen_time_s * 4.0 + @as(f32, @floatFromInt(i)) * 0.48;
        const radius = 44.0 + @as(f32, @floatFromInt(i)) * 9.0;
        const alpha = toU8(80.0 + 90.0 * (0.5 + 0.5 * @sin(phase)));
        rl.DrawCircleLines(cx, cy, radius, rgba(104, 176, 255, alpha));
    }
    drawCenteredText("LOADING", cx, cy - 10, 24, rgb(226, 234, 244));
    drawCenteredText("asset missing", cx, cy + 24, 16, rgb(255, 150, 110));
}

fn drawResearch(game: *GameState) void {
    drawCinematicSpace(game.ui_time_s * 0.65, rgb(8, 8, 22), rgb(28, 22, 48), rgb(160, 112, 255));
    const panel = rect(74, 54, 1136, 612);
    drawGlassPanel(panel, rgb(160, 112, 255), 228);
    drawTextShadow("Research Lab", 112, 86, 46, rgb(255, 236, 39));
    drawFormat("Research Points: {d}", .{game.story.research_points}, 112, 144, 22, rgb(104, 230, 255));
    drawFormat("Unlocked Tech: {d}/{d}", .{ @popCount(game.tech_flags), @as(i32, @intCast(research_catalog.len)) }, 340, 144, 22, rgb(176, 190, 214));

    drawText("Spend research points to unlock low-level rocket systems.", 112, 180, 18, rgb(210, 224, 244));
    drawText("1-4 unlock | F fund research | Esc back", 112, 628, 17, rgb(150, 160, 180));

    var i: usize = 0;
    while (i < research_catalog.len) : (i += 1) {
        const col = i % 2;
        const row = i / 2;
        const card = rect(112.0 + @as(f32, @floatFromInt(col)) * 534.0, 222.0 + @as(f32, @floatFromInt(row)) * 146.0, 494.0, 118.0);
        if (drawResearchCard(game, i, card)) {
            unlockResearch(game, i);
        }
    }

    drawGlassPanel(rect(112, 530, 440, 72), rgb(255, 212, 120), 204);
    drawTextShadow("Fund Research", 134, 546, 22, rgb(255, 236, 39));
    drawText("$12,000 converts into +1 research point.", 134, 572, 17, rgb(226, 234, 244));
    if (button(rect(576, 538, 164, 48), "Fund", rgb(84, 116, 96))) {
        fundResearch(game);
    }
    if (button(rect(778, 538, 164, 48), "Back", rgb(82, 90, 112))) {
        game.audio.click();
        game.screen = .title;
    }
}

fn drawResearchCard(game: *GameState, index: usize, r: rl.Rectangle) bool {
    const tech = research_catalog[index];
    const unlocked = (game.tech_flags & tech.flag) != 0;
    const can_afford = game.story.research_points >= tech.cost;
    const mouse = mousePosition();
    const hover = pointInRect(mouse, r);
    const accent = if (unlocked) rgb(120, 230, 150) else if (can_afford) rgb(104, 176, 255) else rgb(150, 110, 180);
    drawGlassPanel(r, accent, if (hover) 232 else 206);
    drawFormat("{d}", .{@as(i32, @intCast(index + 1))}, toI32(r.x + 18.0), toI32(r.y + 18.0), 26, accent);
    drawTextShadow(tech.title, toI32(r.x + 62.0), toI32(r.y + 18.0), 24, rgb(238, 244, 252));
    drawText(tech.subtitle, toI32(r.x + 62.0), toI32(r.y + 50.0), 17, rgb(176, 190, 214));
    drawFormat("Cost: {d} RP", .{tech.cost}, toI32(r.x + 62.0), toI32(r.y + 78.0), 17, rgb(255, 212, 120));
    drawText(if (unlocked) "UNLOCKED" else if (can_afford) "READY" else "LOCKED", toI32(r.x + r.width - 128.0), toI32(r.y + 44.0), 18, if (unlocked) rgb(120, 230, 150) else if (can_afford) rgb(104, 176, 255) else rgb(255, 150, 110));
    return hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
}

fn drawSettings(game: *GameState) void {
    drawCinematicSpace(game.ui_time_s * 0.75, rgb(7, 11, 22), rgb(24, 36, 58), rgb(104, 176, 255));

    const panel = rect(256, 76, 768, 568);
    drawGlassPanel(panel, rgb(104, 176, 255), 234);
    drawTextShadow("Settings", 292, 106, 42, rgb(255, 236, 39));
    drawText("Matches the Python menu: audio, display, resolution, and safe Back/Esc.", 292, 156, 18, rgb(176, 190, 214));

    drawGlassPanel(rect(292, 206, 656, 238), rgb(255, 212, 120), 204);
    drawSectionTitle("Music", 322, 226, rgb(255, 212, 120));
    const music_label: [*:0]const u8 = if (game.settings.music_enabled) "Music: ON" else "Music: OFF";
    if (button(rect(322, 264, 168, 42), music_label, if (game.settings.music_enabled) rgb(84, 116, 96) else rgb(92, 80, 84))) {
        toggleMusicEnabled(game);
    }
    if (settingsTrackButton(game, rect(512, 264, 376, 42))) {
        cycleMusicTrack(game);
    }
    drawSettingsSlider("Music Volume", game.settings.music_volume, .music);
    drawSettingsSlider("SFX Volume", game.settings.sfx_volume, .sfx);

    drawGlassPanel(rect(292, 472, 656, 82), rgb(104, 176, 255), 204);
    drawSectionTitle("Display", 322, 488, rgb(104, 176, 255));

    const fullscreen_label: [*:0]const u8 = if (game.settings.fullscreen) "Fullscreen: ON" else "Fullscreen: OFF";
    if (button(rect(322, 526, 232, 36), fullscreen_label, rgb(84, 116, 96))) {
        game.settings.fullscreen = !game.settings.fullscreen;
        applyDisplaySettings(game);
    }
    if (button(rect(584, 526, 232, 36), resolution_options[game.settings.resolution_index].label, rgb(70, 105, 170))) {
        game.settings.resolution_index = (game.settings.resolution_index + 1) % resolution_options.len;
        applyDisplaySettings(game);
    }

    if (button(rect(780, 586, 168, 46), "Back", rgb(82, 90, 112))) {
        game.audio.click();
        game.screen = .title;
    }
    drawText("M music on/off | T track | F fullscreen | R resolution | Esc main menu", 292, 604, 17, rgb(150, 160, 180));
}

fn drawSettingsSlider(label: [*:0]const u8, value: f32, slider: SettingSlider) void {
    const bar = settingsSliderRect(slider);
    const y = toI32(bar.y) - 34;
    const clamped = std.math.clamp(value, 0.0, 1.0);
    drawTextShadow(label, 322, y, 20, rgb(226, 234, 244));
    drawFormat("{d}%", .{@as(i32, @intFromFloat(clamped * 100.0))}, 844, y, 20, rgb(255, 212, 120));
    drawProgressBar(rect(bar.x, bar.y, bar.width, bar.height), clamped, rgb(255, 212, 120));
    drawCircleGradient(toI32(bar.x + bar.width * clamped), toI32(bar.y + bar.height * 0.5), 18.0, rgba(255, 236, 160, 190), rgba(255, 236, 160, 0));
    rl.DrawCircle(toI32(bar.x + bar.width * clamped), toI32(bar.y + bar.height * 0.5), 12.0, rgb(232, 238, 248));
    rl.DrawCircleLines(toI32(bar.x + bar.width * clamped), toI32(bar.y + bar.height * 0.5), 12.0, rgb(16, 20, 28));
}

fn settingsTrackButton(game: *GameState, r: rl.Rectangle) bool {
    const mouse = mousePosition();
    const hover = pointInRect(mouse, r);
    const fill = if (hover) lighten(rgb(70, 105, 170)) else rgb(70, 105, 170);
    rl.DrawRectangleRounded(rect(r.x + 5.0, r.y + 6.0, r.width, r.height), 0.16, 8, rgba(0, 0, 0, if (hover) 120 else 78));
    rl.DrawRectangleRounded(r, 0.16, 8, fill);
    rl.DrawRectangleRoundedLinesEx(r, 0.16, 8, 2.0, if (hover) rgb(255, 212, 120) else rgba(16, 20, 28, 220));
    drawText("Track:", toI32(r.x + 18.0), toI32(r.y + 12.0), 16, rgb(190, 210, 235));
    rl.BeginScissorMode(toI32(r.x + 78.0), toI32(r.y + 4.0), toI32(r.width - 94.0), toI32(r.height - 8.0));
    drawTextShadow(game.audio.currentMusicLabel(), toI32(r.x + 80.0), toI32(r.y + 10.0), 18, rgb(245, 248, 255));
    rl.EndScissorMode();
    return hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
}

fn drawTown(game: *GameState) void {
    drawTownWorld(game);
    drawTownHud(game);

    if (!game.map_open and game.dialogue_npc < 0) {
        if (button(rect(22, @as(f32, @floatFromInt(config.screen_height - 62)), 122, 40), "Hangar", rgb(84, 116, 96))) {
            game.audio.click();
            game.screen = .hangar;
        }
        if (button(rect(154, @as(f32, @floatFromInt(config.screen_height - 62)), 118, 40), "Launch", rgb(70, 105, 170))) {
            beginLaunch(game);
        }
        if (button(rect(282, @as(f32, @floatFromInt(config.screen_height - 62)), 98, 40), "Map", rgb(82, 90, 112))) {
            game.map_open = true;
            game.audio.click();
        }
    }

    if (game.map_open) drawFullTownMap(game);
    if (game.dialogue_npc >= 0) drawNpcDialogue(game);
}

fn drawTownWorld(game: *GameState) void {
    const light = game.time.lightLevel();
    const sky_top = mixColor(rgb(32, 48, 78), rgb(116, 182, 224), light);
    const sky_bottom = mixColor(rgb(42, 54, 76), rgb(194, 220, 208), light);
    rl.DrawRectangleGradientV(0, 0, config.screen_width, config.screen_height, sky_top, sky_bottom);

    if (game.ldtk_visuals.ready) {
        drawLdtkVisualTiles(game);
    } else {
        const sun_col = mixColor(rgb(170, 205, 255), rgb(255, 226, 126), light);
        drawCircleGradient(1048, 112, 76.0, rgba(sun_col.r, sun_col.g, sun_col.b, 150), rgba(sun_col.r, sun_col.g, sun_col.b, 0));
        rl.DrawCircle(1048, 112, 28.0, rgba(sun_col.r, sun_col.g, sun_col.b, 210));
        rl.DrawTriangle(.{ .x = 0, .y = 258 }, .{ .x = 248, .y = 120 }, .{ .x = 542, .y = 258 }, rgba(38, 66, 72, 170));
        rl.DrawTriangle(.{ .x = 336, .y = 258 }, .{ .x = 760, .y = 112 }, .{ .x = 1100, .y = 258 }, rgba(42, 72, 78, 160));
        rl.DrawTriangle(.{ .x = 778, .y = 258 }, .{ .x = 1120, .y = 154 }, .{ .x = 1280, .y = 258 }, rgba(48, 78, 82, 145));
        rl.DrawRectangleGradientV(0, 242, config.screen_width, 84, rgba(86, 138, 102, 90), rgba(86, 138, 102, 0));

        const tile = @as(f32, @floatFromInt(map_mod.tile_size));
        var start_x = @as(i32, @intFromFloat(game.people.camera_x / tile)) - 1;
        var start_y = @as(i32, @intFromFloat(game.people.camera_y / tile)) - 1;
        var end_x = @as(i32, @intFromFloat((game.people.camera_x + @as(f32, @floatFromInt(config.screen_width))) / tile)) + 2;
        var end_y = @as(i32, @intFromFloat((game.people.camera_y + @as(f32, @floatFromInt(config.screen_height))) / tile)) + 2;
        start_x = @max(0, start_x);
        start_y = @max(0, start_y);
        end_x = @min(@as(i32, @intFromFloat(map_mod.world_width / tile)), end_x);
        end_y = @min(@as(i32, @intFromFloat(map_mod.world_height / tile)), end_y);

        var ty = start_y;
        while (ty <= end_y) : (ty += 1) {
            var tx = start_x;
            while (tx <= end_x) : (tx += 1) {
                const wx = @as(f32, @floatFromInt(tx * map_mod.tile_size));
                const wy = @as(f32, @floatFromInt(ty * map_mod.tile_size));
                if (wy + tile < map_mod.ground_y) continue;
                const screen = game.people.worldToScreen(wx, wy);
                const kind = game.town_map.tileAt(wx + tile * 0.5, wy + tile * 0.5);
                rl.DrawRectangle(toI32(screen.x), toI32(screen.y), map_mod.tile_size + 1, map_mod.tile_size + 1, tileColor(kind, tx, ty, light));
                if (kind == .cobblestone) {
                    rl.DrawRectangleLines(toI32(screen.x), toI32(screen.y), map_mod.tile_size + 1, map_mod.tile_size + 1, rgba(70, 76, 84, 92));
                } else if (kind == .water) {
                    rl.DrawCircle(toI32(screen.x + 16), toI32(screen.y + 16), 9.0, rgba(150, 220, 245, 80));
                }
            }
        }
    }

    for (0..game.town_map.zone_count) |i| {
        const zone = game.town_map.zones[i];
        const p = game.people.worldToScreen(zone.rect.x, zone.rect.y);
        rl.DrawRectangleLinesEx(rect(p.x, p.y, zone.rect.w, zone.rect.h), 1.0, rgba(zone.color_r, zone.color_g, zone.color_b, 110));
    }

    drawTownBuildings(game);
    for (0..people_mod.npc_count) |i| {
        drawNpc(game, &game.people.npcs[i]);
    }
    drawPlayer(game);
}

fn drawLdtkVisualTiles(game: *GameState) void {
    if (!game.ldtk_visuals.ready) return;
    var i: usize = 0;
    while (i < game.ldtk_visuals.tile_count) : (i += 1) {
        const tile = game.ldtk_visuals.tiles[i];
        const tileset_index = @as(usize, @intCast(tile.tileset_index));
        if (tileset_index >= game.ldtk_visuals.tileset_count) continue;
        const tileset = game.ldtk_visuals.tilesets[tileset_index];
        if (!tileset.ready) continue;

        const p = game.people.worldToScreen(tile.px_x, tile.px_y);
        if (p.x + tile.size < -32.0 or p.y + tile.size < -32.0) continue;
        if (p.x > @as(f32, @floatFromInt(config.screen_width + 32)) or p.y > @as(f32, @floatFromInt(config.screen_height + 32))) continue;

        rl.DrawTexturePro(
            tileset.texture,
            rect(tile.src_x, tile.src_y, tile.size, tile.size),
            rect(p.x, p.y, tile.size, tile.size),
            .{ .x = 0.0, .y = 0.0 },
            0.0,
            rgb(255, 255, 255),
        );
    }
}

fn drawTownHud(game: *GameState) void {
    drawGlassPanel(rect(18, 18, 428, 96), rgb(255, 212, 120), 210);
    drawTextShadow("RocketCraft Town", 34, 30, 26, rgb(255, 236, 39));
    drawFormat("Funds ${d} | Day {d} {d}:{d:0>2}", .{ game.money, game.time.day, game.time.hour, @as(i32, @intFromFloat(game.time.minute)) }, 34, 62, 18, rgb(226, 234, 244));
    drawFormat("Zone: {s}", .{game.town_map.zoneName(game.people.current_zone)}, 34, 86, 16, rgb(176, 190, 214));

    drawGlassPanel(rect(@as(f32, @floatFromInt(config.screen_width - 340)), 18, 322, 96), rgb(104, 176, 255), 202);
    drawText("WASD/Arrows or click to walk", config.screen_width - 306, 32, 17, rgb(226, 234, 244));
    drawText("E talk | M map | H hangar | L launch", config.screen_width - 306, 58, 16, rgb(176, 190, 214));
    drawFormat("Rep {d} | Research {d} | Ach {d}", .{ game.story.reputation, game.story.research_points, @popCount(game.achievements.unlocked) }, config.screen_width - 306, 82, 16, rgb(176, 190, 214));
}

fn drawTownBuildings(game: *GameState) void {
    const count = @min(game.town_map.building_count, map_mod.max_buildings);
    var order: [map_mod.max_buildings]usize = undefined;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        order[i] = i;
    }

    i = 1;
    while (i < count) : (i += 1) {
        const key = order[i];
        const key_depth = buildingDepth(&game.town_map.buildings[key]);
        var j = i;
        while (j > 0 and buildingDepth(&game.town_map.buildings[order[j - 1]]) > key_depth) : (j -= 1) {
            order[j] = order[j - 1];
        }
        order[j] = key;
    }

    i = 0;
    while (i < count) : (i += 1) {
        drawBuilding(game, &game.town_map.buildings[order[i]]);
    }
}

fn buildingDepth(building: *const map_mod.Building) f32 {
    return building.rect.y + building.rect.h;
}

fn drawBuilding(game: *GameState, building: *const map_mod.Building) void {
    if (game.buildings.textureFor(building.action)) |texture| {
        drawBuildingSprite(game, building, texture);
        return;
    }
    drawFallbackBuilding(game, building);
}

fn drawBuildingSprite(game: *GameState, building: *const map_mod.Building, texture: rl.Texture2D) void {
    if (texture.width <= 0 or texture.height <= 0) {
        drawFallbackBuilding(game, building);
        return;
    }

    const base = game.people.worldToScreen(building.rect.x + building.rect.w * 0.5, building.rect.y + building.rect.h);
    const tw = @as(f32, @floatFromInt(texture.width));
    const th = @as(f32, @floatFromInt(texture.height));
    const target_w = buildingSpriteWidth(building.action);
    const target_h = target_w * (th / tw);
    const dest = rect(base.x - target_w * 0.5, base.y - target_h, target_w, target_h);

    rl.DrawEllipse(toI32(base.x), toI32(base.y + 10.0), target_w * 0.42, 15.0, rgba(0, 0, 0, 58));
    rl.DrawTexturePro(
        texture,
        rect(0.0, 0.0, tw, th),
        dest,
        .{ .x = 0.0, .y = 0.0 },
        0.0,
        rgb(255, 255, 255),
    );
    drawCenteredText(building.name, toI32(base.x), toI32(dest.y - 16.0), 15, rgb(245, 248, 255));
}

fn buildingSpriteWidth(action: map_mod.BuildingAction) f32 {
    return switch (action) {
        .hangar => 230.0,
        .contracts => 205.0,
        .research => 218.0,
        .shop => 210.0,
        .maria_home => 170.0,
        .house, .bob_home, .jenkins_home, .chen_home => 160.0,
    };
}

fn drawFallbackBuilding(game: *GameState, building: *const map_mod.Building) void {
    const p = game.people.worldToScreen(building.rect.x, building.rect.y);
    const x = toI32(p.x);
    const y = toI32(p.y);
    const w = toI32(building.rect.w);
    const h = toI32(building.rect.h);
    rl.DrawEllipse(x + @divTrunc(w, 2), y + h + 10, @as(f32, @floatFromInt(w)) * 0.46, 14.0, rgba(0, 0, 0, 55));
    rl.DrawRectangleGradientV(x, y + 20, w, h - 20, lighten(rgb(building.color_r, building.color_g, building.color_b)), rgb(building.color_r, building.color_g, building.color_b));
    rl.DrawTriangle(
        .{ .x = @as(f32, @floatFromInt(x - 8)), .y = @as(f32, @floatFromInt(y + 24)) },
        .{ .x = @as(f32, @floatFromInt(x + w + 8)), .y = @as(f32, @floatFromInt(y + 24)) },
        .{ .x = @as(f32, @floatFromInt(x + @divTrunc(w, 2))), .y = @as(f32, @floatFromInt(y)) },
        rgb(108, 66, 58),
    );
    rl.DrawRectangleLines(x, y + 20, w, h - 20, rgb(30, 34, 44));
    var wx = x + 16;
    while (wx + 18 < x + w) : (wx += 34) {
        rl.DrawRectangle(wx, y + 42, 18, 16, rgba(255, 236, 160, 160));
        rl.DrawRectangleLines(wx, y + 42, 18, 16, rgba(28, 32, 40, 170));
    }
    rl.DrawRectangle(x + @divTrunc(w, 2) - 12, y + h - 34, 24, 34, rgb(68, 48, 38));
    drawTextShadow(building.name, x, y - 20, 15, rgb(245, 248, 255));
}

fn drawNpc(game: *GameState, npc: *const people_mod.Npc) void {
    const p = game.people.worldToScreen(npc.x, npc.y);
    rl.DrawEllipse(toI32(p.x), toI32(p.y + 12), 14.0, 5.0, rgba(0, 0, 0, 58));
    rl.DrawCircle(toI32(p.x), toI32(p.y - 18), 12.0, rgb(28, 32, 38));
    rl.DrawCircle(toI32(p.x), toI32(p.y - 18), 10.0, rgb(238, 206, 170));
    rl.DrawRectangle(toI32(p.x - 12), toI32(p.y - 12), 24, 28, rgb(28, 32, 38));
    rl.DrawRectangle(toI32(p.x - 10), toI32(p.y - 10), 20, 24, rgb(npc.color_r, npc.color_g, npc.color_b));
    rl.DrawRectangle(toI32(p.x - 9), toI32(p.y - 8), 18, 5, rgba(255, 255, 255, 45));
    const foot_offset: f32 = if ((npc.flags & people_mod.NpcFlags.moving) != 0) @as(f32, @floatFromInt((npc.walk_frame & 1) * 4)) else 0.0;
    rl.DrawLine(toI32(p.x - 5), toI32(p.y + 14), toI32(p.x - 10 + foot_offset), toI32(p.y + 24), rgb(28, 32, 38));
    rl.DrawLine(toI32(p.x + 5), toI32(p.y + 14), toI32(p.x + 10 - foot_offset), toI32(p.y + 24), rgb(28, 32, 38));
    drawTextShadow(npc.name, toI32(p.x - 32), toI32(p.y - 48), 14, rgb(255, 255, 255));
}

fn drawPlayer(game: *GameState) void {
    const p = game.people.worldToScreen(game.people.player.x, game.people.player.y);
    rl.DrawEllipse(toI32(p.x), toI32(p.y + 14), 16.0, 6.0, rgba(0, 0, 0, 70));
    drawCircleGradient(toI32(p.x), toI32(p.y - 4), 32.0, rgba(255, 236, 39, 52), rgba(255, 236, 39, 0));
    rl.DrawCircle(toI32(p.x), toI32(p.y - 18), 13.0, rgb(28, 32, 38));
    rl.DrawCircle(toI32(p.x), toI32(p.y - 18), 11.0, rgb(242, 210, 172));
    rl.DrawRectangle(toI32(p.x - 13), toI32(p.y - 10), 26, 32, rgb(28, 32, 38));
    rl.DrawRectangle(toI32(p.x - 11), toI32(p.y - 8), 22, 28, rgb(255, 236, 39));
    rl.DrawRectangleLines(toI32(p.x - 11), toI32(p.y - 8), 22, 28, rgb(30, 34, 44));
}

fn drawFullTownMap(game: *GameState) void {
    rl.DrawRectangle(0, 0, config.screen_width, config.screen_height, rgba(0, 0, 0, 150));
    const panel = rect(200, 86, 880, 560);
    drawGlassPanel(panel, rgb(104, 176, 255), 232);
    drawTextShadow("Town Map", 230, 112, 28, rgb(255, 236, 39));
    const map_rect = rect(250, 160, 780, 440);
    rl.DrawRectangleRounded(map_rect, 0.025, 8, rgb(54, 92, 58));
    rl.DrawRectangleRoundedLinesEx(map_rect, 0.025, 8, 2.0, rgba(226, 234, 244, 120));
    const sx = map_rect.width / map_mod.world_width;
    const sy = map_rect.height / map_mod.world_height;
    for (0..game.town_map.zone_count) |i| {
        const zone = game.town_map.zones[i];
        rl.DrawRectangleLinesEx(rect(map_rect.x + zone.rect.x * sx, map_rect.y + zone.rect.y * sy, zone.rect.w * sx, zone.rect.h * sy), 1.0, rgba(zone.color_r, zone.color_g, zone.color_b, 180));
    }
    for (0..game.town_map.collision_count) |i| {
        const c = game.town_map.collision_rects[i].rect;
        rl.DrawRectangleRec(rect(map_rect.x + c.x * sx, map_rect.y + c.y * sy, c.w * sx, c.h * sy), rgba(255, 80, 80, 78));
    }
    for (0..game.town_map.building_count) |i| {
        const b = game.town_map.buildings[i];
        rl.DrawRectangleRec(rect(map_rect.x + b.rect.x * sx, map_rect.y + b.rect.y * sy, b.rect.w * sx, b.rect.h * sy), rgb(b.color_r, b.color_g, b.color_b));
    }
    for (0..people_mod.npc_count) |i| {
        const npc = game.people.npcs[i];
        rl.DrawCircle(toI32(map_rect.x + npc.x * sx), toI32(map_rect.y + npc.y * sy), 4.0, rgb(npc.color_r, npc.color_g, npc.color_b));
    }
    rl.DrawCircle(toI32(map_rect.x + game.people.player.x * sx), toI32(map_rect.y + game.people.player.y * sy), 6.0, rgb(255, 236, 39));
    drawText("M/Esc close", 230, 612, 18, rgb(176, 190, 214));
}

fn drawNpcDialogue(game: *GameState) void {
    const index = @as(usize, @intCast(game.dialogue_npc));
    if (index >= people_mod.npc_count) return;
    const npc = &game.people.npcs[index];
    rl.DrawRectangle(0, 0, config.screen_width, config.screen_height, rgba(0, 0, 0, 78));

    const panel = rect(74, @as(f32, @floatFromInt(config.screen_height - 302)), @as(f32, @floatFromInt(config.screen_width - 148)), 264);
    drawDialogueFrame(panel);

    const text_panel = rect(panel.x + 26.0, panel.y + 28.0, 738.0, 196.0);
    drawDialogueInset(text_panel, rgb(255, 205, 128));
    const body = dialogueBodyBytes(people_mod.dialogueText(npc, &game.time, &game.story));
    drawWrappedTextBytes(body, toI32(text_panel.x + 24.0), toI32(text_panel.y + 28.0), toI32(text_panel.width - 48.0), 30, rgb(84, 34, 31));
    drawText("Enter / Space / Click", toI32(text_panel.x + 24.0), toI32(text_panel.y + text_panel.height - 28.0), 16, rgb(130, 76, 46));

    const portrait_side = rect(panel.x + 800.0, panel.y + 12.0, 296.0, 246.0);
    drawDialogueInset(portrait_side, rgb(226, 172, 98));
    const portrait_frame = rect(portrait_side.x + 58.0, portrait_side.y + 16.0, 180.0, 180.0);
    drawPortraitFrame(portrait_frame);
    drawNpcPortrait(game, npc, portrait_frame);

    const name_plate = rect(portrait_side.x + 44.0, portrait_side.y + 190.0, 208.0, 42.0);
    drawNamePlate(name_plate, npc.name, npc.role);
}

fn drawDialogueFrame(r: rl.Rectangle) void {
    rl.DrawRectangle(toI32(r.x - 10.0), toI32(r.y + 10.0), toI32(r.width + 20.0), toI32(r.height + 8.0), rgba(0, 0, 0, 130));
    rl.DrawRectangleRec(r, rgb(91, 44, 22));
    rl.DrawRectangleRec(rect(r.x + 6.0, r.y + 6.0, r.width - 12.0, r.height - 12.0), rgb(190, 92, 28));
    rl.DrawRectangleRec(rect(r.x + 12.0, r.y + 12.0, r.width - 24.0, r.height - 24.0), rgb(126, 66, 34));
    rl.DrawRectangleGradientV(toI32(r.x + 20.0), toI32(r.y + 20.0), toI32(r.width - 40.0), toI32(r.height - 40.0), rgb(245, 177, 92), rgb(232, 147, 68));
    rl.DrawRectangleLinesEx(r, 3.0, rgb(255, 184, 54));
    rl.DrawRectangleLinesEx(rect(r.x + 12.0, r.y + 12.0, r.width - 24.0, r.height - 24.0), 2.0, rgb(94, 39, 24));

    const knob = rgb(205, 102, 30);
    rl.DrawRectangle(toI32(r.x - 14.0), toI32(r.y + 18.0), 18, 42, knob);
    rl.DrawRectangle(toI32(r.x + r.width - 4.0), toI32(r.y + 18.0), 18, 42, knob);
    rl.DrawRectangle(toI32(r.x - 14.0), toI32(r.y + r.height - 60.0), 18, 42, knob);
    rl.DrawRectangle(toI32(r.x + r.width - 4.0), toI32(r.y + r.height - 60.0), 18, 42, knob);
}

fn drawDialogueInset(r: rl.Rectangle, fill: rl.Color) void {
    rl.DrawRectangleRec(r, rgb(97, 43, 25));
    rl.DrawRectangleRec(rect(r.x + 4.0, r.y + 4.0, r.width - 8.0, r.height - 8.0), rgb(180, 96, 38));
    rl.DrawRectangleGradientV(toI32(r.x + 8.0), toI32(r.y + 8.0), toI32(r.width - 16.0), toI32(r.height - 16.0), fill, rgb(244, 172, 92));
    rl.DrawRectangleLinesEx(rect(r.x + 8.0, r.y + 8.0, r.width - 16.0, r.height - 16.0), 1.0, rgba(120, 58, 26, 150));
}

fn drawPortraitFrame(r: rl.Rectangle) void {
    rl.DrawRectangleRec(r, rgb(79, 36, 25));
    rl.DrawRectangleRec(rect(r.x + 8.0, r.y + 8.0, r.width - 16.0, r.height - 16.0), rgb(210, 137, 55));
    rl.DrawRectangleRec(rect(r.x + 16.0, r.y + 16.0, r.width - 32.0, r.height - 32.0), rgb(250, 219, 170));
    rl.DrawRectangleLinesEx(rect(r.x + 16.0, r.y + 16.0, r.width - 32.0, r.height - 32.0), 2.0, rgb(118, 58, 32));
}

fn drawNpcPortrait(game: *GameState, npc: *const people_mod.Npc, frame: rl.Rectangle) void {
    const art = rect(frame.x + 16.0, frame.y + 16.0, frame.width - 32.0, frame.height - 32.0);
    if (game.portraits.textureFor(npc.kind)) |texture| {
        rl.DrawTexturePro(
            texture,
            rect(0.0, 0.0, @as(f32, @floatFromInt(texture.width)), @as(f32, @floatFromInt(texture.height))),
            art,
            .{ .x = 0.0, .y = 0.0 },
            0.0,
            rgb(255, 255, 255),
        );
        return;
    }
    drawFallbackPortrait(npc, art);
}

fn drawFallbackPortrait(npc: *const people_mod.Npc, r: rl.Rectangle) void {
    const cx = toI32(r.x + r.width * 0.5);
    const base_y = toI32(r.y + r.height * 0.84);
    const accent = rgb(npc.color_r, npc.color_g, npc.color_b);
    drawCircleGradient(cx, toI32(r.y + r.height * 0.48), r.width * 0.42, rgba(accent.r, accent.g, accent.b, 90), rgba(accent.r, accent.g, accent.b, 0));
    rl.DrawRectangleRounded(rect(r.x + r.width * 0.28, r.y + r.height * 0.50, r.width * 0.44, r.height * 0.44), 0.18, 8, accent);
    rl.DrawCircle(cx, toI32(r.y + r.height * 0.36), r.width * 0.20, rgb(236, 196, 154));
    rl.DrawRectangle(toI32(r.x + r.width * 0.36), toI32(r.y + r.height * 0.24), toI32(r.width * 0.28), toI32(r.height * 0.10), rgb(36, 30, 34));
    rl.DrawCircle(cx - 15, toI32(r.y + r.height * 0.35), 3.0, rgb(36, 30, 34));
    rl.DrawCircle(cx + 15, toI32(r.y + r.height * 0.35), 3.0, rgb(36, 30, 34));
    rl.DrawEllipse(cx, base_y, r.width * 0.30, 8.0, rgba(0, 0, 0, 60));
}

fn drawNamePlate(r: rl.Rectangle, name: [*:0]const u8, role: [*:0]const u8) void {
    rl.DrawRectangleRec(r, rgb(98, 45, 26));
    rl.DrawRectangleRec(rect(r.x + 5.0, r.y + 5.0, r.width - 10.0, r.height - 10.0), rgb(255, 234, 180));
    rl.DrawRectangleLinesEx(r, 2.0, rgb(220, 128, 38));
    const name_width = rl.MeasureText(name, 22);
    drawTextShadow(name, toI32(r.x + r.width * 0.5) - @divTrunc(name_width, 2), toI32(r.y + 7.0), 22, rgb(84, 34, 31));
    const role_width = rl.MeasureText(role, 13);
    drawText(role, toI32(r.x + r.width * 0.5) - @divTrunc(role_width, 2), toI32(r.y + 30.0), 13, rgb(130, 76, 46));
}

fn dialogueBodyBytes(text: [*:0]const u8) []const u8 {
    const bytes = std.mem.span(text);
    if (std.mem.indexOfScalar(u8, bytes, ':')) |colon| {
        var start = colon + 1;
        while (start < bytes.len and bytes[start] == ' ') : (start += 1) {}
        return bytes[start..];
    }
    return bytes;
}

fn drawWrappedTextBytes(text: []const u8, x: i32, y: i32, max_width: i32, size: i32, col: rl.Color) void {
    var line = [_]u8{0} ** 256;
    var line_len: usize = 0;
    var cursor_y = y;
    var i: usize = 0;
    while (i < text.len) {
        while (i < text.len and text[i] == ' ') : (i += 1) {}
        if (i >= text.len) break;
        const word_start = i;
        while (i < text.len and text[i] != ' ') : (i += 1) {}
        const word = text[word_start..i];
        if (word.len == 0) continue;
        if (!wrappedLineCanFit(&line, line_len, word, max_width, size)) {
            flushWrappedLine(&line, &line_len, x, &cursor_y, size, col);
        }
        appendWordToWrappedLine(&line, &line_len, word);
    }
    flushWrappedLine(&line, &line_len, x, &cursor_y, size, col);
}

fn wrappedLineCanFit(line: *[256]u8, line_len: usize, word: []const u8, max_width: i32, size: i32) bool {
    var candidate = [_]u8{0} ** 256;
    var len = line_len;
    if (len > 0) {
        @memcpy(candidate[0..len], line[0..len]);
        candidate[len] = ' ';
        len += 1;
    }
    const copy_len = @min(word.len, candidate.len - len - 1);
    @memcpy(candidate[len .. len + copy_len], word[0..copy_len]);
    len += copy_len;
    candidate[len] = 0;
    const measured = rl.MeasureText(candidate[0..len :0].ptr, size);
    return measured <= max_width;
}

fn appendWordToWrappedLine(line: *[256]u8, line_len: *usize, word: []const u8) void {
    if (line_len.* > 0 and line_len.* < line.len - 1) {
        line[line_len.*] = ' ';
        line_len.* += 1;
    }
    const copy_len = @min(word.len, line.len - line_len.* - 1);
    @memcpy(line[line_len.* .. line_len.* + copy_len], word[0..copy_len]);
    line_len.* += copy_len;
    line[line_len.*] = 0;
}

fn flushWrappedLine(line: *[256]u8, line_len: *usize, x: i32, y: *i32, size: i32, col: rl.Color) void {
    if (line_len.* == 0) return;
    line[line_len.*] = 0;
    drawText(line[0..line_len.* :0].ptr, x, y.*, size, col);
    y.* += size + 10;
    line_len.* = 0;
    line[0] = 0;
}

fn drawHangar(game: *GameState) void {
    drawCinematicSpace(game.ui_time_s * 0.5, rgb(8, 11, 18), rgb(22, 27, 38), rgb(255, 156, 84));
    rl.DrawRectangleGradientV(0, 150, config.screen_width, 570, rgba(48, 54, 70, 0), rgba(48, 54, 70, 220));
    var gx: i32 = 0;
    while (gx < config.screen_width) : (gx += 80) rl.DrawLine(gx, 192, gx - 180, 720, rgba(255, 255, 255, 18));
    var gy: i32 = 240;
    while (gy < config.screen_height) : (gy += 58) rl.DrawLine(0, gy, config.screen_width, gy, rgba(255, 255, 255, 14));

    drawHeader(game, "Rocket Hangar - Zig Builder");

    drawGlassPanel(rect(42, 112, 384, 492), rgb(255, 156, 84), 222);
    drawSectionTitle("Part Catalog", 66, 138, rgb(255, 156, 84));

    const kinds = [_]parts.PartKind{
        .command_pod,
        .navigation,
        .life_support,
        .heat_shield,
        .service_module,
        .fuel_tank,
        .landing_leg,
        .basic_engine,
    };

    for (kinds, 0..) |kind, i| {
        const y = 188 + @as(i32, @intCast(i)) * 52;
        const part = parts.spec(kind);
        rl.DrawRectangleRounded(rect(58, @as(f32, @floatFromInt(y - 6)), 340, 48), 0.08, 8, rgba(255, 255, 255, 18));
        if (button(rect(66, @as(f32, @floatFromInt(y)), 112, 40), part.short_name, partColor(kind))) {
            buyPart(game, kind);
        }
        drawTextShadow(part.name, 194, y + 2, 18, rgb(222, 230, 242));
        drawFormat("${d} | {d} kg", .{ part.cost, @as(i32, @intFromFloat(part.mass_kg + part.fuel_kg)) }, 194, y + 24, 16, rgb(150, 166, 196));
    }

    drawStackPanel(game, 470, 112);
    drawValidationPanel(game, 870, 112);

    if (button(rect(470, 626, 180, 50), "Add Missing", rgb(84, 116, 96))) {
        addMissingSystems(game);
    }
    if (button(rect(674, 626, 160, 50), "Preset", rgb(70, 105, 170))) {
        loadPreset(game);
    }
    if (button(rect(858, 626, 160, 50), "Clear", rgb(82, 90, 112))) {
        clearBuild(game);
    }
    const launch_label: [*:0]const u8 = if (parts.isLaunchable(&game.stack)) "Launch" else "Fix + Launch";
    if (button(rect(1042, 626, 176, 50), launch_label, rgb(74, 138, 92))) {
        beginLaunch(game);
    }

    drawText("M add missing | P preset | C clear | Backspace remove | L launch | Esc menu", 42, 690, 17, rgb(150, 160, 180));
}

fn drawIntroCutscene(game: *GameState) void {
    const beat = game.cutscene.beat_index;
    const t = std.math.clamp(game.cutscene.beat_time_s / introBeatDuration(beat), 0.0, 1.0);
    switch (beat) {
        0 => drawIntroFailedTest(game, t),
        1 => drawIntroFallout(game, t),
        2 => drawIntroLetter(game, t),
        3 => drawIntroArrival(game, t),
        else => drawIntroTransition(t),
    }
    drawCutsceneCaption(introBeatCaption(beat), t);
    drawText("SPACE / ENTER / ESC skip", config.screen_width - 248, config.screen_height - 30, 16, rgb(168, 178, 198));
}

fn drawIntroFailedTest(game: *GameState, t: f32) void {
    drawCinematicSpace(game.ui_time_s * 0.55, rgb(11, 16, 28), rgb(28, 32, 46), rgb(255, 156, 84));
    drawCenteredText("ORION HEAVY", @divTrunc(config.screen_width, 2), 110, 34, rgb(150, 158, 172));
    drawCutscenePerson(420, 430, rgb(20, 30, 60), 1.35);
    drawCutscenePerson(820, 430, rgb(20, 30, 60), 1.10);
    rl.DrawLine(570, 500, 710, 500, rgb(80, 86, 100));
    rl.DrawLine(640, 500, 640, 350, rgba(120, 130, 150, 150));
    const tilt = if (t > 0.52) @as(f32, -22.0) else @as(f32, 0.0);
    if (!drawRocketGif(game, 640.0, 418.0, 174.0, tilt, rgb(255, 255, 255))) {
        drawIntroRocket(640, 418, tilt, t > 0.32 and t < 0.62);
    }
    if (t > 0.66) {
        drawCenteredText("LIVE VIEWERS: 12 -> 2,847 -> 147,000", @divTrunc(config.screen_width, 2), 570, 28, rgb(255, 236, 39));
    }
    if (t > 0.78) {
        drawGlassPanel(rect(380, 606, 520, 70), rgb(255, 212, 120), 238);
        drawText("at least it did not explode", 402, 620, 17, rgb(238, 244, 252));
        drawText("bro really said 'trust the science' then fell over", 402, 646, 17, rgb(238, 244, 252));
    }
    if (t > 0.52 and t < 0.57) {
        rl.DrawRectangle(0, 0, config.screen_width, config.screen_height, rgba(255, 255, 255, 210));
    }
}

fn drawIntroFallout(_: *GameState, t: f32) void {
    rl.DrawRectangleGradientV(0, 0, config.screen_width, config.screen_height, rgb(44, 46, 52), rgb(24, 26, 34));
    const third = @as(i32, @intFromFloat(t * 3.0));
    if (third == 0) {
        drawTextShadow("HR OFFICE", 80, 70, 34, rgb(205, 210, 220));
        rl.DrawRectangleRounded(rect(520, 430, 310, 80), 0.06, 8, rgb(60, 62, 70));
        drawCutscenePerson(430, 500, rgb(20, 30, 60), 1.0);
        drawCutscenePerson(700, 420, rgb(20, 30, 60), 1.25);
        drawCenteredText("Security will escort you out.", @divTrunc(config.screen_width, 2), 612, 22, rgb(238, 244, 252));
    } else if (third == 1) {
        drawTextShadow("HALLWAY", 80, 70, 34, rgb(205, 210, 220));
        rl.DrawRectangle(0, 360, config.screen_width, 140, rgb(76, 78, 86));
        drawCutscenePerson(470, 455, rgb(20, 30, 60), 1.0);
        drawCutscenePerson(720, 455, rgb(110, 210, 255), 0.9);
        drawCenteredText("Dr. Chen submitted his resignation the same day.", @divTrunc(config.screen_width, 2), 612, 22, rgb(238, 244, 252));
    } else {
        drawTextShadow("MISSION CONTROL", 80, 70, 34, rgb(205, 210, 220));
        drawGlassPanel(rect(520, 390, 360, 95), rgb(80, 180, 210), 220);
        var x: i32 = 545;
        while (x < 850) : (x += 55) {
            rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x)), 410, 34, 18), 0.12, 8, rgb(80, 180, 210));
        }
        drawCutscenePerson(640, 430, rgb(255, 110, 150), 1.05);
        drawCenteredText("Maria was reassigned to Document Archival.", @divTrunc(config.screen_width, 2), 612, 22, rgb(238, 244, 252));
    }
}

fn drawIntroLetter(game: *GameState, t: f32) void {
    rl.DrawRectangleGradientV(0, 0, config.screen_width, config.screen_height, rgb(20, 22, 32), rgb(42, 45, 58));
    if (t < 0.72) {
        const paper = rect(@as(f32, @floatFromInt(@divTrunc(config.screen_width, 2) - 210)), 120, 420, 420);
        rl.DrawRectangleRounded(paper, 0.035, 8, rgb(255, 250, 230));
        rl.DrawRectangleRoundedLinesEx(paper, 0.035, 8, 2.0, rgb(190, 170, 130));
        drawText("old launch base at plaza...", 430, 190, 22, rgb(72, 64, 52));
        if (t > 0.22) drawText("one hangar left...", 430, 238, 22, rgb(72, 64, 52));
        if (t > 0.38) drawText("50,000 from the town council...", 430, 286, 22, rgb(72, 64, 52));
        if (t > 0.54) drawText("just the four of us...", 430, 334, 22, rgb(72, 64, 52));
        if (t > 0.66) drawText("come be director.", 430, 382, 22, rgb(72, 64, 52));
    } else {
        drawCinematicSpace(game.ui_time_s * 0.8, rgb(42, 60, 72), rgb(80, 110, 92), rgb(255, 212, 120));
        const offset = @as(i32, @intFromFloat((t - 0.72) * 900.0));
        var x: i32 = -200;
        while (x < config.screen_width + 200) : (x += 180) {
            drawIntroTree(x - @mod(offset, 180), 420);
        }
        rl.DrawRectangle(0, 470, config.screen_width, 250, rgb(74, 110, 58));
        rl.DrawRectangle(0, 520, config.screen_width, 50, rgb(90, 64, 50));
        drawCenteredText("Bus window, somewhere far from Orion", @divTrunc(config.screen_width, 2), 612, 22, rgb(238, 244, 252));
    }
}

fn drawIntroArrival(game: *GameState, t: f32) void {
    const sky_top = if (t < 0.82) rgb(126, 142, 158) else rgb(116, 176, 220);
    const sky_bottom = if (t < 0.82) rgb(172, 184, 188) else rgb(200, 228, 246);
    rl.DrawRectangleGradientV(0, 0, config.screen_width, config.screen_height, sky_top, sky_bottom);
    rl.DrawRectangle(0, 430, config.screen_width, 290, rgb(74, 130, 72));
    rl.DrawRectangleRounded(rect(760, 330, 230, 120), 0.05, 8, rgb(92, 96, 104));
    rl.DrawTriangle(.{ .x = 740, .y = 330 }, .{ .x = 875, .y = 255 }, .{ .x = 1015, .y = 330 }, rgb(62, 66, 76));
    const bus_x = @as(i32, @intFromFloat(-260.0 + std.math.clamp(t, 0.0, 0.22) / 0.22 * 420.0));
    drawIntroBus(bus_x, 405);
    drawCutscenePerson(320, 456, rgb(40, 48, 70), 0.95);
    if (t > 0.16) drawCutscenePerson(430, 456, rgb(180, 170, 140), 1.0);
    if (t > 0.38) drawCutscenePerson(570, 456, rgb(255, 110, 150), 1.0);
    if (t > 0.58) drawCutscenePerson(700, 456, rgb(110, 210, 255), 1.0);
    if (t > 0.76) drawCutscenePerson(840, 456, rgb(255, 170, 70), 1.0);
    if (t > 0.86) {
        drawCircleGradient(1050, 130, 80.0 + (t - 0.86) * 280.0, rgba(255, 230, 125, 130), rgba(255, 230, 125, 0));
        drawCenteredText("ROCKETCRAFT", @divTrunc(config.screen_width, 2), 190, 62, rgb(255, 255, 255));
        drawCenteredText("Build. Launch. Prove them wrong.", @divTrunc(config.screen_width, 2), 260, 34, rgb(255, 236, 39));
    }
    if (t < 0.82) {
        var i: i32 = 0;
        while (i < 120) : (i += 1) {
            const x = @mod(i * 37 + @as(i32, @intFromFloat(game.cutscene.beat_time_s * 90.0)), config.screen_width);
            const y = @mod(i * 23 + @as(i32, @intFromFloat(game.cutscene.beat_time_s * 180.0)), config.screen_height);
            rl.DrawLine(x, y, x - 5, y + 14, rgb(190, 210, 230));
        }
    }
}

fn drawIntroTransition(t: f32) void {
    rl.ClearBackground(rgb(0, 0, 0));
    const alpha = @as(u8, @intFromFloat(std.math.clamp(t * 2.0, 0.0, 1.0) * 255.0));
    drawCenteredText("ENTER ROCKETCRAFT", @divTrunc(config.screen_width, 2), @divTrunc(config.screen_height, 2), 34, rgba(255, 236, 39, alpha));
}

fn drawMissionCutscene(game: *GameState) void {
    const beat = game.cutscene.beat_index;
    const t = std.math.clamp(game.cutscene.beat_time_s / cutsceneBeatDuration(beat), 0.0, 1.0);
    switch (beat) {
        0 => drawCutsceneRollout(game, t),
        1 => drawCutsceneSystems(game, t),
        2 => drawCutsceneIgnition(game, t),
        else => drawCutsceneBlackout(game, t),
    }
    drawCutsceneCaption(cutsceneBeatCaption(beat), t);
    drawText("SPACE / ENTER / ESC skip", config.screen_width - 248, config.screen_height - 30, 16, rgb(168, 178, 198));
}

fn drawCutsceneRollout(game: *GameState, t: f32) void {
    drawCutsceneSpaceport(game, t);
    const pad_x: i32 = 760;
    const rocket_x = @as(i32, @intFromFloat(230.0 + std.math.clamp(t / 0.72, 0.0, 1.0) * 500.0));
    drawServiceTower(pad_x, 430);
    drawTransport(rocket_x, 500);
    if (!drawRocketGif(game, @as(f32, @floatFromInt(rocket_x + 64)), 414.0, 214.0, 0.0, rgb(255, 255, 255))) {
        drawCutsceneRocket(rocket_x + 64, 414, 1.15, false, 0.0);
    }
    if (t > 0.72) {
        if (!drawRocketGif(game, @as(f32, @floatFromInt(pad_x + 40)), 380.0, 226.0, 0.0, rgb(255, 255, 255))) {
            drawCutsceneRocket(pad_x + 40, 380, 1.22, false, 0.0);
        }
    }
    drawTextShadow("ROLL OUT", 92, 82, 38, rgb(255, 236, 39));
}

fn drawCutsceneSystems(game: *GameState, t: f32) void {
    _ = game;
    rl.DrawRectangleGradientV(0, 0, config.screen_width, config.screen_height, rgb(10, 14, 24), rgb(18, 28, 42));
    drawGlassPanel(rect(84, 90, 552, 330), rgb(78, 210, 230), 222);
    rl.DrawRectangleRounded(rect(128, 128, 462, 250), 0.04, 8, rgb(8, 12, 24));
    var i: i32 = 0;
    while (i < 6) : (i += 1) {
        const x = 152 + i * 70;
        const h = 40 + @as(i32, @intFromFloat(62.0 * (0.5 + 0.5 * @sin(@as(f32, @floatFromInt(i)) + t * 8.0))));
        rl.DrawRectangle(x, 330 - h, 36, h, rgb(80, 220, 230));
        rl.DrawRectangleLines(x, 330 - h, 36, h, rgba(226, 244, 252, 120));
    }
    drawTextShadow("MISSION CONTROL", 196, 50, 32, rgb(255, 236, 39));
    const ready_count = @min(@as(i32, 5), @as(i32, @intFromFloat(t * 7.0)));
    drawSystemLine(0, ready_count, "GUIDANCE");
    drawSystemLine(1, ready_count, "FUEL PRESSURE");
    drawSystemLine(2, ready_count, "COMMS");
    drawSystemLine(3, ready_count, "CREW SEAL");
    drawSystemLine(4, ready_count, "FLIGHT DATA");
    const pulse = 0.5 + 0.5 * @sin(t * 36.0);
    rl.DrawCircleLines(422, 314, 70.0 + 16.0 * pulse, rgb(80, 220, 230));
    rl.DrawCircle(422, 314, 8.0, rgb(255, 236, 80));
}

fn drawCutsceneIgnition(game: *GameState, t: f32) void {
    drawCutsceneSpaceport(game, 1.0);
    const pad_x: i32 = 760;
    const shake = @as(i32, @intFromFloat(@sin(game.cutscene.beat_time_s * 42.0) * @min(9.0, t * 14.0)));
    drawServiceTower(pad_x + shake, 430);
    if (!drawRocketGif(game, @as(f32, @floatFromInt(pad_x + 40 + shake)), 380.0, 226.0, 0.0, rgb(255, 255, 255))) {
        drawCutsceneRocket(pad_x + 40 + shake, 380, 1.22, true, game.cutscene.beat_time_s);
    }
    drawCircleGradient(pad_x + 40 + shake, 534, 80.0 + 110.0 * t, rgba(255, 148, 54, @as(u8, @intFromFloat(95.0 + 80.0 * t))), rgba(255, 148, 54, 0));
    const countdown = @max(0, 3 - @as(i32, @intFromFloat(t * 4.0)));
    if (countdown <= 0) {
        drawCenteredText("IGNITION", @divTrunc(config.screen_width, 2), 112, 44, rgb(255, 236, 80));
    } else {
        drawFormat("T-{d}", .{countdown}, @divTrunc(config.screen_width, 2) - 32, 90, 44, rgb(255, 236, 80));
    }
}

fn drawCutsceneBlackout(_: *GameState, t: f32) void {
    rl.ClearBackground(rgb(0, 0, 0));
    const alpha = @as(u8, @intFromFloat(std.math.clamp(t * 1.6, 0.0, 1.0) * 255.0));
    drawCenteredText("MISSION CONTROL ONLINE", @divTrunc(config.screen_width, 2), @divTrunc(config.screen_height, 2), 31, rgba(255, 236, 80, alpha));
}

fn drawCutsceneSpaceport(game: *GameState, t: f32) void {
    drawCinematicSpace(game.ui_time_s * 0.5, rgb(9, 14, 30), rgb(31, 46, 72), rgb(255, 212, 120));
    rl.DrawTriangle(.{ .x = 0, .y = 420 }, .{ .x = 240, .y = 242 }, .{ .x = 510, .y = 420 }, rgba(38, 56, 62, 190));
    rl.DrawTriangle(.{ .x = 390, .y = 420 }, .{ .x = 780, .y = 220 }, .{ .x = 1120, .y = 420 }, rgba(42, 62, 66, 188));
    rl.DrawRectangle(0, 430, config.screen_width, 290, rgb(44, 74, 58));
    rl.DrawRectangle(0, 520, config.screen_width, 100, rgb(56, 60, 70));
    var x: i32 = 0;
    while (x < config.screen_width) : (x += 72) {
        rl.DrawLine(x, 520, x - 45, config.screen_height, rgba(82, 86, 96, 116));
    }
    drawCircleGradient(1030, 132, 58.0 + 8.0 * @sin(t * std.math.pi), rgba(255, 230, 132, 150), rgba(255, 230, 132, 0));
    rl.DrawCircle(1030, 132, 30.0, rgb(255, 230, 132));
}

fn drawSystemLine(index: i32, ready_count: i32, label: [*:0]const u8) void {
    const y = 214 + index * 48;
    const active = index < ready_count;
    const color = if (active) rgb(104, 230, 150) else rgb(92, 102, 126);
    drawGlassPanel(rect(720, @as(f32, @floatFromInt(y)), 300, 34), color, 205);
    drawText(if (active) "ONLINE" else "WAITING", 738, y + 9, 15, color);
    drawText(label, 820, y + 9, 15, color);
}

fn drawServiceTower(x: i32, y: i32) void {
    rl.DrawRectangle(x - 72, y - 220, 34, 230, rgb(74, 80, 92));
    var row = y - 204;
    while (row < y - 20) : (row += 34) {
        rl.DrawLine(x - 72, row, x - 38, row + 22, rgb(124, 132, 150));
        rl.DrawLine(x - 38, row, x - 72, row + 22, rgb(124, 132, 150));
    }
    rl.DrawRectangle(x - 116, y - 126, 106, 20, rgb(90, 96, 110));
    rl.DrawRectangle(x - 116, y - 126, 106, 4, rgb(255, 202, 72));
}

fn drawTransport(x: i32, y: i32) void {
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y - 44)), 160, 44), 0.18, 8, rgb(92, 100, 114));
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x + 18)), @as(f32, @floatFromInt(y - 64)), 98, 28), 0.14, 8, rgb(42, 48, 60));
    rl.DrawCircle(x + 32, y, 18.0, rgb(24, 26, 30));
    rl.DrawCircle(x + 128, y, 18.0, rgb(24, 26, 30));
    rl.DrawCircle(x + 32, y, 8.0, rgb(130, 138, 152));
    rl.DrawCircle(x + 128, y, 8.0, rgb(130, 138, 152));
}

fn drawIntroBus(x: i32, y: i32) void {
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y - 72)), 230, 72), 0.11, 8, rgb(238, 190, 72));
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x + 24)), @as(f32, @floatFromInt(y - 60)), 48, 26), 0.08, 8, rgb(55, 80, 105));
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x + 88)), @as(f32, @floatFromInt(y - 60)), 48, 26), 0.08, 8, rgb(55, 80, 105));
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x + 152)), @as(f32, @floatFromInt(y - 60)), 48, 26), 0.08, 8, rgb(55, 80, 105));
    rl.DrawCircle(x + 52, y, 18.0, rgb(28, 28, 32));
    rl.DrawCircle(x + 178, y, 18.0, rgb(28, 28, 32));
    rl.DrawCircle(x + 52, y, 8.0, rgb(120, 124, 132));
    rl.DrawCircle(x + 178, y, 8.0, rgb(120, 124, 132));
}

fn drawIntroTree(x: i32, y: i32) void {
    rl.DrawRectangle(x - 5, y - 44, 10, 44, rgb(90, 58, 34));
    rl.DrawCircle(x, y - 62, 28.0, rgb(54, 112, 60));
    rl.DrawCircle(x - 18, y - 52, 18.0, rgb(62, 130, 68));
    rl.DrawCircle(x + 18, y - 52, 18.0, rgb(48, 104, 56));
}

fn drawCutscenePerson(x: i32, y: i32, color: rl.Color, scale: f32) void {
    const head = 18.0 * scale;
    const body_w = 34.0 * scale;
    const body_h = 62.0 * scale;
    const fx = @as(f32, @floatFromInt(x));
    const fy = @as(f32, @floatFromInt(y));
    rl.DrawCircle(x, toI32(fy - body_h - head), head, color);
    rl.DrawRectangleRounded(rect(fx - body_w * 0.5, fy - body_h, body_w, body_h), 0.18, 8, color);
    rl.DrawTriangle(.{ .x = fx - body_w * 0.5, .y = fy - 6.0 }, .{ .x = fx - body_w, .y = fy + 34.0 }, .{ .x = fx - 4.0, .y = fy + 34.0 }, color);
    rl.DrawTriangle(.{ .x = fx + body_w * 0.5, .y = fy - 6.0 }, .{ .x = fx + body_w, .y = fy + 34.0 }, .{ .x = fx + 4.0, .y = fy + 34.0 }, color);
}

fn drawIntroRocket(x: i32, y: i32, angle: f32, flame: bool) void {
    const fx = @as(f32, @floatFromInt(x));
    const fy = @as(f32, @floatFromInt(y));
    rl.DrawRectanglePro(rect(fx - 11.0, fy - 36.0, 22, 70), .{ .x = 11.0, .y = 35.0 }, angle, rgb(218, 222, 230));
    rl.DrawTriangle(.{ .x = fx, .y = fy - 92.0 }, .{ .x = fx - 22.0, .y = fy - 36.0 }, .{ .x = fx + 22.0, .y = fy - 36.0 }, rgb(220, 70, 70));
    rl.DrawRectanglePro(rect(fx - 17.0, fy + 32.0, 34, 14), .{ .x = 17.0, .y = 7.0 }, angle, rgb(150, 154, 164));
    if (flame) {
        const flame_h: f32 = 38.0;
        drawCircleGradient(x, y + 76, 42.0, rgba(255, 136, 35, 170), rgba(255, 136, 35, 0));
        rl.DrawTriangle(.{ .x = fx - 18.0, .y = fy + 46.0 }, .{ .x = fx + 18.0, .y = fy + 46.0 }, .{ .x = fx, .y = fy + 46.0 + flame_h }, rgb(255, 136, 35));
    }
}

fn drawAnimatedGif(animation: *const AnimatedGif, center_x: f32, center_y: f32, size: f32, rotation: f32, tint: rl.Color) bool {
    if (!animation.ready) return false;
    if (animation.texture.width <= 0 or animation.texture.height <= 0) return false;

    rl.DrawTexturePro(
        animation.texture,
        rect(
            0.0,
            0.0,
            @as(f32, @floatFromInt(animation.texture.width)),
            @as(f32, @floatFromInt(animation.texture.height)),
        ),
        rect(center_x, center_y, size, size),
        .{ .x = size * 0.5, .y = size * 0.5 },
        rotation,
        tint,
    );
    return true;
}

fn drawRocketGif(game: *GameState, center_x: f32, center_y: f32, size: f32, rotation: f32, tint: rl.Color) bool {
    return drawAnimatedGif(&game.rocket_gif, center_x, center_y, size, rotation, tint);
}

fn drawCutsceneRocket(x: i32, y: i32, scale: f32, flame: bool, time: f32) void {
    const body_w = 52.0 * scale;
    const body_h = 112.0 * scale;
    const fx = @as(f32, @floatFromInt(x));
    const fy = @as(f32, @floatFromInt(y));
    drawCircleGradient(x, y, 78.0 * scale, rgba(226, 234, 244, 42), rgba(226, 234, 244, 0));
    rl.DrawTriangle(.{ .x = fx, .y = fy - 126.0 * scale }, .{ .x = fx - 26.0 * scale, .y = fy - 76.0 * scale }, .{ .x = fx + 26.0 * scale, .y = fy - 76.0 * scale }, rgb(228, 236, 246));
    rl.DrawRectangleRounded(rect(fx - body_w * 0.5, fy - 76.0 * scale, body_w, body_h), 0.12, 8, rgb(218, 226, 238));
    rl.DrawRectangleRounded(rect(fx - 22.0 * scale, fy - 44.0 * scale, 44.0 * scale, 42.0 * scale), 0.08, 8, rgb(78, 126, 192));
    rl.DrawRectangleRounded(rect(fx - 36.0 * scale, fy + 58.0 * scale, 72.0 * scale, 24.0 * scale), 0.10, 8, rgb(180, 70, 70));
    rl.DrawTriangle(.{ .x = fx - 26.0 * scale, .y = fy + 60.0 * scale }, .{ .x = fx - 56.0 * scale, .y = fy + 98.0 * scale }, .{ .x = fx - 22.0 * scale, .y = fy + 82.0 * scale }, rgb(80, 86, 96));
    rl.DrawTriangle(.{ .x = fx + 26.0 * scale, .y = fy + 60.0 * scale }, .{ .x = fx + 56.0 * scale, .y = fy + 98.0 * scale }, .{ .x = fx + 22.0 * scale, .y = fy + 82.0 * scale }, rgb(80, 86, 96));
    if (flame) {
        const length = (46.0 + 20.0 * @sin(time * 20.0)) * scale;
        drawCircleGradient(x, toI32(fy + 92.0 * scale), length * 1.2, rgba(255, 148, 54, 140), rgba(255, 148, 54, 0));
        rl.DrawTriangle(.{ .x = fx - 22.0 * scale, .y = fy + 82.0 * scale }, .{ .x = fx + 22.0 * scale, .y = fy + 82.0 * scale }, .{ .x = fx, .y = fy + 82.0 * scale + length }, rgb(255, 138, 42));
        rl.DrawTriangle(.{ .x = fx - 12.0 * scale, .y = fy + 82.0 * scale }, .{ .x = fx + 12.0 * scale, .y = fy + 82.0 * scale }, .{ .x = fx, .y = fy + 72.0 * scale + length }, rgb(255, 236, 92));
    }
}

fn drawCutsceneCaption(text: [*:0]const u8, t: f32) void {
    const panel = rect(220, @as(f32, @floatFromInt(config.screen_height - 118)), 840, 70);
    drawGlassPanel(panel, rgb(255, 212, 80), 225);
    drawCenteredText(text, @divTrunc(config.screen_width, 2), config.screen_height - 84, 21, rgb(238, 244, 252));
    drawProgressBar(rect(254, @as(f32, @floatFromInt(config.screen_height - 54)), 772, 6), t, rgb(255, 212, 80));
}

fn drawCenteredText(text: [*:0]const u8, x: i32, y: i32, size: i32, col: rl.Color) void {
    const tw = rl.MeasureText(text, size);
    drawTextShadow(text, x - @divTrunc(tw, 2), y - @divTrunc(size, 2), size, col);
}

fn drawLaunch(game: *GameState) void {
    const alt = @max(0.0, game.rocket.altitude(physics.earth.radius_m));
    const zoom = launchZoom(alt);
    const rocket_screen = worldToLaunchScreen(game.rocket.x, game.rocket.y, game, zoom);
    drawCinematicSpace(game.ui_time_s * 0.35, rgb(4, 8, 18), rgb(10, 18, 34), rgb(78, 210, 230));

    if (game.orbit_count > 2) {
        var previous = worldToLaunchScreen(game.orbit_points[0].x, game.orbit_points[0].y, game, zoom);
        for (1..game.orbit_count) |i| {
            const current = worldToLaunchScreen(game.orbit_points[i].x, game.orbit_points[i].y, game, zoom);
            rl.DrawLineV(previous, current, rgba(78, 210, 230, 170));
            previous = current;
        }
    }

    const surface = worldToLaunchScreen(physics.earth.radius_m, game.rocket.y, game, zoom);
    drawCircleGradient(720, toI32(surface.y + 620.0), 760.0, rgba(70, 132, 90, 232), rgba(70, 132, 90, 0));
    rl.DrawRectangleGradientV(0, toI32(surface.y), config.screen_width, config.screen_height - toI32(surface.y), rgb(44, 76, 56), rgb(28, 42, 38));
    rl.DrawLine(0, toI32(surface.y), config.screen_width, toI32(surface.y), rgb(150, 210, 150));
    rl.DrawRectangleGradientV(0, toI32(surface.y - 42.0), config.screen_width, 42, rgba(78, 210, 230, 0), rgba(78, 210, 230, 45));

    if (game.rocket.throttle > 0.05 and game.rocket.fuel_kg > 0.0) {
        const flame = @as(f32, @floatCast(24.0 + game.rocket.throttle * 34.0));
        drawCircleGradient(toI32(rocket_screen.x), toI32(rocket_screen.y + 54.0), flame * 1.45, rgba(255, 156, 64, 160), rgba(255, 156, 64, 0));
        rl.DrawTriangle(
            .{ .x = rocket_screen.x - 10.0, .y = rocket_screen.y + 28.0 },
            .{ .x = rocket_screen.x + 10.0, .y = rocket_screen.y + 28.0 },
            .{ .x = rocket_screen.x, .y = rocket_screen.y + 28.0 + flame },
            rgb(255, 132, 42),
        );
    }

    drawCircleGradient(toI32(rocket_screen.x), toI32(rocket_screen.y), 52.0, rgba(226, 234, 244, 54), rgba(226, 234, 244, 0));
    if (!drawRocketGif(game, rocket_screen.x + 11.0, rocket_screen.y + 28.0, 92.0, @as(f32, @floatCast(-game.rocket.angle_deg)), rgb(255, 255, 255))) {
        rl.DrawRectanglePro(
            .{ .x = rocket_screen.x, .y = rocket_screen.y, .width = 22.0, .height = 56.0 },
            .{ .x = 11.0, .y = 28.0 },
            @as(f32, @floatCast(-game.rocket.angle_deg)),
            rgb(214, 224, 238),
        );
        rl.DrawRectanglePro(
            .{ .x = rocket_screen.x, .y = rocket_screen.y + 26.0, .width = 28.0, .height = 14.0 },
            .{ .x = 14.0, .y = 7.0 },
            @as(f32, @floatCast(-game.rocket.angle_deg)),
            rgb(230, 82, 82),
        );
    }

    drawHeader(game, "Launch");
    drawGlassPanel(rect(38, 112, 338, 226), rgb(78, 210, 230), 214);
    drawFormat("Altitude: {d} m", .{@as(i32, @intFromFloat(alt))}, 60, 138, 20, rgb(226, 234, 244));
    drawFormat("Speed: {d} m/s", .{@as(i32, @intFromFloat(game.rocket.speed()))}, 60, 168, 20, rgb(226, 234, 244));
    drawFormat("Fuel: {d}%", .{@as(i32, @intFromFloat(game.rocket.fuelPercent()))}, 60, 198, 20, rgb(226, 234, 244));
    drawProgressBar(rect(178, 204, 168, 10), @as(f32, @floatCast(game.rocket.fuelPercent() / 100.0)), rgb(120, 230, 150));
    drawFormat("Throttle: {d}%", .{@as(i32, @intFromFloat(game.rocket.throttle * 100.0))}, 60, 228, 20, rgb(226, 234, 244));
    drawProgressBar(rect(178, 234, 168, 10), @as(f32, @floatCast(game.rocket.throttle)), rgb(255, 156, 84));
    drawFormat("Angle: {d} deg", .{@as(i32, @intFromFloat(game.rocket.angle_deg))}, 60, 258, 20, rgb(226, 234, 244));
    drawText(if ((game.rocket.flags & rocket_mod.VesselFlags.orbit) != 0) "ORBIT ACHIEVED" else "ASCENT ACTIVE", 60, 292, 20, rgb(255, 212, 120));
    drawMissionPanel(game, 38, 344);

    drawText("W/S throttle | A/D rotate | Space ignition | R reset | Esc menu", 38, 690, 18, rgb(150, 160, 180));
}

fn drawHeader(game: *GameState, title: [*:0]const u8) void {
    drawGlassPanel(rect(26, 18, 470, 72), rgb(255, 212, 120), 186);
    drawTextShadow(title, 38, 28, 31, rgb(255, 236, 39));
    drawFormat("Funds: ${d}", .{game.money}, 38, 66, 20, rgb(255, 236, 39));
    drawFormat("Day {d}  {d}:{d:0>2}", .{ game.time.day, game.time.hour, @as(i32, @intFromFloat(game.time.minute)) }, 214, 76, 18, rgb(176, 190, 214));
}

fn drawRocketSummary(game: *GameState, x: i32, y: i32) void {
    drawGlassPanel(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)), 434, 410), rgb(78, 210, 230), 214);
    drawSectionTitle("Current Build", x + 24, y + 28, rgb(78, 210, 230));
    drawFormat("Parts: {d}", .{game.stack.count}, x + 24, y + 76, 20, rgb(176, 190, 214));
    drawFormat("Mass: {d} kg", .{@as(i32, @intFromFloat(parts.totalMass(&game.stack)))}, x + 24, y + 106, 20, rgb(176, 190, 214));
    drawFormat("Cost: ${d}", .{parts.totalCost(&game.stack)}, x + 24, y + 136, 20, rgb(176, 190, 214));
    drawFormat("Research: {d}", .{game.story.research_points}, x + 24, y + 166, 20, rgb(176, 190, 214));
    drawFormat("Achievements: {d}", .{@popCount(game.achievements.unlocked)}, x + 24, y + 196, 20, rgb(176, 190, 214));
    drawText(if (parts.isLaunchable(&game.stack)) "Ready to launch" else "Needs pod, tank, engine", x + 24, y + 236, 22, if (parts.isLaunchable(&game.stack)) rgb(120, 230, 150) else rgb(255, 150, 110));

    const bay = rect(@as(f32, @floatFromInt(x + 258)), @as(f32, @floatFromInt(y + 70)), 116, 252);
    rl.DrawRectangleRounded(bay, 0.08, 8, rgba(255, 255, 255, 18));
    rl.DrawRectangleRoundedLinesEx(bay, 0.08, 8, 1.0, rgba(226, 234, 244, 72));
    if (game.stack.count == 0) {
        drawText("(empty)", x + 282, y + 188, 16, rgb(140, 154, 184));
    } else {
        var draw_y = y + 282;
        for (0..game.stack.count) |offset| {
            const index = game.stack.count - 1 - offset;
            const kind = game.stack.items[index];
            const w = @max(24, @divTrunc(partWidth(kind), 2));
            const px = x + 316 - @divTrunc(w, 2);
            rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(px)), @as(f32, @floatFromInt(draw_y)), @as(f32, @floatFromInt(w)), 18), 0.12, 8, partColor(kind));
            rl.DrawRectangleRoundedLinesEx(rect(@as(f32, @floatFromInt(px)), @as(f32, @floatFromInt(draw_y)), @as(f32, @floatFromInt(w)), 18), 0.12, 8, 1.0, rgb(24, 28, 36));
            draw_y -= 22;
            if (draw_y < y + 88) break;
        }
    }
}

fn drawStackPanel(game: *GameState, x: i32, y: i32) void {
    drawGlassPanel(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)), 320, 492), rgb(78, 210, 230), 218);
    drawSectionTitle("Stack", x + 22, y + 26, rgb(78, 210, 230));

    if (game.stack.count == 0) {
        drawText("(No parts yet)", x + 88, y + 236, 20, rgb(140, 154, 184));
        return;
    }

    var draw_y = y + 430;
    for (0..game.stack.count) |offset| {
        const index = game.stack.count - 1 - offset;
        const kind = game.stack.items[index];
        const w = partWidth(kind);
        const part_x = x + 160 - @divTrunc(w, 2);
        rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(part_x - 8)), @as(f32, @floatFromInt(draw_y - 5)), @as(f32, @floatFromInt(w + 16)), 38), 0.12, 8, rgba(255, 255, 255, 24));
        rl.DrawRectangle(part_x, draw_y, w, 28, partColor(kind));
        rl.DrawRectangleLines(part_x, draw_y, w, 28, rgb(30, 34, 44));
        drawText(parts.spec(kind).short_name, x + 134, draw_y + 6, 14, rgb(12, 18, 24));
        draw_y -= 34;
    }
}

fn drawValidationPanel(game: *GameState, x: i32, y: i32) void {
    drawGlassPanel(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)), 348, 492), rgb(120, 230, 150), 218);
    drawSectionTitle("Mission Readiness", x + 22, y + 26, rgb(120, 230, 150));
    const mask = parts.requiredMask(&game.stack);
    drawReadyLine(mask, parts.Required.command, "Command module", x + 28, y + 86);
    drawReadyLine(mask, parts.Required.service, "Service module", x + 28, y + 124);
    drawReadyLine(mask, parts.Required.propulsion, "Propulsion", x + 28, y + 162);
    drawReadyLine(mask, parts.Required.fuel, "Fuel tank", x + 28, y + 200);
    drawReadyLine(mask, parts.Required.lander, "Lander/legs", x + 28, y + 238);
    drawReadyLine(mask, parts.Required.heat, "Heat shield", x + 28, y + 276);
    drawReadyLine(mask, parts.Required.life, "Life support", x + 28, y + 314);
    drawReadyLine(mask, parts.Required.nav, "Navigation", x + 28, y + 352);
    drawText(if (parts.isLaunchable(&game.stack)) "Layout OK" else "Bottom snap must be an engine", x + 28, y + 420, 20, if (parts.isLaunchable(&game.stack)) rgb(120, 230, 150) else rgb(255, 150, 110));
}

fn drawMissionPanel(game: *GameState, x: i32, y: i32) void {
    drawGlassPanel(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y)), 338, 158), rgb(78, 210, 230), 214);
    drawTextShadow("Flight Missions", x + 22, y + 18, 22, rgb(232, 238, 248));
    drawMissionLine(game.missions.completed, systems.MissionFlags.liftoff, "Liftoff", x + 24, y + 54);
    drawMissionLine(game.missions.completed, systems.MissionFlags.tower_clear, "Tower Clear", x + 174, y + 54);
    drawMissionLine(game.missions.completed, systems.MissionFlags.mach_one, "Mach 1", x + 24, y + 84);
    drawMissionLine(game.missions.completed, systems.MissionFlags.thin_air, "Thin Air", x + 174, y + 84);
    drawMissionLine(game.missions.completed, systems.MissionFlags.space, "Space", x + 24, y + 114);
    drawMissionLine(game.missions.completed, systems.MissionFlags.orbit, "Orbit", x + 174, y + 114);
}

fn drawMissionLine(done_mask: u32, flag: u32, text: [*:0]const u8, x: i32, y: i32) void {
    const done = (done_mask & flag) != 0;
    const pill_col = if (done) rgb(74, 138, 92) else rgb(58, 66, 84);
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y + 2)), 30, 18), 0.35, 8, pill_col);
    drawText(if (done) "OK" else "--", x + 4, y + 3, 14, if (done) rgb(220, 255, 225) else rgb(150, 160, 180));
    drawText(text, x + 34, y, 18, if (done) rgb(180, 220, 190) else rgb(160, 174, 198));
}

fn drawReadyLine(mask: u32, bit: u32, text: [*:0]const u8, x: i32, y: i32) void {
    const ok = (mask & bit) != 0;
    rl.DrawRectangleRounded(rect(@as(f32, @floatFromInt(x)), @as(f32, @floatFromInt(y + 2)), 38, 22), 0.32, 8, if (ok) rgb(74, 138, 92) else rgb(92, 66, 72));
    drawText(if (ok) "OK" else "--", x + 7, y + 4, 15, if (ok) rgb(220, 255, 225) else rgb(255, 180, 160));
    drawText(text, x + 48, y, 20, if (ok) rgb(180, 220, 190) else rgb(180, 150, 150));
}

fn buyPart(game: *GameState, kind: parts.PartKind) void {
    const part = parts.spec(kind);
    if (game.stack.count >= parts.max_parts) {
        game.audio.errorTone();
        setNotice(game, "Stack is full.");
        return;
    }
    if (game.money < part.cost) {
        game.audio.errorTone();
        setNotice(game, "Not enough funds.");
        return;
    }
    game.money -= part.cost;
    _ = game.stack.add(kind);
    game.audio.confirm();
    setNotice(game, "Part added.");
}

fn removeLastPart(game: *GameState) void {
    if (game.stack.removeLast()) |kind| {
        game.money += parts.spec(kind).cost;
        game.audio.click();
        setNotice(game, "Part removed and refunded.");
    }
}

fn addMissingSystems(game: *GameState) void {
    var fixed = game.stack;
    parts.addMissing(&fixed);
    const current_cost = parts.totalCost(&game.stack);
    const target_cost = parts.totalCost(&fixed);
    const delta = target_cost - current_cost;
    if (delta > game.money) {
        game.audio.errorTone();
        setNotice(game, "Not enough funds for missing systems.");
        return;
    }
    game.money -= delta;
    game.stack = fixed;
    game.audio.confirm();
    setNotice(game, "Missing mission systems added.");
}

fn loadPreset(game: *GameState) void {
    var preset = parts.Stack.init();
    parts.loadStarterPreset(&preset);
    const refund = parts.totalCost(&game.stack);
    const cost = parts.totalCost(&preset);
    const available = game.money + refund;
    if (available < cost) {
        game.audio.errorTone();
        setNotice(game, "Need more funds for preset.");
        return;
    }
    game.money = available - cost;
    game.stack = preset;
    game.audio.confirm();
    setNotice(game, "Starter lunar preset loaded.");
}

fn clearBuild(game: *GameState) void {
    game.money += parts.totalCost(&game.stack);
    game.stack.clear();
    game.audio.click();
    setNotice(game, "Build cleared.");
}

fn syncAudioSettings(game: *GameState) void {
    if (game.audio.track_count > 0 and game.settings.music_index >= game.audio.track_count) {
        game.settings.music_index = 0;
    }
    game.audio.sfx_volume = game.settings.sfx_volume;
    game.audio.applyMusicSettings(game.settings.music_enabled, game.settings.music_index, game.settings.music_volume);
    game.settings.music_index = game.audio.selected_music;
}

fn toggleMusicEnabled(game: *GameState) void {
    game.settings.music_enabled = !game.settings.music_enabled;
    game.audio.setMusicEnabled(game.settings.music_enabled);
    game.audio.click();
    saveSettingsFile(game);
}

fn cycleMusicTrack(game: *GameState) void {
    if (game.audio.track_count == 0) {
        game.audio.errorTone();
        setNotice(game, "No .ogg music tracks found.");
        return;
    }
    game.settings.music_index = (game.settings.music_index + 1) % game.audio.track_count;
    game.audio.applyMusicSettings(game.settings.music_enabled, game.settings.music_index, game.settings.music_volume);
    game.settings.music_index = game.audio.selected_music;
    game.audio.confirm();
    saveSettingsFile(game);
}

fn fundResearch(game: *GameState) void {
    const cost = 12_000;
    if (game.money < cost) {
        game.audio.errorTone();
        setNotice(game, "Need $12,000 to fund research.");
        return;
    }
    game.money -= cost;
    game.story.research_points += 1;
    game.audio.confirm();
    setNotice(game, "Research funded. +1 RP");
}

fn unlockResearch(game: *GameState, index: usize) void {
    if (index >= research_catalog.len) return;
    const tech = research_catalog[index];
    if ((game.tech_flags & tech.flag) != 0) {
        game.audio.errorTone();
        setNotice(game, "Technology already unlocked.");
        return;
    }
    if (game.story.research_points < tech.cost) {
        game.audio.errorTone();
        setNotice(game, "Not enough research points.");
        return;
    }
    game.story.research_points -= tech.cost;
    game.tech_flags |= tech.flag;
    if (tech.flag == TechFlags.crew_systems) {
        var i: usize = 0;
        while (i < game.story.npc_morale.len) : (i += 1) {
            game.story.npc_morale[i] = std.math.clamp(game.story.npc_morale[i] + 1, 0, 10);
        }
    }
    game.audio.confirm();
    setNoticeFmt(game, "Unlocked: {s}", .{tech.title});
}

fn openLoadGame(game: *GameState) void {
    game.audio.click();
    game.load_screen_time_s = 0.0;
    refreshSaveSlots(game);
    game.loader_gif.initFromPaths(loader_animation_paths[0..], 0.10);
    game.screen = .load_game;
    if (!game.loader_gif.ready) {
        setNotice(game, "SceenLoader.gif was not loaded.");
    }
}

fn closeLoadGame(game: *GameState) void {
    game.audio.click();
    game.loader_gif.deinit();
    game.load_screen_time_s = 0.0;
    game.screen = .title;
}

fn loadTownMapFromLdtk(game: *GameState) void {
    for (town_ldtk_paths) |path| {
        if (!rl.FileExists(path)) continue;

        var data_size: c_int = 0;
        const data = rl.LoadFileData(path, &data_size);
        if (data == null) continue;
        defer rl.UnloadFileData(data);
        if (data_size <= 0) continue;

        const bytes: [*]const u8 = @ptrCast(data);
        if (game.town_map.loadLdtkFromSlice(bytes[0..@as(usize, @intCast(data_size))])) {
            return;
        }
    }
}

fn saveSettingsFile(game: *const GameState) void {
    if (!rl.DirectoryExists(save_dir) and rl.MakeDirectory(save_dir) != 0) return;
    var blob = makeSettingsBlob(game);
    blob.checksum = settingsBlobChecksum(&blob);
    _ = rl.SaveFileData(settings_path, @ptrCast(&blob), @as(c_int, @intCast(@sizeOf(SettingsBlob))));
}

fn loadSettingsFile(game: *GameState) void {
    var data_size: c_int = 0;
    const data = rl.LoadFileData(settings_path, &data_size);
    if (data == null) return;
    defer rl.UnloadFileData(data);

    if (data_size != @as(c_int, @intCast(@sizeOf(SettingsBlob)))) return;
    var blob: SettingsBlob = undefined;
    const source: [*]const u8 = @ptrCast(data);
    @memcpy(std.mem.asBytes(&blob), source[0..@sizeOf(SettingsBlob)]);
    if (!validateSettingsBlob(&blob)) return;

    game.settings.music_enabled = blob.music_enabled != 0;
    game.settings.music_index = blob.music_index;
    game.settings.music_volume = std.math.clamp(blob.music_volume, 0.0, 1.0);
    game.settings.sfx_volume = std.math.clamp(blob.sfx_volume, 0.0, 1.0);
    game.settings.fullscreen = blob.fullscreen != 0;
    game.settings.resolution_index = if (blob.resolution_index < resolution_options.len) blob.resolution_index else 0;
}

fn makeSettingsBlob(game: *const GameState) SettingsBlob {
    var blob = std.mem.zeroes(SettingsBlob);
    blob.magic = settings_magic;
    blob.version = settings_version;
    blob.music_enabled = if (game.settings.music_enabled) 1 else 0;
    blob.music_index = @as(u8, @intCast(@min(game.settings.music_index, 255)));
    blob.fullscreen = if (game.settings.fullscreen) 1 else 0;
    blob.resolution_index = @as(u8, @intCast(@min(game.settings.resolution_index, 255)));
    blob.music_volume = game.settings.music_volume;
    blob.sfx_volume = game.settings.sfx_volume;
    return blob;
}

fn validateSettingsBlob(blob: *const SettingsBlob) bool {
    if (blob.magic != settings_magic or blob.version != settings_version) return false;
    return blob.checksum == settingsBlobChecksum(blob);
}

fn settingsBlobChecksum(blob: *const SettingsBlob) u32 {
    const bytes = std.mem.asBytes(blob);
    return checksumBytes(bytes[0 .. bytes.len - @sizeOf(u32)]);
}

fn saveGameSlot(game: *GameState, slot: usize) void {
    if (slot >= save_slot_count) {
        game.audio.errorTone();
        setNotice(game, "Invalid save slot.");
        return;
    }
    if (!rl.DirectoryExists(save_dir) and rl.MakeDirectory(save_dir) != 0) {
        game.audio.errorTone();
        setNotice(game, "Could not create saves directory.");
        return;
    }

    var path_buf: [64]u8 = undefined;
    const path = saveSlotPath(slot, &path_buf) orelse {
        game.audio.errorTone();
        setNotice(game, "Save path formatting failed.");
        return;
    };

    var blob = makeSaveBlob(game);
    blob.checksum = saveBlobChecksum(&blob);
    if (!rl.SaveFileData(path.ptr, @ptrCast(&blob), @as(c_int, @intCast(@sizeOf(SaveBlob))))) {
        game.audio.errorTone();
        setNotice(game, "Save write failed.");
        return;
    }
    refreshSaveSlots(game);
    game.audio.confirm();
    setNoticeFmt(game, "Saved slot {d}.", .{@as(i32, @intCast(slot + 1))});
}

fn loadGameSlot(game: *GameState, slot: usize) void {
    if (slot >= save_slot_count) {
        game.audio.errorTone();
        setNotice(game, "Invalid load slot.");
        return;
    }
    var blob: SaveBlob = undefined;
    if (!readSaveBlob(slot, &blob)) {
        refreshSaveSlots(game);
        game.audio.errorTone();
        setNotice(game, "No valid save data in that slot.");
        return;
    }
    if (!applySaveBlob(game, &blob)) {
        game.audio.errorTone();
        setNotice(game, "Save data could not be applied.");
        return;
    }
    game.loader_gif.deinit();
    game.load_screen_time_s = 0.0;
    game.screen = .town;
    game.audio.confirm();
    setNoticeFmt(game, "Loaded slot {d}.", .{@as(i32, @intCast(slot + 1))});
}

fn refreshSaveSlots(game: *GameState) void {
    var i: usize = 0;
    while (i < save_slot_count) : (i += 1) {
        game.save_slots[i] = readSaveSlotInfo(i);
    }
    if (game.selected_save_slot >= save_slot_count) game.selected_save_slot = 0;
}

fn readSaveSlotInfo(slot: usize) SaveSlotInfo {
    var blob: SaveBlob = undefined;
    if (!readSaveBlob(slot, &blob)) return SaveSlotInfo.empty();
    return .{
        .present = true,
        .money = blob.money,
        .day = blob.day,
        .hour = blob.hour,
        .minute = @as(i32, @intFromFloat(blob.minute)),
        .part_count = blob.stack_count,
        .research_points = blob.research_points,
        .tech_flags = blob.tech_flags,
    };
}

fn readSaveBlob(slot: usize, out: *SaveBlob) bool {
    var path_buf: [64]u8 = undefined;
    const path = saveSlotPath(slot, &path_buf) orelse return false;
    var data_size: c_int = 0;
    const data = rl.LoadFileData(path.ptr, &data_size);
    if (data == null) return false;
    defer rl.UnloadFileData(data);

    const bytes = std.mem.asBytes(out);
    if (data_size != @as(c_int, @intCast(bytes.len))) return false;
    const source: [*]const u8 = @ptrCast(data);
    @memcpy(bytes, source[0..bytes.len]);
    return validateSaveBlob(out);
}

fn saveSlotPath(slot: usize, buffer: *[64]u8) ?[:0]u8 {
    if (slot >= save_slot_count) return null;
    return std.fmt.bufPrintZ(buffer, "{s}/slot{d}.rcsave", .{ save_dir, slot + 1 }) catch null;
}

fn makeSaveBlob(game: *const GameState) SaveBlob {
    var blob = std.mem.zeroes(SaveBlob);
    blob.magic = save_magic;
    blob.version = save_version;
    blob.money = game.money;
    blob.day = game.time.day;
    blob.hour = game.time.hour;
    blob.minute = game.time.minute;
    blob.story_flags = game.story.flags;
    blob.reputation = game.story.reputation;
    blob.research_points = game.story.research_points;
    blob.npc_morale = game.story.npc_morale;
    blob.achievements_unlocked = game.achievements.unlocked;
    blob.launch_count = game.achievements.launch_count;
    blob.orbit_count = game.achievements.orbit_count;
    blob.missions_completed = game.missions.completed;
    blob.missions_funds = game.missions.funds;
    blob.tech_flags = game.tech_flags;
    blob.stack_count = @as(u8, @intCast(game.stack.count));
    var i: usize = 0;
    while (i < game.stack.count and i < parts.max_parts) : (i += 1) {
        blob.stack_items[i] = @intFromEnum(game.stack.items[i]);
    }
    blob.player_x = game.people.player.x;
    blob.player_y = game.people.player.y;
    return blob;
}

fn validateSaveBlob(blob: *const SaveBlob) bool {
    if (blob.magic != save_magic or blob.version != save_version) return false;
    if (blob.stack_count > parts.max_parts) return false;
    return blob.checksum == saveBlobChecksum(blob);
}

fn applySaveBlob(game: *GameState, blob: *const SaveBlob) bool {
    if (!validateSaveBlob(blob)) return false;
    var next_stack = parts.Stack.init();
    var i: usize = 0;
    while (i < blob.stack_count) : (i += 1) {
        const kind = partKindFromByte(blob.stack_items[i]) orelse return false;
        if (!next_stack.add(kind)) return false;
    }

    game.money = blob.money;
    game.time = systems.TimeSystem.init();
    game.time.day = blob.day;
    game.time.hour = std.math.clamp(blob.hour, 0, 23);
    game.time.minute = std.math.clamp(blob.minute, 0.0, 59.0);
    game.story = systems.StoryState.init();
    game.story.flags = blob.story_flags;
    game.story.reputation = blob.reputation;
    game.story.research_points = blob.research_points;
    game.story.npc_morale = blob.npc_morale;
    game.achievements = systems.AchievementSystem.init();
    game.achievements.unlocked = blob.achievements_unlocked;
    game.achievements.launch_count = blob.launch_count;
    game.achievements.orbit_count = blob.orbit_count;
    game.missions = systems.MissionTracker.init();
    game.missions.completed = blob.missions_completed;
    game.missions.funds = blob.missions_funds;
    game.tech_flags = blob.tech_flags;
    game.stack = next_stack;
    game.rocket = rocket_mod.Rocket.init(config.earth_radius_m);
    game.people.player.x = blob.player_x;
    game.people.player.y = blob.player_y;
    game.people.player.target_x = blob.player_x;
    game.people.player.target_y = blob.player_y;
    game.people.update(&game.town_map, &game.time, &game.story, 0.0);
    game.orbit_info = .{};
    game.orbit_count = 0;
    game.launch_time_s = 0.0;
    game.mission_paid = false;
    game.map_open = false;
    game.dialogue_npc = -1;
    return true;
}

fn partKindFromByte(value: u8) ?parts.PartKind {
    return switch (value) {
        0 => .command_pod,
        1 => .service_module,
        2 => .fuel_tank,
        3 => .basic_engine,
        4 => .landing_leg,
        5 => .heat_shield,
        6 => .life_support,
        7 => .navigation,
        else => null,
    };
}

fn saveBlobChecksum(blob: *const SaveBlob) u32 {
    const bytes = std.mem.asBytes(blob);
    return checksumBytes(bytes[0 .. bytes.len - @sizeOf(u32)]);
}

fn checksumBytes(bytes: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (bytes) |b| {
        hash = (hash ^ b) *% 16777619;
    }
    return hash;
}

fn beginLaunch(game: *GameState) void {
    parts.repairOrder(&game.stack);
    if (!parts.isLaunchable(&game.stack)) {
        game.audio.errorTone();
        setNotice(game, "Rocket needs pod, tank, and bottom engine.");
        game.screen = .hangar;
        return;
    }
    startMissionCutscene(game);
}

fn startMissionCutscene(game: *GameState) void {
    game.cutscene = MissionCutsceneState.init();
    game.notice_len = 0;
    game.notice[0] = 0;
    game.notice_timer_s = 0.0;
    game.audio.confirm();
    game.screen = .mission_cutscene;
}

fn startIntroCutscene(game: *GameState) void {
    game.cutscene = MissionCutsceneState.init();
    game.notice_len = 0;
    game.notice[0] = 0;
    game.notice_timer_s = 0.0;
    game.audio.confirm();
    game.screen = .intro_cutscene;
}

fn completeIntroCutscene(game: *GameState) void {
    game.screen = .town;
    game.audio.confirm();
    setNotice(game, "Welcome to RocketCraft.");
}

fn completeMissionCutscene(game: *GameState) void {
    resetLaunch(game);
    applyAchievement(game, game.achievements.checkLaunch());
    game.audio.ignition();
    game.screen = .launch;
}

fn resetLaunch(game: *GameState) void {
    game.rocket = rocket_mod.buildFromStack(&game.stack, physics.earth.radius_m);
    applyResearchTechToRocket(game);
    game.rocket.throttle = 1.0;
    game.rocket.angle_deg = 0.0;
    game.orbit_count = 0;
    game.orbit_info = .{};
    game.launch_time_s = 0.0;
    game.mission_paid = false;
    game.missions.reset();
}

fn applyResearchTechToRocket(game: *GameState) void {
    if ((game.tech_flags & TechFlags.engine_tuning) != 0) {
        game.rocket.max_thrust_n *= 1.12;
    }
    if ((game.tech_flags & TechFlags.fuel_efficiency) != 0) {
        game.rocket.weighted_isp *= 1.08;
    }
}

fn newCampaign(game: *GameState) void {
    game.money = config.starting_funds;
    game.time = systems.TimeSystem.init();
    game.town_map = map_mod.TownMap.init();
    loadTownMapFromLdtk(game);
    game.people = people_mod.PeopleSystem.init();
    game.stack = parts.Stack.init();
    game.rocket = rocket_mod.Rocket.init(config.earth_radius_m);
    game.missions = systems.MissionTracker.init();
    game.achievements = systems.AchievementSystem.init();
    game.story = systems.StoryState.init();
    game.tech_flags = 0;
    game.orbit_info = .{};
    game.orbit_count = 0;
    game.launch_time_s = 0.0;
    game.mission_paid = false;
    game.notice_len = 0;
    game.notice[0] = 0;
    game.notice_timer_s = 0.0;
    game.map_open = false;
    game.dialogue_npc = -1;
    startIntroCutscene(game);
}

fn applyDisplaySettings(game: *GameState) void {
    if (game.settings.resolution_index >= resolution_options.len) {
        game.settings.resolution_index = 0;
    }
    const option = resolution_options[game.settings.resolution_index];
    const borderless = rl.IsWindowState(rl.FLAG_WINDOW_UNDECORATED);
    if (game.settings.fullscreen and !borderless) {
        rl.ToggleBorderlessWindowed();
    } else if (!game.settings.fullscreen and borderless) {
        rl.ToggleBorderlessWindowed();
        rl.SetWindowSize(@as(c_int, @intCast(option.width)), @as(c_int, @intCast(option.height)));
    } else if (!game.settings.fullscreen) {
        rl.SetWindowSize(@as(c_int, @intCast(option.width)), @as(c_int, @intCast(option.height)));
    }
    game.audio.confirm();
    saveSettingsFile(game);
}

fn setSettingSlider(game: *GameState, slider: SettingSlider, mouse_x: f32) void {
    const bar = settingsSliderRect(slider);
    if (bar.width <= 0.0) return;
    const value = std.math.clamp((mouse_x - bar.x) / bar.width, 0.0, 1.0);
    switch (slider) {
        .music => {
            game.settings.music_volume = value;
            game.audio.setMusicVolume(value);
        },
        .sfx => {
            game.settings.sfx_volume = value;
            game.audio.sfx_volume = value;
        },
        .none => {},
    }
}

fn settingsSliderRect(slider: SettingSlider) rl.Rectangle {
    return switch (slider) {
        .music => rect(474, 350, 420, 14),
        .sfx => rect(474, 418, 420, 14),
        .none => rect(0, 0, 0, 0),
    };
}

fn pointInRect(point: rl.Vector2, r: rl.Rectangle) bool {
    return point.x >= r.x and point.x <= r.x + r.width and point.y >= r.y and point.y <= r.y + r.height;
}

fn applyAchievement(game: *GameState, result: systems.AchievementResult) void {
    if (result.unlocked == 0) return;
    game.money += result.reward;
    game.audio.confirm();
    if (result.reward > 0) {
        setNoticeFmt(game, "Achievement: {s} +${d}", .{ result.name, result.reward });
    } else {
        setNoticeFmt(game, "Achievement: {s}", .{result.name});
    }
}

fn setNotice(game: *GameState, message: []const u8) void {
    const max_len = @min(message.len, game.notice.len - 1);
    @memcpy(game.notice[0..max_len], message[0..max_len]);
    game.notice[max_len] = 0;
    game.notice_len = max_len;
    game.notice_timer_s = 2.6;
}

fn setNoticeFmt(game: *GameState, comptime fmt: []const u8, args: anytype) void {
    const text = std.fmt.bufPrint(&game.notice, fmt, args) catch {
        setNotice(game, "Notice formatting failed.");
        return;
    };
    if (text.len < game.notice.len) game.notice[text.len] = 0;
    game.notice_len = text.len;
    game.notice_timer_s = 2.6;
}

fn audioMode(screen: Screen) audio_mod.AudioMode {
    return switch (screen) {
        .title => .title,
        .load_game => .title,
        .research => .title,
        .intro_cutscene => .title,
        .settings => .title,
        .town => .town,
        .hangar => .hangar,
        .mission_cutscene => .launch,
        .launch => .launch,
    };
}

fn drawNotice(game: *GameState) void {
    if (game.notice_len == 0 or game.notice_timer_s <= 0.0) return;
    const text = game.notice[0..game.notice_len :0];
    const width = rl.MeasureText(text.ptr, 20);
    const centered_x = @divTrunc(config.screen_width, 2) - @divTrunc(width, 2);
    const box = rect(@as(f32, @floatFromInt(centered_x - 24)), 88, @as(f32, @floatFromInt(width + 48)), 44);
    drawGlassPanel(box, rgb(255, 212, 120), 230);
    drawTextShadow(text.ptr, centered_x, 101, 20, rgb(255, 236, 39));
}

fn drawCinematicSpace(time: f32, top: rl.Color, bottom: rl.Color, accent: rl.Color) void {
    rl.DrawRectangleGradientV(0, 0, config.screen_width, config.screen_height, top, bottom);
    drawCircleGradient(1018, 610, 390.0, rgba(accent.r, accent.g, accent.b, 96), rgba(0, 0, 0, 0));
    drawCircleGradient(1018, 610, 212.0, rgba(48, 96, 116, 168), rgba(48, 96, 116, 0));
    rl.DrawEllipse(1020, 662, 548.0, 108.0, rgba(70, 132, 96, 210));
    rl.DrawEllipseLines(1020, 662, 548.0, 108.0, rgba(180, 235, 190, 130));
    drawStarfield(time);
    rl.DrawLine(0, 530, config.screen_width, 452, rgba(accent.r, accent.g, accent.b, 42));
    rl.DrawLine(0, 592, config.screen_width, 514, rgba(255, 236, 160, 26));
}

fn drawStarfield(time: f32) void {
    for (0..210) |i| {
        const base_x = @as(i32, @intCast((i * 97 + 31) % @as(usize, @intCast(config.screen_width))));
        const base_y = @as(i32, @intCast((i * 53 + 47) % @as(usize, @intCast(config.screen_height))));
        const drift = @mod(@as(i32, @intFromFloat(time * @as(f32, @floatFromInt((i % 5) + 1)) * 2.0)), config.screen_width);
        const x = @mod(base_x + drift, config.screen_width);
        const twinkle = @sin(time * 1.8 + @as(f32, @floatFromInt(i)) * 0.37) * 34.0;
        const b = toU8(146.0 + @as(f32, @floatFromInt((i * 17) % 84)) + twinkle);
        const size: i32 = if ((i & 31) == 0) 2 else 1;
        rl.DrawRectangle(x, base_y, size, size, .{ .r = b, .g = b, .b = if (b > 232) 255 else b + 22, .a = 255 });
    }
}

fn drawGlassPanel(r: rl.Rectangle, accent: rl.Color, alpha: u8) void {
    rl.DrawRectangleRounded(rect(r.x + 7.0, r.y + 8.0, r.width, r.height), 0.055, 8, rgba(0, 0, 0, 88));
    rl.DrawRectangleRounded(r, 0.055, 8, rgba(13, 19, 31, alpha));
    rl.DrawRectangleGradientH(toI32(r.x + 1.0), toI32(r.y + 1.0), toI32(r.width - 2.0), 4, rgba(accent.r, accent.g, accent.b, 190), rgba(255, 236, 160, 70));
    rl.DrawRectangleRoundedLinesEx(r, 0.055, 8, 1.5, rgba(152, 170, 214, 160));
    rl.DrawRectangleRoundedLinesEx(rect(r.x + 3.0, r.y + 3.0, r.width - 6.0, r.height - 6.0), 0.045, 8, 1.0, rgba(255, 255, 255, 28));
}

fn drawSectionTitle(title: [*:0]const u8, x: i32, y: i32, accent: rl.Color) void {
    rl.DrawRectangleGradientH(x, y + 31, 210, 2, rgba(accent.r, accent.g, accent.b, 220), rgba(accent.r, accent.g, accent.b, 0));
    drawTextShadow(title, x, y, 26, rgb(238, 244, 255));
}

fn drawStatChip(label: [*:0]const u8, value: [*:0]const u8, r: rl.Rectangle, accent: rl.Color) void {
    drawGlassPanel(r, accent, 204);
    drawText(label, toI32(r.x + 14.0), toI32(r.y + 10.0), 14, rgb(148, 166, 196));
    drawTextShadow(value, toI32(r.x + 14.0), toI32(r.y + 28.0), 21, rgb(245, 248, 255));
}

fn drawProgressBar(r: rl.Rectangle, value: f32, fill: rl.Color) void {
    const clamped = std.math.clamp(value, 0.0, 1.0);
    rl.DrawRectangleRounded(r, 0.35, 8, rgba(20, 26, 38, 230));
    rl.DrawRectangleRounded(rect(r.x, r.y, r.width * clamped, r.height), 0.35, 8, fill);
    rl.DrawRectangleRoundedLinesEx(r, 0.35, 8, 1.0, rgba(255, 255, 255, 72));
}

fn drawTextShadow(text: [*:0]const u8, x: i32, y: i32, size: i32, col: rl.Color) void {
    rl.DrawText(text, x + 2, y + 2, size, rgba(0, 0, 0, 150));
    rl.DrawText(text, x, y, size, col);
}

fn presentCanvas(canvas: rl.RenderTexture2D) void {
    rl.ClearBackground(rgb(8, 12, 20));
    rl.DrawTexturePro(
        canvas.texture,
        rect(0.0, 0.0, @as(f32, @floatFromInt(config.screen_width)), -@as(f32, @floatFromInt(config.screen_height))),
        rect(0.0, 0.0, @as(f32, @floatFromInt(rl.GetScreenWidth())), @as(f32, @floatFromInt(rl.GetScreenHeight()))),
        .{ .x = 0.0, .y = 0.0 },
        0.0,
        rgb(255, 255, 255),
    );
}

fn mousePosition() rl.Vector2 {
    const raw = rl.GetMousePosition();
    const screen_w = @max(1, rl.GetScreenWidth());
    const screen_h = @max(1, rl.GetScreenHeight());
    return .{
        .x = raw.x * @as(f32, @floatFromInt(config.screen_width)) / @as(f32, @floatFromInt(screen_w)),
        .y = raw.y * @as(f32, @floatFromInt(config.screen_height)) / @as(f32, @floatFromInt(screen_h)),
    };
}

fn drawStars() void {
    for (0..150) |i| {
        const x = @as(i32, @intCast((i * 97 + 31) % @as(usize, @intCast(config.screen_width))));
        const y = @as(i32, @intCast((i * 53 + 47) % @as(usize, @intCast(config.screen_height))));
        const b = @as(u8, @intCast(90 + ((i * 17) % 150)));
        const blue: u8 = if (b > 231) 255 else b + 24;
        rl.DrawPixel(x, y, .{ .r = b, .g = b, .b = blue, .a = 255 });
    }
}

fn button(r: rl.Rectangle, label: [*:0]const u8, fill: rl.Color) bool {
    const mouse = mousePosition();
    const hover = mouse.x >= r.x and mouse.x <= r.x + r.width and mouse.y >= r.y and mouse.y <= r.y + r.height;
    const color = if (hover) lighten(fill) else fill;
    rl.DrawRectangleRounded(rect(r.x + 5.0, r.y + 6.0, r.width, r.height), 0.16, 8, rgba(0, 0, 0, if (hover) 120 else 78));
    rl.DrawRectangleRounded(r, 0.16, 8, color);
    rl.DrawRectangleGradientH(toI32(r.x + 2.0), toI32(r.y + 2.0), toI32(r.width - 4.0), toI32(r.height * 0.42), rgba(255, 255, 255, if (hover) 64 else 32), rgba(255, 255, 255, 8));
    rl.DrawRectangleRoundedLinesEx(r, 0.16, 8, 2.0, if (hover) rgb(255, 212, 120) else rgba(16, 20, 28, 220));
    if (hover) {
        rl.DrawRectangleRoundedLinesEx(rect(r.x - 2.0, r.y - 2.0, r.width + 4.0, r.height + 4.0), 0.16, 8, 1.0, rgba(255, 212, 120, 112));
    }
    const tw = rl.MeasureText(label, 20);
    drawTextShadow(label, toI32(r.x + r.width * 0.5) - @divTrunc(tw, 2), toI32(r.y + r.height * 0.5) - 10, 20, rgb(245, 248, 255));
    return hover and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
}

fn drawText(text: [*:0]const u8, x: i32, y: i32, size: i32, col: rl.Color) void {
    rl.DrawText(text, x, y, size, col);
}

fn tileColor(kind: map_mod.TileKind, tx: i32, ty: i32, light: f32) rl.Color {
    const noise = @as(i32, @intCast(@mod(tx * 17 + ty * 31, 9))) - 4;
    const n = @as(f32, @floatFromInt(noise));
    const base = switch (kind) {
        .grass => .{ @as(f32, 72), @as(f32, 154), @as(f32, 70) },
        .dirt => .{ @as(f32, 126), @as(f32, 92), @as(f32, 56) },
        .cobblestone => .{ @as(f32, 124), @as(f32, 128), @as(f32, 130) },
        .wood => .{ @as(f32, 132), @as(f32, 88), @as(f32, 48) },
        .water => .{ @as(f32, 46), @as(f32, 126), @as(f32, 180) },
    };
    const shade = 0.66 + std.math.clamp(light, 0.0, 1.0) * 0.34;
    return rgb(
        toU8((base[0] + n) * shade),
        toU8((base[1] + n) * shade),
        toU8((base[2] + n) * shade),
    );
}

fn drawFormat(comptime fmt: []const u8, args: anytype, x: i32, y: i32, size: i32, col: rl.Color) void {
    var buf: [128]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, fmt, args) catch return;
    drawText(text.ptr, x, y, size, col);
}

fn loadTextureFromPaths(paths: []const [*:0]const u8, out: *rl.Texture2D, filter: c_int) bool {
    for (paths) |path| {
        if (!rl.FileExists(path)) continue;
        const texture = rl.LoadTexture(path);
        if (!rl.IsTextureValid(texture)) continue;
        rl.SetTextureFilter(texture, filter);
        out.* = texture;
        return true;
    }
    return false;
}

fn loadRelTexture(rel_path: []const u8, out: *rl.Texture2D) bool {
    var buf: [ldtk_path_bytes]u8 = undefined;
    const legacy_asset_prefix = "Game asset/";
    if (std.mem.startsWith(u8, rel_path, legacy_asset_prefix)) {
        const local_path = std.fmt.bufPrintZ(&buf, "assets/{s}", .{rel_path[legacy_asset_prefix.len..]}) catch return false;
        if (tryLoadRelTexturePath(local_path, out)) return true;
    }
    if (tryLoadRelTexturePath(rel_path, out)) return true;
    const parent = std.fmt.bufPrintZ(&buf, "../{s}", .{rel_path}) catch return false;
    if (tryLoadRelTexturePath(parent, out)) return true;
    const grand_parent = std.fmt.bufPrintZ(&buf, "../../{s}", .{rel_path}) catch return false;
    return tryLoadRelTexturePath(grand_parent, out);
}

fn tryLoadRelTexturePath(path: []const u8, out: *rl.Texture2D) bool {
    if (path.len == 0 or path.len >= ldtk_path_bytes) return false;
    var z: [ldtk_path_bytes]u8 = [_]u8{0} ** ldtk_path_bytes;
    @memcpy(z[0..path.len], path);
    if (!rl.FileExists(z[0..path.len :0].ptr)) return false;
    const texture = rl.LoadTexture(z[0..path.len :0].ptr);
    if (!rl.IsTextureValid(texture)) return false;
    rl.SetTextureFilter(texture, rl.TEXTURE_FILTER_POINT);
    out.* = texture;
    return true;
}

fn jObjectGet(value: std.json.Value, key: []const u8) ?std.json.Value {
    if (value != .object) return null;
    return value.object.get(key);
}

fn jArray(value: std.json.Value) ?[]const std.json.Value {
    if (value != .array) return null;
    return value.array.items;
}

fn jString(value: std.json.Value) ?[]const u8 {
    return switch (value) {
        .string => |s| s,
        else => null,
    };
}

fn jInt(value: std.json.Value) ?i32 {
    return switch (value) {
        .integer => |i| if (i >= std.math.minInt(i32) and i <= std.math.maxInt(i32)) @as(i32, @intCast(i)) else null,
        .float => |f| if (f >= @as(f64, @floatFromInt(std.math.minInt(i32))) and f <= @as(f64, @floatFromInt(std.math.maxInt(i32)))) @as(i32, @intFromFloat(f)) else null,
        else => null,
    };
}

fn rect(x: f32, y: f32, w: f32, h: f32) rl.Rectangle {
    return .{ .x = x, .y = y, .width = w, .height = h };
}

fn rgb(r: u8, g: u8, b: u8) rl.Color {
    return .{ .r = r, .g = g, .b = b, .a = 255 };
}

fn rgba(r: u8, g: u8, b: u8, a: u8) rl.Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

fn mixColor(a: rl.Color, b: rl.Color, t: f32) rl.Color {
    const k = std.math.clamp(t, 0.0, 1.0);
    return rgb(
        toU8(@as(f32, @floatFromInt(a.r)) + (@as(f32, @floatFromInt(b.r)) - @as(f32, @floatFromInt(a.r))) * k),
        toU8(@as(f32, @floatFromInt(a.g)) + (@as(f32, @floatFromInt(b.g)) - @as(f32, @floatFromInt(a.g))) * k),
        toU8(@as(f32, @floatFromInt(a.b)) + (@as(f32, @floatFromInt(b.b)) - @as(f32, @floatFromInt(a.b))) * k),
    );
}

fn toU8(value: f32) u8 {
    return @as(u8, @intFromFloat(std.math.clamp(value, 0.0, 255.0)));
}

fn lighten(c: rl.Color) rl.Color {
    return .{
        .r = if (c.r > 231) 255 else c.r + 24,
        .g = if (c.g > 231) 255 else c.g + 24,
        .b = if (c.b > 231) 255 else c.b + 24,
        .a = c.a,
    };
}

fn partColor(kind: parts.PartKind) rl.Color {
    return switch (kind) {
        .command_pod => rgb(220, 80, 80),
        .service_module => rgb(92, 132, 190),
        .fuel_tank => rgb(240, 150, 50),
        .basic_engine => rgb(140, 140, 150),
        .landing_leg => rgb(120, 100, 80),
        .heat_shield => rgb(120, 78, 66),
        .life_support => rgb(98, 196, 160),
        .navigation => rgb(112, 188, 235),
    };
}

fn partWidth(kind: parts.PartKind) i32 {
    return switch (kind) {
        .command_pod => 76,
        .service_module => 96,
        .fuel_tank => 92,
        .basic_engine => 68,
        .landing_leg => 110,
        .heat_shield => 90,
        .life_support => 82,
        .navigation => 72,
    };
}

fn launchZoom(altitude_m: f64) f64 {
    if (altitude_m < 12_000.0) return 0.0026;
    if (altitude_m < 100_000.0) return 0.0012;
    if (altitude_m < 800_000.0) return 0.00020;
    return 0.00005;
}

fn worldToLaunchScreen(wx: f64, wy: f64, game: *const GameState, zoom: f64) rl.Vector2 {
    const sx = 720.0 + (wy - game.rocket.y) * zoom;
    const sy = 470.0 - (wx - game.rocket.x) * zoom;
    return .{ .x = @as(f32, @floatCast(sx)), .y = @as(f32, @floatCast(sy)) };
}

fn toI32(value: f32) i32 {
    return @as(i32, @intFromFloat(value));
}

fn asF32(value: anytype) f32 {
    return switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => @as(f32, @floatFromInt(value)),
        .float, .comptime_float => @as(f32, @floatCast(value)),
        else => @compileError("value must be an integer or float"),
    };
}

test "game state starts with empty stack and fixed memory buffers" {
    const game = GameState.init();
    try std.testing.expectEqual(@as(usize, 0), game.stack.count);
    try std.testing.expectEqual(physics.max_orbit_points, game.orbit_points.len);
}

test "save blob checksum validates packed game state" {
    var game = GameState.init();
    _ = game.stack.add(.command_pod);
    game.tech_flags = TechFlags.engine_tuning;
    var blob = makeSaveBlob(&game);
    blob.checksum = saveBlobChecksum(&blob);
    try std.testing.expect(validateSaveBlob(&blob));
    blob.money += 1;
    try std.testing.expect(!validateSaveBlob(&blob));
}
