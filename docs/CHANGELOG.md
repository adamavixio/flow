# Flow Language - Changelog

All notable changes to the Flow language will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - 2025-09-30

#### Boolean Type System (Phase 3b)
- **New primitive type**: `bool` with `true`/`false` literals
- **Boolean literals**: Can use `bool : true` and `bool : false` in pipelines
- **Comparison operations** (return bool):
  - `equals` - Compare int, uint, or string for equality
  - `not_equals` - Compare int, uint, or string for inequality  
  - `greater` - Numeric greater than (int, uint)
  - `less` - Numeric less than (int, uint)
  - `greater_equals` - Numeric greater than or equal (int, uint)
  - `less_equals` - Numeric less than or equal (int, uint)
- **String comparison operations** (return bool):
  - `contains` - Check if string contains substring
  - `starts_with` - Check if string starts with prefix
  - `ends_with` - Check if string ends with suffix
- **Logical operations** (bool → bool):
  - `not` - Logical NOT
  - `and` - Logical AND (takes bool argument)
  - `or` - Logical OR (takes bool argument)
- **Testing operation**:
  - `assert` - Assert boolean condition is true, exit with message if false
- **Print support**: Bool values print as "true" or "false"

#### Lexer Enhancement
- **Underscore support in identifiers**: Lexer now accepts `_` in identifier names
  - Enables operations like `starts_with`, `greater_equals`, etc.
  - Matches standard programming language conventions
  - Fix for critical bug where underscore operations couldn't be parsed

#### Test Suite Improvements
- **Converted all behavior tests to use `assert`**: 32 behavior tests now use assertions instead of print
  - Tests verify correctness automatically
  - Cleaner test output (silent on success)
  - Better CI/CD integration
- **Added 6 new tests** for underscore boolean operations:
  - `test_bool_starts_with.flow`
  - `test_bool_ends_with.flow`
  - `test_bool_not_equals.flow`
  - `test_bool_greater_equals.flow`
  - `test_bool_less_equals.flow`
  - `test_bool_less.flow`
- **Total test coverage**: 39 tests (32 behaviors + 7 errors)

### Changed - 2025-09-30

#### Type System
- **Extended `equals` operation**: Now supports `uint` in addition to `int` and `string`
- **Extended comparison operations**: `greater`, `less`, `greater_equals`, `less_equals` now support `uint`
- **Semantic analyzer**: Enhanced type checking for boolean operations

#### Architecture
- **Parser**: Enhanced to recognize `true`/`false` as boolean literals (treated as identifiers)
- **Interpreter**: Added handling for boolean literal evaluation
- **Analyzer**: Added type inference for boolean literals and operations

### Fixed - 2025-09-30

#### Critical Bugs
- **Lexer underscore support**: Fixed lexer to accept underscores in identifiers
  - Previously, operations with underscores (e.g., `starts_with`) couldn't be parsed
  - Added underscore to identifier character class in DFA transition table
  - All 5 underscore operations now functional

#### Type System
- **Value.clone()**: Added bool case to clone function
- **Value.assert()**: Added bool case to assert function  
- **Value.parse()**: Added bool parsing logic

### Known Issues

#### Parser Limitations
- **`and`/`or` ambiguity**: Operations like `bool : true -> and false` fail due to parser treating `false` as new pipeline
  - **Workaround**: Not critical for current use cases
  - **Future fix**: Require parentheses or redesign syntax
  - **Status**: Documented, low priority

---

## [0.3.0] - 2025-09-30 (Phase 3a Complete)

### Added
- **String operations**: `uppercase`, `lowercase`, `split`, `join`
- **Memory-safe string handling**: All operations allocate and free properly
- **Type-checked strings**: Semantic analyzer validates string operations
- **4 string tests**: Comprehensive test coverage

---

## [0.2.0] - 2025-09-29 (Phase 2 Complete)

### Added
- **Semantic analyzer**: Compile-time type checking through dataflow analysis
- **Parser error recovery**: Continue parsing after syntax errors
- **Enhanced error messages**: Show location, context, and suggestions
- **Graceful error handling**: No crashes on expected errors
- **Source locations**: Every AST node tracks position for error reporting

### Changed
- **AST redesign**: Pure dataflow structure (Program → Pipeline[])
- **Table-driven DFA lexer**: 19 states, production quality
- **Error reporting**: All errors shown with file:line:column

---

## [0.1.0] - 2025-09-25 (Phase 1 Complete)

### Added
- **Initial release**: Basic Flow language implementation
- **Core types**: int, uint, float, string, file, directory, path, array
- **File operations**: content, write, copy, exists, size, extension, basename, dirname
- **Directory operations**: files (with glob pattern support)
- **Array operations**: length, first, last
- **Pipeline syntax**: `->` for transforms, `|` for mutations (reserved)
- **16 working examples**: All basic features demonstrated

---

## Release Planning

### Phase 3c - JSON/YAML (Next - 2-3 weeks)
- JSON parsing (`parse_json`, `get "key"`)
- YAML/TOML support
- Nested object access

### Phase 4 - Performance & Advanced Features (Future)
- In-place mutations (`|` operator implementation)
- Lazy evaluation for large files
- Parallel execution (`<>` operator)
- Pipeline definitions

---

## Development Notes

### Versioning Strategy
- **Major version (X.0.0)**: Breaking changes to language syntax or semantics
- **Minor version (0.X.0)**: New features, backward compatible
- **Patch version (0.0.X)**: Bug fixes only

### Changelog Conventions
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features marked for removal
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security fixes

### Links
- [Documentation](../README.md)
- [Development Goals](./GOALS.md)
- [Design Decisions](./DECISIONS.md)
- [LLM Testing Report](./LLM.md)
