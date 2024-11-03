const std = @import("std");

const core = @import("core.zig");
pub const FlowTag = core.FlowTag;
pub const FlowType = core.FlowType;

const status = @import("status.zig");
pub const CoreError = status.Error;

const trait = @import("trait.zig");
pub const Mutatable = trait.Mutatable;
pub const Transformable = trait.Transformable;
pub const Terminable = trait.Terminable;

test {
    std.testing.refAllDecls(core);
    std.testing.refAllDecls(status);
    std.testing.refAllDecls(trait);
}
