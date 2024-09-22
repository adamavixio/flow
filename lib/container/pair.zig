const std = @import("std");

pub fn Pair(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        key: K,
        value: V,

        pub fn init(key: K, value: V) Self {
            return .{ .key = key, .value = value };
        }
    };
}

test "pair" {
    const pair = Pair([]const u8, []const u8).init("key", "value");
    std.debug.print("{any}", .{pair});
}
