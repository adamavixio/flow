# Flow Language - Design Decisions

This document records key architectural decisions made during Flow's development, along with the rationale and trade-offs considered.

---

## Decision 0: Phase 2 Scope - Error Handling Only (2025-09-29)

**Decision**: Phase 2 will focus exclusively on error handling and polish, deferring all language feature additions to Phase 3+.

**What's Deferred**:
- ❌ Variables (`let x = ...`)
- ❌ Functions (`fn name() {}`)
- ❌ Pipeline definitions (named, reusable pipelines)
- ❌ Parallel execution (`<>` operator parsing)
- ❌ Type inference sugar (`"file.txt"` → file)
- ❌ Optional chaining (`->?` operator)

**What Phase 2 WILL Include**:
- ✅ Parser error recovery (continue parsing after syntax errors)
- ✅ Enhanced error messages (context, suggestions, categorization)
- ✅ Graceful error handling (no crashes on expected errors)

**Rationale**:
1. **Avoid premature syntax decisions**: We haven't tested Flow with real users yet
2. **Complex features need user feedback**: Don't build speculatively
3. **Type inference sugar is confusing**: `"test.txt"` IS a string, not a file
4. **Make current functionality rock-solid**: Polish over features
5. **Massive refactors should wait**: Pipeline definitions and `<>` are huge architectural changes

**Key Insight**: Explicit typing (`file : "test.txt"`) is clearer than inference. The `type : value` syntax makes intent unambiguous for humans and AI.

**Trade-offs**:
- ✅ Avoid locking into syntax we might regret
- ✅ Ship Phase 2 Alpha faster (2-3 weeks not 6-8 weeks)
- ✅ Get user feedback on solid foundations
- ✅ Data-driven Phase 3 priorities
- ⚠️ Users may want variables/functions (Phase 3 will address)

**Status**: ✅ Decided - Focus on error handling

---

## Decision 1: Pure Dataflow AST (2025-09-29)

**Decision**: Remove `Statement` and `Expression` wrappers from AST, making `Pipeline` the top-level construct.

**Rationale**:
- Flow is a dataflow language, not an imperative language
- Wrapping pipelines in statements added unnecessary indirection
- Parser complexity was higher with intermediate layers
- Semantic analysis would need to unwrap layers anyway

**Before**:
```zig
Statement → Expression → Pipeline → Operation
```

**After**:
```zig
Program → Pipeline[] → [Source, Operation[], Split?]
```

**Trade-offs**:
- ✅ Simpler AST structure
- ✅ More direct parser implementation
- ✅ Better alignment with language semantics
- ✅ Easier for AI to reason about
- ⚠️ Required rewriting parser and interpreter (one-time cost)

**Status**: ✅ Implemented and validated with 16 working examples

---

## Decision 2: Source Location on Every Node (2025-09-29)

**Decision**: Add `SourceLocation` field to every AST node.

**Rationale**:
- Essential for high-quality error messages
- Needed for IDE tooling (LSP, go-to-definition)
- Relatively small memory overhead (3 x usize per node)
- Standard practice in production compilers

**Structure**:
```zig
pub const SourceLocation = struct {
    line: usize,      // 1-based line number
    column: usize,    // 1-based column number
    offset: usize,    // 0-based byte offset in source
};
```

**Trade-offs**:
- ✅ Enables precise error reporting
- ✅ Supports IDE features
- ✅ Helps debugging during development
- ⚠️ Small memory overhead (~24 bytes per node)
- ⚠️ Requires tracking during parsing

**Example Error Output**:
```
error: Unknown operation 'foo'
  --> examples/test.flow:3:15
   |
 3 | file : "x.txt" -> foo
   |                   ^^^ unknown operation
```

**Status**: ✅ Implemented on all AST nodes

---

## Decision 3: Zig as Implementation Language

**Decision**: Implement Flow compiler/interpreter in Zig.

**Rationale**:
- Manual memory management needed for performance
- Excellent C interop for future extensions
- Safety features prevent common C bugs
- Growing ecosystem with good tooling
- Comptime enables powerful metaprogramming

**Alternatives Considered**:
- **Rust**: More mature but steeper learning curve, more complex lifetimes
- **C**: Maximum portability but no safety features
- **Go**: Easier GC but less control over performance
- **OCaml**: Excellent for compilers but smaller ecosystem

**Trade-offs**:
- ✅ Memory safety without GC overhead
- ✅ Direct control over allocations
- ✅ Comptime for optimizations
- ⚠️ Smaller community than Rust/Go
- ⚠️ Language still evolving (pre-1.0)

**Status**: Working well, no regrets

---

## Decision 4: Pipeline-First Syntax

**Decision**: Make pipelines the primary language construct, not functions or expressions.

**Rationale**:
- Matches mental model of "data flowing through operations"
- Natural for AI to generate (linear, predictable)
- Avoids nested expression complexity
- Composes well with standard library operations

**Syntax**:
```flow
file : "input.txt" -> content | replace "old" "new" -> write "output.txt"
```

**Alternatives Considered**:
- **Function calls**: `write(replace(content(file("input.txt")), "old", "new"), "output.txt")`
  - ❌ Harder to read, nested complexity
- **Method chains**: `file("input.txt").content().replace("old", "new").write("output.txt")`
  - ❌ Requires OOP semantics, less clear dataflow
- **Unix pipes**: `file input.txt | content | replace old new | write output.txt`
  - ❌ Ambiguous parsing, shell quote hell

**Trade-offs**:
- ✅ Readable left-to-right flow
- ✅ AI-friendly generation pattern
- ✅ Clear operator precedence
- ⚠️ Requires teaching new syntax (not familiar to most programmers)

**Status**: Core language design, well-received

---

## Decision 5: Type System Strategy

**Decision**: Runtime types with planned compile-time inference, not explicit type annotations.

**Current Implementation**:
```zig
pub const ValueType = enum {
    int, float, string, bool,
    file, dir, content, lines, path,
    array,
};
```

**Future Semantic Analysis**:
- Infer types through dataflow
- Validate operation compatibility at compile time
- No explicit type annotations required

**Rationale**:
- Flow is about rapid file manipulation, not type bureaucracy
- Type inference provides safety without annotation burden
- AI can generate code without worrying about types
- Dataflow structure makes inference straightforward

**Alternatives Considered**:
- **Explicit types**: `file : File = "x.txt"`
  - ❌ Verbose, slows down development
- **Dynamic only**: No compile-time checking
  - ❌ Errors found too late, poor developer experience
- **Gradual typing**: Optional type annotations
  - ⚠️ Possible future extension

**Trade-offs**:
- ✅ Concise syntax
- ✅ AI-friendly (no type wrangling)
- ✅ Still provides compile-time safety
- ⚠️ Type errors discovered during semantic analysis, not parsing
- ⚠️ Requires sophisticated inference engine

**Status**: Runtime types working, semantic analysis planned for Phase 2

---

## Decision 6: Two Pipeline Operators (-> and |) [REVISED 2025-09-30]

**Decision**: Use `->` for transforms (creates new values) and reserve `|` for future in-place mutations.

**Original Vision** (Performance-Oriented):
- `->` = Pass by value (creates new allocation, possibly different type)
- `|` = Pass by reference/pointer (modify in place, like `*struct` in Go or `&mut` in Rust)

**Current Implementation** (Phase 3a):
- `->` = All operations that create new values (transforms, type conversions, IO)
- `|` = **Reserved for future** (not yet implemented, will be true in-place mutations)

**Why the Change**:
True in-place mutation requires:
1. Mutable string buffers (Zig strings are `[]const u8`, immutable)
2. Copy-on-write semantics for safety
3. Complex ownership tracking
4. Significant implementation complexity

**Decision**: Defer true mutation semantics to Phase 4 (Performance), focus on features now.

**Current Examples**:
```flow
// -> for ALL operations (creates new values)
string : "hello" -> uppercase -> print        // Creates new string
int : 42 -> string -> print                   // Type conversion
file : "input.txt" -> content -> print        // IO operation
string : "a,b,c" -> split "," -> length       // Transform
array : [3,1,2] -> sort -> print              // Creates sorted copy

// | is RESERVED (not yet implemented)
// Future: string : "hello" | uppercase  // Would mutate in place
// Future: array : [3,1,2] | sort        // Would sort in place
```

**Phase 4 Plan** (In-Place Mutations):
```flow
// Future with true | mutation:
file : "huge.json" -> content | parse_json | transform -> save
// ^ Avoids copies for large data, mutates in place

string : "small" -> uppercase  // Small data, copy is fine
string : huge_text | uppercase // Large data, mutate in place for efficiency
```

**Trade-offs**:
- ✅ Simple to implement (single operator for now)
- ✅ Reserves `|` for future performance optimizations
- ✅ Clear semantics: `->` always means "new value"
- ⚠️ Currently only one operator is used (`->`)
- ⚠️ Need to implement `|` mutations later for performance

**Status**: `->` implemented and working, `|` reserved for Phase 4

---

## Decision 7: Source Types with Type Syntax

**Decision**: Use `type : value` syntax for creating sources (e.g., `file : "path"`).

**Rationale**:
- Makes type clear at source creation point
- Distinguishes file paths from literal strings
- Natural for AI to generate (explicit intent)
- Extensible to other source types (dir, url, db, etc.)

**Syntax**:
```flow
file : "data.txt"       // File source
dir : "src"             // Directory source
int : 42                // Integer literal
string : "hello"        // String literal
array : [1, 2, 3]       // Array literal
```

**Alternatives Considered**:
- **Function calls**: `file("data.txt")`
  - ❌ Ambiguous: is `file` a type or a function?
- **Sigils**: `@"data.txt"` for files, `$"src"` for dirs
  - ❌ Cryptic, requires memorizing sigil meanings
- **Keywords**: `let f = file "data.txt"`
  - ❌ Verbose, imperative feel

**Trade-offs**:
- ✅ Clear and explicit
- ✅ Extensible to new source types
- ✅ Natural for AI generation
- ⚠️ Slightly verbose for simple cases
- ⚠️ Unusual syntax (not common in other languages)

**Status**: Working well, users seem to like it

---

## Decision 8: Array Literals with Square Brackets

**Decision**: Use `[item1, item2, ...]` for array literals, like JSON/JavaScript.

**Rationale**:
- Familiar to most programmers (JSON, JavaScript, Python, etc.)
- Clear visual distinction from strings
- Natural nesting for multi-dimensional arrays
- Works well with type prefix: `array : [1, 2, 3]`

**Examples**:
```flow
array : [1, 2, 3]
array : ["a", "b", "c"]
array : [[1, 2], [3, 4]]
```

**Alternatives Considered**:
- **Parentheses**: `(1, 2, 3)`
  - ❌ Ambiguous with function calls
- **Curly braces**: `{1, 2, 3}`
  - ❌ Reserved for future objects/maps
- **Custom syntax**: `array(1, 2, 3)`
  - ❌ Looks like function call

**Trade-offs**:
- ✅ Familiar syntax
- ✅ Clear nesting
- ✅ JSON-compatible
- ✅ Works with type prefix

**Status**: Implemented and working

---

## Decision 9: Memory Management Strategy

**Decision**: Use arena allocators for AST, explicit cleanup for long-lived values.

**Rationale**:
- AST nodes are tree-structured, ideal for arena allocation
- Parser creates many small allocations (tokens, nodes)
- Arena cleanup is O(1) instead of O(n) for individual frees
- Zig's allocator interface makes this transparent

**Implementation**:
```zig
pub fn deinit(self: *Program) void {
    // Recursively free all AST nodes
    for (self.pipelines) |*pipeline| {
        pipeline.deinit();
    }
    self.allocator.free(self.pipelines);
}
```

**Trade-offs**:
- ✅ Fast allocation during parsing
- ✅ Simple cleanup (single free)
- ✅ No need to track lifetimes manually
- ⚠️ Memory not reclaimed until AST destroyed
- ⚠️ Requires discipline with long-running programs

**Status**: Working well, no memory leaks detected

---

## Decision 10: Semantic Analyzer with Dataflow Type Checking (2025-09-29)

**Decision**: Implement semantic analyzer that performs type checking through dataflow analysis before execution.

**Rationale**:
- Catch type errors at compile time, not runtime
- Provide clear error messages with source locations
- Enable future optimizations based on type information
- Standard practice in production compilers
- Makes Flow more reliable for AI generation

**Architecture**:
```zig
Source → Lexer → Parser → Analyzer → Interpreter
                            ↓
                    Type inference through
                    dataflow analysis
```

**How It Works**:
1. Infer type of each pipeline source (literal, typed literal, nested pipeline)
2. Flow types through operations sequentially
3. Validate each operation is compatible with input type
4. Store inferred types in AST (`pipeline.flow_type`)
5. Report all errors with source context

**Example Error**:
```
=== Semantic Analysis Errors ===
Error at line 1, col 10: Transform 'content' requires file type, got int
  int : 42 -> content
           ^
=================================
```

**Trade-offs**:
- ✅ Errors caught before execution
- ✅ Better developer experience
- ✅ Type information available for future optimizations
- ✅ No runtime overhead (analysis happens once)
- ⚠️ Adds compilation phase (acceptable)
- ⚠️ Small increase in compile time

**Status**: ✅ Implemented with full test coverage

---

## Decision 11: Built-in Operations as Methods

**Decision**: Implement built-in operations as property access and function calls, not keywords.

**Rationale**:
- Extensible: easy to add new operations
- Uniform syntax: all operations look the same
- Natural for AI: operations are just names
- Simple parser: no special cases for builtins

**Examples**:
```flow
file : "x.txt" -> content          // Property access
dir : "." -> files                 // Property access
dir : "." -> files "*.txt"         // Function call with arg
array : [1, 2, 3] -> first         // Property access
```

**Alternatives Considered**:
- **Keywords**: `read file "x.txt"`
  - ❌ Requires many keywords, not extensible
- **Functions**: `content(file("x.txt"))`
  - ❌ Nested syntax, harder to read
- **Special syntax**: `"x.txt"::content`
  - ❌ Unusual, hard to extend

**Trade-offs**:
- ✅ Uniform syntax
- ✅ Easy to extend
- ✅ Simple parser
- ⚠️ No distinction between properties and operations (by design)

**Status**: Working well, feels natural

---

## Future Decisions to Make

### Open Questions

1. **Parallel Execution Semantics**
   - How should `<>` splits handle errors?
   - Should results be ordered or unordered?
   - What happens if one branch fails?

2. **Error Handling**
   - Implicit propagation or explicit handling?
   - Try/catch syntax or result types?
   - How to recover from IO errors?

3. **Pipeline Definitions**
   - Should pipelines be first-class values?
   - How to parameterize pipelines?
   - Scope rules for pipeline names?

4. **Module System**
   - How to import external pipelines?
   - Namespace management?
   - Package distribution format?

5. **Async Operations**
   - Do we need explicit async/await?
   - Can we auto-parallelize pure operations?
   - How to handle long-running operations?

These decisions will be made as we encounter concrete use cases in Phase 2+.

---

## Decision Log Format

For future decisions, use this template:

```markdown
## Decision N: Title (Date)

**Decision**: One sentence summary.

**Rationale**:
- Why we made this choice
- What problem it solves

**Alternatives Considered**:
- Option A: Why not chosen
- Option B: Why not chosen

**Trade-offs**:
- ✅ Advantages
- ⚠️ Disadvantages

**Status**: Current implementation status
```