"""Regras fixas, política econômica vigente e vocabulário do domínio.

As regras fixas e os verbetes do glossário são lidos de
`models/presentation/financas/_docs_financas.md`; a calibragem da carteira, da
política vigente no mês em `_politicas_financas.md`. Aqui ficam só as escolhas
de apresentação: cores, rótulos e ordem.
"""

from __future__ import annotations

import calendar
import re
import unicodedata
from datetime import date
from pathlib import Path

_PASTA = Path(__file__).resolve().parents[2] / "models/presentation/financas"
_TEXTO_DOC = (_PASTA / "_docs_financas.md").read_text(encoding="utf-8")
_TEXTO_POLITICAS = (_PASTA / "_politicas_financas.md").read_text(encoding="utf-8")


def _chave(texto):
    return unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode().strip().lower()


def _bloco(nome):
    m = re.search(r"\{% docs " + nome + r" %\}(.*?)\{% enddocs %\}", _TEXTO_DOC, re.S)
    if not m:
        raise ValueError(f"_docs_financas.md: bloco `{nome}` não encontrado")
    return m.group(1)


def _linhas_tabela(texto, titulo):
    m = re.search(r"^### " + re.escape(titulo) + r"\n(.*?)(?=^##|\Z)", texto, re.S | re.M)
    linhas = [ln for ln in (m.group(1).splitlines() if m else []) if ln.startswith("|")]
    if len(linhas) < 2:
        return None
    celulas = [[c.strip() for c in ln.strip().strip("|").split("|")] for ln in linhas]
    return [dict(zip(celulas[0], linha)) for linha in celulas[2:]]


def _tabela(bloco, titulo):
    linhas = _linhas_tabela(_bloco(bloco), titulo)
    if not linhas:
        raise ValueError(f"_docs_financas.md: tabela sob `### {titulo}` em `{bloco}` não encontrada")
    return linhas


def _numero(texto):
    m = re.search(r"\d[\d.]*(?:,\d+)?", texto)
    if not m:
        raise ValueError(f"_docs_financas.md: valor sem número: {texto!r}")
    valor = float(m.group().replace(".", "").replace(",", "."))
    return int(valor) if valor.is_integer() else valor


def _parametro(nome):
    achados = [ln for ln in _tabela("regras_fixas", "Parâmetros") if ln["Parâmetro"] == nome]
    if not achados:
        raise ValueError(f"_docs_financas.md: parâmetro `{nome}` ausente em `### Parâmetros`")
    return achados


def _linha(bloco, prefixo):
    for ln in _bloco(bloco).splitlines():
        if ln.startswith(prefixo):
            return ln[len(prefixo):].strip()
    raise ValueError(f"_docs_financas.md: linha `{prefixo}` ausente em `{bloco}`")


def _texto_md(texto):
    # Código e negrito do Markdown viram texto corrido; categoria citada sai com o rótulo do PDF.
    texto = re.sub(r"`([^`]+)`", lambda m: ROTULO_CAT.get(m.group(1), m.group(1)).lower(), texto)
    return texto.replace("**", "").replace("→ ", "").strip()


# Paleta da skill `dataviz`, na ordem declarada. Cor é por entidade, nunca por
# ranking: a mesma camada e a mesma categoria têm o mesmo slot em todo gráfico
# dos dois relatórios.
SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]

# ------------------------------------------------------------------ pessoas ---

NOME = {"lucas": "Lucas", "jessica": "Jéssica", "deusa": "Deusa"}
# Escopos de relatório de investimento — um por titular.
ESCOPOS_INVESTIMENTO = ["lucas", "jessica", "deusa"]
# Quem tem série de nível por pessoa em staging_google_sheets.stg_patrimonio, que alimenta a
# seção de patrimônio individual do fechamento. Deusa só tem o total líquido da planilha dela
# (índice em riqueza, sem abertura por conta).
COM_PATRIMONIO = ["lucas", "jessica"]

# --------------------------------------------------------------- categorias ---

CATEGORIAS = ["mercado", "diversos", "assinaturas", "role", "transporte", "apartamento", "saude", "educacao"]
ROTULO_CAT = {
    "mercado": "Mercado",
    "diversos": "Diversos",
    "assinaturas": "Assinaturas",
    "role": "Rolê",
    "transporte": "Transporte",
    "apartamento": "Apartamento",
    "saude": "Saúde",
    "educacao": "Educação",
}
COR_CAT = {c: SERIES[i] for i, c in enumerate(CATEGORIAS)}

# Onde há decisão a tomar dentro do mês: `saude` e `educacao` nunca entram em corte, e
# `apartamento` e `assinaturas` são fixas. Base da margem do relatório de meio de mês.
CATEGORIAS_COMPRIMIVEIS = ["role", "diversos", "mercado"]

# ------------------------------------------------------------------ camadas ---

COR_CAMADA = {
    "RESERVA": SERIES[0],
    "CRESCIMENTO": SERIES[1],
    "RENDA": SERIES[2],
    "RESERVA ESTRATEGICA": SERIES[3],
    "NAO CLASSIFICADO": "#7a7975",
}
# Camadas com alocação-alvo, na ordem em que saem no relatório.
CAMADAS_COM_ALVO = ["RESERVA", "CRESCIMENTO", "RENDA"]
# Camadas reportadas à parte, sem alvo (ver `camada_investimento`).
CAMADAS_SEM_ALVO = ["RESERVA ESTRATEGICA", "NAO CLASSIFICADO"]
# Os valores no banco não têm acento; o PDF tem.
ROTULO_CAMADA = {
    "RESERVA": "Reserva",
    "CRESCIMENTO": "Crescimento",
    "RENDA": "Renda",
    "RESERVA ESTRATEGICA": "Reserva estratégica",
    "NAO CLASSIFICADO": "Não classificado",
}

# ------------------------------------------------ regras fixas (lidas do doc) ---

# "Lucas e Jéssica" é a reserva do casal.
META_RESERVA_MESES = {
    ("casal" if " e " in ln["Pessoa"] else _chave(ln["Pessoa"])): _numero(ln["N (meses)"])
    for ln in _tabela("regras_fixas", "Reserva de emergência")
}
META_RESERVA_PISO = _numero(_parametro("Piso da reserva-alvo")[0]["Valor"])
FGC_FOLGA_MINIMA = _numero(_parametro("Folga mínima sobre o limite FGC")[0]["Valor"])
META_POUPANCA_PCT = _numero(_parametro("Taxa de poupança alvo")[0]["Valor"])

# ------------------------------------------------- política vigente (lida do doc) ---


def _campo(secao, nome):
    m = re.search(r"^- " + nome + r":[ \t]*(\d{4}-\d{2}-\d{2})?", secao, re.M)
    if not m:
        raise ValueError(f"_politicas_financas.md: linha `- {nome}:` ausente")
    return date.fromisoformat(m.group(1)) if m.group(1) else None


def _postura(secao):
    m = re.search(r"^### Gastos\n(.*?)(?=^##|\Z)", secao, re.S | re.M)
    p = re.search(r"^- Postura:[ \t]*(\S+)", m.group(1), re.M) if m else None
    return p.group(1) if p else None


def _politicas():
    for secao in re.split(r"^## ", _TEXTO_POLITICAS, flags=re.M)[1:]:
        nome = secao.splitlines()[0].strip()
        linhas = _linhas_tabela(secao, "Calibragem")
        if linhas is None:
            raise ValueError(f"_politicas_financas.md: `{nome}` sem tabela sob `### Calibragem`")
        calibragem = {
            _chave(ln["Titular"]): {
                "alvos": {cm: _numero(ln[cm]) for cm in CAMADAS_COM_ALVO},
                "banda": _numero(ln["Banda (p.p.)"]),
                "aporte": _numero(ln["Aporte (R$/mês)"]),
                "internacional": _numero(ln["Exposição internacional"]),
            }
            for ln in linhas
        }
        yield {
            "nome": nome,
            "inicio": _campo(secao, "Início"),
            "fim": _campo(secao, "Fim"),
            "postura": _postura(secao),
            "calibragem": calibragem,
        }


def politica_vigente(mes_ref):
    """Política de maior início até o fim de `mes_ref` (AAAA-MM ou AAAA-MM-DD).
    Titular ausente de `calibragem` está com calibragem pendente; `postura` é a
    postura de gasto (None se a política não declara). Mês anterior a toda
    política volta com `nome` None e nenhuma calibragem."""
    ano, mes = int(mes_ref[:4]), int(mes_ref[5:7])
    fim_mes = date(ano, mes, calendar.monthrange(ano, mes)[1])
    candidatas = [p for p in _politicas() if p["inicio"] <= fim_mes]
    if not candidatas:
        return {"nome": None, "inicio": None, "fim": None, "postura": None, "calibragem": {}}
    return max(candidatas, key=lambda p: p["inicio"])


# ---------------------------------------------------- glossário (lido do doc) ---

TEXTO_CAMADA = {}
for _cm in COR_CAMADA:
    _t = _texto_md(_linha("camada_investimento", f"`{_cm}` — "))
    TEXTO_CAMADA[_cm] = _t[:1].upper() + _t[1:]
TEXTO_CATEGORIA = {
    c: _texto_md(
        f"{_linha(f'categoria_{c}', f'**{ROTULO_CAT[c]}** — ').capitalize().rstrip('.')}: "
        f"{_linha(f'categoria_{c}', 'Entra:').rstrip('.')}. "
        f"Não inclui {_linha(f'categoria_{c}', 'Não entra:')}"
    )
    for c in CATEGORIAS
}
