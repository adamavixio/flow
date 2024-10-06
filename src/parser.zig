const std = @import("std");

const Self = @This();
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;
const Primitive = @import("type.zig").Primitive;
const Logger = @import("log/root.zig").Logger;

lexer: Lexer,
token: Token,
logger: Logger,
allocator: std.mem.Allocator,

pub const Ast = union(enum) {
    module: Module,
    pipeline: Pipeline,
    stage: Stage,

    pub const Tag = std.meta.FieldEnum(Ast);

    pub fn Type(comptime tag: Tag) type {
        return std.meta.FieldType(Ast, tag);
    }

    pub const Module = struct {
        pipelines: std.ArrayList(*Pipeline),

        pub fn init(allocator: std.mem.Allocator) !*Module {
            const module = try allocator.create(Module);
            module.* = .{ .pipelines = std.ArrayList(*Pipeline).init(allocator) };
            return module;
        }

        pub fn deinit(module: *Module, allocator: std.mem.Allocator) void {
            for (module.pipelines.items) |pipeline| {
                pipeline.deinit(allocator);
            }
            module.pipelines.deinit();
            allocator.destroy(module);
        }

        pub fn appendPipeline(module: *Module, pipeline: *Pipeline) Error!void {
            try module.pipelines.append(pipeline);
        }
    };

    pub const Pipeline = struct {
        stages: std.ArrayList(*Stage),

        pub fn init(allocator: std.mem.Allocator) !*Pipeline {
            const pipeline = try allocator.create(Pipeline);
            pipeline.* = .{ .stages = std.ArrayList(*Stage).init(allocator) };
            return pipeline;
        }

        pub fn deinit(pipeline: *Pipeline, allocator: std.mem.Allocator) void {
            for (pipeline.stages.items) |stage| {
                stage.deinit(allocator);
            }
            pipeline.stages.deinit();
            allocator.destroy(pipeline);
        }

        pub fn appendStage(pipeline: *Pipeline, stage: *Stage) Error!void {
            try pipeline.stages.append(stage);
        }
    };

    pub const Stage = union(Primitive.Tag) {
        int: IntStage,
        float: FloatStage,
        string: StringStage,

        pub const IntStage = struct {
            literals: std.ArrayList(Token),
            operators: std.ArrayList(Primitive.Operator(.int)),
        };

        pub const FloatStage = struct {
            literals: std.ArrayList(Token),
            operators: std.ArrayList(Primitive.Operator(.float)),
        };

        pub const StringStage = struct {
            literals: std.ArrayList(Token),
            operators: std.ArrayList(Primitive.Operator(.string)),
        };

        pub fn init(tag: Primitive.Tag, allocator: std.mem.Allocator) Error!*Stage {
            const stage = try allocator.create(Stage);
            stage.* = switch (tag) {
                inline else => |t| @unionInit(Stage, @tagName(t), .{
                    .literals = std.ArrayList(Token).init(allocator),
                    .operators = std.ArrayList(Primitive.Operator(t)).init(allocator),
                }),
            };
            return stage;
        }

        pub fn deinit(stage: *Stage, allocator: std.mem.Allocator) void {
            switch (stage.*) {
                inline else => |s| {
                    s.literals.deinit();
                    s.operators.deinit();
                },
            }
            allocator.destroy(stage);
        }

        pub fn appendLiteral(stage: *Stage, literal: Token) !void {
            switch (stage.*) {
                inline else => |*s| try s.literals.append(literal),
            }
        }

        pub fn appendOperator(stage: *Stage, comptime tag: Primitive.Tag, operator: Primitive.Operator(tag)) !void {
            switch (stage.*) {
                inline else => |*s, t| if (tag == t) {
                    try s.operators.append(operator);
                },
            }
        }
    };
};

pub const Error = error{
    Expected_Keyword_Or_Special,
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
    Expected_Special_EOF,
} || std.mem.Allocator.Error;

pub fn init(lexer: Lexer, allocator: std.mem.Allocator) Self {
    return .{
        .lexer = lexer,
        .token = undefined,
        .logger = Logger.init(.info),
        .allocator = allocator,
    };
}

pub fn next(self: *Self) void {
    self.token = self.lexer.next();
}

pub fn parse(self: *Self) Error!*Ast.Module {
    var module = try Ast.Module.init(self.allocator);
    errdefer module.deinit(self.allocator);

    self.next();
    while (true) {
        const pipeline = switch (self.token) {
            .keyword => switch (self.token.keyword) {
                .int => try self.parsePipeline(.int),
                .float => try self.parsePipeline(.float),
                .string => try self.parsePipeline(.string),
            },
            .special => switch (self.token.special) {
                .eof => return module,
                else => return Error.Expected_Special_EOF,
            },
            else => return Error.Expected_Keyword_Or_Special,
        };
        try module.appendPipeline(pipeline);
    }
}

pub fn parsePipeline(self: *Self, tag: Primitive.Tag) Error!*Ast.Pipeline {
    var pipeline = try Ast.Pipeline.init(self.allocator);
    errdefer pipeline.deinit(self.allocator);

    self.next();
    switch (self.token) {
        .symbol => switch (self.token.symbol) {
            .colon => {},
        },
        else => return Error.Expected_Symbol,
    }

    while (true) {
        const stage = try self.parseStage(tag);
        try pipeline.appendStage(stage);
        switch (self.token) {
            .keyword => return pipeline,
            .operator => switch (self.token.operator) {
                .arrow => {},
                else => return Error.Expected_Operator_Arrow,
            },
            .special => switch (self.token.special) {
                .eof => return pipeline,
                else => return Error.Expected_Special_EOF,
            },
            else => return Error.Expected_Operator,
        }
    }
}

pub fn parseStage(self: *Self, tag: Primitive.Tag) Error!*Ast.Stage {
    var stage = try Ast.Stage.init(tag, self.allocator);
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
