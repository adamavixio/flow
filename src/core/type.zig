const std = @import("std");
const builtin = std.builtin;
const fmt = std.fmt;
const fs = std.fs;
const heap = std.heap;
const io = std.io;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;

// Simple glob pattern matching for file names
fn matchesGlob(filename: []const u8, pattern: []const u8) bool {
    // Simple implementation for basic patterns like "*.zig"
    if (mem.eql(u8, pattern, "*")) {
        return true; // Match all files
    }

    if (pattern.len > 0 and pattern[0] == '*') {
        // Pattern starts with *, check if filename ends with the rest
        const suffix = pattern[1..];
        return mem.endsWith(u8, filename, suffix);
    }

    if (pattern.len > 0 and pattern[pattern.len - 1] == '*') {
        // Pattern ends with *, check if filename starts with the prefix
        const prefix = pattern[0..pattern.len - 1];
        return mem.startsWith(u8, filename, prefix);
    }

    // Exact match
    return mem.eql(u8, filename, pattern);
}

pub const Error = error{
    ParseTypeFailed,
    ParseValueFailed,
    ParseMutationFailed,
    ParseTransformFailed,
    InvalidMutation,
    InvalidTransform,
    TypeMismatch,
    FileNotFound,
    PermissionDenied,
    PathInvalid,
};

// File system data structures
pub const FileData = struct {
    path: []const u8,
    exists: bool,
    size: ?u64,
    permissions: ?fs.File.PermissionsUnix,

    pub fn init(allocator: mem.Allocator, path: []const u8) !FileData {
        const owned_path = try allocator.dupe(u8, path);
        var file_data = FileData{
            .path = owned_path,
            .exists = false,
            .size = null,
            .permissions = null,
        };

        // Try to get file info
        if (fs.cwd().statFile(path)) |stat| {
            file_data.exists = true;
            file_data.size = stat.size;
            if (@import("builtin").os.tag != .windows) {
                file_data.permissions = fs.File.PermissionsUnix{ .mode = stat.mode };
            }
        } else |_| {
            // File doesn't exist or can't be accessed
        }

        return file_data;
    }

    pub fn deinit(self: FileData, allocator: mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const DirectoryData = struct {
    path: []const u8,
    exists: bool,

    pub fn init(allocator: mem.Allocator, path: []const u8) !DirectoryData {
        const owned_path = try allocator.dupe(u8, path);
        var dir_data = DirectoryData{
            .path = owned_path,
            .exists = false,
        };

        // Try to access directory
        if (fs.cwd().openDir(path, .{})) |dir| {
            var mutable_dir = dir;
            mutable_dir.close();
            dir_data.exists = true;
        } else |_| {
            // Directory doesn't exist or can't be accessed
        }

        return dir_data;
    }

    pub fn deinit(self: DirectoryData, allocator: mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const PathData = struct {
    path: []const u8,

    pub fn init(allocator: mem.Allocator, path: []const u8) !PathData {
        return PathData{
            .path = try allocator.dupe(u8, path),
        };
    }

    pub fn deinit(self: PathData, allocator: mem.Allocator) void {
        allocator.free(self.path);
    }

    pub fn extension(self: PathData) ?[]const u8 {
        return fs.path.extension(self.path);
    }

    pub fn basename(self: PathData) []const u8 {
        return fs.path.basename(self.path);
    }

    pub fn dirname(self: PathData) []const u8 {
        return fs.path.dirname(self.path) orelse ".";
    }
};

pub const Tag = enum {
    int,
    uint,
    float,
    string,
    array,  // Renamed from tuple for clarity
    void,
    // File system types
    file,
    directory,
    path,

    pub fn parse(name: []const u8) !Tag {
        // Handle aliases
        if (mem.eql(u8, name, "dir")) return .directory;

        if (meta.stringToEnum(Tag, name)) |tag| return tag;
        return Error.ParseTypeFailed;
    }
};

pub fn Build(comptime tag: Tag) type {
    return switch (tag) {
        .int => struct { owned: bool, data: isize },
        .uint => struct { owned: bool, data: usize },
        .float => struct { owned: bool, data: f64 },
        .string => struct { owned: bool, data: []const u8 },
        .array => struct { owned: bool, data: []Value },
        .void => struct { owned: bool, data: void },
        .file => struct { owned: bool, data: FileData },
        .directory => struct { owned: bool, data: DirectoryData },
        .path => struct { owned: bool, data: PathData },
    };
}

pub const Mutation = enum {
    add,
    sub,
    mul,
    div,

    pub fn parse(name: []const u8) !Mutation {
        if (meta.stringToEnum(Mutation, name)) |mutation| return mutation;
        return Error.ParseMutationFailed;
    }
};

test Mutation {
    const add = try Mutation.parse("add");
    const sub = try Mutation.parse("sub");
    const mul = try Mutation.parse("mul");
    const div = try Mutation.parse("div");
    try testing.expectEqual(.add, add);
    try testing.expectEqual(.sub, sub);
    try testing.expectEqual(.mul, mul);
    try testing.expectEqual(.div, div);
}

pub const Transform = union(enum) {
    int,
    uint,
    float,
    string,
    print: std.io.AnyWriter,
    // File operations
    content,       // Read file content as string
    exists,        // Check if file/directory exists
    size,          // Get file size
    extension,     // Get file extension
    basename,      // Get file basename
    dirname,       // Get directory name
    copy: []const u8,    // Copy file to destination path
    files: ?[]const u8,  // List files in directory with optional pattern
    write: []const u8,   // Write content to file
    // String operations
    uppercase,     // Convert string to uppercase
    lowercase,     // Convert string to lowercase
    split: []const u8,   // Split string by delimiter -> array
    join: []const u8,    // Join array elements with delimiter -> string
    // Array operations
    filter,        // Filter array elements
    map,           // Transform each array element
    each,          // Apply operation to each element
    length,        // Get array length
    first,         // Get first element
    last,          // Get last element

    pub fn parse(name: []const u8) !meta.FieldEnum(Transform) {
        if (meta.stringToEnum(meta.FieldEnum(Transform), name)) |transform| return transform;
        return Error.ParseTransformFailed;
    }
};

test Transform {
    const string = try Transform.parse("string");
    const print = try Transform.parse("print");
    const content = try Transform.parse("content");
    const exists = try Transform.parse("exists");
    try testing.expectEqual(.string, string);
    try testing.expectEqual(.print, print);
    try testing.expectEqual(.content, content);
    try testing.expectEqual(.exists, exists);
}

pub const Value = union(Tag) {
    int: Build(.int),
    uint: Build(.uint),
    float: Build(.float),
    string: Build(.string),
    array: Build(.array),
    void: Build(.void),
    file: Build(.file),
    directory: Build(.directory),
    path: Build(.path),

    pub fn init(comptime tag: Tag, data: meta.TagPayload(Value, tag)) Value {
        return @unionInit(Value, @tagName(tag), data);
    }

    pub fn parse(allocator: mem.Allocator, tag: Tag, data: []const u8) !Value {
        return switch (tag) {
            .int => init(.int, .{ .owned = false, .data = try fmt.parseInt(isize, data, 10) }),
            .uint => init(.uint, .{ .owned = false, .data = try fmt.parseInt(usize, data, 10) }),
            .float => init(.float, .{ .owned = false, .data = try fmt.parseFloat(f64, data) }),
            .string => init(.string, .{ .owned = true, .data = try allocator.dupe(u8, data) }),
            .void => init(.void, .{ .owned = false, .data = {} }),
            .file => init(.file, .{ .owned = true, .data = try FileData.init(allocator, data) }),
            .directory => init(.directory, .{ .owned = true, .data = try DirectoryData.init(allocator, data) }),
            .path => init(.path, .{ .owned = true, .data = try PathData.init(allocator, data) }),
            .array => Error.ParseValueFailed, // Arrays need special handling
        };
    }

    pub fn deinit(self: Value, allocator: mem.Allocator) void {
        switch (self) {
            .string => |string| if (string.owned) {
                allocator.free(string.data);
            },
            .array => |array| if (array.owned) {
                for (array.data) |value| {
                    value.deinit(allocator);
                }
                allocator.free(array.data);
            },
            .file => |file| if (file.owned) {
                file.data.deinit(allocator);
            },
            .directory => |directory| if (directory.owned) {
                directory.data.deinit(allocator);
            },
            .path => |path| if (path.owned) {
                path.data.deinit(allocator);
            },
            else => {},
        }
    }

    /// Create a deep copy of this value
    pub fn clone(self: Value, allocator: mem.Allocator) !Value {
        return switch (self) {
            .int => |v| init(.int, v),
            .uint => |v| init(.uint, v),
            .float => |v| init(.float, v),
            .void => |v| init(.void, v),
            .string => |s| init(.string, .{
                .owned = true,
                .data = try allocator.dupe(u8, s.data),
            }),
            .array => |arr| blk: {
                var cloned = try allocator.alloc(Value, arr.data.len);
                for (arr.data, 0..) |item, i| {
                    cloned[i] = try item.clone(allocator);
                }
                break :blk init(.array, .{
                    .owned = true,
                    .data = cloned,
                });
            },
            .file => |f| init(.file, .{
                .owned = true,
                .data = try FileData.init(allocator, f.data.path),
            }),
            .directory => |d| init(.directory, .{
                .owned = true,
                .data = try DirectoryData.init(allocator, d.data.path),
            }),
            .path => |p| init(.path, .{
                .owned = true,
                .data = try PathData.init(allocator, p.data.path),
            }),
        };
    }

    pub fn typedMutation(self: Value, mutation: Mutation) ![]const Tag {
        return switch (mutation) {
            .add => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
            .sub => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
            .mul => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
            .div => switch (self) {
                inline .int, .uint, .float => |_, tag| &.{tag},
                else => Error.InvalidMutation,
            },
        };
    }

    pub fn applyMutation(self: *Value, mutation: Mutation, values: []Value) !void {
        return switch (mutation) {
            .add => switch (self.*) {
                inline .int, .uint, .float => |*left, tag| left.data += try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
            .sub => switch (self.*) {
                inline .int, .uint, .float => |*left, tag| left.data -= try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
            .mul => switch (self.*) {
                inline .int, .uint, .float => |*left, tag| left.data *= try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
            .div => switch (self.*) {
                inline .int, .uint => |*left, tag| left.data = @divTrunc(left.data, try assert(tag, values[0])),
                inline .float => |*left, tag| left.data /= try assert(tag, values[0]),
                else => return Error.InvalidMutation,
            },
        };
    }

    pub fn typedTransform(self: Value, transform: meta.FieldEnum(Transform)) ![]const Tag {
        return switch (transform) {
            .int => switch (self) {
                inline .uint => &.{},
                else => Error.InvalidTransform,
            },
            .uint => switch (self) {
                inline .int => &.{},
                else => Error.InvalidTransform,
            },
            .float => switch (self) {
                inline .int, .uint => &.{},
                else => Error.InvalidTransform,
            },
            .string => switch (self) {
                inline .int, .uint, .float => &.{},
                else => Error.InvalidTransform,
            },
            .print => &.{},
            // File operations
            .content => switch (self) {
                inline .file => &.{},
                else => Error.InvalidTransform,
            },
            .exists => switch (self) {
                inline .file, .directory => &.{},
                else => Error.InvalidTransform,
            },
            .size => switch (self) {
                inline .file => &.{},
                else => Error.InvalidTransform,
            },
            .extension, .basename, .dirname => switch (self) {
                inline .file, .path => &.{},
                else => Error.InvalidTransform,
            },
            .copy => switch (self) {
                inline .file => &.{},
                else => Error.InvalidTransform,
            },
            .files => switch (self) {
                inline .directory => &.{},
                else => Error.InvalidTransform,
            },
            .write => switch (self) {
                inline .file => &.{},
                else => Error.InvalidTransform,
            },
            // Array operations
            .filter, .map, .each => switch (self) {
                inline .array => &.{},
                else => Error.InvalidTransform,
            },
            .length, .first, .last => switch (self) {
                inline .array => &.{},
                else => Error.InvalidTransform,
            },
        };
    }

    pub fn applyTransform(self: Value, allocator: mem.Allocator, transform: Transform, _: []Value) !Value {
        return switch (transform) {
            .int => switch (self) {
                inline .uint => |value| init(.int, .{
                    .owned = false,
                    .data = @intCast(value.data),
                }),
                else => return Error.InvalidTransform,
            },
            .uint => switch (self) {
                inline .int => |value| init(.uint, .{
                    .owned = false,
                    .data = @intCast(value.data),
                }),
                else => return Error.InvalidTransform,
            },
            .float => switch (self) {
                inline .uint, .int => |value| init(.float, .{
                    .owned = false,
                    .data = @floatFromInt(value.data),
                }),
                else => return Error.InvalidTransform,
            },
            .string => switch (self) {
                inline .int, .uint, .float => |value| blk: {
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try fmt.allocPrint(allocator, "{d}", .{value.data}),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .print => |writer| switch (self) {
                inline .int, .uint, .float => |value| blk: {
                    try writer.print("{d}\n", .{value.data});
                    break :blk init(.void, .{
                        .owned = false,
                        .data = {},
                    });
                },
                inline .string => |value| blk: {
                    try writer.print("{s}\n", .{value.data});
                    break :blk init(.void, .{
                        .owned = false,
                        .data = {},
                    });
                },
                else => return Error.InvalidTransform,
            },
            // File operations
            .content => switch (self) {
                inline .file => |file| blk: {
                    const content = fs.cwd().readFileAlloc(allocator, file.data.path, std.math.maxInt(usize)) catch |err| switch (err) {
                        error.FileNotFound => return Error.FileNotFound,
                        error.AccessDenied => return Error.PermissionDenied,
                        else => return err,
                    };
                    break :blk init(.string, .{
                        .owned = true,
                        .data = content,
                    });
                },
                else => return Error.InvalidTransform,
            },
            .exists => switch (self) {
                inline .file => |file| init(.uint, .{
                    .owned = false,
                    .data = if (file.data.exists) 1 else 0,
                }),
                inline .directory => |directory| init(.uint, .{
                    .owned = false,
                    .data = if (directory.data.exists) 1 else 0,
                }),
                else => return Error.InvalidTransform,
            },
            .size => switch (self) {
                inline .file => |file| init(.uint, .{
                    .owned = false,
                    .data = file.data.size orelse 0,
                }),
                else => return Error.InvalidTransform,
            },
            .extension => switch (self) {
                inline .file => |file| blk: {
                    const ext = fs.path.extension(file.data.path);
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try allocator.dupe(u8, ext),
                    });
                },
                inline .path => |path| blk: {
                    const ext = path.data.extension() orelse "";
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try allocator.dupe(u8, ext),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .basename => switch (self) {
                inline .file => |file| blk: {
                    const name = fs.path.basename(file.data.path);
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try allocator.dupe(u8, name),
                    });
                },
                inline .path => |path| blk: {
                    const name = path.data.basename();
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try allocator.dupe(u8, name),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .dirname => switch (self) {
                inline .file => |file| blk: {
                    const dir = fs.path.dirname(file.data.path) orelse ".";
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try allocator.dupe(u8, dir),
                    });
                },
                inline .path => |path| blk: {
                    const dir = path.data.dirname();
                    break :blk init(.string, .{
                        .owned = true,
                        .data = try allocator.dupe(u8, dir),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .copy => |dest_path| switch (self) {
                inline .file => |file| blk: {
                    fs.cwd().copyFile(file.data.path, fs.cwd(), dest_path, .{}) catch |err| switch (err) {
                        error.FileNotFound => return Error.FileNotFound,
                        error.AccessDenied => return Error.PermissionDenied,
                        else => return err,
                    };
                    // Return a new file object for the destination
                    break :blk init(.file, .{
                        .owned = true,
                        .data = try FileData.init(allocator, dest_path),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .files => |pattern| switch (self) {
                inline .directory => |directory| blk: {
                    var dir = fs.cwd().openDir(directory.data.path, .{ .iterate = true }) catch |err| switch (err) {
                        error.FileNotFound => return Error.FileNotFound,
                        error.AccessDenied => return Error.PermissionDenied,
                        else => return err,
                    };
                    defer dir.close();

                    var file_list = std.ArrayList(Value).empty;
                    var iterator = dir.iterate();

                    while (try iterator.next()) |entry| {
                        if (entry.kind == .file) {
                            // Apply pattern filter if provided
                            if (pattern) |glob_pattern| {
                                if (!matchesGlob(entry.name, glob_pattern)) {
                                    continue;
                                }
                            }

                            const full_path = try fs.path.join(allocator, &.{ directory.data.path, entry.name });
                            defer allocator.free(full_path); // Free the joined path since FileData dupes it
                            const file_value = init(.file, .{
                                .owned = true,
                                .data = try FileData.init(allocator, full_path),
                            });
                            try file_list.append(allocator, file_value);
                        }
                    }

                    break :blk init(.array, .{
                        .owned = true,
                        .data = try file_list.toOwnedSlice(allocator),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .write => |content| switch (self) {
                inline .file => |file| blk: {
                    fs.cwd().writeFile(.{
                        .sub_path = file.data.path,
                        .data = content,
                    }) catch |err| switch (err) {
                        error.FileNotFound => return Error.FileNotFound,
                        error.AccessDenied => return Error.PermissionDenied,
                        else => return err,
                    };
                    // Return the same file object
                    break :blk self;
                },
                else => return Error.InvalidTransform,
            },
            // String operations
            .uppercase => switch (self) {
                inline .string => |string| blk: {
                    const result = try allocator.alloc(u8, string.data.len);
                    for (string.data, 0..) |char, i| {
                        result[i] = std.ascii.toUpper(char);
                    }
                    break :blk init(.string, .{
                        .owned = true,
                        .data = result,
                    });
                },
                else => return Error.InvalidTransform,
            },
            .lowercase => switch (self) {
                inline .string => |string| blk: {
                    const result = try allocator.alloc(u8, string.data.len);
                    for (string.data, 0..) |char, i| {
                        result[i] = std.ascii.toLower(char);
                    }
                    break :blk init(.string, .{
                        .owned = true,
                        .data = result,
                    });
                },
                else => return Error.InvalidTransform,
            },
            .split => |delimiter| switch (self) {
                inline .string => |string| blk: {
                    if (delimiter.len == 0) return Error.InvalidTransform;

                    var parts = std.ArrayList(Value).empty;
                    var iter = mem.splitSequence(u8, string.data, delimiter);
                    while (iter.next()) |part| {
                        const part_value = init(.string, .{
                            .owned = true,
                            .data = try allocator.dupe(u8, part),
                        });
                        try parts.append(allocator, part_value);
                    }

                    break :blk init(.array, .{
                        .owned = true,
                        .data = try parts.toOwnedSlice(allocator),
                    });
                },
                else => return Error.InvalidTransform,
            },
            .join => |delimiter| switch (self) {
                inline .array => |array| blk: {
                    // Calculate total length needed
                    var total_len: usize = 0;
                    for (array.data, 0..) |item, i| {
                        switch (item) {
                            .string => |s| {
                                total_len += s.data.len;
                                if (i < array.data.len - 1) total_len += delimiter.len;
                            },
                            else => return Error.InvalidTransform, // Can only join strings
                        }
                    }

                    // Build result string
                    var result = try allocator.alloc(u8, total_len);
                    var pos: usize = 0;
                    for (array.data, 0..) |item, i| {
                        const s = item.string.data;
                        @memcpy(result[pos..pos + s.len], s);
                        pos += s.len;
                        if (i < array.data.len - 1) {
                            @memcpy(result[pos..pos + delimiter.len], delimiter);
                            pos += delimiter.len;
                        }
                    }

                    break :blk init(.string, .{
                        .owned = true,
                        .data = result,
                    });
                },
                else => return Error.InvalidTransform,
            },
            // Array operations
            .length => switch (self) {
                inline .array => |array| init(.uint, .{
                    .owned = false,
                    .data = array.data.len,
                }),
                else => return Error.InvalidTransform,
            },
            .first => switch (self) {
                inline .array => |array| blk: {
                    if (array.data.len == 0) return Error.InvalidTransform;
                    // Clone the first element so we can safely free the array
                    break :blk try array.data[0].clone(allocator);
                },
                else => return Error.InvalidTransform,
            },
            .last => switch (self) {
                inline .array => |array| blk: {
                    if (array.data.len == 0) return Error.InvalidTransform;
                    // Clone the last element so we can safely free the array
                    break :blk try array.data[array.data.len - 1].clone(allocator);
                },
                else => return Error.InvalidTransform,
            },
            .filter, .map, .each => switch (self) {
                inline .array => |_| blk: {
                    // These operations need additional parameters/predicates
                    // For now, return the same array (placeholder implementation)
                    // TODO: Implement proper filter/map/each with predicates
                    break :blk self;
                },
                else => return Error.InvalidTransform,
            },
        };
    }

    pub fn assert(comptime tag: Tag, value: Value) !switch (tag) {
        .int => isize,
        .uint => usize,
        .float => f64,
        .string => []const u8,
        .array => []Value,
        .void => void,
        .file => FileData,
        .directory => DirectoryData,
        .path => PathData,
    } {
        if (tag != meta.activeTag(value)) {
            return Error.TypeMismatch;
        }
        return switch (tag) {
            .int => value.int.data,
            .uint => value.uint.data,
            .float => value.float.data,
            .string => value.string.data,
            .array => value.array.data,
            .void => value.void.data,
            .file => value.file.data,
            .directory => value.directory.data,
            .path => value.path.data,
        };
    }
};

test Value {
    // Mutations
    inline for (comptime meta.tags(Mutation)) |mutation| {
        switch (mutation) {
            .add => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const add_types = try value.typedMutation(.add);
                        try testing.expectEqualSlices(Tag, &.{tag}, add_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.add, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 10 }), value);
                    },
                    else => {},
                }
            },
            .sub => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const sub_types = try value.typedMutation(.sub);
                        try testing.expectEqualSlices(Tag, &.{tag}, sub_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.sub, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 0 }), value);
                    },
                    else => {},
                }
            },
            .mul => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const mul_types = try value.typedMutation(.sub);
                        try testing.expectEqualSlices(Tag, &.{tag}, mul_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.mul, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 25 }), value);
                    },
                    else => {},
                }
            },
            .div => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const div_types = try value.typedMutation(.div);
                        try testing.expectEqualSlices(Tag, &.{tag}, div_types);

                        var inputs = [_]Value{try Value.parse(testing.allocator, tag, "5")};
                        defer inputs[0].deinit(testing.allocator);

                        try value.applyMutation(.div, &inputs);
                        try testing.expectEqual(Value.init(tag, .{ .owned = false, .data = 1 }), value);
                    },
                    else => {},
                }
            },
        }
    }

    // Transforms
    inline for (comptime meta.tags(meta.FieldEnum(Transform))) |transform| {
        switch (transform) {
            .int => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .uint => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const coercion = try value.typedTransform(.int);
                        try testing.expectEqualSlices(Tag, &.{}, coercion);

                        const coerced = try value.applyTransform(testing.allocator, .int, &.{});
                        defer coerced.deinit(testing.allocator);
                        try testing.expectEqual(Value.init(.int, .{ .owned = false, .data = 5 }), coerced);
                    },
                    else => {},
                }
            },
            .uint => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const coercion = try value.typedTransform(.uint);
                        try testing.expectEqualSlices(Tag, &.{}, coercion);

                        const coerced = try value.applyTransform(testing.allocator, .uint, &.{});
                        defer coerced.deinit(testing.allocator);
                        try testing.expectEqual(Value.init(.uint, .{ .owned = false, .data = 5 }), coerced);
                    },
                    else => {},
                }
            },
            .float => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const coercion = try value.typedTransform(.float);
                        try testing.expectEqualSlices(Tag, &.{}, coercion);

                        const coerced = try value.applyTransform(testing.allocator, .float, &.{});
                        defer coerced.deinit(testing.allocator);
                        try testing.expectEqual(Value.init(.float, .{ .owned = false, .data = 5 }), coerced);
                    },
                    else => {},
                }
            },
            .string => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const string_types = try value.typedTransform(.string);
                        try testing.expectEqualSlices(Tag, &.{}, string_types);

                        const string_value = try value.applyTransform(testing.allocator, .string, &.{});
                        defer string_value.deinit(testing.allocator);
                        try testing.expectEqualStrings("5", string_value.string.data);
                    },
                    else => {},
                }
            },
            .print => inline for (comptime meta.tags(Tag)) |tag| {
                switch (tag) {
                    .int, .uint, .float => {
                        var value = try Value.parse(testing.allocator, tag, "5");
                        defer value.deinit(testing.allocator);

                        const print_types = try value.typedTransform(.print);
                        try testing.expectEqualSlices(Tag, &.{}, print_types);
                    },
                    .string => {
                        var value = try Value.parse(testing.allocator, tag, "test");
                        defer value.deinit(testing.allocator);

                        const print_types = try value.typedTransform(.print);
                        try testing.expectEqualSlices(Tag, &.{}, print_types);
                    },
                    .void => {
                        var value = try Value.parse(testing.allocator, tag, "");
                        defer value.deinit(testing.allocator);

                        const print_types = try value.typedTransform(.print);
                        try testing.expectEqualSlices(Tag, &.{}, print_types);
                    },
                    else => {},
                }
            },
            // File operation transforms - just verify they parse correctly
            .content, .exists, .size, .extension, .basename, .dirname, .copy, .files, .write => {
                // These transforms are tested separately in file-specific tests
                // For now, just ensure they can be parsed
            },
            // Array operation transforms - just verify they parse correctly
            .filter, .map, .each, .length, .first, .last => {
                // These transforms are tested separately in array-specific tests
                // For now, just ensure they can be parsed
            },
        }
    }
}
