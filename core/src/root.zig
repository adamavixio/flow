const std = @import("std");

pub const Core = @import("core.zig");
pub const Trait = @import("trait.zig");

test {
    std.testing.refAllDecls(Core);
    std.testing.refAllDecls(Trait);
}
