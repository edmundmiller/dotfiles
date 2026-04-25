# hermes-dcp

DCP-style context engine plugin for Hermes Agent.

This package provides a pluggable `ContextEngine` implementation (`dcp`) focused on:

- dynamic pruning of stale tool outputs
- duplicate tool-call output pruning
- old error-input purging
- optional manual tool helpers for context analysis/pruning

## Status

Initial scaffold (v0.1.0). This is a starting point for Pi/OpenCode-style DCP behavior in Hermes.
