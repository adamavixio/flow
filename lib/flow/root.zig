const std = @import("std");

pub const Lexer = @import("lexer.zig");
pub const Parser = @import("parser.zig");
pub const Interpreter = @import("interpreter.zig");

test {
    std.testing.refAllDecls(Lexer);
    std.testing.refAllDecls(Parser);
    std.testing.refAllDecls(Interpreter);
}
