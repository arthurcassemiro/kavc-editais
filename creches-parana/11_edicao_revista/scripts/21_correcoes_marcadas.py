"""Aplica correções dos autores como alterações marcadas (autor e data fixos) num docx descompactado.
Uso: python3.13 -I marca.py <dir> <ops.json>
ops: {"subs": [{"part","contexto","old","new"}], "inserir_apos": [{"titulo","texto","modelo"}]}"""
import sys, json, copy
from lxml import etree
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
w = lambda t: '{%s}%s' % (W, t)
AUTOR, DATA = 'Arthur Cassemiro Bispo', '2026-11-11T12:00:00Z'
d, ops = sys.argv[1], json.load(open(sys.argv[2], encoding='utf8'))
nid = [910000]
def novo_id():
    nid[0] += 1; return str(nid[0])
def marca(tag):
    el = etree.Element(w(tag)); el.set(w('id'), novo_id()); el.set(w('author'), AUTOR); el.set(w('date'), DATA); return el
def ptexto(p):
    return ''.join(t.text or '' for t in p.iter(w('t')))
def runs_texto(p):
    # runs com texto, na ordem, ignorando os que estão dentro de equações
    out = []
    for r in p.iter(w('r')):
        if any(etree.QName(a).localname == 'oMath' for a in r.iterancestors()): continue
        ts = r.findall(w('t'))
        if ts: out.append(r)
    return out
def dividir(r, pos):
    """Divide o run r (com um único w:t) na posição pos; devolve (esq, dir)."""
    t = r.find(w('t')); s = t.text or ''
    r2 = copy.deepcopy(r)
    t.text = s[:pos]; t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    t2 = r2.find(w('t')); t2.text = s[pos:]; t2.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    r.addnext(r2); return r, r2
def subst(p, old, new, tirar_destaque=False):
    rs = runs_texto(p)
    txt = ''.join(''.join(t.text or '' for t in r.findall(w('t'))) for r in rs)
    i = txt.find(old)
    assert i >= 0 and txt.count(old) == 1, (old, txt[:200])
    j = i + len(old)
    # localizar runs e dividir nas fronteiras
    pos = 0; alvo = []
    for r in rs:
        ts = r.findall(w('t'))
        if len(ts) > 1:  # juntar w:t do run
            ts[0].text = ''.join(t.text or '' for t in ts); [r.remove(t) for t in ts[1:]]
        s = r.find(w('t')).text or ''
        a, b = pos, pos + len(s); pos = b
        if b <= i or a >= j: continue
        if a < i:
            _, r = dividir(r, i - a); a = i; s = r.find(w('t')).text
        if b > j:
            r, _ = dividir(r, j - a)
        alvo.append(r)
    rpr = alvo[0].find(w('rPr'))
    de = marca('del'); alvo[0].addprevious(de)
    for r in alvo:
        de.append(r)
        t = r.find(w('t')); t.tag = w('delText')
    if new:
        ins = marca('ins'); de.addnext(ins)
        nr = etree.SubElement(ins, w('r'))
        if rpr is not None:
            rp = copy.deepcopy(rpr)
            if tirar_destaque:
                for h in rp.findall(w('highlight')): rp.remove(h)
            nr.append(rp)
        nt = etree.SubElement(nr, w('t')); nt.text = new; nt.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
partes = {}
def parte(nome):
    if nome not in partes:
        partes[nome] = etree.parse(f'{d}/{nome}')
    return partes[nome]
for op in ops.get('subs', []):
    r = parte(op['part']).getroot()
    cands = [p for p in r.iter(w('p')) if op['contexto'] in ptexto(p) and op['old'] in ptexto(p)]
    assert len(cands) == 1, (op['contexto'], len(cands))
    subst(cands[0], op['old'], op['new'], op.get('tirar_destaque', False))
    print('ok subst:', op['old'][:50], '->', op['new'][:50])
for op in ops.get('inserir_apos', []):
    r = parte('word/document.xml').getroot()
    ps = list(r.iter(w('p')))
    tit = [p for p in ps if ptexto(p).strip() == op['titulo']]
    assert len(tit) == 1, op['titulo']
    modelo = [p for p in ps if ptexto(p).startswith(op['modelo'])]
    assert len(modelo) == 1, op['modelo']
    np_ = etree.Element(w('p'))
    ppr = copy.deepcopy(modelo[0].find(w('pPr'))) if modelo[0].find(w('pPr')) is not None else etree.Element(w('pPr'))
    rpr_p = ppr.find(w('rPr'))
    if rpr_p is None: rpr_p = etree.SubElement(ppr, w('rPr'))
    rpr_p.insert(0, marca('ins'))
    np_.append(ppr)
    mr = None
    for rr in modelo[0].iter(w('r')):
        if rr.find(w('t')) is not None: mr = rr; break
    ins = marca('ins'); np_.append(ins)
    nr = etree.SubElement(ins, w('r'))
    if mr is not None and mr.find(w('rPr')) is not None: nr.append(copy.deepcopy(mr.find(w('rPr'))))
    nt = etree.SubElement(nr, w('t')); nt.text = op['texto']
    tit[0].addnext(np_)
    print('ok inserir após:', op['titulo'][:50])
for nome, t in partes.items():
    t.write(f'{d}/{nome}', xml_declaration=True, encoding='UTF-8', standalone=True)
