const std = @import("std");
const Source = @import("source.zig");
const Token = @import("token.zig");

pub const Lexer = @This();

index: usize,
source: Source,

pub fn init(source: Source) Lexer {
    return .{
        .index = 0,
        .source = source,
    };
}

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

pub fn next(self: *Lexer) Token {
    var state = State.start;
    var token = Token.init(undefined, Token.Location.init(self.index, undefined));

    while (true) {
        switch (state) {
            .start => switch (self.source.buffer[self.index]) {
                0 => {
                    token.tag = .end_of_frame;
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
                    token.location.start = self.index;
                },
                else => {
                    state = .invalid;
                },
            },
            .identifier => switch (self.source.buffer[self.index]) {
                'a'...'z' => {
                    self.index += 1;
                },
                '0'...'9' => {
                    self.index += 1;
                },
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .identifier;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .zero => switch (self.source.buffer[self.index]) {
                '.' => {
                    self.index += 1;
                    state = .number_period;
                },
                else => {
                    state = .invalid;
                },
            },
            .number => switch (self.source.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    state = .number;
                },
                '.' => {
                    self.index += 1;
                    state = .number_period;
                },
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .int;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .number_period => switch (self.source.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    state = .float;
                },
                else => {
                    state = .invalid;
                },
            },
            .float => switch (self.source.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    state = .float;
                },
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .float;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .quote => switch (self.source.buffer[self.index]) {
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
            .quote_back_slash => switch (self.source.buffer[self.index]) {
                '\\', 'n', 't', 'r', '\'' => {
                    self.index += 1;
                    state = .quote;
                },
                else => {
                    state = .invalid;
                },
            },
            .quote_quote => switch (self.source.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .string;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .colon => switch (self.source.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .colon;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .pipe => switch (self.source.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .pipe;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .left_angle => switch (self.source.buffer[self.index]) {
                '>' => {
                    self.index += 1;
                    state = .left_angle_right_angle;
                },
                else => {
                    state = .invalid;
                },
            },
            .left_angle_right_angle => switch (self.source.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .chain;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .hyphen => switch (self.source.buffer[self.index]) {
                '>' => {
                    self.index += 1;
                    state = .hyphen_right_angle;
                },
                else => {
                    state = .invalid;
                },
            },
            .hyphen_right_angle => switch (self.source.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .arrow;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .invalid => switch (self.source.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.tag = .invalid;
                    break;
                },
                else => {
                    self.index += 1;
                },
            },
        }
    }

    token.location.end = self.index;
    return token;
}

test "operators" {
    const allocator = std.testing.allocator;

    // arrow
    {
        // Base
        {
            var source = try Source.initString("->", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.arrow, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(" -> ", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.arrow, Token.Location.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Split
        {
            var source = try Source.initString("- >", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.invalid, Token.Location.init(0, 1)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.invalid, Token.Location.init(2, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }

    // Chain
    {
        // Base
        {
            var source = try Source.initString("<>", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.chain, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(" <> ", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.chain, Token.Location.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Split
        {
            var source = try Source.initString("< >", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.invalid, Token.Location.init(0, 1)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.invalid, Token.Location.init(2, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }

    // Colon
    {
        // Base
        {
            var source = try Source.initString(":", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.colon, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(" : ", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.colon, Token.Location.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }

    // Pipe
    {
        // Base
        {
            var source = try Source.initString("|", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.pipe, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(" | ", allocator);
            defer source.deinit();

            var lexer = Lexer.init(source);
            try std.testing.expectEqual(
                Token.init(.pipe, Token.Location.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }
}

test "literals" {
    const allocator = std.testing.allocator;

    // Int
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            const tag = if (i == 0) .invalid else .int;

            // Base
            {
                var source = try Source.initString(numbers[i..] ++ numbers[0..i], allocator);
                defer source.deinit();

                var lexer = Lexer.init(source);
                try std.testing.expectEqual(
                    Token.init(tag, Token.Location.init(0, source.buffer.len)),
                    lexer.next(),
                );
                try std.testing.expectEqual(
                    Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                    lexer.next(),
                );
            }

            // Whitespace
            {
                var source = try Source.initString(" " ++ numbers[i..] ++ numbers[0..i] ++ " ", allocator);
                defer source.deinit();

                var lexer = Lexer.init(source);
                try std.testing.expectEqual(
                    Token.init(tag, Token.Location.init(1, source.buffer.len - 1)),
                    lexer.next(),
                );
                try std.testing.expectEqual(
                    Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                    lexer.next(),
                );
            }
        }
    }

    // Float
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            const rotated = numbers[i..] ++ numbers[0..i];
            inline for (0..rotated.len + 1) |j| {
                const tag = blk: {
                    if (i == 0 and j != 1) break :blk .invalid;
                    if (j == 0 or j == 10) break :blk .invalid;
                    break :blk .float;
                };

                // Base
                {
                    var source = try Source.initString(rotated[0..j] ++ "." ++ rotated[j..], allocator);
                    defer source.deinit();

                    var lexer = Lexer.init(source);
                    try std.testing.expectEqual(
                        Token.init(tag, Token.Location.init(0, source.buffer.len)),
                        lexer.next(),
                    );
                    try std.testing.expectEqual(
                        Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                        lexer.next(),
                    );
                }

                // Whitespace
                {
                    var source = try Source.initString(" " ++ rotated[0..j] ++ "." ++ rotated[j..] ++ " ", allocator);
                    defer source.deinit();

                    var lexer = Lexer.init(source);
                    try std.testing.expectEqual(
                        Token.init(tag, Token.Location.init(1, source.buffer.len - 1)),
                        lexer.next(),
                    );
                    try std.testing.expectEqual(
                        Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                        lexer.next(),
                    );
                }
            }
        }
    }

    // String tests
    {
        // Base
        {
            var source = try Source.initString("'string'", allocator);
            defer source.deinit();

            var lexer = init(source);
            try std.testing.expectEqual(
                Token.init(.string, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Empty
        {
            var source = try Source.initString("''", allocator);
            defer source.deinit();

            var lexer = init(source);
            try std.testing.expectEqual(
                Token.init(.string, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Escaped Quotes
        {
            var source = try Source.initString("'\\'escaped quotes\\''", allocator);
            defer source.deinit();

            var lexer = init(source);
            try std.testing.expectEqual(
                Token.init(.string, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Escaped Characters
        {
            var source = try Source.initString("'\\n\\t\\r\\'\\\\'", allocator);
            defer source.deinit();

            var lexer = init(source);
            try std.testing.expectEqual(
                Token.init(.string, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Invalid Escapes
        {
            var source = try Source.initString("'\\x'", allocator);
            defer source.deinit();

            var lexer = init(source);
            try std.testing.expectEqual(
                Token.init(.invalid, Token.Location.init(0, source.buffer.len)),
                lexer.next(),
            );
            try std.testing.expectEqual(
                Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }
}

test "whitespace" {
    const allocator = std.testing.allocator;

    // Base
    {
        var source = try Source.initString(" \n \t \r", allocator);
        defer source.deinit();

        var lexer = Lexer.init(source);
        try std.testing.expectEqual(
            Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
            lexer.next(),
        );
    }

    // Empty
    {
        var source = try Source.initString("", allocator);
        defer source.deinit();

        var lexer = Lexer.init(source);
        try std.testing.expectEqual(
            Token.init(.end_of_frame, Token.Location.init(source.buffer.len, source.buffer.len)),
            lexer.next(),
        );
    }
}
