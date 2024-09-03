const std = @import("std");

pub const Type = enum {
    expression,
    operator,
    special,
};

pub const Expression = enum(usize) {
    number,
};

pub const Operator = enum(usize) {
    plus,
    minus,
    asterisk,
    forward_slash,
};

pub const Special = enum(usize) {
    illegal,
};

pub const Tag = union(Type) {
    expression: Expression,
    operator: Operator,
    special: Special,
};

pub fn init(byte: u8) Tag {
    return tags[byte];
}

const tags = blk: {
    var comp: [256]Tag = undefined;
    for (0..256) |i| {
        comp[i] = switch (i) {
            '+' => .{ .operator = .plus },
            '-' => .{ .operator = .minus },
            '*' => .{ .operator = .asterisk },
            '/' => .{ .operator = .forward_slash },
            '0'...'9' => .{ .expression = .number },
            else => .{ .special = .illegal },
        };
    }
    break :blk comp;
};
