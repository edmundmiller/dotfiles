USER := emiller
HOST := meshify

NIXOS_VERSION := 20.03
NIXOS_PREFIX  := $(PREFIX)/etc/nixos
COMMAND       := test
FLAGS         := -I "config=$$(pwd)/config" \
				 -I "modules=$$(pwd)/modules" \
				 -I "bin=$$(pwd)/bin" \
				 $(FLAGS)

# The real Labowski
all: channels
	@sudo nixos-rebuild $(FLAGS) $(COMMAND)

install: channels update config
	@sudo nixos-install --root "$(PREFIX)" $(FLAGS)

upgrade: update switch

update:
	@sudo nix-channel --update

switch:
	@sudo nixos-rebuild $(FLAGS) switch

boot:
	@sudo nixos-rebuild $(FLAGS) boot

rollback:
	@sudo nixos-rebuild $(FLAGS) --rollback $(COMMAND)

dry:
	@sudo nixos-rebuild $(FLAGS) dry-build

gc:
	@nix-collect-garbage -d

clean:
	@rm -f result


# Parts
config: $(NIXOS_PREFIX)/configuration.nix

channels:
	@sudo nix-channel --add "https://nixos.org/channels/nixos-${NIXOS_VERSION}" nixos
	@sudo nix-channel --add "https://github.com/rycee/home-manager/archive/release-${NIXOS_VERSION}.tar.gz" home-manager
	@sudo nix-channel --add "https://nixos.org/channels/nixpkgs-unstable" nixpkgs-unstable

$(NIXOS_PREFIX)/configuration.nix:
	@sudo nixos-generate-config --root "$(PREFIX)"
	@echo "import /etc/dotfiles \"$${HOST:-$$(hostname)}\" \"$$USER\"" | sudo tee "$(NIXOS_PREFIX)/configuration.nix"
	@[ -f machines/$(HOST).nix ] || echo "WARNING: hosts/$(HOST)/default.nix does not exist"



# Convenience aliases
i: install
s: switch
up: upgrade


.PHONY: config
