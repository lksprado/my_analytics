{{ config(
    tags=["politica"]
) }}

WITH
indicadores (fonte, indicador, descricao, unidade, escala, periodo_tipo, url_fonte) AS (
    VALUES
    ('RADAR CONGRESSO', 'GOVERNISMO TRIMESTRAL', 'Alinhamento do voto à orientação do líder do Governo no trimestre; voto diferente, abstenção ou falta contam como não alinhados.', 'PERCENTUAL', '0 a 100', 'TRIMESTRE', 'https://radar.congressoemfoco.com.br'),
    ('RADAR CONGRESSO', 'GOVERNISMO NO MANDATO', 'Alinhamento acumulado no mandato até o último trimestre publicado; qt_base é o total de votações consideradas.', 'PERCENTUAL', '0 a 100', 'MANDATO', 'https://radar.congressoemfoco.com.br'),
    ('RANKING DOS POLITICOS', 'PONTUACAO GERAL', 'Pontuação atual do parlamentar no Ranking dos Políticos.', 'PONTOS', '0 a 10', 'ATUAL', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'POSICAO GERAL', 'Posição entre todos os parlamentares avaliados.', 'POSICAO', '1 = melhor', 'ATUAL', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'POSICAO NA CASA', 'Posição dentro da casa.', 'POSICAO', '1 = melhor', 'ATUAL', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'POSICAO NO PARTIDO', 'Posição dentro do partido.', 'POSICAO', '1 = melhor', 'ATUAL', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'POSICAO NA UF', 'Posição dentro da UF.', 'POSICAO', '1 = melhor', 'ATUAL', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'POSICAO NA CASA E UF', 'Posição dentro da casa na UF.', 'POSICAO', '1 = melhor', 'ATUAL', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'PONTUACAO ANUAL', 'Pontuação do parlamentar no ano.', 'PONTOS', '0 a 10', 'ANO', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'NOTA VOTACOES', 'Nota do ano pelas posições de voto.', 'PONTOS', 'varia por ano', 'ANO', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'NOTA GASTOS', 'Nota do ano pelo controle de gastos.', 'PONTOS', 'varia por ano', 'ANO', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'NOTA PRESENCA', 'Nota do ano pela presença.', 'PONTOS', 'varia por ano', 'ANO', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'NOTA PRIVILEGIOS', 'Nota do ano pela rejeição de privilégios.', 'PONTOS', 'varia por ano', 'ANO', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'BONUS PROCESSOS', 'Bônus ou penalidade do ano por processos.', 'PONTOS', 'varia por ano', 'ANO', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'BONUS PRODUCAO LEGISLATIVA', 'Bônus do ano por produção legislativa.', 'PONTOS', 'varia por ano', 'ANO', 'https://ranking.org.br'),
    ('RANKING DOS POLITICOS', 'BONUS ARTICULACAO LEGISLATIVA', 'Bônus do ano por articulação legislativa.', 'PONTOS', 'varia por ano', 'ANO', 'https://ranking.org.br')
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['fonte', 'indicador']) }} AS sk_indicador_externo,
        fonte,
        indicador,
        descricao,
        unidade,
        escala,
        periodo_tipo,
        url_fonte,
        '{{ run_started_at }}'::TIMESTAMPTZ                            AS model_run_at
    FROM indicadores
)

SELECT * FROM final
