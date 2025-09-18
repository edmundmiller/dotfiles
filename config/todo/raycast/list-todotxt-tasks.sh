#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title List tasks
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon ./todotxt_logo_2012.png
# @raycast.argument1 { "type": "text", "placeholder": "Project", "percentEncoded": false }
# @raycast.packageName Todo 

# Documentation:
# @raycast.description List all tasks 
# @raycast.author Martin Stemplinger

todo.sh ls "+$1"