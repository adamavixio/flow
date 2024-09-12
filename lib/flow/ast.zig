const std = @import("std");

// file : path "ests" <> path "edsfs" -> lines -> sort | deduplicate

pub const AST = struct {
    pub const Node = struct {
        pub const Type = enum {
            string,
            object,
        };
    };
};

pub const NodeType = enum {
    BinaryOp,
    IntLiteral,
};

pub const BinaryType = enum {
    Add,
    Subtract,
    Multiply,
    Divide,
};

pub const Node = union(NodeType) {
    BinaryOp: struct {
        op: BinaryType,
        left: *Node,
        right: *Node,
    },
    IntLiteral: struct {
        value: i64,
    },

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .BinaryOp => |*op| {
                op.left.deinit(allocator);
                op.right.deinit(allocator);
                allocator.destroy(op.left);
                allocator.destroy(op.right);
            },
            .IntLiteral => {},
        }
    }
};
