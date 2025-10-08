# Flow Language Specification

**Version**: 0.3.0 (Phase 3c)
**Last Updated**: 2025-10-07

## 1. Introduction

Flow is a **pure dataflow language** designed for AI generation and data processing. It replaces traditional imperative programming with explicit data pipelines that are linear, predictable, and naturally parallel.

### Core Principles

1. **No variables** - Data flows through pipelines, not stored in variables
2. **No functions** - Only transformations and operations on data streams
3. **Explicit typing** - All types are declared explicitly (no inference)
4. **Immutable by default** - Transformations create new values
5. **AI-friendly** - Linear syntax that AI can reason about trivially

## 2. Lexical Structure

### Keywords

Flow has minimal keywords:
- `true` - Boolean true literal
- `false` - Boolean false literal

### Operators

| Operator | Name | Purpose | Precedence |
|----------|------|---------|------------|
| `:` | Type operator | Separates type from value | Highest |
| `->` | Transform | Data transformation (creates new value) | High |
| `\|` | Mutation | In-place mutation (Phase 4, reserved) | High |
| `<>` | Parallel | Parallel execution / Type parameters | Medium |
| `::` | (reserved) | Future use | Medium |

### Identifiers

Identifiers follow these rules:
- Start with lowercase letter `[a-z]`
- Continue with lowercase, digits, or underscore `[a-z0-9_]*`
- Examples: `file`, `parse_json`, `to_string`, `starts_with`

### Literals

#### Integer Literals
```flow
int : 42
int : -17
int : 0
```

#### Float Literals
```flow
float : 3.14
float : -0.5
float : 2.0
```

#### String Literals
```flow
string : "hello world"
string : "path/to/file.txt"
string : ""
```

#### Boolean Literals
```flow
bool : true
bool : false
```

#### Array Literals (Phase 3c)
```flow
array<int> : [1, 2, 3]
array<string> : ["a", "b", "c"]
array<bool> : [true, false, true]
array<array<int>> : [[1, 2], [3, 4]]
```

#### Map Literals (Phase 3c)
```flow
map<string, int> : {"age": 30, "count": 5}
map<int, string> : {0: "zero", 1: "one"}
map<string, bool> : {"active": true, "verified": false}
```

## 3. Type System

### Primitive Types

| Type | Description | Example |
|------|-------------|---------|
| `int` | Signed integer | `int : 42` |
| `uint` | Unsigned integer | (from operations like `length`) |
| `float` | Floating point | `float : 3.14` |
| `string` | UTF-8 string | `string : "hello"` |
| `bool` | Boolean | `bool : true` |
| `void` | No value (from operations like `print`) | (no literal) |

### File System Types

| Type | Description | Example |
|------|-------------|---------|
| `file` | File reference | `file : "test.txt"` |
| `directory` | Directory reference | `directory : "src"` |
| `path` | Generic path | `path : "/usr/local"` |

### Collection Types (Phase 3c)

#### Arrays
Arrays are homogeneous, typed collections.

**Syntax**: `array<ElementType> : [elements]`

```flow
# Integer array
array<int> : [1, 2, 3, 4, 5]

# String array
array<string> : ["apple", "banana", "cherry"]

# Nested arrays
array<array<int>> : [[1, 2], [3, 4], [5, 6]]

# Empty array
array<int> : []
```

**Rules**:
- All elements must be the same type
- Type must be explicitly specified (no inference)
- Elements are comma-separated
- Trailing comma is optional

#### Maps
Maps are typed key-value collections.

**Syntax**: `map<KeyType, ValueType> : {key: value, ...}`

```flow
# String keys, integer values
map<string, int> : {"age": 30, "count": 5}

# Integer keys, string values
map<int, string> : {0: "zero", 1: "one", 2: "two"}

# Boolean keys (yes, really!)
map<bool, string> : {true: "yes", false: "no"}

# Nested maps
map<string, map<string, int>> : {
    "person1": {"age": 30, "score": 95},
    "person2": {"age": 25, "score": 87}
}

# Map with array values
map<string, array<int>> : {
    "scores": [95, 87, 92],
    "ages": [25, 30, 35]
}

# Empty map
map<string, int> : {}
```

**Rules**:
- Keys and values must match their declared types
- Keys must be comparable types (int, uint, string, bool)
- Type parameters must be explicitly specified
- Key-value pairs are comma-separated
- Trailing comma is optional

### Generic Type Syntax

Flow uses angle brackets `<>` for type parameters:

```flow
array<Type>                    # Array of Type
map<KeyType, ValueType>        # Map from KeyType to ValueType
array<array<Type>>            # Nested arrays
map<string, array<int>>       # Map with array values
```

**No Ambiguity with Parallel Operator:**
- Inside type declarations: `<>` means type parameters
- Between values in pipeline: `<>` means parallel execution

```flow
# Type parameters (in type position)
array<int> : [1, 2, 3]
        ^^^

# Parallel execution (between values)
int : 1 <> 2 <> 3 -> print
        ^^    ^^
```

## 4. Pipeline Syntax

### Basic Pipeline Structure

```
Source -> Transform -> Transform -> Sink
```

**Source**: Creates initial value (typed literal)
**Transform**: Modifies value, produces new value
**Sink**: Consumes value (like `print`)

### Source Declaration

```flow
Type : Value -> ...
```

Examples:
```flow
int : 42 -> print
string : "hello" -> uppercase -> print
file : "data.txt" -> content -> print
array<int> : [1, 2, 3] -> length -> print
```

### Transform Operations

Transforms use `->` operator and create new values:

```flow
# String transforms
string : "hello" -> uppercase -> print               # HELLO
string : "a,b,c" -> split "," -> join "|" -> print  # a|b|c

# Numeric transforms
int : 42 -> string -> print                          # 42

# File transforms
file : "test.txt" -> content -> uppercase -> print

# Array transforms
array<int> : [1, 2, 3] -> length -> print           # 3
array<int> : [1, 2, 3] -> first -> print            # 1
```

### Parallel Execution

The `<>` operator executes pipelines in parallel:

```flow
# Multiple files processed in parallel
file : "one.txt" <> "two.txt" <> "three.txt"
    -> content
    -> uppercase
    -> print

# Multiple values in parallel
int : 1 <> 2 <> 3 <> 4
    -> multiply 10
    -> print
```

## 5. Operations by Type

### String Operations

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `uppercase` | string | string | `string : "hi" -> uppercase` |
| `lowercase` | string | string | `string : "HI" -> lowercase` |
| `split <delim>` | string | array\<string\> | `string : "a,b" -> split ","` |
| `join <delim>` | array\<string\> | string | (array) `-> join ","` |
| `contains <substr>` | string | bool | `string : "hello" -> contains "ell"` |
| `starts_with <prefix>` | string | bool | `string : "hello" -> starts_with "hel"` |
| `ends_with <suffix>` | string | bool | `string : "hello" -> ends_with "lo"` |

### Comparison Operations

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `equals <value>` | int/uint/string | bool | `int : 42 -> equals "42"` |
| `not_equals <value>` | int/uint/string | bool | `int : 5 -> not_equals "3"` |
| `greater <n>` | int/uint | bool | `int : 10 -> greater 5` |
| `less <n>` | int/uint | bool | `int : 3 -> less 5` |
| `greater_equals <n>` | int/uint | bool | `int : 5 -> greater_equals 5` |
| `less_equals <n>` | int/uint | bool | `int : 3 -> less_equals 5` |

### Logical Operations

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `not` | bool | bool | `bool : false -> not` |
| `and <bool>` | bool | bool | `bool : true -> and true` |
| `or <bool>` | bool | bool | `bool : false -> or true` |

### File Operations

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `content` | file | string | `file : "x.txt" -> content` |
| `write <path>` | string | file | `string : "hi" -> write "out.txt"` |
| `exists` | file | bool | `file : "x.txt" -> exists` |
| `size` | file | uint | `file : "x.txt" -> size` |
| `extension` | file | string | `file : "x.txt" -> extension` |
| `basename` | file | string | `file : "x.txt" -> basename` |
| `dirname` | file | string | `file : "x.txt" -> dirname` |

### Directory Operations

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `files` | directory | array\<file\> | `directory : "src" -> files` |
| `files <pattern>` | directory | array\<file\> | `directory : "." -> files "*.zig"` |

### Array Operations

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `length` | array\<T\> | uint | `array<int> : [1,2,3] -> length` |
| `first` | array\<T\> | T | `array<int> : [1,2,3] -> first` |
| `last` | array\<T\> | T | `array<int> : [1,2,3] -> last` |
| `get <index>` | array\<T\> | T | (Phase 3c - planned) |

### Map Operations (Phase 3c - Planned)

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `get <key>` | map\<K,V\> | V | `map<string,int> : {...} -> get "age"` |
| `set <key> <value>` | map\<K,V\> | map\<K,V\> | (creates new map) |
| `delete <key>` | map\<K,V\> | map\<K,V\> | (creates new map) |
| `keys` | map\<K,V\> | array\<K\> | Returns all keys |
| `values` | map\<K,V\> | array\<V\> | Returns all values |
| `has <key>` | map\<K,V\> | bool | Check if key exists |

### JSON Operations (Phase 3c - Planned)

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `parse_json` | string | map\<string,any\> | Parse JSON string |
| `to_json` | map | string | Convert map to JSON |
| `get_as_string <key>` | map | string | Type-safe accessor |
| `get_as_int <key>` | map | int | Type-safe accessor |
| `get_as_bool <key>` | map | bool | Type-safe accessor |

### Testing Operations

| Operation | Input | Output | Example |
|-----------|-------|--------|---------|
| `assert <message>` | bool | void | `bool : true -> assert "test passes"` |
| `print` | any | void | `int : 42 -> print` |

## 6. Type Conversion

| From | To | Operation | Example |
|------|-----|-----------|---------|
| int | string | `string` | `int : 42 -> string -> print` |
| file | string | `content` | `file : "x.txt" -> content` |
| array\<string\> | string | `join <delim>` | `(array) -> join ","` |
| string | array\<string\> | `split <delim>` | `string : "a,b" -> split ","` |

## 7. Error Handling

### Compile-Time Errors

Flow performs semantic analysis before execution:

```flow
# Type error (caught at compile-time)
int : 42 -> uppercase  # ERROR: Transform 'uppercase' requires string type, got int

# Invalid operation (caught at compile-time)
file : "x.txt" -> length  # ERROR: Transform 'length' requires array type, got file
```

### Runtime Errors

Operations can fail at runtime:

```flow
# File doesn't exist
file : "missing.txt" -> content  # Runtime error: file not found

# Array index out of bounds (future)
array<int> : [1, 2, 3] -> get 10  # Runtime error: index out of bounds
```

### Assertions

The `assert` operation exits with error if condition is false:

```flow
int : 42
    -> equals "42"
    -> assert "value should be 42"  # Passes

int : 42
    -> equals "100"
    -> assert "this will fail"  # ❌ Assertion failed: this will fail (exits)
```

## 8. Memory Model

### Ownership

- **Owned values**: Created by source declarations, owned by pipeline
- **Borrowed values**: References passed through transforms
- **Clone on modify**: Transforms create new values (immutable)

### Deallocation

Values are freed when:
1. Pipeline completes
2. Value is replaced by transform
3. Program exits

Example:
```flow
string : "hello"    # Allocates "hello"
    -> uppercase     # Allocates "HELLO", frees "hello"
    -> print         # Uses "HELLO", then frees it
```

## 9. Execution Model

### Sequential Pipelines

Data flows left-to-right through transforms:

```flow
int : 42 -> string -> print
# Step 1: Create int(42)
# Step 2: Transform to string("42")
# Step 3: Print and free
```

### Parallel Pipelines

The `<>` operator creates parallel execution:

```flow
file : "a.txt" <> "b.txt" -> content -> print
# Step 1: Create file("a.txt") and file("b.txt") in parallel
# Step 2: Read content of both in parallel
# Step 3: Print both in parallel
```

**Implementation**: Each branch is an independent pipeline executing concurrently.

## 10. Grammar (EBNF)

```ebnf
Program     ::= Pipeline+
Pipeline    ::= Source Transform* EOL

Source      ::= Type ':' Value ParallelChain?
ParallelChain ::= ('<>' Value)+

Type        ::= SimpleName TypeParams?
TypeParams  ::= '<' Type (',' Type)* '>'
SimpleName  ::= 'int' | 'uint' | 'float' | 'string' | 'bool' | 'void'
              | 'file' | 'directory' | 'path' | 'array' | 'map'

Value       ::= IntLit | FloatLit | StringLit | BoolLit | ArrayLit | MapLit
IntLit      ::= '-'? [0-9]+
FloatLit    ::= '-'? [0-9]+ '.' [0-9]+
StringLit   ::= '"' .* '"'
BoolLit     ::= 'true' | 'false'
ArrayLit    ::= '[' (Value (',' Value)*)? ']'
MapLit      ::= '{' (KeyValue (',' KeyValue)*)? '}'
KeyValue    ::= Value ':' Value

Transform   ::= '->' Operation Args?
Operation   ::= [a-z][a-z0-9_]*
Args        ::= Value+
```

## 11. Design Decisions

### Why No Type Inference?

**Decision**: All types must be explicitly declared.

**Rationale**:
1. **AI clarity**: No ambiguity about what type a value is
2. **Simplicity**: No complex inference algorithm needed
3. **Readability**: Code is self-documenting

Example:
```flow
# ✅ Explicit (required)
array<int> : [1, 2, 3]

# ❌ Inferred (not supported)
array : [1, 2, 3]  # What type? Unclear!
```

### Why `<>` for Both Generics and Parallel?

**Decision**: Use `<>` in two contexts: type parameters and parallel execution.

**Rationale**:
1. **No ambiguity**: Parser distinguishes by position
   - After type name = type parameters: `array<int>`
   - Between values = parallel: `1 <> 2 <> 3`
2. **Familiar**: Generic syntax like Rust, C++, Java, TypeScript
3. **Visual**: Chain-link fence metaphor for parallel still works

### Why Explicit `->` Instead of Implicit Pipes?

**Decision**: Require `->` between all transforms.

**Rationale**:
1. **AI-friendly**: Explicit flow direction
2. **Future-proof**: Distinguishes from `|` (mutation in Phase 4)
3. **Readable**: Clear data flow visualization

### Why Maps Allow Any Hashable Key Type?

**Decision**: Maps support int, uint, string, bool keys (not just strings).

**Rationale**:
1. **Data processing**: Integer keys are common (like array indices)
2. **Zig support**: No technical limitation
3. **Flexibility**: Boolean keys useful for binary mappings

## 12. Future Features (Phase 4+)

### Mutation Operator `|`
```flow
# In-place mutation for performance (Phase 4)
string : huge_text | uppercase  # Mutates in place, no copy
```

### Struct Types
```flow
# Named struct definitions (Phase 4+)
type User : struct(name: string, id: int, active: bool)
User : {name: "Alice", id: 123, active: true}
```

### Pipeline Definitions
```flow
# Reusable pipeline definitions (Phase 4+)
pipeline transform_user : (row) ->
    get "name"
    | uppercase
    -> prefix "User: "
```

### Advanced Parallel Merging
```flow
# Parallel execution with result merging (Phase 4+)
file : "data.json"
    -> content
    | parse_json
    <> (
        db1 : "postgres://prod" | insert "analytics",
        db2 : "mongo://backup" | insert "archive"
    ) -> merge_results
```

## 13. Examples

### Basic Data Processing
```flow
# Read CSV, process numbers
file : "data.csv"
    -> content
    -> split "\n"
    -> first
    -> split ","
    -> length
    -> print
```

### File Manipulation
```flow
# Transform file content
file : "config.txt"
    -> content
    -> uppercase
    -> write "CONFIG.txt"
```

### Boolean Logic
```flow
# Validate condition
string : "hello world"
    -> contains "world"
    -> assert "should contain 'world'"
```

### Array Processing (Phase 3c)
```flow
# Array operations
array<int> : [5, 2, 8, 1, 9]
    -> length
    -> equals "5"
    -> assert "array has 5 elements"
```

### JSON Processing (Phase 3c)
```flow
# Parse and query JSON
file : "config.json"
    -> content
    -> parse_json
    -> get "database"
    -> get "host"
    -> print
```

### Parallel File Processing
```flow
# Process multiple files in parallel
file : "log1.txt" <> "log2.txt" <> "log3.txt"
    -> content
    -> split "\n"
    -> length
    -> print
```

## 14. Implementation Notes

### Lexer
- Table-driven DFA with 19 states
- Supports underscore in identifiers
- Position tracking for error messages

### Parser
- Recursive descent parser
- Panic-mode error recovery
- Reports all syntax errors in one pass

### Semantic Analyzer
- Compile-time type checking
- Dataflow type inference (flow_type tracking)
- Comprehensive error messages with source locations

### Interpreter
- Direct AST execution
- Memory-safe value management (Zig allocators)
- Pipeline-based execution model

## 15. References

- **Main README**: [README.md](../README.md)
- **Development Goals**: [GOALS.md](./GOALS.md)
- **Design Decisions**: [DECISIONS.md](./DECISIONS.md)
- **Change Log**: [CHANGELOG.md](./CHANGELOG.md)
- **LLM Testing Report**: [LLM.md](./LLM.md)

---

*Flow Language Specification v0.3.0 - Pure Dataflow for AI and Data Processing*
