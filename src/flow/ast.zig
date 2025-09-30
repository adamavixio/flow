const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const meta = std.meta;

const lib = @import("../root.zig");
const core = lib.core;
const flow = lib.flow;

/// Source location for error reporting
pub const SourceLocation = struct {
    start_line: usize,
    start_col: usize,
    end_line: usize,
    end_col: usize,

    pub fn from_token(tok: flow.Token) SourceLocation {
        return .{
            .start_line = tok.line,
            .start_col = tok.column,
            .end_line = tok.line,
            .end_col = tok.column + (tok.end - tok.start),
        };
    }

    pub fn merge(start: SourceLocation, end: SourceLocation) SourceLocation {
        return .{
            .start_line = start.start_line,
            .start_col = start.start_col,
            .end_line = end.end_line,
            .end_col = end.end_col,
        };
    }
};

/// Root of a Flow program - a collection of pipelines
/// This is the only top-level structure in Flow
pub const Program = struct {
    pipelines: []Pipeline,
    allocator: mem.Allocator,

    pub fn deinit(self: *Program) void {
        for (self.pipelines) |*pipeline| {
            pipeline.deinit(self.allocator);
        }
        self.allocator.free(self.pipelines);
    }
};

/// A pipeline is a dataflow node - the fundamental unit of Flow programs
/// Data flows from source through operations, optionally splitting into parallel branches
pub const Pipeline = struct {
    /// Where the data comes from
    source: Source,

    /// Sequential operations applied to the data
    operations: []Operation,

    /// Optional: split into parallel branches
    split: ?Split,

    /// Source location for error reporting
    loc: SourceLocation,

    /// Inferred type of data flowing through this pipeline (filled by analyzer)
    flow_type: ?core.Type = null,

    pub fn deinit(self: *Pipeline, allocator: mem.Allocator) void {
        self.source.deinit(allocator);
        for (self.operations) |*op| {
            op.deinit(allocator);
        }
        allocator.free(self.operations);
        if (self.split) |*s| {
            s.deinit(allocator);
        }
    }
};

/// Where data comes from in a pipeline
pub const Source = union(enum) {
    /// Literal value: 42, 3.14, "hello"
    literal: struct {
        token: flow.Token,
        loc: SourceLocation,
    },

    /// Typed literal: int : 42, file : "test.txt"
    typed: struct {
        type_name: flow.Token,
        value: *Source,
        loc: SourceLocation,
    },

    /// Reference to a named pipeline: pipeline transform_user
    pipeline_ref: struct {
        name: flow.Token,
        loc: SourceLocation,
    },

    /// Nested pipeline (for composition)
    pipeline: *Pipeline,

    pub fn location(self: Source) SourceLocation {
        return switch (self) {
            .literal => |l| l.loc,
            .typed => |t| t.loc,
            .pipeline_ref => |r| r.loc,
            .pipeline => |p| p.loc,
        };
    }

    pub fn deinit(self: *Source, allocator: mem.Allocator) void {
        switch (self.*) {
            .typed => |*t| {
                t.value.deinit(allocator);
                allocator.destroy(t.value);
            },
            .pipeline => |p| {
                p.deinit(allocator);
                allocator.destroy(p);
            },
            else => {},
        }
    }
};

/// Operations that transform or mutate data
pub const Operation = union(enum) {
    /// Transform: creates new value (->)
    transform: Transform,

    /// Mutation: modifies in place (|)
    mutation: Mutation,

    pub const Transform = struct {
        name: flow.Token,
        args: []Source,
        loc: SourceLocation,
    };

    pub const Mutation = struct {
        name: flow.Token,
        args: []Source,
        loc: SourceLocation,
    };

    pub fn location(self: Operation) SourceLocation {
        return switch (self) {
            .transform => |t| t.loc,
            .mutation => |m| m.loc,
        };
    }

    pub fn name(self: Operation) flow.Token {
        return switch (self) {
            .transform => |t| t.name,
            .mutation => |m| m.name,
        };
    }

    pub fn deinit(self: *Operation, allocator: mem.Allocator) void {
        const args = switch (self.*) {
            .transform => |*t| t.args,
            .mutation => |*m| m.args,
        };
        for (args) |*arg| {
            arg.deinit(allocator);
        }
        allocator.free(args);
    }
};

/// Parallel execution: split data into multiple branches
pub const Split = struct {
    /// Parallel branches to execute
    branches: []Pipeline,

    /// How to merge results (for future: wait_all, first, race)
    merge_strategy: MergeStrategy,

    /// Source location
    loc: SourceLocation,

    pub fn deinit(self: *Split, allocator: mem.Allocator) void {
        for (self.branches) |*branch| {
            branch.deinit(allocator);
        }
        allocator.free(self.branches);
    }
};

/// How to merge results from parallel branches
pub const MergeStrategy = enum {
    /// Wait for all branches to complete (default for <>)
    wait_all,

    /// Take first result that completes
    first,

    /// Race - fastest wins
    race,
};