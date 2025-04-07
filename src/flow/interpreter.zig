const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const io = lib.io;
const flow = lib.flow;

const Parser = @This();

ast: flow.AST,
source: io.Source,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, source: io.Source) !Parser {
    var parser = try flow.Parser.init(allocator, source);
    const ast = try parser.parse();
    return .{
        .ast = ast,
        .source = source,
        .allocator = allocator,
    };
}

pub fn execute(self: *Parser) !void {
    for (self.ast.statements) |statement| {
        switch (statement) {
            .pipeline => |pipeline| try self.executePipeline(pipeline),
        }
    }
}

pub fn executePipeline(self: *Parser, pipeline: flow.AST.Statement.Pipeline) !void {
    const value = try self.evaluateTypeExpression(pipeline.type);
    std.debug.print("\n\nValue: {any}\n\n", .{value});
}

pub fn evaluateTypeExpression(
    self: *Parser,
    expression: flow.AST.ExpressionType,
) !core.Value {
    const tag = try core.Type.parse(expression.name);
    const value = try core.Value.init(self.allocator, tag, expression.parameter.literal);
    return value;
}

test execute {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 5 | add 10 | sub 5 -> string | test -> print";
    const source = try io.Source.initString(arena.allocator(), input);

    var interpreter = try init(arena.allocator(), source);
    _ = try interpreter.execute();
}
