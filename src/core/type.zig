const std = @import("std");
const builtin = std.builtin;
const fmt = std.fmt;
const heap = std.heap;
const io = std.io;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

pub const Error = error{
    ParseTypeFailed,
    ParseValueFailed,
    ParseMutationFailed,
    ParseTransformFailed,
    InvalidMutation,
    InvalidTransform,
    TypeMismatch,
};

pub const Tag = enum {
    int,
    uint,
    float,
    string,
    tuple,
    void,

    pub fn parse(name: []const u8) !Tag {
        if (meta.stringToEnum(Tag, name)) |tag| return tag;
        return Error.ParseTypeFailed;
    }
};

pub fn Build(comptime tag: Tag) type {
    return switch (tag) {
        .int => struct { owned: bool, data: isize },
        .uint => struct { owned: bool, data: usize },
        .float => struct { owned: bool, data: f64 },
        .string => struct { owned: bool, data: []const u8 },
        .tuple => struct { owned: bool, data: []Value },
        .void => struct { owned: bool, data: void },
    };
}

pub const Mutation = enum {
    add,
    sub,
    mul,
    div,

    pub fn parse(name: []const u8) !Mutation {
        if (meta.stringToEnum(Mutation, name)) |mutation| return mutation;
        return Error.ParseMutationFailed;
    }
};

test Mutation {
    const add = try Mutation.parse("add");
    const sub = try Mutation.parse("sub");
    const mul = try Mutation.parse("mul");
    const div = try Mutation.parse("div");
    try testing.expectEqual(.add, add);
    try testing.expectEqual(.sub, sub);
    try testing.expectEqual(.mul, mul);
    try testing.expectEqual(.div, div);
}

pub const Transform = union(enum) {
    int,
    uint,
    float,
    string,
    print: std.io.AnyWriter,

    pub fn parse(name: []const u8) !meta.FieldEnum(Transform) {
        if (meta.stringToEnum(meta.FieldEnum(Transform), name)) |transform| return transform;
        return Error.ParseTransformFailed;
    }
};

test Transform {
    const string = try Transform.parse("string");
    const print = try Transform.parse("print");
    try testing.expectEqual(.string, string);
    try testing.expectEqual(.print, print);
}

pub const Value = union(Tag) {
    int: Build(.int),
    uint: Build(.uint),
    float: Build(.float),
    string: Build(.string),
    tuple: Build(.tuple),
    void: Build(.void),

    pub fn init(comptime tag: Tag, data: meta.TagPayload(Value, tag)) Value {
        return @unionInit(Value, @tagName(tag), data);
    }

    pub fn parse(allocator: mem.Allocator, tag: Tag, data: []const u8) !Value {
        return switch (tag) {
            .int => init(.int, .{ .owned = false, .data = try fmt.parseInt(isize, data, 10) }),
            .uint => init(.uint, .{ .owned = false, .data = try fmt.parseInt(usize, data, 10) }),
            .float => init(.float, .{ .owned = false, .data = try fmt.parseFloat(f64, data) }),
            .string => init(.string, .{ .owned = true, .data = try allocator.dupe(u8, data) }),
            .void => init(.void, .{ .owned = false, .data = {} }),
            else => Error.ParseValueFailed,
        };
    }

    pub fn deinit(self: Value, allocator: mem.Allocator) void {
        switch (self) {
            .string => |string| if (string.owned) {
                allocator.free(string.data);
            },
            .tuple => |tuple| if (tuple.owned) {
                for (tuple.data) |value| {
                    value.deinit(allocator);
                }
            },
            else => {},
        }
    }

    pub fn typedMutation(self: Value, mutation: Mutation) ![]const Tag {
        return switch (mutation) {
            .add => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
            .sub => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
            .mul => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
            .div => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
        };
    }

    pub fn applyMutation(self: *Value, mutation: Mutation, values: []Value) !void {
        return switch (mutation) {
            .add => switch (self.*) {
                inline .int, .uint, .float => |*left, tag| left.data += try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
            .sub => switch (self.*) {
                inline .int, .uint, .float => |*left, tag| left.data -= try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
            .mul => switch (self.*) {
                inline .int, .uint, .float => |*left, tag| left.data *= try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
            .div => switch (self.*) {
                inline .int, .uint => |*left, tag| left.data = @divTrunc(left.data, try assert(tag, values[0])),
                inline .float => |*left, tag| left.data /= try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
        };
    }

    pub fn typedTransform(self: Value, transform: meta.FieldEnum(Transform)) ![]const Tag {
        return switch (transform) {
            .int => switch (self) {
                inline .uint => &.{},
                else => Error.InvalidTransform,
            },
            .uint => switch (self) {
                inline .int => &.{},
                else => Error.InvalidTransform,
            },
            .float => switch (self) {
                inline .int, .uint => &.{},
                else => Error.InvalidTransform,
            },
            .string => switch (self) {
                inline .int, .uint, .float => &.{},
                else => Error.InvalidTransform,
            },
            .print => &.{},
        };
    }

    pub fn applyTransform(self: Value, allocator: mem.Allocator, transform: Transform, _: []Value) !Value {
        return switch (transform) {
            .int => switch (self) {
                inline .uint => |value| init(.int, .{
                    .owned = false,
                    .data = @intCast(value.data),
                }),
                else => return Error.InvalidTransform,
            },
            .uint => switch (self) {
                inline .int => |value| init(.uint, .{
                    .owned = false,
                    .data = @intCast(value.data),
                }),
                else => return Error.InvalidTransform,
            },
            .float => switch (self) {
                inline .uint, .int => |value| init(.float, .{
                    .owned = false,
                    .data = @floatFromInt(value.data),
                }),
                else => return Error.InvalidTransform,
            },
            .string => switch (self) {
                inline .int, .uint, .float => |value| blk: {
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try fmt.allocPrint(allocator, "{d}", .{value.data}),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .print => |writer| switch (self) {
                inline .int, .uint, .float => |value| blk: {
                    try writer.print("{d}\n", .{value.data});
                    break :blk init(.void, .{
                        .owned = false,
                        .data = {},
                    });
                },
                inline .string => |value| blk: {
                    try writer.print("{s}\n", .{value.data});
                    break :blk init(.void, .{
                        .owned = false,
                        .data = {},
                    });
                },
                else => return Error.InvalidTransform,
            },
        };
    }

    pub fn assert(comptime tag: Tag, value: Value) !switch (tag) {
        .int => isize,
        .uint => usize,
        .float => f64,
        .string => []const u8,
        .tuple => []Value,
        .void => void,
    } {
        if (tag != meta.activeTag(value)) {
            return Error.TypeMismatch;
        }
        return switch (tag) {
            .int => value.int.data,
            .uint => value.uint.data,
            .float => value.float.data,
            .string => value.string.data,
            .tuple => value.tuple.data,
            .void => value.void.data,
        };
    }
};

test Value {
    // Mutations
    inline for (comptime meta.tags(Mutation)) |mutation| {
        switch (mutation) {
            .add => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const add_types = try value.typedMutation(.add);
                        try testing.expectEqualSlices(Tag, &.{tag}, add_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.add, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 10 }), value);
                    },
                    else => {},
                }
            },
            .sub => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const sub_types = try value.typedMutation(.sub);
                        try testing.expectEqualSlices(Tag, &.{tag}, sub_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.sub, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 0 }), value);
                    },
                    else => {},
                }
            },
            .mul => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const mul_types = try value.typedMutation(.sub);
                        try testing.expectEqualSlices(Tag, &.{tag}, mul_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.mul, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 25 }), value);
                    },
                    else => {},
                }
            },
            .div => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const div_types = try value.typedMutation(.div);
                        try testing.expectEqualSlices(Tag, &.{tag}, div_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.div, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 1 }), value);
                    },
                    else => {},
                }
            },
        }
    }

    // Transforms
    inline for (comptime meta.tags(meta.FieldEnum(Transform))) |transform| {
        switch (transform) {
            .int => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .uint => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const coercion = try value.typedTransform(.int);
                        try testing.expectEqualSlices(Tag, &.{}, coercion);

                        const coerced = try value.applyTransform(testing.allocator, .int, &.{});
                        defer coerced.deinit(testing.allocator);
                        try testing.expectEqual(Value.init(.int, .{ .owned = false, .data = 5 }), coerced);
                    },
                    else => {},
                }
            },
            .uint => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const coercion = try value.typedTransform(.uint);
                        try testing.expectEqualSlices(Tag, &.{}, coercion);

                        const coerced = try value.applyTransform(testing.allocator, .uint, &.{});
                        defer coerced.deinit(testing.allocator);
                        try testing.expectEqual(Value.init(.uint, .{ .owned = false, .data = 5 }), coerced);
                    },
                    else => {},
                }
            },
            .float => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const coercion = try value.typedTransform(.float);
                        try testing.expectEqualSlices(Tag, &.{}, coercion);

                        const coerced = try value.applyTransform(testing.allocator, .float, &.{});
                        defer coerced.deinit(testing.allocator);
                        try testing.expectEqual(Value.init(.float, .{ .owned = false, .data = 5 }), coerced);
                    },
                    else => {},
                }
            },
            .string => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const string_types = try value.typedTransform(.string);
                        try testing.expectEqualSlices(Tag, &.{}, string_types);

                        const string_value = try value.applyTransform(testing.allocator, .string, &.{});
                        defer string_value.deinit(testing.allocator);
                        try testing.expectEqualStrings("5", string_value.string.data);
                    },
                    else => {},
                }
            },
            .print => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const print_types = try value.typedTransform(.print);
                        try testing.expectEqualSlices(Tag, &.{}, print_types);
                    },
                    .string => {
                        var value = try Value.parse(testing.allocator, tag, "test");
                        defer value.deinit(testing.allocator);

                        const print_types = try value.typedTransform(.print);
                        try testing.expectEqualSlices(Tag, &.{}, print_types);
                    },
                    .void => {
                        var value = try Value.parse(testing.allocator, tag, "");
                        defer value.deinit(testing.allocator);

                        const print_types = try value.typedTransform(.print);
                        try testing.expectEqualSlices(Tag, &.{}, print_types);
                    },
                    else => {},
                }
            },
        }
    }
}
