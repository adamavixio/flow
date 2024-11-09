const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

const root = @import("root.zig");
const AST = root.AST;
const Lexer = root.Lexer;
const Position = root.Position;
const Source = root.Source;
const Token = root.Token;

pub const Parser = @This();

arena: *ArenaAllocator,
index: usize,
token: Token,
source: Source,
tokens: ArrayList(Token),

pub const Error = error{
    InvalidPipeline,
    InvalidStage,
    InvalidInputStage,
    InvalidDeclaration,
    InvalidTypeDeclaration,
    InvalidExpression,
} || Allocator.Error;

pub fn init(arena: *ArenaAllocator, source: Source, tokens: ArrayList(Token)) Parser {
    return .{
        .arena = arena,
        .index = 0,
        .token = undefined,
        .source = source,
        .tokens = tokens,
    };
}

pub fn peek(self: *Parser) Token {
    return self.tokens.items[self.index];
}

pub fn next(self: *Parser) Token {
    return self.tokens.items[self.index + 1];
}

pub fn skip(self: *Parser) void {
    self.index += 1;
}

pub fn consume(self: *Parser) Token {
    defer self.index += 1;
    return self.tokens.items[self.index];
}

pub fn parse(self: *Parser) Error!*AST {
    var ast = try AST.init(self.arena);
    errdefer ast.deinit();

    while (true) switch (self.peek().tag) {
        .new_line => {
            self.skip();
        },
        .identifier => {
            const pipeline = try self.parsePipeline();
            try ast.pipelines.append(pipeline);
        },
        .end_of_frame => {
            break;
        },
        else => {
            self.printError();
            return Error.InvalidPipeline;
        },
    };

    return ast;
}

pub fn parsePipeline(self: *Parser) Error!*AST.Pipeline {
    var pipeline = try AST.Pipeline.init(self.arena);

    while (true) switch (self.peek().tag) {
        .identifier => {
            const stage = try self.parseInputStage();
            try pipeline.stages.append(stage);
        },
        .arrow => {
            self.skip();
            while (self.peek().tag == .new_line) {
                self.skip();
            }
            const stage = try self.parseTransformStage();
            try pipeline.stages.append(stage);
        },
        .new_line, .end_of_frame => {
            break;
        },
        else => {
            self.printError();
            return Error.InvalidPipeline;
        },
    };

    return pipeline;
}

pub fn parseInputStage(self: *Parser) Error!*AST.Stage {
    const declaration = try self.parseTypeDeclaration();
    var expressions = ArrayList(*AST.Expression).init(self.arena.allocator());

    while (true) switch (self.peek().tag) {
        .arrow, .new_line, .end_of_frame => {
            break;
        },
        .pipe => {
            self.skip();
            while (self.peek().tag == .new_line) {
                self.skip();
            }
        },
        .identifier => {
            const identifier = try self.parseIdentifierExpression();
            try expressions.append(identifier);
            while (true) switch (self.peek().tag) {
                .int, .float, .string => {
                    const literal = try self.parseLiteralExpression();
                    try expressions.append(literal);
                },
                else => {
                    break;
                },
            };
        },
        else => {
            self.printError();
            return Error.InvalidInputStage;
        },
    };

    return try AST.Stage.initInput(
        self.arena,
        declaration,
        expressions,
    );
}

pub fn parseTransformStage(self: *Parser) Error!*AST.Stage {
    var expressions = ArrayList(*AST.Expression).init(self.arena.allocator());

    while (true) switch (self.peek().tag) {
        .arrow, .new_line, .end_of_frame => {
            break;
        },
        .pipe => {
            self.skip();
            while (self.peek().tag == .new_line) {
                self.skip();
            }
        },
        .identifier => {
            const identifier = try self.parseIdentifierExpression();
            try expressions.append(identifier);
            while (true) switch (self.peek().tag) {
                .int, .float, .string => {
                    const literal = try self.parseLiteralExpression();
                    try expressions.append(literal);
                },
                else => {
                    break;
                },
            };
        },
        else => {
            self.printError();
            return Error.InvalidInputStage;
        },
    };

    return AST.Stage.initTransform(
        self.arena,
        expressions,
    );
}

pub fn parseTypeDeclaration(self: *Parser) !*AST.Declaration {
    const name = try self.parseIdentifierExpression();
    if (self.consume().tag != .colon) {
        self.printError();
        return Error.InvalidTypeDeclaration;
    }
    const value = try self.parseLiteralExpression();
    return try AST.Declaration.initType(
        self.arena,
        name,
        value,
    );
}

pub fn parseIdentifierExpression(self: *Parser) !*AST.Expression {
    const token = self.consume();
    const content = self.source.slice(token.position);
    return try AST.Expression.initIdentifier(
        self.arena,
        content,
        token.position,
    );
}

pub fn parseLiteralExpression(self: *Parser) !*AST.Expression {
    const token = self.consume();
    const content = self.source.slice(token.position);
    return try AST.Expression.initLiteral(
        self.arena,
        content,
        token.position,
    );
}

pub fn printError(self: *Parser) void {
    const token = self.peek();
    const content = self.source.slice(token.position);
    std.debug.print("Token: {any}\n", .{token});
    std.debug.print("Content: {s}\n", .{content});
}

test "parser" {
    const allocator = testing.allocator;

    const input =
        \\ int : 5 | add 5 | sub 5 -> string | upper -> print
        \\ int : 5 | add 5 | sub 5 -> string | upper -> print
    ;
    var source = try Source.initString(allocator, input);
    defer source.deinit();

    var lexer = Lexer.init(source);
    const tokens = try lexer.Tokenize(allocator);
    defer tokens.deinit();

    var arena = ArenaAllocator.init(allocator);
    var parser = init(&arena, source, tokens);
    const ast = try parser.parse();
    defer ast.deinit();

    ast.walk();
}
