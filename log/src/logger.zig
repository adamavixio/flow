const std = @import("std");
const datetime = @import("datetime");

const Logger = @This();

level: std.log.Level,
writer: std.io.AnyWriter,

pub fn init(level: std.log.Level, writer: std.io.AnyWriter) Logger {
    return .{ .level = level, .writer = writer };
}

pub fn default() Logger {
    return init(std.log.default_level, std.io.getStdErr().writer().any());
}
pub fn log(self: Logger, comptime level: std.log.Level, comptime format: []const u8, args: anytype) !void {
    if (@intFromEnum(self.level) > @intFromEnum(level)) return;
    try self.writer.print("{s}[", .{color(level)});
    try datetime.now().write(self.writer);
    try self.writer.print("] [{s}]\x1b[0m ", .{label(level)});
    try self.writer.print(format, args);
    try self.writer.print("\n", .{});
}

pub fn debug(self: Logger, comptime format: []const u8, args: anytype) !void {
    try self.log(.debug, format, args);
}

pub fn info(self: Logger, comptime format: []const u8, args: anytype) !void {
    try self.log(.info, format, args);
}

pub fn warn(self: Logger, comptime format: []const u8, args: anytype) !void {
    try self.log(.warn, format, args);
}

pub fn err(self: Logger, comptime format: []const u8, args: anytype) !void {
    try self.log(.err, format, args);
}

pub fn label(level: std.log.Level) []const u8 {
    return switch (level) {
        .debug => "DEBUG",
        .info => "INFO",
        .warn => "WARN",
        .err => "ERROR",
    };
}

pub fn color(level: std.log.Level) []const u8 {
    return switch (level) {
        .debug => "\x1b[90m",
        .info => "\x1b[34m",
        .warn => "\x1b[33m",
        .err => "\x1b[31m",
    };
}

test "log levels" {
    const allocator = std.testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const levels = [_]std.log.Level{ .debug, .info, .warn, .err };
    inline for (levels) |level| {
        const logger = init(level, buffer.writer().any());

        inline for (levels) |logged| {
            try switch (logged) {
                .debug => logger.debug("{s}", .{"test"}),
                .info => logger.info("{s}", .{"test"}),
                .warn => logger.warn("{s}", .{"test"}),
                .err => logger.err("{s}", .{"test"}),
            };

            if (@intFromEnum(level) <= @intFromEnum(logged)) {
                try std.testing.expectEqual(1, std.mem.count(u8, buffer.items, label(logged)));
                try std.testing.expectEqual(1, std.mem.count(u8, buffer.items, "test"));
                buffer.clearRetainingCapacity();
            } else {
                try std.testing.expectFmt(buffer.items, "", .{});
            }
        }
    }
}

test "log colors" {
    try std.testing.expectEqualStrings("\x1b[90m", color(.debug));
    try std.testing.expectEqualStrings("\x1b[34m", color(.info));
    try std.testing.expectEqualStrings("\x1b[33m", color(.warn));
    try std.testing.expectEqualStrings("\x1b[31m", color(.err));
}
