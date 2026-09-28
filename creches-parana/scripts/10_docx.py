"""Gera o manuscrito DOCX anonimizado a partir de 08_artigo/artigo.md.
Normas: A4, margens 2,5 cm, Arial 12, espaçamento 1,5, recuo 1,5 cm; tabelas em Arial 9 com recuo zero,
cabeçalho em dois níveis (células mescladas), cabeçalho repetido, linhas indivisíveis; figuras a 16 cm
presas à sua fonte; nota de rodapé para o material suplementar; metadados sem autoria.
Sintaxe do .md: '# ' e '## ' títulos; parágrafos; '![legenda](caminho){width=16} | Fonte: ... | Nota: ...';
'TABLE: csv | Tabela N. legenda | Fonte: ... | Nota: ...' (cabeçalho em dois níveis quando o nome da coluna tem 'grupo :: coluna');
'QUADRO: csv | Quadro N. legenda | Fonte: ...'; '[^nota]' no texto vira nota de rodapé com o texto definido em linha '[^nota]: texto'."""
import re, os, copy, pandas as pd
from docx import Document
from docx.shared import Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn, nsmap
from docx.oxml import OxmlElement, parse_xml
from docx.opc.constants import RELATIONSHIP_TYPE as RT
from docx.opc.part import Part
from docx.opc.packuri import PackURI
TAB_SIZE=[9]
SRC="08_artigo/artigo.md"; OUT="08_artigo/artigo_creches_parana_anonimizado.docx"
txt=open(SRC,encoding="utf-8").read()
fm,body=txt.split("---\n",2)[1:]
meta={}
for line in fm.strip().split("\n"):
    k,v=line.split(":",1); meta[k.strip()]=v.strip()
# notas de rodapé definidas no .md
notas={m.group(1):m.group(2).strip() for m in re.finditer(r"^\[\^(\w+)\]: (.+)$",body,re.M)}
body=re.sub(r"^\[\^(\w+)\]: .+$\n?","",body,flags=re.M)
doc=Document()
for s in doc.sections:
    s.page_height=Cm(29.7); s.page_width=Cm(21.0); s.top_margin=s.bottom_margin=s.left_margin=s.right_margin=Cm(2.5)
st=doc.styles["Normal"]; st.font.name="Arial"; st.font.size=Pt(12); st.element.rPr.rFonts.set(qn("w:eastAsia"),"Arial")
pf=st.paragraph_format; pf.line_spacing_rule=WD_LINE_SPACING.ONE_POINT_FIVE; pf.space_after=Pt(0); pf.space_before=Pt(0); pf.alignment=WD_ALIGN_PARAGRAPH.JUSTIFY; pf.first_line_indent=Cm(1.5)
# estilo "Tabela"
from docx.enum.style import WD_STYLE_TYPE
tst=doc.styles.add_style("Tabela",WD_STYLE_TYPE.PARAGRAPH); tst.base_style=st; tst.font.name="Arial"; tst.font.size=Pt(9)
tpf=tst.paragraph_format; tpf.line_spacing_rule=WD_LINE_SPACING.SINGLE; tpf.space_after=Pt(0); tpf.space_before=Pt(0); tpf.first_line_indent=Cm(0); tpf.left_indent=Cm(0); tpf.alignment=WD_ALIGN_PARAGRAPH.LEFT
# ---------- notas de rodapé (parte footnotes.xml) ----------
FOOT_XML='<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote><w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote></w:footnotes>'
foot_part=Part(PackURI("/word/footnotes.xml"),"application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",FOOT_XML.encode("utf-8"),doc.part.package)
doc.part.relate_to(foot_part,RT.FOOTNOTES)
foot_el=parse_xml(FOOT_XML); _foot_id=[0]
def add_footnote(paragraph,texto):
    _foot_id[0]+=1; fid=_foot_id[0]
    fn=parse_xml(f'<w:footnote xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" w:id="{fid}"><w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/><w:ind w:firstLine="0"/><w:jc w:val="both"/></w:pPr><w:r><w:rPr><w:vertAlign w:val="superscript"/><w:sz w:val="20"/></w:rPr><w:footnoteRef/></w:r><w:r><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve"> {texto}</w:t></w:r></w:p></w:footnote>')
    foot_el.append(fn)
    r=paragraph.add_run(); rPr=OxmlElement("w:rPr"); va=OxmlElement("w:vertAlign"); va.set(qn("w:val"),"superscript"); rPr.append(va); r._r.append(rPr)
    ref=OxmlElement("w:footnoteReference"); ref.set(qn("w:id"),str(fid)); r._r.append(ref)
def add_text_with_notes(p,text,size=12,bold=False,italic=False):
    parts=re.split(r"(\[\^\w+\])",text)
    for part in parts:
        m=re.fullmatch(r"\[\^(\w+)\]",part)
        if m: add_footnote(p,notas[m.group(1)])
        elif part:
            r=p.add_run(part); r.font.size=Pt(size); r.bold=bold; r.italic=italic; r.font.name="Arial"
def para(text,align=WD_ALIGN_PARAGRAPH.JUSTIFY,indent=Cm(1.5),size=12,bold=False,italic=False,spacing=1.5,after=0,before=0,keep=False):
    p=doc.add_paragraph(); p.alignment=align; p.paragraph_format.first_line_indent=indent
    p.paragraph_format.line_spacing_rule=WD_LINE_SPACING.ONE_POINT_FIVE if spacing==1.5 else WD_LINE_SPACING.SINGLE
    p.paragraph_format.space_after=Pt(after); p.paragraph_format.space_before=Pt(before); p.paragraph_format.keep_with_next=keep
    add_text_with_notes(p,text,size,bold,italic); return p
def heading(text,level):
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.LEFT; p.paragraph_format.first_line_indent=Cm(0)
    p.paragraph_format.space_before=Pt(12 if level==1 else 6); p.paragraph_format.space_after=Pt(6); p.paragraph_format.keep_with_next=True
    p.paragraph_format.line_spacing_rule=WD_LINE_SPACING.ONE_POINT_FIVE
    r=p.add_run(text if level>1 else text.upper()); r.bold=True; r.font.size=Pt(12); r.font.name="Arial"
def borders(cell,top=None,bottom=None):
    tcPr=cell._tc.get_or_add_tcPr(); b=OxmlElement("w:tcBorders")
    for edge,val in [("top",top),("bottom",bottom),("left",None),("right",None)]:
        el=OxmlElement(f"w:{edge}")
        if val is None: el.set(qn("w:val"),"nil")
        else: el.set(qn("w:val"),"single"); el.set(qn("w:sz"),val); el.set(qn("w:color"),"3A3A3A")
        b.append(el)
    tcPr.append(b)
def cell_text(cell,text,bold=False,align=WD_ALIGN_PARAGRAPH.LEFT,size=9):
    size=min(size,TAB_SIZE[0]); size=min(size,8) if bold else size
    cell.text=""; p=cell.paragraphs[0]; p.style=doc.styles["Tabela"]; p.alignment=align
    p.paragraph_format.first_line_indent=Cm(0); p.paragraph_format.left_indent=Cm(0); p.paragraph_format.keep_with_next=True
    r=p.add_run(text); r.bold=bold; r.font.size=Pt(size); r.font.name="Arial"
    tcPr=cell._tc.get_or_add_tcPr(); mar=OxmlElement("w:tcMar")
    for side in ("left","right"):
        m=OxmlElement(f"w:{side}"); m.set(qn("w:w"),"40"); m.set(qn("w:type"),"dxa"); mar.append(m)
    tcPr.append(mar); vA=OxmlElement("w:vAlign"); vA.set(qn("w:val"),"center"); tcPr.append(vA)
def row_props(row,header=False):
    trPr=row._tr.get_or_add_trPr(); trPr.append(OxmlElement("w:cantSplit"))
    if header: trPr.append(OxmlElement("w:tblHeader"))
def fmt_cell(v,dec):
    if isinstance(v,str): return v
    if v!=v: return ""
    if dec is None:
        dec=0 if float(v).is_integer() else 1
    s=f"{v:,.{dec}f}"; return s.replace(",","X").replace(".",",").replace("X",".")
def table(csv,caption,fonte,nota=None,decs=None,wide_first=None):
    df=pd.read_csv(csv); TAB_SIZE[0]=8 if len(df.columns)>10 else 9
    cols=list(df.columns); groups=[(c.split(" :: ")[0] if " :: " in c else None, c.split(" :: ")[-1]) for c in cols]
    two=any(g for g,_ in groups)
    para(caption,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=11,spacing=1,after=3,before=8,keep=True)
    n=len(cols); nhead=2 if two else 1
    t=doc.add_table(rows=nhead,cols=n); t.alignment=WD_TABLE_ALIGNMENT.CENTER; t.autofit=False
    tblPr=t._tbl.tblPr; lay=OxmlElement("w:tblLayout"); lay.set(qn("w:type"),"fixed"); tblPr.append(lay)
    for old in tblPr.findall(qn("w:tblW")): tblPr.remove(old)
    tw=OxmlElement("w:tblW"); tw.set(qn("w:w"),str(int(16.0/2.54*1440))); tw.set(qn("w:type"),"dxa"); tblPr.append(tw)
    w0=Cm(wide_first if wide_first else (4.4 if n<=6 else (3.3 if n>10 else 3.8))); wr=int((Cm(16.0)-w0)/(n-1)); w0=int(w0)
    for j,col in enumerate(t.columns): col.width=w0 if j==0 else wr
    # cabeçalho
    if two:
        r0=t.rows[0].cells; r1=t.rows[1].cells; j=0
        while j<n:
            g,c=groups[j]
            if g is None:
                a=r0[j].merge(r1[j]); cell_text(a,c,bold=True,align=WD_ALIGN_PARAGRAPH.CENTER if j else WD_ALIGN_PARAGRAPH.LEFT); borders(a,top="8",bottom="4"); j+=1
            else:
                k=j
                while k<n and groups[k][0]==g: k+=1
                a=r0[j] if k==j+1 else r0[j].merge(r0[k-1]); cell_text(a,g,bold=True,align=WD_ALIGN_PARAGRAPH.CENTER); borders(a,top="8",bottom="4")
                for m in range(j,k): cell_text(r1[m],groups[m][1],bold=True,align=WD_ALIGN_PARAGRAPH.CENTER); borders(r1[m],bottom="4")
                j=k
        row_props(t.rows[0],True); row_props(t.rows[1],True)
    else:
        for j,c in enumerate(cols):
            cell_text(t.rows[0].cells[j],c,bold=True,align=WD_ALIGN_PARAGRAPH.CENTER if j else WD_ALIGN_PARAGRAPH.LEFT); borders(t.rows[0].cells[j],top="8",bottom="4")
        row_props(t.rows[0],True)
    last=len(df)-1
    for i,row in df.iterrows():
        cells=t.add_row().cells; row_props(t.rows[-1])
        total=str(row.iloc[0]).strip().lower() in ("paraná","total")
        for j,v in enumerate(row):
            d=None if decs is None else decs[j]
            cell_text(cells[j],fmt_cell(v,d),bold=False,align=WD_ALIGN_PARAGRAPH.LEFT if j==0 else WD_ALIGN_PARAGRAPH.RIGHT)
            borders(cells[j],top="4" if total else None,bottom="8" if i==last else None)
    for c in t.rows[-1].cells:
        for p in c.paragraphs: p.paragraph_format.keep_with_next=True
    para("Fonte: "+fonte,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=0 if nota else 6,before=3)
    if nota: para("Nota: "+nota,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=6)
def quadro(csv,caption,fonte,nota=None):
    df=pd.read_csv(csv); n=len(df.columns); TAB_SIZE[0]=9
    para(caption,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=11,spacing=1,after=3,before=8,keep=True)
    t=doc.add_table(rows=1,cols=n); t.alignment=WD_TABLE_ALIGNMENT.CENTER; t.autofit=False
    tblPr=t._tbl.tblPr; lay=OxmlElement("w:tblLayout"); lay.set(qn("w:type"),"fixed"); tblPr.append(lay)
    for old in tblPr.findall(qn("w:tblW")): tblPr.remove(old)
    tw=OxmlElement("w:tblW"); tw.set(qn("w:w"),str(int(16.0/2.54*1440))); tw.set(qn("w:type"),"dxa"); tblPr.append(tw)
    widths=[Cm(3.0),Cm(2.6),Cm(4.0),Cm(6.4)] if n==4 else [int(Cm(16.0)/n)]*n
    for j,col in enumerate(t.columns): col.width=int(widths[j])
    for j,c in enumerate(df.columns): cell_text(t.rows[0].cells[j],c,bold=True,align=WD_ALIGN_PARAGRAPH.LEFT); borders(t.rows[0].cells[j],top="8",bottom="4")
    row_props(t.rows[0],True)
    for i,row in df.iterrows():
        cells=t.add_row().cells; row_props(t.rows[-1])
        for j,v in enumerate(row): cell_text(cells[j],str(v),align=WD_ALIGN_PARAGRAPH.LEFT,size=8.5); borders(cells[j],bottom="8" if i==len(df)-1 else "2")
    for c in t.rows[-1].cells:
        for p in c.paragraphs: p.paragraph_format.keep_with_next=True
    para("Fonte: "+fonte,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=0 if nota else 6,before=3)
    if nota: para("Nota: "+nota,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=6)
def figure(caption,path,width,fonte,nota=None):
    para(caption,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=11,spacing=1,after=3,before=8,keep=True)
    dd,ff=os.path.split(path); alt=os.path.join(dd,"sem_rotulo",ff)
    p2=doc.add_paragraph(); p2.alignment=WD_ALIGN_PARAGRAPH.CENTER; p2.paragraph_format.first_line_indent=Cm(0); p2.paragraph_format.space_after=Pt(2); p2.paragraph_format.keep_with_next=True
    p2.add_run().add_picture(alt if os.path.exists(alt) else path,width=Cm(width))
    para("Fonte: "+fonte,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=0 if nota else 6)
    if nota: para("Nota: "+nota,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=6)
# ---------- frente ----------
for lang in ["pt","en","es"]: para(meta[f"titulo_{lang}"],align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),bold=True,after=6)
def bloco(rot,texto,rotkw,kw):
    para(rot,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),bold=True,spacing=1,after=2,before=8)
    para(texto,align=WD_ALIGN_PARAGRAPH.JUSTIFY,indent=Cm(0),spacing=1,after=4)
    para(f"{rotkw}: {kw}",align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),spacing=1,after=4)
bloco("RESUMO",meta["resumo_pt"],"Palavras-chave",meta["palavras_pt"]); bloco("ABSTRACT",meta["resumo_en"],"Keywords",meta["palavras_en"]); bloco("RESUMEN",meta["resumo_es"],"Palabras clave",meta["palavras_es"])
# ---------- corpo ----------
DECS={"tab1_porte_ms.csv":[None,0,1,3,0,0,0,0,0,0,None,None,None,None],"tab3_beneficiados.csv":None,"tab5_cenarios_ms.csv":[None,0,1,0,1,1,1,1,1],"tab6_regional_ms.csv":[None,0,3,1,0,1,1,1]}
in_refs=False
for block in body.strip().split("\n\n"):
    block=block.strip()
    if not block: continue
    if block.startswith("# "):
        h=block[2:].strip(); heading(h,1); in_refs=h.upper().startswith("REFER"); continue
    if block.startswith("## "): heading(block[3:].strip(),2); continue
    m=re.match(r"!\[(.+?)\]\((.+?)\)\{width=(\d+)\}\s*\|\s*Fonte:\s*(.+?)(?:\s*\|\s*Nota:\s*(.+))?$",block,re.S)
    if m: figure(m.group(1),m.group(2),int(m.group(3)),m.group(4).strip(),(m.group(5) or "").strip() or None); continue
    if block.startswith("TABLE:") or block.startswith("QUADRO:"):
        kind=block.split(":")[0]; parts=[x.strip() for x in block.split(":",1)[1].split("|")]
        csv,cap=parts[0],parts[1]; fonte=parts[2].replace("Fonte:","").strip(); nota=parts[3].replace("Nota:","").strip() if len(parts)>3 else None
        if kind=="TABLE": table(csv,cap,fonte,nota,decs=DECS.get(os.path.basename(csv)))
        else: quadro(csv,cap,fonte,nota)
        continue
    if in_refs: para(block,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),spacing=1,after=4); continue
    para(block)
# gravar notas de rodapé
foot_part._blob=foot_el.xml.encode("utf-8") if hasattr(foot_el,"xml") else None
from lxml import etree
foot_part._blob=etree.tostring(foot_el,xml_declaration=True,encoding="UTF-8",standalone=True)
cp=doc.core_properties
for a in ("author","last_modified_by","title","subject","comments","keywords","category"): setattr(cp,a,"")
doc.save(OUT); print("salvo",OUT,"notas:",_foot_id[0])
