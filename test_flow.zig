const std = @import("std");

// Import all the modules directly
const core_type = @import("src/core/type.zig");
const io_source = @import("src/io/source.zig");

// Token
const Token = struct {
    tag: Tag,
    start: usize,
    end: usize,

    const Tag = enum {
        identifier,
        int,
        float,
        string,
        plus,
        minus,
        multiply,
        divide,
        set,
        arrow,
        chain,
        colon,
        pipe,
        invalid,
        end_of_frame,
    };
};

// Simple lexer
const Lexer = struct {
    index: usize,
    source: io_source.Source,

    pub fn init(source: io_source.Source) Lexer {
        return .{
            .index = 0,
            .source = source,
        };
    }

    pub fn next(self: *Lexer) Token {
        // Skip whitespace
        while (self.index < self.source.buffer.len and
               (self.source.buffer[self.index] == ' ' or
                self.source.buffer[self.index] == '\n' or
                self.source.buffer[self.index] == '\t')) {
            self.index += 1;
        }

        if (self.index >= self.source.buffer.len or self.source.buffer[self.index] == 0) {
            return Token{ .tag = .end_of_frame, .start = self.index, .end = self.index };
        }

        const start = self.index;
        const ch = self.source.buffer[self.index];

        // Parse tokens
        if (ch >= '0' and ch <= '9') {
            // Number
            while (self.index < self.source.buffer.len and
                   self.source.buffer[self.index] >= '0' and
                   self.source.buffer[self.index] <= '9') {
                self.index += 1;
            }
            if (self.index < self.source.buffer.len and self.source.buffer[self.index] == '.') {
                // Float
                self.index += 1;
                while (self.index < self.source.buffer.len and
                       self.source.buffer[self.index] >= '0' and
                       self.source.buffer[self.index] <= '9') {
                    self.index += 1;
                }
                return Token{ .tag = .float, .start = start, .end = self.index };
            }
            return Token{ .tag = .int, .start = start, .end = self.index };
        } else if ((ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z')) {
            // Identifier
            while (self.index < self.source.buffer.len and
                   ((self.source.buffer[self.index] >= 'a' and self.source.buffer[self.index] <= 'z') or
                    (self.source.buffer[self.index] >= 'A' and self.source.buffer[self.index] <= 'Z') or
                    (self.source.buffer[self.index] >= '0' and self.source.buffer[self.index] <= '9'))) {
                self.index += 1;
            }
            return Token{ .tag = .identifier, .start = start, .end = self.index };
        } else if (ch == '"') {
            // String
            self.index += 1;
            while (self.index < self.source.buffer.len and self.source.buffer[self.index] != '"') {
                if (self.source.buffer[self.index] == '\\') {
                    self.index += 1;
                }
                self.index += 1;
            }
            if (self.index < self.source.buffer.len) {
                self.index += 1; // closing quote
            }
            return Token{ .tag = .string, .start = start, .end = self.index };
        } else if (ch == ':') {
            self.index += 1;
            return Token{ .tag = .colon, .start = start, .end = self.index };
        } else if (ch == '|') {
            self.index += 1;
            return Token{ .tag = .pipe, .start = start, .end = self.index };
        } else if (ch == '-') {
            self.index += 1;
            if (self.index < self.source.buffer.len and self.source.buffer[self.index] == '>') {
                self.index += 1;
                return Token{ .tag = .arrow, .start = start, .end = self.index };
            }
            return Token{ .tag = .minus, .start = start, .end = self.index };
        } else {
            self.index += 1;
            return Token{ .tag = .invalid, .start = start, .end = self.index };
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("LEAK");
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <flow-file>\n", .{args[0]});
        return;
    }

    // Read file
    var source = io_source.Source.initFile(allocator, args[1]) catch |err| {
        std.debug.print("Error loading file: {s}\n", .{@errorName(err)});
        return;
    };
    defer source.deinit(allocator);

    // Tokenize
    var lexer = Lexer.init(source);

    std.debug.print("=== Tokens ===\n", .{});
    while (true) {
        const token = lexer.next();
        const lexeme = source.buffer[token.start..token.end];
        std.debug.print("{s}: '{s}'\n", .{@tagName(token.tag), lexeme});
        if (token.tag == .end_of_frame) break;
    }

    // Simple interpretation
    lexer.index = 0;

    while (true) {
        const token = lexer.next();
        if (token.tag == .end_of_frame) break;

        // Simple pattern: type : value -> print
        if (token.tag == .identifier) {
            const type_name = source.buffer[token.start..token.end];
            const colon = lexer.next();
            if (colon.tag != .colon) continue;

            const value_token = lexer.next();
            const value_str = source.buffer[value_token.start..value_token.end];

            // Check for arrow and print
            const next = lexer.next();
            if (next.tag == .arrow) {
                const cmd = lexer.next();
                if (cmd.tag == .identifier) {
                    const cmd_name = source.buffer[cmd.start..cmd.end];
                    if (std.mem.eql(u8, cmd_name, "print")) {
                        if (std.mem.eql(u8, type_name, "int")) {
                            const val = std.fmt.parseInt(i64, value_str, 10) catch 0;
                            std.debug.print("{d}\n", .{val});
                        } else if (std.mem.eql(u8, type_name, "float")) {
                            const val = std.fmt.parseFloat(f64, value_str) catch 0;
                            std.debug.print("{d}\n", .{val});
                        } else if (std.mem.eql(u8, type_name, "string")) {
                            // Remove quotes
                            if (value_str.len >= 2 and value_str[0] == '"' and value_str[value_str.len - 1] == '"') {
                                std.debug.print("{s}\n", .{value_str[1..value_str.len - 1]});
                            } else {
                                std.debug.print("{s}\n", .{value_str});
                            }
                        }
                    }
                }
            }
        }
    }
}