const std = @import("std");
const testing = @import("testing");
const Token = @import("token.zig");

const Lexer = @This();

const State = enum { init, keyword, operator, invalid };
const Lexeme = Token.Lexeme;

left: usize = 0,
right: usize = 0,
input: [:0]const u8,

pub fn init(input: [:0]const u8) Lexer {
    return Lexer{ .input = input };
}

pub fn shift(self: *Lexer) void {
    self.left += 1;
}

pub fn scan(self: *Lexer) void {
    self.right += 1;
}

pub fn slice(self: *Lexer) []const u8 {
    return self.input[self.left..self.right];
}

pub fn next(self: *Lexer) Token {
    var state: State = .init;
    var lexeme: Token.Lexeme = undefined;
    while (true) : (self.scan()) {
        const byte = self.input[self.right];
        switch (state) {
            .init => switch (byte) {
                0 => {
                    lexeme = .{ .special = .eof };
                    break;
                },
                ' ', '\n', '\t', '\r' => {
                    self.shift();
                },
                'a'...'z' => {
                    state = .keyword;
                },
                '-', '|' => {
                    state = .operator;
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
                    if (Lexeme.parseKeyword(self.slice())) |keyword| {
                        lexeme = .{ .keyword = keyword };
                        break;
                    }
                    lexeme = .{ .literal = .string };
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
                    if (Lexeme.parseOperator(self.slice())) |operator| {
                        lexeme = .{ .operator = operator };
                        break;
                    }
                    lexeme = .{ .special = .invalid };
                    break;
                },
                else => {
                    state = .invalid;
                },
            },
            .invalid => switch (byte) {
                0, ' ', '\n', '\t', '\r' => {
                    break;
                },
                else => {
                    continue;
                },
            },
        }
    }

    return self.mint(lexeme);
}

pub fn mint(self: *Lexer, lexeme: Token.Lexeme) Token {
    const left, const right = .{ self.left, self.right };
    self.left = self.right;
    return .{ .left = left, .right = right, .lexeme = lexeme };
}

test "lexer" {
    {
        var lexer = Lexer.init("file path -> |");
        var unit = testing.Unit(Token).static();
        try unit.case(lexer.next(), Token.init(0, 4, .{ .keyword = .file }));
        try unit.case(lexer.next(), Token.init(5, 9, .{ .keyword = .path }));
        try unit.case(lexer.next(), Token.init(10, 12, .{ .operator = .arrow }));
        try unit.case(lexer.next(), Token.init(13, 14, .{ .operator = .pipe }));
        try unit.case(lexer.next(), Token.init(14, 14, .{ .special = .eof }));
        try unit.run();
    }

    {
        var lexer = Lexer.init(" file path -> | ");
        var unit = testing.Unit(Token).static();
        try unit.case(lexer.next(), Token.init(1, 5, .{ .keyword = .file }));
        try unit.case(lexer.next(), Token.init(6, 10, .{ .keyword = .path }));
        try unit.case(lexer.next(), Token.init(11, 13, .{ .operator = .arrow }));
        try unit.case(lexer.next(), Token.init(14, 15, .{ .operator = .pipe }));
        try unit.case(lexer.next(), Token.init(16, 16, .{ .special = .eof }));
        try unit.run();
    }

    {
        var lexer = Lexer.init("string");
        var unit = testing.Unit(Token).static();
        try unit.case(lexer.next(), Token.init(0, 6, .{ .literal = .string }));
        try unit.case(lexer.next(), Token.init(6, 6, .{ .special = .eof }));
        try unit.run();
    }

    {
        var lexer = Lexer.init(" string ");
        var unit = testing.Unit(Token).static();
        try unit.case(lexer.next(), Token.init(1, 7, .{ .literal = .string }));
        try unit.case(lexer.next(), Token.init(8, 8, .{ .special = .eof }));
        try unit.run();
    }
}
