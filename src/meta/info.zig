const std = @import("std");

pub fn Info(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Pointer => return struct {
            const child = std.meta.Child(T);
        },
        .Union => return struct {
            pub fn FieldEnum() type {
                return std.meta.FieldEnum(T);
            }

            pub fn FieldType(comptime field: FieldEnum()) type {
                return std.meta.FieldType(T, field);
            }

            pub fn fieldName(comptime tag: FieldEnum()) []const u8 {
                return std.meta.fieldInfo(T, tag).name;
            }
        },
        .Struct => return struct {
            pub fn fields() []const std.builtin.Type.StructField {
                return std.meta.fields(T);
            }

            pub fn fieldCount() usize {
                return fields().len;
            }

            pub fn fieldNames() [fieldCount()][]const u8 {
                var field_names: [fieldCount()][]const u8 = undefined;
                inline for (fields(), 0..) |field, i| {
                    field_names[i] = field.name;
                }
                return field_names;
            }

            pub fn declarations() []const std.builtin.Type.Declaration {
                return @typeInfo(T).Struct.decls;
            }

            pub fn declarationCount() usize {
                return declarations().len;
            }

            pub fn declarationNames() [declarationCount()][]const u8 {
                var declaration_names: [declarationCount()][]const u8 = undefined;
                inline for (declarations(T), 0..) |declaration, i| {
                    declaration_names[i] = declaration.name;
                }
                return declaration_names;
            }

            // pub fn FieldEnum() type {
            //     return std.meta.FieldEnum(T);
            // }

            // pub fn FieldType(comptime field: FieldEnum()) type {
            //     return std.meta.FieldType(T, field);
            // }

            // pub fn fieldName(comptime tag: FieldEnum()) []const u8 {
            //     return std.meta.fieldInfo(T, tag).name;
            // }

            // const FieldEnum = std.meta.DeclEnum(T);

            // pub fn FieldType(comptime tag: FieldEnum) type {
            //     return @TypeOf(@field(T, @tagName(tag)));
            // }

            // pub fn hasFunction(comptime name: []const u8) bool {
            //     return std.meta.hasFn(T, name);
            // }
        },
        else => @compileError("unsupported type: " ++ @typeName(T)),
    }
}

test "union" {
    const Union = union {
        field_a: usize,
        field_b: isize,
        field_c: isize,
    };

    const UnionInfo = Info(Union);

    try std.testing.expectEqual(.field_a, UnionInfo.FieldEnum().field_a);
    try std.testing.expectEqual(.field_b, UnionInfo.FieldEnum().field_b);
    try std.testing.expectEqual(.field_c, UnionInfo.FieldEnum().field_c);

    try std.testing.expectEqual(usize, UnionInfo.FieldType(.field_a));
    try std.testing.expectEqual(isize, UnionInfo.FieldType(.field_b));
    try std.testing.expectEqual(isize, UnionInfo.FieldType(.field_c));

    try std.testing.expectEqualStrings("field_a", UnionInfo.fieldName(.field_a));
    try std.testing.expectEqualStrings("field_b", UnionInfo.fieldName(.field_b));
    try std.testing.expectEqualStrings("field_c", UnionInfo.fieldName(.field_c));
}

// test "struct" {
// comptime {
//     const Struct = struct {
//         const decl_a: usize = 1;
//         const decl_b: isize = 2;
//         const decl_c: isize = 3;
//         field_a: usize,
//         field_b: isize,
//         field_c: isize,
//         fn method_a() void {}
//         fn method_b(a: usize) usize {
//             return a;
//         }
//     };

//     const decls = std.meta.declarations(Struct)[0];
//     @compileLog(decls);
// }

// const StructInfo = Info(Struct);

// const field_names = StructInfo.fieldNames();
// try std.testing.expectEqual(3, StructInfo.fieldCount());
// try std.testing.expectEqualStrings("field_a", field_names[0]);
// try std.testing.expectEqualStrings("field_b", field_names[1]);
// try std.testing.expectEqualStrings("field_c", field_names[2]);

// std.debug.print("{any}", .{StructInfo.declarations()});
// // const declarations = StructInfo.fieldNames();
// // try std.testing.expectEqual(3, StructInfo.declarationCount());
// // try std.testing.expectEqualStrings("field_a", field_names[0]);
// // try std.testing.expectEqualStrings("field_b", field_names[1]);
// // try std.testing.expectEqualStrings("field_c", field_names[2]);
// }
