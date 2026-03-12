<!-- Agent-only ops notes for UNAS host. Keep concise, public-safe. -->

# UNAS agent notes

## Security / privacy

- Never commit full MAC in this public repo.
- Public-safe only: `d4:5d:64:**:**:**` (ASUSTek OUI).

## Bring-up workflow

1. Resolve current UNAS IP from router DHCP lease table (match ASUS MAC prefix `d4:5d:64`).
2. Verify reachability:
   - `ping -c 1 <ip>`
   - `nc -vz -w 2 <ip> 22`
3. Verify host identity over SSH (if key/auth works):
   - `ssh -o ConnectTimeout=5 emiller@<ip> 'hostname'`

## If IP changed, update all 3 places

- `flake.nix` → `deploy.nodes.unas.hostname`
- `bin/hey.d/remote.just` → `UNAS_HOST`
- `hosts/_home.nix` → `unas.home`

Keep these in sync.

## Deploy

```bash
hey unas
```

## Common blocker

- `connection refused` on port 22 => sshd not running.
- Fix on UNAS console:

```bash
sudo systemctl enable --now sshd
sudo systemctl status sshd --no-pager
```
