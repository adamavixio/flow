const std = @import("std");

const Type = @import("type");
const Lexer = @import("./lexer.zig");

const Self = @This();

lexer: Lexer,
allocator: std.mem.Allocator,

pub const Error = error{
    InvalidTokenTag,
    InvalidKeywordToken,
    InvalidSymbolToken,
    InvalidOperatorToken,
    InvalidLiteralToken,
    InvalidSpecialToken,
    InvalidOperatorMethod,
};

pub const AST = struct {
    token: Lexer.Token,
    children: std.ArrayList(*AST),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, token: Lexer.Token) !*AST {
        const ast = try allocator.create(AST);
        ast.* = .{
            .token = token,
            .children = std.ArrayList(*AST).init(allocator),
            .allocator = allocator,
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

    pub fn append(self: *AST, allocator: std.mem.Allocator, token: Lexer.Token) !void {
        const child = try self.init(allocator, token);
        try self.children.append(child);
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

pub fn next(self: *Self) !*AST {
    return try AST.init(self.allocator, self.lexer.next());
}

pub fn parse(self: *Self) !*AST {
    const root = try AST.init(self.allocator, self.lexer.next());

    while (true) {
        const token = self.lexer.next();
        const child = switch (token.lexeme) {
            .keyword => |lexeme| try parseKeyword(lexeme, token),
            .special => |lexeme| switch (lexeme) {
                .eof => break,
                else => return Error.InvalidSpecialToken,
            },
            else => return Error.InvalidTokenTag,
        };
        try root.append(self.allocator, child);
    }

    return root;
}

pub fn parseKeyword(self: *Self, keyword: Lexer.Lexeme.Keyword, token: Lexer.Token) !*AST {
    const root = try AST.init(self.allocator, token);

    var symbol = self.lexer.next();
    try expectSymbol(self.lexer.next(), .colon);

    while (true) {
        const literal = try parseLiteral(keyword, token);
        try root.append(self.allocator, literal);

        symbol = self.lexer.next();
        if (!isSymbol(symbol, .chain)) break;
    }

    while (true) {
        const literal = try parseLiteral(self.lexer.next(), keyword);
        try root.append(self.allocator, literal);
    }
}

pub fn isSymbol(token: Lexer.Token, expected: Lexer.Lexeme.Symbol) bool {
    switch (token.lexeme) {
        .symbol => |actual| return expected == actual,
        else => return false,
    }
}

pub fn expectSymbol(token: Lexer.Token, expected: Lexer.Lexeme.Symbol) !void {
    if (!isSymbol(token, expected)) return Error.InvalidSymbolToken;
}

pub fn isLiteral(token: Lexer.Token, expected: Lexer.Lexeme.Literal) bool {
    switch (token.lexeme) {
        .literal => |actual| return expected == actual,
        else => false,
    }
}

pub fn expectLiteral(token: Lexer.Token, expected: Lexer.Lexeme.Literal) !void {
    if (isLiteral(token, expected)) return Error.InvalidLiteralToken;
}

pub fn parseLiteral(self: *Self, keyword: Lexer.Lexeme.Keyword, token: Lexer.Token) !*AST {
    try switch (keyword) {
        .int => expectLiteral(token.lexeme, .int),
        .float => expectLiteral(token.lexeme, .float),
        .string => expectLiteral(token.lexeme, .string),
    };
    return try AST.init(self.allocator, token);
}

pub fn isOperator(token: Lexer.Token, expected: Lexer.Lexeme.Operator) bool {
    switch (token.lexeme) {
        .operator => |actual| return expected == actual,
        else => false,
    }
}

pub fn expectOperator(token: Lexer.Token, expected: Lexer.Lexeme.Operator) !void {
    if (isOperator(token, expected)) return Error.InvalidOperatorToken;
}

pub fn parseOperator(self: *Self, keyword: Lexer.Lexeme.Keyword, token: Lexer.Token) !*AST {
    const declared = switch (keyword) {
        .int => @hasDecl(Type.Primitive.Int, @tagName(token.lexeme)),
        .float => @hasDecl(Type.Primitive.Float, @tagName(token.lexeme)),
        .string => @hasDecl(Type.Primitive.String, @tagName(token.lexeme)),
    };
    if (!declared) return Error.InvalidOperatorMethod;
    return try AST.init(self.allocator, token);
}

test "Parse single file expression" {
    const allocator = std.testing.allocator;

    const input = "string : 'test' | sort | unique";
    const lexer = Lexer.init(input);

    var parser = init(allocator, lexer);
    const ast = try parser.parse();
    defer ast.deinit(allocator);
}
