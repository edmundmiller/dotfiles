# Eval-time config validation for HA custom components using JSON schemas.
#
# Reads JSON schemas from ./schemas/ and generates NixOS assertions that
# reject invalid config keys before the build even starts. This catches
# the class of error where agents hallucinate plausible-but-nonexistent
# options (e.g. force_rgb_color) that sail through freeform attrsets and
# only explode at HA runtime.
#
# Usage: import this file from the main hass module. Add schemas to
# ./schemas/<domain>.json with the structure:
#   { "properties": { "<domain>": { "items": { "properties": { ... } } } } }
#
{ config, lib, ... }:
let
  cfg = config.services.home-assistant.config;

  # Read a JSON schema and extract valid property names for a domain
  schemaFor =
    domain: schemaFile:
    let
      schema = builtins.fromJSON (builtins.readFile schemaFile);
      domainSchema = schema.properties.${domain}.items.properties;
      validKeys = builtins.attrNames domainSchema;
    in
    validKeys;

  # Generate assertions for a list-of-attrsets config section (e.g. adaptive_lighting)
  validateDomain =
    domain: schemaFile:
    let
      validKeys = schemaFor domain schemaFile;
      entries = cfg.${domain} or [ ];
    in
    lib.imap0 (
      i: entry:
      let
        entryKeys = builtins.attrNames entry;
        invalidKeys = builtins.filter (k: !(builtins.elem k validKeys)) entryKeys;
        name = entry.name or "entry ${toString i}";
      in
      {
        assertion = invalidKeys == [ ];
        message = builtins.concatStringsSep "\n" [
          "services.home-assistant.config.${domain}[${toString i}] (${name}): invalid key(s): ${builtins.concatStringsSep ", " invalidKeys}"
          "  Valid keys: ${builtins.concatStringsSep ", " validKeys}"
        ];
      }
    ) entries;

  # -- Schema registry --
  # Add new schemas here as they're generated from custom component source.
  schemas = {
    adaptive_lighting = ./schemas/adaptive-lighting.json;
  };

in
{
  assertions = lib.concatLists (lib.mapAttrsToList validateDomain schemas);
}
