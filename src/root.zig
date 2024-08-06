const std = @import("std");

pub usingnamespace @import("stream.zig");

test {
    std.testing.refAllDecls(@This());
}
