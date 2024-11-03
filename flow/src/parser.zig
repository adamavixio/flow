const std = @import("std");

const root = @import("root.zig");
const Source = root.Source;
const Token = root.Token;

const Parser = struct {

pub const Lexer = struct {
    source: Source,
    index: usize,
    // ... rest of lexer implementation

    pub fn init(source: Source) Lexer {
        return .{
            .source = source,
            .index = 0,
        };
    }
};

// Usage example:
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // From file
    var source = try Source.initFile("input.txt", allocator);
    defer source.deinit();
    var lexer = Lexer.init(source);

    // From string
    var str_source = try Source.initString("some content", allocator);
    defer str_source.deinit();
    var str_lexer = Lexer.init(str_source);
}

const Ast = @import("ast.zig");
const Token = @import("token.zig");

index: usize,
tokens: std.ArrayList(Token),
buffer: [:0]const u8,
allocator: std.mem.Allocator,

pub const Error = error{
    InvalidInputStage,
    ///
    UnexpectedInvalidToken,
    UnexpectedEndOfFrameToken,

    InvalidKeyword,
    InvalidMutation,
    InvalidTransform,
    InvalidTerminalStage,
    InvalidTransformToken,

    ExpectedKeyword,
    ExpectedKeywordOrIdentifier,

    ExpectedIdentifier,
    ExpectedSymbolColon,
    EndOfInput,
};

pub fn init(allocator: std.mem.Allocator, buffer: [:0]const u8, tokens: std.ArrayList(Token)) Parser {
    return .{ .index = 0, .tokens = tokens, .buffer = buffer, .allocator = allocator };
}

pub fn previous_token(self: *Parser) Token {
    return self.tokens[self.index - 1];
}

pub fn previous_content(self: *Parser) Token {
    const token = self.previous_token();
    return self.buffer[token.location.left..token.location.right];
}

pub fn current_token(self: *Parser) Token {
    return self.tokens[self.index];
}

pub fn current_content(self: *Parser) Token {
    const token = self.current_token();
    return self.buffer[token.location.left..token.location.right];
}

pub fn consume_token(self: *Parser) Token {
    self.index += 1;
    return self.previous_token();
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

    var input_stage = try self.parseInputStage();
    try pipeline.stages.append(input_stage);

    while (self.isValidTransform(stage.tag)) {
        stage = try self.parseTransformStage(stage.tag);
        try pipeline.stages.append(stage);
    }

    if (self.isValidTerminal(stage.tag)) {
        stage = try self.parseTerminalStage(stage.tag);
        try pipeline.stages.append(stage);
    } else {
        return Error.InvalidTerminalStage;
    }

    return pipeline;
}

pub fn parseInputStage(self: *Parser) Error!*Ast.Stage {
    const tag = try core.FlowTag.fromString(self.current_content());

    var stage = try Ast.Stage.init(self.allocator, tag);
    errdefer stage.deinit(self.allocator);

    const input_step = try self.parseInputStep();
    try stage.steps.append(input_step);

    while (self.prev().tag == .operator_pipe) {
        const mutation_step = try self.ParseMutationStep(stage.tag);
        try stage.steps.append(mutation_step);
    }

    return stage;
}

pub fn parseTransformStage(self: *Parser, tag: core.FlowTag) Error!*Ast.Stage {
    var stage = try Ast.Stage.init(self.allocator);
    errdefer stage.deinit(self.allocator);

    const transform_step = try self.parseTransformStep(tag);
    try stage.steps.append(transform_step);

    const transform_content = self.read(transform_step.token);
    stage.tag = try core.FlowTag.fromTransformTrait(transform_content);

    while (self.prev().tag == .operator_pipe) {
        const mutation_step = try self.ParseMutationStep(stage.tag);
        try stage.steps.append(mutation_step);
    }

    return stage;
}

pub fn parseTerminalStage(self: *Parser, tag: core.FlowTag) Error!*Ast.Stage {
    var stage = try Ast.Stage.init(self.allocator);
    errdefer stage.deinit(self.allocator);

    const keyword_step = try self.parseKeywordStep();
    try stage.steps.append(keyword_step);

    const keyword_content = self.read(keyword_step.token);
    stage.tag = try core.FlowTag.fromString(keyword_content);

    while (self.prev().tag == .operator_pipe) {
        const mutation_step = try self.ParseMutationStep(stage.tag);
        try stage.steps.append(mutation_step);
    }

    return stage;
}

pub fn parseInputStep(self: *Parser) Error!Ast.Step {
    const input_token = self.consume_token();
    const input_arguments = std.ArrayList(Token).init(self.allocator);
    defer input_arguments.deinit();

    if (self.consume_token().is(.symbol_colon)) {
        while (self.current_token().isIdentifier() or self.current_token().isLiteral()) {
            const argument_token = self.consume_token();
            try input_arguments.append(argument_token);
        }
    }

    return .{
        .token = input_token,
        .arguments = input_arguments.toOwnedSlice(),
    };
}

pub fn parseTransformStep(self: *Parser, tag: core.FlowTag) Error!Ast.Step {
    const transform_token = self.consume_token();
    if (!transform_token.isKeyword() and !transform_token.isIdentifier()) return Error.ExpectedKeywordOrLiteral;

    const transform_content = self.previous_content();
    if (!tag.hasTransform(transform_content)) return Error.InvalidTransform;

    const transform_arguments = std.ArrayList(Token).init(self.allocator);
    defer transform_arguments.deinit();

    switch (self.consume_token().tag) {
        .symbol_colon => while (true) {
            const argument_token = self.consume_token();
            switch (argument_token.tag) {
                .identifier => try transform_arguments.append(argument_token),
                .literal_int => try transform_arguments.append(argument_token),
                .literal_float => try transform_arguments.append(argument_token),
                .literal_string => try transform_arguments.append(argument_token),
                .special_invalid => return Error.UnexpectedInvalidToken,
                .special_end_of_frame => return Error.UnexpectedEndOfFrameToken,
                else => break,
            }
        },
        .special_invalid => Error.UnexpectedInvalidToken,
        .special_end_of_frame => Error.UnexpectedEndOfFrameToken,
        else => {},
    }

    return .{
        .token = transform_token,
        .arguments = transform_arguments.toOwnedSlice(),
    };
}

pub fn ParseMutationStep(self: *Parser, tag: core.FlowTag) Error!Ast.Step {
    const mutation_token = self.consume_token();
    if (!mutation_token.isIdentifier) return Error.ExpectedIdentifier;

    const mutation_content = self.previous_content();
    if (!tag.hasMutation(mutation_content)) return Error.InvalidMutation;

    const mutation_arguments = std.ArrayList(Token).init(self.allocator);
    defer mutation_arguments.deinit();

    while (true) {
        const argument_token = self.consume_token();
        switch (argument_token.tag) {
            .identifier => try mutation_arguments.append(argument_token),
            .literal_int => try mutation_arguments.append(argument_token),
            .literal_float => try mutation_arguments.append(argument_token),
            .literal_string => try mutation_arguments.append(argument_token),
            .special_invalid => return Error.UnexpectedInvalidToken,
            .special_end_of_frame => return Error.UnexpectedEndOfFrameToken,
            else => break,
        }
    }

    return .{
        .token = mutation_token,
        .arguments = mutation_arguments.toOwnedSlice(),
    };
}

fn isValidInputStage(self: *Parser) bool {
    switch (true) {
        self.current_token().isLiteral() => return true,
        self.current_token().isKeyword() => return core.FlowTag.hasString(self.current_content()),
        else => return false,
    }
}

fn isValidTransform(self: *Parser, tag: core.FlowTag) bool {
    switch (self.previous_token().tag) {
        .operator_arrow => return tag.hasTransform(self.current_content()),
        else => return false,
    }
}

fn isValidTerminal(self: *Parser, tag: core.FlowTag) bool {
    switch (self.previous_token().tag) {
        .operator_arrow => return tag.hasTerminal(self.current_content()),
        else => return false,
    }
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
