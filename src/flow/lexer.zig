const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const flow = lib.flow;
const io = lib.io;

pub const Lexer = @This();

index: usize,
source: io.Source,

pub const State = enum {
    start,
    identifier,
    zero,
    number,
    number_period,
    float,
    // quote,
    // quote_back_slash,
    // quote_quote,
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
};

pub fn init(source: io.Source) Lexer {
    return .{
        .index = 0,
        .source = source,
    };
}

pub fn next(self: *Lexer) flow.Token {
    var token = flow.Token{
        .tag = undefined,
        .start = self.index,
        .end = undefined,
    };
    state: switch (State.start) {
        .start => switch (self.source.buffer[self.index]) {
            ' ', '\n', '\t', '\r' => {
                self.index += 1;
                token.start = self.index;
                continue :state .start;
            },
            'a'...'z' => {
                self.index += 1;
                continue :state .identifier;
            },
            '0' => {
                self.index += 1;
                continue :state .zero;
            },
            '1'...'9' => {
                self.index += 1;
                continue :state .number;
            },
            // '\'' => {
            //     self.index += 1;
            //     continue :state .quote;
            // },
            '+' => {
                self.index += 1;
                continue :state .plus;
            },
            '-' => {
                self.index += 1;
                continue :state .hyphen;
            },
            '*' => {
                self.index += 1;
                continue :state .asterisk;
            },
            '/' => {
                self.index += 1;
                continue :state .forward_slash;
            },
            ':' => {
                self.index += 1;
                continue :state .colon;
            },
            '|' => {
                self.index += 1;
                continue :state .pipe;
            },
            '<' => {
                self.index += 1;
                continue :state .left_angle;
            },
            0 => token.tag = .end_of_frame,
            else => continue :state .invalid,
        },
        .identifier => switch (self.source.buffer[self.index]) {
            'a'...'z' => {
                self.index += 1;
                continue :state .identifier;
            },
            '0'...'9' => {
                self.index += 1;
                continue :state .identifier;
            },
            0, ' ', '\n', '\t', '\r' => token.tag = .identifier,
            else => continue :state .invalid,
        },
        .zero => switch (self.source.buffer[self.index]) {
            '.' => {
                self.index += 1;
                continue :state .number_period;
            },
            else => {
                continue :state .invalid;
            },
        },
        .number => switch (self.source.buffer[self.index]) {
            '0'...'9' => {
                self.index += 1;
                continue :state .number;
            },
            '.' => {
                self.index += 1;
                continue :state .number_period;
            },
            0, ' ', '\n', '\t', '\r' => token.tag = .int,
            else => continue :state .invalid,
        },
        .number_period => switch (self.source.buffer[self.index]) {
            '0'...'9' => {
                self.index += 1;
                continue :state .float;
            },
            else => continue :state .invalid,
        },
        .float => switch (self.source.buffer[self.index]) {
            '0'...'9' => {
                self.index += 1;
                continue :state .float;
            },
            0, ' ', '\n', '\t', '\r' => token.tag = .float,
            else => continue :state .invalid,
        },
        // .quote => switch (self.source.buffer[self.index]) {
        //     '\\' => {
        //         self.index += 1;
        //         continue :state .quote_back_slash;
        //     },
        //     '\'' => {
        //         self.index += 1;
        //         continue :state .quote_quote;
        //     },
        //     0 => {
        //         continue :state .invalid;
        //     },
        //     else => {
        //         self.index += 1;
        //     },
        // },
        // .quote_back_slash => switch (self.source.buffer[self.index]) {
        //     '\\', 'n', 't', 'r', '\'' => {
        //         self.index += 1;
        //         continue :state .quote;
        //     },
        //     else => {
        //         continue :state .invalid;
        //     },
        // },
        // .quote_quote => switch (self.source.buffer[self.index]) {
        //     0, ' ', '\n', '\t', '\r' => {
        //         token.tag = .string;
        //
        //     },
        //     else => {
        //         continue :state .invalid;
        //     },
        // },
        .plus => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .plus,
            else => continue :state .invalid,
        },
        .hyphen => switch (self.source.buffer[self.index]) {
            '>' => {
                self.index += 1;
                continue :state .hyphen_right_angle;
            },
            0, ' ', '\n', '\t', '\r' => token.tag = .minus,
            else => continue :state .invalid,
        },
        .hyphen_right_angle => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .arrow,
            else => continue :state .invalid,
        },
        .asterisk => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .multiply,
            else => continue :state .invalid,
        },
        .forward_slash => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .divide,
            else => continue :state .invalid,
        },
        .colon => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .colon,
            else => continue :state .invalid,
        },
        .pipe => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .pipe,
            else => continue :state .invalid,
        },
        .left_angle => switch (self.source.buffer[self.index]) {
            '>' => {
                self.index += 1;
                continue :state .left_angle_right_angle;
            },
            else => continue :state .invalid,
        },
        .left_angle_right_angle => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .chain,
            else => continue :state .invalid,
        },
        .invalid => switch (self.source.buffer[self.index]) {
            0, ' ', '\n', '\t', '\r' => token.tag = .invalid,
            else => {
                self.index += 1;
                continue :state .invalid;
            },
        },
    }

    token.end = self.index;
    return token;
}

pub fn tokenize(self: *Lexer, allocator: mem.Allocator) ![]flow.Token {
    var tokens = std.ArrayList(flow.Token).init(allocator);
    defer tokens.deinit();

    while (true) {
        const token = self.next();
        try tokens.append(token);
        if (token.tag == .end_of_frame) break;
    }

    return tokens.toOwnedSlice();
}

test "identifiers" {
    const allocator = testing.allocator;

    // base
    {
        var source = try io.Source.initString(allocator, "abc123zyz");
        defer source.deinit(testing.allocator);

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            flow.Token{ .tag = .identifier, .start = 0, .end = source.buffer.len },
            lexer.next(),
        );
        try testing.expectEqual(
            flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
            lexer.next(),
        );
    }

    // whitespace
    {
        var source = try io.Source.initString(allocator, " abc123zyz ");
        defer source.deinit(testing.allocator);

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            flow.Token{ .tag = .identifier, .start = 1, .end = source.buffer.len - 1 },
            lexer.next(),
        );
        try testing.expectEqual(
            flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
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

            // base
            {
                var source = try io.Source.initString(allocator, numbers[i..] ++ numbers[0..i]);
                defer source.deinit(testing.allocator);

                var lexer = Lexer.init(source);
                try testing.expectEqual(
                    flow.Token{ .tag = tag, .start = 0, .end = source.buffer.len },
                    lexer.next(),
                );
                try testing.expectEqual(
                    flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                    lexer.next(),
                );
            }

            // whitespace
            {
                var source = try io.Source.initString(allocator, " " ++ numbers[i..] ++ numbers[0..i] ++ " ");
                defer source.deinit(testing.allocator);

                var lexer = Lexer.init(source);
                try testing.expectEqual(
                    flow.Token{ .tag = tag, .start = 1, .end = source.buffer.len - 1 },
                    lexer.next(),
                );
                try testing.expectEqual(
                    flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
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

                // base
                {
                    var source = try io.Source.initString(allocator, rotated[0..j] ++ "." ++ rotated[j..]);
                    defer source.deinit(testing.allocator);

                    var lexer = Lexer.init(source);
                    try testing.expectEqual(
                        flow.Token{ .tag = tag, .start = 0, .end = source.buffer.len },
                        lexer.next(),
                    );
                    try testing.expectEqual(
                        flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                        lexer.next(),
                    );
                }

                // whitespace
                {
                    var source = try io.Source.initString(allocator, " " ++ rotated[0..j] ++ "." ++ rotated[j..] ++ " ");
                    defer source.deinit(testing.allocator);

                    var lexer = Lexer.init(source);
                    try testing.expectEqual(
                        flow.Token{ .tag = tag, .start = 1, .end = source.buffer.len - 1 },
                        lexer.next(),
                    );
                    try testing.expectEqual(
                        flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                        lexer.next(),
                    );
                }
            }
        }
    }

    // // String tests
    // {
    //     // base
    //     {
    //         var source = try io.Source.initString(allocator, "'string'");
    //         defer source.deinit(testing.allocator);

    //         var lexer = init(source);
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .string, .start = 0, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //     }

    //     // Empty
    //     {
    //         var source = try io.Source.initString(allocator, "''");
    //         defer source.deinit(testing.allocator);

    //         var lexer = init(source);
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .string, .start = 0, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //     }

    //     // Escaped Quotes
    //     {
    //         var source = try io.Source.initString(allocator, "'\\'escaped quotes\\''");
    //         defer source.deinit(testing.allocator);

    //         var lexer = init(source);
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .string, .start = 0, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //     }

    //     // Escaped Characters
    //     {
    //         var source = try io.Source.initString(allocator, "'\\n\\t\\r\\'\\\\'");
    //         defer source.deinit(testing.allocator);

    //         var lexer = init(source);
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .string, .start = 0, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //     }

    //     // Invalid Escapes
    //     {
    //         var source = try io.Source.initString(allocator, "'\\x'");
    //         defer source.deinit(testing.allocator);

    //         var lexer = init(source);
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .invalid, .start = 0, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //         try testing.expectEqual(
    //             flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
    //             lexer.next(),
    //         );
    //     }
    // }
}

test "operators" {
    const allocator = testing.allocator;

    // plus
    {
        // base
        {
            var source = try io.Source.initString(allocator, "+");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .plus, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " + ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .plus, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }

    // minus
    {
        // base
        {
            var source = try io.Source.initString(allocator, "-");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .minus, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " - ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .minus, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }

    // multiply
    {
        // base
        {
            var source = try io.Source.initString(allocator, "*");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .multiply, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " * ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .multiply, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }

    // divide
    {
        // base
        {
            var source = try io.Source.initString(allocator, "/");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .divide, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " / ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .divide, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }

    // arrow
    {
        // base
        {
            var source = try io.Source.initString(allocator, "->");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .arrow, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " -> ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .arrow, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // // split
        // {
        //     var source = try io.Source.initString(allocator, "- >");
        //     defer source.deinit(testing.allocator);

        //     var lexer = Lexer.init(source);
        //     try testing.expectEqual(
        //         flow.Token{ .tag = .invalid, .start = 0, .end = 1 },
        //         lexer.next(),
        //     );
        //     try testing.expectEqual(
        //         flow.Token{ .tag = .invalid, .start = 2, .end = source.buffer.len },
        //         lexer.next(),
        //     );
        //     try testing.expectEqual(
        //         flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
        //         lexer.next(),
        //     );
        // }
    }

    // Chain
    {
        // base
        {
            var source = try io.Source.initString(allocator, "<>");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .chain, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " <> ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .chain, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // split
        {
            var source = try io.Source.initString(allocator, "< >");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .invalid, .start = 0, .end = 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .invalid, .start = 2, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }

    // Colon
    {
        // base
        {
            var source = try io.Source.initString(allocator, ":");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .colon, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " : ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .colon, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }

    // Pipe
    {
        // base
        {
            var source = try io.Source.initString(allocator, "|");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .pipe, .start = 0, .end = source.buffer.len },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " | ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .pipe, .start = 1, .end = source.buffer.len - 1 },
                lexer.next(),
            );
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }
}

test "specials" {
    const allocator = testing.allocator;

    // New Line
    {
        // base
        {
            var source = try io.Source.initString(allocator, " \t\r\n\t ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }

        // whitespace
        {
            var source = try io.Source.initString(allocator, " \t\r\n\t ");
            defer source.deinit(testing.allocator);

            var lexer = Lexer.init(source);
            try testing.expectEqual(
                flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
                lexer.next(),
            );
        }
    }
}

test "whitespace" {
    const allocator = testing.allocator;

    // base
    {
        var source = try io.Source.initString(allocator, " \t \r");
        defer source.deinit(testing.allocator);

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
            lexer.next(),
        );
    }

    // Empty
    {
        var source = try io.Source.initString(allocator, "");
        defer source.deinit(testing.allocator);

        var lexer = Lexer.init(source);
        try testing.expectEqual(
            flow.Token{ .tag = .end_of_frame, .start = source.buffer.len, .end = source.buffer.len },
            lexer.next(),
        );
    }
}
