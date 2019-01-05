#!/usr/bin/env bash

STATE=$(nmcli networking connectivity)

if [ $STATE = 'full' ]; then
	~/.dotfiles/bin/msmtp-runqueue.sh
	mbsync -Vanf
	notmuch new
	exit 0
fi
echo "No internet connection."
exit 0
