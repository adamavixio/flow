const std = @import("std");

pub fn main() void {
    const data = Buffer();
    std.debug.print("{any}", .{data});
}

fn Buffer() []const u8 {
    const data = [_]u8{ 0, 1, 2, 3 };
    return data[0..4];
}
