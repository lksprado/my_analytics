#!/usr/bin/env python3
"""Monta o relatório de meio de mês a partir do JSON extraído.

    montar_meio_mes.py --dados D.json --narrativa N.json --saida R.pdf

Um relatório só, do casal — despesa não tem lançamento por pessoa. Duas
partes, com recortes de tempo diferentes e deliberadamente não misturados:

    partes 1-4   mês CORRENTE, até o dia do corte: ritmo do gasto, projeção de
                 fechamento e a margem que ainda cabe gastar. É acionável
                 justamente porque o mês não acabou.
    parte 5      mês ANTERIOR: desempenho do patrimônio DO CASAL contra CDI e
                 inflação pessoal. Mora aqui, e não no relatório de fechamento,
                 porque o IPCA só sai por volta do dia 10 — no dia 1º o número
                 não existe.
    parte 6      mês ANTERIOR: patrimônio e ativos DE DEUSA, escopo apartado.
                 Ela não tem despesa lançada no warehouse, então não aparece em
                 nada das partes 1 a 4; e o patrimônio dela nunca se soma ao do
                 casal — são planilhas, carteiras e objetivos distintos.

Divisão de responsabilidades igual à do fechamento: este script renderiza tudo
que é calculável, e o arquivo de narrativa traz só o texto analítico.

Dois documentos, um script (`--escopo`):

    casal   o relatório acima, com a leitura patrimonial de Deusa como uma
            seção entre oito
    deusa   só a leitura dela, com capa, narrativa e rodapé próprios — mesmos
            blocos, outro leitor, e entregável sem expor o orçamento do casal.
            Não tem partes 1 a 4: sem despesa lançada não há ritmo, projeção
            nem orçamento a calcular.

Estrutura do arquivo de narrativa (todas as chaves opcionais):

    {
      "sumario": "<p>…</p>",
      "diagnostico_ritmo": "<p>…</p>",
      "diagnostico_categorias": "<p>…</p>",
      "diagnostico_desempenho": "<p>…</p>",   # só se pronto_indicadores
      "diagnostico_deusa": "<p>…</p>",        # só se pronto_deusa
      "diagnostico_ativos": "<p>…</p>",       # só no --escopo deusa
      "recomendacoes": [{"titulo": "…", "texto": "…"}],
      "premissas": ["…"]
    }
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "scripts"))

from relatorios.blocos import (
    bloco,
    css_inline,
    glossario_categorias,
    kpi,
    recomendacoes_html,
    rotulo_chip,
    secao,
    tabela,
    tag,
)
from relatorios.calculo import mediana
from relatorios.formato import (
    brl,
    classe_delta,
    data_br,
    dia_mes_br,
    esc,
    mes_curto,
    mes_extenso,
    num,
    pct,
    sinal,
)
from relatorios.graficos import barras_desvio, barras_empilhadas, legenda, linhas, linhas_dia
from relatorios.politica import (
    CATEGORIAS,
    CATEGORIAS_COMPRIMIVEIS,
    COR_CAT,
    META_POUPANCA_PCT,
    ROTULO_CAT,
    SERIES,
)
from relatorios.saida import escrever

# Marcas de referência: a envoltória e a mediana dos meses fechados não são
# entidades, são contexto. Vão em tinta neutra, e a mediana se distingue por
# traço, não por cor — cor categórica aqui faria o leitor contar três séries.
COR_REF = "#52514e"
# Acima deste desvio a projeção de uma categoria deixa de ser ruído.
BANDA_CATEGORIA_PCT = 15
# Ressalva que vale igual para o índice do casal e para o de Deusa: os dois
# compõem aporte com rentabilidade. Impressa nas duas seções, na mesma redação,
# porque uma só das duas com a ressalva convida a comparar como se a outra
# fosse retorno puro.
NOTA_INDICE = (
    '<p class="sub"><strong>O índice de patrimônio compõe aporte e '
    "rentabilidade — não é retorno de carteira</strong>, e compará-lo ao CDI "
    'superestima o desempenho. Serve para responder "o patrimônio cresceu mais '
    'que a inflação?", não "a carteira bateu o CDI?".</p>'
)


# ------------------------------------------------------------------ cálculo ---


def curva_densa(pontos, dias, chave="acumulado"):
    """Acumulado dia a dia, preenchido para frente.

    A série do banco só tem linha nos dias em que houve lançamento. Num
    acumulado, dia sem lançamento repete o valor anterior — deixar buraco faria
    a linha cair até zero no gráfico."""
    por_dia = {int(p["dia_fatura"]): float(p[chave]) for p in pontos}
    saida, ultimo = [], 0.0
    for d in dias:
        ultimo = por_dia.get(d, ultimo)
        saida.append(ultimo)
    return saida


def envelope(historico, dias):
    """Mínimo, mediana e máximo por dia entre os meses fechados."""
    por_mes = {}
    for p in historico:
        por_mes.setdefault(p["mes"], []).append(p)
    curvas = [curva_densa(ps, dias) for ps in por_mes.values()]
    if not curvas:
        return None, None, None
    lo = [min(c[i] for c in curvas) for i in range(len(dias))]
    hi = [max(c[i] for c in curvas) for i in range(len(dias))]
    med = [mediana([c[i] for c in curvas]) for i in range(len(dias))]
    return lo, med, hi


def por_categoria(d):
    return {c["categoria"]: c for c in d["categorias"]}


# ------------------------------------------------------------------ montagem ---


def aviso_prontidao(meta):
    """Tarja de dado insuficiente. Dois portões independentes: um mês ainda
    cedo demais não impede a leitura de benchmark do mês anterior, e indexador
    não publicado não impede a leitura de ritmo."""
    pr = meta["prontidao"]
    avisos = []
    if not pr["pronto_ritmo"]:
        itens = "".join(f"<li>{esc(p)}</li>" for p in pr["pendencias_ritmo"])
        avisos.append(
            '<div class="destaque-bloco alerta"><h4>Ritmo do mês — base '
            "insuficiente</h4><p>O acumulado do mês corrente ainda não sustenta "
            "projeção. Os números das seções de ritmo, categorias e margem "
            "estão parciais e não devem embasar decisão.</p>"
            f"<ul>{itens}</ul></div>"
        )
    if not pr["pronto_indicadores"]:
        itens = "".join(f"<li>{esc(p)}</li>" for p in pr["pendencias_indicadores"])
        ult = pr.get("ultimo_mes_indicador")
        alt = (f"<p>Último mês com indexador publicado: <strong>{mes_extenso(ult)}</strong>.</p>") if ult else ""
        avisos.append(
            '<div class="destaque-bloco alerta"><h4>Desempenho — indexadores '
            "ainda não publicados</h4>"
            f"<ul>{itens}</ul>{alt}</div>"
        )
    if not pr.get("pronto_deusa", True):
        itens = "".join(f"<li>{esc(p)}</li>" for p in pr.get("pendencias_deusa", []))
        ult = pr.get("ultimo_mes_carteira_deusa")
        alt = (f"<p>Última posição disponível: <strong>{mes_extenso(ult)}</strong>.</p>") if ult else ""
        avisos.append(
            '<div class="destaque-bloco alerta"><h4>Ativos de Deusa — carteira '
            "sem a posição do mês</h4>"
            f"<ul>{itens}</ul>{alt}</div>"
        )
    return "".join(avisos)


def cabecalho(meta):
    corte = f"01/{meta['mes_corrente'][5:7]} a {dia_mes_br(meta['hoje'])}"
    return f"""<meta charset="utf-8"><title>Acompanhamento de meio de mês</title>
<style>{css_inline()}</style>
<div class="capa">
  <div class="eyebrow">Acompanhamento de meio de mês · orçamento do casal</div>
  <h1>Acompanhamento de {mes_extenso(meta["mes_corrente"])}</h1>
  <div class="periodo">{esc(corte)} · faltam {meta["dias_restantes"]} dias</div>
  <p style="max-width:120mm;color:var(--text-secondary)">
    Preparado para Lucas e Jéssica. Lê o gasto do mês <strong>em andamento</strong>
    contra o ritmo dos seis meses fechados, projeta o fechamento e diz quanto
    ainda cabe gastar — enquanto ainda dá para mudar o resultado.
    <br><br>
    As duas últimas seções falam de
    <strong>{mes_extenso(meta["mes_anterior"])}</strong>, não deste mês: o
    desempenho do patrimônio do casal contra os benchmarks — que só agora tem
    indexador publicado — e, em escopo apartado, o patrimônio e os ativos de
    Deusa. O relatório de fechamento roda antes disso e por isso não os traz.
  </p>
  {aviso_prontidao(meta)}
  <div class="rodape-capa">
    Gerado em {data_br(meta["gerado_em"])} a partir da camada <code>marts</code>
    do data warehouse · corte no dia {meta["dia_corte"]} do ciclo de fatura
  </div>
</div>"""


def secao_ritmo(d, n, num_secao):
    meta = d["meta"]
    dias = list(range(1, meta["dias_no_mes"] + 1))
    corte = meta["dia_corte"]
    dias_ate_corte = [x for x in dias if x <= corte]

    atual = curva_densa(d["ritmo"], dias_ate_corte)
    lo, med, hi = envelope(d["ritmo_historico"], dias)

    series = [(mes_curto(meta["mes_corrente"]), SERIES[0], atual, False)]
    if med:
        series.append(("Mediana 6m", COR_REF, med, True))

    marcos = [x for x in (5, 10, 15, 20, 25, dias[-1]) if x <= dias[-1]]
    linhas_tab = []
    for m in marcos:
        i = m - 1
        v_atual = atual[m - 1] if m <= corte else None
        v_med = med[i] if med else None
        var = (v_atual - v_med) / v_med * 100 if v_atual is not None and v_med else None
        linhas_tab.append(
            [
                f"dia {m}" + (" (corte)" if m == corte else ""),
                brl(v_atual) if v_atual is not None else "—",
                brl(v_med),
                brl(lo[i]) if lo else "—",
                brl(hi[i]) if hi else "—",
                f'<span class="{classe_delta(var, bom_se_sobe=False)}">{sinal(var)}</span>',
            ]
        )

    corpo = (
        f"<figure>{linhas_dia(dias, series, faixa=(lo, hi) if lo else None)}"
        + legenda(
            [(f"Acumulado de {mes_curto(meta['mes_corrente'])}", SERIES[0]), ("Mediana dos 6 meses fechados", COR_REF)]
        )
        + "<figcaption>Gasto acumulado do mês, por dia do ciclo de fatura. A "
        "faixa cinza é o intervalo entre o menor e o maior acumulado dos seis "
        "meses fechados no mesmo dia. A linha do mês corrente termina no dia "
        "do corte — não há dado depois dele.</figcaption></figure>"
        + tabela(
            ["Marco", f"{mes_curto(meta['mes_corrente'])}", "Mediana 6m", "Mínimo 6m", "Máximo 6m", "Var. vs mediana"],
            linhas_tab,
        )
        + '<p class="sub">O eixo é o dia do <strong>ciclo de fatura</strong> '
        "(<code>dia_fatura</code>), não o dia do calendário: é o que torna "
        "dois meses comparáveis dia a dia, porque a compra no cartão pertence "
        "a um mês e é paga em outro.</p>" + bloco("Leitura do ritmo", n.get("diagnostico_ritmo", ""))
    )
    return secao(
        num_secao, "Ritmo do mês", f"Acumulado até o dia {corte} do ciclo · contra os seis meses fechados", corpo
    )


def secao_categorias(d, n, num_secao):
    cats = por_categoria(d)
    tot = cats["total"]
    linhas_tab, desvios, soma_proj = [], [], 0.0
    for c in CATEGORIAS:
        r = cats.get(c)
        if not r:
            continue
        realizado, agendado = float(r["realizado"]), float(r["agendado"])
        mesmo, proj = float(r["mesmo_dia_mediana_6m"]), float(r["projecao"])
        cheio = float(r["mes_cheio_mediana_6m"])
        soma_proj += proj
        var_dia = ((realizado - mesmo) / mesmo * 100) if mesmo else None
        var_proj = ((proj - cheio) / cheio * 100) if cheio else None
        fora = var_proj is not None and abs(var_proj) > BANDA_CATEGORIA_PCT
        linhas_tab.append(
            [
                rotulo_chip(COR_CAT[c], ROTULO_CAT[c]),
                brl(realizado),
                brl(mesmo),
                f'<span class="{classe_delta(var_dia, bom_se_sobe=False)}">{sinal(var_dia)}</span>',
                brl(agendado),
                brl(proj),
                brl(cheio),
                tag("acima", "tag-atencao", "▲")
                if fora and var_proj > 0
                else tag("abaixo", "tag-ok", "✓")
                if fora
                else tag("no padrão", "", "•"),
            ]
        )
        if var_proj is not None:
            desvios.append((ROTULO_CAT[c], var_proj, f"{sinal(var_proj, 0)} · {brl(proj - cheio)}"))

    proj_total = float(tot["projecao"])
    cheio_total = float(tot["mes_cheio_mediana_6m"])
    # A mediana de uma soma não é a soma das medianas, e GREATEST é não linear:
    # a coluna de projeção não fecha com a linha de total, e isso é correto.
    # Silenciar seria pior — o leitor soma e desconfia do relatório inteiro.
    gap = soma_proj - proj_total
    nota_gap = (
        f'<p class="sub">A coluna de projeção <strong>não soma</strong> ao total '
        f"({brl(soma_proj)} contra {brl(proj_total)}, diferença de "
        f"{brl(abs(gap))}). Não é erro de conta: cada projeção usa a mediana da "
        f"categoria, e a mediana de uma soma não é a soma das medianas. Para "
        f"julgar o mês inteiro vale o total, apurado sobre a série do total; "
        f"para julgar uma categoria vale a linha dela.</p>"
    )

    corpo = (
        tabela(
            [
                "Categoria",
                f"Até o dia {d['meta']['dia_corte']}",
                "Mesmo dia 6m",
                "Var.",
                "Já agendado",
                "Projeção",
                "Mediana do mês 6m",
                "Situação",
            ],
            linhas_tab,
            [
                "Total",
                brl(tot["realizado"]),
                brl(tot["mesmo_dia_mediana_6m"]),
                sinal(
                    (
                        (float(tot["realizado"]) - float(tot["mesmo_dia_mediana_6m"]))
                        / float(tot["mesmo_dia_mediana_6m"])
                        * 100
                    )
                    if float(tot["mesmo_dia_mediana_6m"])
                    else None
                ),
                brl(tot["agendado"]),
                brl(proj_total),
                brl(cheio_total),
                "",
            ],
            ["l", "n", "n", "n", "n", "n", "n", "l"],
        )
        + nota_gap
        + "<h3>Onde a projeção destoa do mês típico</h3>"
        + f"<figure>{barras_desvio(sorted(desvios, key=lambda x: -x[1]))}"
        f"<figcaption>Desvio da projeção de fechamento contra a mediana do mês "
        f"cheio dos seis meses fechados.</figcaption></figure>"
        + '<p class="sub">Regra da projeção: <strong>realizado até o corte + o '
        "maior entre</strong> (a) a mediana do que caiu depois do dia do corte "
        "nos seis meses fechados e (b) o que já está lançado com data futura "
        "neste mês. É o maior dos dois, e não a soma, porque a mediana "
        "histórica já embute as despesas fixas do dia 25 — somar contaria as "
        "fixas duas vezes.</p>" + bloco("Leitura das categorias", n.get("diagnostico_categorias", ""))
    )
    return secao(num_secao, "Categorias", "Realizado, comprometido e projetado contra o mês típico", corpo, quebra=True)


def secao_margem(d, n, num_secao):
    """A seção que só faz sentido no meio do mês: o que ainda dá para decidir.

    Só entram as categorias que a política admite comprimir. `saude` e
    `educacao` ficam de fora por decisão registrada no glossário, e as fixas
    (`apartamento`, `assinaturas`) não se comprimem dentro do mês."""
    cats = por_categoria(d)
    tot = cats["total"]
    dre = d["dre_mensal"]
    receita = float(dre[-1]["total_receita"]) if dre else 0.0
    proj_total = float(tot["projecao"])

    teto_poupanca = receita * (1 - META_POUPANCA_PCT / 100)
    folga_poupanca = teto_poupanca - proj_total
    poupanca_proj = (receita - proj_total) / receita * 100 if receita else 0

    linhas_tab = []
    for c in CATEGORIAS_COMPRIMIVEIS:
        r = cats.get(c)
        if not r:
            continue
        proj, cheio = float(r["projecao"]), float(r["mes_cheio_mediana_6m"])
        realizado = float(r["realizado"])
        folga = cheio - proj
        linhas_tab.append(
            [
                rotulo_chip(COR_CAT[c], ROTULO_CAT[c]),
                brl(realizado),
                brl(proj),
                brl(cheio),
                f'<span class="{"delta-neg" if folga < 0 else ""}">{brl(folga)}</span>',
                tag("já estourou", "tag-atencao", "▲") if folga < 0 else tag("ainda cabe", "tag-ok", "✓"),
            ]
        )

    corpo = (
        '<div class="kpis tres">'
        + kpi(
            "Poupança projetada",
            pct(poupanca_proj),
            f"meta {META_POUPANCA_PCT}%",
            "delta-pos" if poupanca_proj >= META_POUPANCA_PCT else "delta-neg",
        )
        + kpi("Teto de despesa do mês", brl(teto_poupanca), f"para fechar em {META_POUPANCA_PCT}% de poupança")
        + kpi(
            "Folga contra o teto",
            brl(folga_poupanca),
            "acima do teto" if folga_poupanca < 0 else "ainda dentro",
            "delta-pos" if folga_poupanca >= 0 else "delta-neg",
        )
        + "</div>"
        + "<h3>Margem por categoria comprimível</h3>"
        + tabela(
            [
                "Categoria",
                f"Até o dia {d['meta']['dia_corte']}",
                "Projeção",
                "Mediana do mês 6m",
                "Ainda cabe",
                "Situação",
            ],
            linhas_tab,
            None,
            ["l", "n", "n", "n", "n", "l"],
        )
        + '<p class="sub">Só entram aqui as categorias que a política admite '
        "comprimir. <strong>Saúde e educação não entram em sugestão de corte</strong>, "
        "por decisão registrada no glossário; apartamento e assinaturas são "
        "fixas e não se comprimem dentro do mês. «Ainda cabe» é a diferença "
        "entre a mediana do mês cheio e a projeção — quanto dá para gastar sem "
        "sair do padrão dos últimos seis meses.</p>"
    )
    return secao(
        num_secao,
        "Margem disponível",
        f"O que ainda dá para decidir nos {d['meta']['dias_restantes']} dias restantes",
        corpo,
    )


def coluna(registros, chave):
    """Extrai uma coluna numérica de uma lista de dicts, preservando ausência."""
    return [float(x[chave]) if x.get(chave) is not None else None for x in registros]


def rebase(vals):
    """Reindexa a série para 1,000 no primeiro mês da janela.

    Os índices de `riqueza` não compartilham base: o do patrimônio é composto a
    partir de 2023-11, o de Deusa a partir da primeira variação da planilha dela
    e os dos indexadores vêm prontos da planilha, com base própria e
    desconhecida. Plotados crus, o eixo compara níveis que não se comparam — e
    a legenda que dizia «indexadas à mesma base» era falsa. Rebasear no primeiro
    mês exibido é o que torna a leitura «quem cresceu mais na janela» correta.
    Só variação DENTRO da janela é comparável; o nível absoluto do mart, não."""
    base = next((v for v in vals if v), None)
    if not base:
        return vals
    return [None if v is None else v / base for v in vals]


def crescimento(vals):
    """Variação ponta a ponta da janela, em %."""
    limpos = [v for v in vals if v]
    if len(limpos) < 2:
        return None
    return (limpos[-1] / limpos[0] - 1) * 100


def secao_desempenho(d, n, num_secao):
    """Seção do mês ANTERIOR, **só do casal**. Migrada do relatório de
    fechamento, que roda antes de o IPCA sair. Nunca lê `comparativo_*`: aquelas
    colunas rotulam superação com RICO/POBRE, vocabulário interno que não vai
    para o PDF.

    Deusa saiu daqui e ganhou seção própria (`secao_deusa`). Enquanto ela era
    uma linha a mais neste gráfico, o leitor comparava duas séries lado a lado
    como se fossem partes de um mesmo total — e não são: patrimônios
    independentes, que só dividem o benchmark."""
    meta = d["meta"]
    r, ind = d["riqueza"], d["indicadores"]
    if not r:
        return secao(
            num_secao,
            f"Desempenho até {mes_extenso(meta['mes_anterior'])}",
            "Patrimônio do casal contra CDI e inflação pessoal",
            "<p>Sem série de benchmark disponível para o período.</p>",
            quebra=True,
        )
    meses = [x["mes_base"] for x in r]
    ind_por_mes = {x["mes_base"]: x for x in ind}

    casal = rebase(coluna(r, "total_patrimonio_liquido_acum"))
    cdi = rebase(coluna(r, "cdi_acum"))
    infl = rebase(coluna(r, "minha_inflacao_acum"))
    ipca = rebase(coluna(r, "ipca_acum"))

    series = [("Casal", SERIES[0], casal), ("CDI", SERIES[1], cdi), ("Infl. pessoal", SERIES[2], infl)]

    kpis = (
        kpi("Patrimônio do casal", sinal(crescimento(casal)), "no período")
        + kpi("CDI", sinal(crescimento(cdi)), "no período")
        + kpi("IPCA", sinal(crescimento(ipca)), "no período")
        + kpi("Inflação pessoal", sinal(crescimento(infl)), "no período")
    )

    linhas_tab = [
        [
            mes_curto(x["mes_base"]),
            num(casal[i]),
            num(cdi[i]),
            num(ipca[i]),
            num(infl[i]),
            pct(float(im["ipca"]) * 100, 2)
            if (im := ind_por_mes.get(x["mes_base"], {})).get("ipca") is not None
            else "—",
            pct(float(im["cdi"]) * 100, 2) if im.get("cdi") is not None else "—",
        ]
        for i, x in enumerate(r)
    ]

    janela = f"{mes_extenso(meses[0])} a {mes_extenso(meses[-1])}"
    corpo = (
        f'<div class="kpis">{kpis}</div>'
        + f"<figure>{linhas(meses, series, formato='idx')}"
        + legenda([(rot, cor) for rot, cor, _ in series])
        + f"<figcaption>Índice reindexado a 1,000 em {mes_curto(meses[0])}, o "
        f"primeiro mês da janela. Os índices crus do mart não compartilham "
        f"base, então só a variação dentro desta janela é comparável entre as "
        f"séries.</figcaption></figure>"
        + tabela(["Mês", "Casal", "CDI", "IPCA", "Infl. pessoal", "IPCA no mês", "CDI no mês"], linhas_tab)
        + f'<p class="sub">Na janela de {janela}, o patrimônio do casal variou '
        f"{sinal(crescimento(casal))}, contra {sinal(crescimento(cdi))} do CDI, "
        f"{sinal(crescimento(ipca))} do IPCA e {sinal(crescimento(infl))} da "
        f"inflação pessoal.</p>" + NOTA_INDICE + bloco("", n.get("diagnostico_desempenho", ""))
    )
    return secao(
        num_secao,
        f"Desempenho até {mes_extenso(meta['mes_anterior'])}",
        "Patrimônio líquido do casal contra CDI e inflação pessoal · índice reindexado no primeiro mês da janela",
        corpo,
        quebra=True,
    )


# ------------------------------------------------------- blocos de Deusa ---
# Os quatro blocos abaixo são as peças da leitura patrimonial de Deusa, e
# existem separados porque servem a dois documentos: viram UMA seção dentro do
# relatório do casal (`secao_deusa`) e TRÊS seções no relatório dela
# (`montar_deusa`). Enquanto o conteúdo morava inteiro dentro da seção do
# casal, o relatório dela só podia ser uma cópia — e cópia diverge.
#
# O que NÃO entra em nenhum deles, por ser do relatório de fechamento (que
# emite um PDF de investimentos só dela): camada, alocação alvo, teto do FGC,
# vencimentos e destino do aporte. Aqui é posição, não política.


def deusa_kpis(d):
    """Nível, variação no mês e a fatia que está parada em conta."""
    evol = d.get("deusa_evolucao") or []
    if not evol:
        return ""
    atual = evol[-1]
    anterior = evol[-2] if len(evol) > 1 else None
    total = float(atual["total_geral"])
    disp, inv = float(atual["disponivel"]), float(atual["investido"])
    var_mes = (
        (total / float(anterior["total_geral"]) - 1) * 100 if anterior and float(anterior["total_geral"]) else None
    )
    pct_disp = disp / total * 100 if total else 0
    return (
        '<div class="kpis">'
        + kpi("Patrimônio de Deusa", brl(total), f"posição de {mes_extenso(d['meta']['mes_anterior'])}")
        + kpi("Variação no mês", sinal(var_mes), "contra o mês anterior", classe_delta(var_mes))
        + kpi("Investido", brl(inv), f"{pct(100 - pct_disp)} do total")
        + kpi("Parado em conta", brl(disp), f"{pct(pct_disp)} do total", classe_delta(-pct_disp))
        + "</div>"
    )


def deusa_benchmark(d):
    """Índice dela contra os mesmos indexadores do casal.

    Recorta a janela onde a série existe: `linhas` traça o caminho ponto a
    ponto e não sabe pular um None. A base é própria e diferente da do casal —
    a legenda diz isso, porque as duas séries não se comparam entre si."""
    r, ind = d["riqueza"], d["indicadores"]
    if not r:
        return ""
    idx = [i for i, x in enumerate(r) if x.get("patrimonio_liquido_deusa_acum") is not None]
    if len(idx) < 2:
        return ""
    rr = r[idx[0] : idx[-1] + 1]
    meses = [x["mes_base"] for x in rr]
    ind_por_mes = {x["mes_base"]: x for x in ind}
    deusa = rebase(coluna(rr, "patrimonio_liquido_deusa_acum"))
    cdi = rebase(coluna(rr, "cdi_acum"))
    infl = rebase(coluna(rr, "minha_inflacao_acum"))
    ipca = rebase(coluna(rr, "ipca_acum"))
    series = [("Deusa", SERIES[6], deusa), ("CDI", SERIES[1], cdi), ("Infl. pessoal", SERIES[2], infl)]
    linhas_tab = [
        [
            mes_curto(x["mes_base"]),
            num(deusa[i]),
            num(cdi[i]),
            num(ipca[i]),
            num(infl[i]),
            pct(float(im["cdi"]) * 100, 2)
            if (im := ind_por_mes.get(x["mes_base"], {})).get("cdi") is not None
            else "—",
        ]
        for i, x in enumerate(rr)
    ]
    janela = f"{mes_extenso(meses[0])} a {mes_extenso(meses[-1])}"
    return (
        f"<figure>{linhas(meses, series, formato='idx')}"
        + legenda([(rot, cor) for rot, cor, _ in series])
        + f"<figcaption>Índice reindexado a 1,000 em {mes_curto(meses[0])}. "
        f"Base própria, diferente da do casal — as duas séries não se "
        f"comparam entre si, só cada uma contra o benchmark."
        f"</figcaption></figure>"
        + tabela(["Mês", "Deusa", "CDI", "IPCA", "Infl. pessoal", "CDI no mês"], linhas_tab)
        + f'<p class="sub">Na janela de {janela} o patrimônio de Deusa '
        f"variou {sinal(crescimento(deusa))}, contra "
        f"{sinal(crescimento(cdi))} do CDI e {sinal(crescimento(infl))} "
        f"da inflação pessoal. <strong>Não há despesa de Deusa no "
        f"warehouse</strong>: uma queda aqui não pode ser atribuída a "
        f"saque nem a perda de mercado.</p>" + '<p class="sub">A «inflação pessoal» é a do casal, apurada da '
        "cesta de consumo deles — é o único índice de consumo que o "
        "warehouse tem. Serve de referência, não é a inflação medida "
        "sobre os gastos de Deusa, que não existem na base.</p>" + NOTA_INDICE
    )


def deusa_ativos(d):
    """Onde o dinheiro está: disponível contra investido, instituição, classe
    e indexador — sempre com o mês anterior ao lado, para a variação ser lida
    e não inferida."""
    evol = d.get("deusa_evolucao") or []
    inst = d.get("deusa_instituicao") or []
    classes = d.get("deusa_classe") or []
    indexadores = d.get("deusa_indexador") or []
    atual = evol[-1] if evol else None
    partes = []

    if len(evol) > 1:
        meses_e = [x["mes_base"] for x in evol]
        partes.append(
            bloco(
                "Disponível contra investido",
                "<figure>"
                + barras_empilhadas(
                    meses_e,
                    [
                        ("Investido", SERIES[0], [float(x["investido"]) for x in evol]),
                        ("Parado em conta", SERIES[3], [float(x["disponivel"]) for x in evol]),
                    ],
                )
                + legenda([("Investido", SERIES[0]), ("Parado em conta", SERIES[3])])
                + "<figcaption>Saldo em conta corrente contra o que está aplicado, "
                "por mês. O que está parado é a única leitura acionável desta "
                "seção — o resto é posição.</figcaption></figure>",
            )
        )

    def linha_comp(rotulo, valor, valor_ant, total):
        v = float(valor)
        va = float(valor_ant) if valor_ant is not None else None
        var = ((v / va - 1) * 100) if va else None
        return [
            rotulo,
            brl(v),
            pct(v / total * 100) if total else "—",
            brl(va) if va is not None else "—",
            sinal(var) if var is not None else "—",
        ]

    if inst and atual:
        total = float(atual["total_geral"])
        partes.append(
            bloco(
                "Por instituição",
                tabela(
                    ["Instituição", "Valor", "% do total", "Mês anterior", "Variação"],
                    [linha_comp(x["instituicao"], x["valor"], x.get("valor_anterior"), total) for x in inst],
                )
                + '<p class="sub">Concentração por instituição é posição, não '
                "risco: o teto do FGC e a exposição por emissor saem no "
                "relatório de fechamento.</p>",
            )
        )

    if classes and atual:
        total = float(atual["total_geral"])
        partes.append(
            bloco(
                "Por classe de ativo",
                tabela(
                    ["Classe", "Tipo", "Ativos", "Valor", "% do total", "Mês anterior", "Variação"],
                    [
                        [x["classe_ativo"], x["tipo_ativo"], str(x["ativos"])]
                        + linha_comp("", x["valor"], x.get("valor_anterior"), total)[1:]
                        for x in classes
                    ],
                    alinhamentos=["l", "l", "n", "n", "n", "n", "n"],
                ),
            )
        )

    if indexadores and atual:
        total = float(atual["total_geral"])
        rf_sem = sum(float(x.get("valor_renda_fixa") or 0) for x in indexadores if x["indexador"] == "SEM INDEXADOR")
        partes.append(
            bloco(
                "Por indexador",
                tabela(
                    ["Indexador", "Valor", "% do total", "Do qual renda fixa"],
                    [
                        [
                            x["indexador"],
                            brl(float(x["valor"])),
                            pct(float(x["valor"]) / total * 100),
                            brl(float(x.get("valor_renda_fixa") or 0)),
                        ]
                        for x in indexadores
                    ],
                )
                + f'<p class="sub"><strong>«Sem indexador» é lacuna de '
                f"cadastro antes de ser exposição.</strong> Dele, "
                f"{brl(rf_sem)} são renda fixa — título com taxa "
                f"contratada cujo campo não foi preenchido na origem. O "
                f"resto é fundo, ação e saldo em conta, que de fato não "
                f"têm taxa. Enquanto o campo não for preenchido, esta "
                f"linha não mede exposição a juro nenhum.</p>",
            )
        )

    partes.append(deusa_conciliacao(d))
    return "".join(partes)


def deusa_conciliacao(d):
    """Duas fontes, dois totais — a diferença nunca passa calada.

    O nível e a composição vêm de `carteira_deusa`, no grão de ativo; o índice
    vem da planilha de patrimônio, via `riqueza`. Em 07/2026 diferiam em R$ 2,
    em 12/2024 em R$ 60 mil. É daqui que sai a divergência entre a variação do
    mês no KPI e a variação do índice."""
    conc = d.get("deusa_conciliacao") or {}
    tc, tp = conc.get("total_carteira"), conc.get("total_planilha")
    if tc is None or tp is None:
        return ""
    dif = float(tc) - float(tp)
    dif_pct = dif / float(tp) * 100 if float(tp) else 0
    return (
        f'<p class="sub"><strong>Conciliação.</strong> A composição vem da '
        f"carteira ({brl(float(tc))}) e o índice vem da planilha de "
        f"patrimônio ({brl(float(tp))}) — duas fontes, dois totais. A "
        f"diferença em {mes_extenso(d['meta']['mes_anterior'])} é de "
        f"{brl(dif)} ({sinal(dif_pct, 2)}). Diferença grande significa "
        f"posição não lançada em uma das duas, não erro de conta.</p>"
    )


def secao_deusa(d, n, num_secao):
    """A leitura patrimonial de Deusa como UMA seção do relatório do casal.

    O relatório dela usa os mesmos blocos abertos em três seções — ver
    `montar_deusa`. Aqui eles ficam juntos porque, no documento do casal, esta
    é uma seção entre oito e não o assunto."""
    mes_ref = mes_extenso(d["meta"]["mes_anterior"])
    bench = deusa_benchmark(d)
    corpo = (
        deusa_kpis(d)
        + (bloco("Contra o benchmark", bench) if bench else "")
        + deusa_ativos(d)
        + bloco("", n.get("diagnostico_deusa", ""))
    )
    return secao(
        num_secao,
        f"Patrimônio e ativos de Deusa · {mes_ref}",
        "Escopo apartado do casal · os dois patrimônios não se somam",
        corpo,
        quebra=True,
    )


def rodape(d, premissas):
    meta = d["meta"]
    pr = meta["prontidao"]
    itens = "".join(f"<li>{esc(p)}</li>" for p in premissas)
    bloco_prem = (
        (f"<p><strong>Premissas e critérios adotados neste relatório:</strong></p><ul>{itens}</ul>")
        if premissas
        else ""
    )

    incompleto = ""
    for chave, rot, pend in (
        ("pronto_ritmo", "Ritmo em base insuficiente", "pendencias_ritmo"),
        ("pronto_indicadores", "Indexadores não publicados", "pendencias_indicadores"),
        ("pronto_deusa", "Carteira de Deusa desatualizada", "pendencias_deusa"),
    ):
        if not pr.get(chave, True):
            incompleto += f"<p><strong>{rot}.</strong> {esc('; '.join(pr.get(pend, [])))}</p>"

    esp = meta.get("motivos_especiais")
    sazonal = (
        (
            f"<p>{mes_extenso(meta['mes_corrente'])} é mês de data especial "
            f"({esc(esp.capitalize())}), o que costuma elevar rolê e "
            f"diversos.</p>"
        )
        if esp
        else ""
    )

    return f"""<section class="quebra"><h2><span class="num">—</span>Notas e procedência</h2>
<div class="rodape-doc">{incompleto}{bloco_prem}{sazonal}
  <p>Origem: camada <code>marts</code> do data warehouse pessoal (PostgreSQL),
  domínio finanças. Ritmo, categorias e margem apurados em
  {mes_extenso(meta["mes_corrente"])} até {data_br(meta["hoje"])}, no dia
  {meta["dia_corte"]} do ciclo de fatura. Desempenho do casal e ativos de Deusa
  apurados em {mes_extenso(meta["mes_anterior"])}. A base de comparação são os
  {meta["meses_de_base"]} meses fechados anteriores.</p>
  <p>O patrimônio de Deusa é escopo apartado e <strong>nunca é somado ao do
  casal</strong>: são planilhas, carteiras e objetivos distintos, e as duas
  séries de índice têm bases diferentes — só a variação dentro da janela
  exibida é comparável. Não há despesa de Deusa no warehouse, então nenhuma
  variação do patrimônio dela pode ser atribuída a saque ou a perda de
  mercado.</p>
  <p>Este relatório não traz alocação por camada, exposição ao FGC, vencimentos
  nem cobertura da reserva de emergência — nem para o casal, nem para Deusa.
  Esses são assunto dos relatórios de fechamento, gerados no início do mês. A
  composição de ativos de Deusa aqui é posição, não política.</p>
  <p>Definições de categoria de gasto conforme
  <code>models/presentation/financas/_docs_financas.md</code>, fonte única do domínio.
  Meses posteriores ao corrente existem na base como lançamentos futuros
  pré-agendados e foram excluídos de todos os números.</p>
  <p>Este documento é gerado automaticamente a partir de dados próprios e não
  constitui recomendação de investimento de profissional certificado.</p>
  <p>Gerado em {data_br(meta["gerado_em"])}.</p>
</div></section>"""


def montar(d, n):
    meta = d["meta"]
    pr = meta["prontidao"]
    cats = por_categoria(d)
    tot = cats["total"]
    dre = d["dre_mensal"]
    receita = float(dre[-1]["total_receita"]) if dre else 0.0
    proj_total, realizado = float(tot["projecao"]), float(tot["realizado"])
    mesmo_dia = float(tot["mesmo_dia_mediana_6m"])
    cheio = float(tot["mes_cheio_mediana_6m"])
    var_dia = ((realizado - mesmo_dia) / mesmo_dia * 100) if mesmo_dia else None
    var_proj = ((proj_total - cheio) / cheio * 100) if cheio else None
    poupanca_proj = (receita - proj_total) / receita * 100 if receita else 0

    numero = 0

    def prox():
        nonlocal numero
        numero += 1
        return numero

    partes = [cabecalho(meta)]

    partes.append(
        secao(
            prox(),
            "Sumário executivo",
            f"{mes_extenso(meta['mes_corrente']).capitalize()} até o dia {meta['dia_corte']} do ciclo",
            '<div class="kpis">'
            + kpi(
                f"Gasto até o dia {meta['dia_corte']}",
                brl(realizado),
                f"{sinal(var_dia)} vs. mesmo dia, mediana 6m",
                classe_delta(var_dia, bom_se_sobe=False),
            )
            + kpi(
                "Projeção de fechamento",
                brl(proj_total),
                f"{sinal(var_proj)} vs. mediana do mês 6m",
                classe_delta(var_proj, bom_se_sobe=False),
            )
            + kpi(
                "Poupança projetada",
                pct(poupanca_proj),
                f"meta {META_POUPANCA_PCT}%",
                "delta-pos" if poupanca_proj >= META_POUPANCA_PCT else "delta-neg",
            )
            + kpi("Dias restantes", str(meta["dias_restantes"]), f"de {meta['dias_no_mes']} no mês")
            + "</div>"
            + (n.get("sumario") or "")
            + '<p class="sub">A receita do mês corrente já está lançada (é o '
            "salário) e sustenta a poupança projetada; a despesa é projeção, não "
            "realizado. Alocação por camada, reserva de emergência e risco FGC "
            "não entram neste relatório — saem no fechamento. Os KPIs acima são "
            "do casal: Deusa não tem despesa lançada e aparece só na seção "
            "patrimonial, apartada.</p>",
        )
    )

    partes.append(secao_ritmo(d, n, prox()))
    partes.append(secao_categorias(d, n, prox()))
    partes.append(secao_margem(d, n, prox()))
    if pr["pronto_indicadores"]:
        partes.append(secao_desempenho(d, n, prox()))
    # Portão próprio: a carteira de Deusa fecha em cadência independente da do
    # IPCA, e uma seção pode sair sem a outra. `pronto_deusa` só existe em JSON
    # extraído depois desta seção — `.get` mantém de pé um pacote antigo.
    if pr.get("pronto_deusa"):
        partes.append(secao_deusa(d, n, prox()))

    partes.append(
        secao(
            prox(),
            "Recomendações",
            f"Ações para os {meta['dias_restantes']} dias que restam · o destino do "
            f"aporte e a alocação por camada saem no relatório de fechamento",
            recomendacoes_html(n.get("recomendacoes", [])),
            quebra=True,
        )
    )

    partes.append(
        secao(prox(), "Glossário", "O que cada categoria de gasto engloba", glossario_categorias(), quebra=True)
    )

    partes.append(rodape(d, n.get("premissas", [])))
    return "\n".join(partes)


def cabecalho_deusa(meta):
    """Capa do documento dela. Diz de saída que não há gasto na leitura: é a
    diferença que mais confunde quem recebe este PDF depois de ver o do casal,
    onde metade das páginas é despesa."""
    mes = mes_extenso(meta["mes_anterior"])
    return f"""<meta charset="utf-8"><title>Patrimônio e ativos de Deusa</title>
<style>{css_inline()}</style>
<div class="capa">
  <div class="eyebrow">Acompanhamento de meio de mês · patrimônio de Deusa</div>
  <h1>Patrimônio de {mes}</h1>
  <div class="periodo">posição fechada de {mes} · gerado em {data_br(meta["hoje"])}</div>
  <p style="max-width:120mm;color:var(--text-secondary)">
    Preparado para Deusa. Lê o patrimônio <strong>fechado de {mes}</strong>
    contra o CDI e a inflação, e mostra onde o dinheiro está — por instituição,
    por classe de ativo e por indexador —, com atenção ao que está parado em
    conta corrente.
    <br><br>
    <strong>Não há gasto neste relatório.</strong> O warehouse não tem despesa
    lançada de Deusa, então não há ritmo de consumo, projeção de fechamento nem
    orçamento aqui — nada disso pode ser calculado. Pela mesma razão, uma queda
    no patrimônio não distingue resgate de perda de mercado.
    <br><br>
    Este é o acompanhamento de meio de mês. Camada de investimento, alocação
    alvo, teto do FGC, vencimentos e destino do aporte saem no relatório de
    fechamento, no início do mês.
  </p>
  {aviso_prontidao_deusa(meta)}
  <div class="rodape-capa">
    Gerado em {data_br(meta["gerado_em"])} a partir da camada <code>marts</code>
    do data warehouse · posição de {mes}
  </div>
</div>"""


def aviso_prontidao_deusa(meta):
    """Só os dois portões que valem para ela. `pronto_ritmo` é do casal e não
    entra: ela não tem gasto, e reprovar o documento dela por causa de
    lançamento atrasado de despesa do casal seria falso."""
    pr = meta["prontidao"]
    avisos = []
    if not pr.get("pronto_deusa", True):
        itens = "".join(f"<li>{esc(x)}</li>" for x in pr.get("pendencias_deusa", []))
        ult = pr.get("ultimo_mes_carteira_deusa")
        alt = (f"<p>Última posição disponível: <strong>{mes_extenso(ult)}</strong>.</p>") if ult else ""
        avisos.append(
            f'<div class="destaque-bloco alerta"><h4>Carteira sem a posição do mês</h4><ul>{itens}</ul>{alt}</div>'
        )
    if not pr["pronto_indicadores"]:
        itens = "".join(f"<li>{esc(x)}</li>" for x in pr["pendencias_indicadores"])
        avisos.append(
            f'<div class="destaque-bloco alerta"><h4>Indexadores ainda não publicados</h4><ul>{itens}</ul></div>'
        )
    return "".join(avisos)


def rodape_deusa(d, premissas):
    meta = d["meta"]
    pr = meta["prontidao"]
    itens = "".join(f"<li>{esc(x)}</li>" for x in premissas)
    bloco_prem = (
        (f"<p><strong>Premissas e critérios adotados neste relatório:</strong></p><ul>{itens}</ul>")
        if premissas
        else ""
    )
    incompleto = ""
    for chave, rot, pend in (
        ("pronto_deusa", "Carteira desatualizada", "pendencias_deusa"),
        ("pronto_indicadores", "Indexadores não publicados", "pendencias_indicadores"),
    ):
        if not pr.get(chave, True):
            incompleto += f"<p><strong>{rot}.</strong> {esc('; '.join(pr.get(pend, [])))}</p>"
    return f"""<section class="quebra"><h2><span class="num">—</span>Notas e procedência</h2>
<div class="rodape-doc">{incompleto}{bloco_prem}
  <p>Origem: camada <code>marts</code> do data warehouse pessoal (PostgreSQL),
  domínio finanças. Posição e composição apuradas em
  {mes_extenso(meta["mes_anterior"])}, o último mês fechado.</p>
  <p>O nível e a composição vêm de <code>marts_financas.carteira_deusa</code>, no grão de
  ativo; o índice de desempenho vem da planilha de patrimônio, via
  <code>marts_financas.riqueza</code>. São duas fontes com totais próprios, e a
  conciliação entre elas está impressa na seção de ativos.</p>
  <p>Este patrimônio é <strong>independente do patrimônio do casal</strong> e em
  nenhum momento foi somado a ele. Os dois índices têm bases diferentes e não se
  comparam entre si — cada um só se compara ao seu benchmark, dentro da janela
  exibida. O índice compõe aporte com rentabilidade: mede se o patrimônio
  cresceu acima da inflação, não se a carteira bateu o CDI.</p>
  <p>Este relatório não traz alocação por camada, exposição ao FGC, vencimentos
  nem cobertura da reserva de emergência. Esses são assunto do relatório de
  fechamento, gerado no início do mês. O que está aqui é posição, não
  política.</p>
  <p>Este documento é gerado automaticamente a partir de dados próprios e não
  constitui recomendação de investimento de profissional certificado.</p>
  <p>Gerado em {data_br(meta["gerado_em"])}.</p>
</div></section>"""


def montar_deusa(d, n):
    """O documento dela: os mesmos blocos da seção do casal, abertos em três
    seções, com capa e rodapé próprios.

    Existe separado porque tem outro leitor. No PDF do casal esta leitura é uma
    seção entre oito, cercada de despesa que não é dela; aqui é o assunto, e o
    documento pode ser entregue sem expor o orçamento do casal."""
    meta = d["meta"]
    mes = mes_extenso(meta["mes_anterior"])
    numero = 0

    def prox():
        nonlocal numero
        numero += 1
        return numero

    partes = [cabecalho_deusa(meta)]

    partes.append(secao(prox(), "Sumário", f"Posição fechada de {mes}", deusa_kpis(d) + (n.get("sumario") or "")))

    # Sem `quebra`: o sumário é curto e, com a quebra, deixava dois terços da
    # primeira página em branco num documento de oito. As duas seções seguintes
    # continuam abrindo página, porque começam com gráfico.
    bench = deusa_benchmark(d)
    if bench:
        partes.append(
            secao(
                prox(),
                f"Desempenho até {mes}",
                "Patrimônio contra CDI e inflação · índice reindexado no primeiro mês da janela",
                bench + bloco("", n.get("diagnostico_desempenho", "")),
            )
        )

    partes.append(
        secao(
            prox(),
            "Onde o dinheiro está",
            "Disponível contra investido, instituição, classe de ativo e indexador",
            deusa_ativos(d) + bloco("", n.get("diagnostico_ativos", "")),
            quebra=True,
        )
    )

    partes.append(
        secao(
            prox(),
            "Recomendações",
            "A camada de investimento e o destino do aporte saem no relatório de fechamento",
            recomendacoes_html(n.get("recomendacoes", [])),
            quebra=True,
        )
    )

    partes.append(rodape_deusa(d, n.get("premissas", [])))
    return "\n".join(partes)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dados", required=True)
    ap.add_argument("--narrativa", required=True)
    ap.add_argument(
        "--saida",
        required=True,
        help="caminho do relatório. Termine em .pdf para entregar "
        "só o PDF (o HTML vira temporário e é descartado); "
        "termine em .html para inspecionar a marcação.",
    )
    ap.add_argument(
        "--escopo",
        choices=("casal", "deusa"),
        default="casal",
        help="casal: o relatório de acompanhamento do mês em "
        "andamento, com a seção patrimonial de Deusa dentro. "
        "deusa: só a leitura patrimonial dela, como documento "
        "próprio — outro leitor, outra narrativa.",
    )
    a = ap.parse_args()

    d = json.loads(Path(a.dados).read_text(encoding="utf-8"))
    n = json.loads(Path(a.narrativa).read_text(encoding="utf-8"))
    html = montar_deusa(d, n) if a.escopo == "deusa" else montar(d, n)
    escrever(html, a.saida, Path(__file__).resolve().parent / "html_para_pdf.sh")


if __name__ == "__main__":
    main()
