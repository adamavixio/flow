const std = @import("std");

const Self = @This();

len: usize,
data: []u8,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, data: []const u8) !Self {
    return .{
        .len = data.len,
        .data = try allocator.dupe(u8, data),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.data);
    self.* = undefined;
}

pub fn sort(self: *Self, comptime order: enum { asc, desc }) void {
    std.mem.sort(u8, self.data, {}, switch (order) {
        .asc => std.sort.asc(u8),
        .desc => std.sort.desc(u8),
    });
}

pub fn unique(self: *Self) !void {
    var seen = std.AutoHashMap(u8, void).init(self.allocator);
    defer seen.deinit();

    var write_index: usize = 0;
    for (0..self.len) |read_index| {
        const char = self.data[read_index];
        if (!seen.contains(char)) {
            try seen.put(char, {});
            self.data[write_index] = char;
            write_index += 1;
        }
    }

    if (write_index < self.data.len) {
        self.len = write_index;
        self.data = try self.allocator.realloc(self.data, write_index);
    }
}

test "String operations" {
    var string = try init(std.testing.allocator, "ccbbaa");
    defer string.deinit();

    try std.testing.expectEqual(6, string.len);
    try std.testing.expectEqualStrings("ccbbaa", string.data);

    string.sort(.asc);
    try std.testing.expectEqual(6, string.len);
    try std.testing.expectEqualStrings("aabbcc", string.data);

    try string.unique();
    try std.testing.expectEqual(3, string.len);
    try std.testing.expectEqualStrings("abc", string.data);
}
