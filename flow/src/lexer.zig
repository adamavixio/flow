const std = @import("std");

const Lexer = @This();
const Token = @import("token.zig");

index: usize,
buffer: [:0]const u8,

pub const State = enum {
    start,
    identifier,
    zero,
    number,
    number_period,
    float,
    quote,
    quote_back_slash,
    quote_quote,
    colon,
    pipe,
    hyphen,
    hyphen_right_angle,
    left_angle,
    left_angle_right_angle,
    invalid,
};

pub fn init(buffer: [:0]const u8) Lexer {
    return .{
        .index = 0,
        .buffer = buffer,
    };
}

pub fn next(self: *Lexer) Token {
    var state = State.start;
    var token = Token{
        .kind = undefined,
        .location = .{ .left = self.index, .right = undefined },
    };

    while (true) {
        switch (state) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    token.kind = .special_end_of_frame;
                    break;
                },
                'a'...'z' => {
                    self.index += 1;
                    state = .identifier;
                },
                '0' => {
                    self.index += 1;
                    state = .zero;
                },
                '1'...'9' => {
                    self.index += 1;
                    state = .number;
                },
                '\'' => {
                    self.index += 1;
                    state = .quote;
                },
                ':' => {
                    self.index += 1;
                    state = .colon;
                },
                '|' => {
                    self.index += 1;
                    state = .pipe;
                },
                '-' => {
                    self.index += 1;
                    state = .hyphen;
                },
                '<' => {
                    self.index += 1;
                    state = .left_angle;
                },
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    token.location.left = self.index;
                },
                else => {
                    state = .invalid;
                },
            },
            .identifier => switch (self.buffer[self.index]) {
                'a'...'z' => {
                    self.index += 1;
                },
                '0'...'9' => {
                    self.index += 1;
                },
                0, ' ', '\n', '\t', '\r' => {
                    const string = self.buffer[token.location.left..self.index];
                    token.kind = Token.keywords.get(string) orelse .identifier;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .zero => switch (self.buffer[self.index]) {
                '.' => {
                    self.index += 1;
                    state = .number_period;
                },
                else => {
                    state = .invalid;
                },
            },
            .number => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    state = .number;
                },
                '.' => {
                    self.index += 1;
                    state = .number_period;
                },
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .literal_int;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .number_period => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    state = .float;
                },
                else => {
                    state = .invalid;
                },
            },
            .float => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    state = .float;
                },
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .literal_float;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .quote => switch (self.buffer[self.index]) {
                '\\' => {
                    self.index += 1;
                    state = .quote_back_slash;
                },
                '\'' => {
                    self.index += 1;
                    state = .quote_quote;
                },
                0 => {
                    state = .invalid;
                },
                else => {
                    self.index += 1;
                },
            },
            .quote_back_slash => switch (self.buffer[self.index]) {
                '\\', 'n', 't', 'r', '\'' => {
                    self.index += 1;
                    state = .quote;
                },
                else => {
                    state = .invalid;
                },
            },
            .quote_quote => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .literal_string;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .colon => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .symbol_colon;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .pipe => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .operator_pipe;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .left_angle => switch (self.buffer[self.index]) {
                '>' => {
                    self.index += 1;
                    state = .left_angle_right_angle;
                },
                else => {
                    state = .invalid;
                },
            },
            .left_angle_right_angle => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .operator_chain;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .hyphen => switch (self.buffer[self.index]) {
                '>' => {
                    self.index += 1;
                    state = .hyphen_right_angle;
                },
                else => {
                    state = .invalid;
                },
            },
            .hyphen_right_angle => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .operator_arrow;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .invalid => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.kind = .special_invalid;
                    break;
                },
                else => {
                    self.index += 1;
                },
            },
        }
    }

    token.location.right = self.index;
    return token;
}

pub fn tokenize(self: *Lexer, allocator: std.mem.Allocator) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();

    while (true) {
        const token = self.next();
        try tokens.append(token);

        if (token.kind.isSpecial()) {
            break;
        }
    }

    return tokens;
}

test "keyword" {
    // Identifier tests
    {
        const keywords = comptime blk: {
            var keywords: [Token.keywords.keys().len][:0]const u8 = undefined;
            for (Token.keywords.keys(), 0..) |key, i| {
                keywords[i] = key ++ &[_:0]u8{0};
            }
            break :blk keywords;
        };

        inline for (keywords, 0..) |keyword, i| {
            const kind = Token.keywords.values()[i];
            const size = keyword.len - 1;

            // Basic identifier
            {
                var lexer = init(keyword);

                try std.testing.expectEqual(Token{
                    .kind = kind,
                    .location = .{ .left = 0, .right = size },
                }, lexer.next());
            }

            // Leading space
            {
                var lexer = init(" " ++ keyword);
                try std.testing.expectEqual(Token{
                    .kind = kind,
                    .location = .{ .left = 1, .right = size + 1 },
                }, lexer.next());
            }

            // Leading character
            {
                var lexer = init("x" ++ keyword);
                try std.testing.expectEqual(Token{
                    .kind = .identifier,
                    .location = .{ .left = 0, .right = size + 1 },
                }, lexer.next());
            }

            // Invalid character
            {
                var lexer = init("!" ++ keyword);

                try std.testing.expectEqual(Token{
                    .kind = .special_invalid,
                    .location = .{ .left = 0, .right = size + 1 },
                }, lexer.next());
            }
        }
    }
}

test "symbols" {
    const symbols = comptime blk: {
        var symbols: [Token.symbols.keys().len][:0]const u8 = undefined;
        for (Token.symbols.keys(), 0..) |key, i| {
            symbols[i] = key ++ &[_:0]u8{0};
        }
        break :blk symbols;
    };

    inline for (symbols, 0..) |symbol, i| {
        const kind = Token.symbols.values()[i];
        const size = symbol.len - 1;

        // Basic symbol
        {
            var lexer = init(symbol);

            try std.testing.expectEqual(Token{
                .kind = kind,
                .location = .{ .left = 0, .right = size },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size, .right = size },
            }, lexer.next());
        }

        // Leading space
        {
            var lexer = init(" " ++ symbol);

            try std.testing.expectEqual(Token{
                .kind = kind,
                .location = .{ .left = 1, .right = size + 1 },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size + 1, .right = size + 1 },
            }, lexer.next());
        }

        // Leading invalid (x)
        {
            var lexer = init("x" ++ symbol);

            try std.testing.expectEqual(Token{
                .kind = .special_invalid,
                .location = .{ .left = 0, .right = size + 1 },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size + 1, .right = size + 1 },
            }, lexer.next());
        }

        // Leading invalid (!)
        {
            var lexer = init("!" ++ symbol);

            try std.testing.expectEqual(Token{
                .kind = .special_invalid,
                .location = .{ .left = 0, .right = size + 1 },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size + 1, .right = size + 1 },
            }, lexer.next());
        }

        // Trailing space
        {
            var lexer = init(symbol ++ " ");

            try std.testing.expectEqual(Token{
                .kind = kind,
                .location = .{ .left = 0, .right = size },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size, .right = size },
            }, lexer.next());
        }

        // Trailing invalid (x)
        {
            var lexer = init(symbol ++ "x");

            try std.testing.expectEqual(Token{
                .kind = .symbol_colon,
                .location = .{ .left = 0, .right = size },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size, .right = size },
            }, lexer.next());
        }

        // Space on both sides
        {
            var lexer = init(" " ++ symbol ++ " ");

            try std.testing.expectEqual(Token{
                .kind = kind,
                .location = .{ .left = 1, .right = size + 1 },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size + 1, .right = size + 1 },
            }, lexer.next());
        }

        // Invalid on both sides
        {
            var lexer = init("x" ++ symbol ++ "x");

            try std.testing.expectEqual(Token{
                .kind = .special_invalid,
                .location = .{ .left = 0, .right = size + 1 },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = size + 1, .right = size + 1 },
            }, lexer.next());
        }
    }
}

test "operators" {
    // Basic operators
    {
        var lexer = init("-> | <>");

        try std.testing.expectEqual(Token{
            .kind = .operator_arrow,
            .location = .{ .left = 0, .right = 2 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_pipe,
            .location = .{ .left = 3, .right = 4 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_chain,
            .location = .{ .left = 5, .right = 7 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 7, .right = 7 },
        }, lexer.next());
    }

    // No spaces between operators (invalid)
    {
        var lexer = init("->|<>");

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 0, .right = 5 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 5, .right = 5 },
        }, lexer.next());
    }

    // Split operators (invalid)
    {
        var lexer = init("- > < > |");

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 0, .right = 1 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 2, .right = 3 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 4, .right = 5 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 6, .right = 7 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_pipe,
            .location = .{ .left = 8, .right = 9 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 9, .right = 9 },
        }, lexer.next());
    }

    // Invalid operator combinations
    {
        var lexer = init("<- >< |>");

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 0, .right = 2 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 3, .right = 5 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 6, .right = 8 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 8, .right = 8 },
        }, lexer.next());
    }

    // Extra whitespace
    {
        var lexer = init("  ->     |   <>  ");

        try std.testing.expectEqual(Token{
            .kind = .operator_arrow,
            .location = .{ .left = 2, .right = 4 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_pipe,
            .location = .{ .left = 9, .right = 10 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_chain,
            .location = .{ .left = 13, .right = 15 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 17, .right = 17 },
        }, lexer.next());
    }

    // Invalid operator sequences
    {
        var lexer = init("-> | <>->");

        try std.testing.expectEqual(Token{
            .kind = .operator_arrow,
            .location = .{ .left = 0, .right = 2 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_pipe,
            .location = .{ .left = 3, .right = 4 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 5, .right = 9 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 9, .right = 9 },
        }, lexer.next());
    }

    // Double operators (invalid)
    {
        var lexer = init("|| ->-> <><>");

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 0, .right = 2 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 3, .right = 7 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_invalid,
            .location = .{ .left = 8, .right = 12 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 12, .right = 12 },
        }, lexer.next());
    }

    // Multiple valid operators with spaces
    {
        var lexer = init("| | -> -> <> <>");

        try std.testing.expectEqual(Token{
            .kind = .operator_pipe,
            .location = .{ .left = 0, .right = 1 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_pipe,
            .location = .{ .left = 2, .right = 3 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_arrow,
            .location = .{ .left = 4, .right = 6 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_arrow,
            .location = .{ .left = 7, .right = 9 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_chain,
            .location = .{ .left = 10, .right = 12 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .operator_chain,
            .location = .{ .left = 13, .right = 15 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 15, .right = 15 },
        }, lexer.next());
    }
}

test "literals" {
    // Integer tests
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            var lexer = init(numbers[i..] ++ numbers[0..i]);

            switch (i) {
                0 => {
                    try std.testing.expectEqual(Token{
                        .kind = .special_invalid,
                        .location = .{ .left = 0, .right = 10 },
                    }, lexer.next());
                },
                else => {
                    try std.testing.expectEqual(Token{
                        .kind = .literal_int,
                        .location = .{ .left = 0, .right = 10 },
                    }, lexer.next());
                },
            }

            try std.testing.expectEqual(Token{
                .kind = .special_end_of_frame,
                .location = .{ .left = 10, .right = 10 },
            }, lexer.next());
        }
    }

    // Float tests
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            const rotate = numbers[i..] ++ numbers[0..i];
            inline for (0..rotate.len + 1) |j| {
                const float = rotate[0..j] ++ "." ++ rotate[j..];
                var lexer = init(float);
                switch (float[10]) {
                    '.' => {
                        try std.testing.expectEqual(Token{
                            .kind = .special_invalid,
                            .location = .{ .left = 0, .right = 11 },
                        }, lexer.next());
                    },
                    else => switch (float[0]) {
                        '.' => {
                            try std.testing.expectEqual(Token{
                                .kind = .special_invalid,
                                .location = .{ .left = 0, .right = 11 },
                            }, lexer.next());
                        },
                        '0' => switch (float[1]) {
                            '.' => {
                                try std.testing.expectEqual(Token{
                                    .kind = .literal_float,
                                    .location = .{ .left = 0, .right = 11 },
                                }, lexer.next());
                            },
                            else => {
                                try std.testing.expectEqual(Token{
                                    .kind = .special_invalid,
                                    .location = .{ .left = 0, .right = 11 },
                                }, lexer.next());
                            },
                        },
                        else => {
                            try std.testing.expectEqual(Token{
                                .kind = .literal_float,
                                .location = .{ .left = 0, .right = 11 },
                            }, lexer.next());
                        },
                    },
                }
                try std.testing.expectEqual(Token{
                    .kind = .special_end_of_frame,
                    .location = .{ .left = 11, .right = 11 },
                }, lexer.next());
            }
        }
    }

    // String tests
    {
        // Basic string
        {
            var lexer = init("'string literal'");

            try std.testing.expectEqual(Token{
                .kind = .literal_string,
                .location = .{ .left = 0, .right = 16 },
            }, lexer.next());
        }

        // Empty string
        {
            var lexer = init("''");

            try std.testing.expectEqual(Token{
                .kind = .literal_string,
                .location = .{ .left = 0, .right = 2 },
            }, lexer.next());
        }

        // Escaped quotes
        {
            var lexer = init("'\\'escaped quotes\\''");

            try std.testing.expectEqual(Token{
                .kind = .literal_string,
                .location = .{ .left = 0, .right = 20 },
            }, lexer.next());
        }

        // Escaped characters
        {
            var lexer = init("'\\n\\t\\r\\'\\\\'");

            try std.testing.expectEqual(Token{
                .kind = .literal_string,
                .location = .{ .left = 0, .right = 12 },
            }, lexer.next());
        }

        // Invalid escapes
        {
            var lexer = init("'\\x'");

            try std.testing.expectEqual(Token{
                .kind = .special_invalid,
                .location = .{ .left = 0, .right = 4 },
            }, lexer.next());
        }

        // Multiple strings
        {
            var lexer = init("'one' 'two' 'three'");

            try std.testing.expectEqual(Token{
                .kind = .literal_string,
                .location = .{ .left = 0, .right = 5 },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .literal_string,
                .location = .{ .left = 6, .right = 11 },
            }, lexer.next());

            try std.testing.expectEqual(Token{
                .kind = .literal_string,
                .location = .{ .left = 12, .right = 19 },
            }, lexer.next());
        }
    }
}

test "whitespace" {
    // Simple whitespace
    {
        var lexer = init(" ");

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 1, .right = 1 },
        }, lexer.next());
    }

    // Mixed whitespace
    {
        var lexer = init(" \n\t\r");

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 4, .right = 4 },
        }, lexer.next());
    }

    // Empty string
    {
        var lexer = init("");

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 0, .right = 0 },
        }, lexer.next());
    }

    // Whitespace between tokens
    {
        var lexer = init("a \n\t\r b");

        try std.testing.expectEqual(Token{
            .kind = .identifier,
            .location = .{ .left = 0, .right = 1 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .identifier,
            .location = .{ .left = 6, .right = 7 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 7, .right = 7 },
        }, lexer.next());
    }

    // Leading whitespace
    {
        var lexer = init("   abc");

        try std.testing.expectEqual(Token{
            .kind = .identifier,
            .location = .{ .left = 3, .right = 6 },
        }, lexer.next());
    }

    // Trailing whitespace
    {
        var lexer = init("abc   ");

        try std.testing.expectEqual(Token{
            .kind = .identifier,
            .location = .{ .left = 0, .right = 3 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 6, .right = 6 },
        }, lexer.next());
    }

    // Multiple whitespace sequences
    {
        var lexer = init("  a  b  c  ");

        try std.testing.expectEqual(Token{
            .kind = .identifier,
            .location = .{ .left = 2, .right = 3 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .identifier,
            .location = .{ .left = 5, .right = 6 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .identifier,
            .location = .{ .left = 8, .right = 9 },
        }, lexer.next());

        try std.testing.expectEqual(Token{
            .kind = .special_end_of_frame,
            .location = .{ .left = 11, .right = 11 },
        }, lexer.next());
    }
}
