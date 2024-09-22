const std = @import("std");

pub const Bound = enum {
    exclusive,
    inclusive,
};

pub fn Range(comptime N: type, comptime bound: Bound) type {
    switch (@typeInfo(N)) {
        .Int, .Float => {},
        else => @compileError("Parameter 'N' must be 'Int' or 'Float'"),
    }

    return struct {
        iter: N,
        step: N,
        start: N,
        stop: N,

        pub fn init(start: N, stop: N, step: N) @This() {
            if (step < 1) @panic("Parameter 'step' cannot be less than '1'");
            return .{ .iter = @min(start, stop), .step = step, .start = start, .stop = stop };
        }

        pub fn next(self: *@This()) ?N {
            const curr = @min(self.start, self.stop) + self.iter;
            const last = @max(self.start, self.stop) + @intFromEnum(bound);
            if (curr >= last) return null;
            const value = blk: {
                if (self.start <= self.stop) break :blk self.iter;
                break :blk self.start - self.iter;
            };
            self.iter += 1;
            return value;
        }

        pub fn Static(comptime start: N, comptime stop: N, comptime step: N) type {
            if (step < 1) @compileError("Parameter 'step' cannot be less than '1'");
            return struct {
                pub const min: N = @min(start, stop);
                pub const max: N = @max(start, stop);
                pub const size: N = (max - min + @intFromEnum(bound)) / step;

                iter: N,

                pub fn init() @This() {
                    return .{ .iter = min };
                }

                pub fn next(self: *@This()) ?N {
                    const curr = min + self.iter;
                    const last = max + @intFromEnum(bound);
                    if (curr >= last) return null;
                    const value = blk: {
                        if (start <= stop) break :blk self.iter;
                        break :blk start - self.iter;
                    };
                    self.iter += step;
                    return value;
                }

                pub fn collect() [size]N {
                    var iter = min;
                    var sequence: [size]N = undefined;
                    for (0..size) |i| {
                        sequence[i] = blk: {
                            if (start <= stop) break :blk iter;
                            break :blk start - iter;
                        };
                        iter += step;
                    }
                    return sequence;
                }
            };
        }
    };
}

test "dynamic range sequence - exclusive ascending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .exclusive).init(0, 5, 1);
            try std.testing.expectEqual(0, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "dynamic range sequence - exclusive descending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .exclusive).init(5, 0, 1);
            try std.testing.expectEqual(5, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "dynamic range sequence - inclusive ascending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .inclusive).init(0, 5, 1);
            try std.testing.expectEqual(0, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(5, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "dynamic range sequence - inclusive descending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .inclusive).init(5, 0, 1);
            try std.testing.expectEqual(5, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(0, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "static range sequence - exclusive ascending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .exclusive).Static(0, 5, 1).init();
            try std.testing.expectEqual(0, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "static range sequence - exclusive descending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .exclusive).Static(5, 0, 1).init();
            try std.testing.expectEqual(5, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "static range sequence - inclusive ascending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .inclusive).Static(0, 5, 1).init();
            try std.testing.expectEqual(0, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(5, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "static range sequence - inclusive descending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            var range = Range(N, .inclusive).Static(5, 0, 1).init();
            try std.testing.expectEqual(5, range.next());
            try std.testing.expectEqual(4, range.next());
            try std.testing.expectEqual(3, range.next());
            try std.testing.expectEqual(2, range.next());
            try std.testing.expectEqual(1, range.next());
            try std.testing.expectEqual(0, range.next());
            try std.testing.expectEqual(null, range.next());
        }
    }
}

test "static range collection - exclusive ascending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            const set = Range(N, .exclusive).Static(0, 5, 1).collect();
            try std.testing.expectEqualSlices(N, &.{ 0, 1, 2, 3, 4 }, &set);
        }
    }
}

test "static range collection - exclusive descending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            const set = Range(N, .exclusive).Static(5, 0, 1).collect();
            try std.testing.expectEqualSlices(N, &.{ 5, 4, 3, 2, 1 }, &set);
        }
    }
}

test "static range collection - inclusive ascending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            const set = Range(N, .inclusive).Static(0, 5, 1).collect();
            try std.testing.expectEqualSlices(N, &.{ 0, 1, 2, 3, 4, 5 }, &set);
        }
    }
}

test "static range collection - inclusive descending" {
    inline for ([_]type{ usize, isize }) |N| {
        {
            const set = Range(N, .inclusive).Static(5, 0, 1).collect();
            try std.testing.expectEqualSlices(N, &.{ 5, 4, 3, 2, 1, 0 }, &set);
        }
    }
}
