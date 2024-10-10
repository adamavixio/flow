const std = @import("std");
const primitive = @import("type/primitive.zig");

const Ast = @This();
const Token = @import("token.zig");

pipelines: std.ArrayList(*Pipeline),

pub const Pipeline = struct {
    stages: std.ArrayList(*Stage),

    pub fn init(allocator: std.mem.Allocator) !*Pipeline {
        const pipeline = try allocator.create(Pipeline);
        pipeline.* = .{
            .stages = std.ArrayList(*Stage).init(allocator),
        };
        return pipeline;
    }

    pub fn deinit(pipeline: *Pipeline, allocator: std.mem.Allocator) void {
        for (pipeline.stages.items) |stage| {
            stage.deinit(allocator);
        }
        pipeline.stages.deinit();
        allocator.destroy(pipeline);
    }

    pub fn appendStage(pipeline: *Pipeline, stage: *Stage) !void {
        try pipeline.stages.append(stage);
    }
};

pub const Stage = struct {
    input: primitive.Type,
    output: primitive.Type,
    literals: std.ArrayList(Token),
    mutations: std.ArrayList(Token),
    transforms: std.ArrayList(Token),
    terminals: std.ArrayList(Token),

    pub fn init(tag: primitive.Type, allocator: std.mem.Allocator) !*Stage {
        const stage = try allocator.create(Stage);
        stage.* = .{
            .tag = tag,
            .literals = std.ArrayList(Token).init(allocator),
            .mutations = std.ArrayList(Token).init(allocator),
            .transforms = std.ArrayList(Token).init(allocator),
            .terminals = std.ArrayList(Token).init(allocator),
        };
        return stage;
    }

    pub fn deinit(stage: *Stage, allocator: std.mem.Allocator) void {
        switch (stage.*) {
            inline else => |s| {
                s.literals.deinit();
                s.mutations.deinit();
                s.transforms.deinit();
                s.terminals.deinit();
            },
        }
        allocator.destroy(stage);
    }

    pub fn appendLiteral(stage: *Stage, token: Token) !void {
        switch (stage.*) {
            inline else => |*self| {
                try self.literals.append(token);
            },
        }
    }

    pub fn appendMutation(stage: *Stage, token: Token) !void {
        switch (stage.*) {
            inline else => |*self| {
                try self.mutations.append(token);
            },
        }
    }

    pub fn appendTransform(stage: *Stage, token: Token) !void {
        switch (stage.*) {
            inline else => |*self| {
                try self.transforms.append(token);
            },
        }
    }

    pub fn appendTerminal(stage: *Stage, token: Token) !void {
        switch (stage.*) {
            inline else => |*self| {
                try self.terminals.append(token);
            },
        }
    }
};

pub fn init(allocator: std.mem.Allocator) !*Ast {
    const ast = try allocator.create(Ast);
    ast.* = .{
        .pipelines = std.ArrayList(*Pipeline).init(allocator),
    };
    return ast;
}

pub fn deinit(module: *Ast, allocator: std.mem.Allocator) void {
    for (module.pipelines.items) |pipeline| {
        pipeline.deinit(allocator);
    }
    module.pipelines.deinit();
    allocator.destroy(module);
}

pub fn appendPipeline(ast: *Ast, pipeline: *Pipeline) !void {
    try ast.pipelines.append(pipeline);
}
