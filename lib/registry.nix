# Per-service dashboard/monitoring registry.
#
# Each `modules.services.<name>` declares how it wants to appear on the Gatus
# status page and the Homepage dashboard, instead of `gatus/default.nix` and
# `homepage.nix` carrying a hard-coded entry per service. Those two aggregators
# read `registry` off every service and merge the enabled ones in.
#
# `null` (the default) means "do not advertise this service" — most modules are
# infrastructure with nothing to show.
#
# Services that have no owning module (a router, a hosted SaaS dashboard) stay
# hard-coded in the aggregator; there is nothing here to hang them off.
{ lib, ... }:
let
  inherit (lib) mkOption types;

  # Display position, matching the hand-placed order these entries had before
  # they moved into the registry. Entries sort by `order`, then by name so
  # equal/default values stay deterministic. Pick a number near the services
  # you want to sit beside; gaps are intentional so later services can slot in
  # without renumbering.
  order = mkOption {
    type = types.int;
    default = 1000;
    description = "Sort position within the service's group (lower is earlier).";
  };

  gatusEntry = types.submodule {
    options = {
      name = mkOption { type = types.str; };
      group = mkOption { type = types.str; };
      url = mkOption { type = types.str; };
      interval = mkOption {
        type = types.str;
        default = "60s";
      };
      conditions = mkOption {
        type = types.listOf types.str;
        default = [ "[STATUS] < 500" ];
      };
      # Gatus alert providers are resolved by the aggregator, which knows which
      # providers are enabled; a service only opts in.
      alerts = mkOption {
        type = types.bool;
        default = false;
      };
      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      inherit order;
    };
  };

  homepageEntry = types.submodule {
    options = {
      group = mkOption { type = types.str; };
      name = mkOption { type = types.str; };
      description = mkOption { type = types.str; };
      icon = mkOption { type = types.str; };
      href = mkOption { type = types.str; };
      # attrs, not a submodule: widget shapes differ per Homepage widget type
      # and carry `{{HOMEPAGE_VAR_*}}` placeholder strings.
      widget = mkOption {
        type = types.nullOr types.attrs;
        default = null;
      };
      inherit order;
    };
  };
in
{
  /*
    Declare a service's dashboard/monitoring registry entries.

    Used as `options.modules.services.<name> = { ... } // mkRegistry { ... };`
    so the entries are option *defaults* — a host can still override or null
    them out without the module needing a second `config` block.
  */
  mkRegistry =
    {
      gatus ? null,
      homepage ? null,
    }:
    {
      registry = {
        gatus = mkOption {
          type = types.nullOr gatusEntry;
          default = gatus;
          description = "Gatus status-page endpoint for this service, or null.";
        };

        homepage = mkOption {
          type = types.nullOr homepageEntry;
          default = homepage;
          description = "Homepage dashboard card for this service, or null.";
        };
      };
    };
}
