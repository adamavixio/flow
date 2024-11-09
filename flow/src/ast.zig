const std = @import("std");
const meta = std.meta;
const testing = std.testing;
const ArrayList = std.ArrayList;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const StaticStringMap = std.StaticStringMap;

const root = @import("root.zig");
const Position = root.Position;

pub const AST = @This();

arena: *ArenaAllocator,
pipelines: ArrayList(*Pipeline),

pub fn init(arena: *ArenaAllocator) !*AST {
    const ast = try arena.allocator().create(AST);
    const ast_pipelines = ArrayList(*Pipeline).init(arena.allocator());
    ast.* = .{ .arena = arena, .pipelines = ast_pipelines };
    return ast;
}

pub fn deinit(self: AST) void {
    self.arena.deinit();
}

pub const Pipeline = struct {
    stages: ArrayList(*Stage),

    pub fn init(arena: *ArenaAllocator) !*Pipeline {
        const pipeline = try arena.allocator().create(Pipeline);
        const pipeline_stages = ArrayList(*Stage).init(arena.allocator());
        pipeline.* = .{ .stages = pipeline_stages };
        return pipeline;
    }
};

pub const Stage = union(enum) {
    input: *Input,
    transform: *Transform,

    pub fn initInput(
        arena: *ArenaAllocator,
        declaration: *Declaration,
        expressions: ArrayList(*Expression),
    ) !*Stage {
        const stage = try arena.allocator().create(Stage);
        const stage_input = try Input.init(arena, declaration, expressions);
        stage.* = .{ .input = stage_input };
        return stage;
    }

    pub fn initTransform(
        arena: *ArenaAllocator,
        expressions: ArrayList(*Expression),
    ) !*Stage {
        const stage = try arena.allocator().create(Stage);
        const stage_transform = try Transform.init(arena, expressions);
        stage.* = .{ .transform = stage_transform };
        return stage;
    }

    pub const Input = struct {
        declaration: *Declaration,
        expressions: ArrayList(*Expression),

        pub fn init(
            arena: *ArenaAllocator,
            declaration: *Declaration,
            expressions: ArrayList(*Expression),
        ) !*Input {
            const input = try arena.allocator().create(Stage.Input);
            input.* = .{ .declaration = declaration, .expressions = expressions };
            return input;
        }
    };

    pub const Transform = struct {
        expressions: ArrayList(*Expression),

        pub fn init(
            arena: *ArenaAllocator,
            expressions: ArrayList(*Expression),
        ) !*Transform {
            const transform = try arena.allocator().create(Stage.Transform);
            transform.* = .{ .expressions = expressions };
            return transform;
        }
    };
};

pub const Declaration = union(enum) {
    type: *Type,

    pub const Type = struct {
        name: *Expression,
        value: *Expression,

        pub fn init(arena: *ArenaAllocator, name: *Expression, value: *Expression) !*Type {
            const @"type" = try arena.allocator().create(Type);
            @"type".* = .{ .name = name, .value = value };
            return @"type";
        }
    };

    pub fn initType(arena: *ArenaAllocator, name: *Expression, value: *Expression) !*Declaration {
        const declaration = try arena.allocator().create(Declaration);
        const declaration_type = try Type.init(arena, name, value);
        declaration.* = .{ .type = declaration_type };
        return declaration;
    }
};

pub const Expression = union(enum) {
    identifier: *Identifier,
    literal: *Literal,

    pub const Identifier = struct {
        name: []const u8,
        position: Position,

        pub fn init(arena: *ArenaAllocator, name: []const u8, position: Position) !*Identifier {
            const identifier = try arena.allocator().create(Identifier);
            const identifier_name = try arena.allocator().dupe(u8, name);
            identifier.* = .{ .name = identifier_name, .position = position };
            return identifier;
        }
    };

    pub fn initIdentifier(arena: *ArenaAllocator, name: []const u8, position: Position) !*Expression {
        const expression = try arena.allocator().create(Expression);
        const expression_identifier = try Identifier.init(arena, name, position);
        expression.* = .{ .identifier = expression_identifier };
        return expression;
    }

    pub const Literal = struct {
        value: []const u8,
        position: Position,

        pub fn init(arena: *ArenaAllocator, value: []const u8, position: Position) !*Literal {
            const literal = try arena.allocator().create(Literal);
            const literal_value = try arena.allocator().dupe(u8, value);
            literal.* = .{ .value = literal_value, .position = position };
            return literal;
        }
    };

    pub fn initLiteral(arena: *ArenaAllocator, value: []const u8, position: Position) !*Expression {
        const expression = try arena.allocator().create(Expression);
        const expression_literal = try Literal.init(arena, value, position);
        expression.* = .{ .literal = expression_literal };
        return expression;
    }
};

pub fn walk(ast: *AST) void {
    for (ast.pipelines.items) |pipeline| {
        walkPipeline(pipeline);
    }
}

pub fn walkPipeline(pipeline: *Pipeline) void {
    for (pipeline.stages.items) |stage| {
        walkStage(stage);
    }
}

pub fn walkStage(stage: *Stage) void {
    switch (stage.*) {
        .input => |input| {
            std.debug.print("\nInput Stage\n", .{});
            walkDeclaration(input.declaration);
            for (input.expressions.items) |expr| {
                walkExpression(expr);
            }
        },
        .transform => |transform| {
            std.debug.print("\nTransform Stage\n", .{});
            for (transform.expressions.items) |expr| {
                walkExpression(expr);
            }
        },
    }
}

pub fn walkDeclaration(declaration: *Declaration) void {
    switch (declaration.*) {
        .type => |type_decl| {
            walkExpression(type_decl.name);
            walkExpression(type_decl.value);
        },
    }
}

pub fn walkExpression(expression: *Expression) void {
    switch (expression.*) {
        .identifier => |identifier| {
            // Process identifier
            // For example, print or analyze identifier.name and identifier.position
            std.debug.print("Identifier: {s}\n", .{identifier.name});
        },
        .literal => |literal| {
            // Process literal
            // For example, print or analyze literal.value and literal.position
            std.debug.print("Literal: {s}\n", .{literal.value});
        },
    }
}

// pub const Value = union(enum) {
//     /// Integer (Signed)
//     i8: i8,
//     i16: i16,
//     i32: i32,
//     i64: i64,
//     i128: i128,
//     int: isize,
//     /// Integer (Unsigned)
//     u8: u8,
//     u16: u16,
//     u32: u32,
//     u64: u64,
//     u128: u128,
//     uint: usize,
//     /// Float
//     f16: f16,
//     f32: f32,
//     f64: f64,
//     f128: f128,
//     float: f64,
//     /// String
//     string: []const u8,

//     pub fn init(comptime field_name: []const u8, field_value: []const u8) !Value {
//         const T = try Type(field_name);
//         return switch (@typeInfo(T)) {
//             .Int => |info| {
//                 const value = switch (info.signedness) {
//                     .signed => try std.fmt.parseInt(T, field_value, 10),
//                     .unsigned => try std.fmt.parseUnsigned(T, field_value, 10),
//                 };
//                 return @unionInit(Value, field_name, value);
//             },
//             .Float => {
//                 const value = try std.fmt.parseFloat(T, field_value);
//                 return @unionInit(Value, field_name, value);
//             },
//             .Pointer => |info| {
//                 switch (info.size) {
//                     .Slice => if (info.child != u8) return Error.SliceIsNotString,
//                     else => return Error.PointerIsNotSlice,
//                 }
//                 return Value{ .string = field_value };
//             },
//             else => error.UnsupportedType,
//         };
//     }

//     const map = blk: {
//         const fields = meta.fields(Value);
//         var mapped: [fields.len]struct { []const u8, type } = undefined;
//         for (fields, 0..) |field, i| mapped[i] = .{ field.name, field.type };
//         break :blk StaticStringMap(type).initComptime(mapped);
//     };

//     pub fn Type(comptime field_name: []const u8) Error!type {
//         return map.get(field_name) orelse return Error.ValueFieldNameNotFound;
//     }
// };

// test "value" {
//     inline for (meta.fields(Value)) |field| {
//         switch (@field(meta.FieldEnum(Value), field.name)) {
//             .i8, .i16, .i32, .i64, .i128, .int => |tag| {
//                 try testing.expectEqual(@unionInit(Value, field.name, 0), try Value.init(@tagName(tag), "0"));
//                 try testing.expectEqual(meta.FieldType(Value, tag), try Value.Type(@tagName(tag)));
//             },
//             .u8, .u16, .u32, .u64, .u128, .uint => |tag| {
//                 try testing.expectEqual(@unionInit(Value, field.name, 0), try Value.init(@tagName(tag), "0"));
//                 try testing.expectEqual(meta.FieldType(Value, tag), try Value.Type(@tagName(tag)));
//             },
//             .f16, .f32, .f64, .f128, .float => |tag| {
//                 try testing.expectEqual(@unionInit(Value, field.name, 0), try Value.init(@tagName(tag), "0"));
//                 try testing.expectEqual(meta.FieldType(Value, tag), try Value.Type(@tagName(tag)));
//             },
//             .string => |tag| {
//                 try testing.expectEqual(@unionInit(Value, field.name, "0"), try Value.init(@tagName(tag), "0"));
//                 try testing.expectEqual(meta.FieldType(Value, tag), try Value.Type(@tagName(tag)));
//             },
//         }
//     }
// }

// pub const generateId = struct {
//     var id: usize = 0;

//     pub fn generate() usize {
//         id += 1;
//         return id;
//     }
// }.generate;
