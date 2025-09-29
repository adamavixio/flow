const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    //
    // Modules
    //

    const core_module = builder.createModule(.{
        .root_source_file = builder.path("src/core/root.zig"),
    });

    const flow_module = builder.createModule(.{
        .root_source_file = builder.path("src/flow/root.zig"),
    });

    const io_module = builder.createModule(.{
        .root_source_file = builder.path("src/io/root.zig"),
    });

    //
    // Executables
    //

    const main_module = builder.createModule(.{
        .root_source_file = builder.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    main_module.addImport("core", core_module);
    main_module.addImport("flow", flow_module);
    main_module.addImport("io", io_module);

    const flow_executable = builder.addExecutable(.{
        .name = "flow",
        .root_module = main_module,
    });

    builder.installArtifact(flow_executable);

    //
    // Tests
    //

    const test_module = builder.createModule(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_module.addImport("flow", flow_module);

    const flow_test = builder.addTest(.{
        .root_module = test_module,
    });

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
