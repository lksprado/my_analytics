{# dbt_orphan compara schema por igualdade exata; os schemas reais são <camada>_<subpasta>, então a lista vem do banco. #}
{% macro cleanup_orphans_camadas(dry_run=true) %}
    {% if not execute %}
        {{ return('') }}
    {% endif %}

    {% set schemas_query %}
        select schema_name
        from information_schema.schemata
        where schema_name in ('seeds', 'snapshots', 'staging', 'intermediate', 'marts', 'presentation')
            or schema_name ~ '^(snapshots|staging|intermediate|marts|presentation)_'
        order by schema_name
    {% endset %}

    {% set schemas = run_query(schemas_query).columns[0].values() | list %}

    {% do dbt_orphan.cleanup_orphans(schemas=schemas, dry_run=dry_run) %}
{% endmacro %}
