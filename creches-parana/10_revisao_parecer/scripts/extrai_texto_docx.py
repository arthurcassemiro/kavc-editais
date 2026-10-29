import sys, re
from docx import Document
from docx.text.paragraph import Paragraph
from docx.table import Table
from docx.oxml.ns import qn
M="{http://schemas.openxmlformats.org/officeDocument/2006/math}"
def ptext(el):
    # texto do parágrafo incluindo texto de equações inline (entre ⟦ ⟧) e marcadores de nota [^n]
    out=[]
    for node in el.iter():
        tag=node.tag
        if tag==qn("w:t") and not any(a.tag==M+"oMath" for a in node.iterancestors()):
            out.append(node.text or "")
        elif tag==M+"oMath":
            txt="".join(t.text or "" for t in node.iter(M+"t"))
            out.append("⟦"+txt+"⟧")
        elif tag==qn("w:footnoteReference"):
            out.append("[^"+node.get(qn("w:id"))+"]")
        elif tag==qn("w:tab") and not any(a.tag==M+"oMath" for a in node.iterancestors()):
            out.append("\t")
    return "".join(out)
d=Document(sys.argv[1])
body=d.element.body
lines=[]
for i,el in enumerate(body.iterchildren()):
    tag=el.tag.split('}')[1]
    if tag=="p":
        p=Paragraph(el,d)
        sty=p.style.name if p.style is not None else ""
        img="[IMG] " if el.findall('.//{http://schemas.openxmlformats.org/drawingml/2006/main}blip') else ""
        num=" [NUM]" if el.find('.//'+qn('w:numPr')) is not None else ""
        lines.append(f"{i:03d} P[{sty}{num}] {img}{ptext(el)}")
    elif tag=="tbl":
        t=Table(el,d)
        rows=[" | ".join(c.text.strip().replace("\n"," / ") for c in r.cells) for r in t.rows]
        lines.append(f"{i:03d} TBL {len(t.rows)}x{len(t.columns)}\n      "+"\n      ".join(rows))
    else:
        lines.append(f"{i:03d} {tag}")
open(sys.argv[2],"w").write("\n".join(lines))
# notas de rodapé
import zipfile
z=zipfile.ZipFile(sys.argv[1])
from lxml import etree
fx=etree.fromstring(z.read("word/footnotes.xml"))
W="{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
notes=[]
for fn in fx.findall(W+"footnote"):
    fid=fn.get(W+"id")
    t="".join(ptext(p) for p in fn.findall(".//"+W+"p"))
    notes.append(f"[^{fid}] {t.strip()}")
open(sys.argv[3],"w").write("\n".join(notes))
print(len(lines),"elementos;",len(notes),"notas")
