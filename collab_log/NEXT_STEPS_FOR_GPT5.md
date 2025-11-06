# Quick Start for GPT5

## Current State
- **Branch**: `new_crystal_parser`
- **Test Results**: 728 examples, **5 failures**, 6 pending
- **Last Commit**: fe52b8319 "Fix proc literal parsing..."

## Your Mission: Fix 5 Remaining Test Failures

### Quick Commands
```bash
# Run all parser tests
cd /Users/sergey/Projects/Crystal/crystal/crystal_v2
crystal spec spec/parser/

# Run single failing test
crystal spec spec/parser/parser_path_spec.cr:262

# Debug mode
ENV["PARSER_DEBUG"]="1" crystal run /tmp/test.cr
```

### The 5 Failures (Priority Order)

1. **Path with spaces** - `spec/parser/parser_path_spec.cr:262`
   - `Foo :: Bar` → should be Path node, got Call
   - Likely simple fix in path parsing

2. **Nested tuples** - `spec/parser/parser_tuple_spec.cr:72`
   - `{1, {2, 3}}` → 1 root expected, got 2

3. **?? in assignment** - `spec/parser/parser_nil_coalesce_spec.cr:43`
   - Expected Assign node, got String

4. **In with complex left** - `spec/parser/parser_in_operator_spec.cr:141`
   - Complex left expression → 2 roots instead of 1

5. **responds_to? in ternary** - `spec/parser/parser_responds_to_spec.cr:230`
   - Expected Ternary, got Nil

### Debug Template
```crystal
ENV["PARSER_DEBUG"] = "1"
require "./src/compiler/frontend/parser"

source = "Foo :: Bar"  # Your test case
parser = CrystalV2::Compiler::Frontend::Parser.new(
  CrystalV2::Compiler::Frontend::Lexer.new(source)
)
program = parser.parse_program

puts "Roots: #{program.roots.size}"
puts "Diagnostics: #{parser.diagnostics.size}"
parser.diagnostics.each { |d| puts "  #{d.message}" }

if program.roots.size > 0
  arena = program.arena
  root = arena[program.roots[0]]
  puts "Kind: #{CrystalV2::Compiler::Frontend.node_kind(root)}"
end
```

### Key Functions You'll Need

**Whitespace Handling**:
- `skip_trivia` → whitespace + comments (NO newlines)
- `skip_statement_end` → whitespace + comments + newlines + semicolons

**Parsing**:
- `parse_statement` → handles assignments (use in bodies)
- `parse_expression(prec)` → just expressions (use in operators)
- `end_token?` → check for closing delimiters

**Reference**:
- Original parser: `/Users/sergey/Projects/Crystal/crystal/src/compiler/crystal/syntax/parser.cr`
- Our parser: `src/compiler/frontend/parser.cr`

### Common Patterns from Last Session

**Multi-root problem** usually means:
- Missing `end_token?` check
- Wrong `skip_X` function
- Parsing stopped early, treated rest as new statement

**Wrong node type** usually means:
- Need `parse_statement` instead of `parse_expression`
- Missing precedence check in operator
- Wrong prefix/infix handler

### Success Criteria
- All 5 tests pass
- No new failures introduced
- Run full suite to verify: `crystal spec spec/parser/`

### When You Commit
```bash
git add src/compiler/frontend/parser.cr spec/parser/*.cr
git commit -m "Fix [issue]: [what you did]

Tests fixed: X
Remaining: Y

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## Detailed Context

Read `2025-11-04_claude_proc_literals_fix.md` for:
- Complete debugging session
- Pattern explanations
- Code examples
- Technical insights

## Good Luck! 🚀

You've got this. The hard part (proc literals) is done.
These 5 are likely simpler fixes.

Start with path parsing - probably just need to handle whitespace around `::`.
