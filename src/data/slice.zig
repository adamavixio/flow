const std = @import("std");

pub fn Fixed(
    comptime T: type,
) type {
    return struct {
        const Self = @This();

        len: usize,
        data: []T,

        pub fn init(data: anytype) Self {
            return .{ .len = data.len, .data = data };
        }

        pub fn contains(self: *Self, value: T) bool {
            for (self.data) |element| if (element == value) return true;
            return false;
        }

        pub fn replace(self: *Self, value: T, with: T) void {
            for (self.data, 0..) |element, i| {
                if (element == value) self.data[i] = with;
            }
        }

        pub fn replaceSubslice(self: *Self, value: []T, with: []T) void {
            std.debug.assert(value.len != 0);
            std.debug.assert(with.len <= value.len);

            var i: usize = 0;
            var j: usize = 0;

            while (i < self.len) {
                if (std.mem.startsWith(T, self.data[i..], value)) {
                    std.mem.copyForwards(T, self.data[j..], with);
                    i += value.len;
                    j += with.len;
                } else {
                    self.data[j] = self.data[i];
                    i += 1;
                    j += 1;
                }
            }

            self.len = j;
        }
    };
}

// fn fixed(comptime T: type) Fixed(T) {
//     return .{};
// }

test "slice" {
    var data: [20]u8 = "this - is - a - test".*;
    var slice = Fixed(u8).init(data[0..]);

    try std.testing.expectEqualStrings("this - is - a - test", slice.data[0..]);
    try std.testing.expectEqual(true, slice.contains('-'));
    try std.testing.expectEqual(false, slice.contains('|'));

    slice.replace('-', '|');

    try std.testing.expectEqualSlices(u8, "this | is | a | test", slice.data[0..]);
    try std.testing.expectEqual(false, slice.contains('-'));
    try std.testing.expectEqual(true, slice.contains('|'));

    var subslice: [3]u8 = " | ".*;
    var subslice_with: [1]u8 = " ".*;
    slice.replaceSubslice(subslice[0..], subslice_with[0..]);

    try std.testing.expectEqualSlices(u8, "this is a test", slice.data[0..]);
    try std.testing.expectEqual(false, slice.contains('-'));
    try std.testing.expectEqual(false, slice.contains('|'));
}
