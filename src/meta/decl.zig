const std = @import("std");

// pub fn Declaration(comptime Struct: type) bool {
//     if (@typeInfo(Struct) != Struct) {
//         @compileError("Parameter 'Struct' is not of type struct");
//     }

//     return struct {};
// }

// pub const function_names = blk: {
//     var size = 0;
//     for (@typeInfo(Self).Struct.fields) |field| {
//         if (std.mem.eql(field.name, "init")) continue;
//         if (std.mem.eql(field.name, "deinit")) continue;
//         if (@typeInfo(field.type) != .Fn) continue;
//         size += 1;
//     }

//     var index: usize = 0;
//     const names: [size][]const u8 = undefined;
//     for (@typeInfo(Self).Struct.fields) |field| {
//         if (std.mem.eql(field.name, "init")) continue;
//         if (std.mem.eql(field.name, "deinit")) continue;
//         if (@typeInfo(field.type) != .Fn) continue;
//         names[index] = field.name;
//         index += 1;
//     }

//     break :blk names;
// };
