# Language toolchains

Toolchains are enabled per host with `modules.dev.<language>.enable`. Some also
offer `enableGlobally` for PATH-level installation; keep project-local versus
system-wide ownership explicit in the owning module.

Run `hey check modules/dev` and the target platform check for package or option
changes. A tool's presence in the current shell does not prove the host module
installs it.
