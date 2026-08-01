---
name: ggsql
description: Writes, modifies, explains, validates, and runs ggsql grammar-of-graphics visualization queries.
license: MIT
metadata:
  author: George Stagg (@georgestagg)
  upstream: https://github.com/posit-dev/skills/blob/main/ggsql/ggsql/SKILL.md
---

# ggsql Query Writer

Write valid ggsql visualization queries from natural-language requests. ggsql combines SQL data shaping with a declarative grammar of graphics.

## Use this skill when

- Creating or modifying a ggsql query.
- Converting a chart request into ggsql.
- Explaining, validating, or running ggsql.
- Choosing ggsql layers, mappings, scales, facets, projections, or labels.

Do not trigger for ordinary SQL work that has no visualization component.

## Required reference

Read [references/syntax.md](references/syntax.md) before writing or changing a query. It is the complete upstream language reference and defines the allowed clauses, aesthetics, layers, settings, palettes, and CLI commands.

Never invent ggsql syntax. If the reference does not document a requested feature, say so and offer the closest documented form.

## Workflow

1. Identify the data source, columns, desired visual encodings, grouping, and output.
2. Shape data with SQL or CTEs before `VISUALISE` when necessary.
3. Choose the simplest documented `DRAW` layer and mappings.
4. Add `SCALE`, `FACET`, `PROJECT`, or `LABEL` only when the request needs them.
5. If `ggsql` is available, validate with `ggsql validate`. Render with `ggsql exec ... -v` only when output is requested.
6. Return the complete query, then briefly explain consequential choices.

## Minimal pattern

```ggsql
SELECT category, SUM(value) AS total
FROM 'data.parquet'
GROUP BY category
VISUALISE category AS x, total AS y
DRAW bar
LABEL
  title => 'Total by category',
  x => 'Category',
  y => 'Total'
```

Alternatively, let `VISUALISE` name the source:

```ggsql
VISUALISE bill_len AS x, bill_dep AS y, species AS color
FROM ggsql:penguins
DRAW point
```

## Guardrails

- Use only documented clauses, settings, aesthetics, layers, transforms, and palettes.
- Preserve the user's source names and column names.
- Prefer `ggsql:penguins` or `ggsql:airquality` only when example data is needed.
- Do not claim validation or rendering unless the command actually ran.
- Keep SQL portable unless the selected backend requires a documented dialect feature.
