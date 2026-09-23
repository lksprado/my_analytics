# CLAUDE.md

Guidance for Claude Code in this repo.

## Project Overview

Personal multi-domain data warehouse in dbt on PostgreSQL.

## Common Commands

```bash
dbt debug
dbt run
dbt run -s
dbt build
dbt build -s
dbt test
dbt seed --full-refresh
dbt deps
sqfluff fix
```

## Comments

In Brazilian Portuguese. Comment only a non-obvious *why* (business rule, performance workaround) in one line.
Never narrate what the SQL does, never put profiling numbers, row counts or refactor history in code.

## Architecture

### Layers

| Layer | Materialization | Schema | Prefix | Purpose |
| ------- | ---------------- | -------- | -------- | --------- |
| Staging | `table` | `staging_<subpasta>` | `stg_` | Type-cast raw sources (JSON, Sheets, seeds) |
| Intermediate | `view` | `intermediate_<subpasta>` | `int_` | Business logic |
| Marts | `table` | `marts_<subpasta>` | `fct_*` `dim_*` `bridge_*_*` | Dimension Modeling |
| Presentation | `table` | `presentation_<subpasta>` | none | Visualization-ready |

### Audit column

Every model must contain `model_run_at` as last column to mark the moment it runs:

```sql
'{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
```

Except `ephemeral` models and `enabled=false`. Beware to avoid column duplication error and `UNION`
with `dummy_row()`, add `['model_run_at', "'" ~ run_started_at ~ "'::TIMESTAMPTZ"]` to avoid different timestamps.

### Schema/YAML files

Naming convention is `_schema.yml` (leading underscore). Descriptions are succinct:

- Column: what the value **means**, one short sentence; add domain/unit when useful
  (`"Casa legislativa (CAMARA, SENADO)."`). No calculation logic, joins, source lineage, counts, coverage
  percentages or history.
- Model: grain and purpose in at most two sentences.
- Repeated columns use the same text in every model (`model_run_at: "Início do dbt run que materializou o modelo."`).
- No code in descriptions. Profiling and validation evidence go in the commit message or PR, not in YAML.

## Dependencies

- `dbt-core ^1.10.0`, `dbt-postgres ^1.10.0`
- `dbt-labs/dbt_utils 1.3.3` — `unique_combination_of_columns`, `pivot`, `get_column_values`
- `calogica/dbt_date` — `get_date_dimension` behind `int_dates`
- `sqlfluff ^3.5.0`

## Commit patterns

- `feat:` Adds a new feature or functionality.
- `fix:` Fixes a bug or issue.
- `docs:` Changes documentation only, such as the repository README. No code changes.
- `test:` Adds, modifies, or removes tests. No production code changes.
- `build:` Changes build configuration or dependencies.
- `refactor:` Restructures existing code without changing its functionality.
- `chore:` Makes maintenance changes such as formatting, linting, semicolons, trailing spaces, or `.gitignore` updates.
- `remove:` Removes obsolete or unused files, directories, features, or other source-code
 elements to reduce complexity and keep the project organized.

## Linting

The project contains `sqlfluff` but it might not parse it correctly, so fix it to allign lines for human readability.
