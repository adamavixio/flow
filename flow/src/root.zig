const std = @import("std");

pub const AST = @import("ast.zig");
// pub const Analyzer = @import("analyzer.zig");
pub const Lexer = @import("lexer.zig");
pub const Parser = @import("parser.zig");
pub const Position = @import("position.zig");
pub const Source = @import("source.zig");
pub const Token = @import("token.zig");

const @"type" = @import("type.zig");
pub const Registry = @"type".Registry;
pub const Type = @"type".Type;

test {
    std.testing.refAllDecls(AST);
    // std.testing.refAllDecls(Analyzer);
    std.testing.refAllDecls(Lexer);
    std.testing.refAllDecls(Parser);
    std.testing.refAllDecls(Position);
    std.testing.refAllDecls(Source);
    std.testing.refAllDecls(Token);
    std.testing.refAllDecls(@"type");
}
