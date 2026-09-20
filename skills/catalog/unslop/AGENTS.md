# Unslop provenance

This skill vendors Cursor pstack unslop. The numbered rules stay verbatim
from the pin. Local text lives only in frontmatter metadata and the
`This checkout` section.

Source:
https://github.com/cursor/plugins/blob/e8d856f0273b42ebafe0ec3546bd645709e7c1b0/pstack/skills/unslop/SKILL.md

Pin: `e8d856f0273b42ebafe0ec3546bd645709e7c1b0`

Refresh:

1. Copy `pstack/skills/unslop/SKILL.md` from that commit or a newer one.
2. Restore `metadata.source`, `metadata.pin`, and `metadata.tweet`.
3. Keep the `This checkout` section.
4. Point `metadata.pin` and the source URL at the new commit.
5. Run `python3 skills/catalog/skill-quality/scripts/validate.py skills/catalog/unslop`.
