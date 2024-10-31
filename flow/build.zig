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

    const core = builder.dependency("core", .{
        .target = target,
        .optimize = optimize,
    });

    //
    // Executable (flow)
    //

    const flow = builder.addExecutable(.{
        .name = "flow",
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    flow.root_module.addImport("log", log.module("log"));
    flow.root_module.addImport("core", core.module("core"));

    const flow_test = builder.addTest(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    flow_test.root_module.addImport("log", log.module("log"));
    flow_test.root_module.addImport("core", core.module("core"));

    //
    // Command (flow)
    //

    const flow_step = builder.addRunArtifact(flow);
    flow_step.step.dependOn(builder.getInstallStep());

    if (builder.args) |args| {
        flow_step.addArgs(args);
    }

    const flow_command = builder.step("flow", "Run flow");
    flow_command.dependOn(&flow_step.step);

    //
    // Command (test)
    //

    const test_step = builder.addRunArtifact(flow_test);

    const test_command = builder.step("test", "Run tests");
    test_command.dependOn(&test_step.step);
}
