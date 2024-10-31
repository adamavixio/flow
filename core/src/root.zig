const std = @import("std");
const @"type" = @import("type.zig");

const Type = @"type".Type;
const Primitive = @"type".map;

test {
    std.testing.refAllDecls(@"type");
}
