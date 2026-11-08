# Convenções

## Objetivo

Descrever heurísticas e dinâmicas das finanças pessoais.

## Consumo

### Dinâmica de conciliação de gastos

**Ajuste realizado** — compensação mensal das despesas conjuntas.

Lucas concentra as despesas compartilhadas e Jéssica compensa para que cada um arque com parcela proporcional à renda, já descontadas as despesas individuais de Lucas. Positivo é o que Jéssica transferiu a Lucas no mês.

Não conta como receita ou despesa, saldos de conta corrente já o refletem o ajuste aplicado no fechamento.

---

### Cartão de Crédito

O consumo é concentrado no cartão de crédito de Lucas para acumulação de cashback.

**Ciclo de fatura** — duas datas para o mesmo gasto.

| Campo | O que é |
| --- | --- |
| `mes_debito` | **Mês de competência**, chave de toda análise (DRE, categoria, resultado, poupança). |
| `mes_fatura` | Mês da fatura que cobrou a despesa; só para conciliar com o extrato do cartão. |
| `dia_real` | Dia do calendário em que o gasto ocorreu. |
| `dia_ajustado` | Posição do dia dentro do ciclo de fatura; torna meses comparáveis dia a dia. |

---

## Investimentos

### Camadas de alocação

Consiste no papel que o ativo cumpre na carteira, pela intenção do investidor.

Após o processamento dos extratos, investimentos não classificados serão apresentados em `ativos_sem_classificacao` para classificação manual no Google Sheets para o reprocessamento corrigir.

 Para o relatório estar correto é necessário que essa tabela esteja vazia no momento da confecção.

---

#### `RESERVA`

**Significa**: Garante liquidez e preservação de capital: resgate em até D+1, sem marcação a mercado negativa, para cobrir despesas correntes e emergenciais.

**Instrumentos típicos**: "Caixinhas" e "Cofrinhos" em CDB e RDB de liquidez diária, conta remunerada, saldo em conta

---

#### `RESERVA ESTRATEGICA`

**Significa**: Foco em reserva de valor, mas depende de cenário favorável para ser liquidada e raramente aportada por isso fica fora da alocação-alvo.

**Instrumentos típicos**: Cripto, stablecoins, conta com moeda estrangeira, cashback

---

#### `CRESCIMENTO`

**Significa**: Foco em acumulação de patrimônio para médio-longo prazo, aceitando oscilações; inclui renda fixa longa sujeita a marcação a mercado e ativos no exterior.

**Instrumentos típicos**: Renda fixa em RDB e CDB de vencimento, LCA, LCI; renda variável em ações, fundos, ETFs, títulos prefixados longos.

---

#### `RENDA`

**Significa**: Diversificação e possibilita fluxo de caixa recorrente e previsível para incrementar capacidade de reinvestimentos.

**Instrumentos típicos**:  FIIs, ações pagadoras de dividendos

---

#### `NAO CLASSIFICADO`

**Significa**: Informação faltando, corrigir imediatamente

**Instrumentos típicos**: Não aplicável.

---

## Parâmetros

| Parâmetro | Valor | Aplicação |
| --- | --- | --- |
| Reserva mínima | 6 meses | Lucas e Jéssica |
| Teto da reserva | R$ 100.000 | Lucas e Jéssica |
| Limite FGC por conglomerado | R$ 250.000 | Todos |
| Folga mínima sobre o limite FGC | R$ 50.000 | Todos |
| Taxa de poupança alvo | 35% | Lucas e Jéssica |
| Isenção de IR em venda de ações BR | R$ 20.000 | Por titular, por mês |

### Reserva de emergência

Ativos de alta liquidez servem para garantir:

**Reserva mínima** piso deve cobrir 6 meses da mediana de despesas dos últimos 6 meses de Lucas e Jéssica.

**Reserva ideal** teto de R$100.000 para o casal, excedentes servem para guiar novos aportes. Se a reserva mínima passar do teto, vale a mínima.

---

### FGC

O Limite FGC por conglomerado é de R$ 250.000. Desejável manter folga mínima de R$ 50.000 sobre o limite

---

### Poupança

Taxa de poupança alvo é em torno de 35% da receita líquida de Lucas e Jéssica, violação pode ser explicada em `_fatos_relevantes.md`.

---

### Benchmarks

- Bater o CDI é a meta da carteira global;

- Superar a inflação pessoal (`minha_inflacao`) é a meta do patrimônio líquido;
