# CrystalGuard - Security & Defensive Programming Analyzer

## Vision

**CrystalGuard** - статический анализатор безопасности для Crystal, который находит уязвимости и плохие практики до того как код попадет в production.

**Motto:** "Security by default, safety by design"

---

## Why CrystalGuard?

### Current Gap in Crystal Ecosystem

| Tool | Style | Performance | Security | Safety |
|------|-------|-------------|----------|--------|
| Ameba | ✅ | ❌ | ❌ | ❌ |
| Crystal Compiler | ❌ | ❌ | ⚠️ (partial) | ✅ |
| **CrystalGuard** | ⚠️ | ❌ | ✅ | ✅ |

**No comprehensive security analysis tool exists for Crystal!**

---

## Core Capabilities

### 1. Vulnerability Detection (OWASP Top 10)

#### SQL Injection (CWE-89)
```crystal
# ❌ BAD - Detectable
user_input = params["name"]
db.query("SELECT * FROM users WHERE name = '#{user_input}'")
# CrystalGuard: [HIGH] SQL Injection via string interpolation

# ✅ GOOD
db.query("SELECT * FROM users WHERE name = ?", user_input)
# CrystalGuard: ✓ Parameterized query - safe
```

#### Command Injection (CWE-78)
```crystal
# ❌ BAD
filename = params["file"]
system("cat #{filename}")
# CrystalGuard: [CRITICAL] Command injection - user input in system()

# ✅ GOOD
Process.run("cat", [filename])
# CrystalGuard: ✓ Using Process.run with array - safe
```

#### Path Traversal (CWE-22)
```crystal
# ❌ BAD
user_path = params["path"]
File.read("/var/data/#{user_path}")
# CrystalGuard: [HIGH] Path traversal - unsanitized user input

# ✅ GOOD
user_path = File.expand_path(params["path"], "/var/data")
raise "Invalid path" unless user_path.starts_with?("/var/data")
File.read(user_path)
# CrystalGuard: ✓ Path validation present
```

#### XSS (CWE-79)
```crystal
# ❌ BAD
user_content = params["content"]
html = "<div>#{user_content}</div>"
# CrystalGuard: [HIGH] XSS - unescaped user input in HTML

# ✅ GOOD
user_content = HTML.escape(params["content"])
html = "<div>#{user_content}</div>"
# CrystalGuard: ✓ HTML escaped
```

---

### 2. Secrets Detection

```crystal
# ❌ BAD - Detectable
API_KEY = "sk_live_1234567890abcdef"
# CrystalGuard: [CRITICAL] Hardcoded API key detected

DATABASE_URL = "postgres://user:password123@localhost/db"
# CrystalGuard: [CRITICAL] Hardcoded password in connection string

# ✅ GOOD
API_KEY = ENV["API_KEY"]
# CrystalGuard: ✓ Using environment variable
```

**Patterns to detect:**
- API keys (AWS, Stripe, OpenAI, etc.)
- Private keys (RSA, EC, SSH)
- Passwords in code
- JWT tokens
- Database credentials
- OAuth secrets

---

### 3. Memory Safety (C Bindings)

```crystal
# ❌ BAD
lib LibC
  fun dangerous(ptr : UInt8*, size : Int32) : Int32
end

user_input = gets
LibC.dangerous(user_input.to_unsafe, user_input.size)
# CrystalGuard: [HIGH] Unsafe C binding call with user input

# ✅ GOOD
user_input = gets
validated = validate_input(user_input)
LibC.dangerous(validated.to_unsafe, validated.size)
# CrystalGuard: ⚠️ C binding call - verify safety
```

---

### 4. Nil Safety Analysis

```crystal
# ❌ BAD
def process_user(user : User?)
  user.name.upcase  # Could be nil!
  # CrystalGuard: [MEDIUM] Potential nil dereference
end

# ✅ GOOD
def process_user(user : User?)
  return unless user
  user.name.upcase
  # CrystalGuard: ✓ Nil check present
end
```

---

### 5. Cryptography Mistakes

```crystal
# ❌ BAD
password = "secret"
hash = Digest::MD5.hexdigest(password)
# CrystalGuard: [HIGH] MD5 is cryptographically broken - use bcrypt

# ❌ BAD
Random.new.rand(100)  # Predictable for security!
# CrystalGuard: [MEDIUM] Using non-cryptographic random for security

# ✅ GOOD
hash = Crypto::Bcrypt::Password.create(password)
# CrystalGuard: ✓ Using bcrypt for password hashing

Random::Secure.rand(100)
# CrystalGuard: ✓ Using cryptographic random
```

---

### 6. Taint Analysis (Data Flow)

**Track user input through the program:**

```crystal
# Taint source: params
user_input = params["query"]  # TAINTED

# Propagation
processed = user_input.downcase  # STILL TAINTED

# Sink: SQL query
db.query("SELECT * FROM items WHERE name = '#{processed}'")
# CrystalGuard: [CRITICAL] Tainted data reaches SQL sink
```

**Taint Sources:**
- HTTP params
- HTTP headers
- File reads from user-controlled paths
- Environment variables (some)
- Network sockets

**Taint Sinks:**
- SQL queries
- System commands
- File operations
- HTML output
- eval/macro expansion

**Sanitizers:**
- Parameterized queries
- HTML.escape
- Path validation
- Input validation

---

## Architecture

### Analysis Phases

```
1. Parse Code (using our Parser) ✅
   ↓
2. Build Symbol Table (using Semantic Analysis) ✅
   ↓
3. Type Inference (for data flow) ✅
   ↓
4. Taint Analysis (new)
   ↓
5. Pattern Matching (new)
   ↓
6. Report Generation
```

### Core Components

```crystal
module CrystalGuard
  class Analyzer
    # Main entry point
    def analyze(program : Program) : Report
      findings = [] of Finding

      # Run all checks
      findings.concat(sql_injection_check(program))
      findings.concat(command_injection_check(program))
      findings.concat(secrets_check(program))
      findings.concat(crypto_check(program))
      findings.concat(nil_safety_check(program))

      Report.new(findings)
    end
  end

  # Taint analysis
  class TaintAnalyzer
    def track(source : Node, program : Program) : Array(TaintFlow)
      # Follow data flow from source to sinks
    end
  end

  # Pattern matcher
  class PatternMatcher
    def match(node : Node, pattern : String) : Bool
      # Match AST patterns (like Semgrep)
    end
  end
end
```

---

## Rule Format (YAML)

```yaml
rules:
  - id: sql-injection-string-interpolation
    severity: HIGH
    message: "SQL injection via string interpolation"
    description: "Using string interpolation in SQL queries allows injection attacks"
    pattern: |
      db.query("... #{...}")
    fix: "Use parameterized queries: db.query(\"...\", param)"
    cwe: CWE-89
    owasp: A03:2021 - Injection

  - id: hardcoded-api-key
    severity: CRITICAL
    message: "Hardcoded API key detected"
    pattern: |
      API_KEY = "sk_live_..."
    regex: '(sk|pk)_(live|test)_[a-zA-Z0-9]{20,}'
    fix: "Use environment variables: ENV[\"API_KEY\"]"

  - id: weak-crypto-md5
    severity: HIGH
    message: "MD5 is cryptographically broken"
    pattern: |
      Digest::MD5.hexdigest(...)
    fix: "Use Crypto::Bcrypt for passwords, SHA-256 for hashing"
    cwe: CWE-327
```

---

## Output Formats

### Terminal (Default)
```
CrystalGuard Security Analysis Report
═══════════════════════════════════════

📊 Summary: 3 issues found (1 critical, 2 high, 0 medium, 0 low)

🔴 CRITICAL (1)
  src/api/auth.cr:42:15
  Hardcoded API key detected
    API_KEY = "sk_live_1234567890abcdef"
    ───────────────────────────────────
  Fix: Use environment variables: ENV["API_KEY"]
  CWE-798 | OWASP A07:2021

🔴 HIGH (2)
  src/db/queries.cr:15:8
  SQL injection via string interpolation
    db.query("SELECT * FROM users WHERE name = '#{user_input}'")
    ─────────────────────────────────────────────────────────────
  Fix: Use parameterized queries
  CWE-89 | OWASP A03:2021

  src/utils/file.cr:23:5
  Path traversal - unsanitized user input
    File.read("/data/#{user_path}")
    ───────────────────────────────────
  Fix: Validate and sanitize file paths
  CWE-22 | OWASP A01:2021

Scan completed in 0.234s
```

### SARIF (for GitHub Code Scanning)
```json
{
  "version": "2.1.0",
  "$schema": "https://...",
  "runs": [{
    "tool": {
      "driver": {
        "name": "CrystalGuard",
        "version": "1.0.0"
      }
    },
    "results": [...]
  }]
}
```

### JSON (for CI/CD)
```json
{
  "summary": {
    "critical": 1,
    "high": 2,
    "medium": 0,
    "low": 0
  },
  "findings": [...]
}
```

---

## Integration

### CLI
```bash
# Scan current project
crystal-guard scan

# Scan specific files
crystal-guard scan src/**/*.cr

# Output to SARIF
crystal-guard scan --format sarif -o results.sarif

# CI mode (fail on high/critical)
crystal-guard scan --fail-on high

# Custom rules
crystal-guard scan --rules my-rules.yml
```

### CI/CD (GitHub Actions)
```yaml
name: Security Scan
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run CrystalGuard
        run: |
          crystal-guard scan --format sarif -o results.sarif
      - name: Upload results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif
```

### Pre-commit Hook
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/crystal-guard/crystal-guard
    rev: v1.0.0
    hooks:
      - id: crystal-guard
        args: [--fail-on, high]
```

---

## Rule Categories

### 1. Injection Vulnerabilities
- SQL Injection (CWE-89)
- Command Injection (CWE-78)
- LDAP Injection (CWE-90)
- XML Injection (CWE-91)
- Code Injection (CWE-94)

### 2. Authentication & Authorization
- Hardcoded credentials (CWE-798)
- Weak password requirements (CWE-521)
- Missing authentication (CWE-306)
- Broken access control (CWE-284)

### 3. Cryptography
- Weak encryption (CWE-327)
- Insecure random (CWE-338)
- Weak hash (CWE-328)
- Hardcoded keys (CWE-321)

### 4. Input Validation
- Path traversal (CWE-22)
- XXE (CWE-611)
- Unvalidated redirects (CWE-601)
- SSRF (CWE-918)

### 5. Error Handling
- Information disclosure (CWE-209)
- Improper error handling (CWE-755)

### 6. Memory Safety
- Buffer overflow (CWE-120)
- Use after free (CWE-416)
- Null pointer dereference (CWE-476)

### 7. Concurrency
- Race conditions (CWE-362)
- Deadlock (CWE-833)

---

## Implementation Timeline

### Week 1: Foundation
- Pattern matching engine
- Basic rule format
- Terminal output

### Week 2: Core Rules
- SQL injection detection
- Command injection detection
- Secrets detection

### Week 3: Taint Analysis
- Data flow tracking
- Source/sink identification
- Sanitizer recognition

### Week 4: Integration
- CI/CD integration
- SARIF output
- GitHub Actions

### Week 5: Advanced Rules
- Cryptography checks
- Memory safety
- Nil safety

---

## Performance Goals

- **Speed:** < 500ms for 10K LOC project
- **Accuracy:** < 5% false positive rate
- **Coverage:** 80% of OWASP Top 10

---

## Comparison with Existing Tools

| Feature | Ameba | SonarQube | **CrystalGuard** |
|---------|-------|-----------|------------------|
| SQL Injection | ❌ | ✅ | ✅ |
| Command Injection | ❌ | ✅ | ✅ |
| Secrets Detection | ❌ | ⚠️ | ✅ |
| Taint Analysis | ❌ | ✅ | ✅ |
| Speed | Fast | Slow | **Fast** |
| Crystal-specific | ✅ | ❌ | ✅ |
| Free | ✅ | ⚠️ | ✅ |

---

## Roadmap Integration

**Priority:** HIGH - Start in parallel with LSP

**Week 1-2:** Basic pattern matching + secrets detection
**Week 3-4:** Taint analysis + SQL/Command injection
**Week 5:** CI/CD integration
**Week 6+:** Advanced rules

Can be developed **in parallel** with LSP because:
- Uses same Parser ✅
- Uses same AST ✅
- Simpler than type inference
- High community value

---

## Success Metrics

### Adoption:
- 50+ GitHub stars in first month
- Integrated in 10+ Crystal projects
- Mentioned in Crystal blog/newsletter

### Quality:
- Find real vulnerabilities in popular shards
- < 5% false positive rate
- 0 false negatives on test suite

### Impact:
- Prevent 1+ CVE in Crystal ecosystem
- Improve security awareness in community

---

## Next Steps

1. **This week:** Create basic pattern matcher
2. **Next week:** Implement secrets detection (easiest, high value)
3. **Week 3:** Add SQL injection detection
4. **Week 4:** Public beta release

**First command tomorrow:**
```bash
mkdir crystal_guard
cd crystal_guard
crystal init app guard
```
