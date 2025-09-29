const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const meta = std.meta;

const lib = @import("../root.zig");
const core = lib.core;
const flow = lib.flow;

pub const Statement = union(enum) {
    declaration: *Declaration,
    expression: *Expression,
};

pub const Declaration = union(enum) {
    type: Type,
    pipeline: Pipeline,

    pub const Type = struct {
        name: flow.Token,
    };

    pub const Pipeline = struct {
        name: flow.Token,
        input: Type,
        output: core.Type,
        block: Expression.Pipeline,
    };
};

pub const Expression = union(enum) {
    literal: Literal,
    typed: Typed,
    pipeline: Pipeline,

    pub const Literal = struct {
        value: flow.Token,
    };

    pub const Typed = struct {
        name: flow.Token,
        expression: *Expression,
    };

    pub const Pipeline = struct {
        initial: *Expression,
        operations: []Operation,
    };
};

pub const Operation = union(enum) {
    mutation: Mutation,
    transform: Transform,

    pub const Mutation = struct {
        name: flow.Token,
        parameters: []*Expression,
    };

    pub const Transform = struct {
        name: flow.Token,
        parameters: []*Expression,
    };
};
