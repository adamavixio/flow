const std = @import("std");

pub const Language = struct {
    pub const Lexer = @import("lexer.zig");
    pub const Parser = @import("parser.zig");
    pub const Interpreter = @import("interpreter.zig");
};

pub const Primitive = struct {
    pub const Int = @import("primitive/int.zig");
    pub const Float = @import("primitive/float.zig");
    pub const String = @import("primitive/string.zig");
};

pub const Builtin = struct {
    pub const File = @import("builtin/file.zig");
    pub const Path = @import("builtin/path.zig");
};

test {
    std.testing.refAllDecls(Language);
    std.testing.refAllDecls(Primitive);
    std.testing.refAllDecls(Builtin);
}
