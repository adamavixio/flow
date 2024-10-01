const std = @import("std");

const Type = @import("type");
const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");

pub const Self = @This();

allocator: std.mem.Allocator,

pub const Primitive = union(enum) {
    int: Type.Primitive.Int,
    float: Type.Primitive.Float,
    string: Type.Primitive.String,

    pub fn deinit(self: *Primitive) void {
        switch (self.*) {
            .int => |*v| v.deinit(),
            .float => |*v| v.deinit(),
            .string => |*v| v.deinit(),
        }
    }
};

pub const Error = error{
    UnsupportedNode,
    UnsupportedKeyword,
    UnsupportedLiteral,
    UnsupportedSpecial,
    ExecutionError,
} || std.mem.Allocator.Error;

pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn interpret(self: *Self, ast: *Parser.AST) Error!void {
    try self.executeNode(ast);
}

fn executeNode(self: *Self, node: *Parser.AST) Error!void {
    switch (node.token.tag) {
        .keyword => try self.executeKeyword(node),
        .special => |lexeme| switch (lexeme) {
            .module => try self.executeModule(node),
            else => {
                std.log.debug("{any}\n", .{node});
                return Error.UnsupportedSpecial;
            },
        },
        else => {
            std.log.debug("{any}\n", .{node});
            return Error.UnsupportedNode;
        },
    }
}

fn executeModule(self: *Self, node: *Parser.AST) Error!void {
    for (node.children.items) |child| {
        try self.executeNode(child);
    }
}

fn executeKeyword(self: *Self, node: *Parser.AST) Error!void {
    switch (node.token.tag) {
        .keyword => |keyword| switch (keyword) {
            .int, .float, .string => try self.executeLiteral(),
        },
    }
    var literals = std.ArrayList(*Parser.AST).init(self.allocator);
    defer literals.deinit();

    var operators = std.ArrayList(*Parser.AST).init(self.allocator);
    defer operators.deinit();

    for (node.children.items) |child| switch (child.token.tag) {
        .literal => try literals.append(child),
        .operator => try operators.append(child),
        else => return Error.UnsupportedNode,
    };

    for (literals.items) |literal| {
        var primitive = try self.executeLiteral(node, literal);
        defer primitive.deinit();
        switch (primitive) {
            inline else => |*value| for (operators.items) |operator| {
                switch (operator.lexeme.operator) {
                    .sort => value.sort(.asc),
                    .unique => try value.unique(),
                }
            },
        }
        std.debug.print("|{s}|", .{primitive.string.data});
    }
}

fn executeLiteral(self: *Self, parent: *Parser.AST, child: *Parser.AST) Error!Primitive {
    const literal = child.literal orelse return Error.ExecutionError;
    return switch (parent.lexeme) {
        .keyword => |keyword| switch (keyword) {
            .int => .{
                .int = try Type.Primitive.Int.init(self.allocator, literal),
            },
            .float => .{
                .float = try Type.Primitive.Float.init(self.allocator, literal),
            },
            .string => .{
                .string = try Type.Primitive.String.init(self.allocator, trimQuotes(literal)),
            },
        },
        else => error.UnsupportedNode,
    };
}

fn trimQuotes(str: []const u8) []const u8 {
    if (str.len >= 2 and str[0] == '\'' and str[str.len - 1] == '\'') {
        return str[1 .. str.len - 1];
    }
    return str;
}

test "Interpreter test" {
    const allocator = std.testing.allocator;

    const input = "string : 'ccbbaa' <> 'aabbcc' | sort | unique";
    const lexer = Lexer.init(input);

    var parser = Parser.init(allocator, lexer);
    var ast = try parser.parse();
    defer ast.deinit(allocator);

    var interpreter = init(allocator);
    try interpreter.interpret(ast);
    // Add assertions here to check the interpreter's output or behavior
}
