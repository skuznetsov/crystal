# Crystal Debugging Roadmap

**Status**: Planning Phase
**Goal**: Make Crystal debugging experience best-in-class for systems languages
**Timeline**: 12-16 weeks for MVP

---

## Current State Analysis

### ✅ What Works (implemented 5 years ago)

**DWARF Debug Info Generation** (`src/compiler/crystal/codegen/debug.cr`):
- Basic types (Int32, Float64, Bool, Char, Symbol)
- Structs and classes with instance variables
- Unions (MixedUnionType, ReferenceUnionType, NilableType)
- Collections (StaticArray, Tuple, NamedTuple)
- Enums with values
- Source location mapping via `expanded_location`
- Function metadata (DW_TAG_subprogram with parameters)
- Variable declarations (parameters and locals)

**Debug Modes** (`src/compiler/crystal/compiler.cr:14-18`):
```crystal
enum Debug
  LineNumbers  # --debug (default) - line numbers only
  Variables    # -d - full debug with variables + NoInline + OptimizeNone
  Default = LineNumbers
end
```

**LLDB Formatters** (`etc/lldb/crystal_formatters.py`):
- ✅ `CrystalArraySyntheticProvider` - shows Array elements
- ✅ `CrystalString_SummaryProvider` - pretty-prints String values

### ❌ Critical Gaps

1. **No DAP (Debug Adapter Protocol) server**
   - VSCode/editor integration requires manual LLDB configuration
   - No standardized debug experience

2. **Proc/Closure debug info missing**
   - `NilableProcType` in sinkhole (`debug.cr:305`)
   - Closured variables invisible in debugger
   - Proc literals have no debug metadata

3. **Inline functions invisible**
   - No `DW_TAG_inlined_subroutine` generation
   - Can't step into `@[AlwaysInline]` methods
   - Stack traces skip inlined frames

4. **Macro-expanded code opaque**
   - VirtualFile locations collapse to single expansion line
   - Can't debug macro-generated code
   - No source mapping for macro expansions

5. **Generic type parameters invisible**
   - No `DW_TAG_template_type_parameter`
   - `Array(Int32)` vs `Array(String)` indistinguishable
   - Type parameters not inspectable

6. **Lexical scopes missing**
   - Only function-level scopes
   - No nested scopes for if/while/begin blocks
   - Variable shadowing causes confusion

7. **Expression evaluation not supported**
   - Can't evaluate Crystal expressions in paused state
   - No REPL in debug context
   - Method calls on objects don't work

8. **Limited LLDB formatters**
   - Only Array and String supported
   - Missing: Hash, Set, Tuple, NamedTuple, Range
   - No custom object formatters

---

## Architecture Overview

```
┌────────────────────────────────────────────────────────────┐
│                     VSCode / Editor                         │
│  - Debug UI (breakpoints, variables, watch, call stack)    │
│  - Debug Console (expression evaluation)                   │
└────────────────────────────────────────────────────────────┘
                            ↕ DAP Protocol (JSON-RPC)
┌────────────────────────────────────────────────────────────┐
│               Crystal DAP Server (NEW)                      │
│  - Protocol handler (launch, attach, breakpoints, etc.)    │
│  - LLDB integration (C API bindings)                       │
│  - Crystal type system awareness                           │
│  - Expression evaluator (JIT compilation)                  │
│  - Custom formatters (reuse crystal_formatters.py logic)   │
└────────────────────────────────────────────────────────────┘
                            ↕ LLDB C API
┌────────────────────────────────────────────────────────────┐
│                   LLDB Debugger Backend                     │
│  - liblldb.dylib (macOS) / liblldb.so (Linux)             │
│  - DWARF parser                                            │
│  - Process control (breakpoints, stepping, etc.)           │
└────────────────────────────────────────────────────────────┘
                            ↕ ptrace/debug API
┌────────────────────────────────────────────────────────────┐
│              Crystal Program (debuggee)                     │
│  - Compiled with -d flag (full debug info)                │
│  - Embedded type metadata (future)                         │
└────────────────────────────────────────────────────────────┘
```

---

## Phase 1: DAP Server MVP (4 weeks)

**Goal**: Basic debugging works out-of-box in VSCode

### Week 1-2: Core DAP Server

**Location**: New directory `src/dap/` in Crystal repo

**Components**:
1. **Protocol Handler** (`src/dap/protocol.cr`)
   - JSON-RPC parser/serializer
   - DAP message types (Request, Response, Event)
   - stdio/TCP transport

2. **LLDB Bindings** (`src/dap/lldb_bindings.cr`)
   ```crystal
   @[Link("lldb")]
   lib LibLLDB
     # Core types
     type SBDebugger = Void*
     type SBTarget = Void*
     type SBProcess = Void*
     type SBThread = Void*
     type SBFrame = Void*
     type SBBreakpoint = Void*
     type SBValue = Void*

     # Initialization
     fun SBDebugger_Create = SBDebuggerCreate() : SBDebugger
     fun SBDebugger_Destroy = SBDebuggerDestroy(debugger : SBDebugger)

     # Target management
     fun SBDebugger_CreateTarget = SBDebuggerCreateTarget(
       debugger : SBDebugger,
       filename : UInt8*,
       target_triple : UInt8*,
       platform_name : UInt8*,
       add_dependent_modules : Bool,
       error : SBError*
     ) : SBTarget

     # Process control
     fun SBTarget_LaunchSimple = SBTargetLaunchSimple(
       target : SBTarget,
       argv : UInt8**,
       envp : UInt8**,
       working_directory : UInt8*
     ) : SBProcess

     # Breakpoints
     fun SBTarget_BreakpointCreateByLocation =
       SBTargetBreakpointCreateByLocation(
         target : SBTarget,
         file : UInt8*,
         line : UInt32
       ) : SBBreakpoint

     # Stepping
     fun SBThread_StepOver = SBThreadStepOver(thread : SBThread)
     fun SBThread_StepInto = SBThreadStepInto(thread : SBThread)
     fun SBThread_StepOut = SBThreadStepOut(thread : SBThread)

     # Variable inspection
     fun SBFrame_GetVariables = SBFrameGetVariables(
       frame : SBFrame,
       arguments : Bool,
       locals : Bool,
       statics : Bool,
       in_scope_only : Bool
     ) : SBValueList

     # ... more bindings
   end
   ```

3. **Session Manager** (`src/dap/session.cr`)
   ```crystal
   class DAP::Session
     @debugger : LibLLDB::SBDebugger
     @target : LibLLDB::SBTarget?
     @process : LibLLDB::SBProcess?
     @breakpoints : Hash(Int32, LibLLDB::SBBreakpoint)

     def initialize
       @debugger = LibLLDB.SBDebugger_Create
       @breakpoints = {} of Int32 => LibLLDB::SBBreakpoint
     end

     def launch(program : String, args : Array(String), env : Hash(String, String))
       # Create target
       error = LibLLDB::SBError.new
       @target = LibLLDB.SBDebugger_CreateTarget(
         @debugger, program, nil, nil, true, pointerof(error)
       )

       # Launch process
       @process = LibLLDB.SBTarget_LaunchSimple(
         @target, args, env, Dir.current
       )

       # Send initialized event
       send_event("initialized")
     end

     def set_breakpoint(file : String, line : Int32) : Int32
       bp = LibLLDB.SBTarget_BreakpointCreateByLocation(
         @target, file, line
       )
       bp_id = allocate_breakpoint_id
       @breakpoints[bp_id] = bp
       bp_id
     end

     def continue
       LibLLDB.SBProcess_Continue(@process)
       wait_for_event
     end

     def step_over
       thread = get_current_thread
       LibLLDB.SBThread_StepOver(thread)
       wait_for_event
     end

     # ... more methods
   end
   ```

4. **Main Server** (`src/dap/server.cr`)
   ```crystal
   require "json"
   require "./protocol"
   require "./session"

   module DAP
     class Server
       @session : Session
       @seq : Int32 = 0

       def initialize(@input : IO, @output : IO)
         @session = Session.new
       end

       def run
         loop do
           message = read_message
           handle_message(message)
         end
       end

       def handle_message(msg : Protocol::Request)
         case msg.command
         when "initialize"
           handle_initialize(msg)
         when "launch"
           handle_launch(msg)
         when "setBreakpoints"
           handle_set_breakpoints(msg)
         when "continue"
           handle_continue(msg)
         when "next"
           handle_next(msg)
         when "stepIn"
           handle_step_in(msg)
         when "stepOut"
           handle_step_out(msg)
         when "stackTrace"
           handle_stack_trace(msg)
         when "scopes"
           handle_scopes(msg)
         when "variables"
           handle_variables(msg)
         when "evaluate"
           handle_evaluate(msg)
         else
           send_error_response(msg, "Unknown command: #{msg.command}")
         end
       end

       # ... implementation of handlers
     end
   end

   # Entry point
   server = DAP::Server.new(STDIN, STDOUT)
   server.run
   ```

**CLI Integration**:
```bash
# Build DAP server
crystal build src/dap/server.cr -o bin/crystal-dap

# VSCode will launch it automatically via launch.json
```

### Week 3: VSCode Extension Enhancement

**Location**: `etc/vscode/crystal-debug/`

**package.json** additions:
```json
{
  "contributes": {
    "debuggers": [
      {
        "type": "crystal",
        "label": "Crystal Debug",
        "program": "./bin/crystal-dap",
        "configurationAttributes": {
          "launch": {
            "required": ["program"],
            "properties": {
              "program": {
                "type": "string",
                "description": "Path to Crystal source file or compiled binary"
              },
              "args": {
                "type": "array",
                "description": "Command line arguments"
              },
              "env": {
                "type": "object",
                "description": "Environment variables"
              },
              "buildFlags": {
                "type": "array",
                "description": "Crystal compiler flags",
                "default": ["-d"]
              },
              "stopOnEntry": {
                "type": "boolean",
                "description": "Automatically stop after launch",
                "default": true
              }
            }
          }
        },
        "configurationSnippets": [
          {
            "label": "Crystal: Debug Program",
            "body": {
              "type": "crystal",
              "request": "launch",
              "name": "Debug Crystal Program",
              "program": "^\"\\${workspaceFolder}/\\${file}\"",
              "stopOnEntry": false
            }
          }
        ]
      }
    ]
  }
}
```

**Custom Variable Formatters** (`extension.ts`):
```typescript
// Port crystal_formatters.py logic to TypeScript
export class CrystalDebugAdapterDescriptorFactory
  implements vscode.DebugAdapterDescriptorFactory {

  createDebugAdapterDescriptor(
    session: vscode.DebugSession
  ): vscode.ProviderResult<vscode.DebugAdapterDescriptor> {
    // Launch crystal-dap server
    const dapPath = path.join(extensionPath, 'bin/crystal-dap');
    return new vscode.DebugAdapterExecutable(dapPath);
  }
}

// Custom variable rendering
export function formatCrystalValue(
  variable: DebugProtocol.Variable
): string {
  const type = variable.type;

  if (type?.startsWith('Array(')) {
    // Array: show [1, 2, 3] instead of raw pointer
    return formatArray(variable);
  } else if (type === 'String') {
    // String: show "hello" instead of struct
    return formatString(variable);
  } else if (type?.startsWith('Hash(')) {
    return formatHash(variable);
  }
  // ... more formatters

  return variable.value;
}
```

### Week 4: Testing & Polish

**Test Suite** (`spec/dap/`):
```crystal
describe DAP::Server do
  it "launches program and stops at breakpoint" do
    server = create_test_server

    # Send initialize request
    server.send_request("initialize", {...})
    expect_response("initialize")

    # Set breakpoint
    server.send_request("setBreakpoints", {
      source: {path: "/tmp/test.cr"},
      breakpoints: [{line: 5}]
    })
    expect_response("setBreakpoints")

    # Launch
    server.send_request("launch", {
      program: "/tmp/test.cr"
    })

    # Should stop at breakpoint
    expect_event("stopped", {reason: "breakpoint"})
  end

  it "inspects variables" do
    # ... test variable inspection
  end

  # ... more tests
end
```

**Manual Testing Checklist**:
- [ ] Launch Crystal program from VSCode
- [ ] Set breakpoint on line
- [ ] Breakpoint hits correctly
- [ ] Step over/into/out works
- [ ] Variables panel shows locals
- [ ] Call stack shows Crystal functions
- [ ] String/Array formatted nicely
- [ ] Continue execution works
- [ ] Program terminates cleanly

**Deliverables**:
- ✅ `bin/crystal-dap` executable
- ✅ VSCode extension with DAP support
- ✅ Basic debugging works (launch, breakpoints, stepping, variables)
- ✅ Documentation: `docs/debugging/getting-started.md`

---

## Phase 2: Enhanced LLDB Formatters (2 weeks)

**Goal**: Make variable inspection delightful

### Extend `crystal_formatters.py`

**Current** (`etc/lldb/crystal_formatters.py:3-63`):
- ✅ Array
- ✅ String

**Add**:

1. **Hash** (most requested):
```python
class CrystalHashSyntheticProvider:
    def __init__(self, valobj, internal_dict):
        self.valobj = valobj
        self.entries = []

    def update(self):
        if self.valobj.type.is_pointer:
            self.valobj = self.valobj.Dereference()

        # Hash internal structure:
        # @size : Int32
        # @indices_bytesize : UInt8
        # @indices : Pointer(UInt8)
        # @entries_bytesize : UInt8
        # @entries : Pointer(Entry(K, V))

        size = int(self.valobj.GetChildMemberWithName('size').GetValue())
        entries_ptr = self.valobj.GetChildMemberWithName('entries')

        # Parse Entry(K, V) struct array
        self.entries = []
        for i in range(size):
            entry = entries_ptr.GetChildAtIndex(i)
            key = entry.GetChildMemberWithName('key')
            value = entry.GetChildMemberWithName('value')
            self.entries.append((key, value))

    def num_children(self):
        return len(self.entries)

    def get_child_at_index(self, index):
        if index >= len(self.entries):
            return None
        key, value = self.entries[index]
        # Return as {key => value}
        return create_value_from_expression(
            f'[{index}]',
            f'{key} => {value}'
        )

def CrystalHash_SummaryProvider(value, dict):
    if value.TypeIsPointerType():
        value = value.Dereference()
    size = int(value.GetChildMemberWithName('size').GetValue())
    return f'Hash(size={size})'
```

2. **Tuple**:
```python
def CrystalTuple_SummaryProvider(value, dict):
    if value.TypeIsPointerType():
        value = value.Dereference()

    # Tuple stored as struct with fields [0], [1], [2], ...
    num_fields = value.GetNumChildren() - 1  # -1 for type_id
    elements = []
    for i in range(num_fields):
        field = value.GetChildAtIndex(i + 1)  # Skip type_id
        elements.append(str(field.GetValue()))

    return '{' + ', '.join(elements) + '}'
```

3. **NamedTuple**:
```python
def CrystalNamedTuple_SummaryProvider(value, dict):
    if value.TypeIsPointerType():
        value = value.Dereference()

    # NamedTuple has named fields
    pairs = []
    for i in range(value.GetNumChildren() - 1):
        field = value.GetChildAtIndex(i + 1)
        name = field.GetName()
        val = field.GetValue()
        pairs.append(f'{name}: {val}')

    return '{' + ', '.join(pairs) + '}'
```

4. **Range**:
```python
def CrystalRange_SummaryProvider(value, dict):
    if value.TypeIsPointerType():
        value = value.Dereference()

    begin = value.GetChildMemberWithName('begin')
    end = value.GetChildMemberWithName('end')
    exclusive = value.GetChildMemberWithName('exclusive')

    op = '...' if exclusive.GetValue() == 'true' else '..'
    return f'{begin.GetValue()}{op}{end.GetValue()}'
```

5. **Pointer**:
```python
def CrystalPointer_SummaryProvider(value, dict):
    # Show pointed value, not raw address
    if value.TypeIsPointerType():
        pointed = value.Dereference()
        return f'Pointer -> {pointed.GetValue()}'
    return str(value.GetValue())
```

**Registration** (update `__lldb_init_module`):
```python
def __lldb_init_module(debugger, dict):
    debugger.HandleCommand(
        r'type synthetic add -l crystal_formatters.CrystalArraySyntheticProvider '
        r'-x "^Array\(.+\)(\s*\**)?" -w Crystal'
    )
    debugger.HandleCommand(
        r'type summary add -F crystal_formatters.CrystalString_SummaryProvider '
        r'-x "^(String|\(String \| Nil\))(\s*\**)?$" -w Crystal'
    )
    debugger.HandleCommand(
        r'type synthetic add -l crystal_formatters.CrystalHashSyntheticProvider '
        r'-x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal'
    )
    debugger.HandleCommand(
        r'type summary add -F crystal_formatters.CrystalHash_SummaryProvider '
        r'-x "^Hash\(.+,.+\)(\s*\**)?" -w Crystal'
    )
    debugger.HandleCommand(
        r'type summary add -F crystal_formatters.CrystalTuple_SummaryProvider '
        r'-x "^Tuple\(.+\)(\s*\**)?" -w Crystal'
    )
    debugger.HandleCommand(
        r'type summary add -F crystal_formatters.CrystalNamedTuple_SummaryProvider '
        r'-x "^NamedTuple\(.+\)(\s*\**)?" -w Crystal'
    )
    debugger.HandleCommand(
        r'type summary add -F crystal_formatters.CrystalRange_SummaryProvider '
        r'-x "^Range\(.+\)(\s*\**)?" -w Crystal'
    )
    debugger.HandleCommand(
        r'type summary add -F crystal_formatters.CrystalPointer_SummaryProvider '
        r'-x "^Pointer\(.+\)(\s*\**)?" -w Crystal'
    )
    debugger.HandleCommand(r'type category enable Crystal')
```

### DAP Server Integration

**Port formatters to Crystal** (`src/dap/formatters.cr`):
```crystal
module DAP::Formatters
  # Convert LLDB SBValue to DAP Variable
  def self.format_value(sb_value : LibLLDB::SBValue) : Protocol::Variable
    type_name = LibLLDB.SBValue_GetTypeName(sb_value)

    case
    when type_name.starts_with?("Array(")
      format_array(sb_value)
    when type_name == "String"
      format_string(sb_value)
    when type_name.starts_with?("Hash(")
      format_hash(sb_value)
    when type_name.starts_with?("Tuple(")
      format_tuple(sb_value)
    # ... more cases
    else
      format_generic(sb_value)
    end
  end

  private def self.format_array(sb_value)
    size = LibLLDB.SBValue_GetChildMemberWithName(sb_value, "size")
    size_int = LibLLDB.SBValue_GetValueAsUnsigned(size)

    Protocol::Variable.new(
      name: LibLLDB.SBValue_GetName(sb_value),
      value: "Array(size=#{size_int})",
      type: LibLLDB.SBValue_GetTypeName(sb_value),
      variables_reference: allocate_reference(sb_value),
      indexed_variables: size_int
    )
  end

  # ... more formatters
end
```

**Deliverables**:
- ✅ Extended `crystal_formatters.py` with Hash, Tuple, NamedTuple, Range, Pointer
- ✅ DAP server uses same formatting logic
- ✅ Test suite for formatters
- ✅ Documentation update

---

## Phase 3: Compiler Debug Info Enhancements (4 weeks)

### Week 1: Proc/Closure Debug Info

**Problem**: Procs invisible, closured variables inaccessible

**Solution**: Generate debug types for ProcInstanceType

**Implementation** (`src/compiler/crystal/codegen/debug.cr`):

```crystal
# Add after line 305 (remove from sinkhole)
def create_debug_type(type : ProcInstanceType, original_type : Type)
  # Proc representation: {Void*, Void*} = {func_ptr, context_ptr}
  # For debugger: show as function pointer type

  arg_types = type.arg_types.map { |t| get_debug_type(t) }.compact
  return_type = get_debug_type(type.return_type) ||
                di_builder.create_unspecified_type("void")

  # Create subroutine type
  subroutine_type = di_builder.create_subroutine_type(
    nil,
    [return_type] + arg_types
  )

  # Proc is {func_ptr, context_ptr}
  # We'll show it as pointer to function for now
  di_builder.create_pointer_type(
    subroutine_type,
    8u64 * llvm_typer.pointer_size,
    8u64 * llvm_typer.pointer_size,
    original_type.to_s
  )
end

def create_debug_type(type : NilableProcType, original_type : Type)
  # Nilable Proc: similar to Proc but can be null
  proc_type = create_debug_type(type.proc_type, type.proc_type)
  return unless proc_type

  # For now, treat same as regular Proc
  # TODO: represent as union {null, proc}
  proc_type
end
```

**Closure Context Debug Info**:

```crystal
# In codegen/fun.cr, after setting up closure_ptr
def setup_closure_vars(def_vars, closure_vars, context, closure_type, closure_ptr)
  # ... existing code ...

  # NEW: Declare closure context for debugging
  if @debug.variables?
    declare_closure_context_variable(closure_vars, closure_ptr, def_vars.first?.try(&.location))
  end
end

# In codegen/debug.cr
def declare_closure_context_variable(closure_vars, closure_ptr, location)
  return unless location

  # Create synthetic struct type for closure data
  member_types = [] of LibLLVM::MetadataRef

  closure_vars.each_with_index do |var, idx|
    var_type = get_debug_type(var.type)
    next unless var_type

    # Calculate offset in closure struct
    offset = calculate_closure_var_offset(idx)
    size = size_in_bits(var.type)

    member = di_builder.create_member_type(
      nil,                    # scope
      var.name,               # name
      nil,                    # file
      1,                      # line
      size,                   # size in bits
      align_of(var.type),     # align in bits
      offset * 8,             # offset in bits
      LLVM::DIFlags::Zero,
      var_type
    )
    member_types << member
  end

  # Create struct type
  closure_struct_type = di_builder.create_struct_type(
    nil,
    "__closure_context",
    nil,
    1,
    total_closure_size * 8,
    total_closure_align * 8,
    LLVM::DIFlags::Artificial,  # Mark as compiler-generated
    nil,
    member_types
  )

  # Declare as local variable
  declare_variable(
    "__closure",
    closure_struct_type,
    closure_ptr,
    location
  )
end
```

### Week 2: Lexical Scopes

**Problem**: No nested scopes, variable shadowing confusing

**Solution**: Create `DW_TAG_lexical_block` for control flow

**Implementation**:

```crystal
# Add to CodeGenVisitor
@current_lexical_scope : LibLLVM::MetadataRef?

def with_lexical_scope(node : ASTNode, &)
  return yield unless @debug.line_numbers?

  old_scope = @current_lexical_scope

  # Create new scope for blocks that introduce variables
  if creates_scope?(node)
    location = node.location.try &.expanded_location
    if location
      file, dir = file_and_dir(location.filename)
      file_metadata = di_builder.create_file(file, dir)

      parent_scope = @current_lexical_scope ||
                     get_current_debug_scope(location)

      @current_lexical_scope = di_builder.create_lexical_block(
        scope: parent_scope,
        file: file_metadata,
        line: location.line_number,
        column: location.column_number
      )
    end
  end

  yield

ensure
  @current_lexical_scope = old_scope
end

def creates_scope?(node : ASTNode) : Bool
  case node
  when If, While, Until, Case, Block, Begin, ExceptionHandler
    true
  else
    false
  end
end

# Update visitors
def visit(node : If)
  # ...
  with_lexical_scope(node.then) do
    accept(node.then)
  end

  with_lexical_scope(node.else) do
    accept(node.else)
  end
  # ...
end

def visit(node : While)
  with_lexical_scope(node.body) do
    # ...
    accept(node.body)
  end
end

# Similar for Case, Block, etc.
```

### Week 3: Generic Type Parameters

**Problem**: Can't distinguish `Array(Int32)` from `Array(String)`

**Solution**: Add `DW_TAG_template_type_parameter`

**Implementation**:

```crystal
def create_debug_type(type : GenericClassInstanceType, original_type : Type)
  # First create base struct
  base_type = create_instance_var_container_type(type, original_type)
  return unless base_type

  # Add template parameters
  template_params = [] of LibLLVM::MetadataRef

  type.type_vars.each do |name, param_type|
    param_debug_type = get_debug_type(param_type)
    next unless param_debug_type

    template_param = di_builder.create_template_type_parameter(
      scope: base_type,
      name: name,
      type: param_debug_type,
      file: nil,
      line: 0,
      column: 0
    )
    template_params << template_param
  end

  # LLVM doesn't have a direct "add template params to existing type"
  # Workaround: encode in type name
  # e.g., "Array<Int32>" instead of just "Array"
  # This is what Rust/C++ compilers do

  base_type
end

# Update type name generation
def debug_type_name(type : GenericClassInstanceType) : String
  base_name = type.name
  type_args = type.type_vars.values.map(&.to_s).join(", ")
  "#{base_name}<#{type_args}>"
end
```

### Week 4: Inline Function Debugging

**Problem**: Can't see inlined functions in stack trace

**Solution**: Generate `DW_TAG_inlined_subroutine`

**Challenge**: Requires tracking inline decisions during codegen

**Implementation**:

```crystal
# Track inline call sites
@inline_call_stack = [] of {Def, Location}

def codegen_call_with_inline_tracking(call : Call, target_def : Def)
  if should_inline?(target_def)
    # Push to inline stack
    @inline_call_stack.push({target_def, call.location})

    # Generate inline debug scope
    emit_inline_scope_begin(call, target_def)

    # Inline the function body
    inline_function_body(target_def)

    # Pop from stack
    emit_inline_scope_end
    @inline_call_stack.pop
  else
    # Regular function call
    codegen_regular_call(call, target_def)
  end
end

def emit_inline_scope_begin(call : Call, target_def : Def)
  return unless @debug.line_numbers?

  location = call.location.try &.expanded_location
  return unless location

  file, dir = file_and_dir(target_def.location.filename)
  file_metadata = di_builder.create_file(file, dir)

  # Create inlined subroutine scope
  inlined_scope = di_builder.create_inlined_subroutine(
    scope: get_current_debug_scope(location),
    name: target_def.name,
    inlined_at: di_builder.create_debug_location(
      location.line_number,
      location.column_number,
      get_current_debug_scope(location)
    ),
    file: file_metadata,
    line: target_def.location.line_number
  )

  # Set as current scope
  @current_debug_scope = inlined_scope
end
```

**Deliverables**:
- ✅ Proc/Closure debug types
- ✅ Lexical scopes for control flow
- ✅ Generic type parameters in debug info
- ✅ Inline function tracking (basic)
- ✅ Test suite for all features
- ✅ Update compiler tests

---

## Phase 4: Expression Evaluation (4 weeks)

**Most Complex Feature**

### Architecture

```
User types: obj.@value * 2
            ↓
┌─────────────────────────────────────┐
│ DAP Server receives "evaluate"      │
│ request from VSCode                 │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ Expression Parser                    │
│ - Use Crystal::Parser               │
│ - Parse expression to AST           │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ Type Resolver (NEW)                 │
│ - Infer types from debug info       │
│ - Resolve method calls              │
│ - Handle instance variables         │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ Mini Codegen                        │
│ - Generate LLVM IR for expression   │
│ - Link against running process      │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ JIT Execution via LLDB              │
│ - Inject code into target process   │
│ - Execute in paused context         │
│ - Return result                     │
└─────────────────────────────────────┘
```

### Week 1-2: Expression Parser & Type Resolver

**Simple expressions first**:
- Literals: `42`, `"hello"`, `true`
- Variables: `x`, `obj`
- Instance variables: `@value`
- Arithmetic: `x + 1`, `y * 2`
- Comparisons: `x > 5`

**Type Resolver** (`src/dap/evaluator/type_resolver.cr`):
```crystal
module DAP::Evaluator
  class TypeResolver
    @frame : LibLLDB::SBFrame
    @debug_info : DebugInfo

    def resolve_type(node : ASTNode) : Type?
      case node
      when NumberLiteral
        # Infer from literal
        node.kind == :i32 ? Int32Type : Float64Type
      when StringLiteral
        StringType
      when Var
        # Look up in local variables
        var = find_variable(node.name)
        parse_debug_type(var.type_name)
      when InstanceVar
        # Lookup 'self' type, then find ivar
        self_var = find_variable("self")
        self_type = parse_debug_type(self_var.type_name)
        find_instance_var_type(self_type, node.name)
      when Call
        # Simple method resolution
        receiver_type = resolve_type(node.obj)
        resolve_method_return_type(receiver_type, node.name, node.args)
      # ... more cases
      end
    end

    private def find_variable(name : String)
      # Query LLDB for variable in current frame
      vars = LibLLDB.SBFrame_GetVariables(@frame, true, true, false, true)
      # ... find by name
    end

    private def parse_debug_type(type_name : String) : Type
      # Parse DWARF type name to Crystal Type
      # "Int32" -> Int32Type
      # "Array<Int32>" -> ArrayType(Int32Type)
      # This is tricky - need type registry
    end
  end
end
```

### Week 3: Mini Codegen & JIT

**Challenge**: Can't use full Crystal compiler (too heavy)

**Solution**: Minimal LLVM IR generation for expressions

```crystal
module DAP::Evaluator
  class Codegen
    @context : LLVM::Context
    @builder : LLVM::Builder
    @module : LLVM::Module

    def codegen(node : ASTNode, resolved_types : Hash) : LLVM::Value
      case node
      when NumberLiteral
        @context.int32.const_int(node.value.to_i32)
      when Var
        # Load from debuggee memory
        var = @frame.find_variable(node.name)
        var_addr = var.load_addr
        # Generate load instruction
        @builder.load(@builder.int_pointer, var_addr)
      when Call
        if node.obj.nil?
          # Top-level function call
          codegen_function_call(node.name, node.args)
        else
          # Method call
          codegen_method_call(node.obj, node.name, node.args)
        end
      when Binary
        left = codegen(node.left, resolved_types)
        right = codegen(node.right, resolved_types)
        case node.op
        when "+"
          @builder.add(left, right)
        when "*"
          @builder.mul(left, right)
        # ... more ops
        end
      # ... more cases
      end
    end

    def compile_and_execute : Result
      # Finalize module
      @module.verify

      # Use LLDB's JIT evaluator
      options = LibLLDB::SBExpressionOptions.new
      LibLLDB.SBExpressionOptions_SetLanguage(options, :llvm)

      # Get LLVM IR as string
      ir = @module.to_s

      # Execute in target process
      result = LibLLDB.SBFrame_EvaluateExpression(
        @frame, ir, options
      )

      parse_result(result)
    end
  end
end
```

### Week 4: Integration & Testing

**DAP Handler** (`src/dap/server.cr`):
```crystal
def handle_evaluate(msg : Protocol::Request)
  args = msg.arguments.as(Protocol::EvaluateArguments)

  # Get current frame
  thread = @session.get_current_thread
  frame = LibLLDB.SBThread_GetSelectedFrame(thread)

  begin
    # Parse expression
    parser = Crystal::Parser.new(args.expression)
    ast = parser.parse_expression

    # Resolve types
    resolver = DAP::Evaluator::TypeResolver.new(frame)
    types = resolver.resolve(ast)

    # Codegen
    codegen = DAP::Evaluator::Codegen.new(frame)
    result = codegen.generate_and_execute(ast, types)

    # Format response
    send_response(msg, Protocol::EvaluateResponse.new(
      result: result.value,
      type: result.type,
      variables_reference: result.has_children? ? allocate_ref(result) : 0
    ))
  rescue ex
    send_error_response(msg, "Evaluation failed: #{ex.message}")
  end
end
```

**Limitations (document clearly)**:
- No macro expansion
- No generic method instantiation
- Limited to expressions (no statements)
- Method calls only on simple types initially

**Deliverables**:
- ✅ Expression evaluator for basic expressions
- ✅ Type resolution from debug info
- ✅ JIT execution via LLDB
- ✅ Integration tests
- ✅ Documentation with limitations

---

## Phase 5: Macro Debugging (Future - 4+ weeks)

**Deferred to post-MVP**

High-level approach:
1. **Virtual File Source Maps**
   - Generate `.crystal-debug/macro-expansions/`
   - Map VirtualFile → real file on disk
   - Update source locations

2. **Macro Stepper**
   - Special debug mode: `crystal debug --macro-step program.cr`
   - Shows expansion step-by-step
   - Breakpoints in macro code

3. **VSCode UI Enhancement**
   - Split view: source | expansion
   - Highlight expansion site

---

## Testing Strategy

### Unit Tests
- LLDB bindings (`spec/dap/lldb_bindings_spec.cr`)
- Protocol handling (`spec/dap/protocol_spec.cr`)
- Formatters (`spec/dap/formatters_spec.cr`)
- Expression evaluator (`spec/dap/evaluator_spec.cr`)

### Integration Tests
- Full debug sessions (`spec/dap/session_spec.cr`)
- VSCode extension tests (TypeScript/Mocha)

### Manual Testing
- Real-world Crystal programs
- VSCode debug experience
- Performance benchmarks

---

## Documentation

### User Docs
- `docs/debugging/getting-started.md` - Setup & first steps
- `docs/debugging/vscode.md` - VSCode-specific guide
- `docs/debugging/lldb-formatters.md` - LLDB script usage
- `docs/debugging/expression-evaluation.md` - Eval limitations
- `docs/debugging/troubleshooting.md` - Common issues

### Developer Docs
- `docs/debugging/architecture.md` - DAP server design
- `docs/debugging/debug-info-generation.md` - DWARF emission
- `docs/debugging/contributing.md` - How to extend

---

## Success Metrics

### MVP (Phase 1-2)
- [ ] VSCode launches Crystal programs with one click
- [ ] Breakpoints work reliably
- [ ] Variables show meaningful values (String, Array, Hash)
- [ ] Call stack shows Crystal function names
- [ ] Stepping through code feels natural
- [ ] 80%+ user satisfaction (survey)

### Full Release (Phase 1-4)
- [ ] Expression evaluation works for 90% of common cases
- [ ] Debugging 2x faster than printf debugging
- [ ] Documentation rated "excellent" by users
- [ ] Adoption: 50%+ of Crystal developers use debugger regularly

---

## Timeline Summary

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Phase 1: DAP Server MVP | 4 weeks | Basic debugging in VSCode |
| Phase 2: Enhanced Formatters | 2 weeks | Hash, Tuple, etc. support |
| Phase 3: Compiler Enhancements | 4 weeks | Procs, scopes, generics, inline |
| Phase 4: Expression Evaluation | 4 weeks | Eval expressions in debug console |
| **Total** | **14 weeks** | **Production-ready debugger** |

Phase 5 (Macro debugging) deferred to future iteration.

---

## Next Steps

1. **Validate approach with community**
   - Post RFC to Crystal forum
   - Gather feedback on priorities

2. **Setup development environment**
   - Create `src/dap/` directory
   - Setup LLDB development headers
   - Create VSCode extension scaffold

3. **Start Phase 1: Week 1**
   - Implement LLDB C bindings
   - Basic DAP protocol handler
   - First integration test

---

**Questions? Feedback? Let's discuss!**
