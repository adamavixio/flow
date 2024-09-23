const std = @import("std");
const Parser = @import("./parser.zig");
const Lexer = @import("./lexer.zig");

pub const Self = @This();

allocator: std.mem.Allocator,

pub const InterpreterError = error{
    UnsupportedNode,
    UnsupportedLiteral,
    UnsupportedSpecial,
    ExecutionError,
};

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

pub fn interpret(self: *Self, ast: *Parser.Node) InterpreterError!void {
    try self.executeNode(ast);
}

fn executeNode(self: *Self, node: *Parser.Node) InterpreterError!void {
    switch (node.lexeme) {
        .keyword => |lexeme| switch (lexeme) {
            .file => try self.executeFile(node),
            .path => try self.executePath(node),
            .lines => try self.executeLines(node),
        },
        .operator => |lexeme| switch (lexeme) {
            .sort => try self.executeSort(node),
            .deduplicate => try self.executeDeduplicate(node),
        },
        .literal => |lexeme| switch (lexeme) {
            .string => try self.executeString(node),
            else => {
                std.debug.print("{any}\n", .{node});
                return InterpreterError.UnsupportedLiteral;
            },
        },
        .special => |lexeme| switch (lexeme) {
            .module => try self.executeModule(node),
            else => {
                std.debug.print("{any}\n", .{node});
                return InterpreterError.UnsupportedSpecial;
            },
        },
        else => {
            std.debug.print("{any}\n", .{node});
            return InterpreterError.UnsupportedNode;
        },
    }
}

fn executeModule(self: *Self, node: *Parser.Node) InterpreterError!void {
    std.debug.print("Executing module: {s}\n", .{node.literal});
    for (node.children.items) |child| {
        self.executeNode(child) catch |err| {
            std.debug.print("Error executing child node: {}\n", .{err});
            return InterpreterError.ExecutionError;
        };
    }
}

fn executeFile(self: *Self, node: *Parser.Node) InterpreterError!void {
    std.debug.print("Executing file: {s}\n", .{node.literal});
    for (node.children.items) |child| {
        self.executeNode(child) catch |err| {
            std.debug.print("Error executing child node: {}\n", .{err});
            return InterpreterError.ExecutionError;
        };
    }
}

fn executePath(_: *Self, node: *Parser.Node) InterpreterError!void {
    std.debug.print("Processing path: {s}\n", .{node.literal});
    // Here you would typically read the file content
    // For now, we'll just print the path
}

fn executeLines(self: *Self, node: *Parser.Node) InterpreterError!void {
    std.debug.print("Processing lines\n", .{});
    for (node.children.items) |child| {
        self.executeNode(child) catch |err| {
            std.debug.print("Error processing line operation: {}\n", .{err});
            return InterpreterError.ExecutionError;
        };
    }
}

fn executeSort(_: *Self, _: *Parser.Node) InterpreterError!void {
    std.debug.print("Sorting lines\n", .{});
    // Implement sorting logic here
}

fn executeDeduplicate(_: *Self, _: *Parser.Node) InterpreterError!void {
    std.debug.print("Deduplicating lines\n", .{});
    // Implement deduplication logic here
}

fn executeString(_: *Self, node: *Parser.Node) InterpreterError!void {
    std.debug.print("String literal: {s}\n", .{node.literal});
}

test "Interpreter test" {
    const allocator = std.testing.allocator;
    const input = "file : path 'test.txt' -> lines | sort";
    const lexer = Lexer.init(input);
    var parser = Parser.init(allocator, lexer);
    var ast = try parser.parse();
    defer ast.deinit(allocator);
    var interpreter = init(allocator);
    try interpreter.interpret(ast);
    // Add assertions here to check the interpreter's output or behavior
}
