const std = @import("std");

pub const Type = @import("type.zig").Tag;
pub const Value = @import("type.zig").Value;

test {
    std.testing.refAllDecls(@This());
}
