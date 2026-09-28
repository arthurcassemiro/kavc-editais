import sys; sys.path.insert(0,"scripts")
from estilo import *
import geopandas as gpd, pandas as pd, numpy as np, matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.lines import Line2D
g=gpd.read_file("02_base_tratada/base_municipal_geo.gpkg").to_crs(epsg=5880)
g["geometry"]=g.geometry.simplify(300,preserve_topology=True)  # simplificação leve (300 m, invisível na escala estadual) para reduzir o tamanho dos vetores
ordem=["G2","G1","M2","M1","P4","P3","P2","P1"]
OUT="05_mapas/"
def base_ax(fig,ax,titulo,fonte="Elaboração própria a partir das planilhas do PCM (Casa Civil/Ipardes) e malha municipal IBGE 2022."):
    ax.set_axis_off(); ax.set_title(titulo,loc="left",fontsize=10,fontweight="medium",color=GRAFITE,pad=6)
    fig.text(0.01,0.005,"Fonte: "+fonte,fontsize=6.5,color=GRAFITE_CLARO,ha="left",va="bottom")
    # escala gráfica 100 km
    x0,x1=ax.get_xlim(); y0,y1=ax.get_ylim()
    xs=x0+(x1-x0)*0.03; ys=y0+(y1-y0)*0.05
    ax.plot([xs,xs+100000],[ys,ys],color=GRAFITE,lw=1.2); ax.text(xs+50000,ys+(y1-y0)*0.012,"100 km",ha="center",fontsize=6.5,color=GRAFITE)
    ax.annotate("N",xy=(1.06,0.30),xycoords="axes fraction",ha="center",fontsize=7,color=GRAFITE)
    ax.annotate("",xy=(1.06,0.29),xytext=(1.06,0.20),xycoords="axes fraction",textcoords="axes fraction",arrowprops=dict(arrowstyle="-|>",color=GRAFITE,lw=1))
def choropleth_classes(col,breaks,labels,ramp,titulo,fname,legtitle,fonte=None,ax=None,fig=None,leg=True):
    own = ax is None
    if own: fig,ax=plt.subplots(figsize=(6.4,4.6))
    cls=np.digitize(g[col].values,breaks,right=True)  # breaks = limites superiores exceto último
    cls=np.clip(cls,0,len(ramp)-1)
    g.plot(ax=ax,color=[ramp[i] for i in cls],edgecolor="white",linewidth=0.25)
    g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
    if leg:
        handles=[Patch(facecolor=ramp[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,label=labels[i]) for i in range(len(ramp))]
        ax.legend(handles=handles,title=legtitle,loc="upper left",bbox_to_anchor=(1.0,0.95),frameon=False,fontsize=7,title_fontsize=7.5,alignment="left")
    if own:
        base_ax(fig,ax,titulo,fonte) if fonte else base_ax(fig,ax,titulo)
        salvar(fig,OUT+fname); plt.close(fig)
    return cls
def quantile_breaks(col,k=5,dec=2):
    qs=np.quantile(g[col],np.linspace(0,1,k+1)); br=qs[1:-1]
    labels=[]; lo=qs[0]
    for i,hi in enumerate(list(br)+[qs[-1]]):
        labels.append(f"{lo:.{dec}f} a {hi:.{dec}f}"); lo=hi
    return br,labels
dados_export={}
# --- Mapa 1: PCM ---
br,lab=quantile_breaks("pcm_padrao",5,3)
c=choropleth_classes("pcm_padrao",br,lab,RAMP_PETROLEO,"Mapa 1. Potencial de Creche por Município (PCM), quintis","mapa01_pcm","PCM (quintis)")
dados_export["mapa01_pcm"]=g[["cod7","mun","pcm_padrao"]].assign(classe=c)
# --- Mapa 2: componentes (3 painéis) ---
fig,axes=plt.subplots(1,3,figsize=(10.5,3.9))
for ax,(col,nome,letra) in zip(axes,[("fe","Fator educacional","a"),("fd","Fator demográfico","b"),("fs","Fator socioeconômico","c")]):
    br,lab=quantile_breaks(col,5,1)
    c=choropleth_classes(col,br,lab,RAMP_PETROLEO,"","", "", ax=ax,fig=fig,leg=True)
    ax.set_axis_off(); ax.set_title(f"({letra}) {nome}",loc="left",fontsize=9,color=GRAFITE)
    ax.get_legend().remove()
    ax.legend(handles=[Patch(facecolor=RAMP_PETROLEO[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,label=lab[i]) for i in range(5)],title="Escore 0–100 (quintis)",loc="upper center",bbox_to_anchor=(0.5,0.04),ncol=3,frameon=False,fontsize=6.5,title_fontsize=7,alignment="left",columnspacing=1.0,handlelength=1.4)
    dados_export[f"mapa02_{col}"]=g[["cod7","mun",col]].assign(classe=c)
fig.suptitle("Mapa 2. Componentes do PCM por município",x=0.01,ha="left",fontsize=10,fontweight="medium",color=GRAFITE)
fig.text(0.01,0.0,"Fonte: Elaboração própria a partir das planilhas do PCM (Casa Civil/Ipardes) e malha municipal IBGE 2022. Escores normalizados 0–100.",fontsize=6.5,color=GRAFITE_CLARO)
salvar(fig,OUT+"mapa02_componentes"); plt.close(fig)
# --- Mapa 3: faixas de porte (2 painéis) ---
fig,axes=plt.subplots(1,2,figsize=(10.5,5.3))
lab_ic=["G2 (> 1 milhão)","G1 (500 mil a 1 milhão)","M2 (200 a 500 mil)","M1 (100 a 200 mil)","P4 (70 a 100 mil)","P3 (40 a 70 mil)","P2 (20 a 40 mil)","P1 (até 20 mil)"]
lab_dc=["G2 (> 1 milhão)","G1 (500 mil a 1 milhão)","M2 (200 a 500 mil)","M1 (100 a 200 mil)","P4 (70 a 100 mil)","P3 (20 a 70 mil)","P2 (5 a 20 mil)","P1 (até 5 mil)"]
for ax,(col,lab,tit) in zip(axes,[("porte_ic",lab_ic,"(a) Classificação da etapa técnica"),("porte_dc",lab_dc,"(b) Classificação da etapa consolidada")]):
    idx=g[col].map({p:i for i,p in enumerate(ordem)}).values
    g.plot(ax=ax,color=[RAMP_8[::-1][i] for i in idx],edgecolor="white",linewidth=0.25); g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
    ax.set_axis_off(); ax.set_title(tit,loc="left",fontsize=9,color=GRAFITE)
    ax.legend(handles=[Patch(facecolor=RAMP_8[::-1][i],edgecolor=GRAFITE_CLARO,linewidth=0.4,label=lab[i]) for i in range(8)],title="Porte (habitantes, 2022)",loc="upper center",bbox_to_anchor=(0.5,0.04),ncol=4,frameon=False,fontsize=6.5,columnspacing=1.0,handlelength=1.4,title_fontsize=7,alignment="left")
fig.suptitle("Mapa 3. Faixas de porte populacional (G2 a P1) nas duas etapas",x=0.01,ha="left",fontsize=10,fontweight="medium",color=GRAFITE)
fig.text(0.01,0.0,"Fonte: Elaboração própria. População: Censo Demográfico 2022 (IBGE). Malha municipal IBGE 2022.",fontsize=6.5,color=GRAFITE_CLARO)
salvar(fig,OUT+"mapa03_faixas_porte"); plt.close(fig)
dados_export["mapa03_faixas"]=g[["cod7","mun","pop","porte_ic","porte_dc"]]
# --- Mapas 4 e 5: técnica e consolidada ---
br_c=[0,1,2,5,10]; lab_c=["0","1","2","3 a 5","6 a 10","11 ou mais"]; ramp_c=["#ffffff"]+RAMP_VERDE
for col,tit,fn in [("tec_ic","Mapa 4. Distribuição técnica inicial (251 creches, 209 municípios)","mapa04_distribuicao_tecnica"),("cons_total300","Mapa 5. Distribuição consolidada (300 creches, 224 municípios)","mapa05_distribuicao_consolidada")]:
    fig,ax=plt.subplots(figsize=(6.4,4.6))
    cls=np.digitize(g[col].values,br_c,right=True)
    g.plot(ax=ax,color=[ramp_c[i] for i in cls],edgecolor="#bdbdbd",linewidth=0.25); g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
    ax.legend(handles=[Patch(facecolor=ramp_c[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,label=lab_c[i]) for i in range(6)],title="Creches por município",loc="upper left",bbox_to_anchor=(1.0,0.95),frameon=False,fontsize=7,title_fontsize=7.5,alignment="left")
    base_ax(fig,ax,tit); salvar(fig,OUT+fn); plt.close(fig)
    dados_export[fn]=g[["cod7","mun",col]].assign(classe=cls)
# --- Mapa 6: diferença consolidada - técnica ---
fig,ax=plt.subplots(figsize=(6.4,4.6))
d=g.dif_cons_tec.values
def cls_dif(x):
    if x<=-2: return 0
    if x==-1: return 1
    if x==0: return 2
    if x==1: return 3
    if x==2: return 4
    return 5
cd=np.array([cls_dif(x) for x in d]); cols=["#1f5c6a","#8db6bf","#ffffff","#f6c48f","#e8862a","#b85c0a"]
labs=["−4 a −2 (redução)","−1 (redução)","0 (sem alteração)","+1 (acréscimo)","+2 (acréscimo)","+3 a +16 (acréscimo)"]
g.plot(ax=ax,color=[cols[i] for i in cd],edgecolor="#bdbdbd",linewidth=0.25)
g[cd<2].plot(ax=ax,facecolor="none",edgecolor=GRAFITE,hatch="////",linewidth=0)
g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
h=[Patch(facecolor=cols[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,hatch="////" if i<2 else None,label=labs[i]) for i in range(6)]
ax.legend(handles=h,title="Consolidada − técnica (creches)",loc="upper left",bbox_to_anchor=(1.0,0.95),frameon=False,fontsize=7,title_fontsize=7.5,alignment="left")
base_ax(fig,ax,"Mapa 6. Diferença entre a distribuição consolidada e a técnica inicial"); salvar(fig,OUT+"mapa06_diferenca"); plt.close(fig)
dados_export["mapa06_diferenca"]=g[["cod7","mun","tec_ic","cons_total300","dif_cons_tec"]].assign(classe=cd)
# --- Mapa 7: tipologia em três etapas ---
fig,ax=plt.subplots(figsize=(6.4,4.6))
tcol={"Não contemplado":"#f2f2f2","Somente na técnica":"#8db6bf","Nas três etapas":"#1b6b52","Entrou na consolidada":"#86bd9c","Técnica, excluído na consolidada, reincluído na publicada":"#f6c48f","Somente na lista publicada":"#e8862a"}
cnt=g.tipologia3.value_counts()
tlab={k:f"{k} ({cnt.get(k,0)})" for k in tcol}
tlab["Somente na lista publicada"]=f"Somente na lista publicada: ajuste posterior ({cnt.get('Somente na lista publicada',0)})"
tlab["Técnica, excluído na consolidada, reincluído na publicada"]=f"Técnica, excluído na consolidada,\nreincluído na publicada ({cnt.get('Técnica, excluído na consolidada, reincluído na publicada',0)})"
tlab["Entrou na consolidada"]=f"Entrou na consolidada e permaneceu ({cnt.get('Entrou na consolidada',0)})"
g.plot(ax=ax,color=g.tipologia3.map(tcol).values,edgecolor="#bdbdbd",linewidth=0.25)
g[g.tipologia3=="Somente na técnica"].plot(ax=ax,facecolor="none",edgecolor=GRAFITE,hatch="////",linewidth=0)
g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
h=[Patch(facecolor=tcol[k],edgecolor=GRAFITE_CLARO,linewidth=0.4,hatch="////" if k=="Somente na técnica" else None,label=tlab[k]) for k in ["Nas três etapas","Entrou na consolidada","Técnica, excluído na consolidada, reincluído na publicada","Somente na lista publicada","Somente na técnica","Não contemplado"]]
ax.legend(handles=h,title="Tipologia das etapas",loc="upper left",bbox_to_anchor=(1.0,0.95),frameon=False,fontsize=7,title_fontsize=7.5,alignment="left")
base_ax(fig,ax,"Mapa 7. Tipologia dos municípios segundo as três etapas de distribuição"); salvar(fig,OUT+"mapa07_tipologia"); plt.close(fig)
dados_export["mapa07_tipologia"]=g[["cod7","mun","tec_ic","cons_total300","pub_res219","tipologia3"]]
# --- Mapa 9: lista publicada ---
fig,ax=plt.subplots(figsize=(6.4,4.6))
cls=np.digitize(g["pub_res219"].values,br_c,right=True)
g.plot(ax=ax,color=[ramp_c[i] for i in cls],edgecolor="#bdbdbd",linewidth=0.25); g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
ax.legend(handles=[Patch(facecolor=ramp_c[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,label=lab_c[i]) for i in range(6)],title="Creches por município",loc="upper left",bbox_to_anchor=(1.0,0.95),frameon=False,fontsize=7,title_fontsize=7.5,alignment="left")
base_ax(fig,ax,"Mapa 9. Lista publicada na Resolução SEDEF 219/2024 (303 creches, 261 municípios)"); salvar(fig,OUT+"mapa09_lista_publicada"); plt.close(fig)
dados_export["mapa09_publicada"]=g[["cod7","mun","pub_res219"]].assign(classe=cls)
# --- Mapa 10: diferença publicada - consolidada ---
fig,ax=plt.subplots(figsize=(6.4,4.6))
d2=(g.pub_res219-g.cons_total300).values
cd2=np.array([cls_dif(x) for x in d2])
labs2=["−5 a −2 (redução)","−1 (redução)","0 (sem alteração)","+1 (acréscimo)","+2 (acréscimo)","+3 ou mais (acréscimo)"]
g.plot(ax=ax,color=[cols[i] for i in cd2],edgecolor="#bdbdbd",linewidth=0.25)
g[cd2<2].plot(ax=ax,facecolor="none",edgecolor=GRAFITE,hatch="////",linewidth=0)
g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
pres=[i for i in range(6) if (cd2==i).any()]
h=[Patch(facecolor=cols[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,hatch="////" if i<2 else None,label=labs2[i]) for i in pres]
ax.legend(handles=h,title="Publicada − consolidada (creches)",loc="upper left",bbox_to_anchor=(1.0,0.95),frameon=False,fontsize=7,title_fontsize=7.5,alignment="left")
base_ax(fig,ax,"Mapa 10. Diferença entre a lista publicada e a distribuição consolidada"); salvar(fig,OUT+"mapa10_diferenca_publicada"); plt.close(fig)
dados_export["mapa10_dif_publicada"]=g[["cod7","mun","cons_total300","pub_res219"]].assign(dif=d2,classe=cd2)
# --- Mapa 8: creches por 10 mil crianças (consolidada) ---
g["cpc"]=g.creches_por_10mil_04_cons
br=[0,3,6,10,15]; lab=["0 (não contemplado)","até 3","3 a 6","6 a 10","10 a 15","mais de 15"]
fig,ax=plt.subplots(figsize=(6.4,4.6)); cls=np.digitize(g.cpc.values,br,right=True)
g.plot(ax=ax,color=[ramp_c[i] for i in cls],edgecolor="#bdbdbd",linewidth=0.25); g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
ax.legend(handles=[Patch(facecolor=ramp_c[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,label=lab[i]) for i in range(6)],title="Creches por 10 mil crianças de 0 a 4 anos",loc="upper left",bbox_to_anchor=(1.0,0.95),frameon=False,fontsize=7,title_fontsize=7.5,alignment="left")
base_ax(fig,ax,"Mapa 8. Intensidade da distribuição consolidada em relação à população-alvo"); salvar(fig,OUT+"mapa08_creches_por_crianca"); plt.close(fig)
dados_export["mapa08_intensidade"]=g[["cod7","mun","pop04","cons_total300","cpc"]].assign(classe=cls)
with pd.ExcelWriter(OUT+"dados_dos_mapas.xlsx") as w:
    for k,v in dados_export.items(): pd.DataFrame(v.drop(columns="geometry",errors="ignore")).to_excel(w,sheet_name=k[:31],index=False)
g.drop(columns="geometry").to_csv(OUT+"dados_dos_mapas.csv",index=False)
print("mapas ok")
# --- Mapas compostos para o manuscrito ---
# 11: três etapas lado a lado
fig,axes=plt.subplots(1,3,figsize=(10.5,3.9))
for ax,(col,tit) in zip(axes,[("tec_ic","(a) Técnica inicial: 251 creches, 209 municípios"),("cons_total300","(b) Consolidada: 300 creches, 224 municípios"),("pub_res219","(c) Publicada (Res. 219/2024): 303 creches, 261 municípios")]):
    cls=np.digitize(g[col].values,br_c,right=True)
    g.plot(ax=ax,color=[ramp_c[i] for i in cls],edgecolor="#bdbdbd",linewidth=0.2); g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5)
    ax.set_axis_off(); ax.set_title(tit,loc="left",fontsize=8,color=GRAFITE)
    ax.legend(handles=[Patch(facecolor=ramp_c[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,label=lab_c[i]) for i in range(6)],title="Creches por município",loc="upper center",bbox_to_anchor=(0.5,0.04),ncol=3,frameon=False,fontsize=6.5,title_fontsize=7,alignment="left",columnspacing=1.0,handlelength=1.4)
fig.suptitle("Mapa 4. Creches por município nas três etapas de distribuição",x=0.01,ha="left",fontsize=10,fontweight="medium",color=GRAFITE)
fig.text(0.01,0.0,"Fonte: Elaboração própria a partir das planilhas do PCM, da Resolução SEDEF 219/2024 e da malha municipal IBGE 2022.",fontsize=6.5,color=GRAFITE_CLARO)
salvar(fig,OUT+"mapa11_tres_etapas"); plt.close(fig)
# 12: duas transições lado a lado
fig,axes=plt.subplots(1,2,figsize=(10.5,4.6))
for ax,(dvals,tit,labs_) in zip(axes,[(g.dif_cons_tec.values,"(a) Consolidada − técnica inicial",labs),((g.pub_res219-g.cons_total300).values,"(b) Publicada − consolidada",labs2)]):
    cdd=np.array([cls_dif(x) for x in dvals])
    g.plot(ax=ax,color=[cols[i] for i in cdd],edgecolor="#bdbdbd",linewidth=0.2)
    g[cdd<2].plot(ax=ax,facecolor="none",edgecolor=GRAFITE,hatch="////",linewidth=0)
    g.dissolve().boundary.plot(ax=ax,color=GRAFITE,linewidth=0.5); ax.set_axis_off(); ax.set_title(tit,loc="left",fontsize=8.5,color=GRAFITE)
    pres=[i for i in range(6) if (cdd==i).any()]
    ax.legend(handles=[Patch(facecolor=cols[i],edgecolor=GRAFITE_CLARO,linewidth=0.4,hatch="////" if i<2 else None,label=labs_[i]) for i in pres],title="Diferença (creches)",loc="upper center",bbox_to_anchor=(0.5,0.04),ncol=3,frameon=False,fontsize=6.5,title_fontsize=7,alignment="left",columnspacing=1.0,handlelength=1.4)
fig.suptitle("Mapa 5. Diferenças entre as etapas de distribuição",x=0.01,ha="left",fontsize=10,fontweight="medium",color=GRAFITE)
fig.text(0.01,0.0,"Fonte: Elaboração própria. Hachura: redução. Laranja: acréscimo.",fontsize=6.5,color=GRAFITE_CLARO)
salvar(fig,OUT+"mapa12_diferencas_duas_transicoes"); plt.close(fig)
print("mapas compostos ok")
