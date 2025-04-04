# Flow

# Types

## Primitive

### Boolean

* bool

### Unsigned Integer

* uint
* u16
* u3zwxAQd
* u64
* u128

> [!NOTE]
> The 'uint' type is either 32-bit (u32) or 64-bit (u64) depending on computer architecture

### Signed Integer

* int
* i16
* i32
* i64
* i128

> The 'int' type is either 32-bit (i32) or 64-bit (i64) depending on computer architecture

### Floating Pointer Number

* float
* f16
* f32
* f64
* f128

> The 'float' type is 64-bit (f64)

### String

* string

> The 'string' type is []const u8 and immutable

## Syntax

### Declaration

```text
[type] : [Expression]
```

### Examples

```text
int : 10
file : path 'path/to/file.ext'
```

file :
    path 'path_3' <>
    path 'path_4' -> lines | deduplicate

file
    : path 'path_3'
    <> path 'path_4'
    -> lines | deduplicate ||

* file <- path : 'path_1' <> path : 'path_2' -> lines | sort .asc -> print
* file : path 'path_3' <> path 'path_4' -> lines | deduplicate ||
* string : 'string' | sort .asc | unique

file : path 'path_1' <> path 'path_2' -> sort => [name]
[name] =>
'name' =>

file : path ('path_1') <> path ('path_2') -> lines | sort (asc) -> print
int : 10 | add 5 -> out 'my_int'
in : 'my_int' -> string -> print
in : 'my_int' -> sub 5 -> print

# Compiler Pipeline Guide

## 1. Lexical Analysis (Scanning)

**Role**: Convert raw source text into meaningful tokens

**Components**:

* `token.zig`: Defines token types and operations
* `lexer.zig`: Implements the scanning process

**Scope**:

* Character-by-character analysis
* Token identification
* Error detection for invalid characters/sequences
* Source location tracking
* Whitespace handling
* Comment handling

**Examples**:

```zig
// Token definition
pub const Token = struct {
    tag: Tag,
    location: Location,
    lexeme: []const u8,
};

// Input:
file: path 'input.txt' -> lines | sort -> print

// Tokens:
[identifier "file"]
[colon ":"]
[identifier "path"]
[string "input.txt"]
[arrow "->"]
[identifier "lines"]
[pipe "|"]
[identifier "sort"]
[arrow "->"]
[identifier "print"]
```

## 2. Syntactic Analysis (Parsing)

**Role**: Convert token stream into Abstract Syntax Tree (AST)

**Components**:

* `parser.zig`: Implements parsing logic
* `ast.zig`: Defines tree structure
* `error.zig`: Parser error handling

**Scope**:

* Grammar rule validation
* Tree construction
* Error recovery
* Expression parsing
* Statement parsing
* Basic type recognition

**Examples**:

```zig
// AST Node definition
pub const Node = union(enum) {
    Program: struct {
        pipelines: std.ArrayList(*Node),
    },
    Pipeline: struct {
        input_type: []const u8,
        input: *Node,
        operations: *Node,
    },
    // ...
};

// Grammar rules:
pipeline → type ":" value operations
operations → (transform | mutation)*
transform → "->" identifier
mutation → "|" identifier
```

## 3. Semantic Analysis

**Role**: Validate program meaning and correctness

**Components**:

* `types.zig`: Type system implementation
* `analyzer.zig`: Semantic validation
* `symbols.zig`: Symbol table management
* `scope.zig`: Scope tracking

**Scope**:

* Type checking
* Type inference
* Operation validation
* Method availability
* Pipeline compatibility
* Symbol resolution
* Scope management
* Error detection

**Examples**:

```zig
// Type checking
file: path 'input.txt' -> lines | sort -> print
//    ^ path returns file
//                     ^ lines returns string[]
//                              ^ sort requires string[]
//                                      ^ print accepts any

// Error cases:
string: 'hello' | sort -> count  // Error: sort not defined for string
int: 5 -> lines                  // Error: lines only works on file
```

## 4. Method and Type System

**Role**: Manage type capabilities and extensibility

**Components**:

* `trait.zig`: Type trait definitions
* `method.zig`: Method registration
* `registry.zig`: Type/method registry

**Scope**:

* Method definitions
* Type capabilities
* Operation mapping
* Method resolution
* Type conversion
* Plugin system

**Examples**:

```zig
// Method definition
method string.split(delimiter: string) -> string[] {
    return self | split_at delimiter
}

// Type trait
pub fn Transformable(comptime Self: type) type {
    return struct {
        pub fn string(self: *Self) !*String {
            // Implementation
        }
    };
}

// Registry
const registry = TypeRegistry.init(allocator);
try registry.registerMethod("string", "split", splitImpl);
```

## 5. Runtime Execution

**Role**: Execute the validated program

**Components**:

* `runtime.zig`: Execution engine
* `value.zig`: Runtime value representation
* `pipeline.zig`: Pipeline execution
* `operations.zig`: Operation implementations

**Scope**:

* Value management
* Operation execution
* Pipeline orchestration
* Memory management
* Error handling
* I/O operations

**Examples**:

```zig
// Pipeline execution
pub fn executePipeline(self: *Runtime, pipeline: *Node) !void {
    var value = try self.executeInput(pipeline.input);
    
    for (pipeline.operations.items) |op| {
        value = switch (op.kind) {
            .transform => try self.executeTransform(value, op),
            .mutation => try self.executeMutation(value, op),
            .terminal => try self.executeTerminal(value, op),
        };
    }
}

// Operation implementation
fn executeTransform(value: *Value, op: Operation) !*Value {
    return switch (op.name[0]) {
        'lines' => readLines(value),
        'string' => toString(value),
        else => error.UnknownOperation,
    };
}
```

## 6. Extensibility System

**Role**: Enable language extension and customization

**Components**:

* `plugin.zig`: Plugin system
* `custom.zig`: Custom method support
* `extension.zig`: Type extension

**Scope**:

* Plugin loading
* Method registration
* Type extension
* Custom operations
* User-defined methods
* Error handling

**Examples**:

```zig
// Plugin definition
const MyPlugin = struct {
    pub fn register(registry: *Registry) !void {
        try registry.addMethod("string", "reverse", reverse);
        try registry.addMethod("file", "word_count", wordCount);
    }
};

// Custom method
method file.word_count() -> int {
    return self -> lines | split ' ' -> count
}
```

## 7. Error Handling

**Role**: Provide clear error reporting and recovery

**Components**:

* `error.zig`: Error types and messages
* `diagnostic.zig`: Error reporting
* `recovery.zig`: Error recovery

**Scope**:

* Error detection
* Error messages
* Source location
* Recovery strategies
* Diagnostic output
* Error aggregation

**Examples**:

```zig
// Error types
pub const CompileError = error{
    InvalidSyntax,
    TypeMismatch,
    UndefinedMethod,
    InvalidOperation,
};

// Error reporting
pub fn reportError(self: *Diagnostic, err: CompileError, token: Token) !void {
    const loc = token.location;
    try self.errors.append(.{
        .error = err,
        .message = getMessage(err),
        .line = loc.line,
        .column = loc.column,
    });
}
```

// 1. Arena/GPA for AST and compilation
pub const Compiler = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    arena: std.heap.ArenaAllocator,
    ast_arena: std.heap.ArenaAllocator, // Separate arena for AST
    symbols: SymbolTable,

    pub fn init() Compiler {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        return .{
            .gpa = gpa,
            .arena = std.heap.ArenaAllocator.init(gpa.allocator()),
            .ast_arena = std.heap.ArenaAllocator.init(gpa.allocator()),
            .symbols = SymbolTable.init(gpa.allocator()),
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.ast_arena.deinit();  // Free all AST nodes at once
        self.arena.deinit();      // Free other compilation data
        self.symbols.deinit();
        _ = self.gpa.deinit();
    }
};

// 2. Symbol/Variable Management
pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    data: union {
        variable: struct {
            type_tag: TypeTag,
            is_mutable: bool,
            value: ?*Value,
        },
        function: struct {
            params: []const TypeTag,
            return_type: TypeTag,
        },
    },
};

pub const SymbolTable = struct {
    const Scope = struct {
        parent: ?*Scope,
        symbols: std.StringHashMap(Symbol),
    };

    allocator: std.mem.Allocator,
    current_scope: *Scope,
    scopes: std.ArrayList(*Scope),

    pub fn enterScope(self: *SymbolTable) !void {
        const new_scope = try self.allocator.create(Scope);
        new_scope.* = .{
            .parent = self.current_scope,
            .symbols = std.StringHashMap(Symbol).init(self.allocator),
        };
        try self.scopes.append(new_scope);
        self.current_scope = new_scope;
    }

    pub fn exitScope(self: *SymbolTable) void {
        const old_scope = self.scopes.pop();
        old_scope.symbols.deinit();
        self.allocator.destroy(old_scope);
        self.current_scope = if (self.scopes.items.len > 0)
            self.scopes.items[self.scopes.items.len - 1]
        else
            null;
    }

    pub fn define(self: *SymbolTable, name: []const u8, symbol: Symbol) !void {
        try self.current_scope.symbols.put(name, symbol);
    }

    pub fn lookup(self: SymbolTable, name: []const u8) ?Symbol {
        var current = self.current_scope;
        while (current) |scope| {
            if (scope.symbols.get(name)) |symbol| {
                return symbol;
            }
            current = scope.parent;
        }
        return null;
    }
};

// 3. Runtime Value Management
pub const Value = struct {
    type_tag: TypeTag,
    data: union {
        int: i64,
        float: f64,
        string: []const u8,
        list: std.ArrayList(*Value),
        map: std.StringHashMap(*Value),
    },
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, type_tag: TypeTag) !*Value {
        const value = try allocator.create(Value);
        value.* = .{
            .type_tag = type_tag,
            .data = undefined,
            .allocator = allocator,
        };
        return value;
    }

    pub fn deinit(self: *Value) void {
        switch (self.type_tag) {
            .String => self.allocator.free(self.data.string),
            .List => {
                for (self.data.list.items) |item| {
                    item.deinit();
                }
                self.data.list.deinit();
            },
            .Map => {
                var iter = self.data.map.iterator();
                while (iter.next()) |entry| {
                    entry.value_ptr.*.deinit();
                }
                self.data.map.deinit();
            },
            else => {},
        }
        self.allocator.destroy(self);
    }
};

// 4. Pipeline Stage Memory Management
pub const PipelineStage = struct {
    input: *Value,
    output: ?*Value,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: *Value) PipelineStage {
        return .{
            .allocator = allocator,
            .input = input,
            .output = null,
        };
    }

    pub fn deinit(self: *PipelineStage) void {
        if (self.output) |output| {
            if (output != self.input) {
                output.deinit();
            }
        }
    }

    pub fn transform(self: *PipelineStage, op: Operation) !void {
        const result = try op.execute(self.allocator, self.input);
        if (self.output) |old| {
            if (old != self.input) {
                old.deinit();
            }
        }
        self.output = result;
    }
};

// 5. Example Usage
pub fn main() !void {
    var compiler = Compiler.init();
    defer compiler.deinit();

    // Parse source
    const source = 
        \\file: path 'input.txt' -> lines | sort -> print
        \\string: 'hello' -> uppercase -> print
    ;
    
    // Compilation phase - uses arena
    const ast = try compiler.parse(source);

    // Create runtime
    var runtime = Runtime.init(compiler.gpa.allocator());
    defer runtime.deinit();

    try runtime.execute(ast);
}

// 6. Runtime Execution Example
pub const Runtime = struct {
    allocator: std.mem.Allocator,
    values: std.ArrayList(*Value),

    pub fn executePipeline(self: *Runtime, pipeline: *Node) !void {
        var stage = PipelineStage.init(
            self.allocator,
            try self.evaluateInput(pipeline.input)
        );
        defer stage.deinit();

        for (pipeline.operations.items) |op| {
            try stage.transform(op);
        }

        // Track allocated value
        try self.values.append(stage.output.?);
    }

    pub fn deinit(self: *Runtime) void {
        for (self.values.items) |value| {
            value.deinit();
        }
        self.values.deinit();
    }
};
