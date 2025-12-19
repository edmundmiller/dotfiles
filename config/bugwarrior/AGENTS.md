# Bugwarrior Configuration

Two-flavor bugwarrior setup: **personal** and **work** machines with different services and credential management.

## Architecture

```
config/bugwarrior/
├── AGENTS.md                  # This file
├── aliases.zsh                # Shared shell aliases
├── bugwarrior-personal.toml   # Personal machine (MacTraitor-Pro)
└── bugwarrior-work.toml       # Work machine (Seqeratop)
```

The nix module (`modules/shell/bugwarrior.nix`) symlinks the appropriate TOML based on `flavor` option.

## Flavors

### Personal (`bugwarrior-personal.toml`)

**Host:** MacTraitor-Pro

**Services:**
- `my_reminders` - Apple Reminders (personal tasks)
- `work_linear` - Linear (family/personal projects)
- `github_personal_issues/prs` - edmundmiller, BioJulia
- `github_phd_issues/prs` - Functional-Genomics-Lab
- `github_nfcore_issues/prs` - nf-core, bioinformaticsorphanage, bioconda

**Credentials:** opnix (1Password integration)
- `/usr/local/var/opnix/secrets/bugwarrior-linear-token`
- `/usr/local/var/opnix/secrets/bugwarrior-github-token`

### Work (`bugwarrior-work.toml`)

**Host:** Seqeratop

**Services:**
- `seqera_jira` - Seqera Jira
- `github_seqera_issues/prs` - nextflow-io, seqeralabs, seqera-services
- `github_nfcore_issues/prs` - nf-core, bioinformaticsorphanage, bioconda
- `work_gmail` - Work Gmail (TODO: requires OAuth setup)

**Credentials:** Manual file-based (no 1Password auth at runtime)
- `~/.config/bugwarrior/secrets/jira-host`
- `~/.config/bugwarrior/secrets/jira-username`
- `~/.config/bugwarrior/secrets/jira-password`
- `~/.config/bugwarrior/secrets/github-work-token`

## Credential Setup

### Personal Machine

Credentials managed via opnix. 1Password items required:

| Item | Vault | Field |
|------|-------|-------|
| Linear Bugwarrior | Private | credential |
| GitHub Personal Access Token | Private | token |

### Work Machine

Create secrets directory and add credentials manually:

```bash
mkdir -p ~/.config/bugwarrior/secrets
chmod 700 ~/.config/bugwarrior/secrets

# Add your Jira host URL
echo "https://your-company.atlassian.net" > ~/.config/bugwarrior/secrets/jira-host
chmod 600 ~/.config/bugwarrior/secrets/jira-host

# Add your Jira email
echo "your.email@company.com" > ~/.config/bugwarrior/secrets/jira-username
chmod 600 ~/.config/bugwarrior/secrets/jira-username

# Add your Jira API token (from https://id.atlassian.com/manage-profile/security/api-tokens)
echo "your-jira-api-token" > ~/.config/bugwarrior/secrets/jira-password
chmod 600 ~/.config/bugwarrior/secrets/jira-password

# Add your GitHub PAT
echo "ghp_your-work-github-token" > ~/.config/bugwarrior/secrets/github-work-token
chmod 600 ~/.config/bugwarrior/secrets/github-work-token
```

## Host Configuration

In host `default.nix`:

```nix
# Personal machine
modules.shell.bugwarrior = {
  enable = true;
  flavor = "personal";
};

# Work machine
modules.shell.bugwarrior = {
  enable = true;
  flavor = "work";
};
```

## Adding New Services

1. Determine which flavor(s) need the service
2. Add target section to appropriate TOML file(s)
3. Add any new secrets to credential setup (opnix for personal, manual for work)
4. Update this doc

## Future Work

- `work_gmail` service requires Google OAuth setup (see bead dotfiles-l6h)
- Consider FreshDesk/Rocketlane integration if API keys become available
