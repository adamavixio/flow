const std = @import("std");
const token = @import("token.zig");

pub const State = enum {
    sof,
    operator,
    operator_assert,
    int,
    invalid,
    eof,
};

pub const Location = struct {
    line: usize = 1,
    left: usize = 0,
    right: usize = 0,

    fn shift(self: *Location) void {
        self.left += 1;
        self.right = @max(self.left, self.right);
    }

    fn sync(self: *Location) void {
        self.left = self.right;
    }

    fn scan(self: *Location) void {
        self.right += 1;
    }

    fn jump(self: *Location) void {
        self.line += 1;
    }
};

pub const Lexer = struct {
    input: []const u8,
    state: State = .sof,
    location: Location = Location{},

    pub fn next(self: *Lexer) token.Token {
        // std.debug.print("before\n", .{});
        // std.debug.print("location: {any}\n", .{self.location});
        // std.debug.print("state: {any}\n", .{self.state});
        while (self.location.right < self.input.len and self.state != .eof) {
            const byte = self.input[self.location.right];
            std.debug.print("state: {any}\n", .{self.state});
            std.debug.print("location: {any}\n", .{self.location});
            switch (self.state) {
                .sof => switch (byte) {
                    '\n' => {
                        self.location.jump();
                        self.location.shift();
                    },
                    ' ', '\t', '\r' => {
                        self.location.shift();
                    },
                    '+', '-', '*', '/' => {
                        self.location.scan();
                        self.state = .operator;
                        break;
                    },
                    '0'...'9' => {
                        self.location.scan();
                        self.state = .int;
                    },
                    else => {
                        self.location.scan();
                        self.state = .invalid;
                        break;
                    },
                },
                .operator_assert => switch (byte) {
                    '\n' => {
                        self.location.jump();
                        self.location.scan();
                        self.state = .invalid;
                    },
                    ' ', '\t', '\r' => {
                        self.location.shift();
                    },
                    '0'...'9' => {
                        self.location.scan();
                        self.state = .int;
                    },
                    else => {
                        self.location.scan();
                        self.state = .invalid;
                        break;
                    },
                },
                .int => switch (byte) {
                    ' ', '\n', '\t', '\r' => {
                        break;
                    },
                    '0'...'9' => {
                        self.location.scan();
                    },
                    else => {
                        self.location.scan();
                        self.state = .invalid;
                        break;
                    },
                },
                else => {
                    self.location.scan();
                    self.state = .invalid;
                    break;
                },
            }
            // std.debug.print("after\n", .{});
            // std.debug.print("location: {any}\n", .{self.location});
            // std.debug.print("state: {any}\n\n", .{self.state});
        }

        const lexeme = self.read();
        self.location.sync();

        return switch (self.state) {
            .operator => {
                self.state = .operator_assert;
                return token.operator(
                    lexeme,
                );
            },
            .int => {
                self.state = .sof;
                return token.expression(
                    token.Tag.int,
                    lexeme,
                );
            },
            .invalid => {
                self.state = .sof;
                return token.special(
                    token.Tag.invalid,
                    lexeme,
                );
            },
            else => {
                return token.special(
                    token.Tag.eof,
                    lexeme,
                );
            },
        };
    }

    pub fn read(self: *Lexer) []const u8 {
        return self.input[self.location.left..self.location.right];
    }
};

pub fn init(input: []const u8) Lexer {
    return Lexer{ .input = input };
}

test "lexer" {
    var lexer = init("0 + 1 -2 * 123 $ /+");

    const Case = struct { tag: token.Tag, lexeme: []const u8 };
    const cases = [_]Case{
        .{ .tag = .int, .lexeme = "0" },
        .{ .tag = .plus, .lexeme = "+" },
        .{ .tag = .int, .lexeme = "1" },
        .{ .tag = .minus, .lexeme = "-" },
        .{ .tag = .int, .lexeme = "2" },
        .{ .tag = .asterisk, .lexeme = "*" },
        .{ .tag = .int, .lexeme = "123" },
        .{ .tag = .invalid, .lexeme = "$" },
        .{ .tag = .forward_slash, .lexeme = "/" },
        .{ .tag = .invalid, .lexeme = "+" },
        .{ .tag = .eof, .lexeme = "" },
    };

    for (cases) |exp| {
        const got = lexer.next();
        try std.testing.expectEqual(exp.tag, got.tag);
        try std.testing.expectEqualStrings(exp.lexeme, got.lexeme);
    }
}
