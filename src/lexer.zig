const std = @import("std");

const token = @import("./token.zig");
const readers = @import("./io/reader.zig");

pub fn Buffered(
    comptime ReaderType: type,
    comptime buffer_size: usize,
) type {
    if (buffer_size == 0) @compileError("Lexer type 'Buffered' argument 'buffer_size' cannot be 0");

    return struct {
        const Self = @This();

        src: ReaderType,
        len: usize = 0,
        left: usize = 0,
        middle: usize = 0,
        right: usize = 0,
        buffer: [buffer_size]u8 = undefined,

        pub fn next(self: *Self) !token.Token {
            if (self.len == 0) try self.read();
            if (self.right == self.len) return token.endOfFrame();

            try self.whitespace();
            if (self.right == self.len) return token.endOfFrame();

            switch (self.buffer[self.right]) {
                '0'...'9' => return try self.number(),
                else => {},
            }

            return try self.invalid();
        }

        fn whitespace(self: *Self) !void {
            while (self.right < self.len) : (self.right += 1) {
                const byte = self.buffer[self.right];
                switch (byte) {
                    ' ', '\n' => {},
                    else => return,
                }
            }
        }

        fn number(self: *Self) !token.Token {
            while (self.right < self.len) : (self.right += 1) {
                const byte = self.buffer[self.right];
                switch (byte) {
                    '0'...'9' => {
                        self.buffer[self.middle] = byte;
                        self.middle += 1;
                    },
                    else => break,
                }
            }
            return token.number(self.write());
        }

        fn invalid(self: *Self) !token.Token {
            while (self.right < self.len) : (self.right += 1) {
                const byte = self.buffer[self.right];
                switch (byte) {
                    ' ', '\n' => break,
                    '0'...'9' => break,
                    else => {
                        self.buffer[self.middle] = byte;
                        self.middle += 1;
                    },
                }
            }
            return token.invalid(self.write());
        }

        fn read(self: *Self) !void {
            self.len = try self.src.read(self.buffer[self.left..]);
        }

        fn write(self: *Self) []u8 {
            const data = self.buffer[self.left..self.middle];
            self.left = self.middle;
            return data;
        }
    };
}

pub fn buffered(reader: anytype, comptime buffer_size: usize) Buffered(@TypeOf(reader), buffer_size) {
    return .{ .src = reader };
}

test "lexer" {
    const input = "   123a45 a123a 12 ";

    var stream = std.io.fixedBufferStream(input);
    const reader = readers.buffered(stream.reader(), 100);
    var lexer = buffered(reader, 100);

    var i: usize = 0;
    var tokens: [10]token.Token = undefined;

    while (lexer.next()) |value| : (i += 1) {
        tokens[i] = value;
        if (value.is(token.Type.end_of_frame)) break;
    } else |err| {
        std.debug.print("Error: {any}", .{err});
    }

    for (tokens[0..i]) |value| {
        std.debug.print("ident: {any}, literal: '{s}'\n", .{ value.ident, value.literal });
    }
}
