const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const root = @import("root.zig");
const Token = root.Token;
const Position = root.Position;
const Source = root.Source;

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
    var token = Token.init(undefined, Position.init(self.index, undefined));

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
                '\n' => {
                    self.index += 1;
                    token.tag = .new_line;
                    break;
                },
                ' ', '\t', '\r' => {
                    self.index += 1;
                    token.position.start = self.index;
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

    token.position.end = self.index;
    return token;
}

pub fn Tokenize(self: *Lexer, allocator: Allocator) !ArrayList(Token) {
    var tokens = ArrayList(Token).init(allocator);
    errdefer tokens.deinit();

    while (true) {
        const token = self.next();
        try tokens.append(token);
        if (token.tag == .end_of_frame) break;
    }

    return tokens;
}

test "identifiers" {
    const allocator = testing.allocator;

    // Base
    {
        var source = try Source.initString(allocator, "abc123zyz");
        defer source.deinit();

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            Token.init(.identifier, Position.init(0, source.buffer.len)),
            lexer.next(),
        );
        try testing.expectEqual(
            Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
            lexer.next(),
        );
    }

    // Whitespace
    {
        var source = try Source.initString(allocator, " abc123zyz ");
        defer source.deinit();

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            Token.init(.identifier, Position.init(1, source.buffer.len - 1)),
            lexer.next(),
        );
        try testing.expectEqual(
            Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
            lexer.next(),
        );
    }
}

test "literals" {
    const allocator = testing.allocator;

    // Int
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            const tag = if (i == 0) .invalid else .int;

            // Base
            {
                var source = try Source.initString(allocator, numbers[i..] ++ numbers[0..i]);
                defer source.deinit();

                var lexer = Lexer.init(source);
                try testing.expectEqual(
                    Token.init(tag, Position.init(0, source.buffer.len)),
                    lexer.next(),
                );
                try testing.expectEqual(
                    Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                    lexer.next(),
                );
            }

            // Whitespace
            {
                var source = try Source.initString(allocator, " " ++ numbers[i..] ++ numbers[0..i] ++ " ");
                defer source.deinit();

                var lexer = Lexer.init(source);
                try testing.expectEqual(
                    Token.init(tag, Position.init(1, source.buffer.len - 1)),
                    lexer.next(),
                );
                try testing.expectEqual(
                    Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
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
                    var source = try Source.initString(allocator, rotated[0..j] ++ "." ++ rotated[j..]);
                    defer source.deinit();

                    var lexer = Lexer.init(source);
                    try testing.expectEqual(
                        Token.init(tag, Position.init(0, source.buffer.len)),
                        lexer.next(),
                    );
                    try testing.expectEqual(
                        Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                        lexer.next(),
                    );
                }

                // Whitespace
                {
                    var source = try Source.initString(allocator, " " ++ rotated[0..j] ++ "." ++ rotated[j..] ++ " ");
                    defer source.deinit();

                    var lexer = Lexer.init(source);
                    try testing.expectEqual(
                        Token.init(tag, Position.init(1, source.buffer.len - 1)),
                        lexer.next(),
                    );
                    try testing.expectEqual(
                        Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
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
            var source = try Source.initString(allocator, "'string'");
            defer source.deinit();

            var lexer = init(source);
            try testing.expectEqual(
                Token.init(.string, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Empty
        {
            var source = try Source.initString(allocator, "''");
            defer source.deinit();

            var lexer = init(source);
            try testing.expectEqual(
                Token.init(.string, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Escaped Quotes
        {
            var source = try Source.initString(allocator, "'\\'escaped quotes\\''");
            defer source.deinit();

            var lexer = init(source);
            try testing.expectEqual(
                Token.init(.string, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Escaped Characters
        {
            var source = try Source.initString(allocator, "'\\n\\t\\r\\'\\\\'");
            defer source.deinit();

            var lexer = init(source);
            try testing.expectEqual(
                Token.init(.string, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Invalid Escapes
        {
            var source = try Source.initString(allocator, "'\\x'");
            defer source.deinit();

            var lexer = init(source);
            try testing.expectEqual(
                Token.init(.invalid, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }
}

test "operators" {
    const allocator = testing.allocator;

    // arrow
    {
        // Base
        {
            var source = try Source.initString(allocator, "->");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.arrow, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(allocator, " -> ");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.arrow, Position.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Split
        {
            var source = try Source.initString(allocator, "- >");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.invalid, Position.init(0, 1)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.invalid, Position.init(2, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }

    // Chain
    {
        // Base
        {
            var source = try Source.initString(allocator, "<>");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.chain, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(allocator, " <> ");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.chain, Position.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Split
        {
            var source = try Source.initString(allocator, "< >");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.invalid, Position.init(0, 1)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.invalid, Position.init(2, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }

    // Colon
    {
        // Base
        {
            var source = try Source.initString(allocator, ":");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.colon, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(allocator, " : ");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.colon, Position.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }

    // Pipe
    {
        // Base
        {
            var source = try Source.initString(allocator, "|");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.pipe, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(allocator, " | ");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.pipe, Position.init(1, source.buffer.len - 1)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }
}

test "specials" {
    const allocator = testing.allocator;

    // New Line
    {
        // Base
        {
            var source = try Source.initString(allocator, "\n");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.new_line, Position.init(0, source.buffer.len)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }

        // Whitespace
        {
            var source = try Source.initString(allocator, " \t\r\n\t ");
            defer source.deinit();

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                Token.init(.new_line, Position.init(3, source.buffer.len - 2)),
                lexer.next(),
            );
            try testing.expectEqual(
                Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
                lexer.next(),
            );
        }
    }
}

test "whitespace" {
    const allocator = testing.allocator;

    // Base
    {
        var source = try Source.initString(allocator, " \t \r");
        defer source.deinit();

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
            lexer.next(),
        );
    }

    // Empty
    {
        var source = try Source.initString(allocator, "");
        defer source.deinit();

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            Token.init(.end_of_frame, Position.init(source.buffer.len, source.buffer.len)),
            lexer.next(),
        );
    }
}
