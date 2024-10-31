const std = @import("std");
const datetime = @import("datetime.zig");

pub const Datetime = datetime.DateTime;
pub const now = datetime.now;

test {
    std.testing.refAllDecls(datetime);
}
