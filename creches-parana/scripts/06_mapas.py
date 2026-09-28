"""Mapas (revisão editorial): 16 cm de largura, corpo >= 7 pt, contorno estadual pela malha de UF do IBGE,
limites municipais cinza 0,3 pt, vírgula decimal, classes sem repetição de limites, escala e norte uma vez por figura."""
import sys, os; sys.path.insert(0,"scripts")
from estilo import *
import geopandas as gpd, pandas as pd, numpy as np, matplotlib.pyplot as plt
from matplotlib.patches import Patch
SP="/tmp/claude-0/-home-user-kavc-editais/98e3c548-b4ab-5729-ad4a-337524077c70/scratchpad/"
g=gpd.read_file("02_base_tratada/base_municipal_geo.gpkg").to_crs(epsg=5880)
g["geometry"]=g.geometry.simplify(300,preserve_topology=True)
uf=gpd.read_file(SP+"malha/PR_UF_2022.shp").to_crs(epsg=5880); uf["geometry"]=uf.geometry.simplify(300,preserve_topology=True)
ordem=["G2","G1","M2","M1","P4","P3","P2","P1"]
OUT="05_mapas/"
LW_MUN=0.3; LW_UF=0.75
def desenhar(ax,cores,hachura=None):
    g.plot(ax=ax,color=cores,edgecolor=BORDA,linewidth=LW_MUN)
    if hachura is not None and hachura.any():
        g[hachura].plot(ax=ax,facecolor="none",edgecolor=TINTA,hatch="////",linewidth=0)
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
def fonte(fig,txt,y=0.0): fig.text(0.0,y,"Fonte: "+txt,fontsize=7,color=TINTA2,ha="left",va="top")
FONTE_BASE="Elaboração própria a partir das planilhas do PCM (Casa Civil/Ipardes). Malha municipal e estadual IBGE 2022, SIRGAS 2000 (EPSG:4674), projeção policônica (EPSG:5880)."
dados={}
# ---------------- Mapa 1 (manuscrito): PCM e os três fatores, 2 x 2 ----------------
L14=14*CM
fig,axes=plt.subplots(2,2,figsize=(L14,L14*1.06))
paineis=[("pcm_padrao","(a) PCM",PCM_RAMPA,3),("fe","(b) Fator educacional",FE_RAMPA,1),("fd","(c) Fator demográfico",FD_RAMPA,1),("fs","(d) Fator socioeconômico",FS_RAMPA,1)]
for ax,(col,tit,rampa,dec) in zip(axes.ravel(),paineis):
    cls,lab=classes_quantis(g[col].values,5,dec); desenhar(ax,[rampa[i] for i in cls])
    ax.set_title(tit,loc="left",fontsize=9,color=TINTA,pad=2)
    legenda(ax,[Patch(facecolor=rampa[i],edgecolor=BORDA,linewidth=0.4,label=lab[i]) for i in range(5)],"PCM, quintis" if col=="pcm_padrao" else "Escore de 0 a 100, quintis",ncol=2,y=0.0)
    dados[f"mapa01_{col}"]=g[["cod7","mun",col]].assign(classe=cls+1)
escala_norte(axes[1,1])
fig.suptitle("Mapa 1. Potencial de Creche por Município (PCM) e seus três fatores",x=0.0,ha="left",fontsize=9,color=TINTA)
plt.subplots_adjust(wspace=0.06,hspace=0.30)
salvar(fig,OUT+"mapa01_pcm_fatores",jpeg=True); plt.close(fig)
# ---------------- Mapa 2 (manuscrito): tipologia das etapas ----------------
fig,ax=plt.subplots(figsize=(LARG,LARG*0.66))
tip=g.tipologia3.copy()
tip=tip.replace({"Técnica, excluído na consolidada, reincluído na publicada":"Acrescidos na lista publicada","Somente na lista publicada":"Acrescidos na lista publicada"})
cores={"Nas três etapas":CINZA_CLARO,"Entrou na consolidada":CINZAS[0],"Acrescidos na lista publicada":ACENTO,"Somente na técnica":"#FFFFFF","Não contemplado":"#FFFFFF"}
cnt=tip.value_counts()
rot={"Nas três etapas":f"Nas três etapas ({cnt['Nas três etapas']})","Entrou na consolidada":f"Entrou na consolidada e permaneceu ({cnt['Entrou na consolidada']})",
     "Acrescidos na lista publicada":f"Acrescidos na lista publicada ({cnt['Acrescidos na lista publicada']})","Somente na técnica":f"Somente na técnica ({cnt['Somente na técnica']})","Não contemplado":f"Não contemplado ({cnt['Não contemplado']})"}
desenhar(ax,tip.map(cores).values,hachura=(tip=="Somente na técnica").values)
h=[Patch(facecolor=cores[k],edgecolor=BORDA,linewidth=0.4,hatch="////" if k=="Somente na técnica" else None,label=rot[k]) for k in ["Nas três etapas","Entrou na consolidada","Acrescidos na lista publicada","Somente na técnica","Não contemplado"]]
legenda(ax,h,"Percurso do município nas três etapas",ncol=3,y=0.0); escala_norte(ax)
ax.set_title("Mapa 2. Tipologia dos municípios segundo as etapas de distribuição",loc="left",fontsize=9,color=TINTA)
salvar(fig,OUT+"mapa02_tipologia",jpeg=True); plt.close(fig)
dados["mapa02_tipologia"]=g[["cod7","mun","tec_ic","cons_total300","pub_res219","tipologia3"]].assign(classe_mapa=tip.values)
# ---------------- Suplementares ----------------
# S1: faixas de porte (2 painéis)
fig,axes=plt.subplots(1,2,figsize=(LARG,LARG*0.42))
lab_ic=["G2 (acima de 1 milhão)","G1 (500 mil a 1 milhão)","M2 (200 a 500 mil)","M1 (100 a 200 mil)","P4 (70 a 100 mil)","P3 (40 a 70 mil)","P2 (20 a 40 mil)","P1 (até 20 mil)"]
lab_dc=["G2 (acima de 1 milhão)","G1 (500 mil a 1 milhão)","M2 (200 a 500 mil)","M1 (100 a 200 mil)","P4 (70 a 100 mil)","P3 (20 a 70 mil)","P2 (5 a 20 mil)","P1 (até 5 mil)"]
R8=["#252525","#404040","#5c5c5c","#787878","#969696","#b4b4b4","#d2d2d2","#f0f0f0"]
for ax,(col,lab,tit) in zip(axes,[("porte_ic",lab_ic,"(a) Etapa técnica"),("porte_dc",lab_dc,"(b) Etapa consolidada e lista publicada")]):
    idx=g[col].map({p:i for i,p in enumerate(ordem)}).values; desenhar(ax,[R8[i] for i in idx]); ax.set_title(tit,loc="left",fontsize=9,color=TINTA,pad=2)
    legenda(ax,[Patch(facecolor=R8[i],edgecolor=BORDA,linewidth=0.4,label=lab[i]) for i in range(8)],"Porte (habitantes, 2022)",ncol=2,y=0.0)
escala_norte(axes[1]); fig.suptitle("Mapa S1. Faixas de porte populacional nas duas classificações",x=0.0,ha="left",fontsize=9,color=TINTA)
salvar(fig,OUT+"mapaS1_faixas_porte",jpeg=True); plt.close(fig)
dados["mapaS1_faixas"]=g[["cod7","mun","pop","porte_ic","porte_dc"]]
# S2: creches por município nas três etapas (2 x 2, 4º quadro com legenda)
br_c=[0,1,2,5]; lab_c=["nenhuma","1","2","3 a 5","6 ou mais"]; ramp_c=["#FFFFFF"]+RAMPA_CINZA[1:5]
fig,axes=plt.subplots(2,2,figsize=(LARG,LARG*0.84))
for ax,(col,tit) in zip(axes.ravel()[:3],[("tec_ic","(a) Técnica inicial: 251 creches, 209 municípios"),("cons_total300","(b) Consolidada: 300 creches, 224 municípios"),("pub_res219","(c) Lista publicada: 303 creches, 261 municípios")]):
    cls=np.digitize(g[col].values,br_c,right=True); desenhar(ax,[ramp_c[i] for i in cls]); ax.set_title(tit,loc="left",fontsize=9,color=TINTA,pad=2)
    dados[f"mapaS2_{col}"]=g[["cod7","mun",col]]
axes[1,1].set_axis_off(); axes[1,1].legend(handles=[Patch(facecolor=ramp_c[i],edgecolor=BORDA,linewidth=0.4,label=lab_c[i]) for i in range(5)],title="Creches por município",loc="center",frameon=False,fontsize=8,title_fontsize=8.5,alignment="left")
escala_norte(axes[1,0]); fig.suptitle("Mapa S2. Creches por município nas três etapas de distribuição",x=0.0,ha="left",fontsize=9,color=TINTA)
plt.subplots_adjust(wspace=0.04,hspace=0.12); salvar(fig,OUT+"mapaS2_tres_etapas",jpeg=True); plt.close(fig)
# S3: diferenças entre etapas (2 painéis, mesma escala)
def cls_dif(x):
    if x<=-2: return 0
    if x==-1: return 1
    if x==0: return 2
    if x==1: return 3
    return 4
cols_d=["#8C8C8C","#D9D9D9","#FFFFFF","#E8A0A8",ACENTO]; labs_d=["−5 a −2 (redução)","−1 (redução)","sem alteração","+1 (acréscimo)","+2 a +3 (acréscimo)"]
fig,axes=plt.subplots(1,2,figsize=(LARG,LARG*0.42))
for ax,(dv,tit) in zip(axes,[(g.dif_cons_tec.values,"(a) Consolidada menos técnica inicial"),((g.pub_res219-g.cons_total300).values,"(b) Lista publicada menos consolidada")]):
    cd=np.array([cls_dif(x) for x in dv]); desenhar(ax,[cols_d[i] for i in cd],hachura=(cd<2)); ax.set_title(tit,loc="left",fontsize=9,color=TINTA,pad=2)
legenda(axes[0],[Patch(facecolor=cols_d[i],edgecolor=BORDA,linewidth=0.4,hatch="////" if i<2 else None,label=labs_d[i]) for i in range(5)],"Diferença em creches",ncol=3,y=0.0)
escala_norte(axes[1]); fig.suptitle("Mapa S3. Diferenças entre as etapas de distribuição",x=0.0,ha="left",fontsize=9,color=TINTA)
salvar(fig,OUT+"mapaS3_diferencas",jpeg=True); plt.close(fig)
dados["mapaS3_diferencas"]=g[["cod7","mun","tec_ic","cons_total300","pub_res219"]].assign(dif_cons_tec=g.dif_cons_tec.values,dif_pub_cons=(g.pub_res219-g.cons_total300).values)
# S4: intensidade por criança (lista publicada)
g["cpc_pub"]=g.pub_res219/g.pop04*1e4
br=[0,3,6,10,15]; lab=["não contemplado","até 3","3,1 a 6","6,1 a 10","10,1 a 15","acima de 15"]; rampa=["#FFFFFF"]+RAMPA_CINZA[1:]
fig,ax=plt.subplots(figsize=(LARG,LARG*0.66)); cls=np.digitize(g.cpc_pub.values,br,right=True); desenhar(ax,[rampa[i] for i in cls])
legenda(ax,[Patch(facecolor=rampa[i],edgecolor=BORDA,linewidth=0.4,label=lab[i]) for i in range(6)],"Creches por 10 mil crianças de 0 a 4 anos (lista publicada)",ncol=3,y=0.0); escala_norte(ax)
ax.set_title("Mapa S4. Intensidade da lista publicada em relação à população-alvo",loc="left",fontsize=9,color=TINTA)
salvar(fig,OUT+"mapaS4_creches_por_crianca",jpeg=True); plt.close(fig)
dados["mapaS4_intensidade"]=g[["cod7","mun","pop04","pub_res219","cpc_pub"]]
with pd.ExcelWriter(OUT+"dados_dos_mapas.xlsx") as w:
    for k,v in dados.items(): pd.DataFrame(v.drop(columns="geometry",errors="ignore")).to_excel(w,sheet_name=k[:31],index=False)
print("mapas ok")
