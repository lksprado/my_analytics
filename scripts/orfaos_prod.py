#!/usr/bin/env python3
"""Lista objetos órfãos (sem modelo dbt correspondente) e, com --drop, remove-os.

Órfão aqui é objeto que existe nos schemas do warehouse mas não é produzido por
nenhum modelo do manifest — tipicamente resto de modelo renomeado ou removido,
que o dbt não dropa sozinho.

Uso, a partir da raiz do repo, num host que enxergue o banco alvo:

    dbt compile                                    # gera target/manifest.json
    export PGPASSWORD=...                          # nunca a senha na DSN: `ps` é público
    D="postgresql://user@host:5432/analytics_prod"

    python3 scripts/orfaos_prod.py --dsn "$D"                      # só relatório
    pg_dump "$D" -t schema.objeto > backup.sql                     # backup
    python3 scripts/orfaos_prod.py --dsn "$D" --drop --backup backup.sql

O manifest serve para qualquer target: `generate_schema_name` deriva o schema do
caminho do arquivo, não da conexão, então os nomes batem em dev e em prod.

Sem --drop não escreve nada. Com --drop, exige backup existente, roda em
transação e não usa CASCADE — se algo inesperado depender do objeto, falha em vez
de arrastar junto. Aborta se algum órfão tiver leituras ou dependente externo.

A coluna `leituras` é `seq_scan + idx_scan` acumulado, e só significa alguma coisa
junto da janela que o relatório imprime: num banco recém-reiniciado, zero leituras
quer dizer "ninguém leu desde ontem", não "ninguém usa".
"""
import argparse, json, subprocess, sys, pathlib

SCHEMAS = r"^(staging|intermediate|marts|presentation)_"


def psql(dsn, sql):
    r = subprocess.run(['psql', dsn, '-tAF', '\x1f', '-c', sql],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"psql falhou: {r.stderr.strip()}")
    return [l.split('\x1f') for l in r.stdout.strip().split('\n') if l]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dsn', required=True, help='libpq DSN do banco alvo')
    ap.add_argument('--manifest', default='target/manifest.json')
    ap.add_argument('--drop', action='store_true')
    ap.add_argument('--backup', help='arquivo .sql do pg_dump (exigido com --drop)')
    a = ap.parse_args()

    man = json.load(open(a.manifest))
    known = {f"{n['schema']}.{n.get('alias') or n['name']}"
             for n in man['nodes'].values() if n['resource_type'] == 'model'}

    objs = psql(a.dsn, f"""
        SELECT n.nspname||'.'||c.relname, c.relkind,
               pg_size_pretty(pg_total_relation_size(c.oid)),
               COALESCE(s.seq_scan,0)+COALESCE(s.idx_scan,0)
        FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace
        LEFT JOIN pg_stat_user_tables s ON s.relid=c.oid
        WHERE n.nspname ~ '{SCHEMAS}' AND c.relkind IN ('r','v','m','p')
        ORDER BY 1;""")

    orphans = [o for o in objs if o[0] not in known]
    if not orphans:
        print("nenhum órfão."); return

    janela = psql(a.dsn, """
        SELECT date_trunc('second', pg_postmaster_start_time())::text,
               COALESCE(date_trunc('second', stats_reset)::text, 'nunca')
        FROM pg_stat_database WHERE datname = current_database();""")[0]
    print(f"postgres no ar desde {janela[0]} | stats resetadas: {janela[1]}")
    print("as leituras abaixo acumulam desde a mais recente dessas duas datas\n")

    print(f"{'objeto':55s} {'tipo':8s} {'tamanho':>10s} {'leituras':>9s}")
    lidos = []
    for name, kind, size, scans in orphans:
        k = {'r': 'table', 'v': 'view', 'm': 'matview', 'p': 'partit'}[kind]
        print(f"{name:55s} {k:8s} {size:>10s} {scans:>9s}")
        if int(scans or 0) > 0:
            lidos.append((name, scans))

    # Dependentes fora do conjunto de órfãos: se houver, NÃO dropar.
    nomes = "','".join(o[0] for o in orphans)
    deps = psql(a.dsn, f"""
        SELECT DISTINCT ds.nspname||'.'||dep.relname, sn.nspname||'.'||src.relname
        FROM pg_depend d
        JOIN pg_rewrite rw ON rw.oid=d.objid
        JOIN pg_class dep ON dep.oid=rw.ev_class
        JOIN pg_namespace ds ON ds.oid=dep.relnamespace
        JOIN pg_class src ON src.oid=d.refobjid
        JOIN pg_namespace sn ON sn.oid=src.relnamespace
        WHERE sn.nspname||'.'||src.relname IN ('{nomes}') AND dep.oid<>src.oid;""")
    externos = [d for d in deps if d[0] not in {o[0] for o in orphans}]

    print()
    if lidos:
        print("!! ATENÇÃO: estes órfãos FORAM LIDOS desde o último reset das "
              "estatísticas — provável consumidor externo (BI, relatório):")
        for n, s in lidos:
            print(f"   {n}  ({s} leituras)")
    if externos:
        print("!! ATENÇÃO: há dependentes FORA do conjunto de órfãos:")
        for dep, src in externos:
            print(f"   {dep} depende de {src}")

    if not a.drop:
        print("\n(relatório apenas; use --drop para remover)")
        return
    if lidos or externos:
        sys.exit("\nabortado: resolva os avisos acima antes de dropar.")
    if not a.backup or not pathlib.Path(a.backup).exists():
        sys.exit("\nabortado: --backup com um pg_dump existente é obrigatório.")

    stmts = [f"DROP {'VIEW' if k=='v' else 'MATERIALIZED VIEW' if k=='m' else 'TABLE'} "
             f"IF EXISTS {n};" for n, k, _, _ in orphans]
    sql = "BEGIN;\n" + "\n".join(stmts) + "\nCOMMIT;"
    print("\n" + sql)
    r = subprocess.run(['psql', a.dsn, '-v', 'ON_ERROR_STOP=1', '-c', sql],
                       capture_output=True, text=True)
    print(r.stdout or r.stderr)
    if r.returncode:
        sys.exit("drop falhou (transação revertida).")
    print("ok — órfãos removidos.")


if __name__ == '__main__':
    main()
