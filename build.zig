const std = @import("std");

pub fn build(b: *std.Build) void {
    const config = Config{
        .default = .{
            .modules = &.{
                .{ .name = "flow", .path = "lib/flow/root.zig" },
                .{ .name = "container", .path = "lib/container/root.zig" },
                .{ .name = "math", .path = "lib/math/root.zig" },
            },
            .executables = &.{
                .{ .name = "flow", .path = "src/main.zig" },
            },
        },
    };

    const builder = Builder(config).init(b);
    const modules = Modules(config).init(builder);
    std.debug.print("{}", .{modules.get(.flow)});
    // const executables = Executables(config).init(builder);
    // modules.link(.flow, .{ .module = .container });
    // modules.link(.container, .{ .module = .math });
    // executables.link(.flow, .{ .module = .flow });

    // const modules = Modules(config).init();
    // const executables = Executables(config).init(modules.);
    // Tests(config).init(executables, modules);
}

const Mode = enum {
    default,
};

const Config = union(Mode) {
    default: struct {
        const Type = struct {
            name: [:0]const u8,
            path: []const u8,
        };

        modules: []const Type,
        executables: []const Type,
    },
};

inline fn Builder(comptime config: Config) type {
    return switch (config) {
        .default => struct {
            const Self = @This();

            build: *std.Build,
            target: std.Build.ResolvedTarget,
            optimize: std.builtin.OptimizeMode,

            fn init(b: *std.Build) Self {
                return .{
                    .build = b,
                    .target = b.standardTargetOptions(.{}),
                    .optimize = b.standardOptimizeOption(.{}),
                };
            }
        },
    };
}

inline fn Modules(comptime config: Config) type {
    return switch (config) {
        inline .default => |d| struct {
            const Self = @This();
            const Tag = Generate.Enum(d.modules).Map(.name);

            builder: Builder(config),
            modules: []?*std.Build.Module = undefined,

            fn init(builder: Builder(config)) Self {
                return .{ .builder = builder };
            }

            pub fn get(self: Self, tag: Tag) *std.Build.Module {
                const i = @intFromEnum(tag);
                if (self.modules[i] == null) {
                    self.modules[i] = self.builder.build.addModule(d.modules[i].name, .{
                        .root_source_file = self.builder.build.path(d.modules[i].path),
                        .target = self.builder.target,
                        .optimize = self.builder.optimize,
                    });
                }
                return self.modules[i].?;
            }
        },
    };
}

inline fn Executables(comptime config: Config) type {
    return switch (config) {
        inline .default => |d| struct {
            const Self = @This();
            const Tag = Generate.Enum(d.modules).Map(.name);

            builder: Builder(config),
            executables: []?*std.Build.Compile.Step = undefined,

            fn init(builder: Builder(config)) Self {
                return .{ .builder = builder };
            }

            pub fn get(self: Self, tag: Tag) *std.Build.Step.Compile {
                const i = @intFromEnum(tag);
                if (self.executables[i] == null) {
                    self.executables[i] = self.builder.build.addModule(d.executables[i].name, .{
                        .root_source_file = self.builder.build.path(d.executables[i].path),
                        .target = self.builder.target,
                        .optimize = self.builder.optimize,
                    });
                }
                return self.executables[i].?;
            }
        },
    };
}

// inline fn Tests(comptime config: Config) type {
//     return switch (config) {
//         inline .default => |d| struct {
//             const Self = @This();
//             const ModulesType = Modules(config);
//             const ExecutablesType = Executables(config);

//             const Unit = union(enum) {
//                 module: ModulesType.Type,
//                 executable: ExecutablesType.Type,
//             };

//             modules: ModulesType,
//             executables: ExecutablesType,

//             pub fn init(modules: ModulesType, executables: ExecutablesType) Self {
//                 return .{
//                     .modules = modules,
//                     .executables = executables,
//                 };
//             }
//         },
//     };
// }

// fn Iterator(comptime Input: type) type {
//     return struct {
//         fn Map(comptime Output: type) type {

//         }
//         const self = @This();

//         fn init(slice: []T)
//     }
// }

const Generate = struct {
    fn Enum(comptime from: anytype) type {
        if (Meta(from).Iterable()) |iterable| {
            return switch (@typeInfo(iterable)) {
                .Struct => struct {
                    fn Map(field_name: std.meta.FieldEnum(iterable)) type {
                        const field_type = std.meta.FieldType(iterable, field_name);
                        if (Meta(field_type).Iterable()) |element| {
                            if (Meta(element).is(u8)) {
                                return @Type(.{
                                    .Enum = .{
                                        .tag_type = std.math.IntFittingRange(0, from.len - 1),
                                        .fields = blk: {
                                            var enum_fields: [from.len]std.builtin.Type.EnumField = undefined;
                                            for (from, 0..) |f, i| {
                                                enum_fields[i] = .{
                                                    .name = @field(f, @tagName(field_name)),
                                                    .value = i,
                                                };
                                            }
                                            break :blk &enum_fields;
                                        },
                                        .decls = &.{},
                                        .is_exhaustive = true,
                                    },
                                });
                            }
                        }
                    }
                },
                else => @compileError("Generate Enum: Unsupported iterable type '" ++ @typeName(iterable) ++ "'"),
            };
        } else {
            @compileError("Generate Enum: Unsupported non-iterable type '" ++ Meta(from).name ++ "'");
        }
    }
};

pub fn Meta(comptime value: anytype) type {
    return struct {
        pub const Type = if (@TypeOf(value) != type) @TypeOf(value) else value;
        pub const type_name = @typeName(Type);
        pub const type_info = @typeInfo(Type);

        pub fn Iterable() ?type {
            return switch (type_info) {
                .Array => |info| info.child,
                .Vector => |info| info.child,
                .Pointer => |info| switch (info.size) {
                    .C => info.child,
                    .Many => info.child,
                    .Slice => info.child,
                    .One => switch (@typeInfo(info.child)) {
                        .Array => |child_info| child_info.child,
                        .Vector => |child_info| child_info.child,
                        else => null,
                    },
                },
                .Optional => Meta(type_info.child).Core.Iterable(),
                else => null,
            };
        }

        pub fn is(comptime Value: type) bool {
            return switch (Type) {
                else => Type == Value,
            };
        }

        pub fn iterable() ?std.builtin.Type {
            return switch (type_info) {
                .Array => |info| info,
                .Vector => |info| info,
                .Pointer => |info| switch (info.size) {
                    .C => info,
                    .Many => info,
                    .Slice => info,
                    .One => switch (@typeInfo(info.child)) {
                        .Array => |child_info| child_info,
                        .Vector => |child_info| child_info,
                        else => null,
                    },
                },
                .Optional => Meta(type_info.child).Info.Iterable(),
                else => null,
            };
        }
    };
}

// test "info" {
//     const array = [_]u8{};
//     std.testing.expect(std.meta.eql(.Array, Meta(array).Info.iterable().?));
// }

// fn generate(comptime tags: [][]const u8, ) type {
//     switch (@typeInfo(@TypeOf(fields))) {
//         .Pointer => |p| if (p.size != .Slice) {
//             @compileError("Fields must be a slice");
//         },
//         else => @compileError("Fields must be a slice"),
//     }
//     return @Type(.{
//         .Enum = .{
//             .tag_type = std.math.IntFittingRange(0, fields.len - 1),
//             .fields = blk: {
//                 var enum_fields: [fields.len]std.builtin.Type.EnumField = undefined;
//                 for (fields, 0..) |field, i| {
//                     if (!@hasField(@TypeOf(field), "name")) {
//                         @compileError("Field must have a 'name' field");
//                     }
//                     enum_fields[i] = .{ .name = @field(field, "name"), .value = i };
//                 }
//                 break :blk &enum_fields;
//             },
//             .decls = &.{},
//             .is_exhaustive = true,
//         },
//     });
// }

// fn generateEnum(comptime fields: ) type {
//     switch (@typeInfo(@TypeOf(fields))) {
//         .Pointer => |p| if (p.size != .Slice) {
//             @compileError("Fields must be a pointer of type slice");
//         },
//         else => @compileError("Fields must be a pointer of type slice"),
//     }
//     return @Type(.{
//         .Enum = .{
//             .tag_type = std.math.IntFittingRange(0, fields.len - 1),
//             .fields = blk: {
//                 var enum_fields: [fields.len]std.builtin.Type.EnumField = undefined;
//                 for (fields, 0..) |field, i| {
//                     if (!@hasField(@TypeOf(field), "name")) {
//                         @compileError("Field must have a 'name' field");
//                     }
//                     enum_fields[i] = .{ .name = @field(field, "name"), .value = i };
//                 }
//                 break :blk &enum_fields;
//             },
//             .decls = &.{},
//             .is_exhaustive = true,
//         },
//     });
// }

// pub const Modules(comptime mode) type {
//     return struct {
//         const Self = @This();

//         flow: *std.Build.Module = config.build.addModule("flow", .{
//             .root_source_file = config.build.path("lib/flow/root.zig"),
//             .target = config.target,
//             .optimize = config.optimize,
//         }),

//         container:*std.Build.Module = config.build.addModule("container", .{
//             .root_source_file = config.build.path("lib/container/root.zig"),
//             .target = config.target,
//             .optimize = config.optimize,
//         }),

//          math: *std.Build.Module = config.build.addModule("math", .{
//             .root_source_file = config.build.path("lib/math/root.zig"),
//             .target = config.target,
//             .optimize = config.optimize,
//         }),

//         fn init() Self {
//             flow.addImport(container);
//             container.addImport(math);
//             return .{};
//         }
//     };
// }

// fn Executables(config: Config) type {
//     return struct {
//         const Self = @This();

//         const flow = config.build.addExecutable(.{
//             .name = "flow",
//             .root_source_file = config.build.path("src/main.zig"),
//             .target = config.target,
//             .optimize = config.optimize,
//         });

//         fn init(modules: []*std.Build.Module) Self {
//             const root = flow.root_module;
//             for (modules) |m| root.addImport(m);
//             config.build.installArtifact(flow);
//             return .{};
//         }
//     };
// }

// fn Tests(config: Config) type {
//     return struct {
//         const flow = config.build.addTest(.{
//             .root_source_file = config.build.path("lib/flow/root.zig"),
//             .target = config.target,
//             .optimize = config.optimize,
//         });

//         const container = config.build.addTest(.{
//             .root_source_file = config.build.path("lib/flow/root.zig"),
//             .target = config.target,
//             .optimize = config.optimize,
//         });

//         const math = config.build.addTest(.{
//             .root_source_file = config.build.path("lib/math/root.zig"),
//             .target = config.target,
//             .optimize = config.optimize,
//         });
//     };
// }

// fn Steps(config: Config) type {
//     return struct {
//         const tests = config.build.step("test", "Run unit tests");

//         fn init(executables: Executables(config), modules: Modules(config)) void {
//             unit_test.dependOn(b.addRunArtifact(&Tests.flow.step));
//             unit_test.dependOn(b.addRunArtifact(&Tests.container.step));
//             unit_test.dependOn(b.addRunArtifact(&Tests.math.step));
//         }
//     };
// }
