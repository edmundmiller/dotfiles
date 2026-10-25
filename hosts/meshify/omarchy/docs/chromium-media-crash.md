---
purpose: Track Chromium Media SIGILL crashes and the update and acceleration retest plan on meshify.
applies_to: Chromium renderer crashes alongside NVIDIA memory mapping errors.
entrypoint: Read the current status, then follow the recovery and retest steps.
verification: Retry the affected media and compare new coredumps and kernel logs.
update_when: An update completes, acceleration changes, or a reproduction confirms or rejects the suspected cause.
---

# Chromium media crash on meshify

## Evidence from September 26, 2026

Chromium renderer PID 1993049 crashed in its Media thread at 21:59:45 CDT.
Systemd finished recording the dump at 22:00:43. Renderer PID 2006681 crashed
at 22:02:31 at the same instruction, with its dump recorded at 22:04:35.

Both crashes coincided with NVIDIA kernel messages:

```text
dmaAllocMapping_GM107: can't alloc VA space for mapping.
NV_ERR_NO_MEMORY
Failed to map NvKmsKapiMemory
```

GDB found an `int3; ud2` sequence with execution stopped on `ud2`. This
strongly suggests a deliberate fatal-error trap in Chromium's media path.
The NVIDIA errors concern mapping address space. They do not prove that
system RAM or all GPU memory was exhausted. No system OOM kill was found.

The suspected cause is the Chromium/NVIDIA graphics interaction. The exact
failed check and triggering page remain unknown. Debug symbols were
unavailable and the core lacked stack memory needed to unwind its threads.
No evidence establishes an Omarchy-specific bug. Extracted core copies were
deleted because they can contain private browser data.

Versions observed before the update attempt:

- Chromium `151.0.7922.137-1`.
- NVIDIA RTX 2070 SUPER, driver `610.57.04`.
- `nvidia-utils` and `nvidia-open-dkms` `610.57.04-1`.
- Linux `7.1.8.arch1-3`.
- Omarchy `4.0.0-1.2`.

## Current status

- The user authorized the normal Omarchy update and this documented retest plan.
- `omarchy update -y` was launched in a visible terminal on September 26.
  The system package transaction and boot-image hooks finished. The updater
  reached Omarchy migrations and is waiting for the user's sudo password at
  migration `1787133200`, "Add webp decoding to the shell". The full update
  has not yet completed. Its live log is `/tmp/omarchy-update.log`.
- Installed versions now include Chromium `152.0.7977.82-1` and Linux
  `7.2.3.arch1-3`. NVIDIA packages remain `610.57.04-1`. The NVIDIA DKMS build
  for `7.2.3-arch1-3` finished. The running kernel is still `7.1.8-arch1-3`.
- No acceleration setting has been changed by this investigation.
- Reboot and post-update reproduction have not been performed.
- No known fixed version has been established. An update is a reasonable
  attempt, not a confirmed fix.

## Recovery and retest

1. Finish the normal `omarchy update` flow. Enter the sudo password in its
   terminal if requested. Record the exit status and versions below. Do not
   treat opening the updater as a successful update.
2. Save work and reboot when ready. This loads the installed kernel and driver
   and clears accumulated GPU mappings. Do not reboot an active session from
   an agent without coordinating with the user.
3. Retry the affected page or video with acceleration enabled. If it no longer
   crashes, leave acceleration enabled and record the tested page or workload
   privately, the versions, and the test duration.
4. If the crash persists, open `chrome://settings/system`, turn off
   "Use graphics acceleration when available", and relaunch after saving work.
   Retry the same workload. Check `chrome://gpu` for the resulting graphics
   status. This bypasses GPU-backed paths implicated by the mapping failures,
   but can increase CPU use and reduce video performance.
5. If acceleration was disabled before updating, re-enable it after the update
   and reboot, then repeat the same workload. If only the accelerated run
   crashes, leave acceleration off temporarily and record that result here.
6. If crashes continue with acceleration off, inspect the new dump and logs.
   Do not assume every SIGILL has this cause. A matching media trap and NVIDIA
   mapping errors support the existing diagnosis; different evidence needs a
   new diagnosis.

Use these read-only checks after updating and after each reproduction:

```bash
pacman -Q chromium nvidia-utils nvidia-open-dkms linux
uname -r
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used --format=csv
coredumpctl list chromium --since today --no-pager
journalctl -k --since today --no-pager | grep -E 'NVRM|NvKms|invalid opcode|Out of memory'
```

Record results here so a future session can distinguish pending work from
tested fixes. Do not commit raw cores, browser history, or private page URLs.
Browser session recovery files exist under `~/.config/chromium/Default/Sessions/`;
use History or Ctrl+Shift+T for closed tabs. Unsaved page state is not guaranteed
to be recoverable.

Diagnosis and authorization are in the
[Amp conversation](https://ampcode.com/threads/T-01a0e0d2-7d96-76ef-94b7-cc7b66af123c).
