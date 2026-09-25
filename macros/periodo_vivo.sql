{#-
    Incremental do domínio política por período vivo: a cada build reprocessa tudo a partir do início da
    legislatura corrente, alinhado à granularidade do período (legislatura, year, quarter ou week).
    O passado fica congelado; carga retroativa, mudança de seed ou de regra exige --full-refresh.
-#}
{% macro inicio_periodo_vivo(granularidade='legislatura') %}
    {%- if not execute -%}
        {{ return("'1900-01-01'::DATE") }}
    {%- endif -%}
    {%- set truncado = 'inicio' if granularidade == 'legislatura' else "DATE_TRUNC('" ~ granularidade ~ "', inicio)" -%}
    {%- set consulta -%}
        SELECT ({{ truncado }})::DATE
        FROM {{ ref('seed_legislaturas') }}
        WHERE inicio <= CURRENT_DATE
        ORDER BY inicio DESC
        LIMIT 1
    {%- endset -%}
    {{ return("'" ~ run_query(consulta).columns[0].values()[0] ~ "'::DATE") }}
{% endmacro %}

{% macro apagar_periodo_vivo(expressao, granularidade='legislatura') %}
    {%- if is_incremental() -%}
        DELETE FROM {{ this }} WHERE {{ expressao }} >= {{ inicio_periodo_vivo(granularidade) }}
    {%- endif -%}
{% endmacro %}
