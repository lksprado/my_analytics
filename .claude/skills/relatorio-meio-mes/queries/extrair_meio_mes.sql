-- Extração determinística para o relatório de MEIO DE MÊS.
--
-- Parâmetro:
--   :hoje  -- data real do dia da execução, ex.: '2026-08-17'
--
-- Duas perguntas, dois recortes de tempo. O relatório fala do mês CORRENTE
-- (ritmo do gasto, projeção de fechamento, margem que ainda cabe) e do mês
-- ANTERIOR (desempenho contra CDI e inflação pessoal, que só agora tem
-- indexador publicado; e os ativos de Deusa, cuja carteira fecha na mesma
-- cadência). Nenhum bloco mistura os dois.
--
-- Deusa é o terceiro escopo e é APARTADO por construção: patrimônio, carteira
-- e objetivos dela não se somam aos do casal em lugar nenhum deste arquivo.
-- Ela não tem despesa lançada no warehouse, então não entra em nada das partes
-- 1 a 4 — só existe do lado patrimonial.
--
-- Por que o parâmetro é `:hoje` e não um mês: a pergunta do relatório é "como
-- está o mês a esta altura". Travar :hoje num dia já passado reproduz
-- exatamente o relatório daquele dia — é assim que se afere se a projeção
-- acertou, comparando contra o fechamento que veio depois.
--
-- Eixo de dia: `dia_fatura` (o `dia_ajustado` da planilha), nunca `dia_mes`.
-- O bloco {% docs ciclo_fatura %} define dia_ajustado como o dia deslocado
-- para a posição que ocupa dentro do ciclo de fatura, "para que gastos de
-- ciclos diferentes sejam comparáveis dia a dia". É precisamente a comparação
-- que este relatório faz. Usar o dia do calendário compara posições
-- diferentes do ciclo e invalida todo o bloco de ritmo.

\set ON_ERROR_STOP on

WITH
params AS (
    SELECT
        :'hoje'::date                                                   AS hoje,
        date_trunc('month', :'hoje'::date)::date                        AS mes_corrente,
        (date_trunc('month', :'hoje'::date) - interval '1 month')::date AS mes_anterior,
        (date_trunc('month', :'hoje'::date) + interval '1 month'
                                            - interval '1 day')::date   AS fim_mes_corrente
),

-- Grão diário do consumo, com o total do dia somado sobre as oito categorias.
gasto_diario AS (
    SELECT
        mes,
        data,
        dia_fatura,
        total_mercado, total_diversos, total_assinaturas, total_role,
        total_transporte, total_apartamento, total_saude, total_educacao,
        total_mercado + total_diversos + total_assinaturas + total_role
        + total_transporte + total_apartamento + total_saude + total_educacao AS total_dia
    FROM marts.consumo
),

-- ----------------------------------------------------------- meses fechados ---
-- Mesma regra do relatório de fechamento: o mês tem DRE com variáveis (não é
-- mês só pré-lançado) e o lançamento vai até o fim do mês. Só mês fechado
-- entra na base de comparação — meio mês comparado contra meio mês.
cobertura_mes AS (
    SELECT
        g.mes,
        MAX(g.data) FILTER (WHERE g.total_dia <> 0)           AS ultimo_dia_com_gasto,
        (g.mes + interval '1 month' - interval '1 day')::date AS fim_do_mes
    FROM gasto_diario AS g
    GROUP BY g.mes
),

meses_fechados AS (
    SELECT c.mes
    FROM cobertura_mes AS c
    INNER JOIN marts.resultado AS r ON r.mes_debito = c.mes
    CROSS JOIN params AS p
    WHERE r.total_role + r.total_diversos + r.total_transporte > 0
      AND c.ultimo_dia_com_gasto IS NOT NULL
      AND (c.fim_do_mes - c.ultimo_dia_com_gasto) <= 2
      AND c.mes < p.mes_corrente
),

base_6 AS (
    SELECT mes FROM meses_fechados ORDER BY mes DESC LIMIT 6
),
base_12 AS (
    SELECT mes FROM meses_fechados ORDER BY mes DESC LIMIT 12
),

-- -------------------------------------------------------------- dia de corte ---
-- Posição já alcançada dentro do ciclo de fatura. Sai do dado, não do
-- calendário: é o maior dia_fatura entre os lançamentos do mês corrente que já
-- ocorreram. As linhas com data > hoje são fixas pré-agendadas e não contam
-- para "até onde chegamos".
corte AS (
    SELECT COALESCE(MAX(g.dia_fatura), 0) AS dia_corte
    FROM gasto_diario AS g
    CROSS JOIN params AS p
    WHERE g.mes = p.mes_corrente
      AND g.data <= p.hoje
),

-- -------------------------------------------------------------------- portão ---
-- Dois portões independentes, um por parte do relatório.
prontidao AS (
    SELECT
        (SELECT dia_corte FROM corte)                                   AS dia_corte,
        EXTRACT(DAY FROM p.hoje)::int                                   AS dia_do_mes,
        (SELECT COUNT(*) FROM gasto_diario g
          WHERE g.mes = p.mes_corrente AND g.data <= p.hoje
            AND g.total_dia <> 0)::int                                  AS dias_com_gasto,
        (SELECT MAX(g.data) FROM gasto_diario g
          WHERE g.mes = p.mes_corrente AND g.data <= p.hoje
            AND g.total_dia <> 0)                                       AS ultimo_lancamento,
        (SELECT p.hoje - MAX(g.data) FROM gasto_diario g
          WHERE g.mes = p.mes_corrente AND g.data <= p.hoje
            AND g.total_dia <> 0)::int                                  AS dias_desde_ultimo_lancamento,
        (SELECT COUNT(*) FROM base_6)::int                              AS meses_de_base,
        (SELECT COUNT(*) FROM marts.indicadores i
          WHERE i.mes_base = p.mes_anterior AND i.ipca IS NOT NULL)     AS tem_indicadores,
        (SELECT MAX(i.mes_base) FROM marts.indicadores i
          WHERE i.ipca IS NOT NULL)                                     AS ultimo_mes_indicador,
        -- A carteira de Deusa fecha em cadência própria e costuma vir um mês
        -- atrás. Portão separado: sem a posição do mês anterior a seção de
        -- ativos sai do relatório, sem derrubar as outras.
        (SELECT COUNT(*) FROM marts.carteira_deusa c
          WHERE c.mes_base = p.mes_anterior)                            AS tem_carteira_deusa,
        (SELECT MAX(c.mes_base) FROM marts.carteira_deusa c)            AS ultimo_mes_carteira_deusa
    FROM params AS p
),

pendencias AS (
    SELECT 'ritmo'::text AS escopo,
           'Hoje é dia ' || dia_do_mes || ': cedo demais. Antes do dia 10 o acumulado '
           || 'ainda não sustenta projeção nem comparação — meia dúzia de lançamentos '
           || 'move o número inteiro.' AS frase
    FROM prontidao WHERE dia_do_mes < 10
    UNION ALL
    SELECT 'ritmo',
           'Nenhum gasto lançado no mês corrente até hoje.'
    FROM prontidao WHERE ultimo_lancamento IS NULL
    UNION ALL
    SELECT 'ritmo',
           'Último gasto lançado há ' || dias_desde_ultimo_lancamento
           || ' dias: os lançamentos estão atrasados e o acumulado está subestimado.'
    FROM prontidao WHERE dias_desde_ultimo_lancamento > 3
    UNION ALL
    SELECT 'ritmo',
           'Só ' || dias_com_gasto || ' dias com gasto no mês — pouca base para ler ritmo.'
    FROM prontidao WHERE ultimo_lancamento IS NOT NULL AND dias_com_gasto < 7
    UNION ALL
    SELECT 'ritmo',
           'Apenas ' || meses_de_base || ' meses fechados disponíveis como base de '
           || 'comparação (a projeção pede 6). A mediana fica frágil.'
    FROM prontidao WHERE meses_de_base < 6
    UNION ALL
    SELECT 'indicadores',
           'Os indexadores do mês anterior ainda não estão preenchidos em '
           || 'marts.indicadores. O IPCA sai por volta do dia 10 e a planilha é '
           || 'preenchida depois; sem eles não há leitura de desempenho.'
    FROM prontidao WHERE tem_indicadores = 0
    UNION ALL
    SELECT 'deusa',
           'A carteira de Deusa ainda não tem a posição do mês anterior em '
           || 'marts.carteira_deusa — a última é de '
           || COALESCE(to_char(ultimo_mes_carteira_deusa, 'MM/YYYY'), 'nenhum mês')
           || '. Sem ela não há leitura de ativos.'
    FROM prontidao WHERE tem_carteira_deusa = 0
),

-- --------------------------------------------------------------------- blocos ---

b_meta AS (
    SELECT json_build_object(
        'hoje',              (SELECT hoje FROM params),
        'mes_corrente',      (SELECT mes_corrente FROM params),
        'mes_anterior',      (SELECT mes_anterior FROM params),
        'fim_mes_corrente',  (SELECT fim_mes_corrente FROM params),
        'dia_corte',         (SELECT dia_corte FROM prontidao),
        'dias_no_mes',       (SELECT EXTRACT(DAY FROM fim_mes_corrente)::int FROM params),
        'dias_restantes',    (SELECT (fim_mes_corrente - hoje)::int FROM params),
        'gerado_em',         to_char(now(), 'YYYY-MM-DD HH24:MI:SS'),
        'meses_de_base',     (SELECT meses_de_base FROM prontidao),
        'motivos_especiais', (
            SELECT NULLIF(r.motivo, 'NORMAL')
            FROM marts.resultado r CROSS JOIN params p
            WHERE r.mes_debito = p.mes_corrente
        ),
        'prontidao', (
            SELECT json_build_object(
                'pronto_ritmo', (dia_do_mes >= 10
                             AND ultimo_lancamento IS NOT NULL
                             AND COALESCE(dias_desde_ultimo_lancamento, 99) <= 3
                             AND dias_com_gasto >= 7),
                'pronto_indicadores',           tem_indicadores > 0,
                'pronto_deusa',                 tem_carteira_deusa > 0,
                'dia_do_mes',                   dia_do_mes,
                'dia_corte',                    dia_corte,
                'dias_com_gasto',               dias_com_gasto,
                'ultimo_lancamento',            ultimo_lancamento,
                'dias_desde_ultimo_lancamento', dias_desde_ultimo_lancamento,
                'meses_de_base',                meses_de_base,
                'ultimo_mes_indicador',         ultimo_mes_indicador,
                'ultimo_mes_carteira_deusa',    ultimo_mes_carteira_deusa,
                'pendencias_ritmo', (
                    SELECT COALESCE(json_agg(frase), '[]'::json)
                    FROM pendencias WHERE escopo = 'ritmo'
                ),
                'pendencias_indicadores', (
                    SELECT COALESCE(json_agg(frase), '[]'::json)
                    FROM pendencias WHERE escopo = 'indicadores'
                ),
                'pendencias_deusa', (
                    SELECT COALESCE(json_agg(frase), '[]'::json)
                    FROM pendencias WHERE escopo = 'deusa'
                )
            )
            FROM prontidao
        )
    ) AS j
),

-- Curva acumulada do mês corrente, dia a dia do ciclo, só o que já ocorreu.
b_ritmo AS (
    SELECT COALESCE(json_agg(t ORDER BY t.dia_fatura), '[]'::json) AS j
    FROM (
        SELECT
            g.dia_fatura,
            SUM(SUM(g.total_dia))          OVER (ORDER BY g.dia_fatura) AS acumulado,
            SUM(SUM(g.total_mercado))      OVER (ORDER BY g.dia_fatura) AS acum_mercado,
            SUM(SUM(g.total_diversos))     OVER (ORDER BY g.dia_fatura) AS acum_diversos,
            SUM(SUM(g.total_assinaturas))  OVER (ORDER BY g.dia_fatura) AS acum_assinaturas,
            SUM(SUM(g.total_role))         OVER (ORDER BY g.dia_fatura) AS acum_role,
            SUM(SUM(g.total_transporte))   OVER (ORDER BY g.dia_fatura) AS acum_transporte,
            SUM(SUM(g.total_apartamento))  OVER (ORDER BY g.dia_fatura) AS acum_apartamento,
            SUM(SUM(g.total_saude))        OVER (ORDER BY g.dia_fatura) AS acum_saude,
            SUM(SUM(g.total_educacao))     OVER (ORDER BY g.dia_fatura) AS acum_educacao
        FROM gasto_diario AS g
        CROSS JOIN params AS p
        WHERE g.mes = p.mes_corrente
          AND g.data <= p.hoje
        GROUP BY g.dia_fatura
    ) AS t
),

-- Mesma curva para cada um dos 6 meses fechados, dia a dia e mês inteiro. A
-- envoltória mín–máx e a mediana por dia são calculadas no montador, que já
-- tem `mediana()` — evita repetir percentile_cont oito vezes aqui.
b_ritmo_historico AS (
    SELECT COALESCE(json_agg(t ORDER BY t.mes, t.dia_fatura), '[]'::json) AS j
    FROM (
        SELECT
            g.mes,
            g.dia_fatura,
            SUM(SUM(g.total_dia)) OVER (PARTITION BY g.mes ORDER BY g.dia_fatura) AS acumulado
        FROM gasto_diario AS g
        WHERE g.mes IN (SELECT mes FROM base_6)
        GROUP BY g.mes, g.dia_fatura
    ) AS t
),

-- ------------------------------------------------------------------ projeção ---
-- Por categoria, três parcelas distintas e não sobrepostas:
--
--   realizado  o que já ocorreu no mês corrente (data <= hoje)
--   agendado   o que já está lançado no mês com data futura — as fixas do
--              dia 25. É dinheiro comprometido, não estimativa.
--   restante   mediana, nos 6 meses fechados, do que caiu DEPOIS do dia de
--              corte. Inclui as fixas daquele mês.
--
--   projeção = realizado + GREATEST(restante_mediano, agendado)
--
-- É GREATEST e não soma: `restante` já embute as fixas históricas, e somar o
-- `agendado` por cima contaria as fixas duas vezes. Quando o agendado deste
-- mês supera o padrão histórico (uma fixa nova, uma parcela grande), ele vira
-- o piso. A regra é conservadora por construção e precisa ir para `premissas`.

-- As oito categorias viram linhas uma única vez. Sem isto, cada agregação
-- abaixo repetiria um CASE de oito ramos e as cópias divergiriam — foi
-- exatamente o que aconteceu com o de-para de instituições antes da macro.
gasto_cat AS (
    SELECT g.mes, g.data, g.dia_fatura, v.categoria, v.valor
    FROM gasto_diario AS g
    CROSS JOIN LATERAL (VALUES
        ('mercado',     g.total_mercado),
        ('diversos',    g.total_diversos),
        ('assinaturas', g.total_assinaturas),
        ('role',        g.total_role),
        ('transporte',  g.total_transporte),
        ('apartamento', g.total_apartamento),
        ('saude',       g.total_saude),
        ('educacao',    g.total_educacao)
    ) AS v(categoria, valor)
),

-- GROUPING SETS dá a linha por categoria e a linha de total na mesma varredura;
-- a de total sai com categoria NULL e é rotulada 'total' na saída.
atual_cat AS (
    SELECT
        g.categoria,
        COALESCE(SUM(g.valor) FILTER (WHERE g.data <= p.hoje), 0) AS realizado,
        COALESCE(SUM(g.valor) FILTER (WHERE g.data >  p.hoje), 0) AS agendado
    FROM gasto_cat AS g
    CROSS JOIN params AS p
    WHERE g.mes = p.mes_corrente
    GROUP BY GROUPING SETS ((g.categoria), ())
),

historico_cat AS (
    SELECT
        g.mes,
        g.categoria,
        COALESCE(SUM(g.valor) FILTER (WHERE g.dia_fatura <= c.dia_corte), 0) AS ate_corte,
        COALESCE(SUM(g.valor) FILTER (WHERE g.dia_fatura >  c.dia_corte), 0) AS apos_corte,
        COALESCE(SUM(g.valor), 0)                                            AS mes_cheio
    FROM gasto_cat AS g
    CROSS JOIN corte AS c
    WHERE g.mes IN (SELECT mes FROM base_6)
    GROUP BY GROUPING SETS ((g.mes, g.categoria), (g.mes))
),

mediana_cat AS (
    SELECT
        h.categoria,
        -- percentile_cont devolve double precision mesmo sobre numeric; sem o
        -- cast o ROUND(v, 2) lá embaixo não encontra função.
        percentile_cont(0.5) WITHIN GROUP (ORDER BY h.ate_corte)::numeric  AS mesmo_dia_mediana,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY h.apos_corte)::numeric AS restante_mediana,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY h.mes_cheio)::numeric  AS mes_cheio_mediana
    FROM historico_cat AS h
    GROUP BY h.categoria
),

b_categorias AS (
    SELECT COALESCE(json_agg(t ORDER BY t.ord), '[]'::json) AS j
    FROM (
        SELECT
            ord.ord,
            COALESCE(a.categoria, 'total')                  AS categoria,
            ROUND(a.realizado, 2)                           AS realizado,
            ROUND(a.agendado, 2)                            AS agendado,
            ROUND(COALESCE(m.mesmo_dia_mediana, 0), 2)      AS mesmo_dia_mediana_6m,
            ROUND(COALESCE(m.restante_mediana, 0), 2)       AS restante_mediana_6m,
            ROUND(COALESCE(m.mes_cheio_mediana, 0), 2)      AS mes_cheio_mediana_6m,
            ROUND(a.realizado
                  + GREATEST(COALESCE(m.restante_mediana, 0), a.agendado), 2) AS projecao
        FROM atual_cat AS a
        LEFT JOIN mediana_cat AS m
            ON a.categoria IS NOT DISTINCT FROM m.categoria
        JOIN (VALUES
                ('mercado', 1), ('diversos', 2), ('assinaturas', 3), ('role', 4),
                ('transporte', 5), ('apartamento', 6), ('saude', 7),
                ('educacao', 8), ('total', 9)
             ) AS ord(nome, ord)
            ON ord.nome = COALESCE(a.categoria, 'total')
    ) AS t
),

b_dre AS (
    SELECT COALESCE(json_agg(t ORDER BY t.mes_debito), '[]'::json) AS j
    FROM (
        SELECT *
        FROM marts.resultado
        WHERE mes_debito <= (SELECT mes_corrente FROM params)
          AND mes_debito >  (SELECT mes_corrente FROM params) - interval '13 months'
    ) AS t
),

b_indicadores AS (
    SELECT COALESCE(json_agg(t ORDER BY t.mes_base), '[]'::json) AS j
    FROM (
        SELECT *
        FROM marts.indicadores
        WHERE mes_base <= (SELECT mes_anterior FROM params)
          AND mes_base >  (SELECT mes_anterior FROM params) - interval '13 months'
    ) AS t
),

b_riqueza AS (
    SELECT COALESCE(json_agg(t ORDER BY t.mes_base), '[]'::json) AS j
    FROM (
        SELECT *
        FROM marts.riqueza
        WHERE mes_base <= (SELECT mes_anterior FROM params)
          AND mes_base >  (SELECT mes_anterior FROM params) - interval '13 months'
    ) AS t
),

-- ------------------------------------------------------------ ativos de Deusa ---
-- Mês ANTERIOR, escopo APARTADO. A pergunta aqui é "onde o dinheiro dela
-- está" — instituição, disponibilidade contra investido, classe e indexador.
-- Camada, teto do FGC, vencimento e destino do aporte NÃO entram: são do
-- relatório de fechamento, que já emite um PDF de investimentos só dela.
--
-- Duas fontes com totais próprios, e por isso conciliadas explicitamente no
-- bloco `b_deusa_conciliacao`:
--
--   marts.carteira_deusa           grão de ativo; é o que dá classe,
--                                  indexador e a quebra por instituição
--   int_patrimonio_mensal_deusa    a planilha dela; é o que alimenta o índice
--                                  de `riqueza` exibido na mesma seção
--
-- Em 07/2026 os dois totais diferem em R$ 2, mas em 12/2024 diferiam em R$ 60
-- mil. Exibir um número de cada fonte na mesma página sem mostrar a diferença
-- é o modo de o relatório mentir sem errar nenhuma conta. O intermediate é
-- lido direto porque nenhum mart expõe o nível do patrimônio de Deusa —
-- `riqueza` carrega só o índice e `marts.patrimonio` não tem coluna dela.

-- A série e a composição saem as duas de `carteira_deusa`, no grão de ativo.
-- `carteira_deusa_agregada` traria a série pronta, mas o `total_disponibilidades`
-- dela não bate com o que a classe DISPONIBILIDADE soma na carteira (R$ 259 de
-- diferença em 07/2026, com o total geral idêntico): são dois critérios de
-- corte para a mesma fronteira. Uma seção, uma definição.
b_deusa_evolucao AS (
    SELECT COALESCE(json_agg(t ORDER BY t.mes_base), '[]'::json) AS j
    FROM (
        SELECT
            c.mes_base,
            ROUND(SUM(c.vlr_atualizado_brl), 2) AS total_geral,
            ROUND(COALESCE(SUM(c.vlr_atualizado_brl)
                  FILTER (WHERE c.classe_ativo = 'DISPONIBILIDADE'), 0), 2)  AS disponivel,
            ROUND(COALESCE(SUM(c.vlr_atualizado_brl)
                  FILTER (WHERE c.classe_ativo <> 'DISPONIBILIDADE'), 0), 2) AS investido
        FROM marts.carteira_deusa AS c
        CROSS JOIN params AS p
        WHERE c.mes_base <= p.mes_anterior
          AND c.mes_base >  p.mes_anterior - interval '13 months'
        GROUP BY c.mes_base
    ) AS t
),

-- Mês anterior e o anterior a ele na mesma varredura: a coluna de variação da
-- composição sai de um FILTER, não de uma segunda leitura da carteira.
deusa_pos AS (
    SELECT
        c.mes_base,
        c.instituicao,
        c.classe_ativo,
        c.tipo_ativo,
        COALESCE(NULLIF(TRIM(c.indexador), ''), 'SEM INDEXADOR') AS indexador,
        c.vlr_atualizado_brl                                     AS valor
    FROM marts.carteira_deusa AS c
    CROSS JOIN params AS p
    WHERE c.mes_base IN (p.mes_anterior,
                         (p.mes_anterior - interval '1 month')::date)
),

b_deusa_instituicao AS (
    SELECT COALESCE(json_agg(t ORDER BY t.valor DESC), '[]'::json) AS j
    FROM (
        SELECT
            d.instituicao,
            ROUND(SUM(d.valor) FILTER (WHERE d.mes_base = p.mes_anterior), 2) AS valor,
            ROUND(SUM(d.valor) FILTER (WHERE d.mes_base < p.mes_anterior), 2) AS valor_anterior
        FROM deusa_pos AS d
        CROSS JOIN params AS p
        GROUP BY d.instituicao
        HAVING SUM(d.valor) FILTER (WHERE d.mes_base = p.mes_anterior) IS NOT NULL
    ) AS t
),

b_deusa_classe AS (
    SELECT COALESCE(json_agg(t ORDER BY t.valor DESC), '[]'::json) AS j
    FROM (
        SELECT
            d.classe_ativo,
            d.tipo_ativo,
            COUNT(*) FILTER (WHERE d.mes_base = p.mes_anterior)::int         AS ativos,
            ROUND(SUM(d.valor) FILTER (WHERE d.mes_base = p.mes_anterior), 2) AS valor,
            ROUND(SUM(d.valor) FILTER (WHERE d.mes_base < p.mes_anterior), 2) AS valor_anterior
        FROM deusa_pos AS d
        CROSS JOIN params AS p
        GROUP BY d.classe_ativo, d.tipo_ativo
        HAVING SUM(d.valor) FILTER (WHERE d.mes_base = p.mes_anterior) IS NOT NULL
    ) AS t
),

-- `valor_renda_fixa` existe porque «SEM INDEXADOR» é ambíguo e a ambiguidade
-- muda a conclusão. Em 07/2026 os R$ 311 mil sem indexador incluem R$ 202 mil
-- de renda fixa — título com taxa contratada cujo campo não foi preenchido na
-- origem — e não só fundo, ação e saldo em conta. Sem esta coluna a seção
-- reportaria como «exposição sem indexador» o que é lacuna de cadastro.
b_deusa_indexador AS (
    SELECT COALESCE(json_agg(t ORDER BY t.valor DESC), '[]'::json) AS j
    FROM (
        SELECT
            d.indexador,
            ROUND(SUM(d.valor) FILTER (WHERE d.mes_base = p.mes_anterior), 2) AS valor,
            ROUND(COALESCE(SUM(d.valor) FILTER (WHERE d.mes_base = p.mes_anterior
                                            AND d.classe_ativo = 'RENDA FIXA'), 0), 2)
                                                                              AS valor_renda_fixa
        FROM deusa_pos AS d
        CROSS JOIN params AS p
        GROUP BY d.indexador
        HAVING SUM(d.valor) FILTER (WHERE d.mes_base = p.mes_anterior) IS NOT NULL
    ) AS t
),

b_deusa_conciliacao AS (
    SELECT json_build_object(
        'mes_base',       (SELECT mes_anterior FROM params),
        'total_carteira', (SELECT ROUND(SUM(c.vlr_atualizado_brl), 2)
                           FROM marts.carteira_deusa AS c
                           CROSS JOIN params AS p
                           WHERE c.mes_base = p.mes_anterior),
        'total_planilha', (SELECT x.total_patrimonio_liquido
                           FROM intermediate.int_patrimonio_mensal_deusa AS x
                           CROSS JOIN params AS p
                           WHERE x.mes_base = p.mes_anterior)
    ) AS j
),

b_meses_base AS (
    SELECT COALESCE(json_agg(mes ORDER BY mes), '[]'::json) AS j FROM base_6
)

SELECT json_build_object(
    'meta',             (SELECT j FROM b_meta),
    'ritmo',            (SELECT j FROM b_ritmo),
    'ritmo_historico',  (SELECT j FROM b_ritmo_historico),
    'categorias',       (SELECT j FROM b_categorias),
    'dre_mensal',       (SELECT j FROM b_dre),
    'indicadores',      (SELECT j FROM b_indicadores),
    'riqueza',          (SELECT j FROM b_riqueza),
    'meses_base',       (SELECT j FROM b_meses_base),
    'deusa_evolucao',    (SELECT j FROM b_deusa_evolucao),
    'deusa_instituicao', (SELECT j FROM b_deusa_instituicao),
    'deusa_classe',      (SELECT j FROM b_deusa_classe),
    'deusa_indexador',   (SELECT j FROM b_deusa_indexador),
    'deusa_conciliacao', (SELECT j FROM b_deusa_conciliacao)
)::text;
