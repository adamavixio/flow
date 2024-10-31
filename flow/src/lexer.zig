const std = @import("std");

const Lexer = @This();
const Token = @import("token.zig");

index: usize,
buffer: [:0]const u8,

pub const State = enum {
    init,
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
    var state = State.init;
    var token = Token.init(undefined, Token.Location.init(self.index, undefined));

    while (true) {
        switch (state) {
            .init => switch (self.buffer[self.index]) {
                0 => {
                    token.lexeme = Token.Lexeme.init(.special, .end_of_frame);
                    token.location.right = self.index;
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
                    token.lexeme = Token.Lexeme.init(.literal, .identifier);
                    token.location.right = self.index;
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
                    token.lexeme = Token.Lexeme.init(.literal, .int);
                    token.location.right = self.index;
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
                    token.lexeme = Token.Lexeme.init(.literal, .float);
                    token.location.right = self.index;
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
                    token.lexeme = Token.Lexeme.init(.literal, .string);
                    token.location.right = self.index;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .colon => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.lexeme = Token.Lexeme.init(.symbol, .colon);
                    token.location.right = self.index;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .pipe => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.lexeme = Token.Lexeme.init(.operator, .pipe);
                    token.location.right = self.index;
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
                    token.lexeme = Token.Lexeme.init(.operator, .chain);
                    token.location.right = self.index;
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
                    token.lexeme = Token.Lexeme.init(.operator, .arrow);
                    token.location.right = self.index;
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .invalid => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    token.lexeme = Token.Lexeme.init(.special, .invalid);
                    token.location.right = self.index;
                    break;
                },
                else => {
                    self.index += 1;
                },
            },
        }
    }

    return token;
}

pub fn read(self: Lexer, location: Token.Location) []const u8 {
    return self.buffer[location.left..location.right];
}

test "whitespace" {
    {
        var lexer = init(" \n\t\r");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(4, 4)), lexer.next());
    }
}

test "symbols" {
    inline for (std.meta.fields(Token.Lexeme.Symbol)) |field| {
        const string = switch (@field(Token.Lexeme.Symbol, field.name)) {
            .colon => ":",
        };
        const size = string.len;
        const lexeme = @field(Token.Lexeme.Symbol, field.name);

        {
            var lexer = init(string);
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.symbol, lexeme), Token.Location.init(0, size)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size, size)), lexer.next());
        }

        {
            var lexer = init(" " ++ string);
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.symbol, lexeme), Token.Location.init(1, size + 1)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
        }

        {
            var lexer = init("x" ++ string);
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 1)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
        }

        {
            var lexer = init("!" ++ string);
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 1)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
        }

        {
            var lexer = init(string ++ " ");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.symbol, lexeme), Token.Location.init(0, size)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
        }

        {
            var lexer = init(string ++ "x");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 1)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
        }

        {
            var lexer = init(string ++ "!");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 1)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
        }

        {
            var lexer = init(" " ++ string ++ " ");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.symbol, lexeme), Token.Location.init(1, size + 1)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 2, size + 2)), lexer.next());
        }

        {
            var lexer = init("x" ++ string ++ "x");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 2)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 2, size + 2)), lexer.next());
        }

        {
            var lexer = init("!" ++ string ++ "!");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 2)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 2, size + 2)), lexer.next());
        }
    }
}

test "literals" {
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            var lexer = init(numbers[i..] ++ numbers[0..i]);
            switch (i) {
                0 => {
                    try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 10)), lexer.next());
                    try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(10, 10)), lexer.next());
                },
                else => {
                    try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .int), Token.Location.init(0, 10)), lexer.next());
                    try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(10, 10)), lexer.next());
                },
            }
        }
    }

    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            const rotate = numbers[i..] ++ numbers[0..i];
            inline for (0..rotate.len + 1) |j| {
                const float = rotate[0..j] ++ "." ++ rotate[j..];
                var lexer = init(float);
                switch (float[10]) {
                    '.' => {
                        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 11)), lexer.next());
                        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(11, 11)), lexer.next());
                    },
                    else => switch (float[0]) {
                        '.' => {
                            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 11)), lexer.next());
                            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(11, 11)), lexer.next());
                        },
                        '0' => switch (float[1]) {
                            '.' => {
                                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .float), Token.Location.init(0, 11)), lexer.next());
                                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(11, 11)), lexer.next());
                            },
                            else => {
                                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 11)), lexer.next());
                                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(11, 11)), lexer.next());
                            },
                        },
                        else => {
                            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .float), Token.Location.init(0, 11)), lexer.next());
                            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(11, 11)), lexer.next());
                        },
                    },
                }
            }
        }
    }

    {
        {
            var lexer = init("'string literal'");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(0, 16)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(16, 16)), lexer.next());
        }

        {
            var lexer = init("''");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(0, 2)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(2, 2)), lexer.next());
        }

        {
            var lexer = init("'\\'escaped quotes\\''");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(0, 20)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(20, 20)), lexer.next());
        }

        {
            var lexer = init("'\\n\\t\\r\\'\\\\'");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(0, 12)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(12, 12)), lexer.next());
        }

        {
            var lexer = init("'unescaped\\'");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 12)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(12, 12)), lexer.next());
        }

        {
            var lexer = init("'unterminated");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 13)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(13, 13)), lexer.next());
        }

        {
            var lexer = init("'\\n'");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(0, 4)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(4, 4)), lexer.next());
        }

        {
            var lexer = init("'\\x'");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 4)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(4, 4)), lexer.next());
        }

        {
            var lexer = init("'one' 'two' 'three'");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(0, 5)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(6, 11)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(12, 19)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(19, 19)), lexer.next());
        }

        {
            var lexer = init("'outer \\'inner\\' quote'");
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .string), Token.Location.init(0, 23)), lexer.next());
            try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(23, 23)), lexer.next());
        }
    }

    {
        inline for ([_][:0]const u8{ "int", "uint", "float", "string" }) |string| {
            const size = string.len;
            {
                var lexer = init(string);
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .identifier), Token.Location.init(0, size)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size, size)), lexer.next());
            }

            {
                var lexer = init(" " ++ string);
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .identifier), Token.Location.init(1, size + 1)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
            }

            {
                var lexer = init("x" ++ string);
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .identifier), Token.Location.init(0, size + 1)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
            }

            {
                var lexer = init("!" ++ string);
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 1)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
            }

            {
                var lexer = init(string ++ " ");
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .identifier), Token.Location.init(0, size)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
            }

            {
                var lexer = init(string ++ "x");
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .identifier), Token.Location.init(0, size + 1)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
            }

            {
                var lexer = init(string ++ "!");
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 1)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 1, size + 1)), lexer.next());
            }

            {
                var lexer = init(" " ++ string ++ " ");
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .identifier), Token.Location.init(1, size + 1)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 2, size + 2)), lexer.next());
            }

            {
                var lexer = init("x" ++ string ++ "x");
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.literal, .identifier), Token.Location.init(0, size + 2)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 2, size + 2)), lexer.next());
            }

            {
                var lexer = init("!" ++ string ++ "!");
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, size + 2)), lexer.next());
                try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(size + 2, size + 2)), lexer.next());
            }
        }
    }
}

test "operators" {
    {
        var lexer = init("-> | <>");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .arrow), Token.Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .pipe), Token.Location.init(3, 4)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .chain), Token.Location.init(5, 7)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(7, 7)), lexer.next());
    }

    {
        var lexer = init("->|<>");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(5, 5)), lexer.next());
    }

    {
        var lexer = init("- > < > |");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 1)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(2, 3)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(4, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(6, 7)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .pipe), Token.Location.init(8, 9)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(9, 9)), lexer.next());
    }

    {
        var lexer = init("<- >< |>");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(3, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(6, 8)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(8, 8)), lexer.next());
    }

    {
        var lexer = init("  ->     |   <>  ");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .arrow), Token.Location.init(2, 4)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .pipe), Token.Location.init(9, 10)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .chain), Token.Location.init(13, 15)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(17, 17)), lexer.next());
    }

    {
        var lexer = init("-> | <>->");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .arrow), Token.Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .pipe), Token.Location.init(3, 4)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(5, 9)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(9, 9)), lexer.next());
    }

    {
        var lexer = init("|| ->-> <><>");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(3, 7)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .invalid), Token.Location.init(8, 12)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(12, 12)), lexer.next());
    }

    {
        var lexer = init("| | -> -> <> <>");
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .pipe), Token.Location.init(0, 1)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .pipe), Token.Location.init(2, 3)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .arrow), Token.Location.init(4, 6)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .arrow), Token.Location.init(7, 9)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .chain), Token.Location.init(10, 12)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.operator, .chain), Token.Location.init(13, 15)), lexer.next());
        try std.testing.expectEqual(Token.init(Token.Lexeme.init(.special, .end_of_frame), Token.Location.init(15, 15)), lexer.next());
    }
}
