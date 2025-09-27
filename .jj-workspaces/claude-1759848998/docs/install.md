https://nixos.org/manual/nixos/stable/#sec-booting-from-usb-linux

```bash
wget https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso
diskutil unmountDisk diskX
sudo dd if=<path-to-image> of=/dev/rdiskX bs=4m
```
