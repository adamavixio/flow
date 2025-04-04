const std = @import("std");
const fmt = std.fmt;
const heap = std.heap;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

pub const Error = error{
    ExpectedIdentifierType,
};

pub const Value = union(enum) {
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

    pub fn init(_: mem.Allocator, identifier: []const u8, literal: []const u8) !Value {
        inline for (meta.fields(Value)) |field| {
            if (mem.eql(u8, identifier, field.name)) {
                return switch (field.type) {
                    i8 => .{ .i8 = try fmt.parseInt(field.type, literal, 10) },
                    i16 => .{ .i16 = try fmt.parseInt(field.type, literal, 10) },
                    i32 => .{ .i32 = try fmt.parseInt(field.type, literal, 10) },
                    i64 => .{ .i64 = try fmt.parseInt(field.type, literal, 10) },
                    i128 => .{ .i128 = try fmt.parseInt(field.type, literal, 10) },
                    isize => .{ .int = try fmt.parseInt(field.type, literal, 10) },
                    u8 => .{ .u8 = try fmt.parseInt(field.type, literal, 10) },
                    u16 => .{ .u16 = try fmt.parseInt(field.type, literal, 10) },
                    u32 => .{ .u32 = try fmt.parseInt(field.type, literal, 10) },
                    u64 => .{ .u64 = try fmt.parseInt(field.type, literal, 10) },
                    u128 => .{ .u128 = try fmt.parseInt(field.type, literal, 10) },
                    usize => .{ .uint = try fmt.parseInt(field.type, literal, 10) },
                    f16 => .{ .f16 = try fmt.parseFloat(field.type, literal) },
                    f32 => .{ .f32 = try fmt.parseFloat(field.type, literal) },
                    f64 => switch (mem.eql(u8, identifier, "f64")) {
                        true => .{ .f64 = try fmt.parseFloat(field.type, literal) },
                        false => .{ .float = try fmt.parseFloat(field.type, literal) },
                    },
                    f128 => .{ .f128 = try fmt.parseFloat(field.type, literal) },
                    else => unreachable,
                };
            }
        }
        return Error.ExpectedIdentifierType;
    }
};

test Value {
    var arena = heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const size = meta.fields(Value).len;
    const cases = [size]struct { identifier: []const u8, literal: []const u8, expected: Value }{
        .{ .identifier = "i8", .literal = "0", .expected = .{ .i8 = 0 } },
        .{ .identifier = "i16", .literal = "0", .expected = .{ .i16 = 0 } },
        .{ .identifier = "i32", .literal = "0", .expected = .{ .i32 = 0 } },
        .{ .identifier = "i64", .literal = "0", .expected = .{ .i64 = 0 } },
        .{ .identifier = "i128", .literal = "0", .expected = .{ .i128 = 0 } },
        .{ .identifier = "int", .literal = "0", .expected = .{ .int = 0 } },
        .{ .identifier = "u8", .literal = "0", .expected = .{ .u8 = 0 } },
        .{ .identifier = "u16", .literal = "0", .expected = .{ .u16 = 0 } },
        .{ .identifier = "u32", .literal = "0", .expected = .{ .u32 = 0 } },
        .{ .identifier = "u64", .literal = "0", .expected = .{ .u64 = 0 } },
        .{ .identifier = "u128", .literal = "0", .expected = .{ .u128 = 0 } },
        .{ .identifier = "uint", .literal = "0", .expected = .{ .uint = 0 } },
        .{ .identifier = "f16", .literal = "0", .expected = .{ .f16 = 0 } },
        .{ .identifier = "f32", .literal = "0", .expected = .{ .f32 = 0 } },
        .{ .identifier = "f64", .literal = "0", .expected = .{ .f64 = 0 } },
        .{ .identifier = "f128", .literal = "0", .expected = .{ .f128 = 0 } },
        .{ .identifier = "float", .literal = "0", .expected = .{ .float = 0 } },
    };

    for (cases) |case| {
        const actual = try Value.init(arena.allocator(), case.identifier, case.literal);
        switch (actual) {
            else => try testing.expectEqual(case.expected, actual),
        }
    }
}

// pub const Error = error{
//     TypeNameNotFound,
//     CoreTagNotFound,
//     MethodNotFound,
//     MethodInvalid,
//     InvalidIntLiteral,
//     InvalidFloatLiteral,
//     InvalidStringLiteral,
// };

// pub const Core = union(enum) {
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

//     pub const types = blk: {
//         const fields = meta.fields(Core);
//         var pairs: [fields.len]struct { []const u8, type } = undefined;
//         for (fields, 0..) |field, i| {
//             pairs[i] = .{ field.name, field.type };
//         }
//         break :blk std.StaticStringMap(type).initComptime(pairs);
//     };

//     pub const infos = blk: {
//         const fields = meta.fields(Core);
//         var pairs: [fields.len]struct { []const u8, Info } = undefined;
//         for (fields, 0..) |field, i| {
//             pairs[i] = .{ field.name, Info.init(field.type) };
//         }
//         break :blk std.StaticStringMap(Info).initComptime(pairs);
//     };

//     pub const builds = blk: {
//         const fields = meta.fields(Core);
//         var pairs: [fields.len]struct { []const u8, type } = undefined;
//         for (meta.fields(Core), 0..) |field, i| {
//             pairs[i] = Build(field.type);
//         }
//         break :blk std.StaticStringMap(type).initComptime(pairs);
//     };
// };

// pub const Info = struct {
//     CoreType: type,
//     BuildType: type,
//     methods: std.StaticStringMap(void),
//     outputs: std.StaticStringMap(void),

//     pub fn init(comptime T: type) Info {
//         const B = Build(T);
//         const declarations = meta.declarations();

//         const methods = blk: {
//             var size = 0;
//             for (declarations) |decl| {
//                 if (isValidMethod(B, decl.name)) size += 1;
//             }
//             var pairs: [size]struct { []const u8, void } = undefined;
//             var i = 0;
//             for (declarations) |decl| {
//                 if (isValidMethod(B, decl.name)) {
//                     pairs[i] = .{ decl.name, {} };
//                     i += 1;
//                 }
//             }
//             break :blk std.StaticStringMap(void).initComptime(pairs);
//         };

//         const outputs = blk: {
//             var size = 0;
//             for (declarations) |decl| {
//                 if (isValidOutput(B, decl.name)) size += 1;
//             }
//             var pairs: [size]struct { []const u8, void } = undefined;
//             var i = 0;
//             for (declarations) |decl| {
//                 if (isValidOutput(B, decl.name)) {
//                     pairs[i] = .{ decl.name, {} };
//                     i += 1;
//                 }
//             }
//             break :blk std.StaticStringMap(void).initComptime(pairs);
//         };

//         return .{
//             .CoreType = T,
//             .BuildType = B,
//             .methods = methods,
//             .outputs = outputs,
//         };
//     }

//     pub fn OutputInfo(self: Info, method_name: []const u8) ?Info {
//         return if (self.OutputType(method_name)) |T| Info.init(T) else null;
//     }

//     pub fn isValidLiteral(self: Info, literal: []const u8) Error!void {
//         switch (@typeInfo(self.CoreType)) {
//             .Int => _ = fmt.parseInt(self.CoreType, literal, 10) catch {
//                 return Error.InvalidIntLiteral;
//             },
//             .Float => _ = fmt.parseFloat(self.CoreType, literal) catch {
//                 return Error.InvalidFloatLiteral;
//             },
//             .Pointer => |info| switch (info.size) {
//                 .Slice => switch (info.child) {
//                     u8 => if (literal.len < 2 or literal[0] != '"' or literal[literal.len - 1] != '"') {
//                         return Error.InvalidStringLiteral;
//                     },
//                     else => @compileError("Unsupported slice type " ++ @typeName(info.child)),
//                 },
//                 else => |size| @compileError("Unsupported pointer size " ++ size),
//             },
//             else => @compileError("Unsupported primitive type " ++ @typeName(self.CoreType)),
//         }
//     }

//     fn isValidMethod(comptime BuildType: type, comptime method_name: []const u8) bool {
//         const Result = OutputBuild(BuildType, method_name) orelse return false;
//         return BuildType == Result;
//     }

//     fn isValidOutput(comptime BuildType: type, comptime method_name: []const u8) bool {
//         const Result = OutputBuild(BuildType, method_name) orelse return false;
//         return BuildType != Result;
//     }

//     fn OutputBuild(comptime BuildType: type, comptime method_name: []const u8) ?type {
//         if (mem.eql(u8, method_name, "init")) return null;
//         if (mem.eql(u8, method_name, "create")) return null;
//         if (mem.eql(u8, method_name, "deinit")) return null;

//         const fn_type = @TypeOf(@field(BuildType, method_name));
//         const fn_info = @typeInfo(fn_type);
//         if (fn_info != .Fn) return null;

//         const return_type = fn_info.Fn.return_type orelse return null;
//         const return_info = @typeInfo(return_type);
//         if (return_info != .ErrorUnion) return null;

//         const payload_info = @typeInfo(return_info.ErrorUnion.payload);
//         if (payload_info != .Pointer) return null;

//         const Type = payload_info.Pointer.child;
//         if (!@hasDecl(Type, "Mark") or @field(Type, "Mark") != BuildMarker) return null;

//         return Type;
//     }

//     fn OutputType(self: Info, method_name: []const u8) ?type {
//         if (!self.outputs.has(method_name)) return null;
//         if (OutputBuild(self.BuildType, method_name)) |build_type| {
//             inline for (meta.fields(Core)) |field| {
//                 if (Build(field.type) == build_type) {
//                     return field.type;
//                 }
//             }
//         }
//         return null;
//     }
// };

// test "Info" {
//     inline for (meta.fields(Core)) |field| {
//         switch (@typeInfo(field.type)) {
//             .Int => {
//                 const TypeInfo = try Core.InfoFrom(field.name);
//                 // Method
//                 try testing.expect(!TypeInfo.methods.has("init"));
//                 try testing.expect(!TypeInfo.methods.has("create"));
//                 try testing.expect(!TypeInfo.methods.has("deinit"));
//                 try testing.expect(TypeInfo.methods.has("add"));
//                 try testing.expect(TypeInfo.methods.has("sub"));
//                 try testing.expect(TypeInfo.methods.has("mul"));
//                 try testing.expect(TypeInfo.methods.has("div"));
//                 try testing.expect(!TypeInfo.methods.has("string"));
//                 // Output
//                 try testing.expect(!TypeInfo.outputs.has("init"));
//                 try testing.expect(!TypeInfo.outputs.has("create"));
//                 try testing.expect(!TypeInfo.outputs.has("deinit"));
//                 try testing.expect(!TypeInfo.outputs.has("add"));
//                 try testing.expect(!TypeInfo.outputs.has("sub"));
//                 try testing.expect(!TypeInfo.outputs.has("mul"));
//                 try testing.expect(!TypeInfo.outputs.has("div"));
//                 try testing.expect(TypeInfo.outputs.has("string"));
//                 // Output Info
//                 try testing.expectEqual(Info([]const u8), TypeInfo.OutputInfo("string"));
//                 // Literal
//                 try TypeInfo.isValidLiteral("0");
//             },
//             .Float => {
//                 const TypeInfo = try Core.InfoFrom(field.name);
//                 // Method
//                 try testing.expect(!TypeInfo.methods.has("init"));
//                 try testing.expect(!TypeInfo.methods.has("create"));
//                 try testing.expect(!TypeInfo.methods.has("deinit"));
//                 try testing.expect(TypeInfo.methods.has("add"));
//                 try testing.expect(TypeInfo.methods.has("sub"));
//                 try testing.expect(TypeInfo.methods.has("mul"));
//                 try testing.expect(TypeInfo.methods.has("div"));
//                 try testing.expect(!TypeInfo.methods.has("string"));
//                 // Output
//                 try testing.expect(!TypeInfo.outputs.has("init"));
//                 try testing.expect(!TypeInfo.outputs.has("create"));
//                 try testing.expect(!TypeInfo.outputs.has("deinit"));
//                 try testing.expect(!TypeInfo.outputs.has("add"));
//                 try testing.expect(!TypeInfo.outputs.has("sub"));
//                 try testing.expect(!TypeInfo.outputs.has("mul"));
//                 try testing.expect(!TypeInfo.outputs.has("div"));
//                 try testing.expect(TypeInfo.outputs.has("string"));
//                 // Output Info
//                 try testing.expectEqual(Info([]const u8), TypeInfo.OutputInfo("string"));
//             },
//             .Pointer => {
//                 const TypeInfo = try Core.InfoFrom(field.name);
//                 // Method
//                 try testing.expect(!TypeInfo.methods.has("init"));
//                 try testing.expect(!TypeInfo.methods.has("create"));
//                 try testing.expect(!TypeInfo.methods.has("deinit"));
//                 try testing.expect(TypeInfo.methods.has("upper"));
//                 try testing.expect(TypeInfo.methods.has("lower"));
//                 // Output
//                 try testing.expect(!TypeInfo.outputs.has("init"));
//                 try testing.expect(!TypeInfo.outputs.has("create"));
//                 try testing.expect(!TypeInfo.outputs.has("deinit"));
//                 try testing.expect(!TypeInfo.outputs.has("upper"));
//                 try testing.expect(!TypeInfo.outputs.has("lower"));
//             },
//             else => {
//                 @compileError("Unsupported Type: " ++ @typeName(field.type));
//             },
//         }
//     }
// }

// pub fn Build(T: type) type {
//     switch (@typeInfo(T)) {
//         .Int => Int(T),
//         .Float => Float(T),
//         .Pointer => |info| switch (info.size) {
//             .Slice => switch (info.child) {
//                 u8 => String(T),
//                 else => @compileError("unsupported slie type " ++ @typeName(info.child)),
//             },
//             else => |size| @compileError("unsupported pointer size " ++ size),
//         },
//         else => @compileError("unsupported primitive type " ++ @typeName(T)),
//     }
// }

// pub fn Int(comptime Value: type) type {
//     return struct {
//         const Self = @This();
//         value: Value,
//         mutations: IntMutations(Self, Value) = .{},
//         pub fn init(allocator: mem.Allocator, value: Value) !*Self {
//             const self = try allocator.create(Self);
//             self.value = value;
//             return self;
//         }
//         pub fn deinit(self: *Self, allocator: mem.Allocator) void {
//             allocator.destroy(self);
//             self = void;
//         }
//     };
// }

// pub fn IntMutations(comptime Container: type, comptime Value: type) type {
//     return struct {
//         const Self = @This();
//         container: *Container = @alignCast(@fieldParentPtr("mutations", @This())),
//         pub fn add(self: *Self, value: Value) void {
//             self.container.value += value;
//         }
//         pub fn sub(self: *Self, value: Value) void {
//             self.container.value -= value;
//         }
//         pub fn mul(self: *Self, value: Value) void {
//             self.container.value *= value;
//         }
//         pub fn div(self: *Self, value: Value) void {
//             self.container.value = @divTrunc(self.contaienr.value, value);
//         }
//         pub const methods = blk: {
//             const declarations = meta.declarations(Self);
//             var pairs: [declarations.len]struct { []const u8, void } = undefined;
//             for (declarations, 0..) |declaration, i| pairs[i] = .{ declaration.name, void };
//             break :blk std.StaticStringMap(Self).initComptime(pairs);
//         };
//         pub fn exists(name: []const u8) bool {
//             return methods.has(name);
//         }
//     };
// }

// pub fn IntOutputs(comptime Container: type, comptime Value: type) type {
//     return struct {
//         const Self = @This();
//         container: *Container = @alignCast(@fieldParentPtr("mutations", @This())),
//         pub fn string(self: *Self, allocator: mem.Allocator, value: Value) void {}
//         pub fn sub(self: *Self, value: Value) void {
//             self.container.value -= value;
//         }
//         pub fn mul(self: *Self, value: Value) void {
//             self.container.value *= value;
//         }
//         pub fn div(self: *Self, value: Value) void {
//             self.container.value = @divTrunc(self.contaienr.value, value);
//         }
//         const methods = blk: {
//             const declarations = meta.declarations(Self);
//             var pairs: [declarations.len]struct { []const u8, void } = undefined;
//             for (declarations, 0..) |declaration, i| pairs[i] = .{ declaration.name, void };
//             break :blk std.StaticStringMap(Self).initComptime(pairs);
//         };
//         pub fn exists(name: []const u8) bool {
//             return methods.has(name);
//         }
//     };
// }

// pub fn Float(comptime Value: type) type {
//     return struct {
//         const Self = @This();
//         value: Value,
//         mutations: FloatMutations(Self, Value) = .{},
//         pub fn init(allocator: mem.Allocator, value: Value) !*Self {
//             const self = try allocator.create(Self);
//             self.value = value;
//             return self;
//         }
//         pub fn deinit(self: *Self, allocator: mem.Allocator) void {
//             allocator.destroy(self);
//             self = void;
//         }
//     };
// }

// pub fn FloatMutations(comptime Container: type, comptime Value: type) type {
//     return struct {
//         const Self = @This();
//         const methods = blk: {
//             const declarations = meta.declarations(Self);
//             var pairs: [declarations.len]struct { []const u8, void } = undefined;
//             for (declarations, 0..) |declaration, i| pairs[i] = .{ declaration.name, void };
//             break :blk std.StaticStringMap(Self).initComptime(pairs);
//         };
//         container: *Container = @alignCast(@fieldParentPtr("mutations", @This())),
//         pub fn add(self: *Self, value: Value) void {
//             self.container.value += value;
//         }
//         pub fn sub(self: *Self, value: Value) void {
//             self.container.value -= value;
//         }
//         pub fn mul(self: *Self, value: Value) void {
//             self.container.value *= value;
//         }
//         pub fn div(self: *Self, value: Value) void {
//             self.container.value = @divTrunc(self.contaienr.value, value);
//         }
//         pub fn exists(name: []const u8) bool {
//             return methods.has(name);
//         }
//     };
// }

// pub fn String(comptime Value: type) type {
//     return struct {
//         const Self = @This();
//         value: Value,
//         mutations: IntMutations(Self, Value) = .{},
//         pub fn init(allocator: mem.Allocator, value: Value) !*Self {
//             const self = try allocator.create(Self);
//             errdefer allocator.destroy(self);
//             const clone = try allocator.dupe(u8, value);
//             self.* = .{ .value = clone };
//             return self;
//         }
//         pub fn deinit(self: *Self) void {
//             self.allocator.free(self.value);
//             self.allocator.destroy(self);
//         }
//     };
// }

// pub fn StringMutations(comptime Container: type) type {
//     return struct {
//         const Self = @This();
//         const methods = blk: {
//             const declarations = meta.declarations(Self);
//             var pairs: [declarations.len]struct { []const u8, void } = undefined;
//             for (declarations, 0..) |declaration, i| pairs[i] = .{ declaration.name, void };
//             break :blk std.StaticStringMap(Self).initComptime(pairs);
//         };
//         container: *Container = @alignCast(@fieldParentPtr("mutations", @This())),
//         pub fn upper(self: *Self) !void {
//             for (self.value) |*c| c.* = ascii.toUpper(c);
//         }
//         pub fn lower(self: *Self) !void {
//             for (self.value) |*c| c.* = ascii.toLower(c);
//         }
//         pub fn exists(name: []const u8) bool {
//             return methods.has(name);
//         }
//     };
// }

// pub fn IntOutputs(comptime Container: type, comptime Value: type) type {
//     return struct {
//         const Self = @This();
//         container: *Container = @alignCast(@fieldParentPtr("outputs", @This())),
//         pub fn string(self: *Self) !*Build([]const u8) {
//             defer self.deinit();
//             const output = try fmt.allocPrint(self.allocator, "{d}", .{self.value});
//             defer self.allocator.free(output);
//             return try Build([]const u8).init(self.allocator, output);
//         }

//         pub fn print(self: *Self) void {
//             std.debug.print("{any}", .{self.value});
//         }
//     };
// }

// pub fn Mutatable(comptime Pointer: type, comptime Value: type) type {
//     switch (@typeInfo(Value)) {
//         .Int => return struct {
//             const Self = @This();
//             pointer: *Pointer,
//             pub fn init() Self {
//                 return .{ .pointer = @alignCast(@fieldParentPtr("mutation", @This())) };
//             }
//             pub fn add(self: *Self, value: Value) Value {
//                 return self.pointer.value + value;
//             }
//             pub fn sub(self: *Self, value: Value) Value {
//                 return self.pointer.value - value;
//             }
//             pub fn mul(self: *Self, value: Value) Value {
//                 return self.pointer.value * value;
//             }
//             pub fn div(self: *Self, value: Value) Value {
//                 return @divTrunc(self.pointer.value, value);
//             }
//         },
//         .Float => return struct {
//             const Self = @This();
//             pointer: *Pointer,
//             pub fn init() Self {
//                 return .{ .pointer = @alignCast(@fieldParentPtr("mutation", @This())) };
//             }
//             pub fn add(self: *Self, value: Value) Value {
//                 return self.pointer.value + value;
//             }
//             pub fn sub(self: *Self, value: Value) Value {
//                 return self.pointer.value - value;
//             }
//             pub fn mul(self: *Self, value: Value) Value {
//                 return self.pointer.value * value;
//             }
//             pub fn div(self: *Self, value: Value) Value {
//                 return @divTrunc(self.pointer.value, value);
//             }
//         },
//         .Pointer => |info| switch (info.size) {
//             .Slice => switch (info.child) {
//                 u8 => switch (info.is_const) {
//                     false => return struct {
//                         const Self = @This();
//                         pub fn upper(self: *Self) void {
//                             const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
//                             for (pointer.value) |*c| {
//                                 c.* = std.ascii.toUpper(c.*);
//                             }
//                         }
//                         pub fn lower(self: *Self) void {
//                             const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
//                             for (pointer.value) |*c| {
//                                 c.* = std.ascii.toLower(c.*);
//                             }
//                         }
//                     },
//                     else => @compileError("unsupported slice is const"),
//                 },
//                 else => @compileError("unsupported slice type: " ++ @typeName(info.child)),
//             },
//             else => @compileError("unsupported pointer size: " ++ @typeName(info.size)),
//         },
//         else => @compileError("unsupported value type: " ++ @typeInfo(Value)),
//     }
// }

// pub fn Transformable(comptime Pointer: type, comptime Value: type) type {
//     switch (@typeInfo(Value)) {
//         .Int => return struct {
//             const Self = @This();
//             pub fn string(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
//                 const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
//                 const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
//                 defer allocator.free(transform);
//                 return try core.FlowType.FromTag(.string).init(allocator, transform);
//             }
//         },
//         .Float => return struct {
//             const Self = @This();
//             pub fn string(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
//                 const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
//                 const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
//                 defer allocator.free(transform);
//                 return try core.FlowType.FromTag(.string).init(allocator, transform);
//             }
//         },
//         .Pointer => |info| switch (info.size) {
//             .Slice => switch (info.child) {
//                 u8 => switch (info.is_const) {
//                     true => return struct {
//                         const Self = @This();
//                         pub fn upper(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
//                             const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
//                             var transform = try allocator.alloc(u8, pointer.value.len);
//                             defer allocator.free(transform);
//                             for (pointer.value, 0..) |c, i| {
//                                 transform[i] = std.ascii.toUpper(c);
//                             }
//                             return core.FlowType.FromTag(.string).init(allocator, transform);
//                         }
//                         pub fn lower(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
//                             const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
//                             var transform = try allocator.alloc(u8, pointer.value.len);
//                             defer allocator.free(transform);
//                             for (pointer.value, 0..) |c, i| {
//                                 transform[i] = std.ascii.toLower(c);
//                             }
//                             return core.FlowType.FromTag(.string).init(allocator, transform);
//                         }
//                     },
//                     false => return struct {},
//                 },
//                 else => @compileError("unsupported slice type: " ++ @typeName(info.child)),
//             },
//             else => @compileError("unsupported pointer size: " ++ @typeName(info.size)),
//         },
//         else => @compileError("unsupported value type: " ++ @typeInfo(Value)),
//     }
// }

// pub fn Terminable(comptime Pointer: type, comptime Value: type) type {
//     switch (@typeInfo(Value)) {
//         .Int => return struct {
//             const Self = @This();
//             pub fn print(self: *Self) !void {
//                 const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
//                 std.debug.print(pointer.value);
//             }
//         },
//         .Float => return struct {
//             const Self = @This();
//             pub fn print(self: *Self) !void {
//                 const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
//                 std.debug.print(pointer.value);
//             }
//         },
//         .Pointer => |info| switch (info.size) {
//             .Slice => switch (info.child) {
//                 u8 => switch (info.is_const) {
//                     true => return struct {
//                         const Self = @This();
//                         pub fn print(self: *Self) !void {
//                             const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
//                             std.debug.print(pointer.value);
//                         }
//                     },
//                     false => return struct {
//                         const Self = @This();
//                         pub fn print(self: *Self) !void {
//                             const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
//                             std.debug.print(pointer.value);
//                         }
//                     },
//                 },
//                 else => @compileError("unsupported slice type: " ++ @typeName(info.child)),
//             },
//             else => @compileError("unsupported pointer size: " ++ @typeName(info.size)),
//         },
//         else => @compileError("unsupported value type: " ++ @typeInfo(Value)),
//     }
// }

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
