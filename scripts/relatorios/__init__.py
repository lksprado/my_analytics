"""Camada compartilhada dos relatórios do domínio finanças.

Dois relatórios consomem este pacote, com cadências diferentes:

    relatorio-financas    fechamento do mês anterior, rodado nos primeiros
                          dias do mês seguinte — quatro PDFs
    relatorio-meio-mes    acompanhamento do mês em andamento, rodado entre os
                          dias 15 e 20 — dois PDFs

O que mora aqui é o que os dois precisam ver igual: os parâmetros da política
(`politica`), a formatação pt-BR (`formato`), os agregados (`calculo`), os
gráficos SVG (`graficos`) e os blocos de HTML (`blocos`). O que é específico de
um relatório — capa, rodapé, tarja de prontidão, ordem das seções — fica no
montador daquele relatório.

Os parâmetros da política e os verbetes do glossário não são copiados: `politica`
os lê de `models/presentation/financas/_docs_financas.md` a cada execução.
"""

