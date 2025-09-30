# Flow Language Behaviors

This directory contains Flow programs that demonstrate correct language behavior. All programs in this directory should **parse and execute successfully**.

## Test Organization

These examples test that Flow's parser, semantic analyzer, and interpreter work correctly for valid Flow code.

### Primitive Types
- `test_simple.flow` - Basic integer literal and print
- `test_zero.flow` - Zero value handling
- `test_negative_int.flow` - Negative integer literals
- `test_negative_float.flow` - Negative floating point literals
- `test_negative_zero.flow` - Negative zero handling
- `test_lowercase_identifiers.flow` - Lowercase type names

### File Operations
- `test_content.flow` - Reading file contents
- `test_write.flow` - Writing to files
- `test_copy.flow` - Copying files
- `test_path.flow` - Path operations (extension, basename, dirname)

### Directory Operations
- `test_directory.flow` - Directory existence checking
- `test_glob_pattern.flow` - Glob pattern matching

### Array Operations
- `test_array_length.flow` - Get array length
- `test_array_first.flow` - Get first array element
- `test_array_operations.flow` - Combined array operations

### Integration Tests
- `test_working.flow` - Multiple operations in sequence

## Running Tests

```bash
# Run all behavior tests
make examples-behaviors

# Or run all examples (behaviors + errors)
make examples
```

## Expected Behavior

All files in this directory should:
- ✅ Parse successfully (no syntax errors)
- ✅ Pass semantic analysis (no type errors)
- ✅ Execute successfully (produce expected output)
- ✅ Exit with code 0 (success)

If any test fails, it indicates a regression in the language implementation.