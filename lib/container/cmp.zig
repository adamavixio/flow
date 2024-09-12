const std = @import("std");

pub inline fn equal(a: anytype, b: anytype) bool {
    const Type = @TypeOf(a, b);
    const Info = @typeInfo(Type);
    // @compileLog(Info);
    return switch (Info) {
        // Types
        //
        // Single Value
        //
        .Void => a == b,
        //
        // Multiple Value
        //
        .Type, .Bool, .Int, .ComptimeInt, .Float, .ComptimeFloat, .EnumLiteral => a == b,
        //
        // Special Value
        //
        .NoReturn, .Opaque, .Frame, .AnyFrame => @compileError("Invalid Type: " ++ @typeName(Type)),

        // Values
        //
        // Single
        //
        .Null => a == b,
        //
        // Multiple
        //
        .Enum => a == b,
        .Pointer => |pointer| blk: {
            break :blk switch (pointer.size) {
                .One, .Many, .C => a == b,
                .Slice => a.ptr == b.ptr and a.len == b.len,
            };
        },
        //
        // Special
        //
        .Undefined => @compileError("Invalid Type: " ++ @typeName(Type)),
        else => @compileError("Unsupported Type: {}" ++ @typeName(Type)),
    };
}

inline fn testMatrix(info: std.builtin.Type, values: []const @Type(info), function: anytype) !void {
    for (values) |a| for (values) |b| try function(a, b);
}

inline fn testEqual(a: anytype, b: anytype) anyerror!void {
    if (equal(a, b)) {
        try std.testing.expectEqual(a, b);
        return;
    }
    // try std.testing.expectError(
    //     error.TestExpectedEqual,
    //     std.testing.expectEqual(a, b),
    // );
}

test "equal" {
    // Type
    //
    // Single Value
    //
    {
        // Void
        try testMatrix(.Void, &.{{}}, testEqual);
    }
    //
    // Multiple Values
    //
    {
        // Bool
        try testMatrix(.Bool, &.{ false, true }, testEqual);

        // Int
        inline for ([_]type{ usize, u8, u16, u32, u64, u128, isize, i8, i16, i32, i64 }) |Type| {
            try testMatrix(@typeInfo(Type), &.{ 0, 1 }, testEqual);
            try testMatrix(@typeInfo(Type), &.{ std.math.minInt(Type), std.math.maxInt(Type) }, testEqual);
        }

        // Comptime Int
        // try testMatrix(comptime_int, &.{ 0, 1 }, testEqual);

        // Float
        inline for ([_]type{ f16, f32, f64, f128 }) |Type| {
            try testMatrix(@typeInfo(Type), &.{ 0, 1 }, testEqual);
            try testMatrix(@typeInfo(Type), &.{ -std.math.inf(Type), std.math.inf(Type) }, testEqual);
        }

        // Enum
        // const Enum = enum { a, b };
        // try testMatrix(@typeInfo(@TypeOf(.a)), &.{ .a, .b }, testEqual);
    }

    // Value
    //
    // Single
    //
    comptime {
        // Null
        try testMatrix(.Null, &.{null}, testEqual);
    }

    // // Value - Single
    // {
    //     // Null
    //     {
    //         const a: @TypeOf(null) = null;
    //         const b: @TypeOf(null) = null;
    //         try testEqual(a, a);
    //         try testEqual(a, b);
    //         try testEqual(b, a);
    //         try testEqual(b, b);
    //     }
    // }

    // //  Value - Multiple
    // {
    //     // Enum
    //     {
    //         const a = enum {};
    //         const b = enum {};
    //         try testEqual(a, a);
    //         try testEqual(a, b);
    //         try testEqual(b, a);
    //         try testEqual(b, b);
    //     }
    // }
}
