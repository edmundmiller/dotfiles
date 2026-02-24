# Learning: Prefix Protection for Cache Optimization

**Hash**: 3d263626  
**Category**: Optimization Strategies  
**Date**: 2026-01-10  
**Source**: DCP + Caching research  
**Confidence**: MEDIUM (theoretical - needs validation)

## Core Concept

**Prefix protection**: Preserving the first ~1024 tokens of conversation history to maintain prompt cache eligibility and effectiveness.

**Note**: This strategy is LESS CRITICAL when using cache warming pattern (see learning-455d01b5), but still provides additional optimization opportunities.

## The Three-Zone Model

Divide conversation into three zones with different pruning rules:

```
[Zone 1: Prefix]  [Zone 2: Middle]  [Zone 3: Tail]
  0-1024 tokens     1024-N-10         Last 10 messages
  PROTECTED         PRUNABLE          PROTECTED
  (cache)           (optimization)    (recency)
```

### Zone 1: Prefix (Protected)

- **Size**: First 1024-2048 tokens (cache minimum)
- **Rule**: Never pruned
- **Purpose**: Ensures cache eligibility maintained
- **Benefit**: Stable cache foundation

### Zone 2: Middle (Prunable)

- **Size**: Between prefix and tail
- **Rule**: Aggressive pruning allowed
- **Purpose**: Optimization opportunity
- **Benefit**: Token savings without breaking cache

### Zone 3: Tail (Protected)

- **Size**: Last N messages (configurable, default 10)
- **Rule**: Protected by recency
- **Purpose**: Maintains context coherence
- **Benefit**: Recent context always available

## Implementation Pattern

```typescript
const CACHE_PREFIX_SIZE = 1024; // tokens

function shouldProtectMessage(msg, ctx) {
  const prefixEndIndex = findTokenBoundary(ctx.messages, CACHE_PREFIX_SIZE);
  const tailStartIndex = ctx.messages.length - ctx.config.keepRecentCount;

  // Protect prefix
  if (msg.index <= prefixEndIndex) {
    msg.metadata.shouldPrune = false;
    msg.metadata.protectedBy = "prefix";
    return true;
  }

  // Protect tail
  if (msg.index >= tailStartIndex) {
    msg.metadata.shouldPrune = false;
    msg.metadata.protectedBy = "recency";
    return true;
  }

  // Middle zone is prunable
  return false;
}
```

## When Prefix Protection Matters

### High Value Scenarios

1. **WITHOUT cache warming** - Prefix stability is critical
2. **Very long conversations** - Compounding cache benefits
3. **Static system prompts** - Large unchanging prefix
4. **Multiple cache boundaries** - Claude's hierarchical caching

### Lower Value Scenarios

1. **WITH cache warming** - Cache misses are managed
2. **Short conversations** - Below cache minimum anyway
3. **Highly dynamic contexts** - Little stable content

## Cost-Benefit Analysis

### Without Cache Warming

**Benefit**: Significant

- Prevents cache invalidation
- 60-80% reduction in cache misses
- Net positive cost impact

**Trade-off**: Moderate

- Some duplicates remain in prefix
- Slightly higher token count
- Less aggressive optimization

**Verdict**: Strongly recommended

### With Cache Warming

**Benefit**: Marginal

- Warming already handles cache misses
- Prefix protection adds incremental benefit
- Faster cache creation on warming calls

**Trade-off**: Same

- Reduced pruning in prefix
- Higher token count

**Verdict**: Optional enhancement

## Provider-Specific Considerations

### Claude (Anthropic)

**Hierarchical Caching**:

- Tools layer (cached separately)
- System layer (cached separately)
- Messages layer (prefix protection applies here)

**Opportunity**: Could preserve system prompt cache while pruning messages

### OpenAI

**Automatic Caching**:

- Single prefix structure
- Hash-based routing
- No explicit control

**Opportunity**: Stable prefix improves hash consistency

## Integration with DCP Rules

### Deduplication + Prefix Protection

```typescript
// Prefix-preserving deduplication
if (isDuplicate(msg) && msg.index > prefixEndIndex) {
  msg.metadata.shouldPrune = true;
  msg.metadata.pruneReason = "duplicate-tail";
}
// Duplicates in prefix are kept
```

### Superseded Writes + Prefix Protection

```typescript
// Preserve first write in prefix
const firstWrite = findFirstWrite(filePath);
if (firstWrite.index <= prefixEndIndex) {
  // Keep first, remove later
  if (msg.index > firstWrite.index) {
    msg.metadata.shouldPrune = true;
  }
} else {
  // Standard behavior: keep latest
  if (newerWriteExists(msg.filePath)) {
    msg.metadata.shouldPrune = true;
  }
}
```

### Error Purging + Prefix Protection

```typescript
// Defer error purging from prefix
if (isResolvedError(msg)) {
  if (msg.index <= prefixEndIndex) {
    msg.metadata.deferredPrune = true;
  } else {
    msg.metadata.shouldPrune = true;
  }
}
```

## Configuration Options

```typescript
interface PrefixProtectionConfig {
  enabled: boolean; // Default: false (use cache warming instead)
  prefixSize: number; // Default: 1024 tokens
  provider: "claude" | "openai"; // Auto-detect
  mode: "strict" | "adaptive"; // Strict = always protect, adaptive = context-dependent
}
```

## Adaptive Mode

```typescript
function shouldUsePrefix Protection(ctx) {
  // Skip if using cache warming
  if (ctx.config.useCacheWarming) return false;

  // Skip if conversation too short
  if (ctx.totalTokens < 1024) return false;

  // Enable if cache hit rate is low
  if (ctx.cacheHitRate < 0.3) return true;

  // Enable for long conversations
  if (ctx.messageCount > 50) return true;

  return false;
}
```

## Testing Strategy

### A/B Test Design

**Control**: No prefix protection  
**Test**: Prefix protection enabled  
**Measure**: Cache hit rate, total cost, token count

**Expected Results**:

- Higher cache hit rate (test)
- Higher token count (test)
- Lower total cost (test) - IF not using cache warming

### Metrics to Track

1. **Cache effectiveness**
   - Hit rate by zone (prefix, middle, tail)
   - Cache misses caused by prefix pruning
2. **Token usage**
   - Total tokens with/without protection
   - Tokens saved by middle-zone pruning
3. **Cost impact**
   - Net cost: (cache savings) - (extra tokens)
   - Cost per conversation
   - Long-term trends

## Key Takeaways

1. **Prefix protection is a fallback strategy** - Cache warming is the better solution
2. **Still valuable in specific scenarios** - Very long conversations, no warming
3. **Simple to implement** - Single rule, clear boundaries
4. **Measurable impact** - Easy to A/B test effectiveness

## When to Implement

**Priority 1**: Implement cache warming pattern (learning-455d01b5)  
**Priority 2**: If NOT using cache warming, implement prefix protection  
**Priority 3**: Consider as incremental enhancement even with warming

## Anti-Patterns to Avoid

❌ **Don't use prefix protection WITHOUT telemetry** - Can't measure if it helps  
❌ **Don't set prefix too large** - Reduces optimization opportunity  
❌ **Don't combine with aggressive mode** - Contradictory goals  
❌ **Don't implement before cache warming** - Solving wrong problem

## Related Concepts

- Cache warming pattern (learning-455d01b5)
- Dynamic context pruning
- Prompt caching mechanics
- Token boundary detection

## References

- Research: `.memory/research-0ca58594-dcp-caching-comprehensive.md`
- Implementation: See Phase 2 in research document
- Related: `.memory/research-a7f3c4d1-prompt-caching-impact.md`

---

**Status**: Theoretical strategy - validation needed  
**Applicability**: Systems NOT using cache warming  
**Impact**: 60-80% reduction in cache misses (estimated)  
**Recommendation**: Use cache warming instead, this as enhancement only
