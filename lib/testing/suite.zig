const std = @import("std");

const SuiteError = error{
    OutOfMemory,
    OutOfBounds,
};

pub fn Unit(comptime TestType: anytype) type {
    return struct {
        pub fn static() Static(32) {
            return .{};
        }

        pub fn staticCapacity(comptime capacity: usize) Static(capacity) {
            return .{};
        }

        pub fn Static(comptime capacity: usize) type {
            return struct {
                const Self = @This();

                pub const Result = struct {
                    got: TestType,
                    exp: TestType,
                };

                i: usize = 0,
                len: usize = 0,
                results: [capacity]Result = undefined,

                pub fn case(self: *Self, exp: TestType, got: TestType) !void {
                    if (self.len == capacity) return SuiteError.OutOfMemory;
                    self.results[self.len].got = got;
                    self.results[self.len].exp = exp;
                    self.len += 1;
                }

                pub fn next(self: *Self) ?Result {
                    if (self.i == self.len) return null;
                    const result = self.results[self.i];
                    self.i += 1;
                    return result;
                }

                pub fn run(self: *Self) !void {
                    while (self.next()) |result| {
                        switch (TestType) {
                            []const u8 => try std.testing.expectEqualStrings(
                                result.got,
                                result.exp,
                            ),
                            else => try std.testing.expectEqualDeep(
                                result.got,
                                result.exp,
                            ),
                        }
                    }
                }
            };
        }
    };
}

pub fn Suite(comptime function: anytype) type {
    return struct {
        pub fn Static(comptime capacity: usize) type {
            return struct {
                const Self = @This();
                pub const Args = std.meta.ArgsTuple(@TypeOf(function));
                pub const Expect = @typeInfo(@TypeOf(function)).Fn.return_type.?;
                pub const Result = struct { got: Expect, exp: Expect };

                i: usize = 0,
                len: usize = 0,
                results: [capacity]Result = undefined,

                pub fn init() Self {
                    return .{};
                }

                pub inline fn case(self: *Self, args: Args, exp: Expect) !void {
                    if (self.len == capacity) return SuiteError.OutOfMemory;
                    self.results[self.len].got = @call(.auto, function, args);
                    self.results[self.len].exp = exp;
                    self.len += 1;
                }

                pub fn next(self: *Self) ?Result {
                    if (self.i == self.len) return null;
                    const result = self.results[self.i];
                    self.i += 1;
                    return result;
                }

                pub fn run(self: *Self) !void {
                    while (self.next()) |result| {
                        switch (Expect) {
                            []const u8 => try std.testing.expectEqualStrings(
                                result.got,
                                result.exp,
                            ),
                            else => try std.testing.expectEqualDeep(
                                result.got,
                                result.exp,
                            ),
                        }
                    }
                }
            };
        }

        pub const Dynamic = struct {
            const Self = @This();

            pub const Args = std.meta.ArgsTuple(@TypeOf(function));
            pub const Expect = @typeInfo(@TypeOf(function)).Fn.return_type.?;
            pub const Case = struct { args: Args, exp: Expect };
            pub const Result = struct { got: Expect, exp: Expect };

            i: usize = 0,
            cases: std.ArrayList(Case),

            pub fn init(allocator: std.mem.Allocator) Self {
                return .{ .cases = std.ArrayList(Case).init(allocator) };
            }

            pub fn deinit(self: *Self) void {
                self.cases.deinit();
            }

            pub fn case(self: *Self, args: Args, exp: Expect) !void {
                try self.cases.append(.{ .args = args, .exp = exp });
            }

            pub fn run(self: *Self) ?Result {
                if (self.i == self.cases.items.len) return null;
                const result = Result{
                    .got = @call(.auto, function, self.cases.items[self.i].args),
                    .exp = self.cases.items[self.i].exp,
                };
                self.i += 1;
                return result;
            }
        };
    };
}

test "unit" {
    const allocator = std.testing.allocator;

    const add = struct {
        fn func(a: i32, b: i32) i32 {
            return a + b;
        }
    }.func;

    {
        var suite = Suite(add).Static(2).init();
        try suite.case(.{ 1, 2 }, 3);
        try suite.case(.{ 2, 4 }, 6);
        try std.testing.expectError(SuiteError.OutOfMemory, suite.case(.{ 2, 4 }, 6));
        try suite.run();
    }

    {
        var suite = Suite(add).Dynamic.init(allocator);
        defer suite.deinit();
        try suite.case(.{ 1, 2 }, 3);
        try suite.case(.{ 2, 4 }, 6);
        while (suite.run()) |result| {
            try std.testing.expectEqual(result.exp, result.got);
        }
        try std.testing.expectEqual(null, suite.run());
    }
}
