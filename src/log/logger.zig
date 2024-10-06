const std = @import("std");
const builtin = @import("builtin");

const Self = @This();

level: std.log.Level,

pub fn init(level: std.log.Level) Self {
    return .{ .level = level };
}

pub fn prefix(level: std.log.Level) []const u8 {
    return switch (level) {
        .debug => "\x1b[90m",
        .info => "\x1b[34m",
        .warn => "\x1b[33m",
        .err => "\x1b[31m",
    };
}

pub fn log(self: Self, comptime level: std.log.Level, comptime format: []const u8, args: anytype) void {
    switch (builtin.mode) {
        .Debug => if (@intFromEnum(self.level) <= @intFromEnum(level)) {
            std.debug.print(prefix(level) ++ format ++ "\x1b[0m\n", args);
        },
        else => return,
    }
}

pub fn debug(self: Self, comptime format: []const u8, args: anytype) void {
    self.log(.debug, format, args);
}

pub fn info(self: Self, comptime format: []const u8, args: anytype) void {
    self.log(.info, format, args);
}

pub fn warn(self: Self, comptime format: []const u8, args: anytype) void {
    self.log(.warn, format, args);
}

pub fn err(self: Self, comptime format: []const u8, args: anytype) void {
    self.log(.err, format, args);
}
