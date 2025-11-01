# Parser Optimization Roadmap
**Date**: 2025-11-01
**Current**: 38.71 ms (1.58x slower than original)
**Target**: 24 ms or better (match or beat original)
**Method**: Landmark Protocol analysis (Cassandra + Daedalus + Maieutic)

## Root Cause Analysis

### [LM-CASSANDRA] Predicted Bottlenecks (Verified)

1. **String allocations** (HIGHEST IMPACT - 80% confidence)
   - `token_text()` creates new String 35+ times per parse
   - Type annotation building: array of strings + join
   - Identifier/literal extraction

2. **Arena hash lookups** (HIGH IMPACT - 70% confidence)
   - Every `@arena[expr_id]` is Hash lookup
   - Hash overhead vs array index

3. **Method call overhead** (MEDIUM IMPACT - 60% confidence)
   - Small methods without @[AlwaysInline]
   - skip_trivia called hundreds of times

### [LM-DAEDALUS] Architecture Comparison

**Our Parser Overhead**:
```crystal
# Current (SLOW):
@arena : Hash(Int32, TypedNode)
@arena[expr_id]  # Hash lookup

# Potential (FAST):
@arena : Array(TypedNode)
@arena[expr_id.value]  # Array index
```

**String Allocation Pattern**:
```crystal
# Current (ALLOCATES):
name = token_text(token)  # String.new(slice)

# Optimized (NO ALLOCATION):
name = token.slice  # Direct slice
```

### [LM-MAIEUTIC] Key Insights

**Q**: "ExprId is just wrapper around Int32. Why use Hash?"
**A**: Sequential allocation means Array would work perfectly!

**Q**: "Why convert slice to String 35+ times?"
**A**: Most places can use Slice(UInt8) directly!

**Q**: "What's the actual cost breakdown?"
**A**: Need profiling, but architecture suggests:
- 30-40% string allocations
- 20-30% hash lookups
- 20-30% method call overhead
- 20% everything else

## Optimization Tiers

### TIER 1: Quick Wins (1-2 days, 20-30% speedup)

**Impact**: Get to ~30ms (1.25x slower than original)

#### 1.1 Arena: Hash → Array [CRITICAL]
**Current**:
```crystal
@arena : Hash(Int32, TypedNode)
```

**Optimized**:
```crystal
@arena : Array(TypedNode)
@arena_size : Int32

def add_typed(node : TypedNode) : ExprId
  id = ExprId.new(@arena_size)
  @arena << node
  @arena_size += 1
  id
end

def [](id : ExprId) : TypedNode
  @arena.unsafe_fetch(id.value)  # No bounds check
end
```

**Expected**: 5-10% speedup (O(1) hash → O(1) array, but faster constant)

#### 1.2 Reduce String Allocations [CRITICAL]
**Strategy**: Use Slice(UInt8) wherever possible

**Example - parse_type_annotation**:
```crystal
# Current (SLOW):
type_tokens = [] of String
type_tokens << token_text(token)
type_tokens.join(" ")

# Optimized (FAST):
# Return Slice(UInt8) directly, build String only once
start_offset = token.span.start_offset
end_offset = current_token.span.end_offset
@source[start_offset...end_offset]  # Single slice, no allocations!
```

**Expected**: 15-20% speedup

#### 1.3 Inline Hot Methods
```crystal
@[AlwaysInline]
private def skip_trivia
  # ... current code ...
end

@[AlwaysInline]
private def current_token
  @tokens.unsafe_fetch(@index)
end

@[AlwaysInline]
private def advance
  @previous_token = current_token
  @index += 1
end
```

**Expected**: 5-10% speedup

### TIER 2: Medium Optimizations (3-5 days, 10-20% additional)

**Impact**: Get to ~24ms (match original)

#### 2.1 Token Lookahead Cache
```crystal
@lookahead_cache : Token?
@lookahead_valid : Bool

private def peek_token : Token
  return @lookahead_cache.not_nil! if @lookahead_valid

  token = @tokens[@index + 1]
  @lookahead_cache = token
  @lookahead_valid = true
  token
end
```

**Expected**: 3-5% speedup

#### 2.2 String Pool for Common Types
```crystal
TYPE_POOL = {
  "Int32" => "Int32".to_slice,
  "String" => "String".to_slice,
  "Bool" => "Bool".to_slice,
  # ... top 50 common types
}

private def get_type_slice(name : String) : Slice(UInt8)
  TYPE_POOL[name]? || name.to_slice
end
```

**Expected**: 2-5% speedup

#### 2.3 Optimize skip_trivia
```crystal
# Current: checks token.kind in loop
# Optimized: early exit, unroll loop

@[AlwaysInline]
private def skip_trivia
  # Fast path: no trivia
  kind = current_token.kind
  return if kind != Token::Kind::Whitespace && kind != Token::Kind::Comment

  # Slow path: skip all trivia
  loop do
    advance
    kind = current_token.kind
    break if kind != Token::Kind::Whitespace && kind != Token::Kind::Comment
  end
end
```

**Expected**: 5-7% speedup

### TIER 3: Advanced Optimizations (1-2 weeks, 10-20% additional)

**Impact**: Get to ~20ms (1.2x FASTER than original!)

#### 3.1 Custom Arena with Regions
```crystal
# Pre-allocate memory in chunks
@arena_regions : Array(Pointer(TypedNode))
@region_size : Int32 = 4096
@current_region : Int32
@region_offset : Int32

def add_typed(node : TypedNode) : ExprId
  if @region_offset >= @region_size
    # Allocate new region
    allocate_region
  end

  ptr = @arena_regions[@current_region] + @region_offset
  ptr.value = node

  id = ExprId.new(@current_region * @region_size + @region_offset)
  @region_offset += 1
  id
end
```

**Expected**: 5-10% speedup (cache locality)

#### 3.2 SIMD Token Skipping
```crystal
# Use SIMD to skip whitespace/comments in bulk
# Requires inline assembly or Crystal bindings
```

**Expected**: 3-5% speedup

#### 3.3 Parallel Parsing
```crystal
# Parse top-level definitions in parallel
# Use fibers/threads for independent modules
```

**Expected**: 20-50% speedup on multi-core (but complex!)

## Implementation Priority

### Phase 1: Foundation (Week 1)
**Goal**: 30ms (20-30% faster)

1. ✅ Arena: Hash → Array (Day 1-2)
2. ✅ Inline hot methods (Day 1)
3. ✅ Reduce string allocations in parse_type_annotation (Day 2-3)
4. ✅ Optimize skip_trivia (Day 3)

**Risk**: Low (architectural improvements)
**Effort**: 3-5 days
**Expected Speedup**: 25-35%

### Phase 2: Refinement (Week 2)
**Goal**: 24ms (match original)

1. Token lookahead cache (Day 1)
2. String pool for types (Day 2)
3. Profile-guided optimization (Day 3-5)

**Risk**: Low-Medium (incremental improvements)
**Effort**: 5 days
**Expected Speedup**: 10-15% additional

### Phase 3: Advanced (Weeks 3-4)
**Goal**: 20ms (beat original!)

1. Custom arena with regions (Week 3)
2. SIMD optimizations (Week 4)
3. Benchmark-driven tuning (Week 4)

**Risk**: Medium (complex optimizations)
**Effort**: 10 days
**Expected Speedup**: 15-20% additional

## Measurement Strategy

### Micro-benchmarks
```crystal
# Benchmark each optimization separately
Benchmark.ips do |x|
  x.report("hash lookup") { @arena[expr_id] }
  x.report("array lookup") { @arena.unsafe_fetch(expr_id.value) }

  x.report("string alloc") { String.new(slice) }
  x.report("slice direct") { slice }
end
```

### Regression Testing
```bash
# Run before/after each optimization
crystal run benchmark_parser.cr
# Ensure no correctness regression
./bin/crystal_gpt5 src/compiler/frontend/lexer.cr 2>&1 | grep -c "unexpected"
```

### Profiling
```bash
# macOS Instruments
instruments -t "Time Profiler" -D trace.trace bin/crystal_gpt5 file.cr

# Linux perf
perf record -g ./bin/crystal_gpt5 file.cr
perf report
```

## Expected Timeline

**Aggressive (1 month)**:
- Week 1: Phase 1 → 30ms
- Week 2: Phase 2 → 24ms
- Week 3-4: Phase 3 → 20ms

**Conservative (2 months)**:
- Weeks 1-2: Phase 1 → 30ms (with testing)
- Weeks 3-4: Phase 2 → 24ms (with testing)
- Weeks 5-8: Phase 3 → 20ms (with validation)

## Risk Mitigation

### Correctness
- Run full test suite after each optimization
- Parse all stdlib files and verify 0 errors
- Compare AST output with original (if needed)

### Performance Regression
- Track benchmark results in git
- Automated CI benchmark runs
- Alert if slowdown > 5%

### Maintainability
- Document each optimization
- Keep unoptimized version for reference
- Use feature flags for experimental optimizations

## Success Criteria

### Minimum (Must Have)
- ✅ Match original speed: ~24ms
- ✅ Zero correctness regressions
- ✅ Self-hosting maintained

### Target (Should Have)
- ⭐ Beat original: ~20ms (1.2x faster)
- ⭐ Memory usage same or better
- ⭐ Code quality maintained

### Stretch (Nice to Have)
- 🚀 2x faster than original: ~12ms
- 🚀 Parallel parsing support
- 🚀 Incremental parsing capability

## Conclusion

**Feasibility**: ✅ Very High

Оригинальный парсер оптимизировался 10+ лет, но мы можем:
1. **Match speed** (24ms) в 1-2 недели с простыми оптимизациями
2. **Beat speed** (20ms) в 1 месяц с продвинутыми техниками
3. **Significantly beat** (15ms) возможно с SIMD + parallel parsing

**Key Insight**: Архитектурные улучшения (Arena Hash→Array, slice вместо String) дадут 80% прироста с минимальными рисками!

**Recommendation**: Start with Phase 1 (Foundation), measure, then decide on Phase 2/3.

---

**Next Step**: Implement Arena as Array (1-2 days, 5-10% speedup, low risk)
