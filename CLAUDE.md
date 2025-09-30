# Flow Language - AI-First File Manipulation Language

## Project Documentation

- **[Main README](./README.md)** - User-facing documentation with working examples
- **[Installation Guide](./INSTALL.md)** - How to install and use Flow (includes LLM usage)
- **[Development Goals](./docs/GOALS.md)** - Phased roadmap for Flow development
- **[Design Review](./docs/REVIEW.md)** - Comprehensive analysis of current language architecture
- **[Design Decisions](./docs/DECISIONS.md)** - Key architectural decisions and rationale
- **[LLM Testing Report](./docs/LLM.md)** - Real-world testing by Claude Code (Phase 2 validation)

## Vision

Flow is a **pure dataflow language** optimized for AI generation and file manipulation, designed to replace bash while being a fully functioning programming language.

## ⚠️ CRITICAL: Pipeline Operators (Read This First!)

**Current Implementation (Phase 3a - 2025-09-30)**:

```flow
// Use -> for ALL operations (transforms that create new values)
string : "hello" -> uppercase -> print
int : 42 -> string -> print
file : "x.txt" -> content -> print
array : [3,1,2] -> sort -> print

// | is RESERVED for future (in-place mutations, NOT YET IMPLEMENTED)
// Do NOT use | in current code - it will fail!
```

**Future (Phase 4 - Performance)**:
- `|` will enable in-place mutations for large data (like `*struct` in Go)
- Example: `string : huge_text | uppercase` (mutates in place, no copy)

**See [docs/DECISIONS.md#decision-6](./docs/DECISIONS.md) for full rationale.**

### Core Philosophy: Everything is Data Flow

**Flow is NOT another traditional programming language.** It is fundamentally different:

- **NO variables** (`let x = ...` ❌)
- **NO traditional functions** (`func(a int) int {}` ❌)
- **NO imperative statements** (sequential execution ❌)

Instead, Flow is **pure dataflow** where:

- Data flows through pipelines continuously
- Pipelines can split, merge, and branch
- Everything is a transformation or stream
- Execution is inherently parallel where possible

### Design Principle: Linear Predictability for AI

```flow
// ❌ NOT THIS (traditional programming - verbose and complex):
let x = file : "config.json"
func processFile(f File) Result {
    content := f.read()
    json := parse(content)
    return json.get("version")
}

// ✅ THIS (pure dataflow - linear and predictable):
file : "config.json"
    -> content
    | parse_json
    -> get "version"
    -> print
```

**Why this matters**: AI can reason about dataflow trivially because it's **completely linear**. There's no hidden state, no variable scope, no execution order ambiguity.

### Advanced Dataflow Concepts (Future Vision)

#### Named Pipeline References (Reusable Flows)

```flow
// Define a reusable pipeline
pipeline transform_user : (row) ->
    get "name"
    | uppercase
    -> prefix "User: "

// Use it in a larger flow
db : "users.db"
    -> query "SELECT * FROM users"
    | foreach transform_user
    -> print
```

#### Parallel Execution (`<>` operator)

```flow
// Split data into parallel branches, merge results
file : "data.json"
    -> content
    | parse_json
    <> (
        db1 : "postgres://prod" | insert "analytics",
        db2 : "mongo://backup" | insert "archive",
        file : "output.log" | append
    )
```

#### Pipeline Composition (Data to Multiple Destinations)

```flow
// Query database, process rows, write to multiple outputs in parallel
sql : "connection_string"
    | connect
    -> query "SELECT * FROM logs WHERE level='ERROR'"
    | foreach (row ->
        get "message"
        | extract_pattern /error: (.*)/
    )
    <> (
        pipeline notify_slack,
        pipeline save_to_file,
        pipeline send_to_monitoring
    )
```

### Key Architectural Constraint

**The AST, parser, and semantic analyzer MUST NOT limit dataflow capabilities.**

Flow's architecture must support:

1. **Graph-based dataflow** (not linear statement sequences)
2. **Type inference through data streams** (not symbol table lookups)
3. **Parallel branch analysis** (splits and merges)
4. **Pipeline references** (composition without functions)
5. **Streaming execution** (lazy evaluation for large data)

### What Flow Is NOT

- ❌ Not a general-purpose language with file features bolted on
- ❌ Not bash with better syntax
- ❌ Not Python/JavaScript for file operations
- ❌ Not a functional language with pipes

### What Flow IS

- ✅ A **dataflow-first language** that happens to excel at file operations
- ✅ A **pure transformation language** where data continuously flows
- ✅ An **AI-native language** designed for linear, predictable generation
- ✅ A **parallel-by-default language** where `<>` enables natural concurrency

### Design Implication: Dataflow Graph, Not AST

Traditional languages build an **Abstract Syntax Tree** and execute statements.

Flow should build a **Dataflow Execution Graph** and stream data through transforms.

```
Traditional AST:          Flow Dataflow Graph:
┌─────────────┐          ┌──────────┐
│ Statement 1 │          │  Source  │
└──────┬──────┘          └────┬─────┘
       │                      │
┌──────▼──────┐          ┌────▼──────┐
│ Statement 2 │          │ Transform │
└──────┬──────┘          └────┬─────┘
       │                      ├─────┐
┌──────▼──────┐          ┌────▼──┐  │
│ Statement 3 │          │ Split │  │
└─────────────┘          └───────┘  │
                         (parallel branches)
```

This is why Flow's architecture must be designed around **dataflow analysis**, not traditional semantic analysis.

## Why This Works Well

### 1. AI-Friendly Syntax

Pipeline approach (`->`, `|`, `<>`) creates **linear, predictable flows** that AI can reason about easily:

```flow
file : "config.json" -> content -> parse_json -> modify "version" "2.0" -> save
```

This is much clearer for AI than bash's nested subshells and cryptic flags.

**IMPORTANT - Operator Semantics (As of Phase 3a)**:
- `->` = Transform (creates new value, used for ALL current operations)
- `|` = Mutation (reserved for future in-place modifications, NOT YET IMPLEMENTED)
- `<>` = Parallel split (future feature)

**Current Rule**: Use `->` for everything. The `|` operator is reserved for Phase 4 when we implement true in-place mutations for performance.

### 2. Type Safety + Inference

The type system prevents many errors that plague bash scripts:

```flow
// AI knows this chain is valid:
dir : "src" -> files | filter ".zig" | count -> print

// AI knows this would fail at compile time:
int : 42 -> files  // Type error!
```

### 3. Natural Language Alignment

The syntax reads like instructions:

- "Take file X, get its content, replace Y with Z, save it"
- Maps directly to: `file : "X" -> content | replace "Y" "Z" -> save`

## Core Operations for File Editing

```flow
// File manipulation
file : "input.txt"
    -> lines
    | filter_matching "TODO"
    | prepend_line_numbers
    -> write "output.txt"

// Batch operations
dir : "."
    -> files "*.md"
    | parallel (file -> content | add_header "# Generated" -> save)

// Safe sed/awk replacement
files : glob "src/**/*.zig"
    | replace_in_files "oldFunc" "newFunc"
    | backup_and_save
```

## AI-Specific Features to Consider

1. **Dry-run mode** - Let AI preview changes before execution
2. **Automatic rollback** - Transaction-like file operations
3. **Built-in diff** - Show what changed
4. **Pattern templates** - Common refactoring patterns AI can invoke

## Comparison with Existing Tools

- **Better than bash**: Type-safe, readable, no quote hell
- **Better than Python/JS**: Purpose-built, concise for file ops
- **Better than sed/awk**: Modern, composable, less cryptic

## Development Guidelines

### Core Principles

1. **Predictability**: AI should be able to reason about what a pipeline will do
2. **Safety**: Operations should be reversible/previewable by default
3. **Composability**: Small operations that chain together naturally
4. **Readability**: Code should read like natural language instructions

### Priority Operations for MVP

1. File reading/writing with automatic backups
2. Pattern matching and replacement
3. JSON/YAML/TOML parsing and modification
4. Directory traversal and batch operations
5. Git integration for safe commits
6. Diff generation and preview

### Syntax Patterns to Develop

#### File Safety Pattern

```flow
file : "important.conf"
    -> backup ".bak"
    -> content
    | replace_all "oldval" "newval"
    -> save_if_changed
```

#### Batch Processing Pattern

```flow
dir : "src"
    -> files "*.js"
    | each (file ->
        content
        | add_line 0 "// Copyright 2024"
        -> save
    )
```

#### Validation Pattern

```flow
file : "config.json"
    -> content
    | parse_json
    | validate_schema "schema.json"
    -> if_valid save else error
```

## Future Considerations

### Language Extensions

- Async/parallel operations for large file sets
- Streaming for huge files
- Network operations (HTTP/API calls)
- Database connections
- Shell command integration (escape hatch to bash when needed)

### AI Integration Points

- Built-in templates for common refactoring tasks
- Semantic understanding of code changes
- Automatic error recovery suggestions
- Change impact analysis

### Tooling

- LSP server for IDE integration
- REPL for interactive development
- Debugger with pipeline visualization
- Performance profiler for large operations

## Implementation Notes

### Current Status (Phase 1.5 Complete ✅ - 2025-09-29)

**Production-Ready Components:**

- ✅ **Lexer**: TRUE table-driven DFA with 19 states, position tracking
- ✅ **Parser**: Pure dataflow parser (Program → Pipeline[])
- ✅ **AST**: Pure dataflow structure (NO statements, NO expressions)
- ✅ **Semantic Analyzer**: Compile-time type checking through dataflow analysis
- ✅ **Interpreter**: Executes pipelines by flowing data through operations
- ✅ **Type System**: int, float, string, file, directory, path, array
- ✅ **File Operations**: content, write, copy, exists, size, extension, basename, dirname
- ✅ **Directory Operations**: files (with glob pattern support)
- ✅ **Array Operations**: length, first, last
- ✅ **16 Working Examples**: All examples pass tests

**Complete Compiler Pipeline:**

```
Source Code → Lexer → Parser → Analyzer → Interpreter
                ↓       ↓        ↓          ↓
             Tokens  Program   Types    Execution
```

**Architecture is NOW Pure Dataflow:**

- ✅ Pipelines ARE the program (not wrapped in statements)
- ✅ Source locations on every node
- ✅ Compile-time type checking (errors before execution)
- ✅ Type inference through dataflow (flow_type tracking)
- ✅ Parallel execution ready (Split struct exists for `<>`)

### Phase 2: Error Handling & Polish (Starting - 2-3 weeks)

**Focus**: Make Flow production-ready through better error handling, NOT expanding syntax.

**Goals:**

1. **Parser Error Recovery** (1 week) - Continue parsing after errors, show all mistakes
2. **Enhanced Error Messages** (1 week) - Context, suggestions, categorization
3. **Graceful Error Handling** (1 week) - File ops fail gracefully, no crashes

**Non-Goals (Deferred to Phase 3+):**

- ❌ Variables (`let x = ...`) - Complex, needs symbol tables
- ❌ Functions (`fn name() {}`) - Complex, needs closures
- ❌ Pipeline definitions - Massive refactor required
- ❌ Parallel execution (`<>`) - Requires async runtime
- ❌ Type inference sugar (`"file.txt"` as file) - Confusing, breaks explicit typing
- ❌ Optional chaining (`->?`) - Premature syntax expansion

**Rationale**: Focus on making current functionality rock-solid before adding complexity. Ship Phase 2 Alpha, get user feedback, let data guide Phase 3 priorities.

### Immediate Next Steps

**Week 1: Parser Error Recovery**
- Implement panic-mode recovery
- Add synchronization points at pipeline boundaries
- Report all syntax errors in one pass

**Week 2: Enhanced Error Messages**
- Show runtime error context (which pipeline failed)
- Add helpful suggestions for common mistakes
- Categorize errors (syntax/type/runtime)

**Week 3: Graceful Error Handling**
- Handle file operation errors without crashing
- Proper error propagation through pipelines
- Resource cleanup on errors

### Testing Strategy

- Every operation should have a dry-run mode
- Test with AI-generated code samples
- Focus on error messages that help AI self-correct
- Benchmark against equivalent bash scripts
- **NEW**: Test parallel execution and dataflow correctness

## Example Use Cases

### Config File Update

```flow
files : glob "**/*.json"
    | filter_content_matching "version.*1.0"
    | backup_all ".pre-upgrade"
    | replace_in_files "1.0" "2.0"
    | save_all
    -> print "Updated {count} files"
```

### Code Refactoring

```flow
dir : "src"
    -> files "*.zig"
    | parse_ast
    | find_function "oldFunction"
    | rename_to "newFunction"
    | update_references
    -> save_with_format
```

### Log Analysis

```flow
file : "/var/log/app.log"
    -> lines
    | filter_matching "ERROR"
    | parse_timestamp
    | group_by_hour
    | count_per_group
    -> chart_ascii
    -> print
```

## Claude Code Memory Integration

This CLAUDE.md file serves as **Project Memory** for the Flow language development. It provides Claude Code with persistent context about:

- **Language vision and goals** - AI-first file manipulation focus
- **Development phases** - Current status and next priorities
- **Design decisions** - Architectural choices and rationale
- **Implementation patterns** - Code conventions and best practices

### Current Development Status (2025-09-30)

✅ **Phase 2 Complete** (Major Milestone):

- Production-quality table-driven lexer (19 states)
- **Pure dataflow AST** (Program → Pipeline[], NO statements!)
- **Semantic analyzer** with compile-time type checking
- **Source locations** on every AST node for error messages
- **Parser error recovery** (panic-mode, reports all errors)
- **Enhanced error messages** (location, context, suggestions)
- **Graceful error handling** (no crashes, proper cleanup)
- **String execution** (run code without files: `flow 'code'`)
- **LLM validated** - Claude Code tested and provided feedback

✅ **Phase 3a Complete** (String Operations):

- ✅ **String operations**: `uppercase`, `lowercase`, `split`, `join`
- ✅ **Memory-safe**: All operations allocate and free properly
- ✅ **Type-checked**: Semantic analyzer validates string operations
- ✅ **Documented**: Updated README, GOALS, help text

✅ **Phase 3b Complete** (Boolean Operations - 2025-09-30):

- ✅ **Bool type**: New primitive type with `true`/`false` literals
- ✅ **Comparison operations**: `equals`, `not_equals`, `greater`, `less`, `greater_equals`, `less_equals`
- ✅ **String comparisons**: `contains`, `starts_with`, `ends_with`
- ✅ **Logical operations**: `not`, `and`, `or`
- ✅ **Assert operation**: Testing primitive that exits on failure
- ✅ **Lexer enhancement**: Added underscore support for identifiers
- ✅ **Test improvements**: Converted all 32 behavior tests to use `assert`
- ✅ **Comprehensive testing**: 39 tests total (32 behaviors + 7 errors)
- ✅ **Documented**: CHANGELOG.md created, all docs updated

**Examples**:
```flow
# String operations
string : "hello world" -> uppercase -> print  # HELLO WORLD
string : "a,b,c" -> split "," -> join " | " -> print  # a | b | c

# Boolean operations
int : 42 -> equals "42" -> assert "test passes"
string : "hello" -> contains "ell" -> assert "contains works"
bool : false -> not -> assert "not false is true"
```

🎯 **Current State**:

- Architecture is PURE DATAFLOW (no imperative baggage)
- Type checking happens at compile-time (semantic analyzer)
- Error handling is production-ready
- String operations complete and tested
- **NO variables** - maintaining pure dataflow philosophy

⏳ **Next Priority (Phase 3c - JSON/YAML)**:

- JSON parsing (`parse_json`, `get "key"`, `set "key" value`)
- YAML/TOML support
- Nested object access
- **Defer variables** until we see if they're truly needed
- See [docs/LLM.md](./docs/LLM.md) for LLM testing insights
- See [docs/CHANGELOG.md](./docs/CHANGELOG.md) for detailed change history

### Key Implementation Guidelines

- **Pure dataflow architecture** - NOT traditional programming constructs
- **No variables, no functions** - Only pipelines and data streams
- **AI-friendly syntax** - Linear, predictable dataflow
- **Parallel by default** - `<>` operator for concurrent branches
- **Type inference through flows** - Not symbol tables
- **Scalable architecture** - AST must support future dataflow features

### Architectural Principles (CRITICAL)

1. **Build for Dataflow, Not Statements**
   - AST should be a graph, not a tree
   - Semantic analysis tracks data flow, not variable scope
   - Execution model is streaming, not sequential

2. **Don't Limit Future Capabilities**
   - Design must support pipeline references
   - Design must support parallel splits/merges
   - Design must support lazy streaming evaluation

3. **Keep It Linear for AI**
   - Data flows in one direction through transforms
   - No hidden state or side effects
   - Completely predictable execution model

This document serves as a living guide for Flow's development as an AI-first **pure dataflow language** for file manipulation and system automation.
