pub const Token = @This();

tag: Tag,
location: Location,

pub fn init(tag: Tag, location: Location) Token {
    return .{
        .tag = tag,
        .location = location,
    };
}

pub const Tag = enum {
    /// Identifier
    identifier,

    /// Operator
    colon,
    pipe,
    chain,
    arrow,

    /// Literal
    int,
    float,
    string,

    /// Special
    invalid,
    end_of_frame,

    pub fn isIdentifier(token: Token) bool {
        switch (token) {
            .identifier => return true,
            else => return false,
        }
    }

    pub fn isOperator(token: Token) bool {
        switch (token) {
            .colon, .pipe, .chain, .arrow => return true,
            else => return false,
        }
    }

    pub fn isLiteral(token: Token) bool {
        switch (token) {
            .int, .float, .string => return true,
            else => return false,
        }
    }

    pub fn isSpecial(token: Token) bool {
        switch (token) {
            .invalid, .end_of_frame => return true,
            else => return false,
        }
    }
};

pub const Location = struct {
    start: usize,
    end: usize,

    pub fn init(start: usize, end: usize) Location {
        return .{
            .start = start,
            .end = end,
        };
    }
};
