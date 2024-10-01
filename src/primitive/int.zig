const std = @import("std");

pub fn int(comptime Int: type) type {
    switch (@typeInfo(Int)) {
        .Int => {},
        else => @compileError("expected int"),
    }
    return struct {
        const Self = @This();
        data: Int,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, data: Int) !*Self {
            const self = try allocator.create(Self);
            self.* = .{ .data = data, .allocator = allocator };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
            self.* = undefined;
        }

        pub fn add(self: *Self, value: Int) void {
            self.data += value;
        }

        pub fn sub(self: *Self, value: Int) void {
            self.data -= value;
        }

        pub fn mul(self: *Self, value: Int) void {
            self.data *= value;
        }

        pub fn div(self: *Self, value: Int) void {
            self.data /= value;
        }
    };
}

test "int" {
    const testing = std.testing;

    var int_usize = try int(usize).init(testing.allocator, 0);
    defer int_usize.deinit();

    int_usize.add(10);
    try testing.expectEqual(int_usize.data, 10);

    int_usize.sub(5);
    try testing.expectEqual(int_usize.data, 5);

    int_usize.mul(2);
    try testing.expectEqual(int_usize.data, 10);

    int_usize.div(2);
    try testing.expectEqual(int_usize.data, 5);
}
