const std = @import("std");

pub const Source = @This();

buffer: [:0]const u8,
allocator: std.mem.Allocator,

pub fn initFile(path: []const u8, allocator: std.mem.Allocator) !Source {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const buffer = try file.readToEndAllocOptions(
        allocator,
        std.math.maxInt(usize),
        null,
        @alignOf(u8),
        0,
    );

    return .{
        .buffer = buffer,
        .allocator = allocator,
    };
}

pub fn initString(content: []const u8, allocator: std.mem.Allocator) !Source {
    return .{
        .buffer = try allocator.dupeZ(u8, content),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Source) void {
    self.allocator.free(self.buffer);
}
