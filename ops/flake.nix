{
  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.terranix.url = "github:terranix/terranix";
  outputs = {
    self,
    nixpkgs,
    terranix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    terraform = pkgs.terraform;
    terraformConfiguration = terranix.lib.terranixConfiguration {
      inherit system;
      modules = [./config.nix];
    };
  in {
    # nix run ".#apply"
    apps.${system} = {
      apply = {
        type = "app";
        program = toString (pkgs.writers.writeBash "apply" ''
          if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
          cp ${terraformConfiguration} config.tf.json \
            && ${terraform}/bin/terraform init \
            && ${terraform}/bin/terraform apply
        '');
      };
      # nix run ".#destroy"
      destroy = {
        type = "app";
        program = toString (pkgs.writers.writeBash "destroy" ''
          if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
          cp ${terraformConfiguration} config.tf.json \
            && ${terraform}/bin/terraform init \
            && ${terraform}/bin/terraform destroy
        '');
      };
    };
    # nix run
    defaultApp.${system} = self.apps.${system}.apply;
  };
}
