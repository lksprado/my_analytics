"""Camada compartilhada dos relatórios do domínio finanças.

Consumido por `relatorio-financas`, o fechamento do mês anterior rodado nos
primeiros dias do mês seguinte (quatro PDFs).

O que mora aqui é o que não é específico do montador: os parâmetros da política
(`politica`), a formatação pt-BR (`formato`), os agregados (`calculo`), os
gráficos SVG (`graficos`) e os blocos de HTML (`blocos`). O que é específico de
um relatório — capa, rodapé, tarja de prontidão, ordem das seções — fica no
montador daquele relatório.

Regras fixas, política vigente, perfil de referência, natureza das categorias e
fatos relevantes não são copiados: `politica` os lê dos `.md` em
`models/presentation/financas/` a cada execução.
"""

