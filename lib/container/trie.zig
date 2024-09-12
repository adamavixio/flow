const std = @import("std");

const Self = @This();

terminal: bool = false,
children: [256]?*Self = .{null} ** 256,

pub fn init(comptime strings: []const []const u8) Self {
    return build(strings);
}

fn build(comptime strings: []const []const u8) Self {
    var root = Self{};

    inline for (strings) |string| {
        var node = &root;
        inline for (string) |byte| {
            if (node.children[byte] == null) {
                var new_node = Self{};
                node.children[byte] = &new_node;
            }
            node = node.children[byte].?;
        }
        node.terminal = true;
    }

    return root;
}

pub fn contains(self: *const Self, comptime str: []const u8) bool {
    var node = self;
    inline for (str) |c| {
        if (node.children[c] == null) return false;
        node = node.children[c].?;
    }
    return node.terminal;
}

test "Single String" {
    const Trie = init(&.{"hello"});
    try std.testing.expect(Trie.contains("hello"));
    try std.testing.expect(!Trie.contains("hell"));
    try std.testing.expect(!Trie.contains("hello world"));
}

test "Multiple Strings" {
    const Trie = init(&.{ "apple", "app", "application" });
    try std.testing.expect(Trie.contains("apple"));
    try std.testing.expect(Trie.contains("app"));
    try std.testing.expect(Trie.contains("application"));
    try std.testing.expect(!Trie.contains("appl"));
    try std.testing.expect(!Trie.contains("appli"));
}

test "Empty String" {
    const Trie = init(&.{""});
    try std.testing.expect(Trie.contains(""));
    try std.testing.expect(!Trie.contains("a"));
}

test "Mixed Length Strings" {
    const Trie = init(&.{ "a", "ab", "abc", "abcd" });
    try std.testing.expect(Trie.contains("a"));
    try std.testing.expect(Trie.contains("ab"));
    try std.testing.expect(Trie.contains("abc"));
    try std.testing.expect(Trie.contains("abcd"));
    try std.testing.expect(!Trie.contains("abcde"));
    try std.testing.expect(!Trie.contains("b"));
}

test "Case Sensitivity" {
    const Trie = init(&.{"Hello"});
    try std.testing.expect(Trie.contains("Hello"));
    try std.testing.expect(!Trie.contains("hello"));
    try std.testing.expect(!Trie.contains("HELLO"));
}

test "Special Characters" {
    const Trie = init(&.{ "hello!", "@world", "#zig" });
    try std.testing.expect(Trie.contains("hello!"));
    try std.testing.expect(Trie.contains("@world"));
    try std.testing.expect(Trie.contains("#zig"));
    try std.testing.expect(!Trie.contains("hello"));
    try std.testing.expect(!Trie.contains("world"));
}

test "Overlapping Prefixes" {
    const Trie = init(&.{ "prefix", "pref", "preface" });
    try std.testing.expect(Trie.contains("prefix"));
    try std.testing.expect(Trie.contains("pref"));
    try std.testing.expect(Trie.contains("preface"));
    try std.testing.expect(!Trie.contains("pre"));
    try std.testing.expect(!Trie.contains("prefi"));
}
