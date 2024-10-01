const std = @import("std");

pub const Enum = @import("enum.zig");

test {
    std.testing.refAllDecls(Enum);
}
