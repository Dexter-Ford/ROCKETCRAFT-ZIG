const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    configureRaylibModule(b, root_module, target, optimize);

    const exe = b.addExecutable(.{
        .name = "rocketcraft-zig",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run RocketCraft Zig");
    run_step.dependOn(&run_cmd.step);

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    configureRaylibModule(b, test_module, target, optimize);

    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });

    const test_cmd = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_cmd.step);
}

fn configureRaylibModule(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const raylib_dep = if (target.result.os.tag == .windows)
        b.dependency("raylib", .{
            .target = target,
            .optimize = optimize,
            .platform = .win32,
            .rmodels = false,
        })
    else
        b.dependency("raylib", .{
            .target = target,
            .optimize = optimize,
            .platform = .glfw,
            .rmodels = false,
        });
    module.addIncludePath(raylib_dep.path("src"));
    module.linkLibrary(raylib_dep.artifact("raylib"));
}
