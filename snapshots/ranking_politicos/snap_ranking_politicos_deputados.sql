{% snapshot snap_ranking_politicos_deputados %}

{{
    config(
        strategy='check',
        unique_key='id',
        check_cols='all',
        hard_deletes='new_record'
    )
}}

WITH
source AS (
    -- Metadados de carga ficam de fora: só mudança no valor publicado abre versão nova.
    SELECT
        id,
        nome,
        nome_eleitoral,
        nome_civil,
        url_foto,
        cargo,
        partido,
        situacao,
        uf,
        slug,
        pontuavel,
        composicao_pontuacao_pontuacao,
        composicao_pontuacao_anos,
        composicao_pontuacao_ranking_geral,
        composicao_pontuacao_ranking_geral_variacao,
        composicao_pontuacao_ranking_casa,
        composicao_pontuacao_ranking_casa_variacao,
        composicao_pontuacao_ranking_partido,
        composicao_pontuacao_ranking_partido_variacao,
        composicao_pontuacao_ranking_estado,
        composicao_pontuacao_ranking_estado_variacao,
        composicao_pontuacao_ranking_casa_estado,
        composicao_pontuacao_ranking_casa_estado_variacao
    FROM {{ source('ranking', 'raw_ranking_deputados') }}
)

SELECT * FROM source

{% endsnapshot %}
