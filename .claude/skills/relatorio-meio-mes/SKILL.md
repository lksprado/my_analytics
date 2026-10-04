---
name: relatorio-meio-mes
description: Gera o relatório de acompanhamento do mês EM ANDAMENTO — ritmo do gasto até hoje, projeção de fechamento, quanto ainda cabe gastar por categoria, mais o desempenho do patrimônio do casal contra CDI e inflação pessoal do mês anterior e uma seção apartada com o patrimônio e a composição dos ativos de Deusa. Use quando o usuário pedir o acompanhamento de meio de mês, como está o gasto do mês, se vai estourar o orçamento, o desempenho contra os benchmarks, ou a análise patrimonial de Deusa fora do fechamento. NÃO é o fechamento mensal — para os quatro PDFs do mês fechado, use relatorio-financas.
---

# Relatório de meio de mês

Roda entre os dias 15 e 20. A pergunta é **"o que fazer nos dias que restam"**. AAAA-MM é o mês corrente.

| Arquivo | Leitor | Conteúdo |
| --- | --- | --- |
| `relatorio_meio_mes_AAAA-MM.pdf` | Lucas e Jéssica | Mês corrente (ritmo, categorias, margem) + desempenho do casal no mês anterior + seção apartada de Deusa |
| `relatorio_meio_mes_deusa_AAAA-MM.pdf` | Deusa | Só o patrimônio dela no mês anterior; nada do casal |

Três recortes, cada um com seu portão: **mês corrente do casal** (gasto diário, o dado mais fresco),
**mês anterior do casal** (benchmark, que só sai ~dia 10) e **mês anterior de Deusa** (patrimônio e
composição). Ver `calendario_dados` no doc.

**Fronteira com `relatorio-financas`:** aqui não entram camada, alocação-alvo, FGC, vencimentos,
reserva de emergência nem destino do aporte — nem do casal, nem de Deusa. A composição de Deusa que
entra aqui é posição (instituição, disponível × investido, classe, indexador), não política.

Acionamento sob demanda. Sem sessão interativa: `scripts/gerar_relatorio_meio_mes.sh`.

## Passo 0 — Ler as regras do domínio

Leia `models/presentation/financas/_docs_financas.md`, começando por `fatos_relevantes`: aqui eles
pesam mais, porque o relatório alerta sobre o mês em curso e um pico previsto não é descontrole.
Categorias, benchmark e as armadilhas do índice estão lá, não aqui. Fato usado entra em `premissas`
com o status; `[CONFIRMAR]` é usado e sinalizado em `premissas`.

## Passo 1 — Resolver a data

```bash
date +%Y-%m-%d
```

Rode o comando. O corte é hoje e o mês é o corrente (o oposto do fechamento). Data pedida pelo usuário
vence. Antes do dia 10 o portão reprova: diga e ofereça rodar mais tarde. Declare a data antes de extrair.

## Passo 2 — Extrair

```bash
.claude/skills/relatorio-meio-mes/scripts/extrair_dados.sh <AAAA-MM-DD> <scratchpad>/dados.json
```

Todo número sai desse JSON. Faltou um corte: acrescente em `queries/extrair_meio_mes.sql`.

### Portão de prontidão (`meta.prontidao`)

| flag | exige | bloqueia |
| --- | --- | --- |
| `pronto_ritmo` | hoje ≥ dia 10; último lançamento a ≤ 3 dias; ≥ 7 dias com gasto | o PDF do casal |
| `pronto_indicadores` | `indicadores` com `ipca` do mês anterior | seção de desempenho (casal e Deusa) |
| `pronto_deusa` | `carteira_deusa` com a posição do mês anterior | seção de Deusa e o PDF dela |

São independentes; o PDF de Deusa não depende de `pronto_ritmo`. Seção reprovada o montador omite e
renumera. Com `pronto_ritmo` reprovado, relate as `pendencias_ritmo` e não gere o do casal, a menos
que o usuário mande. `meta.meses_de_base` < 6 vai para `premissas`.

### Regra de projeção

> projeção = realizado até o corte + **o maior** entre (a) a mediana, nos 6 meses fechados, do que
> caiu depois do mesmo dia do ciclo e (b) o já lançado neste mês com data futura (`agendado`).

- O maior, não a soma: a mediana já embute as fixas do dia 25.
- Enviesada para cima por construção: prefere avisar demais.
- A coluna por categoria não soma ao total (mediana de soma ≠ soma de medianas). O total julga o mês;
  a linha julga a categoria. Nunca reconcilie os dois na narrativa.

Declare a regra em `premissas`.

### Armadilhas operacionais

- O eixo é `dia_fatura` (o `dia_ajustado` do ciclo, ver `ciclo_fatura`): "até o dia 17" é dia 17 do ciclo.
- Linha do mês corrente com data futura é fixa agendada, não gasto. Acumulado abaixo da mediana antes
  do dia 25 **não** é economia.
- A receita do mês já está lançada; a poupança projetada só é incerta do lado da despesa.
- `riqueza.comparativo_*` usa `RICO`/`POBRE` internamente; no PDF escreva "acima do CDI" / "abaixo do IPCA".
- Deusa, "sem indexador": em boa parte é renda fixa com taxa contratada e campo vazio na origem. Use
  `valor_renda_fixa` para separar; nunca reporte a linha inteira como exposição. `TIR` em conta corrente
  é rótulo herdado da planilha.
- Deusa, concentração por instituição é posição; o risco FGC é do fechamento.
- `deusa_conciliacao` traz os dois totais de Deusa (`carteira_deusa` × índice); se a variação do KPI
  discordar da do índice, a diferença vem daí.

## Passo 3 — Analisar

- **Ritmo:** o acumulado está na faixa dos 6 meses fechados no mesmo dia do ciclo? Se saiu, quando e por quê.
- **Categorias:** quais projeções destoam da mediana do mês cheio, e quanto disso é `agendado` contra decisão.
- **Margem (prioridade):** quanto ainda cabe em `role`, `diversos` e `mercado` para fechar no padrão e
  na meta de poupança.
- **Desempenho** (se `pronto_indicadores`): patrimônio do casal contra CDI e inflação pessoal,
  separadamente, com a ressalva do aporte; olhe também os últimos meses isolados.
- **Deusa** (se `pronto_deusa`): índice contra os mesmos benchmarks; quanto está parado em conta e
  como evoluiu (a leitura acionável); rotação entre classes; a variação que sobra sem explicação.

Conduta: recomendação tem valor em R$ e prazo; não mande cortar o que é `agendado`; quando o dado
não sustenta, diga.

## Passo 4 — Narrativa

O montador renderiza KPIs, tabelas e gráficos. Você escreve duas narrativas no scratchpad, HTML
restrito a `<p>` e `<strong>`, chaves opcionais:

| arquivo | chaves | limite |
| --- | --- | --- |
| `narrativa_meio_mes.json` | `sumario`, `diagnostico_ritmo`, `diagnostico_categorias`, `diagnostico_desempenho`*, `diagnostico_deusa`**, `recomendacoes`, `premissas` | 6 recomendações |
| `narrativa_deusa.json`** | `sumario`, `diagnostico_desempenho`*, `diagnostico_ativos`, `recomendacoes`, `premissas` | 4 recomendações |

\* só com `pronto_indicadores`; \*\* só com `pronto_deusa`. `recomendacoes` é `[{"titulo", "texto"}]`;
`premissas` é lista de strings.

- Número citado confere com o JSON.
- `premissas` do casal: regra da projeção, `meses_de_base`, `[CONFIRMAR]` e fatos usados.
- A de Deusa não é recorte da outra: leitor é ela, nada de gasto, orçamento ou número do casal.
  Recomendações são ações que dependem dela ou da planilha dela. Premissas obrigatórias: sem despesa
  lançada, índice com aporte, bases diferentes, duas fontes conciliadas.

Seções do montador (não duplique). Casal: capa, sumário, ritmo, categorias, margem, desempenho*,
Deusa**, recomendações, glossário, notas. Deusa: capa (diz que não há gasto), sumário, desempenho*,
onde o dinheiro está, recomendações, notas. Numeração sequencial, sem buraco.

## Passo 5 — Montar

```bash
S=<scratchpad>; D=${RELATORIOS_DIR:-relatorios/<AAAA-MM>}; nome=relatorio_meio_mes_<AAAA-MM>
python3 .claude/skills/relatorio-meio-mes/scripts/montar_meio_mes.py \
    --dados "$S/dados.json" --narrativa "$S/narrativa_meio_mes.json" --saida "$D/$nome.pdf"
# só se pronto_deusa
python3 .claude/skills/relatorio-meio-mes/scripts/montar_meio_mes.py \
    --dados "$S/dados.json" --narrativa "$S/narrativa_deusa.json" --escopo deusa --saida "$D/${nome}_deusa.pdf"
```

Os dois leem o mesmo JSON: número divergente entre PDFs é erro de narrativa. `--saida *.pdf` entrega
só o PDF; para depurar, `--saida "$S/debug.html"`, nunca em `$D`.

## Passo 6 — Conferir

1. `pdftoppm -png -r 80 -f 1 -l 4 <pdf> <prefixo>` nos **dois** PDFs e olhe: texto cortado, tabela
   estourando, gráfico sobreposto, linha quebrando.
2. Dois ou três números da narrativa contra as tabelas.
3. Ritmo, categorias e margem só do mês corrente; desempenho e Deusa só do mês anterior. É o erro mais provável.
4. Nenhum mês futuro pré-lançado em número ou gráfico.
5. Nada de camada, FGC, vencimento ou reserva de emergência.
6. Deusa: nada somado ao casal, índices não comparados entre si, nenhum número do casal no PDF dela.

Texto errado: corrija a narrativa. Layout ou número errado: `montar_meio_mes.py` ou
`scripts/relatorios/` (afeta também o fechamento — confira os dois). Não entregue PDF que não olhou.

## Encerramento

Caminho dos dois PDFs, data de corte, mês de cada bloco, seções omitidas pelo portão (e se o PDF de
Deusa não foi gerado). Pendências: categorias estouradas, poupança projetada abaixo da meta, base com
menos de 6 meses, `[CONFIRMAR]` que sustentaram recomendação.
