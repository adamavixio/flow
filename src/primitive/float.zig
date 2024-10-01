const std = @import("std");

pub fn float(comptime Float: type) type {
    switch (@typeInfo(Float)) {
        .Float => {},
        else => @compileError("expected float"),
    }
    return struct {
        const Self = @This();

        data: Float,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, data: Float) !*Self {
            const self = try allocator.create(Self);
            self.* = .{ .data = data, .allocator = allocator };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
            self.* = undefined;
        }

        pub fn add(self: *Self, value: Float) void {
            self.data += value;
        }

        pub fn sub(self: *Self, value: Float) void {
            self.data -= value;
        }

        pub fn mul(self: *Self, value: Float) void {
            self.data *= value;
        }

        pub fn div(self: *Self, value: Float) void {
            self.data /= value;
        }
    };
}

test "int" {
    var float_64 = try float(f64).init(std.testing.allocator, 0);
    defer float_64.deinit();

    float_64.add(10);
    try std.testing.expectEqual(float_64.data, 10);

    float_64.sub(5);
    try std.testing.expectEqual(float_64.data, 5);

    float_64.mul(2);
    try std.testing.expectEqual(float_64.data, 10);

    float_64.div(2);
    try std.testing.expectEqual(float_64.data, 5);
}
