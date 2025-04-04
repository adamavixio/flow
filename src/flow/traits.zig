const std = @import("std");
const testing = std.testing;

pub fn Type(comptime Value: type) type {
    return struct {
        const Self = @This();
        value: Value,
    };
}

pub fn Add(comptime Container: type, comptime Value: type) type {
    switch (@typeInfo(Value)) {
        .Int, .Float => return struct {
            pub fn implemented() bool {
                return true;
            }
            pub fn execute(value: Value) @This() {
                const container: *Container = @alignCast(@fieldParentPtr("mutation", @This()));
                container.*.value += value;
            }
        },
        else => return struct {
            pub fn implemented() bool {
                return false;
            }
        },
    }
}

pub fn isSignedInt(Type: type) bool {
    switch (@typeInfo(Type)) {
        .Int => |info| return info.signedness == .signed,
        else => return false,
    }
}

test "is signed int" {
    {
        const types = [_]type{ i8, i16, i32, i64, i128, isize };
        inline for (types) |Type| try testing.expect(isSignedInt(Type));
    }
    {
        const types = [_]type{ u8, u16, u32, u64, u128, usize, f16, f32, f64, f128, []const u8 };
        inline for (types) |Type| try testing.expect(!isSignedInt(Type));
    }
}

pub fn isUnsignedInt(Type: type) bool {
    switch (@typeInfo(Type)) {
        .Int => |info| return info.signedness == .unsigned,
        else => return false,
    }
}

test "is unsigned int" {
    {
        const types = [_]type{ u8, u16, u32, u64, u128, usize };
        inline for (types) |Type| try testing.expect(isUnsignedInt(Type));
    }
    {
        const types = [_]type{ i8, i16, i32, i64, i128, isize, f16, f32, f64, f128, []const u8 };
        inline for (types) |Type| try testing.expect(!isUnsignedInt(Type));
    }
}

pub fn isFloat(Type: type) bool {
    switch (@typeInfo(Type)) {
        .Float => return true,
        else => return false,
    }
}

test "is float" {
    {
        const types = [_]type{ f16, f32, f64, f128 };
        inline for (types) |Type| try testing.expect(isFloat(Type));
    }
    {
        const types = [_]type{ i8, i16, i32, i64, i128, isize, u8, u16, u32, u64, u128, usize, []const u8 };
        inline for (types) |Type| try testing.expect(!isFloat(Type));
    }
}

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
