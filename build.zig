const std = @import("std");

pub fn build(b: *std.Build) void {
    const config = Config{
        .default = .{
            .modules = &.{
                .{
                    .name = "flow",
                    .path = "lib/flow/root.zig",
                },
                .{
                    .name = "container",
                    .path = "lib/container/root.zig",
                },
                .{
                    .name = "math",
                    .path = "lib/math/root.zig",
                },
            },
            .executables = &.{
                .{
                    .name = "flow",
                    .path = "src/main.zig",
                },
            },
        },
    };

    const builder = Builder(config).init(b);

    const modules = Modules(config).init(builder);
    modules.link(.flow, &.{.{ .module = .container }});
    modules.link(.container, &.{.{ .module = .math }});

    const executables = Executables(config).init(builder);
    executables.link(.flow, modules, &.{.{ .module = .flow }});

    const artifacts = Artifacts(config).init(builder, executables);
    artifacts.installExecutables(&.{.flow});
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
            const Dep = struct { name: ?[]const u8 = null, module: Tag };

            modules: [d.modules.len]*std.Build.Module,

            fn init(builder: Builder(config)) Self {
                return .{
                    .modules = blk: {
                        var modules: [d.modules.len]*std.Build.Module = undefined;
                        for (d.modules, 0..) |m, i| {
                            modules[i] = builder.build.addModule(m.name, .{
                                .root_source_file = builder.build.path(m.path),
                                .target = builder.target,
                                .optimize = builder.optimize,
                            });
                        }
                        break :blk modules;
                    },
                };
            }

            fn get(self: Self, tag: Tag) *std.Build.Module {
                return switch (tag) {
                    inline else => |t| self.modules[@intFromEnum(t)],
                };
            }

            fn link(self: Self, module: Tag, targets: []const Dep) void {
                var source = self.get(module);
                for (targets) |target| source.addImport(
                    target.name orelse @tagName(target.module),
                    self.get(target.module),
                );
            }
        },
    };
}

inline fn Executables(comptime config: Config) type {
    return switch (config) {
        inline .default => |d| struct {
            const Self = @This();

            const Tag = Generate.Enum(d.executables).Map(.name);
            const Dep = struct { name: ?[]const u8 = null, module: Modules(config).Tag };

            executables: [d.executables.len]*std.Build.Step.Compile,

            fn init(builder: Builder(config)) Self {
                return .{
                    .executables = blk: {
                        var executables: [d.executables.len]*std.Build.Step.Compile = undefined;
                        for (d.executables, 0..) |e, i| {
                            executables[i] = builder.build.addExecutable(.{
                                .name = e.name,
                                .root_source_file = builder.build.path(e.path),
                                .target = builder.target,
                                .optimize = builder.optimize,
                            });
                        }
                        break :blk executables;
                    },
                };
            }

            fn get(self: Self, tag: Tag) *std.Build.Step.Compile {
                return switch (tag) {
                    inline else => |t| self.executables[@intFromEnum(t)],
                };
            }

            fn link(self: Self, executable: Tag, modules: Modules(config), targets: []const Dep) void {
                var source = self.get(executable).root_module;
                for (targets) |target| source.addImport(
                    target.name orelse @tagName(target.module),
                    modules.get(target.module),
                );
            }
        },
    };
}

inline fn Artifacts(comptime config: Config) type {
    return switch (config) {
        inline .default => struct {
            const Self = @This();

            builder: Builder(config),
            executables: Executables(config),

            fn init(builder: Builder(config), executables: Executables(config)) Self {
                return .{
                    .builder = builder,
                    .executables = executables,
                };
            }

            fn installExecutables(self: Self, tags: []const Executables(config).Tag) void {
                for (tags) |tag| self.builder.build.installArtifact(
                    self.executables.get(tag),
                );
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
