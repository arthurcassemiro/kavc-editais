"""Mapas individuais dos pilares do PCM (FE, FD, FS) e do PCM: 12 cm de largura, quintis (5 classes),
rampas por pilar (estilo.py), legenda abaixo do mapa, contorno da UF, escala e norte, sete cidades rotuladas.
Rodar duas vezes: normal e com MAPAS_SEM_ROTULO=1 (saída em 05_mapas/sem_rotulo/)."""
import sys, os; sys.path.insert(0,"scripts")
from estilo import *
import geopandas as gpd, pandas as pd, numpy as np, matplotlib.pyplot as plt
import matplotlib.patheffects as pe
from matplotlib.patches import Patch
SP="/tmp/claude-0/-home-user-kavc-editais/98e3c548-b4ab-5729-ad4a-337524077c70/scratchpad/"
g=gpd.read_file("02_base_tratada/base_municipal_geo.gpkg").to_crs(epsg=5880)
g["geometry"]=g.geometry.simplify(300,preserve_topology=True)
uf=gpd.read_file(SP+"malha/PR_UF_2022.shp").to_crs(epsg=5880); uf["geometry"]=uf.geometry.simplify(300,preserve_topology=True)
OUT="05_mapas/"
L12=LARG*0.75   # 12 cm
LW_MUN=0.3; LW_UF=0.75
def desenhar(ax,cores):
    g.plot(ax=ax,color=cores,edgecolor=BORDA,linewidth=LW_MUN)
    uf.boundary.plot(ax=ax,color=TINTA,linewidth=LW_UF); ax.set_axis_off()
def escala_norte(ax):
    x0,x1=ax.get_xlim(); y0,y1=ax.get_ylim()
    xs=x0+(x1-x0)*0.70; ys=y0+(y1-y0)*0.06
    ax.plot([xs,xs+100000],[ys,ys],color=TINTA,lw=1.0); ax.text(xs+50000,ys+(y1-y0)*0.02,"100 km",ha="center",fontsize=7,color=TINTA)
    xn=xs+150000; ax.annotate("",xy=(xn,ys+(y1-y0)*0.10),xytext=(xn,ys),arrowprops=dict(arrowstyle="-|>",color=TINTA,lw=0.8))
    ax.text(xn,ys+(y1-y0)*0.115,"N",ha="center",va="bottom",fontsize=7,color=TINTA)
def legenda(ax,handles,titulo,ncol=3,y=-0.02):
    ax.legend(handles=handles,title=titulo,loc="upper center",bbox_to_anchor=(0.5,y),ncol=ncol,frameon=False,fontsize=7,title_fontsize=7.5,alignment="left",columnspacing=1.2,handlelength=1.5,handletextpad=0.5)
def classes_quantis(vals,k=5,dec=3):
    qs=np.quantile(vals,np.linspace(0,1,k+1)); br=qs[1:-1]
    cls=np.clip(np.digitize(vals,br,right=True),0,k-1)
    step=10**-dec; labels=[]
    for i in range(k):
        if i==0: labels.append(f"até {fmt_br(br[0],dec)}")
        elif i<k-1: labels.append(f"{fmt_br(br[i-1]+step,dec)} a {fmt_br(br[i],dec)}")
        else: labels.append(f"acima de {fmt_br(br[-1],dec)}")
    return cls,labels
# cidades rotuladas: (nome, deslocamento do texto em km, alinhamento horizontal)
CIDADES={"Curitiba":(6,4,"left"),"Londrina":(6,4,"left"),"Maringá":(-6,4,"right"),"Ponta Grossa":(6,4,"left"),
         "Cascavel":(6,-4,"left"),"Foz do Iguaçu":(9,-15,"left"),"Guarapuava":(6,4,"left")}
def rotular(ax):
    halo=[pe.withStroke(linewidth=1.8,foreground="white")]
    for nome,(dx,dy,ha) in CIDADES.items():
        p=g.loc[g.mun==nome].geometry.representative_point().iloc[0]
        ax.plot(p.x,p.y,marker="o",ms=2.6,mfc="white",mec=TINTA,mew=0.6,zorder=5)
        ax.text(p.x+dx*1000,p.y+dy*1000,nome,fontsize=6.5,color=TINTA,ha=ha,va="center",zorder=6,path_effects=halo)
FONTE_BASE="Elaboração própria a partir das planilhas do PCM (Casa Civil/Ipardes). Malha municipal e estadual IBGE 2022, SIRGAS 2000 (EPSG:4674), projeção policônica (EPSG:5880)."
mapas=[("fe","mapa_fe_educacional","Mapa 1. Fator educacional (FE), por quintis",FE_RAMPA,1,"FE (escore de 0 a 100), quintis"),
       ("fd","mapa_fd_demografico","Mapa 2. Fator demográfico (FD), por quintis",FD_RAMPA,1,"FD (escore de 0 a 100), quintis"),
       ("fs","mapa_fs_socioeconomico","Mapa 3. Fator socioeconômico (FS), por quintis",FS_RAMPA,1,"FS (escore de 0 a 100), quintis"),
       ("pcm_padrao","mapa_pcm","Mapa 4. Potencial de Creche por Município (PCM), por quintis",PCM_RAMPA,3,"PCM, quintis")]
dados=g[["cod7","mun","fe","fd","fs","pcm_padrao"]].copy()
for col,arq,tit,rampa,dec,leg in mapas:
    cls,lab=classes_quantis(g[col].values,5,dec)
    fig,ax=plt.subplots(figsize=(L12,L12*0.70))
    desenhar(ax,[rampa[i] for i in cls]); rotular(ax); escala_norte(ax)
    ax.set_title(tit,loc="left",fontsize=9,color=TINTA,pad=3)
    legenda(ax,[Patch(facecolor=rampa[i],edgecolor=BORDA,linewidth=0.4,label=lab[i]) for i in range(5)],leg,ncol=3,y=0.0)
    salvar(fig,OUT+arq); plt.close(fig)
    dados[f"quintil_{col}"]=cls+1
if not SEM_ROTULO:
    dados=pd.DataFrame(dados.drop(columns="geometry",errors="ignore"))
    with pd.ExcelWriter(OUT+"dados_dos_mapas.xlsx",engine="openpyxl",mode="a",if_sheet_exists="replace") as w:
        dados.to_excel(w,sheet_name="pilares",index=False)
print("mapas pilares ok" + (" (sem rótulo)" if SEM_ROTULO else ""))
