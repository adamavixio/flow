const std = @import("std");

pub fn Buffered(
    comptime ReaderType: type,
    comptime buffer_size: usize,
) type {
    if (buffer_size == 0) @compileError("Reader type 'Buffered' argument 'buffer_size' cannot be 0");

    return struct {
        const Self = @This();

        src: ReaderType,
        left: usize = 0,
        right: usize = 0,
        buffer: [buffer_size]u8 = undefined,

        pub fn read(self: *Self, dst: []u8) Error!usize {
            var pos: usize = 0;

            while (pos < dst.len) {
                if (self.left == self.right) {
                    self.left = 0;
                    self.right = try self.src.read(self.buffer[0..]);
                }

                const len = @min(self.right - self.left, dst.len - pos);
                if (len == 0) return pos;

                @memcpy(dst[pos..][0..len], self.buffer[self.left..][0..len]);
                pos += len;
                self.left += len;
            }

            return pos;
        }

        pub const Reader = std.io.Reader(*Self, Error, read);
        pub const Error = ReaderType.Error;

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn buffered(reader: anytype, comptime buffer_size: usize) Buffered(@TypeOf(reader), buffer_size) {
    return .{ .src = reader };
}

test "buffered" {
    {
        const steps = [5]usize{ 1, 5, 10, 15, 20 };

        inline for (steps) |dst_size| {
            inline for (steps) |buffer_size| {
                const input = "this is a test";

                var src = std.io.fixedBufferStream(input);
                var dst = std.mem.zeroes([dst_size]u8);
                var reader = buffered(src.reader(), buffer_size);

                var n: usize = 0;
                var w: usize = 0;

                while (true) {
                    n = try reader.read(dst[0..]);
                    if (n == 0) break;
                    try std.testing.expectEqualStrings(input[w..][0..n], dst[0..n]);
                    w += n;
                }

                try std.testing.expectEqual(input.len, w);
            }
        }
    }
}
