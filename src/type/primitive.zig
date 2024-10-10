const std = @import("std");

pub const Tag = union(enum) {
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
    float: f32,

    string: []u8,

    pub fn Type(string: []const u8) type {
        return std.meta.FieldType(Tag, @field(Tag, string));
    }
};

pub fn Type(comptime Value: type) type {
    return struct {
        const Self = @This();

        value: Value,
        allocatable: Allocatable(Self, Value) = .{},
        mutatable: Mutatable(Self, Value) = .{},
        transformable: Transformable(Self, Value) = .{},
        terminable: Terminable(Self, Value) = .{},

        pub fn init(allocator: std.mem.Allocator, value: Value) !*Self {
            return Allocatable(Self, Value).init(allocator, value);
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.allocatable.deinit(allocator);
        }
    };
}

pub fn Allocatable(comptime T: type, comptime Value: type) type {
    return switch (@typeInfo(Value)) {
        .Int => struct {
            const Self = @This();
            pub fn init(allocator: std.mem.Allocator, value: Value) !*T {
                const self = try allocator.create(T);
                self.*.value = value;
                return self;
            }
            pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
                const pointer: *T = @alignCast(@fieldParentPtr("allocatable", self));
                allocator.destroy(pointer);
            }
        },
        .Float => struct {
            const Self = @This();
            pub fn init(allocator: std.mem.Allocator, value: Value) !*T {
                const self = try allocator.create(T);
                self.*.value = value;
                return self;
            }
            pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
                const pointer: *T = @alignCast(@fieldParentPtr("allocatable", self));
                allocator.destroy(pointer);
            }
        },
        .Pointer => |ptr_info| switch (ptr_info.child) {
            u8 => struct {
                const Self = @This();
                pub fn init(allocator: std.mem.Allocator, value: Value) !*T {
                    const self = try allocator.create(T);
                    self.*.value = try allocator.dupe(u8, value);
                    return self;
                }
                pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
                    const pointer: *T = @alignCast(@fieldParentPtr("allocatable", self));
                    allocator.free(pointer.value);
                    allocator.destroy(pointer);
                }
            },
            else => @compileError("Unsupported pointer type"),
        },
        else => @compileError("Unsupported type"),
    };
}

pub fn Mutatable(comptime T: type, comptime Value: type) type {
    return switch (@typeInfo(Value)) {
        .Int, .Float => struct {
            const Self = @This();
            pub fn add(self: *Self, value: Value) void {
                const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
                pointer.value += value;
            }
            pub fn sub(self: *Self, value: Value) void {
                const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
                pointer.value -= value;
            }
            pub fn mul(self: *Self, value: Value) void {
                const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
                pointer.value *= value;
            }
            pub fn div(self: *Self, value: Value) void {
                const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
                pointer.value = @divTrunc(pointer.value, value);
            }
        },
        .Pointer => |info| switch (info.child) {
            u8 => struct {
                const Self = @This();
                pub fn upper(self: *Self) void {
                    const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
                    for (pointer.value) |*c| {
                        c.* = std.ascii.toUpper(c.*);
                    }
                }
                pub fn lower(self: *Self) void {
                    const pointer: *T = @alignCast(@fieldParentPtr("mutatable", self));
                    for (pointer.value) |*c| {
                        c.* = std.ascii.toLower(c.*);
                    }
                }
            },
            else => @compileError("Unsupported pointer type"),
        },
        else => @compileError("Unsupported type"),
    };
}

pub fn Transformable(comptime T: type, comptime Value: type) type {
    return switch (@typeInfo(Value)) {
        .Int, .Float => struct {
            const Self = @This();
            pub fn string(self: *Self, allocator: std.mem.Allocator) !*Type([]u8) {
                const pointer: *T = @alignCast(@fieldParentPtr("transformable", self));
                const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
                defer allocator.free(transform);
                const value = try Type([]u8).init(allocator, transform);
                return value;
            }
        },
        .Pointer => |info| switch (info.child) {
            u8 => struct {
                const Self = @This();
                pub fn len(self: *Self, allocator: std.mem.Allocator) !*Type(usize) {
                    const pointer: *T = @alignCast(@fieldParentPtr("transformable", self));
                    const value = try Type(usize).init(allocator, pointer.value.len);
                    return value;
                }
            },
            else => @compileError("Unsupported pointer type"),
        },
        else => @compileError("Unsupported type"),
    };
}

pub fn Terminable(comptime T: type, comptime Value: type) type {
    return switch (@typeInfo(Value)) {
        .Int, .Float => struct {
            const Self = @This();
            pub fn print(self: *Self) void {
                const pointer: *T = @alignCast(@fieldParentPtr("terminable", self));
                std.debug.print("{d}\n", .{pointer.value});
            }
        },
        .Pointer => |info| switch (info.child) {
            u8 => struct {
                const Self = @This();
                pub fn print(self: *Self) !*Type(usize) {
                    const pointer: *T = @alignCast(@fieldParentPtr("terminable", self));
                    std.debug.print("{s}\n", .{pointer.value});
                }
            },
            else => @compileError("Unsupported pointer type"),
        },
        else => @compileError("Unsupported type"),
    };
}

test "integer tags" {
    inline for ([_]struct { type, []const u8 }{
        .{ i8, "i8" },
        .{ i16, "i16" },
        .{ i32, "i32" },
        .{ i64, "i64" },
        .{ i128, "i128" },
        .{ isize, "int" },
        .{ u8, "u8" },
        .{ u16, "u16" },
        .{ u32, "u32" },
        .{ u64, "u64" },
        .{ u128, "u128" },
        .{ usize, "uint" },
    }) |case| {
        try std.testing.expectEqual(case[0], Tag.Type(case[1]));
    }
}

test "float tags" {
    inline for ([_]struct { type, []const u8 }{
        .{ f16, "f16" },
        .{ f32, "f32" },
        .{ f64, "f64" },
        .{ f128, "f128" },
        .{ f32, "float" },
    }) |case| {
        try std.testing.expectEqual(case[0], Tag.Type(case[1]));
    }
}

test "string tags" {
    inline for ([_]struct { type, []const u8 }{
        .{ []u8, "string" },
    }) |case| {
        try std.testing.expectEqual(case[0], Tag.Type(case[1]));
    }
}

test "integer primitive" {
    const allocator = std.testing.allocator;
    inline for ([_][]const u8{ "i8", "i16", "i32", "i64", "i128", "int", "u8", "u16", "u32", "u64", "u128", "uint" }) |name| {
        var integer = try Type(Tag.Type(name)).init(allocator, 0);
        defer integer.deinit(allocator);
        try std.testing.expectEqual(0, integer.value);
        integer.mutatable.add(10);
        try std.testing.expectEqual(10, integer.value);
        integer.mutatable.sub(5);
        try std.testing.expectEqual(5, integer.value);
        integer.mutatable.mul(4);
        try std.testing.expectEqual(20, integer.value);
        integer.mutatable.div(5);
        try std.testing.expectEqual(4, integer.value);
    }
    inline for ([_][]const u8{ "i8", "i16", "i32", "i64", "i128", "int", "u8", "u16", "u32", "u64", "u128", "uint" }) |name| {
        var integer = try Type(Tag.Type(name)).init(allocator, 10);
        defer integer.deinit(allocator);
        try std.testing.expectEqual(10, integer.value);
        const string = try integer.transformable.string(allocator);
        defer string.deinit(allocator);
        try std.testing.expectEqualStrings("10", string.value);
    }
}

test "float primitive" {
    const allocator = std.testing.allocator;
    inline for ([_][]const u8{ "f16", "f32", "f64", "f128" }) |name| {
        var float = try Type(Tag.Type(name)).init(allocator, 0);
        defer float.deinit(allocator);
        try std.testing.expectEqual(0, float.value);
        float.mutatable.add(10);
        try std.testing.expectEqual(10, float.value);
        float.mutatable.sub(5);
        try std.testing.expectEqual(5, float.value);
        float.mutatable.mul(4);
        try std.testing.expectEqual(20, float.value);
        float.mutatable.div(5);
        try std.testing.expectEqual(4, float.value);
    }
    inline for ([_][]const u8{ "f16", "f32", "f64", "f128" }) |name| {
        var float = try Type(Tag.Type(name)).init(allocator, 10);
        defer float.deinit(allocator);
        try std.testing.expectEqual(10, float.value);
        const string = try float.transformable.string(allocator);
        defer string.deinit(allocator);
        try std.testing.expectEqualStrings("10", string.value);
    }
}

test "string primitive" {
    const allocator = std.testing.allocator;
    inline for ([_][]const u8{"string"}) |name| {
        var input = "test".*;
        var string = try Type(Tag.Type(name)).init(allocator, &input);
        defer string.deinit(allocator);
        try std.testing.expectEqualStrings("test", string.value);
        string.mutatable.upper();
        try std.testing.expectEqualStrings("TEST", string.value);
        string.mutatable.lower();
        try std.testing.expectEqualStrings("test", string.value);
    }
    inline for ([_][]const u8{"string"}) |name| {
        var input = "test".*;
        var string = try Type(Tag.Type(name)).init(allocator, &input);
        defer string.deinit(allocator);
        try std.testing.expectEqualStrings("test", string.value);
        var integer = try string.transformable.len(allocator);
        defer integer.deinit(allocator);
        try std.testing.expectEqual(4, integer.value);
    }
}
