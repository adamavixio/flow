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
debug_enabled: bool = true,

fn debug(self: Interpreter, comptime fmt: []const u8, args: anytype) void {
    if (!self.debug_enabled) return;
    std.debug.print("[DEBUG] " ++ fmt ++ "\n", args);
}

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
            .declaration => |_| {
                // TODO: Handle declarations
            },
        }
    }
}

pub fn evaluateExpression(self: Interpreter, expression: *flow.AST.Expression) !core.Value {
    const result = switch (expression.*) {
        .literal => |literal| switch (literal.token.tag) {
            .int => blk: {
                const data = self.exchange(literal.token);
                break :blk try core.Value.parse(self.allocator, .int, data);
            },
            .float => blk: {
                const data = self.exchange(literal.token);
                break :blk try core.Value.parse(self.allocator, .float, data);
            },
            .string => blk: {
                const data = self.exchange(literal.token);
                // Remove quotes from string literal
                const trimmed = if (data.len >= 2 and data[0] == '"' and data[data.len - 1] == '"')
                    data[1 .. data.len - 1]
                else
                    data;
                break :blk try core.Value.parse(self.allocator, .string, trimmed);
            },
            else => {
                return Error.InvalidExpression;
            },
        },
        .typed => |typed| {
            const tag = try core.Type.parse(self.exchange(typed.name));
            const value = try self.evaluateExpression(typed.expression);
            if (tag == meta.activeTag(value)) {
                return value;
            }
            // For file system types, we need to create them from string literals
            switch (tag) {
                .file, .directory, .path => {
                    // Extract string data from the value
                    const string_data = switch (value) {
                        .string => |s| s.data,
                        else => {
                            defer value.deinit(self.allocator);
                            return Error.InvalidExpression;
                        },
                    };
                    defer value.deinit(self.allocator);
                    return try core.Value.parse(self.allocator, tag, string_data);
                },
                .int, .uint, .float, .string => {
                    const transform: core.Transform = switch (tag) {
                        .int => .int,
                        .uint => .uint,
                        .float => .float,
                        .string => .string,
                        else => unreachable,
                    };
                    defer value.deinit(self.allocator);
                    return value.applyTransform(self.allocator, transform, &.{});
                },
                else => return Error.InvalidExpression,
            }
        },
        .pipeline => |pipeline| blk: {
            var value = try self.evaluateExpression(pipeline.initial);

            for (pipeline.operations) |operation| {
                switch (operation) {
                    .mutation => |mutation_operation| {
                        var parameter_values = std.ArrayList(core.Value).empty;
                        for (mutation_operation.parameters) |parameter_expression| {
                            const parameter_value = try self.evaluateExpression(parameter_expression);
                            try parameter_values.append(self.allocator, parameter_value);
                        }
                        const values = try parameter_values.toOwnedSlice(self.allocator);
                        defer self.allocator.free(values);
                        const name = self.exchange(mutation_operation.name);
                        const mutation_tag = try core.Mutation.parse(name);
                        try value.applyMutation(mutation_tag, values);
                    },
                    .transform => |transform_operation| {
                        var parameters = std.ArrayList(core.Value).empty;
                        for (transform_operation.parameters) |parameter_expression| {
                            const parameter_value = try self.evaluateExpression(parameter_expression);
                            try parameters.append(self.allocator, parameter_value);
                        }
                        const values = try parameters.toOwnedSlice(self.allocator);
                        defer {
                            for (values) |v| {
                                v.deinit(self.allocator);
                            }
                            self.allocator.free(values);
                        }
                        const name = self.exchange(transform_operation.name);
                        const transform_tag = try core.Transform.parse(name);
                        if (transform_tag == .print) {
                            // Handle print specially - just output and return void
                            switch (value) {
                                .int => |v| std.debug.print("{d}\n", .{v.data}),
                                .uint => |v| std.debug.print("{d}\n", .{v.data}),
                                .float => |v| std.debug.print("{d}\n", .{v.data}),
                                .string => |v| std.debug.print("{s}\n", .{v.data}),
                                .array => |arr| {
                                    std.debug.print("[\n", .{});
                                    for (arr.data) |item| {
                                        std.debug.print("  ", .{});
                                        switch (item) {
                                            .int => |v| std.debug.print("{d}", .{v.data}),
                                            .uint => |v| std.debug.print("{d}", .{v.data}),
                                            .float => |v| std.debug.print("{d}", .{v.data}),
                                            .string => |v| std.debug.print("{s}", .{v.data}),
                                            .file => |f| std.debug.print("{s}", .{f.data.path}),
                                            else => std.debug.print("?", .{}),
                                        }
                                        std.debug.print("\n", .{});
                                    }
                                    std.debug.print("]\n", .{});
                                },
                                else => {},
                            }
                            const old = value;
                            defer old.deinit(self.allocator);
                            value = core.Value.init(.void, .{ .owned = false, .data = {} });
                        } else {
                            // Build the transform with parameters
                            const transform: core.Transform = switch (transform_tag) {
                                .int => .int,
                                .uint => .uint,
                                .float => .float,
                                .string => .string,
                                .content => .content,
                                .exists => .exists,
                                .size => .size,
                                .extension => .extension,
                                .basename => .basename,
                                .dirname => .dirname,
                                .copy => copy_blk: {
                                    if (values.len != 1) return Error.TransformParametersInvalid;
                                    const dest_path = switch (values[0]) {
                                        .string => |s| s.data,
                                        else => return Error.TransformParametersInvalid,
                                    };
                                    break :copy_blk .{ .copy = dest_path };
                                },
                                .write => write_blk: {
                                    if (values.len != 1) return Error.TransformParametersInvalid;
                                    const content = switch (values[0]) {
                                        .string => |s| s.data,
                                        else => return Error.TransformParametersInvalid,
                                    };
                                    break :write_blk .{ .write = content };
                                },
                                .files => files_blk: {
                                    const pattern = if (values.len > 0) switch (values[0]) {
                                        .string => |s| s.data,
                                        else => return Error.TransformParametersInvalid,
                                    } else null;
                                    break :files_blk .{ .files = pattern };
                                },
                                .length => .length,
                                .first => .first,
                                .last => .last,
                                .filter, .map, .each => return Error.InvalidExpression, // Not yet implemented
                                else => return Error.InvalidExpression,
                            };
                            const new_value = try value.applyTransform(self.allocator, transform, &.{});
                            // For transforms that don't create new allocations (like write which returns self),
                            // we need to avoid double-free. Check if the transform is one that reuses the value.
                            const reuses_value = switch (transform_tag) {
                                .write => true,  // write returns self
                                .filter, .map, .each => true, // these return self (placeholder)
                                else => false,
                            };
                            if (!reuses_value) {
                                value.deinit(self.allocator);
                            }
                            value = new_value;
                        }
                    },
                }
            }
            break :blk value;
        },
    };
    return result;
}

pub fn exchange(self: Interpreter, token: flow.Token) []const u8 {
    return self.source.buffer[token.start..token.end];
}

test execute {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 5 | add 10 | sub 5 -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);

    const interpreter = init(testing.allocator, source);
    const statements = try parser.parse();
    _ = try interpreter.execute(statements);
}
