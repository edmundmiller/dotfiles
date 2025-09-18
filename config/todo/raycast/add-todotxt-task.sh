#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Add Todotxt task
# @raycast.mode compact

# Optional parameters:
# @raycast.icon ./todotxt_logo_2012.png
# @raycast.argument1 { "type": "text", "placeholder": "task", "percentEncoded": false }
# @raycast.argument2 { "type": "text", "placeholder": "project", "percentEncoded": false }
# @raycast.argument3 { "type": "text", "placeholder": "context", "percentEncoded": false }
# @raycast.packageName Todo 

# Documentation:
# @raycast.description Add a task to my Todotxt file
# @raycast.author Martin Stemplinger

todo.sh add "$1 +$2 @$3"

