# Crystal Debugging Guide

Quick start guide for debugging Crystal programs in VSCode using lldb-dap.

## Prerequisites

- Crystal compiler with `-d` (debug) flag support
- LLDB (comes with Xcode Command Line Tools or LLVM)
- VSCode with lldb-dap support (built into recent versions)

## Quick Start (VSCode)

###1. Open Your Crystal Project

```bash
cd your-crystal-project
code .
```

### 2. Set Breakpoints

Click in the left margin of your `.cr` file to set breakpoints (red dots will appear).

### 3. Start Debugging

**Method A: Debug Current File**
- Open your `.cr` file
- Press `F5`
- Select "Crystal: Debug Current File"
- Program auto-compiles with `-d` and starts debugging

**Method B: Debug Existing Binary**
- Build with debug info: `crystal build -d your_program.cr`
- Press `F5`
- Select "Crystal: Debug Program"
- Enter path to your binary

### 4. Use Debugger Features

- **Step Over** (`F10`): Execute current line
- **Step Into** (`F11`): Step into function calls
- **Step Out** (`Shift+F11`): Step out of current function
- **Continue** (`F5`): Run until next breakpoint
- **Variables Panel**: See all local variables with Crystal formatters
- **Watch Expressions**: Add expressions to monitor
- **Debug Console**: Evaluate expressions

## Debug Features

### ✅ Working Features

**Basic Debugging:**
- Breakpoints in `.cr` files
- Step through code (over/into/out)
- View call stack
- Inspect variables

**Crystal-Specific:**
- **String Formatting**: Shows `"Hello, Crystal!"` instead of pointers
- **Array Formatting**: Displays array elements `[1, 2, 3, 4, 5]`
- **Hash Formatting**: Shows key-value pairs with expandable entries
- **Set Formatting**: Displays elements like `Set{1, 2, 3, 4, 5}`
- **Range Formatting**: Distinguishes `1..10` (inclusive) from `1...10` (exclusive)
- **Tuple Formatting**: Shows elements `(42, "answer", 3.14)`
- **NamedTuple Formatting**: Shows named fields `(name: "Crystal", version: 1)`
- **Constants**: Visible in debugger (Phase 3.5)
- **Macros**: Step through expanded macro source (Phase 3.7)
- **Procs**: Debug info for Proc types (Phase 3.1)
- **Generics**: Distinguish `Array(Int32)` from `Array(String)` (Phase 3.3)

### Example Session

```crystal
# test.cr
def greet(name : String)
  message = "Hello, #{name}!"
  result = name.size * 2  # Set breakpoint here
  result
end

x = greet("Crystal")
puts "Result: #{x}"
```

**In Debugger:**
```
Breakpoint hit at test.cr:4

Variables:
  name: (String *) "Crystal"
  message: (String *) "Hello, Crystal!"
  result: (Int32) 14

Watch:
  name.size → 7
```

### Crystal Type Formatters

Crystal-specific type formatters make debugging easier by showing human-readable values:

**String and Array:**
```
(lldb) p my_string
(String *) "Hello, Crystal!"

(lldb) p my_array
(Array(Int32)) [1, 2, 3, 4, 5]
```

**Hash (use `*` to dereference):**
```
(lldb) p *my_hash
(Hash(String, Int32)) {
  [0] = (hash = 454616463, key = "one", value = 1)
  [1] = (hash = 1673748108, key = "two", value = 2)
  [2] = (hash = 1680372361, key = "three", value = 3)
}
```

**Set:**
```
(lldb) p my_set
(Set(Int32)) Set{10, 20, 30, 40, 50}
```

**Range (inclusive vs exclusive):**
```
(lldb) p my_range_incl
(Range(Int32, Int32)) 1..10

(lldb) p my_range_excl
(Range(Int32, Int32)) 1...10
```

**Tuple:**
```
(lldb) p my_tuple
(Tuple(Int32, String, Float64)) ([0] = 42, [1] = "answer", [2] = 3.14)
```

**NamedTuple:**
```
(lldb) p my_named_tuple
(NamedTuple(name: String, version: Int32)) (name = "Crystal", version = 1)
```

## Command Line Debugging (LLDB)

### Basic Usage

```bash
# 1. Build with debug info
crystal build -d your_program.cr

# 2. Start LLDB
lldb your_program

# 3. Load Crystal formatters (automatic if .lldbinit exists)
(lldb) command script import etc/lldb/crystal_formatters.py

# 4. Set breakpoint
(lldb) b your_file.cr:10

# 5. Run
(lldb) run

# 6. Inspect variables
(lldb) frame variable
(lldb) p my_variable

# 7. Step through code
(lldb) step      # Step into
(lldb) next      # Step over
(lldb) finish    # Step out
(lldb) continue  # Continue execution
```

### LLDB Commands Reference

| Command | Shortcut | Description |
|---------|----------|-------------|
| `run` | `r` | Start program |
| `continue` | `c` | Continue execution |
| `step` | `s` | Step into |
| `next` | `n` | Step over |
| `finish` | `f` | Step out |
| `breakpoint set` | `b` | Set breakpoint |
| `frame variable` | `fr v` | Show local variables |
| `print` | `p` | Evaluate expression |
| `backtrace` | `bt` | Show call stack |
| `quit` | `q` | Exit LLDB |

## Configuration Files

### `.lldbinit` (Project Root)

Auto-loads Crystal formatters when LLDB starts in this directory:

```python
# Crystal LLDB Configuration
command script import etc/lldb/crystal_formatters.py
settings set target.inline-breakpoint-strategy always
```

### `.vscode/launch.json`

Pre-configured debug configurations:
- **Crystal: Debug Current File** - Auto-compile current file
- **Crystal: Debug Program** - Debug any binary
- **Debug compiler** - Debug Crystal compiler itself

### `.vscode/tasks.json`

Build tasks:
- `crystal: build current file (debug)` - Compile with `-d`
- `crystal: build current file (release)` - Optimized build
- `crystal: run current file` - Quick execution
- `crystal: spec current file` - Run specs

## Tips & Tricks

### 1. Compile with Maximum Debug Info

```bash
crystal build -d your_program.cr
```

The `-d` flag enables:
- Full variable debug info
- No function inlining
- No optimizations
- Constants visibility
- Macro expanded source

### 2. Debug Macros

When stepping through macro-generated code, LLDB shows expanded source from temp files:

```
/tmp/crystal-macro-debug-<PID>/macro_name_line15.cr:3
```

This allows you to see exactly which line of the expanded macro you're on!

### 3. View Constants

Constants are visible in debugger:

```crystal
PI_VALUE = 3.14159
MY_CONST = "hello"

# In debugger:
(lldb) p PI_VALUE
(double) 3.14159

(lldb) p MY_CONST
(String *) "hello"
```

### 4. Inspect Complex Types

Crystal formatters show readable values:

```crystal
my_array = [1, 2, 3, 4, 5]
my_string = "Hello, Crystal!"

# In Variables panel:
my_array: (Array(Int32) *) [1, 2, 3, 4, 5]
my_string: (String *) "Hello, Crystal!"
```

### 5. Debug Specs

Run specs with debugging:

```bash
crystal build -d spec/my_spec.cr
lldb spec/my_spec
(lldb) r
```

Or use VSCode task: `crystal: spec current file`

## Troubleshooting

### Formatters Not Loading

**Problem**: Variables show as raw pointers

**Solution**:
```bash
# Check .lldbinit exists
ls .lldbinit

# Manually load formatters
(lldb) command script import etc/lldb/crystal_formatters.py
```

### Breakpoints Not Working

**Problem**: Breakpoints show as "unresolved"

**Solution**:
- Ensure you compiled with `-d` flag
- Check file path matches exactly (case-sensitive)
- Rebuild if source changed

### Can't See Variables

**Problem**: Variables show as "optimized out"

**Solution**:
- Compile with `-d` flag (disables optimizations)
- Don't use `--release` when debugging
- Some variables may still be optimized even in debug mode

### lldb-dap Not Found

**Problem**: VSCode can't find lldb-dap

**Solution**:
```bash
# Find lldb-dap path
which lldb-dap

# Add to launch.json if needed
"lldbDAPPath": "/opt/homebrew/opt/llvm/bin/lldb-dap"
```

## Advanced Topics

### Custom Formatters

Add your own type formatters in `etc/lldb/crystal_formatters.py`:

```python
class MyTypeSummaryProvider:
    def __init__(self, valobj, dict):
        self.valobj = valobj

    def update(self):
        # Update internal state
        pass

    def has_children(self):
        return True

    def get_value(self):
        # Return summary string
        return "MyType summary"
```

### Expression Evaluation

Evaluate Crystal expressions in debug console:

```
(lldb) p obj.@instance_var
(lldb) p method_call(arg)
(lldb) p 2 + 2
```

**Note**: Complex expressions may not work as Crystal doesn't have full expression evaluator yet.

### Remote Debugging

Debug programs on remote machines:

```bash
# On remote machine:
lldb-server platform --listen *:1234

# On local machine:
(lldb) platform select remote-linux
(lldb) platform connect connect://remote:1234
(lldb) file your_program
(lldb) run
```

## Resources

- [LLDB Documentation](https://lldb.llvm.org/)
- [DAP Protocol Specification](https://microsoft.github.io/debug-adapter-protocol/)
- [Crystal Debugging Roadmap](../DEBUGGING_ROADMAP.md)
- [VSCode Debugging](https://code.visualstudio.com/docs/editor/debugging)

## Next Steps

**Phase 2: Enhanced Formatters**
- Hash, Set, Tuple formatters
- Better array element display
- Custom type formatters

**Phase 4: Expression Evaluation**
- Full Crystal expression support in debugger
- Method calls on objects
- REPL in debug context

See [DEBUGGING_ROADMAP.md](../DEBUGGING_ROADMAP.md) for detailed roadmap.
