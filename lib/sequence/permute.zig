const std = @import("std");
const range = @import("./range.zig");

fn Indexes(comptime n: usize) type {
    return struct {
        const Self = @This();
        const Range = range.Range(usize, .exclusive).Static(0, n, 1);

        iter: [n]usize,
        done: bool,

        pub fn init() Self {
            return .{ .iter = Range.collect(), .done = false };
        }

        pub fn next(self: *Self) ?[n]usize {
            if (self.done) return null;

            var result: [n]usize = undefined;
            std.mem.copyForwards(usize, &result, &self.iter);

            if (n == 1) {
                self.done = true;
                return result;
            }

            var k: usize = n - 2;
            while (self.iter[k] >= self.iter[k + 1]) : (k -= 1) {
                if (k == 0) {
                    self.done = true;
                    return result;
                }
            }

            var l: usize = n - 1;
            while (self.iter[@intCast(k)] >= self.iter[l]) : (l -= 1) {}

            std.mem.swap(usize, &self.iter[@intCast(k)], &self.iter[l]);
            std.mem.reverse(usize, self.iter[@intCast(k + 1)..]);

            return result;
        }
    };
}

test "index permutations" {
    const n = 3;
    var gen = Indexes(n).init();

    while (gen.next()) |permutation| {
        std.debug.print("Permutation: ", .{});
        for (permutation) |value| {
            std.debug.print("{} ", .{value});
        }
        std.debug.print("\n", .{});
    }
}
