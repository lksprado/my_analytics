{#
    Schema = <camada>_<subpasta>, derivado do caminho do arquivo.

      models/staging/avenue/stg_x.sql          -> staging_avenue
      models/intermediate/financas/int_x.sql   -> intermediate_financas
      models/marts/inflation/mrt_x.sql         -> marts_inflation
      models/staging/nhl/parameters/vw_x.sql   -> staging_nhl   (só a 1ª subpasta conta)
      models/marts/x.sql                       -> marts         (sem subpasta)
      snapshots/financas/snap_x.sql            -> snapshots_financas
      snapshots/snap_x.sql                     -> snapshots
      seeds/seed_x.csv                         -> seeds         (sempre, com ou sem subpasta)

    Para models, snapshots e seeds a regra acima decide e `+schema` é ignorado —
    não há como distinguir um `schema` do dbt_project.yml de um posto no config
    do recurso. Os demais recursos (testes com store_failures, arquivos
    soltos na raiz de models/) seguem a regra antiga: `custom_schema_name`
    quando existe, senão `target.schema`.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set pastas = node.path.split('/')[:-1] -%}

    {%- if node.resource_type == 'seed' -%}
        seeds
    {%- elif node.resource_type == 'snapshot' -%}
        {{ (['snapshots'] + pastas[:1]) | join('_') }}
    {%- elif node.resource_type == 'model' and pastas | length > 0 -%}
        {{ pastas[:2] | join('_') }}
    {%- elif custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
