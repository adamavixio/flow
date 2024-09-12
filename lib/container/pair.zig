const std = @import("std");

pub fn Key(comptime K: type) type {
    return struct {
        pub fn Value(comptime V: type) type {
            return struct { key: K, value: V };
        }
    };
}

pub fn initKeys(comptime K: type, comptime keys: []const K, value: anytype) [keys.len]Key(K).Value(@TypeOf(value)) {
    var pairs: [keys.len]Key(K).Value(@TypeOf(value)) = undefined;
    inline for (keys, 0..) |key, i| pairs[i] = .{ .key = key, .value = value };
    return pairs;
}

test "init keys" {
    const keys = [_][]const u8{ "a", "b", "c" };
    const pairs = initKeys([]const u8, &keys, true);
    std.debug.print("{any}", .{pairs});
}
