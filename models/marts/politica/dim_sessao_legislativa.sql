{{ config(
    tags=["politica"]
) }}

WITH
legislaturas AS (
    SELECT
        legislatura,
        inicio,
        fim
    FROM {{ ref('dim_legislatura') }}
),

-- A sessão legislativa vai de 1º/fev a 31/jan, quatro por legislatura.
sessoes AS (
    SELECT
        l.legislatura,
        s.sessao_legislativa,
        (l.inicio + (s.sessao_legislativa - 1) * INTERVAL '1 year')::DATE             AS inicio,
        LEAST((l.inicio + s.sessao_legislativa * INTERVAL '1 year')::DATE - 1, l.fim) AS fim
    FROM legislaturas AS l
    CROSS JOIN GENERATE_SERIES(1, 4) AS s (sessao_legislativa)
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['legislatura', 'sessao_legislativa']) }} AS sk_sessao_legislativa,
        legislatura,
        sessao_legislativa,
        inicio,
        fim,
        '{{ run_started_at }}'::TIMESTAMPTZ                                           AS model_run_at
    FROM sessoes
)

SELECT * FROM final
