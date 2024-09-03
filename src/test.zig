const std = @import("std");

// Token types
const TokenType = enum {
    Identifier,
    Number,
    Plus,
    Minus,
    Multiply,
    Divide,
    LeftParen,
    RightParen,
    EOF,
};

// Token structure
const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
};

// AST Node types
const NodeType = enum {
    BinaryOp,
    Number,
    Identifier,
};

// AST Node structure
const AstNode = struct {
    type: NodeType,
    value: union {
        binary_op: struct {
            left: *AstNode,
            right: *AstNode,
            op: TokenType,
        },
        number: f64,
        identifier: []const u8,
    },

    fn deinit(self: *AstNode, allocator: std.mem.Allocator) void {
        switch (self.type) {
            .BinaryOp => {
                self.value.binary_op.left.deinit(allocator);
                allocator.destroy(self.value.binary_op.left);
                self.value.binary_op.right.deinit(allocator);
                allocator.destroy(self.value.binary_op.right);
            },
            else => {},
        }
    }
};

// Tokenizer structure
const Tokenizer = struct {
    input: []const u8,
    position: usize,
    line: usize,

    fn init(input: []const u8) Tokenizer {
        return .{
            .input = input,
            .position = 0,
            .line = 1,
        };
    }

    fn nextToken(self: *Tokenizer) !Token {
        self.skipWhitespace();

        if (self.position >= self.input.len) {
            return Token{ .type = .EOF, .lexeme = "", .line = self.line };
        }

        const char = self.input[self.position];
        self.position += 1;

        return switch (char) {
            '+' => Token{ .type = .Plus, .lexeme = "+", .line = self.line },
            '-' => Token{ .type = .Minus, .lexeme = "-", .line = self.line },
            '*' => Token{ .type = .Multiply, .lexeme = "*", .line = self.line },
            '/' => Token{ .type = .Divide, .lexeme = "/", .line = self.line },
            '(' => Token{ .type = .LeftParen, .lexeme = "(", .line = self.line },
            ')' => Token{ .type = .RightParen, .lexeme = ")", .line = self.line },
            '0'...'9' => self.number(),
            'a'...'z', 'A'...'Z', '_' => self.identifier(),
            else => error.UnexpectedCharacter,
        };
    }

    fn number(self: *Tokenizer) Token {
        const start = self.position - 1;
        while (self.position < self.input.len and std.ascii.isDigit(self.input[self.position])) {
            self.position += 1;
        }
        return Token{
            .type = .Number,
            .lexeme = self.input[start..self.position],
            .line = self.line,
        };
    }

    fn identifier(self: *Tokenizer) Token {
        const start = self.position - 1;
        while (self.position < self.input.len and (std.ascii.isAlphanumeric(self.input[self.position]) or self.input[self.position] == '_')) {
            self.position += 1;
        }
        return Token{
            .type = .Identifier,
            .lexeme = self.input[start..self.position],
            .line = self.line,
        };
    }

    fn skipWhitespace(self: *Tokenizer) void {
        while (self.position < self.input.len) : (self.position += 1) {
            switch (self.input[self.position]) {
                ' ', '\t', '\r' => {},
                '\n' => self.line += 1,
                else => return,
            }
        }
    }
};

// Parser structure
const Parser = struct {
    tokenizer: *Tokenizer,
    current_token: Token,
    allocator: std.mem.Allocator,

    fn init(tokenizer: *Tokenizer, allocator: std.mem.Allocator) !Parser {
        return Parser{
            .tokenizer = tokenizer,
            .current_token = try tokenizer.nextToken(),
            .allocator = allocator,
        };
    }

    fn parse(self: *Parser) !*AstNode {
        return self.expression();
    }

    fn expression(self: *Parser) !*AstNode {
        var left = try self.term();

        while (self.current_token.type == .Plus or self.current_token.type == .Minus) {
            const op = self.current_token.type;
            try self.consume(op);
            var right = try self.term();

            var node = try self.allocator.create(AstNode);
            node.* = AstNode{
                .type = .BinaryOp,
                .value = .{ .binary_op = .{ .left = left, .right = right, .op = op } },
            };
            left = node;
        }

        return left;
    }

    fn term(self: *Parser) !*AstNode {
        var left = try self.factor();

        while (self.current_token.type == .Multiply or self.current_token.type == .Divide) {
            const op = self.current_token.type;
            try self.consume(op);
            var right = try self.factor();

            var node = try self.allocator.create(AstNode);
            node.* = AstNode{
                .type = .BinaryOp,
                .value = .{ .binary_op = .{ .left = left, .right = right, .op = op } },
            };
            left = node;
        }

        return left;
    }

    fn factor(self: *Parser) !*AstNode {
        switch (self.current_token.type) {
            .Number => {
                const value = try std.fmt.parseFloat(f64, self.current_token.lexeme);
                var node = try self.allocator.create(AstNode);
                node.* = AstNode{ .type = .Number, .value = .{ .number = value } };
                try self.consume(.Number);
                return node;
            },
            .Identifier => {
                var node = try self.allocator.create(AstNode);
                node.* = AstNode{
                    .type = .Identifier,
                    .value = .{ .identifier = self.current_token.lexeme },
                };
                try self.consume(.Identifier);
                return node;
            },
            .LeftParen => {
                try self.consume(.LeftParen);
                var node = try self.expression();
                try self.consume(.RightParen);
                return node;
            },
            else => return error.UnexpectedToken,
        }
    }

    fn consume(self: *Parser, expected: TokenType) !void {
        if (self.current_token.type != expected) {
            return error.UnexpectedToken;
        }
        self.current_token = try self.tokenizer.nextToken();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = "3 + 4 * 2 - (1 + 2) * 3";
    var tokenizer = Tokenizer.init(input);
    var parser = try Parser.init(&tokenizer, allocator);

    const ast = try parser.parse();
    defer ast.deinit(allocator);
    defer allocator.destroy(ast);

    // Here you would typically do something with the AST, like interpret it or generate code
    std.debug.print("AST created successfully\n", .{});
}
