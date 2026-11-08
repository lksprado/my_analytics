---
name: relatorio-financas
description: Varre a camada marts do domínio finanças e gera quatro relatórios mensais em PDF — um de investimentos para cada titular (Lucas, Jéssica e Deusa) e um de orçamento do casal (receita, despesa, gastos por categoria e reserva). Use quando o usuário pedir o relatório financeiro do mês, o fechamento mensal, ou o PDF de finanças.
---

# Relatório financeiro mensal (fechamento)

Quatro PDFs sobre o **mês fechado anterior**, escritos como planejador financeiro (orçamento) e
assessor de investimentos (carteiras):

| Arquivo | Escopo | Conteúdo |
| --- | --- | --- |
| `relatorio_orcamento_casal_AAAA-MM.pdf` | `orcamento` | Receita, despesa, resultado, poupança, categorias e natureza, luz, reserva de emergência |
| `relatorio_investimentos_lucas_AAAA-MM.pdf` | `lucas` | Camadas, classe contra o perfil de referência, riscos, aporte, patrimônio, renda passiva |
| `relatorio_investimentos_jessica_AAAA-MM.pdf` | `jessica` | idem |
| `relatorio_investimentos_deusa_AAAA-MM.pdf` | `deusa` | idem, sem patrimônio |

Cada PDF tem no máximo 3 páginas: sem capa, sem glossário, sem lista posição a posição.

- Receita e despesa são do casal: só o orçamento fala de gasto. Não invente despesa individual, nem para Deusa.
- A reserva de emergência é do casal e mora no orçamento; nos individuais de Lucas e Jéssica aparece como
  camada e, quando passa do teto, como excedente que orienta o aporte.

CDI, IPCA e inflação pessoal só aparecem pelo bloco `desempenho` do JSON, sempre com o mês dele
(o último com indexador publicado, que pode ser anterior ao de referência). A variação do patrimônio
inclui aportes e entradas: compara-se o patrimônio com a inflação pessoal, que é a meta do
`_convencoes.md`; nunca se diz que a carteira bateu ou perdeu do CDI. O relatório não fala de ritmo,
projeção ou margem do mês corrente.

Acionamento sob demanda. Para refazer meses em lote sem sessão interativa:
`scripts/gerar_relatorios_financas.sh`.

## Passo 0 — Ler as fontes do domínio

Leia, em `models/presentation/financas/`:

1. `_convencoes.md`: conciliação, ciclo de fatura, camadas de alocação e a tabela de parâmetros
   (reserva mínima e teto, FGC, poupança).
2. `_despesas.md`: o que entra em cada categoria e a natureza dela (essencial ou não, estável ou variável).
3. `_politicas_financas.md`: a política **vigente na data de geração** (maior `Início` até hoje).
   Contexto, objetivos, postura de gasto, perfil de referência por titular e gatilhos de revisão.
4. `_fatos_relevantes.md`: eventos datados que explicam variação brusca.
5. `_perfis_de_investimento.md`: fonte externa datada (carteiras-modelo do mercado). Use a
   taxonomia, a alocação média, as faixas e os instrumentos típicos. O contexto de mercado (Selic,
   Focus) é pano de fundo para o tom, nunca número citado. Se a data do documento tiver mais de
   3 meses, registre em `premissas` que a referência está velha.

Leia também `relatorios/<mês anterior>/narrativa_<escopo>.json` de cada escopo, se existir: são as
recomendações do mês passado, que o Passo 4 acompanha. (Com `RELATORIOS_DIR` customizado, a pasta
irmã do mês anterior.)

O montador lê os mesmos arquivos para os números; nada disso está repetido aqui.

## Como interpretar

### Hierarquia de autoridade

Quando duas fontes apontam para lados diferentes, vence a de cima:

1. **Parâmetros de `_convencoes.md`**: reserva mínima e teto, FGC, poupança alvo. Não se negociam.
2. **Política vigente**: contexto, objetivos, postura de gasto. É o que se quer agora.
3. **Perfil de referência** (`_perfis_de_investimento.md`, perfil que a política aponta): a tradução
   numérica, vinda de fora, do que é uma carteira daquele perfil.
4. **Natureza da categoria** (`_despesas.md`).

Consequências que já se sabe que aparecem:

- **Dólar**: a política pede dolarização e vence a faixa de internacional do perfil. Mesmo assim,
  internacional RF e caixa em dólar contam como proteção; internacional RV conta como risco e entra
  no total de risco contra o perfil.
- **Reserva**: o perfil põe a reserva de emergência fora da alocação; a tabela do perfil já mede a
  carteira sem a camada `RESERVA`.
- O FGC do perfil (por instituição) cede à regra da casa (por conglomerado, com folga).

### Política vigente

- Vale a política vigente **no dia em que o relatório roda**, não a do mês de referência: as
  recomendações olham para o próximo aporte e o próximo mês de gasto.
- Política sem calibragem por camada é o caso normal: a comparação numérica é a do perfil de
  referência. Sem perfil declarado para o titular, a leitura é só qualitativa, ancorada nos objetivos.
- Toda recomendação diz qual objetivo da política ela serve.
- Uma carteira por vez: a leitura de um titular não se transporta para outro.

### Postura de gasto

A postura muda o tom e a prioridade das recomendações de gasto, nunca os números (mediana, meta de
poupança, reserva).

| Postura | Leitura |
| --- | --- |
| `austeridade` | Em categoria não essencial, gasto acima da média de 6 meses é recomendação ativa de corte, com valor em R$. A sobra vai para liquidez e dolarização, não para consumo. Recomendações de gasto vêm antes das demais no orçamento. |
| `neutra` | Vale a meta de poupança; corte só quando a poupança fica abaixo da meta. |
| `expansão` | Gasto acima da média nas categorias não essenciais não é desvio, desde que a poupança fique na meta. |

Em qualquer postura: categoria essencial que sobe se explica, não se manda cortar, e fato previsto
em `_fatos_relevantes.md` não é desvio.

### Ambiguidade e limites

- Quando as fontes não decidem um caso, escolha a leitura mais coerente com os objetivos, siga com
  ela e registre em `premissas` como `[INTERPRETAÇÃO] <leitura adotada>`. Nunca preencha lacuna com
  regra ou número inventado.
- Não recomende ticker, produto ou emissor fora da carteira. Classe ou instrumento genérico do perfil
  serve ("Tesouro IPCA+ curto", "ETF de ouro", "CDB de liquidez diária"); "IVVB11" ou "CDB do banco X
  a 112% do CDI" não.
- Não altere a política. Gatilho de revisão ocorrido, fato relevante que muda objetivo ou dado que
  contradiz um objetivo vira recomendação "Revisar política" com o motivo em uma frase.

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
| `por_titular.<pessoa>.pronto` | carteira no máximo 2 meses atrás, nenhum ativo sem camada e nenhum fundo ou renda variável no exterior sem lastro em `seed_ativos_lastro` | o individual daquele titular |

**Trava: antes de analisar ou escrever qualquer coisa**, leia `meta.prontidao`. Com qualquer
pendência (`pendencias_orcamento` ou `por_titular.<pessoa>.pendencias`), pare e mostre no terminal,
agrupado por escopo:

```text
Portão de prontidão — <AAAA-MM>
  orçamento: ok | bloqueado
    - <pendência>
  lucas: ok | bloqueado
    - <pendência>
  ...
```

Depois pergunte ao usuário (`AskUserQuestion`) o que fazer, nesta ordem de opções:

1. **Corrigir e reextrair** (recomendado quando a pendência é cadastro: camada na planilha ou linha
   na seed). Espere o usuário corrigir, rode o `dbt` que a pendência indica se ele pedir, e volte
   ao Passo 2.
2. **Gerar só o que passou**: os escopos bloqueados ficam para depois.
3. **Forçar tudo**: o montador imprime a tarja e o diagnóstico diz que os valores são parciais.

Sem resposta do usuário (modo não interativo), siga a opção 2. Nunca force por conta própria.

`por_titular.<pessoa>.avisos` (posição que a planilha mostra e a carteira não tem, acima de R$ 1.000)
entra na mesma impressão, marcado "aviso, não bloqueia". Não pergunte por causa de aviso; diga na
narrativa que a carteira daquele titular pode estar subestimada.

### Armadilhas operacionais

- A extração já corta meses posteriores a `mes_ref`; nunca os reintroduza.
- Com `meta.defasagem_carteira_meses > 0`, declare a data de cada número: carteira em
  `meta.mes_carteira`, orçamento em `meta.mes_ref`. No orçamento, a reserva é o único número da carteira.
- `meta.motivos_especiais` não nulo (ex.: aniversário) explica pico em `role` e `diversos`.
- `carteira_referencia.pct_da_base` é sobre a carteira sem `RESERVA` e sem `NAO CLASSIFICADO`; é o
  número que a tabela do perfil mostra. Não confunda com `pct_da_carteira` das camadas.
- Fundos e ETFs têm `veiculo` (ETF, FII) e `lastro` (onde investem) em `posicoes`, vindos de
  `seed_ativos_lastro`; use o lastro para explicar a classe ("ETF de títulos IPCA+"), não o
  `tipo_ativo`, que diz só FUNDO. Fundo ou ETF fora da seed já trava no portão; lastro que parece
  errado vira pendência no encerramento, não correção na narrativa.

## Passo 3 — Analisar

**Orçamento (casal):** taxa de poupança do mês e de 12 meses contra a meta; categorias por
participação e contra a média de 6 meses; essencial × não essencial pela natureza de cada categoria;
fatos relevantes do mês que explicam o desvio e a poupança sem eles (o montador imprime; o valor do
fato é aproximado, serve para ler o padrão); aporte-alvo (meta de poupança sobre a receita de cada um)
contra o resultado do casal; reserva contra mínimo e teto (abaixo do mínimo é prioridade; acima do
teto, o excedente orienta aporte); inflação pessoal do mês de desempenho; luz separando preço
(`preco_kwh`) de consumo (`kwh_dia`). Tom e prioridade seguem a postura de gasto.

**Investimentos (um por titular, contra o perfil de referência):** classe por classe contra média e
faixa do perfil, e o total de risco; exposição em dólar separando RF e RV; camadas; concentração por
instituição e conglomerado; FGC sem folga; vencimentos em 12 meses e destino do principal; **destino
do aporte do mês**, em valor e classe, dizendo qual objetivo serve. Para Lucas e Jéssica, o excedente
da reserva do casal entra como fonte de aporte. A leitura é por classe e camada, não ativo a ativo; só
vencimento e FGC descem ao ativo. Patrimônio contra inflação pessoal no bloco de desempenho.

Rebalanceamento segue `### Rebalanceamento e aporte` da política: corrige-se por aporte, e a venda é
sugerida quando conveniente:

- classe com etiqueta "venda sugerida" (acima do dobro do teto da faixa);
- ações brasileiras dentro da isenção mensal (`Isenção de IR em venda de ações BR` em `_convencoes.md`);
- fato relevante com desembolso próximo que peça caixa;
- outro caso a seu juízo, registrado como `[INTERPRETAÇÃO]`.

Venda primeiro o que mais destoa do perfil (alternativos, internacional RV, ações), em valor por
classe e com o objetivo que serve. O warehouse não tem preço médio: não estime IR sobre o ganho; só
cite a isenção quando a venda for de ações brasileiras.

## Passo 4 — Narrativa

O montador renderiza KPIs, tabelas, gráficos, fatos relevantes e notas. Você escreve só o texto, em
`narrativa_<escopo>.json` no scratchpad, HTML restrito a `<p>` e `<strong>`:

```json
{"sumario": "<p>…</p>", "diagnostico_orcamento": "<p>…</p>", "diagnostico_carteira": "<p>…</p>",
 "diagnostico_riscos": "<p>…</p>", "recomendacoes": [{"titulo": "…", "texto": "…"}], "premissas": ["…"],
 "acompanhamento": [{"recomendacao": "…", "situacao": "seguida|parcial|não seguida|sem dado", "evidencia": "…"}]}
```

| escopo | chaves renderizadas (as demais são ignoradas) |
| --- | --- |
| `orcamento` | `sumario`, `diagnostico_orcamento`, `acompanhamento`, `recomendacoes`, `premissas` |
| `lucas`, `jessica`, `deusa` | `sumario`, `diagnostico_carteira`, `diagnostico_riscos`, `acompanhamento`, `recomendacoes`, `premissas` |

- Número citado confere com o JSON. Não repita número que a tabela ao lado já mostra sem acrescentar leitura.
- `sumario`: até 3 frases.
- Cada diagnóstico: até 3 parágrafos de até 3 frases, cada um aberto por um rótulo em `<strong>`.
  `diagnostico_carteira` e `diagnostico_riscos` saem juntos num bloco só: não repita assunto entre eles.
- No máximo 4 recomendações, cada uma com valor em R$ no título e a razão em uma frase. Orçamento
  recomenda gasto, poupança e reserva; individuais recomendam destino do aporte. Sem repetir entre os dois.
- `acompanhamento`: só com a narrativa do mês anterior lida no Passo 0; uma linha por recomendação
  dela, no máximo 4, com o título resumido. Evidência em uma frase, do dado: no orçamento, o DRE;
  nos individuais, `carteira_referencia_anterior` contra `carteira_referencia`. Variação de classe
  mistura aporte com mercado: "parcial" ou "sem dado" quando não der para separar, nunca "seguida"
  por suposição.
- `premissas`: até 5 itens de uma linha. `[INTERPRETAÇÃO]` adotadas, idade da referência externa e
  limitações do dado. Política vigente, perfil e fatos relevantes o montador já imprime nas notas.

Seções que o montador já produz (não duplique). Orçamento: cabeçalho com KPIs e sumário, resultado em
13 meses, recomendações, categorias com natureza, reserva e energia, leitura, notas com fatos.
Individuais: cabeçalho com KPIs e sumário, camadas (com a reserva do casal para Lucas e Jéssica),
recomendações, perfil de referência, riscos (instituição, FGC, vencimentos, não classificados),
leitura, evolução (patrimônio só de Lucas e Jéssica; proventos) e notas com fatos de patrimônio.

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

`--saida *.pdf` entrega o PDF e grava ao lado `narrativa_<escopo>.json`, que o relatório do mês
seguinte lê para o acompanhamento. Para depurar, `--saida "$S/debug.html"`; nunca grave `.html` em `$D`.
`relatorios/` está no `.gitignore`.

## Passo 6 — Conferir

1. `pdfinfo <pdf>`: no máximo 3 páginas. Passou disso, encurte a narrativa até os limites do Passo 4;
   não mexa no layout para caber.
2. `pdftoppm -png -r 80 <pdf> <prefixo>` e olhe: texto cortado, tabela estourando, gráfico
   sobreposto, título sozinho no pé da página.
3. Confira dois ou três números da narrativa contra as tabelas renderizadas.
4. Nenhum mês futuro em número ou gráfico.
5. Nenhum assunto vazou: individuais sem despesa, orçamento sem posição de carteira, CDI/IPCA só
   datados pelo bloco de desempenho, nenhum ticker recomendado, nenhum IR estimado.

Texto errado: corrija a narrativa. Layout ou número errado: `montar_relatorio.py` ou
`scripts/relatorios/`. Não entregue PDF que não olhou.

## Encerramento

Caminhos dos PDFs, mês de cada bloco, escopos que ficaram de fora pelo portão e pendências por titular:
ativos sem camada, classe de referência suspeita, conglomerados sem folga FGC, classes fora da faixa
do perfil, classes com venda sugerida, excedente ou falta de reserva, avisos de posição possivelmente
faltando, referência externa velha e sinalizações "Revisar política".
