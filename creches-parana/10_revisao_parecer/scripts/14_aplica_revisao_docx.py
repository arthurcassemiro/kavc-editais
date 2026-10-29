"""Aplica as alterações da revisão (parecer RPD) ao document.xml e ao footnotes.xml de um .docx descompactado.
Uso: python3.13 -I aplica.py <dir_descompactado> <spec.json>
Marcação dos textos: **negrito**, ⟦F_E⟧ ou ⟦PCM⟧ (OMML inline), [^7] (chamada de nota).
Os índices de elemento referem-se aos filhos de w:body do arquivo de entrada (mesma numeração de texto.txt)."""
import sys, json, re, copy, random
from lxml import etree

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
W14 = 'http://schemas.microsoft.com/office/word/2010/wordml'
w = lambda t: '{%s}%s' % (W, t)
m = lambda t: '{%s}%s' % (M, t)

root_dir, spec_path = sys.argv[1], sys.argv[2]
DESTACAR = '--destacar' in sys.argv[3:]
spec = json.load(open(spec_path, encoding='utf8'))
doc_path = root_dir + '/word/document.xml'
fn_path = root_dir + '/word/footnotes.xml'
doc = etree.parse(doc_path)
body = doc.getroot().find(w('body'))
kids = list(body)
used_ids = set(doc.getroot().xpath('//@w14:paraId', namespaces={'w14': W14}))
rnd = random.Random(20261029)

def new_para_id():
    while True:
        v = '%08X' % rnd.randint(0x10000000, 0x7FFFFFFF)
        if v not in used_ids:
            used_ids.add(v)
            return v

def lang_rpr(bold=False):
    rpr = etree.Element(w('rPr'))
    if bold:
        etree.SubElement(rpr, w('b')); etree.SubElement(rpr, w('bCs'))
    if DESTACAR:
        h = etree.SubElement(rpr, w('highlight')); h.set(w('val'), 'yellow')
    l = etree.SubElement(rpr, w('lang')); l.set(w('val'), 'pt-BR')
    return rpr

def add_highlight(r):
    rpr = r.find(w('rPr'))
    if rpr is None:
        rpr = etree.Element(w('rPr')); r.insert(0, rpr)
    if rpr.find(w('highlight')) is None:
        h = etree.Element(w('highlight')); h.set(w('val'), 'yellow')
        # ordem do esquema: highlight vem antes de u, effect, bdr, shd, fitText, vertAlign, rtl, cs, em, lang...
        later = [w(x) for x in ('u','effect','bdr','shd','fitText','vertAlign','rtl','cs','em','lang','eastAsianLayout','specVanish','oMath')]
        pos = len(rpr)
        for i, c in enumerate(rpr):
            if c.tag in later:
                pos = i; break
        rpr.insert(pos, h)

def text_run(txt, bold=False):
    r = etree.Element(w('r'))
    r.append(lang_rpr(bold))
    t = etree.SubElement(r, w('t')); t.text = txt
    t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    return r

def math_rpr():
    rpr = etree.Element(w('rPr'))
    f = etree.SubElement(rpr, w('rFonts')); f.set(w('ascii'), 'Cambria Math'); f.set(w('hAnsi'), 'Cambria Math')
    return rpr

def m_run(txt):
    r = etree.Element(m('r')); r.append(math_rpr())
    t = etree.SubElement(r, m('t')); t.text = txt
    return r

def omath(expr):
    om = etree.Element(m('oMath'))
    if '_' in expr:
        base, sub = expr.split('_', 1)
        ss = etree.SubElement(om, m('sSub'))
        pr = etree.SubElement(ss, m('sSubPr')); cp = etree.SubElement(pr, m('ctrlPr')); cp.append(math_rpr())
        e = etree.SubElement(ss, m('e')); e.append(m_run(base))
        s = etree.SubElement(ss, m('sub')); s.append(m_run(sub))
    else:
        om.append(m_run(expr))
    return om

def fn_ref_run(fid):
    r = etree.Element(w('r'))
    rpr = etree.SubElement(r, w('rPr'))
    st = etree.SubElement(rpr, w('rStyle')); st.set(w('val'), 'FootnoteReference')
    l = etree.SubElement(rpr, w('lang')); l.set(w('val'), 'pt-BR')
    fr = etree.SubElement(r, w('footnoteReference')); fr.set(w('id'), str(fid))
    return r

TOK = re.compile(r'(\*\*.+?\*\*|⟦[^⟧]+⟧|\[\^\d+\])')

def build_runs(markup):
    out = []
    for part in TOK.split(markup):
        if not part:
            continue
        if part.startswith('**') and part.endswith('**'):
            out.append(text_run(part[2:-2], bold=True))
        elif part.startswith('⟦'):
            out.append(omath(part[1:-1]))
        elif part.startswith('[^'):
            out.append(fn_ref_run(int(part[2:-1])))
        else:
            out.append(text_run(part))
    return out

def clear_content(p):
    for c in list(p):
        if c.tag != w('pPr'):
            p.remove(c)

def para_like(template, markup):
    p = etree.Element(w('p'))
    p.set('{%s}paraId' % W14, new_para_id())
    p.set('{%s}textId' % W14, '77777777')
    ppr = template.find(w('pPr'))
    if ppr is not None:
        p.append(copy.deepcopy(ppr))
    for r in build_runs(markup):
        p.append(r)
    return p

def ptext(p):
    return ''.join(t.text or '' for t in p.iter(w('t')))

log = []
# 1. substituições pontuais de texto dentro de um elemento (em um único w:t)
for s in spec.get('text_subs', []):
    el = kids[s['el']]
    done = False
    for t in el.iter(w('t')):
        if t.text and s['old'] in t.text:
            if not DESTACAR:
                t.text = t.text.replace(s['old'], s['new'], 1); done = True; break
            r = t.getparent(); a, b = t.text.split(s['old'], 1)
            t.text = a; t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
            rn = copy.deepcopy(r); rn.find(w('t')).text = s['new']; add_highlight(rn)
            rb = copy.deepcopy(r); rb.find(w('t')).text = b
            r.addnext(rn); rn.addnext(rb)
            if not a: r.getparent().remove(r)
            done = True; break
    assert done, f"texto não encontrado no elemento {s['el']}: {s['old']}"
    log.append(f"sub {s['el']}: {s['old']!r} -> {s['new']!r}")
# 1b. substituições em células de tabela: linha identificada pelo texto da primeira célula
for s in spec.get('cell_subs', []):
    tbl = kids[s['el']]
    row = None
    for tr in tbl.findall(w('tr')):
        c0 = tr.findall(w('tc'))[0]
        if ''.join(t.text or '' for t in c0.iter(w('t'))).strip() == s['row_first']:
            row = tr; break
    assert row is not None, s
    cell = row.findall(w('tc'))[s['col']]
    ts = [t for t in cell.iter(w('t')) if t.text == s['old']]
    assert len(ts) == 1, (s, [t.text for t in cell.iter(w('t'))])
    ts[0].text = s['new']
    if DESTACAR:
        add_highlight(ts[0].getparent())
    log.append(f"cell {s['el']} [{s['row_first']}][{s['col']}]: {s['old']!r} -> {s['new']!r}")
# 1c. substituições de texto em notas de rodapé existentes
fn_subs = spec.get('footnote_subs', [])
# 2. substituições em OMML (m:t)
for s in spec.get('math_subs', []):
    el = kids[s['el']]
    hits = [t for t in el.iter(m('t')) if t.text == s['old']]
    assert hits, f"m:t {s['old']!r} não encontrado em {s['el']}"
    for t in hits:
        t.text = s['new']
        if DESTACAR:
            add_highlight(t.getparent())
    log.append(f"math {s['el']}: {s['old']!r} -> {s['new']!r} ({len(hits)}x)")
# 3. substituição de parágrafos (o primeiro texto ocupa o elemento; os demais entram depois, com o mesmo pPr)
for k, paras in spec.get('replace', {}).items():
    el = kids[int(k)]
    assert el.tag == w('p'), k
    before = ptext(el)[:60]
    clear_content(el)
    for r in build_runs(paras[0]):
        el.append(r)
    anchor = el
    for extra in paras[1:]:
        np_ = para_like(el, extra)
        anchor.addnext(np_); anchor = np_
    log.append(f"replace {k} ({before!r}...) -> {len(paras)} parágrafo(s)")
# 4. inserção de novos parágrafos após um elemento, com pPr copiado de outro elemento
for k, items in spec.get('insert_after', {}).items():
    anchor = kids[int(k)]
    for it in items:
        np_ = para_like(kids[int(it['ppr_from'])], it['text'])
        anchor.addnext(np_); anchor = np_
    log.append(f"insert_after {k}: {len(items)} parágrafo(s)")
# 5. inserção de referências antes de um elemento (cópia do formato da referência de destino)
for k, refs in spec.get('ref_insert_before', {}).items():
    tgt = kids[int(k)]
    for ref in refs:
        p = copy.deepcopy(tgt)
        p.set('{%s}paraId' % W14, new_para_id())
        runs = p.findall(w('r'))
        for r in runs[1:]:
            p.remove(r)
        runs[0].find(w('t')).text = ref
        runs[0].find(w('t')).set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
        if DESTACAR:
            add_highlight(runs[0])
        tgt.addprevious(p)
    log.append(f"ref_insert_before {k}: {len(refs)}")
# 6. remoções
for k in spec.get('remove', []):
    el = kids[int(k)]
    log.append(f"remove {k} ({ptext(el)[:50]!r})")
    body.remove(el)
doc.write(doc_path, xml_declaration=True, encoding='UTF-8', standalone=True)

# 7. notas de rodapé: substituições e notas novas (modelo: a última nota existente)
fn_repl = spec.get('footnote_replace', {})
if spec.get('footnotes') or fn_subs or fn_repl:
    fn = etree.parse(fn_path)
    froot = fn.getroot()
    for s in fn_subs:
        note = [n for n in froot.findall(w('footnote')) if n.get(w('id')) == str(s['id'])][0]
        done = False
        for t in note.iter(w('t')):
            if t.text and s['old'] in t.text:
                if not DESTACAR:
                    t.text = t.text.replace(s['old'], s['new'], 1)
                else:
                    r = t.getparent(); a, b = t.text.split(s['old'], 1)
                    t.text = a; t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
                    rn = copy.deepcopy(r); rn.find(w('t')).text = s['new']; add_highlight(rn)
                    rb = copy.deepcopy(r); rb.find(w('t')).text = b
                    r.addnext(rn); rn.addnext(rb)
                    if not a: r.getparent().remove(r)
                done = True; break
        assert done, s
        log.append(f"footnote_sub {s['id']}: {s['old']!r} -> {s['new']!r}")
    notes = froot.findall(w('footnote'))
    model = [n for n in notes if int(n.get(w('id'))) > 0][-1]
    for fid, markup in fn_repl.items():
        note = [n for n in froot.findall(w('footnote')) if n.get(w('id')) == str(fid)][0]
        p = note.find(w('p'))
        for c in list(p):
            if c.tag == w('r') and c.find(w('footnoteRef')) is None:
                p.remove(c)
        for r in build_runs(markup):
            p.append(r)
        log.append(f"footnote_replace {fid}: {markup[:60]!r}")
    for fid, markup in spec.get('footnotes', {}).items():
        nn = copy.deepcopy(model)
        nn.set(w('id'), str(fid))
        p = nn.find(w('p'))
        p.set('{%s}paraId' % W14, new_para_id())
        for c in list(p):
            if c.tag == w('r') and c.find(w('footnoteRef')) is None:
                p.remove(c)
        for r in build_runs(markup):
            p.append(r)
        froot.append(nn)
        log.append(f"footnote {fid}: {markup[:60]!r}")
    fn.write(fn_path, xml_declaration=True, encoding='UTF-8', standalone=True)
print('\n'.join(log))
