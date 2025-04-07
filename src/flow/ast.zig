const std = @import("std");
const heap = std.heap;
const mem = std.mem;

const lib = @import("../root.zig");
const core = lib.core;
const flow = lib.flow;

pub const AST = @This();
statements: []Statement,

pub const Statement = union(enum) {
    pipeline: Pipeline,

    pub const Pipeline = struct {
        type: ExpressionType,
        transforms: []ExpressionTransform,
    };
};

pub const ExpressionType = struct {
    name: []const u8,
    parameter: ExpressionParameter,
    operations: []ExpressionOperation,
};

pub const ExpressionTransform = struct {
    name: []const u8,
    parameters: []ExpressionParameter,
    operations: []ExpressionOperation,
};

pub const ExpressionOperation = struct {
    name: []const u8,
    parameters: []ExpressionParameter,
};

pub const ExpressionParameter = union(enum) {
    literal: []const u8,
};
