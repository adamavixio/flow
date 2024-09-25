const std = @import("std");
const Lexer = @import("./lexer.zig");

const Self = @This();

token: Lexer.Token,
lexer: Lexer,
allocator: std.mem.Allocator,

pub const Error = error{
    InvalidTokenTag,
    InvalidKeywordToken,
    InvalidSymbolToken,
    InvalidOperatorToken,
    InvalidLiteralToken,
    InvalidSpecialToken,
};

pub const AST = struct {
    lexeme: Lexer.Lexeme,
    literal: []const u8,
    children: std.ArrayList(*AST),

    pub fn init(allocator: std.mem.Allocator, lexer: Lexer, token: Lexer.Token) !*AST {
        const ast = try allocator.create(AST);
        ast.* = .{
            .lexeme = token.lexeme,
            .literal = try allocator.dupe(u8, lexer.input[token.left..token.right]),
            .children = std.ArrayList(*AST).init(allocator),
        };
        return ast;
    }

    pub fn deinit(self: *AST, allocator: std.mem.Allocator) void {
        allocator.free(self.literal);
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
    }

    fn printAST(ast: *const AST, writer: anytype, depth: usize) !void {
        try writer.writeByteNTimes(' ', depth * 2);
        try writer.print("{s}", .{@tagName(ast.lexeme)});
        try writer.print(": \"{s}\"", .{ast.literal});
        try writer.writeByte('\n');

        for (ast.children.items) |child| {
            try printAST(child, writer, depth + 1);
        }
    }
};

pub fn init(allocator: std.mem.Allocator, lexer: Lexer) Self {
    return .{
        .token = .{
            .left = 0,
            .right = 0,
            .lexeme = .{ .special = .module },
        },
        .lexer = lexer,
        .allocator = allocator,
    };
}

pub fn next(self: *Self) void {
    self.token = self.lexer.next();
}

pub fn parse(self: *Self) !*AST {
    const ast = try AST.init(self.allocator, self.lexer, self.token);

    while (true) {
        self.next();
        const child = switch (self.token.lexeme) {
            .keyword => |lexeme| switch (lexeme) {
                .file => try self.parseFile(),
                else => return Error.InvalidKeywordToken,
            },
            .special => |lexeme| switch (lexeme) {
                .invalid => try AST.init(self.allocator, self.lexer, self.token),
                .eof => break,
                else => return Error.InvalidSpecialToken,
            },
            else => return Error.InvalidTokenTag,
        };
        try ast.children.append(child);
    }

    return ast;
}

pub fn parseFile(self: *Self) !*AST {
    const ast = try AST.init(self.allocator, self.lexer, self.token);

    self.next();
    switch (self.token.lexeme) {
        .symbol => |lexeme| switch (lexeme) {
            .colon => {},
            else => return Error.InvalidSymbolToken,
        },
        else => return Error.InvalidTokenTag,
    }

    while (true) {
        self.next();
        const child = switch (self.token.lexeme) {
            .keyword => |lexeme| switch (lexeme) {
                .path => try self.parsePath(),
                else => return Error.InvalidKeywordToken,
            },
            else => return Error.InvalidTokenTag,
        };
        try ast.children.append(child);

        self.next();
        switch (self.token.lexeme) {
            .symbol => |lexeme| switch (lexeme) {
                .arrow => break,
                .chain => continue,
                else => return Error.InvalidSymbolToken,
            },
            else => return Error.InvalidTokenTag,
        }
    }

    self.next();
    const child = switch (self.token.lexeme) {
        .keyword => |lexeme| switch (lexeme) {
            .lines => try self.parseLines(),
            else => return Error.InvalidKeywordToken,
        },
        else => return Error.InvalidTokenTag,
    };
    try ast.children.append(child);

    return ast;
}

pub fn parsePath(self: *Self) !*AST {
    const ast = try AST.init(self.allocator, self.lexer, self.token);

    self.next();
    const child = switch (self.token.lexeme) {
        .literal => |lexeme| switch (lexeme) {
            .string => try AST.init(self.allocator, self.lexer, self.token),
            else => return Error.InvalidLiteralToken,
        },
        else => return Error.InvalidTokenTag,
    };
    try ast.children.append(child);

    return ast;
}

pub fn parseLines(self: *Self) !*AST {
    const ast = try AST.init(self.allocator, self.lexer, self.token);

    while (true) {
        self.next();
        switch (self.token.lexeme) {
            .symbol => |lexeme| switch (lexeme) {
                .pipe => {},
                else => break,
            },
            .special => |lexeme| switch (lexeme) {
                .eof => break,
                else => return Error.InvalidSpecialToken,
            },
            else => return Error.InvalidTokenTag,
        }

        self.next();
        const child = switch (self.token.lexeme) {
            .operator => |lexeme| switch (lexeme) {
                .sort => try AST.init(self.allocator, self.lexer, self.token),
                else => return Error.InvalidOperatorToken,
            },
            else => return Error.InvalidTokenTag,
        };
        try ast.children.append(child);
    }

    return ast;
}

pub fn parseString(self: *Self) !*AST {
    const ast = try AST.init(self.allocator, self.lexer, self.token);
    while (true) {
        self.next();
        const child = switch (self.token.lexeme) {
            .symbol => |lexeme| switch (lexeme) {
                .pipe => try self.parseStringOperator(),
                else => return Error.InvalidSymbolToken,
            },
            else => return Error.InvalidTokenTag,
        };
        try ast.children.append(child);
    }
    return ast;
}

pub fn parseStringOperator(self: *Self) !*AST {
    const ast = try AST.init(self.allocator, self.lexer, self.token);
    while (true) {
        try self.next();
        const child = switch (self.token.lexeme) {
            .operator => |lexeme| switch (lexeme) {
                .pipe => try self.parseStringOperator(),
                else => return Error.InvalidSymbolToken,
            },
            else => return Error.InvalidTokenTag,
        };
        try ast.children.append(child);
    }
    return ast;
}

fn print(self: *Self) ![]u8 {
    var root = try self.parse();
    defer root.deinit(self.allocator);

    var list = std.ArrayList(u8).init(self.allocator);
    defer list.deinit();

    try root.printAST(list.writer(), 1);
    return list.toOwnedSlice();
}

test "Parse single file expression" {
    const allocator = std.testing.allocator;

    const input = "file : path 'path_1' <> path 'path_2' -> lines | sort";
    const lexer = Lexer.init(input);
    var parser = init(allocator, lexer);

    const output = try parser.print();
    defer allocator.free(output);

    std.debug.print("{s}", .{output});
}
