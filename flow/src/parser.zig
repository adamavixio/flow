const std = @import("std");
const core = @import("core");

const Parser = @This();
const Ast = @import("ast.zig");
const Token = @import("token.zig");

index: usize,
tokens: std.ArrayList(Token),
buffer: [:0]const u8,
allocator: std.mem.Allocator,

pub const Error = error{
    InvalidKeyword,
    ExpectedKeyword,
    ExpectedSymbolColon,
    EndOfInput,
};

pub fn init(allocator: std.mem.Allocator, buffer: [:0]const u8, tokens: std.ArrayList(Token)) Parser {
    return .{ .index = 0, .tokens = tokens, .buffer = buffer, .allocator = allocator };
}

pub fn prev(self: *Parser) Token {
    return self.tokens[self.index - 1];
}

pub fn next(self: *Parser) Token {
    const token = self.tokens[self.index];
    self.index += 1;
    return token;
}

pub fn read(self: *Parser, token: Token) []const u8 {
    return self.buffer[token.location.left..token.location.right];
}

pub fn parse(self: *Parser) !*Ast {
    var ast = try Ast.init(self.allocator);
    errdefer ast.deinit(self.allocator);

    while (self.parsePipeline()) |pipeline| {
        try ast.pipelines.append(pipeline);
    } else |err| switch (err) {
        .EndOfInput => {},
        else => return err,
    }

    return ast;
}

pub fn parsePipeline(self: *Parser) Error!*Ast.Pipeline {
    var pipeline = try Ast.Pipeline.init(self.allocator);
    errdefer pipeline.deinit(self.allocator);

    const input_stage = try self.parseInputStage();
    try pipeline.stages.append(input_stage);

    while (self.prev().kind == .operator_arrow) {
        const transformation_stage = try self.parseTransformationStage();
        try pipeline.stages.append(transformation_stage);
    }

    return pipeline;
}

pub fn parseInputStage(self: *Parser) Error!*Ast.Stage {
    var stage = try Ast.Stage.init(self.allocator);
    errdefer stage.deinit(self.allocator);

    try stage.steps.append(.{
        .input = .{
            .token = blk: {
                const token = self.next();
                if (!token.isKeyword()) {
                    return Error.ExpectedKeyword;
                }
                break :blk token;
            },
            .arguments = blk: {
                if (self.next().kind != .symbol_colon) {
                    return Error.ExpectedKeyword;
                }
                const arguments = std.ArrayList(Token).init(self.allocator);
                defer arguments.deinit();
                while (true) {
                    const token = self.next();
                    switch (token.kind) {
                        .literal_int, .literal_float, .literal_string => try arguments.append(token),
                        else => break,
                    }
                }
                break :blk arguments.toOwnedSlice();
            },
            .tag = blk: {
                const content = self.read(self.prev());
                if (std.meta.stringToEnum(core.Type.Tag, content)) |tag| {
                    break :blk tag;
                }
                return Error.InvalidToken;
            },
        },
    });

    while (self.prev().kind == .operator_pipe) {
        try stage.steps.append(.{
            .mutation = .{
                .token = blk: {
                    const token = self.next();
                    if (!token.isLiteral()) {
                        return Error.ExpectedKeyword;
                    }
                    break :blk token;
                },
                .arguments = blk: {
                    const arguments = std.ArrayList(Token).init(self.allocator);
                    defer arguments.deinit();
                    while (true) {
                        const token = self.next();
                        switch (token.kind) {
                            .identifier => try arguments.append(token),
                            else => break,
                        }
                    }
                    break :blk arguments.toOwnedSlice();
                },
            },
        });
    }

    return stage;
}

pub fn parseTransformationStage(self: *Parser) Error!*Ast.Stage {
    var stage = try Ast.Stage.init(self.allocator);
    errdefer stage.deinit(self.allocator);

    try stage.steps.append(.{
        .input = .{
            .token = blk: {
                const token = self.next();
                if (!token.isKeyword()) {
                    return Error.ExpectedKeyword;
                }
                break :blk token;
            },
            .arguments = blk: {
                if (self.next().kind != .symbol_colon) {
                    return Error.ExpectedKeyword;
                }
                const arguments = std.ArrayList(Token).init(self.allocator);
                defer arguments.deinit();
                while (true) {
                    const token = self.next();
                    switch (token.kind) {
                        .literal_int, .literal_float, .literal_string => try arguments.append(token),
                        else => break,
                    }
                }
                break :blk arguments.toOwnedSlice();
            },
            .tag = blk: {
                const content = self.read(self.prev());
                if (std.meta.stringToEnum(core.Type.Tag, content)) |tag| {
                    break :blk tag;
                }
                return Error.InvalidToken;
            },
        },
    });

    while (self.prev().kind == .operator_pipe) {
        try stage.steps.append(.{
            .mutation = .{
                .token = blk: {
                    const token = self.next();
                    if (!token.isLiteral()) {
                        return Error.ExpectedKeyword;
                    }
                    break :blk token;
                },
                .arguments = blk: {
                    const arguments = std.ArrayList(Token).init(self.allocator);
                    defer arguments.deinit();
                    while (true) {
                        const token = self.next();
                        switch (token.kind) {
                            .identifier => try arguments.append(token),
                            else => break,
                        }
                    }
                    break :blk arguments.toOwnedSlice();
                },
            },
        });
    }

    return stage;
}

// pub fn parseStage(self: *Parser, Type: type) !?*Ast.Stage {
//     var stage = try Ast.Stage.init(self.allocator, Type);
//     errdefer stage.deinit(self.allocator);

//     self.next();
//     switch (self.token.lexeme) {
//         .symbol => switch (self.token.lexeme.symbol) {
//             .colon => {},
//         },
//         else => return Error.InvalidToken,
//     }

//     const info = @typeInfo(Type);

//     self.next();
//     switch (self.token.lexeme) {
//         .literal => switch (self.token.lexeme.literal) {
//             .int => switch(@typeInfo(Type)) {
//                 .Int => {},
//             },
//             .float => if (info != .Float) {
//                 return Error.InvalidToken;
//             },
//             .string => {
//                 const info =
//             }
//         },
//     }
//     stage.appendLiteral(self.token);

//     while (true) {
//         self.next();
//         switch (self.token.lexeme) {
//             .operator => switch (self.token.lexeme.operator) {
//                 .chain => {},
//                 else => break,
//             },
//             else => break,
//         }
//         self.next();
//         switch (self.token.lexeme) {
//             .literal => switch (self.token.lexeme.literal) {
//                 .int => if (@typeInfo(primitive.Declare.Type(tag)) != .Int) {
//                     return Error.InvalidToken;
//                 },
//                 .float => if (@typeInfo(primitive.Declare.Type(tag)) != .Flaot) {
//                     return Error.InvalidToken;
//                 },
//                 .string => if (@typeInfo(primitive.Declare.Type(tag)) != .Pointer or @typeInfo(primitive.Declare.Type(tag).child != u8)) {
//                     return Error.InvalidToken;
//                 },
//             },
//         }
//         stage.appendLiteral(self.token);
//     }

//     while (true) {
//         self.next();
//         switch (self.token.lexeme) {
//             .operator => switch (self.token.lexeme.operator) {
//                 .pipe => continue,
//                 .arrow => break,
//                 else => return Error.InvalidToken,
//             },
//             else => return Error.InvalidToken,
//         }
//         self.next();
//         if (!primitive.Implement(tag).hasMutatable(self.content())) {
//             return Error.InvalidToken;
//         }
//     }

//     while (true) {
//         self.next();
//         switch (self.token) {
//             .literal => switch (self.token.literal) {
//                 .identifier => |identifier| {
//                     const value = self.lexer.read(identifier);
//                     switch (tag) {
//                         inline else => |t| {
//                             const operator = core.Type.initOperator(t, value) orelse return Error.InvalidToken;
//                             try stage.appendOperator(t, operator);
//                         },
//                     }
//                 },
//                 else => return Error.InvalidToken,
//             },
//             else => return Error.InvalidToken,
//         }

//         self.next();
//         switch (self.token) {
//             .operator => switch (self.token.operator) {
//                 .pipe => continue,
//                 else => return stage,
//             },
//             .special => switch (self.token.special) {
//                 .eof => return stageInvalidToken,
//                 else => return Error.Expected_Special_EOF,
//             },
//             else => return Error.Expected_Operator,
//         }
//     }
// }

// pub fn parseChain(self: *Parser, tag: primitive.Declare.Tag) !?Token {
//     self.next();
//     switch (self.token.lexeme) {
//         .operator => switch (self.token.lexeme.operator) {
//             .chain => {},
//             else => return null,
//         },
//         else => return null,
//     }

//     self.next();
//     switch (self.token.lexeme) {
//         .literal => switch (self.token.lexeme.literal) {
//             .int => if (@typeInfo(primitive.Declare.Type(tag)) != .Int) {
//                 return Error.Expected_Literal_Identifier_Int;
//             },
//             .float => if (@typeInfo(primitive.Declare.Type(tag)) != .Flaot) {
//                 return Error.Expected_Literal_Type_Float;
//             },
//             .string => if (@typeInfo(primitive.Declare.Type(tag)) != .Pointer or @typeInfo(primitive.Declare.Type(tag).child != u8)) {
//                 return Error.Expected_Literal_Type_Float;
//             },
//         },
//     }

//     return self.token();
// }

test "string" {
    const allocator = std.testing.allocator;

    const input = "string : \"test\" | sort | unique";
    const lexer = Lexer.init(input);

    var parser = init(lexer, allocator);
    var ast = try parser.parse();
    defer ast.deinit(allocator);
}
