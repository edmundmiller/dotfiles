#!/usr/bin/env python3
"""Pass one identity-checked capture handle, never a reusable ALSA device node."""

from array import array
import os
from pathlib import Path
import re
import socket
import stat
import sys


def capture_name(sysfs, major, minor):
    """Verify PCM direction, device number, USB product and approved physical port."""
    pcm = (sysfs / "dev/char" / f"{major}:{minor}").resolve(strict=True)
    usb = sysfs / "devices/pci0000:00/0000:00:14.0/usb1/1-4"
    if (major != 116 or not re.fullmatch(r"pcmC[0-9]+D0c", pcm.name)
            or usb not in pcm.parents
            or (pcm / "dev").read_text().strip() != f"{major}:{minor}"
            or (usb / "idVendor").read_text().strip() != "2ca3"
            or (usb / "idProduct").read_text().strip() != "4011"):
        raise ValueError("Unapproved capture identity")
    return pcm.name


def open_capture(sysfs=Path("/sys"), devices=Path("/dev/snd")):
    candidates = []
    for pcm in (sysfs / "class/sound").glob("pcmC*D0c"):
        try:
            major, minor = map(int, (pcm / "dev").read_text().strip().split(":"))
            name = capture_name(sysfs, major, minor)
            candidates.append((name, major, minor))
        except (OSError, ValueError):
            continue
    if len(candidates) != 1:
        raise ValueError("Expected exactly one approved capture endpoint")
    name, major, minor = candidates[0]
    metadata = (sysfs / "dev/char" / f"{major}:{minor}").resolve(strict=True)
    # Hold the sysfs inode across open; a removal/replacement must not look like
    # the original device just because the kernel reused its path/device number.
    pinned = os.open(metadata, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        if capture_name(sysfs, major, minor) != name:
            raise ValueError("Capture identity changed")
        fd = os.open(devices / name, os.O_RDWR | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            info = os.fstat(fd)
            if (not stat.S_ISCHR(info.st_mode) or info.st_rdev != os.makedev(major, minor)
                    or not os.path.samestat(os.fstat(pinned), metadata.stat())
                    or capture_name(sysfs, major, minor) != name):
                raise ValueError("Capture identity changed during open")
            return fd
        except BaseException:
            os.close(fd)
            raise
    finally:
        os.close(pinned)


def serve(connection):
    # Fixed request, no caller-selected path, card, mixer, command or format.
    request = b"NOTE4C_DJI_CAPTURE_FD_V1\n"
    connection.settimeout(2)
    received = b""
    while len(received) < len(request) and not received.endswith(b"\n"):
        part = connection.recv(len(request) - len(received))
        if not part:
            break
        received += part
    if received != request:
        connection.sendall(b"ERROR request\n")
        return
    fd = open_capture()
    try:
        # The receiver owns this open file description, not a future lookup by
        # major/minor. Unplug fails the handle; it cannot retarget another card.
        connection.sendmsg([b"OK capture-fd-v1\n"],
            [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array("i", [fd]))])
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        with socket.socket(fileno=0) as connection:
            serve(connection)
    except (OSError, ValueError, KeyError):
        print("amp-orbs: DJI capture handle request failed", file=sys.stderr)
        sys.exit(1)
