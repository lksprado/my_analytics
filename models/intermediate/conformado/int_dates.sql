{{ config(
    tags=["datas"]
) }}

{#- Início em 2019 e não em 2020: a planilha de patrimônio de Deusa começa em
    set/2019, e todo modelo que junta com esta dimensão o faz por INNER JOIN a
    partir dos próprios dados — uma espinha que começa depois do dado descarta a
    linha em silêncio. Era o que acontecia com os quatro primeiros meses dela em
    marts.patrimonio_deusa e em marts.carteira. Estender para trás é aditivo:
    nenhum consumidor usa esta tabela como spine sem limitar pelo min/max do
    próprio dado. -#}
{{ dbt_date.get_date_dimension("2019-01-01", "2050-12-31") }}