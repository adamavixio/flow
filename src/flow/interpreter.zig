const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const io = lib.io;
const flow = lib.flow;

pub const Interpreter = @This();

source: io.Source,
allocator: mem.Allocator,

pub const Error = error{
    InvalidStatement,
    InvalidExpression,
    TransformParametersInvalid,
    MutationParametersInvalid,
};

pub fn init(allocator: mem.Allocator, source: io.Source) Interpreter {
    return .{
        .source = source,
        .allocator = allocator,
    };
}

pub fn execute(self: Interpreter, statements: []*flow.AST.Statement) !void {
    for (statements) |statement| {
        switch (statement.*) {
            .expression => |expression| {
                const value = try self.evaluateExpression(expression);
                defer value.deinit(self.allocator);
            },
        }
    }
}

pub fn evaluateExpression(self: Interpreter, expression: *flow.AST.Expression) !core.Value {
    return switch (expression.*) {
        .literal => |literal| switch (literal.token.tag) {
            .int => blk: {
                const data = self.exchange(literal.token);
                break :blk try core.Value.parse(self.allocator, .int, data);
            },
            .float => blk: {
                const data = self.exchange(literal.token);
                break :blk try core.Value.parse(self.allocator, .float, data);
            },
            else => return Error.InvalidExpression,
        },
        .typed => |typed| {
            const tag = try core.Type.parse(self.exchange(typed.name));
            const value = try self.evaluateExpression(typed.expression);
            if (tag != meta.activeTag(value)) {
                return value;
            }
            const transform: core.Transform = switch (tag) {
                .int => .int,
                .uint => .uint,
                .float => .float,
                .string => .string,
                else => return Error.InvalidExpression,
            };
            defer value.deinit(self.allocator);
            return value.applyTransform(self.allocator, transform, &.{});
        },
        .pipeline => |pipeline| {
            var value = try self.evaluateExpression(pipeline.initial);
            for (pipeline.operations) |operation| {
                switch (operation) {
                    .mutation => |mutation_operation| {
                        var parameter_values = std.ArrayList(core.Value).init(self.allocator);
                        for (mutation_operation.parameters) |parameter_expression| {
                            const parameter_value = try self.evaluateExpression(parameter_expression);
                            try parameter_values.append(parameter_value);
                        }
                        const values = try parameter_values.toOwnedSlice();
                        defer self.allocator.free(values);
                        const name = self.exchange(mutation_operation.name);
                        const mutation_tag = try core.Mutation.parse(name);
                        try value.applyMutation(mutation_tag, values);
                    },
                    .transform => |transform_operation| {
                        var parameters = std.ArrayList(core.Value).init(self.allocator);
                        for (transform_operation.parameters) |parameter_expression| {
                            const parameter_value = try self.evaluateExpression(parameter_expression);
                            try parameters.append(parameter_value);
                        }
                        const values = try parameters.toOwnedSlice();
                        defer self.allocator.free(values);
                        const name = self.exchange(transform_operation.name);
                        const transform_tag = try core.Transform.parse(name);
                        const transform_coercion: core.Transform = switch (transform_tag) {
                            .int => .int,
                            .uint => .uint,
                            .float => .float,
                            .string => .string,
                            .print => .{ .print = std.io.getStdErr().writer().any() },
                        };
                        const old = value;
                        defer old.deinit(self.allocator);
                        value = try value.applyTransform(self.allocator, transform_coercion, &.{});
                    },
                }
            }
            return value;
        },
    };
}

pub fn exchange(self: Interpreter, token: flow.Token) []const u8 {
    return self.source.buffer[token.start..token.end];
}

test execute {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "float : 5 | sub 10 | sub 5 -> string -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);

    const interpreter = init(testing.allocator, source);
    const statements = try parser.parse();
    _ = try interpreter.execute(statements);
}
