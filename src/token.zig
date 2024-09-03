const std = @import("std");

pub const Tag = enum {
    plus,
    minus,
    asterisk,
    forward_slash,
    int,
    invalid,
    eof,
};

pub const Token = struct {
    tag: Tag,
    lexeme: []const u8,

    pub fn operator(lexeme: []const u8) Token {
        if (lexeme.len != 1) {
            return .{
                .tag = .invalid,
                .lexeme = lexeme,
            };
        }

        return .{
            .tag = switch (lexeme[0]) {
                '+' => .plus,
                '-' => .minus,
                '*' => .asterisk,
                '/' => .forward_slash,
                else => .invalid,
            },
            .lexeme = lexeme,
        };
    }

    pub fn expression(tag: Tag, lexeme: []const u8) Token {
        if (lexeme.len == 0 or tag != .int) {
            return .{
                .tag = .invalid,
                .lexeme = lexeme,
            };
        }

        return .{
            .tag = tag,
            .lexeme = lexeme,
        };
    }

    pub fn special(tag: Tag, lexeme: []const u8) Token {
        return .{
            .tag = tag,
            .lexeme = lexeme,
        };
    }
};

test "token" {
    const Case = struct { tag: Tag, lexeme: []const u8 };

    const operators = [_]Case{
        .{ .tag = .plus, .lexeme = "+" },
        .{ .tag = .minus, .lexeme = "-" },
        .{ .tag = .asterisk, .lexeme = "*" },
        .{ .tag = .forward_slash, .lexeme = "/" },
        .{ .tag = .invalid, .lexeme = "1" },
        .{ .tag = .invalid, .lexeme = "12" },
        .{ .tag = .invalid, .lexeme = "$" },
        .{ .tag = .invalid, .lexeme = "" },
    };

    for (operators) |exp| {
        const got = Token.operator(exp.lexeme);
        try std.testing.expectEqual(exp.tag, got.tag);
        try std.testing.expectEqualStrings(exp.lexeme, got.lexeme);
    }

    const expressions = [_]Case{
        .{ .tag = .invalid, .lexeme = "+" },
        .{ .tag = .invalid, .lexeme = "-" },
        .{ .tag = .invalid, .lexeme = "*" },
        .{ .tag = .invalid, .lexeme = "/" },
        .{ .tag = .int, .lexeme = "1" },
        .{ .tag = .int, .lexeme = "12" },
        .{ .tag = .invalid, .lexeme = "$" },
        .{ .tag = .invalid, .lexeme = "" },
    };

    for (expressions) |exp| {
        const got = Token.expression(exp.tag, exp.lexeme);
        try std.testing.expectEqual(exp.tag, got.tag);
        try std.testing.expectEqualStrings(exp.lexeme, got.lexeme);
    }

    const specials = [_]Case{
        .{ .tag = .invalid, .lexeme = "+" },
        .{ .tag = .invalid, .lexeme = "-" },
        .{ .tag = .invalid, .lexeme = "*" },
        .{ .tag = .invalid, .lexeme = "/" },
        .{ .tag = .invalid, .lexeme = "1" },
        .{ .tag = .invalid, .lexeme = "12" },
        .{ .tag = .invalid, .lexeme = "$" },
        .{ .tag = .invalid, .lexeme = "" },
        .{ .tag = .eof, .lexeme = "" },
    };

    for (specials) |exp| {
        const got = Token.special(exp.tag, exp.lexeme);
        try std.testing.expectEqual(exp.tag, got.tag);
        try std.testing.expectEqualStrings(exp.lexeme, got.lexeme);
    }
}
