const std = @import("std");

const Parser = @This();
const Ast = @import("ast.zig");
const Lexer = @import("lexer.zig");
const Token = @import("lexer.zig");

lexer: Lexer,
token: Token,
allocator: std.mem.Allocator,

pub const Error = error{
    InvalidToken,
    InvalidSpecial,
    Expected_Symbol,
    Expected_Symbol_Colon,
    Expected_Operator,
    Expected_Operator_Arrow,
    Expected_Literal,
    Expected_Literal_Type,
    Expected_Literal_Type_Int,
    Expected_Literal_Type_Float,
    Expected_Literal_Type_String,
    Expected_Literal_Identifier,
    Expected_Literal_Identifier_Int,
    Expected_Literal_Identifier_Float,
    Expected_Literal_Identifier_String,
    ExpectedSpecialEOF,
};

pub fn init(lexer: Lexer, allocator: std.mem.Allocator) Parser {
    return .{
        .lexer = lexer,
        .token = lexer.next(),
        .allocator = allocator,
    };
}

pub fn next(self: *Parser) void {
    self.token = self.lexer.next();
}

pub fn parse(self: *Parser) !*Ast {
    var ast = try Ast.init(self.allocator);
    errdefer ast.deinit(self.allocator);

    while (true) {
        switch (self.token) {
            .type => {
                const pipeline = try self.parsePipeline();
                try ast.appendPipeline(pipeline);
            },
            .special => switch (self.token.special) {
                .eof => break,
                else => return Error.InvalidSpecial,
            },
            else => return Error.InvalidToken,
        }
    }

    return ast;
}

pub fn parsePipeline(self: *Parser) Error!*Ast.Pipeline {
    var pipeline = try Ast.Pipeline.init(self.allocator);
    errdefer pipeline.deinit(self.allocator);

    while (self.parseStage()) |stage| {
        try pipeline.appendStage(stage);
    }

    return pipeline;
}

pub fn parseStage(self: *Parser) !?*Ast.Stage {
    var stage = try Ast.Stage.init(self.allocator, tag);
    errdefer stage.deinit(self.allocator);

    while (true) {
        self.next();
        switch (self.token) {
            .literal => switch (self.token.literal) {
                .int => if (tag != .int) return Error.Expected_Literal_Type_Int,
                .float => if (tag != .float) return Error.Expected_Literal_Type_Float,
                .string => if (tag != .string) return Error.Expected_Literal_Type_String,
                else => return Error.Expected_Literal_Type,
            },
            else => return Error.Expected_Literal,
        }
        try stage.appendLiteral(self.token);

        self.next();
        switch (self.token) {
            .operator => switch (self.token.operator) {
                .pipe => break,
                .chain => continue,
                else => return stage,
            },
            .special => switch (self.token.special) {
                .eof => return stage,
                else => return Error.Expected_Special_EOF,
            },
            else => return Error.Expected_Operator,
        }
    }

    while (true) {
        self.next();
        switch (self.token) {
            .literal => switch (self.token.literal) {
                .identifier => |identifier| {
                    const value = self.lexer.read(identifier);
                    switch (tag) {
                        inline else => |t| {
                            const operator = Primitive.initOperator(t, value) orelse return Error.Expected_Literal_Identifier_Int;
                            try stage.appendOperator(t, operator);
                        },
                    }
                },
                else => return Error.Expected_Literal_Identifier,
            },
            else => return Error.Expected_Literal,
        }

        self.next();
        switch (self.token) {
            .operator => switch (self.token.operator) {
                .pipe => continue,
                else => return stage,
            },
            .special => switch (self.token.special) {
                .eof => return stage,
                else => return Error.Expected_Special_EOF,
            },
            else => return Error.Expected_Operator,
        }
    }
}

test "string" {
    const allocator = std.testing.allocator;

    const input = "string : \"test\" | sort | unique";
    const lexer = Lexer.init(input);

    var parser = init(lexer, allocator);
    var ast = try parser.parse();
    defer ast.deinit(allocator);
}
