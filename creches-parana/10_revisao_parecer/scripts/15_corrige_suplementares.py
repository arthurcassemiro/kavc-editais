"""Aplica aos arquivos suplementares as mesmas correções de tabelas, figura e legendas feitas no manuscrito.
Uso: python3.13 -I supl.py <dir_origem> <dir_destino>"""
import sys, os, shutil, zipfile
from lxml import etree
import openpyxl
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
w = lambda t: '{%s}%s' % (W, t); m = lambda t: '{%s}%s' % (M, t)
log = []

# (texto da primeira célula da linha, coluna, antigo, novo); a primeira célula muda por último
CELULAS = [
    # Tabela 2, linha PC
    ('Proporção de crianças pequenas (PC)', 1, 'População da faixa etária infantil / população total', 'População de 5 a 14 anos / população total'),
    ('Proporção de crianças pequenas (PC)', 5, '6,1% de 0 a 4 anos (2022)', '13,1% de 5 a 14 anos (2022)'),
    ('Proporção de crianças pequenas (PC)', 6, '6,3% (2022)', '13,5% (2022)'),
    ('Proporção de crianças pequenas (PC)', 7, '6ª menor', '8ª menor'),
    ('Proporção de crianças pequenas (PC)', 0, 'Proporção de crianças pequenas (PC)', 'Proporção de crianças (PC)'),
    # Tabela 6
    ('Porte (habitantes)', 1, 'Mun/', 'Mun.'),
    ('Porte (habitantes)', 2, 'Pop. 0–4 (%)', 'Pop. 5–14 (%)'),
    ('G2 (acima de 1 milhão)', 2, '12,2', '13,5'),
    ('G1 (500 mil a 1 milhão)', 2, '4,3', '4,5'),
    ('M1 (100 a 200 mil)', 2, '17,4', '17,6'),
    ('P4 (70 a 100 mil)', 2, '6,4', '6,1'),
    ('G2 a P4', 1, '399', '30'),
    ('G2 a P4', 2, '100,0', '59,1'),
    ('G2 a P4', 3, '100,9', '101,0'),
    ('G2 a P4', 7, '100 após tetos', '100 (cota fixa)'),
]
TEXTOS = [
    ('3. Tetos por município: 10, 8, 7, 4 e 2 unidades (de 142 para 100)', '3. Cota fixa de 100 unidades, com tetos de 10, 8, 7, 4 e 2 por município'),
    ('03/2024', '05/2024'),
]

def txt(el):
    return ''.join(t.text or '' for t in el.iter(w('t'))).strip()

def fix_doc(root, name):
    n = 0
    for tbl in root.iter(w('tbl')):
        rows = tbl.findall(w('tr'))
        # só tabelas cuja primeira coluna contém a linha-alvo
        for first, col, old, new in CELULAS:
            for tr in rows:
                tcs = tr.findall(w('tc'))
                if not tcs or txt(tcs[0]) != first or col >= len(tcs):
                    continue
                # Tabela 6 x Tabela 4: as linhas G2... existem nas duas; exige cabeçalho da Tabela 6
                if first.startswith(('G2', 'G1', 'M1', 'P4')) and 'Teto por mun.' not in txt(rows[0]):
                    continue
                ts = [t for t in tcs[col].iter(w('t')) if t.text == old]
                if len(ts) == 1:
                    ts[0].text = new; n += 1
    for t in root.iter(w('t')):
        for old, new in TEXTOS:
            if t.text == old:
                t.text = new; n += 1
    for ss in root.iter(m('sSub')):
        e = ''.join(x.text or '' for x in ss.find(m('e')).iter(m('t')))
        sub = [x for x in ss.find(m('sub')).iter(m('t'))]
        if e == 'F' and len(sub) == 1 and sub[0].text == 's':
            sub[0].text = 'S'; n += 1
    return n

for f in sorted(os.listdir(src)):
    p = os.path.join(src, f); q = os.path.join(dst, f)
    if f.endswith('.docx'):
        zin = zipfile.ZipFile(p)
        root = etree.fromstring(zin.read('word/document.xml'))
        n = fix_doc(root, f)
        if n:
            data = etree.tostring(root, xml_declaration=True, encoding='UTF-8', standalone=True)
            with zipfile.ZipFile(q, 'w', zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    zout.writestr(item, data if item.filename == 'word/document.xml' else zin.read(item.filename))
            log.append(f'{f}: {n} correção(ões)')
        else:
            shutil.copy2(p, q)
    elif f.endswith('.xlsx'):
        wb = openpyxl.load_workbook(p)
        t2, t6, t7 = wb['Tabela 2'], wb['Tabela 6'], wb['Tabela 7']
        assert t2['A5'].value == 'Proporção de crianças pequenas (PC)'
        t2['A5'].value = 'Proporção de crianças (PC)'
        t2['B5'].value = 'População de 5 a 14 anos / população total'
        t2['F5'].value = '13,1% de 5 a 14 anos (2022)'; t2['G5'].value = '13,5% (2022)'; t2['H5'].value = '8ª menor'
        assert t6['C3'].value == 'Pop. 0–4 (%)' and t6['A9'].value == 'G2 a P4'
        t6['C3'].value = 'Pop. 5–14 (%)'
        if t6['B3'].value == 'Mun/': t6['B3'].value = 'Mun.'
        assert t6['H9'].value == '100 após tetos'; t6['H9'].value = '100 (cota fixa)'
        if t6['E3'].value is None: t6['E3'].value = 'K'
        for cell, v in [('C4', 13.5), ('C5', 4.5), ('C7', 17.6), ('C8', 6.1), ('B9', 30), ('C9', 59.1), ('D9', 101.0)]:
            t6[cell].value = v
        assert t7['F3'].value == 'Revisão\n03/2024'
        t7['F3'].value = 'Revisão\n05/2024'
        wb.save(q); log.append(f'{f}: Tabelas 2, 6 e 7')
    else:
        shutil.copy2(p, q)
print('\n'.join(log))
