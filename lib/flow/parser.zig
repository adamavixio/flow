const std = @import("std");
const Lexer = @import("./lexer.zig");

const Self = @This();

token: Lexer.Token,
lexer: Lexer,
allocator: std.mem.Allocator,

pub const Error = error{
    InvalidToken,
};

pub const Node = struct {
    lexeme: Lexer.Lexeme,
    literal: ?[]const u8,
    children: std.ArrayList(*Node),

    pub fn init(allocator: std.mem.Allocator, Lexer.Token) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .lexeme = token.lexeme,
            .literal = switch (token.lexeme) {
                .literal => try allocator.dupe(u8, lexer.input[token.left..token.right]),
                else => null,
            },
            .children = std.ArrayList(*Node).init(allocator),
        };
        return node;
    }

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
    }
};

// file : path "ests" <> path "edsfs" -> lines | sort | deduplicate

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

pub fn next(self: *Self) void {
    self.token = self.lexer.next();
}

pub fn parse(self: *Self) !*Node {
    const node = Node.init(self.allocator, self.token);

    while (true) {
        self.next();
        switch (self.token.lexeme) {
            .keyword => |k| switch (k) {
                .file => {
                    const child = try self.parseFile();
                    try self.root.children.append(child);
                },
                else => return Error.InvalidToken,
            },
            .special => |s| switch (s) {
                .invalid => {
                    const child = try Node.init(self.allocator, self.token);
                    try self.root.children.append(child);
                    break;
                },
                .eof => {
                    break;
                },
                else => return error.InvalidToken,
            },
            else => return Error.InvalidToken,
        }
    }

    return node;
}

pub fn parseFile(self: *Self) !*Node {
    const node = try Node.init(self.allocator, self.token);

    self.next();
    switch (self.token.lexeme) {
        .symbol => |s| switch (s) {
            .colon => {},
            else => return Error.InvalidToken,
        },
    }

    while (true) {
        self.next();
        switch (self.token.lexeme) {
            .keyword => |k| switch (k) {
                .path => {
                    const child = try self.parsePath();
                    try node.children.append(child);
                },
                else => return error.InvalidToken,
            },
            .special => |s| switch (s) {
                .invalid => {
                    const child = try Node.init(self.allocator, self.token);
                    try node.children.append(child);
                    break;
                },
                .eof => {
                    break;
                },
                else => return error.InvalidToken,
            },
            else => return error.InvalidToken,
        }
    }

    return node;
}

pub fn parsePath(self: *Self) !*Node {
    const node = try Node.init(self.allocator, self.token);

    self.next();
    switch (self.token.lexeme) {
        .literal => |l| switch (l) {
            .string => {
                const child = try Node.init(self.allocator, self.token);
                try node.children.append(child);
            },
            else => return Error.InvalidToken,
        },
    }

    return node;
}
