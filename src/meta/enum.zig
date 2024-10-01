const std = @import("std");

pub inline fn fieldNamesWithPrefix(comptime Enum: type, comptime prefix: []const u8) []const []const u8 {
    comptime {
        if (@typeInfo(Enum) != .Enum) {
            @compileError("parameter 'Enum' must be an enum type");
        }

        var size: usize = 0;
        for (std.meta.fields(Enum)) |field| {
            if (std.mem.startsWith(u8, field.name, prefix)) {
                size += 1;
            }
        }

        var index: usize = 0;
        var result: [size][]const u8 = undefined;
        for (std.meta.fields(Enum)) |field| {
            if (std.mem.startsWith(u8, field.name, prefix)) {
                result[index] = field.name[prefix.len..];
                index += 1;
            }
        }

        return &result;
    }
}

test "fieldNamesWithPrefix" {
    const Test = enum { zero, prefix_one, prefix_two, three };
    const field_names = fieldNamesWithPrefix(Test, "prefix_");
    try std.testing.expectEqual(field_names.len, 2);
    try std.testing.expectEqualStrings("one", field_names[0]);
    try std.testing.expectEqualStrings("two", field_names[1]);
}
