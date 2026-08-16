---
purpose: Distinguish OMP realtime voice, dictation, spoken replies, and speech-file generation.
applies_to: Configuring or diagnosing OMP microphone, speech, TTS, xAI, or live voice behavior.
entrypoint: Identify the speech path below before changing its provider or voice setting.
verification: Inspect active speech settings, check local models, and exercise the selected path.
update_when: OMP live transport, speech providers, authentication, voice settings, or keybindings change.
---

# OMP voice subsystems

OMP has separate speech paths with different providers. A provider setting for one path does not affect the others.

| Path                | Purpose                                                                   | Backend                        | Primary settings                              |
| ------------------- | ------------------------------------------------------------------------- | ------------------------------ | --------------------------------------------- |
| `/live` or `Ctrl+L` | Realtime speech-to-speech conversation and delegation to the coding agent | OpenAI Codex realtime          | `live.voice`                                  |
| Dictation           | Transcribe microphone input into the normal prompt editor                 | Local Parakeet or Whisper      | `stt.*`                                       |
| Spoken replies      | Read assistant output through the speakers                                | Local Kokoro                   | `speech.*`                                    |
| `tts` tool          | Let the agent generate an MP3 or WAV file                                 | Local Kokoro or xAI Grok Voice | `speechgen.enabled`, `providers.tts`, `tts.*` |
| `omp say`           | Speak text immediately or save it as WAV                                  | Local Kokoro                   | `tts.localModel`, `tts.localVoice`            |

## Realtime live voice

`/live` and `Ctrl+L` create `LiveSessionController`, which directly constructs `CodexLiveTransport`. The transport uses the `openai-codex` OAuth credential and Codex realtime signaling. `live.voice` selects the Codex realtime voice; it does not select a provider.

There is no `live.provider` setting in OMP 17.2.15. `providers.tts` does not affect `/live`. Adding xAI-backed live voice requires a realtime transport implementation and a provider-selection seam in OMP; selecting xAI in the TTS settings is insufficient.

Authoritative upstream sources:

- `packages/coding-agent/src/live/controller.ts`
- `packages/coding-agent/src/live/transport.ts`
- `packages/coding-agent/src/live/voices.ts`

## Dictation

Set `stt.enabled` to use local microphone transcription in the normal editor. Hold Space to record and release it to transcribe, or bind `app.stt.toggle` in `~/.omp/agent/keybindings.yml` for press-to-toggle recording:

```yaml
app.stt.toggle: Alt+S
```

Run `/hotkeys` to inspect the active binding. `stt.modelName` selects the local model; the default is Parakeet. `stt.submitTrigger` controls whether a completed transcription is inserted only or submitted automatically.

## Spoken replies

`speech.enabled` speaks assistant output as it streams. This path uses local Kokoro, independently of `providers.tts`.

- `speech.mode: assistant` speaks assistant messages.
- `speech.mode: yield` speaks only the final message.
- `speech.mode: all` also includes thinking output.
- `speech.voice` selects the Kokoro voice.

Use Escape to stop active playback.

## Speech-file generation

`speechgen.enabled` exposes the agent-callable `tts` tool. `providers.tts` selects its backend:

- `local`: Kokoro writes WAV/PCM16 on-device.
- `xai`: xAI Grok Voice writes MP3 or WAV and requires xAI Grok OAuth or `XAI_API_KEY`.
- `auto`: prefers local synthesis, but routes an MP3 request to xAI when xAI credentials are available. Without suitable xAI credentials, a requested MP3 becomes a sibling WAV.

`tts.localModel` and `tts.localVoice` apply to the local backend. They do not configure `/live` or automatic spoken replies.

`omp say` is a separate local-only command. It uses Kokoro, plays through the speakers by default, and writes WAV when passed `--out`:

```sh
omp say "Hello from OMP"
omp say --voice bm_fable "Hello" --out /tmp/hello.wav
```

## Verification

Inspect the active settings rather than inferring provider behavior from a settings-screen label:

```sh
omp config list --json | jq 'with_entries(select(.key | test("^(live|stt|speech|speechgen|providers\\.tts|tts\\.)")))'
omp setup speech --check --json
```

Then exercise the selected path:

- `/live`: run `/login` for OpenAI Codex OAuth, then use `Ctrl+L` and confirm two-way audio.
- Dictation: enable `stt.enabled`, record one phrase, and confirm the transcript appears in the editor.
- Spoken replies: enable `speech.enabled`, request a short response, and confirm audible playback.
- `tts` tool: enable `speechgen.enabled`, generate a file, and inspect the reported backend and output format.
- `omp say`: synthesize a short phrase with `--out`, then run it without `--out` to confirm playback.

Recheck these boundaries after an OMP update because the live transport and provider settings are upstream runtime behavior, not repository-owned interfaces.
