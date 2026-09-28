"""Gera o manuscrito DOCX anonimizado a partir de 08_artigo/artigo.md (Arial 12, espaçamento 1,5, A4, margens 2,5 cm, ABNT)."""
import re, pandas as pd
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
SRC="08_artigo/artigo.md"; OUT="08_artigo/artigo_creches_parana_anonimizado.docx"
txt=open(SRC,encoding="utf-8").read()
fm,body=txt.split("---\n",2)[1:]
meta={}
for line in fm.strip().split("\n"):
    k,v=line.split(":",1); meta[k.strip()]=v.strip()
doc=Document()
# página e margens
for s in doc.sections:
    s.page_height=Cm(29.7); s.page_width=Cm(21.0); s.top_margin=s.bottom_margin=s.left_margin=s.right_margin=Cm(2.5)
st=doc.styles["Normal"]; st.font.name="Arial"; st.font.size=Pt(12); st.element.rPr.rFonts.set(qn("w:eastAsia"),"Arial")
pf=st.paragraph_format; pf.line_spacing_rule=WD_LINE_SPACING.ONE_POINT_FIVE; pf.space_after=Pt(0); pf.space_before=Pt(0); pf.alignment=WD_ALIGN_PARAGRAPH.JUSTIFY; pf.first_line_indent=Cm(1.5)
def para(text,align=WD_ALIGN_PARAGRAPH.JUSTIFY,indent=Cm(1.5),size=12,bold=False,italic=False,spacing=1.5,after=0,before=0,left=None):
    p=doc.add_paragraph(); p.alignment=align; p.paragraph_format.first_line_indent=indent
    p.paragraph_format.line_spacing_rule=WD_LINE_SPACING.ONE_POINT_FIVE if spacing==1.5 else WD_LINE_SPACING.SINGLE
    p.paragraph_format.space_after=Pt(after); p.paragraph_format.space_before=Pt(before)
    if left is not None: p.paragraph_format.left_indent=left
    r=p.add_run(text); r.font.size=Pt(size); r.bold=bold; r.italic=italic; r.font.name="Arial"
    return p
def heading(text,level):
    p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.LEFT; p.paragraph_format.first_line_indent=Cm(0)
    p.paragraph_format.space_before=Pt(12 if level==1 else 6); p.paragraph_format.space_after=Pt(6); p.paragraph_format.keep_with_next=True
    p.paragraph_format.line_spacing_rule=WD_LINE_SPACING.ONE_POINT_FIVE
    r=p.add_run(text if level>1 else text.upper()); r.bold=True; r.font.size=Pt(12); r.font.name="Arial"
    if level==2: r.bold=False; r.italic=False; r.bold=True
def set_cell_borders(cell,top=None,bottom=None):
    tcPr=cell._tc.get_or_add_tcPr(); b=OxmlElement("w:tcBorders")
    for edge,val in [("top",top),("bottom",bottom),("left","nil"),("right","nil"),("insideH","nil"),("insideV","nil")]:
        el=OxmlElement(f"w:{edge}"); 
        if val is None or val=="nil": el.set(qn("w:val"),"nil")
        else: el.set(qn("w:val"),"single"); el.set(qn("w:sz"),val); el.set(qn("w:color"),"3A3A3A")
        b.append(el)
    tcPr.append(b)
def fmt(v):
    if isinstance(v,float):
        if v!=v: return ""
        if abs(v-round(v))<1e-9 and abs(v)<1e6: return f"{int(round(v)):,}".replace(",",".")
        return f"{v:,.3f}".rstrip("0").rstrip(".").replace(",","X").replace(".",",").replace("X",".") if abs(v)<1 else f"{v:,.2f}".replace(",","X").replace(".",",").replace("X",".")
    if isinstance(v,int): return f"{v:,}".replace(",",".")
    return str(v)
def table(csv,caption,note):
    df=pd.read_csv(csv)
    p=para(caption,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=11,bold=False,spacing=1,after=4,before=8); p.paragraph_format.keep_with_next=True
    t=doc.add_table(rows=1,cols=len(df.columns)); t.alignment=WD_TABLE_ALIGNMENT.CENTER; t.autofit=False
    n=len(df.columns); w0=Cm(5.0) if n<=7 else Cm(3.6); wr=int((Cm(16.0)-w0)/(n-1)); w0=int(w0)
    tblPr=t._tbl.tblPr
    lay=OxmlElement("w:tblLayout"); lay.set(qn("w:type"),"fixed"); tblPr.append(lay)
    tw=OxmlElement("w:tblW"); tw.set(qn("w:w"),str(int(Cm(16.0).twips if hasattr(Cm(16.0),"twips") else 16.0/2.54*1440))); tw.set(qn("w:type"),"dxa"); 
    for old in tblPr.findall(qn("w:tblW")): tblPr.remove(old)
    tblPr.append(tw)
    for j,col in enumerate(t.columns): col.width=w0 if j==0 else wr
    for j,c in enumerate(df.columns):
        cell=t.rows[0].cells[j]; cell.width=w0 if j==0 else wr; cell.text=""; r=cell.paragraphs[0].add_run(str(c)); r.bold=True; r.font.size=Pt(8); r.font.name="Arial"
        cell.paragraphs[0].alignment=WD_ALIGN_PARAGRAPH.CENTER; cell.paragraphs[0].paragraph_format.line_spacing_rule=WD_LINE_SPACING.SINGLE
        set_cell_borders(cell,top="8",bottom="4")
    for i,row in df.iterrows():
        cells=t.add_row().cells
        for j,v in enumerate(row):
            cells[j].width=w0 if j==0 else wr; cells[j].text=""; r=cells[j].paragraphs[0].add_run(fmt(v)); r.font.size=Pt(8); r.font.name="Arial"
            cells[j].paragraphs[0].alignment=WD_ALIGN_PARAGRAPH.LEFT if j==0 else WD_ALIGN_PARAGRAPH.CENTER
            cells[j].paragraphs[0].paragraph_format.line_spacing_rule=WD_LINE_SPACING.SINGLE
            set_cell_borders(cells[j],bottom="8" if i==len(df)-1 else None)
    para(note,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=6,before=3)
def figure(caption,path,width,fonte="Fonte: Elaboração própria."):
    p=para(caption,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=11,spacing=1,after=3,before=6); p.paragraph_format.keep_with_next=True
    p2=doc.add_paragraph(); p2.alignment=WD_ALIGN_PARAGRAPH.CENTER; p2.paragraph_format.first_line_indent=Cm(0); p2.paragraph_format.space_after=Pt(2)
    import os
    dd,ff=os.path.split(path); alt=os.path.join(dd,"sem_rotulo",ff)
    p2.add_run().add_picture(alt if os.path.exists(alt) else path,width=Cm(width))
    para(fonte,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),size=10,spacing=1,after=6)
# ---- frente ----
for lang in ["pt","en","es"]:
    para(meta[f"titulo_{lang}"],align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),bold=True,after=6)
def bloco_resumo(rot,txt,rotkw,kw):
    para(rot,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),bold=True,spacing=1,after=2,before=8)
    para(txt,align=WD_ALIGN_PARAGRAPH.JUSTIFY,indent=Cm(0),spacing=1,after=4)
    para(f"{rotkw}: {kw}",align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),spacing=1,after=4)
bloco_resumo("RESUMO",meta["resumo_pt"],"Palavras-chave",meta["palavras_pt"])
bloco_resumo("ABSTRACT",meta["resumo_en"],"Keywords",meta["palavras_en"])
bloco_resumo("RESUMEN",meta["resumo_es"],"Palabras clave",meta["palavras_es"])
# ---- corpo ----
in_refs=False
for block in body.strip().split("\n\n"):
    block=block.strip()
    if not block: continue
    if block.startswith("# "):
        h=block[2:].strip(); heading(h,1); in_refs = h.upper().startswith("REFER"); continue
    if block.startswith("## "): heading(block[3:].strip(),2); continue
    m=re.match(r"!\[(.+?)\]\((.+?)\)\{width=(\d+)\}(?:\s*\|\s*(.+))?",block,re.S)
    if m: figure(m.group(1),m.group(2),int(m.group(3)),(m.group(4) or "Fonte: Elaboração própria.").strip()); continue
    if block.startswith("TABLE:"):
        csv,cap,note=[x.strip() for x in block[6:].split("|")]; table(csv,cap,note); continue
    if in_refs:
        p=para(block,align=WD_ALIGN_PARAGRAPH.LEFT,indent=Cm(0),spacing=1,after=5); continue
    para(block)
# anonimização de metadados
cp=doc.core_properties
cp.author=""; cp.last_modified_by=""; cp.title=""; cp.subject=""; cp.comments=""; cp.keywords=""; cp.category=""; cp.company="" if hasattr(cp,"company") else None
doc.save(OUT); print("salvo",OUT)
