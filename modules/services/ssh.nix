{ config, options, pkgs, lib, ... }:
with lib; {
  options.modules.services.ssh = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.services.ssh.enable {
    services.openssh = {
      enable = true;
      forwardX11 = true;
      permitRootLogin = "no";
      passwordAuthentication = false;

      # Allow local LAN to connect with passwords
      extraConfig = ''
        Match address 192.168.0.0/24
        PasswordAuthentication yes
      '';
    };

    users.users.emiller.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDryEMVfVCSV7WynuHkB+gBTxN/0d5QJ3i2cw4XaFfP/+UFw8OnKn0IxG4UzrNJ0e/w9KM7t8Mx9iJPCqYONa5mkWcsjTsDxI9TRjEyAj5l40Np/r6hSGw5tLxNDnlWJI0YBEHN2i88bmYQ8iQg4FIBwcptV6eQgLFsMHa1B2ZDhvdtQxiSuoG/dQey7CNAmagbBfpbT09McTpyKRPPCKPY1z08dII+ng3AjWs8If4CgRirRDswLKfIqHZEtv9Yg8/fNbJa8/UDdXSrRJghzccu3JQS8/uxx8Gn00/81AqWNrKIIyz12sfm7pB3OT8I5QrnT8Pt3TM4hSEZDHzXWwtBluJlzP/TYsfzObdDsFLvdjf5QO2QuOAD3ZQhNN5zqUIvk9d+5u09dbTFygp2HP6puuDxsuvO7pFvkLgNwtSNG3978fGqiQBjGqI2xeZZmat93iOpiBZvRFXN0DNLO4nhnddgT2gG6mtQ5QpgHtKZ5IfYXVyBnh4FzbQ8UoIh1IW2pbmrXa6hBSeoiBEvluX33+cdts0MhQ4TWNg3pVSt6lAaqPBXyhNV3+a4IqKgFiXKHyuv8znORU7NGD7phhIGe/m/xJRyYzBN/d6kPDer7+ciROMto/e+XV/mzuR5rINRmq1+m2eOk8WMlAgI7lbmOAp55KChz4wxi5BvMpkd8Q== cardno:000611339240"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3EVc3A55QHe83NXfqrClVohWz2DscDgx0pr4PSlcGO edmund.a.miller@protonmail.com"
    ];
  };
}
