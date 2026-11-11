"""Lista inserções e exclusões marcadas (w:ins/w:del) com contexto do parágrafo. Uso: python3.13 -I marcas.py <docx>"""
import sys, zipfile
from lxml import etree
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
w = lambda t: '{%s}%s' % (W, t)
z = zipfile.ZipFile(sys.argv[1])
for part in ['word/document.xml', 'word/footnotes.xml']:
    doc = etree.fromstring(z.read(part))
    n = 0
    for p in doc.iter(w('p')):
        mods = []
        for el in p.iter(w('ins'), w('del'), w('moveFrom'), w('moveTo')):
            tag = etree.QName(el).localname
            t = ''.join((x.text or '') for x in el.iter(w('t'), w('delText'), w('instrText')))
            if t.strip() or tag in ('ins', 'del'):
                mods.append(f"[{tag}:{el.get(w('author'))}] «{t}»")
        rpr = [etree.QName(x.getparent().getparent()).localname for x in p.iter(w('rPrChange'), w('pPrChange'))]
        if mods or rpr:
            n += 1
            final = ''.join((x.text or '') for x in p.iter(w('t')) if not any(etree.QName(a).localname == 'del' for a in x.iterancestors()))
            print(f'--- {part} #{n}' + (f' (formatação: {len(rpr)})' if rpr else ''))
            for m in mods: print('   ', m[:400])
            print('    FINAL:', final[:700])
