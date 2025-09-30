const std = @import("std");
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const flow = lib.flow;
const io = lib.io;

/// Semantic Analyzer for Flow programs
/// Performs type inference and validation through dataflow analysis
pub const Analyzer = @This();

allocator: mem.Allocator,
source: io.Source,
errors: std.ArrayList(AnalysisError),

pub const AnalysisError = struct {
    message: []const u8,
    loc: flow.AST.SourceLocation,

    pub fn format(
        self: AnalysisError,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Error at line {d}, col {d}: {s}", .{
            self.loc.start_line,
            self.loc.start_col,
            self.message,
        });
    }
};

pub const Error = error{
    AnalysisFailed,
    UnknownType,
    TypeMismatch,
    UnknownOperation,
    InvalidOperationForType,
} || mem.Allocator.Error;

pub fn init(allocator: mem.Allocator, source: io.Source) Analyzer {
    return .{
        .allocator = allocator,
        .source = source,
        .errors = std.ArrayList(AnalysisError).empty,
    };
}

pub fn deinit(self: *Analyzer) void {
    for (self.errors.items) |err| {
        self.allocator.free(err.message);
    }
    self.errors.deinit(self.allocator);
}

/// Analyze a Flow program and fill in type information
pub fn analyze(self: *Analyzer, program: *flow.AST.Program) !void {
    // Analyze each pipeline
    for (program.pipelines) |*pipeline| {
        self.analyzePipeline(pipeline) catch |err| {
            // Continue analyzing other pipelines even if one fails
            if (err != Error.AnalysisFailed) return err;
        };
    }

    // If we collected any errors, report them and fail
    if (self.errors.items.len > 0) {
        std.debug.print("\n=== Semantic Analysis Errors ===\n", .{});
        for (self.errors.items) |err| {
            std.debug.print("Error at line {d}, col {d}: {s}\n", .{
                err.loc.start_line,
                err.loc.start_col,
                err.message,
            });
            // Show source line
            const line_start = self.getLineStart(err.loc.start_line);
            const line_end = self.getLineEnd(line_start);
            const line_text = self.source.buffer[line_start..line_end];
            std.debug.print("  {s}\n", .{line_text});
            // Show error indicator
            var spaces: usize = 0;
            while (spaces < err.loc.start_col - 1) : (spaces += 1) {
                std.debug.print(" ", .{});
            }
            std.debug.print("  ^\n", .{});
        }
        std.debug.print("=================================\n\n", .{});
        return Error.AnalysisFailed;
    }
}

/// Analyze a single pipeline and infer its type
fn analyzePipeline(self: *Analyzer, pipeline: *flow.AST.Pipeline) !void {
    // Infer type of source
    const source_type = try self.inferSourceType(pipeline.source);

    // Flow the type through operations
    var current_type = source_type;
    for (pipeline.operations) |operation| {
        current_type = self.inferOperationType(current_type, operation) catch |err| {
            if (err == Error.AnalysisFailed) {
                return err; // Already added to errors
            }
            return err;
        };
    }

    // Store the final type in the pipeline
    pipeline.flow_type = current_type;
}

/// Infer the type of a source
fn inferSourceType(self: *Analyzer, source: flow.AST.Source) Error!core.Type {
    return switch (source) {
        .literal => |lit| self.inferLiteralType(lit.token),
        .typed => |typed| blk: {
            const type_name = self.exchange(typed.type_name);
            const tag = core.Type.parse(type_name) catch {
                try self.addError(typed.loc, "Unknown type: {s}", .{type_name});
                return Error.AnalysisFailed;
            };
            // Validate that the value is compatible with the type
            const value_type = try self.inferSourceType(typed.value.*);

            // Check if the value can be coerced to the target type
            const compatible = switch (tag) {
                .file, .directory, .path => value_type == .string,
                .int => value_type == .int or value_type == .uint,
                .uint => value_type == .uint or value_type == .int,
                .float => value_type == .float or value_type == .int or value_type == .uint,
                .string => value_type == .string or value_type == .int or value_type == .uint or value_type == .float,
                else => value_type == tag,
            };

            if (!compatible) {
                try self.addError(typed.loc, "Cannot convert {s} to {s}", .{ @tagName(value_type), type_name });
                return Error.AnalysisFailed;
            }

            break :blk tag;
        },
        .pipeline_ref => |ref| {
            const name = self.exchange(ref.name);
            try self.addError(ref.loc, "Pipeline references not yet implemented: {s}", .{name});
            return Error.AnalysisFailed;
        },
        .pipeline => |pipe| blk: {
            try self.analyzePipeline(pipe);
            break :blk pipe.flow_type orelse .void;
        },
    };
}

/// Infer the type of a literal token
fn inferLiteralType(self: *Analyzer, token: flow.Token) Error!core.Type {
    return switch (token.tag) {
        .int => .int,
        .float => .float,
        .string => .string,
        else => {
            const text = self.exchange(token);
            try self.addError(
                flow.AST.SourceLocation.from_token(token),
                "Invalid literal: {s}",
                .{text},
            );
            return Error.AnalysisFailed;
        },
    };
}

/// Infer the result type of applying an operation to a value of a given type
fn inferOperationType(self: *Analyzer, input_type: core.Type, operation: flow.AST.Operation) Error!core.Type {
    return switch (operation) {
        .mutation => |mut| try self.inferMutationType(input_type, mut),
        .transform => |trans| try self.inferTransformType(input_type, trans),
    };
}

/// Infer the result type of a mutation (mutations return same type)
fn inferMutationType(self: *Analyzer, input_type: core.Type, mutation: flow.AST.Operation.Mutation) Error!core.Type {
    const name = self.exchange(mutation.name);
    const mutation_tag = core.Mutation.parse(name) catch {
        try self.addError(mutation.loc, "Unknown mutation: {s}", .{name});
        return Error.AnalysisFailed;
    };

    // Check if mutation is valid for this type
    const valid = switch (mutation_tag) {
        .add, .sub, .mul, .div => switch (input_type) {
            .int, .uint, .float => true,
            else => false,
        },
    };

    if (!valid) {
        try self.addError(
            mutation.loc,
            "Mutation '{s}' cannot be applied to type '{s}'",
            .{ name, @tagName(input_type) },
        );
        return Error.AnalysisFailed;
    }

    // Mutations return the same type
    return input_type;
}

/// Infer the result type of a transform
fn inferTransformType(self: *Analyzer, input_type: core.Type, transform: flow.AST.Operation.Transform) Error!core.Type {
    const name = self.exchange(transform.name);
    const transform_tag = core.Transform.parse(name) catch {
        try self.addError(transform.loc, "Unknown transform: {s}", .{name});
        return Error.AnalysisFailed;
    };

    // Type inference rules for each transform
    const result_type: core.Type = switch (transform_tag) {
        // Type conversions
        .int => switch (input_type) {
            .uint => .int,
            else => {
                try self.addError(transform.loc, "Cannot convert {s} to int", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .uint => switch (input_type) {
            .int => .uint,
            else => {
                try self.addError(transform.loc, "Cannot convert {s} to uint", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .float => switch (input_type) {
            .int, .uint => .float,
            else => {
                try self.addError(transform.loc, "Cannot convert {s} to float", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .string => switch (input_type) {
            .int, .uint, .float => .string,
            else => {
                try self.addError(transform.loc, "Cannot convert {s} to string", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .print => .void,

        // File operations
        .content => switch (input_type) {
            .file => .string,
            else => {
                try self.addError(transform.loc, "Transform 'content' requires file type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .exists => switch (input_type) {
            .file, .directory => .uint,
            else => {
                try self.addError(transform.loc, "Transform 'exists' requires file or directory type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .size => switch (input_type) {
            .file => .uint,
            else => {
                try self.addError(transform.loc, "Transform 'size' requires file type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .extension, .basename, .dirname => switch (input_type) {
            .file, .path => .string,
            else => {
                try self.addError(transform.loc, "Transform '{s}' requires file or path type, got {s}", .{ name, @tagName(input_type) });
                return Error.AnalysisFailed;
            },
        },
        .copy => switch (input_type) {
            .file => .file,
            else => {
                try self.addError(transform.loc, "Transform 'copy' requires file type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .write => switch (input_type) {
            .file => .file,
            else => {
                try self.addError(transform.loc, "Transform 'write' requires file type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .files => switch (input_type) {
            .directory => .array,
            else => {
                try self.addError(transform.loc, "Transform 'files' requires directory type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },

        // String operations
        .uppercase, .lowercase => switch (input_type) {
            .string => .string,
            else => {
                try self.addError(transform.loc, "Transform '{s}' requires string type, got {s}", .{ name, @tagName(input_type) });
                return Error.AnalysisFailed;
            },
        },
        .split => switch (input_type) {
            .string => .array,
            else => {
                try self.addError(transform.loc, "Transform 'split' requires string type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .join => switch (input_type) {
            .array => .string,
            else => {
                try self.addError(transform.loc, "Transform 'join' requires array type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },

        // Array operations
        .length => switch (input_type) {
            .array => .uint,
            else => {
                try self.addError(transform.loc, "Transform 'length' requires array type, got {s}", .{@tagName(input_type)});
                return Error.AnalysisFailed;
            },
        },
        .first, .last => switch (input_type) {
            .array => .file, // For now, arrays contain files (could be generalized)
            else => {
                try self.addError(transform.loc, "Transform '{s}' requires array type, got {s}", .{ name, @tagName(input_type) });
                return Error.AnalysisFailed;
            },
        },
        .filter, .map, .each => switch (input_type) {
            .array => .array,
            else => {
                try self.addError(transform.loc, "Transform '{s}' requires array type, got {s}", .{ name, @tagName(input_type) });
                return Error.AnalysisFailed;
            },
        },
    };

    return result_type;
}

/// Add an error to the error list
fn addError(self: *Analyzer, loc: flow.AST.SourceLocation, comptime fmt: []const u8, args: anytype) !void {
    const message = try std.fmt.allocPrint(self.allocator, fmt, args);
    try self.errors.append(self.allocator, .{
        .message = message,
        .loc = loc,
    });
}

/// Get the start index of a line
fn getLineStart(self: Analyzer, line: usize) usize {
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

/// Get the end index of a line (not including newline)
fn getLineEnd(self: Analyzer, start: usize) usize {
    var index = start;
    while (index < self.source.buffer.len and self.source.buffer[index] != '\n') {
        index += 1;
    }
    return index;
}

/// Get the text for a token
fn exchange(self: Analyzer, token: flow.Token) []const u8 {
    return self.source.buffer[token.start..token.end];
}

test "analyzer - simple pipeline" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 42 -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);
    var program = try parser.parse();
    defer program.deinit();

    var analyzer = init(arena.allocator(), source);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
    try testing.expect(program.pipelines[0].flow_type != null);
    try testing.expectEqual(core.Type.void, program.pipelines[0].flow_type.?);
}

test "analyzer - type mismatch" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 42 -> content";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);
    var program = try parser.parse();
    defer program.deinit();

    var analyzer = init(arena.allocator(), source);
    defer analyzer.deinit();

    const result = analyzer.analyze(&program);
    try testing.expectError(Error.AnalysisFailed, result);
    try testing.expect(analyzer.errors.items.len > 0);
}

test "analyzer - file operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "file : \"test.txt\" -> content -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);
    var program = try parser.parse();
    defer program.deinit();

    var analyzer = init(arena.allocator(), source);
    defer analyzer.deinit();

    try analyzer.analyze(&program);
    try testing.expectEqual(@as(usize, 0), analyzer.errors.items.len);
}