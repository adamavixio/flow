const std = @import("std");

pub const Logger = @import("logger.zig");

test {
    std.testing.refAllDecls(Logger);
}
