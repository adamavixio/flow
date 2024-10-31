const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    //
    // Build (log)
    //

    const log = builder.dependency("log", .{
        .target = target,
        .optimize = optimize,
    });

    //
    // Module (core)
    //

    const core = builder.addModule("core", .{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    core.addImport("log", log.module("log"));

    //
    // Test (core)
    //

    const core_test = builder.addTest(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    core_test.root_module.addImport("log", log.module("log"));

    //
    // Command (test)
    //

    const test_step = builder.addRunArtifact(core_test);
    const test_command = builder.step("test", "Run module tests");
    test_command.dependOn(&test_step.step);
}
