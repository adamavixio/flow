const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    //
    // Module (log)
    //

    _ = builder.addModule("datetime", .{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const log_test = builder.addTest(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    //
    // Command (test)
    //

    const test_step = builder.addRunArtifact(log_test);

    const test_command = builder.step("test", "Run module tests");
    test_command.dependOn(&test_step.step);
}
