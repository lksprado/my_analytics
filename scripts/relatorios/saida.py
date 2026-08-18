"""Gravação do relatório montado — HTML para depurar, PDF para entregar.

O HTML sempre existiu como passo intermediário, não como produto: o Chrome
headless só imprime a partir de um `file://`, então o documento precisa existir
em disco antes de virar PDF. O que ele não precisa é sobreviver à conversão nem
ficar no diretório de entrega, onde só confundia — dois arquivos por relatório,
um deles sem uso depois do primeiro minuto.

Contrato: a extensão de `--saida` decide o que é entregue.

    --saida R.pdf    grava só o PDF (HTML vai para um temporário e é descartado)
    --saida R.html   grava só o HTML, sem converter — modo de depuração

Em falha de conversão o intermediário é preservado e o caminho vai para o
stderr: é justamente quando se precisa dele.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def escrever(html: str, saida: str | Path, conversor: str | Path) -> Path:
    """Grava `html` em `saida`, convertendo para PDF se a extensão pedir.

    `conversor` é o caminho do `html_para_pdf.sh` — cada skill tem o seu, ao
    lado do próprio montador."""
    saida = Path(saida)
    saida.parent.mkdir(parents=True, exist_ok=True)

    if saida.suffix.lower() != ".pdf":
        saida.write_text(html, encoding="utf-8")
        print(f"HTML montado: {saida} ({len(html) // 1024} KB)")
        return saida

    tmp = Path(tempfile.mkdtemp(prefix="relatorio-"))
    intermediario = tmp / f"{saida.stem}.html"
    intermediario.write_text(html, encoding="utf-8")
    try:
        subprocess.run([str(conversor), str(intermediario), str(saida)],
                       check=True)
    except (subprocess.CalledProcessError, OSError) as erro:
        print(f"erro: conversão para PDF falhou ({erro}). HTML preservado em "
              f"{intermediario}", file=sys.stderr)
        raise
    shutil.rmtree(tmp, ignore_errors=True)
    return saida
