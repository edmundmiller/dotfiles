# UNAS

Keep the full MAC private; the public-safe ASUS prefix is `d4:5d:64:**:**:**`.
Resolve its address from router DHCP leases and confirm SSH hostname as `emiller`.

An IP change affects three sources: `flake.nix` (`deploy.nodes.unas.hostname`),
`bin/hey.d/remote.nu` (`UNAS_HOST`), and `hosts/_home.nix` (`unas.home`). Keep them
consistent. Deploy with `hey unas` when authorized.

Port 22 refusing connections usually requires console recovery of sshd:
`sudo systemctl enable --now sshd`, then `systemctl status sshd`.
