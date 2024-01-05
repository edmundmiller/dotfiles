{
  atuin,
  fetchpatch,
}:
atuin.overrideAttrs (_old: {
  # as cursed as doing mitigations=off in the kernel command line
  patches = [
    (fetchpatch
      {
        url = "https://github.com/Mic92/dotfiles/raw/main/home-manager/pkgs/atuin/0001-make-atuin-on-zfs-fast-again.patch";
        hash = "sha256-2hN3n9d3ClgIcccb3mxPElOjJ9OrvRAhKitTl2lVgMM=";
      })
  ];
})
