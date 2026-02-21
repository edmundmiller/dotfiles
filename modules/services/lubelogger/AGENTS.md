# LubeLogger Module

Vehicle maintenance & fuel mileage tracker. Wraps upstream `services.lubelogger`.

## Files

- `default.nix` — Module definition
- `hosts/nuc/secrets/lubelogger-env.age` — `LUBELOGGER_ALLOWED_USERS=user:pass`
- `hosts/nuc/secrets/homepage-env.age` — Contains `HOMEPAGE_VAR_LUBELOGGER_USERNAME/PASSWORD`

## Credentials

- **1Password:** `Private/LubeLogger` (login item)
- **Agenix:** `lubelogger-env.age` (owner: `lubelogger`, not `emiller`)

## Gotchas

- **Kestrel binds localhost by default.** Upstream module sets `Kestrel__Endpoints__Http__Url` to `http://localhost:<port>`. We `mkForce` override to `0.0.0.0` for Tailscale access.
- **Service user is `lubelogger`**, not `emiller`. Agenix secret owner must match or the service can't read its env file.
- **Auth format:** `LUBELOGGER_ALLOWED_USERS=username:password` (colon-separated, one pair per line)

## Integrations

- **Gatus:** Conditional endpoint in `modules/services/gatus/`, group "Home"
- **Homepage:** Widget in `modules/services/homepage.nix`, needs `HOMEPAGE_VAR_LUBELOGGER_*` in env
- **Home Assistant (HACS):** `hollowpnt92/lubelogger-ha` — per-vehicle sensors
