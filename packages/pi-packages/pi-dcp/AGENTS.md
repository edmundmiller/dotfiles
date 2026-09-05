# Pi context pruning

The context hook runs prepare → process → filter; rules own pruning and tools
expose prune/distill/compress. Preserve assistant `thinking` and
`redacted_thinking` blocks unchanged, tool-call/result pairing, and protected
recent messages to keep provider requests valid.

Missing redacted-thinking blocks at provider ingestion/serialization belong to
pi-ai upstream, not this pruning layer. Fix the owning source rather than
patching mutable installed node_modules.
