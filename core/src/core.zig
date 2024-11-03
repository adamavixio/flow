const std = @import("std");
const trait = @import("trait.zig");
const status = @import("status.zig");

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

    pub fn ToBaseType(flow_tag: FlowTag) type {
        return switch (flow_tag) {
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

    pub fn ToFlowType(flow_tag: FlowTag) type {
        return FlowType(flow_tag);
    }

    pub const map = blk: {
        var entries: [@typeInfo(FlowTag).Enum.fields.len]struct { []const u8, FlowTag } = undefined;
        for (@typeInfo(FlowTag).Enum.fields, 0..) |field, i| {
            entries[i] = .{ field.name, @field(FlowTag, field.name) };
        }
        break :blk std.StaticStringMap(FlowTag).initComptime(entries);
    };

    pub fn hasString(string: []const u8) bool {
        return map.has(string);
    }

    pub fn fromString(string: []const u8) status.Error!FlowTag {
        return map.get(string) orelse status.Error.TagNameNotFound;
    }

    pub fn fromFlowType(T: type) status.Error!FlowTag {
        inline for (@typeInfo(FlowTag).Enum.fields) |field| {
            const flow_tag = @field(FlowTag, field.name);
            if (FlowType.FromTag(flow_tag) == T) return flow_tag;
        }
        return status.Error.TagTypeNotFound;
    }

    pub fn fromTransformTrait(flow_tag: FlowTag, comptime trait_name: []const u8) status.Error!FlowTag {
        switch (flow_tag) {
            inline else => |value| {
                const Transform = FlowType.FromTag(value).Transform;

                if (!@hasDecl(Transform, trait_name)) {
                    return status.Error.TransformTraitNotFound;
                }

                const fn_info = switch (@typeInfo(@TypeOf(@field(Transform, trait_name)))) {
                    .Fn => |info| info,
                    else => return status.Error.TransformTraitNotFunction,
                };

                const error_info = switch (@typeInfo(fn_info.return_type.?)) {
                    .ErrorUnion => |info| info,
                    else => return status.Error.TransformResultNotError,
                };

                const pointer_info = switch (@typeInfo(error_info.payload)) {
                    .Pointer => |info| info,
                    else => return status.Error.TransformResultNotPointer,
                };

                return try fromFlowType(pointer_info.child);
            },
        }
    }

    pub fn hasMutation(flow_tag: FlowTag, comptime trait_name: []const u8) bool {
        switch (flow_tag) {
            inline else => |value| {
                return @hasDecl(FlowType.FromTag(value).Mutation, trait_name);
            },
        }
    }

    pub fn hasTransform(flow_tag: FlowTag, comptime trait_name: []const u8) bool {
        switch (flow_tag) {
            inline else => |value| {
                return @hasDecl(FlowType.FromTag(value).Transform, trait_name);
            },
        }
    }

    pub fn hasTerminal(flow_tag: FlowTag, comptime trait_name: []const u8) bool {
        switch (flow_tag) {
            inline else => |value| {
                return @hasDecl(FlowType.FromTag(value).Terminal, trait_name);
            },
        }
    }
};

pub const FlowType = struct {
    pub fn FromString(comptime flow_tag_name: []const u8) type {
        const flow_Tag = try FlowTag.fromString(flow_tag_name);
        return FromTag(flow_Tag);
    }

    pub fn FromTag(comptime flow_tag: FlowTag) type {
        return struct {
            const Self = @This();

            pub const Base = flow_tag.ToBaseType();
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
};

test "signed integer" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "i8", "i16", "i32", "i64", "i128", "int" }) |string| {
        const flow_tag = try FlowTag.fromString(string);

        try std.testing.expect(flow_tag.hasMutation("add"));
        try std.testing.expect(flow_tag.hasMutation("sub"));
        try std.testing.expect(flow_tag.hasMutation("mul"));
        try std.testing.expect(flow_tag.hasMutation("div"));
        try std.testing.expect(flow_tag.hasTransform("string"));
        try std.testing.expect(flow_tag.hasTerminal("print"));
        try std.testing.expectEqual(.string, flow_tag.fromTransformTrait("string"));

        var flow_value = try FlowType.FromString(string).init(allocator, 0);
        defer flow_value.deinit(allocator);

        try std.testing.expectEqual(0, flow_value.value);
        flow_value.mutation.add(20);
        try std.testing.expectEqual(20, flow_value.value);
        flow_value.mutation.sub(10);
        try std.testing.expectEqual(10, flow_value.value);
        flow_value.mutation.mul(5);
        try std.testing.expectEqual(50, flow_value.value);
        flow_value.mutation.div(2);
        try std.testing.expectEqual(25, flow_value.value);

        const transform = try flow_value.transform.string(allocator);
        defer transform.deinit(allocator);

        try std.testing.expectEqualStrings("25", transform.value);
    }
}

test "unsigned integer" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "u8", "u16", "u32", "u64", "u128", "uint" }) |string| {
        const flow_tag = try FlowTag.fromString(string);

        try std.testing.expect(flow_tag.hasMutation("add"));
        try std.testing.expect(flow_tag.hasMutation("sub"));
        try std.testing.expect(flow_tag.hasMutation("mul"));
        try std.testing.expect(flow_tag.hasMutation("div"));
        try std.testing.expect(flow_tag.hasTransform("string"));
        try std.testing.expect(flow_tag.hasTerminal("print"));
        try std.testing.expectEqual(.string, flow_tag.fromTransformTrait("string"));

        var flow_value = try FlowType.FromString(string).init(allocator, 0);
        defer flow_value.deinit(allocator);

        try std.testing.expectEqual(0, flow_value.value);
        flow_value.mutation.add(20);
        try std.testing.expectEqual(20, flow_value.value);
        flow_value.mutation.sub(10);
        try std.testing.expectEqual(10, flow_value.value);
        flow_value.mutation.mul(5);
        try std.testing.expectEqual(50, flow_value.value);
        flow_value.mutation.div(2);
        try std.testing.expectEqual(25, flow_value.value);

        const transform = try flow_value.transform.string(allocator);
        defer transform.deinit(allocator);

        try std.testing.expectEqualStrings("25", transform.value);
    }
}

test "floating point" {
    const allocator = std.testing.allocator;

    inline for ([_][]const u8{ "f16", "f32", "f64", "f128", "float" }) |string| {
        const flow_tag = try FlowTag.fromString(string);

        try std.testing.expect(flow_tag.hasMutation("add"));
        try std.testing.expect(flow_tag.hasMutation("sub"));
        try std.testing.expect(flow_tag.hasMutation("mul"));
        try std.testing.expect(flow_tag.hasMutation("div"));
        try std.testing.expect(flow_tag.hasTransform("string"));
        try std.testing.expect(flow_tag.hasTerminal("print"));
        try std.testing.expectEqual(.string, flow_tag.fromTransformTrait("string"));

        var flow_value = try FlowType.FromString(string).init(allocator, 0);
        defer flow_value.deinit(allocator);

        try std.testing.expectEqual(0, flow_value.value);
        flow_value.mutation.add(20);
        try std.testing.expectEqual(20, flow_value.value);
        flow_value.mutation.sub(10);
        try std.testing.expectEqual(10, flow_value.value);
        flow_value.mutation.mul(5);
        try std.testing.expectEqual(50, flow_value.value);
        flow_value.mutation.div(2);
        try std.testing.expectEqual(25, flow_value.value);

        const transform = try flow_value.transform.string(allocator);
        defer transform.deinit(allocator);

        try std.testing.expectEqualStrings("25", transform.value);
    }
}

test "bytes" {
    const allocator = std.testing.allocator;
    const flow_tag = try FlowTag.fromString("bytes");

    try std.testing.expect(flow_tag.hasMutation("upper"));
    try std.testing.expect(flow_tag.hasMutation("lower"));
    try std.testing.expect(flow_tag.hasTerminal("print"));

    var slice = "test".*;
    var flow_value = try FlowType.FromString("bytes").init(allocator, &slice);
    defer flow_value.deinit(allocator);

    try std.testing.expectEqualStrings("test", flow_value.value);
    flow_value.mutation.upper();
    try std.testing.expectEqualStrings("TEST", flow_value.value);
    flow_value.mutation.lower();
    try std.testing.expectEqualStrings("test", flow_value.value);
}

test "string" {
    const allocator = std.testing.allocator;
    const flow_tag = try FlowTag.fromString("string");

    try std.testing.expect(flow_tag.hasTransform("upper"));
    try std.testing.expect(flow_tag.hasTransform("lower"));
    try std.testing.expect(flow_tag.hasTerminal("print"));

    var flow_value = try FlowType.FromString("string").init(allocator, "test");
    defer flow_value.deinit(allocator);

    try std.testing.expectEqualStrings("test", flow_value.value);
    const upper = try flow_value.transform.upper(allocator);
    defer upper.deinit(allocator);
    try std.testing.expectEqualStrings("TEST", upper.value);
    const lower = try flow_value.transform.lower(allocator);
    defer lower.deinit(allocator);
    try std.testing.expectEqualStrings("test", lower.value);
}
