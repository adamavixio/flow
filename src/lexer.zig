const std = @import("std");

const Self = @This();

index: usize,
buffer: [:0]const u8,

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

pub const Token = union(enum) {
    keyword: Keyword,
    symbol: Symbol,
    operator: Operator,
    literal: Literal,
    special: Special,

    const Keyword = union(enum) {
        uint: Location,
        u8: Location,
        u16: Location,
        u32: Location,
        u64: Location,
        u128: Location,
        int: Location,
        i8: Location,
        i16: Location,
        i32: Location,
        i64: Location,
        i128: Location,
        f16: Location,
        f32: Location,
        f64: Location,
        f80: Location,
        f128: Location,
        string: Location,
    };

    const Symbol = union(enum) {
        colon: Location,
    };

    const Operator = union(enum) {
        arrow: Location,
        chain: Location,
        pipe: Location,
    };

    const Literal = union(enum) {
        int: Location,
        float: Location,
        string: Location,
        identifier: Location,
    };

    const Special = union(enum) {
        module: Location,
        invalid: Location,
        eof: Location,
    };

    pub const Tag = std.meta.FieldEnum(Token);

    pub fn TagType(tag: Tag) type {
        return std.meta.FieldType(Token, tag);
    }

    pub fn Lexeme(tag: Tag) type {
        return std.meta.FieldEnum(TagType(tag));
    }

    pub const keywords = std.StaticStringMap(Lexeme(.keyword)).initComptime(.{
        .{ "u8", .u8 },
        .{ "u16", .u16 },
        .{ "u32", .u32 },
        .{ "u64", .u64 },
        .{ "u128", .u128 },
        .{ "uint", .uint },
        .{ "i8", .i8 },
        .{ "i16", .i16 },
        .{ "i32", .i32 },
        .{ "i64", .i64 },
        .{ "i128", .i128 },
        .{ "int", .int },
        .{ "f16", .f16 },
        .{ "f32", .f32 },
        .{ "f64", .f64 },
        .{ "f80", .f80 },
        .{ "f128", .f128 },
        .{ "string", .string },
    });

    pub fn init(comptime tag: Tag, comptime lexeme: Lexeme(tag), location: Location) Token {
        return @unionInit(Token, @tagName(tag), @unionInit(TagType(tag), @tagName(type_tag), location));
    }

    pub fn initString(string: []const u8, location: Location) Token {
        if (keywords.get(string)) |keyword| switch (keyword) {
            inline else => |value| return Token.init(.keyword, value, location),
        };
        return Token.init(.literal, .identifier, location);
    }
};

pub const Location = struct {
    left: usize,
    right: usize,

    pub fn init(left: usize, right: usize) Location {
        return .{
            .left = left,
            .right = right,
        };
    }
};

pub fn init(buffer: [:0]const u8) Self {
    return .{
        .index = 0,
        .buffer = buffer,
    };
}

pub fn next(self: *Self) Token {
    var state = State.init;
    var location = Location.init(self.index, undefined);
    while (true) {
        switch (state) {
            .init => switch (self.buffer[self.index]) {
                0 => {
                    location.right = self.index;
                    return Token.init(.special, .eof, location);
                },
                'a'...'z' => {
                    self.index += 1;
                    state = .character;
                },
                '0' => {
                    self.index += 1;
                    state = .zero;
                },
                '1'...'9' => {
                    self.index += 1;
                    state = .number;
                },
                '"' => {
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
                    location.left = self.index;
                },
                else => {
                    state = .invalid;
                },
            },
            .character => switch (self.buffer[self.index]) {
                'a'...'z' => {
                    self.index += 1;
                },
                0, ' ', '\n', '\t', '\r' => {
                    location.right = self.index;
                    return Token.initString(self.read(location), location);
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
                    location.right = self.index;
                    return Token.init(.literal, .int, location);
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
                    location.right = self.index;
                    return Token.init(.literal, .float, location);
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
                '"' => {
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
                '\\', 'n', 't', 'r', '"' => {
                    self.index += 1;
                    state = .quote;
                },
                else => {
                    state = .invalid;
                },
            },
            .quote_quote => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    location.right = self.index;
                    return Token.init(.literal, .string, location);
                },
                else => {
                    state = .invalid;
                },
            },
            .colon => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    location.right = self.index;
                    return Token.init(.symbol, .colon, location);
                },
                else => {
                    state = .invalid;
                },
            },
            .pipe => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    location.right = self.index;
                    return Token.init(.operator, .pipe, location);
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
                    location.right = self.index;
                    return Token.init(.operator, .chain, location);
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
                    location.right = self.index;
                    return Token.init(.operator, .arrow, location);
                },
                else => {
                    state = .invalid;
                },
            },
            .invalid => switch (self.buffer[self.index]) {
                0, ' ', '\n', '\t', '\r' => {
                    location.right = self.index;
                    return Token.init(.special, .invalid, location);
                },
                else => {
                    self.index += 1;
                },
            },
        }
    }
}

pub fn read(self: Self, location: Location) []const u8 {
    return self.buffer[location.left..location.right];
}

test "whitespace" {
    {
        var lexer = init(" \n\t\r");
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(4, 4)), lexer.next());
    }
}

test "keywords" {
    {
        var lexer = init("int intx int!");
        try std.testing.expectEqual(Token.init(.keyword, .int, Location.init(0, 3)), lexer.next());
        try std.testing.expectEqual(Token.init(.literal, .identifier, Location.init(4, 8)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(9, 13)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(13, 13)), lexer.next());
    }

    {
        var lexer = init("float floatx float!");
        try std.testing.expectEqual(Token.init(.keyword, .float, Location.init(0, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(.literal, .identifier, Location.init(6, 12)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(13, 19)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(19, 19)), lexer.next());
    }

    {
        var lexer = init("string stringx string!");
        try std.testing.expectEqual(Token.init(.keyword, .string, Location.init(0, 6)), lexer.next());
        try std.testing.expectEqual(Token.init(.literal, .identifier, Location.init(7, 14)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(15, 22)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(22, 22)), lexer.next());
    }
}

test "literals" {
    {
        const numbers = "0123456789";
        inline for (0..numbers.len) |i| {
            var lexer = init(numbers[i..] ++ numbers[0..i]);
            switch (i) {
                0 => {
                    try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 10)), lexer.next());
                    try std.testing.expectEqual(Token.init(.special, .eof, Location.init(10, 10)), lexer.next());
                },
                else => {
                    try std.testing.expectEqual(Token.init(.literal, .int, Location.init(0, 10)), lexer.next());
                    try std.testing.expectEqual(Token.init(.special, .eof, Location.init(10, 10)), lexer.next());
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
                        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 11)), lexer.next());
                        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(11, 11)), lexer.next());
                    },
                    else => switch (float[0]) {
                        '.' => {
                            try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 11)), lexer.next());
                            try std.testing.expectEqual(Token.init(.special, .eof, Location.init(11, 11)), lexer.next());
                        },
                        '0' => switch (float[1]) {
                            '.' => {
                                try std.testing.expectEqual(Token.init(.literal, .float, Location.init(0, 11)), lexer.next());
                                try std.testing.expectEqual(Token.init(.special, .eof, Location.init(11, 11)), lexer.next());
                            },
                            else => {
                                try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 11)), lexer.next());
                                try std.testing.expectEqual(Token.init(.special, .eof, Location.init(11, 11)), lexer.next());
                            },
                        },
                        else => {
                            try std.testing.expectEqual(Token.init(.literal, .float, Location.init(0, 11)), lexer.next());
                            try std.testing.expectEqual(Token.init(.special, .eof, Location.init(11, 11)), lexer.next());
                        },
                    },
                }
            }
        }
    }

    {
        var lexer = init("\"string literal\"");
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(0, 16)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(16, 16)), lexer.next());
    }

    {
        var lexer = init("\"\"");
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(2, 2)), lexer.next());
    }

    {
        var lexer = init("\"\\\"escaped quotes\\\"\"");
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(0, 20)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(20, 20)), lexer.next());
    }

    {
        var lexer = init("\"\\n\\t\\r\\\"\\\\\"");
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(0, 12)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(12, 12)), lexer.next());
    }

    {
        var lexer = init("\"unescaped\\\"");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 12)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(12, 12)), lexer.next());
    }

    {
        var lexer = init("\"unterminated");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 13)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(13, 13)), lexer.next());
    }

    {
        var lexer = init("\"\\n\"");
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(0, 4)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(4, 4)), lexer.next());
    }

    {
        var lexer = init("\"\\x\"");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 4)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(4, 4)), lexer.next());
    }

    {
        var lexer = init("\"one\" \"two\" \"three\"");
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(0, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(6, 11)), lexer.next());
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(12, 19)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(19, 19)), lexer.next());
    }

    {
        var lexer = init("\"outer 'inner' quote\"");
        try std.testing.expectEqual(Token.init(.literal, .string, Location.init(0, 21)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(21, 21)), lexer.next());
    }
}

test "symbols" {
    {
        var lexer = init("-> : | <>");
        try std.testing.expectEqual(Token.init(.operator, .arrow, Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(.symbol, .colon, Location.init(3, 4)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .pipe, Location.init(5, 6)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .chain, Location.init(7, 9)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(9, 9)), lexer.next());
    }

    {
        var lexer = init("->:|<>");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 6)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(6, 6)), lexer.next());
    }

    {
        var lexer = init("- > < > : |");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 1)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(2, 3)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(4, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(6, 7)), lexer.next());
        try std.testing.expectEqual(Token.init(.symbol, .colon, Location.init(8, 9)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .pipe, Location.init(10, 11)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(11, 11)), lexer.next());
    }

    {
        var lexer = init("<- >< |> :>");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(3, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(6, 8)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(9, 11)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(11, 11)), lexer.next());
    }

    {
        var lexer = init("  ->   :  |   <>  ");
        try std.testing.expectEqual(Token.init(.operator, .arrow, Location.init(2, 4)), lexer.next());
        try std.testing.expectEqual(Token.init(.symbol, .colon, Location.init(7, 8)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .pipe, Location.init(10, 11)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .chain, Location.init(14, 16)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(18, 18)), lexer.next());
    }

    {
        var lexer = init(":-> | <>:");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 3)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .pipe, Location.init(4, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(6, 9)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(9, 9)), lexer.next());
    }

    {
        var lexer = init(":: || ->-> <><>");
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(0, 2)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(3, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(6, 10)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .invalid, Location.init(11, 15)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(15, 15)), lexer.next());
    }

    {
        var lexer = init(": : | | -> -> <> <>");
        try std.testing.expectEqual(Token.init(.symbol, .colon, Location.init(0, 1)), lexer.next());
        try std.testing.expectEqual(Token.init(.symbol, .colon, Location.init(2, 3)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .pipe, Location.init(4, 5)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .pipe, Location.init(6, 7)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .arrow, Location.init(8, 10)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .arrow, Location.init(11, 13)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .chain, Location.init(14, 16)), lexer.next());
        try std.testing.expectEqual(Token.init(.operator, .chain, Location.init(17, 19)), lexer.next());
        try std.testing.expectEqual(Token.init(.special, .eof, Location.init(19, 19)), lexer.next());
    }
}
