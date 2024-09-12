pub usingnamespace (@import("suite.zig"));
pub usingnamespace (@import("string.zig"));

test {
    @import("std").testing.refAllDecls(@This());
}
