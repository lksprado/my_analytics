"""Parâmetros da política de investimento e vocabulário do domínio.

Cópia única, em Python, do que está escrito em
`models/marts/financas/_docs_financas.md`. O Markdown é a fonte de verdade —
o montador não lê Markdown, e por isso os números vivem aqui também. Mudou lá,
muda aqui **na mesma passada**: os dois já divergiram uma vez e o PDF mensal
saiu com alvos que contradiziam a política escrita.
"""
from __future__ import annotations

# Paleta da skill `dataviz`, na ordem declarada. Cor é por entidade, nunca por
# ranking: a mesma camada e a mesma categoria têm o mesmo slot em todo gráfico
# dos dois relatórios.
SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100",
          "#e87ba4", "#008300", "#4a3aa7", "#e34948"]

# ------------------------------------------------------------------ pessoas ---

NOME = {"lucas": "Lucas", "jessica": "Jéssica", "deusa": "Deusa"}
# Escopos de relatório de investimento — um por titular.
ESCOPOS_INVESTIMENTO = ["lucas", "jessica", "deusa"]
# Quem tem série de NÍVEL por pessoa em marts.patrimonio — é o que o relatório
# de fechamento consome para a seção de patrimônio individual. Deusa não entra:
# a planilha dela alimenta int_patrimonio_mensal_deusa, que traz só o total
# líquido, sem abertura por conta.
# Atenção: isto NÃO é o mesmo que ter índice em marts.riqueza. Deusa tem índice
# acumulado lá desde 2026-08 e aparece na seção de desempenho do relatório de
# meio de mês; o que ela não tem é nível por conta aqui.
COM_PATRIMONIO = ["lucas", "jessica"]

# --------------------------------------------------------------- categorias ---

CATEGORIAS = ["mercado", "diversos", "assinaturas", "role",
              "transporte", "apartamento", "saude", "educacao"]
ROTULO_CAT = {"mercado": "Mercado", "diversos": "Diversos",
              "assinaturas": "Assinaturas", "role": "Rolê",
              "transporte": "Transporte", "apartamento": "Apartamento",
              "saude": "Saúde", "educacao": "Educação"}
COR_CAT = {c: SERIES[i] for i, c in enumerate(CATEGORIAS)}

# Categorias que podem entrar em sugestão de corte, na ordem em que a política
# manda cortar. `saude` e `educacao` ficam de fora por decisão registrada no
# glossário; `apartamento` e `assinaturas` são fixas e não se comprimem dentro
# do mês. É a lista que o relatório de meio de mês usa para calcular margem
# ainda disponível — só faz sentido oferecer folga onde há decisão a tomar.
CATEGORIAS_COMPRIMIVEIS = ["role", "diversos", "mercado"]

# ------------------------------------------------------------------ camadas ---

COR_CAMADA = {"RESERVA": SERIES[0], "CRESCIMENTO": SERIES[1], "RENDA": SERIES[2],
              "RESERVA ESTRATEGICA": SERIES[3], "NAO CLASSIFICADO": "#7a7975"}
# Camadas com alocação-alvo, na ordem em que saem no relatório.
CAMADAS_COM_ALVO = ["RESERVA", "CRESCIMENTO", "RENDA"]
# Camadas reportadas à parte, sem alvo (ver `camada_investimento`).
CAMADAS_SEM_ALVO = ["RESERVA ESTRATEGICA", "NAO CLASSIFICADO"]
# Os valores no banco não têm acento; o PDF tem.
ROTULO_CAMADA = {"RESERVA": "Reserva", "CRESCIMENTO": "Crescimento",
                 "RENDA": "Renda", "RESERVA ESTRATEGICA": "Reserva estratégica",
                 "NAO CLASSIFICADO": "Não classificado"}

# Alocação-alvo, cópia da tabela de `politica_investimentos` em
# _docs_financas.md. Percentuais sobre a carteira EXCLUINDO
# 'RESERVA ESTRATEGICA' e 'NAO CLASSIFICADO' — as duas não têm alvo.
ALVOS_CAMADA = {
    "lucas":   {"RESERVA": 30, "CRESCIMENTO": 50, "RENDA": 20},
    "jessica": {"RESERVA": 30, "CRESCIMENTO": 70, "RENDA": 0},
    "deusa":   {"RESERVA": 30, "CRESCIMENTO": 60, "RENDA": 10},
}
# Banda de tolerância da alocação, em pontos percentuais. Desvio dentro dela
# não gera recomendação.
BANDA_CAMADA_PP = 5

# ------------------------------------------------------------------- metas ---

APORTE_ALVO = {"lucas": 4000, "jessica": 2000, "deusa": 3000}
# Reserva-alvo = max(N x mediana da despesa de 6 meses, R$ 100.000). O N de
# Deusa está na política mas não tem uso aqui: não há despesa dela no warehouse
# para dimensionar cobertura, então o KPI só existe no relatório de orçamento.
META_RESERVA_MESES = {"casal": 6, "deusa": 12}
META_RESERVA_PISO = 100000
# Taxa de poupança alvo, % da receita líquida do casal. Consumida pelo
# relatório de meio de mês, que projeta o fechamento e mede a folga contra ela.
META_POUPANCA_PCT = 35
FGC_FOLGA_MINIMA = 50000
# Exposição internacional alvo, % da carteira.
META_INTERNACIONAL_PCT = {"lucas": 15, "jessica": 15, "deusa": 10}

# ---------------------------------------------------------------- glossário ---
# Resumo de _docs_financas.md. Ao editar lá, propague para cá — a SKILL.md
# exige que os dois não divirjam, e já divergiram uma vez.

TEXTO_CAMADA = {
    "RESERVA": "Liquidez e preservação de capital. Resgate em até D+1, sem "
               "marcação a mercado negativa, e destinado a cobrir despesa — "
               "não a ser carregado até o vencimento.",
    "CRESCIMENTO": "Acumulação de patrimônio no longo prazo, aceitando "
                   "volatilidade. Horizonte de cinco anos ou mais.",
    "RENDA": "Geração de fluxo de caixa recorrente e previsível. O que "
             "qualifica é a regularidade do pagamento, não o retorno total "
             "nem o prazo.",
    "RESERVA ESTRATEGICA": "Reserva de valor em cripto, moeda estrangeira e "
                           "cashback. Líquida, mas dependente de cenário "
                           "favorável para ser liquidada e sem novos aportes — "
                           "por isso fica fora da alocação-alvo.",
    "NAO CLASSIFICADO": "Ativo ainda sem camada atribuída na planilha. Não é "
                        "uma alocação — é pendência de classificação.",
}
TEXTO_CATEGORIA = {
    "mercado": "Abastecimento da casa: supermercado, hortifruti, feira, "
               "açougue, peixaria, padaria de despensa, marmitas fit, bebidas "
               "para consumo em casa, limpeza, higiene pessoal e itens "
               "domésticos não duráveis. Não inclui refeição fora nem "
               "delivery (rolê), farmácia (saúde) nem móveis e "
               "eletrodomésticos.",
    "diversos": "Categoria residual: vestuário e calçado, presentes, "
                "eletrônicos e acessórios pessoais, objetos domésticos, "
                "clube de tiro, charutos, salão de beleza e imprevistos. O "
                "que não cabe nas demais.",
    "assinaturas": "Serviços recorrentes de cobrança automática: streaming de "
                   "vídeo e música, nuvem, licenças de software, telefonia "
                   "móvel, academia e clubes com mensalidade, jornais e "
                   "revistas. Não inclui internet fixa (apartamento), plano "
                   "de saúde nem mensalidade de curso.",
    "role": "Lazer e consumo fora de casa: bares e restaurantes, delivery e "
            "aplicativos de comida, cafés, cinema, shows, eventos, viagens "
            "(hospedagem, aluguel de veículo, passeios), compras de mercado "
            "só para eventos e hobbies em geral.",
    "transporte": "Combustível, aplicativos de transporte, transporte "
                  "público, estacionamento, pedágio, manutenção e revisão do "
                  "veículo, seguro, IPVA e licenciamento. Viagem de lazer com "
                  "hospedagem é rolê.",
    "apartamento": "Moradia e sua manutenção: condomínio, IPTU, energia "
                   "elétrica, internet fixa, móveis, reformas e reparos. "
                   "Produtos de limpeza e consumo da casa são mercado.",
    "saude": "Plano de saúde, consultas, exames, procedimentos, odontologia, "
             "terapia, farmácia e medicamentos. Academia é assinatura.",
    "educacao": "Cursos, graduação e pós-graduação, certificações, livros, "
                "material didático e plataformas de ensino.",
}
