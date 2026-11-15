"""Gera um PDF a partir de um Markdown simples (títulos, parágrafos, listas, **negrito** e `código`).

Uso: python tools/docs/md_para_pdf.py docs/bancos-de-dados.md docs/bancos-de-dados.pdf
Requer: pip install reportlab
"""
import html
import os
import re
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import HRFlowable, ListFlowable, ListItem, Paragraph, SimpleDocTemplate, Spacer

VERDE = colors.HexColor('#0B705D')
TINTA = colors.HexColor('#1F2937')
CINZA = colors.HexColor('#5D6874')


def registrar_fontes():
    """Segoe UI no Windows (acentos e boa leitura); fora dele, Helvetica."""
    pasta = os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts')
    arquivos = {'Texto': 'segoeui.ttf', 'Texto-Negrito': 'segoeuib.ttf', 'Texto-Italico': 'segoeuii.ttf', 'Codigo': 'consola.ttf'}
    if all(os.path.exists(os.path.join(pasta, a)) for a in arquivos.values()):
        for nome, arquivo in arquivos.items():
            pdfmetrics.registerFont(TTFont(nome, os.path.join(pasta, arquivo)))
        pdfmetrics.registerFontFamily('Texto', normal='Texto', bold='Texto-Negrito', italic='Texto-Italico', boldItalic='Texto-Negrito')
        return 'Texto', 'Texto-Negrito', 'Codigo'
    return 'Helvetica', 'Helvetica-Bold', 'Courier'


TEXTO, NEGRITO, CODIGO = registrar_fontes()
ESTILOS = {
    'h1': ParagraphStyle('h1', fontName=NEGRITO, fontSize=20, leading=25, textColor=VERDE, spaceAfter=4),
    'h2': ParagraphStyle('h2', fontName=NEGRITO, fontSize=14, leading=18, textColor=TINTA, spaceBefore=14, spaceAfter=6),
    'p': ParagraphStyle('p', fontName=TEXTO, fontSize=10.5, leading=15.5, textColor=TINTA, alignment=TA_LEFT, spaceAfter=7),
    'li': ParagraphStyle('li', fontName=TEXTO, fontSize=10.5, leading=15, textColor=TINTA),
    'sub': ParagraphStyle('sub', fontName=TEXTO, fontSize=9.5, leading=13, textColor=CINZA, spaceAfter=10),
}


def inline(texto):
    """Markdown em linha para a marcação do ReportLab."""
    texto = html.escape(texto, quote=False)
    texto = re.sub(r'`([^`]+)`', rf'<font name="{CODIGO}" size="9.5" color="#0B705D">\1</font>', texto)
    texto = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', texto)
    return texto


def converter(origem, destino, subtitulo):
    linhas = open(origem, encoding='utf-8').read().splitlines()
    historia, lista, paragrafo = [], [], []

    def fechar_paragrafo():
        if paragrafo:
            historia.append(Paragraph(inline(' '.join(paragrafo)), ESTILOS['p']))
            paragrafo.clear()

    def fechar_lista():
        if lista:
            itens = [ListItem(Paragraph(inline(i), ESTILOS['li']), leftIndent=14, value='•') for i in lista]
            historia.append(ListFlowable(itens, bulletType='bullet', start='•', leftIndent=14, bulletColor=VERDE, spaceAfter=8))
            lista.clear()

    for linha in linhas:
        if linha.startswith('# '):
            fechar_paragrafo(); fechar_lista()
            historia.append(Paragraph(inline(linha[2:]), ESTILOS['h1']))
            historia.append(Paragraph(subtitulo, ESTILOS['sub']))
            historia.append(HRFlowable(width='100%', thickness=1, color=VERDE, spaceAfter=10))
        elif linha.startswith('## '):
            fechar_paragrafo(); fechar_lista()
            historia.append(Paragraph(inline(linha[3:]), ESTILOS['h2']))
        elif linha.startswith('- '):
            fechar_paragrafo()
            lista.append(linha[2:])
        elif not linha.strip():
            fechar_paragrafo(); fechar_lista()
        elif lista:
            lista[-1] += ' ' + linha.strip()
        else:
            paragrafo.append(linha.strip())
    fechar_paragrafo(); fechar_lista()

    def rodape(canvas, doc):
        canvas.saveState()
        canvas.setFont(TEXTO, 8.5)
        canvas.setFillColor(CINZA)
        canvas.drawString(2 * cm, 1.2 * cm, 'Conexão Solidária · Hackathon FIAP 11NETT · Grupo 31')
        canvas.drawRightString(A4[0] - 2 * cm, 1.2 * cm, f'Página {doc.page}')
        canvas.restoreState()

    doc = SimpleDocTemplate(destino, pagesize=A4, leftMargin=2.2 * cm, rightMargin=2.2 * cm, topMargin=2 * cm, bottomMargin=2 * cm,
                            title='Bancos de dados: justificativa', author='Grupo 31', subject='Conexão Solidária')
    doc.build(historia, onFirstPage=rodape, onLaterPages=rodape)


if __name__ == '__main__':
    converter(sys.argv[1], sys.argv[2],
              sys.argv[3] if len(sys.argv) > 3 else 'Conexão Solidária (ONG Esperança Solidária) · Hackathon FIAP Pós Tech 11NETT · Grupo 31')
