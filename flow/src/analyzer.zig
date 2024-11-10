const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const root = @import("root.zig");
const AST = root.AST;
const Lexer = root.Lexer;
const Parser = root.Parser;
const Source = root.Source;

const Analyzer = @This();

pub const Error = error{
    ExpectedInputStage,
    InvalidTypeDeclaration,
    ExpectedIdentifierExpression,
    ExpectedLiteralExpression,
} || Allocator.Error;

ast: *AST,

pub fn init(ast: *AST) Analyzer {
    return .{ .ast = ast };
}

pub fn run(self: Analyzer) !void {
    for (self.ast.pipelines.items) |pipeline| {
        try analyzePipeline(pipeline);
    }
}

pub fn analyzePipeline(pipeline: *AST.Pipeline) !void {
    var previous: *AST.Stage = undefined;
    for (pipeline.stages.items) |stage| {
        switch (stage) {
            .input => previous = try analyzeInputStage(stage),
            // .transform => try analyzeTransformStage(stage, identifier),
        }
    }
}

pub fn analyzeInputStage(stage: *AST.Stage) !*AST.Stage {
    switch (stage.*) {
        .input => |input| {
            const declaration = try analyzeTypeDeclaration(input.declaration);
            for (input.expressions.items) |expression| {
                switch (expression) {
                    .identifier => try Registry.hasMethod(
                        declaration.name.identifier.name,
                        expression.identifier.name,
                    ),
                    else => return Error.ExpectedIdentifierExpression,
                }
            }
            return input;
        },
        else => return Error.ExpectedInputStage,
    }
}

pub fn analyzeTransformStage(stage: *AST.Stage, previous: *AST.Stage) !*AST.Stage {
    switch (stage.*) {
        .transform => |transform| {
            for (transform.expressions.items) |expression| {
                switch (expression) {
                    .identifier => try Registry.hasMethod(
                        declaration.name.identifier.name,
                        expression.identifier.name,
                    ),
                    else => return Error.ExpectedIdentifierExpression,
                }
            }
        },
        else => return Error.ExpectedInputStage,
    }
}

pub fn analyzeTypeDeclaration(declaration: *AST.Declaration) Error!*AST.Declaration {
    switch (declaration.*) {
        .type => |@"type"| {
            const type_name = try analyzeIdentifierExpression(@"type".name);
            const type_value = try analyzeLiteralExpression(@"type".value);
            if (!Registry.isValid(type_name.identifier.name, type_value.literal.value)) {
                return Error.InvalidTypeDeclaration;
            }
            return declaration;
        },
    }
}

pub fn analyzeIdentifierExpression(expression: *AST.Expression) Error!*AST.Expression {
    return switch (expression.*) {
        .identifier => return expression,
        else => return Error.ExpectedIdentifierExpression,
    };
}

pub fn analyzeLiteralExpression(expression: *AST.Expression) Error!*AST.Expression {
    return switch (expression.*) {
        .literal => return expression,
        else => return Error.ExpectedIdentifierExpression,
    };
}

test "parser" {
    const allocator = testing.allocator;

    const input =
        \\ int : 5 | add 5 | sub 5 -> string | upper -> print
        \\ int : 5 | add 5 | sub 5 -> string | upper -> print
    ;
    var source = try Source.initString(allocator, input);
    defer source.deinit();

    var lexer = Lexer.init(source);
    const tokens = try lexer.Tokenize(allocator);
    defer tokens.deinit();

    var arena = ArenaAllocator.init(allocator);
    var parser = Parser.init(&arena, source, tokens);
    const ast = try parser.parse();
    defer ast.deinit();

    const analyzer = init(ast);
    try analyzer.run();
}

// pub fn analyzeExpression(declaration: *AST.Declaration) !type {

// }
