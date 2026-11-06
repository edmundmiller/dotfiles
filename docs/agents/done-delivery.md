---
purpose: Stage the canonical done bundle for hosted Amp User Skills without publishing.
applies_to: Changes to skills/catalog/done and its hosted Amp copy.
entrypoint: mise run skills:amp-stage-done <local-user-skills-clone>.
verification: scripts/check_done_bundle.py and the done-delivery-tests check.
update_when: Amp skill staging or the done bundle contract changes.
---

# Done bundle delivery

`skills/catalog/done` is canonical. Amp's hosted User Skills repository contains
a separate copy. `skills:update`, `skills:sync`, and `skills:bump` manage Nix pins
and host activation. They do not update the hosted copy.

Clone or reuse the User Skills repository listed by `amp skills repositories`.
From the dotfiles checkout, run `mise run skills:amp-stage-done <clone>`.
The argument must be a clone or linked worktree root. The task verifies a
temporary copy of the entire canonical `done` directory, comparing every file
and running the existing done contracts before replacing the target bundle.
Clean tracked resources removed from canonical become deletions in the target.
The task refuses local `done` edits, including ignored content, and checks again
before replacement. It does not commit, push, activate a host, or reload skills.

Do not substitute a SKILL.md-only import. Amp CLI local-path installation has
omitted bundled scripts and references in testing. The parity gate rejects
missing resources and obsolete target files instead of accepting a partial copy.

The gate requires Python 3.11+, Git, and a working `jj`. It exercises Git-only
and unusable-jj fallback with staged, unstaged, and untracked content preserved,
plus the real jj backend and publisher tests. Whole-bundle comparison prevents
staging a fixed detector with a stale publisher or missing resource. Coordinate
concurrent done changes in canonical source before staging.

Review the local skills clone's diff and the gate's SHA-256 manifest. Local
staging is not proof of server distribution. After separately authorized
publication, record the hosted commit and the served bundle revision, then run
`python3 scripts/check_done_bundle.py <served-done-directory>` against a freshly
loaded bundle. Never patch Amp's materialized cache as a source fix.

`tests/test_done_delivery.py` exercises the staging task in a temporary Git
repository and rejects stale, missing, or extra files. That local materialization
does not contact Amp or claim that the server has distributed the bundle.
