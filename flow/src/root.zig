const std = @import("std");

pub const Flow = struct {
    pub const Lexer = @import("lexer.zig");
    pub const Parser = @import("parser.zig");
    pub const Interpreter = @import("interpreter.zig");
};

test {
    std.testing.refAllDecls(Flow);
}
