# Approved SSH login keys, not the separate agenix recipient/host-key inventory.
{
  ownerKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBsb81evtCCcWSZcLbFaXWrAeCWFrPXPjUvjH4ZKbQC edmundmiller"
    "no-touch-required sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDvVosAjBisOM6GMdSjkxDUQpaf0LX8bmT+T/c7NX2AdAAAACnNzaDpnaXRodWI= edmundmiller"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFr8iZah3mwOy5QmDA/loQYBRspXooF2Fqaoq9kTAfuX edmuna.a.miller@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK3EVc3A55QHe83NXfqrClVohWz2DscDgx0pr4PSlcGO edmund.a.miller@protonmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILKq5Pgw1Cj7sKCo13FuFBBKNvSNJvlN3ZObhF/EjGT0 iphone-moshi"
  ];

  # Existing UNAS machine authorizations retain their original restrictions.
  unasMachineKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJ64slBBRJVfH38s9zN6mlphbj/R0rrOfm91vgZEzkh blip@meshify"
    ''from="192.168.1.222,100.112.179.64",no-agent-forwarding,no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB6NdOGUlSTcYb9lB7CGx98mAZwvgATLNoRpB69CwE/F nuc-emiller''
  ];
}
