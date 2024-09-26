const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //
    // Modules
    //

    const module_type = b.addModule("type", .{
        .root_source_file = b.path("lib/type/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const module_flow = b.addModule("core", .{
        .root_source_file = b.path("lib/flow/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    module_flow.addImport("type", module_type);

    //
    // Executables
    //

    const executable_flow = b.addExecutable(.{
        .name = "flow",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    executable_flow.root_module.addImport("flow", module_flow);

    //
    // Tests
    //

    const module_type_test = b.addTest(.{
        .root_source_file = b.path("lib/type/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const module_flow_test = b.addTest(.{
        .root_source_file = b.path("lib/flow/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const executable_flow_test = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    module_flow_test.root_module.addImport("type", module_type);
    executable_flow_test.root_module.addImport("flow", module_flow);

    //
    // Install
    //

    b.installArtifact(executable_flow);

    //
    // Artifacts
    //

    const run_cmd = b.addRunArtifact(executable_flow);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const module_flow_test_run = b.addRunArtifact(module_flow_test);
    const module_type_test_run = b.addRunArtifact(module_type_test);
    const executable_flow_test_run = b.addRunArtifact(executable_flow_test);

    //
    // Steps
    //

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&module_flow_test_run.step);
    test_step.dependOn(&module_type_test_run.step);
    test_step.dependOn(&executable_flow_test_run.step);
}
