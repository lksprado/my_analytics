# my_analytics

Projeto dbt único (Postgres) que transforma as tabelas `raw_*` carregadas pelo
[`my_ingestion`](https://github.com/lksprado/my_ingestion) em modelos prontos para análise. Em
produção, quem roda é o Airflow do [`my_orchestrator`](https://github.com/lksprado/my_orchestrator),
pela DAG `dag_dbt_my_analytics` (Cosmos).

> Visão geral do deploy dos quatro repos (runners, tokens, troubleshooting):
> [`homelab/docs/como_funciona_o_deploy.md`](https://github.com/lksprado/homelab/blob/main/docs/como_funciona_o_deploy.md).

## Uso em dev

```bash
uv sync                    # dbt-postgres e sqlfluff
source .venv/bin/activate
pre-commit install         # bloqueia commit direto na main
dbt deps                   # pacotes de packages.yml (versões travadas no package-lock.yml)
dbt debug                  # confere a conexão
```

A conexão vem do `~/.dbt/profiles.yml`, perfil `my_analytics`, target `dev` (banco
`analytics_dev`). O arquivo fica fora do repo. Em prod o Airflow monta o perfil a partir da
connection `postgres_dw`.

```bash
dbt build -s stg_proventos+          # model e tudo que depende dele, com testes
dbt build -s models/marts/financas   # uma pasta
dbt seed -s seed_x --full-refresh
sqlfluff lint models/                # lint com o templater do dbt
```

### Onde cada coisa vai

| Camada | Materialização | Prefixo |
|---|---|---|
| `staging` | table | `stg_` |
| `intermediate` | view | `int_` |
| `marts` | table | `fct_`, `dim_`, `bridge_` |
| `presentation` | table | sem prefixo |

O schema sai do caminho do arquivo, e `+schema` é ignorado:
- `models/<camada>/<subpasta>/x.sql` → `<camada>_<subpasta>`;
- seeds sempre vão para `seeds`.

A regra está em `macros/generate_schema_name.sql`. As convenções de SQL e YAML estão no `CLAUDE.md`.

### Relatórios financeiros

- **Caminho normal:** as skills `/relatorio-financas` e `/relatorio-meio-mes` no Claude Code.
- **Em lote** (meses passados), use os scripts:
  - `scripts/gerar_relatorios_financas.sh [AAAA-MM] [--forcar]`;
  - `scripts/gerar_relatorio_meio_mes.sh [AAAA-MM-DD] [--forcar]`.
- Os PDFs vão para `relatorios/AAAA-MM/`.

## Deploy

**A `main` é produção.** O projeto entra no Airflow de prod quando o PR é mergeado.

### Ao abrir o PR

Não há check no GitHub. Valide em dev:
- rode `dbt build -s <o que mudou>+` contra o `analytics_dev`;
- ou dispare a `dag_dbt_my_analytics` no Airflow local, que lê este diretório ao vivo.

### Ao fazer o merge

1. Qualquer mudança fora de `.md` e `.github/` faz o workflow `Deploy prod`
   (`.github/workflows/deploy-prod.yml`) avisar o `my_orchestrator`.
2. O deploy do `my_orchestrator` publica a ponta dos três repos no atb:

| O que mudou | O que acontece em prod |
|---|---|
| model, macro, seed, teste, `dbt_project.yml` | só rsync, sem restart; a DAG passa a ver a mudança em até 1 min |
| `packages.yml` + `package-lock.yml` | rsync + `dbt deps` automático no scheduler, sem restart |

3. O run fica em [my_orchestrator → Actions](https://github.com/lksprado/my_orchestrator/actions).

**Pacote dbt novo:**
1. Edite o `packages.yml`.
2. Rode `dbt deps` local, para atualizar o `package-lock.yml`.
3. Commite os dois.

O deploy só roda `dbt deps` quando o **lock** muda.

O merge não roda o dbt. As tabelas de prod só mudam na próxima execução da
`dag_dbt_my_analytics`, pelo agendamento ou por disparo manual na UI de prod.
