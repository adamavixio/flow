pub const Token = @This();

tag: Tag,
start: usize,
end: usize,
// Optional location info (for better error messages)
// Will be populated by lexer2, old lexer leaves them as 0
line: usize = 0,
column: usize = 0,

pub const Tag = enum {
    // Identifier
    identifier,
    // Literal
    int,
    float,
    string,
    // Operator
    plus,
    minus,
    multiply,
    divide,
    set,
    arrow,
    chain,
    colon,
    pipe,
    // Special
    invalid,
    end_of_frame,
};
