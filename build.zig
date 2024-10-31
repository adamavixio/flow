const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //
    // Build (log)
    //

    const log_build = b.dependency("log", .{
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run all tests");

    // Add log tests
    const log_tests = b.addRunArtifact(log_build.artifact("test"));
    test_step.dependOn(&log_tests.step);
}
