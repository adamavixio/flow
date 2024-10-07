const std = @import("std");

pub const Error = error{
    InvalidLiteral,
};

pub const Primitive = union(enum) {
    i8: Int(i8),
    i16: Int(i16),
    i32: Int(i32),
    i64: Int(i64),
    i128: Int(i128),
    int: Int(isize),
    u8: Int(u8),
    u16: Int(u16),
    u32: Int(u32),
    u64: Int(u64),
    u128: Int(u128),
    uint: Int(usize),
    f16: Float(f16),
    f32: Float(f32),
    f64: Float(f64),
    f80: Float(f80),
    f128: Float(f128),
    string: String,

    pub const Tags = std.StaticStringMap(type);
    pub const tags = Tags.initComptime(.{
        .{ "i8", Int(i8) },
        .{ "i16", Int(i16) },
        .{ "i32", Int(i32) },
        .{ "i64", Int(i64) },
        .{ "i128", Int(i128) },
        .{ "int", Int(isize) },
        .{ "u8", Int(u8) },
        .{ "u16", Int(u16) },
        .{ "u32", Int(u32) },
        .{ "u64", Int(u64) },
        .{ "u128", Int(u128) },
        .{ "uint", Int(usize) },
        .{ "f16", Float(f16) },
        .{ "f32", Float(f32) },
        .{ "f64", Float(f64) },
        .{ "f80", Float(f80) },
        .{ "f128", Float(f128) },
        .{ "string", String },
    });
};

pub fn hasTransformable(comptime tag: Meta(Primitive).Tag, name: []const u8) bool {
    const Type = Meta(Primitive).Type(tag);
    if (!@hasDecl(Type, "Transformable")) return false;
    for (std.meta.declarations(Type.Transformable)) |declaration| {
        if (std.mem.eql(u8, declaration.name, name)) return true;
    }
    return false;
}

pub fn hasMutatable(comptime tag: Meta(Primitive).Tag, name: []const u8) bool {
    const Type = Meta(Primitive).Type(tag);
    if (!@hasDecl(Type, "Mutatable")) return false;
    for (std.meta.declarations(Type.Transformable)) |declaration| {
        if (std.mem.eql(u8, declaration.name, name)) return true;
    }
    return false;
}

pub fn hasTerminable(comptime tag: Meta(Primitive).Tag, name: []const u8) bool {
    const Type = Meta(Primitive).Type(tag);
    if (!@hasDecl(Type, "Terminable")) return false;
    for (std.meta.declarations(Type.Transformable)) |declaration| {
        if (std.mem.eql(u8, declaration.name, name)) return true;
    }
    return false;
}

test "Traits" {
    try std.testing.expect(Primitive.hasTransformable(.u8, "string"));
    try std.testing.expect(Primitive.hasMutatable(.u8));
    try std.testing.expect(Primitive.hasTerminable(.u8));
}

pub fn Int(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,

        pub fn init(allocator: std.mem.Allocator, value: []const u8) !*Self {
            const self = try allocator.create(Self);
            self.* = .{ .value = try std.fmt.parseInt(T, value, 10) };
            return self;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }

        pub const Transformable = struct {
            pub fn string(self: *Self, allocator: std.mem.Allocator) !*String {
                defer self.deinit(allocator);
                const str = try std.fmt.allocPrint(allocator, "{d}", .{self.value});
                return String.init(allocator, str);
            }
        };

        pub const Mutatable = struct {
            pub fn add(self: *Self, value: T) void {
                self.value += value;
            }

            pub fn sub(self: *Self, value: T) void {
                self.value -= value;
            }

            pub fn mul(self: *Self, value: T) void {
                self.value += value;
            }

            pub fn div(self: *Self, value: T) void {
                self.value = @divFloor(self.value, value);
            }
        };

        pub const Terminable = struct {
            pub fn print(self: *Self) void {
                std.debug.print("{d}\n", .{self.value});
            }
        };
    };
}

pub fn Float(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,

        pub fn init(allocator: std.mem.Allocator, value: []const u8) !*Self {
            const self = try allocator.create(Self);
            self.* = .{ .value = try std.fmt.parseInt(T, value, 10) };
            return self;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }

        pub const Transformable = struct {
            pub fn string(self: *Self, allocator: std.mem.Allocator) !*String {
                defer self.deinit(allocator);
                const str = try std.fmt.allocPrint(allocator, "{d}", .{self.value});
                return String.init(allocator, str);
            }
        };

        pub const Mutatable = struct {
            pub fn add(self: *Self, value: T) void {
                self.value += value;
            }

            pub fn sub(self: *Self, value: T) void {
                self.value -= value;
            }

            pub fn mul(self: *Self, value: T) void {
                self.value += value;
            }

            pub fn div(self: *Self, value: T) void {
                self.value /= value;
            }
        };

        pub const Terminable = struct {
            pub fn print(self: *Self) void {
                std.debug.print("{d}\n", .{self.value});
            }
        };
    };
}

pub const String = struct {
    const Self = @This();

    value: []u8,

    pub fn init(allocator: std.mem.Allocator, value: []const u8) !*Self {
        const self = try allocator.create(Self);
        self.* = .{ .value = try allocator.dupe(u8, value) };
        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        allocator.destroy(self);
    }

    pub const Transformable = struct {
        pub fn len(self: *Self) usize {
            return self.value.len;
        }
    };

    pub const Mutatable = struct {
        pub fn sort(self: *Self, order: enum { asc, desc }) void {
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

    pub const Terminable = struct {
        pub fn print(self: *Self) void {
            std.debug.print("{any}\n", .{self.value});
        }
    };
};

pub fn Meta(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Pointer => return struct {
            const child = std.meta.Child(T);
        },
        .Union => return struct {
            const Tag = std.meta.FieldEnum(T);

            pub fn Type(comptime tag: Tag) type {
                return std.meta.FieldType(T, tag);
            }

            pub fn hasDeclaration(comptime tag: Tag) []const u8 {
                return std.meta.fieldInfo(T, tag).name;
            }

            pub fn name(comptime tag: Tag) []const u8 {
                return std.meta.fieldInfo(T, tag).name;
            }
        },
        .Struct => return struct {
            const Tag = std.meta.DeclEnum(T);

            pub fn Type(comptime tag: Tag) type {
                return @TypeOf(@field(T, @tagName(tag)));
            }

            pub fn hasFunction(comptime name: []const u8) bool {
                return std.meta.hasFn(T, name);
            }
        },
        else => @compileError("unsupported type: " ++ @typeName(T)),
    }
}

// test "primitive" {
//     {
//         const allocator = std.testing.allocator;
//         var int = Primitive.init(allocator, "usize", "10");

//         try int.init(std.testing.allocator, "10");
//         defer int.deinit(std.testing.allocator);

//         const output = try int.print(std.testing.allocator);
//         defer std.testing.allocator.free(output);
//         std.debug.print("{s}\n", .{output});
//     }

//     {
//         var string = Primitive.init(.string);

//         try string.init(std.testing.allocator, "string");
//         defer string.deinit(std.testing.allocator);

//         const output = try string.print(std.testing.allocator);
//         defer std.testing.allocator.free(output);
//         std.debug.print("{s}\n", .{output});
//     }
// }

// pub fn init(allocator: std.mem.Allocator, value: []const u8) Meta(Primitive).Type(tag) {
//     const Type = Meta(Primitive).Type(tag);
//     return Type.init(allocator)
// }
// };

// pub fn Trait(comptime Type: type) type {
//     return struct {
//         pointer: *anyopaque,
//         transformable: *const Transformable(Type),
//         mutatable: *const Mutatable(Type),
//         terminable: *const Terminable(Type),

//         pub fn init(self: *Trait, allocator: std.mem.Allocator, value: []const u8) !void {
//             self.pointer = try self.transformable.init(allocator, value);
//         }

//         pub fn len(self: *Trait, allocator: std.mem.Allocator, value: []const u8) !void {
//             const pointer = self.transformable.len(self.pointer);
//             self.pointer = try self.transformable.init(allocator, value);
//         }

//         pub fn deinit(self: Trait, allocator: std.mem.Allocator) void {
//             self.implementation.deinit(self.pointer, allocator);
//         }

//         pub fn print(self: Trait, allocator: std.mem.Allocator) ![]const u8 {
//             return try self.implementation.print(self.pointer, allocator);
//         }
//     };
// }

// pub fn Transformable(comptime Type: type) type {
//     return struct {
//         init: *const fn (allocator: std.mem.Allocator, value: []const u8) anyerror!*anyopaque,
//         len: *const fn (pointer: *anyopaque) *anyopaque,

//         pub fn init(allocator: std.mem.Allocator, value: []const u8) !*anyopaque {
//             return @ptrCast(@alignCast(try Type.init(allocator, value)));
//         }

//         pub fn len(pointer: *anyopaque) *anyopaque {
//             const self: *Type = @ptrCast(@alignCast(pointer));
//             return self.len();
//         }
//     };
// }

// pub fn Mutatable(comptime Type: type) type {
//     return struct {
//         deinit: *const fn (pointer: *anyopaque, allocator: std.mem.Allocator) void,
//         sort: *const fn (pointer: *anyopaque, order: enum { asc, desc }) void,
//         unique: *const fn (pointer: *anyopaque, allocator: std.mem.Allocator) anyerror!void,

//         pub const Mutatable = struct {
//             pub fn deinit(pointer: *anyopaque, allocator: std.mem.Allocator) void {
//                 const self: *Type = @ptrCast(@alignCast(pointer));
//                 self.deinit(allocator);
//             }

//             pub fn sort(pointer: *anyopaque, allocator: std.mem.Allocator) ![]const u8 {
//                 const self: *Type = @ptrCast(@alignCast(pointer));
//                 return self.print(allocator);
//             }

//             pub fn unique(pointer: *anyopaque, allocator: std.mem.Allocator) ![]const u8 {
//                 const self: *Type = @ptrCast(@alignCast(pointer));
//                 return self.print(allocator);
//             }
//         };
//     };
// }

// pub fn Terminable(comptime Type: type) type {
//     return struct {
//         print: *const fn (pointer: *anyopaque, allocator: std.mem.Allocator) anyerror![]const u8,

//         pub fn print(pointer: *anyopaque, allocator: std.mem.Allocator) ![]const u8 {
//             const self: *Type = @ptrCast(@alignCast(pointer));
//             return self.print(allocator);
//         }
//     };
// }
