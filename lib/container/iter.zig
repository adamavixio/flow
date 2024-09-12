const std = @import("std");
const map = @import("map.zig");
const pair = @import("pair.zig");

pub fn Collection(comptime T: type) type {
    return struct {
        const Self = @This();

        elements: []T,

        pub inline fn static(comptime elements: []const T) Self {
            var clone: [elements.len]T = undefined;
            for (elements, 0..) |element, i| clone[i] = element;
            return .{ .elements = &clone };
        }

        pub inline fn unique(self: *Self) void {
            const seen = pair.initKeys(T, self.elements, false);
            for (self.elements) |element| {
                if (!seen.get(element)) std.debug.print("{}\n", .{element});
                seen.set(element, true);
            }
        }
    };
}

test "collection" {
    var collection = Collection(usize).static(&.{ 1, 1, 2, 3 });
    collection.unique();
}
