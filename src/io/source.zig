const std = @import("std");
const fs = std.fs;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

pub const Source = @This();

buffer: [:0]const u8,

pub fn initFile(allocator: mem.Allocator, path: []const u8) !Source {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    const buffer = try file.readToEndAllocOptions(allocator, math.maxInt(usize), null, @alignOf(u8), 0);
    return .{ .buffer = buffer };
}

test initFile {
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const path = try fs.path.join(testing.allocator, &.{ &tmp_dir.sub_path, "test.flow" });
    defer testing.allocator.free(path);
    const file = try tmp_dir.dir.createFile("test.flow", .{});
    defer file.close();
    const content = "test content";
    try file.writeAll(content);

    const tmp_path = try fs.path.join(testing.allocator, &.{ ".zig-cache", "tmp", path });
    defer testing.allocator.free(tmp_path);
    var source = try initFile(testing.allocator, tmp_path);
    defer source.deinit(testing.allocator);

    try testing.expectEqualStrings(content, source.buffer);
}

pub fn initString(allocator: mem.Allocator, content: []const u8) !Source {
    return .{ .buffer = try allocator.dupeZ(u8, content) };
}

pub fn deinit(self: *Source, allocator: mem.Allocator) void {
    allocator.free(self.buffer);
}
