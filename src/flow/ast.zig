const std = @import("std");
const heap = std.heap;
const mem = std.mem;

const root = @import("../root.zig");
const flow = root.flow;
const core = flow.core;

pub const Node = union(enum) {
    pipeline: Pipeline,
    operation: Operation,
    declaration: Declaration,
    expression: Expression,
    literal: Literal,
};

pub const Pipeline = struct {
    left: *Node,
    right: *Node,

    pub fn create(allocator: mem.Allocator, left: *Node, right: *Node) !*Node {
        const node_ptr = try allocator.create(Node);
        node_ptr.* = .{ .pipeline = .{ .left = left, .right = right } };
        return node_ptr;
    }
};

pub const Operation = struct {
    name: *Node,
    args: []*Node,

    pub fn create(allocator: mem.Allocator, name: *Node, args: []*Node) !*Node {
        const node_ptr = try allocator.create(Node);
        node_ptr.* = .{ .operation = .{ .name = name, .args = args } };
        return node_ptr;
    }
};

pub const Declaration = struct {
    name: []const u8,
    literal: *Node,

    pub fn create(allocator: mem.Allocator, name: []const u8, literal: *Node) !*Node {
        const node_ptr = try allocator.create(Node);
        node_ptr.* = .{ .declaration = .{ .name = name, .literal = literal } };
        return node_ptr;
    }
};

pub const Expression = struct {
    left: *Node,
    right: *Node,

    pub fn create(allocator: mem.Allocator, left: *Node, right: *Node) !*Node {
        const node_ptr = try allocator.create(Node);
        node_ptr.* = .{ .expression = .{ .left = left, .right = right } };
        return node_ptr;
    }
};

pub const Literal = struct {
    value: core.Value,

    pub fn create(allocator: mem.Allocator, value: core.Value) !*Node {
        const node_ptr = try allocator.create(Node);
        node_ptr.* = .{ .literal = .{ .value = value } };
        return node_ptr;
    }
};

// pub const Pipeline = struct {
//     stages: std.ArrayList(*Stage),

//     pub fn init(allocator: heap.ArenaAllocator) !*Pipeline {
//         const pipeline = try allocator.create(Pipeline);
//         const pipeline_stages = std.ArrayList(*Stage).init(allocator);
//         pipeline.* = .{ .stages = pipeline_stages };
//         return pipeline;
//     }
// };

// pub const Stage = union(enum) {
//     input: *Input,
//     transform: *Transform,

//     pub fn initInput(
//         allocator: heap.ArenaAllocator,
//         declaration: *Declaration,
//         expressions: std.ArrayList(*Expression),
//     ) !*Stage {
//         const stage = try allocator.create(Stage);
//         const stage_input = try Input.init(allocator, declaration, expressions);
//         stage.* = .{ .input = stage_input };
//         return stage;
//     }

//     pub fn initTransform(
//         allocator: heap.ArenaAllocator,
//         expressions: std.ArrayList(*Expression),
//     ) !*Stage {
//         const stage = try allocator.create(Stage);
//         const stage_transform = try Transform.init(allocator, expressions);
//         stage.* = .{ .transform = stage_transform };
//         return stage;
//     }

//     pub const Input = struct {
//         declaration: *Declaration,
//         expressions: std.ArrayList(*Expression),

//         pub fn init(
//             allocator: heap.ArenaAllocator,
//             declaration: *Declaration,
//             expressions: std.ArrayList(*Expression),
//         ) !*Input {
//             const input = try allocator.create(Stage.Input);
//             input.* = .{ .declaration = declaration, .expressions = expressions };
//             return input;
//         }
//     };

//     pub const Transform = struct {
//         expressions: std.ArrayList(*Expression),

//         pub fn init(
//             allocator: heap.ArenaAllocator,
//             expressions: std.ArrayList(*Expression),
//         ) !*Transform {
//             const transform = try allocator.create(Stage.Transform);
//             transform.* = .{ .expressions = expressions };
//             return transform;
//         }
//     };
// };

// pub const Declaration = union(enum) {
//     type: *Type,

//     pub const Type = struct {
//         name: *Expression,
//         value: *Expression,

//         pub fn init(allocator: heap.ArenaAllocator, name: *Expression, value: *Expression) !*Type {
//             const @"type" = try allocator.create(Type);
//             @"type".* = .{ .name = name, .value = value };
//             return @"type";
//         }
//     };

//     pub fn initType(allocator: heap.ArenaAllocator, name: *Expression, value: *Expression) !*Declaration {
//         const declaration = try allocator.create(Declaration);
//         const declaration_type = try Type.init(allocator, name, value);
//         declaration.* = .{ .type = declaration_type };
//         return declaration;
//     }
// };

// pub const Expression = union(enum) {
//     identifier: *Identifier,
//     literal: *Literal,

//     pub const Identifier = struct {
//         name: []const u8,
//         position: Position,

//         pub fn init(allocator: heap.ArenaAllocator, name: []const u8, position: Position) !*Identifier {
//             const identifier = try allocator.create(Identifier);
//             const identifier_name = try allocator.dupe(u8, name);
//             identifier.* = .{ .name = identifier_name, .position = position };
//             return identifier;
//         }
//     };

//     pub fn initIdentifier(allocator: heap.ArenaAllocator, name: []const u8, position: Position) !*Expression {
//         const expression = try allocator.create(Expression);
//         const expression_identifier = try Identifier.init(allocator, name, position);
//         expression.* = .{ .identifier = expression_identifier };
//         return expression;
//     }

//     pub const Literal = struct {
//         value: []const u8,
//         position: Position,

//         pub fn init(allocator: heap.ArenaAllocator, value: []const u8, position: Position) !*Literal {
//             const literal = try allocator.create(Literal);
//             const literal_value = try allocator.dupe(u8, value);
//             literal.* = .{ .value = literal_value, .position = position };
//             return literal;
//         }
//     };

//     pub fn initLiteral(allocator: heap.ArenaAllocator, value: []const u8, position: Position) !*Expression {
//         const expression = try allocator.create(Expression);
//         const expression_literal = try Literal.init(allocator, value, position);
//         expression.* = .{ .literal = expression_literal };
//         return expression;
//     }
// };

// pub fn walk(ast: *AST) void {
//     for (ast.pipelines.items) |pipeline| {
//         walkPipeline(pipeline);
//     }
// }

// pub fn walkPipeline(pipeline: *Pipeline) void {
//     for (pipeline.stages.items) |stage| {
//         walkStage(stage);
//     }
// }

// pub fn walkStage(stage: *Stage) void {
//     switch (stage.*) {
//         .input => |input| {
//             std.debug.print("\nInput Stage\n", .{});
//             walkDeclaration(input.declaration);
//             for (input.expressions.items) |expr| {
//                 walkExpression(expr);
//             }
//         },
//         .transform => |transform| {
//             std.debug.print("\nTransform Stage\n", .{});
//             for (transform.expressions.items) |expr| {
//                 walkExpression(expr);
//             }
//         },
//     }
// }

// pub fn walkDeclaration(declaration: *Declaration) void {
//     switch (declaration.*) {
//         .type => |type_decl| {
//             walkExpression(type_decl.name);
//             walkExpression(type_decl.value);
//         },
//     }
// }

// pub fn walkExpression(expression: *Expression) void {
//     switch (expression.*) {
//         .identifier => |identifier| {
//             // Process identifier
//             // For example, print or analyze identifier.name and identifier.position
//             std.debug.print("Identifier: {s}\n", .{identifier.name});
//         },
//         .literal => |literal| {
//             // Process literal
//             // For example, print or analyze literal.value and literal.position
//             std.debug.print("Literal: {s}\n", .{literal.value});
//         },
//     }
// }
