const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const testing = std.testing;

const lib = @import("../root.zig");
const core = lib.core;
const io = lib.io;
const flow = lib.flow;

pub const State = enum {
    start,
    identifier,
    identifier_literal,
    pipeline,
    mutation,
    transform,
    parameters,
    end,
};

pub const Error = error{
    InvalidToken,
    InvalidStatement,
    EmptyStack,
} || mem.Allocator.Error;

pub fn parse(allocator: mem.Allocator, source: io.Source) Error![]*flow.AST.Statement {
    var lexer = flow.Lexer.init(source);
    var token = lexer.next();

    var ast = std.ArrayList(*flow.AST.Statement).init(allocator);
    var stack = std.ArrayList(*flow.AST.Statement).init(allocator);

    state: switch (State.start) {
        .start => switch (token.tag) {
            .identifier => {
                const statement = try allocator.create(flow.AST.Statement);
                statement.* = .{ .expression = .{ .typed = .{
                    .type = .{ .name = token },
                    .value = undefined,
                } } };
                try stack.append(statement);
                token = lexer.next();
                continue :state .identifier;
            },
            .end_of_frame => return ast.toOwnedSlice(),
            else => return Error.InvalidToken,
        },
        .identifier => switch (token.tag) {
            .colon => {
                token = lexer.next();
                continue :state .identifier_literal;
            },
            else => return Error.InvalidToken,
        },
        .identifier_literal => switch (token.tag) {
            .int, .float => {
                const statement = stack.getLast();
                statement.expression.typed.value = token;
                token = lexer.next();
                continue :state .pipeline;
            },
            else => return Error.InvalidToken,
        },
        .pipeline => switch (token.tag) {
            .pipe => {
                token = lexer.next();
                continue :state .mutation;
            },
            .arrow => {
                token = lexer.next();
                continue :state .transform;
            },
            else => continue :state .end,
        },
        .mutation => switch (token.tag) {
            .identifier => {
                const statement = stack.getLast();
                const expression = try allocator.create(flow.AST.Expression);
                expression.* = statement.expression;
                statement.expression = .{
                    .mutation = .{
                        .input = expression,
                        .operation = token,
                        .parameters = undefined,
                    },
                };
                token = lexer.next();
                continue :state .parameters;
            },
            else => return Error.InvalidToken,
        },
        .transform => switch (token.tag) {
            .identifier => {
                const statement = stack.getLast();
                const expression = try allocator.create(flow.AST.Expression);
                expression.* = statement.expression;
                statement.expression = .{
                    .transform = .{
                        .input = expression,
                        .operation = token,
                        .parameters = undefined,
                    },
                };
                token = lexer.next();
                continue :state .parameters;
            },
            else => return Error.InvalidToken,
        },
        .parameters => {
            var expressions = std.ArrayList(*flow.AST.Expression).init(allocator);
            tag: switch (token.tag) {
                .int, .float => {
                    var expression = flow.AST.Expression{ .typed = .{
                        .type = undefined,
                        .value = token,
                    } };
                    try expressions.append(&expression);
                    token = lexer.next();
                    continue :tag token.tag;
                },
                else => {
                    const statement = stack.getLast();
                    switch (statement.expression) {
                        .mutation => {
                            statement.expression.mutation.parameters = try expressions.toOwnedSlice();
                            continue :state .pipeline;
                        },
                        .transform => {
                            statement.expression.transform.parameters = try expressions.toOwnedSlice();
                            continue :state .pipeline;
                        },
                        else => return Error.InvalidStatement,
                    }
                },
            }
        },
        .end => {
            const statement = stack.pop() orelse return Error.EmptyStack;
            try ast.append(statement);
            continue :state .start;
        },
    }
}

test parse {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const input = "int : 5 | add 10 | sub 5 -> string | test -> print";
    const source = try io.Source.initString(arena.allocator(), input);
    _ = try parse(arena.allocator(), source);
}
