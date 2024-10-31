const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    //
    // Build (log)
    //

    const datetime_build = builder.dependency("datetime", .{
        .target = target,
        .optimize = optimize,
    });

    //
    // Module (datetime)
    //

    const datetime_module = datetime_build.module("datetime");

    //
    // Module (log)
    //

    const log_module = builder.addModule("log", .{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    log_module.addImport("datetime", datetime_module);

    //
    // Test (log)
    //

    const log_test = builder.addTest(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    log_test.root_module.addImport("datetime", datetime_module);

    //
    // Command (test)
    //

    const test_step = builder.addRunArtifact(log_test);
    const test_command = builder.step("test", "Run module tests");

    test_command.dependOn(&test_step.step);
}
