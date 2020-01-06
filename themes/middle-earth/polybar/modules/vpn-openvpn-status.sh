#!/bin/sh

printf "VPN: " && (pgrep -a openvpn$ | head -n 1 | awk '{print $NF}' | cut -d '-' -f 4-5 && echo down) | head -n 1
