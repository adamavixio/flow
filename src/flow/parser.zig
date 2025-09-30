const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const io = lib.io;
const flow = lib.flow;

const Parser = @This();

token: flow.Token,
lexer: *flow.Lexer,
allocator: mem.Allocator,
errors: std.ArrayList(ParseError),
panic_mode: bool,

pub const ParseError = struct {
    message: []const u8,
    loc: flow.AST.SourceLocation,

    pub fn deinit(self: ParseError, allocator: mem.Allocator) void {
        allocator.free(self.message);
    }
};

pub const Error = error{
    InvalidToken,
    InvalidPipeline,
    EmptyStack,
    ParseFailed,
} || mem.Allocator.Error;

pub fn init(allocator: mem.Allocator, lexer: *flow.Lexer) Parser {
    return .{
        .token = lexer.next(),
        .lexer = lexer,
        .allocator = allocator,
        .errors = std.ArrayList(ParseError).empty,
        .panic_mode = false,
    };
}

pub fn deinit(self: *Parser) void {
    for (self.errors.items) |err| {
        err.deinit(self.allocator);
    }
    self.errors.deinit(self.allocator);
}

/// Add a parse error to the error list
fn addError(self: *Parser, loc: flow.AST.SourceLocation, comptime fmt: []const u8, args: anytype) !void {
    // Don't add multiple errors while in panic mode
    if (self.panic_mode) return;

    const message = try std.fmt.allocPrint(self.allocator, fmt, args);
    try self.errors.append(self.allocator, .{
        .message = message,
        .loc = loc,
    });
    self.panic_mode = true;
}

/// Synchronize parser at pipeline boundary after error
fn synchronize(self: *Parser) void {
    self.panic_mode = false;

    // Skip tokens until we find a synchronization point
    // For Flow, pipelines are typically on separate lines or at EOF
    while (self.token.tag != .end_of_frame) {
        // If we hit a potential pipeline start (identifier or literal), stop
        switch (self.token.tag) {
            .identifier, .int, .float, .string => return,
            else => self.advance(),
        }
    }
}

/// Parse a Flow program - returns a Program containing pipelines
pub fn parse(self: *Parser) !flow.AST.Program {
    var pipelines = std.ArrayList(flow.AST.Pipeline).empty;

    while (self.token.tag != .end_of_frame) {
        if (self.parsePipeline()) |pipeline| {
            try pipelines.append(self.allocator, pipeline);
        } else |err| {
            // On error, try to synchronize and continue
            if (err != Error.ParseFailed) {
                // Real allocation error or similar - abort
                return err;
            }
            self.synchronize();
        }
    }

    // If we collected any parse errors, report them and fail
    if (self.errors.items.len > 0) {
        std.debug.print("\n=== Parse Errors ===\n", .{});
        for (self.errors.items) |err| {
            std.debug.print("Error at line {d}, col {d}: {s}\n", .{
                err.loc.start_line,
                err.loc.start_col,
                err.message,
            });
        }
        std.debug.print("====================\n\n", .{});
        return Error.ParseFailed;
    }

    return flow.AST.Program{
        .pipelines = try pipelines.toOwnedSlice(self.allocator),
        .allocator = self.allocator,
    };
}

/// Parse a single pipeline: source -> operations
fn parsePipeline(self: *Parser) !flow.AST.Pipeline {
    const start_loc = flow.AST.SourceLocation.from_token(self.token);

    // Parse source
    const source = try self.parseSource();

    // Parse operations (if any)
    var operations = std.ArrayList(flow.AST.Operation).empty;
    while (self.token.tag == .pipe or self.token.tag == .arrow) {
        const op = try self.parseOperation();
        try operations.append(self.allocator, op);
    }

    const end_loc = if (operations.items.len > 0)
        operations.items[operations.items.len - 1].location()
    else
        source.location();

    return flow.AST.Pipeline{
        .source = source,
        .operations = try operations.toOwnedSlice(self.allocator),
        .split = null, // TODO: Parse <> splits
        .loc = flow.AST.SourceLocation.merge(start_loc, end_loc),
    };
}

/// Parse a source: literal or typed literal
fn parseSource(self: *Parser) !flow.AST.Source {
    // Check for typed source: "int : 42" or "file : "test.txt""
    if (self.token.tag == .identifier) {
        const type_name = self.token;
        const loc_start = flow.AST.SourceLocation.from_token(type_name);
        self.advance();

        if (self.token.tag != .colon) {
            try self.addError(
                flow.AST.SourceLocation.from_token(self.token),
                "Expected ':' after type name, got '{s}'",
                .{@tagName(self.token.tag)},
            );
            return Error.ParseFailed;
        }
        self.advance();

        // Parse the value (must be a literal)
        const value_token = self.token;
        if (value_token.tag != .int and value_token.tag != .float and value_token.tag != .string) {
            try self.addError(
                flow.AST.SourceLocation.from_token(value_token),
                "Expected literal value after ':', got '{s}'",
                .{@tagName(value_token.tag)},
            );
            return Error.ParseFailed;
        }
        self.advance();

        const value = try self.allocator.create(flow.AST.Source);
        value.* = flow.AST.Source{
            .literal = .{
                .token = value_token,
                .loc = flow.AST.SourceLocation.from_token(value_token),
            },
        };

        const loc_end = flow.AST.SourceLocation.from_token(value_token);
        return flow.AST.Source{
            .typed = .{
                .type_name = type_name,
                .value = value,
                .loc = flow.AST.SourceLocation.merge(loc_start, loc_end),
            },
        };
    }

    // Simple literal source: 42, "hello", 3.14
    if (self.token.tag == .int or self.token.tag == .float or self.token.tag == .string) {
        const literal = self.token;
        self.advance();
        return flow.AST.Source{
            .literal = .{
                .token = literal,
                .loc = flow.AST.SourceLocation.from_token(literal),
            },
        };
    }

    try self.addError(
        flow.AST.SourceLocation.from_token(self.token),
        "Expected source (type or literal), got '{s}'",
        .{@tagName(self.token.tag)},
    );
    return Error.ParseFailed;
}

/// Parse an operation: mutation (|) or transform (->)
fn parseOperation(self: *Parser) !flow.AST.Operation {
    const is_mutation = self.token.tag == .pipe;
    const op_loc = flow.AST.SourceLocation.from_token(self.token);
    self.advance();

    // Operation name must be an identifier
    if (self.token.tag != .identifier) {
        try self.addError(
            flow.AST.SourceLocation.from_token(self.token),
            "Expected operation name after '{s}', got '{s}'",
            .{ if (is_mutation) "|" else "->", @tagName(self.token.tag) },
        );
        return Error.ParseFailed;
    }

    const name = self.token;
    self.advance();

    // Parse arguments (literals only for now)
    var args = std.ArrayList(flow.AST.Source).empty;
    while (self.token.tag == .int or self.token.tag == .float or self.token.tag == .string) {
        const arg_token = self.token;
        self.advance();
        try args.append(self.allocator, flow.AST.Source{
            .literal = .{
                .token = arg_token,
                .loc = flow.AST.SourceLocation.from_token(arg_token),
            },
        });
    }

    const loc = flow.AST.SourceLocation.merge(op_loc, flow.AST.SourceLocation.from_token(name));

    if (is_mutation) {
        return flow.AST.Operation{
            .mutation = .{
                .name = name,
                .args = try args.toOwnedSlice(self.allocator),
                .loc = loc,
            },
        };
    } else {
        return flow.AST.Operation{
            .transform = .{
                .name = name,
                .args = try args.toOwnedSlice(self.allocator),
                .loc = loc,
            },
        };
    }
}

pub fn advance(self: *Parser) void {
    self.token = self.lexer.next();
}

test "parse simple pipeline" {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 42 -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = init(arena.allocator(), &lexer);
    var program = try parser.parse();
    defer program.deinit();

    try testing.expectEqual(@as(usize, 1), program.pipelines.len);
}

test "parse pipeline with operations" {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 5 | add 10 -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = init(arena.allocator(), &lexer);
    var program = try parser.parse();
    defer program.deinit();

    try testing.expectEqual(@as(usize, 1), program.pipelines.len);
    try testing.expectEqual(@as(usize, 2), program.pipelines[0].operations.len);
}