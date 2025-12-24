# WakaTime Integration for Claude Code

Automatic time tracking and productivity metrics for Claude Code sessions.

## Setup

WakaTime API key is securely managed using agenix and automatically configured on system rebuild.

### Already Configured

The API key is encrypted and managed via agenix. Configuration is automatic after running:

```bash
hey rebuild
```

### Manual Setup (if needed)

If you need to update the API key:

1. Get your WakaTime API key from [wakatime.com/settings/api-key](https://wakatime.com/settings/api-key)

2. Encrypt and update the secret:

```bash
cd hosts/shared/secrets
echo -n "waka_YOUR_NEW_KEY" > /tmp/waka.txt
RULES=./secrets.nix agenix -e wakatime-api-key.age -i ~/.ssh/id_ed25519 < /tmp/waka.txt
rm /tmp/waka.txt
```

3. Apply Configuration

Rebuild your system to activate the plugin:

```bash
hey rebuild
```

4. Rebuild and verify:

```bash
hey rebuild
```

## How It Works

The WakaTime API key is:

1. **Encrypted** with your SSH key using agenix (`hosts/shared/secrets/wakatime-api-key.age`)
2. **Decrypted** at system activation to `~/.local/share/agenix/wakatime-api-key`
3. **Referenced** in `~/.wakatime.cfg` using `api_key_vault_cmd`
4. **Never stored** in plain text in the nix store or git repository

Configuration is managed in:

- `hosts/shared/secrets/secrets.nix` - Defines which SSH keys can decrypt
- `modules/agenix.nix` - Handles decryption on Darwin
- `modules/shell/claude.nix` - Generates ~/.wakatime.cfg

## Verification

Start using Claude Code normally. Your activity should appear on your [WakaTime Dashboard](https://wakatime.com/dashboard) within a few minutes.

To verify the configuration:

```bash
# Check the decrypted secret exists
ls -l ~/.local/share/agenix/wakatime-api-key

# Check wakatime config
cat ~/.wakatime.cfg
```

## What Gets Tracked

- File paths and project names from your IDE
- Time spent in Claude Code sessions
- Language and project statistics

## Privacy

WakaTime collects file names and project information. To obfuscate file names:

1. Go to [WakaTime Settings](https://wakatime.com/settings)
2. Enable "Obfuscate file names" option
3. Configure patterns to exclude sensitive paths

See [WakaTime Privacy](https://wakatime.com/privacy) for details.

## Troubleshooting

### No data appearing

1. Verify secret is decrypted:

   ```bash
   cat ~/.local/share/agenix/wakatime-api-key
   ```

2. Check wakatime config references the secret:

   ```bash
   cat ~/.wakatime.cfg
   # Should show: api_key_vault_cmd = cat /Users/emiller/.local/share/agenix/wakatime-api-key
   ```

3. Verify plugin is enabled:

   ```bash
   grep wakatime ~/.claude/settings.json
   ```

4. View WakaTime logs:

   ```bash
   tail -f ~/.wakatime/wakatime.log
   ```

### Secret decryption fails

If the secret can't be decrypted, verify your SSH key is listed in `hosts/shared/secrets/secrets.nix`:

```bash
# Your SSH public key should match one in secrets.nix
cat ~/.ssh/id_ed25519.pub
```

### Plugin not loaded

After modifying `config/claude/settings.json` or secrets, you must rebuild:

```bash
hey rebuild
```

## Resources

- [WakaTime Dashboard](https://wakatime.com/dashboard)
- [WakaTime Claude Code Plugin](https://github.com/wakatime/claude-code-wakatime)
- [WakaTime Documentation](https://wakatime.com/help)
