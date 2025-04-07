const std = @import("std");
const builtin = std.builtin;
const fmt = std.fmt;
const heap = std.heap;
const io = std.io;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;

pub const Tag = enum {
    i8,
    i16,
    i32,
    i64,
    i128,
    int,
    u8,
    u16,
    u32,
    u64,
    u128,
    uint,
    f16,
    f32,
    f64,
    f128,
    float,
    string,
    void,

    pub fn parse(literal: []const u8) !Tag {
        if (meta.stringToEnum(Tag).parse(literal)) |tag|
            return tag;
        return core.Error.InvalidType;
    }
};

pub fn Base(comptime tag: Tag) type {
    return switch (tag) {
        .i8 => i8,
        .i16 => i16,
        .i32 => i32,
        .i64 => i64,
        .i128 => i128,
        .int => isize,
        .u8 => u8,
        .u16 => u16,
        .u32 => u32,
        .u64 => u64,
        .u128 => u128,
        .uint => usize,
        .f16 => f16,
        .f32 => f32,
        .f64 => f64,
        .f128 => f128,
        .float => f64,
        .string => []const u8,
        .void => void,
    };
}

pub const Info = union(enum) {
    int: Int,
    float: Float,
    string: String,
    void: void,

    pub const Int = struct {
        signed: bool,
    };

    pub const Float = struct {};

    pub const String = struct {};

    pub fn init(tag: Tag) Info {
        return switch (tag) {
            .i8, .i16, .i32, .i64, .i128, .int => .{
                .int = .{ .signed = true },
            },
            .u8, .u16, .u32, .u64, .u128, .uint => .{
                .int = .{ .signed = false },
            },
            .f16, .f32, .f64, .f128, .float => .{
                .float = .{},
            },
            .string => .{
                .string = .{},
            },
            .void => .{ .void = {} },
        };
    }
};

pub fn Build(comptime tag: Tag) type {
    const T = Base(tag);
    return switch (Info.init(tag)) {
        .int => struct {
            const Self = @This();
            data: T,

            pub fn parse(literal: []const u8) !Self {
                return .{ .data = try fmt.parseInt(T, literal, 10) };
            }

            pub fn add(self: Self, other: Self) Self {
                return .{ .data = self.data + other.data };
            }

            pub fn sub(self: Self, other: Self) Self {
                return .{ .data = self.data - other.data };
            }

            pub fn mul(self: Self, other: Self) Self {
                return .{ .data = self.data * other.data };
            }

            pub fn div(self: Self, other: Self) Self {
                return .{ .data = @divTrunc(self.data, other.data) };
            }

            pub fn string(self: Self, allocator: mem.Allocator) !Build(.string) {
                const buffer = try fmt.allocPrint(allocator, "{d}", .{self.data});
                return Build(.string).initOwned(buffer);
            }

            pub fn print(self: Self, writer: io.AnyWriter) !void {
                return try writer.print("{d}", .{self.data});
            }

            pub fn equal(self: Self, other: Self) bool {
                return self.data == other.data;
            }
        },
        .float => struct {
            const Self = @This();
            data: T,

            pub fn parse(literal: []const u8) !Self {
                return .{ .data = try fmt.parseFloat(T, literal) };
            }

            pub fn add(self: Self, other: Self) Self {
                return .{ .data = self.data + other.data };
            }

            pub fn sub(self: Self, other: Self) Self {
                return .{ .data = self.data - other.data };
            }

            pub fn mul(self: Self, other: Self) Self {
                return .{ .data = self.data * other.data };
            }

            pub fn div(self: Self, other: Self) Self {
                return .{ .data = @divTrunc(self.data, other.data) };
            }

            pub fn string(self: Self, allocator: mem.Allocator) !Build(.string) {
                const buffer = try fmt.allocPrint(allocator, "{d}", .{self.data});
                return Build(.string).initOwned(buffer);
            }

            pub fn print(self: Self, writer: io.AnyWriter) !void {
                return try writer.print("{d}", .{self.data});
            }

            pub fn equal(self: Self, other: Self) !bool {
                return self.data == other.data;
            }
        },
        .string => struct {
            const Self = @This();
            data: T,
            owned: bool,

            pub fn parse(literal: []const u8) !Self {
                return .{ .data = literal, .owned = false };
            }

            pub fn initOwned(literal: []const u8) !Self {
                return .{ .data = literal, .owned = true };
            }

            pub fn deinit(self: Self, allocator: mem.Allocator) void {
                if (self.owned) allocator.free(self.data);
            }

            pub fn print(self: Self, writer: io.AnyWriter) !void {
                return try writer.print("{s}", .{self.data});
            }

            pub fn equal(self: Self, other: Self) bool {
                return mem.eql(u8, self.data, other.data);
            }
        },
        .void => struct {
            const Self = @This();

            pub fn parse(literal: []const u8) !Self {
                _ = literal;
                return .{};
            }

            pub fn print(_: Self, _: io.AnyWriter) !void {
                return;
            }
        },
    };
}

pub const Value = union(Tag) {
    i8: Build(.i8),
    i16: Build(.i16),
    i32: Build(.i32),
    i64: Build(.i64),
    i128: Build(.i128),
    int: Build(.int),

    u8: Build(.u8),
    u16: Build(.u16),
    u32: Build(.u32),
    u64: Build(.u64),
    u128: Build(.u128),
    uint: Build(.uint),

    f16: Build(.f16),
    f32: Build(.f32),
    f64: Build(.f64),
    f128: Build(.f128),
    float: Build(.float),

    string: Build(.string),

    void: Build(.void),

    pub fn init(tag: Tag, literal: []const u8) !Value {
        return switch (tag) {
            inline else => |t| @unionInit(Value, @tagName(t), try Build(t).parse(literal)),
        };
    }

    pub fn deinit(self: Value, allocator: mem.Allocator) void {
        switch (self) {
            .string => |v| v.deinit(allocator),
            else => {},
        }
    }

    pub const Operation = enum {
        add,
        sub,
        mul,
        div,
    };

    pub fn hasOperation(self: Value, operation: Operation) bool {
        return switch (self) {
            inline else => |v| switch (operation) {
                inline else => |o| meta.hasMethod(@TypeOf(v), @tagName(o)),
            },
        };
    }

    pub fn applyOperation(self: Value, operation: Operation, other: Value) !Value {
        switch (self) {
            inline .i8, .i16, .i32, .i64, .i128, .int, .u8, .u16, .u32, .u64, .u128, .uint => |v, t| {
                return @unionInit(Value, @tagName(t), switch (operation) {
                    .add => v.add(@field(other, @tagName(t))),
                    .sub => v.sub(@field(other, @tagName(t))),
                    .mul => v.mul(@field(other, @tagName(t))),
                    .div => v.div(@field(other, @tagName(t))),
                });
            },
            inline .f16, .f32, .f64, .f128, .float => |v, t| {
                return @unionInit(Value, @tagName(t), switch (operation) {
                    .add => v.add(@field(other, @tagName(t))),
                    .sub => v.sub(@field(other, @tagName(t))),
                    .mul => v.mul(@field(other, @tagName(t))),
                    .div => v.div(@field(other, @tagName(t))),
                });
            },
            inline .string, .void => return core.Error.InvalidOperation,
        }
    }

    pub const Transform = union(enum) {
        string,
        print: io.AnyWriter,
    };

    pub fn hasTransform(self: Value, transform: meta.FieldEnum(Transform)) bool {
        return switch (self) {
            inline else => |v| switch (transform) {
                inline else => |t| meta.hasMethod(@TypeOf(v), @tagName(t)),
            },
        };
    }

    pub fn applyTransform(self: Value, allocator: mem.Allocator, transform: Transform) !Value {
        switch (self) {
            inline .i8, .i16, .i32, .i64, .i128, .int, .u8, .u16, .u32, .u64, .u128, .uint => |v| {
                return switch (transform) {
                    .string => @unionInit(Value, @tagName(.string), try v.string(allocator)),
                    .print => |writer| blk: {
                        try v.print(writer);
                        break :blk @unionInit(Value, "void", .{});
                    },
                };
            },
            inline .f16, .f32, .f64, .f128, .float => |v| {
                return switch (transform) {
                    .string => @unionInit(Value, @tagName(.string), try v.string(allocator)),
                    .print => |writer| blk: {
                        try v.print(writer);
                        break :blk @unionInit(Value, "void", .{});
                    },
                };
            },
            inline .string => |v| {
                return switch (transform) {
                    .print => blk: {
                        try v.print(std.io.getStdOut().writer().any());
                        break :blk @unionInit(Value, "void", .{});
                    },
                    else => core.Error.InvalidTransform,
                };
            },
            inline .void => return core.Error.InvalidTransform,
        }
    }

    pub const Comparison = enum {
        equal,
    };

    pub fn hasComparison(self: Value, comparison: Comparison) bool {
        return switch (self) {
            inline else => |v| switch (comparison) {
                inline else => |t| meta.hasMethod(@TypeOf(v), @tagName(t)),
            },
        };
    }

    pub fn applyComparison(self: Value, comparison: Comparison, other: Value) !bool {
        switch (self) {
            inline .i8, .i16, .i32, .i64, .i128, .int, .u8, .u16, .u32, .u64, .u128, .uint => |v, t| {
                return switch (comparison) {
                    .equal => v.equal(@field(other, @tagName(t))),
                };
            },
            inline .f16, .f32, .f64, .f128, .float => |v, t| {
                return switch (comparison) {
                    .equal => v.equal(@field(other, @tagName(t))),
                };
            },
            inline .string => |v, t| {
                return switch (comparison) {
                    .equal => v.equal(@field(other, @tagName(t))),
                };
            },
            inline .void => return core.Error.InvalidTransform,
        }
    }
};

test Value {
    // Test Operations
    @setEvalBranchQuota(10_000);
    for (comptime meta.tags(Tag)) |tag| {
        switch (Info.init(tag)) {
            .int, .float => {
                const value = try Value.init(tag, "10");
                try testing.expect(value.hasOperation(.add));
                try testing.expect(value.hasOperation(.sub));
                try testing.expect(value.hasOperation(.mul));
                try testing.expect(value.hasOperation(.div));

                const operand = try Value.init(tag, "5");
                const add_actual = try value.applyOperation(.add, operand);
                const sub_actual = try value.applyOperation(.sub, operand);
                const mul_actual = try value.applyOperation(.mul, operand);
                const div_actual = try value.applyOperation(.div, operand);
                const add_expected = try Value.init(tag, "15");
                const sub_expected = try Value.init(tag, "5");
                const mul_expected = try Value.init(tag, "50");
                const div_expected = try Value.init(tag, "2");
                try testing.expect(try add_expected.applyComparison(.equal, add_actual));
                try testing.expect(try sub_expected.applyComparison(.equal, sub_actual));
                try testing.expect(try mul_expected.applyComparison(.equal, mul_actual));
                try testing.expect(try div_expected.applyComparison(.equal, div_actual));
            },
            .string => {},
            .void => {},
        }
    }

    // Test Transforms
    @setEvalBranchQuota(10_000);
    for (comptime meta.tags(Tag)) |tag| {
        switch (Info.init(tag)) {
            .int, .float => {
                const value = try Value.init(tag, "10");
                try testing.expect(value.hasTransform(.string));
                try testing.expect(value.hasTransform(.print));

                const string_actual = try value.applyTransform(testing.allocator, .string);
                defer string_actual.deinit(testing.allocator);
                const string_expected = try Value.init(.string, "10");
                defer string_expected.deinit(testing.allocator);
                try testing.expect(try string_expected.applyComparison(.equal, string_actual));

                var buffer = std.ArrayList(u8).init(testing.allocator);
                defer buffer.deinit();

                _ = try value.applyTransform(testing.allocator, .{ .print = buffer.writer().any() });
                try testing.expectEqualStrings("10", buffer.items);
            },
            .string => {},
            .void => {},
        }
    }
}
