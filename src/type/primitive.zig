const std = @import("std");

pub const Primitive = union(enum) {
    u8: Int(u8),
    u16: Int(u16),
    u32: Int(u32),
    u64: Int(u64),
    u128: Int(u128),
    uint: Int(usize),

    i8: Int(i8),
    i16: Int(i16),
    i32: Int(i32),
    i64: Int(i64),
    i128: Int(i128),
    int: Int(isize),

    f16: Float(f16),
    f32: Float(f32),
    f64: Float(f64),
    f80: Float(f80),
    f128: Float(isize),

    string: String,

    pub const Tag = std.meta.FieldEnum(Primitive);

    pub fn Type(comptime tag: Tag) type {
        return std.meta.FieldType(Primitive, tag);
    }

    pub fn Operator(comptime tag: Tag) type {
        return std.meta.DeclEnum(Type(tag));
    }

    pub fn initOperator(comptime tag: Tag, name: []const u8) ?Operator(tag) {
        return std.meta.stringToEnum(Operator(tag), name);
    }

    pub fn Mutate(comptime tag: Tag) type {
        return struct {
            function: fn (self: *Type(tag), op: Operator(tag), args: ?[]const u8) anyerror!void,

            pub fn modify(self: *Type(tag), impl: *const Mutate(tag), op: Operator(tag), args: ?[]const u8) !void {
                return impl.function(self, op, args);
            }
        };
    }

    pub fn Convert(comptime from_tag: Tag) type {
        return struct {
            function: fn (self: *const Type(from_tag), to_tag: Tag) anyerror!*Primitive,

            pub fn convert(self: *const Type(from_tag), impl: *const Convert(from_tag), to_tag: Tag) !*Primitive {
                return impl.function(self, to_tag);
            }
        };
    }
};

test "int field type" {
    try std.testing.expectEqual(Int, Primitive.Type(.int));
}

test "float field type" {
    try std.testing.expectEqual(Float, Primitive.Type(.float));
}

test "string field type" {
    try std.testing.expectEqual(String, Primitive.Type(.string));
}

test "int field declaration" {
    const operations = [_][]const u8{ "init", "deinit", "add", "sub", "mul", "div", "mod" };
    try std.testing.expectEqual(.init, Primitive.initOperator(.int, operations[0]));
    try std.testing.expectEqual(.deinit, Primitive.initOperator(.int, operations[1]));
    try std.testing.expectEqual(.add, Primitive.initOperator(.int, operations[2]));
    try std.testing.expectEqual(.sub, Primitive.initOperator(.int, operations[3]));
    try std.testing.expectEqual(.mul, Primitive.initOperator(.int, operations[4]));
    try std.testing.expectEqual(.div, Primitive.initOperator(.int, operations[5]));
    try std.testing.expectEqual(.mod, Primitive.initOperator(.int, operations[6]));
    try std.testing.expectEqual(std.meta.fields(Primitive.Operator(.int)).len, operations.len);
}

test "float field declaration" {
    const operations = [_][]const u8{ "init", "deinit", "add", "sub", "mul", "div" };
    try std.testing.expectEqual(.init, Primitive.initOperator(.float, operations[0]));
    try std.testing.expectEqual(.deinit, Primitive.initOperator(.float, operations[1]));
    try std.testing.expectEqual(.add, Primitive.initOperator(.float, operations[2]));
    try std.testing.expectEqual(.sub, Primitive.initOperator(.float, operations[3]));
    try std.testing.expectEqual(.mul, Primitive.initOperator(.float, operations[4]));
    try std.testing.expectEqual(.div, Primitive.initOperator(.float, operations[5]));
    try std.testing.expectEqual(std.meta.fields(Primitive.Operator(.float)).len, operations.len);
}

test "string field declaration" {
    const operations = [_][]const u8{ "init", "deinit", "sort", "unique" };
    try std.testing.expectEqual(.init, Primitive.initOperator(.string, operations[0]));
    try std.testing.expectEqual(.deinit, Primitive.initOperator(.string, operations[1]));
    try std.testing.expectEqual(.sort, Primitive.initOperator(.string, operations[2]));
    try std.testing.expectEqual(.unique, Primitive.initOperator(.string, operations[3]));
    try std.testing.expectEqual(std.meta.fields(Primitive.Operator(.string)).len, operations.len);
}

pub fn Int(comptime IntType: type) type {
    if (@typeInfo(IntType) != .Int) {
        @compileError("Invalid 'IntType' type: " ++ @typeName(IntType));
    }

    return struct {
        const Self = @This();

        data: IntType,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, data: IntType) !*Self {
            const self = try allocator.create(Self);
            self.* = .{ .data = data, .allocator = allocator };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }

        pub fn add(self: *Self, value: IntType) void {
            self.data += value;
        }

        pub fn sub(self: *Self, value: IntType) void {
            self.data -= value;
        }

        pub fn mul(self: *Self, value: IntType) void {
            self.data *= value;
        }

        pub fn div(self: *Self, value: IntType) void {
            self.data = @divTrunc(self.data, value);
        }

        pub fn mod(self: *Self, value: IntType) void {
            self.data = @mod(self.data, value);
        }
    };
}

test "signed" {
    const types = [_]type{ i8, i16, i32, i64, i128, isize };
    inline for (types) |Type| {
        var int = try Int(Type).init(std.testing.allocator, 0);
        defer int.deinit();

        int.add(10);
        try std.testing.expectEqual(int.data, 10);

        int.sub(5);
        try std.testing.expectEqual(int.data, 5);

        int.mul(2);
        try std.testing.expectEqual(int.data, 10);

        int.div(2);
        try std.testing.expectEqual(int.data, 5);

        int.mod(2);
        try std.testing.expectEqual(int.data, 1);
    }
}

test "unsigned" {
    const types = [_]type{ u8, u16, u32, u64, u128, usize };
    inline for (types) |Type| {
        var int = try Int(Type).init(std.testing.allocator, 0);
        defer int.deinit();

        int.add(10);
        try std.testing.expectEqual(int.data, 10);

        int.sub(5);
        try std.testing.expectEqual(int.data, 5);

        int.mul(2);
        try std.testing.expectEqual(int.data, 10);

        int.div(2);
        try std.testing.expectEqual(int.data, 5);

        int.mod(2);
        try std.testing.expectEqual(int.data, 1);
    }
}

pub fn Float(comptime FloatType: type) type {
    if (@typeInfo(FloatType) != .Float) {
        @compileError("Invalid 'FloatType' type: " ++ @typeName(FloatType));
    }

    return struct {
        const Self = @This();

        data: FloatType,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, data: FloatType) !*Self {
            const self = try allocator.create(Self);
            self.* = .{ .data = data, .allocator = allocator };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self);
        }

        pub fn add(self: *Self, value: FloatType) void {
            self.data += value;
        }

        pub fn sub(self: *Self, value: FloatType) void {
            self.data -= value;
        }

        pub fn mul(self: *Self, value: FloatType) void {
            self.data *= value;
        }

        pub fn div(self: *Self, value: FloatType) void {
            self.data /= value;
        }
    };
}

test "float" {
    const types = [_]type{ f16, f32, f64, f80, f128 };
    inline for (types) |Type| {
        var float = try Float(Type).init(std.testing.allocator, 0);
        defer float.deinit();

        float.add(10);
        try std.testing.expectEqual(float.data, 10);

        float.sub(5);
        try std.testing.expectEqual(float.data, 5);

        float.mul(2);
        try std.testing.expectEqual(float.data, 10);

        float.div(2);
        try std.testing.expectEqual(float.data, 5);
    }
}

pub const String = struct {
    const Self = @This();

    len: usize,
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !Self {
        return .{
            .len = data.len,
            .data = try allocator.dupe(u8, data),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
        self.* = undefined;
    }

    pub fn sort(self: *Self, comptime order: enum { asc, desc }) void {
        std.mem.sort(u8, self.data, {}, switch (order) {
            .asc => std.sort.asc(u8),
            .desc => std.sort.desc(u8),
        });
    }

    pub fn unique(self: *Self) !void {
        var seen = std.AutoHashMap(u8, void).init(self.allocator);
        defer seen.deinit();

        var write_index: usize = 0;
        for (0..self.len) |read_index| {
            const char = self.data[read_index];
            if (!seen.contains(char)) {
                try seen.put(char, {});
                self.data[write_index] = char;
                write_index += 1;
            }
        }

        if (write_index < self.data.len) {
            self.len = write_index;
            self.data = try self.allocator.realloc(self.data, write_index);
        }
    }
};

test "String operations" {
    var string = try String.init(std.testing.allocator, "ccbbaa");
    defer string.deinit();

    try std.testing.expectEqual(6, string.len);
    try std.testing.expectEqualStrings("ccbbaa", string.data);

    string.sort(.asc);
    try std.testing.expectEqual(6, string.len);
    try std.testing.expectEqualStrings("aabbcc", string.data);

    try string.unique();
    try std.testing.expectEqual(3, string.len);
    try std.testing.expectEqualStrings("abc", string.data);
}
