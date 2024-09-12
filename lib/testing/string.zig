const std = @import("std");
const Suite = @import("suite.zig").Suite;

inline fn randomString(size: usize, selection: []const u8) []const u8 {
    var rng = std.rand.DefaultPrng.init(0);
    const random = rng.random();

    var result: [size]u8 = undefined;
    for (result, 0..) |_, i| {
        const byte = selection[random.intRangeLessThan(usize, 0, selection.len)];
        result[i] = byte;
    }

    return &result;
}

inline fn filterString(string: []const u8, remove: []const u8) []const u8 {
    var result: [string.len]u8 = undefined;

    var i: usize = 0;
    var j: usize = 0;

    for (string) |char| {
        result[i] = char;
        i += 1;
        if (char == remove[j]) {
            j += 1;
        } else {
            j = 0;
        }
        if (j == remove.len) {
            i -= j;
            j = 0;
        }
    }

    return result[0..i];
}

test "random string" {
    var suite = Suite(randomString).Static(2).init();
    try suite.case(.{ 0, "abc" }, "");
    try suite.case(.{ 10, "abc" }, "abbabaccaa");
    try suite.run();
}

test "filter string" {
    var suite = Suite(filterString).Static(4).init();
    try suite.case(.{ " a b c ", " " }, "abc");
    try suite.case(.{ "  a  b  c  ", "  " }, "abc");
    try suite.case(.{ "aaabc", "aa" }, "abc");
    try suite.case(.{ "abccc", "cc" }, "abc");
    try suite.run();
}
