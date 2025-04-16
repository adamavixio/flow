const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

const lib = @import("../root.zig");
const core = lib.core;
const flow = lib.flow;
const io = lib.io;

const Analyzer = @This();
types: std.AutoHashMap(flow.AST.Expression, core.Type),
values: std.AutoHashMap(flow.AST.Expression, core.Type.Value),
errors: std.ArrayList(Diagnostic),
source: io.Source,
allocator: mem.Allocator,

pub const Diagnostic = struct {
    type: Error,
    token: flow.Token,
};

pub const Error = error{
    InvalidType,
    InvalidValueInt,
    InvalidValueFloat,
    InvalidOperation,
    InvalidExpressionPipeline,
};

pub fn init(allocator: mem.Allocator, source: io.Source) Analyzer {
    return .{
        .types = std.AutoHashMap(flow.AST.Expression, core.Type.Tag).init(allocator),
        .values = std.AutoHashMap(flow.AST.Expression, core.Type.Value).init(allocator),
        .errors = std.ArrayList(Diagnostic).init(allocator),
        .source = source,
        .allocator = allocator,
    };
}

pub fn run(self: Analyzer, ast: flow.AST) void {
    for (ast.statements) |statement| switch (statement) {
        .expression => |expression| try self.runPipeline(expression),
    };
}

pub fn runPipeline(self: Analyzer, expression: flow.AST.Expression) !void {
    switch (expression) {
        .pipeline => |pipeline| {
            const tag = if (self.tryType(pipeline.type)) |tag| blk: {
                try self.types.put(expression, tag);
                break :blk tag;
            } else |err| return switch (err) {
                core.Type.Error.TypeNotFound => try self.errors.append(.{
                    .type = .InvalidType,
                    .token = pipeline.type,
                }),
                else => err,
            };

            if (self.tryValue(tag, pipeline.value)) |value| {
                try self.values.put(expression, value);
            } else |err| return switch (err) {
                fmt.ParseIntError => try self.errors.append(.{
                    .type = .InvalidValueInt,
                    .token = pipeline.value,
                }),
                fmt.ParseFloatError => try self.errors.append(.{
                    .type = .InvalidValueFloat,
                    .token = pipeline.value,
                }),
                else => err,
            };

            for (pipeline.operations) |operation| {
                try self.runOperation(operation);
            }
        },
        else => Error.InvalidExpressionPipeline,
    }
}

pub fn runOperation(self: Analyzer, expression: flow.AST.Expression) !void {
    switch (expression) {
        .pipeline => |pipeline| {
            const tag = if (self.tryType(pipeline.type)) |tag| blk: {
                try self.types.put(expression, tag);
                break :blk tag;
            } else {
                return try self.errors.append(.{
                    .type = .InvalidType,
                    .token = pipeline.type,
                });
            };

            if (self.tryValue(tag, pipeline.value)) |value| {
                try self.values.put(expression, value);
            } else {
                return try self.errors.append(.{
                    .type = .InvalidValue,
                    .token = pipeline.value,
                });
            }

            for (pipeline.operations) |operation| {}
        },
    }
}

pub fn tryType(self: Analyzer, token: flow.Token) !core.Type.Tag {
    const content = self.exchange(token);
    return core.Type.Tag.parse(content);
}

pub fn tryValue(self: Analyzer, tag: core.Type.Tag, token: flow.Token) !core.Type.Tag {
    const content = self.exchange(token);
    return core.Type.Value.init(self.allocator, tag, content);
}

pub fn exchange(self: Analyzer, token: flow.Token) []const u8 {
    return self.source.buffer[token.start..token.end];
}
