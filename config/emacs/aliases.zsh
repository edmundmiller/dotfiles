alias e='emacsclient -n'

ediff() { e --eval "(ediff-files \"$1\" \"$2\")"; }
