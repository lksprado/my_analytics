<!-- markdownlint-disable MD024 -->
<!--
  Políticas econômicas do domínio FINANÇAS, uma seção `##` por política, a vigente no topo.
  Como ler e como abrir uma nova: `_interpretacao_financas.md`. Política encerrada não se edita.

  `scripts/relatorios/politica.py` lê daqui as linhas `- Início:` / `- Fim:` / `- Status:`, a linha
  `- Postura:` sob `### Gastos` e a tabela sob `### Calibragem`: não renomeie esses títulos nem as
  colunas da tabela. Titular fora da tabela, ou tabela vazia, é calibragem pendente.
-->

# Políticas econômicas

## Preservação

- Status: vigente
- Início: 2026-10-01
- Fim:

### Contexto

Aberta na entrevista de 2026-11-01.

Em cenário de grande incerteza econômica se faz necessário rever posições e redirecionar aportes para absorver alta volatilidade. Foco em dolarização e liquidez.

### Objetivos

| Titular | Objetivo | Prazo | Valor (R$) | Prioridade | Flexibilidade |
| --- | --- | --- | --- | --- | --- |
| Lucas | Acumular patrimônio sem oscilação de preço relevante no extrato | Longo, sem data | | Alta | Alta |
| Jéssica | Acumular patrimônio com liquidez folgada | Longo, sem data | | Alta | Alta |
| Lucas e Jéssica | Manter colchão de liquidez acima da reserva-alvo | Contínuo | | Alta | Baixa |
| Deusa | Preservar o patrimônio para a sucessão; a renda própria cobre a despesa | Indefinido | | Alta | Baixa |

### Leitura do titular

Lucas e Jéssica: risco é oscilação de preço, renda variável e título marcado a
mercado mostrando perda no extrato. Dinheiro travado até o vencimento, concentração e câmbio não
incomodam do mesmo jeito. Diante de uma queda de 20% na parte de crescimento, manteria a posição,
incomodado, e pararia de aportar nela até recuperar. Liquidez acima do mínimo traz tranquilidade e é
desejada, não ineficiência.

Deusa: a carteira é colchão e herança, não fonte de renda; o papel dela é não perder.

Todos: Busca por liquidez, baixo risco e dolarização.

### Restrições

- Renda variável (ações, ETFs, BDRs, FIIs) até 10% da carteira de cada titular, somando todas as
  camadas. Renda variável no exterior conta dentro do teto.
- Renda fixa com marcação a mercado (prefixado e IPCA+ longos) só se levada ao vencimento.
- Sem aporte em cripto, exceto se USDT; a posição em bitcoin existente fica.
- Venda autorizada para trazer a renda variável ao teto. Nos demais desvios rebalanceia-se por
  aporte; venda só com desvio acima de 15 p.p. do alvo.
- Exposição internacional pode ser renda fixa ou caixa em dólar.

### Gastos

- Postura: austeridade

A incerteza pede que a sobra do mês vá para liquidez e dolarização, não para consumo.

- `role` e `diversos`: cortar. Gasto acima da mediana de 6 meses é recomendação de corte com valor,
  não só observação.
- `assinaturas`: revisar. Toda cobrança recorrente sem uso claro é candidata a cancelamento.
- `mercado`: manter o padrão; corte aqui não é objetivo.
- `saude`, `educacao`, `apartamento` e `transporte`: fora de corte.
- Fato previsto em `_fatos_relevantes.md` segue sendo execução de plano, não desvio.

### Calibragem

| Titular | RESERVA | CRESCIMENTO | RENDA | Banda (p.p.) | Aporte (R$/mês) | Exposição internacional | Razão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Lucas | 35% | 60% | 5% | 5 | 4.000 | 30% | `CRESCIMENTO` vira renda fixa de vencimento; `RENDA` cai porque FII oscila; reserva com colchão |
| Jéssica | 60% | 40% | 0% | 5 | 2.000 | 25% | Colchão aceito: a reserva do casal fica perto do dobro da reserva-alvo |
| Deusa | 30% | 65% | 5% | 5 | 3.000 | 25% | Preservar para a sucessão: `CRESCIMENTO` em renda fixa, renda variável abaixo do teto |

### Gatilhos de revisão

- Surge objetivo com prazo (imóvel, filhos, outro desembolso grande).
- Renda do casal muda mais de 20%.
- Deusa passa a precisar da carteira para a despesa.
- Reserva do casal abaixo de 1,5 vez a reserva-alvo.
- Muda a leitura do risco (ex.: queda de 20% passa a ser tolerável).
- Fim da austeridade: o cenário de incerteza que a motivou se desfaz, a juízo de Lucas.

## Acumulação

- Status: encerrada
- Início: 2026-07-25
- Fim: 2026-09-30

### Contexto

Primeira política escrita. Lucas e Jéssica em fase de acumulação com horizonte longo; Deusa
aposentada, com reserva formada e renda própria cobrindo a despesa.

### Objetivos

| Titular | Objetivo | Prazo | Valor (R$) | Prioridade | Flexibilidade |
| --- | --- | --- | --- | --- | --- |
| Lucas | Acumular patrimônio e começar a formar fluxo de caixa antes de precisar dele | Longo | | Alta | Alta |
| Jéssica | Acumulação pura, sem necessidade de fluxo corrente | Longo | | Alta | Alta |
| Deusa | Crescimento a serviço da sucessão | Longo | | Média | Alta |

### Leitura do titular

Não registrada; a política foi escrita só com alvos.

### Restrições

Rebalanceamento por aporte; venda só com desvio acima de 15 p.p. do alvo (alvo 50% autoriza venda
abaixo de 35% ou acima de 65%).

### Gastos

- Postura: neutra

Não registrada; valia o glossário.

### Calibragem

| Titular | RESERVA | CRESCIMENTO | RENDA | Banda (p.p.) | Aporte (R$/mês) | Exposição internacional | Razão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Lucas | 30% | 50% | 20% | 5 | 4.000 | 15% | Horizonte longo; `RENDA` começa a formar fluxo de caixa antes de precisar dele |
| Jéssica | 30% | 70% | 0% | 5 | 2.000 | 15% | Acumulação pura, sem necessidade de fluxo corrente |
| Deusa | 30% | 60% | 10% | 5 | 3.000 | 10% | Aposentada, reserva formada e renda própria cobrindo a despesa; crescimento serve à sucessão |

### Gatilhos de revisão

Não registrados.
