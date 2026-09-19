# my_analytics

Single dbt project that transforms the `raw_*` tables loaded by
[`my_ingestion`](https://github.com/lksprado/my_ingestion) into analysis-ready models. In
production, it is run by the Airflow in [`my_orchestrator`](https://github.com/lksprado/my_orchestrator),
through the `dag_dbt_my_analytics` DAG (Cosmos).

> Deploy overview for the four repos (runners, tokens, troubleshooting):
> [`homelab/docs/como_funciona_o_deploy.md`](https://github.com/lksprado/homelab/blob/main/docs/como_funciona_o_deploy.md).

## Dev usage

```bash
uv sync                    # dbt-postgres and sqlfluff
source .venv/bin/activate
pre-commit install         # blocks direct commits to main
dbt deps                   # packages from packages.yml (versions pinned in package-lock.yml)
dbt debug                  # checks the connection
```

The connection comes from `~/.dbt/profiles.yml`, profile `my_analytics`, target `dev` (database
`analytics_dev`). The file lives outside the repo. In prod, Airflow builds the profile from the
`postgres_dw` connection.

```bash
dbt build -s stg_proventos+          # model and everything downstream of it, with tests
dbt build -s models/marts/financas   # a folder
dbt seed -s seed_x --full-refresh
sqlfluff lint models/                # lint with the dbt templater
```

### Where things go

| Layer | Materialization | Prefix |
| --- | --- | --- |
| `staging` | table | `stg_` |
| `intermediate` | view | `int_` |
| `marts` | table | `fct_`, `dim_`, `bridge_` |
| `presentation` | table | no prefix |

## Deploy

**`main` is production.** The project reaches prod Airflow when the PR is merged.

### When opening the PR

There are no GitHub checks. Validate in dev:

- run `dbt build -s <what changed>+` against `analytics_dev`;
- or trigger `dag_dbt_my_analytics` in local Airflow, which reads this directory live.

### When merging

1. Any change outside `.md` and `.github/` makes the `Deploy prod` workflow
   (`.github/workflows/deploy-prod.yml`) notify `my_orchestrator`.
2. The `my_orchestrator` deploy publishes the tip of the three repos to atb:

| What changed | What happens in prod |
| --- | --- |
| model, macro, seed, test, `dbt_project.yml` | rsync only, no restart; the DAG picks up the change within 1 min |
| `packages.yml` + `package-lock.yml` | rsync + automatic `dbt deps` on the scheduler, no restart |

1. The run shows up in [my_orchestrator → Actions](https://github.com/lksprado/my_orchestrator/actions).

**New dbt package:**

1. Edit `packages.yml`.
2. Run `dbt deps` locally to update `package-lock.yml`.
3. Commit both.

The deploy only runs `dbt deps` when the **lock** changes.

Merging does not run dbt. Prod tables only change on the next run of
`dag_dbt_my_analytics`, either on schedule or via a manual trigger in the prod UI.
