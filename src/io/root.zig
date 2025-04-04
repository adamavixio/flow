const std = @import("std");

pub const Source = @import("source.zig");

test {
    std.testing.refAllDecls(@This());
}
