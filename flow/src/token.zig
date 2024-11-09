const root = @import("root.zig");
const Position = root.Position;

pub const Token = @This();

tag: Tag,
position: Position,

pub fn init(tag: Tag, position: Position) Token {
    return .{
        .tag = tag,
        .position = position,
    };
}

pub const Tag = enum {
    /// Identifier
    identifier,

    /// Literal
    int,
    float,
    string,

    /// Operator
    colon,
    pipe,
    chain,
    arrow,

    /// Special
    invalid,
    new_line,
    end_of_frame,
};
