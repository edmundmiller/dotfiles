---
purpose: Record upstream research into the Schiit Modi 3+ audio failure on Arch Linux 7.1.8.
applies_to: meshify audio troubleshooting after the Omarchy Quattro upgrade.
entrypoint: Compare the tested kernels, then inspect the linked upstream changes and trackers.
verification: Re-run the linked tracker searches and reproduce with a controlled kernel A/B test.
update_when: An upstream report, responsible commit, or fixed kernel is identified.
---

# Schiit Modi 3+ Linux 7.1.8 audio regression

Research snapshot: 2026-08-29.

## Result

No existing report was found for silent playback from a Schiit Modi 3+ on Linux
7.1.8. Searches covered the Arch Linux kernel package tracker, Linux kernel
Bugzilla, and indexed public issue reports using `Schiit`, `Schiit Modi`, USB ID
`30be:1014`, `snd_usb_audio`, and `7.1.8`.

The local evidence still supports a regression:

- Arch `linux 7.1.8.arch1-3` produced no audible output, including with direct
  ALSA playback that bypassed PipeWire.
- The Schiit sink monitor contained the expected signal, but the physical DAC
  output was silent.
- After rolling back to `linux 7.1.6.arch1-1`, test tones, Discord, and Rocket
  League worked for a full gaming session.

This is not yet a commit-level bisection, so the responsible change is unknown.

## Upstream delta

Linux 7.1.8 added two generic USB-audio streaming changes in
`sound/usb/endpoint.c`:

1. [`bd65b7191683` — fix DMA buffer sizing when `fill_max` is set](https://github.com/gregkh/linux/commit/bd65b7191683bebd9923904f0558b9211b9129da)
2. [`53f0aa37eb94` — clamp frame size in implicit-feedback mode](https://github.com/gregkh/linux/commit/53f0aa37eb945f3c983f61d12fc35eb33debb8a9)

Neither obviously applies to this device. The Modi 3+ USB descriptors report
class-specific endpoint `bmAttributes = 0x00`, so `UAC_EP_CS_ATTR_FILL_MAX`
(`0x80`) is clear. `/proc/asound/card3/stream0` reports an asynchronous endpoint
with an explicit feedback endpoint and `Implicit Feedback Mode: No`.

The other USB-audio changes in the
[`v7.1.7...v7.1.8` stable comparison](https://github.com/gregkh/linux/compare/v7.1.7...v7.1.8)
are MIDI-, RME-, Akai-, or 6fire-specific. Between 7.1.8 and 7.1.12, the only
clearly identified USB-audio regression fix is specific to a SteelSeries mixer,
not generic playback:
[`0663d1df8d28`](https://github.com/gregkh/linux/commit/0663d1df8d286843cca698d8c7ade02bdde248fb).

## Arch build difference

Arch rebuilt 7.1.8 with GCC 16.2.1 for `arch1-2` and `arch1-3`:

- [Initial `7.1.8.arch1-1` package update](https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/commit/d65b837da2bc44bd4837d52464e80edfe36def28)
- [`7.1.8.arch1-2` GCC 16.2.1 rebuild](https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/commit/a713bad0b4d7474555603de3a497382032368467)
- [`7.1.8.arch1-3` GCC 16.2.1 rebuild](https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/commit/09c7759a787f6fb0aa99cb494ec19864dacf41af)

The installed 7.1.6 package was built with GCC 16.1.1, while the failing 7.1.8
package was built with GCC 16.2.1. No matching GCC miscompilation report was
found, but this means the A/B test changed both kernel source and compiler.

## Tracker searches

- [Arch kernel issues matching `Schiit`](https://gitlab.archlinux.org/api/v4/projects/42594/issues?scope=all&search=Schiit&per_page=100) — no matches
- [Arch kernel issues matching `7.1.8`](https://gitlab.archlinux.org/api/v4/projects/42594/issues?scope=all&search=7.1.8&per_page=100) — no matching audio report
- [Kernel Bugzilla search for `Schiit Modi`](https://bugzilla.kernel.org/buglist.cgi?quicksearch=Schiit%20Modi) — no matching 7.1.8 audio report
- [Linux stable `v7.1.6...v7.1.8` comparison](https://github.com/gregkh/linux/compare/v7.1.6...v7.1.8)

## Best next discriminator

Test Arch's archived `7.1.8.arch1-1` build:

- If `arch1-1` works and `arch1-3` fails, investigate the GCC 16.2.1 rebuild.
- If both fail, investigate the upstream 7.1.8 stable delta.

Until that test is run, report the problem as a reproducible version regression,
not as a confirmed bug in either of the two `sound/usb/endpoint.c` commits.
