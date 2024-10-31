const std = @import("std");
const log = @import("log");

const logger = log.Logger.default();

pub const Error = error{
    InvalidType,
    InvalidDeclaration,
    MissingMutation,
    InvalidMutation,
    MissingTransformation,
    InvalidTransformation,
    MissingTermination,
    InvalidTermination,
};

pub const Tag = enum {
    i8,
    i16,
    i32,
    i64,
    i128,
    int,
    u8,
    u16,
    u32,
    u64,
    u128,
    uint,
    f16,
    f32,
    f64,
    f128,
    float,
    bytes,
    string,
};

pub const Base = union(Tag) {
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    i128: i128,
    int: isize,
    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    u128: u128,
    uint: usize,
    f16: f16,
    f32: f32,
    f64: f64,
    f128: f128,
    float: f64,
    bytes: []u8,
    string: []const u8,
};

pub fn Type(comptime tag: Tag) type {
    return struct {
        const Self = @This();
        const Value = std.meta.FieldType(Base, tag);
        const Traits = Implement(Self, Value);

        value: Value,
        traits: Traits = .{},

        pub fn init(allocator: std.mem.Allocator, value: Value) !*Self {
            const self = try allocator.create(Self);
            switch (@typeInfo(Value)) {
                .Pointer => |ptr_info| switch (ptr_info.child) {
                    u8 => self.*.value = try allocator.dupe(u8, value),
                    else => self.*.value = value,
                },
                else => self.*.value = value,
            }
            return self;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (@typeInfo(Value)) {
                .Pointer => |ptr_info| switch (ptr_info.child) {
                    u8 => allocator.free(self.value),
                    else => {},
                },
                else => {},
            }
            allocator.destroy(self);
        }

        pub fn assertMutation(_: Self, comptime trait_name: []const u8) Error!void {
            if (!@hasDecl(Traits, trait_name)) return .MissingMutation;

            const fn_info = switch (@typeInfo(@TypeOf(@field(Traits, trait_name)))) {
                .Fn => |info| info,
                else => return Error.InvalidDeclaration,
            };

            switch (fn_info.return_type.?) {
                void => return,
                else => return Error.InvalidMutation,
            }
        }

        pub fn assertTransformation(_: Self, comptime trait_name: []const u8) Error!void {
            if (!@hasDecl(Traits, trait_name)) return .MissingTermination;

            const fn_info = switch (@typeInfo(@TypeOf(@field(Traits, trait_name)))) {
                .Fn => |info| info,
                else => return Error.InvalidDeclaration,
            };

            const result_info = switch (@typeInfo(fn_info.return_type.?)) {
                .ErrorUnion => |info| info,
                else => return Error.InvalidTransformation,
            };

            const type_info = switch (@typeInfo(result_info.payload)) {
                .Pointer => |info| info,
                else => return Error.InvalidTransformation,
            };

            inline for (std.meta.fields(Tag)) |field| {
                if (type_info.child == Type(@field(Tag, field.name))) return;
            }

            return Error.InvalidTransformation;
        }

        pub fn assertTermination(_: Self, comptime trait_name: []const u8) Error!void {
            if (!@hasDecl(Traits, trait_name)) return .MissingTermination;

            const fn_info = switch (@typeInfo(@TypeOf(@field(Traits, trait_name)))) {
                .Fn => |info| info,
                else => return Error.InvalidDeclaration,
            };

            const result_info = switch (@typeInfo(fn_info.return_type.?)) {
                .ErrorUnion => |info| info,
                else => return Error.InvalidTermination,
            };

            switch (result_info.payload) {
                void => return,
                else => return Error.InvalidMutation,
            }
        }
    };
}

pub fn Implement(comptime Pointer: type, comptime Value: type) type {
    switch (@typeInfo(Value)) {
        .Int => return struct {
            const Self = @This();

            pub fn add(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value += value;
            }

            pub fn sub(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value -= value;
            }

            pub fn mul(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value *= value;
            }

            pub fn div(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value = @divTrunc(pointer.value, value);
            }

            pub fn string(self: *Self, allocator: std.mem.Allocator) !*Type(.string) {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
                defer allocator.free(transform);
                return try Type(.string).init(allocator, transform);
            }

            pub fn print(self: *Self) !void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                std.debug.print(pointer.value);
            }
        },
        .Float => return struct {
            const Self = @This();

            pub fn add(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value += value;
            }

            pub fn sub(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value -= value;
            }

            pub fn mul(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value *= value;
            }

            pub fn div(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                pointer.value = @divTrunc(pointer.value, value);
            }

            pub fn string(self: *Self, allocator: std.mem.Allocator) !*Type(.string) {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
                defer allocator.free(transform);
                return try Type(.string).init(allocator, transform);
            }

            pub fn print(self: *Self) !void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                std.debug.print(pointer.value);
            }
        },
        .Pointer => |info| switch (info.size) {
            .Slice => switch (info.child) {
                u8 => if (info.is_const) {
                    return struct {
                        const Self = @This();

                        pub fn upper(self: *Self, allocator: std.mem.Allocator) !*Type(.string) {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                            var transform = try allocator.alloc(u8, pointer.value.len);
                            defer allocator.free(transform);
                            for (pointer.value, 0..) |c, i| {
                                transform[i] = std.ascii.toUpper(c);
                            }
                            return Type(.string).init(allocator, transform);
                        }

                        pub fn lower(self: *Self, allocator: std.mem.Allocator) !*Type(.string) {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                            var transform = try allocator.alloc(u8, pointer.value.len);
                            defer allocator.free(transform);
                            for (pointer.value, 0..) |c, i| {
                                transform[i] = std.ascii.toLower(c);
                            }
                            return Type(.string).init(allocator, transform);
                        }

                        pub fn print(self: *Self) !void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                            std.debug.print(pointer.value);
                        }
                    };
                } else {
                    return struct {
                        const Self = @This();

                        pub fn upper(self: *Self) void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                            for (pointer.value) |*c| {
                                c.* = std.ascii.toUpper(c.*);
                            }
                        }

                        pub fn lower(self: *Self) void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                            for (pointer.value) |*c| {
                                c.* = std.ascii.toLower(c.*);
                            }
                        }

                        pub fn print(self: *Self) !void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("traits", self));
                            std.debug.print(pointer.value);
                        }
                    };
                },
                else => @compileError("unsupported slice type: " ++ @typeName(info.child)),
            },
            else => @compileError("unsupported pointer size: " ++ @typeName(info.size)),
        },
        else => @compileError("unsupported value type: " ++ @typeInfo(Value)),
    }
}

pub fn TypeFrom(string: []const u8) type {
    inline for (std.meta.fields(Tag)) |field| {
        if (std.mem.eql(u8, field.name, string)) {
            return Type(@field(Tag, field.name));
        }
    }
    @compileError("Invalid string: " ++ string);
}

test "primitive int" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "i8", "i16", "i32", "i64", "i128", "int" }) |literal| {
        var int = try TypeFrom(literal).init(allocator, 0);
        defer int.deinit(allocator);
        try std.testing.expectEqual(0, int.value);

        try int.assertMutation("add");
        int.traits.add(20);
        try std.testing.expectEqual(20, int.value);

        try int.assertMutation("sub");
        int.traits.sub(10);
        try std.testing.expectEqual(10, int.value);

        try int.assertMutation("mul");
        int.traits.mul(5);
        try std.testing.expectEqual(50, int.value);

        try int.assertMutation("div");
        int.traits.div(2);
        try std.testing.expectEqual(25, int.value);

        try int.assertTransformation("string");
        const string = try int.traits.string(allocator);
        defer string.deinit(allocator);
        try std.testing.expectEqualStrings("25", string.value);

        try int.assertTermination("print");
    }
}

test "primitive uint" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "u8", "u16", "u32", "u64", "u128", "uint" }) |literal| {
        var uint = try TypeFrom(literal).init(allocator, 0);
        defer uint.deinit(allocator);
        try std.testing.expectEqual(0, uint.value);

        try uint.assertMutation("add");
        uint.traits.add(20);
        try std.testing.expectEqual(20, uint.value);

        try uint.assertMutation("sub");
        uint.traits.sub(10);
        try std.testing.expectEqual(10, uint.value);

        try uint.assertMutation("mul");
        uint.traits.mul(5);
        try std.testing.expectEqual(50, uint.value);

        try uint.assertMutation("div");
        uint.traits.div(2);
        try std.testing.expectEqual(25, uint.value);

        try uint.assertTransformation("string");
        const string = try uint.traits.string(allocator);
        defer string.deinit(allocator);
        try std.testing.expectEqualStrings("25", string.value);

        try uint.assertTermination("print");
    }
}

test "primitive float" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "f16", "f32", "f64", "f128", "float" }) |literal| {
        var float = try TypeFrom(literal).init(allocator, 0);
        defer float.deinit(allocator);
        try std.testing.expectEqual(0, float.value);

        try float.assertMutation("add");
        float.traits.add(20);
        try std.testing.expectEqual(20, float.value);

        try float.assertMutation("sub");
        float.traits.sub(10);
        try std.testing.expectEqual(10, float.value);

        try float.assertMutation("mul");
        float.traits.mul(5);
        try std.testing.expectEqual(50, float.value);

        try float.assertMutation("div");
        float.traits.div(2);
        try std.testing.expectEqual(25, float.value);

        try float.assertTransformation("string");
        const string = try float.traits.string(allocator);
        defer string.deinit(allocator);
        try std.testing.expectEqualStrings("25", string.value);

        try float.assertTermination("print");
    }
}

test "primitive bytes" {
    const allocator = std.testing.allocator;

    var slice = "test".*;
    var bytes = try TypeFrom("bytes").init(allocator, &slice);
    defer bytes.deinit(allocator);
    try std.testing.expectEqualStrings("test", bytes.value);

    try bytes.assertMutation("upper");
    bytes.traits.upper();
    try std.testing.expectEqualStrings("TEST", bytes.value);

    try bytes.assertMutation("lower");
    bytes.traits.lower();
    try std.testing.expectEqualStrings("test", bytes.value);

    try bytes.assertTermination("print");
}

test "primitive string" {
    const allocator = std.testing.allocator;

    var string = try TypeFrom("string").init(allocator, "test");
    defer string.deinit(allocator);
    try std.testing.expectEqualStrings("test", string.value);

    try string.assertTransformation("upper");
    const upper = try string.traits.upper(allocator);
    defer upper.deinit(allocator);
    try std.testing.expectEqualStrings("TEST", upper.value);

    try string.assertTransformation("lower");
    const lower = try string.traits.lower(allocator);
    defer lower.deinit(allocator);
    try std.testing.expectEqualStrings("test", lower.value);

    try string.assertTermination("print");
}

// test "primitive uint" {
//     const allocator = std.testing.allocator;

//     inline for ([_][]const u8{ "u8", "u16", "u32", "u64", "u128", "uint" }) |Int| {
//         var int = try Type(Int).init(allocator, 0);
//         defer int.deinit(allocator);

//         try std.testing.expect(int.hasMutation("add"));
//         try std.testing.expectEqual(0, int.value);
//         int.traits.add(10);

//         try std.testing.expect(int.hasMutation("sub"));
//         try std.testing.expectEqual(10, int.value);
//         int.traits.sub(5);

//         try std.testing.expect(int.hasMutation("mul"));
//         try std.testing.expectEqual(5, int.value);
//         int.traits.mul(10);

//         try std.testing.expect(int.hasMutation("div"));
//         try std.testing.expectEqual(50, int.value);

//         try std.testing.expect(int.hasTransformation("string"));
//         try std.testing.expect(int.hasTermination("print"));
//     }
// }

// test "primitive float" {
//     const allocator = std.testing.allocator;

//     inline for ([_]type{ f16, f32, f64, f128 }) |Int| {
//         var int = try Type(Int).init(allocator, 0);
//         defer int.deinit(allocator);

//         try std.testing.expect(int.hasMutation("add"));
//         try std.testing.expectEqual(0, int.value);
//         int.traits.add(10);

//         try std.testing.expect(int.hasMutation("sub"));
//         try std.testing.expectEqual(10, int.value);
//         int.traits.sub(5);

//         try std.testing.expect(int.hasMutation("mul"));
//         try std.testing.expectEqual(5, int.value);
//         int.traits.mul(10);

//         try std.testing.expect(int.hasMutation("div"));
//         try std.testing.expectEqual(50, int.value);

//         try std.testing.expect(int.hasTransformation("string"));
//         try std.testing.expect(int.hasTermination("print"));
//     }
// }

// pub fn Compose(comptime Base: type, comptime traits: []type) type {
//     var Result = Base;

//     inline for (traits) |Trait| {
//         Result = struct {
//             pub const Self = @This();
//             // Include base fields
//             value: Result.value,

//             // Include base methods
//             usingnamespace Result;

//             // Include trait methods
//             usingnamespace Trait(Self);
//         };
//     }

//     return Result;
// }

// pub fn invokeMethod(comptime T: type, methodName: []const u8, instance: *T, args: anytype) !void {
//     comptime {
//         if (!@hasDecl(T, methodName)) {
//             return error.MethodNotFound;
//         }
//     }
//     const method = @field(instance.*, methodName);
//     method(instance, args);
// }

// pub fn Implement(comptime tag: Primitive.Tag) type {
//     return struct {
//         const Self = @This();
//         const Value = std.meta.FieldPrimitive(Primitive, tag);

//         value: Value,
//         allocatable: Allocatable(Self, Value) = .{},
//         mutatable: Mutatable(Self, Value) = .{},
//         transformable: Transformable(Self, Value) = .{},
//         terminable: Terminable(Self, Value) = .{},

//         pub fn init(allocator: std.mem.Allocator, value: Value) !*Self {
//             return Allocatable(Self, Value).init(allocator, value);
//         }

//         pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
//             self.allocatable.deinit(allocator);
//         }

//         pub fn hasMutatable(name: []const u8) bool {
//             const Tag = std.meta.DeclEnum(Mutatable(Self, Value));
//             inline for (std.meta.fieldNames(Tag)) |field_name| {
//                 if (std.mem.eql(u8, field_name, name)) return true;
//             }
//             return false;
//         }

//         pub fn hasTransformable(name: []const u8) bool {
//             const Tag = std.meta.DeclEnum(Transformable(Self, Value));
//             inline for (std.meta.fieldNames(Tag)) |field_name| {
//                 if (std.mem.eql(u8, field_name, name)) return true;
//             }
//             return false;
//         }

//         pub fn hasTerminable(name: []const u8) bool {
//             const Tag = std.meta.DeclEnum(Terminable(Self, Value));
//             inline for (std.meta.fieldNames(Tag)) |field_name| {
//                 if (std.mem.eql(u8, field_name, name)) return true;
//             }
//             return false;
//         }
//     };
// }

// pub fn Traits(comptime tag: Primitive.Tag) type {
//     return struct {
//         const Self = @This();
//         const Value = Primitive.Layout(tag);

//         allocatable: Allocatable(Self, Value) = .{},
//         mutatable: Mutatable(Self, Value) = .{},
//         transformable: Transformable(Self, Value) = .{},
//         terminable: Terminable(Self, Value) = .{},

//         pub fn init(allocator: std.mem.Allocator, value: Value) !*Self {
//             return Allocatable(Self, Value).init(allocator, value);
//         }

//         pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
//             self.allocatable.deinit(allocator);
//         }

//         pub fn hasMutatable(name: []const u8) bool {
//             const Tag = std.meta.DeclEnum(Mutatable(Self, Value));
//             inline for (std.meta.fieldNames(Tag)) |field_name| {
//                 if (std.mem.eql(u8, field_name, name)) return true;
//             }
//             return false;
//         }

//         pub fn hasTransformable(name: []const u8) bool {
//             const Tag = std.meta.DeclEnum(Transformable(Self, Value));
//             inline for (std.meta.fieldNames(Tag)) |field_name| {
//                 if (std.mem.eql(u8, field_name, name)) return true;
//             }
//             return false;
//         }

//         pub fn hasTerminable(name: []const u8) bool {
//             const Tag = std.meta.DeclEnum(Terminable(Self, Value));
//             inline for (std.meta.fieldNames(Tag)) |field_name| {
//                 if (std.mem.eql(u8, field_name, name)) return true;
//             }
//             return false;
//         }
//     };
// }

// pub fn Allocatable(comptime T: type, comptime Value: type) type {
//     return switch (@typeInfo(Value)) {
//         .Int => struct {
//             const Self = @This();
//             pub fn init(allocator: std.mem.Allocator, value: Value) !*T {
//                 const self = try allocator.create(T);
//                 self.*.value = value;
//                 return self;
//             }
//             pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
//                 const pointer: *T = @alignCast(@fieldParentPtr("allocatable", self));
//                 allocator.destroy(pointer);
//             }
//         },
//         .Float => struct {
//             const Self = @This();
//             pub fn init(allocator: std.mem.Allocator, value: Value) !*T {
//                 const self = try allocator.create(T);
//                 self.*.value = value;
//                 return self;
//             }
//             pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
//                 const pointer: *T = @alignCast(@fieldParentPtr("allocatable", self));
//                 allocator.destroy(pointer);
//             }
//         },
//         .Pointer => |info| switch (info.child) {
//             u8 => struct {
//                 const Self = @This();
//                 pub fn init(allocator: std.mem.Allocator, value: Value) !*T {
//                     const self = try allocator.create(T);
//                     self.*.value = try allocator.dupe(u8, value);
//                     return self;
//                 }
//                 pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
//                     const pointer: *T = @alignCast(@fieldParentPtr("allocatable", self));
//                     allocator.free(pointer.value);
//                     allocator.destroy(pointer);
//                 }
//             },
//             else => @compileError("Unsupported pointer type"),
//         },
//         else => @compileError("Unsupported type"),
//     };
// }

// pub fn Mutatable(comptime T: type, comptime Value: type) type {
//     return switch (@typeInfo(Value)) {
//         .Int, .Float => struct {
//             const Self = @This();
//             pub fn add(self: *Self, value: Value) void {
//                 const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
//                 pointer.value += value;
//             }
//             pub fn sub(self: *Self, value: Value) void {
//                 const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
//                 pointer.value -= value;
//             }
//             pub fn mul(self: *Self, value: Value) void {
//                 const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
//                 pointer.value *= value;
//             }
//             pub fn div(self: *Self, value: Value) void {
//                 const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
//                 pointer.value = @divTrunc(pointer.value, value);
//             }
//         },
//         .Pointer => |info| switch (info.child) {
//             u8 => struct {
//                 const Self = @This();
//                 pub fn upper(self: *Self) void {
//                     const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
//                     for (pointer.value) |*c| {
//                         c.* = std.ascii.toUpper(c.*);
//                     }
//                 }
//                 pub fn lower(self: *Self) void {
//                     const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
//                     for (pointer.value) |*c| {
//                         c.* = std.ascii.toLower(c.*);
//                     }
//                 }
//             },
//             else => @compileError("Unsupported pointer type"),
//         },
//         else => @compileError("Unsupported type"),
//     };
// }

// pub fn Transformable(comptime T: type, comptime Value: type) type {
//     return switch (@typeInfo(Value)) {
//         .Int, .Float => struct {
//             const Self = @This();
//             pub fn string(self: *Self, allocator: std.mem.Allocator) !*Implement(.string) {
//                 const pointer: *T = @alignCast(@fieldParentPtr("transformable", self));
//                 const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
//                 defer allocator.free(transform);
//                 const value = try Implement(.string).init(allocator, transform);
//                 return value;
//             }
//         },
//         .Pointer => |info| switch (info.child) {
//             u8 => struct {
//                 const Self = @This();
//                 pub fn len(self: *Self, allocator: std.mem.Allocator) !*Implement(.uint) {
//                     const pointer: *T = @alignCast(@fieldParentPtr("transformable", self));
//                     const value = try Implement(.uint).init(allocator, pointer.value.len);
//                     return value;
//                 }
//             },
//             else => @compileError("Unsupported pointer type"),
//         },
//         else => @compileError("Unsupported type"),
//     };
// }

// pub fn Terminable(comptime T: type, comptime Value: type) type {
//     return switch (@typeInfo(Value)) {
//         .Int, .Float => struct {
//             const Self = @This();
//             pub fn print(self: *Self) void {
//                 const pointer: *T = @alignCast(@fieldParentPtr("terminable", self));
//                 std.debug.print("{d}\n", .{pointer.value});
//             }
//         },
//         .Pointer => |info| switch (info.child) {
//             u8 => struct {
//                 const Self = @This();
//                 pub fn print(self: *Self) void {
//                     const pointer: *T = @alignCast(@fieldParentPtr("terminable", self));
//                     std.debug.print("{s}\n", .{pointer.value});
//                 }
//             },
//             else => @compileError("Unsupported pointer type"),
//         },
//         else => @compileError("Unsupported type"),
//     };
// }

// test "convert type tag to underlying type" {
//     inline for ([_]struct { Primitive.Tag, type }{
//         .{ .i8, i8 },
//         .{ .i16, i16 },
//         .{ .i32, i32 },
//         .{ .i64, i64 },
//         .{ .i128, i128 },
//         .{ .int, isize },
//         .{ .u8, u8 },
//         .{ .u16, u16 },
//         .{ .u32, u32 },
//         .{ .u64, u64 },
//         .{ .u128, u128 },
//         .{ .uint, usize },
//         .{ .f16, f16 },
//         .{ .f32, f32 },
//         .{ .f64, f64 },
//         .{ .f128, f128 },
//         .{ .float, f64 },
//         .{ .string, []u8 },
//     }) |case| {
//         try std.testing.expectEqual(case[1], Primitive.Underlying(case[0]));
//     }
// }

// test "integer tags" {
//     inline for ([_]struct { type, []const u8 }{
//         .{ i8, "i8" },
//         .{ i16, "i16" },
//         .{ i32, "i32" },
//         .{ i64, "i64" },
//         .{ i128, "i128" },
//         .{ isize, "int" },
//         .{ u8, "u8" },
//         .{ u16, "u16" },
//         .{ u32, "u32" },
//         .{ u64, "u64" },
//         .{ u128, "u128" },
//         .{ usize, "uint" },
//     }) |case| {
//         try std.testing.expectEqual(case[0], Primitive.LayoutFromString(case[1]));
//     }
// }

// test "string tags" {
//     inline for ([_]struct { type, []const u8 }{
//         .{ []u8, "string" },
//     }) |case| {
//         try std.testing.expectEqual(case[0], Primitive.LayoutFromString(case[1]));
//     }
// }

// test "integer primitive" {
//     const allocator = std.testing.allocator;
//     inline for ([_]Primitive.Tag{ .i8, .i16, .i32, .i64, .i128, .int, .u8, .u16, .u32, .u64, .u128, .uint }) |tag| {
//         const Integer = Implement(tag);
//         try std.testing.expect(Integer.hasMutatable("add"));
//         try std.testing.expect(Integer.hasMutatable("sub"));
//         try std.testing.expect(Integer.hasMutatable("mul"));
//         try std.testing.expect(Integer.hasMutatable("div"));
//         try std.testing.expect(!Integer.hasMutatable("upper"));
//         try std.testing.expect(!Integer.hasMutatable("lower"));
//         try std.testing.expect(Integer.hasTransformable("string"));
//         try std.testing.expect(!Integer.hasTransformable("len"));
//         try std.testing.expect(Integer.hasTerminable("print"));
//     }
//     inline for ([_]Primitive.Tag{ .i8, .i16, .i32, .i64, .i128, .int, .u8, .u16, .u32, .u64, .u128, .uint }) |tag| {
//         var integer = try Implement(tag).init(allocator, 0);
//         defer integer.deinit(allocator);
//         try std.testing.expectEqual(0, integer.value);
//         integer.mutatable.add(10);
//         try std.testing.expectEqual(10, integer.value);
//         integer.mutatable.sub(5);
//         try std.testing.expectEqual(5, integer.value);
//         integer.mutatable.mul(4);
//         try std.testing.expectEqual(20, integer.value);
//         integer.mutatable.div(5);
//         try std.testing.expectEqual(4, integer.value);
//     }
//     inline for ([_]Primitive.Tag{ .i8, .i16, .i32, .i64, .i128, .int, .u8, .u16, .u32, .u64, .u128, .uint }) |tag| {
//         var integer = try Implement(tag).init(allocator, 10);
//         defer integer.deinit(allocator);
//         try std.testing.expectEqual(10, integer.value);
//         const string = try integer.transformable.string(allocator);
//         defer string.deinit(allocator);
//         try std.testing.expectEqualStrings("10", string.value);
//     }
// }

// test "float primitive" {
//     const allocator = std.testing.allocator;
//     inline for ([_]Primitive.Tag{ .f16, .f32, .f64, .f128 }) |tag| {
//         const Float = Implement(tag);
//         try std.testing.expect(Float.hasMutatable("add"));
//         try std.testing.expect(Float.hasMutatable("sub"));
//         try std.testing.expect(Float.hasMutatable("mul"));
//         try std.testing.expect(Float.hasMutatable("div"));
//         try std.testing.expect(!Float.hasMutatable("upper"));
//         try std.testing.expect(!Float.hasMutatable("lower"));
//         try std.testing.expect(Float.hasTransformable("string"));
//         try std.testing.expect(!Float.hasTransformable("len"));
//         try std.testing.expect(Float.hasTerminable("print"));
//     }
//     inline for ([_]Primitive.Tag{ .f16, .f32, .f64, .f128 }) |tag| {
//         var float = try Implement(tag).init(allocator, 0);
//         defer float.deinit(allocator);
//         try std.testing.expectEqual(0, float.value);
//         float.mutatable.add(10);
//         try std.testing.expectEqual(10, float.value);
//         float.mutatable.sub(5);
//         try std.testing.expectEqual(5, float.value);
//         float.mutatable.mul(4);
//         try std.testing.expectEqual(20, float.value);
//         float.mutatable.div(5);
//         try std.testing.expectEqual(4, float.value);
//     }
//     inline for ([_]Primitive.Tag{ .f16, .f32, .f64, .f128 }) |tag| {
//         var float = try Implement(tag).init(allocator, 10);
//         defer float.deinit(allocator);
//         try std.testing.expectEqual(10, float.value);
//         const string = try float.transformable.string(allocator);
//         defer string.deinit(allocator);
//         try std.testing.expectEqualStrings("10", string.value);
//     }
// }

// test "string primitive" {
//     const allocator = std.testing.allocator;
//     inline for ([_]Primitive.Tag{.string}) |tag| {
//         const String = Implement(tag);
//         try std.testing.expect(!String.hasMutatable("add"));
//         try std.testing.expect(!String.hasMutatable("sub"));
//         try std.testing.expect(!String.hasMutatable("mul"));
//         try std.testing.expect(!String.hasMutatable("div"));
//         try std.testing.expect(String.hasMutatable("upper"));
//         try std.testing.expect(String.hasMutatable("lower"));
//         try std.testing.expect(!String.hasTransformable("string"));
//         try std.testing.expect(String.hasTransformable("len"));
//         try std.testing.expect(String.hasTerminable("print"));
//     }
//     inline for ([_]Primitive.Tag{.string}) |tag| {
//         var input = "test".*;
//         var string = try Implement(tag).init(allocator, &input);
//         defer string.deinit(allocator);
//         try std.testing.expectEqualStrings("test", string.value);
//         string.mutatable.upper();
//         try std.testing.expectEqualStrings("TEST", string.value);
//         string.mutatable.lower();
//         try std.testing.expectEqualStrings("test", string.value);
//     }
//     inline for ([_]Primitive.Tag{.string}) |tag| {
//         var input = "test".*;
//         var string = try Implement(tag).init(allocator, &input);
//         defer string.deinit(allocator);
//         try std.testing.expectEqualStrings("test", string.value);
//         var integer = try string.transformable.len(allocator);
//         defer integer.deinit(allocator);
//         try std.testing.expectEqual(4, integer.value);
//     }
// }
