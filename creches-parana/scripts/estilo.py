"""Estilo visual comum: IBM Plex Sans, fundo branco, grafite, azul-petróleo, verde; laranja só para ajustes."""
import matplotlib, glob, os
from matplotlib import font_manager as fm
import matplotlib.pyplot as plt
FONTDIR="/tmp/claude-0/-home-user-kavc-editais/98e3c548-b4ab-5729-ad4a-337524077c70/scratchpad/fonts/ibm-plex-sans/fonts/complete/ttf"
for f in glob.glob(FONTDIR+"/*.ttf"): fm.fontManager.addfont(f)
plt.rcParams.update({"font.family":"IBM Plex Sans","font.size":8,"svg.fonttype":"none","pdf.fonttype":42,"ps.fonttype":42,
  "figure.facecolor":"white","axes.facecolor":"white","savefig.facecolor":"white","axes.edgecolor":"#3a3a3a","text.color":"#3a3a3a","axes.labelcolor":"#3a3a3a","xtick.color":"#3a3a3a","ytick.color":"#3a3a3a"})
GRAFITE="#3a3a3a"; GRAFITE_CLARO="#8a8a8a"; PETROLEO="#1f5c6a"; VERDE="#1b6b52"; VERDE_CLARO="#6db27a"; LARANJA="#e8862a"; LARANJA_ESC="#b85c0a"; LARANJA_CLARO="#f6c48f"
RAMP_PETROLEO=["#eaf1f3","#bfd6db","#8db6bf","#568c99","#1f5c6a"]
RAMP_VERDE=["#e8f1eb","#bcdac8","#86bd9c","#4c976f","#1b6b52"]
RAMP_8=["#f1f5f6","#d6e3e6","#b7cfd4","#93b6bd","#6f9ca6","#4c818d","#2f6572","#17424c"]
SEM_ROTULO=os.environ.get("MAPAS_SEM_ROTULO")=="1"   # versão para o manuscrito: sem título e sem fonte dentro da imagem
def _limpar(fig):
    pref=("Mapa ","Figura ","Gráfico ","Fonte:")
    for t in fig.texts:
        if t.get_text().startswith(pref): t.set_text("")
    for ax in fig.axes:
        if ax.get_title(loc="left").startswith(pref): ax.set_title("",loc="left")
        if ax.get_title().startswith(pref): ax.set_title("")
        for t in ax.texts:
            if t.get_text().startswith(pref): t.set_text("")
def salvar(fig,base,dpi=300):
    if SEM_ROTULO:
        _limpar(fig); d,f=os.path.split(base); base=os.path.join(d,"sem_rotulo",f)
    os.makedirs(os.path.dirname(base),exist_ok=True)
    fig.savefig(base+".svg",bbox_inches="tight"); fig.savefig(base+".pdf",bbox_inches="tight"); fig.savefig(base+".png",dpi=dpi,bbox_inches="tight")
    if SEM_ROTULO:  # recorta margens brancas do PNG para o manuscrito
        from PIL import Image, ImageChops
        im=Image.open(base+".png").convert("RGB"); bg=Image.new("RGB",im.size,(255,255,255)); bbox=ImageChops.difference(im,bg).getbbox()
        if bbox: im=im.crop((max(bbox[0]-20,0),max(bbox[1]-20,0),min(bbox[2]+20,im.size[0]),min(bbox[3]+20,im.size[1])))
        w,h=im.size; f=min(1.0,2200/w); im=im.resize((int(w*f),int(h*f)))   # ~230 dpi em 24 cm; limite de 3 MB do arquivo de submissão
        im.convert("P",palette=Image.ADAPTIVE,colors=128).save(base+".png",optimize=True)
