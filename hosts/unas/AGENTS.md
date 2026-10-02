# UNAS

Keep the full MAC private; the public-safe ASUS prefix is `d4:5d:64:**:**:**`.
Resolve its address from router DHCP leases and confirm SSH hostname as `emiller`.

An IP change affects three sources: `flake.nix` (`deploy.nodes.unas.hostname`),
`bin/hey.d/remote.nu` (`UNAS_HOST`), and `hosts/_home.nix` (`unas.home`). Keep them
consistent. Deploy with `hey unas` when authorized.

Port 22 refusing connections usually requires console recovery of sshd:
`sudo systemctl enable --now sshd`, then `systemctl status sshd`.

Run `hey check hosts/unas bin/hey.d/remote.nu` after changing address wiring.
DNS/DHCP inspection is read-only; console repair and `hey unas` deployment need
explicit authorization.

`nas.nix` restricts NFS exports and TCP 2049 source rules to the home LAN
`192.168.1.0/24` and Tailscale `100.64.0.0/10`. Keep them aligned. After authorized
deployment, inspect `exportfs -v` and `iptables -S nixos-fw` on UNAS.
