const std = @import("std");

inline fn primes(comptime n: usize) [n]usize {
    comptime {
        const m = @max(128, n * std.math.log2(n));

        var index = 0;
        var prime = [_]usize{0} ** n;
        var valid = [_]bool{true} ** m;

        @setEvalBranchQuota(1e9);
        for (2..m) |i| {
            if (valid[i]) {
                var j = i * i;
                while (j < m) : (j += i) {
                    valid[j] = false;
                }
                prime[index] = i;
                index += 1;
                if (index >= n) {
                    break;
                }
            }
        }

        return prime;
    }
}

test "generate primes" {
    const result = primes(10);
    std.debug.print("{any}", .{result});
}
