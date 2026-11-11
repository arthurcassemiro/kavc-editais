"""Aceita todas as alterações marcadas de um docx descompactado (document, footnotes, endnotes, headers/footers).
Uso: python3.13 -I aceita.py <dir_descompactado>"""
import sys, os, glob
from lxml import etree
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
w = lambda t: '{%s}%s' % (W, t)
d = sys.argv[1]
partes = ['word/document.xml', 'word/footnotes.xml', 'word/endnotes.xml'] + [os.path.relpath(p, d) for p in glob.glob(d + '/word/header*.xml') + glob.glob(d + '/word/footer*.xml')]
REMOVE = ['del', 'moveFrom', 'cellDel']
UNWRAP = ['ins', 'moveTo', 'cellIns']
CHANGE_RECS = ['rPrChange', 'pPrChange', 'sectPrChange', 'tblPrChange', 'trPrChange', 'tcPrChange', 'tblGridChange', 'numberingChange', 'tblPrExChange']
RANGES = ['moveFromRangeStart', 'moveFromRangeEnd', 'moveToRangeStart', 'moveToRangeEnd', 'customXmlInsRangeStart', 'customXmlInsRangeEnd', 'customXmlDelRangeStart', 'customXmlDelRangeEnd']
tot = {}
for p in partes:
    f = os.path.join(d, p)
    if not os.path.exists(f): continue
    tree = etree.parse(f); r = tree.getroot()
    n = 0
    # parágrafos inteiros excluídos: marca de parágrafo excluída (w:pPr/w:rPr/w:del) -> juntar com o seguinte
    for tag in REMOVE:
        for el in list(r.iter(w(tag))):
            par = el.getparent()
            if par is not None and etree.QName(par).localname == 'rPr':
                continue  # tratado abaixo
            par.remove(el); n += 1
    for tag in UNWRAP:
        for el in list(r.iter(w(tag))):
            par = el.getparent()
            if par is not None and etree.QName(par).localname in ('rPr', 'trPr'):
                par.remove(el); n += 1; continue
            i = par.index(el)
            for ch in list(el):
                par.insert(i, ch); i += 1
            par.remove(el); n += 1
    for tag in CHANGE_RECS + RANGES:
        for el in list(r.iter(w(tag))):
            el.getparent().remove(el); n += 1
    # marcas de parágrafo excluídas: rPr/del dentro de pPr -> mesclar o parágrafo com o próximo
    for mark in list(r.iter(w('del'), w('moveFrom'))):
        rpr = mark.getparent()
        ppr = rpr.getparent() if rpr is not None else None
        p_el = ppr.getparent() if ppr is not None else None
        if p_el is None or etree.QName(p_el).localname != 'p': 
            rpr.remove(mark); continue
        rpr.remove(mark)
        nxt = p_el.getnext()
        if nxt is not None and etree.QName(nxt).localname == 'p':
            # a marca de parágrafo que sobrevive é a do seguinte: o parágrafo mesclado fica com as propriedades dele
            novo_ppr = nxt.find(w('pPr'))
            if novo_ppr is not None:
                p_el.replace(ppr, novo_ppr)
            for ch in list(nxt):
                if etree.QName(ch).localname != 'pPr':
                    p_el.append(ch)
            nxt.getparent().remove(nxt)
        n += 1
    tree.write(f, xml_declaration=True, encoding='UTF-8', standalone=True)
    tot[p] = n
    # equações que ficaram vazias depois de aceitar as exclusões
    M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
    for om in list(r.iter('{%s}oMath' % M)):
        if not ''.join(x.text or '' for x in om.iter('{%s}t' % M)).strip():
            par = om.getparent()
            if etree.QName(par).localname == 'oMathPara' and len(par) == 1:
                par.getparent().remove(par)
            else:
                par.remove(om)
    tree.write(f, xml_declaration=True, encoding='UTF-8', standalone=True)
# trackRevisions desligado nas configurações
s = os.path.join(d, 'word/settings.xml')
if os.path.exists(s):
    t = etree.parse(s); r = t.getroot()
    for el in list(r.iter(w('trackRevisions'))): el.getparent().remove(el)
    t.write(s, xml_declaration=True, encoding='UTF-8', standalone=True)
print(tot)
