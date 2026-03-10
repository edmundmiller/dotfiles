# dmux package

Purpose: wrap upstream `dmux` with a local inference bridge so AI features can use existing `opencode`/`pi` auth before OpenRouter.

## What this package provides

- `dmux` wrapper binary (delegates to upstream npm `dmux`)
- `dmux-ai-infer` bridge (`opencode` / `pi` providers)
- `dmux-openrouter-shim.cjs` fetch interceptor for OpenRouter chat calls

## Provider order / fallback

Default provider: `pi`.

Fallback order when `DMUX_AI_PROVIDER=auto`:

1. `opencode`
2. `pi`
3. `openrouter` (only if `DMUX_OPENROUTER_REAL_KEY` exists)

Override with env:

- `DMUX_AI_PROVIDER=auto|opencode|pi|openrouter`
- `DMUX_AI_PROVIDER_ORDER=opencode,pi,openrouter`

## Env contract

- `DMUX_OPENCODE_ATTACH` - Optional `opencode serve` URL, used via `opencode run --attach`
- `DMUX_OPENCODE_MODEL` - Optional model override for opencode
- `DMUX_OPENCODE_AGENT` - Optional opencode agent override
- `DMUX_PI_MODEL` - Optional pi model override
- `DMUX_AI_TIMEOUT_MS` - Inference timeout in ms (default `20000`)
- `DMUX_REAL_BIN` - Explicit upstream dmux path (if not in default npm global paths)

## Upstream dmux requirement

This package does not bundle upstream dmux itself. Install upstream once:

```bash
npm install -g dmux@5.4.0
```

Then run `dmux` (wrapper from nix package).

## Interactive verification (manual)

1. Verify bridge provider detection:
   - `dmux-ai-infer probe && echo ok`
2. Verify opencode path:
   - `DMUX_AI_PROVIDER=opencode dmux-ai-infer infer <<<'{"messages":[{"role":"user","content":"reply ok"}]}'`
3. Verify pi path:
   - `DMUX_AI_PROVIDER=pi dmux-ai-infer infer <<<'{"messages":[{"role":"user","content":"reply ok"}]}'`
4. Run `dmux` inside interactive terminal + tmux and confirm:
   - slug generation uses AI output
   - merge commit message generation uses AI output
   - pane status analysis no longer hard-depends on OpenRouter key
