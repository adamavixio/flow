const std = @import("std");
const seq = @import("./seq.zig");

pub fn Function(comptime Value: type) type {
    switch (@typeInfo(Value)) {
        .Int => |info| switch (info.signedness) {
            .unsigned => return struct {
                const Self = @This();

                const Operation = union(enum) {
                    add: struct { value: u64 },
                    mul: struct { value: u64 },
                    mod: struct { value: u64 },
                };

                operations: []const Operation,

                pub fn hash(self: Self, value: Value) u64 {
                    var result: u64 = value;
                    for (self.operations) |operation| {
                        switch (operation) {
                            .id => struct {},
                            .add => |o| result += o.value,
                            .mul => |o| result *= o.value,
                            .mod => |o| result %= o.value,
                        }
                    }
                    return result;
                }
            },
            else => {},
        },
        .Pointer => |info| switch (info.size) {
            .Slice => switch (@typeInfo(info.child)) {
                .Int => |child_info| switch (child_info.signedness) {
                    .unsigned => return struct {
                        const Self = @This();

                        const Operation = union(enum) {
                            id: struct {},
                            add: struct { value: u64 },
                            mul: struct { value: u64 },
                            mod: struct { value: u64 },
                        };

                        element: ?Function(info.child) = null,
                        operations: []const Operation,

                        pub fn hash(self: Self, value: Value) u64 {
                            var result: u64 = ;
                            for (self.operations) |operation| {

                                switch (operation) {
                                    .add => |o| result += o.value,
                                    .mul => |o| result *= o.value,
                                    .mod => |o| result %= o.value,
                                }
                            }
                            return result;
                        }
                    },
                    else => {},
                },
                else => {},
            },
            else => {},
        },
        else => {},
    }
    @compileError("type '" ++ @typeName(Value) ++ "' not supported");
}

// pub fn Chain(comptime Value: type) type {
//     return struct {
//         const Self = @This();

//         funcs: []const Func(Value),

//         pub fn init(funcs: []const Func(Value)) Self {
//             return .{ .funcs = funcs };
//         }

//         pub fn hash(self: Self, value: Value) u64 {
//             var value: u64 = value;
//             for (self.funcs) |func| value = func.hash(@intCast(value));
//             return value;
//         }
//     };
// }

// pub fn initChain(comptime Value: type, comptime params: []Param) Chain(Value) {
//     return Chain(Value).init(params);
// }

test "hash function" {
    {
        const function = Function(usize){
            .operations = &.{
                .{ .id = .{} },
                .{ .add = .{ .value = 1 } },
                .{ .mul = .{ .value = 2 } },
                .{ .mod = .{ .value = 3 } },
            },
        };

        try std.testing.expectEqual(2, function.hash(0));
        try std.testing.expectEqual(1, function.hash(1));
        try std.testing.expectEqual(0, function.hash(2));
        try std.testing.expectEqual(2, function.hash(3));
        try std.testing.expectEqual(1, function.hash(4));
        try std.testing.expectEqual(0, function.hash(5));
    }

    // {
    //     const function = Func(usize){ .modulus = .{ .n = 2 } };
    //     try std.testing.expectEqual(0, function.hash(0));
    //     try std.testing.expectEqual(1, function.hash(1));
    //     try std.testing.expectEqual(0, function.hash(2));
    //     try std.testing.expectEqual(1, function.hash(3));
    //     try std.testing.expectEqual(0, function.hash(4));
    // }

    // {
    //     const function = Func(usize){ .multiplicative = .{ .m = 2 } };
    //     try std.testing.expectEqual(0, function.hash(0));
    //     try std.testing.expectEqual(2, function.hash(1));
    //     try std.testing.expectEqual(4, function.hash(2));
    //     try std.testing.expectEqual(6, function.hash(3));
    //     try std.testing.expectEqual(8, function.hash(4));
    // }

    // {
    //     const function = Func([]const u8){ .identity = .{} };
    //     try std.testing.expectEqual(97, function.hash("a"));
    //     try std.testing.expectEqual(98, function.hash("b"));
    //     try std.testing.expectEqual(195, function.hash("ab"));
    // }

    // {
    //     const function = Func([]const u8){ .positional = .{} };
    //     try std.testing.expectEqual(97, function.hash("a"));
    //     try std.testing.expectEqual(98, function.hash("b"));
    //     try std.testing.expectEqual(293, function.hash("ab"));
    // }
}

// test "hash function chain" {
//     {
//         const function = Chain(u8).init(&[_]Func(u8){
//             Func(u8){ .multiplicative = .{ .m = 3 } },
//             Func(u8){ .modulus = .{ .n = 2 } },
//         });
//         try std.testing.expectEqual(0, function.hash(0));
//         try std.testing.expectEqual(1, function.hash(1));
//         try std.testing.expectEqual(0, function.hash(2));
//     }
// }

// pub fn Perfect(comptime K: type, comptime n: u64) type {
//     return struct {
//         const Self = @This();

//         k: u64,
//         prime: u64,

//         pub fn init(values: [n]K) Self {
//             const k: u64, const prime: u64 = blk: {};
//             return .{ .k = k, .prime = prime };
//         }

//         pub fn hash(self: Self, value: K) u64 {
//             var value: u64 = 0;
//             switch (@typeInfo(value)) {
//                 .Int =>
//                 .Array => |info| {
//                     switch(@typeInfo(info.child)) {
//                         .Number =>
//                     }
//                 }
//             }
//         }
//     };
// }
