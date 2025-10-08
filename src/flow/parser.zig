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
prev_token: flow.Token,
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
    const first_token = lexer.next();
    return .{
        .token = first_token,
        .prev_token = first_token, // Initialize to first token
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

/// Get source text for a token
fn tokenSource(self: *Parser, token: flow.Token) []const u8 {
    return self.lexer.source.buffer[token.start..token.end];
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
    // Check for typed source: "int : 42" or "array<int> : [1,2,3]"
    if (self.token.tag == .identifier) {
        const type_name = self.token;
        const loc_start = flow.AST.SourceLocation.from_token(type_name);
        self.advance();

        // Check for generic type parameters: array<int>, map<string, int>
        var type_params = std.ArrayList(flow.Token).empty;
        errdefer type_params.deinit(self.allocator);

        if (self.token.tag == .left_angle) {
            self.advance(); // consume <

            // Parse comma-separated type parameters
            while (true) {
                if (self.token.tag != .identifier) {
                    try self.addError(
                        flow.AST.SourceLocation.from_token(self.token),
                        "Expected type parameter, got '{s}'",
                        .{@tagName(self.token.tag)},
                    );
                    return Error.ParseFailed;
                }
                try type_params.append(self.allocator, self.token);
                self.advance();

                if (self.token.tag == .right_angle) {
                    self.advance(); // consume >
                    break;
                } else if (self.token.tag == .comma) {
                    self.advance(); // consume comma and continue
                } else {
                    try self.addError(
                        flow.AST.SourceLocation.from_token(self.token),
                        "Expected ',' or '>' in type parameters, got '{s}'",
                        .{@tagName(self.token.tag)},
                    );
                    return Error.ParseFailed;
                }
            }
        }

        if (self.token.tag != .colon) {
            try self.addError(
                flow.AST.SourceLocation.from_token(self.token),
                "Expected ':' after type name, got '{s}'",
                .{@tagName(self.token.tag)},
            );
            return Error.ParseFailed;
        }
        self.advance();

        // Check if this is an array literal: array<int> : [1, 2, 3]
        const type_name_str = self.tokenSource(type_name);
        if (std.mem.eql(u8, type_name_str, "array")) {
            if (type_params.items.len != 1) {
                try self.addError(
                    loc_start,
                    "Array type requires exactly one type parameter, got {d}",
                    .{type_params.items.len},
                );
                return Error.ParseFailed;
            }

            if (self.token.tag != .left_bracket) {
                try self.addError(
                    flow.AST.SourceLocation.from_token(self.token),
                    "Expected '[' for array literal, got '{s}'",
                    .{@tagName(self.token.tag)},
                );
                return Error.ParseFailed;
            }
            return try self.parseArrayLiteral(type_params.items, loc_start);
        }

        // Check if this is a map literal: map<string, int> : {"key": 42}
        if (std.mem.eql(u8, type_name_str, "map")) {
            if (type_params.items.len != 2) {
                try self.addError(
                    loc_start,
                    "Map type requires exactly two type parameters, got {d}",
                    .{type_params.items.len},
                );
                return Error.ParseFailed;
            }

            if (self.token.tag != .left_brace) {
                try self.addError(
                    flow.AST.SourceLocation.from_token(self.token),
                    "Expected open brace for map literal, got '{s}'",
                    .{@tagName(self.token.tag)},
                );
                return Error.ParseFailed;
            }
            return try self.parseMapLiteral(type_params.items, loc_start);
        }

        // Regular typed literal: int : 42, file : "test.txt"
        defer type_params.deinit(self.allocator);

        const value_token = self.token;
        const is_bool_literal = value_token.tag == .identifier and
            (std.mem.eql(u8, self.tokenSource(value_token), "true") or
             std.mem.eql(u8, self.tokenSource(value_token), "false"));

        if (value_token.tag != .int and value_token.tag != .float and
            value_token.tag != .string and !is_bool_literal) {
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

/// Parse array literal: [1, 2, 3]
fn parseArrayLiteral(self: *Parser, element_type: []flow.Token, loc_start: flow.AST.SourceLocation) !flow.AST.Source {
    self.advance(); // consume [

    var elements = std.ArrayList(flow.AST.Source).empty;
    errdefer {
        for (elements.items) |*elem| elem.deinit(self.allocator);
        elements.deinit(self.allocator);
    }

    // Parse comma-separated elements
    while (self.token.tag != .right_bracket) {
        if (self.token.tag == .end_of_frame) {
            try self.addError(
                flow.AST.SourceLocation.from_token(self.token),
                "Unexpected end of input, expected ']'",
                .{},
            );
            return Error.ParseFailed;
        }

        // Parse element (can be any literal)
        const elem = try self.parseLiteralValue();
        try elements.append(self.allocator, elem);

        if (self.token.tag == .comma) {
            self.advance(); // consume comma
            // Allow trailing comma
            if (self.token.tag == .right_bracket) {
                break;
            }
        } else if (self.token.tag != .right_bracket) {
            try self.addError(
                flow.AST.SourceLocation.from_token(self.token),
                "Expected ',' or ']' in array literal, got '{s}'",
                .{@tagName(self.token.tag)},
            );
            return Error.ParseFailed;
        }
    }

    const loc_end = flow.AST.SourceLocation.from_token(self.token);
    self.advance(); // consume ]

    // Clone type_params for AST (it will be freed by caller)
    const element_type_copy = try self.allocator.alloc(flow.Token, element_type.len);
    @memcpy(element_type_copy, element_type);

    return flow.AST.Source{
        .array = .{
            .element_type = element_type_copy,
            .elements = try elements.toOwnedSlice(self.allocator),
            .loc = flow.AST.SourceLocation.merge(loc_start, loc_end),
        },
    };
}

/// Parse map literal: {"key": value, ...}
fn parseMapLiteral(self: *Parser, type_params: []flow.Token, loc_start: flow.AST.SourceLocation) !flow.AST.Source {
    self.advance(); // consume {

    var pairs = std.ArrayList(flow.AST.MapPair).empty;
    errdefer {
        for (pairs.items) |*pair| pair.deinit(self.allocator);
        pairs.deinit(self.allocator);
    }

    // Parse comma-separated key:value pairs
    while (self.token.tag != .right_brace) {
        if (self.token.tag == .end_of_frame) {
            try self.addError(
                flow.AST.SourceLocation.from_token(self.token),
                "Unexpected end of input, expected close brace",
                .{},
            );
            return Error.ParseFailed;
        }

        const pair_loc_start = flow.AST.SourceLocation.from_token(self.token);

        // Parse key
        const key = try self.parseLiteralValue();

        // Expect colon
        if (self.token.tag != .colon) {
            try self.addError(
                flow.AST.SourceLocation.from_token(self.token),
                "Expected ':' after map key, got '{s}'",
                .{@tagName(self.token.tag)},
            );
            return Error.ParseFailed;
        }
        self.advance();

        // Parse value
        const value = try self.parseLiteralValue();

        const pair_loc_end = flow.AST.SourceLocation.from_token(self.prev_token);
        try pairs.append(self.allocator, flow.AST.MapPair{
            .key = key,
            .value = value,
            .loc = flow.AST.SourceLocation.merge(pair_loc_start, pair_loc_end),
        });

        if (self.token.tag == .comma) {
            self.advance(); // consume comma
            // Allow trailing comma
            if (self.token.tag == .right_brace) {
                break;
            }
        } else if (self.token.tag != .right_brace) {
            try self.addError(
                flow.AST.SourceLocation.from_token(self.token),
                "Expected comma or close brace in map literal, got '{s}'",
                .{@tagName(self.token.tag)},
            );
            return Error.ParseFailed;
        }
    }

    const loc_end = flow.AST.SourceLocation.from_token(self.token);
    self.advance(); // consume }

    // Clone type_params for AST
    const key_type = try self.allocator.alloc(flow.Token, 1);
    const value_type = try self.allocator.alloc(flow.Token, 1);
    key_type[0] = type_params[0];
    value_type[0] = type_params[1];

    return flow.AST.Source{
        .map = .{
            .key_type = key_type,
            .value_type = value_type,
            .pairs = try pairs.toOwnedSlice(self.allocator),
            .loc = flow.AST.SourceLocation.merge(loc_start, loc_end),
        },
    };
}

/// Parse a literal value (int, float, string, bool) - helper for array/map parsing
fn parseLiteralValue(self: *Parser) !flow.AST.Source {
    const value_token = self.token;
    const is_bool_literal = value_token.tag == .identifier and
        (std.mem.eql(u8, self.tokenSource(value_token), "true") or
         std.mem.eql(u8, self.tokenSource(value_token), "false"));

    if (value_token.tag != .int and value_token.tag != .float and
        value_token.tag != .string and !is_bool_literal) {
        try self.addError(
            flow.AST.SourceLocation.from_token(value_token),
            "Expected literal value, got '{s}'",
            .{@tagName(value_token.tag)},
        );
        return Error.ParseFailed;
    }
    self.advance();

    return flow.AST.Source{
        .literal = .{
            .token = value_token,
            .loc = flow.AST.SourceLocation.from_token(value_token),
        },
    };
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
    self.prev_token = self.token;
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