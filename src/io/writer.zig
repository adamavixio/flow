const std = @import("std");

pub fn Buffered(
    comptime WriterType: type,
    comptime buffer_size: usize,
    comptime skip_bytes: ?[]const u8,
    comptime skip_bytes_delimiter: ?[]const u8,
) type {
    if (buffer_size == 0) @compileError("Reader type 'Buffered' argument 'buffer_size' cannot be 0");

    return struct {
        const Self = @This();
        pub const write = if (skip_bytes) |_| writeSkip else writeDefault;

        dst: WriterType,
        pos: usize = 0,
        buffer: [buffer_size]u8 = undefined,
        skip_bytes: ?[]const u8 = skip_bytes,
        skip_bytes_delimiter: ?[]const u8 = skip_bytes_delimiter,

        pub fn flush(self: *Self) !void {
            try self.dst.writeAll(self.buffer[0..self.pos]);
            self.pos = 0;
        }

        fn writeDefault(self: *Self, src: []const u8) Error!usize {
            if (self.buffer.len < src.len) return self.dst.write(src);

            var len = self.pos + src.len;
            if (self.buffer.len < len) {
                try self.flush();
                len = src.len;
            }

            @memcpy(self.buffer[self.pos..len], src);
            self.pos = len;

            return src.len;
        }

        fn writeSkip(self: *Self, src: []const u8) Error!usize {
            var pos: usize = 0;
            var written: usize = 0;

            while (pos < src.len) {
                while (pos < src.len and self.contains(src[pos])) {
                    pos += 1;
                } else if (self.skip_bytes_delimiter) |delimiter| {
                    written += try self.writeDefault(delimiter);
                }

                var next_pos: usize = pos;
                while (next_pos < src.len and !self.contains(src[next_pos])) {
                    next_pos += 1;
                } else {
                    written += try self.writeDefault(src[pos..next_pos]);
                    pos = next_pos;
                }
            }

            return written;
        }

        fn contains(self: *Self, byte: u8) bool {
            if (self.skip_bytes) |skips| {
                for (skips) |skip| if (byte == skip) return true;
            }
            return false;
        }

        pub const Writer = std.io.Writer(*Self, Error, write);
        pub const Error = WriterType.Error;

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

pub fn buffered(
    writer: anytype,
    comptime buffer_size: usize,
    comptime skip_bytes: ?[]const u8,
    comptime skip_bytes_delimiter: ?[]const u8,
) Buffered(
    @TypeOf(writer),
    buffer_size,
    skip_bytes,
    skip_bytes_delimiter,
) {
    return .{ .dst = writer };
}

test "buffered" {
    {
        const input = "this - is - a - test -";
        var output: [100]u8 = undefined;
        const skip_bytes = [2]u8{ ' ', '-' };
        const skip_delimiter = [1]u8{'|'};

        var dst = std.io.fixedBufferStream(output[0..]);
        var writer = buffered(dst.writer(), 2, skip_bytes[0..], skip_delimiter[0..]);

        _ = try writer.write(input);
        try writer.flush();
        try std.testing.expectEqualStrings("this|is|a|test", dst.getWritten());
    }
}
