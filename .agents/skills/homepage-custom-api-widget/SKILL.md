---
name: homepage-custom-api-widget
description: This skill should be used when the user asks to "configure a Homepage customapi widget", "map API fields in Homepage", "use dynamic-list in Homepage", or mentions Homepage Custom API widget mappings.
version: 0.1.0
---

# Homepage Custom API Widget

Use this skill to configure Homepage `customapi` widgets from an existing API response. Keep the process narrow: inspect the response shape, map fields once, and validate the YAML you change.

## Core workflow

1. Identify the response shape.
   Capture whether the API returns an object, a root array, or an object containing an array. Treat that shape as the contract that drives the widget config.

2. Choose the display mode.
   Use `block` for scalar fields, `list` for paired rows, and `dynamic-list` for arrays of items.
   - `block` and `list` use `mappings` as an array of mapping objects.
   - `dynamic-list` uses `mappings` as a single object with `items`, `name`, `label`, and optional `limit`, `format`, and `target`.

3. Map fields exactly once.
   Use dot notation for nested object paths. Use array indexes only when the response is stable and the target is intentionally positional. Prefer the root-array form only when the API actually returns an array at the root.

4. Keep transformations local.
   Apply `format`, `remap`, `scale`, `prefix`, `suffix`, and date options on the mapping that needs them. Avoid helper data or extra widget layers when one mapping can express the value.

5. Handle auth and request shape explicitly.
   Set `username`, `password`, `headers`, `method`, and `requestBody` only when the API requires them. Keep secrets in environment variables or secret files; never hard-code tokens into the widget config.

6. Verify the rendered contract.
   Re-read the widget YAML after editing and confirm each mapping still points at a real field in the observed response. If the field shape changes, update the mapping before finishing.

## Mapping rules

- Use `field` for the source path.
- Use `label` for the display name.
- Use `format` only when the rendered type should change.
- Use `additionalField` only in `display: list`.
- Reserve `items`, `name`, `limit`, and `target` for `display: dynamic-list`.
- For arrays at the root, omit `items` and map the root directly.
- For `date` and `relativeDate`, set locale and style only when presentation matters.

## Common shapes

- Single object response: map scalar fields with `display: block`.
- Nested object response: use dot paths such as `origin.name`.
- Array response: use `display: dynamic-list` and bind `name`/`label` to item fields.
- Aggregate count: use `format: size` on an array, string, or object when the count is what matters.

## Good defaults

- Prefer the simplest display mode that fits the response.
- Prefer stable field paths over computed structure.
- Prefer explicit labels that match the dashboard vocabulary.
- Prefer environment-backed secrets over inline values.

## Additional resources

- Upstream widget reference: `https://gethomepage.dev/widgets/services/customapi/`
- Rebuild and inspect the live Homepage config after editing the source file that generates it.
