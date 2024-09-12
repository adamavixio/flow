const std = @import("std");
const testing = @import("testing");

const Self = @This();

pub const Lexeme = union(Tag) {
    pub const Tag = enum { keyword, operator, literal, special };
    pub const Keyword = enum { file, path };
    pub const Operator = enum { colon, arrow, pipe };
    pub const Literal = enum { string };
    pub const Special = enum { invalid, eof };

    keyword: Keyword,
    operator: Operator,
    literal: Literal,
    special: Special,

    pub fn init(string: []const u8) ?Lexeme {
        inline for (comptime std.meta.tags(Keyword)) |tag| {
            if (std.mem.eql(u8, string, @tagName(tag))) {
                return .{ .keyword = tag };
            }
        }
        return null;
    }

    pub fn initOperator(str: []const u8) ?Lexeme {
        if (std.mem.eql(u8, str, "->")) return .{ .operator = .arrow };
        if (std.mem.eql(u8, str, ":")) return .{ .operator = .colon };
        if (std.mem.eql(u8, str, "|")) return .{ .operator = .pipe };
        return null;
    }
};

left: usize,
right: usize,
lexeme: Lexeme,

pub fn init(left: usize, right: usize, lexeme: Lexeme) Self {
    return .{ .left = left, .right = right, .lexeme = lexeme };
}
