{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.qb;
  mediaUid = config.users.users.${config.user.name}.uid;
  mediaGroup = config.users.users.${config.user.name}.group;
  mediaGid = config.users.groups.${mediaGroup}.gid;
in
{
  options.modules.services.qb = {
    enable = mkBoolOpt false;
    authKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime secret file for the downloader's separate Tailscale identity.";
    };
    webuiCredentialsFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime JSON secret with username and passwordPBKDF2 for the authenticated WebUI.";
    };
    mullvadExitNode = mkOption {
      type = types.str;
      default = "";
      example = "us-dal-wg-601.mullvad.ts.net";
      description = "Mullvad exit-node DNS name for the isolated downloader.";
    };
  };

  config = optionalAttrs (!isDarwin) (
    mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.authKeyFile != null && hasPrefix "/run/" cfg.authKeyFile;
          message = "qb.authKeyFile must name a runtime secret under /run, not a Nix store file.";
        }
        {
          assertion = cfg.webuiCredentialsFile != null && hasPrefix "/run/" cfg.webuiCredentialsFile;
          message = "qb.webuiCredentialsFile must name a runtime secret under /run, not a Nix store file.";
        }
        {
          assertion = hasSuffix ".mullvad.ts.net" cfg.mullvadExitNode;
          message = "qb.mullvadExitNode must select a Mullvad Tailscale exit node.";
        }
      ];

      fileSystems."/data/media/downloads" = {
        device = "unas.home:/data/media/downloads";
        fsType = "nfs";
        options = [
          "nfsvers=4.2"
          "hard"
          "_netdev"
          "x-systemd.mount-timeout=30s"
        ];
      };
      networking.nat = {
        enable = true;
        internalInterfaces = [ "ve-qb" ];
      };
      systemd.services."container@qb" = {
        unitConfig.RequiresMountsFor = [ "/data/media/downloads" ];
        bindsTo = [ "data-media-downloads.mount" ];
        after = [ "data-media-downloads.mount" ];
        # The native container post-start raises ve-qb only after guest boot.
        postStart = mkAfter ''
          ${pkgs.nixos-container}/bin/nixos-container run qb -- \
            ${pkgs.systemd}/bin/systemctl start --no-block qb-workload.target
        '';
      };

      containers.qb = {
        autoStart = true;
        privateNetwork = true;
        enableTun = true;
        hostAddress = "192.168.150.1";
        localAddress = "192.168.150.2";
        bindMounts = {
          "/data/media/downloads" = {
            hostPath = "/data/media/downloads";
            isReadOnly = false;
          };
        }
        // optionalAttrs (cfg.authKeyFile != null) {
          # NixOS mounts a separate /run/keys ramfs during container boot.
          "/run/qb-tailscale-auth".hostPath = cfg.authKeyFile;
        }
        // optionalAttrs (cfg.webuiCredentialsFile != null) {
          "/run/qb-webui".hostPath = cfg.webuiCredentialsFile;
        };

        config = {
          system.stateVersion = "25.05";
          networking = {
            hostName = "qb-downloads";
            defaultGateway = "192.168.150.1";
            useHostResolvConf = false;
            # Only tailscaled needs bootstrap DNS outside its own tunnel.
            nameservers = [ "1.1.1.1" ];
            firewall.trustedInterfaces = [ "tailscale0" ];
            nftables = {
              enable = true;
              tables.qb-egress = {
                family = "inet";
                content = ''
                  chain output {
                    type filter hook output priority -10; policy accept;
                    meta skuid ${toString mediaUid} oifname { "lo", "tailscale0" } accept
                    meta skuid ${toString mediaUid} counter reject
                  }
                '';
              };
            };
          };
          services.resolved.enable = false;
          services.tailscale = {
            enable = true;
            openFirewall = true;
            useRoutingFeatures = "client";
            authKeyFile = "/run/qb-tailscale-auth";
            extraUpFlags = [
              "--hostname=qb-downloads"
              "--advertise-tags=tag:qb-downloads"
            ];
            extraSetFlags = [
              "--exit-node=${cfg.mullvadExitNode}"
              "--exit-node-allow-lan-access=false"
              "--accept-dns=false"
            ];
          };
          systemd.targets.qb-workload.description = "Downloader services after host veth setup";
          systemd.services.tailscaled-autoconnect = {
            wantedBy = mkForce [ "qb-workload.target" ];
            serviceConfig = {
              Type = mkForce "oneshot";
              RemainAfterExit = true;
            };
            # The upstream autoconnect script expands the key into argv.
            script = mkForce ''
              if ! tailscale status --json | jq --exit-status '.BackendState == "Running"' >/dev/null; then
                tailscale up --auth-key=file:/run/qb-tailscale-auth --hostname=qb-downloads \
                  --advertise-tags=tag:qb-downloads \
                  --exit-node-allow-lan-access=false --accept-dns=false --timeout=60s
              fi
            '';
          };
          systemd.services.tailscaled-set.wantedBy = mkForce [ "qb-workload.target" ];
          users.users.qbittorrent.uid = mediaUid;
          users.groups.${mediaGroup}.gid = mediaGid;
          services.qbittorrent = {
            enable = true;
            group = mediaGroup;
            webuiPort = 8090;
            serverConfig = {
              LegalNotice.Accepted = true;
              BitTorrent.Session = {
                InterfaceName = "tailscale0";
                DefaultSavePath = "/data/media/downloads/complete";
                TempPath = "/data/media/downloads/incomplete";
                TempPathEnabled = true;
                AddTorrentStopped = true;
                UPnP = false;
              };
              Preferences.WebUI = {
                Address = "127.0.0.1";
                LocalHostAuth = true;
                UseUPnP = false;
              };
            };
          };
          systemd.services.qbittorrent = {
            wantedBy = mkForce [ "qb-workload.target" ];
            requires = [
              "nftables.service"
              "tailscaled-set.service"
            ];
            after = [
              "nftables.service"
              "tailscaled-set.service"
            ];
            bindsTo = [
              "nftables.service"
              "tailscaled.service"
            ];
            serviceConfig = {
              BindReadOnlyPaths = [
                "${pkgs.writeText "qb-resolv.conf" "nameserver 100.100.100.100\n"}:/etc/resolv.conf"
              ];
              LoadCredential = [ "webui:/run/qb-webui" ];
              # The upstream module installs its public config on every start.
              ExecStartPre = mkAfter [
                (pkgs.writeShellScript "qb-webui-credentials" ''
                  set -eu
                  ${pkgs.jq}/bin/jq --exit-status --raw-output '
                    if type == "object" and keys == ["passwordPBKDF2", "username"]
                      and (.username | type == "string")
                      and (.passwordPBKDF2 | type == "string")
                      and (.username | test("^[A-Za-z0-9._@-]+$"))
                      and (.passwordPBKDF2 | test("^@ByteArray\\([A-Za-z0-9+/]{22}==:[A-Za-z0-9+/]{86}==\\)$"))
                    then "\n[Preferences]\nWebUI\\Username=\(.username)\nWebUI\\Password_PBKDF2=\(.passwordPBKDF2)"
                    else error("Invalid qBittorrent WebUI credentials") end
                  ' "$CREDENTIALS_DIRECTORY/webui" >> /var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
                '')
              ];
            };
            preStart = ''
              ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 20 \
                https://am.i.mullvad.net/json | ${pkgs.jq}/bin/jq --exit-status \
                '.mullvad_exit_ip == true' >/dev/null
            '';
          };
          systemd.services.qb-tailscale-serve = {
            wantedBy = [ "qb-workload.target" ];
            requires = [ "tailscaled-set.service" ];
            after = [ "tailscaled-set.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --tcp=8090 tcp://127.0.0.1:8090";
              ExecStop = "${pkgs.tailscale}/bin/tailscale serve --tcp=8090 off";
            };
          };
        };
      };
    }
  );
}
