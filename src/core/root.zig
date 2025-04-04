const std = @import("std");

const value = @import("value.zig");

test {
    std.testing.refAllDecls(@This());
}
