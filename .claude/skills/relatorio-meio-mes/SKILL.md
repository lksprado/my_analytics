---
name: relatorio-meio-mes
description: Gera o relatório de acompanhamento do mês EM ANDAMENTO — ritmo do gasto até hoje, projeção de fechamento, quanto ainda cabe gastar por categoria, mais o desempenho do patrimônio do casal contra CDI e inflação pessoal do mês anterior e uma seção apartada com o patrimônio e a composição dos ativos de Deusa. Use quando o usuário pedir o acompanhamento de meio de mês, como está o gasto do mês, se vai estourar o orçamento, o desempenho contra os benchmarks, ou a análise patrimonial de Deusa fora do fechamento. NÃO é o fechamento mensal — para os quatro PDFs do mês fechado, use relatorio-financas.
---

# Relatório de meio de mês

**Dois PDFs**, com leitores diferentes, onde AAAA-MM é o **mês corrente**:

| Arquivo | Para quem | Conteúdo |
|---|---|---|
| `relatorio_meio_mes_AAAA-MM.pdf` | Lucas e Jéssica | o mês em andamento (ritmo, projeção, margem) + desempenho do casal + a seção patrimonial de Deusa |
| `relatorio_meio_mes_deusa_AAAA-MM.pdf` | Deusa | só a leitura patrimonial dela, com capa e narrativa próprias |

Roda entre os dias 15 e 20. O documento de Deusa **não depende dessa janela** —
ele é todo do mês fechado anterior e não muda com o dia da geração —, mas sai
na mesma passada porque usa a mesma extração.

O documento dela existe separado porque tem outro leitor: no PDF do casal a
leitura patrimonial de Deusa é uma seção entre oito, cercada de despesa que não
é dela, e o arquivo inteiro não é entregável a ela sem expor o orçamento do
casal. **Mesmos blocos, mesmo JSON, outra narrativa** — o montador é um só, com
`--escopo`.

## Por que existe

As fontes do domínio não ficam prontas ao mesmo tempo, e o relatório de
fechamento roda cedo demais para duas coisas:

| Fonte | Quando fica confiável |
|---|---|
| `marts_financas.consumo` (gasto diário) | contínuo, ~D+1 |
| `marts_financas.resultado` (DRE) | primeiros dias do mês seguinte |
| carteira e patrimônio | fecham em cadência própria, costumam vir 1 mês atrás |
| indexadores IPCA/CDI/Selic/inflação pessoal | **IPCA sai ~dia 10**; a planilha é preenchida depois |

Daí as três partes, com recortes de tempo e escopos diferentes:

1. **Mês corrente, casal** (partes 1 a 4) — o gasto diário é o dado mais fresco
   do domínio e, no fechamento, era lido uma vez por mês, quando já não dava
   mais para agir. No dia 17 metade do mês passou e a outra metade ainda é
   decisão.
2. **Mês anterior, casal** (parte 5) — o desempenho contra benchmark, que saiu
   do relatório de fechamento porque lá os indexadores ainda não existem. Isso
   fechava a série um mês antes, em silêncio.
3. **Mês anterior, Deusa** (parte 6) — o patrimônio dela contra os mesmos
   indexadores e a composição dos ativos, em **escopo apartado**. Ela não tem
   despesa lançada no warehouse, então não aparece em nada das partes 1 a 4; e
   o patrimônio dela **nunca é somado ao do casal**. Já foi uma linha a mais no
   gráfico do casal, e ali o leitor comparava duas séries lado a lado como se
   fossem partes de um mesmo total.

**O que este relatório não faz:** alocação por camada, exposição ao FGC,
vencimentos, reserva de emergência, destino do aporte — nem para o casal, nem
para Deusa. Tudo isso é do `relatorio-financas`, que emite um PDF de
investimentos só dela. Não repita nem antecipe. A composição de ativos de Deusa
que **entra** aqui é posição — instituição, disponível contra investido, classe
e indexador —, não política.

**Acionamento: sob demanda.** Não há agendador. Para rodar sem sessão
interativa existe `scripts/gerar_relatorio_meio_mes.sh`.

## Passo 0 — Ler as regras do domínio

**Antes de qualquer análise**, leia `models/marts/financas/_docs_financas.md`.

Aqui as subseções **Fatos relevantes** de cada categoria valem mais do que no
fechamento, porque este relatório dispara alerta sobre mês em curso. Um pico
previsto não é descontrole: em agosto/2026 há troca de carro (~R$ 15.000 em
`transporte`) e a partir de setembro o transplante capilar (~R$ 25.000 em
`saude`). Ler o desvio sem ler o fato produz uma recomendação que manda cortar
o que já estava decidido. Fato usado no diagnóstico entra em `premissas`, com o
status (previsto ou realizado).

Os parâmetros numéricos vêm de `scripts/relatorios/politica.py`, cópia única
compartilhada com o `relatorio-financas`. Se ela e o Markdown discordarem,
**vale o `_docs_financas.md`** — e corrija o Python na mesma passada.

## Passo 1 — Resolver a data

```bash
date +%Y-%m-%d
```

**Rode o comando. Não use a data que você acha que é.**

- O mês de referência é o **corrente**, e o corte é hoje. Isto é o oposto do
  relatório de fechamento, que nunca fala do mês corrente — não confunda os
  dois.
- Se o usuário pedir uma data específica ("como estava dia 17 de junho"), use
  a data dele. A extração é parametrizada por data justamente para isso.
- Antes do dia 10 o portão reprova. Diga isso e ofereça rodar mais tarde, em
  vez de gerar um relatório que o próprio dado não sustenta.

Declare a data resolvida antes de extrair.

## Passo 2 — Extrair os dados

```bash
.claude/skills/relatorio-meio-mes/scripts/extrair_dados.sh <AAAA-MM-DD> <saida.json>
```

Grave o JSON no scratchpad da sessão, não no repositório.

**Todo número do relatório sai desse JSON.** Não consulte o banco por fora nem
recalcule agregados de cabeça — se faltar um corte, acrescente o bloco em
`queries/extrair_meio_mes.sql` e rode de novo.

### Portão de prontidão

Leia `meta.prontidao`. São **três portões independentes**:

| flag | o que exige | bloqueia |
|---|---|---|
| `pronto_ritmo` | hoje ≥ dia 10; último lançamento a ≤ 3 dias; ≥ 7 dias com gasto | partes 1 a 4 |
| `pronto_indicadores` | `marts_financas.indicadores` tem o mês anterior com `ipca` preenchido | parte 5 |
| `pronto_deusa` | `marts_financas.carteira_deusa` tem a posição do mês anterior | parte 6 |

Cada um passa sem os outros — a carteira de Deusa fecha em cadência
independente da publicação do IPCA. Se `pronto_indicadores` ou `pronto_deusa`
reprovar, o montador **omite** a seção correspondente e renumera sozinho — não
force. Se `pronto_ritmo` reprovar, o relatório inteiro perde o sentido: relate
as `pendencias_ritmo` em português claro e não gere, a menos que o usuário
mande.

`meta.meses_de_base` diz quantos meses fechados sustentam a mediana. Menos de 6
é pendência declarada, e precisa ir para `premissas`.

### Armadilhas dos dados — leia antes de interpretar

- **O eixo é `dia_fatura`, não o dia do calendário.** É o `dia_ajustado` da
  planilha, o dia deslocado para a posição que ocupa dentro do ciclo de fatura.
  É o que torna dois meses comparáveis dia a dia. Ao escrever "até o dia 17",
  entenda dia 17 *do ciclo*.
- **Linhas do mês corrente com data futura são fixas pré-agendadas**, não gasto
  realizado. Saem em `agendado` e entram só na projeção. As fixas caem no dia
  25: no dia 17 elas ainda não aconteceram, e o acumulado estar abaixo da
  mediana por causa disso **não** é economia.
- **A projeção é conservadora por construção**:
  `realizado + GREATEST(mediana do que cai após o corte, o já agendado)`. É o
  maior dos dois e não a soma, porque a mediana histórica já embute as fixas —
  somar contaria duas vezes. Declare a regra em `premissas`.
- **A coluna de projeção não soma ao total, e isso está certo.** A mediana de
  uma soma não é a soma das medianas. O montador já imprime a nota e o tamanho
  da diferença. Para julgar o mês inteiro use o total; para julgar uma
  categoria use a linha dela. Nunca reconcilie os dois na narrativa.
- **`transporte` tem sazonalidade forte** (IPVA, seguro, licenciamento).
  Compare contra o mesmo mês do ano anterior antes de chamar de aumento.
- **`total_diversos` é categoria residual.** Alta em `diversos` é abuso de
  compras desnecessárias — a categoria mais indicada para redução.
- **`saude` e `educacao` não entram em sugestão de corte**, por decisão
  registrada no glossário. Elas nem aparecem na seção de margem.
- **A receita do mês corrente já está lançada** (é o salário) e por isso a
  poupança projetada é confiável do lado da receita. A despesa é projeção.
- **O índice de `riqueza` inclui aportes** — não é rentabilidade, e compará-lo
  ao CDI superestima o desempenho da carteira. Responde "o patrimônio cresceu
  mais que a inflação?", não "a carteira bateu o CDI?". Diga isso em vez de
  omitir. Corolário: **salto de dois dígitos num único mês é entrada de recurso
  ou reavaliação de ativo**, nunca rendimento — se o ganho da janela se
  concentra em um ou dois degraus, diga isso, senão o número engana.
- **São dois patrimônios, não um.** `riqueza` traz o do casal e o de Deusa, que
  vem de outra planilha (`marts_financas.patrimonio_deusa`, só o total líquido).
  Carteiras e objetivos distintos: comparam-se ao mesmo benchmark, mas **não se
  somam** e não viram um total. Deusa não tem série em `marts_financas.patrimonio` — o
  nível por conta dela não existe, só o índice.
- **Queda no índice de Deusa não tem causa apurável aqui.** Não há despesa dela
  no warehouse, então não dá para separar resgate planejado de perda de
  mercado. Reporte a queda e diga que não dá para atribuí-la; não escolha uma
  das hipóteses.
- **Os índices não compartilham base** — o do casal começa em 2023-11, o de
  Deusa na primeira variação da planilha dela, os dos indexadores vêm prontos da
  planilha. O montador reindexa tudo no primeiro mês da janela; **cite variação
  dentro da janela, nunca nível absoluto**.
- **`riqueza.comparativo_*`** usa `RICO`/`POBRE` como rótulo interno. Não
  reproduza esses termos no PDF — escreva "acima do CDI" / "abaixo do IPCA".

Só da seção de Deusa:

- **Nunca some o patrimônio dela ao do casal, e nunca compare os dois índices
  entre si.** As séries têm bases diferentes; cada uma só se compara ao
  benchmark, dentro da janela exibida. É a razão de ela ter seção própria.
- **Não há despesa de Deusa no warehouse.** Uma queda no patrimônio dela não
  pode ser atribuída a resgate nem a perda de mercado — o dado não separa os
  dois. Diga que não separa; não escolha uma hipótese.
- **Duas fontes, dois totais.** Nível e composição vêm de `carteira_deusa`
  (grão de ativo); o índice vem da planilha de patrimônio, via `riqueza`. Em
  07/2026 diferiam em R$ 2, em 12/2024 em R$ 60 mil. `deusa_conciliacao` traz
  os dois e a seção imprime a diferença — quando a variação do mês no KPI
  discordar da variação do índice, é daí que vem, e não de duas realidades.
- **«Sem indexador» é lacuna de cadastro antes de ser exposição.** Em 07/2026
  são R$ 311 mil, dos quais R$ 202 mil de renda fixa com taxa contratada e
  campo vazio na origem. Use `valor_renda_fixa` para separar os dois; nunca
  reporte a linha inteira como exposição sem indexador. O indexador `TIR` sobre
  conta corrente é do mesmo tipo de problema: rótulo herdado da planilha.
- **Concentração por instituição é posição, não risco.** O teto do FGC e a
  exposição por emissor são do relatório de fechamento. Cite o percentual e
  aponte para lá.
- **A fronteira disponível/investido é a classe `DISPONIBILIDADE`.**
  `carteira_deusa_agregada.total_disponibilidades` já usou um corte ligeiramente
  diferente (R$ 259 a menos em 07/2026, com total geral idêntico); desde que
  `carteira_agregada` passou a cortar por `classe_ativo`, os dois concordam. A
  seção continua lendo o grão de ativo, que é de onde saem a classe e a quebra
  por instituição.

## Passo 3 — Analisar

Você é o planejador financeiro do casal olhando um mês que ainda dá para
mudar. A pergunta não é "como foi", é **"o que fazer nos dias que restam"**.

- **Ritmo**: o acumulado está dentro da faixa dos seis meses fechados no mesmo
  dia do ciclo? Se saiu, quando saiu e por quê.
- **Categorias**: quais projeções destoam da mediana do mês cheio, e o quanto
  disso já está comprometido (`agendado`) contra o quanto ainda é decisão.
- **Margem**: quanto ainda cabe em `role`, `diversos` e `mercado` para fechar
  dentro do padrão e para bater a meta de poupança. É a seção que justifica o
  relatório existir no dia 17 e não no dia 30 — priorize-a.
- **Desempenho** (só se `pronto_indicadores`): patrimônio **do casal** contra o
  CDI e contra a inflação pessoal, separadamente, sempre com a ressalva de que
  o índice inclui aportes. Olhe também os últimos meses isolados, não só a
  janela inteira: uma sequência de queda é o achado que a variação ponta a
  ponta esconde.
- **Deusa** (só se `pronto_deusa`): o índice dela contra os mesmos benchmarks,
  com a mesma ressalva; **quanto está parado em conta e como isso evoluiu** — a
  única leitura acionável da seção; a rotação entre classes de ativo no mês; e
  o que sobra de variação depois de descontada a rotação, que é justamente o
  pedaço que o dado não explica e precisa ser apurado fora do relatório.

Regras de conduta:
- Recomendação sem número é opinião. Diga o valor em reais e o prazo.
- Não recomende cortar o que já está comprometido — `agendado` não é decisão.
- Quando os dados não sustentarem uma conclusão, diga que não sustentam.

## Passo 4 — Escrever a narrativa

**Você não escreve HTML.** `scripts/montar_meio_mes.py` renderiza KPIs, tabelas
e gráficos direto do JSON. Você escreve **duas** narrativas no scratchpad, uma
por documento.

#### `narrativa_meio_mes.json` — o do casal

```json
{
  "sumario": "<p>…</p>",
  "diagnostico_ritmo": "<p>…</p>",
  "diagnostico_categorias": "<p>…</p>",
  "diagnostico_desempenho": "<p>…</p>",
  "diagnostico_deusa": "<p>…</p>",
  "recomendacoes": [{"titulo": "…", "texto": "…"}],
  "premissas": ["…"]
}
```

Todas as chaves são opcionais; o conteúdo é HTML restrito a `<p>` e `<strong>`.
`diagnostico_desempenho` só é renderizada se `pronto_indicadores`, e
`diagnostico_deusa` só se `pronto_deusa` — se o portão reprovou, não a
escreva.

#### `narrativa_deusa.json` — o dela

```json
{
  "sumario": "<p>…</p>",
  "diagnostico_desempenho": "<p>…</p>",
  "diagnostico_ativos": "<p>…</p>",
  "recomendacoes": [{"titulo": "…", "texto": "…"}],
  "premissas": ["…"]
}
```

Só é escrita se `pronto_deusa`. **Não é recorte da outra**: o leitor é ela, o
assunto é só o patrimônio dela, e o texto pode ser mais longo porque não
compete com sete outras seções. Nada de gasto, orçamento, projeção ou número do
casal — nem para comparar. As recomendações são as ações que dependem dela ou
da planilha dela; no máximo 4.

Sobre o texto dos dois:

- Números citados têm que bater com os que o montador renderiza. Confira contra
  o JSON, não de memória.
- No máximo 6 recomendações no do casal, 4 no dela, cada uma com valor em R$ e
  prazo.
- Em `premissas`, liste: a regra da projeção, quantos meses fechados
  sustentaram a mediana, qualquer `[CONFIRMAR]` do glossário que você usou, e
  os fatos relevantes que explicaram um desvio. No dela, as quatro premissas
  estruturais — sem despesa lançada, índice com aporte, bases diferentes, duas
  fontes conciliadas — são obrigatórias.

### O que o montador já produz sozinho

Não peça para escrever, não duplique na narrativa:

| # | Seção | Conteúdo |
|---|---|---|
| — | Capa | Com a nota de que a última seção fala do mês anterior |
| 1 | Sumário — gasto até o corte, projeção, poupança projetada, dias restantes + `sumario` |
| 2 | Ritmo do mês — acumulado diário contra faixa e mediana + `diagnostico_ritmo` |
| 3 | Categorias — realizado, agendado, projeção, desvio + `diagnostico_categorias` |
| 4 | Margem disponível — teto de despesa e folga por categoria comprimível |
| 5 | Desempenho do casal no mês anterior — KPIs de variação na janela, séries reindexadas + `diagnostico_desempenho` — **só se `pronto_indicadores`** |
| 6 | Patrimônio e ativos de Deusa no mês anterior — nível, índice contra benchmark, disponível contra investido, composição por instituição, classe e indexador, conciliação entre as duas fontes + `diagnostico_deusa` — **só se `pronto_deusa`** |
| 7 | Recomendações — a partir de `recomendacoes[]` |
| 8 | Glossário de categorias de gasto |
| — | Notas e procedência, com as `premissas[]` |

A numeração é sequencial: sem a 5, sem a 6, ou sem as duas, as seguintes sobem.
Não pode haver buraco.

E no documento de Deusa (`--escopo deusa`):

| # | Seção | Conteúdo |
|---|---|---|
| — | Capa | Diz de saída que **não há gasto** na leitura, e por quê |
| 1 | Sumário — nível, variação no mês, investido, parado em conta + `sumario` |
| 2 | Desempenho — índice contra CDI, IPCA e inflação pessoal + `diagnostico_desempenho` |
| 3 | Onde o dinheiro está — disponível contra investido, instituição, classe, indexador, conciliação + `diagnostico_ativos` |
| 4 | Recomendações — a partir de `recomendacoes[]` |
| — | Notas e procedência, com as `premissas[]` |

Este documento **não tem portão de ritmo**: `pronto_ritmo` é do casal e reprová-lo
não diz nada sobre o patrimônio dela. Ele depende de `pronto_deusa` e, para a
seção 2, de `pronto_indicadores`.

## Passo 5 — Montar

```bash
S=<scratchpad>
D=${RELATORIOS_DIR:-relatorios/<AAAA-MM>}
nome=relatorio_meio_mes_<AAAA-MM>

python3 .claude/skills/relatorio-meio-mes/scripts/montar_meio_mes.py \
    --dados "$S/dados.json" --narrativa "$S/narrativa_meio_mes.json" \
    --saida "$D/$nome.pdf"

# só se pronto_deusa
python3 .claude/skills/relatorio-meio-mes/scripts/montar_meio_mes.py \
    --dados "$S/dados.json" --narrativa "$S/narrativa_deusa.json" \
    --escopo deusa --saida "$D/${nome}_deusa.pdf"
```

Os dois leem o **mesmo** JSON de dados: se um número diverge entre os PDFs, o
erro está na narrativa, não na extração.

**Um comando, um arquivo.** `--saida` terminando em `.pdf` monta o HTML num
temporário, converte e descarta o intermediário: o diretório de entrega recebe
só o PDF. Não chame `html_para_pdf.sh` à mão e **não grave `.html` em `$D`** —
o HTML nunca foi produto, era passo intermediário à vista.

Para depurar a marcação, troque a extensão: `--saida "$S/debug.html"` grava só
o HTML, sem converter, e no scratchpad — nunca no diretório de entrega.

Destino padrão: `relatorios/AAAA-MM/` na raiz (fora do git). Respeite
`RELATORIOS_DIR` se estiver definida.

## Passo 6 — Conferir antes de entregar

Obrigatório, não opcional:

1. Converta as páginas em imagem e **olhe**:
   ```bash
   pdftoppm -png -r 80 -f 1 -l 4 <arquivo.pdf> <prefixo>
   ```
   Procure texto cortado, tabela estourando a margem, gráfico sobreposto,
   rótulo colidindo, linha de tabela quebrando em duas.
2. Confira dois ou três números da sua narrativa contra as tabelas renderizadas.
3. **Nenhum número das partes 1 a 4 pode ser do mês anterior, e nenhum das
   partes 5 e 6 pode ser do mês corrente.** É o erro mais provável deste
   relatório.
4. Verifique que nenhum mês futuro entrou em número ou gráfico — setembro
   existe na base como pré-lançado.
5. Confirme que o relatório não fala de camada, FGC, vencimento nem reserva de
   emergência — nem na seção do casal, nem na de Deusa. Isso é do fechamento.
6. A numeração das seções não pode ter buraco.
7. Na seção de Deusa, confirme que nenhum número dela foi somado a número do
   casal e que os dois índices não foram comparados entre si.
8. **Olhe o PDF dela também** — os dois documentos, não só o do casal. No dela,
   confirme que não sobrou nenhum número do orçamento do casal e que os valores
   que aparecem nos dois batem entre si.

Se o texto estiver errado, corrija a narrativa; se o layout ou um número
renderizado estiver errado, corrija `montar_meio_mes.py` ou
`scripts/relatorios/relatorio.css`. **Mexer em `scripts/relatorios/` afeta
também o relatório de fechamento** — confira os dois. Nos dois casos, monte e
converta de novo. Não entregue um PDF que você não olhou.

## Encerramento

Informe o caminho **dos dois PDFs**, a data de corte, o mês de cada bloco, e
diga explicitamente se a seção de desempenho ou a de Deusa ficaram de fora por
causa do portão — e, se `pronto_deusa` reprovou, que o PDF dela não foi
gerado.
Liste as pendências que apareceram — categorias já estouradas, poupança
projetada abaixo da meta, base de comparação com menos de 6 meses, premissas
`[CONFIRMAR]` que sustentaram alguma recomendação.
