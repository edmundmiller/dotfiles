# Command policy contracts

Cover denied raw rebuilds and `git commit --no-verify`, allowed `hey re`, and
command extraction from extension tools as well as direct bash calls. These
are enforcement seams for `config/pi/pi-permission-system.jsonc`, not just
string-matching examples.

Run `hey check` on `packages/pi-packages/pi-command-policy-bridge` for the owning
package test. Every allowed case needs a nearby denied case that differs at the
policy boundary.
