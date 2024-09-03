const std = @import("std");

const Node = @import("ast.zig").Node;
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;

pub const Interpreter = struct {
    allocator: std.mem.Allocator,

    pub fn interpret(self: *Interpreter, node: *Node) !i64 {
        return switch (node.*) {
            .IntLiteral => |n| n.value,
            .BinaryOp => |op| {
                const left = try self.interpret(op.left);
                const right = try self.interpret(op.right);
                return switch (op.op) {
                    .Add => left + right,
                    .Subtract => left - right,
                    .Multiply => left * right,
                    .Divide => @divTrunc(left, right),
                };
            },
        };
    }

    pub fn run(self: *Interpreter, input: []const u8) !i64 {
        var lexer = Lexer.init(input);
        var parser = try Parser.init(&lexer, self.allocator);
        const ast = try parser.parseExpression();
        defer ast.deinit(self.allocator);
        return self.interpret(ast);
    }
};

test "interpreter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var interpreter = Interpreter{ .allocator = allocator };
    const result = try interpreter.run(" 1 + 2 * 3 - 1 ");
    std.debug.print("{}\n", .{result});
    try std.testing.expectEqual(@as(i64, 6), result);
}
