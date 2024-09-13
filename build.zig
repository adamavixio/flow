const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //
    // Modules
    //

    const module_math = b.addModule("math", .{
        .root_source_file = b.path("lib/math/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const module_container = b.addModule("container", .{
        .root_source_file = b.path("lib/container/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const module_flow = b.addModule("flow", .{
        .root_source_file = b.path("lib/flow/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    module_container.addImport("math", module_math);
    module_container.addImport("container", module_container);

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

    const test_module_math = b.addTest(.{
        .root_source_file = b.path("lib/math/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_module_container = b.addTest(.{
        .root_source_file = b.path("lib/container/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_module_flow = b.addTest(.{
        .root_source_file = b.path("lib/flow/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_executable_flow = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

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

    const run_test_module_math = b.addRunArtifact(test_module_math);
    const run_test_module_container = b.addRunArtifact(test_module_container);
    const run_test_module_flow = b.addRunArtifact(test_module_flow);
    const run_test_executable_flow = b.addRunArtifact(test_executable_flow);

    //
    // Steps
    //

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_test_module_math.step);
    test_step.dependOn(&run_test_module_container.step);
    test_step.dependOn(&run_test_module_flow.step);
    test_step.dependOn(&run_test_executable_flow.step);
}
