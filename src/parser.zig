const std = @import("std");

const Self = @This();
const Source = @import("io/source.zig");
const Type = @import("type");
const Lexer = @import("lexer.zig");

lexer: Lexer,
token: Lexer.Token,

pub const Ast = union(enum) {
    module: Module,
    declaration: Declaration,
    literal: Literal,
    operation: Operation,

    pub const Module = struct {
        token: Lexer.Token,
    };

    pub const Object = struct {
        token: Lexer.Token,
        literals: std.ArrayList(*Literal),
        operations: std.ArrayList(*Operation),
    };

    const Literal = struct {
        token: Lexer.Token,
    };

    const Operation = struct {
        token: Lexer.Token,
    };

    pub const Error = error{
        TagInvalid,
    };

    pub fn init(allocator: std.mem.Allocator, tag: std.meta.Tag(Ast), token: Lexer.Token) !*Ast {
        const ast = try allocator.create(Ast);
        switch (tag) {
            .module => {
                ast.* = .{
                    .module = .{
                        .token = token,
                        .literals = std.ArrayList(*Literal).init(allocator),
                        .operations = std.ArrayList(*Operation).init(allocator),
                    },
                };
            },
            .literals => {
                ast.* = .{
                    .literals = .{
                        .token = token,
                    },
                };
            },
            .operation => {
                ast.* = .{
                    .operation = .{
                        .token = token,
                    },
                };
            },
        }
        return ast;
    }

    pub fn deinit(self: *Ast, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .module => |*m| {
                for (m.literals.items) |decl| {
                    allocator.destroy(decl);
                }
                m.literals.deinit();
                for (m.operations.items) |op| {
                    allocator.destroy(op);
                }
                m.operations.deinit();
            },
            .literal => {},
            .operation => {},
        }
        allocator.destroy(self);
    }

    pub fn addLiteral(self: *Ast, literal: *Literal) !void {
        switch (self.*) {
            .module => |*m| try m.literals.append(literal),
            else => return Ast.Error.TagInvalid,
        }
    }

    pub fn addOperation(self: *Ast, operation: *Operation) !void {
        switch (self.*) {
            .module => |*m| try m.operations.append(operation),
            else => return Ast.Error.TagInvalid,
        }
    }
};

pub const Error = error{
    InvalidTag,
    InvalidKeyword,
    InvalidSymbol,
    InvalidLiteral,
    InvalidOperator,
    InvalidSpecial,
};

pub fn init(allocator: std.mem.Allocator, lexer: Lexer) Self {
    const token = Lexer.Token.initDefault(.{ .special = .module });
    return .{ .token = token, .lexer = lexer, .allocator = allocator };
}

pub fn next(self: *Self) void {
    self.token = self.lexer.next();
}

pub fn parse(self: *Self) !*Ast {
    const root = try Ast.init(self.allocator, self.token);

    while (true) {
        self.next();
        switch (self.token.tag) {
            .keyword => {
                const child = try self.parseKeyword();
                try root.children.append(child);
            },
            .special => |tag| switch (tag) {
                .eof => break,
                else => return Error.InvalidSpecial,
            },
            else => return Error.InvalidTag,
        }
    }

    return root;
}

pub fn parseKeyword(self: *Self) !*Ast {
    switch (self.token.tag.keyword) {
        .int, .float, .string => return try self.parseType(),
    }
    const node = try Ast.init(self.allocator, self.token);

    self.next();
    try node.children.append(try self.parseColon());

    self.next();
    while (try self.parseChain()) |literal| {
        try node.children.append(literal);
    }
    while (try self.parsePipe()) |operator| {
        try node.children.append(operator);
    }

    return node;
}

pub fn parseColon(self: *Self) !*Ast {
    switch (self.token.tag) {
        .symbol => |symbol| switch (symbol) {
            .colon => self.next(),
            else => return Error.InvalidSymbol,
        },
        else => return Error.InvalidTag,
    }
    return try self.parseLiteral();
}

pub fn parseChain(self: *Self) !?*Ast {
    switch (self.token.tag) {
        .symbol => |symbol| switch (symbol) {
            .chain => self.next(),
            else => return null,
        },
        else => return Error.InvalidTag,
    }
    return try self.parseLiteral();
}

pub fn parseLiteral(self: *Self) !*Ast {
    return switch (self.token.tag) {
        .literal => try Ast.init(self.allocator, self.token),
        else => Error.InvalidTag,
    };
}

pub fn parsePipe(self: *Self) !?*Ast {
    switch (self.token.tag) {
        .symbol => |symbol| switch (symbol) {
            .pipe => self.next(),
            else => return null,
        },
        else => return Error.InvalidTag,
    }
    return try self.parseLiteral();
}

pub fn parseOperator(self: *Self) !?*Ast {
    return switch (self.token.tag) {
        .literal => try Ast.init(self.allocator, self.token),
        else => return Error.InvalidTag,
    };
}

test "string" {
    const allocator = std.testing.allocator;

    const input = Source.initString("string : 'test' | sort | unique");
    const lexer = Lexer.init(input);

    var parser = init(allocator, lexer);
    const ast = try parser.parse();
    defer ast.deinit(allocator);
}
