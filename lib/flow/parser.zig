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
    lexeme: Lexer.Lexeme,
    literal: ?[]const u8,
    children: std.ArrayList(*AST),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, lexeme: Lexer.Lexeme, literal: ?[]const u8) !*AST {
        const ast = try allocator.create(AST);
        ast.* = .{
            .lexeme = lexeme,
            .literal = if (literal) |data| try allocator.dupe(u8, data) else null,
            .children = std.ArrayList(*AST).init(allocator),
            .allocator = allocator,
        };
        return ast;
    }

    pub fn deinit(self: *AST, allocator: std.mem.Allocator) void {
        if (self.literal) |literal| {
            allocator.free(literal);
        }
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
    }
};

pub fn init(allocator: std.mem.Allocator, lexer: Lexer) Self {
    return .{ .lexer = lexer, .allocator = allocator };
}

pub fn parse(self: *Self) !*AST {
    const root = try AST.init(self.allocator, .{ .special = .module }, null);

    while (true) {
        const token = self.lexer.next();
        const child = switch (token.lexeme) {
            .keyword => |lexeme| try self.parseKeyword(lexeme, token),
            .special => |lexeme| switch (lexeme) {
                .eof => break,
                else => {
                    return Error.InvalidSpecialToken;
                },
            },
            else => return Error.InvalidTokenTag,
        };
        try root.children.append(child);
    }

    return root;
}

pub fn parseKeyword(self: *Self, keyword: Lexer.Lexeme.Keyword, token: Lexer.Token) !*AST {
    const root = try AST.init(self.allocator, token.lexeme, self.lexer.read(token));

    var symbol = self.lexer.next();
    try expectSymbol(symbol, .colon);

    while (true) {
        const literal = try self.parseLiteral(keyword, self.lexer.next());
        try root.children.append(literal);

        symbol = self.lexer.next();
        if (!isSymbol(symbol, .chain)) break;
    }

    while (true) {
        const literal = try self.parseOperator(keyword, self.lexer.next());
        try root.children.append(literal);

        symbol = self.lexer.next();
        if (!isSymbol(symbol, .pipe)) break;
    }

    return root;
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
        else => return false,
    }
}

pub fn expectLiteral(token: Lexer.Token, expected: Lexer.Lexeme.Literal) !void {
    if (!isLiteral(token, expected)) return Error.InvalidLiteralToken;
}

pub fn parseLiteral(self: *Self, keyword: Lexer.Lexeme.Keyword, token: Lexer.Token) !*AST {
    try switch (keyword) {
        .int => expectLiteral(token, .int),
        .float => expectLiteral(token, .float),
        .string => expectLiteral(token, .string),
    };
    return try AST.init(self.allocator, token.lexeme, self.lexer.read(token));
}

pub fn isOperator(token: Lexer.Token, expected: Lexer.Lexeme.Operator) bool {
    switch (token.lexeme) {
        .operator => |actual| return expected == actual,
        else => return false,
    }
}

pub fn expectOperator(token: Lexer.Token, expected: Lexer.Lexeme.Operator) !void {
    if (isOperator(token, expected)) return Error.InvalidOperatorToken;
}

pub fn parseOperator(self: *Self, keyword: Lexer.Lexeme.Keyword, token: Lexer.Token) !*AST {
    const declared = switch (token.lexeme) {
        .operator => |operator| switch (keyword) {
            .int => switch (operator) {
                .sort => @hasDecl(Type.Primitive.Int, "sort"),
                .unique => @hasDecl(Type.Primitive.Int, "unique"),
            },
            .float => switch (operator) {
                .sort => @hasDecl(Type.Primitive.Float, "sort"),
                .unique => @hasDecl(Type.Primitive.Float, "unique"),
            },
            .string => switch (operator) {
                .sort => @hasDecl(Type.Primitive.String, "sort"),
                .unique => @hasDecl(Type.Primitive.String, "unique"),
            },
        },
        else => return Error.InvalidTokenTag,
    };

    if (!declared) return Error.InvalidOperatorMethod;
    return try AST.init(self.allocator, token.lexeme, self.lexer.read(token));
}

test "Parse single file expression" {
    const allocator = std.testing.allocator;

    const input = "string : 'test' | sort | unique";
    const lexer = Lexer.init(input);

    var parser = init(allocator, lexer);
    const ast = try parser.parse();
    defer ast.deinit(allocator);
}
