const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const io = lib.io;
const flow = lib.flow;

pub const Error = error{
    ParametersInvalid,
};

pub fn execute(allocator: mem.Allocator, source: io.Source) !void {
    const arena = try heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const statements = try flow.Parser.parse(arena.allocator(), source);
    for (statements) |statement| try evaluateStatement(allocator, source, null, statement);
}

pub fn evaluateStatement(
    allocator: mem.Allocator,
    source: io.Source,
    statement: *flow.AST.Statement,
) !void {
    switch (statement) {
        .expression => |expression| try evaluateExpression(allocator, source, expression),
    }
}

pub fn evaluateExpression(
    allocator: mem.Allocator,
    source: io.Source,
    expression: *flow.AST.Expression,
) !core.Value {
    return switch (expression) {
        .typed => |typed| {
            const tag = core.Type.parse(typed.type.name);
            const data = exchange(source, typed.value);
            return parseValue(allocator, tag, data);
        },
        .mutation => |mutation| {
            const input = try evaluateExpression(allocator, source, mutation.input);
            const operation = exchange(mutation.operation);
            const tags = try input.parseMutation(operation);
            var values = std.ArrayList(core.Value).init(allocator);
            for (tags, mutation.parameters) |tag, parameter| {}
            if (tags.len != mutation.parameters.len) {
                return Error.MutationParametersInvalid;
            }

            for (tags, mutation.parameters) |tag, parameter| {
                switch (parameter.expression) {}
            }
        },
    };
}

pub fn parseValue(allocator: mem.Allocator, tag: core.Type.Tag, data: []const u8) !core.Value {
    return core.Value.parse(allocator, tag, data);
}

pub fn exchange(source: io.Source, token: flow.Token) []const u8 {
    return source.buffer[token.start..token.end];
}

fn executeExpression(allocator: mem.Allocator, source: io.Source, node: *flow.AST.Node) !core.Value {
    std.debug.print("\nExecute Expression", .{});
    return switch (node.statement) {
        .declaration => Error.DeclarationNode,
        .expression => |expression| switch (expression) {
            .literal => |token| {
                std.debug.print("\nExecute Literal", .{});
                const left_node = node.left orelse return Error.ExpressionLiteralLeftNull;
                const left_value = try executeDeclaration(allocator, source, left_node);
                const data = source.buffer[token.start..token.end];
                const value = try core.Value.parse(allocator, left_value, data);
                std.debug.print("\nExpression Literal: {any}", .{value});
                return value;
            },
            .operation => error.Unimplemented,
            .mutation => |token| {
                std.debug.print("\nExecute Mutation", .{});
                const left_node = node.left orelse return Error.ExpressionMutationLeftNull;
                var left_value = try executeExpression(allocator, source, left_node);
                std.debug.print("\nExpression Mutation Left: {any}", .{left_value});
                const right_node = node.right orelse return Error.ExpressionMutationRightNull;
                var right_value = try executeExpression(allocator, source, right_node);
                std.debug.print("\nExpression Mutation Right: {any}", .{right_value});
                const data = source.buffer[token.start..token.end];
                const mutation = try left_value.parseMutation(data);
                const parameters = try right_value.data.tuple.toOwnedSlice();
                try left_value.applyMutation(mutation, parameters);
                std.debug.print("\nExpression Mutation Value: {any}", .{left_value});
                return left_value;
            },
            .transform => |token| {
                std.debug.print("\nExecute Transform", .{});
                const left_node = node.left orelse return Error.ExpressionTransformLeftNull;
                var left_value = try executeExpression(allocator, source, left_node);
                std.debug.print("\nExpression Transform Left: {any}", .{left_value});
                const right_node = node.right orelse return Error.ExpressionMutationRightNull;
                var right_value = try executeExpression(allocator, source, right_node);
                std.debug.print("\nExpression Transform Right: {any}", .{left_value});
                const data = source.buffer[token.start..token.end];
                const transform = try left_value.parseTransform(data);
                const parameters = try right_value.data.tuple.toOwnedSlice();
                const value = switch (transform) {
                    .string => left_value.applyTransform(allocator, .string, parameters),
                    .print => left_value.applyTransform(allocator, .{
                        .print = std.io.getStdOut().writer().any(),
                    }, parameters),
                };
                std.debug.print("\nExpression Transform Value: {any}", .{value});
                return value;
            },
            .parameters => |nodes| {
                std.debug.print("\nExecute Parameters", .{});
                var value = try core.Value.parse(allocator, .tuple, &.{});
                for (nodes) |parameter| {
                    const parameter_value = try executeExpression(allocator, source, parameter);
                    try value.data.tuple.append(parameter_value);
                }
                std.debug.print("\nExpression Parameters Value: {any}", .{value});
                return value;
            },
        },
    };
}

pub fn visitType(self: Interpreter, node: *flow.AST.Node) !core.Type.Tag {
    const token = node.statement.type.name.token;
    const data = self.source.buffer[token.start..token.end];
    return core.Type.parse(data);
}

test execute {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 5 | add 10 | sub 5 -> string -> print";
    const source = try io.Source.initString(arena.allocator(), input);
    try execute(arena.allocator(), source);
}
