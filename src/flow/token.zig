const std = @import("std");
const mem = std.mem;

const root = @import("../root.zig");
const flow = root.flow;

pub const Token = @This();

tag: Tag,
start: usize,
end: usize,

pub const Tag = enum {
    // Identifier
    identifier,
    // Literal
    int,
    float,
    // Operator
    plus,
    minus,
    multiply,
    divide,
    arrow,
    chain,
    colon,
    pipe,
    // Special
    invalid,
    end_of_frame,
};

pub fn isIdentifier(self: Token) bool {
    return switch (self.tag) {
        .identifier => true,
        else => false,
    };
}

pub fn isLiteral(self: Token) bool {
    return switch (self.tag) {
        .int, .float, .string => true,
        else => false,
    };
}

pub fn isOperator(self: Token) bool {
    return switch (self.tag) {
        .plus, .minus, .multiply, .divide, .arrow, .chain, .colon, .pipe => true,
        else => false,
    };
}

pub fn isSpecial(self: Token) bool {
    return switch (self.tag) {
        .end_of_frame, .invalid, .new_line => true,
        else => false,
    };
}
