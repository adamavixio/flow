# Flow Language Development Goals

Based on the comprehensive language design review and implementation progress, this document outlines concrete development steps to evolve Flow from its current working prototype into a production-ready AI-friendly file manipulation language.

## Development Philosophy

**Core Insight**: Flow's pipeline syntax (`type : value | operation -> transform`) is excellent for AI generation. With Phase 1 complete (file system primitives working), the next priority is strengthening the language foundation (lexer, parser, semantic analysis) to enable rapid feature growth.

**Key Principle**: **Strong foundations enable fast iteration.** Investing 2-3 weeks in lexer/parser improvements now saves months of refactoring later.

## Phase 1: Foundation (COMPLETE ✅)

### Goal: Make Flow actually useful for basic file operations

#### 1.1 File System Types ✅
- [x] Add `file`, `directory`, `path` as first-class types to core type system
- [x] Implement file existence checking, size, permissions
- [x] Add basic file operations: read, write, copy
- [x] Create path manipulation operations: extension, basename, dirname

#### 1.2 Essential File Operations ✅
- [x] `file : "config.txt" -> content` - read file contents
- [x] `file : "output.txt" -> write "data"` - write to file
- [x] `file : "source.txt" -> copy "dest.txt"` - file copying
- [x] `dir : "folder" -> files` - list directory contents
- [x] `path : "file.ext" -> extension` - path operations

#### 1.3 Collection Types ✅
- [x] Add `array` type for handling multiple files/values
- [x] Implement basic array operations: length, first, last
- [x] Support glob patterns: `dir : "src" -> files "*.zig"`

### Success Criteria ✅
- Can read/write files with Flow syntax
- Can perform basic directory operations
- Pipeline operations work on collections of files
- **11 working examples demonstrating all Phase 1 features**

## Phase 1.5: Strengthen Foundation (COMPLETE ✅)

### Goal: Build solid lexer/parser/analyzer foundation for rapid feature growth

**Rationale**: A strong foundation makes adding variables, functions, and modules 5-10x faster. Investing now prevents months of refactoring later.

#### 1.5.1 Lexer Improvements ✅
- [x] Add `peek()` method for lookahead (enables better operator parsing)
- [x] Add proper position tracking (line, column) for every token
- [x] **COMPLETE**: Table-driven DFA lexer with 19 states and comprehensive tests

#### 1.5.2 AST Enhancements ✅ COMPLETED (2025-09-29)
- [x] **Pure Dataflow AST**: Removed Statement/Expression wrappers entirely
- [x] **Source Locations**: Added to ALL AST nodes (Pipeline, Source, Operation)
- [x] **Type Inference Ready**: Added `flow_type` field to Pipeline for analyzer
- [x] **Dataflow Parser**: Builds Program → Pipeline[] directly
- [x] **Dataflow Interpreter**: Executes by flowing data through operations

#### 1.5.3 Semantic Analysis ✅ COMPLETED (2025-09-29)
- [x] **Semantic Analyzer**: Type checking through dataflow analysis
- [x] **Compile-Time Error Detection**: Catches type mismatches before execution
- [x] **Error Accumulation**: Reports all errors with source locations
- [x] **Type Inference**: Tracks types flowing through pipelines

### Success Criteria ✅
- ✅ **Table-driven DFA lexer**: 19 states, production quality
- ✅ **Position tracking**: Every token has line and column
- ✅ **Pure dataflow AST**: Pipeline as top-level construct
- ✅ **Semantic analyzer**: Compile-time type checking
- ✅ **All tests pass**: Including 3 new analyzer tests
- ✅ **All 16 examples work**: No regressions

**Time Investment**: ~2 weeks total
**Payoff**: Solid foundation for Phase 2 development

---

## Phase 2: Error Handling & Polish ✅ COMPLETE

### Goal: Make Flow production-ready through better error handling and diagnostics

**Philosophy**: Focus on making what we have **rock-solid** before expanding syntax or adding complex features. No new operators or syntax sugar.

**Prerequisites**: Phase 1.5 complete ✅

#### 2.1 Parser Error Recovery ✅ COMPLETE
- [x] **Panic-mode recovery**: Continue parsing after syntax errors
- [x] **Synchronization points**: Don't give up on first mistake
- [x] **Multiple error reporting**: Show ALL syntax errors in one pass
- [x] **Better synchronization**: Recover at pipeline boundaries
- [x] **Test infrastructure**: Created `examples/errors/` with 4 error tests
- [x] **Example reorganization**: Moved working examples to `examples/behaviors/`
- [x] **Makefile automation**: `make examples` runs all tests (behaviors + errors)

**Result**: Parser now reports all syntax errors in one pass, then synchronizes and continues. All 16 behavior tests pass, all 4 error tests correctly report multiple errors.

#### 2.2 Enhanced Error Messages ✅ COMPLETE
- [x] **Runtime error context**: Show which pipeline/operation failed
- [x] **Source location tracking**: Show line/column for runtime errors
- [x] **Helpful suggestions**: Suggest fixes for common mistakes (FileNotFound, AccessDenied)
- [x] **Error categories**: Distinguish syntax (parser), type (analyzer), and runtime (interpreter) errors
- [x] **Memory leak fix**: Proper cleanup with `errdefer` on evaluation errors

**Result**: Runtime errors now show location, context, source line with error indicator, and helpful suggestions. Example:
```
=== Runtime Error ===
Error: FileNotFound
Context: Failed to apply transform
Location: line 1, col 26
  file : "nonexistent.txt" -> content -> print
                           ^
Suggestion: Check that the file path is correct and the file exists.
```

#### 2.3 Graceful Error Handling ✅ COMPLETE
- [x] **File operation errors**: Handle FileNotFound, PermissionDenied gracefully
- [x] **Error propagation**: Stop pipeline on error without crashing
- [x] **Enhanced error suggestions**: Added suggestions for IsDir, NotDir, AccessDenied
- [x] **Cleanup on error**: Proper resource cleanup with `errdefer`
- [x] **Test coverage**: Added `test_pipeline_stops_on_error.flow` to verify graceful stopping

**Result**: File operations fail gracefully with helpful error messages. Pipeline execution stops on error without crashing or leaking memory. All 7 error tests pass, demonstrating robust error handling.

### Success Criteria ✅
- ✅ Parser reports ALL syntax errors, not just first
- ✅ Error messages include helpful context and suggestions
- ✅ Runtime errors don't crash the interpreter
- ✅ All errors show clear source location with line/column
- ✅ File operations fail gracefully with meaningful errors
- ✅ All 23 tests pass (16 behaviors + 7 errors)
- ✅ Proper resource cleanup on all error paths
- ✅ Pipeline stops gracefully on runtime errors

### Non-Goals (Deferred to Phase 3+)
- ❌ Variables (`let x = ...`) - Complex, needs symbol tables
- ❌ Functions (`fn name() {}`) - Complex, needs closures
- ❌ Optional chaining (`->?`) - New syntax, premature
- ❌ Type inference sugar (`"file.txt" -> content`) - Confusing, breaks explicit typing
- ❌ Pipeline definitions - Requires massive refactor
- ❌ Parallel execution (`<>`) - Requires async runtime

**Rationale**: These features require significant architectural changes and lock us into syntax decisions. Get user feedback on solid foundations first.

**Ship Phase 2 Alpha**: Robust error handling + polished UX, ready for real users

## Phase 3: Language Features (Medium-term - Based on User Feedback)

### Goal: Add core language features based on what users actually need

**Prerequisites**: Phase 2 Alpha shipped, user feedback collected

**Decision Point**: Let real usage guide which features to prioritize. Don't add features speculatively.

#### 3.1 Variables (If needed - 2-3 weeks)
- [ ] Add `let` declarations: `let x = file : "test.txt" -> content`
- [ ] Implement symbol table for variable tracking
- [ ] Add scope management (block scoping)
- [ ] Support variable references in pipelines

**User need**: Reuse intermediate results without repeating pipelines

#### 3.2 Control Flow (If needed - 2-3 weeks)
- [ ] Conditional pipelines: Basic if/else
- [ ] Iteration: Process collections
- [ ] Pattern matching: Handle different cases
- [ ] Loop control: break, continue

**User need**: Complex logic beyond simple pipelines

#### 3.3 Pipeline Definitions (If needed - 3-4 weeks)
- [ ] Define reusable pipelines
- [ ] Pipeline parameters and closure
- [ ] Pipeline references and resolution
- [ ] Scope and symbol management

**User need**: Reusable operations across files

**Note**: This is a MASSIVE feature. Only tackle if users demand it.

#### 3.4 Standard Library Expansion (In Progress)

**Phase 3a - String Operations** ✅ COMPLETE (2025-09-30)
- [x] `uppercase` - Convert string to uppercase
- [x] `lowercase` - Convert string to lowercase
- [x] `split` - Split string by delimiter into array
- [x] `join` - Join array of strings with delimiter
- [x] 4 new tests added

**Phase 3b - Boolean Operations** ✅ COMPLETE (2025-09-30)
- [x] `bool` type with `true`/`false` literals
- [x] Comparison operations: `equals`, `not_equals`, `greater`, `less`, `greater_equals`, `less_equals`
- [x] String comparisons: `contains`, `starts_with`, `ends_with`
- [x] Logical operations: `not`, `and`, `or`
- [x] Assert operation for testing
- [x] Lexer underscore support added
- [x] 6 new tests added, all 32 behaviors converted to use `assert`
- [x] Total: 39 tests (32 behaviors + 7 errors)

**Phase 3c - JSON/YAML** (Next - 1-2 weeks)
- [ ] JSON module: parse_json, get "key", set "key" value
- [ ] YAML/TOML parsers
- [ ] Nested object access

**Phase 3d - More Operations** (Later - 2-3 weeks)
- [ ] String operations: replace, trim
- [ ] Math operations: add, subtract, multiply, divide
- [ ] More array operations: map, filter, reduce
- [ ] HTTP module: fetch, post (for remote files)

**User need**: Common file processing operations

#### 3.5 Advanced File Operations (If needed - 2-3 weeks)
- [ ] Atomic operations: `transaction { ... }`
- [ ] Dry-run mode: `--dry-run` flag
- [ ] Automatic backups
- [ ] File watching (complex, 4+ weeks)

**User need**: Safe file manipulation workflows

#### 3.6 Performance & Scalability (If bottleneck - 3-4 weeks)
- [ ] Lazy evaluation for large files
- [ ] Memory-efficient streaming
- [ ] Parallel processing (MASSIVE - 6+ weeks)
- [ ] Bytecode compilation (if performance critical)

**User need**: Handle large file sets efficiently

### Success Criteria
- ✅ Users can accomplish their real-world tasks
- ✅ Language has features users actually use
- ✅ No dead/unused features
- ✅ Performance is acceptable for typical workloads

### Strategy
**Data-driven development**:
1. Ship Phase 2 Alpha
2. Collect usage data and feedback
3. Prioritize Phase 3 features by actual need
4. Don't build features speculatively

## Phase 4: Production Readiness (Long-term - 12-20 weeks)

### Goal: Production-grade language with tooling ecosystem

**Prerequisites**: Phase 3 shipped, growing user base

#### 4.1 Developer Tooling
- [ ] Language Server Protocol (LSP) implementation
- [ ] Syntax highlighting for VSCode, Vim, etc.
- [ ] REPL for interactive development
- [ ] Debugger: Step through pipelines, inspect values
- [ ] Playground: Web-based Flow editor

#### 4.2 Package System
- [ ] Package manager: `flow install fs-utils`
- [ ] Module system: `import fs-utils`
- [ ] Registry for sharing Flow libraries
- [ ] Semantic versioning support

#### 4.3 Extensibility
- [ ] Plugin system: Write custom operations in Zig
- [ ] User-defined types: `struct Config { ... }`
- [ ] FFI: Call external libraries
- [ ] Macros: Metaprogramming support

#### 4.4 Safety & Security
- [ ] Sandboxing: Run untrusted Flow scripts safely
- [ ] Permission system: File access control
- [ ] Static analysis: Detect security issues
- [ ] Audit logging: Track file operations

#### 4.5 Optimization
- [ ] JIT compilation for hot paths
- [ ] Bytecode compiler
- [ ] Profile-guided optimization
- [ ] Benchmark suite

### Success Criteria
- LSP makes Flow a first-class citizen in editors
- Package ecosystem enables code reuse
- Production users trust Flow for critical workflows
- Performance competitive with bash/Python

## Implementation Strategy

### Revised Priority Order (Based on Phase 1 Success)

1. **Foundation strength** ✨ NEW PRIORITY
   - Strong lexer/parser enables all future features
   - 2-3 weeks now saves months later
   - Better error messages improve AI + human experience

2. **Core language features** (variables, functions, error handling)
   - Now possible with strong foundation
   - Needed for real-world scripts
   - Ship Phase 2 Alpha quickly for user feedback

3. **Advanced file operations** (transactions, dry-run, backups)
   - Based on user feedback from Phase 2
   - Differentiates Flow from bash/Python

4. **Tooling & extensibility** (LSP, packages, plugins)
   - When user base justifies investment
   - Critical for production adoption

### Key Architectural Changes (Revised Timeline)

#### Phase 1.5 (Immediate - 2-3 weeks)
**Lexer**:
- [ ] Add `peek()` for lookahead (essential for better parsing)
- [ ] Add position tracking to every token (line, column)
- [ ] Defer table-driven rewrite to Phase 3 (only if needed)

**Parser**:
- [ ] Add panic-mode error recovery (continue after errors)
- [ ] Track source locations in AST (better error messages)
- [ ] Defer Pratt parsing (not needed yet, Flow has simple precedence)

**Type System**:
- [ ] Add basic semantic analysis pass (type check before running)
- [ ] Start type inference (infer file from string literals)
- [ ] Generic types deferred to Phase 3

#### Phase 2 (3-4 weeks after 1.5)
**Semantic Analysis**:
- [ ] Symbol table for variables
- [ ] Scope management for blocks
- [ ] Type checking for pipelines

#### Phase 3 (Based on user feedback)
**Optimization**:
- [ ] Lazy evaluation if memory is bottleneck
- [ ] Table-driven lexer if state machine limits features
- [ ] Bytecode compiler if performance critical

### Why This Order?

**Phase 1.5 unlocks Phase 2-3**:
- Variables need symbol tables → Need semantic pass
- Functions need type inference → Need better AST
- Error messages need locations → Need position tracking
- Complex operators need lookahead → Need peek()

**2-3 weeks now saves 2-3 months later.**

## Success Metrics

### Phase 1 Success ✅
- ✅ Can replace basic bash file operations
- ✅ Pipeline syntax works for file manipulation
- ✅ AI can generate working file processing code
- ✅ 11 examples covering primitives, files, arrays

### Phase 1.5 Success (Foundation)
- Parser reports multiple errors with file:line:column
- Type errors caught before execution
- AST supports future features (variables, functions)
- Lexer can handle new operators without major surgery

### Phase 2 Success (Core Features)
- Variables work in pipelines
- Errors don't crash, show helpful messages
- Functions can be defined and called
- AI generates more complex scripts successfully

### Phase 3 Success (Advanced Features)
- Control flow enables complex logic
- Standard library covers common file tasks
- Performance handles 1000+ files efficiently
- Users report high productivity

### Phase 4 Success (Production)
- IDE integration via LSP
- Package ecosystem enables code reuse
- Production users trust Flow for critical workflows
- Growing community and contributions

## Current Status (2025-09-30)

✅ **Phase 1 Complete**: File system types, operations, arrays, 16 working examples

✅ **Phase 1.5 Complete**:
- Table-driven DFA lexer (19 states)
- Pure dataflow AST (no imperative wrappers)
- Semantic analyzer with compile-time type checking
- Source location tracking on all nodes

✅ **Phase 2 Complete**: Error handling & polish
- Parser error recovery with panic-mode synchronization
- Enhanced error messages with location, context, and suggestions
- Graceful runtime error handling with proper cleanup
- 23 comprehensive tests (16 behaviors + 7 errors)

✅ **Phase 3a Complete**: String Operations
- ✅ `uppercase`, `lowercase`, `split`, `join` implemented
- ✅ 4 new tests added

✅ **Phase 3b Complete**: Boolean Operations (2025-09-30)
- ✅ Bool type with true/false literals
- ✅ Comparison operations (equals, greater, less, etc.)
- ✅ String comparisons (contains, starts_with, ends_with)
- ✅ Logical operations (not, and, or)
- ✅ Assert operation for testing
- ✅ Lexer underscore support
- ✅ 6 new tests, all 32 behaviors use assert
- ✅ Total: 39 tests (32 behaviors + 7 errors)
- 🎯 **Next**: JSON/YAML parsing (Phase 3c)

**Achieved**:
- Production-quality lexer, parser, and semantic analyzer
- Robust error handling at all levels (parse, semantic, runtime)
- All 39 tests pass (32 behaviors + 7 errors)
- All unit tests pass including 3 analyzer tests
- Compile-time type checking catches errors before execution
- Runtime errors show helpful context and suggestions
- Proper resource cleanup on all error paths
- String operations with memory safety
- Boolean operations with full comparison and logic support
- Assert-based testing for all behavior tests
- Lexer supports underscores in identifiers

**Next Steps**: JSON parsing (Phase 3c), then gather user feedback for priorities

## Notes for Implementation

### Core Principles (Unchanged)
- **Keep syntax simple** - AI needs predictable, linear operations
- **Safety by default** - operations should be safe unless explicitly marked unsafe
- **Progressive complexity** - start simple but design for extensibility
- **Test with AI generation** - validate that AI can actually generate correct Flow code

### Strategic Approach (Updated)
- **Foundation first** - Strong lexer/parser unlocks rapid feature development
- **Ship incrementally** - Get user feedback early (Phase 2 Alpha)
- **Data-driven decisions** - Refactor based on real bottlenecks, not speculation
- **Embrace tech debt** - Some shortcuts are OK if they enable faster user validation

### Decision Framework

**When to refactor vs. add features:**
1. **Refactor if**: Current architecture blocks next 3+ features
2. **Add features if**: Current architecture is sufficient
3. **Hybrid if**: Small improvements enable big wins (Phase 1.5 approach)

**Example**:
- Adding peek() to lexer (1 day) → Enables better operator parsing → Worth it
- Rewriting lexer as table-driven (1-2 weeks) → No immediate benefit → Defer to Phase 3

### Milestone Targets

- **Phase 1** ✅: September 2025 (COMPLETE)
- **Phase 1.5**: October 2025 (2-3 weeks)
- **Phase 2 Alpha**: November 2025 (ship to early users)
- **Phase 2 Beta**: December 2025 (based on feedback)
- **Phase 3**: Q1 2026 (4-6 weeks)
- **Phase 4**: Q2-Q3 2026 (12-20 weeks)

### The Bottom Line

Flow has proven its core concept with 11 working examples. The question isn't "Can we build this?" but **"How fast can we get it into users' hands?"**

**Answer**: Invest 2-3 weeks strengthening the foundation (Phase 1.5), then ship Phase 2 Alpha in 8-10 weeks total. Get real user feedback. Let data guide Phase 3-4 decisions.

This roadmap transforms Flow from a working prototype into a production-ready AI-friendly file manipulation language.