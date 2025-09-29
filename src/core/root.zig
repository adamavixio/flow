const std = @import("std");

const @"type" = @import("type.zig");
pub const Mutation = @"type".Mutation;
pub const Transform = @"type".Transform;
pub const Type = @"type".Tag;
pub const Value = @"type".Value;

test {
    std.testing.refAllDecls(@This());
}
