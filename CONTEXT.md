# Dotfiles Context

This file defines project vocabulary only. It is not a specification or implementation guide.

## Glossary

### Home Assistant sleep lifecycle

**Winding Down**:
A passive circadian prelude that gradually makes the home dimmer and warmer before active bedtime routines begin.
_Avoid_: Get Ready for Bed, Good Night, Sleep

**Get Ready for Bed**:
The first bedtime phase that prepares the house and people to transition toward bed.
_Avoid_: Good Night, Sleep

**Good Night**:
The second bedtime phase for when people are in bed and ready for bedroom-only settling actions.
_Avoid_: Ignite, Launch Sequence, Audiobook, Sleep

**Sleep**:
The final bedtime phase for fully asleep state after settling time has elapsed.
_Avoid_: Good Night, Get Ready for Bed

### Global agent skill

An agent skill intended for use across projects. In this dotfiles repo, durable global skills normally live under `skills/`, especially `skills/catalog/`, and are installed into the global skills target by the normal rebuild workflow.

### Project-local agent skill

An agent skill intended only for work inside one repository. In this dotfiles repo, project-local skills live under `.agents/skills/` and must not be installed into the global skills target.

### Global skills target

The user-level skills directory `~/.agents/skills`. It may contain globally useful skills installed by this repo and manually installed or created global skills. It must not contain this dotfiles repo's project-local skills from `.agents/skills/`.

### Hermes Runtime Root

The host-level Hermes state root, usually `~/.hermes`, shared by Interactive Hermes frontends and Hermes Gateway processes on that host.
_Avoid_: Hermes Profile

### Hermes Profile

A named Hermes state directory under a Hermes Runtime Root, such as `~/.hermes/profiles/scintillate`, with its own config, environment, sessions, memory, skills, cron jobs, and gateway state.
_Avoid_: workspace, sandbox

### Interactive Hermes

A per-user Hermes runtime for a person interactively using Hermes on a specific machine. It may expose CLI, TUI, or Desktop frontends, and its purpose can vary by host. Interactive Hermes uses the host's Hermes Runtime Root and may target one of its Hermes Profiles.
_Avoid_: Hermes Desktop, Hermes Coding Agent

### Hermes Gateway

A long-running Hermes background process for messaging, web, or remote access. A Hermes Gateway may run on a server or desktop. It shares the host's Hermes Runtime Root, while each gateway identity should be represented as a Hermes Profile under that root.
_Avoid_: Hermes Service

### Hermes Runtime Preset

A reusable Hermes configuration/persona bundle owned outside host wiring, typically by `agents-workspace`. Dotfiles may select a preset for a host but should not define reusable Hermes personas.
_Avoid_: host-specific wiring

### Host Hermes Wiring

Dotfiles-owned configuration that installs Hermes frontends, chooses a runtime preset, sets the host's `HERMES_HOME`, wires host-specific secrets, and bootstraps mutable runtime files for one machine.
_Avoid_: Hermes Runtime Preset

## Relationships

- **Winding Down** precedes **Get Ready for Bed** in the Home Assistant sleep lifecycle.
- **Get Ready for Bed** precedes **Good Night** in the Home Assistant sleep lifecycle.
- **Good Night** precedes **Sleep** in the Home Assistant sleep lifecycle.

## Flagged ambiguities

- "Ignite" was used as a voice phrase for the bedtime settling action; resolved: the canonical domain term is **Good Night**, and "Ignite"/"Launch Sequence" are retired rather than retained as aliases.
- "Goodnight" previously referred to the first house-prep phase; resolved: the canonical first active phase is **Get Ready for Bed**, and **Good Night** is the in-bed settling phase.
