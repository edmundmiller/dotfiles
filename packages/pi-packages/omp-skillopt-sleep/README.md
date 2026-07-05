# pi-skillopt-sleep

OMP extension package for Microsoft SkillOpt-Sleep.

It ships:

- `extensions/skillopt-sleep.ts` — registers the `skillopt_sleep_omp` tool and `/skillopt-sleep` command.
- `skills/skillopt-sleep-omp/SKILL.md` — on-demand playbook bundled with the extension.
- `scripts/skillopt-sleep-omp.py` — mirrors OMP JSONL sessions into a Claude-compatible SkillOpt-Sleep home, then delegates to `python -m skillopt_sleep`.

The package follows OMP extension authoring conventions: `package.json` uses `omp.extensions`, while conventional `skills/` content is discovered from the package when linked.
