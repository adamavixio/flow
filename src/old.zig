const std = @import("std");
const identifier = @import("./identifier.zig");

pub fn Token(tag: identifier.Tag) type {
    return struct {
        const Self = @This();

        ident: identifier.Identifier(tag),
        lexeme: []const u8,

        pub fn init(lexeme: []const u8) Self {
            return .{
                .ident = identifier.init(lexeme[0]),
                .lexeme = lexeme,
            };
        }
    };
}

pub fn init(lexeme: []const u8) Token(lexeme[0]) {
    const tag = identifier.Tag.Init(lexeme[0]);
    return Token(tag).init(lexeme);
}

test "Token creation and properties" {
    const plus_token = init("+");
    try std.testing.expectEqual(identifier.Type.operator, plus_token.getType());
    try std.testing.expectEqual(identifier.Operator.plus, plus_token.getValue());
    try std.testing.expectEqualStrings("+", plus_token.lexeme);

    const number_token = init("42");
    try std.testing.expectEqual(identifier.Type.expression, number_token.getType());
    try std.testing.expectEqual(identifier.Expression.number, number_token.getValue());
    try std.testing.expectEqualStrings("42", number_token.lexeme);

    const illegal_token = init("$");
    try std.testing.expectEqual(identifier.Type.special, illegal_token.getType());
    try std.testing.expectEqual(identifier.Special.illegal, illegal_token.getValue());
    try std.testing.expectEqualStrings("$", illegal_token.lexeme);
}
