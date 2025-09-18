#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Do task
# @raycast.mode compact

# Optional parameters:
# @raycast.icon ./todotxt_logo_2012.png
# @raycast.argument1 { "type": "text", "placeholder": "task id", "percentEncoded": false }
# @raycast.packageName Todo 

# Documentation:
# @raycast.description Mark task with taskId done
# @raycast.author Martin Stemplinger

todo.sh done "$1"