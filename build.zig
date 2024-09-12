const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const Modules = struct {
        const flow = b.addModule("flow", .{
            .root_source_file = b.path("lib/flow/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        const container = b.addModule("container", .{
            .root_source_file = b.path("lib/container/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        const math = b.addModule("math", .{
            .root_source_file = b.path("lib/math/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        fn init() void {
            flow.addImport(container);
            container.addImport(math);
        }
    };

    const Executables = struct {
        const flow = b.addExecutable(.{
            .name = "flow",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        fn init() void {
            flow.root_module.addImport(Modules.container);
            b.installArtifact(flow);
        }
    };

    const Tests = struct {
        const flow = b.addTest(.{
            .root_source_file = b.path("lib/flow/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        const container = b.addTest(.{
            .root_source_file = b.path("lib/flow/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        const math = b.addTest(.{
            .root_source_file = b.path("lib/math/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        fn init() void {}
    };

    const Steps = struct {
        const unit_test = b.step("test", "Run unit tests");

        fn init() void {
            unit_test.dependOn(b.addRunArtifact(&Tests.flow.step));
            unit_test.dependOn(b.addRunArtifact(&Tests.container.step));
            unit_test.dependOn(b.addRunArtifact(&Tests.math.step));
        }
    };

    Modules.init();
    Executables.init();
    Tests.init();
    Steps.init();
}
