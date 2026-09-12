# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **dbt (data build tool) project** for a personal multi-domain data warehouse running on **PostgreSQL**. It is used as a **Git submodule** inside an Airflow environment orchestrated via Astro Cosmos. All SQL is PostgreSQL — not Snowflake or BigQuery.

## Common Commands

```bash
# Validate connection
dbt debug

# Run all models
dbt run

# Run a single model
dbt run --select carteira

# Run a domain by tag (financas | datas | livros | inflacao | nhl)
dbt run --select tag:financas

# Run a domain by folder, when its tag does not cover every layer (energia: only the marts are tagged)
dbt run --select path:models/staging/solar path:models/staging/weather path:models/marts/energy

# Run a model and all its downstream dependents
dbt run --select carteira+

# Run tests
dbt test
dbt test --select carteira

# Load the seeds (several finanças models depend on them)
dbt seed

# Generate and browse docs
dbt docs generate && dbt docs serve

# Install packages
dbt deps
```

## Comments in SQL

**Absolutely no comment that explains obvious code.** A comment is allowed only when it says something the code cannot: a data trap (`NULL` in the indexadores means "not published yet"), a choice that looks wrong but is deliberate (`LEFT` where `INNER` seems right, a cast after the `SUM` and not before), a platform gotcha (`SUM()` over `bigint` returns `NUMERIC`; `get_date_dimension`'s end date is exclusive), or a magic literal (a date, an algorithm). Keep it to the non-obvious fact, in as few lines as it takes.

Never write:
- what the model is, its grain or its columns — that goes in `_schema.yml`;
- history (`antes era…`, `o refactor eliminou…`) — that is what git is for;
- labels that repeat the next line (`-- PESO` above `THEN 'weight'`), section banners, or file paths;
- commented-out code or lists of discarded source columns.

## Architecture

### Layer conventions

| Layer | Materialization | Schema | Prefix | Purpose |
|-------|----------------|--------|--------|---------|
| Staging | `table` | `staging_<subpasta>` | `stg_` | Extract and type-cast raw sources (JSON payloads, Google Sheets exports, seeds); add indexes via `post_hook` |
| Intermediate | `view` | `intermediate_<subpasta>` | `int_` (`int_dim_` / `int_fct_` in NHL) | Business logic joins; Kimball dimensions and facts |
| Marts | `table` | `marts_<subpasta>` | none in most domains, `mrt_` in energy | Analytics-ready models |
| Presentation | `table` | `presentation` | none | Demodados outputs ready for publication (governismo, e-Cidadania) |

> **Schema = pasta:** `macros/generate_schema_name.sql` derives the schema from the file path — `<camada>_<primeira subpasta>` (`staging_avenue`, `intermediate_financas`, `marts_financas`); snapshots get `snapshots_<subpasta>`. `+schema` is ignored for models and snapshots, so moving a file between folders moves its table between schemas. Seeds always go to `seeds`. Anything outside dbt that queries a table by name (the report extractions in `.claude/skills/*/queries/`) must use the full schema, e.g. `marts_financas.carteira`.

> **Materialization:** every mart is a `table` (`dbt_project.yml` → `marts: +materialized: table`). Some models set `materialized = 'table'` explicitly in their config, which is redundant but harmless. Nothing in the project uses PostgreSQL `MATERIALIZED VIEW` except the NHL parameter views — so no `REFRESH MATERIALIZED VIEW` step is needed anywhere.

### Domain structure

Each domain lives under `models/staging/<domain>/`, and — where it has downstream logic — `models/intermediate/<domain>/` and `models/marts/<domain>/`.

**Finanças** is the active domain, and the only one with a semantic dictionary. It is spread across several staging folders that all feed `models/{intermediate,marts}/financas/`:

- **google** — Google Sheets export: contas, consolidado, patrimônio, luz, ajuste, classificação de carteira
- **b3** — B3 positions: ações, BDR, ETF, fundos, renda fixa, tesouro direto, proventos
- **avenue** — Avenue (broker no exterior): assets e dividendos
- **seeds_sources** — seeds: câmbio USD, de-para FGC, investimentos faltantes, datas especiais

Other domains:

- **inflation** — Price tracking from Atacadão and Minha Inflação scrapers
- **livros** — Bookstore price history from Vide Editorial scraping
- **solar** + **weather** — Residential IoT solar generation + OpenWeather API (mart `energy`)
- **demodados** — Brazilian legislative data: staging `senado`, `camara_deputados`, `ecidadania`, `radar_congresso` (disabled in each model's config) and `ranking`; intermediate `parlamentares`, `votacoes` and `scores`; mart `demodados`; and the `presentation` layer
- **conformado** — `int_dates` is the conformed calendar, **1900-01-01 → 2100-12-31**, with `data_sk`, pt-BR names, national holidays (ANBIMA/B3 banking calendar: fixed national holidays, Sexta-feira Santa, Carnaval and Corpus Christi, Easter computed in SQL) and `fl_dia_util` / `dia_util_mes`. Two dimensions sit on it: `dim_datas` (`marts_conformado`, adds the family's special dates — finanças, energia, livros) and its calendar-only twin `dim_dates` (`marts_demodados`, votações — never expose the family dates there). The spine is wide on purpose: every consumer `INNER JOIN`s into it from its own data, so a spine shorter than the data discards rows without a word — it once started in 2020 and dropped set–dez/2019 of Deusa's patrimônio; votações go back to 1991. `dbt_date.get_date_dimension`'s end date is **exclusive** — the old `"2050-12-31"` stopped on 12-30 — so the argument is the day after the last one.
- **nhl** — NHL hockey analytics. **Currently disabled**: `dbt_project.yml` sets `+enabled: false` for both `staging.nhl` and `intermediate.nhl`, so these models do not build and are excluded from `dbt run`. The code is kept in the repo.

### Finanças — read this before touching the domain

`models/marts/financas/_docs_financas.md` is the single source of truth for spending categories, investment layers and the investment policy (target allocation, contribution targets, reserve, FGC limits). Change a rule **there**, not in a `_schema.yml`.

Its numeric parameters are duplicated in `scripts/relatorios/politica.py` (`ALVOS_CAMADA`, `APORTE_ALVO`, `META_RESERVA_*`, `META_POUPANCA_PCT`, `TEXTO_CATEGORIA`, `TEXTO_CAMADA`) because the report builders cannot read Markdown. **Edit both in the same pass** — they silently diverged once and the monthly PDF rendered targets that contradicted the written policy. There is exactly **one** Python copy, shared by both report skills; do not make a third.

### Two reports, two cadences

The sources do not become trustworthy at the same time — `{% docs calendario_dados %}` in `_docs_financas.md` is the table. Spend is daily; the DRE closes in the first days of the next month; the carteira closes on its own cadence; **the indexadores (IPCA/CDI/Selic/inflação pessoal) only land around day 10**, because the IPCA is published then and the spreadsheet is filled afterwards. Hence two skills, both **on-demand only** — nothing schedules them, no DAG, no cron:

| | `relatorio-financas` | `relatorio-meio-mes` |
|---|---|---|
| Runs | days 1–5 | days 15–20 |
| Reference | the **previous**, closed month | the **current** month (+ benchmark of the previous) |
| Output | 4 PDFs — one per titular + the couple's budget | 2 PDFs — the couple's and Deusa's |
| Parameter | a month (`AAAA-MM`) | a **date** (`AAAA-MM-DD`), so a past day can be reproduced |
| Gates in `meta.prontidao` | `pronto_orcamento` (needs the DRE), `pronto_investimentos` (needs the carteira in date) | `pronto_ritmo` (day ≥ 10, entries fresh), `pronto_indicadores` (previous month's IPCA filled) |
| Batch path | `scripts/gerar_relatorios_financas.sh` | `scripts/gerar_relatorio_meio_mes.sh` |

`relatorio-financas` resolves its month from `date` (never `MAX(mes)`, never the current month). Investment is individual, receita/despesa is joint, and the emergency reserve lives in the budget report because it is sized by the couple's median expense.

`relatorio-meio-mes` answers "what to do in the days that remain": accumulated spend against the min–max envelope and median of the six closed months **on the same day of the billing cycle** (`dia_fatura`, never `dia_mes`), a projected close, and the margin still available in the compressible categories. **The benchmark section lives here, not in the closing report** — `riqueza` INNER JOINs the indexadores, so on day 1 the reference month is simply absent and the series used to shrink by one month in silence. The mart `indicadores` exists to make that legible: unlike `riqueza` it keeps the row with `NULL`, which is what `pronto_indicadores` reads.

That benchmark section covers **two independent patrimônios** against the same indexadores: the couple's (from `patrimonio_mom`) and Deusa's (from `patrimonio_deusa`, total líquido only — she has no per-account level, so she is absent from `patrimonio` and from `COM_PATRIMONIO` in `politica.py`, which gates the *closing* report's individual section). Never sum the two. Three properties of `riqueza` that the report must state rather than hide: the index **includes contributions** (it is not a return, so a double-digit monthly jump is an inflow or a revaluation); the series **do not share a base** (the couple's composes from 2023-11, Deusa's from her sheet's first variation, the indexadores arrive pre-computed — so only variation *within* a window compares, and the montador reindexes to the first displayed month); and there is **no despesa for Deusa** in the warehouse, so a fall in her index cannot be attributed to withdrawal or to market loss.

Deusa gets her **own section and her own PDF** (`--escopo deusa` on the same montador: same JSON, same blocks, its own capa, narrative and rodapé — the couple's file is not deliverable to her without exposing their budget, and no number of theirs belongs in hers). Her document has **no ritmo gate** — it is entirely about the closed previous month, so `scripts/gerar_relatorio_meio_mes.sh` still emits it when `pronto_ritmo` fails. The section is gated by its own `pronto_deusa` (does `marts_financas.carteira_deusa` have the previous month?) — the carteira closes on a cadence independent of the IPCA, so either section can appear without the other. Two things make that section different from every other block in the project. First, it deliberately mixes layers: the level and the composition come from `marts_financas.carteira_deusa` while the index comes from the planilha via `riqueza`, so the section **prints the reconciliation** between the two totals (R$ 2 apart in 07/2026, R$ 60k in 12/2024) — that gap, not two realities, is why the KPI's monthly variation can differ from the index's. Second, the whole section is *position*, never policy: camada, FGC, vencimento and destino do aporte stay in the closing report, which already emits a PDF just for her. Two data traps it must surface rather than smooth over: `SEM INDEXADOR` is a cadastro gap before it is an exposure (R$ 202k of it is renda fixa with a contracted rate and an empty field, hence the `valor_renda_fixa` column), and the disponível/investido boundary is the `DISPONIBILIDADE` class. `carteira_deusa_agregada.total_disponibilidades` once used a slightly different cut (R$ 259 apart, same grand total); since `carteira_agregada` started cutting by `classe_ativo` instead of by source model, the two agree — the section still reads the asset grain because that is where the class and the per-institution split come from.

Projection rule (documented in `{% docs cadencia_relatorios %}`): `realizado + GREATEST(median of what fell after the cut in the 6 closed months, what is already booked with a future date)`. `GREATEST` and not a sum, because the historical median already embeds the day-25 fixed expenses. It is biased high by construction, and **the per-category column does not add up to the total** — the median of a sum is not the sum of the medians. Both facts are printed in the PDF; never reconcile them in the narrative.

### Shared rendering layer

`scripts/relatorios/` is a Python package imported by **both** skills: `politica` (the policy parameters above), `formato` (pt-BR money/percent/date), `calculo` (`media`/`mediana`/`variacao`), `graficos` (hand-written inline SVG — no chart library), `blocos` (KPI/table/section/glossary HTML), `saida` (writing the finished report) and `relatorio.css`. Capa, rodapé, readiness banner and section order stay in each skill's montador, because the procedência text and the gates differ. Touching `scripts/relatorios/` changes both PDFs — check both. The montadores bootstrap it with `sys.path.insert(0, parents[4] / "scripts")`.

**One command, one file.** `--saida` on either montador dispatches on the extension: `.pdf` renders the HTML into a tempdir, drives `html_para_pdf.sh` (Chrome headless needs a `file://`) and discards the intermediate, so the delivery directory only ever receives PDFs; `.html` writes the markup and stops, for debugging. Never call `html_para_pdf.sh` by hand and never write `.html` into `relatorios/` — the HTML was always a build step, not a product. On conversion failure the intermediate is kept and its path printed to stderr.

### Key patterns

**Dinheiro é inteiro:** every monetary column reaches `marts` as `integer`/`bigint` — reais inteiros, no cents. The conversion happens once, at the point where the branches converge (`int_renda_fixa_incompleta` for renda fixa; the `SUM` inside `consumo` for the couple's daily spend), never per branch, so a value is rounded once and not twice. `::INT` rounds, it does not truncate. Staging keeps `NUMERIC(18,2)` so the cents survive until that point — **never `double precision` for money**: `stg_acoes`, `stg_bdr`, `stg_etf`, `stg_fundos` and `stg_proventos` inherited float from `raw` and now cast explicitly. What stays decimal is what is not money: variations and indices (`patrimonio_mom`, `riqueza`, `indicadores`, `NUMERIC(18,3)`) and the electricity bill (`luz`, kWh and price per kWh). Watch for `SUM()`: over `integer` PostgreSQL returns `bigint`, but over `bigint` it returns `NUMERIC` — that is why `carteira_auditoria` casts both sides. `dbt_date`'s `get_date_dimension` returns `day_of_month` / `day_of_year` as `double precision`; `int_dates` casts both to `integer`.

**JSON denormalization at staging:** Scraper and API sources store a single `payload jsonb` column. Staging models cast every field explicitly, e.g. `(payload ->> 'id')::int as game_id`. Never reference raw `payload` columns downstream of staging. Google Sheets and seed sources are not JSON — they arrive as text columns and are cleaned with the `clean_string` / `clean_integer` macros.

**De-para de instituições:** `macros/normaliza_instituicao.sql` é a fonte única do mapeamento variante → nome padronizado da instituição, chamada por `int_renda_variavel`, `int_renda_fixa_incompleta`, `int_renda_fixa_loop` e `int_dividendos`. Grafia nova de uma fonte se resolve com uma linha no dicionário `de_para` da macro — antes o mesmo `CASE` estava copiado nos três modelos e as cópias divergiram. O fallback `'DESCONHECIDO'` é o detector: uma coluna `desconhecido` com saldo em `carteira_agregada` significa variante não mapeada — hoje o pivot não gera essa coluna, ou seja, o de-para está completo.

**Ephemeral base models:** Some staging models have a helper that does the parsing shared by two sibling staging tables — `stg_base_*` in the NHL domain, `bases/` subfolder in the inflation domain.

**Classificação de camada — estado atual, sem histórico:** The investment layer (`camada`) is classified by hand in a spreadsheet and read back through `stg_carteira_classificacao`. The mart `carteira` resolves it with a `LEFT JOIN` on `pessoa + codigo_ativo + instituicao`; unclassified positions fall back to `'NAO CLASSIFICADO'`. Institution is part of the key on purpose — `BRSTNCLTN806` (Deusa) is registered at two banks, and joining on `pessoa + codigo_ativo` alone fans the position out. This **used to be an SCD2 as-of join** (`LEFT JOIN LATERAL` picking the last classification with `mes_base <=` the position's month), so past months kept the classification in force then. The sheet lost its `mes_base` column, so there is no longer a vigência to resolve: reclassifying an asset now rewrites its whole history.

**Parameter views:** `models/staging/nhl/parameters/vw_stg_request_*.sql` are not standard staging models — they are `materialized_view` query helpers that the Airflow extraction layer reads to determine which records to fetch next. They follow a different convention (`vw_` prefix) intentionally.

**Incremental loading:** Incremental models (`stg_all_play_by_play`, `stg_all_games_details`) use `delete+insert` strategy with composite unique keys. Always use PostgreSQL date arithmetic (`- interval '3 days'`), not `dateadd()` (Snowflake syntax).

**Index post-hooks:** Staging tables add indexes in `post_hook` using `CREATE INDEX IF NOT EXISTS`. Composite indexes exist on high-cardinality join keys (`game_id`, `event_id`, `game_date`).

**Domain selection:** there is no `selectors.yml` — select a domain by tag (`--select tag:financas`) or by folder (`--select path:models/marts/energy`).

### Schema/YAML files

- `models/staging/_sources.yml` — **every** raw source, 58 tables. Raw data lives in the `raw_ingestion_dev` database, one schema per origin, and each schema is one dbt source named after it — except `radar` (schema `radar_congresso`) and `ranking` (schema `ranking_politicos`). Never declare sources in a subfolder.
- `models/<camada>/<subpasta>/_schema.yml` — model documentation and tests, one file per folder that has models, documenting only that folder's models (`models/presentation/_schema.yml` for the presentation layer)
- `models/marts/financas/_docs_financas.md` — `{% docs %}` blocks shared by the finanças schemas

**Naming:** always `_schema.yml` and `_sources.yml` — not `schema.yml`, `_<dominio>__models.yml` or `_<dominio>__sources.yml`.

## Dependencies

- `dbt-core ^1.10.0`, `dbt-postgres ^1.10.0`
- `dbt-labs/dbt_utils 1.3.3` — `unique_combination_of_columns` generic test, `pivot` and `get_column_values`
- `calogica/dbt_date` — `get_date_dimension` macro behind `int_dates`
- `sqlfluff ^3.5.0` — SQL linting with dbt templating support

## Known Gaps (fora do escopo atual)

- `dbt_utils.get_column_values(..., default=[...])` devolve `Undefined` — e não o `default` — na fase de parse (dbt_utils 1.4.1 + Jinja 3.1). O `default` só vale em runtime, quando a relação não existe. Operar sobre o retorno (`+`, `| unique`) sem um guard em `execute` quebra o parse; ver o header de `carteira_agregada.sql`.
- Fallback de camada das disponibilidades: é `'NAO CLASSIFICADO'`, mas a intenção registrada era `'RESERVA ESTRATEGICA'` — saldo em conta, que tem camada natural, aparece como pendência de classificação na planilha. Hoje são as três contas Avenue (R$ 295 no mês corrente).
- Reconciliação de Deusa: `marts_financas.carteira_deusa` somava R$ 835.455 contra R$ 726.736 de `marts_financas.patrimonio_deusa` em 07/2026 — R$ 108 mil, não os R$ 2 de antes. A diferença é da carteira ter passado a itemizar as seeds de investimentos faltantes (R$ 92 mil) e a Avenue, que não tem coluna na planilha dela. O relatório de meio de mês imprime a diferença; ninguém verificou ainda qual dos dois números está certo.
- Reserva-alvo: o N em meses de despesa (6 casal / 12 Deusa) está marcado `[CONFIRMAR]` na política — nunca foi validado.
- Sources sem `freshness:` — só as cinco sources do demodados têm (`loaded_at_field: data_carga`, aviso em 160 h); finanças e os demais domínios não têm alerta de dados desatualizados.
- Sources em outro banco: as sources apontam para `raw_ingestion_dev`, mas o profile local conecta em `analytics_dev`, e o PostgreSQL não faz referência entre bancos (`cross-database references are not implemented`) nem há `postgres_fdw`. `dbt parse`/`compile` funcionam; `dbt run` local sobre staging, não.
- Tabelas declaradas que não existem em `raw_ingestion_dev`: `google_finance_sheet.ajuste` (só existe no antigo `postgres.raw`), `radar_congresso.raw_radar_parlamentares` (só em `demodados.raw`) e `radar_congresso.raw_radar_governismo_senadores` (em nenhum dos dois).
- Domínio NHL desabilitado (`+enabled: false`): `stg_all_players.sql` duplica ~45 linhas de extração JSON entre `regular` e `playoffs`, e `stg_all_games_details` usa incremental por `game_id > max(game_id)`, que não cobre backfills.
