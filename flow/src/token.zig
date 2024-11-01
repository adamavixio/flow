const std = @import("std");
const Token = @This();

kind: Kind,
location: Location,

pub const Kind = enum {
    identifier,

    keyword_i8,
    keyword_i16,
    keyword_i32,
    keyword_i64,
    keyword_i128,
    keyword_int,
    keyword_u8,
    keyword_u16,
    keyword_u32,
    keyword_u64,
    keyword_u128,
    keyword_uint,
    keyword_f16,
    keyword_f32,
    keyword_f64,
    keyword_f128,
    keyword_float,
    keyword_bytes,
    keyword_string,

    symbol_colon,

    operator_arrow,
    operator_chain,
    operator_pipe,

    literal_int,
    literal_float,
    literal_string,

    special_invalid,
    special_end_of_frame,
};

pub const Location = struct {
    left: usize,
    right: usize,
};

pub const keywords = std.StaticStringMap(Kind).initComptime(.{
    .{ "i8", .keyword_i8 },
    .{ "i16", .keyword_i16 },
    .{ "i32", .keyword_i32 },
    .{ "i64", .keyword_i64 },
    .{ "i128", .keyword_i128 },
    .{ "int", .keyword_int },
    .{ "u8", .keyword_u8 },
    .{ "u16", .keyword_u16 },
    .{ "u32", .keyword_u32 },
    .{ "u64", .keyword_u64 },
    .{ "u128", .keyword_u128 },
    .{ "uint", .keyword_uint },
    .{ "f16", .keyword_f16 },
    .{ "f32", .keyword_f32 },
    .{ "f64", .keyword_f64 },
    .{ "f128", .keyword_f128 },
    .{ "float", .keyword_float },
    .{ "bytes", .keyword_bytes },
    .{ "string", .keyword_string },
});

pub fn isKeyword(kind: Kind) bool {
    return switch (kind) {
        .keyword_i8, .keyword_i16, .keyword_i32, .keyword_i64, .keyword_i128, .keyword_int => true,
        .keyword_u8, .keyword_u16, .keyword_u32, .keyword_u64, .keyword_u128, .keyword_uint => true,
        .keyword_f16, .keyword_f32, .keyword_f64, .keyword_f128, .keyword_float => true,
        .keyword_bytes, .keyword_string => true,
        else => false,
    };
}

pub const symbols = std.StaticStringMap(Kind).initComptime(.{
    .{ ":", .symbol_colon },
});

pub fn isSymbol(kind: Kind) bool {
    return switch (kind) {
        .symbol_colon => true,
        else => false,
    };
}

pub const operators = std.StaticStringMap(Kind).initComptime(.{
    .{ "->", .operator_arrow },
    .{ "<>", .operator_chain },
    .{ "|", .operator_pipe },
});

pub fn isOperator(kind: Kind) bool {
    return switch (kind) {
        .operator_arrow, .operator_chain, .operator_pipe => true,
        else => false,
    };
}

pub fn isIdentifier(kind: Kind) bool {
    return switch (kind) {
        .identifier => true,
        else => false,
    };
}

pub fn isLiteral(self: Kind) bool {
    return switch (self) {
        .literal_int, .literal_float, .literal_string => true,
        else => false,
    };
}

pub fn isSpecial(self: Kind) bool {
    return switch (self) {
        .invalid, .end_of_frame => true,
        else => false,
    };
}
