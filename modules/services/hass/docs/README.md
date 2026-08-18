---
purpose: Index operational and research guidance for the Nix-managed Home Assistant module.
applies_to: Work under modules/services/hass that needs context beyond inline Nix comments.
entrypoint: Select the narrowest topic below before inspecting implementation files.
verification: Follow the verification instructions in the selected topic.
update_when: A canonical Home Assistant guide is added, renamed, or removed.
---

# Home Assistant docs

This directory keeps operational notes for the Nix-managed Home Assistant setup on the NUC.

Home Assistant is the automation source of truth. Apple Home/HomePods, Matter devices, and other frontends should call into HA routines when the behavior is more than a direct device toggle.

## Topics

- [HomeKit Bridge and Siri routine wrappers](./homekit-bridge.md)
- [Public Nix configuration patterns and GitHub searches](./public-config-patterns.md)
