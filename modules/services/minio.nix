
{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.minio;
in {
  options.modules.services.minio = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
	  services.minio = {
		  enable = true;
		  dataDir = ["/data/minio"];
		  # package = "unstable.minio";
	  };
	  networking.firewall.allowedTCPPorts = [ 9000 ];

  };
}