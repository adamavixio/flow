const std = @import("std");

pub usingnamespace @import("ast.zig");
pub usingnamespace @import("interpreter.zig");
pub usingnamespace @import("lexer.zig");
pub usingnamespace @import("parser.zig");
pub usingnamespace @import("token.zig");

test {
    std.testing.refAllDecls(@This());
}
