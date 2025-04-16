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
