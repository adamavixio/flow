const std = @import("std");
const core = @import("core.zig");

pub fn Mutatable(comptime Pointer: type, comptime Value: type) type {
    switch (@typeInfo(Value)) {
        .Int => return struct {
            const Self = @This();
            pub fn add(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value += value;
            }
            pub fn sub(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value -= value;
            }
            pub fn mul(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value *= value;
            }
            pub fn div(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value = @divTrunc(pointer.value, value);
            }
        },
        .Float => return struct {
            const Self = @This();
            pub fn add(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value += value;
            }
            pub fn sub(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value -= value;
            }
            pub fn mul(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value *= value;
            }
            pub fn div(self: *Self, value: Value) void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                pointer.value = @divTrunc(pointer.value, value);
            }
        },
        .Pointer => |info| switch (info.size) {
            .Slice => switch (info.child) {
                u8 => switch (info.is_const) {
                    true => return struct {
                        const Self = @This();
                    },
                    false => return struct {
                        const Self = @This();
                        pub fn upper(self: *Self) void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                            for (pointer.value) |*c| {
                                c.* = std.ascii.toUpper(c.*);
                            }
                        }
                        pub fn lower(self: *Self) void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("mutation", self));
                            for (pointer.value) |*c| {
                                c.* = std.ascii.toLower(c.*);
                            }
                        }
                    },
                },
                else => @compileError("unsupported slice type: " ++ @typeName(info.child)),
            },
            else => @compileError("unsupported pointer size: " ++ @typeName(info.size)),
        },
        else => @compileError("unsupported value type: " ++ @typeInfo(Value)),
    }
}

pub fn Transformable(comptime Pointer: type, comptime Value: type) type {
    switch (@typeInfo(Value)) {
        .Int => return struct {
            const Self = @This();
            pub fn string(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
                const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
                defer allocator.free(transform);
                return try core.FlowType.FromTag(.string).init(allocator, transform);
            }
        },
        .Float => return struct {
            const Self = @This();
            pub fn string(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
                const transform = try std.fmt.allocPrint(allocator, "{d}", .{pointer.value});
                defer allocator.free(transform);
                return try core.FlowType.FromTag(.string).init(allocator, transform);
            }
        },
        .Pointer => |info| switch (info.size) {
            .Slice => switch (info.child) {
                u8 => switch (info.is_const) {
                    true => return struct {
                        const Self = @This();
                        pub fn upper(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
                            var transform = try allocator.alloc(u8, pointer.value.len);
                            defer allocator.free(transform);
                            for (pointer.value, 0..) |c, i| {
                                transform[i] = std.ascii.toUpper(c);
                            }
                            return core.FlowType.FromTag(.string).init(allocator, transform);
                        }
                        pub fn lower(self: *Self, allocator: std.mem.Allocator) !*core.FlowType.FromTag(.string) {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("transform", self));
                            var transform = try allocator.alloc(u8, pointer.value.len);
                            defer allocator.free(transform);
                            for (pointer.value, 0..) |c, i| {
                                transform[i] = std.ascii.toLower(c);
                            }
                            return core.FlowType.FromTag(.string).init(allocator, transform);
                        }
                    },
                    false => return struct {},
                },
                else => @compileError("unsupported slice type: " ++ @typeName(info.child)),
            },
            else => @compileError("unsupported pointer size: " ++ @typeName(info.size)),
        },
        else => @compileError("unsupported value type: " ++ @typeInfo(Value)),
    }
}

pub fn Terminable(comptime Pointer: type, comptime Value: type) type {
    switch (@typeInfo(Value)) {
        .Int => return struct {
            const Self = @This();
            pub fn print(self: *Self) !void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
                std.debug.print(pointer.value);
            }
        },
        .Float => return struct {
            const Self = @This();
            pub fn print(self: *Self) !void {
                const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
                std.debug.print(pointer.value);
            }
        },
        .Pointer => |info| switch (info.size) {
            .Slice => switch (info.child) {
                u8 => switch (info.is_const) {
                    true => return struct {
                        const Self = @This();
                        pub fn print(self: *Self) !void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
                            std.debug.print(pointer.value);
                        }
                    },
                    false => return struct {
                        const Self = @This();
                        pub fn print(self: *Self) !void {
                            const pointer: *Pointer = @alignCast(@fieldParentPtr("terminal", self));
                            std.debug.print(pointer.value);
                        }
                    },
                },
                else => @compileError("unsupported slice type: " ++ @typeName(info.child)),
            },
            else => @compileError("unsupported pointer size: " ++ @typeName(info.size)),
        },
        else => @compileError("unsupported value type: " ++ @typeInfo(Value)),
    }
}
