---
name: derive-web-api-client
description: Derive a narrow, efficient API client or CLI from an authorized browser workflow by recording and analyzing HAR network traffic. Use when repeated browser automation is slow or brittle, when asked to inspect a HAR or reverse-engineer a site's first-party requests, or when turning a demonstrated website action into a structured command-line tool.
---

# Derive a Web API Client

Replace repeated browser driving with the smallest task-focused client supported by observed network evidence. Keep the browser as the discovery, authentication, and recovery surface.

## Guardrails

- Work only against accounts, data, and actions the user is authorized to access.
- Check for an official API first. Prefer it when it covers the workflow.
- Do not bypass CAPTCHAs, access controls, anti-abuse systems, or site restrictions.
- Treat every raw HAR as a credential-bearing secret. Store it in a temporary path with restrictive permissions; never commit, upload, or quote it.
- Start recording after login. Do not capture passwords, SSO, MFA, or unrelated browsing.
- Default to read-only operations. Add mutations only when explicitly requested; require `--dry-run` plus an explicit confirmation flag for purchases, messages, deletes, submissions, or financial actions.

## Workflow

### 1. Define one observable flow

Write the input, action, and expected output before recording. Keep each capture narrow, such as “search restaurants near this address and return ten unsponsored results.” Record separate flows for pagination, detail lookup, and mutations.

### 2. Record the network trace

Use an available controlled browser's HAR recording support. If none exists, ask the user to use browser DevTools: open **Network**, clear existing traffic, perform the flow once, then export **HAR with content**. Save it outside the repository and restrict access:

```bash
chmod 600 /tmp/flow.har
```

Preserve response bodies when the recorder offers that option. Note the page URL, exact interaction, timestamp, and visible result so later replay has a ground truth.

### 3. Build a secret-reduced inventory

Run the bundled helper before inspecting raw entries:

```bash
python3 ~/.agents/skills/derive-web-api-client/scripts/har_inventory.py \
  /tmp/flow.har --host api.example.com
```

The helper requires Python 3 and uses only the standard library.

The helper emits methods, normalized paths, status codes, field names, and GraphQL operation names. It omits header, query, payload, and response values except the GraphQL operation name. It excludes static assets by default. Its output is safer, not secret-free: paths, field names, and operation names may still be sensitive.

Identify the smallest request chain that explains the visible result. Prioritize first-party `fetch`/XHR requests and JSON or GraphQL responses. Separate required calls from bootstrap configuration, analytics, ads, feature flags, and prefetch noise.

### 4. Minimize and replay

Reproduce one read-only request with `curl` or a small script. Start from the observed request, then remove browser-only headers one at a time. Retain only demonstrated requirements such as content type, locale, CSRF token, persisted-query hash, or device/location context.

Never copy captured cookie, authorization, CSRF, address, or account values into source. Supply runtime credentials through an existing authorized session, OS credential store, environment variable, or documented token flow. If authentication expires, return to the browser for reauthentication instead of encoding the login sequence.

Confirm the replay's status, response shape, and user-visible meaning against the recorded result. Capture another narrow trace if the sequence is ambiguous; do not infer missing calls.

### 5. Implement the task-shaped client

Design commands around user actions, not raw endpoints. Keep the implementation small and preserve the repository's language and CLI conventions.

- Emit stable JSON on stdout; send diagnostics to stderr.
- Validate inputs and use distinct nonzero exit codes for auth, rate-limit, network, and schema failures.
- Implement observed pagination, retry hints, and rate limits; do not invent unsupported behavior.
- Parse only fields required by the command, but fail clearly when the response contract drifts.
- Redact secrets from errors, fixtures, snapshots, and debug logs.
- Mock transport in unit tests. Use sanitized, minimal fixtures rather than the raw HAR.

For mutations, expose a dry-run plan containing the target and payload shape without secrets. Require a second explicit flag to execute. Use idempotency keys when the observed protocol supports them, then re-read authoritative state after success.

### 6. Verify and hand off

Verify three boundaries separately:

1. Unit tests cover request construction, response parsing, redaction, and failures.
2. A live read-only smoke test matches the same browser flow's visible result.
3. The CLI works from a fresh process without the raw HAR or hard-coded session data.

Document the observed endpoints, authentication source, capture date, unsupported actions, and recovery path. Keep browser automation available for recapture when the private contract changes; do not silently fall back and claim the client succeeded.

## Completion criteria

- The client performs the defined flow with fewer interactions than browser control.
- No raw HAR, credential value, or personal response body appears in version control or logs.
- Every implemented request traces to captured evidence or official documentation.
- Fresh verification proves output equivalence and authentication behavior.

Source: [Dax Raad's HAR-to-CLI technique](https://x.com/thdxr/status/2078727284865827140).
