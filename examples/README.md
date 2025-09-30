# Flow Language Examples

This directory contains example Flow programs organized by test type.

## Directory Structure

### `behaviors/` - Successful Execution Tests ✅
Contains valid Flow programs that should parse, analyze, and execute successfully.
These test correct language behavior.

**Test Categories:**
- **Primitive types** - int, float, string, zero, negative values
- **File operations** - read, write, copy, path operations
- **Directory operations** - list files, glob patterns
- **Array operations** - length, first, last
- **Integration tests** - multiple operations in sequence

See [behaviors/README.md](behaviors/README.md) for details.

**Count:** 16 working examples

### `errors/` - Error Recovery Tests ❌
Contains Flow programs with intentional syntax errors to test parser error recovery.
These test that the parser can detect and report multiple errors gracefully.

**Test Categories:**
- Missing colons in typed sources
- Missing operation names
- Invalid pipeline sources
- Multiple errors in one file
- Pipeline stops on error (graceful)
- File not found (runtime)
- Directory not found (runtime)

See [errors/README.md](errors/README.md) for details.

**Count:** 7 error examples

## Running Examples

```bash
# Run all tests (behaviors + errors)
make examples

# Run only successful behavior tests
make examples-behaviors

# Run only error recovery tests
make examples-errors
```

## Test Philosophy

Flow uses **example-driven testing**:
- `behaviors/` - What should work (positive tests)
- `errors/` - What should fail gracefully (negative tests)

This ensures the language works correctly **AND** fails helpfully.

## Current Status (Phase 1.5 Complete)

### ✅ All Tests Passing
- 16 behavior examples execute successfully
- 7 error examples report errors correctly
- Parser error recovery working
- Semantic analyzer catching type errors
- All integration tests green

## Adding New Examples

### For Behaviors
1. Create `examples/behaviors/test_feature.flow`
2. Ensure it's valid Flow syntax
3. Run `make examples-behaviors` to verify
4. Document in `behaviors/README.md`

### For Error Tests
1. Create `examples/errors/test_error_case.flow`
2. Include intentional syntax error
3. Run `make examples-errors` to verify it fails
4. Document expected error in `errors/README.md`