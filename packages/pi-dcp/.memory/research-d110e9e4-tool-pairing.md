# Research: Tool Pairing Integrity in Message Pruning

**Research Date**: January 10, 2026  
**Project**: Pi-DCP Dynamic Context Pruning Extension  
**Status**: Completed & Implemented  
**Impact Level**: Critical (API Compliance)

## Executive Summary

This research documents the discovery and resolution of a critical issue in message pruning systems: **tool pairing integrity**. When intelligently pruning conversation history, naïve pruning rules can break the semantic relationship between `tool_use` (function calls) and `tool_result` (function results) messages, causing API validation failures.

## Problem Statement

### The Core Issue

In Claude API conversations, tool invocation follows a strict protocol:

1. Assistant sends `tool_use` block with a unique `tool_use_id`
2. User responds with `tool_result` block referencing that same `tool_use_id`

**Critical Constraint**: Every `tool_result` must have a corresponding `tool_use` in the previous assistant message.

### When Message Pruning Breaks This

A naive pruning system might:

- Keep a `tool_result` message but prune its corresponding `tool_use` (orphaned result)
- Keep a `tool_use` message but prune its corresponding `tool_result` (incomplete pair)

**Result**: API validation error preventing message send

### Observed Error

```
Error: 400 {"type":"error","error":{"type":"invalid_request_error",
"message":"messages.6.content.1: unexpected `tool_use_id` found in `tool_result` blocks:
toolu_01VzLnitYpwspzkRMSc2bhfA. Each `tool_result` block must have a corresponding
`tool_use` block in the previous message."}}
```

## Research Findings

### Discovery 1: Naive Rule Ordering Breaks Pairs

**Finding**: Individual pruning rules operating independently cannot maintain tool pairing integrity.

**Why**: Consider this scenario:

1. Message A: `tool_use` with id "X"
2. Message B: `tool_result` referencing id "X"
3. Message C: Duplicate of Message A

Rules applied separately:

- `deduplication`: Prunes Message C (correct)
- `superseded-writes`: May keep Message A but not B
- `error-purging`: May prune Message A but not B
- `recency`: May selectively protect B but not A

**Result**: Orphaned tool_result or incomplete tool_use pair

### Discovery 2: Tool Pairing is a Cross-Message Constraint

**Finding**: Tool pairing integrity cannot be enforced within a single message - it requires analysis of relationships between messages.

**Implication**:

- Cannot be solved by individual rules acting on message content
- Requires a rule that:
  - Scans entire message history for tool relationships
  - Tracks tool_use_id → corresponding tool_result mappings
  - Enforces "both or neither" decision for paired messages

### Discovery 3: Rule Ordering Matters for Semantic Integrity

**Finding**: Not all rule orderings produce semantically valid results.

**Critical Rule**: The `tool-pairing` rule must execute BEFORE the `recency` rule.

**Why**: The recency rule overrides all other pruning decisions for recent messages. If applied first:

1. Recency protects a `tool_result` (recent message)
2. Tool-pairing would want to prune it (because its pair was already pruned)
3. Ordering conflict: Which decision wins?

**Solution**: Run tool-pairing AFTER other pruning rules but BEFORE recency. This ensures:

1. Tool pairs are identified and marked
2. Both are protected or both are pruned together
3. Recency's override doesn't break the pairing

### Discovery 4: Message Structure Variation in Pruning

**Finding**: Messages in conversation history may have malformed or missing content parts.

**Observation**:

```
Cannot read properties of undefined (reading 'type')
```

This error suggests:

- Some messages have `content` array items that are undefined
- Some messages have partially-formed content structures
- Defensive programming is essential when analyzing message structure

## Technical Solution

### Approach: Dedicated Tool-Pairing Rule

A specialized rule that:

1. **Prepare Phase**: Identify all tool relationships

   ```
   For each message:
   - Extract all tool_use_id values
   - Extract all tool_result references
   - Map bidirectional relationships
   - Store in metadata
   ```

2. **Process Phase**: Enforce pairing integrity

   ```
   For each paired (tool_use, tool_result):
   - If one is marked for pruning, mark both for pruning
   - If one is protected, protect both
   - Avoid orphaned tool operations
   ```

3. **Execution Timing**: Position in rule sequence
   ```
   Order: [dedup, supersedes, errors, tool-pairing, recency]
                                    ↑
                            Runs before recency
   ```

### Defensive Improvements

Enhanced metadata extraction with safety checks:

- Check if content part exists before accessing properties
- Use optional chaining for nested access
- Provide sensible fallbacks for missing data
- Log warnings for malformed messages

## Architectural Implications

### 1. Cross-Message Constraints Require Special Handling

**Pattern**: When a rule needs to consider relationships between multiple messages (not just individual message content), it must:

- Have access to full message history
- Run with appropriate ordering relative to other rules
- Include metadata about interdependencies

### 2. Rule Composition Needs Ordering Awareness

**Pattern**: Not all rule orders are semantically equivalent.

**Recommendation**:

- Document rule ordering requirements
- Consider rule dependencies in configuration
- Validate ordering at runtime if custom rules are used

### 3. API Constraints Flow Through to Implementation

**Pattern**: The Claude API's message structure constraints directly determine implementation requirements:

- API requirement (tool pairing) → creates pruning constraint → requires specialized rule → affects rule ordering

## Data Structures

### Tool Relationship Metadata

```typescript
interface ToolRelationship {
  tool_use_id: string; // Unique identifier
  tool_use_index: number; // Message index containing tool_use
  tool_result_index: number; // Message index containing tool_result
  status: "paired" | "orphaned"; // Detection state
}

interface ToolPairingMetadata {
  tool_use_ids: Set<string>; // All IDs in this message
  referenced_tool_use_ids: Set<string>; // IDs this message references
  relationships: ToolRelationship[]; // Full context
}
```

### Message Metadata Extension

```typescript
interface EnhancedMessageMetadata {
  // ... existing fields ...
  tool_pairing?: {
    paired_with_indices: number[]; // Indices of paired messages
    must_be_same_state: boolean; // Both kept or both pruned
  };
}
```

## Lessons Learned

### 1. Domain Constraints Require Domain Solutions

Context pruning isn't purely about message relevance or efficiency. It must respect domain-specific constraints (API protocol requirements).

**Implication**: Generic pruning algorithms need domain-specific rules.

### 2. Message Pruning is a Semantic Transformation

Removing messages changes conversation semantics:

- Tool pairs are broken
- Error recovery chains are interrupted
- Context references become dangling

**Implication**: Must validate semantic integrity after pruning.

### 3. Rule Composition Requires Careful Ordering

Sequential rule application can produce invalid results if ordering is wrong.

**Implication**: Document rule dependencies, validate at runtime.

## Verification & Testing

### Test Scenarios Covered

1. **Orphaned Tool Result**
   - Prune tool_use, keep tool_result → Both pruned
   - Result: Valid message sequence

2. **Incomplete Tool Use**
   - Prune tool_result, keep tool_use → Both pruned
   - Result: Valid message sequence

3. **Recency Override**
   - Recency protects recent tool_result → Tool-pairing protects its tool_use
   - Result: Both protected, valid

4. **Multiple Tool Pairs**
   - Multiple tool invocations in conversation → All pairs maintained independently
   - Result: All pairs remain intact

5. **Malformed Messages**
   - Messages with undefined or partial content → Handled gracefully
   - Result: No errors, safe fallbacks applied

## Recommendations for Similar Systems

### 1. Map Domain Constraints Early

Before implementing a pruning/filtering system:

- Identify all domain constraints (API rules, protocol requirements, semantic rules)
- Map how pruning affects each constraint
- Design rules to enforce constraints

### 2. Test with Invalid States

Don't just test that the system works - test that it prevents invalid states:

- Create test cases for each constraint violation
- Verify the system prevents that violation
- Document what makes a state invalid

### 3. Document Rule Dependencies

For systems with multiple rules:

- Explicitly document dependencies between rules
- Specify required ordering
- Provide rationale for ordering choices

### 4. Use Metadata for Relationships

When tracking relationships between entities:

- Use structured metadata instead of heuristics
- Make relationships explicit, not implicit
- Include reference information in metadata

## Future Research Directions

### 1. Generalized Cross-Message Constraint Framework

Could we build a framework for expressing constraints like:

- "If message A is kept, message B must be kept"
- "Messages A and B must have the same pruning state"
- "If A is pruned, B must be pruned before C"

### 2. Constraint Validation at Configuration Time

Instead of runtime checking, could we:

- Analyze rule configuration for conflicts
- Detect impossible constraint combinations
- Warn about ordering issues before deployment

### 3. Automated Rule Composition

Could we:

- Automatically derive optimal rule ordering
- Detect constraints and add rules automatically
- Validate that ruleset is complete

## Implementation Notes

### Files Modified

1. `src/rules/tool-pairing.ts` - NEW
   - Implements tool pairing protection
   - Bidirectional relationship checking

2. `src/metadata.ts` - ENHANCED
   - Added `extractToolUseIds()`
   - Added `hasToolUse()`, `hasToolResult()`
   - Fixed `hashMessage()` with defensive checks

3. `index.ts` - UPDATED
   - Registered new rule
   - Positioned before recency rule

4. `src/config.ts` - UPDATED
   - Added to default rule configuration

### Configuration Update

```typescript
const DEFAULT_CONFIG = {
  enabled: true,
  debug: true,
  rules: [
    "deduplication",
    "superseded-writes",
    "error-purging",
    "tool-pairing", // Position critical
    "recency",
  ],
  keepRecentCount: 10,
};
```

## References

### API Documentation

- Claude API Messages: https://docs.anthropic.com/claude/reference/messages_post
- Claude Tool Use: https://docs.anthropic.com/claude/docs/tool-use

### Related Research Areas

- Message pruning and summarization
- Constraint satisfaction in sequential systems
- Domain-specific optimization

## Conclusion

Tool pairing integrity is a **domain-specific constraint** that naive pruning systems cannot handle. By:

1. Making relationships explicit in metadata
2. Creating a specialized rule to enforce constraints
3. Positioning rules correctly in execution order
4. Adding defensive programming practices

We can safely prune messages while maintaining semantic integrity and API compliance.

**Key Insight**: Effective message pruning requires understanding not just individual messages, but the semantic relationships between them.

---

**Research Status**: Complete  
**Implementation Status**: Deployed  
**Testing Status**: Verified  
**Documentation**: Comprehensive
