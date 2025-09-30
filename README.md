# Flow - Pure Dataflow Language

Flow is an AI-first programming language for file manipulation and data processing. It uses **pure dataflow semantics** where data flows through pipelines without variables, functions, or imperative control flow.

## Core Philosophy

- **NO variables** - Data flows, never stops
- **NO functions** - Pipelines compose directly
- **NO statements** - Everything is a pipeline
- **Linear & predictable** - Perfect for AI generation

## Quick Start

```bash
# Install Flow (requires sudo)
make install

# Run Flow code directly
flow 'int : 42 -> print'
flow 'dir : "." -> files "*.md" -> length -> print'

# Or run from a file
flow examples/behaviors/test_simple.flow

# Get help
flow --help

# Check version
flow --version

# Development
zig build          # Build Flow
zig build test     # Run unit tests
make examples      # Run all example tests
```

⚠️ **Important**: When running Flow from command line, use single quotes (') not double quotes ("):
```bash
✅ flow 'dir : "." -> files'   # Correct
❌ flow "dir : "." -> files"   # Wrong - shell strips quotes
```

## Syntax Overview

Flow programs are pipelines that transform data:

```flow
type : value -> transform -> transform
```

- `type : value` - Source (where data comes from)
- `->` - Transform (creates new value)
- `|` - Mutation (reserved for future in-place modifications)

**Note**: Currently, use `->` for all operations. The `|` operator is reserved for Phase 4 performance optimizations (in-place mutations for large data).

## Working Examples

### 1. Basic Primitives

```flow
# Integer
int : 42 -> print
# Output: 42

# Float
float : 3.14 -> print
# Output: 3.14

# String
string : "Hello, Flow!" -> print
# Output: Hello, Flow!

# Negative numbers
int : -42 -> print
# Output: -42

# Zero
int : 0 -> print
# Output: 0
```

### 2. Type Conversion

```flow
# Integer to string
int : 42 -> string -> print
# Output: 42

# Multiple conversions
int : 42 -> string -> print
float : 3.14 -> string -> print
string : "Flow language works!" -> print
# Output:
# 42
# 3.14
# Flow language works!
```

### 3. File Operations

```flow
# Read file content
file : "test.txt" -> content -> print
# Output: Hello from test.txt

# Write to file (returns file for chaining)
file : "output.txt" -> write "Hello, Flow!" -> exists -> print
# Output: 1

# Copy file
file : "test.txt" -> copy "test_copy.txt" -> exists -> print
# Output: 1

# File properties
file : "test.txt" -> size -> print
file : "test.txt" -> extension -> print
file : "test.txt" -> basename -> print
file : "test.txt" -> dirname -> print
```

### 4. Directory Operations

```flow
# List files in directory
dir : "." -> files -> print
# Output:
# [
#   ./file1.txt
#   ./file2.txt
#   ...
# ]

# Glob pattern matching
dir : "src" -> files "*.zig" -> length -> print
# Output: 2

# Get specific file from list
dir : "." -> files -> first -> basename -> print
# Output: file1.txt
```

### 5. Array Operations

```flow
# Array length
dir : "." -> files -> length -> print
# Output: 10

# First element
dir : "." -> files -> first -> basename -> print
# Output: .DS_Store

# Last element
dir : "." -> files -> last -> basename -> print
```

### 6. Path Operations

```flow
# Path type for path manipulation
path : "tmp/test.txt" -> extension -> print
# Output: .txt

path : "src/main.zig" -> basename -> print
# Output: main.zig

path : "src/main.zig" -> dirname -> print
# Output: src
```

### 7. String Operations

```flow
# Convert case
string : "hello world" -> uppercase -> print
# Output: HELLO WORLD

string : "HELLO WORLD" -> lowercase -> print
# Output: hello world

# Split string into array
string : "a,b,c,d" -> split "," -> length -> print
# Output: 4

# Split and join with different delimiter
string : "one,two,three" -> split "," -> join " | " -> print
# Output: one | two | three
```

### 8. Boolean Operations

```flow
# Boolean literals
bool : true -> print
# Output: true

bool : false -> print
# Output: false

# Comparisons (return bool)
int : 42 -> equals "42" -> print
# Output: true

int : 10 -> greater 5 -> print
# Output: true

int : 3 -> less_equals 5 -> print
# Output: true

# String comparisons
string : "hello world" -> contains "world" -> print
# Output: true

string : "hello" -> starts_with "hel" -> print
# Output: true

string : "hello" -> ends_with "lo" -> print
# Output: true

# Logical operations
bool : false -> not -> print
# Output: true

# Assert for testing
int : 42 -> equals "42" -> assert "42 should equal 42"
# Exits silently on success, prints error and exits 1 on failure
```

## Type System

### Primitives
- `int` - Signed integer (architecture dependent, 32 or 64-bit)
- `float` - Floating point (64-bit)
- `string` - Immutable UTF-8 string
- `bool` - Boolean (true/false)
- `uint` - Unsigned integer

### File System
- `file` - File handle with path
- `directory` (alias: `dir`) - Directory handle
- `path` - Path manipulation without I/O

### Collections
- `array` - Array of values

## Transform Operations (->)

Transforms create new values:

| Operation | Input | Output | Description |
|-----------|-------|--------|-------------|
| `print` | any | void | Print value to stdout |
| `string` | any | string | Convert to string |
| `int` | any | int | Convert to integer |
| `float` | any | float | Convert to float |
| `content` | file | string | Read file contents |
| `write <str>` | file | file | Write string to file |
| `copy <path>` | file | file | Copy file to path |
| `exists` | file | int | Check if file exists (1/0) |
| `size` | file | int | Get file size in bytes |
| `extension` | file/path | string | Get file extension |
| `basename` | file/path | string | Get file name |
| `dirname` | file/path | string | Get directory name |
| `files [pattern]` | directory | array | List files (optional glob) |
| `uppercase` | string | string | Convert to uppercase |
| `lowercase` | string | string | Convert to lowercase |
| `split <delim>` | string | array | Split by delimiter |
| `join <delim>` | array | string | Join with delimiter |
| `contains <str>` | string | bool | Check if contains substring |
| `starts_with <str>` | string | bool | Check if starts with prefix |
| `ends_with <str>` | string | bool | Check if ends with suffix |
| `equals <val>` | int/uint/string | bool | Compare for equality |
| `not_equals <val>` | int/uint/string | bool | Compare for inequality |
| `greater <num>` | int/uint | bool | Greater than |
| `less <num>` | int/uint | bool | Less than |
| `greater_equals <num>` | int/uint | bool | Greater than or equal |
| `less_equals <num>` | int/uint | bool | Less than or equal |
| `not` | bool | bool | Logical NOT |
| `and <bool>` | bool | bool | Logical AND |
| `or <bool>` | bool | bool | Logical OR |
| `assert <msg>` | bool | void | Assert true, exit with message if false |
| `length` | array | int | Get array length |
| `first` | array | any | Get first element |
| `last` | array | any | Get last element |

## Mutation Operations (|)

⚠️ **Reserved for Phase 4** - The `|` operator will enable in-place mutations for performance optimization with large data structures. Not yet implemented.

**Future operations** (planned for Phase 4):

| Operation | Input | Effect |
|-----------|-------|--------|
| `sort` | array | Sort array in place |
| `uppercase` | string | Convert to uppercase in place (large strings) |
| `filter` | array | Filter elements in place |
| `map` | array | Transform each element in place |

**Rationale**: In-place mutations will avoid copying large data structures (like `*struct` in Go or `&mut` in Rust), improving performance for file processing workflows.

## Architecture

Flow uses a pure dataflow execution model:

```
Source Code → Lexer → Parser → Analyzer → Interpreter
                ↓       ↓         ↓          ↓
            Tokens  Program   Types     Execution
                            (Pipeline[])
```

### Key Components

**Lexer** ([src/flow/lexer.zig](src/flow/lexer.zig)):
- Table-driven DFA with 19 states
- Position tracking for error messages
- Handles all operators: `->`, `|`, `<>`, `:`, etc.

**Parser** ([src/flow/parser.zig](src/flow/parser.zig)):
- Builds `Program` containing `Pipeline[]`
- No statements or expressions - pure dataflow
- Source locations on every AST node
- Panic-mode error recovery (reports all errors)

**Analyzer** ([src/flow/analyzer.zig](src/flow/analyzer.zig)):
- Compile-time type checking through dataflow analysis
- Type inference through pipelines
- Catches type mismatches before execution

**AST** ([src/flow/ast.zig](src/flow/ast.zig)):
```zig
Program → Pipeline[] → [Source, Operation[], Split?]
```

**Interpreter** ([src/flow/interpreter.zig](src/flow/interpreter.zig)):
- Executes pipelines by flowing data through operations
- Memory-safe value management
- Graceful error handling with helpful messages
- Runtime error context and suggestions

## Future Features (Not Yet Implemented)

### Named Pipeline Definitions
```flow
pipeline transform_user : (row) ->
    get "name"
    | uppercase
    -> prefix "User: "

db : "users" -> query "..." | foreach transform_user
```

### Parallel Execution (`<>`)
```flow
file : "data.json"
    -> content
    | parse_json
    <> (
        db : "postgres://prod" | insert "analytics",
        file : "backup.json" | write
    )
```

### Error Handling
```flow
file : "config.json" ->? content | parse_json -> print
# ->? operator for safe navigation
```

### Semantic Analyzer
- Type inference through dataflow
- Compile-time type checking
- Better error messages with source locations

## Development

### Project Structure
```
flow/
├── src/
│   ├── core/                    # Type system and values
│   ├── flow/                    # Lexer, parser, AST, analyzer, interpreter
│   ├── io/                      # File I/O operations
│   └── main.zig                 # Entry point
├── examples/
│   ├── behaviors/               # Working Flow programs (positive tests)
│   └── errors/                  # Error test cases (negative tests)
├── docs/
│   ├── GOALS.md                 # Development roadmap
│   ├── REVIEW.md                # Architecture analysis
│   ├── DECISIONS.md             # Design decisions
│   └── LLM.md                   # LLM testing report
├── CLAUDE.md                    # Project documentation (AI context)
├── INSTALL.md                   # Installation and usage guide
└── README.md                    # This file
```

### Current Status (2025-09-30)

✅ **Phase 2 Complete**:
- Production-quality table-driven lexer (19 states)
- Pure dataflow AST (no statements!)
- Semantic analyzer with compile-time type checking
- Parser error recovery (reports all errors)
- Enhanced error messages with helpful suggestions
- Graceful runtime error handling
- String execution (run code without files)
- 23 comprehensive tests (16 behaviors + 7 errors)
- LLM tested and validated

✅ **Phase 3a Complete** (String Operations):
- ✅ `uppercase`, `lowercase` - Case conversion
- ✅ `split`, `join` - String/array operations

🚀 **Phase 3b Complete** (Boolean Operations):
- ✅ `bool` type with `true`/`false` literals
- ✅ Comparison operations: `equals`, `greater`, `less`, etc.
- ✅ String comparisons: `contains`, `starts_with`, `ends_with`
- ✅ Logical operations: `not`, `and`, `or`
- ✅ Testing: `assert` operation
- ✅ 39 comprehensive tests (32 behaviors + 7 errors)

🎯 **Phase 3 Next Steps**:
- JSON/YAML/TOML parsing
- Math operations (add, subtract, multiply, divide)
- More array operations (filter, map, reduce)
- Based on user feedback

### Contributing

Flow is in active development. The language design prioritizes:
1. **AI-friendliness** - Linear, predictable syntax
2. **Pure dataflow** - No hidden state or side effects
3. **File operations** - First-class file/directory support
4. **Simplicity** - Minimal concepts, maximum power

See [CLAUDE.md](CLAUDE.md) for the complete vision and [GOALS.md](GOALS.md) for the development roadmap.

## License

[Add your license here]

## Documentation

- [CLAUDE.md](CLAUDE.md) - Complete language vision and philosophy
- [INSTALL.md](INSTALL.md) - Installation and usage guide
- [docs/GOALS.md](docs/GOALS.md) - Phased development roadmap
- [docs/REVIEW.md](docs/REVIEW.md) - Architecture analysis
- [docs/DECISIONS.md](docs/DECISIONS.md) - Key design choices
- [docs/LLM.md](docs/LLM.md) - LLM testing report (Claude Code)