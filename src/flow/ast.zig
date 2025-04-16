const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const meta = std.meta;

const lib = @import("../root.zig");
const core = lib.core;
const flow = lib.flow;

pub const Statement = union(enum) {
    expression: Expression,
};

pub const Expression = union(enum) {
    typed: Typed,
    mutation: Mutation,
    transform: Transform,

    pub const Typed = struct {
        type: Type,
        value: flow.Token,
    };

    pub const Mutation = struct {
        input: *Expression,
        operation: flow.Token,
        parameters: []*Expression,
    };

    pub const Transform = struct {
        input: *Expression,
        operation: flow.Token,
        parameters: []*Expression,
    };
};

pub const Type = struct {
    name: flow.Token,
};
