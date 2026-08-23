#!/usr/bin/env bash
# Geração em lote do relatório de meio de mês.
#
# NÃO está plugado em nenhum agendador. O caminho normal é interativo — a skill
# `/relatorio-meio-mes` no terminal, que resolve a data sozinha. Este script é
# para o caso em lote: reproduzir o relatório de uma data já passada sem sessão
# interativa, que é também como se afere se a projeção acertou.
#
#   gerar_relatorio_meio_mes.sh [AAAA-MM-DD] [--forcar]
#
# Sem argumento: hoje.
# --forcar: gera mesmo com o portão de ritmo reprovado (o PDF sai com tarja).
#
# Variáveis de ambiente:
#   RELATORIOS_DIR   destino do PDF (default: <projeto>/relatorios/AAAA-MM)
#   DBT_PROFILES_DIR diretório do profiles.yml (default: ~/.dbt)
#   CLAUDE_BIN       caminho do CLI (default: `claude` no PATH)
#   TIMEOUT_SEG      teto de execução (default: 900)
#   PERMITIR_INCOMPLETO=1  mesmo efeito de --forcar
#
# Dois PDFs por execução, com portões independentes:
#
#   relatorio_meio_mes_AAAA-MM.pdf         casal   exige `pronto_ritmo`
#   relatorio_meio_mes_deusa_AAAA-MM.pdf   Deusa   exige `pronto_deusa`
#
# `pronto_indicadores` não bloqueia nenhum dos dois — decide só se a seção de
# desempenho entra. E `pronto_ritmo` NÃO bloqueia o PDF de Deusa: ele é todo do
# mês fechado anterior, e reprovar o ritmo do casal não diz nada sobre o
# patrimônio dela. Por isso um mês sem ritmo ainda gera o documento dela.
#
# Saída: 0 pelo menos um PDF gerado
#        75 nenhum dos dois é possível (não é erro — tente de novo depois)
#        outros != 0 para falha de verdade
#
# Aferição da projeção (o teste que decide se o relatório vale):
#   for d in 2026-05-17 2026-06-17 2026-07-17; do
#       scripts/gerar_relatorio_meio_mes.sh "$d" || echo "pulou $d"
#   done
#   # depois compare projecao.total com marts.resultado.total_despesas do mês
set -euo pipefail

PROJETO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
TIMEOUT_SEG="${TIMEOUT_SEG:-900}"
FORCAR="${PERMITIR_INCOMPLETO:-0}"
HOJE=""

for arg in "$@"; do
    case "$arg" in
        --forcar) FORCAR=1 ;;
        -*)       echo "erro: opção desconhecida '$arg'" >&2; exit 2 ;;
        *)        HOJE="$arg" ;;
    esac
done

HOJE="${HOJE:-$(date +%F)}"
if ! [[ "$HOJE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "erro: data inválida '$HOJE' (esperado AAAA-MM-DD)" >&2
    exit 2
fi
MES="${HOJE:0:7}"

DESTINO="${RELATORIOS_DIR:-$PROJETO/relatorios/$MES}"
mkdir -p "$DESTINO"

command -v "$CLAUDE_BIN" >/dev/null 2>&1 || {
    echo "erro: CLI '$CLAUDE_BIN' não encontrado no PATH" >&2; exit 3; }

echo "[meio-mes] projeto=$PROJETO hoje=$HOJE destino=$DESTINO"

# Extrai ANTES de chamar o agente: falha cedo se o banco não responde, e o
# portão é lido aqui em vez de depender de o agente obedecer.
DADOS="$DESTINO/.dados_meio_mes_$HOJE.json"
"$PROJETO/.claude/skills/relatorio-meio-mes/scripts/extrair_dados.sh" "$HOJE" "$DADOS"

leitura="$(python3 - "$DADOS" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))["meta"]["prontidao"]
print(int(bool(p.get("pronto_ritmo"))), int(bool(p.get("pronto_indicadores"))),
      int(bool(p.get("pronto_deusa"))))
print("|".join(p.get("pendencias_ritmo") or []))
PY
)"
PRONTO_RITMO="$(echo "$leitura" | head -1 | cut -d' ' -f1)"
PRONTO_IND="$(echo "$leitura" | head -1 | cut -d' ' -f2)"
PRONTO_DEUSA="$(echo "$leitura" | head -1 | cut -d' ' -f3)"
PENDENCIAS="$(echo "$leitura" | tail -1)"

echo "[meio-mes] pronto_ritmo=$PRONTO_RITMO pronto_indicadores=$PRONTO_IND pronto_deusa=$PRONTO_DEUSA"

# Cada PDF tem o seu portão. O do casal cai com o ritmo; o de Deusa, não — ele
# é todo do mês fechado anterior.
FAZ_CASAL=1
[[ "$PRONTO_RITMO" != "1" && "$FORCAR" != "1" ]] && FAZ_CASAL=0
FAZ_DEUSA="$PRONTO_DEUSA"

if [[ "$FAZ_CASAL" != "1" && "$FAZ_DEUSA" != "1" ]]; then
    echo "[meio-mes] nenhum dos dois relatórios é possível agora:" >&2
    echo "$PENDENCIAS" | tr '|' '\n' | sed 's/^/    - /' >&2
    rm -f "$DADOS"
    exit 75
fi

EXTRA=""
[[ "$PRONTO_IND" != "1" ]] && EXTRA=" Os indexadores do mês anterior não estão publicados: omita a seção de desempenho."
[[ "$PRONTO_RITMO" != "1" && "$FAZ_CASAL" == "1" ]] && EXTRA="$EXTRA Gere mesmo com o portão de ritmo reprovado e deixe claro que os números estão parciais."
[[ "$FAZ_DEUSA" != "1" ]] && EXTRA="$EXTRA A carteira de Deusa não tem a posição do mês anterior: omita a seção dela e NÃO gere o PDF dela."
if [[ "$FAZ_CASAL" != "1" ]]; then
    echo "[meio-mes] ritmo reprovado: só o relatório de Deusa será gerado." >&2
    echo "$PENDENCIAS" | tr '|' '\n' | sed 's/^/    - /' >&2
    EXTRA="$EXTRA O mês corrente não sustenta leitura de ritmo, então NÃO gere o relatório do casal: gere apenas o PDF de Deusa, que não depende desse portão."
fi

RELATORIOS_DIR="$DESTINO" timeout "$TIMEOUT_SEG" "$CLAUDE_BIN" \
    --print --permission-mode acceptEdits \
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Skill" \
    "/relatorio-meio-mes data de referência $HOJE. Grave o PDF em $DESTINO.$EXTRA" \
    || { echo "erro: o CLI falhou ou estourou o timeout" >&2; exit 4; }

conferir() {
    local pdf="$1"
    [[ -f "$pdf" ]] || { echo "erro: não encontrei $pdf" >&2; exit 4; }
    local tam; tam="$(stat -c%s "$pdf")"
    (( tam >= 20000 )) || { echo "erro: $pdf tem só $tam bytes" >&2; exit 5; }
    echo "[meio-mes] pronto: $pdf ($(du -h "$pdf" | cut -f1))"
}

[[ "$FAZ_CASAL" == "1" ]] && conferir "$DESTINO/relatorio_meio_mes_$MES.pdf"
[[ "$FAZ_DEUSA" == "1" ]] && conferir "$DESTINO/relatorio_meio_mes_deusa_$MES.pdf"

rm -f "$DADOS"
