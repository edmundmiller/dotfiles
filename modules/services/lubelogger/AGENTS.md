# LubeLogger

Wraps upstream `services.lubelogger`. Agenix `lubelogger-env.age` must be owned
by `lubelogger`, not `emiller`. Credentials are referenced by `Private/LubeLogger`
in 1Password; `LUBELOGGER_ALLOWED_USERS` is colon-separated `username:password`.

The module overrides upstream Kestrel localhost binding to `0.0.0.0` for
Tailscale access. Dashboard credentials use `HOMEPAGE_VAR_LUBELOGGER_*` in
`homepage-env.age`. Service registry entries own monitoring/dashboard integration;
`hollowpnt92/lubelogger-ha` provides optional HACS vehicle sensors.
