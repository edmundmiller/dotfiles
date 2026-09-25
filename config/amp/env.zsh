# The Amp Mac app discovers its mutable CLI through the login shell's PATH.
typeset -U path PATH
path=("$HOME/.amp/bin" $path)
