const std = @import("std");

const Self = @This();
const Reader = @import("io/reader.zig");

reader: Reader.Buffer(1024),

pub const State = enum {
    init,
    character,
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

pub const Tag = enum {
    symbol_arrow,
    symbol_chain,
    symbol_colon,
    symbol_pipe,
    keyword_int,
    keyword_float,
    keyword_string,
    literal,
    literal_int,
    literal_float,
    literal_string,
    special_module,
    special_invalid,
    special_eof,
};

pub const Token = struct {
    left: usize,
    right: usize,
    tag: Tag,
};

const Error = error{
    InvalidTagType,
    InvalidValueType,
};

pub fn init(reader: Reader.Buffer(1024)) Self {
    return .{ .reader = reader };
}

pub fn next(self: *Self) Token {
    self.reader.skip();
    const tag: Tag = blk: {
        var state: State = .init;
        while (true) {
            switch (state) {
                .init => switch (self.reader.peekRight()) {
                    0 => {
                        break :blk .special_eof;
                    },
                    'a'...'z' => {
                        self.reader.shiftRight();
                        state = .character;
                    },
                    '0' => {
                        self.reader.shiftRight();
                        state = .zero;
                    },
                    '1'...'9' => {
                        self.reader.shiftRight();
                        state = .number;
                    },
                    '"' => {
                        self.reader.shiftRight();
                        state = .quote;
                    },
                    ':' => {
                        self.reader.shiftRight();
                        state = .colon;
                    },
                    '|' => {
                        self.reader.shiftRight();
                        state = .pipe;
                    },
                    '-' => {
                        self.reader.shiftRight();
                        state = .hyphen;
                    },
                    '<' => {
                        self.reader.shiftRight();
                        state = .left_angle;
                    },
                    ' ', '\n', '\t', '\r' => {
                        self.reader.shiftLeft();
                        continue;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .character => switch (self.reader.peekRight()) {
                    'a'...'z' => {
                        self.reader.shiftRight();
                    },
                    0, ' ', '\n', '\t', '\r' => {
                        if (self.reader.equal("int")) {
                            break :blk .keyword_int;
                        }
                        if (self.reader.equal("float")) {
                            break :blk .keyword_float;
                        }
                        if (self.reader.equal("string")) {
                            break :blk .keyword_string;
                        }
                        break :blk .literal;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .zero => switch (self.reader.peekRight()) {
                    '.' => {
                        self.reader.shiftRight();
                        state = .number_period;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .number => switch (self.reader.peekRight()) {
                    '0'...'9' => {
                        self.reader.shiftRight();
                        state = .number;
                    },
                    '.' => {
                        self.reader.shiftRight();
                        state = .number_period;
                    },
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .literal_int;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .number_period => switch (self.reader.peekRight()) {
                    '0'...'9' => {
                        self.reader.shiftRight();
                        state = .float;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .float => switch (self.reader.peekRight()) {
                    '0'...'9' => {
                        self.reader.shiftRight();
                        state = .float;
                    },
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .literal_float;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .quote => switch (self.reader.peekRight()) {
                    '\\' => {
                        self.reader.shiftRight();
                        state = .quote_back_slash;
                    },
                    '"' => {
                        self.reader.shiftRight();
                        state = .quote_quote;
                    },
                    0 => {
                        state = .invalid;
                    },
                    else => {
                        self.reader.shiftRight();
                    },
                },
                .quote_back_slash => switch (self.reader.peekRight()) {
                    '\\', 'n', 't', 'r', '"' => {
                        self.reader.shiftRight();
                        state = .quote;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .quote_quote => switch (self.reader.peekRight()) {
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .literal_string;
                    },
                    else => {
                        std.debug.print("quote_quote {any}\n", .{self.reader.peekRight()});
                        state = .invalid;
                    },
                },
                .colon => switch (self.reader.peekRight()) {
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .symbol_colon;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .pipe => switch (self.reader.peekRight()) {
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .symbol_pipe;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .left_angle => switch (self.reader.peekRight()) {
                    '>' => {
                        self.reader.shiftRight();
                        state = .left_angle_right_angle;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .left_angle_right_angle => switch (self.reader.peekRight()) {
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .symbol_chain;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .hyphen => switch (self.reader.peekRight()) {
                    '>' => {
                        self.reader.shiftRight();
                        state = .hyphen_right_angle;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .hyphen_right_angle => switch (self.reader.peekRight()) {
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .symbol_arrow;
                    },
                    else => {
                        state = .invalid;
                    },
                },
                .invalid => switch (self.reader.peekRight()) {
                    0, ' ', '\n', '\t', '\r' => {
                        break :blk .special_invalid;
                    },
                    else => {
                        self.reader.shiftRight();
                        continue;
                    },
                },
            }
        }
    };

    return .{
        .left = self.reader.left,
        .right = self.reader.right,
        .tag = tag,
    };
}

test "whitespace" {
    {
        var lexer = init(try Reader.Buffer(1024).init(" \n\t\r"));
        try std.testing.expectEqual(Token{ .left = 4, .right = 4, .tag = .special_eof }, lexer.next());
    }
}

test "keywords" {
    {
        var lexer = init(try Reader.Buffer(1024).init("int intx int!"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 3, .tag = .keyword_int }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 8, .tag = .literal }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 9, .right = 13, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 13, .right = 13, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init("float floatx float!"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 5, .tag = .keyword_float }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 12, .tag = .literal }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 13, .right = 19, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 19, .right = 19, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init("string stringx string!"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 6, .tag = .keyword_string }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 7, .right = 14, .tag = .literal }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 15, .right = 22, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 22, .right = 22, .tag = .special_eof }, lexer.next());
    }
}

test "literals" {
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            var lexer = init(try Reader.Buffer(1024).init(numbers[i..] ++ numbers[0..i]));
            switch (i) {
                0 => {
                    try std.testing.expectEqual(Token{ .left = 0, .right = 10, .tag = .special_invalid }, lexer.next());
                    try std.testing.expectEqual(Token{ .left = 10, .right = 10, .tag = .special_eof }, lexer.next());
                },
                else => {
                    try std.testing.expectEqual(Token{ .left = 0, .right = 10, .tag = .literal_int }, lexer.next());
                    try std.testing.expectEqual(Token{ .left = 10, .right = 10, .tag = .special_eof }, lexer.next());
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
                var lexer = init(try Reader.Buffer(1024).init(float));
                switch (float[10]) {
                    '.' => {
                        try std.testing.expectEqual(Token{ .left = 0, .right = 11, .tag = .special_invalid }, lexer.next());
                        try std.testing.expectEqual(Token{ .left = 11, .right = 11, .tag = .special_eof }, lexer.next());
                    },
                    else => switch (float[0]) {
                        '.' => {
                            try std.testing.expectEqual(Token{ .left = 0, .right = 11, .tag = .special_invalid }, lexer.next());
                            try std.testing.expectEqual(Token{ .left = 11, .right = 11, .tag = .special_eof }, lexer.next());
                        },
                        '0' => switch (float[1]) {
                            '.' => {
                                try std.testing.expectEqual(Token{ .left = 0, .right = 11, .tag = .literal_float }, lexer.next());
                                try std.testing.expectEqual(Token{ .left = 11, .right = 11, .tag = .special_eof }, lexer.next());
                            },
                            else => {
                                try std.testing.expectEqual(Token{ .left = 0, .right = 11, .tag = .special_invalid }, lexer.next());
                                try std.testing.expectEqual(Token{ .left = 11, .right = 11, .tag = .special_eof }, lexer.next());
                            },
                        },
                        else => {
                            try std.testing.expectEqual(Token{ .left = 0, .right = 11, .tag = .literal_float }, lexer.next());
                            try std.testing.expectEqual(Token{ .left = 11, .right = 11, .tag = .special_eof }, lexer.next());
                        },
                    },
                }
            }
        }
    }

    {
        {
            var lexer = init(try Reader.Buffer(1024).init("\"string literal\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 16, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 16, .right = 16, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 2, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 2, .right = 2, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"\\\"escaped quotes\\\"\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 20, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 20, .right = 20, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"\\n\\t\\r\\\"\\\\\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 12, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 12, .right = 12, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"unescaped\\\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 12, .tag = .special_invalid }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 12, .right = 12, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"unterminated"));
            try std.testing.expectEqual(Token{ .left = 0, .right = 13, .tag = .special_invalid }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 13, .right = 13, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"\\n\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 4, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 4, .right = 4, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"\\x\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 4, .tag = .special_invalid }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 4, .right = 4, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"one\" \"two\" \"three\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 5, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 6, .right = 11, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 12, .right = 19, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 19, .right = 19, .tag = .special_eof }, lexer.next());
        }

        {
            var lexer = init(try Reader.Buffer(1024).init("\"outer 'inner' quote\""));
            try std.testing.expectEqual(Token{ .left = 0, .right = 21, .tag = .literal_string }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 21, .right = 21, .tag = .special_eof }, lexer.next());
        }
    }
}

test "symbols" {
    {
        var lexer = init(try Reader.Buffer(1024).init("-> : | <>"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 2, .tag = .symbol_arrow }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 3, .right = 4, .tag = .symbol_colon }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 6, .tag = .symbol_pipe }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 7, .right = 9, .tag = .symbol_chain }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 9, .right = 9, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init("->:|<>"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 6, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 6, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init("- > < > : |"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 1, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 2, .right = 3, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 5, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 7, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 8, .right = 9, .tag = .symbol_colon }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 10, .right = 11, .tag = .symbol_pipe }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 11, .right = 11, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init("<- >< |> :>"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 2, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 3, .right = 5, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 8, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 9, .right = 11, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 11, .right = 11, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init("  ->   :  |   <>  "));
        try std.testing.expectEqual(Token{ .left = 2, .right = 4, .tag = .symbol_arrow }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 7, .right = 8, .tag = .symbol_colon }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 10, .right = 11, .tag = .symbol_pipe }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 14, .right = 16, .tag = .symbol_chain }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 18, .right = 18, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init(":-> | <>:"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 3, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 5, .tag = .symbol_pipe }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 9, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 9, .right = 9, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init(":: || ->-> <><>"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 2, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 3, .right = 5, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 10, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 11, .right = 15, .tag = .special_invalid }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 15, .right = 15, .tag = .special_eof }, lexer.next());
    }

    {
        var lexer = init(try Reader.Buffer(1024).init(": : | | -> -> <> <>"));
        try std.testing.expectEqual(Token{ .left = 0, .right = 1, .tag = .symbol_colon }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 2, .right = 3, .tag = .symbol_colon }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 5, .tag = .symbol_pipe }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 7, .tag = .symbol_pipe }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 8, .right = 10, .tag = .symbol_arrow }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 11, .right = 13, .tag = .symbol_arrow }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 14, .right = 16, .tag = .symbol_chain }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 17, .right = 19, .tag = .symbol_chain }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 19, .right = 19, .tag = .special_eof }, lexer.next());
    }
}
