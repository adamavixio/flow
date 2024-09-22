const std = @import("std");

pub fn primes(comptime n: u32) Primes(n) {
    return .{};
}

pub fn Primes(comptime n: u32) type {
    return struct {
        const Self = @This();
        const size = @max(128, n * std.math.log2(n));

        prime: usize = 1,
        valid: [size]bool = [_]bool{true} ** size,

        pub fn next(self: *Self) usize {
            self.prime += 1;
            while (!self.valid[self.prime]) self.prime += 1;
            var i = self.prime * self.prime;
            while (i < size) : (i += self.prime) self.valid[i] = false;
            return self.prime;
        }
    };
}

test "primes" {
    comptime {
        var seq = primes(100);
        try std.testing.expectEqual(2, seq.next());
        try std.testing.expectEqual(3, seq.next());
        try std.testing.expectEqual(5, seq.next());
        try std.testing.expectEqual(7, seq.next());
        try std.testing.expectEqual(11, seq.next());
    }
}
