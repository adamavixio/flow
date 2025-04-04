const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    //
    // Modules
    //

    const flow_module = builder.createModule(.{
        .root_source_file = builder.path("src/flow/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const io_module = builder.createModule(.{
        .root_source_file = builder.path("src/io/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    //
    // Executables
    //

    const flow_executable = builder.addExecutable(.{
        .name = "flow",
        .root_source_file = builder.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    flow_executable.root_module.addImport(
        "flow",
        flow_module,
    );

    flow_executable.root_module.addImport(
        "io",
        io_module,
    );

    builder.installArtifact(flow_executable);

    //
    // Tests
    //

    const flow_test = builder.addTest(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    flow_test.root_module.addImport("flow", flow_module);

    //
    // Command (flow)
    //

    const flow_step = builder.addRunArtifact(flow_executable);
    flow_step.step.dependOn(builder.getInstallStep());
    if (builder.args) |args| flow_step.addArgs(args);

    const flow_command = builder.step("flow", "Run flow");
    flow_command.dependOn(&flow_step.step);

    //
    // Command (flow)
    //

    const test_step = builder.addRunArtifact(flow_test);

    const test_command = builder.step("test", "Run tests");
    test_command.dependOn(&test_step.step);
}
