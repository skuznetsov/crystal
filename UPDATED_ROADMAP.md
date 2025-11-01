# CrystalV2 Updated Roadmap - With Security Focus

## Strategic Pivot: Three Parallel Tracks

```
Track A: LSP Server (DX improvement)
Track B: CrystalGuard (Security)
Track C: Type Inference → Codegen (Long-term)
```

**Why three tracks?**
- Different complexity levels
- Different team members can work on each
- Quick wins (Track B) while building complex features (Track C)
- All use same Parser infrastructure ✅

---

## Track A: LSP Server (Week 1-4) 🎯 PRIMARY

### Week 1-2: MVP
- textDocument/* protocol
- Syntax error diagnostics
- Hover for basic types
- Go-to-definition

**Deliverable:** Working LSP in VS Code

### Week 3-4: Polish
- Auto-completion
- Find references
- Performance optimization
- Community feedback

**Deliverable:** Beta release

---

## Track B: CrystalGuard Security (Week 1-6) 🔒 HIGH PRIORITY

### Week 1: Foundation ⚡ QUICK WIN
**Goal:** Ship useful tool in 1 week!

**Tasks:**
1. **Secrets Detection** (2 days)
   ```crystal
   # Patterns to detect:
   - API keys (regex: sk_live_*, pk_test_*)
   - AWS keys (AKIA*)
   - Private keys (-----BEGIN)
   - Passwords in strings
   - JWT tokens
   ```

2. **Pattern Matcher** (2 days)
   ```crystal
   # Simple AST pattern matching
   pattern: db.query("... #{...}")
   → SQL injection warning
   ```

3. **CLI + Output** (1 day)
   ```bash
   crystal-guard scan
   # Shows findings in terminal
   ```

**Deliverable:** `crystal-guard` tool that finds secrets + basic SQL injection

**Why start here?**
- ✅ Easiest to implement (string matching)
- ✅ High value (prevents credential leaks)
- ✅ Quick win for community
- ✅ No complex analysis needed

---

### Week 2: Injection Detection

**Tasks:**
1. **SQL Injection** (2 days)
   - String interpolation in queries
   - Pattern: `db.query("... #{user_input}")`

2. **Command Injection** (2 days)
   - `system()` with user input
   - Unsafe shell expansion

3. **Path Traversal** (1 day)
   - File operations with user input

**Deliverable:** Detects top 3 OWASP vulnerabilities

---

### Week 3-4: Taint Analysis

**Goal:** Track data flow from sources to sinks

```crystal
# Taint source
user_input = params["query"]  # TAINTED

# Propagation through variables
query = user_input.downcase   # STILL TAINTED

# Sink: SQL
db.query("SELECT * FROM t WHERE x = '#{query}'")
# WARNING: Tainted data reaches SQL sink
```

**Tasks:**
1. Data flow graph (3 days)
2. Source/sink identification (2 days)
3. Sanitizer recognition (2 days)

**Deliverable:** Advanced vulnerability detection with data flow

---

### Week 5: Integration

**Tasks:**
1. **CI/CD** (2 days)
   - GitHub Actions integration
   - SARIF output for Code Scanning

2. **Pre-commit hooks** (1 day)

3. **Rule customization** (2 days)
   - YAML rule format
   - Custom rules support

**Deliverable:** Production-ready security tool

---

### Week 6: Advanced Rules

**Tasks:**
1. Cryptography mistakes (2 days)
2. Nil safety analysis (2 days)
3. Memory safety (C bindings) (2 days)

**Deliverable:** Comprehensive security coverage

---

## Track C: Type Inference + Codegen (Week 4-16) 🚀 LONG-TERM

### Week 4-6: Generic Types
- Generic method instantiation
- Type constraints
- Generic classes

### Week 7-8: Union Types
- Union type inference
- Nilable handling
- Type narrowing

### Week 9-10: Method Dispatch
- Overload resolution
- Virtual dispatch
- Multiple dispatch

### Week 11-13: LLVM IR Generation
- Basic IR generation
- Memory management
- GC integration

### Week 14-15: Advanced Codegen
- Classes & vtables
- Closures & blocks

### Week 16: Self-hosting
- Compile CrystalV2 with itself
- Performance benchmarks
- Bootstrap test

---

## Why This Order?

### 1. Quick Wins First (CrystalGuard Week 1)
```
Secrets detection: 2 days → INSTANT VALUE
├─ Prevents credential leaks
├─ Easy to implement (regex)
└─ Community loves it
```

### 2. Parallel Development
```
Week 1:  LSP basics      + CrystalGuard secrets
Week 2:  LSP hover       + CrystalGuard injection
Week 3:  LSP completion  + CrystalGuard taint
Week 4:  LSP polish      + Type inference start
```

### 3. Progressive Complexity
```
Easy:    Secrets detection (regex)
Medium:  LSP server (protocol)
Hard:    Taint analysis (data flow)
Hardest: Type inference + Codegen
```

---

## Immediate Action Plan (This Week)

### Day 1 (Today): Setup
```bash
# Create three projects
mkdir crystal_v2_lsp
mkdir crystal_guard
mkdir crystal_v2_inference

# Setup basic structure
cd crystal_guard
crystal init app guard
```

### Day 2-3: CrystalGuard Secrets Detection
```crystal
# Implement basic secrets scanner
class SecretsScanner
  PATTERNS = {
    "AWS Key" => /AKIA[0-9A-Z]{16}/,
    "Stripe Key" => /(sk|pk)_(live|test)_[a-zA-Z0-9]{24}/,
    "Generic API Key" => /api[_-]?key[_-]?[=:]\s*['""]([a-zA-Z0-9]{32,})['"]/,
    # ... more patterns
  }

  def scan(file : String) : Array(Finding)
    # Read file, match patterns, report findings
  end
end
```

### Day 4-5: CrystalGuard SQL Injection
```crystal
# Pattern matcher for AST
class SQLInjectionChecker
  def check(node : CallNode) : Finding?
    # If node is db.query(...) with string interpolation
    # Return finding
  end
end
```

### Day 6-7: CrystalGuard CLI + Tests
```bash
# Should work by end of week:
crystal-guard scan src/

# Output:
# 🔴 CRITICAL: Hardcoded API key at src/config.cr:12
# 🔴 HIGH: SQL injection at src/db/queries.cr:45
```

---

## Success Metrics (First Month)

### CrystalGuard (Week 1-6):
- ✅ Detect secrets in code
- ✅ Detect SQL/Command injection
- ✅ < 5% false positives
- ✅ 50+ GitHub stars
- ✅ Used in 5+ projects

### LSP (Week 1-4):
- ✅ VS Code extension published
- ✅ Basic features work (hover, goto)
- ✅ Faster than Crystalline
- ✅ 100+ GitHub stars

### Type Inference (Week 4+):
- ✅ Generic types work
- ✅ Union types handled
- ✅ Pass compiler test suite

---

## Community Impact Strategy

### Week 1: CrystalGuard MVP
**Announcement:**
> "🔒 Introducing CrystalGuard: Security scanner for Crystal
>
> Found 3 hardcoded API keys and 5 SQL injection vulnerabilities in popular shards!
>
> Try it: `shards install crystal-guard`"

**Impact:** Immediate value, shows we're serious about security

---

### Week 2: LSP Alpha
**Announcement:**
> "🚀 CrystalV2 LSP Alpha: Real-time syntax errors in VS Code
>
> 10x faster than Crystalline (50ms vs 3s)
>
> Try it: Install 'Crystal-GPT5' extension"

**Impact:** Better DX, community excitement

---

### Week 4: LSP Beta + CrystalGuard Integration
**Announcement:**
> "💎 CrystalV2 Suite:
> - LSP with hover + goto-def
> - CrystalGuard integrated (security warnings in editor!)
>
> The future of Crystal development"

**Impact:** Complete developer experience

---

## Resource Allocation

If working solo:
- **80% time:** LSP (Track A) - highest impact
- **15% time:** CrystalGuard (Track B) - quick wins
- **5% time:** Planning Track C

If team of 2-3:
- **Person 1:** LSP full-time
- **Person 2:** CrystalGuard → Taint Analysis
- **Person 3:** Type Inference foundation

---

## Risk Mitigation

### Risk 1: Spreading too thin
**Mitigation:** CrystalGuard Week 1 is TINY scope (secrets only)
- If takes > 3 days, pause and focus on LSP

### Risk 2: False positives in CrystalGuard
**Mitigation:** Start conservative
- Better to miss vulnerabilities than spam with false positives
- Add suppressions: `# crystal-guard: disable sql-injection`

### Risk 3: LSP performance
**Mitigation:** Already fast!
- Our parser: 43ms for parser.cr
- Crystalline: 3+ seconds
- We have 70x advantage

---

## Timeline Visualization

```
Month 1:  ████████████ LSP MVP + CrystalGuard Secrets
          Week 1-4

Month 2:  ████████████ LSP Beta + CrystalGuard Injection
          Week 5-8

Month 3:  ██████████── LSP Stable + Type Inference Start
          Week 9-12

Month 4:  ──────██████ Type Inference + Codegen Foundation
          Week 13-16
```

---

## Decision: What to Start Tomorrow?

### Option A: LSP First
**Pros:**
- Highest long-term impact
- Most complex, should start early

**Cons:**
- Takes 2-4 weeks for useful MVP

### Option B: CrystalGuard First (RECOMMENDED)
**Pros:**
- ✅ Ships in 1 week! (secrets detection)
- ✅ Immediate community value
- ✅ Builds momentum
- ✅ Easier to implement (good warm-up)

**Cons:**
- Delays LSP by 1 week

### Option C: Both Parallel
**Pros:**
- Maximum throughput

**Cons:**
- Risk of spreading thin
- Context switching cost

---

## RECOMMENDATION: Start with CrystalGuard (Option B)

**Rationale:**
1. **Quick win** - ship useful tool in 1 week
2. **Momentum** - success breeds success
3. **Learning** - warm up with easier problem
4. **Marketing** - shows we're building useful tools
5. **Security** - prevents real vulnerabilities NOW

**Then:** Pivot to LSP with confidence and momentum

---

## First Actions (Tomorrow Morning)

```bash
# 1. Create CrystalGuard repo
mkdir crystal_guard
cd crystal_guard
crystal init app guard

# 2. Create secrets detection
# File: src/scanners/secrets.cr

# 3. Write 20 tests
# File: spec/secrets_spec.cr

# 4. Create CLI
# File: src/cli.cr

# Goal: Working prototype by end of day
```

**By Friday:** Have CrystalGuard secrets detection working!

**Next Monday:** Start LSP with momentum from shipping CrystalGuard

---

## What do you think?

A) Start with CrystalGuard (1 week to ship) → Then LSP
B) Start with LSP (2-4 weeks to MVP) → Then CrystalGuard
C) Do both in parallel (risky but fast)

Мой рекомендация: **Option A** (CrystalGuard first)
- Quick win
- Build confidence
- Still get to LSP soon

Как тебе план?
