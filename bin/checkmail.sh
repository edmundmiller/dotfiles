#!/usr/bin/env bash

STATE=$(nmcli networking connectivity)

if [ $STATE = 'full' ]; then
	msmtp-runqueue.sh
	mbsync -a
	exit 0
fi
echo "No internet connection."
exit 0
