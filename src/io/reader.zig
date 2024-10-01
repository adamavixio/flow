const std = @import("std");

const File = @import("file.zig");

pub const Error = error{
    TypeInvalid,
    ReadSizeMismatch,
    IndexOutOfBounds,
};

pub fn Buffer(comptime capacity: usize) type {
    // switch (Source) {
    //     []const u8 => {},
    //     File => {},
    //     else => @compileError("Parameter 'Source' must be either '[]const u8' or 'File'"),
    // }
    return struct {
        const Self = @This();

        // pub const Config = switch (tag) {
        //     .string => struct { string: []const u8 },
        //     .file => struct { path: []const u8 },
        // };

        left: usize = 0,
        right: usize = 0,
        buffer: [capacity]u8 = undefined,
        // offset: usize = 0,
        // source: switch (tag) {
        //     .string => []const u8,
        //     .file => File,
        // },

        pub fn init(source: []const u8) !Self {
            var self = Self{};
            std.mem.copyForwards(u8, &self.buffer, source);
            // var self = Self{};
            // switch (Source) {
            //     []const u8 => std.mem.copyForwards(u8, &self.buffer, source),
            //     File => try source.read(self.buffer),
            //     else => Error.TypeInvalid,
            // }
            return self;
        }

        pub fn skip(self: *Self) void {
            self.left = self.right;
        }

        pub fn shiftLeft(self: *Self) void {
            self.left += 1;
            self.right = @max(self.left, self.right);
        }

        pub fn shiftRight(self: *Self) void {
            self.right += 1;
        }

        pub fn peek(self: Self) []const u8 {
            return self.buffer[self.left..self.right];
        }

        pub fn peekLeft(self: Self) u8 {
            return self.buffer[self.left];
        }

        pub fn peekRight(self: Self) u8 {
            return self.buffer[self.right];
        }

        pub fn equal(self: Self, string: []const u8) bool {
            return std.mem.eql(u8, self.peek(), string);
        }

        pub fn equalLeft(self: Self, character: u8) bool {
            return self.peekLeft() == character;
        }

        pub fn equalRight(self: Self, character: u8) bool {
            return self.peekRight() == character;
        }

        pub fn read(self: Self, destination: []u8) usize {
            const size = @min(destination.len, self.right - self.left);
            @memcpy(destination[0..], self.buffer[self.left .. self.left + size]);
            self.left += size;
            return size;
        }
    };
}

test "string" {
    var source = try Buffer(1024).init("test");
    try std.testing.expectEqualStrings("", source.peek());
    try std.testing.expectEqual('t', source.peekLeft());
    try std.testing.expectEqual('t', source.peekRight());
    try std.testing.expect(source.equal(""));
    try std.testing.expect(source.equalLeft('t'));
    try std.testing.expect(source.equalRight('t'));

    source.shiftRight();
    try std.testing.expectEqualStrings("t", source.peek());
    try std.testing.expectEqual('t', source.peekLeft());
    try std.testing.expectEqual('e', source.peekRight());
    try std.testing.expect(source.equal("t"));
    try std.testing.expect(source.equalLeft('t'));
    try std.testing.expect(source.equalRight('e'));

    source.shiftRight();
    try std.testing.expectEqualStrings("te", source.peek());
    try std.testing.expectEqual('t', source.peekLeft());
    try std.testing.expectEqual('s', source.peekRight());
    try std.testing.expect(source.equal("te"));
    try std.testing.expect(source.equalLeft('t'));
    try std.testing.expect(source.equalRight('s'));

    source.shiftRight();
    try std.testing.expectEqualStrings("tes", source.peek());
    try std.testing.expectEqual('t', source.peekLeft());
    try std.testing.expectEqual('t', source.peekRight());
    try std.testing.expect(source.equal("tes"));
    try std.testing.expect(source.equalLeft('t'));
    try std.testing.expect(source.equalRight('t'));

    source.shiftRight();
    try std.testing.expectEqualStrings("test", source.peek());
    try std.testing.expectEqual('t', source.peekLeft());
    try std.testing.expect(source.equal("test"));
    try std.testing.expect(source.equalLeft('t'));
}

// test "file" {
//     const path = "tmp/test.txt";
//     const file = try File.createWithContent(path, "test");
//     defer file.delete();

//     var source = try initFile(path);
//     defer source.deinit();

//     try std.testing.expectEqual(0, source.buffer[buffer.len]);
//     try std.testing.expectEqualStrings("Test String", source.buffer);

//     for (buffer, 0..) |char, i| try std.testing.expectEqual(char, source.peek(i));
//     try std.testing.expectEqualStrings("", source.peekSize(0, 0));
//     try std.testing.expectEqualStrings("Test String", source.peekSize(0, 11));
//     try std.testing.expectEqualStrings("", source.peekRange(0, 0));
//     try std.testing.expectEqualStrings("Test String", source.peekRange(0, 11));

//     for (buffer, 0..) |char, i| try std.testing.expect(source.match(i, char));
//     try std.testing.expect(source.matchSize(0, 0, ""));
//     try std.testing.expect(source.matchSize(0, 11, "Test String"));
//     try std.testing.expect(source.matchRange(0, 0, ""));
//     try std.testing.expect(source.matchRange(0, 11, "Test String"));
// }
