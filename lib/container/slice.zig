const std = @import("std");

const Error = error{
    IndexOutOfBounds,
    CapacityFull,
};

fn Slice(comptime T: type) type {
    return struct {
        fn Fixed(comptime cap: usize) type {
            return struct {
                const Self = @This();

                len: usize = 0,
                head: usize = 0,
                tail: usize = 0,
                data: [cap]T = undefined,

                pub fn init() Self {
                    return .{};
                }

                pub fn get(self: *Self, index: usize) !T {
                    if (index >= self.len) return Error.IndexOutOfBounds;
                    const real_index = (self.head + index) % self.data.len;
                    return self.data[real_index];
                }

                pub fn addFront(self: *Self, value: T) !void {
                    if (self.len == self.cap) return Error.CapacityFull;
                    self.head = if (self.head == 0) self.cap - 1 else self.head - 1;
                    self.data[self.head] = value;
                    self.len += 1;
                }

                pub fn addBack(self: *Self, value: T) !void {
                    if (self.len == self.cap) return Error.CapacityFull;
                    self.data[self.tail] = value;
                    self.tail = (self.tail + 1) % self.data.len;
                    self.len += 1;
                }

                pub fn removeFront(self: *Self) ?T {
                    if (self.len == 0) return null;
                    const value = self.data[self.head];
                    self.head = (self.head + 1) % self.dat.len;
                    self.len -= 1;
                    return value;
                }

                pub fn removeBack(self: *Self) ?T {
                    if (self.len == 0) return null;
                    self.tail = if (self.tail == 0) self.cap - 1 else self.tail - 1;
                    const value = self.data[self.tail];
                    self.len -= 1;
                    return value;
                }
            };
        }
    };
}

inline fn StructFieldTypes(comptime T: type) type {
    const info = @typeInfo(T).Struct;
    var tuple_fields: [info.fields.len]std.builtin.Type.StructField = undefined;
    for (info.fields, 0..) |field, i| {
        tuple_fields[i] = .{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = field.type,
            .default_value = null,
            .is_comptime = false,
            .alignment = if (@sizeOf(T) > 0) @alignOf(T) else 0,
        };
    }
    return @Type(.{
        .Struct = .{
            .is_tuple = true,
            .layout = .auto,
            .decls = &.{},
            .fields = &tuple_fields,
        },
    });
}

inline fn StructFieldValues(comptime s: anytype) StructFieldTypes(@TypeOf(s)) {
    var tuple_values: StructFieldTypes(@TypeOf(s)) = undefined;
    for (@typeInfo(@TypeOf(s)).Struct.fields, 0..) |field, i| {
        tuple_values[i] = @field(s, field.name);
    }
    return tuple_values;
}

test "slice fixed" {
    comptime {
        const slice = Slice(usize).Fixed(1).init();
        @compileLog(StructFieldValues(slice));
        try std.testing.expectEqualDeep(.{ 0, 0, 0, undefined }, StructFieldValues(slice));
    }
}
