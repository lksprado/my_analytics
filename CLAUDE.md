# CLAUDE.md

Guidance for Claude Code in this repo.

## Project Overview

Personal multi-domain data warehouse in **dbt on PostgreSQL** (never Snowflake/BigQuery syntax). Runs as a Git submodule inside an Airflow environment orchestrated via Astro Cosmos.

## Common Commands

```bash
dbt debug                       # validate connection
dbt run                         # run all models
dbt run --select carteira       # single model
dbt run --selector energia      # domain selector (energia | livros | inflation)
dbt run --select tag:financas   # domain by tag (financas | datas — no selector exists)
dbt run --select carteira+      # model + downstream dependents
dbt test / dbt test --select carteira
dbt seed                        # required before most finanças models
dbt docs generate && dbt docs serve
dbt deps
```

## Comments in SQL

Comment only if it says something the code can't. Never write: model/grain/column docs (→ `_schema.yml`), history (`antes era…` — that's git's job), labels that repeat the next line, section banners, file paths, or commented-out code.

## Architecture

### Layers

| Layer | Materialization | Schema | Prefix | Purpose |
|-------|----------------|--------|--------|---------|
| Staging | `table` | `staging_<subpasta>` | `stg_` | Type-cast raw sources (JSON, Sheets, seeds); indexes via `post_hook` |
| Intermediate | `view` | `intermediate_<subpasta>` | `int_` (`int_dim_`/`int_fct_` in NHL) | Business logic, Kimball dims/facts |
| Marts | `table` | `marts_<subpasta>` | none (`mrt_` in energy) | Analytics-ready |

`macros/generate_schema_name.sql` derives schema from path (`<camada>_<primeira subpasta>`); `+schema` config is ignored, so moving a file between folders moves its table between schemas. Seeds always go to `seeds`. Code outside dbt (e.g. `.claude/skills/*/queries/`) must use the full schema name. Every mart is `+materialized: table`; nothing uses Postgres `MATERIALIZED VIEW` except NHL parameter views.

### Domains

Each lives under `models/staging/<domain>/`, with `intermediate/`/`marts/` where it has downstream logic.

**Finanças** — the only domain with a semantic dictionary, feeding `models/{intermediate,marts}/financas/` from: **google** (Sheets: contas, consolidado, patrimônio, luz, ajuste, classificação), **b3** (ações, BDR, ETF, fundos, renda fixa, tesouro, proventos), **avenue** (assets/dividendos exterior), **seeds_sources** (câmbio USD, de-para FGC, investimentos faltantes, datas especiais).

Other domains:
- **inflation** — Atacadão + Minha Inflação scrapers
- **livros** — Vide Editorial price history
- **solar + weather** — IoT solar generation + OpenWeather → mart `energy`, selector `energia`
- **conformado** — `int_dates`, conformed calendar **1900-01-01 → 2100-12-31**, pt-BR, ANBIMA/B3 holidays, `fl_dia_util`/`dia_util_mes`. Feeds `dim_datas` (`marts_conformado`, + family special dates) and `dim_dates` (`marts_demodados`, votações only — never expose family dates there). Spine is deliberately wide: every consumer `INNER JOIN`s in, so a short spine silently drops rows (once dropped set–dez/2019 of Deusa's patrimônio; votações go back to 1991). `dbt_date.get_date_dimension`'s end date is **exclusive** — pass the day *after* the last one wanted.
- **nhl** — **disabled** (`+enabled: false` for staging/intermediate); code kept in repo, excluded from `dbt run`.

### Finanças — read before touching

`models/marts/financas/_docs_financas.md` is the single source of truth for categories, investment layers and policy (targets, reserve, FGC limits). Its numeric parameters are duplicated in `scripts/relatorios/politica.py` (`ALVOS_CAMADA`, `APORTE_ALVO`, `META_RESERVA_*`, `META_POUPANCA_PCT`, `TEXTO_CATEGORIA`, `TEXTO_CAMADA`) because the report builders can't read Markdown — **edit both together** (they diverged once, producing a PDF that contradicted policy). Exactly one Python copy, shared by both report skills.

### Two reports, two cadences

Nothing scheduled — both are on-demand only.

| | `relatorio-financas` | `relatorio-meio-mes` |
|---|---|---|
| Runs | days 1–5 | days 15–20 |
| Reference | previous, closed month | current month + prior-month benchmark |
| Output | 4 PDFs (per titular + couple's budget) | 2 PDFs (couple's + Deusa's) |
| Parameter | month `AAAA-MM` | date `AAAA-MM-DD` (reproducible) |
| Gates | `pronto_orcamento`, `pronto_investimentos` | `pronto_ritmo` (day ≥10, fresh entries), `pronto_indicadores` (prior IPCA filled) |
| Batch | `scripts/gerar_relatorios_financas.sh` | `scripts/gerar_relatorio_meio_mes.sh` |

Key rules:
- `relatorio-financas` resolves its month from the `date` param — never `MAX(mes)`, never current month.
- `relatorio-meio-mes` compares against min–max/median of the six closed months on the **same `dia_fatura`** (never `dia_mes`); projection = `realizado + GREATEST(median of what falls after the cut over 6 months, what's already booked with a future date)` — biased high by design, and the per-category column does **not** sum to the total (median of a sum ≠ sum of medians). Both facts must appear in the PDF, never reconciled away.
- Benchmark section lives only in meio-mês, because `riqueza` `INNER JOIN`s indexadores (absent on day 1 → series would silently shrink by a month). Mart `indicadores` keeps the `NULL` row instead, which is what `pronto_indicadores` reads.
- Covers two independent, never-summed patrimônios: couple's (`patrimonio_mom`) and Deusa's (`patrimonio_deusa`, total líquido only — she has no per-account level, so she's excluded from `patrimonio` and from `COM_PATRIMONIO` in `politica.py`). `riqueza` **includes contributions** (not a pure return), series don't share a base (couple's from 2023-11, Deusa's from her sheet's first variation, indexadores pre-computed — the montador reindexes to the first displayed month), and there's no despesa for Deusa in the warehouse (can't attribute a drop to withdrawal vs. market loss).
- Deusa gets her own PDF (`--escopo deusa`, same montador/JSON/blocks, own capa/narrative/rodapé) with **no ritmo gate** (whole-previous-month only) — gated instead by its own `pronto_deusa` (does `carteira_deusa` have the prior month?). Her section deliberately mixes layers (level/composition from `carteira_deusa`, index from `riqueza`) and **prints the reconciliation gap** between the two totals rather than picking one. It stays position-only (no camada/FGC/vencimento — that's the closing report). Two known cadastro traps to surface, not smooth: `SEM INDEXADOR` renda fixa with a contracted rate and empty field, and the disponível/investido boundary (the `DISPONIBILIDADE` class).

### Shared rendering layer

`scripts/relatorios/` — imported by both skills: `politica` (params), `formato` (pt-BR money/%/date), `calculo` (media/mediana/variação), `graficos` (hand-written inline SVG, no chart lib), `blocos` (KPI/table/section/glossary HTML), `saida` (writes report), `relatorio.css`. Capa/rodapé/gates/section order stay per-skill. **Touching this package changes both PDFs — check both.** Montadores bootstrap via `sys.path.insert(0, parents[4] / "scripts")`.

`--saida` dispatches on extension: `.pdf` renders to a tempdir, drives `html_para_pdf.sh` (needs `file://`), discards the intermediate — delivery dir only ever gets PDFs. `.html` writes markup and stops (debug only). Never call `html_para_pdf.sh` directly, never write `.html` into `relatorios/`. On conversion failure the intermediate is kept and its path printed to stderr.

### Key patterns

- **Dinheiro é inteiro:** every monetary mart column is `integer`/`bigint`, cast once at the convergence point (`int_renda_fixa_incompleta` for renda fixa; the `SUM` inside `consumo` for daily spend) — never per branch. `::INT` rounds, doesn't truncate. Staging keeps `NUMERIC(18,2)` so cents survive until then. Never `double precision` for money (`stg_acoes`/`stg_bdr`/`stg_etf`/`stg_fundos`/`stg_proventos` now cast explicitly). Decimal stays for non-money: variations/indices (`patrimonio_mom`, `riqueza`, `indicadores`, `NUMERIC(18,3)`) and `luz` (kWh, price/kWh). `SUM()` over `integer` returns `bigint`, over `bigint` returns `NUMERIC` — `carteira_auditoria` casts both sides. `dbt_date`'s `day_of_month`/`day_of_year` are `double precision`; `int_dates` casts to `integer`.
- **JSON at staging:** sources with `payload jsonb` are cast explicitly per field in staging (`(payload ->> 'id')::int`); never reference raw `payload` downstream. Sheets/seed sources are text, cleaned via `clean_string`/`clean_integer`.
- **De-para de instituições:** `macros/normaliza_instituicao.sql` is the single mapping source, used by `int_renda_variavel`, `int_renda_fixa_incompleta`, `int_renda_fixa_loop`, `int_dividendos`. New spelling → add a row to the macro's `de_para` dict (previously copy-pasted across 3 models and diverged). Fallback `'DESCONHECIDO'` is the detector: a `desconhecido` column with balance in `carteira_agregada` means an unmapped variant.
- **Ephemeral base models:** shared parsing helpers for sibling staging tables — `stg_base_*` (NHL), `bases/` subfolder (inflation).
- **Classificação de camada — no history:** `camada` is hand-classified in a spreadsheet, read via `stg_carteira_classificacao`; `carteira` mart resolves it with `LEFT JOIN` on `pessoa + codigo_ativo + instituicao` (institution matters — `BRSTNCLTN806`/Deusa is at two banks). Unclassified → `'NAO CLASSIFICADO'`. Used to be an SCD2 as-of join (`LEFT JOIN LATERAL`, `mes_base <=` position month); the sheet lost its `mes_base` column, so there's no vigência anymore — reclassifying an asset now rewrites its whole history.
- **Parameter views:** `models/staging/nhl/parameters/vw_stg_request_*.sql` are `materialized_view` helpers the Airflow extraction layer reads to pick next records — intentionally on a different (`vw_`) convention.
- **Incremental:** `stg_all_play_by_play`, `stg_all_games_details` use `delete+insert` with composite unique keys. Postgres date arithmetic only (`- interval '3 days'`), never `dateadd()`.
- **Index post-hooks:** `CREATE INDEX IF NOT EXISTS` on high-cardinality join keys (`game_id`, `event_id`, `game_date`).
- **Selectors:** `selectors.yml` covers `energia`/`livros`/`inflation` by path. Finanças/conformado have no selector — use `--select tag:financas` / `tag:datas`.

### Schema/YAML files

- `models/staging/_sources.yml` — all 36 raw sources
- `models/{staging,intermediate,marts}/<domain>/_schema.yml` — per-domain docs/tests
- `models/marts/financas/_docs_financas.md` — shared `{% docs %}` blocks

Naming convention is `_schema.yml` (leading underscore); `intermediate/financas`, `intermediate/livros`, `intermediate/nhl`, `marts/energy`, `marts/inflation`, `marts/livros` still use `schema.yml` — rename on next touch (dbt doesn't care about the filename).

## Dependencies

- `dbt-core ^1.10.0`, `dbt-postgres ^1.10.0`
- `dbt-labs/dbt_utils 1.3.3` — `unique_combination_of_columns`, `pivot`, `get_column_values`
- `calogica/dbt_date` — `get_date_dimension` behind `int_dates`
- `sqlfluff ^3.5.0`

## Known Gaps

- `dbt_utils.get_column_values(..., default=[...])` returns `Undefined`, not `default`, at parse time (dbt_utils 1.4.1 + Jinja 3.1); operating on the result without an `execute` guard breaks parsing — see header of `carteira_agregada.sql`.
- Disponibilidades' layer fallback is `'NAO CLASSIFICADO'`, but the intended value was `'RESERVA ESTRATEGICA'` — account balance with a natural layer shows as a classification gap in the sheet. Currently the three Avenue accounts (R$ 295, current month).
- Deusa reconciliation: `carteira_deusa` vs `patrimonio_deusa` gap grew from R$ 2 to R$ 108k (07/2026) once `carteira_deusa` started itemizing missing-investment seeds (R$ 92k) and Avenue (absent from her sheet). Meio-de-mês report prints the diff; no one has confirmed which number is correct.
- Reserve target: N months of expense (6 couple / 12 Deusa) is marked `[CONFIRMAR]` in policy — never validated.
- No source in `_sources.yml` has `freshness:` configured.
- NHL domain disabled (`+enabled: false`): `stg_all_players.sql` duplicates ~45 lines of JSON extraction between `regular`/`playoffs`; `stg_all_games_details`'s incremental (`game_id > max(game_id)`) doesn't cover backfills.
