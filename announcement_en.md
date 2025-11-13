# Automatic Debugging Setup for Crystal in VSCode

Hi everyone,

I've been working on improving the debugging experience for Crystal applications and wanted to share the results with the community.

## The Problem

When I started working with Crystal, setting up debugging in VSCode felt like a quest: create `.vscode/launch.json` by hand, find LLDB formatters somewhere, write the correct paths, configure import commands. And in the Variables panel, all variables showed up as raw pointers - I had to manually parse memory structures just to see the contents of a String or Array.

I thought - why not automate this entire process?

## What's Been Done

### DWARF Debug Info Improvements

First I had to improve the basic DWARF debug info in the Crystal compiler - without this even simple things worked poorly.

**Macro debugging (Phase 3.7)** - previously when debugging macros, the debugger only showed the line with the macro invocation, and when trying to step into it would just skip over all the expanded code. Now temporary files (`/tmp/crystal-macro-debug-<PID>/`) are created with the expanded source, and DWARF debug info points to them. You can step-by-step through each line of macro expansion and inspect variables. Only works in debug mode (`-d` flag) for zero overhead in production.

Implementation in `src/compiler/crystal/codegen/debug.cr` - when generating debug info for VirtualFile I check the debug mode flag and create a temp file with the content, replacing the path in DWARF metadata.

**Block/closure debugging (Phase 3.6)** - verified that this already works correctly. You can see block parameters, local variables, captured variables. Stepping through blocks works as expected.

**Constants debugging (Phase 3.5)** - added DWARF debug info generation for global constants. Previously constants weren't visible in the debugger at all - now you can do `p CONSTANT_NAME` and see the value.

Implementation in `src/compiler/crystal/codegen/debug.cr:declare_const_debug_info` - I create a `DIGlobalVariableExpression` and attach it to the LLVM global via `global.add_debug_info()`. The key point is needing to switch to `@main_mod` context before creating debug metadata, otherwise LLVM doesn't register the variable in the compilation unit.

**Class variables debugging (Phase 3.5.1)** - added DWARF debug info generation for class variables. Now `@@class_var` are visible in debugger via `target variable -r ClassName`. Shows correct type and value: `(int) Counter::total = 30`. Instance variables (`@ivar`) already worked as struct fields.

Implementation in `src/compiler/crystal/codegen/class_var.cr:declare_class_var_debug_info` - follows same pattern as constants, extracts location from initializer, creates `DIGlobalVariableExpression` with class_var_global_name.

**Proc types** - added DWARF debug types for `Proc` and `NilableProc`. Previously they showed up as `void*` in the debugger - now you can see that it's specifically a Proc with the correct parameters and return type.

Implementation in `src/llvm/di_builder.cr` - added bindings for `LLVMDIBuilderCreateSubroutineType` and a `create_subroutine_type` method for generating debug types for functions.

**Generic types and inline functions** - verified that these already work. Generic types are correctly instantiated in debug info, inline functions generate correct DWARF location info.

All these improvements work at the DWARF level - meaning they help any debugger (LLDB, GDB, lldb-dap in VSCode, CodeLLDB extension, etc), not just VSCode.

### Phase 1: Auto-generation in crystal init

Now `crystal init` automatically creates a complete VSCode debugging configuration:
- `.vscode/launch.json` with two debug configurations (current file and main program)
- `.vscode/tasks.json` with build tasks
- `.vscode/crystal_formatters.py` with LLDB formatters and custom commands

Just press F5 right after `crystal init app myapp` - and debugging works.

Implementation in `src/compiler/crystal/tools/init.cr` through the View/template system - added three new Views for VSCode files (two ECR templates and one static Python file).

### Phase 2: crystal tool debug:setup for existing projects

Added a new command `crystal tool debug:setup` for setting up debugging in existing projects.

```bash
crystal tool debug:setup           # Setup for current project
crystal tool debug:setup --global  # Update ~/.lldbinit
crystal tool debug:setup --force   # Overwrite existing files
```

The command detects the project name from `shard.yml` (or uses the directory name), creates VSCode configuration, copies formatters from the Crystal installation. With the `--global` flag it updates `~/.lldbinit` for system-wide LLDB (works in CLI, Xcode, other IDEs).

Implementation in `src/compiler/crystal/command/debug_setup.cr` - uses `Crystal::Config.exec_path` to locate formatters, YAML parser to read shard.yml, colorized output.

### Phase 3: LLDB Type Formatters

Wrote formatters for Crystal's core types. Instead of pointers, the Variables panel now shows:

- **String**: `"Hello, Crystal!"` instead of `0x00007f8b9c0001a0`
- **Array**: `[0] = 1, [1] = 2, [2] = 3` with indices
- **Hash**: key-value pairs with proper formatting
- **Set**: `Set{10, 20, 30, ...}`
- **Range**: `1..10` or `1...10`
- **Tuple**: indexed elements
- **NamedTuple**: named fields

The formatters work automatically - no additional commands needed.

### Phase 4: Custom LLDB Commands

Added three custom commands for the Debug Console:

**crystal_size** - collection sizes
```
(lldb) crystal_size my_array
my_array.size = 5
```

**crystal_at** - array element access
```
(lldb) crystal_at my_array 2
my_array[2] = 3
```

**crystal_keys** - Hash keys
```
(lldb) crystal_keys my_hash
Keys: "one", "two", "three"
```

Commands use the LLDB Python API directly - bypassing C++ expression evaluation (which often glitches with Crystal code). They automatically dereference pointers, check array bounds, format String keys.

Implementation in `etc/lldb/crystal_formatters.py` - three command classes (`CrystalSizeCommand`, `CrystalAtCommand`, `CrystalKeysCommand`) with registration through `__lldb_init_module`.

## How to Use

### New project
```bash
crystal init app myapp
cd myapp
code .
# F5 - and debugging works
```

### Existing project
```bash
cd my_project
crystal tool debug:setup
# F5 - and debugging works
```

### System-wide installation
```bash
crystal tool debug:setup --global
# Now formatters work everywhere (CLI LLDB, Xcode, etc)
```

## Documentation

Wrote complete documentation in `etc/lldb/README.md`:
- Installation instructions
- Formatter examples for each type
- Custom commands reference
- Troubleshooting
- VSCode integration details

Added demo file `test/debug_formatters_demo.cr` with usage examples.

## What Wasn't Done and Why

**Support for IDEs other than VSCode** - didn't add because each IDE needs specific research (CLion, Sublime Text, etc). But with the `--global` flag, formatters work in any LLDB-based debugger.

**Windows support** - didn't test (I'm on macOS). The code is written universally (using `::Path`, `File.copy`, etc), but someone needs to test on Windows. Linux should work (LLDB is the same there).

**Advanced LLDB features** - could have added more commands (like `crystal_find` for searching in Hash by key, `crystal_filter` for filtering Arrays, etc). For now limited to basic operations needed in 90% of cases.

**Visual collection representations** - VSCode DAP supports custom visualizers, but that requires a separate extension. Currently using standard LLDB synthetic providers.

## Testing

Tested on macOS with:
- New projects through `crystal init`
- Existing projects through `crystal tool debug:setup`
- Global installation (`--global`)
- All type formatters on real Crystal code
- Custom commands with various data types

Everything works with VSCode + lldb-dap extension.

## Code Location

Branch: https://github.com/skuznetsov/crystal/tree/feature/proc-debug-types

Key files:
- `src/compiler/crystal/tools/init.cr` - auto-generation in crystal init
- `src/compiler/crystal/command/debug_setup.cr` - debug:setup command
- `etc/lldb/crystal_formatters.py` - formatters and commands
- `etc/lldb/README.md` - documentation

Key commits:
1. Proc/NilableProc DWARF types
2. Macro debugging with expanded source visibility
3. Constants debugging (global constants visible)
4. Class variables debugging (@@class_var visible)
5. Enhanced LLDB formatters (String, Array, Hash, Set, Range, Tuple, NamedTuple)
6. Custom LLDB commands (crystal_size, crystal_at, crystal_keys)
7. VSCode integration guide
8. Auto-generate VSCode config in crystal init
9. crystal tool debug:setup command

## Feedback Welcome

Ready for testing! Try it out and let me know:
- What works well
- What doesn't work
- What could be improved
- Platform-specific issues (I only have macOS)

If everything looks good - I'll submit a PR to upstream crystal-lang/crystal.

## Installation for Testing

```bash
git clone -b feature/proc-debug-types https://github.com/skuznetsov/crystal.git
cd crystal
make
./bin/crystal init app test_debug
cd test_debug
code .
# F5!
```

--
ComputerMage
