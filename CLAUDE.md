# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About This Repository

This is the Crystal programming language compiler and standard library. Crystal is a statically typed, compiled language with Ruby-like syntax that aims to achieve C-level performance while maintaining developer productivity.

The compiler is written in Crystal itself (self-hosting), and the standard library is located in `src/`.

## Building the Compiler

**Prerequisites:**
- An existing Crystal compiler installation (for bootstrapping)
- LLVM (see `src/llvm/ext/llvm-versions.txt` for compatible versions)
- Required system libraries: https://github.com/crystal-lang/crystal/wiki/All-required-libraries

**Build commands:**
```bash
# Build the compiler (default)
make

# Build with release optimizations
make crystal release=1 interpreter=1

# Build with progress output
make progress=1

# Clean and rebuild
make clean crystal
```

The built compiler is placed in `.build/crystal` (or `.build/crystal.exe` on Windows).

**Using the local compiler:**
Use `./bin/crystal` instead of `crystal` - this wrapper script uses the repository's standard library and the compiled version if available, falling back to the system Crystal compiler.

## Running Tests

```bash
# Run all tests
make test

# Run standard library tests only
make std_spec

# Run compiler tests only
make compiler_spec

# Run primitive tests
make primitives_spec

# Run a specific test file
bin/crystal spec spec/std/array_spec.cr

# Run tests with verbose output
make std_spec verbose=1

# Run tests with specific order
make std_spec order=random
```

Test executables are built in `.build/` directory:
- `.build/std_spec` - Standard library specs
- `.build/compiler_spec` - Compiler specs
- `.build/primitives_spec` - Primitive method specs

## Code Formatting

Crystal has an official code formatter that must be used:

```bash
# Format all source files
crystal tool format

# Check formatting without modifying files
crystal tool format --check

# Format specific files or directories
crystal tool format src/compiler/crystal/codegen/
```

**Git pre-commit hook:** Install the formatting pre-commit hook to ensure all commits are properly formatted:
```bash
ln -s scripts/git/pre-commit .git/hooks
```

This hook runs `crystal tool format --check` on all staged `.cr` files before allowing a commit.

## Documentation

```bash
# Generate standard library documentation
make docs
```

Output goes to `docs/` directory. Documentation is written inline in the source code using a subset of Markdown.

**Documentation guidelines:**
- Use third-person perspective
- Document all public APIs with parameter descriptions and examples
- Follow the conventions at https://crystal-lang.org/reference/conventions/documenting_code.html

## Architecture Overview

### Compiler Structure (`src/compiler/crystal/`)

The compiler is organized into these major components:

- **`syntax/`** - Lexer and parser that transform source code into an Abstract Syntax Tree (AST)
- **`semantic/`** - Type inference, method resolution, and semantic analysis
  - Type unification and inference
  - Method dispatch resolution
  - Macro expansion
  - Generic type instantiation
- **`codegen/`** - LLVM code generation that transforms the typed AST into native code
  - Handles memory management integration with garbage collector
  - Optimizes Crystal's high-level constructs to efficient LLVM IR
- **`interpreter/`** - Interpreter for compile-time code execution (macros, compile-time constants)
- **`tools/`** - Built-in tools (formatter, documentation generator, etc.)
- **`command/`** - CLI command implementations (`build`, `spec`, `run`, etc.)

Key files:
- `src/compiler/crystal.cr` - Compiler entry point (requires wrapper environment variable)
- `src/compiler/compiler.cr` - Main compiler orchestration
- `src/compiler/program.cr` - Program representation and type system
- `src/compiler/types.cr` - Type system implementation

### Standard Library (`src/`)

The standard library is organized into thematic modules. Important top-level files include:
- `src/prelude.cr` - Core types and methods loaded automatically
- Various `.cr` files for different stdlib components (collections, IO, concurrency, etc.)

### Build System

- Uses GNU Make
- The `bin/crystal` wrapper script manages paths and delegates to either `.build/crystal` or the system compiler
- LLVM integration via `src/llvm/ext/` (C++ extension for LLVM < 18)
- Environment variables:
  - `CRYSTAL_PATH` - Search path for required files (defaults to `./lib:$CRYSTAL_ROOT/src`)
  - `CRYSTAL_LIBRARY_PATH` - Native library search path
  - `CRYSTAL_HAS_WRAPPER` - Set by `bin/crystal` wrapper to prevent direct compilation

## Development Workflow

### Making Changes to Standard Library

1. Edit files in `src/`
2. Add corresponding specs in `spec/std/`
3. Run relevant tests: `bin/crystal spec spec/std/your_spec.cr`
4. Format code: `crystal tool format`
5. Run full test suite: `make std_spec`

### Making Changes to Compiler

1. Edit files in `src/compiler/`
2. Add specs in `spec/compiler/`
3. Rebuild compiler: `make crystal`
4. Test: `make compiler_spec`
5. May need to run benchmarks for performance-sensitive changes

### Testing Single Changes Quickly

For quick iteration on stdlib changes:
```bash
# Test a specific spec file
bin/crystal spec spec/std/string_spec.cr

# Run a single example
bin/crystal run examples/your_example.cr
```

## Key Environment Variables

- `CRYSTAL` - Path to parent crystal compiler (default: `crystal`)
- `LLVM_CONFIG` - Path to llvm-config (auto-detected if not set)
- `CRYSTAL_PATH` - Compiler search path for source files
- `CRYSTAL_LIBRARY_PATH` - Runtime library search path

## Important Notes

### Compiler Self-Hosting

The compiler is written in Crystal, so you need an existing Crystal compiler to build it. This creates a bootstrap dependency. The `bin/crystal` wrapper handles this by:
1. Using `.build/crystal` if it exists (locally built compiler)
2. Falling back to system `crystal` command
3. Setting appropriate environment variables for library paths

### Direct Compilation Warning

Do not compile `src/compiler/crystal.cr` directly without the wrapper. It requires `CRYSTAL_HAS_WRAPPER` environment variable or the `i_know_what_im_doing` flag. Always use `make crystal` or `bin/crystal`.

### LLVM Integration

- For LLVM >= 18, no additional extension is needed
- For LLVM < 18, requires building `src/llvm/ext/llvm_ext.o`
- Compatible LLVM versions are listed in `src/llvm/ext/llvm-versions.txt`

## Contributing

Before submitting PRs:
1. Open an issue first for new features (unless it's a minor fix)
2. Ensure all tests pass: `make test`
3. Format code: `crystal tool format`
4. Review CONTRIBUTING.md for detailed guidelines
5. Use squash merge for PRs (maintainers handle this)
6. Don't force-push to PR branches - preserve review history

## Common Make Targets

```bash
make              # Build compiler
make test         # Run all tests
make spec         # Run all specs (std, compiler, primitives)
make crystal      # Build compiler explicitly
make clean        # Remove build artifacts
make format       # Format all source code
make docs         # Generate documentation
make help         # Show all available targets
```

## Platform Notes

- **Windows**: Use `Makefile.win` for native Windows builds
- **MSYS2**: Can use the regular `Makefile`
- Shell scripts use POSIX sh, should work on all Unix-like systems
