# PRD - Domínio Política

## 1. Objetivo

Esta camada de dados deve responder a perguntas analíticas sobre:

* parlamentares;
* proposições;
* tramitação legislativa;
* votações;
* comportamento de votação;
* partidos e bancadas;
* participação popular no e-Cidadania;
* métricas externas de fontes como Ranking dos Políticos e Radar do Congresso.

O domínio deve suportar análises históricas e comparações por:

* Casa;
* parlamentar;
* partido;
* bancada;
* UF;
* tema;
* legislatura;
* sessão legislativa;
* governo/presidente do Executivo;
* período.

---

## 2. Fontes de dados

### 2.1 Câmara dos Deputados

Fontes principais:

* proposições;
* autores;
* temas;
* tramitações;
* votações;
* votos individuais;
* orientações de bancadas;
* parlamentares;
* partidos;
* órgãos/comissões;
* legislaturas.

A API da Câmara disponibiliza endpoints específicos para proposições, autores, temas, tramitações, votações, orientações e votos.

### 2.2 Senado Federal

Fontes principais:

* matérias legislativas;
* autoria;
* relatoria;
* tramitação;
* parlamentares;
* mandatos;
* partidos;
* votações nominais;
* comissões;
* legislaturas.

Os Dados Abertos do Senado disponibilizam conjuntos específicos para autoria, relatoria, mandatos e votações nominais.

### 2.3 e-Cidadania

Fontes principais:

* consultas públicas;
* votos em consultas públicas;
* ideias legislativas;
* apoios;
* participação em eventos interativos.

A consulta pública do e-Cidadania registra votos de participantes sobre proposições em tramitação no Senado. O resultado não vincula a decisão dos senadores.

### 2.4 Ranking dos Políticos

Armazenar os indicadores publicados pela fonte, preservando:

* valor original;
* nome do indicador;
* período de referência;
* parlamentar;
* fonte;
* data de coleta;
* metodologia/origem, quando disponível.

Os valores não devem ser recalculados pelo domínio quando a intenção for representar o indicador original da fonte.

### 2.5 Radar do Congresso

Armazenar o indicador de governismo publicado pela fonte, preservando:

* parlamentar;
* Casa;
* período;
* valor original;
* quantidade de votações utilizada, quando disponível;
* origem da métrica.

O Radar informa que seu índice compara o voto do parlamentar com a orientação do líder do governo e considera votos diferentes da orientação, incluindo abstenção ou falta, como não alinhados. Também aplica um nível mínimo de votações para exibição do parlamentar.

---

# 3. Princípios de modelagem

## 3.1 Preservar fatos observáveis

O modelo deve preservar, separadamente:

* voto registrado;
* orientação do governo;
* resultado da votação;
* participação/ausência;
* proposição;
* tramitação;
* autoria;
* relatoria;
* consulta pública;
* indicadores externos.

Não substituir fatos por classificações interpretativas.

## 3.2 Preservar métricas externas

Métricas provenientes do Ranking dos Políticos e Radar do Congresso devem manter seus valores originais e sua proveniência.

Não tratar essas métricas como métricas calculadas pelo próprio domínio.

## 3.3 Separar métrica própria de métrica externa

Exemplo:

```text
governismo_pct_modelo
governismo_pct_radar
```

Não sobrescrever uma métrica externa com uma métrica calculada internamente.

## 3.4 Toda métrica deve possuir definição formal

Cada métrica deve especificar:

* nome;
* definição;
* fórmula;
* grão;
* numerador;
* denominador;
* população elegível;
* período;
* tratamento de NULL;
* tratamento de ausência;
* tratamento de empate, quando aplicável;
* fonte;
* limitações.

---

# 4. Métricas

## 4.1 Governismo

### Definição

Percentual de votos de um parlamentar que coincidem com a orientação do governo em votações elegíveis para o cálculo.

### Componentes mínimos

```text
votacoes_elegiveis
votacoes_participadas
votos_alinhados_governo
participacao_pct
governismo_pct
```

### Regra conceitual

Não confundir:

```text
participação
```

com:

```text
alinhamento
```

Exemplo:

```text
Parlamentar A
governismo_pct = 70%
participacao_pct = 80%

Parlamentar B
governismo_pct = 100%
participacao_pct = 1%
```

Os dois valores devem permanecer separadamente disponíveis.

### Requisitos

O cálculo deve identificar explicitamente:

* orientação do governo;
* voto do parlamentar;
* votação elegível;
* participação;
* ausência;
* abstenção;
* obstrução;
* votação sem orientação;
* votação secreta;
* mínimo de observações.

O modelo interno não deve presumir que a metodologia do Radar é idêntica à metodologia própria. As duas métricas devem permanecer comparáveis, mas independentes.

---

## 4.2 Alinhamento do resultado à orientação do governo

Evitar usar "Sucesso" como conceito primário do modelo.

Representar o fato de forma observável:

```text
resultado_alinhado_governo
```

Exemplo conceitual:

```text
resultado_votacao = aprovado
orientacao_governo = sim
resultado_alinhado_governo = true
```

ou:

```text
resultado_votacao = rejeitado
orientacao_governo = nao
resultado_alinhado_governo = true
```

A regra precisa definir explicitamente como tratar casos em que:

* não existe orientação;
* governo liberou a bancada;
* votação não permite identificar orientação;
* resultado não é binário;
* votação não está associada a uma proposição de maneira confiável.

---

## 4.3 Aderência à consulta pública

Usar `aderencia_consulta_publica` como conceito do domínio.

Não utilizar `soberania_popular` como nome de métrica factual.

A métrica deve comparar:

```text
resultado_consulta_ecidadania
vs.
resultado_votacao
```

e preservar separadamente:

```text
votos_sim_ecidadania
votos_nao_ecidadania
total_votos_ecidadania
resultado_consulta
resultado_votacao
aderencia_consulta_publica
```

A consulta pública representa os participantes do e-Cidadania e não constitui votação vinculante dos senadores.

O modelo não deve interpretar automaticamente o resultado da consulta como representação da opinião da população brasileira.

---

## 4.4 Indicadores externos

Preservar indicadores externos sem alterar sua metodologia.

Exemplo:

```text
fonte = ranking_politicos
indicador = score_total
valor_original = ...
periodo_referencia = ...

fonte = radar_congresso
indicador = governismo
valor_original = ...
periodo_referencia = ...
```

---

# 5. Grãos obrigatórios

O domínio deve suportar, no mínimo, os seguintes grãos.

## 5.1 Parlamentar × período

Uma linha representa:

```text
1 parlamentar em 1 período analítico
```

Uso:

* governismo;
* participação;
* indicadores externos;
* séries temporais;
* análises por partido/UF/Casa.

## 5.2 Parlamentar × votação

Uma linha representa:

```text
1 parlamentar × 1 votação
```

Uso:

* voto;
* alinhamento ao governo;
* orientação;
* participação;
* comportamento de votação.

## 5.3 Votação

Uma linha representa:

```text
1 votação
```

Uso:

* resultado;
* data;
* Casa;
* órgão;
* sessão;
* proposição relacionada;
* agregações.

## 5.4 Proposição

Uma linha representa:

```text
1 proposição
```

Uso:

* autoria;
* situação;
* datas;
* tema;
* tramitação;
* quantidade de votações.

## 5.5 Proposição × tema

Uma linha representa:

```text
1 proposição × 1 tema
```

Uma proposição pode possuir múltiplos temas. Portanto, análises por tema não devem assumir relação 1:1 entre proposição e tema.

## 5.6 Proposição × parlamentar

Uma linha representa:

```text
1 proposição × 1 parlamentar × 1 papel
```

Exemplos de papel:

```text
autor
relator
coautor
```

## 5.7 Proposição × tramitação

Uma linha representa:

```text
1 evento de tramitação
```

Preservar:

* data;
* situação;
* órgão;
* origem;
* destino;
* tipo de tramitação;
* ordem temporal.

## 5.8 Votação × proposição

Não assumir relacionamento simples 1:1.

Preservar o tipo de relacionamento disponível na fonte, por exemplo:

```text
objeto
afetada
possível_objeto
```

A Câmara informa que existem limitações na identificação do objeto real de determinadas votações.

---

# 6. Dimensões

O domínio deve possuir, no mínimo:

```text
dim_parlamentar
dim_partido
dim_casa
dim_uf
dim_legislatura
dim_sessao_legislativa
dim_tempo
dim_proposicao
dim_tema
dim_orgao
dim_governo
dim_bancada
```

## 6.1 Histórico

Partido, bancada, Casa, mandato, comissão e governo devem possuir tratamento temporal quando a mudança histórica for relevante para a análise.

Não utilizar automaticamente o valor atual do parlamentar em registros históricos.

---

# 7. Requisitos funcionais

## 7.1 Filtros

Deve ser possível filtrar por:

* Casa;
* período;
* legislatura;
* sessão legislativa;
* parlamentar;
* partido;
* bancada;
* UF;
* tema;
* governo;
* situação da proposição;
* tipo de proposição;
* resultado da votação.

## 7.2 Análise temporal

O domínio deve permitir:

* séries temporais;
* comparação entre períodos;
* comparação entre legislaturas;
* evolução por parlamentar;
* evolução por partido;
* evolução por tema;
* evolução por Casa;
* evolução por governo.

## 7.3 Granularidade

Devem existir tabelas não agregadas suficientes para permitir reagrupamento posterior.

Não criar somente métricas agregadas quando os dados em nível detalhado forem necessários para reconstrução da métrica.

## 7.4 Data Visualization-ready

Os marts destinados à visualização devem:

* possuir métricas calculadas;
* possuir dimensões desnormalizadas quando necessário;
* evitar joins obrigatórios para visualizações comuns;
* preservar o grão explicitamente;
* impedir duplicação causada por relações N:N;
* permitir agregação sem double counting.

"Data Visualization-ready" não significa que o modelo dimensional inteiro deva ser uma única tabela larga.

---

# 8. Perguntas que o domínio deve responder

## Parlamentares e comportamento

* Qual é o percentual de governismo por parlamentar?
* Qual é a participação média nas votações por parlamentar?
* Como participação e alinhamento governamental se distribuem?
* Como o comportamento de votação mudou ao longo da legislatura?
* Como o comportamento de votação se distribui entre partidos?
* Como a orientação partidária se relaciona com os votos registrados?

## Governismo

* Qual é o percentual médio de governismo?
* Qual é a diferença entre governismo calculado pelo modelo e governismo publicado pelo Radar do Congresso?
* Em quais períodos as métricas apresentam maior divergência?
* Quais diferenças metodológicas explicam divergências entre as métricas?

## Proposições

* Quantas proposições foram apresentadas?
* Quantas proposições avançaram?
* Quantas foram arquivadas?
* Quantas permanecem em tramitação?
* Quantas proposições estão em cada situação de tramitação?
* Qual é o tempo entre apresentação e conclusão?
* Em quais etapas as proposições permanecem por mais tempo?
* Quantas votações estão associadas a cada proposição?
* Quais temas concentram as proposições?
* Quais temas concentram votações de aprovação?

## Participação popular

* Quais proposições receberam maior participação no e-Cidadania?
* Qual foi o resultado da consulta pública de cada proposição?
* Qual foi a diferença entre o resultado da consulta pública e o resultado parlamentar?
* Como essa diferença varia por tema e período?
* Como a participação no e-Cidadania varia ao longo do tempo?

## Relacionamentos

* Quais parlamentares são autores ou relatores das proposições?
* Quais parlamentares participaram das mesmas votações?
* Quais temas aparecem associados às proposições?
* Quais proposições estão relacionadas?
* Quais parlamentares estão associados a determinados temas ou proposições?

## Indicadores externos

* Qual a relação entre governismo e indicadores externos?
* Como os indicadores do Ranking dos Políticos variam ao longo do tempo?
* Como os indicadores externos diferem de métricas calculadas pelo domínio?
* Qual era o valor publicado por uma fonte para determinado parlamentar em determinado período?

---

# 9. Edge cases obrigatórios

O agente deve considerar explicitamente:

### Votações

* votação nominal;
* votação simbólica;
* votação secreta;
* ausência;
* abstenção;
* obstrução;
* ausência de voto registrado;
* ausência de orientação governamental;
* governo liberou a bancada;
* votação sem proposição claramente identificada.

### Proposições

* proposição com múltiplos autores;
* proposição com múltiplos temas;
* proposição relacionada a outras proposições;
* proposição com múltiplas votações;
* proposição com múltiplos eventos de tramitação;
* proposição arquivada;
* proposição em tramitação;
* proposição concluída;
* proposição sem resultado final.

### Parlamentares

* mudança de partido;
* mudança de Casa;
* suplente;
* afastamento;
* retorno ao mandato;
* mudança de bancada;
* término de mandato.

### Indicadores externos

* mudança de metodologia da fonte;
* alteração retroativa do indicador;
* ausência de indicador para determinado parlamentar;
* indicador disponível apenas para determinada Casa ou período.

---

# 10. Regras de qualidade

Toda tabela deve possuir documentação explícita de:

```text
grain
primary key
foreign keys
source
source_column
business_definition
refresh_frequency
historical_coverage
```

Toda métrica deve possuir teste que impeça:

* divisão por zero;
* duplicação causada por joins N:N;
* mistura de Casas;
* mistura de períodos;
* utilização de dados futuros em análises históricas;
* duplicação de parlamentares;
* dupla contagem de proposições;
* dupla contagem de votações.

---

# 11. Regras para o agente de IA

Ao implementar este domínio, o agente deve:

1. Não inventar regras de negócio ausentes neste documento.
2. Não alterar a metodologia de métricas externas.
3. Não misturar métricas de fontes diferentes.
4. Sempre identificar o grão antes de escrever SQL.
5. Sempre verificar relações N:N antes de agregar.
6. Não calcular métricas em tabelas que tenham duplicidade causada por joins.
7. Preservar IDs da fonte original.
8. Preservar histórico quando houver mudança temporal.
9. Preferir métricas factuais a classificações interpretativas.
10. Documentar qualquer regra derivada que não esteja definida neste PRD.
11. Não substituir uma métrica externa por uma métrica calculada internamente.
12. Quando duas fontes tiverem conceitos semelhantes, manter ambas e documentar suas diferenças metodológicas.

---

# 12. Critérios de aceite

O domínio será considerado funcional quando for possível:

* reconstruir o comportamento de votação de um parlamentar a partir do nível `parlamentar × votação`;
* reconstruir o governismo a partir dos registros de voto e orientação elegíveis;
* reproduzir os indicadores externos armazenados sem alteração;
* acompanhar a tramitação de uma proposição em ordem temporal;
* relacionar proposições a autores, relatores, temas e votações;
* comparar consulta pública e resultado legislativo;
* produzir análises por Casa, partido, UF, tema, bancada e período;
* produzir visualizações sem depender de joins complexos em cada consulta;
* rastrear a origem de cada métrica;
* detectar diferenças de metodologia entre métricas semelhantes.

---

# 13. Questões que precisam de definição metodológica antes da implementação

Os pontos abaixo não devem ser inferidos pelo agente:

* definição exata de "votação elegível" para governismo;
* fonte oficial da orientação governamental em cada Casa;
* tratamento de ausência, abstenção e obstrução no cálculo próprio;
* quantidade mínima de votações para publicação de governismo próprio;
* definição operacional de "resultado alinhado à orientação do governo";
* regra para vincular consulta pública a uma votação específica;
* tratamento de proposições cuja votação tenha múltiplos objetos possíveis;
* periodicidade e versionamento dos indicadores externos;
* período exato dos agregados de parlamentar;
* definição histórica de governo e presidente do Executivo;
* regra de classificação de temas quando uma proposição possuir múltiplos temas.
