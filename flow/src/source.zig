const std = @import("std");
const fs = std.fs;
const math = std.math;
const Allocator = std.mem.Allocator;

const root = @import("root.zig");
const Position = root.Position;

pub const Source = @This();

allocator: Allocator,
buffer: [:0]const u8,

pub fn initFile(allocator: Allocator, path: []const u8) !Source {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    const buffer = try file.readToEndAllocOptions(allocator, math.maxInt(usize), null, @alignOf(u8), 0);

    return .{
        .buffer = buffer,
        .allocator = allocator,
    };
}

pub fn initString(allocator: Allocator, content: []const u8) !Source {
    return .{
        .buffer = try allocator.dupeZ(u8, content),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Source) void {
    self.allocator.free(self.buffer);
}

pub fn slice(self: *Source, position: Position) []const u8 {
    return self.buffer[position.start..position.end];
}
