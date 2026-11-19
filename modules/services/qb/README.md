# Isolated qBittorrent

`modules.services.qb` runs native qBittorrent and a separate Tailscale daemon
inside the `qb` NixOS container. It replaces the old Gluetun configuration.
The NUC keeps its current Tailscale identity and Internet routes.

The NUC configuration enables the container with dedicated encrypted credentials
and the `us-dal-wg-601.mullvad.ts.net` exit. Activation requires the guarded NUC
deployment workflow. A local configuration edit does not start the downloader.

## Network and storage boundaries

- The container has its own network namespace and TUN device. Its root-owned
  Tailscale daemon retains the ordinary connection for VPN bootstrap.
- Guest boot finishes before NixOS raises the host-side container link. The
  host then queues `qb-workload.target` for enrollment, exit configuration,
  qBittorrent and Serve, so enrollment cannot deadlock guest readiness.
- Initial enrollment advertises the downloader tag without selecting an exit.
  Enrollment waits up to 60 seconds for the configured exit to appear online
  and eligible in the peer map, which can arrive after Tailscale reports Running.
  Only then can `tailscaled-set` select that exit. An unavailable exit fails
  startup without selecting another node or requesting a new enrollment key.
  qBittorrent cannot start before that configuration and its Mullvad check pass.
- qBittorrent binds to `tailscale0`. An independent nftables output rule rejects
  its IPv4 and IPv6 traffic on every interface except loopback and `tailscale0`.
  The firewall does not exempt established connections from this rule.
- qBittorrent requires the firewall and Tailscale configuration units. Stopping
  the firewall or Tailscale daemon stops qBittorrent. Before startup, a request
  under qBittorrent's UID must pass Mullvad's connection check.
- qBittorrent gets a private resolver file with only Tailscale's
  `100.100.100.100`. Its process cannot use the container's public bootstrap DNS.
  Exit selection enables Tailscale DNS so that resolver uses the selected
  Mullvad exit's advertised DNS servers. Enrollment keeps bootstrap DNS until then.
- The authenticated WebUI listens on container loopback at port 8090.
  Tailscale Serve forwards TCP port 8090 to it through the encrypted tailnet.
  There is no host port publication or public torrent-port forwarding.
- The separate identity advertises only `tag:qb-downloads`. The tailnet policy
  grants it Mullvad eligibility and Internet egress, not permission to
  initiate connections to private tailnet services. Existing trusted members,
  servers, and Amp agents retain their broad inbound access. Grok Bot and the
  GitHub deployment identity do not gain downloader access. No Funnel is granted.
- Both credentials are root-only agenix files. Tailscale reads its key by file
  reference. qBittorrent receives its WebUI credential through systemd
  `LoadCredential`, then adds it to the generated configuration at each start.
  The WebUI login therefore survives restarts. The password hash stays out of
  the Nix store and command arguments, but the service's private state contains it.
- The NAS export `unas.home:/data/media/downloads` mounts on the NUC at
  `/data/media/downloads` and appears at the same path inside the container.
  Container startup requires that mount. Completed and incomplete downloads
  use its `complete` and `incomplete` subdirectories. Unmounting the share stops
  the container instead of allowing writes to the underlying local directory.
- The container's qBittorrent UID and GID match the NUC's configured user.
  The NAS must permit those numeric identities to write to the download share.
- State persists under `/var/lib/nixos-containers/qb`. The old Gluetun directory
  is not imported or deleted. New torrents default to stopped, but a client can
  override that default. Do not connect Radarr or Sonarr during validation.
  The generated configuration declares migration version 8 for qBittorrent 5.2.2,
  preventing its legacy paused-setting migration from resetting that default.

## Requirements before an authorized deployment

1. Restore verified SSH access to the NAS and check the download share's numeric
   ownership and permissions. Do not change ownership without approval.
2. Provision the two encrypted files described below. The NUC already wires
   their runtime paths, but declares the secrets only when `qb.enable` is true.
   Missing encrypted files do not break the disabled configuration.
3. Select an available `*.mullvad.ts.net` exit node through
   `modules.services.qb.mullvadExitNode`. The module does not choose a region.
4. Review `infra/tailnet/tailscale/policy.hujson` in `edmundmiller/family-ops`.
   Use `mise run //:tailnet -- run plan tailscale` from that repository for the
   read-only plan through the owning Alchemy `TailnetAccess/prod` workflow.
   It requires the existing state credential, reviewed private baseline, and
   retained original federation journal via `TAILNET_FEDERATION_JOURNAL_DIR`.
   Review source/live drift before apply.
   Apply only after separate approval. Do not use the retired standalone
   `tailnet` repository as a deployment source. Existing NUC
   authorization does not prove the new device has Mullvad access or a seat.
   Device registration and policy changes require separate approval.
5. Review the private `192.168.150.1` and `192.168.150.2` container link for
   address conflicts. Confirm that the host's NAS name resolves without changing
   Audiobookshelf's mount.
6. Keep Radarr, Sonarr, and Prowlarr disconnected from this downloader until
   their existing monitored content has been reviewed. Their saved Transmission
   clients are not migrated by this module.
7. Obtain deployment approval before enabling the module. Confirm the persistent
   WebUI credential works before client integration.

## Provision credentials only after approval

The dedicated recipient file is `hosts/nuc/secrets/qb/secrets.nix`. It uses the
same Edmund and NUC public keys as the host's existing secrets. This separate
directory avoids the host's automatic secret discovery until the module is enabled.
The encrypted enrollment key and persistent WebUI credential live in this directory.

Use the existing short-lived, single-use, non-ephemeral Tailscale auth key from
the `TailnetQbEnrollment/prod` owner. Do not mint a replacement automatically.
The key must be restricted to `tag:qb-downloads`.
Never add `tag:server`, `tag:nuc`, or an agent tag. Encrypt
only its raw value as `tailscale-auth.age` using agenix in that directory.
The NUC decrypts it to `/run/agenix/qb-tailscale-auth`, mode `0400`, owner root.
The container binds it read-only at `/run/qb-tailscale-auth`, outside NixOS's
separate `/run/keys` ramfs. Its persisted Tailscale state keeps the identity
after the enrollment key expires or is consumed.
Replacing lost container state requires a new authorized enrollment.

Encrypt a JSON object as `webui.age` with exactly two string fields, `username`
and `passwordPBKDF2`. The username accepts letters, digits, `.`, `_`, `@`, and `-`.
The second field contains qBittorrent's `@ByteArray(base64-salt:base64-hash)`
PBKDF2-SHA512 representation, with a 16-byte salt, a 64-byte hash, and 100,000
iterations. Generate it from a unique password through secure local input,
not a shell argument or chat message.
The NUC decrypts it to `/run/agenix/qb-webui`, also root-owned `0400`.
The service rejects malformed credentials instead of starting with a temporary login.
After any later secret rotation, restart the container through the authorized
deployment workflow so its read-only binds use the new agenix generation.

Keep plaintext out of the repository and editor backups. Run `agenix -e` from
the dedicated secret directory with an approved secure editor. Do not run a
global rekey, overwrite another service's secret, or paste either secret into
the thread. Retain the WebUI password in the password manager for later client setup.

## Validation before downloads

The hermetic `vm-services-qb-egress-test` check starts the real NixOS container
and qBittorrent. It substitutes a local network link for Tailscale and tmpfs for
the NAS, without registering a device or contacting an indexer. It checks direct
egress rejection, IPv4 and IPv6 traffic over the simulated VPN, rejection after
VPN loss despite a working fallback route, persistent WebUI authentication,
rejection of malformed credentials, and shutdown when the firewall or storage
mount stops. A network-dependent enrollment fixture must reach the real host
veth before the downloader starts, catching container boot deadlocks. A separate
local daemon-API fixture runs the real Tailscale CLI
against the generated enrollment script and settings. It verifies enrollment
before named-exit selection and identity reuse after the enrollment file is gone.
It covers delayed exit availability and rejects a missing configured exit even
when another exit is online.
The authenticated application API must report `tailscale0` as the binding and
new torrents stopped, with torrent and WebUI UPnP disabled, including after a
restart regenerates the configuration.
Neither fixture proves a real Mullvad session or NAS access.

After an authorized deployment, validate the new device's selected Mullvad exit,
DNS, and connection-check response under qBittorrent's UID. Then test VPN loss
without torrents, verify that NAS writes land on the NAS, and confirm tailnet-only
WebUI access. Do not change the NUC's own exit node to make these checks pass.

Radarr and Sonarr still need their library folders moved to NAS-backed paths
before production. That migration is separate from this downloader configuration.
To roll back an authorized deployment, disable `modules.services.qb` through the
normal NUC deployment workflow. Preserve container state and NAS downloads.
