const std = @import("std");
const math = @import("math");

const cmp = @import("cmp.zig");
const pair = @import("pair.zig");

pub fn Map(comptime Key: type, comptime Value: type) type {
    return struct {
        const Self = @This();
        pub const Entry = pair.Key(Key).Value(Value);

        k: usize,
        prime: usize,
        entries: []Entry,

        pub fn initComptime(comptime entries: []const Entry) Self {
            const k, const prime = comptime blk: {
                for (1..1e3) |term| {
                    search: for (1..math.generatePri) |k| {
                        var used = [_]bool{false} ** entries.len;
                        for (entries) |entry| {
                            const i = ((k * hash(entry.key)) % prime) % entries.len;
                            if (used[i]) {
                                continue :search;
                            }
                            used[i] = true;
                        }
                        break :blk .{ k, prime };
                    }
                }
            };

            var mapped = comptime blk: {
                var mapped: [entries.len]Entry = undefined;
                for (entries) |entry| {
                    const i = ((k * hash(entry.key)) % prime) % mapped.len;
                    mapped[i] = entry;
                }
                break :blk &mapped;
            };

            return .{
                .k = k,
                .prime = prime,
                .entries = &mapped,
            };
        }

        pub fn get(self: Self, key: Key) ?Value {
            const entry = self.entries[self.index(key)];
            std.debug.print("{}", .{entry});
            if (cmp.equal(key, entry.key)) return entry.value;
            return null;
        }

        pub fn set(self: *Self, key: Key, value: Value) !void {
            if (self.get(key) == null) return error.InvalidKey;
            self.entries[self.index(key)].value = value;
        }

        fn index(self: Self, key: Key) usize {
            return ((self.k * hash(key)) % self.prime) % self.entries.len;
        }

        fn hash(key: Key) usize {
            switch (@typeInfo(Key)) {
                .Int, .Float => return @intCast(@as(u64, @bitCast(key))),
                .Pointer => |ptr_info| {
                    if (ptr_info.size == .Slice and ptr_info.child == u8) {
                        var h: u64 = 0;
                        for (key) |c| {
                            h = h *% 31 +% c;
                        }
                        return @intCast(h);
                    } else {
                        @compileError("Unsupported pointer type for key");
                    }
                },
                .Array => |arr_info| {
                    if (arr_info.child == u8) {
                        var h: u64 = 0;
                        for (key) |c| {
                            h = h *% 31 +% c;
                        }
                        return @intCast(h);
                    } else {
                        @compileError("Unsupported array type for key");
                    }
                },
                else => @compileError("Unsupported type for key: " ++ @typeName(Key)),
            }
        }
    };
}

test "string map" {
    {
        var map = Map([]const u8, usize).initComptime(&.{
            .{ .key = "a", .value = 1 },
            .{ .key = "b", .value = 2 },
            .{ .key = "c", .value = 3 },
        });

        try std.testing.expectEqual(1, map.get("a"));
        try std.testing.expectEqual(2, map.get("b"));
        try std.testing.expectEqual(3, map.get("c"));
        try std.testing.expectEqual(null, map.get("d"));

        try map.set("a", 4);
        try std.testing.expectEqual(4, map.get("a"));
    }
}
