#!/usr/bin/env python3
"""Monta um relatório financeiro a partir do JSON extraído.

    montar_relatorio.py --dados D.json --escopo orcamento|lucas|jessica|deusa \
                        --narrativa N.json --saida R.pdf

São quatro relatórios, separados por assunto e por titular:

    orcamento          casal — receita, despesa, resultado, poupança, gasto por
                       categoria, conta de luz e cobertura da reserva
    lucas | jessica    investimentos do titular — camadas, classe contra o
                       perfil de referência, riscos, patrimônio e renda passiva
    deusa              idem, sem patrimônio: não há dado dela em
                       staging_google_sheets.stg_patrimonio

Cada PDF cabe em até 3 páginas: sem capa, sem glossário, sem lista posição a
posição. A carteira é lida por camada (papel na política) e por classe de
referência (a taxonomia do perfil em `_perfis_de_investimento.md`); só
vencimento e FGC descem ao ativo, porque é lá que a ação acontece.

A política que orienta o relatório é a vigente na data de geração: as
recomendações olham para o próximo aporte, não para o mês fechado.

O desempenho é do último mês com indexador publicado, que pode ser anterior
ao de referência. Como a variação do patrimônio inclui aportes, ele compara o
patrimônio com a inflação pessoal; não é rentabilidade da carteira.

Divisão de responsabilidades: este script renderiza tudo que é *calculável*
— KPIs, tabelas, gráficos SVG — direto dos dados, para que nenhum número do
PDF dependa de transcrição manual. O arquivo de narrativa traz apenas o texto
analítico (diagnóstico e recomendações), que é escrito pelo agente.

Estrutura do arquivo de narrativa (todas as chaves opcionais):

    {
      "sumario": "<p>…</p>",
      "diagnostico_orcamento": "<p>…</p>",   # só no escopo orcamento
      "diagnostico_carteira": "<p>…</p>",    # só nos escopos de investimento
      "diagnostico_riscos": "<p>…</p>",      # idem
      "recomendacoes": [{"titulo": "…", "texto": "…"}],
      "acompanhamento": [{"recomendacao": "…", "situacao": "…", "evidencia": "…"}],
      "premissas": ["…"]
    }

Com saída em PDF, a narrativa é copiada para a pasta do PDF: o relatório do mês
seguinte a lê para acompanhar as recomendações.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# A camada compartilhada mora no repositório, em
# scripts/relatorios/ — parâmetros da política, formatação pt-BR, gráficos SVG e
# blocos de HTML. Aqui fica só o que é específico do fechamento: cabeçalho,
# notas, tarja de prontidão e a ordem das seções.
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "scripts"))

from relatorios.blocos import (
    bloco,
    css_inline,
    kpi,
    recomendacoes_html,
    rotulo_chip,
    secao,
    tabela,
    tag_risco,
)
from relatorios.calculo import media, mediana, variacao
from relatorios.formato import brl, classe_delta, data_br, esc, mes_curto, mes_extenso, pct, sinal
from relatorios.graficos import barras_agrupadas, barras_alvo, barras_empilhadas, legenda
from relatorios.politica import (
    CAMADAS_COM_ALVO,
    CAMADAS_SEM_ALVO,
    CATEGORIAS,
    CLASSES_INTERNACIONAIS,
    CLASSES_REFERENCIA,
    CLASSES_RENDA_FIXA,
    CLASSES_RISCO,
    COM_PATRIMONIO,
    COR_CAMADA,
    COR_CAT,
    ESCOPOS_INVESTIMENTO,
    FGC_FOLGA_MINIMA,
    FGC_LIMITE,
    ISENCAO_ACOES_BR,
    META_POUPANCA_PCT,
    NATUREZA_CAT,
    NOME,
    RESERVA_MIN_MESES,
    RESERVA_TETO,
    ROTULO_CAMADA,
    ROTULO_CAT,
    ROTULO_CLASSE,
    SERIES,
    extraordinario_casal,
    fatos_do_mes,
    perfil_referencia,
    politica_vigente,
)
from relatorios.saida import escrever

def grade_2(esquerda, direita):
    return f'<div class="grade-2"><div>{esquerda}</div><div>{direita}</div></div>'


# ----------------------------------------------------------------- carteira ---


def secao_camadas(d, pessoa, cal):
    """`cal` é a calibragem do titular na política vigente; sem ela a tabela mostra só valor e %
    da carteira, e a comparação fica com o perfil de referência."""
    camadas = [c for c in d["carteira_camada"] if c["pessoa"] == pessoa]
    total = sum(c["valor"] for c in camadas)
    if not total:
        return ""
    if not cal:
        lin = [
            [
                rotulo_chip(COR_CAMADA[cm], ROTULO_CAMADA[cm])
                + (' <span class="tag tag-atencao">▲ classificar</span>' if cm == "NAO CLASSIFICADO" else ""),
                brl(c["valor"]),
                pct(c["pct_da_carteira"]),
            ]
            for cm in CAMADAS_COM_ALVO + CAMADAS_SEM_ALVO
            for c in camadas
            if c["camada"] == cm
        ]
        return tabela(["Camada", "Valor", "% da carteira"], lin, ["Total", brl(total), "100,0%"])
    alvos = cal["alvos"] if cal else {}
    valores = {c["camada"]: c["valor"] for c in camadas}

    # O alvo da política é sobre a carteira SEM as camadas que não têm alvo, e
    # `pct_da_carteira` vem do SQL calculado sobre o total — por isso o
    # percentual comparável ao alvo é recalculado aqui sobre a base-alvo.
    base_alvo = total - sum(valores.get(cm, 0) for cm in CAMADAS_SEM_ALVO)
    dados_alvo = [
        (cm, COR_CAMADA[cm], float(valores.get(cm, 0)) / base_alvo * 100 if base_alvo else 0.0, alvos.get(cm, 0))
        for cm in CAMADAS_COM_ALVO
    ]
    atual_total = {c["camada"]: float(c["pct_da_carteira"]) for c in camadas}

    lin = []
    for cm, cor, a, alvo in dados_alvo:
        desvio = a - alvo
        dentro = abs(desvio) <= cal["banda"]
        lin.append(
            [
                rotulo_chip(cor, ROTULO_CAMADA[cm]),
                brl(valores.get(cm, 0)),
                pct(a),
                f"{alvo}%",
                # desvio do alvo é ruim nos dois sentidos — nunca verde por ser positivo
                f'<span class="{"" if dentro else "delta-neg"}">{sinal(desvio, 0, " p.p.")}</span>',
                '<span class="tag tag-ok">✓ na banda</span>'
                if dentro
                else '<span class="tag tag-atencao">▲ fora da banda</span>',
            ]
        )
    # Camadas sem alvo entram para o valor não sumir, em % da carteira toda.
    for cm in CAMADAS_SEM_ALVO:
        if not valores.get(cm):
            continue
        pendencia = cm == "NAO CLASSIFICADO"
        lin.append(
            [
                rotulo_chip(COR_CAMADA[cm], ROTULO_CAMADA[cm]),
                brl(valores[cm]),
                pct(atual_total.get(cm, 0.0)),
                "—",
                "—",
                '<span class="tag tag-atencao">▲ classificar</span>'
                if pendencia
                else '<span class="tag">sem alvo</span>',
            ]
        )

    nota = (
        f"<p class='sub'>Percentual sobre a base de rebalanceamento ({brl(base_alvo)}); "
        f"as camadas sem alvo estão em % da carteira total.</p>"
        if base_alvo < total
        else ""
    )
    return (
        f"<figure>{barras_alvo([(ROTULO_CAMADA[cm], *r) for cm, *r in dados_alvo])}</figure>"
        + tabela(["Camada", "Valor", "Atual", "Alvo", "Desvio", "Situação"], lin)
        + nota
    )


def secao_perfil(d, pessoa, nome_perfil):
    """Carteira na taxonomia do perfil de referência, sem a reserva de emergência. O internacional
    sai sem faixa: a política pede dolarização e vence o perfil, mas RF e RV em dólar ficam
    separados porque um protege e o outro é risco."""
    linhas_ref = {r["classe_referencia"]: r for r in d["carteira_referencia"] if r["pessoa"] == pessoa}
    base = sum(r["valor"] for r in linhas_ref.values())
    if not base:
        return ""
    perfil = perfil_referencia(nome_perfil) if nome_perfil else None

    def atual(classes):
        return sum(linhas_ref[c]["valor"] for c in classes if c in linhas_ref) / base * 100

    lin = []
    for c in CLASSES_REFERENCIA:
        valor = linhas_ref.get(c, {}).get("valor", 0)
        medio = perfil["medio"].get(c) if perfil else None
        if not valor and not medio:
            continue
        a = valor / base * 100
        if not perfil:
            lin.append([ROTULO_CLASSE[c], brl(valor) if valor else "—", pct(a)])
            continue
        if c in CLASSES_INTERNACIONAIS:
            lin.append([ROTULO_CLASSE[c], brl(valor) if valor else "—", pct(a), "—", "—",
                        '<span class="tag">política: dolarização</span>'])
            continue
        lo, hi = perfil["faixa"].get(c, (None, None))
        if lo is None:
            situacao = ""
        elif lo <= a <= hi:
            situacao = '<span class="tag tag-ok">✓ na faixa</span>'
        elif a > 2 * hi:
            # Critério da política: acima do dobro do teto a venda é sugerida, não só o aporte.
            situacao = '<span class="tag tag-critico">▲ venda sugerida</span>'
        else:
            situacao = f'<span class="tag tag-atencao">{"▲ acima" if a > hi else "▼ abaixo"} da faixa</span>'
        lin.append([ROTULO_CLASSE[c], brl(valor) if valor else "—", pct(a), f"{medio}%",
                    f"{lo}–{hi}%" if lo is not None else "—", situacao])

    rf, risco = atual(CLASSES_RENDA_FIXA), atual(CLASSES_RISCO)
    if perfil:
        m_rf, m_risco = perfil["medio"]["TOTAL RF"], perfil["medio"]["TOTAL RISCO"]
        lin.append({"cels": ["Renda fixa e caixa", "", pct(rf), f"{m_rf}%", "",
                             sinal(rf - m_rf, 0, " p.p.")]})
        lin.append({"cels": ["Risco", "", pct(risco), f"~{m_risco}%", "",
                             f'<span class="{"delta-neg" if risco > m_risco else ""}">'
                             f'{sinal(risco - m_risco, 0, " p.p.")}</span>']})
        cab = ["Classe", "Valor", "Atual", "Perfil", "Faixa", "Situação"]
        intl = perfil["medio"]["INTERNACIONAL"]
        lo_i, hi_i = perfil["faixa"].get("INTERNACIONAL", ("?", "?"))
        nota = (
            f"<p class='sub'>Perfil {esc(perfil['nome'].lower())} de {esc(perfil['data'] or 's/d')}, sobre "
            f"{brl(base)} (carteira sem a reserva de emergência). Risco soma ações, FII, internacional RV e "
            f"alternativos. O perfil põe o internacional somado em {intl}% (faixa {lo_i}–{hi_i}%); a política "
            f"pede dolarização, por isso ele não é comparado à faixa.</p>"
        )
        acoes_br = linhas_ref.get("ACOES BRASIL", {}).get("valor", 0)
        if acoes_br and risco > m_risco:
            nota += (
                f"<p class='sub'>Ações Brasil: {brl(acoes_br)}. Venda de até {brl(ISENCAO_ACOES_BR)} por mês em "
                f"ações brasileiras é isenta de IR sobre o ganho.</p>"
            )
    else:
        lin.append({"cels": ["Renda fixa e caixa", "", pct(rf)]})
        lin.append({"cels": ["Risco", "", pct(risco)]})
        cab = ["Classe", "Valor", "Atual"]
        nota = f"<p class='sub'>Política sem perfil de referência para este titular; base {brl(base)}.</p>"
    return tabela(cab, lin, ["Total", brl(base), "100,0%", *([""] * (len(cab) - 3))]) + nota


def secao_riscos(d, pessoa):
    inst = [i for i in d["carteira_instituicao"] if i["pessoa"] == pessoa]
    total = sum(i["valor"] for i in inst)
    fgc = [f for f in d["fgc"] if f["pessoa"] == pessoa]
    venc = [v for v in d["vencimentos_12m"] if v["pessoa"] == pessoa]
    nc = [x for x in d["nao_classificados"] if x["pessoa"] == pessoa]

    # Cauda de instituições pequenas vira uma linha: o risco está nas maiores.
    topo, cauda = inst[:5], inst[5:]
    lin_inst = [[i["instituicao"].title(), brl(i["valor"]), pct(i["pct_da_carteira"])] for i in topo]
    if cauda:
        v = sum(i["valor"] for i in cauda)
        lin_inst.append([f"Demais ({len(cauda)})", brl(v), pct(v / total * 100 if total else 0)])

    h = [
        grade_2(
            "<h3>Concentração por instituição</h3>"
            + tabela(["Instituição", "Valor", "%"], lin_inst, ["Total", brl(total), "100,0%"]),
            "<h3>FGC por conglomerado</h3>"
            + tabela(
                ["Conglomerado", "Cobertura livre", "Situação"],
                [[f["conglomerado_fgc"].title(), brl(f["vlr_liberado"]), tag_risco(f["risco_fgc"])] for f in fgc],
                None,
                ["l", "n", "l"],
            )
            + f'<p class="sub">Limite de {brl(FGC_LIMITE)} por CPF e conglomerado; folga mínima de '
            f"{brl(FGC_FOLGA_MINIMA)}.</p>",
        )
    ]
    if venc:
        h.append("<h3>Vencimentos nos próximos 12 meses</h3>")
        h.append(
            tabela(
                ["Investimento", "Camada", "Vencimento", "Valor"],
                [
                    [esc(v["ativo"]), ROTULO_CAMADA.get(v["camada"], v["camada"]), data_br(v["data_vencimento"]),
                     brl(v["vlr_atualizado_brl"])]
                    for v in venc
                ],
                ["Total", "", "", brl(sum(v["vlr_atualizado_brl"] for v in venc))],
                ["l", "l", "l", "n"],
            )
        )
    if nc:
        h.append("<h3>Ativos sem camada</h3>")
        h.append(
            tabela(
                ["Investimento", "Instituição", "Valor"],
                [[esc(x["ativo"]), x["instituicao"].title(), brl(x["vlr_atualizado_brl"])] for x in nc],
            )
        )
        h.append('<p class="sub">Classificar na aba <code>classificacao</code> da planilha.</p>')
    return "".join(h)


# ------------------------------------------------------------------ montagem ---


def familia(escopo):
    return "orcamento" if escopo == "orcamento" else "investimentos"


def portao(meta, escopo):
    """(pronto, pendências) do escopo. Investimento é por titular: ativo sem camada de um
    titular não segura o relatório dos outros."""
    pr = meta.get("prontidao") or {}
    if escopo == "orcamento":
        return pr.get("pronto_orcamento", True), pr.get("pendencias_orcamento") or []
    tit = (pr.get("por_titular") or {}).get(escopo)
    if tit:
        return tit["pronto"], tit["pendencias"]
    return pr.get("pronto_investimentos", True), pr.get("pendencias_investimentos") or []


def reserva_casal(d):
    """Reserva do casal contra mínimo (N x mediana da despesa de 6 meses) e teto. Mediana para
    que um mês atípico não infle o mínimo; se o mínimo passar do teto, vale o mínimo."""
    dre = d["dre_mensal"]
    mediana6 = mediana([r["total_despesas"] for r in dre[-7:-1]])
    por_pessoa = {
        p: sum(c["valor"] for c in d["carteira_camada"] if c["pessoa"] == p and c["camada"] == "RESERVA")
        for p in ("lucas", "jessica")
    }
    total = sum(por_pessoa.values())
    minimo = RESERVA_MIN_MESES * mediana6
    teto = max(RESERVA_TETO, minimo)
    if total < minimo:
        situacao = f"faltam {brl(minimo - total)} para o mínimo"
    elif total > teto:
        situacao = f"excedente de {brl(total - teto)} acima do teto, que orienta novos aportes"
    else:
        situacao = "entre o mínimo e o teto"
    return {"por_pessoa": por_pessoa, "total": total, "mediana6": mediana6, "minimo": minimo,
            "teto": teto, "excedente": max(total - teto, 0), "falta": max(minimo - total, 0),
            "situacao": situacao}


def fatos_html(fatos):
    if not fatos:
        return ""
    itens = "".join(f"<li>{esc(f['fato'].rstrip('.'))} ({esc(f.get('valor', ''))})</li>" for f in fatos)
    return f"<p><strong>Fatos relevantes do mês.</strong></p><ul>{itens}</ul>"


def aviso_prontidao(meta, escopo):
    """Tarja de dado incompleto. Só aparece quando o relatório foi gerado
    contra a recusa do portão — o número está incompleto e o leitor precisa
    saber disso antes de qualquer conclusão.

    Os portões são dois e independentes: o relatório de carteira não carrega
    tarja de mês de gasto não fechado, e vice-versa."""
    pr = meta.get("prontidao") or {}
    fam = familia(escopo)
    pronto, pendencias = portao(meta, escopo)
    if pronto:
        return ""
    itens = "".join(f"<li>{esc(p)}</li>" for p in pendencias)
    if fam == "orcamento":
        titulo = "Dados incompletos: mês não fechado"
        corpo = (
            "<p>Totais, médias e taxa de poupança estão subestimados e nenhuma "
            "comparação com meses anteriores é válida.</p>"
        )
        fechado = pr.get("ultimo_mes_fechado")
        alt = f"<p>Último mês integralmente carregado: <strong>{mes_extenso(fechado)}</strong>.</p>" if fechado else ""
    elif meta["defasagem_carteira_meses"] > 2:
        titulo = "Carteira defasada"
        corpo = (
            f"<p>Posição mais recente em <strong>{mes_extenso(meta['mes_carteira'])}</strong>, "
            f"{meta['defasagem_carteira_meses']} meses antes de {mes_extenso(meta['mes_ref'])}.</p>"
        )
        alt = ""
    else:
        titulo = "Carteira incompleta"
        corpo = "<p>Há ativos sem camada: alocação e perfil abaixo estão distorcidos.</p>"
        alt = ""
    return f'<div class="destaque-bloco alerta"><h4>{titulo}</h4>{corpo}<ul>{itens}</ul>{alt}</div>'


def cabecalho(titulo, periodo, meta, escopo):
    defasagem = meta["defasagem_carteira_meses"]
    # A carteira fecha em cadência própria: sem o aviso o leitor supõe que
    # todos os números são do mesmo mês.
    if not defasagem:
        aviso = ""
    elif escopo == "orcamento":
        aviso = (
            f"<p class='aviso-datas'>Orçamento de {mes_extenso(meta['mes_ref'])}; a reserva vem da carteira "
            f"de {mes_extenso(meta['mes_carteira'])}.</p>"
        )
    else:
        aviso = (
            f"<p class='aviso-datas'>Carteira de {mes_extenso(meta['mes_carteira'])}, último fechamento "
            f"disponível, {defasagem} mês antes do mês de referência.</p>"
        )
    return f"""<meta charset="utf-8"><title>{esc(titulo)}</title><style>{css_inline()}</style>
<div class="compacto">
<header class="cabecalho-doc">
  <div><h1>{esc(titulo)}</h1><div class="periodo">{esc(periodo)}</div></div>
  <div class="meta-doc">Fechamento de {mes_extenso(meta["mes_ref"])}<br>Gerado em {data_br(meta["gerado_em"])}</div>
</header>
{aviso}{aviso_prontidao(meta, escopo)}"""


def notas(meta, premissas, escopo):
    pol = politica_vigente(meta["gerado_em"])
    linhas = []

    pronto, pendencias = portao(meta, escopo)
    if not pronto:
        rotulo = "Mês não fechado" if escopo == "orcamento" else "Carteira com pendência"
        linhas.append(
            f"<p><strong>{rotulo}.</strong> Gerado apesar do portão de prontidão: "
            f"{esc('; '.join(pendencias))}</p>"
        )

    if pol["nome"]:
        detalhe = ""
        if escopo == "orcamento" and pol["postura"]:
            detalhe = f"; gastos em {esc(pol['postura'])}"
        elif escopo != "orcamento" and pol["perfis"].get(escopo):
            detalhe = f"; perfil de referência {esc(pol['perfis'][escopo].lower())}"
        linhas.append(
            f"<p>Política vigente em {data_br(meta['gerado_em'])}: <strong>{esc(pol['nome'])}</strong>, "
            f"desde {data_br(pol['inicio'].isoformat())}{detalhe}.</p>"
        )
    else:
        linhas.append(f"<p>Nenhuma política econômica vigente em {data_br(meta['gerado_em'])}.</p>")
    if premissas:
        linhas.append("<ul>" + "".join(f"<li>{esc(p)}</li>" for p in premissas) + "</ul>")
    avisos = ((meta.get("prontidao") or {}).get("por_titular") or {}).get(escopo, {}).get("avisos") or []
    if avisos:
        lista = "; ".join(esc(a.split(" (")[0]) for a in avisos)
        linhas.append(f"<p><strong>Posição possivelmente faltando</strong> (planilha acima da carteira, ver "
                      f"<code>investimentos_faltantes_identificados</code>): {lista}.</p>")
    if escopo == "orcamento":
        casal = fatos_do_mes(meta["mes_ref"], "lucas") + fatos_do_mes(meta["mes_ref"], "jessica")
        linhas.append(fatos_html([f for f in fatos_do_mes(meta["mes_ref"]) if f in casal]))
    else:
        linhas.append(fatos_html(fatos_do_mes(meta["mes_carteira"], escopo, "patrim")))

    # Data especial explica pico de rolê e diversos — só interessa ao orçamento.
    esp = meta.get("motivos_especiais")
    if esp and escopo == "orcamento":
        linhas.append(f"<p>Mês de data especial ({esc(esp)}), que costuma elevar rolê e diversos.</p>")

    if escopo == "orcamento":
        escopo_txt = "Posição de cada carteira nos relatórios de investimento."
    elif escopo in COM_PATRIMONIO:
        escopo_txt = "Receita e despesa no relatório do casal."
    else:
        escopo_txt = "Sem lançamento de receita e despesa no warehouse para esta carteira."
    linhas.append(
        f"<p>Fonte: camada <code>marts</code> do warehouse pessoal, sem meses posteriores ao de referência. "
        f"{escopo_txt} Gerado automaticamente; não é recomendação de profissional certificado.</p>"
    )
    return f'<footer class="notas">{"".join(linhas)}</footer></div>'


def montar_orcamento(d, n):
    """Relatório do casal: receita, despesa e o que sobra. Carteira e
    patrimônio saem nos relatórios individuais — aqui a carteira entra só pela
    reserva de emergência, que é dimensionada pela despesa do casal."""
    meta = d["meta"]
    dre = d["dre_mensal"]
    ult = dre[-1]
    meses = [r["mes_debito"] for r in dre]

    desp6 = media([r["total_despesas"] for r in dre[-7:-1]])
    rec6 = media([r["total_receita"] for r in dre[-7:-1]])
    poupanca = ult["resultado"] / ult["total_receita"] * 100 if ult["total_receita"] else 0
    poupanca12 = sum(r["resultado"] for r in dre) / sum(r["total_receita"] for r in dre) * 100

    res = reserva_casal(d)
    cobertura = res["total"] / res["mediana6"] if res["mediana6"] else 0

    # Fato relevante tem valor aproximado: o recorrente lê o padrão, não concilia o mês.
    extra = {r["mes_debito"]: extraordinario_casal(r["mes_debito"]) for r in dre}
    rec_mes = ult["resultado"] + extra[ult["mes_debito"]]
    poupanca12_rec = (
        sum(r["resultado"] + extra[r["mes_debito"]] for r in dre) / sum(r["total_receita"] for r in dre) * 100
    )
    nota_resultado = f"{pct(poupanca)} da receita"
    if extra[ult["mes_debito"]]:
        nota_resultado += (
            f" · sem extraordinários ~{brl(rec_mes)} "
            f"({pct(rec_mes / ult['total_receita'] * 100 if ult['total_receita'] else 0)})"
        )
    alvo_l, alvo_j = aporte_alvo(d, "lucas"), aporte_alvo(d, "jessica")
    linha_aporte = (
        f"<p class='sub'>Aporte-alvo do mês ({META_POUPANCA_PCT:g}% da receita de cada um): "
        f"{brl((alvo_l or 0) + (alvo_j or 0))} (Lucas {brl(alvo_l or 0)}, Jéssica {brl(alvo_j or 0)}); "
        f"resultado do casal {brl(ult['resultado'])}.</p>"
        if alvo_l or alvo_j
        else ""
    )
    des = d.get("desempenho")
    linha_inflacao = (
        f"<p class='sub'>Inflação pessoal de {mes_extenso(des['mes'])}: "
        f"{sinal(des['series']['minha_inflacao']['mes'] * 100, 1)} (IPCA "
        f"{sinal(des['series']['ipca']['mes'] * 100, 1)}).</p>"
        if des and des["series"]["minha_inflacao"]["mes"] is not None
        else ""
    )

    partes = [
        cabecalho("Orçamento do casal", mes_extenso(meta["mes_ref"]).capitalize(), meta, "orcamento"),
        '<div class="kpis">'
        + kpi(
            "Receita do mês",
            brl(ult["total_receita"]),
            f"{sinal(variacao(ult['total_receita'], rec6))} vs. média 6m",
            classe_delta(variacao(ult["total_receita"], rec6)),
        )
        + kpi("Resultado do mês", brl(ult["resultado"]), nota_resultado)
        + kpi(
            "Despesa total",
            brl(ult["total_despesas"]),
            f"{sinal(variacao(ult['total_despesas'], desp6))} vs. média 6m",
            classe_delta(variacao(ult["total_despesas"], desp6), bom_se_sobe=False),
        )
        + kpi(
            "Reserva de emergência",
            f"{cobertura:.1f}".replace(".", ",") + " meses",
            f"mín. {brl(res['minimo'])} · teto {brl(res['teto'])}",
            "delta-neg" if res["falta"] else "",
        )
        + "</div>"
        + (n.get("sumario") or ""),
    ]

    partes.append(
        secao(
            None,
            "Resultado",
            "Receita e despesa nos últimos 13 meses",
            f"<figure>{barras_agrupadas(meses, [('Receita', SERIES[0], [r['total_receita'] for r in dre]), ('Despesa', SERIES[1], [r['total_despesas'] for r in dre])], altura=165)}"
            f"{legenda([('Receita', SERIES[0]), ('Despesa', SERIES[1])])}</figure>"
            f"<p class='sub'>Média de 13 meses: receita {brl(media([r['total_receita'] for r in dre]))}, "
            f"despesa {brl(media([r['total_despesas'] for r in dre]))}, poupança {pct(poupanca12)}, "
            f"{pct(poupanca12_rec)} sem os fatos extraordinários (meta {META_POUPANCA_PCT:g}%).</p>"
            + linha_aporte
            + linha_inflacao,
        )
    )

    partes.append(
        secao(
            None,
            "Recomendações",
            "Gasto, poupança e reserva; o destino do aporte está nos relatórios de investimento",
            acompanhamento_html(n.get("acompanhamento"), mes_anterior(meta["mes_ref"]))
            + recomendacoes_html(n.get("recomendacoes", [])),
        )
    )

    series_cat = [(ROTULO_CAT[c], COR_CAT[c], [r[f"total_{c}"] for r in dre]) for c in CATEGORIAS]
    nao_essencial = sum(ult[f"total_{c}"] for c in CATEGORIAS if not NATUREZA_CAT[c]["essencial"])
    lin_cat = []
    for c in CATEGORIAS:
        atual = ult[f"total_{c}"]
        m6 = media([r[f"total_{c}"] for r in dre[-7:-1]])
        v = variacao(atual, m6)
        lin_cat.append(
            [
                rotulo_chip(COR_CAT[c], ROTULO_CAT[c]),
                "essencial" if NATUREZA_CAT[c]["essencial"] else "não essencial",
                brl(atual),
                pct(atual / ult["total_despesas"] * 100 if ult["total_despesas"] else 0),
                brl(m6),
                f'<span class="{classe_delta(v, bom_se_sobe=False)}">{sinal(v)}</span>',
            ]
        )
    partes.append(
        secao(
            None,
            "Gastos por categoria",
            f"{mes_extenso(meta['mes_ref']).capitalize()} contra a média dos 6 meses anteriores",
            f"<figure>{barras_empilhadas(meses, series_cat, altura=185)}"
            f"{legenda([(ROTULO_CAT[c], COR_CAT[c]) for c in CATEGORIAS])}</figure>"
            + tabela(
                ["Categoria", "Natureza", "No mês", "% da despesa", "Média 6m", "Var. vs 6m"],
                lin_cat,
                ["Total", "", brl(ult["total_despesas"]), "100,0%", brl(desp6),
                 sinal(variacao(ult["total_despesas"], desp6))],
                ["l", "l", "n", "n", "n", "n"],
            )
            + f"<p class='sub'>Não essencial no mês: {brl(nao_essencial)} "
            f"({pct(nao_essencial / ult['total_despesas'] * 100 if ult['total_despesas'] else 0)} da despesa), "
            f"pela natureza declarada em cada categoria.</p>",
        )
    )

    # A reserva é a única ponte entre orçamento e carteira: o tamanho dela é
    # ditado pela despesa, mas o saldo mora na camada RESERVA dos dois titulares.
    reserva_html = (
        "<h3>Reserva de emergência</h3>"
        + tabela(
            ["Titular", "Reserva"],
            [[NOME[p], brl(v)] for p, v in res["por_pessoa"].items()],
            ["Total", brl(res["total"])],
        )
        + f"<p class='sub'>Mínimo {brl(res['minimo'])} ({RESERVA_MIN_MESES} × mediana de 6 meses, "
        f"{brl(res['mediana6'])}); teto {brl(res['teto'])}. Situação: {res['situacao']}. "
        f"Posição de {mes_extenso(meta['mes_carteira'])}.</p>"
    )
    luz_html = (
        "<h3>Conta de energia</h3>"
        + tabela(
            ["Mês", "Fatura", "kWh/dia", "R$/kWh"],
            [
                [
                    mes_curto(r["mes"]),
                    brl(r["vlr_fatura"], 2),
                    f"{r['kwh_dia']}".replace(".", ","),
                    f"{r['preco_kwh']:.2f}".replace(".", ","),
                ]
                for r in d["luz"][-6:]
            ],
        )
        + "<p class='sub'>kWh/dia é consumo; R$/kWh é tarifa.</p>"
    )
    partes.append(secao(None, "Reserva e energia", "", grade_2(reserva_html, luz_html)))

    if n.get("diagnostico_orcamento"):
        partes.append(secao(None, "Leitura do orçamento", "", bloco("", n["diagnostico_orcamento"])))

    partes.append(notas(meta, n.get("premissas", []), "orcamento"))
    return "\n".join(partes)


def aporte_alvo(d, pessoa):
    """Meta de poupança aplicada à receita do titular no mês, quando a política vigente pede aporte
    por meta de poupança. None para quem não tem receita no warehouse (Deusa)."""
    if not politica_vigente(d["meta"]["gerado_em"]).get("aporte"):
        return None
    receita = next((r["receita_total"] for r in d.get("receita_titular") or [] if r["pessoa"] == pessoa), None)
    return receita * META_POUPANCA_PCT / 100 if receita else None


def desempenho_html(d, serie, rotulo):
    """Patrimônio contra inflação pessoal, IPCA e CDI no último mês com índice publicado."""
    des = d.get("desempenho")
    if not des or not des["series"][serie]["mes"]:
        return ""

    def p100(v):
        return "—" if v is None else sinal(v * 100, 1)

    lin = [
        [rotulo, p100(des["series"][serie]["mes"]), p100(des["series"][serie]["12m"])],
        *[
            [r, p100(des["series"][k]["mes"]), p100(des["series"][k]["12m"])]
            for k, r in (("minha_inflacao", "Inflação pessoal"), ("ipca", "IPCA"), ("cdi", "CDI"))
        ],
    ]
    extra = " Queda no patrimônio de Deusa não tem causa apurável: resgate e mercado se confundem." if serie == "deusa" else ""
    return f"<h3>Desempenho, {mes_extenso(des['mes'])}</h3>" + grade_2(
        tabela(["", "No mês", "12 meses"], lin),
        "<p class='sub'>A variação do patrimônio inclui aportes, resgates e entradas como herança: diz se o "
        f"patrimônio cresceu mais que a inflação pessoal, não se a carteira bateu o CDI.{extra}</p>",
    )


SITUACAO_ACOMP = {
    "seguida": "tag-ok",
    "parcial": "tag-atencao",
    "não seguida": "tag-critico",
    "nao seguida": "tag-critico",
    "sem dado": "",
}


def acompanhamento_html(itens, mes_anterior):
    if not itens:
        return ""
    lin = [
        [
            esc(i.get("recomendacao", "")),
            f'<span class="tag {SITUACAO_ACOMP.get(i.get("situacao", "").lower(), "")}">'
            f'{esc(i.get("situacao", ""))}</span>',
            esc(i.get("evidencia", "")),
        ]
        for i in itens
    ]
    return (
        f"<h3>Recomendações de {mes_extenso(mes_anterior)}</h3>"
        + tabela(["Recomendação", "Situação", "Evidência"], lin, None, ["l", "l", "l"])
        + "<h3>Para o próximo mês</h3>"
    )


def mes_anterior(mes):
    a, m = int(mes[:4]), int(mes[5:7])
    a, m = (a - 1, 12) if m == 1 else (a, m - 1)
    return f"{a}-{m:02d}-01"


def linha_reserva_casal(d, pessoa):
    """A reserva é do casal; o excedente sobre o teto vira aporte, e o titular precisa ver isso
    ao lado das camadas dele."""
    if pessoa not in COM_PATRIMONIO:
        return ""
    res = reserva_casal(d)
    if not (res["excedente"] or res["falta"]):
        return ""
    return (
        f"<p class='sub'>Reserva do casal {brl(res['total'])} ({NOME[pessoa]}: "
        f"{brl(res['por_pessoa'][pessoa])}); mínimo {brl(res['minimo'])}, teto {brl(res['teto'])}: "
        f"{res['situacao']}.</p>"
    )


def montar_investimentos(d, n, pessoa):
    """Relatório de investimentos de um titular. O gráfico de patrimônio só
    existe para quem tem série em staging_google_sheets.stg_patrimonio."""
    meta = d["meta"]
    tem_patrimonio = pessoa in COM_PATRIMONIO
    camadas = [c for c in d["carteira_camada"] if c["pessoa"] == pessoa]
    total = sum(c["valor"] for c in camadas)
    div = [r for r in d["dividendos"] if r["pessoa"] == pessoa]
    mdiv = sorted({r["mes_base"] for r in div})
    sv = [sum(r["vlr_liquido_brl"] for r in div if r["mes_base"] == m) for m in mdiv]
    tot12 = sum(sv)
    reserva = next((c["valor"] for c in camadas if c["camada"] == "RESERVA"), 0)
    pol = politica_vigente(meta["gerado_em"])
    cal = pol["calibragem"].get(pessoa)
    moedas = {m["moeda_ativo"]: float(m["pct_da_carteira"]) for m in d["carteira_moeda"] if m["pessoa"] == pessoa}
    # Dólar em renda fixa protege; em renda variável é risco. O KPI mostra os dois.
    pos = [x for x in d["posicoes"] if x["pessoa"] == pessoa]
    usd_rv = sum(x["vlr_atualizado_brl"] for x in pos if x["moeda_ativo"] == "USD" and x["classe_ativo"] == "RENDA VARIAVEL")
    usd = sum(x["vlr_atualizado_brl"] for x in pos if x["moeda_ativo"] == "USD")

    pat = d["patrimonio"] if tem_patrimonio else []
    col_pat = f"patrimonio_liquido_{pessoa}"
    upat = pat[-1][col_pat] if pat else None
    var_pat = variacao(pat[-1][col_pat], pat[-2][col_pat]) if len(pat) > 1 else None

    # Quatro KPIs sempre: quem não tem patrimônio abre com a reserva, para não
    # deixar buraco no grid.
    primeiro_kpi = (
        kpi("Patrimônio líquido", brl(upat), f"{sinal(var_pat)} vs. mês anterior", classe_delta(var_pat))
        if tem_patrimonio
        else kpi("Reserva", brl(reserva), f"{reserva / total * 100:.0f}% da carteira" if total else "")
    )
    partes = [
        cabecalho(f"Investimentos de {NOME[pessoa]}", mes_extenso(meta["mes_carteira"]).capitalize(), meta, pessoa),
        '<div class="kpis">'
        + primeiro_kpi
        + kpi("Carteira total", brl(total))
        + kpi(
            "Renda passiva 12m",
            brl(tot12),
            f"yield {pct(tot12 / total * 100 if total else 0)}",
        )
        + kpi(
            "Exposição em dólar",
            pct(moedas.get("USD", 0)),
            f"RV {pct(usd_rv / total * 100 if total else 0)} · RF e caixa "
            f"{pct((usd - usd_rv) / total * 100 if total else 0)}",
        )
        + "</div>"
        + (n.get("sumario") or ""),
        secao(None, "Alocação por camada",
              "Papel de cada parte da carteira" + (" contra o alvo da política" if cal else ""),
              secao_camadas(d, pessoa, cal) + linha_reserva_casal(d, pessoa)),
        secao(
            None,
            "Recomendações",
            "Destino do aporte"
            + (
                f"; aporte-alvo {brl(alvo)} ({META_POUPANCA_PCT:g}% da receita de {mes_extenso(meta['mes_ref'])})"
                if (alvo := aporte_alvo(d, pessoa))
                else ""
            ),
            acompanhamento_html(n.get("acompanhamento"), mes_anterior(meta["mes_ref"]))
            + recomendacoes_html(n.get("recomendacoes", [])),
        ),
        secao(None, "Perfil de referência", "Classe de ativo contra a carteira-modelo do perfil",
              secao_perfil(d, pessoa, pol["perfis"].get(pessoa))),
        secao(None, "Riscos", "", secao_riscos(d, pessoa)),
    ]

    leitura = (n.get("diagnostico_carteira") or "") + (n.get("diagnostico_riscos") or "")
    if leitura:
        partes.append(secao(None, "Leitura da carteira", "", bloco("", leitura)))

    # Lado a lado, 13 rótulos de barra em meia largura se sobrepõem; os dois
    # gráficos vão empilhados em largura cheia.
    graf_pat = (
        "<h3>Patrimônio líquido, 13 meses</h3>"
        f"<figure>{barras_empilhadas([r['mes_base'] for r in pat], [(NOME[pessoa], SERIES[0], [r[col_pat] for r in pat])], altura=110)}</figure>"
        if pat
        else ""
    )
    # Carteira sem provento rende gráfico de zeros; uma frase diz o mesmo.
    graf_renda = (
        "<h3>Proventos líquidos por mês, 12 meses</h3>"
        f"<figure>{barras_empilhadas(mdiv, [('Proventos', SERIES[0], sv)], altura=110)}</figure>"
        if tot12
        else "<h3>Proventos</h3><p>Nenhum provento nos últimos 12 meses.</p>"
    )
    partes.append(secao(None, "Evolução", "", graf_pat + graf_renda + desempenho_html(d, pessoa, "Patrimônio líquido")))

    partes.append(notas(meta, n.get("premissas", []), pessoa))
    return "\n".join(partes)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dados", required=True)
    ap.add_argument("--escopo", required=True, choices=["orcamento"] + ESCOPOS_INVESTIMENTO)
    ap.add_argument("--narrativa", required=True)
    ap.add_argument(
        "--saida",
        required=True,
        help="caminho do relatório. Termine em .pdf para entregar "
        "só o PDF (o HTML vira temporário e é descartado); "
        "termine em .html para inspecionar a marcação.",
    )
    a = ap.parse_args()

    d = json.loads(Path(a.dados).read_text(encoding="utf-8"))
    n = json.loads(Path(a.narrativa).read_text(encoding="utf-8"))
    html = montar_orcamento(d, n) if a.escopo == "orcamento" else montar_investimentos(d, n, a.escopo)
    escrever(html, a.saida, Path(__file__).resolve().parent / "html_para_pdf.sh")
    # A narrativa entregue vira a base do acompanhamento no relatório do mês seguinte.
    if a.saida.endswith(".pdf"):
        destino = Path(a.saida).parent / f"narrativa_{a.escopo}.json"
        destino.write_text(json.dumps(n, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
