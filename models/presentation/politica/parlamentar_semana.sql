{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook="{{ apagar_periodo_vivo('periodo_inicio', 'week') }}",
    on_schema_change='append_new_columns',
    tags=["politica"]
) }}

-- depends_on: {{ ref('seed_legislaturas') }}

{{ parlamentar_periodo('semana') }}
