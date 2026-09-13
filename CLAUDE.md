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
```

## Comments in SQL

Comment only if it says something the code can't. Never write: model/grain/column docs (→ `_schema.yml`), history (`antes era…` — that's git's job), labels that repeat the next line, section banners, file paths, or commented-out code. Keep it concise.

## Architecture

### Layers

| Layer | Materialization | Schema | Prefix | Purpose |
|-------|----------------|--------|--------|---------|
| Staging | `table` | `staging_<subpasta>` | `stg_` | Type-cast raw sources (JSON, Sheets, seeds); indexes via `post_hook` |
| Intermediate | `view` | `intermediate_<subpasta>` | `int_` | Business logic |
| Marts | `table` | `marts_<subpasta>` | none | Analytics-ready |
| Presentation | `table` | `presentation_<subpasta>` | none | Visualization-ready |


### Schema/YAML files

Naming convention is `_schema.yml` (leading underscore);

## Dependencies

- `dbt-core ^1.10.0`, `dbt-postgres ^1.10.0`
- `dbt-labs/dbt_utils 1.3.3` — `unique_combination_of_columns`, `pivot`, `get_column_values`
- `calogica/dbt_date` — `get_date_dimension` behind `int_dates`
- `sqlfluff ^3.5.0`

## Commit patterns

- `feat:` Commits do tipo feat indicam que seu trecho de código está incluindo um novo recurso.
- `fix:` - Commits do tipo fix indicam que seu trecho de código commitado está solucionando um problema (bug fix).
- `doc:` - Commits do tipo docs indicam que houveram mudanças na documentação, como por exemplo no Readme do seu repositório. (Não inclui alterações em código).
- `test:` - Commits do tipo test são utilizados quando são realizadas alterações em testes, seja criando, alterando ou excluindo testes unitários. (Não inclui alterações em código)
- `build:` - Commits do tipo build são utilizados quando são realizadas modificações em arquivos de build e dependências.
- `refactor:` - Commits do tipo refactor referem-se a mudanças devido a refatorações que não alterem sua funcionalidade.
- `chore:` - Commits do tipo chore indicam atualizações de formatações de código, semicolons, trailing spaces, lint, como por exemplo adicionar um pacote no gitignore. (Não inclui alterações em código)
- `remove:` - Commits do tipo remove indicam a exclusão de arquivos, diretórios ou funcionalidades obsoletas ou não utilizadas, qualquer outra forma de limpeza do código-fonte, reduzindo o tamanho e a complexidade do projeto e mantendo-o mais organizado.
