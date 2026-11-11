"""Lista comentários (autor, texto, trecho ancorado e parágrafo) de um .docx. Uso: python3.13 -I comentarios.py <docx>"""
import sys, zipfile
from lxml import etree
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
w = lambda t: '{%s}%s' % (W, t)
z = zipfile.ZipFile(sys.argv[1])
com = etree.fromstring(z.read('word/comments.xml'))
doc = etree.fromstring(z.read('word/document.xml'))
txt = lambda el: ''.join(t.text or '' for t in el.iter(w('t'), w('delText')) if t.tag == w('t'))
coms = {}
for c in com.findall(w('comment')):
    coms[c.get(w('id'))] = (c.get(w('author')), c.get(w('date')), ' / '.join(txt(p) for p in c.iter(w('p'))))
# trecho ancorado: texto entre commentRangeStart e commentRangeEnd, na ordem do documento
body = doc.find(w('body'))
open_ids, anchored, para_of = set(), {}, {}
for p in body.iter(w('p')):
    ptxt = txt(p)
    for el in p.iter():
        if el.tag == w('commentRangeStart'):
            open_ids.add(el.get(w('id'))); para_of.setdefault(el.get(w('id')), ptxt)
        elif el.tag == w('commentRangeEnd'):
            open_ids.discard(el.get(w('id')))
        elif el.tag == w('commentReference'):
            para_of.setdefault(el.get(w('id')), ptxt)
        elif el.tag == w('t'):
            for i in open_ids:
                anchored[i] = anchored.get(i, '') + (el.text or '')
for i, (a, d, t) in coms.items():
    print(f'### comentário {i} | {a} | {d}')
    print('COMENTÁRIO:', t)
    print('TRECHO:', anchored.get(i, '')[:600])
    print('PARÁGRAFO:', para_of.get(i, '')[:1500])
    print()
