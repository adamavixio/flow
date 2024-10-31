const std = @import("std");
const core = @import("core");

const Parser = @This();
const Ast = @import("ast.zig");
const Lexer = @import("lexer.zig");
const Token = @import("token.zig");

lexer: Lexer,
token: Token,
allocator: std.mem.Allocator,

pub const Error = error{
    InvalidToken,
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

pub fn content(self: *Parser) []const u8 {
    return self.lexer.read(self.token.location);
}

pub fn parse(self: *Parser) !*Ast {
    var ast = try Ast.init(self.allocator);
    errdefer ast.deinit(self.allocator);

    while (true) {
        switch (self.token.lexeme) {
            .type => {
                const pipeline = try self.parsePipeline();
                try ast.appendPipeline(pipeline);
            },
            .special => switch (self.token.special) {
                .eof => break,
                else => return Error.InvalidToken,
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
    const tag = primitive.Declare.tagFromString(self.content());
    var stage = try Ast.Stage.init(self.allocator, tag);
    errdefer stage.deinit(self.allocator);

    self.next();
    switch (self.token.lexeme) {
        .symbol => switch (self.token.lexeme.symbol) {
            .colon => {},
        },
        else => return Error.InvalidToken,
    }
    self.next();
    switch (self.token.lexeme) {
        .literal => switch (self.token.lexeme.literal) {
            .int => if (@typeInfo(primitive.Declare.Type(tag)) != .Int) {
                return Error.InvalidToken;
            },
            .float => if (@typeInfo(primitive.Declare.Type(tag)) != .Flaot) {
                return Error.InvalidToken;
            },
            .string => if (@typeInfo(primitive.Declare.Type(tag)) != .Pointer or @typeInfo(primitive.Declare.Type(tag).child != u8)) {
                return Error.InvalidToken;
            },
        },
    }
    stage.appendLiteral(self.token);

    while (true) {
        self.next();
        switch (self.token.lexeme) {
            .operator => switch (self.token.lexeme.operator) {
                .chain => {},
                else => break,
            },
            else => break,
        }
        self.next();
        switch (self.token.lexeme) {
            .literal => switch (self.token.lexeme.literal) {
                .int => if (@typeInfo(primitive.Declare.Type(tag)) != .Int) {
                    return Error.InvalidToken;
                },
                .float => if (@typeInfo(primitive.Declare.Type(tag)) != .Flaot) {
                    return Error.InvalidToken;
                },
                .string => if (@typeInfo(primitive.Declare.Type(tag)) != .Pointer or @typeInfo(primitive.Declare.Type(tag).child != u8)) {
                    return Error.InvalidToken;
                },
            },
        }
        stage.appendLiteral(self.token);
    }

    while (true) {
        self.next();
        switch (self.token.lexeme) {
            .operator => switch (self.token.lexeme.operator) {
                .pipe => continue,
                .arrow => break,
                else => return Error.InvalidToken,
            },
            else => return Error.InvalidToken,
        }
        self.next();
        if (!primitive.Implement(tag).hasMutatable(self.content())) {
            return Error.InvalidToken;
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
                            const operator = core.Type.initOperator(t, value) orelse return Error.InvalidToken;
                            try stage.appendOperator(t, operator);
                        },
                    }
                },
                else => return Error.InvalidToken,
            },
            else => return Error.InvalidToken,
        }

        self.next();
        switch (self.token) {
            .operator => switch (self.token.operator) {
                .pipe => continue,
                else => return stage,
            },
            .special => switch (self.token.special) {
                .eof => return stageInvalidToken,
                else => return Error.Expected_Special_EOF,
            },
            else => return Error.Expected_Operator,
        }
    }
}

pub fn parseChain(self: *Parser, tag: primitive.Declare.Tag) !?Token {
    self.next();
    switch (self.token.lexeme) {
        .operator => switch (self.token.lexeme.operator) {
            .chain => {},
            else => return null,
        },
        else => return null,
    }

    self.next();
    switch (self.token.lexeme) {
        .literal => switch (self.token.lexeme.literal) {
            .int => if (@typeInfo(primitive.Declare.Type(tag)) != .Int) {
                return Error.Expected_Literal_Identifier_Int;
            },
            .float => if (@typeInfo(primitive.Declare.Type(tag)) != .Flaot) {
                return Error.Expected_Literal_Type_Float;
            },
            .string => if (@typeInfo(primitive.Declare.Type(tag)) != .Pointer or @typeInfo(primitive.Declare.Type(tag).child != u8)) {
                return Error.Expected_Literal_Type_Float;
            },
        },
    }

    return self.token();
}

test "string" {
    const allocator = std.testing.allocator;

    const input = "string : \"test\" | sort | unique";
    const lexer = Lexer.init(input);

    var parser = init(lexer, allocator);
    var ast = try parser.parse();
    defer ast.deinit(allocator);
}
