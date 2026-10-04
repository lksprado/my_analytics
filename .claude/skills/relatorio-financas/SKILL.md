---
name: relatorio-financas
description: Varre a camada marts do domínio finanças e gera quatro relatórios mensais em PDF — um de investimentos para cada titular (Lucas, Jéssica e Deusa) e um de orçamento do casal (receita, despesa, gastos por categoria e reserva). Use quando o usuário pedir o relatório financeiro do mês, o fechamento mensal, ou o PDF de finanças.
---

# Relatório financeiro mensal (fechamento)

Quatro PDFs sobre o **mês fechado anterior**, escritos como planejador financeiro (orçamento) e
assessor de investimentos (carteiras):

| Arquivo | Escopo | Conteúdo |
| --- | --- | --- |
| `relatorio_orcamento_casal_AAAA-MM.pdf` | `orcamento` | Receita, despesa, resultado, poupança, categorias, luz, reserva de emergência |
| `relatorio_investimentos_lucas_AAAA-MM.pdf` | `lucas` | Patrimônio, carteira, renda passiva, riscos, aporte |
| `relatorio_investimentos_jessica_AAAA-MM.pdf` | `jessica` | idem |
| `relatorio_investimentos_deusa_AAAA-MM.pdf` | `deusa` | Carteira, renda passiva, riscos, aporte (sem patrimônio) |

- Receita e despesa são do casal: só o orçamento fala de gasto. Não invente despesa individual, nem para Deusa.
- A reserva de emergência é do casal e mora no orçamento; nos individuais aparece só como camada contra o alvo.

**Fronteira com `relatorio-meio-mes`:** este relatório não cita CDI, IPCA, inflação pessoal nem
desempenho contra benchmark — no dia em que roda os indexadores do mês ainda não saíram (ver
`calendario_dados`). Também não fala de ritmo, projeção ou margem do mês corrente.

Acionamento sob demanda. Para refazer meses em lote sem sessão interativa:
`scripts/gerar_relatorios_financas.sh`.

## Passo 0 — Ler as regras do domínio

Leia `models/presentation/financas/_docs_financas.md` antes de qualquer análise, começando por
`fatos_relevantes`. Categorias, camadas, alvos, reserva-alvo, limites e armadilhas de leitura estão
lá; não estão repetidos aqui. Fato usado no diagnóstico entra em `premissas` com o status.
Parâmetro marcado `[CONFIRMAR]` é usado assim mesmo e sinalizado em `premissas`.

## Passo 1 — Resolver o mês de referência

```bash
date +%Y-%m-%d
```

Rode o comando; a data do contexto pode estar velha.

1. Mês pedido pelo usuário vence. Mês sem ano é a ocorrência mais recente que não está no futuro.
2. Sem pedido, o mês anterior: `date -d "$(date +%Y-%m-01) -1 month" +%Y-%m`.
3. Nunca o mês corrente por default.

Declare o mês antes de extrair.

## Passo 2 — Extrair

```bash
.claude/skills/relatorio-financas/scripts/extrair_dados.sh <AAAA-MM> <scratchpad>/dados.json
```

Todo número sai desse JSON. Faltou um corte: acrescente o bloco em `queries/extrair.sql` e rode de novo.

### Portão de prontidão (`meta.prontidao`)

| flag | exige | bloqueia |
| --- | --- | --- |
| `pronto_orcamento` | mês terminado, DRE com variáveis, lançamento até o fim do mês | orçamento |
| `pronto_investimentos` | carteira no máximo 2 meses atrás | os três individuais |

Os dois são independentes. Gere a família que passou; da reprovada, relate as `pendencias_*`,
informe `ultimo_mes_fechado` e ofereça gerá-lo. Só force se o usuário mandar — aí o montador
imprime a tarja de dados incompletos e o diagnóstico diz que os valores são parciais.

### Armadilhas operacionais

- A extração já corta meses posteriores a `mes_ref`; nunca os reintroduza.
- Com `meta.defasagem_carteira_meses > 0`, declare a data de cada número: carteira em
  `meta.mes_carteira`, orçamento em `meta.mes_ref`. No orçamento, a reserva é o único número da carteira.
- `meta.motivos_especiais` não nulo (ex.: aniversário de casamento) explica pico em `role` e `diversos`.
- Percentual de camada na narrativa é o da tabela do montador (base sem as camadas sem alvo), não o
  `pct_da_carteira` cru do JSON.

## Passo 3 — Analisar

**Orçamento (casal):** taxa de poupança do mês e de 12 meses contra a meta; categorias por
participação, contra a média de 6 meses e o mesmo mês do ano anterior; fixo × variável e essencial ×
discricionário; cobertura da reserva contra a reserva-alvo, dizendo qual regra vale (N meses ou piso);
luz separando preço (`preco_kwh`) de consumo (`kwh_dia`).

**Investimentos (um por titular, contra o alvo daquela pessoa):** camada contra alvo, com desvio em
p.p. e banda; concentração por instituição, emissor e conglomerado; moeda; FGC sem folga; vencimentos
em 12 meses e destino do principal; **destino do aporte do mês**, em valor e camada.

Conduta:
- Não transporte a leitura de uma carteira para outra.
- Não recomende produto ou emissor que não esteja na carteira nem seja instrumento genérico da
  camada ("Tesouro Selic" sim; "CDB do banco X a 112% do CDI" não).
- Quando o dado não sustenta a conclusão, diga que não sustenta.

## Passo 4 — Narrativa

O montador renderiza KPIs, tabelas, gráficos e glossário. Você escreve só o texto, em
`narrativa_<escopo>.json` no scratchpad, HTML restrito a `<p>` e `<strong>`:

```json
{"sumario": "<p>…</p>", "diagnostico_orcamento": "<p>…</p>", "diagnostico_carteira": "<p>…</p>",
 "diagnostico_riscos": "<p>…</p>", "recomendacoes": [{"titulo": "…", "texto": "…"}], "premissas": ["…"]}
```

| escopo | chaves renderizadas (as demais são ignoradas) |
| --- | --- |
| `orcamento` | `sumario`, `diagnostico_orcamento`, `recomendacoes`, `premissas` |
| `lucas`, `jessica`, `deusa` | `sumario`, `diagnostico_carteira`, `diagnostico_riscos`, `recomendacoes`, `premissas` |

- Número citado confere com o JSON.
- No máximo 6 recomendações, cada uma com valor em R$ e a razão em uma frase. Orçamento recomenda
  gasto, poupança e reserva; individuais recomendam destino do aporte. Sem repetir entre os dois.
- `premissas`: regra de reserva-alvo vigente, `[CONFIRMAR]` usados, fatos relevantes usados e
  limitações do dado.

Seções que o montador já produz (não duplique): capa, sumário com KPIs, resultado do mês e 13 meses,
categorias e luz, reserva, recomendações, glossário e notas. Nos individuais: patrimônio (só Lucas e
Jéssica; no de Deusa as seções sobem), carteira, renda passiva, riscos, recomendações, glossário e notas.

## Passo 5 — Montar

```bash
S=<scratchpad>; D=${RELATORIOS_DIR:-relatorios/<AAAA-MM>}
for escopo in orcamento lucas jessica deusa; do   # só os escopos cujo portão passou
  case $escopo in
    orcamento) nome=relatorio_orcamento_casal_<AAAA-MM> ;;
    *)         nome=relatorio_investimentos_${escopo}_<AAAA-MM> ;;
  esac
  python3 .claude/skills/relatorio-financas/scripts/montar_relatorio.py \
      --dados "$S/dados.json" --escopo "$escopo" \
      --narrativa "$S/narrativa_$escopo.json" --saida "$D/$nome.pdf"
done
```

`--saida *.pdf` entrega só o PDF. Para depurar, `--saida "$S/debug.html"`; nunca grave `.html` em `$D`.
`relatorios/` está no `.gitignore`.

## Passo 6 — Conferir

1. `pdftoppm -png -r 80 -f 1 -l 3 <pdf> <prefixo>` e olhe: texto cortado, tabela estourando, gráfico
   sobreposto, página em branco.
2. Confira dois ou três números da narrativa contra as tabelas renderizadas.
3. Nenhum mês futuro em número ou gráfico; cada PDF com mais de uma página.
4. Nenhum assunto vazou: individuais sem despesa, orçamento sem posição de carteira, nenhum com
   CDI/IPCA; numeração sem buraco no de Deusa.

Texto errado: corrija a narrativa. Layout ou número errado: `montar_relatorio.py` ou
`scripts/relatorios/` (que também afeta o meio de mês — confira os dois). Não entregue PDF que não olhou.

## Encerramento

Caminhos dos PDFs, mês de cada bloco, escopos que ficaram de fora pelo portão e pendências por titular:
ativos não classificados, conglomerados sem folga FGC, `[CONFIRMAR]` que sustentaram recomendação.
