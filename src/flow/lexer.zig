const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const flow = lib.flow;
const io = lib.io;

/// TRUE table-driven DFA lexer for Flow
/// Uses a 2D transition table [State][Char] -> Action
/// This is the proper implementation of a table-driven finite automaton
pub const Lexer = @This();

source: io.Source,
index: usize,
line: usize,
column: usize,
line_start: usize,

/// DFA states - matches original lexer exactly
pub const State = enum(u8) {
    start,
    identifier,
    zero,
    number,
    number_period,
    float,
    quote,
    quote_back_slash,
    quote_quote,
    plus,
    hyphen,
    hyphen_right_angle,
    asterisk,
    forward_slash,
    colon,
    pipe,
    left_angle,
    left_angle_right_angle,
    invalid,
    accept, // Used as next_state for .emit actions (never actually entered)
};

/// Actions the lexer can take
pub const Action = enum(u8) {
    consume,        // Consume char, stay in current state
    consume_goto,   // Consume char, go to next state
    emit,           // Emit token with tag
    error_invalid,  // Invalid character
};

/// Transition: what to do given (state, char)
pub const Transition = struct {
    action: Action,
    next_state: State,
    token_tag: flow.Token.Tag = .invalid,
};

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\n' or c == '\t' or c == '\r' or c == 0;
}

/// Build the actual transition table at comptime
fn buildTransitionTable() [@typeInfo(State).@"enum".fields.len][256]Transition {
    @setEvalBranchQuota(100000);
    var table: [@typeInfo(State).@"enum".fields.len][256]Transition = undefined;

    // Initialize all to invalid
    for (&table) |*state_row| {
        for (state_row) |*trans| {
            trans.* = .{
                .action = .error_invalid,
                .next_state = .invalid,
                .token_tag = .invalid,
            };
        }
    }

    const ws_and_eof = [_]u8{ ' ', '\n', '\t', '\r', 0 };

    // State.start transitions
    {
        const state_idx = @intFromEnum(State.start);

        // Whitespace: consume and stay
        for (ws_and_eof[0..4]) |c| {
            table[state_idx][c] = .{
                .action = .consume,
                .next_state = .start,
            };
        }

        // EOF
        table[state_idx][0] = .{
            .action = .emit,
            .next_state = .accept,
            .token_tag = .end_of_frame,
        };

        // Lowercase letters -> identifier
        for ('a'..('z' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume_goto,
                .next_state = .identifier,
            };
        }

        // Zero -> special state (must be followed by dot)
        table[state_idx]['0'] = .{
            .action = .consume_goto,
            .next_state = .zero,
        };

        // Digits 1-9 -> number
        for ('1'..('9' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume_goto,
                .next_state = .number,
            };
        }

        // Quote -> string
        table[state_idx]['"'] = .{
            .action = .consume_goto,
            .next_state = .quote,
        };

        // Operators
        table[state_idx]['+'] = .{
            .action = .consume_goto,
            .next_state = .plus,
        };
        table[state_idx]['-'] = .{
            .action = .consume_goto,
            .next_state = .hyphen,
        };
        table[state_idx]['*'] = .{
            .action = .consume_goto,
            .next_state = .asterisk,
        };
        table[state_idx]['/'] = .{
            .action = .consume_goto,
            .next_state = .forward_slash,
        };
        table[state_idx][':'] = .{
            .action = .consume_goto,
            .next_state = .colon,
        };
        table[state_idx]['|'] = .{
            .action = .consume_goto,
            .next_state = .pipe,
        };
        table[state_idx]['<'] = .{
            .action = .consume_goto,
            .next_state = .left_angle,
        };
    }

    // State.identifier transitions
    {
        const state_idx = @intFromEnum(State.identifier);

        // Continue on lowercase and digits
        for ('a'..('z' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume,
                .next_state = .identifier,
            };
        }
        for ('0'..('9' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume,
                .next_state = .identifier,
            };
        }

        // Emit on whitespace/EOF AND operators (don't consume delimiter)
        const delims = [_]u8{ ' ', '\n', '\t', '\r', 0, '+', '-', '*', '/', '|', ':', '<', '>' };
        for (delims) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .identifier,
            };
        }
    }

    // State.zero transitions (can be followed by '.' for float, or terminate as int)
    {
        const state_idx = @intFromEnum(State.zero);

        table[state_idx]['.'] = .{
            .action = .consume_goto,
            .next_state = .number_period,
        };

        // Allow zero to terminate as int on whitespace/EOF/operators
        const delims = [_]u8{ ' ', '\n', '\t', '\r', 0, '+', '-', '*', '/', '|', ':', '<', '>' };
        for (delims) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .int,
            };
        }
    }

    // State.number transitions
    {
        const state_idx = @intFromEnum(State.number);

        // Continue on digits
        for ('0'..('9' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume,
                .next_state = .number,
            };
        }

        // Dot -> float
        table[state_idx]['.'] = .{
            .action = .consume_goto,
            .next_state = .number_period,
        };

        // Emit int on whitespace/EOF AND operators
        const delims = [_]u8{ ' ', '\n', '\t', '\r', 0, '+', '-', '*', '/', '|', ':', '<', '>' };
        for (delims) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .int,
            };
        }
    }

    // State.number_period transitions (after '.')
    {
        const state_idx = @intFromEnum(State.number_period);

        // Must have digit after period
        for ('0'..('9' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume_goto,
                .next_state = .float,
            };
        }

        // Everything else invalid (no trailing dots)
    }

    // State.float transitions
    {
        const state_idx = @intFromEnum(State.float);

        // Continue on digits
        for ('0'..('9' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume,
                .next_state = .float,
            };
        }

        // Emit float on whitespace/EOF AND operators
        const delims = [_]u8{ ' ', '\n', '\t', '\r', 0, '+', '-', '*', '/', '|', ':', '<', '>' };
        for (delims) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .float,
            };
        }
    }

    // State.quote transitions (inside string)
    {
        const state_idx = @intFromEnum(State.quote);

        // Closing quote
        table[state_idx]['"'] = .{
            .action = .consume_goto,
            .next_state = .quote_quote,
        };

        // Backslash -> escape
        table[state_idx]['\\'] = .{
            .action = .consume_goto,
            .next_state = .quote_back_slash,
        };

        // Any other char: consume and stay (except null)
        for (1..256) |c_usize| {
            const c: u8 = @intCast(c_usize);
            if (c != '"' and c != '\\') {
                table[state_idx][c] = .{
                    .action = .consume,
                    .next_state = .quote,
                };
            }
        }

        // Null in string is invalid
        table[state_idx][0] = .{
            .action = .error_invalid,
            .next_state = .invalid,
        };
    }

    // State.quote_back_slash transitions (after \ in string)
    {
        const state_idx = @intFromEnum(State.quote_back_slash);

        // Valid escapes: \\ \n \t \r \"
        const valid_escapes = [_]u8{ '\\', 'n', 't', 'r', '"' };
        for (valid_escapes) |c| {
            table[state_idx][c] = .{
                .action = .consume_goto,
                .next_state = .quote,
            };
        }

        // Invalid escape
        // (already set to invalid)
    }

    // State.quote_quote transitions (after closing ")
    {
        const state_idx = @intFromEnum(State.quote_quote);

        // According to original lexer: must be followed by specific chars
        // ws, +, -, *, /, |, :, <, >, EOF (NUL 0, not digit '0')
        const follow_set = [_]u8{ ' ', '\n', '\t', '\r', 0, '+', '-', '*', '/', '|', ':', '<', '>' };
        for (follow_set) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .string,
            };
        }

        // Everything else invalid
    }

    // State.plus transitions
    {
        const state_idx = @intFromEnum(State.plus);

        for (ws_and_eof) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .plus,
            };
        }
    }

    // State.hyphen transitions (can become arrow or number)
    {
        const state_idx = @intFromEnum(State.hyphen);

        // Arrow
        table[state_idx]['>'] = .{
            .action = .consume_goto,
            .next_state = .hyphen_right_angle,
        };

        // Negative zero - goes to zero state (which now allows termination as int)
        table[state_idx]['0'] = .{
            .action = .consume_goto,
            .next_state = .zero,
        };

        // Negative number
        for ('1'..('9' + 1)) |c| {
            table[state_idx][c] = .{
                .action = .consume_goto,
                .next_state = .number,
            };
        }

        // Just minus
        for (ws_and_eof) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .minus,
            };
        }
    }

    // State.hyphen_right_angle transitions (->)
    {
        const state_idx = @intFromEnum(State.hyphen_right_angle);

        for (ws_and_eof) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .arrow,
            };
        }
    }

    // State.asterisk, forward_slash, colon, pipe transitions
    for ([_]struct { state: State, tag: flow.Token.Tag }{
        .{ .state = .asterisk, .tag = .multiply },
        .{ .state = .forward_slash, .tag = .divide },
        .{ .state = .colon, .tag = .colon },
        .{ .state = .pipe, .tag = .pipe },
    }) |info| {
        const state_idx = @intFromEnum(info.state);
        for (ws_and_eof) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = info.tag,
            };
        }
    }

    // State.left_angle transitions
    {
        const state_idx = @intFromEnum(State.left_angle);

        // <>
        table[state_idx]['>'] = .{
            .action = .consume_goto,
            .next_state = .left_angle_right_angle,
        };

        // Single < is invalid (no other valid follow)
    }

    // State.left_angle_right_angle transitions (<>)
    {
        const state_idx = @intFromEnum(State.left_angle_right_angle);

        for (ws_and_eof) |c| {
            table[state_idx][c] = .{
                .action = .emit,
                .next_state = .accept,
                .token_tag = .chain,
            };
        }
    }

    return table;
}

const TRANSITION_TABLE = buildTransitionTable();

pub fn init(source: io.Source) Lexer {
    return .{
        .source = source,
        .index = 0,
        .line = 1,
        .column = 1,
        .line_start = 0,
    };
}

fn advance(self: *Lexer) void {
    if (self.index >= self.source.buffer.len) return;

    const c = self.source.buffer[self.index];
    self.index += 1;

    if (c == '\n') {
        self.line += 1;
        self.column = 1;
        self.line_start = self.index;
    } else {
        self.column += 1;
    }
}

fn peek(self: *const Lexer) u8 {
    if (self.index >= self.source.buffer.len) return 0;
    return self.source.buffer[self.index];
}

/// TRUE table-driven tokenization
pub fn next(self: *Lexer) flow.Token {
    var start_index = self.index;
    var start_line = self.line;
    var start_column = self.column;

    var state = State.start;

    while (true) {
        const c = self.peek();
        const state_idx = @intFromEnum(state);
        const transition = TRANSITION_TABLE[state_idx][c];

        switch (transition.action) {
            .consume => {
                self.advance();
                // When skipping whitespace in start state, update start position
                if (state == State.start) {
                    start_index = self.index;
                    start_line = self.line;
                    start_column = self.column;
                }
                // Stay in same state (transition.next_state should equal state)
            },
            .consume_goto => {
                self.advance();
                state = transition.next_state;
            },
            .emit => {
                return flow.Token{
                    .tag = transition.token_tag,
                    .start = start_index,
                    .end = self.index,
                    .line = start_line,
                    .column = start_column,
                };
            },
            .error_invalid => {
                // Consume until whitespace for invalid token
                while (!isWhitespace(self.peek())) {
                    self.advance();
                }
                return flow.Token{
                    .tag = .invalid,
                    .start = start_index,
                    .end = self.index,
                    .line = start_line,
                    .column = start_column,
                };
            },
        }

        // Safety: prevent infinite loop
        if (self.index > self.source.buffer.len) {
            return flow.Token{
                .tag = .invalid,
                .start = start_index,
                .end = self.index,
                .line = start_line,
                .column = start_column,
            };
        }
    }
}

// Tests will be added after verifying table correctness
test "table driven lexer - basic tokens" {
    var source = try io.Source.initString(testing.allocator, "int : 42");
    defer source.deinit(testing.allocator);

    var lexer = Lexer.init(source);

    const t1 = lexer.next();
    try testing.expectEqual(flow.Token.Tag.identifier, t1.tag);

    const t2 = lexer.next();
    try testing.expectEqual(flow.Token.Tag.colon, t2.tag);

    const t3 = lexer.next();
    try testing.expectEqual(flow.Token.Tag.int, t3.tag);
}

test "table driven lexer - negative int" {
    var source = try io.Source.initString(testing.allocator, "-42");
    defer source.deinit(testing.allocator);

    var lexer = Lexer.init(source);

    const t1 = lexer.next();
    try testing.expectEqual(flow.Token.Tag.int, t1.tag);
    try testing.expectEqualStrings("-42", source.buffer[t1.start..t1.end]);
}

test "zero rules" {
    var s1 = try io.Source.initString(testing.allocator, "0 01 0.5 0.");
    defer s1.deinit(testing.allocator);
    var lx = Lexer.init(s1);
    try testing.expectEqual(flow.Token.Tag.int, lx.next().tag); // 0
    try testing.expectEqual(flow.Token.Tag.invalid, lx.next().tag); // 01
    try testing.expectEqual(flow.Token.Tag.float, lx.next().tag); // 0.5
    try testing.expectEqual(flow.Token.Tag.invalid, lx.next().tag); // 0.
}

test "minus with zero" {
    var s = try io.Source.initString(testing.allocator, "-0 -01 -0.5");
    defer s.deinit(testing.allocator);
    var lx = Lexer.init(s);
    try testing.expectEqual(flow.Token.Tag.int, lx.next().tag); // -0
    try testing.expectEqual(flow.Token.Tag.invalid, lx.next().tag); // -01
    try testing.expectEqual(flow.Token.Tag.float, lx.next().tag); // -0.5
}