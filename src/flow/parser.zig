const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const io = lib.io;
const flow = lib.flow;

const Parser = @This();

index: usize,
tokens: []flow.Token,
source: io.Source,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, source: io.Source) !Parser {
    var lexer = flow.Lexer.init(source);
    const tokens = try lexer.tokenize(allocator);
    return .{
        .index = 0,
        .source = source,
        .tokens = tokens,
        .allocator = allocator,
    };
}

pub fn parse(self: *Parser) !flow.AST {
    var statements = std.ArrayList(flow.AST.Statement).init(self.allocator);
    defer statements.deinit();

    while (self.peekToken(0).tag != .end_of_frame) {
        const statement = try self.parseStatementPipeline();
        try statements.append(statement);
    }

    return .{ .statements = try statements.toOwnedSlice() };
}

test parse {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 5 | add 10 | sub 5 -> string | test -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var parser = try init(arena.allocator(), source);
    _ = try parser.parse();
}

fn parseStatementPipeline(self: *Parser) !flow.AST.Statement {
    return .{
        .pipeline = .{
            .type = try self.parseExpressionType(),
            .transforms = try self.parseExpressionTransforms(),
        },
    };
}

fn parseExpressionType(self: *Parser) !flow.AST.ExpressionType {
    return switch (self.peekToken(0).tag) {
        .identifier => switch (self.peekToken(1).tag) {
            .colon => .{
                .name = self.consumeToken(),
                .parameter = blk: {
                    self.skipToken();
                    break :blk try self.parseExpressionParameter();
                },
                .operations = try self.parseExpressionOperations(),
            },
            else => flow.Error.ParserExpectedColon,
        },
        else => flow.Error.ParserExpectedIdentifier,
    };
}

fn parseExpressionTransforms(self: *Parser) ![]flow.AST.ExpressionTransform {
    var transforms = std.ArrayList(flow.AST.ExpressionTransform).init(self.allocator);
    return while (self.parseExpressionTransform()) |transform| {
        try transforms.append(transform);
    } else |err| switch (err) {
        flow.Error.ParserExpectedArrow => try transforms.toOwnedSlice(),
        else => err,
    };
}

fn parseExpressionTransform(self: *Parser) !flow.AST.ExpressionTransform {
    return switch (self.peekToken(0).tag) {
        .arrow => blk: {
            self.skipToken();
            break :blk switch (self.peekToken(0).tag) {
                .identifier => .{
                    .name = self.consumeToken(),
                    .parameters = try self.parseExpressionParameters(),
                    .operations = try self.parseExpressionOperations(),
                },
                else => flow.Error.ParserExpectedIdentifier,
            };
        },
        else => flow.Error.ParserExpectedArrow,
    };
}

fn parseExpressionOperations(self: *Parser) ![]flow.AST.ExpressionOperation {
    var operations = std.ArrayList(flow.AST.ExpressionOperation).init(self.allocator);
    return while (self.parseExpressionOperation()) |operation| {
        try operations.append(operation);
    } else |err| switch (err) {
        flow.Error.ParserExpectedPipe => try operations.toOwnedSlice(),
        else => err,
    };
}

fn parseExpressionOperation(self: *Parser) !flow.AST.ExpressionOperation {
    return switch (self.peekToken(0).tag) {
        .pipe => blk: {
            self.skipToken();
            break :blk switch (self.peekToken(0).tag) {
                .identifier => .{
                    .name = self.consumeToken(),
                    .parameters = try self.parseExpressionParameters(),
                },
                else => flow.Error.ParserExpectedIdentifier,
            };
        },
        else => flow.Error.ParserExpectedPipe,
    };
}

fn parseExpressionParameters(self: *Parser) ![]flow.AST.ExpressionParameter {
    var parameters = std.ArrayList(flow.AST.ExpressionParameter).init(self.allocator);
    return while (self.parseExpressionParameter()) |parameter| {
        try parameters.append(parameter);
    } else |err| switch (err) {
        flow.Error.ParserExpectedParameter => try parameters.toOwnedSlice(),
        else => err,
    };
}

fn parseExpressionParameter(self: *Parser) !flow.AST.ExpressionParameter {
    return switch (self.peekToken(0).tag) {
        .int, .float => .{ .literal = self.consumeToken() },
        else => flow.Error.ParserExpectedParameter,
    };
}

fn peekToken(self: *Parser, offset: usize) flow.Token {
    return self.tokens[self.index + offset];
}

fn skipToken(self: *Parser) void {
    self.index += 1;
}

fn consumeToken(self: *Parser) []const u8 {
    const token = self.tokens[self.index];
    self.index += 1;
    return self.source.buffer[token.start..token.end];
}

// fn parseStatement(
//     allocator: mem.Allocator,
//     source: io.Source,
//     tokens: []flow.Token,
//     index: *usize,
// ) !flow.AST.Statement {}

// fn parseStage(self: Parser) !flow.AST.Stage {
//     const token = self.lexer.next();
//     switch (token.tag) {
//         .identifier => {
//             if (!self.lexer.next().tag != .colon)
//                 return flow.Error.ParserExpectedOperatorColon;
//             const lexeme = self.lexer.exchange(token);
//             return self.parseStageInput(@"type");
//         },
//     }
// }

// fn parseExpression(self: *Parser, @"type": core.Type) !flow.AST.Pipeline {
//     const token = self.lexer.next();
//     switch (token.tag) {
//         .identifier => {
//             const identifier = self.lexer.exchange(token);
//             if (!core.Value.hasType(identifier))
//                 return flow.Error.ParserExpectedIdentifierType;
//             if (!self.lexer.next().tag != .colon)
//                 return flow.Error.ParserExpectedOperatorColon;
//         },
//     }
// }

// pub fn parseExpression(self: *Parser) !*flow.AST.Node {
//     while (self.lexer.peek().tag == .chain) {
//         _ = self.lexer.next();
//     }
// }

// pub fn parseOperation(self: *Parser, identifier: []const u8) !*flow.AST.Node {
//     const token = self.lexer.next();
//     if (!token.isIdentifier()) return Error.ExpectedIdentifier;
//     const content = self.source.buffer[token.start..token.end];
//     const args = std.ArrayList(*flow.AST.Node).init(self.allocator);
//     while (self.lexer.peek().tag == .identifier) {
//         const literal = try self.parseLiteral(content)
//     }
// }

// pub fn parseDeclaration(self: *Parser) !*flow.AST.Node {
//     const token = self.lexer.next();
//     if (!token.isIdentifier()) return Error.ExpectedIdentifier;
//     if (self.lexer.next().tag != .colon) return Error.ExpectedOperatorColon;
//     const content = self.source.buffer[token.start..token.end];
//     const literal = try self.parseLiteral(content);
//     return flow.AST.Declaration.create(self.allocator, content, literal);
// }

// pub fn parseLiteral(self: *Parser, identifier: []const u8) !*flow.AST.Node {
//     const token = self.lexer.next();
//     if (!token.isLiteral()) return Error.ExpectedOperatorColon;
//     const content = self.source.buffer[token.start..token.end];
//     const value = try flow.core.Value.init(self.allocator, identifier, content);
//     return flow.AST.Literal.create(self.allocator, value);
// }

// pub fn parsePipeline(self: *Parser) Error!*flow.AST.Node {
//     var left = parseExpressionn():
//     var pipeline = try flow.AST.Node.Pipeline.init(self.allocator);

//     while (true) switch (self.peek().tag) {
//         .identifier => {
//             const stage = try self.parseInputStage();
//             try pipeline.stages.append(stage);
//         },
//         .arrow => {
//             self.skip();
//             while (self.peek().tag == .new_line) {
//                 self.skip();
//             }
//             const stage = try self.parseTransformStage();
//             try pipeline.stages.append(stage);
//         },
//         .new_line, .end_of_frame => {
//             break;
//         },
//         else => {
//             self.printError();
//             return Error.InvalidPipeline;
//         },
//     };

//     return pipeline;
// }

// pub fn parseInputStage(self: *Parser) Error!*flow.AST.Node.Stage {
//     const declaration = try self.parseTypeDeclaration();
//     var expressions = ArrayList(*flow.AST.Node.Expression).init(self.allocator.allocator());

//     while (true) switch (self.peek().tag) {
//         .arrow, .new_line, .end_of_frame => {
//             break;
//         },
//         .pipe => {
//             self.skip();
//             while (self.peek().tag == .new_line) {
//                 self.skip();
//             }
//         },
//         .identifier => {
//             const identifier = try self.parseIdentifierExpression();
//             try expressions.append(identifier);
//             while (true) switch (self.peek().tag) {
//                 .int, .float, .string => {
//                     const literal = try self.parseLiteralExpression();
//                     try expressions.append(literal);
//                 },
//                 else => {
//                     break;
//                 },
//             };
//         },
//         else => {
//             self.printError();
//             return Error.InvalidInputStage;
//         },
//     };

//     return try flow.AST.Node.Stage.initInput(
//         self.allocator,
//         declaration,
//         expressions,
//     );
// }

// pub fn parseTransformStage(self: *Parser) Error!*flow.AST.Node.Stage {
//     var expressions = ArrayList(*flow.AST.Node.Expression).init(self.allocator.allocator());

//     while (true) switch (self.peek().tag) {
//         .arrow, .new_line, .end_of_frame => {
//             break;
//         },
//         .pipe => {
//             self.skip();
//             while (self.peek().tag == .new_line) {
//                 self.skip();
//             }
//         },
//         .identifier => {
//             const identifier = try self.parseIdentifierExpression();
//             try expressions.append(identifier);
//             while (true) switch (self.peek().tag) {
//                 .int, .float, .string => {
//                     const literal = try self.parseLiteralExpression();
//                     try expressions.append(literal);
//                 },
//                 else => {
//                     break;
//                 },
//             };
//         },
//         else => {
//             self.printError();
//             return Error.InvalidInputStage;
//         },
//     };

//     return flow.AST.Node.Stage.initTransform(
//         self.allocator,
//         expressions,
//     );
// }

// pub fn parseTypeDeclaration(self: *Parser) !*flow.AST.Node.Declaration {
//     const name = try self.parseIdentifierExpression();
//     if (self.consume().tag != .colon) {
//         self.printError();
//         return Error.InvalidTypeDeclaration;
//     }
//     const value = try self.parseLiteralExpression();
//     return try flow.AST.Node.Declaration.initType(
//         self.allocator,
//         name,
//         value,
//     );
// }

// pub fn parseIdentifierExpression(self: *Parser) !*flow.AST.Node.Expression {
//     const token = self.consume();
//     const content = self.source.slice(token.position);
//     return try flow.AST.Node.Expression.initIdentifier(
//         self.allocator,
//         content,
//         token.position,
//     );
// }

// pub fn parseLiteralExpression(self: *Parser) !*flow.AST.Node.Expression {
//     const token = self.consume();
//     const content = self.source.slice(token.position);
//     return try flow.AST.Node.Expression.initLiteral(
//         self.allocator,
//         content,
//         token.position,
//     );
// }

// pub fn printError(self: *Parser) void {
//     const token = self.peek();
//     const content = self.source.slice(token.position);
//     std.debug.print("Token: {any}\n", .{token});
//     std.debug.print("Content: {s}\n", .{content});
// }

// test "parser" {
//     const allocator = testing.allocator;

//     const input =
//         \\ int : 5 | add 5 | sub 5 -> string | upper -> print
//         \\ int : 5 | add 5 | sub 5 -> string | upper -> print
//     ;
//     var source = try Source.initString(allocator, input);
//     defer source.deinit();

//     var lexer = Lexer.init(source);
//     const tokens = try lexer.Tokenize(allocator);
//     defer tokens.deinit();

//     var allocator = ArenaAllocator.init(allocator);
//     var parser = init(&allocator, source, tokens);
//     const ast = try parser.parse();
//     defer ast.deinit();
// }
