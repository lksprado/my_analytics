{% macro extract_product_unit(expr) -%}
    {%- set unit_token -%}
        '(\d+([.,]\d+)?\s*(mg|kg|g|gramas?|ml|l|litros?|quilos?|un|unid|unidades?|rolos|dúzias?|folhas))\M'
    {%- endset -%}
    {%- set count_token -%}
        '(c/|com)\s*\d+\M'
    {%- endset -%}
    {%- set bare_unit -%}
        '\m(kg|quilo|litro|l|ml|un|maço|unidade)\M'
    {%- endset -%}
    CASE
        WHEN REGEXP_COUNT(LOWER({{ expr }}), {{ unit_token }}) > 0
            THEN REGEXP_SUBSTR(LOWER({{ expr }}), {{ unit_token }}, 1, REGEXP_COUNT(LOWER({{ expr }}), {{ unit_token }}))
        WHEN LOWER({{ expr }}) ~ {{ count_token }}
            THEN REGEXP_REPLACE(REGEXP_SUBSTR(LOWER({{ expr }}), {{ count_token }}), '\D', '', 'g') || ' un'
        WHEN LOWER({{ expr }}) ~ {{ bare_unit }}
            THEN REGEXP_SUBSTR(LOWER({{ expr }}), {{ bare_unit }})
    END
{%- endmacro %}


{% macro product_unit_name(token) -%}
    {%- set letters -%}
        REGEXP_REPLACE({{ token }}, '[0-9.,\s]', '', 'g')
    {%- endset -%}
    CASE
        WHEN {{ letters }} IN ('kg', 'quilo', 'quilos') THEN 'kilogram'
        WHEN {{ letters }} IN ('g', 'grama', 'gramas') THEN 'gram'
        WHEN {{ letters }} IN ('ml') THEN 'millilitre'
        WHEN {{ letters }} IN ('l', 'litro', 'litros') THEN 'litre'
        WHEN {{ letters }} IN ('un', 'unid', 'unidade', 'unidades', 'rolos', 'dúzia', 'dúzias', 'folhas', 'maço') THEN 'unity'
    END
{%- endmacro %}


{% macro normalize_product_unit(token) -%}
    {%- set unit_name = product_unit_name(token) -%}
    {%- set unit_value -%}
        COALESCE(NULLIF(REPLACE(REGEXP_REPLACE({{ token }}, '[^0-9.,]', '', 'g'), ',', '.'), '')::NUMERIC, 1)
    {%- endset -%}
    {{ unit_name }} AS unit_normalized,
    CASE
        WHEN {{ unit_name }} IN ('kilogram', 'gram') THEN 'weight'
        WHEN {{ unit_name }} IN ('litre', 'millilitre') THEN 'volume'
        WHEN {{ unit_name }} = 'unity' THEN 'unit'
    END AS unity_type,
    {{ unit_value }} AS unity_value,
    CASE
        WHEN {{ unit_name }} IN ('kilogram', 'litre') THEN {{ unit_value }} * 1000
        ELSE {{ unit_value }}
    END AS unity_value_normalized
{%- endmacro %}
