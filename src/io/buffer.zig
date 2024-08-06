const std = @import("std");

pub const Error = error{ Empty, Full };

pub fn Fixed(comptime size: usize) type {
    if (size == 0) @compileError("Fixed buffer size cannot be 0");

    return struct {
        const Self = @This();

        left: usize = 0,
        right: usize = 0,
        data: [size]u8 = undefined,

        pub fn read(self: *Self, dst: []u8) !usize {
            if (self.len == 0) return Error.Empty;

            const num_bytes = @min(self.len, dst.len);
            const next_left = self.left + num_bytes;

            @memcpy(dst[0..num_bytes], self.buffer[self.left..next_left]);

            self.len = self.right - next_left;
            self.left = next_left;

            return num_bytes;
        }

        pub fn write(self: *Self, src: std.io.AnyReader) !usize {
            if (self.cap == 0) return Error.Full;

            const num_bytes = try src.read(self.buffer[self.len..]);
            const next_right = self.right + num_bytes;

            self.len = next_right - self.left;
            self.cap = size - next_right;
            self.right = next_right;

            return num_bytes;
        }
    };
}

pub fn fixed(comptime size: usize) Fixed(size) {
    return Fixed(size){};
}
