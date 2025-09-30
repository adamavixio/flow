# Installing Flow

Flow is an AI-first file manipulation language designed to be intuitive for both humans and LLMs.

## Quick Install

```bash
# Build and install (requires sudo for /usr/local/bin)
make install

# Verify installation
flow --version
flow --help
```

## Uninstall

```bash
make uninstall
```

## Usage

```bash
# Run Flow code from a string (quick one-liners)
flow "int : 42 -> print"
flow 'dir : "." -> files -> length -> print'

# Run a Flow program from a file
flow program.flow

# Get help
flow --help

# Check version
flow --version
```

## For LLM Testing

Once installed, Flow is available as a system command. LLMs can use Flow naturally with **no file creation needed**:

```bash
# Example: Simple calculation
flow "int : 42 -> string -> print"

# Example: List files in current directory
flow 'dir : "." -> files -> print'

# Example: Count .zig files in src/
flow 'dir : "src" -> files "*.zig" -> length -> print'

# Example: Read and display file content
flow 'file : "README.md" -> content -> print'

# Example: Get file extension
flow 'path : "test.txt" -> extension -> print'
```

Or save to a .flow file for reusable scripts:

```bash
echo 'dir : "." -> files -> length -> print' > count_files.flow
flow count_files.flow
```

## What Makes Flow LLM-Friendly?

1. **String Execution**: Run code directly without creating files
2. **Linear Pipeline Syntax**: Data flows left-to-right through operations
3. **Explicit Types**: No ambiguity about what type you're working with
4. **Self-Documenting**: `flow --help` shows all syntax and examples
5. **Helpful Errors**: Errors show location, context, and suggestions
6. **No Quote Hell**: Unlike bash, strings are just strings

## Examples

See the `examples/` directory for working examples:
- `examples/behaviors/` - Working programs demonstrating features
- `examples/errors/` - Error cases showing helpful error messages

## Testing Flow Examples

```bash
# Run all tests
make examples

# Run just behavior tests
make examples-behaviors

# Run just error tests
make examples-errors
```