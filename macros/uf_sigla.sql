{#-
  De-para do nome da unidade federativa para a sigla de duas letras.

  O Ranking dos Políticos entrega a UF por extenso ('SAO PAULO'); a Câmara e o
  Senado entregam a sigla. Os quatro modelos de scores precisavam da conversão
  e cada um carregava sua própria cópia do CASE de 27 WHEN — o mesmo caminho
  que levou normaliza_instituicao a existir.

  Espera o valor já em maiúsculas e sem acento, como clean_string(campo,
  'upper') devolve. Sem correspondência o resultado é NULL, não a sigla
  errada: UF nula num score é sinal de grafia nova na origem.

  `indent` é o recuo (em espaços) da coluna no SELECT que chama a macro, só
  para o SQL compilado sair legível e passar no sqlfluff.
-#}
{% macro uf_sigla(field='uf', indent=8) -%}
{%- set espaco = ' ' * indent -%}
{%- set de_para = {
    'AC': 'ACRE',
    'AL': 'ALAGOAS',
    'AP': 'AMAPA',
    'AM': 'AMAZONAS',
    'BA': 'BAHIA',
    'CE': 'CEARA',
    'DF': 'DISTRITO FEDERAL',
    'ES': 'ESPIRITO SANTO',
    'GO': 'GOIAS',
    'MA': 'MARANHAO',
    'MT': 'MATO GROSSO',
    'MS': 'MATO GROSSO DO SUL',
    'MG': 'MINAS GERAIS',
    'PA': 'PARA',
    'PB': 'PARAIBA',
    'PR': 'PARANA',
    'PE': 'PERNAMBUCO',
    'PI': 'PIAUI',
    'RJ': 'RIO DE JANEIRO',
    'RN': 'RIO GRANDE DO NORTE',
    'RS': 'RIO GRANDE DO SUL',
    'RO': 'RONDONIA',
    'RR': 'RORAIMA',
    'SC': 'SANTA CATARINA',
    'SP': 'SAO PAULO',
    'SE': 'SERGIPE',
    'TO': 'TOCANTINS'
} -%}
CASE
{%- for sigla, nome in de_para.items() %}
{{ espaco }}    WHEN {{ field }} = '{{ nome }}' THEN '{{ sigla }}'
{%- endfor %}
{{ espaco }}END
{%- endmacro %}
