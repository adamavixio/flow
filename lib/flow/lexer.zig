const std = @import("std");

const Self = @This();

left: usize = 0,
right: usize = 0,
input: [:0]const u8,

pub const State = enum {
    init,
    keyword,
    operator,
    literal_int,
    literal_float,
    literal_string,
    invalid,
};

pub const Token = struct {
    left: usize,
    right: usize,
    lexeme: Lexeme,
};

pub const Lexeme = union(enum) {
    keyword: enum {
        file,
        path,
    },
    operator: enum {
        arrow,
        colon,
        pipe,
    },
    literal: enum {
        int,
        float,
        string,
    },
    special: enum {
        invalid,
        eof,
    },
};

pub fn init(input: [:0]const u8) Self {
    return Self{
        .input = input,
    };
}

pub fn next(self: *Self) Token {
    var state: State = .init;
    var lexeme: Lexeme = undefined;

    self.left = self.right;
    while (true) : (self.right += 1) {
        const byte = self.input[self.right];
        switch (state) {
            .init => switch (byte) {
                0 => {
                    lexeme = .{ .special = .eof };
                    break;
                },
                ' ', '\n', '\t', '\r' => {
                    self.left += 1;
                },
                'a'...'z' => {
                    state = .keyword;
                },
                '-', ':', '|' => {
                    state = .operator;
                },
                '0'...'9' => {
                    state = .literal_int;
                },
                '\'' => {
                    state = .literal_string;
                },
                else => {
                    state = .invalid;
                },
            },
            .keyword => switch (byte) {
                'a'...'z' => {
                    continue;
                },
                0, ' ', '\n', '\t', '\r' => {
                    lexeme = blk: {
                        const string = self.input[self.left..self.right];
                        if (std.mem.eql(u8, string, "file")) break :blk .{ .keyword = .file };
                        if (std.mem.eql(u8, string, "path")) break :blk .{ .keyword = .path };
                        break :blk .{ .special = .invalid };
                    };
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .operator => switch (byte) {
                '>' => {
                    continue;
                },
                0, ' ', '\n', '\t', '\r' => {
                    lexeme = blk: {
                        const string = self.input[self.left..self.right];
                        if (std.mem.eql(u8, string, "->")) break :blk .{ .operator = .arrow };
                        if (std.mem.eql(u8, string, ":")) break :blk .{ .operator = .colon };
                        if (std.mem.eql(u8, string, "|")) break :blk .{ .operator = .pipe };
                        break :blk .{ .special = .invalid };
                    };
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .literal_int => switch (byte) {
                '0'...'9' => {
                    continue;
                },
                '.' => {
                    switch (self.input[self.left]) {
                        '0' => switch (self.input[self.left + 1]) {
                            '.' => state = .literal_float,
                            else => state = .invalid,
                        },
                        else => state = .literal_float,
                    }
                    continue;
                },
                0, ' ', '\n', '\t', '\r' => {
                    lexeme = switch (self.input[self.left]) {
                        '0' => .{ .special = .invalid },
                        else => .{ .literal = .int },
                    };
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .literal_float => switch (byte) {
                '0'...'9' => {
                    continue;
                },
                0, ' ', '\n', '\t', '\r' => {
                    lexeme = switch (self.input[self.right - 1]) {
                        '.' => .{ .special = .invalid },
                        else => .{ .literal = .float },
                    };
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .literal_string => switch (byte) {
                '\\' => {
                    self.right += 1;
                    if (self.right == self.input.len or self.input[self.right] != '\'') {
                        lexeme = .{ .special = .invalid };
                        break;
                    }
                },
                '\'' => {
                    self.right += 1;
                    lexeme = .{ .literal = .string };
                    break;
                },
                0 => {
                    lexeme = .{ .special = .invalid };
                    break;
                },
                else => {
                    continue;
                },
            },
            .invalid => switch (byte) {
                0, ' ', '\n', '\t', '\r' => {
                    lexeme = .{ .special = .invalid };
                    break;
                },
                else => {
                    continue;
                },
            },
        }
    }

    return Token{
        .left = self.left,
        .right = self.right,
        .lexeme = lexeme,
    };
}

test "keyword" {
    {
        var lexer = init("file path");
        try std.testing.expectEqual(Token{ .left = 0, .right = 4, .lexeme = .{ .keyword = .file } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 9, .lexeme = .{ .keyword = .path } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 9, .right = 9, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" file path");
        try std.testing.expectEqual(Token{ .left = 1, .right = 5, .lexeme = .{ .keyword = .file } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 10, .lexeme = .{ .keyword = .path } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 10, .right = 10, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("file path ");
        try std.testing.expectEqual(Token{ .left = 0, .right = 4, .lexeme = .{ .keyword = .file } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 9, .lexeme = .{ .keyword = .path } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 10, .right = 10, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("filepath");
        try std.testing.expectEqual(Token{ .left = 0, .right = 8, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 8, .right = 8, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" filepath");
        try std.testing.expectEqual(Token{ .left = 1, .right = 9, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 9, .right = 9, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("filepath ");
        try std.testing.expectEqual(Token{ .left = 0, .right = 8, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 9, .right = 9, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" filepath ");
        try std.testing.expectEqual(Token{ .left = 1, .right = 9, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 10, .right = 10, .lexeme = .{ .special = .eof } }, lexer.next());
    }
}

test "operator" {
    {
        var lexer = init("-> : |");
        try std.testing.expectEqual(Token{ .left = 0, .right = 2, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 3, .right = 4, .lexeme = .{ .operator = .colon } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 6, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" -> : |");
        try std.testing.expectEqual(Token{ .left = 1, .right = 3, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 5, .lexeme = .{ .operator = .colon } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 7, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("-> : | ");
        try std.testing.expectEqual(Token{ .left = 0, .right = 2, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 3, .right = 4, .lexeme = .{ .operator = .colon } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 6, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" -> : | ");
        try std.testing.expectEqual(Token{ .left = 1, .right = 3, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 5, .lexeme = .{ .operator = .colon } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 7, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 8, .right = 8, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("->: |");
        try std.testing.expectEqual(Token{ .left = 0, .right = 3, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 5, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 5, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" ->: |");
        try std.testing.expectEqual(Token{ .left = 1, .right = 4, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 6, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("->: | ");
        try std.testing.expectEqual(Token{ .left = 0, .right = 3, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 5, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" ->: | ");
        try std.testing.expectEqual(Token{ .left = 1, .right = 4, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 6, .lexeme = .{ .operator = .pipe } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("-> :|");
        try std.testing.expectEqual(Token{ .left = 0, .right = 2, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 3, .right = 5, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 5, .right = 5, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" -> :|");
        try std.testing.expectEqual(Token{ .left = 1, .right = 3, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 6, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init("-> :| ");
        try std.testing.expectEqual(Token{ .left = 0, .right = 2, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 3, .right = 5, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" -> :| ");
        try std.testing.expectEqual(Token{ .left = 1, .right = 3, .lexeme = .{ .operator = .arrow } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 4, .right = 6, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(":|::||-->>->->");
        try std.testing.expectEqual(Token{ .left = 0, .right = 14, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 14, .right = 14, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" :|::||-->>->->");
        try std.testing.expectEqual(Token{ .left = 1, .right = 15, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 15, .right = 15, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(":|::||-->>->-> ");
        try std.testing.expectEqual(Token{ .left = 0, .right = 14, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 15, .right = 15, .lexeme = .{ .special = .eof } }, lexer.next());
    }

    {
        var lexer = init(" :|::||-->>->-> ");
        try std.testing.expectEqual(Token{ .left = 1, .right = 15, .lexeme = .{ .special = .invalid } }, lexer.next());
        try std.testing.expectEqual(Token{ .left = 16, .right = 16, .lexeme = .{ .special = .eof } }, lexer.next());
    }
}

test "literal" {
    {
        {
            const numbers = "0123456789";
            inline for (0..numbers.len) |i| {
                var lexer = init(numbers[i..] ++ numbers[0..i]);
                switch (i) {
                    0 => {
                        try std.testing.expectEqual(Token{ .left = 0, .right = 10, .lexeme = .{ .special = .invalid } }, lexer.next());
                        try std.testing.expectEqual(Token{ .left = 10, .right = 10, .lexeme = .{ .special = .eof } }, lexer.next());
                    },
                    else => {
                        try std.testing.expectEqual(Token{ .left = 0, .right = 10, .lexeme = .{ .literal = .int } }, lexer.next());
                        try std.testing.expectEqual(Token{ .left = 10, .right = 10, .lexeme = .{ .special = .eof } }, lexer.next());
                    },
                }
            }
        }
    }

    {
        {
            const numbers = "0123456789";
            inline for (0..numbers.len) |i| {
                const rotate = numbers[i..] ++ numbers[0..i];
                inline for (0..rotate.len + 1) |j| {
                    const float = rotate[0..j] ++ "." ++ rotate[j..];
                    var lexer = init(float);
                    switch (float[10]) {
                        '.' => {
                            try std.testing.expectEqual(Token{ .left = 0, .right = 11, .lexeme = .{ .special = .invalid } }, lexer.next());
                            try std.testing.expectEqual(Token{ .left = 11, .right = 11, .lexeme = .{ .special = .eof } }, lexer.next());
                        },
                        else => switch (float[0]) {
                            '.' => {
                                try std.testing.expectEqual(Token{ .left = 0, .right = 11, .lexeme = .{ .special = .invalid } }, lexer.next());
                                try std.testing.expectEqual(Token{ .left = 11, .right = 11, .lexeme = .{ .special = .eof } }, lexer.next());
                            },
                            '0' => switch (float[1]) {
                                '.' => {
                                    try std.testing.expectEqual(Token{ .left = 0, .right = 11, .lexeme = .{ .literal = .float } }, lexer.next());
                                    try std.testing.expectEqual(Token{ .left = 11, .right = 11, .lexeme = .{ .special = .eof } }, lexer.next());
                                },
                                else => {
                                    try std.testing.expectEqual(Token{ .left = 0, .right = 11, .lexeme = .{ .special = .invalid } }, lexer.next());
                                    try std.testing.expectEqual(Token{ .left = 11, .right = 11, .lexeme = .{ .special = .eof } }, lexer.next());
                                },
                            },
                            else => {
                                try std.testing.expectEqual(Token{ .left = 0, .right = 11, .lexeme = .{ .literal = .float } }, lexer.next());
                                try std.testing.expectEqual(Token{ .left = 11, .right = 11, .lexeme = .{ .special = .eof } }, lexer.next());
                            },
                        },
                    }
                }
            }
        }

        {
            var lexer = init("0.123");
            try std.testing.expectEqual(Token{ .left = 0, .right = 5, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 5, .right = 5, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 0.123");
            try std.testing.expectEqual(Token{ .left = 1, .right = 6, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("0.123 ");
            try std.testing.expectEqual(Token{ .left = 0, .right = 5, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 0.123 ");
            try std.testing.expectEqual(Token{ .left = 1, .right = 6, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("12.34");
            try std.testing.expectEqual(Token{ .left = 0, .right = 5, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 5, .right = 5, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 12.34");
            try std.testing.expectEqual(Token{ .left = 1, .right = 6, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("12.34 ");
            try std.testing.expectEqual(Token{ .left = 0, .right = 5, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 12.34 ");
            try std.testing.expectEqual(Token{ .left = 1, .right = 6, .lexeme = .{ .literal = .float } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("01.23");
            try std.testing.expectEqual(Token{ .left = 0, .right = 5, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 5, .right = 5, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 01.23");
            try std.testing.expectEqual(Token{ .left = 1, .right = 6, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("01.23 ");
            try std.testing.expectEqual(Token{ .left = 0, .right = 5, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 6, .right = 6, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 01.23 ");
            try std.testing.expectEqual(Token{ .left = 1, .right = 6, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("1.234.5");
            try std.testing.expectEqual(Token{ .left = 0, .right = 7, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 7, .right = 7, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 1.234.5");
            try std.testing.expectEqual(Token{ .left = 1, .right = 8, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 8, .right = 8, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("1.234.5 ");
            try std.testing.expectEqual(Token{ .left = 0, .right = 7, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 8, .right = 8, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 1.234.5 ");
            try std.testing.expectEqual(Token{ .left = 1, .right = 8, .lexeme = .{ .special = .invalid } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 9, .right = 9, .lexeme = .{ .special = .eof } }, lexer.next());
        }
    }

    {
        {
            var lexer = init("'string literal'");
            try std.testing.expectEqual(Token{ .left = 0, .right = 16, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 16, .right = 16, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 'string literal'");
            try std.testing.expectEqual(Token{ .left = 1, .right = 17, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 17, .right = 17, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("'string literal' ");
            try std.testing.expectEqual(Token{ .left = 0, .right = 16, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 17, .right = 17, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" 'string literal' ");
            try std.testing.expectEqual(Token{ .left = 1, .right = 17, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 18, .right = 18, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("'\\'string\\'literal\\''");
            try std.testing.expectEqual(Token{ .left = 0, .right = 21, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 21, .right = 21, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" '\\'string\\'literal\\''");
            try std.testing.expectEqual(Token{ .left = 1, .right = 22, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 22, .right = 22, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init("'\\'string\\'literal\\'' ");
            try std.testing.expectEqual(Token{ .left = 0, .right = 21, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 22, .right = 22, .lexeme = .{ .special = .eof } }, lexer.next());
        }

        {
            var lexer = init(" '\\'string\\'literal\\'' ");
            try std.testing.expectEqual(Token{ .left = 1, .right = 22, .lexeme = .{ .literal = .string } }, lexer.next());
            try std.testing.expectEqual(Token{ .left = 23, .right = 23, .lexeme = .{ .special = .eof } }, lexer.next());
        }
    }
}
