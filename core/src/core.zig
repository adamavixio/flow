const std = @import("std");
const trait = @import("trait.zig");

pub const Core = @This();

pub const FlowTag = enum {
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

    pub fn BaseType(float_flow_tag: FlowTag) type {
        return switch (float_flow_tag) {
            .i8 => i8,
            .i16 => i16,
            .i32 => i32,
            .i64 => i64,
            .i128 => i128,
            .int => isize,
            .u8 => u8,
            .u16 => u16,
            .u32 => u32,
            .u64 => u64,
            .u128 => u128,
            .uint => usize,
            .f16 => f16,
            .f32 => f32,
            .f64 => f64,
            .f128 => f128,
            .float => f64,
            .bytes => []u8,
            .string => []const u8,
        };
    }

    pub const map = blk: {
        var entries: [@typeInfo(FlowTag).Enum.fields.len]struct { []const u8, FlowTag } = undefined;
        for (@typeInfo(FlowTag).Enum.fields, 0..) |field, i| {
            entries[i] = .{ field.name, @field(FlowTag, field.name) };
        }
        break :blk std.StaticStringMap(FlowTag).initComptime(entries);
    };

    pub fn fromString(comptime tag_name: []const u8) ?FlowTag {
        return map.get(tag_name);
    }

    pub fn fromFlowType(T: type) ?FlowTag {
        inline for (@typeInfo(FlowTag).Enum.fields) |field| {
            const flow_tag = @field(FlowTag, field.name);
            if (FlowType(flow_tag) == T) return flow_tag;
        }
        return null;
    }

    pub fn fromTransformTrait(flow_tag: FlowTag, comptime trait_name: []const u8) ?FlowTag {
        switch (flow_tag) {
            inline else => |value| {
                const Transform = FlowType(value).Transform;

                if (!@hasDecl(Transform, trait_name)) {
                    return null;
                }

                const fn_info = switch (@typeInfo(@TypeOf(@field(Transform, trait_name)))) {
                    .Fn => |info| info,
                    else => return null,
                };

                const error_info = switch (@typeInfo(fn_info.return_type.?)) {
                    .ErrorUnion => |info| info,
                    else => return null,
                };

                const pointer_info = switch (@typeInfo(error_info.payload)) {
                    .Pointer => |info| info,
                    else => return null,
                };

                return fromFlowType(pointer_info.child);
            },
        }
    }

    pub fn hasMutation(flow_tag: FlowTag, comptime trait_name: []const u8) bool {
        switch (flow_tag) {
            inline else => |value| {
                return @hasDecl(FlowType(value).Mutation, trait_name);
            },
        }
    }

    pub fn hasTransform(flow_tag: FlowTag, comptime trait_name: []const u8) bool {
        switch (flow_tag) {
            inline else => |value| {
                return @hasDecl(FlowType(value).Transform, trait_name);
            },
        }
    }

    pub fn hasTerminal(flow_tag: FlowTag, comptime trait_name: []const u8) bool {
        switch (flow_tag) {
            inline else => |value| {
                return @hasDecl(FlowType(value).Terminal, trait_name);
            },
        }
    }
};

pub fn FlowType(comptime flow_tag: FlowTag) type {
    return struct {
        const Self = @This();

        pub const Base = flow_tag.BaseType();
        pub const Mutation = trait.Mutatable(Self, Base);
        pub const Transform = trait.Transformable(Self, Base);
        pub const Terminal = trait.Terminable(Self, Base);

        value: Base,
        mutation: Mutation = .{},
        transform: Transform = .{},
        terminal: Terminal = .{},

        pub fn init(allocator: std.mem.Allocator, value: Base) !*Self {
            const self = try allocator.create(Self);
            switch (@typeInfo(Base)) {
                .Pointer => |ptr_info| switch (ptr_info.child) {
                    u8 => self.*.value = try allocator.dupe(u8, value),
                    else => self.*.value = value,
                },
                else => self.*.value = value,
            }
            return self;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (@typeInfo(Base)) {
                .Pointer => |ptr_info| switch (ptr_info.child) {
                    u8 => allocator.free(self.value),
                    else => {},
                },
                else => {},
            }
            allocator.destroy(self);
        }
    };
}

pub fn FlowTypeFromString(type_name: []const u8) ?type {
    if (FlowTag.fromString(type_name)) |flow_tag| {
        return FlowType(flow_tag);
    }
    return null;
}

test "primitive int" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "i8", "i16", "i32", "i64", "i128", "int" }) |string| {
        const flow_tag = FlowTag.fromString(string).?;

        try std.testing.expect(flow_tag.hasMutation("add"));
        try std.testing.expect(flow_tag.hasMutation("sub"));
        try std.testing.expect(flow_tag.hasMutation("mul"));
        try std.testing.expect(flow_tag.hasMutation("div"));
        try std.testing.expect(flow_tag.hasTransform("string"));
        try std.testing.expect(flow_tag.hasTerminal("print"));

        try std.testing.expectEqual(.string, flow_tag.fromTransformTrait("string"));
    }

    inline for ([_][]const u8{ "i8", "i16", "i32", "i64", "i128", "int" }) |string| {
        const Int = FlowTypeFromString(string).?;

        var int = try Int.init(allocator, 0);
        defer int.deinit(allocator);
        try std.testing.expectEqual(0, int.value);

        int.mutation.add(20);
        try std.testing.expectEqual(20, int.value);

        int.mutation.sub(10);
        try std.testing.expectEqual(10, int.value);

        int.mutation.mul(5);
        try std.testing.expectEqual(50, int.value);

        int.mutation.div(2);
        try std.testing.expectEqual(25, int.value);

        const string_transform = try int.transform.string(allocator);
        defer string_transform.deinit(allocator);
        try std.testing.expectEqualStrings("25", string_transform.value);
    }
}

test "primitive uint" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "u8", "u16", "u32", "u64", "u128", "uint" }) |string| {
        const Uint = FlowTypeFromString(string).?;

        var uint = try Uint.init(allocator, 0);
        defer uint.deinit(allocator);
        try std.testing.expectEqual(0, uint.value);

        uint.mutation.add(20);
        try std.testing.expectEqual(20, uint.value);

        uint.mutation.sub(10);
        try std.testing.expectEqual(10, uint.value);

        uint.mutation.mul(5);
        try std.testing.expectEqual(50, uint.value);

        uint.mutation.div(2);
        try std.testing.expectEqual(25, uint.value);

        const string_transform = try uint.transform.string(allocator);
        defer string_transform.deinit(allocator);
        try std.testing.expectEqualStrings("25", string_transform.value);
    }
}

test "primitive float" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "f16", "f32", "f64", "f128", "float" }) |string| {
        const Float = FlowTypeFromString(string).?;

        var float = try Float.init(allocator, 0);
        defer float.deinit(allocator);
        try std.testing.expectEqual(0, float.value);

        float.mutation.add(20);
        try std.testing.expectEqual(20, float.value);

        float.mutation.sub(10);
        try std.testing.expectEqual(10, float.value);

        float.mutation.mul(5);
        try std.testing.expectEqual(50, float.value);

        float.mutation.div(2);
        try std.testing.expectEqual(25, float.value);

        const string_transform = try float.transform.string(allocator);
        defer string_transform.deinit(allocator);
        try std.testing.expectEqualStrings("25", string_transform.value);
    }
}

test "primitive bytes" {
    const allocator = std.testing.allocator;

    const Bytes = FlowTypeFromString("bytes").?;
    var slice = "test".*;
    var bytes = try Bytes.init(allocator, &slice);
    defer bytes.deinit(allocator);
    try std.testing.expectEqualStrings("test", bytes.value);

    bytes.mutation.upper();
    try std.testing.expectEqualStrings("TEST", bytes.value);

    bytes.mutation.lower();
    try std.testing.expectEqualStrings("test", bytes.value);
}

test "primitive string" {
    const String = FlowTypeFromString("string").?;
    const allocator = std.testing.allocator;

    var string = try String.init(allocator, "test");
    defer string.deinit(allocator);
    try std.testing.expectEqualStrings("test", string.value);

    const upper = try string.transform.upper(allocator);
    defer upper.deinit(allocator);
    try std.testing.expectEqualStrings("TEST", upper.value);

    const lower = try string.transform.lower(allocator);
    defer lower.deinit(allocator);
    try std.testing.expectEqualStrings("test", lower.value);
}
