const std = @import("std");
const ascii = std.ascii;
const builtin = std.builtin;
const fmt = std.fmt;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const StaticStringMap = std.StaticStringMap;

pub const Error = error{
    CoreTagNotFound,
    MethodNotFound,
    MethodInvalid,
    InvalidIntLiteral,
    InvalidFloatLiteral,
    InvalidStringLiteral,
};

pub const Core = union(enum) {
    /// Integer (Signed)
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    i128: i128,
    int: isize,
    /// Integer (Unsigned)
    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    u128: u128,
    uint: usize,
    /// Float
    f16: f16,
    f32: f32,
    f64: f64,
    f128: f128,
    float: f64,
    /// String
    string: []const u8,

    pub const infos = blk: {
        const fields = meta.fields(Core);
        var pairs: [fields.len]struct { []const u8, type } = undefined;
        for (meta.fields(Core), 0..) |field, i| {
            pairs[i] = Info(field.type);
        }
        break :blk StaticStringMap(type).initComptime(pairs);
    };

    pub fn InfoFrom(string: []const u8) Error!type {
        inline for (meta.fields(Core)) |field| {
            if (mem.eql(u8, string, field.name)) {
                return Info(field.type);
            }
        }
        return Error.CoreTagNotFound;
    }

    pub const builds = blk: {
        const fields = meta.fields(Core);
        var pairs: [fields.len]struct { []const u8, type } = undefined;
        for (meta.fields(Core), 0..) |field, i| {
            pairs[i] = Build(field.type);
        }
        break :blk StaticStringMap(type).initComptime(pairs);
    };

    pub fn BuildFrom(string: []const u8) Error!type {
        inline for (meta.fields(Core)) |field| {
            if (mem.eql(u8, string, field.name)) {
                return Build(field.type);
            }
        }
        return Error.CoreTagNotFound;
    }
};

pub fn Info(comptime T: type) type {
    return struct {
        pub const CoreType = T;
        pub const BuildType = Build(T);

        pub const declarations = std.meta.declarations(BuildType);
        pub const excluded_declarations = StaticStringMap(void).initComptime(.{
            .{ "init", {} },
            .{ "create", {} },
            .{ "deinit", {} },
        });

        pub const methods = blk: {
            var size = 0;
            for (declarations) |declaration| {
                if (isValidMethod(declaration.name)) {
                    size += 1;
                }
            }
            var index = 0;
            var pairs: [size]struct { []const u8, void } = undefined;
            for (declarations) |declaration| {
                if (isValidMethod(declaration.name)) {
                    pairs[index] = .{ declaration.name, {} };
                    index += 1;
                }
            }
            break :blk StaticStringMap(void).initComptime(pairs);
        };

        fn isValidMethod(method_name: []const u8) bool {
            const Result = OutputBuild(method_name) orelse return false;
            return BuildType == Result;
        }

        pub const outputs = blk: {
            var size = 0;
            for (declarations) |declaration| {
                if (isValidOutput(declaration.name)) {
                    size += 1;
                }
            }
            var index = 0;
            var pairs: [size]struct { []const u8, void } = undefined;
            for (declarations) |declaration| {
                if (isValidOutput(declaration.name)) {
                    pairs[index] = .{ declaration.name, {} };
                    index += 1;
                }
            }
            break :blk StaticStringMap(void).initComptime(pairs);
        };

        fn isValidOutput(method_name: []const u8) bool {
            const Result = OutputBuild(method_name) orelse return false;
            return BuildType != Result;
        }

        pub fn OutputInfo(method_name: []const u8) ?type {
            const Result = OutputBuild(method_name) orelse return null;
            return Info(Result.Type);
        }

        pub fn OutputBuild(comptime method_name: []const u8) ?type {
            if (excluded_declarations.has(method_name)) return null;

            const fn_type = @TypeOf(@field(BuildType, method_name));
            const fn_info = @typeInfo(fn_type);
            if (fn_info != .Fn) return null;

            const return_type = fn_info.Fn.return_type orelse return null;
            const error_info = @typeInfo(return_type);
            if (error_info != .ErrorUnion) return null;

            const payload_info = @typeInfo(error_info.ErrorUnion.payload);
            if (payload_info != .Pointer) return null;

            const Type = payload_info.Pointer.child;
            if (!@hasDecl(Type, "Mark")) return null;
            if (@field(Type, "Mark") != BuildMarker) return null;
            return Type;
        }

        pub fn isValidLiteral(literal: []const u8) bool {
            switch (@typeInfo(T)) {
                .Int => if (fmt.parseInt(T, literal, 10)) |_| return true else |_| return false,
                .Float => if (fmt.parseFloat(T, literal)) |_| return true else |_| return false,
                .Pointer => |info| switch (info.size) {
                    .Slice => switch (info.child) {
                        u8 => return literal.len >= 2 and literal[0] == '"' and literal[literal.len == '"'],
                        else => @compileError("Unsupported slice type " ++ @typeName(info.child)),
                    },
                    else => |size| @compileError("Unsupported pointer size " ++ size),
                },
                else => @compileError("Unsupported primitive type " ++ @typeName(T)),
            }
        }
    };
}

test "Info" {
    inline for (meta.fields(Core)) |field| {
        switch (@typeInfo(field.type)) {
            .Int => {
                const TypeInfo = try Core.InfoFrom(field.name);
                // Method
                try testing.expect(!TypeInfo.methods.has("init"));
                try testing.expect(!TypeInfo.methods.has("create"));
                try testing.expect(!TypeInfo.methods.has("deinit"));
                try testing.expect(TypeInfo.methods.has("add"));
                try testing.expect(TypeInfo.methods.has("sub"));
                try testing.expect(TypeInfo.methods.has("mul"));
                try testing.expect(TypeInfo.methods.has("div"));
                try testing.expect(!TypeInfo.methods.has("string"));
                // Output
                try testing.expect(!TypeInfo.outputs.has("init"));
                try testing.expect(!TypeInfo.outputs.has("create"));
                try testing.expect(!TypeInfo.outputs.has("deinit"));
                try testing.expect(!TypeInfo.outputs.has("add"));
                try testing.expect(!TypeInfo.outputs.has("sub"));
                try testing.expect(!TypeInfo.outputs.has("mul"));
                try testing.expect(!TypeInfo.outputs.has("div"));
                try testing.expect(TypeInfo.outputs.has("string"));
                // Output Info
                try testing.expectEqual(Info([]const u8), TypeInfo.OutputInfo("string"));
                // Literal
                try testing.expect(TypeInfo.isValidLiteral("0"));
            },
            .Float => {
                const TypeInfo = try Core.InfoFrom(field.name);
                // Method
                try testing.expect(!TypeInfo.methods.has("init"));
                try testing.expect(!TypeInfo.methods.has("create"));
                try testing.expect(!TypeInfo.methods.has("deinit"));
                try testing.expect(TypeInfo.methods.has("add"));
                try testing.expect(TypeInfo.methods.has("sub"));
                try testing.expect(TypeInfo.methods.has("mul"));
                try testing.expect(TypeInfo.methods.has("div"));
                try testing.expect(!TypeInfo.methods.has("string"));
                // Output
                try testing.expect(!TypeInfo.outputs.has("init"));
                try testing.expect(!TypeInfo.outputs.has("create"));
                try testing.expect(!TypeInfo.outputs.has("deinit"));
                try testing.expect(!TypeInfo.outputs.has("add"));
                try testing.expect(!TypeInfo.outputs.has("sub"));
                try testing.expect(!TypeInfo.outputs.has("mul"));
                try testing.expect(!TypeInfo.outputs.has("div"));
                try testing.expect(TypeInfo.outputs.has("string"));
                // Output Info
                try testing.expectEqual(Info([]const u8), TypeInfo.OutputInfo("string"));
            },
            .Pointer => {
                const TypeInfo = try Core.InfoFrom(field.name);
                // Method
                try testing.expect(!TypeInfo.methods.has("init"));
                try testing.expect(!TypeInfo.methods.has("create"));
                try testing.expect(!TypeInfo.methods.has("deinit"));
                try testing.expect(TypeInfo.methods.has("upper"));
                try testing.expect(TypeInfo.methods.has("lower"));
                // Output
                try testing.expect(!TypeInfo.outputs.has("init"));
                try testing.expect(!TypeInfo.outputs.has("create"));
                try testing.expect(!TypeInfo.outputs.has("deinit"));
                try testing.expect(!TypeInfo.outputs.has("upper"));
                try testing.expect(!TypeInfo.outputs.has("lower"));
            },
            else => {
                @compileError("Unsupported Type: " ++ @typeName(field.type));
            },
        }
    }
}

const BuildMarker = struct {};

pub fn Build(T: type) type {
    switch (@typeInfo(T)) {
        .Int => return struct {
            const Self = @This();
            const Type = T;
            const Mark = BuildMarker;

            allocator: Allocator,
            value: T,

            pub fn init(allocator: Allocator, value: T) !*Self {
                const self = try allocator.create(Self);
                self.* = .{ .allocator = allocator, .value = value };
                return self;
            }

            pub fn create(self: *Self, value: T) !*Self {
                return init(self.allocator, value);
            }

            pub fn deinit(self: *Self) void {
                self.allocator.destroy(self);
            }

            pub fn add(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(self.value + value);
            }

            pub fn sub(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(self.value - value);
            }

            pub fn mul(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(self.value * value);
            }

            pub fn div(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(@divTrunc(self.value, value));
            }

            pub fn string(self: *Self) !*Build([]const u8) {
                defer self.deinit();
                const output = try fmt.allocPrint(self.allocator, "{d}", .{self.value});
                defer self.allocator.free(output);
                return try Build([]const u8).init(self.allocator, output);
            }

            pub fn print(self: *Self) void {
                std.debug.print("{any}", .{self.value});
            }
        },
        .Float => return struct {
            const Self = @This();
            const Type = T;
            const Mark = BuildMarker;

            allocator: Allocator,
            value: T,

            pub fn init(allocator: Allocator, value: T) !*Self {
                const self = try allocator.create(Self);
                self.* = .{ .allocator = allocator, .value = value };
                return self;
            }

            pub fn create(self: *Self, value: T) !*Self {
                return init(self.allocator, value);
            }

            pub fn deinit(self: *Self) void {
                self.allocator.destroy(self);
            }

            pub fn add(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(self.value + value);
            }

            pub fn sub(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(self.value - value);
            }

            pub fn mul(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(self.value * value);
            }

            pub fn div(self: *Self, value: T) !*Self {
                defer self.deinit();
                return try self.create(@divTrunc(self.value, value));
            }

            pub fn string(self: *Self) !*Build([]const u8) {
                defer self.deinit();
                const output = try fmt.allocPrint(self.allocator, "{d}", .{self.value});
                defer self.allocator.free(output);
                return try Build([]const u8).init(self.allocator, output);
            }

            pub fn print(self: *Self) void {
                std.debug.print("{any}", .{self.value});
            }
        },
        .Pointer => |info| switch (info.size) {
            .Slice => switch (info.child) {
                u8 => {
                    return struct {
                        const Self = @This();
                        const Type = T;
                        const Mark = BuildMarker;

                        allocator: Allocator,
                        value: T,

                        pub fn init(allocator: Allocator, value: T) !*Self {
                            const self = try allocator.create(Self);
                            errdefer allocator.destroy(self);
                            const clone = try allocator.dupe(u8, value);
                            self.* = .{ .allocator = allocator, .value = clone };
                            return self;
                        }

                        pub fn create(self: *Self, value: T) !*Self {
                            return init(self.allocator, value);
                        }

                        pub fn deinit(self: *Self) void {
                            self.allocator.free(self.value);
                            self.allocator.destroy(self);
                        }

                        pub fn upper(self: *Self) !*Self {
                            defer self.deinit();
                            var output = try self.allocator.alloc(u8, self.value.len);
                            defer self.allocator.free(output);
                            for (self.value, 0..) |c, i| output[i] = std.ascii.toUpper(c);
                            return try self.create(output);
                        }

                        pub fn lower(self: *Self) !*Self {
                            defer self.deinit();
                            var output = try self.allocator.alloc(u8, self.value.len);
                            defer self.allocator.free(output);
                            for (self.value, 0..) |c, i| output[i] = std.ascii.toLower(c);
                            return try self.create(output);
                        }

                        pub fn print(self: *Self) void {
                            std.debug.print("{s}", .{self.value});
                        }
                    };
                },
                else => @compileError("Unsupported slice type " ++ @typeName(info.child)),
            },
            else => |size| @compileError("Unsupported pointer size " ++ size),
        },
        else => @compileError("Unsupported primitive type " ++ @typeName(T)),
    }
}

// test "Info" {
//     inline for (meta.fields(Core)) |field| {
//         switch (@typeInfo(field.type)) {
//             .Int => {
//                 try testing.expect(hasMethod(field.name, "add"));
//                 // try testing.expect(!Info(field.type).hasMethod("create"));
//                 // try testing.expect(!Info(field.type).hasMethod("deinit"));
//                 // try testing.expect(Info(field.type).hasMethod("add"));
//                 // try testing.expect(Info(field.type).hasMethod("sub"));
//                 // try testing.expect(Info(field.type).hasMethod("mul"));
//                 // try testing.expect(Info(field.type).hasMethod("div"));
//                 // try testing.expect(Info(field.type).hasMethod("string"));
//             },
//             .Float => {
//                 // try testing.expect(!Info(field.type).hasMethod("init"));
//                 // try testing.expect(!Info(field.type).hasMethod("create"));
//                 // try testing.expect(!Info(field.type).hasMethod("deinit"));
//                 // try testing.expect(Info(field.type).hasMethod("add"));
//                 // try testing.expect(Info(field.type).hasMethod("sub"));
//                 // try testing.expect(Info(field.type).hasMethod("mul"));
//                 // try testing.expect(Info(field.type).hasMethod("div"));
//                 // try testing.expect(Info(field.type).hasMethod("string"));
//             },
//             .Pointer => {
//                 // try testing.expect(!Info(field.type).hasMethod("init"));
//                 // try testing.expect(!Info(field.type).hasMethod("create"));
//                 // try testing.expect(!Info(field.type).hasMethod("deinit"));
//                 // try testing.expect(Info(field.type).hasMethod("upper"));
//                 // try testing.expect(Info(field.type).hasMethod("lower"));
//             },
//             else => {
//                 unreachable;
//             },
//         }
//     }

// inline for (meta.fields(Core)) |field| {
//     switch (@typeInfo(field.type)) {
//         .Int => {
//             try testing.expectEqual(Build.Generate(field.type), Info(field.type).getResult("add"));
//             try testing.expectEqual(Build.Generate(field.type), Info(field.type).getResult("sub"));
//             try testing.expectEqual(Build.Generate(field.type), Info(field.type).getResult("mul"));
//             try testing.expectEqual(Build.Generate(field.type), Info(field.type).getResult("div"));
//             try testing.expectEqual(Build.Generate([]const u8), Info(field.type).getResult("string"));
//         },
//         .Float => {
//             // try testing.expect(!Info(field.type).hasMethod("init"));
//             // try testing.expect(!Info(field.type).hasMethod("create"));
//             // try testing.expect(!Info(field.type).hasMethod("deinit"));
//             // try testing.expect(Info(field.type).hasMethod("add"));
//             // try testing.expect(Info(field.type).hasMethod("sub"));
//             // try testing.expect(Info(field.type).hasMethod("mul"));
//             // try testing.expect(Info(field.type).hasMethod("div"));
//             // try testing.expect(Info(field.type).hasMethod("string"));
//         },
//         .Pointer => {
//             // try testing.expect(!Info(field.type).hasMethod("init"));
//             // try testing.expect(!Info(field.type).hasMethod("create"));
//             // try testing.expect(!Info(field.type).hasMethod("deinit"));
//             // try testing.expect(Info(field.type).hasMethod("upper"));
//             // try testing.expect(Info(field.type).hasMethod("lower"));
//         },
//         else => {
//             unreachable;
//         },
//     }
// }
// }

// test "Build" {
//     inline for (meta.fields(Core)) |field| {
//         switch (@typeInfo(field.type)) {
//             .Int => {
//                 const Int = try Build.Literal(field.name);

//                 var primitive = try Int.init(testing.allocator, 0);
//                 try testing.expectEqual(0, primitive.value);
//                 primitive = try primitive.add(20);
//                 try testing.expectEqual(20, primitive.value);
//                 primitive = try primitive.sub(10);
//                 try testing.expectEqual(10, primitive.value);
//                 primitive = try primitive.mul(5);
//                 try testing.expectEqual(50, primitive.value);
//                 primitive = try primitive.div(2);
//                 try testing.expectEqual(25, primitive.value);

//                 const to_string = try primitive.string();
//                 defer to_string.deinit();
//                 try testing.expectEqualStrings("25", to_string.value);
//             },
//             .Float => {
//                 const Float = try Build.Literal(field.name);

//                 var primitive = try Float.init(testing.allocator, 0);
//                 try testing.expectEqual(0, primitive.value);
//                 primitive = try primitive.add(20);
//                 try testing.expectEqual(20, primitive.value);
//                 primitive = try primitive.sub(10);
//                 try testing.expectEqual(10, primitive.value);
//                 primitive = try primitive.mul(5);
//                 try testing.expectEqual(50, primitive.value);
//                 primitive = try primitive.div(2);
//                 try testing.expectEqual(25, primitive.value);

//                 const to_string = try primitive.string();
//                 defer to_string.deinit();
//                 try testing.expectEqualStrings("25", to_string.value);
//             },
//             .Pointer => {
//                 const String = try Build.Literal(field.name);

//                 var primitive = try String.init(testing.allocator, "test");
//                 try testing.expectEqualStrings("test", primitive.value);
//                 primitive = try primitive.upper();
//                 try testing.expectEqualStrings("TEST", primitive.value);
//                 primitive = try primitive.lower();
//                 try testing.expectEqualStrings("test", primitive.value);
//                 primitive.deinit();
//             },
//             else => {
//                 @compileError("Invalid type " ++ @typeName(field.type));
//             },
//         }
//     }
// }

// Transformations
// inline for (meta.fields(Core)) |field| {
//     switch (@typeInfo(field.type)) {
//         .Int => {
//             try testing.expect(!Info.hasTransformation(field.name, "init"));
//             try testing.expect(!Info.hasTransformation(field.name, "create"));
//             try testing.expect(!Info.hasTransformation(field.name, "deinit"));
//             try testing.expect(!Info.hasTransformation(field.name, "add"));
//             try testing.expect(!Info.hasTransformation(field.name, "sub"));
//             try testing.expect(!Info.hasTransformation(field.name, "mul"));
//             try testing.expect(!Info.hasTransformation(field.name, "div"));
//             try testing.expect(Info.hasTransformation(field.name, "string"));
//         },
//         .Float => {
//             try testing.expect(!Info.hasTransformation(field.name, "init"));
//             try testing.expect(!Info.hasTransformation(field.name, "create"));
//             try testing.expect(!Info.hasTransformation(field.name, "deinit"));
//             try testing.expect(!Info.hasTransformation(field.name, "add"));
//             try testing.expect(!Info.hasTransformation(field.name, "sub"));
//             try testing.expect(!Info.hasTransformation(field.name, "mul"));
//             try testing.expect(!Info.hasTransformation(field.name, "div"));
//             try testing.expect(Info.hasTransformation(field.name, "string"));
//         },
//         .Pointer => {
//             try testing.expect(!Info.hasTransformation(field.name, "init"));
//             try testing.expect(!Info.hasTransformation(field.name, "create"));
//             try testing.expect(!Info.hasTransformation(field.name, "deinit"));
//             try testing.expect(!Info.hasTransformation(field.name, "upper"));
//             try testing.expect(!Info.hasTransformation(field.name, "lower"));
//         },
//         else => {
//             unreachable;
//         },
//     }
// }

// pub const Tag = enum {
//     /// Integer (Signed)
//     i8,
//     i16,
//     i32,
//     i64,
//     i128,
//     int,
//     /// Integer (Unsigned)
//     u8,
//     u16,
//     u32,
//     u64,
//     u128,
//     uint,
//     /// Float
//     f16,
//     f32,
//     f64,
//     f128,
//     float,
//     /// String
//     string,
// };
