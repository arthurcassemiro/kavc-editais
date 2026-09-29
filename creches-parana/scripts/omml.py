"""Conversor de uma sintaxe LaTeX reduzida para OMML (Office MathML), para equações nativas e editáveis no Word.
Suporta: \\frac{a}{b}, x_{sub}, x^{sup}, \\sum_{i}, \\bar{x}, \\lfloor x \\rfloor, \\min, \\max, \\text{...}, ( ), [ ], · − × ≤ Σ e texto simples.
Uso: omath_para(expr, numero) devolve um elemento <m:oMathPara> a inserir em um parágrafo."""
from docx.oxml import parse_xml
from xml.sax.saxutils import escape
M='xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
def _run(t,italic=None):
    rpr='<w:rPr><w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/></w:rPr>'
    sty='<m:rPr><m:sty m:val="p"/></m:rPr>' if italic is False else ''
    return f'<m:r>{sty}{rpr}<m:t xml:space="preserve">{escape(t)}</m:t></m:r>'
class P:
    def __init__(s,src): s.src=src; s.i=0
    def peek(s): return s.src[s.i] if s.i<len(s.src) else ''
    def group(s):
        assert s.peek()=='{', f"esperava {{ em {s.src[s.i:s.i+20]}"
        s.i+=1; depth=1; start=s.i
        while s.i<len(s.src):
            c=s.src[s.i]
            if c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0: out=s.src[start:s.i]; s.i+=1; return out
            s.i+=1
        raise ValueError("chave não fechada")
    def parse(s,stop=None):
        out=[]; buf=''
        def flush():
            nonlocal buf
            if buf: out.append(_run(buf)); buf=''
        while s.i<len(s.src):
            c=s.peek()
            if stop and c==stop: break
            if c=='\\':
                flush(); j=s.i+1
                while j<len(s.src) and s.src[j].isalpha(): j+=1
                cmd=s.src[s.i+1:j]; s.i=j
                if cmd=='frac':
                    a=s.group(); b=s.group(); out.append(f'<m:f><m:num>{conv(a)}</m:num><m:den>{conv(b)}</m:den></m:f>')
                elif cmd=='sum':
                    sub=''; sup=''
                    if s.peek()=='_': s.i+=1; sub=s.group() if s.peek()=='{' else s._one()
                    if s.peek()=='^': s.i+=1; sup=s.group() if s.peek()=='{' else s._one()
                    arg=s.group() if s.peek()=='{' else ''
                    out.append(f'<m:nary><m:naryPr><m:chr m:val="∑"/><m:limLoc m:val="undOvr"/></m:naryPr><m:sub>{conv(sub)}</m:sub><m:sup>{conv(sup)}</m:sup><m:e>{conv(arg)}</m:e></m:nary>')
                elif cmd=='bar':
                    a=s.group(); out.append(f'<m:bar><m:barPr><m:pos m:val="top"/></m:barPr><m:e>{conv(a)}</m:e></m:bar>')
                elif cmd=='lfloor':
                    inner=s.parse_until('\\rfloor'); out.append(f'<m:d><m:dPr><m:begChr m:val="⌊"/><m:endChr m:val="⌋"/></m:dPr><m:e>{inner}</m:e></m:d>')
                elif cmd=='text':
                    a=s.group(); out.append(_run(a,italic=False))
                elif cmd in ('min','max','int','rank','mm','se','e'):
                    out.append(_run(cmd,italic=False))
                elif cmd=='cdot': out.append(_run('·'))
                elif cmd=='le': out.append(_run('≤'))
                elif cmd==',': out.append(_run(' '))
                else: out.append(_run('\\'+cmd))
            elif c in '_^':
                s.i+=1
                arg=s.group() if s.peek()=='{' else s._one()
                if buf:
                    import re as _re
                    mm=_re.search(r"[A-Za-z]+$",buf)
                    if mm: rest,last=buf[:mm.start()],mm.group(0)
                    else: rest,last=buf[:-1],buf[-1]
                    buf=''
                    if rest: out.append(_run(rest))
                    base=_run(last)
                else:
                    base=out.pop() if out else _run('')
                tag='sSub' if c=='_' else 'sSup'; part='sub' if c=='_' else 'sup'
                out.append(f'<m:{tag}><m:e>{base}</m:e><m:{part}>{conv(arg)}</m:{part}></m:{tag}>')
            elif c=='(' or c=='[':
                flush(); close=')' if c=='(' else ']'; s.i+=1
                inner=s.parse(stop=close); s.i+=1
                out.append(f'<m:d><m:dPr><m:begChr m:val="{c}"/><m:endChr m:val="{close}"/></m:dPr><m:e>{inner}</m:e></m:d>')
            elif c=='{':
                flush(); a=s.group(); out.append(conv(a))
            else:
                buf+=c; s.i+=1
        flush(); return ''.join(out)
    def _one(s):
        c=s.src[s.i]; s.i+=1; return c
    def parse_until(s,marker):
        j=s.src.find(marker,s.i); inner=s.src[s.i:j]; s.i=j+len(marker); return conv(inner)
def conv(expr): return P(expr).parse()
def omath_inline(expr):
    return parse_xml(f'<m:oMath {M}>{conv(expr)}</m:oMath>')
