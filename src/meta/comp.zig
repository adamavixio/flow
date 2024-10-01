const std = @import("std");

pub fn Comparison(comptime Type: type) type {
    return struct {
        const Self = @This();

        condition: Condition,
        right_hand_side: Type,

        const Condition = switch (@typeInfo(Type)) {
            .Int => enum {
                less_than,
                less_than_equal_to,
                greater_than,
                greater_than_equal_to,
                equal_to,
            },
            .Float => enum {
                less_than,
                less_than_equal_to,
                greater_than,
                greater_than_equal_to,
                equal_to,
                is_nan,
                is_infinite,
            },
            .Array, .Vector => |info| switch (@typeInfo(info.child)) {
                .Int => enum {
                    has_prefix,
                    has_suffix,
                    contains,
                },
                else => @compileError("unsupported array child type '" ++ @typeName(info.child) ++ "'"),
            },
            .Pointer => |info| switch (info.size) {
                .One => switch (@typeInfo(info.child)) {
                    .Array, .Vector => switch (info.child) {
                        .Int => enum {
                            has_prefix,
                            has_suffix,
                            contains,
                        },
                        else => @compileError("unsupported pointer size one child type '" ++ @typeName(info.child) ++ "'"),
                    },
                    else => @compileError("unsupported pointer child type '" ++ @typeName(info.child) ++ "'"),
                },
                .Slice => switch (@typeInfo(info.child)) {
                    .Int => enum {
                        has_prefix,
                        has_suffix,
                        contains,
                    },
                    else => @compileError("unsupported slice child type '" ++ @typeName(info.child) ++ "'"),
                },
                else => @compileError("unsupported pointer size type'" ++ @typeName(info.size) ++ "'"),
            },
            else => @compileError("unsupported type '" ++ @typeName(Type) ++ "'"),
        };

        pub fn init(condition: Condition, right_hand_side: Type) Self {
            return .{ .condition = condition, .right_hand_side = right_hand_side };
        }

        pub fn evaluate(self: Self, left_hand_side: Type) bool {
            return switch (@typeInfo(Type)) {
                .Int => switch (self.condition) {
                    .less_than => left_hand_side < self.right_hand_side,
                    .less_than_equal_to => left_hand_side <= self.right_hand_side,
                    .greater_than => left_hand_side > self.right_hand_side,
                    .greater_than_equal_to => left_hand_side >= self.right_hand_side,
                    .equal_to => left_hand_side == self.right_hand_side,
                },
                .Float => switch (self.condition) {
                    .less_than => left_hand_side < self.right_hand_side,
                    .less_than_equal_to => left_hand_side <= self.right_hand_side,
                    .greater_than => left_hand_side > self.right_hand_side,
                    .greater_than_equal_to => left_hand_side >= self.right_hand_side,
                    .equal_to => left_hand_side == self.right_hand_side,
                    .is_nan => std.math.isNan(left_hand_side),
                    .is_infinite => std.math.isInf(left_hand_side),
                },
                .Array, .Vector => |info| switch (@typeInfo(info.child)) {
                    .Int => switch (self.condition) {
                        .has_prefix => std.mem.startsWith(u8, left_hand_side, self.right_hand_side),
                        .has_suffix => std.mem.endsWith(u8, left_hand_side, self.right_hand_side),
                        .contains => std.mem.indexOf(u8, left_hand_side, self.right_hand_side) != null,
                    },
                    else => unreachable,
                },
                .Pointer => |info| switch (info.size) {
                    .One => switch (@typeInfo(info.child)) {
                        .Array, .Vector => switch (info.child) {
                            .Int => switch (self.condition) {
                                .has_prefix => std.mem.startsWith(u8, left_hand_side, self.right_hand_side),
                                .has_suffix => std.mem.endsWith(u8, left_hand_side, self.right_hand_side),
                                .contains => std.mem.indexOf(u8, left_hand_side, self.right_hand_side) != null,
                            },
                            else => unreachable,
                        },
                        else => unreachable,
                    },
                    .Slice => switch (@typeInfo(info.child)) {
                        .Int => switch (self.condition) {
                            .has_prefix => std.mem.startsWith(u8, left_hand_side, self.right_hand_side),
                            .has_suffix => std.mem.endsWith(u8, left_hand_side, self.right_hand_side),
                            .contains => std.mem.indexOf(u8, left_hand_side, self.right_hand_side) != null,
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                },
                else => unreachable,
            };
        }
    };
}

test "compare condition evaluate" {
    inline for ([_]type{ u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize }) |Int| {
        const less_than = Comparison(Int).init(.less_than, 10);
        try std.testing.expect(less_than.evaluate(5));
        try std.testing.expect(!less_than.evaluate(10));
        try std.testing.expect(!less_than.evaluate(15));

        const less_than_equal_to = Comparison(Int).init(.less_than_equal_to, 10);
        try std.testing.expect(less_than_equal_to.evaluate(5));
        try std.testing.expect(less_than_equal_to.evaluate(10));
        try std.testing.expect(!less_than_equal_to.evaluate(15));

        const equal_to = Comparison(Int).init(.equal_to, 10);
        try std.testing.expect(!equal_to.evaluate(5));
        try std.testing.expect(equal_to.evaluate(10));
        try std.testing.expect(!equal_to.evaluate(15));

        const greater_than = Comparison(Int).init(.greater_than, 10);
        try std.testing.expect(!greater_than.evaluate(5));
        try std.testing.expect(!greater_than.evaluate(10));
        try std.testing.expect(greater_than.evaluate(15));

        const greater_than_equal_to = Comparison(Int).init(.greater_than_equal_to, 10);
        try std.testing.expect(!greater_than_equal_to.evaluate(5));
        try std.testing.expect(greater_than_equal_to.evaluate(10));
        try std.testing.expect(greater_than_equal_to.evaluate(15));
    }

    inline for ([_]type{ f16, f32, f64, f80, f128 }) |Float| {
        const less_than = Comparison(Float).init(.less_than, 10);
        try std.testing.expect(less_than.evaluate(5));
        try std.testing.expect(!less_than.evaluate(10));
        try std.testing.expect(!less_than.evaluate(15));

        const less_than_equal_to = Comparison(Float).init(.less_than_equal_to, 10);
        try std.testing.expect(less_than_equal_to.evaluate(5));
        try std.testing.expect(less_than_equal_to.evaluate(10));
        try std.testing.expect(!less_than_equal_to.evaluate(15));

        const equal_to = Comparison(Float).init(.equal_to, 10);
        try std.testing.expect(!equal_to.evaluate(5));
        try std.testing.expect(equal_to.evaluate(10));
        try std.testing.expect(!equal_to.evaluate(15));

        const greater_than = Comparison(Float).init(.greater_than, 10);
        try std.testing.expect(!greater_than.evaluate(5));
        try std.testing.expect(!greater_than.evaluate(10));
        try std.testing.expect(greater_than.evaluate(15));

        const greater_than_equal_to = Comparison(Float).init(.greater_than_equal_to, 10);
        try std.testing.expect(!greater_than_equal_to.evaluate(5));
        try std.testing.expect(greater_than_equal_to.evaluate(10));
        try std.testing.expect(greater_than_equal_to.evaluate(15));

        const is_nan = Comparison(Float).init(.is_nan, std.math.nan(Float));
        try std.testing.expect(!is_nan.evaluate(0));
        try std.testing.expect(is_nan.evaluate(std.math.nan(Float)));

        const is_infinite = Comparison(Float).init(.is_infinite, std.math.inf(Float));
        try std.testing.expect(!is_infinite.evaluate(0));
        try std.testing.expect(is_infinite.evaluate(std.math.inf(Float)));
    }

    {
        const has_prefix = Comparison([]const u8).init(.has_prefix, "prefix_");
        try std.testing.expect(has_prefix.evaluate("prefix_"));
        try std.testing.expect(has_prefix.evaluate("prefix_test"));
        try std.testing.expect(!has_prefix.evaluate("test"));

        const has_suffix = Comparison([]const u8).init(.has_suffix, "_suffix");
        try std.testing.expect(has_suffix.evaluate("_suffix"));
        try std.testing.expect(has_suffix.evaluate("test_suffix"));
        try std.testing.expect(!has_suffix.evaluate("test"));

        const contains = Comparison([]const u8).init(.contains, "test");
        try std.testing.expect(!contains.evaluate("prefix_"));
        try std.testing.expect(contains.evaluate("prefix_test"));
        try std.testing.expect(contains.evaluate("test"));
        try std.testing.expect(contains.evaluate("test_suffix"));
        try std.testing.expect(!contains.evaluate("_suffix"));
    }
}
