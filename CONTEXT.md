# Dotfiles Context

This file defines project vocabulary only. It is not a specification or implementation guide.

## Glossary

### Global agent skill

An agent skill intended for use across projects. In this dotfiles repo, durable global skills normally live under `skills/`, especially `skills/catalog/`, and are installed into the global skills target by the normal rebuild workflow.

### Project-local agent skill

An agent skill intended only for work inside one repository. In this dotfiles repo, project-local skills live under `.agents/skills/` and must not be installed into the global skills target.

### Global skills target

The user-level skills directory `~/.agents/skills`. It may contain globally useful skills installed by this repo and manually installed or created global skills. It must not contain this dotfiles repo's project-local skills from `.agents/skills/`.
