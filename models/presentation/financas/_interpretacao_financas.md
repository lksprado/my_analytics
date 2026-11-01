<!--
  Guia estável de interpretação do domínio FINANÇAS, para quem recomenda (pessoa, skill ou outra IA).
  Muda só quando muda o método, não quando muda a política. A política em si mora em
  `_politicas_financas.md`.
-->

# Como interpretar as finanças da casa

Finanças pessoais não têm resposta única: a mesma carteira é prudente para um objetivo e temerária
para outro. Este guia diz como ler os documentos do domínio e como transformar o que eles dizem em
recomendação, sem trocar o julgamento dos titulares pelo de quem recomenda.

## Onde está cada coisa

| Arquivo | Natureza | O que tem |
| --- | --- | --- |
| `_docs_financas.md` | estável | Glossário (categorias, camadas, ciclo de fatura, procedência, calendário do dado), regras fixas e benchmark |
| `_interpretacao_financas.md` | estável | Este guia |
| `_politicas_financas.md` | mutável | Políticas econômicas datadas: objetivos, leitura dos titulares, postura de gasto, calibragem |
| `_fatos_relevantes.md` | mutável | Eventos datados que explicam variação brusca |

## Hierarquia de autoridade

Quando duas fontes apontam para lados diferentes, vence a de cima:

1. **Regras fixas** (`regras_fixas` em `_docs_financas.md`): limite FGC, reserva-alvo, taxa de
   poupança. Não dependem de política e não se negociam na recomendação.
2. **Objetivos e postura de gasto da política vigente**: o que se quer, para quando, com que
   prioridade, e como a casa deve gastar enquanto isso.
3. **Calibragem aprovada da política vigente**: alocação por camada, banda, aporte, exposição
   internacional. É a tradução numérica dos objetivos, não um fim em si.
4. **Heurísticas do glossário**: por exemplo, `diversos` acima de ~20% da despesa.

## Política vigente

- A vigente para um mês é a de maior `Início` menor ou igual ao último dia desse mês. Relatório de mês
  antigo usa a política daquele mês, não a de hoje.
- Desvio da calibragem conta desde a data de início, sem período de transição: no primeiro mês de
  uma política nova a carteira ainda reflete a antiga, e isso aparece como desvio a corrigir.
- Política sem calibragem aprovada para um titular é **calibragem pendente**: não há alvo para
  comparar. O relatório mostra a alocação atual sem coluna de alvo e as recomendações são
  qualitativas, ancoradas nos objetivos.
- Mês anterior a qualquer política: não há alvo; só leitura qualitativa.

## Como recomendar

- **Do objetivo para o número**: toda recomendação de calibragem diz qual objetivo serve. "Aportar
  em `RESERVA`" sem dizer para qual objetivo não é recomendação.
- **Prioridade e flexibilidade decidem conflitos**: objetivo de prioridade alta e flexibilidade
  baixa vem antes; objetivo flexível cede prazo antes de ceder valor, salvo indicação contrária.
- **Leitura do titular pesa mais que perfil genérico**: o texto em primeira pessoa da política é a
  melhor evidência do apetite ao risco. Não substitua por um perfil de manual ("jovem, então
  agressivo").
- **Uma carteira por vez**: a leitura de um titular não se transporta para outro.

## Postura de gasto

A seção `### Gastos` da política declara uma postura e diretrizes em texto. A postura muda o tom e a
prioridade das recomendações de gasto, nunca os números: mediana de 6 meses, meta de poupança e
reserva-alvo seguem os mesmos.

| Postura | Leitura |
| --- | --- |
| `austeridade` | Nas categorias que as diretrizes mandam cortar, gasto acima da mediana é recomendação ativa de corte, com valor em R$. A margem que "ainda cabe" é teto, não convite. Recomendações de gasto vêm antes das demais no orçamento. A heurística de `diversos` (~20% da despesa) cede à diretriz. |
| `neutra` | Vale o glossário e a meta de poupança; corte só quando a poupança fica abaixo da meta. |
| `expansão` | Gasto acima da mediana nas categorias liberadas não é desvio, desde que a poupança fique na meta. |

Em qualquer postura: `saude` e `educacao` nunca entram em corte, o que está `agendado` não se manda
cortar, e fato previsto em `_fatos_relevantes.md` não é desvio.

## Ambiguidade

- Quando a política não decide um caso, escolha a leitura mais coerente com os objetivos e a
  leitura do titular, siga com ela e registre em `premissas` como `[INTERPRETAÇÃO] <leitura adotada>`.
- Nunca preencha lacuna com regra inventada nem com número que a política não aprovou.
- Valor marcado `[CONFIRMAR]` é usado assim mesmo e sinalizado em `premissas`.

## Limites de quem recomenda

- Recomenda dentro da política vigente. Não altera a política, a calibragem nem os objetivos.
- **Sinaliza revisão** quando um gatilho declarado na política ocorre, quando um fato relevante muda
  objetivo, prazo ou apetite, ou quando o dado contradiz um objetivo (ex.: prazo incompatível com o
  aporte possível). A sinalização é uma recomendação "Revisar política" com o motivo em uma frase, e
  entra no encerramento da skill.

## Abrir uma política nova

1. **Entrevista** com os titulares: contexto da mudança, objetivos (valor, prazo, prioridade,
   flexibilidade), leitura de cada titular sobre risco, restrições, gatilhos de revisão.
2. **Proposta de calibragem**: por titular, alocação por camada, banda, aporte e exposição
   internacional, cada linha com a razão que a liga a um objetivo.
3. **Aprovação** de Lucas. Sem aprovação a política entra com calibragem pendente.
4. **Registro** em `_politicas_financas.md`: a nova sobe para o topo com `Status: vigente`; a
   anterior ganha `Fim` (véspera do novo início) e `Status: encerrada` e não se edita mais.

Qualquer mudança de número aprovado abre política nova, ainda que herde os objetivos: assim cada mês
do histórico aponta para uma única calibragem.
