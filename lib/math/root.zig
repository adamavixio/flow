const std = @import("std");

pub usingnamespace @import("prime.zig");

test {
    std.testing.refAllDecls(@This());
}
