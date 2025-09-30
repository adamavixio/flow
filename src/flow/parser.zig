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

pub const Error = error{
    InvalidToken,
    InvalidPipeline,
    EmptyStack,
} || mem.Allocator.Error;

pub fn init(allocator: mem.Allocator, lexer: *flow.Lexer) Parser {
    return .{
        .token = lexer.next(),
        .lexer = lexer,
        .allocator = allocator,
    };
}

/// Parse a Flow program - returns a Program containing pipelines
pub fn parse(self: *Parser) !flow.AST.Program {
    var pipelines = std.ArrayList(flow.AST.Pipeline).empty;

    while (self.token.tag != .end_of_frame) {
        const pipeline = try self.parsePipeline();
        try pipelines.append(self.allocator, pipeline);
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
            return Error.InvalidToken;
        }
        self.advance();

        // Parse the value (must be a literal)
        const value_token = self.token;
        if (value_token.tag != .int and value_token.tag != .float and value_token.tag != .string) {
            return Error.InvalidToken;
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

    return Error.InvalidToken;
}

/// Parse an operation: mutation (|) or transform (->)
fn parseOperation(self: *Parser) !flow.AST.Operation {
    const is_mutation = self.token.tag == .pipe;
    const op_loc = flow.AST.SourceLocation.from_token(self.token);
    self.advance();

    // Operation name must be an identifier
    if (self.token.tag != .identifier) {
        return Error.InvalidToken;
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