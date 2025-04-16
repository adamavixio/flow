const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const fs = std.fs;

const lib = @import("root.zig");
const flow = lib.flow;
const io = lib.io;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("LEAK");
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) return;

    const filepath = args[1];
    var source = io.Source.initFile(allocator, filepath) catch |err| {
        std.debug.print("Error loading file: {s}\n", .{@errorName(err)});
        return;
    };
    defer source.deinit(allocator);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);

    const statements = parser.parse() catch |err| {
        std.debug.print("Parse error: {s}\n", .{@errorName(err)});
        return;
    };

    const interpreter = flow.Interpreter.init(allocator, source);
    interpreter.execute(statements) catch |err| {
        std.debug.print("Execution error: {s}\n", .{@errorName(err)});
        return;
    };
}
