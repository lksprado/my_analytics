"""Parâmetros da política de investimento e vocabulário do domínio.

Os números da política e os verbetes do glossário são lidos de
`models/presentation/financas/_docs_financas.md`, a fonte única. Aqui ficam só
as escolhas de apresentação: cores, rótulos e ordem.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path

_DOC = Path(__file__).resolve().parents[2] / "models/presentation/financas/_docs_financas.md"
_TEXTO_DOC = _DOC.read_text(encoding="utf-8")


def _chave(texto):
    return unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode().strip().lower()


def _bloco(nome):
    m = re.search(r"\{% docs " + nome + r" %\}(.*?)\{% enddocs %\}", _TEXTO_DOC, re.S)
    if not m:
        raise ValueError(f"_docs_financas.md: bloco `{nome}` não encontrado")
    return m.group(1)


def _tabela(bloco, titulo):
    m = re.search(r"^### " + re.escape(titulo) + r"\n(.*?)(?=^### |\Z)", _bloco(bloco), re.S | re.M)
    linhas = [ln for ln in (m.group(1).splitlines() if m else []) if ln.startswith("|")]
    if len(linhas) < 3:
        raise ValueError(f"_docs_financas.md: tabela sob `### {titulo}` em `{bloco}` não encontrada")
    celulas = [[c.strip() for c in ln.strip().strip("|").split("|")] for ln in linhas]
    return [dict(zip(celulas[0], linha)) for linha in celulas[2:]]


def _numero(texto):
    m = re.search(r"\d[\d.]*(?:,\d+)?", texto)
    if not m:
        raise ValueError(f"_docs_financas.md: valor sem número: {texto!r}")
    valor = float(m.group().replace(".", "").replace(",", "."))
    return int(valor) if valor.is_integer() else valor


def _parametro(nome):
    achados = [ln for ln in _tabela("politica_investimentos", "Demais parâmetros") if ln["Parâmetro"] == nome]
    if not achados:
        raise ValueError(f"_docs_financas.md: parâmetro `{nome}` ausente em `### Demais parâmetros`")
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

# --------------------------------------------------- política (lida do doc) ---

ALVOS_CAMADA = {
    _chave(ln["Pessoa"]): {cm: _numero(ln[cm]) for cm in CAMADAS_COM_ALVO}
    for ln in _tabela("politica_investimentos", "Alocação-alvo por camada")
}
APORTE_ALVO = {
    _chave(ln["Pessoa"]): _numero(ln["Aporte alvo (R$/mês)"])
    for ln in _tabela("politica_investimentos", "Aporte mensal estimado")
}
# "Lucas e Jéssica" é a reserva do casal.
META_RESERVA_MESES = {
    ("casal" if " e " in ln["Pessoa"] else _chave(ln["Pessoa"])): _numero(ln["N (meses)"])
    for ln in _tabela("politica_investimentos", "Metas e limites")
}
META_RESERVA_PISO = _numero(_parametro("Piso da reserva-alvo")[0]["Valor"])
BANDA_CAMADA_PP = _numero(_parametro("Banda de tolerância da alocação")[0]["Valor"])
FGC_FOLGA_MINIMA = _numero(_parametro("Folga mínima sobre o limite FGC")[0]["Valor"])
META_POUPANCA_PCT = _numero(_parametro("Taxa de poupança alvo")[0]["Valor"])
META_INTERNACIONAL_PCT = {
    _chave(pessoa): _numero(ln["Valor"])
    for ln in _parametro("Exposição internacional alvo")
    for pessoa in ln["Aplicação"].split(" e ")
}

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
