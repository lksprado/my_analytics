"""Regras fixas, política econômica vigente, perfil de referência e vocabulário do domínio.

Tudo que é regra é lido de `models/presentation/financas/`:

    _convencoes.md              tabela `## Parâmetros` (reserva, FGC, poupança)
    _politicas_financas.md      políticas datadas: período, postura, perfil por titular, calibragem opcional
    _perfis_de_investimento.md  §3, alocação média e faixas por perfil (fonte externa)
    _despesas.md                natureza de cada categoria de gasto
    _fatos_relevantes.md        eventos datados por mês

Aqui ficam só as escolhas de apresentação: cores, rótulos e ordem.
"""

from __future__ import annotations

import re
import unicodedata
from datetime import date
from pathlib import Path

_PASTA = Path(__file__).resolve().parents[2] / "models/presentation/financas"


def _ler(nome):
    return (_PASTA / nome).read_text(encoding="utf-8")


_TEXTO_CONVENCOES = _ler("_convencoes.md")
_TEXTO_POLITICAS = _ler("_politicas_financas.md")
_TEXTO_PERFIS = _ler("_perfis_de_investimento.md")
_TEXTO_DESPESAS = _ler("_despesas.md")
_TEXTO_FATOS = _ler("_fatos_relevantes.md")


def _chave(texto):
    return unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode().strip().lower()


def _tabela_sob(texto, titulo):
    """Primeira tabela Markdown sob o título `##`/`###` que começa com `titulo`."""
    m = re.search(r"^#{2,3} " + re.escape(titulo) + r"[^\n]*\n(.*?)(?=^#{2,3} |\Z)", texto, re.S | re.M)
    linhas = []
    for ln in m.group(1).splitlines() if m else []:
        if ln.startswith("|"):
            linhas.append(ln)
        elif linhas:
            break
    if len(linhas) < 2:
        return None
    celulas = [[c.strip() for c in ln.strip().strip("|").split("|")] for ln in linhas]
    return [dict(zip(celulas[0], linha)) for linha in celulas[2:]]


def _numeros(texto):
    return [
        int(v) if (v := float(n.replace(".", "").replace(",", "."))).is_integer() else v
        for n in re.findall(r"\d[\d.]*(?:,\d+)?", texto)
    ]


def _numero(texto, origem):
    achados = _numeros(texto)
    if not achados:
        raise ValueError(f"{origem}: valor sem número: {texto!r}")
    return achados[0]


SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]

# ------------------------------------------------------------------ pessoas ---

NOME = {"lucas": "Lucas", "jessica": "Jéssica", "deusa": "Deusa"}
ESCOPOS_INVESTIMENTO = ["lucas", "jessica", "deusa"]
# Deusa só tem o total líquido da planilha dela, sem série por pessoa em stg_patrimonio.
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

# ------------------------------------------------------------------ camadas ---

COR_CAMADA = {
    "RESERVA": SERIES[0],
    "CRESCIMENTO": SERIES[1],
    "RENDA": SERIES[2],
    "RESERVA ESTRATEGICA": SERIES[3],
    "NAO CLASSIFICADO": "#7a7975",
}
CAMADAS_COM_ALVO = ["RESERVA", "CRESCIMENTO", "RENDA"]
CAMADAS_SEM_ALVO = ["RESERVA ESTRATEGICA", "NAO CLASSIFICADO"]
ROTULO_CAMADA = {
    "RESERVA": "Reserva",
    "CRESCIMENTO": "Crescimento",
    "RENDA": "Renda",
    "RESERVA ESTRATEGICA": "Reserva estratégica",
    "NAO CLASSIFICADO": "Não classificado",
}

# ------------------------------------------------- classes de referência ---

CLASSES_REFERENCIA = [
    "POS FIXADO",
    "INFLACAO",
    "PREFIXADO",
    "MULTIMERCADO",
    "ACOES BRASIL",
    "FIIS",
    "INTERNACIONAL RF",
    "INTERNACIONAL RV",
    "ALTERNATIVOS",
]
ROTULO_CLASSE = {
    "POS FIXADO": "Pós-fixado",
    "INFLACAO": "Inflação (IPCA+)",
    "PREFIXADO": "Prefixado",
    "MULTIMERCADO": "Multimercado",
    "ACOES BRASIL": "Ações Brasil",
    "FIIS": "Fundos imobiliários",
    "INTERNACIONAL RF": "Internacional RF e caixa",
    "INTERNACIONAL RV": "Internacional RV",
    "ALTERNATIVOS": "Alternativos",
}
# O perfil declara o internacional somado; aqui ele se abre em RF e RV porque o risco é outro.
CLASSES_RENDA_FIXA = ["POS FIXADO", "INFLACAO", "PREFIXADO", "INTERNACIONAL RF"]
CLASSES_RISCO = ["ACOES BRASIL", "FIIS", "INTERNACIONAL RV", "ALTERNATIVOS"]
CLASSES_INTERNACIONAIS = ["INTERNACIONAL RF", "INTERNACIONAL RV"]

# --------------------------------------------- regras fixas (_convencoes.md) ---


def _parametro(nome):
    linhas = _tabela_sob(_TEXTO_CONVENCOES, "Parâmetros") or []
    achado = next((ln for ln in linhas if ln.get("Parâmetro") == nome), None)
    if not achado:
        raise ValueError(f"_convencoes.md: parâmetro `{nome}` ausente na tabela de `## Parâmetros`")
    return _numero(achado["Valor"], "_convencoes.md")


RESERVA_MIN_MESES = _parametro("Reserva mínima")
RESERVA_TETO = _parametro("Teto da reserva")
FGC_LIMITE = _parametro("Limite FGC por conglomerado")
FGC_FOLGA_MINIMA = _parametro("Folga mínima sobre o limite FGC")
META_POUPANCA_PCT = _parametro("Taxa de poupança alvo")
ISENCAO_ACOES_BR = _parametro("Isenção de IR em venda de ações BR")

# ------------------------------------------ política vigente (_politicas) ---


def _campo(secao, nome):
    m = re.search(r"^- " + nome + r":[ \t]*(\d{4}-\d{2}-\d{2})?", secao, re.M)
    return date.fromisoformat(m.group(1)) if m and m.group(1) else None


def _postura(secao):
    m = re.search(r"^### Gastos\n(.*?)(?=^##|\Z)", secao, re.S | re.M)
    p = re.search(r"^- Postura:[ \t]*(\S+)", m.group(1), re.M) if m else None
    return p.group(1) if p else None


def _aporte(secao):
    m = re.search(r"^- Aporte:[ \t]*(.+)$", secao, re.M)
    return m.group(1).strip() if m else None


def _calibragem(secao):
    return {
        _chave(ln["Titular"]): {
            "alvos": {cm: _numero(ln[cm], "_politicas_financas.md") for cm in CAMADAS_COM_ALVO},
            "banda": _numero(ln["Banda (p.p.)"], "_politicas_financas.md"),
            "aporte": _numero(ln["Aporte (R$/mês)"], "_politicas_financas.md"),
        }
        for ln in _tabela_sob(secao, "Calibragem") or []
    }


def _politicas():
    for secao in re.split(r"^## ", _TEXTO_POLITICAS, flags=re.M)[1:]:
        inicio = _campo(secao, "Início")
        if not inicio:
            continue
        nome = re.sub(r"^Política (de |da |do )?", "", secao.splitlines()[0].strip())
        yield {
            "nome": nome,
            "inicio": inicio,
            "fim": _campo(secao, "Fim"),
            "postura": _postura(secao),
            "aporte": _aporte(secao),
            "perfis": {_chave(ln["Titular"]): ln["Perfil"] for ln in _tabela_sob(secao, "Perfil de referência") or []},
            "calibragem": _calibragem(secao),
        }


def politica_vigente(data_geracao):
    """Política de maior início até `data_geracao` (AAAA-MM-DD). As recomendações olham para a
    frente, por isso vale a política do dia em que o relatório roda, não a do mês de referência.
    Sem política, volta `nome` None. Titular fora de `calibragem` não tem alvo por camada."""
    dia = date.fromisoformat(str(data_geracao)[:10])
    candidatas = [p for p in _politicas() if p["inicio"] <= dia]
    if not candidatas:
        return {"nome": None, "inicio": None, "fim": None, "postura": None, "aporte": None, "perfis": {},
                "calibragem": {}}
    return max(candidatas, key=lambda p: p["inicio"])


# ------------------------------------------ perfil de referência (_perfis) ---

# Ordem importa: os totais antes das classes, porque "Total Risco (RV+FII...)" contém "fii".
_PADROES_CLASSE = [
    ("TOTAL RF", "total renda fixa"),
    ("TOTAL RISCO", "total risco"),
    ("POS FIXADO", "pos-fixad"),
    ("POS FIXADO", "pos fixad"),
    ("INFLACAO", "inflacao"),
    ("PREFIXADO", "prefixad"),
    ("MULTIMERCADO", "multimercado"),
    ("ACOES BRASIL", "renda variavel brasil"),
    ("ACOES BRASIL", "acoes brasil"),
    ("FIIS", "fundos imobiliarios"),
    ("FIIS", "fiis"),
    ("INTERNACIONAL", "internacional"),
    ("ALTERNATIVOS", "alternativos"),
]


def _classe_do_rotulo(rotulo):
    k = _chave(re.sub(r"\(.*?\)", "", rotulo.replace("*", "")))
    return next((classe for classe, padrao in _PADROES_CLASSE if padrao in k), None)


DATA_PERFIS = (re.search(r"^# .*?\(.*?,\s*([^)]+)\)", _TEXTO_PERFIS, re.M) or [None, None])[1]


def perfil_referencia(nome):
    """Alocação média e faixa mín-máx do perfil `nome`, por classe de `_PADROES_CLASSE`.
    `INTERNACIONAL` vem somado, como no documento."""
    resumo = _tabela_sob(_TEXTO_PERFIS, "3. Tabela-resumo")
    faixas = _tabela_sob(_TEXTO_PERFIS, "Faixas observadas")
    if not resumo or not faixas:
        raise ValueError("_perfis_de_investimento.md: tabelas da seção 3 não encontradas")
    if nome not in resumo[0]:
        raise ValueError(f"_perfis_de_investimento.md: perfil `{nome}` sem coluna na tabela-resumo")
    medio, faixa = {}, {}
    for ln in resumo:
        if (classe := _classe_do_rotulo(ln["Classe de ativo"])) and _numeros(ln[nome]):
            medio[classe] = _numeros(ln[nome])[0]
    for ln in faixas:
        if (classe := _classe_do_rotulo(ln["Classe"])) and len(n := _numeros(ln[nome])) == 2:
            faixa[classe] = tuple(n)
    faltam = [c for c in ("POS FIXADO", "INFLACAO", "PREFIXADO", "ACOES BRASIL", "FIIS", "INTERNACIONAL",
                          "ALTERNATIVOS", "TOTAL RF", "TOTAL RISCO") if c not in medio]
    if faltam:
        raise ValueError(f"_perfis_de_investimento.md: linhas sem valor para `{nome}`: {faltam}")
    return {"nome": nome, "data": DATA_PERFIS, "medio": medio, "faixa": faixa}


# ---------------------------------------------- natureza do gasto (_despesas) ---


def _natureza():
    out = {}
    for secao in re.split(r"^### ", _TEXTO_DESPESAS, flags=re.M)[1:]:
        cat = _chave(secao.splitlines()[0])
        m = re.search(r"^\*\*Natureza\*\*:?\s*(.*)$", secao, re.M)
        if cat in CATEGORIAS and m:
            k = _chave(m.group(1).split(".")[0])
            out[cat] = {"essencial": "nao essencial" not in k, "variavel": "variavel" in k}
    faltam = [c for c in CATEGORIAS if c not in out]
    if faltam:
        raise ValueError(f"_despesas.md: categorias sem linha `**Natureza**:`: {faltam}")
    return out


NATUREZA_CAT = _natureza()

# ------------------------------------------- fatos relevantes (_fatos) ---

_MESES = {"janeiro": 1, "fevereiro": 2, "marco": 3, "abril": 4, "maio": 5, "junho": 6, "julho": 7,
          "agosto": 8, "setembro": 9, "outubro": 10, "novembro": 11, "dezembro": 12}


def _fatos():
    for secao in re.split(r"^## ", _TEXTO_FATOS, flags=re.M)[1:]:
        m = re.match(r"(\w+)/(\d{4})", _chave(secao.splitlines()[0]))
        if not m or m.group(1) not in _MESES:
            continue
        mes = f"{m.group(2)}-{_MESES[m.group(1)]:02d}"
        for bloco_fato in re.split(r"^(?=\*\*Fato\*\*)", secao, flags=re.M)[1:]:
            campos = {_chave(k): v.strip() for k, v in re.findall(r"^\*\*([^*]+)\*\*:\s*(.*)$", bloco_fato, re.M)}
            numeros = _numeros(campos.get("valor", ""))
            yield {"mes": mes, **campos, "valor_num": numeros[0] if numeros else 0}


FATOS = list(_fatos())


def fatos_do_mes(mes, pessoa=None, impacto=None):
    """Fatos de `mes` (AAAA-MM), filtrados por titular citado em Pessoas e por palavra em Impacto em."""
    return [
        f
        for f in FATOS
        if f["mes"] == str(mes)[:7]
        and (pessoa is None or _chave(NOME[pessoa]) in _chave(f.get("pessoas", "")))
        and (impacto is None or _chave(impacto) in _chave(f.get("impacto em", "")))
    ]


def extraordinario_casal(mes):
    """Gasto do casal em `mes` explicado por fato relevante. O valor do fato é aproximado,
    então o resultado serve para ler o padrão, não para conciliar."""
    casal = fatos_do_mes(mes, "lucas") + fatos_do_mes(mes, "jessica")
    unicos = [f for f in fatos_do_mes(mes) if f in casal]
    return sum(f["valor_num"] for f in unicos if "gastos" in _chave(f.get("impacto em", "")))
