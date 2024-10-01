const std = @import("std");

const Self = @This();

path: []const u8,
file: std.fs.File,

pub fn open(path: []const u8) !Self {
    return try std.fs.cwd().openFile(path, .{ .mode = .read_write });
}

pub fn create(path: []const u8) !Self {
    if (std.fs.cwd().openFile(path, .{ .mode = .read_write })) |file| {
        return .{
            .path = path,
            .file = file,
        };
    } else |err| switch (err) {
        .FileNotFound => return Self{
            .path = path,
            .file = try std.fs.cwd().createFile(path, .{}),
        },
        else => return err,
    }
}

pub fn createWithContent(path: []const u8, content: []const u8) !Self {
    const file = try create(path);
    try file.write(content);
    return file;
}

pub fn read(self: Self, destination: []const u8) !void {
    try self.file.readAll(destination);
}

pub fn write(self: *Self, content: []const u8) !void {
    try self.file.seekTo(0);
    try self.file.writeAll(content);
    try self.file.setEndPos(content.len);
}

pub fn delete(self: Self) !void {
    self.close();
    try std.fs.deletefil(self.path);
}

pub fn close(self: Self) void {
    self.file.close();
}
