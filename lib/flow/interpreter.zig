const std = @import("std");

const Lexer = @import("lexer.zig");
const Parser = @import("parser.zig");

pub const Self = @This();

allocator: std.mem.Allocator,

pub const InterpreterError = error{
    UnsupportedNode,
    UnsupportedKeyword,
    UnsupportedLiteral,
    UnsupportedSpecial,
    ExecutionError,
};

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

pub fn interpret(self: *Self, ast: *Parser.AST) InterpreterError!void {
    try self.executeNode(ast);
}

fn executeNode(self: *Self, node: *Parser.AST) InterpreterError!void {
    switch (node.lexeme) {
        .keyword => |lexeme| switch (lexeme) {
            .file => try self.executeFile(node),
            .path => try self.executePath(node),
            .lines => try self.executeLines(node),
            else => {
                std.log.debug("{any}\n", .{node});
                return InterpreterError.UnsupportedKeyword;
            },
        },
        .operator => |lexeme| switch (lexeme) {
            .sort => try self.executeSort(node),
            .unique => try self.executeUnique(node),
        },
        .literal => |lexeme| switch (lexeme) {
            .string => try self.executeString(node),
            else => {
                std.log.debug("{any}\n", .{node});
                return InterpreterError.UnsupportedLiteral;
            },
        },
        .special => |lexeme| switch (lexeme) {
            .module => try self.executeModule(node),
            else => {
                std.log.debug("{any}\n", .{node});
                return InterpreterError.UnsupportedSpecial;
            },
        },
        else => {
            std.log.debug("{any}\n", .{node});
            return InterpreterError.UnsupportedNode;
        },
    }
}

fn executeModule(self: *Self, node: *Parser.AST) InterpreterError!void {
    std.log.debug("Executing module: {s}\n", .{node.literal});
    for (node.children.items) |child| {
        self.executeNode(child) catch |err| {
            std.log.debug("Error executing child node: {}\n", .{err});
            return InterpreterError.ExecutionError;
        };
    }
}

fn executeFile(self: *Self, node: *Parser.AST) InterpreterError!void {
    std.log.debug("Executing file: {s}\n", .{node.literal});
    for (node.children.items) |child| {
        self.executeNode(child) catch |err| {
            std.log.debug("Error executing child node: {}\n", .{err});
            return InterpreterError.ExecutionError;
        };
    }
}

fn executePath(_: *Self, node: *Parser.AST) InterpreterError!void {
    std.log.debug("Processing path: {s}\n", .{node.literal});
    // Here you would typically read the file content
    // For now, we'll just print the path
}

fn executeLines(self: *Self, node: *Parser.AST) InterpreterError!void {
    std.log.debug("Processing lines\n", .{});
    for (node.children.items) |child| {
        self.executeNode(child) catch |err| {
            std.log.debug("Error processing line operation: {}\n", .{err});
            return InterpreterError.ExecutionError;
        };
    }
}

fn executeSort(_: *Self, _: *Parser.AST) InterpreterError!void {
    std.log.debug("Sorting lines\n", .{});
    // Implement sorting logic here
}

fn executeUnique(_: *Self, _: *Parser.AST) InterpreterError!void {
    std.log.debug("Deduplicating lines\n", .{});
    // Implement deduplication logic here
}

fn executeString(_: *Self, node: *Parser.AST) InterpreterError!void {
    std.log.debug("String literal: {s}\n", .{node.literal});
}

// test "Interpreter test" {
//     const allocator = std.testing.allocator;
//     const input = "file : path 'test.txt' -> lines | sort";
//     const lexer = Lexer.init(input);
//     var parser = Parser.init(allocator, lexer);
//     var ast = try parser.parse();
//     defer ast.deinit(allocator);
//     var interpreter = init(allocator);
//     try interpreter.interpret(ast);
//     // Add assertions here to check the interpreter's output or behavior
// }
