pub const Type = enum {
    whitespace,
    operator,
    number,
    invalid,
    end_of_frame,
};

pub const Token = struct {
    const Self = @This();

    ident: Type,
    literal: []u8,

    pub fn is(self: Self, ident: Type) bool {
        return self.ident == ident;
    }
};

pub fn whitespace(literal: []u8) Token {
    return .{ .ident = Type.whitespace, .literal = literal };
}

pub fn operator(literal: []u8) Token {
    return .{ .ident = Type.operator, .literal = literal };
}

pub fn number(literal: []u8) Token {
    return .{ .ident = Type.number, .literal = literal };
}

pub fn invalid(literal: []u8) Token {
    return .{ .ident = Type.invalid, .literal = literal };
}

pub fn endOfFrame() Token {
    return .{ .ident = Type.end_of_frame, .literal = "" };
}
