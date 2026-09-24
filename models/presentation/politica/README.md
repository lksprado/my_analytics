# Presentation política

Tabelas largas, prontas para visualização, sobre as votações da Câmara e do Senado. Nenhuma exige join.

## Convenções

| Padrão    | Significado                                                             |
| --------- | ----------------------------------------------------------------------- |
| `fl_*`    | 0/1: a média é a taxa, a soma é a contagem                              |
| `qt_*`    | Contagem, somável                                                       |
| `*_pct`   | Percentual 0–100; não somar nem tirar média, recalcular pelas contagens |
| Rótulos   | Texto em maiúsculas sem acento, pronto para legenda e filtro            |
| `partido` | Rótulo da entidade partidária; siglas reutilizadas levam o período      |
| `sk_*`    | Chave para drill-through entre tabelas                                  |

## Votações

| Tabela                | Grão                  | Responde                                                                                                                        |
| --------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `votacoes`            | votação               | Placar, margem e unanimidade; resultado alinhado ao Governo por presidente, classe (mérito × procedimental), órgão e modalidade |
| `votos_parlamentares` | parlamentar × votação | Voto a voto: segue Governo, segue partido, lado vencedor, alinhamento em quatro quadrantes, perfil do parlamentar               |

## Parlamentar

| Tabela                    | Grão                      | Responde                                                                                                   |
| ------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `parlamentar_legislatura` | parlamentar × legislatura | Presença, participação, ausências, governismo, disciplina e votos vencedores do parlamentar na legislatura |
| `parlamentar_ano`         | parlamentar × ano         | O mesmo, por ano civil                                                                                     |
| `parlamentar_trimestre`   | parlamentar × trimestre   | O mesmo, por trimestre                                                                                     |
| `parlamentar_semana`      | parlamentar × semana ISO  | O mesmo, por semana (segunda a domingo)                                                                    |
| `score_vs_governismo`     | parlamentar × ano         | Avaliação do Ranking dos Políticos × governismo no mesmo ano                                               |

## Bancada

| Tabela                            | Grão                                                  | Responde                                                                      |
| --------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| `comportamento_partidario`        | casa × partido × legislatura × presidente × trimestre | Coesão (índice de Rice), governismo e disciplina da bancada ao longo do tempo |
| `score_vs_governismo_por_partido` | casa × partido × ano                                  | Avaliação do Ranking dos Políticos × governismo por bancada                   |

## Qualidade do cálculo

Validam o governismo calculado contra o publicado pelo Radar Congresso. Não são tabelas de análise política.

| Tabela                               | Grão                    | Responde                                              |
| ------------------------------------ | ----------------------- | ----------------------------------------------------- |
| `comparativo_governismo_legislatura` | parlamentar             | Diferença entre as fontes por parlamentar no mandato  |
| `comparativo_governismo_trimestre`   | parlamentar × trimestre | Diferença entre as fontes por parlamentar e trimestre |
| `comparativo_governismo_resumo`      | casa × trimestre        | Correlação, erro e viés entre as fontes               |
| `comparativo_governismo_por_partido` | casa × partido          | Concordância entre as fontes por bancada              |

## e-Cidadania

| Tabela                   | Grão | Responde                           |
| ------------------------ | ---- | ---------------------------------- |
| `ecidadania_bignumbers`  | dia  | Participação popular na plataforma |
| `ecidadania_proposicoes` | —    | Desabilitada                       |

## Cuidados de leitura

- A orientação só existe no Senado a partir de 2019: antes disso, governismo e disciplina ficam nulos.
- `ementa` e `idade` só existem para a Câmara.
- `nota_base_votacoes` depende da posição de voto e é correlacionada ao governismo.
- A pontuação do Ranking dos Políticos existe de 2023 em diante (`score_vs_governismo`).
- Na Câmara a ausência é inferida: a API só lista quem votou, e o deputado é tido em exercício entre o primeiro e o último voto na legislatura.
- Participação e presença contam só o Plenário; governismo e disciplina incluem as comissões.
