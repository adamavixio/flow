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
debug_enabled: bool = false,
current_pipeline: ?flow.AST.Pipeline = null,
current_operation: ?flow.AST.Operation = null,

fn debug(self: Interpreter, comptime fmt: []const u8, args: anytype) void {
    if (!self.debug_enabled) return;
    std.debug.print("[DEBUG] " ++ fmt ++ "\n", args);
}

pub const Error = error{
    InvalidPipeline,
    InvalidSource,
    TransformParametersInvalid,
    MutationParametersInvalid,
    RuntimeError,
};

fn reportRuntimeError(self: Interpreter, err: anyerror, context: []const u8) void {
    std.debug.print("\n=== Runtime Error ===\n", .{});
    std.debug.print("Error: {s}\n", .{@errorName(err)});
    std.debug.print("Context: {s}\n", .{context});

    if (self.current_operation) |op| {
        const loc = op.location();
        std.debug.print("Location: line {d}, col {d}\n", .{ loc.start_line, loc.start_col });

        // Show the source line
        const line_start = self.getLineStart(loc.start_line);
        const line_end = self.getLineEnd(line_start);
        const line_text = self.source.buffer[line_start..line_end];
        std.debug.print("  {s}\n", .{line_text});

        // Show error indicator
        var spaces: usize = 0;
        while (spaces < loc.start_col - 1) : (spaces += 1) {
            std.debug.print(" ", .{});
        }
        std.debug.print("  ^\n", .{});
    }

    // Helpful suggestions based on error type
    if (err == error.FileNotFound) {
        std.debug.print("\nSuggestion: Check that the file path is correct and the file exists.\n", .{});
    } else if (err == error.AccessDenied or err == error.PermissionDenied) {
        std.debug.print("\nSuggestion: Check file permissions or try running with appropriate access.\n", .{});
    } else if (err == error.IsDir) {
        std.debug.print("\nSuggestion: The path points to a directory, not a file.\n", .{});
    } else if (err == error.NotDir) {
        std.debug.print("\nSuggestion: The path points to a file, not a directory.\n", .{});
    }

    std.debug.print("=====================\n\n", .{});
}

fn getLineStart(self: Interpreter, line: usize) usize {
    var current_line: usize = 1;
    var index: usize = 0;
    while (index < self.source.buffer.len and current_line < line) {
        if (self.source.buffer[index] == '\n') {
            current_line += 1;
        }
        index += 1;
    }
    return index;
}

fn getLineEnd(self: Interpreter, start: usize) usize {
    var index = start;
    while (index < self.source.buffer.len and self.source.buffer[index] != '\n') {
        index += 1;
    }
    return index;
}

pub fn init(allocator: mem.Allocator, source: io.Source) Interpreter {
    return .{
        .source = source,
        .allocator = allocator,
    };
}

/// Execute a Flow program - run all pipelines sequentially
pub fn execute(self: *Interpreter, program: flow.AST.Program) !void {
    for (program.pipelines) |pipeline| {
        if (self.executePipeline(pipeline)) |value| {
            defer value.deinit(self.allocator);
        } else |err| {
            // Error already reported in executePipeline
            return err;
        }
    }
}

/// Execute a single pipeline: evaluate source, apply operations
fn executePipeline(self: *Interpreter, pipeline: flow.AST.Pipeline) !core.Value {
    // Evaluate the source to get initial value
    var value = self.evaluateSource(pipeline.source) catch |err| {
        self.reportRuntimeError(err, "Failed to evaluate pipeline source");
        return Error.RuntimeError;
    };
    errdefer value.deinit(self.allocator);

    // Apply each operation in sequence
    for (pipeline.operations) |operation| {
        const new_value = self.applyOperation(value, operation) catch |err| {
            // Don't deinit value here, errdefer will handle it
            return err;
        };
        // Only deinit if we got a different value back
        // (some transforms like write return the same value)
        const is_same = switch (value) {
            .file => |f1| switch (new_value) {
                .file => |f2| f1.data.path.ptr == f2.data.path.ptr,
                else => false,
            },
            else => false,
        };
        if (!is_same) {
            value.deinit(self.allocator);
        }
        value = new_value;
    }

    return value;
}

/// Evaluate a source to produce a value
fn evaluateSource(self: *Interpreter, source: flow.AST.Source) anyerror!core.Value {
    return switch (source) {
        .literal => |lit| try self.evaluateLiteral(lit.token),
        .typed => |typed| blk: {
            const tag = try core.Type.parse(self.exchange(typed.type_name));
            const literal_value = try self.evaluateSource(typed.value.*);

            // For file system types, convert string to appropriate type
            switch (tag) {
                .file, .directory, .path => {
                    const string_data = switch (literal_value) {
                        .string => |s| s.data,
                        else => {
                            defer literal_value.deinit(self.allocator);
                            return Error.InvalidSource;
                        },
                    };
                    defer literal_value.deinit(self.allocator);
                    break :blk try core.Value.parse(self.allocator, tag, string_data);
                },
                // For primitive types, try to convert
                .int, .uint, .float, .string, .bool => {
                    if (tag == meta.activeTag(literal_value)) {
                        break :blk literal_value;
                    }
                    const transform: core.Transform = switch (tag) {
                        .int => .int,
                        .uint => .uint,
                        .float => .float,
                        .string => .string,
                        .bool => return Error.InvalidSource, // Can't convert to bool
                        else => unreachable,
                    };
                    defer literal_value.deinit(self.allocator);
                    break :blk try literal_value.applyTransform(self.allocator, transform, &.{});
                },
                else => return Error.InvalidSource,
            }
        },
        .pipeline_ref => {
            // TODO: Named pipeline references
            return Error.InvalidSource;
        },
        .pipeline => |pipe| try self.executePipeline(pipe.*),
    };
}

/// Evaluate a literal token to a value
fn evaluateLiteral(self: Interpreter, token: flow.Token) !core.Value {
    return switch (token.tag) {
        .int => blk: {
            const data = self.exchange(token);
            break :blk try core.Value.parse(self.allocator, .int, data);
        },
        .float => blk: {
            const data = self.exchange(token);
            break :blk try core.Value.parse(self.allocator, .float, data);
        },
        .string => blk: {
            const data = self.exchange(token);
            // Remove quotes from string literal
            const trimmed = if (data.len >= 2 and data[0] == '"' and data[data.len - 1] == '"')
                data[1 .. data.len - 1]
            else
                data;
            break :blk try core.Value.parse(self.allocator, .string, trimmed);
        },
        .identifier => blk: {
            const data = self.exchange(token);
            // Handle bool literals (true/false)
            if (mem.eql(u8, data, "true") or mem.eql(u8, data, "false")) {
                break :blk try core.Value.parse(self.allocator, .bool, data);
            }
            break :blk Error.InvalidSource;
        },
        else => Error.InvalidSource,
    };
}

/// Apply an operation (mutation or transform) to a value
fn applyOperation(self: *Interpreter, value: core.Value, operation: flow.AST.Operation) !core.Value {
    self.current_operation = operation;

    return switch (operation) {
        .mutation => |mut| self.applyMutation(value, mut) catch |err| {
            self.reportRuntimeError(err, "Failed to apply mutation");
            return Error.RuntimeError;
        },
        .transform => |trans| self.applyTransform(value, trans) catch |err| {
            self.reportRuntimeError(err, "Failed to apply transform");
            return Error.RuntimeError;
        },
    };
}

/// Apply a mutation to a value (in-place modification)
fn applyMutation(self: *Interpreter, value: core.Value, mutation: flow.AST.Operation.Mutation) !core.Value {
    // Evaluate mutation arguments
    var args = std.ArrayList(core.Value).empty;
    defer {
        for (args.items) |arg| arg.deinit(self.allocator);
        args.deinit(self.allocator);
    }

    for (mutation.args) |arg_source| {
        const arg_value = try self.evaluateSource(arg_source);
        try args.append(self.allocator, arg_value);
    }

    const name = self.exchange(mutation.name);
    const mutation_tag = try core.Mutation.parse(name);
    var mutable_value = value;
    try mutable_value.applyMutation(mutation_tag, args.items);
    return mutable_value;
}

/// Apply a transform to a value (creates new value)
fn applyTransform(self: *Interpreter, value: core.Value, transform_op: flow.AST.Operation.Transform) !core.Value {
    const name = self.exchange(transform_op.name);
    const transform_tag = try core.Transform.parse(name);

    // Special handling for print (doesn't create new value, just outputs)
    if (transform_tag == .print) {
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
        // Return void value
        return core.Value.init(.void, .{ .owned = false, .data = {} });
    }

    // Evaluate transform arguments
    var args = std.ArrayList(core.Value).empty;
    defer {
        for (args.items) |arg| arg.deinit(self.allocator);
        args.deinit(self.allocator);
    }

    for (transform_op.args) |arg_source| {
        const arg_value = try self.evaluateSource(arg_source);
        try args.append(self.allocator, arg_value);
    }

    // Build the transform
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
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const dest_path = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :copy_blk .{ .copy = dest_path };
        },
        .write => write_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const content = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :write_blk .{ .write = content };
        },
        .files => files_blk: {
            const pattern = if (args.items.len > 0) switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            } else null;
            break :files_blk .{ .files = pattern };
        },
        .uppercase => .uppercase,
        .lowercase => .lowercase,
        .split => split_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const delimiter = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :split_blk .{ .split = delimiter };
        },
        .join => join_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const delimiter = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :join_blk .{ .join = delimiter };
        },
        .contains => contains_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const substring = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :contains_blk .{ .contains = substring };
        },
        .starts_with => starts_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const prefix = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :starts_blk .{ .starts_with = prefix };
        },
        .ends_with => ends_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const suffix = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :ends_blk .{ .ends_with = suffix };
        },
        .equals => equals_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const compare_val = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :equals_blk .{ .equals = compare_val };
        },
        .not_equals => not_equals_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const compare_val = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :not_equals_blk .{ .not_equals = compare_val };
        },
        .greater => greater_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const compare_val = switch (args.items[0]) {
                .int => |i| i.data,
                else => return Error.TransformParametersInvalid,
            };
            break :greater_blk .{ .greater = compare_val };
        },
        .less => less_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const compare_val = switch (args.items[0]) {
                .int => |i| i.data,
                else => return Error.TransformParametersInvalid,
            };
            break :less_blk .{ .less = compare_val };
        },
        .greater_equals => greater_equals_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const compare_val = switch (args.items[0]) {
                .int => |i| i.data,
                else => return Error.TransformParametersInvalid,
            };
            break :greater_equals_blk .{ .greater_equals = compare_val };
        },
        .less_equals => less_equals_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const compare_val = switch (args.items[0]) {
                .int => |i| i.data,
                else => return Error.TransformParametersInvalid,
            };
            break :less_equals_blk .{ .less_equals = compare_val };
        },
        .not => .not,
        .@"and" => and_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const bool_val = switch (args.items[0]) {
                .bool => |b| b.data,
                else => return Error.TransformParametersInvalid,
            };
            break :and_blk .{ .@"and" = bool_val };
        },
        .@"or" => or_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const bool_val = switch (args.items[0]) {
                .bool => |b| b.data,
                else => return Error.TransformParametersInvalid,
            };
            break :or_blk .{ .@"or" = bool_val };
        },
        .assert => assert_blk: {
            if (args.items.len != 1) return Error.TransformParametersInvalid;
            const message = switch (args.items[0]) {
                .string => |s| s.data,
                else => return Error.TransformParametersInvalid,
            };
            break :assert_blk .{ .assert = message };
        },
        .length => .length,
        .first => .first,
        .last => .last,
        .filter, .map, .each => return Error.InvalidSource, // Not yet implemented
        else => return Error.InvalidSource,
    };

    return try value.applyTransform(self.allocator, transform, &.{});
}

pub fn exchange(self: Interpreter, token: flow.Token) []const u8 {
    return self.source.buffer[token.start..token.end];
}

test "execute simple pipeline" {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 42 -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);

    const interpreter = init(arena.allocator(), source);
    var program = try parser.parse();
    defer program.deinit();

    try interpreter.execute(program);
}