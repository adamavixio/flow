const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const io = lib.io;
const flow = lib.flow;

const Parser = @This();

token: flow.Token,
lexer: *flow.Lexer,
allocator: mem.Allocator,

pub const Error = error{
    InvalidToken,
    InvalidStatement,
    EmptyStack,
} || mem.Allocator.Error;

pub fn init(allocator: mem.Allocator, lexer: *flow.Lexer) Parser {
    return .{
        .token = lexer.next(),
        .lexer = lexer,
        .allocator = allocator,
    };
}

pub fn parse(self: *Parser) ![]*flow.AST.Statement {
    var statements = std.ArrayList(*flow.AST.Statement).init(self.allocator);
    while (self.token.tag != .end_of_frame) {
        const statement = try self.parseStatement();
        try statements.append(statement);
    }
    return statements.toOwnedSlice();
}

fn parseStatement(self: *Parser) !*flow.AST.Statement {
    const expression = try self.parseExpression();
    const statement = try self.allocator.create(flow.AST.Statement);
    statement.* = .{ .expression = expression };
    return statement;
}

fn parseExpression(self: *Parser) !*flow.AST.Expression {
    var expression = try self.parseTypedExpression();
    if (self.token.tag == .pipe or self.token.tag == .arrow)
        expression = try self.parsePipelineExpression(expression);
    return expression;
}

fn parseLiteralExpression(self: *Parser) !*flow.AST.Expression {
    if (self.token.tag != .int and self.token.tag != .float)
        return error.InvalidToken;

    const literal = self.token;
    self.advance();

    const expression = try self.allocator.create(flow.AST.Expression);
    expression.* = .{ .literal = .{ .token = literal } };
    return expression;
}

fn parseTypedExpression(self: *Parser) !*flow.AST.Expression {
    if (self.token.tag != .identifier)
        return Error.InvalidToken;

    const name = self.token;
    self.advance();

    if (self.token.tag != .colon)
        return Error.InvalidToken;

    self.advance();
    const literal = try self.parseLiteralExpression();

    const expression = try self.allocator.create(flow.AST.Expression);
    expression.* = .{ .typed = .{ .name = name, .expression = literal } };
    return expression;
}

fn parsePipelineExpression(self: *Parser, initial: *flow.AST.Expression) !*flow.AST.Expression {
    var operations = std.ArrayList(flow.AST.Operation).init(self.allocator);
    tag: switch (self.token.tag) {
        .pipe => {
            self.advance();
            if (self.token.tag != .identifier) {
                return Error.InvalidToken;
            }
            const name = self.token;
            self.advance();
            var parameters = std.ArrayList(*flow.AST.Expression).init(self.allocator);
            while (self.token.tag == .int or self.token.tag == .float) {
                const parameter = try self.parseLiteralExpression();
                try parameters.append(parameter);
            }
            try operations.append(.{ .mutation = .{ .name = name, .parameters = try parameters.toOwnedSlice() } });
            continue :tag self.token.tag;
        },
        .arrow => {
            self.advance();
            if (self.token.tag != .identifier) {
                return Error.InvalidToken;
            }
            const name = self.token;
            self.advance();
            var parameters = std.ArrayList(*flow.AST.Expression).init(self.allocator);
            while (self.token.tag == .int or self.token.tag == .float) {
                const parameter = try self.parseLiteralExpression();
                try parameters.append(parameter);
            }
            try operations.append(.{ .transform = .{ .name = name, .parameters = try parameters.toOwnedSlice() } });
            continue :tag self.token.tag;
        },
        else => {
            const expression = try self.allocator.create(flow.AST.Expression);
            expression.* = .{ .pipeline = .{ .initial = initial, .operations = try operations.toOwnedSlice() } };
            return expression;
        },
    }
}

pub fn advance(self: *Parser) void {
    self.token = self.lexer.next();
}

test parse {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 5 | add 10 | sub 5 -> string | test -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var lexer = flow.Lexer.init(source);
    var parser = init(arena.allocator(), &lexer);
    _ = try parser.parse();
}
