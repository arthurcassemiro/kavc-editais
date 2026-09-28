"""Estilo visual comum (revisão editorial): Arial (Liberation Sans, metricamente equivalente), fundo branco,
sistema de cores com um único sentido por cor, figuras geradas no tamanho final (16 cm), corpo mínimo 7 pt,
vírgula decimal. Cores dos pilares tomadas da apresentação do programa."""
import matplotlib, glob, os, re
from matplotlib import font_manager as fm
import matplotlib.pyplot as plt
for f in glob.glob("/usr/share/fonts/truetype/liberation/LiberationSans-*.ttf"): fm.fontManager.addfont(f)
plt.rcParams.update({"font.family":"Liberation Sans","font.size":8,"svg.fonttype":"none","pdf.fonttype":42,"ps.fonttype":42,
  "figure.facecolor":"white","axes.facecolor":"white","savefig.facecolor":"white","axes.edgecolor":"#3a3a3a","text.color":"#3a3a3a",
  "axes.labelcolor":"#3a3a3a","xtick.color":"#3a3a3a","ytick.color":"#3a3a3a","axes.unicode_minus":False,"hatch.linewidth":0.5})
CM=1/2.54; LARG=16*CM   # largura final das figuras no manuscrito
TINTA="#3a3a3a"; TINTA2="#5f5f5f"; BORDA="#bfbfbf"
# pilares (apresentação do programa)
FE_ESC="#C24C12"; FE_RAMPA=["#FEEAD2","#FDCB9A","#FE9A4E","#EF6812","#C44000"]
FD_ESC="#0171C1"; FD_RAMPA=["#E3EDF7","#BED8EC","#7EB8D8","#3F8FC4","#1464AB"]
FS_ESC="#307E3E"; FS_RAMPA=["#E8F7E4","#C1E6BA","#85CD84","#3FAA5C","#157E3B"]
# PCM (síntese): roxo
PCM_ESC="#54278F"; PCM_RAMPA=["#F2F0F7","#CBC9E2","#9E9AC8","#756BB1","#54278F"]
# etapas em cinzas (ordem = sequência); margem decisória em acento único
CINZAS=["#969696","#595959","#1F1F1F"]; CINZA_CLARO="#D9D9D9"; CINZA_MEDIO="#A6A6A6"
ACENTO="#B2182B"
RAMPA_CINZA=["#F2F2F2","#D9D9D9","#BDBDBD","#969696","#636363","#252525"]
def fmt_br(x,dec=1):
    """Número em formato brasileiro (vírgula decimal, ponto de milhar)."""
    if isinstance(x,str): return x
    s=f"{x:,.{dec}f}"; return s.replace(",","X").replace(".",",").replace("X",".")
SEM_ROTULO=os.environ.get("MAPAS_SEM_ROTULO")=="1"
def _limpar(fig):
    pref=("Mapa ","Figura ","Gráfico ","Fonte:","Quadro ")
    for t in fig.texts:
        if t.get_text().startswith(pref): t.set_text("")
    for ax in fig.axes:
        if ax.get_title(loc="left").startswith(pref): ax.set_title("",loc="left")
        if ax.get_title().startswith(pref): ax.set_title("")
        for t in ax.texts:
            if t.get_text().startswith(pref): t.set_text("")
def salvar(fig,base,dpi=300,jpeg=False):
    if SEM_ROTULO:
        _limpar(fig); d,f=os.path.split(base); base=os.path.join(d,"sem_rotulo",f)
    os.makedirs(os.path.dirname(base),exist_ok=True)
    fig.savefig(base+".svg",bbox_inches="tight"); fig.savefig(base+".pdf",bbox_inches="tight"); fig.savefig(base+".png",dpi=dpi,bbox_inches="tight")
    svg=open(base+".svg",encoding="utf-8").read().replace("Liberation Sans","Arial, Liberation Sans"); open(base+".svg","w",encoding="utf-8").write(svg)
    from PIL import Image, ImageChops
    im=Image.open(base+".png").convert("RGB"); bg=Image.new("RGB",im.size,(255,255,255)); bbox=ImageChops.difference(im,bg).getbbox()
    if bbox: im=im.crop((max(bbox[0]-12,0),max(bbox[1]-12,0),min(bbox[2]+12,im.size[0]),min(bbox[3]+12,im.size[1])))
    if SEM_ROTULO:
        w,h=im.size; f=min(1.0,1900/w); im=im.resize((int(w*f),int(h*f)),Image.LANCZOS)
        im.convert("P",palette=Image.ADAPTIVE,colors=160).save(base+".png",optimize=True)
        if jpeg: im.save(base+".jpg",quality=92,dpi=(300,300))
    else:
        im.save(base+".png",dpi=(dpi,dpi))
