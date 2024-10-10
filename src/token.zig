const std = @import("std");
const primitive = @import("type/primitive.zig");

const Token = @This();

lexeme: Lexeme,
location: Location,

pub const Lexeme = union(enum) {
    symbol: Symbol,
    operator: Operator,
    literal: Literal,
    special: Special,

    pub const Symbol = enum {
        colon,
    };

    pub const Operator = enum {
        arrow,
        chain,
        pipe,
    };

    pub const Literal = enum {
        int,
        float,
        string,
        identifier,
    };

    pub const Special = enum {
        module,
        invalid,
        end_of_frame,
    };

    pub fn init(comptime tag: std.meta.FieldEnum(Lexeme), comptime lexeme: std.meta.FieldType(Lexeme, tag)) Lexeme {
        return @unionInit(Lexeme, @tagName(tag), lexeme);
    }

    pub fn initString(string: []const u8) Lexeme {
        if (primitive.Type.fromString(string)) |lexeme| {
            return .{ .type = lexeme };
        }
        return .{ .literal = .identifier };
    }
};

pub const Location = struct {
    left: usize,
    right: usize,

    pub fn init(left: usize, right: usize) Location {
        return .{
            .left = left,
            .right = right,
        };
    }
};

pub fn init(lexeme: Lexeme, location: Location) Token {
    return .{
        .lexeme = lexeme,
        .location = location,
    };
}
