# Flow Error Tests

This directory contains Flow programs with intentional errors to test error detection, recovery, and reporting capabilities.

## Test Categories

### Parse Errors (Syntax)
Tests for parser error recovery and reporting.

### Runtime Errors
Tests for runtime error handling with helpful messages.

## Test Files

### Parse Errors

### `test_missing_colon.flow`
**Error**: Missing `:` between type and value
```flow
int 42 -> print
```
**Expected**: Error at line 1, col 5: Expected ':' after type name

### `test_missing_operation.flow`
**Error**: Missing operation name after `->`
```flow
int : 42 ->
```
**Expected**: Error at line 1, col 12: Expected operation name after '->'

### `test_invalid_source.flow`
**Error**: Pipeline starts with operator instead of source
```flow
-> print
```
**Expected**: Error at line 1, col 1: Expected source (type or literal)

### `test_multiple_errors.flow`
**Error**: Multiple syntax errors in different pipelines
```flow
int 42 -> print
string "test" ->
file : -> content
```
**Expected**: All three errors reported (demonstrates error recovery)

### Runtime Errors

#### `test_file_not_found.flow`
**Error**: Reading a file that doesn't exist
```flow
file : "nonexistent_file.txt" -> content -> print
```
**Expected**: Runtime error with location, context, and suggestion to check file path

#### `test_directory_not_found.flow`
**Error**: Listing files in a directory that doesn't exist
```flow
dir : "nonexistent_directory" -> files -> length -> print
```
**Expected**: Runtime error with location and helpful message

#### `test_pipeline_stops_on_error.flow`
**Error**: Pipeline stops on error, subsequent pipelines don't execute
```flow
file : "nonexistent.txt" -> content -> print
int : 42 -> print
```
**Expected**: Error on first pipeline, second pipeline never executes (graceful stop)

## Parser Error Recovery

The Flow parser implements **panic-mode error recovery**:

1. **Error Detection**: When a syntax error is encountered, it's added to an error list
2. **Panic Mode**: Parser enters "panic mode" to avoid cascading errors
3. **Synchronization**: Parser skips tokens until it finds a pipeline boundary (start of new pipeline or EOF)
4. **Continuation**: Parser attempts to continue parsing remaining pipelines
5. **Reporting**: All collected errors are reported together at the end

This allows the parser to **report multiple errors in a single pass**, making it easier to fix all syntax issues at once rather than fixing them one at a time.

## Graceful Runtime Error Handling

Flow handles runtime errors gracefully:

1. **Error Detection**: When a file operation fails, error is caught
2. **Context Reporting**: Shows exact location and operation that failed
3. **Helpful Suggestions**: Provides actionable advice based on error type
4. **Pipeline Termination**: Stops current pipeline execution cleanly
5. **Resource Cleanup**: Uses `errdefer` to free allocated resources
6. **No Crashes**: Returns proper exit code without panics or memory leaks

**Supported Error Types:**
- `FileNotFound` - File doesn't exist
- `PermissionDenied` / `AccessDenied` - Insufficient permissions
- `IsDir` - Expected file, got directory
- `NotDir` - Expected directory, got file

## Benefits

- ✅ **Multiple Errors Reported**: See all syntax errors at once (parser)
- ✅ **Better Developer Experience**: Fix all issues together
- ✅ **Clear Error Messages**: Line/column location with descriptive messages
- ✅ **Graceful Failure**: No crashes, proper error reporting and cleanup
- ✅ **Helpful Suggestions**: Actionable advice for fixing errors
- ✅ **No Memory Leaks**: Proper resource cleanup on all error paths
