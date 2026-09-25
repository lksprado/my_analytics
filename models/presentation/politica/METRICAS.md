# Métricas do domínio política

Definição formal de cada métrica, nos campos do PRD (§3.4). O termo "votos com posição" quer dizer SIM, NÃO ou OBSTRUÇÃO.

## governismo_pct_modelo

| Campo | Definição |
| --- | --- |
| Definição | Percentual de votos do parlamentar que coincidem com a orientação do Governo |
| Fórmula | `100 × qt_votos_alinhados_governo / qt_votos_governismo` |
| Grão | Parlamentar × período (`parlamentar_*`), partido ou bancada (`comportamento_*`) |
| Numerador | Votos com posição iguais à orientação do Governo (`fl_seguiu_governo = 1`) |
| Denominador | Votos com posição em votações nominais abertas com orientação SIM, NÃO ou OBSTRUÇÃO do Governo, inclusive em comissões |
| População elegível | Parlamentares com ao menos um voto no denominador; sem mínimo de votos |
| Período | Data da votação |
| NULL | Nulo sem voto no denominador |
| Ausência | Fica fora; aparece em `participacao_pct` |
| Abstenção | Fica fora do denominador |
| Obstrução | Conta como posição; alinha só com orientação de obstrução |
| Empate | Não se aplica |
| Fonte | Orientação da liderança GOVERNO nos endpoints de orientação de cada casa; voto registrado |
| Limitações | Senado só tem orientação desde 10/2018. Metodologia diferente da do Radar, que conta abstenção e falta como não alinhadas |

## participacao_pct

| Campo | Definição |
| --- | --- |
| Definição | Percentual das votações elegíveis ao governismo em que o parlamentar votou com posição |
| Fórmula | `100 × qt_votacoes_participadas / qt_votacoes_elegiveis` |
| Grão | Parlamentar × período |
| Numerador | Votações elegíveis com voto SIM, NÃO ou OBSTRUÇÃO do parlamentar |
| Denominador | Votações nominais abertas do Plenário, orientadas pelo Governo, em que o parlamentar estava em exercício |
| População elegível | Parlamentares em exercício no Plenário no período |
| Período | Data da votação |
| NULL | Nulo sem votação elegível |
| Ausência | Senado: registro de ausência da origem. Câmara: ausência inferida, porque a API só lista quem votou; o deputado é tido em exercício entre o primeiro e o último voto na legislatura |
| Abstenção | Conta como não participação |
| Empate | Não se aplica |
| Fonte | Votos registrados e lista de presença de cada votação |
| Limitações | Só Plenário: a composição das comissões não é extraída. A regra da Câmara não enxerga ausência antes do primeiro ou depois do último voto |

## presenca_pct

| Campo | Definição |
| --- | --- |
| Definição | Percentual das votações nominais do Plenário em que o parlamentar esteve presente |
| Fórmula | `100 × qt_presencas / votações com presença informada` |
| Grão | Parlamentar × período |
| Numerador | Registros com `fl_presente = 1`: voto, voto secreto, presidência, presença sem voto |
| Denominador | Votações nominais do Plenário em exercício com presença informada |
| NULL | Nulo sem votação elegível; registros sem informação ficam fora do denominador |
| Ausência | Justificada e não justificada (Senado) e inferida (Câmara) contam como ausência |
| Fonte e limitações | As mesmas de `participacao_pct` |

## disciplina_pct e disciplina_bancada_pct

| Campo | Definição |
| --- | --- |
| Definição | Percentual de votos que seguem a orientação do próprio partido (ou da federação ou bloco do partido) |
| Fórmula | `100 × qt_votos_disciplinados / qt_votos_disciplina` |
| Numerador | Votos com posição iguais à orientação da liderança |
| Denominador | Votos com posição em votações em que a liderança orientou SIM, NÃO ou OBSTRUÇÃO |
| Partido | A liderança é a entidade partidária, não a sigla (PR orienta o PL) |
| Bancada | Federação antes de bloco, conforme `seed_bancadas_composicao` |
| NULL | Nulo sem orientação da liderança |
| Limitações | Desde 2023 os partidos federados só orientam como federação: a disciplina deles aparece em `disciplina_bancada_pct` |

## votos_vencedores_pct

| Campo | Definição |
| --- | --- |
| Definição | Percentual de votos SIM ou NÃO do lado vencedor |
| Fórmula | `100 × qt_votos_vencedores / qt_votos_com_resultado` |
| Denominador | Votos SIM ou NÃO em votações com resultado binário |
| NULL | Resultado não binário (empate, prejudicado, sem resultado) fica fora |

## resultado_alinhado_governo (fl_resultado_alinhado_governo)

| Campo | Definição |
| --- | --- |
| Definição | Se o resultado da votação seguiu a orientação do Governo |
| Regra | Alinhado = (orientação SIM e aprovada) ou (orientação NÃO ou OBSTRUÇÃO e rejeitada) |
| Grão | Votação |
| NULL | Com motivo explícito: SEM ORIENTACAO, LIBERADO, ORIENTACAO ABSTENCAO, RESULTADO NAO BINARIO |
| Votação sem proposição | Entra normalmente |
| Limitações | Não é "sucesso": só compara resultado e orientação |

## aderencia_consulta_publica

| Campo | Definição |
| --- | --- |
| Definição | Se a deliberação do Senado sobre a matéria coincidiu com o resultado da consulta pública |
| Regra | 1 quando (consulta SIM e APROVADA) ou (consulta NAO e REJEITADA); 0 no cruzamento oposto |
| Grão | Matéria |
| resultado_consulta | Maioria de votos na última extração: SIM, NAO ou EMPATE |
| resultado_votacao | Deliberação da matéria mapeada por `seed_senado_deliberacoes_resultado` |
| NULL | Com motivo: MATERIA NAO ENCONTRADA NO SENADO, EMPATE NA CONSULTA, SEM DELIBERACAO, DELIBERACAO NAO BINARIA |
| Limitações | A consulta representa os participantes, não a população, e não vincula os senadores. A cobertura depende da extração do processo das matérias consultadas |

## indice_rice_medio

| Campo | Definição |
| --- | --- |
| Definição | Coesão do grupo: média, por votação, de `|SIM − NÃO| / (SIM + NÃO)` dentro do grupo |
| Escala | 0 (dividido ao meio) a 1 (unânime) |
| População | Votações com ao menos dois votos SIM ou NÃO do grupo; obstrução fica fora |

## Placar (votacoes)

| Métrica | Definição |
| --- | --- |
| `sim_pct` | `100 × qt_votos_sim / qt_votantes`, com votantes = SIM + NÃO + OBSTRUÇÃO; na secreta do Senado, total oficial de SIM e NÃO; nulo sem registro nominal |
| `margem` | `qt_votos_sim − qt_votos_nao` |
| `fl_unanimidade` | 1 quando a votação nominal teve só SIM ou só NÃO |

## Métricas externas

`governismo_pct_radar` e os valores de `indicadores_externos` são publicados pela fonte e não são recalculados. As diferenças modelo × Radar (`diferenca_pp`, `erro_absoluto_medio`, `vies_medio`) comparam as duas métricas sem misturá-las.
