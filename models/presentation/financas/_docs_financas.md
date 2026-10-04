{#
  Regras de interpretação do domínio FINANÇAS. Fonte única: categorias de gasto, camadas de
  investimento, política de investimento e armadilhas de leitura do dado.

  Quem lê: `dbt docs` (via `doc()` no `_schema.yml`), as skills `/relatorio-financas` e
  `/relatorio-meio-mes`, e `scripts/relatorios/politica.py`, que extrai daqui os parâmetros e o
  glossário dos PDFs. Por isso não renomeie os títulos `###` nem as colunas das tabelas da
  política, e mantenha as linhas `Entra:` / `Não entra:` e `` `CAMADA` — `` em uma linha só.
  Fato novo é uma linha em `fatos_relevantes`; revise a tabela a cada fechamento. #}

{% docs fatos_relevantes %}

**Fatos relevantes** — eventos datados, fora da rotina, que explicam variação brusca e não estão no dado.

| Período | Categoria | Fato | Valor (R$) | Status |
| --- | --- | --- | --- | --- |
| 05/2026 | educacao | Festa do Livro UNESP, 50% de desconto | ~900 | realizado |
| 08/2026 | role, diversos | Viagem a Ouro Preto (06 a 11/08) | ~15.000 | realizado |
| 09/2026 | saude | Transplante capilar de Lucas, parcela 1/2 | 11.000 | realizado |
| 10/2026 | saude | Transplante capilar de Lucas, parcela 2/2 | 11.000 | realizado |
| 10-11/2026 | transporte | Troca de carro | ~15.000 | previsto |

- Status é `previsto` ou `realizado`; quando o previsto acontece, troque o status e anote o valor efetivo.
- Fato muda a leitura, não o número: nada sai de média, mediana ou reserva-alvo. Desvio até o valor
  declarado é execução de plano; só o excedente pede explicação.
- Fato pago com a `RESERVA` de alguém: a calibragem da carteira usa a reserva menos o compromisso, e a
  queda no mês da saída não é desenquadramento.

{% enddocs %}

{% docs categoria_mercado %}

**Mercado** — abastecimento da casa.

Entra: supermercado, hortifruti, feira, marmitas fit, açougue, peixaria, padaria (compra de despensa), bebidas para consumo em casa, produtos de limpeza, higiene pessoal e itens domésticos não duráveis.

Não entra: refeição fora de casa ou delivery (→ `role`), farmácia (→ `saude`), utensílios, móveis e eletrodomésticos (→ `apartamento` / `diversos`).

Natureza: variável, essencial. Principal despesa compressível; variação mês a mês costuma ser volume de compra, não preço.

{% enddocs %}

{% docs categoria_diversos %}

**Diversos** — categoria residual.

Entra: vestuário e calçado, presentes, eletrônicos e acessórios pessoais, objetos domésticos, imprevistos, clube de tiro, charutos, salão de beleza e o que não couber nas demais.

Não entra: nada que tenha categoria própria.

Natureza: variável, discricionário. Acima de ~20% da despesa do mês indica abuso de compras desnecessárias e é onde o relatório concentra as sugestões de corte. Gasto que aparece aqui todo mês merece categoria própria. `fl_data_especial` e `fl_mes_especial` explicam picos.

{% enddocs %}

{% docs categoria_assinaturas %}

**Assinaturas** — serviços recorrentes de cobrança automática.

Entra: streaming de vídeo e música, nuvem, licenças de software, telefonia móvel, academia e clubes com mensalidade, jornais e revistas.

Não entra: internet fixa (→ `apartamento`), plano de saúde (→ `saude`), mensalidade de curso (→ `educacao`).

Natureza: fixa, discricionário. O corte mais fácil: cancelar é uma decisão só, com efeito permanente.

{% enddocs %}

{% docs categoria_role %}

**Rolê** — lazer e consumo fora de casa.

Entra: bares e restaurantes, delivery e aplicativos de comida, cafés, cinema, shows, eventos, viagens (hospedagem, aluguel de veículo, passeios), compras de mercado só para eventos e hobbies.

Não entra: transporte para chegar ao rolê (→ `transporte`), exceto aluguel de veículo.

Natureza: variável, discricionário. O gasto que mais depende de escolha no dia a dia e o primeiro a rever quando a poupança fica abaixo da meta. `fl_data_especial` e `fl_mes_especial` explicam picos.

{% enddocs %}

{% docs categoria_transporte %}

**Transporte** — deslocamento.

Entra: combustível, aplicativos de transporte, transporte público, estacionamento, pedágio, manutenção e revisão, seguro, IPVA e licenciamento.

Não entra: viagem de lazer com hospedagem (→ `role`).

Natureza: mista. Seguro, IPVA e licenciamento concentram-se em poucos meses: compare com o mesmo mês do ano anterior antes de chamar pico de descontrole.

{% enddocs %}

{% docs categoria_apartamento %}

**Apartamento** — moradia e manutenção.

Entra: condomínio, IPTU, energia elétrica, internet fixa, móveis, reformas e reparos.

Não entra: produtos de limpeza e consumo da casa (→ `mercado`).

Natureza: fixa, essencial; é o piso do orçamento. Móveis e reformas são pontuais e se leem à parte. O mart `luz` detalha a energia (kWh, preço por kWh) e é parcela de `apartamento`: nunca some os dois.

{% enddocs %}

{% docs categoria_saude %}

**Saúde** — saúde física e mental.

Entra: plano de saúde, consultas, exames, procedimentos, odontologia, terapia, farmácia e medicamentos.

Não entra: academia (→ `assinaturas`).

Natureza: mista, não compressível. Nunca entra em sugestão de corte: quando sobe, o relatório reporta e explica.

{% enddocs %}

{% docs categoria_educacao %}

**Educação** — formação e desenvolvimento.

Entra: cursos, graduação e pós-graduação, certificações, livros, material didático e plataformas de ensino.

Não entra: plataforma de conteúdo genérico (→ `assinaturas`).

Natureza: variável. Investimento em capital humano: nunca entra em sugestão de corte.

{% enddocs %}

{% docs ajuste %}

**Ajuste realizado** — compensação mensal das despesas conjuntas.

Lucas paga as despesas compartilhadas e Jéssica compensa para que cada um arque com parcela proporcional à renda, já descontadas as despesas individuais de Lucas. Positivo é o que Jéssica transferiu a Lucas no mês.

Fica fora de `total_receita` e `total_despesas`: somá-lo à receita conta o mesmo dinheiro duas vezes. Os saldos de conta corrente já o refletem.

{% enddocs %}

{% docs ciclo_fatura %}

**Ciclo de fatura** — duas datas para o mesmo gasto.

| Campo | O que é |
| --- | --- |
| `mes_debito` | **Mês de competência**, chave de toda análise (DRE, categoria, resultado, poupança). |
| `mes_fatura` | Mês da fatura que cobrou a despesa; só para conciliar com o extrato do cartão. |
| `dia_real` | Dia do calendário em que o gasto ocorreu. |
| `dia_ajustado` | Posição do dia dentro do ciclo de fatura; torna meses comparáveis dia a dia. |

`dia_real` e `dia_ajustado` chegam prontos da planilha (`raw.luc_contas`, `raw.jsc_contas`). Para mudar a regra do ciclo, edite a planilha, não os modelos.

{% enddocs %}

{% docs camada_investimento %}

**Camada de alocação** — o papel que o ativo cumpre na carteira, pela intenção do investidor (o que o ativo é fica em `tipo_ativo`).

Lucas classifica à mão na aba `classificacao` da planilha; o mart `carteira` lê via `stg_carteira_classificacao` por `pessoa + codigo_ativo + instituicao`. Posição nova nasce `NAO CLASSIFICADO`, inclusive saldo em conta; nenhuma camada é inferida. A classificação é estado atual: reclassificar reescreve a série inteira.

| Camada | Objetivo | Horizonte | Instrumentos típicos |
| --- | --- | --- | --- |
| `RESERVA` | Liquidez e preservação de capital | D+0 a D+1 | CDB e RDB de liquidez diária, conta remunerada, saldo em conta |
| `RESERVA ESTRATEGICA` | Reserva de valor | Indefinido | Cripto, moeda estrangeira, cashback |
| `CRESCIMENTO` | Acumulação, aceita volatilidade | 5 anos ou mais | RDB de vencimento, CDB, LCA, LCI, ações, ETFs, BDRs, fundos de ações, prefixado e IPCA+ longos |
| `RENDA` | Fluxo de caixa recorrente | Indefinido | FIIs, ações pagadoras de dividendos |
| `NAO CLASSIFICADO` | — | — | Default a regularizar |

`RESERVA` — liquidez e preservação de capital: resgate em até D+1, sem marcação a mercado negativa, para cobrir despesa e não para carregar o papel até o vencimento.

A intenção decide os casos ambíguos: CDB de 3 anos com liquidez D+1 levado ao vencimento é `CRESCIMENTO`. O tamanho da reserva é em meses de despesa (ver `politica_investimentos`), não em percentual da carteira.

`RESERVA ESTRATEGICA` — reserva de valor em cripto, moeda estrangeira e cashback: líquida, mas depende de cenário favorável para ser liquidada e não recebe aporte, por isso fica fora da alocação-alvo.

`CRESCIMENTO` — acumulação de patrimônio em cinco anos ou mais, aceitando perda temporária; inclui renda fixa longa sujeita a marcação a mercado e ativos no exterior, mesmo os que pagam dividendos.

`RENDA` — fluxo de caixa recorrente e previsível: qualifica a regularidade do pagamento, não o retorno total nem o prazo; na sobreposição com crescimento, decide a intenção.

`NAO CLASSIFICADO` — ativo sem camada atribuída na planilha: pendência de classificação, não alocação.

Um ativo cai em `NAO CLASSIFICADO` quando é novo ou quando a chave mudou (`pessoa`, `ativo`, `classe_ativo`, `tipo_ativo`, `instituicao`); descrição de renda fixa costuma mudar e quebrar o vínculo. No relatório, vira item de ação.

{% enddocs %}

{% docs politica_investimentos %}

**Política de investimento** — parâmetros que transformam o diagnóstico da carteira em recomendação de aporte.

### Aporte mensal estimado

| Pessoa | Aporte alvo (R$/mês) | Origem |
| --- | --- | --- |
| Lucas | 4.000 | Resultado mensal (receita - despesa) |
| Jéssica | 2.000 | Resultado mensal (receita - despesa) |
| Deusa | 3.000 | Renda própria |

O aporte efetivo é o resultado do mart `resultado`; o alvo mede aderência, e quando o resultado fica abaixo o relatório aponta a categoria que explica a diferença.

### Alocação-alvo por camada

| Pessoa | RESERVA | CRESCIMENTO | RENDA | Razão |
| --- | --- | --- | --- | --- |
| Lucas | 30% | 50% | 20% | Horizonte longo; `RENDA` começa a formar fluxo de caixa antes de precisar dele |
| Jéssica | 30% | 70% | 0% | Acumulação pura, sem necessidade de fluxo corrente |
| Deusa | 30% | 60% | 10% | Aposentada, reserva formada e renda própria cobrindo a despesa; crescimento serve à sucessão |

Base: carteira sem `RESERVA ESTRATEGICA` e `NAO CLASSIFICADO`, que são reportadas à parte em reais e em % da carteira total. Fora da banda, rebalanceia-se por aporte; venda só com desvio acima de 15 p.p. do alvo (alvo 50% autoriza venda abaixo de 35% ou acima de 65%).

### Metas e limites

Reserva-alvo = o maior entre N × mediana da despesa total dos últimos 6 meses fechados e o piso da tabela abaixo. Mediana para que um mês atípico não infle a meta; meses futuros pré-lançados não entram.

| Pessoa | N (meses) | Base de despesa |
| --- | --- | --- |
| Lucas e Jéssica | 6 | Despesa do casal, em conjunto |
| Deusa | 12 | Sem despesa no warehouse: na prática vale o piso |

### Demais parâmetros

| Parâmetro | Valor | Aplicação |
| --- | --- | --- |
| Piso da reserva-alvo | R$ 100.000 | Todos |
| Banda de tolerância da alocação | 5 p.p. | Todos |
| Limite FGC por conglomerado | R$ 250.000 | Todos |
| Folga mínima sobre o limite FGC | R$ 50.000 | Todos; limiar dos marts `risco_fgc_*` |
| Exposição internacional alvo | 15% da carteira | Lucas e Jéssica |
| Exposição internacional alvo | 10% da carteira | Deusa |
| Taxa de poupança alvo | 35% da receita líquida | Lucas e Jéssica |

### Benchmark

Bater o CDI é a meta da carteira; bater a inflação pessoal (`minha_inflacao`) é a meta do patrimônio. As duas saem do mart `riqueza` e são reportadas separadamente.

`riqueza` traz o patrimônio do casal (com abertura de Lucas e Jéssica) e o de Deusa, que vem de outra planilha via `stg_patrimonio_deusa`, só com o total líquido. Mesmo benchmark, carteiras distintas: **nunca some os dois** nem compare um índice com o outro.

Armadilhas, em ordem de importância:

1. **O índice inclui aporte**: responde "o patrimônio cresceu mais que a inflação?", não "a carteira bateu o CDI?". Salto de dois dígitos num mês é entrada de recurso ou reavaliação, não retorno.
2. **As séries não compartilham base** (casal desde 2023-11, Deusa desde a primeira variação da planilha dela, indexadores com base própria): compare só variação dentro da janela, reindexada no primeiro mês exibido.
3. **Queda no índice de Deusa não tem causa apurável**: sem despesa dela no warehouse, resgate e perda de mercado se confundem. Reporte sem atribuir; a composição da carteira separa só a rotação entre classes.
4. **O nível de Deusa tem duas fontes**: o índice vem da planilha de patrimônio e a composição de `carteira_deusa`. Os totais quase sempre batem, mas podem divergir; quem mostra os dois imprime a diferença. `investimentos_faltantes_identificados` aponta o que falta cadastrar na seed.

{% enddocs %}

{% docs calendario_dados %}

**Calendário do dado** — quando cada fonte fica confiável. Primeiro lugar a consultar quando um número parece faltar.

| Fonte | Grão | Quando fica confiável | Por quê |
| --- | --- | --- | --- |
| `consumo` | **diário** | contínuo, ~D+1 | Lançado à mão na planilha, quase todo dia |
| `resultado` | mensal | primeiros dias do mês seguinte | Fecha quando o último lançamento do mês entra |
| `luz` | mensal | com a chegada da fatura | |
| `patrimonio_mom` | mensal | fechamento manual da planilha | |
| `carteira_*`, `dividendos` | mensal | cadência própria da B3 e da Avenue | Costuma vir **1 mês atrás** do DRE; `defasagem_carteira_meses` reporta |
| `indicadores`, `riqueza` | mensal | **~dia 10 do mês seguinte, ou depois** | O IPCA sai ~dia 10 e só então é digitado na planilha |

1. **Nos primeiros dias do mês não há benchmark do mês anterior.** `riqueza` faz `INNER JOIN` com os indexadores e o mês some; `indicadores` mantém a linha com `NULL`.
2. **O gasto diário é o dado mais fresco**: lido só no fechamento, chega quando já não dá para agir.
3. **Meses futuros existem na base**: `resultado` e `consumo` trazem as fixas pré-agendadas (dia 25). Nunca entram em média, mediana ou diagnóstico; no mês em andamento são dinheiro já comprometido.

{% enddocs %}

{% docs fonte_dado %}

**Procedência da linha** — de qual trilha veio o valor da posição.

Relatório e seed se juntam em `int_investimentos_consolidados`; os saldos da planilha entram direto na `carteira`.

| Valor | Trilha | Origem |
| --- | --- | --- |
| `RELATORIO B3` | Relatório (`int_relatorio_*` → `int_relatorio_unificado`) | Relatório da B3 (CEI) |
| `RELATORIO AVENUE` | Relatório | Extrato da Avenue, inclusive o caixa em conta |
| `SEED` | `int_investimentos_faltantes_unificados` | `seed_investimentos_faltantes_*`, produto real que nenhum relatório traz |
| `GOOGLE SHEETS` | `stg_patrimonio`, `stg_patrimonio_deusa` → CTE `saldos` | Conta corrente, cashback, Wise e bitcoin declarados na planilha |

Os investimentos declarados na planilha (`int_planilha_investimentos_selecionados`) não entram na carteira: servem para `investimentos_faltantes_identificados` mostrar o que falta na seed.

- `SEED` e `GOOGLE SHEETS` não se atualizam sozinhos e envelhecem em silêncio.
- Mês sem `RELATORIO B3` ou `RELATORIO AVENUE` é extração que não rodou, não resgate.
- Em `int_relatorio_renda_variavel` a coluna está no `GROUP BY`; se B3 e Avenue um dia custodiarem o mesmo ativo do mesmo titular, a posição aparece em duas linhas.

{% enddocs %}
