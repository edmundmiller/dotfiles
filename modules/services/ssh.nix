{ options, config, lib, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.ssh;
in {
  options.modules.services.ssh = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      challengeResponseAuthentication = false;
      passwordAuthentication = false;
    };

    user.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDryEMVfVCSV7WynuHkB+gBTxN/0d5QJ3i2cw4XaFfP/+UFw8OnKn0IxG4UzrNJ0e/w9KM7t8Mx9iJPCqYONa5mkWcsjTsDxI9TRjEyAj5l40Np/r6hSGw5tLxNDnlWJI0YBEHN2i88bmYQ8iQg4FIBwcptV6eQgLFsMHa1B2ZDhvdtQxiSuoG/dQey7CNAmagbBfpbT09McTpyKRPPCKPY1z08dII+ng3AjWs8If4CgRirRDswLKfIqHZEtv9Yg8/fNbJa8/UDdXSrRJghzccu3JQS8/uxx8Gn00/81AqWNrKIIyz12sfm7pB3OT8I5QrnT8Pt3TM4hSEZDHzXWwtBluJlzP/TYsfzObdDsFLvdjf5QO2QuOAD3ZQhNN5zqUIvk9d+5u09dbTFygp2HP6puuDxsuvO7pFvkLgNwtSNG3978fGqiQBjGqI2xeZZmat93iOpiBZvRFXN0DNLO4nhnddgT2gG6mtQ5QpgHtKZ5IfYXVyBnh4FzbQ8UoIh1IW2pbmrXa6hBSeoiBEvluX33+cdts0MhQ4TWNg3pVSt6lAaqPBXyhNV3+a4IqKgFiXKHyuv8znORU7NGD7phhIGe/m/xJRyYzBN/d6kPDer7+ciROMto/e+XV/mzuR5rINRmq1+m2eOk8WMlAgI7lbmOAp55KChz4wxi5BvMpkd8Q== cardno:000611339240"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3EVc3A55QHe83NXfqrClVohWz2DscDgx0pr4PSlcGO edmund.a.miller@protonmail.com"
    ];

    programs.ssh.extraConfig = ''
      Host pubssh
          HostName pubssh.utdallas.edu
          User eam150030

      Host ganymede
          HostName ganymede.utdallas.edu
          User eam150030
          ProxyJump pubssh

      Host mz
          HostName mz.utdallas.edu
          User eam150030
          ProxyJump pubssh

      Host mk
          HostName mk.utdallas.edu
          User eam150030
          ProxyJump pubssh

      Host promoter
          HostName promoter.utdallas.edu
          User emiller
          ProxyJump pubssh
    '';
  };
}
