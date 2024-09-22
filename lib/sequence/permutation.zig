const std = @import("std");
const range = @import("./range.zig");

fn Indexes(comptime n: usize) type {
    return struct {
        const Self = @This();
        const Range = range.Range(usize, .exclusive).Static(0, n, 1);

        iter: [n]usize,
        done: bool,

        pub fn init() Self {
            return .{
                .permutation = Range.collect(),
                .done = false,
            };
        }

        pub fn next(self: *Self) ?[n]usize {
            if (self.done) return null;

            var result: [n]usize = undefined;
            std.mem.copyForwards(usize, &result, &self.permutation);

            if (n == 1) {
                self.done = true;
                return result;
            }

            var k: usize = n - 2;
            while (self.permutation[k] >= self.permutation[k + 1]) : (k -= 1) {
                if (k == 0) {
                    self.done = true;
                    return result;
                }
            }

            var l: usize = n - 1;
            while (self.permutation[@intCast(k)] >= self.permutation[l]) : (l -= 1) {}

            std.mem.swap(usize, &self.permutation[@intCast(k)], &self.permutation[l]);
            std.mem.reverse(usize, self.permutation[@intCast(k + 1)..]);

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
