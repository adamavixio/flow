const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;

const root = @import("../root.zig");
const flow = root.flow;

pub const Parser = @This();

lexer: flow.Lexer,
source: flow.Source,
allocator: mem.Allocator,

pub const Error = error{
    ExpectedIdentifier,
    ExpectedLiteral,
    ExpectedOperatorColon,
};

pub fn init(allocator: mem.Allocator, source: flow.Source) Parser {
    return .{ .source = source, .lexer = flow.Lexer.init(source), .allocator = allocator };
}

pub fn parse(self: *Parser) !*flow.AST.Node {
    return self.parseDeclaration();
}

test parse {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "string : 'test' | upper -> concat 'ing' -> print";
    const source = try flow.Source.initString(arena.allocator(), input);

    var parser = init(arena.allocator(), source);
    const actual = try parser.parse();
    std.debug.print("{any}\n", .{actual});
}

pub fn parsePipeline(self: *Parser) !*flow.AST.Node {
    const declaration = try self.parseDeclaration();
}

pub fn parseExpression(self: *Parser) !*flow.AST.Node {
    while (self.lexer.peek().tag == .chain) {
        _ = self.lexer.next();
    }
}

pub fn parseOperation(self: *Parser, identifier: []const u8) !*flow.AST.Node {
    const token = self.lexer.next();
    if (!token.isIdentifier()) return Error.ExpectedIdentifier;
    const content = self.source.buffer[token.start..token.end];
    const args = std.ArrayList(*flow.AST.Node).init(self.allocator);
    while (self.lexer.peek().tag == .identifier) {
        const literal = try self.parseLiteral(content)
    }
}


pub fn parseDeclaration(self: *Parser) !*flow.AST.Node {
    const token = self.lexer.next();
    if (!token.isIdentifier()) return Error.ExpectedIdentifier;
    if (self.lexer.next().tag != .colon) return Error.ExpectedOperatorColon;
    const content = self.source.buffer[token.start..token.end];
    const literal = try self.parseLiteral(content);
    return flow.AST.Declaration.create(self.allocator, content, literal);
}

pub fn parseLiteral(self: *Parser, identifier: []const u8) !*flow.AST.Node {
    const token = self.lexer.next();
    if (!token.isLiteral()) return Error.ExpectedOperatorColon;
    const content = self.source.buffer[token.start..token.end];
    const value = try flow.core.Value.init(self.allocator, identifier, content);
    return flow.AST.Literal.create(self.allocator, value);
}

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
