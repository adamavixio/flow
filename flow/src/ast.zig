const std = @import("std");
const core = @import("core");
const Token = @import("token.zig");

pub const Ast = @This();

pipelines: std.ArrayList(*Pipeline),

pub fn init(allocator: std.mem.Allocator) !*Ast {
    const ast = try allocator.create(Ast);
    ast.* = .{ .pipelines = std.ArrayList(*Pipeline).init(allocator) };
    return ast;
}

pub fn deinit(module: *Ast, allocator: std.mem.Allocator) void {
    for (module.pipelines.items) |pipeline| {
        pipeline.deinit(allocator);
    }
    module.pipelines.deinit();
    allocator.destroy(module);
}

pub const Pipeline = struct {
    stages: std.ArrayList(*Stage),

    pub fn init(allocator: std.mem.Allocator) !*Pipeline {
        const pipeline = try allocator.create(Pipeline);
        pipeline.* = .{ .stages = std.ArrayList(*Stage).init(allocator) };
        return pipeline;
    }

    pub fn deinit(pipeline: *Pipeline, allocator: std.mem.Allocator) void {
        for (pipeline.stages.items) |stage| {
            stage.deinit(allocator);
        }
        pipeline.stages.deinit();
        allocator.destroy(pipeline);
    }
};

pub const Stage = struct {
    steps: std.ArrayList(*Step),

    pub fn init(allocator: std.mem.Allocator) !*Stage {
        const stage = try allocator.create(Stage);
        stage.* = .{ .steps = std.ArrayList(*Step).init(allocator) };
        return stage;
    }

    pub fn deinit(self: *Stage, allocator: std.mem.Allocator) void {
        for (self.steps.items) |step| {
            step.deinit(allocator);
        }
        self.steps.deinit();
        allocator.destroy(self);
    }
};

pub const Step = union(enum) {
    input: Input,
    mutation: Mutation,
    transform: Transform,
    terminal: Terminal,

    pub const Input = struct {
        token: Token,
        arguments: []Token,
        input: core.Type.Tag,
    };

    pub const Mutation = struct {
        name: Token,
        args: []Token,
    };

    pub const Transform = struct {
        name: Token,
        args: []Token,
        output: core.Type.Tag,
    };

    pub const Terminal = struct {
        name: Token,
        args: []Token,
    };
};
