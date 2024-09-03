const std = @import("std");

const Token = @import("token.zig").Token;
const Lexer = @import("lexer.zig").Lexer;
const Node = @import("ast.zig").Node;
const BinaryType = @import("ast.zig").BinaryType;

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    allocator: std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) !Parser {
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
            .allocator = allocator,
        };
        try parser.nextToken();
        return parser;
    }

    fn nextToken(self: *Parser) !void {
        self.current_token = self.lexer.next();
    }

    pub fn parseExpression(self: *Parser) !*Node {
        var left = try self.parseTerm();
        while (self.current_token.tag == .plus or self.current_token.tag == .minus) {
            const op = if (self.current_token.tag == .plus) BinaryType.Add else BinaryType.Subtract;
            try self.nextToken();
            const right = try self.parseTerm();
            const node = try self.allocator.create(Node);
            node.* = Node{ .BinaryOp = .{ .op = op, .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseTerm(self: *Parser) !*Node {
        var left = try self.parseFactor();
        while (self.current_token.tag == .asterisk or self.current_token.tag == .forward_slash) {
            const op = if (self.current_token.tag == .asterisk) BinaryType.Multiply else BinaryType.Divide;
            try self.nextToken();
            const right = try self.parseFactor();
            const node = try self.allocator.create(Node);
            node.* = Node{ .BinaryOp = .{ .op = op, .left = left, .right = right } };
            left = node;
        }
        return left;
    }

    fn parseFactor(self: *Parser) !*Node {
        if (self.current_token.tag == .int) {
            const value = try std.fmt.parseInt(i64, self.current_token.lexeme, 10);
            const node = try self.allocator.create(Node);
            node.* = Node{ .IntLiteral = .{ .value = value } };
            try self.nextToken();
            return node;
        } else {
            return error.UnexpectedToken;
        }
    }
};

test "parser" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init("1 + 2 * 3");
    var parser = try Parser.init(&lexer, allocator);

    const root = try parser.parseExpression();
    defer root.deinit(allocator);

    // Now you can traverse or evaluate the AST
    try std.testing.expect(root.* == .BinaryOp);
    try std.testing.expect(root.BinaryOp.op == .Add);
    try std.testing.expect(root.BinaryOp.left.* == .IntLiteral);
    try std.testing.expect(root.BinaryOp.left.IntLiteral.value == 1);
    try std.testing.expect(root.BinaryOp.right.* == .BinaryOp);
    try std.testing.expect(root.BinaryOp.right.BinaryOp.op == .Multiply);
    try std.testing.expect(root.BinaryOp.right.BinaryOp.left.IntLiteral.value == 2);
    try std.testing.expect(root.BinaryOp.right.BinaryOp.right.IntLiteral.value == 3);
}
