-- Remove as 58 tabelas órfãs do analytics_dev (sem modelo no manifest de 2026-09-23).
-- Lista gerada por scripts/orfaos_prod.py. Sem CASCADE: se algo depender de um
-- órfão, o DROP falha e a transação inteira é revertida.
--
-- Backup antes:
--   pg_dump "postgresql://postgres@localhost:5435/analytics_dev" \
--     -n marts_demodados -n marts_energy -n marts_financas \
--     -n presentation_demodados -n staging_camara_deputados \
--     -t marts_politica.dim_dates -t marts_politica.fct_ecidadania_bignumbers \
--     -t marts_politica.fct_ecidadania_proposicoes -t marts_politica.fct_radarcongresso_governismo \
--     -t presentation_politica.comparativo_governismo_legislatura \
--     -t presentation_politica.comparativo_governismo_por_partido \
--     -t presentation_politica.comparativo_governismo_resumo \
--     -t presentation_politica.comparativo_governismo_trimestre \
--     -t staging_ecidadania.stg_ecidadania_mais_votados -t staging_ecidadania.stg_ecidadania_paginas \
--     -t staging_senado.stg_senado_processos -t staging_senado.stg_senado_votacoes_orientacao \
--     > backup_orfaos_dev.sql
--
-- Rodar:
--   psql "postgresql://postgres@localhost:5435/analytics_dev" -v ON_ERROR_STOP=1 -f scripts/drop_orfaos_dev.sql

BEGIN;

-- Schemas que saíram do projeto. O DROP SCHEMA sem CASCADE falha se sobrar algo neles.

-- marts_demodados
DROP TABLE marts_demodados.dim_dates;
DROP TABLE marts_demodados.dim_orientacao_votacoes;
DROP TABLE marts_demodados.dim_parlamentares;
DROP TABLE marts_demodados.dim_parlamentares_score;
DROP TABLE marts_demodados.dim_parlamentares_score_historico;
DROP TABLE marts_demodados.dim_proposicoes;
DROP TABLE marts_demodados.dim_votacoes;
DROP TABLE marts_demodados.fct_ecidadania_bignumbers;
DROP TABLE marts_demodados.fct_ecidadania_proposicoes;
DROP TABLE marts_demodados.fct_votos;
DROP SCHEMA marts_demodados;

-- marts_energy
DROP TABLE marts_energy.solar_energy_daily_weather_conditions;
DROP TABLE marts_energy.solar_energy_hourly_generation;
DROP SCHEMA marts_energy;

-- marts_financas
DROP TABLE marts_financas.ativos_sem_classificacao;
DROP TABLE marts_financas.carteira;
DROP TABLE marts_financas.carteira_agregada;
DROP TABLE marts_financas.carteira_auditoria;
DROP TABLE marts_financas.carteira_classificacao;
DROP TABLE marts_financas.carteira_deusa;
DROP TABLE marts_financas.carteira_deusa_agregada;
DROP TABLE marts_financas.carteira_jessica;
DROP TABLE marts_financas.carteira_jessica_agregada;
DROP TABLE marts_financas.carteira_lucas;
DROP TABLE marts_financas.carteira_lucas_agregada;
DROP TABLE marts_financas.consumo;
DROP TABLE marts_financas.dividendos;
DROP TABLE marts_financas.indicadores;
DROP TABLE marts_financas.luz;
DROP TABLE marts_financas.patrimonio;
DROP TABLE marts_financas.patrimonio_deusa;
DROP TABLE marts_financas.patrimonio_mom;
DROP TABLE marts_financas.resultado;
DROP TABLE marts_financas.riqueza;
DROP TABLE marts_financas.risco_fgc_deusa;
DROP TABLE marts_financas.risco_fgc_jessica;
DROP TABLE marts_financas.risco_fgc_lucas;
DROP TABLE marts_financas.verificar_fgc;
DROP SCHEMA marts_financas;

-- presentation_demodados
DROP TABLE presentation_demodados.governismo;
DROP TABLE presentation_demodados.governismo_por_parlamentar_legislatura;
DROP TABLE presentation_demodados.governismo_por_parlamentar_legislatura_ajustado;
DROP SCHEMA presentation_demodados;

-- staging_camara_deputados
DROP TABLE staging_camara_deputados.stg_camara_deputados;
DROP TABLE staging_camara_deputados.stg_camara_legislaturas;
DROP TABLE staging_camara_deputados.stg_camara_proposicoes;
DROP TABLE staging_camara_deputados.stg_camara_temas;
DROP TABLE staging_camara_deputados.stg_camara_votacoes;
DROP TABLE staging_camara_deputados.stg_camara_votacoes_orientacao;
DROP TABLE staging_camara_deputados.stg_camara_votos_deputados;
DROP SCHEMA staging_camara_deputados;

-- Sobras em schemas que continuam em uso

-- marts_politica
DROP TABLE marts_politica.dim_dates;
DROP TABLE marts_politica.fct_ecidadania_bignumbers;
DROP TABLE marts_politica.fct_ecidadania_proposicoes;
DROP TABLE marts_politica.fct_radarcongresso_governismo;

-- presentation_politica
DROP TABLE presentation_politica.comparativo_governismo_legislatura;
DROP TABLE presentation_politica.comparativo_governismo_por_partido;
DROP TABLE presentation_politica.comparativo_governismo_resumo;
DROP TABLE presentation_politica.comparativo_governismo_trimestre;

-- staging_ecidadania
DROP TABLE staging_ecidadania.stg_ecidadania_mais_votados;
DROP TABLE staging_ecidadania.stg_ecidadania_paginas;

-- staging_senado
DROP TABLE staging_senado.stg_senado_processos;
DROP TABLE staging_senado.stg_senado_votacoes_orientacao;

COMMIT;
