const std = @import("std");
const comp = @import("comp.zig");

pub fn Select(comptime Element: type) type {
    return struct {
        const Match = enum {
            exclude,
            include,
        };

        const Selector = struct {
            match: Match,
            condition: comp.Condition(Element),
            target: Element,
        };

        pub fn Fixed(comptime size: usize) type {
            return struct {
                const Self = @This();

                mask: std.bit_set.StaticBitSet(size),
                elements: []const Element,

                pub fn collect(comptime self: Self) [self.mask.count()]Element {
                    var index: usize = 0;
                    var selected: [self.mask.count()]Element = undefined;
                    for (0..size) |i| {
                        if (self.mask.isSet(i)) {
                            selected[index] = self.elements[i];
                            index += 1;
                        }
                    }
                    return selected;
                }
            };
        }

        pub inline fn init(comptime elements: []const Element, comptime selectors: []const Selector) Fixed(elements.len) {
            comptime {
                var mask = std.bit_set.IntegerBitSet(elements.len).initFull();
                for (selectors) |selector| {
                    for (elements, 0..) |element, i| {
                        const is_match = switch (selector.operation) {
                            .has_prefix => std.mem.startsWith(Child, element, selector.value),
                            .has_suffix => std.mem.endsWith(Child, element, selector.value),
                        };
                        const should_set = switch (selector.match) {
                            .include => mask.isSet(i) or is_match,
                            .exclude => mask.isSet(i) and !is_match,
                        };
                        switch (should_set) {
                            true => mask.set(i),
                            false => mask.unset(i),
                        }
                    }
                }
                return Fixed(elements.len){
                    .mask = mask,
                    .elements = elements,
                };
            }
        }
    };
}

test "Select with strings - basic include and exclude" {
    const selected = Select([]const u8).init(&.{ "apple", "banana", "cherry", "date" }, &.{
        .{ .match = .include, .condition = .has_prefix, .target = "a" },
        .{ .match = .exclude, .condition = .has_suffix, .target = "e" },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 1);
    try std.testing.expectEqualStrings("apple", collected[0]);
}

test "Select with integers" {
    const selected = Select(u32).init(&.{ 123, 456, 789, 1234, 5678 }, &.{
        .{ .match = .include, .operation = .has_prefix, .value = 1 },
        .{ .match = .exclude, .operation = .has_suffix, .value = 4 },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 1);
    try std.testing.expectEqual(collected[0], 123);
}

test "Select with empty input" {
    const selected = Select([]const u8).init(&.{}, &.{
        .{ .match = .include, .operation = .has_prefix, .value = "a" },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 0);
}

test "Select with no selectors" {
    const selected = Select([]const u8).init(&.{ "apple", "banana", "cherry" }, &.{});
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 3);
    try std.testing.expectEqualStrings("apple", collected[0]);
    try std.testing.expectEqualStrings("banana", collected[1]);
    try std.testing.expectEqualStrings("cherry", collected[2]);
}

test "Select with multiple includes" {
    const selected = Select([]const u8).init(&.{ "apple", "banana", "cherry", "date", "elderberry" }, &.{
        .{ .match = .include, .operation = .has_prefix, .value = "a" },
        .{ .match = .include, .operation = .has_prefix, .value = "b" },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 2);
    try std.testing.expectEqualStrings("apple", collected[0]);
    try std.testing.expectEqualStrings("banana", collected[1]);
}

test "Select with multiple excludes" {
    const selected = Select([]const u8).init(&.{ "apple", "banana", "cherry", "date", "elderberry" }, &.{
        .{ .match = .exclude, .operation = .has_suffix, .value = "e" },
        .{ .match = .exclude, .operation = .has_suffix, .value = "y" },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 2);
    try std.testing.expectEqualStrings("banana", collected[0]);
    try std.testing.expectEqualStrings("date", collected[1]);
}

test "Select with alternating include and exclude" {
    const selected = Select([]const u8).init(&.{ "apple", "apricot", "banana", "cherry", "date" }, &.{
        .{ .match = .include, .operation = .has_prefix, .value = "a" },
        .{ .match = .exclude, .operation = .has_suffix, .value = "e" },
        .{ .match = .include, .operation = .has_suffix, .value = "ot" },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 1);
    try std.testing.expectEqualStrings("apricot", collected[0]);
}

test "Select with all elements excluded" {
    const selected = Select([]const u8).init(&.{ "apple", "banana", "cherry" }, &.{
        .{ .match = .exclude, .operation = .has_prefix, .value = "" },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 0);
}

test "Select with all elements included" {
    const selected = Select([]const u8).init(&.{ "apple", "banana", "cherry" }, &.{
        .{ .match = .include, .operation = .has_prefix, .value = "" },
    });
    const collected = selected.collect();
    try std.testing.expectEqual(collected.len, 3);
    try std.testing.expectEqualStrings("apple", collected[0]);
    try std.testing.expectEqualStrings("banana", collected[1]);
    try std.testing.expectEqualStrings("cherry", collected[2]);
}

test "Select with compile-time known result" {
    const selected = Select([]const u8).init(&.{ "apple", "banana", "cherry" }, &.{
        .{ .match = .include, .operation = .has_prefix, .value = "b" },
    });
    const collected = selected.collect();
    comptime {
        try std.testing.expectEqual(collected.len, 1);
        try std.testing.expectEqualStrings("banana", collected[0]);
    }
}
