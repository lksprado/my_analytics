{{ config(
    materialized='incremental',
    incremental_strategy='append',
    pre_hook="{{ apagar_periodo_vivo('data_trimestre', 'quarter') }}",
    on_schema_change='append_new_columns',
    tags=["politica"]
) }}

-- depends_on: {{ ref('seed_legislaturas') }}

{{ comportamento_entidade('bancada') }}
