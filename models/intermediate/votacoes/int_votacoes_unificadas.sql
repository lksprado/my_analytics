{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook="{{ apagar_periodo_vivo('data_votacao', 'legislatura') }}",
    post_hook="CREATE INDEX IF NOT EXISTS idx_int_votacoes_unificadas_data ON {{ this }} (data_votacao)",
    on_schema_change='append_new_columns',
    tags=["politica"]
) }}

-- depends_on: {{ ref('seed_legislaturas') }}

WITH
votacoes AS (
    SELECT
        casa,
        votacao_id_nk,
        sessao_id,
        data_votacao,
        sigla_orgao,
        descricao,
        proposicao_id_fk AS proposicao_id_nk,
        aprovado,
        0                AS fl_secreta,
        NULL::INT        AS qt_votos_sim_secreta,
        NULL::INT        AS qt_votos_nao_secreta,
        NULL::INT        AS qt_abstencao_secreta
    FROM {{ ref('int_votacoes_camara_deduplicadas') }}
    {% if is_incremental() -%}
        WHERE data_votacao >= {{ inicio_periodo_vivo('legislatura') }}
    {%- endif %}
    UNION ALL
    -- Sem colegiado informado, a votação do Senado é do Plenário.
    SELECT
        casa,
        votacao_id_nk::TEXT,
        sessao_id,
        data_votacao,
        COALESCE(sigla_colegiado, 'PLEN') AS sigla_orgao,
        descricao,
        processo_id_nk,
        aprovado,
        fl_secreta,
        qt_votos_sim_secreta,
        qt_votos_nao_secreta,
        qt_abstencao_secreta
    FROM {{ ref('int_votacoes_senado_filtradas') }}
    {% if is_incremental() -%}
        WHERE data_votacao >= {{ inicio_periodo_vivo('legislatura') }}
    {%- endif %}
),

-- O objeto logo após o verbo diz o que foi votado; o resto da descrição engana.
objetos AS (
    SELECT
        *,
        REGEXP_REPLACE(
            COALESCE(descricao, ''),
            '^((APROVAD|REJEITAD|MANTID|PREJUDICAD|RETIRAD)[OA]S?|VOTACAO( NOMINAL| SECRETA| SIMBOLICA)?)(,? EM [A-Z ]+?,)?(,? POR [A-Z ]+?,)?\s*(OS|AS|O|A|DOS|DAS|DO|DA|QUANTO AOS|QUANTO AS|QUANTO AO|QUANTO A)?\s+',
            ''
        ) AS objeto
    FROM votacoes
),

classificadas AS (
    SELECT
        *,
        CASE
            WHEN objeto ~ '^REQUERIMENTO' AND objeto ~ 'URGENCIA' THEN 'URGENCIA'
            WHEN objeto ~ '^REQUERIMENTO' THEN 'REQUERIMENTO PROCEDIMENTAL'
            WHEN objeto ~ '^(PARECER|PRESSUPOSTOS)' THEN 'PARECER'
            WHEN objeto ~ '^(DESTAQUE|EMENDA(?! A CONSTITUICAO)|EMENDAS|SUBEMENDA|ARTIGO|ART\M|INCISO|PARAGRAFO|ALINEA|DISPOSITIVO|EXPRESSAO|TEXTO\M(?![- ]BASE)|ITEM)'
                THEN 'EMENDA/DESTAQUE'
            WHEN objeto ~ '^(PROJETO|PROPOSTA|MEDIDA PROVISORIA|SUBSTITUTIVO|REDACAO FINAL|TEXTO[- ]BASE|MATERIA|PEC|PLV|PLP|PL\M|MPV|PDL|PDC|PRC)'
                THEN 'MERITO'
            WHEN objeto ~ '^(ESCOLHA|INDICACAO|MENSAGEM)' OR descricao ~ 'ESCOLHA D[OA]' THEN 'AUTORIDADE'
            -- No Senado a descrição às vezes é a própria ementa da matéria, que começa pelo verbo.
            WHEN descricao ~ '^\(?(ALTERA|INSTITUI|DISPOE|MODIFICA|ESTABELECE|ACRESCENTA|INCLUI|AUTORIZA|CRIA|REGULAMENTA|APROVA |DA NOVA REDACAO|REVOGA|DENOMINA|DECLARA|INSCREVE|CONCEDE|DEFINE|PROIBE|TORNA|DETERMINA)'
                THEN 'MERITO'
            -- Sem objeto reconhecível no início, vale a primeira pista em qualquer ponto da descrição.
            WHEN descricao ~ 'REQUERIMENTO' AND descricao ~ 'URGENCIA' THEN 'URGENCIA'
            WHEN descricao ~ 'REQUERIMENTO' THEN 'REQUERIMENTO PROCEDIMENTAL'
            WHEN descricao ~ '(PARECER|PRESSUPOSTOS)' THEN 'PARECER'
            WHEN descricao ~ '(DESTAQUE|EMENDA(?! A CONSTITUICAO)|MANTID[OA])' THEN 'EMENDA/DESTAQUE'
            WHEN descricao ~ '(PROJETO|PROPOSTA|MEDIDA PROVISORIA|SUBSTITUTIVO|REDACAO FINAL)' THEN 'MERITO'
            ELSE 'OUTROS'
        END AS classe_votacao
    FROM objetos
)

SELECT
    casa,
    votacao_id_nk,
    sessao_id,
    data_votacao,
    sigla_orgao,
    descricao,
    proposicao_id_nk,
    aprovado,
    fl_secreta,
    qt_votos_sim_secreta,
    qt_votos_nao_secreta,
    qt_abstencao_secreta,
    classe_votacao,
    '{{ run_started_at }}'::TIMESTAMPTZ AS model_run_at
FROM classificadas
