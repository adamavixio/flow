const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const fs = std.fs;

const lib = @import("root.zig");
const flow = lib.flow;
const io = lib.io;

fn printUsage() void {
    std.debug.print("Usage: flow <file.flow>          Run Flow code from file\n", .{});
    std.debug.print("       flow \"<code>\"              Run Flow code from string\n", .{});
    std.debug.print("       flow --help               Show help message\n", .{});
    std.debug.print("       flow --version            Show version\n", .{});
}

fn printVersion() void {
    std.debug.print("Flow 0.2.0 (Phase 2 Complete)\n", .{});
    std.debug.print("AI-first file manipulation language\n", .{});
}

fn printHelp() void {
    std.debug.print(
        \\Flow - AI-First File Manipulation Language
        \\
        \\USAGE:
        \\    flow <file.flow>       Run a Flow program from file
        \\    flow "<code>"          Run Flow code directly from string
        \\    flow --help            Show this help message
        \\    flow --version         Show version information
        \\
        \\DESCRIPTION:
        \\    Flow is a pipeline-based language designed for AI generation and
        \\    file manipulation. It uses intuitive dataflow syntax where data
        \\    flows through operations using arrows (-> and |).
        \\
        \\SYNTAX OVERVIEW:
        \\    Pipeline Syntax:
        \\        type : value -> operation -> operation
        \\        type : value | transform -> operation
        \\
        \\    Types:
        \\        int, float, string    - Primitive types
        \\        file, dir, path       - File system types
        \\        array                 - Collections
        \\
        \\EXAMPLES:
        \\    Basic operations:
        \\        int : 42 -> print
        \\        float : 3.14 -> string -> print
        \\
        \\    File operations:
        \\        file : "config.txt" -> content -> print
        \\        file : "output.txt" -> write "Hello, Flow!"
        \\        file : "source.txt" -> copy "dest.txt"
        \\
        \\    Directory operations:
        \\        dir : "." -> files -> length -> print
        \\        dir : "src" -> files "*.zig" -> length -> print
        \\
        \\    Path operations:
        \\        path : "file.txt" -> extension -> print
        \\        path : "dir/file.txt" -> basename -> print
        \\
        \\    Array operations:
        \\        dir : "." -> files -> first -> print
        \\        dir : "src" -> files "*.zig" -> length -> print
        \\
        \\    String operations:
        \\        string : "hello world" -> uppercase -> print
        \\        string : "HELLO WORLD" -> lowercase -> print
        \\        string : "a,b,c" -> split "," -> length -> print
        \\        string : "a,b,c" -> split "," -> join " | " -> print
        \\
        \\ERROR HANDLING:
        \\    Flow provides helpful error messages with:
        \\    - Exact source location (line and column)
        \\    - Context about what failed
        \\    - Suggestions for fixing common mistakes
        \\    - Graceful failure without crashes
        \\
        \\MORE INFORMATION:
        \\    Documentation: https://github.com/yourusername/flow
        \\    Examples: See examples/ directory in source tree
        \\
        \\
    , .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("LEAK");
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage();
        return;
    }

    // Handle --help and --version flags
    if (mem.eql(u8, args[1], "--help") or mem.eql(u8, args[1], "-h")) {
        printHelp();
        return;
    }

    if (mem.eql(u8, args[1], "--version") or mem.eql(u8, args[1], "-v")) {
        printVersion();
        return;
    }

    const input = args[1];

    // Try to load as file first, if that fails, treat as code string
    var source = io.Source.initFile(allocator, input) catch |file_err| blk: {
        // If file not found, treat input as code string
        if (file_err == error.FileNotFound) {
            break :blk io.Source.initString(allocator, input) catch |str_err| {
                std.debug.print("Error loading code: {s}\n", .{@errorName(str_err)});
                return;
            };
        } else {
            std.debug.print("Error loading file: {s}\n", .{@errorName(file_err)});
            return;
        }
    };
    defer source.deinit(allocator);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var lexer = flow.Lexer.init(source);
    var parser = flow.Parser.init(arena.allocator(), &lexer);
    defer parser.deinit();

    var program = parser.parse() catch |err| {
        std.debug.print("Parse error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer program.deinit();

    // Run semantic analysis
    var analyzer = flow.Analyzer.init(arena.allocator(), source);
    defer analyzer.deinit();

    analyzer.analyze(&program) catch |err| {
        if (err == flow.Analyzer.Error.AnalysisFailed) {
            // Errors already printed by analyzer
            std.process.exit(1);
        }
        std.debug.print("Analysis error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };

    var interpreter = flow.Interpreter.init(allocator, source);
    interpreter.execute(program) catch |err| {
        if (err == flow.Interpreter.Error.RuntimeError) {
            // Error already reported by interpreter
            std.process.exit(1);
        }
        std.debug.print("Execution error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}
