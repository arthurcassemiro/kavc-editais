import sys; sys.path.insert(0,"scripts")
from estilo import *
import pandas as pd, numpy as np, matplotlib.pyplot as plt
OUT="03_resultados/figuras/"
b=pd.read_csv("02_base_tratada/base_municipal.csv")
ordem=["G2","G1","M2","M1","P4","P3","P2","P1"]
M=pd.read_csv("04_simulacoes/metricas_cenarios.csv",index_col=0)
# --- Gráfico 1: participação por porte (população-alvo, técnica, consolidada) ---
t=b.groupby("porte_dc").agg(pop04=("pop04","sum"),tec=("tec_ic","sum"),cons=("cons_total300","sum"),pub=("pub_res219","sum")).reindex(ordem)
t=t/t.sum()*100
fig,ax=plt.subplots(figsize=(6.3,3.0))
x=np.arange(len(ordem)); w=0.2
ax.bar(x-1.5*w,t.pop04,w,color="#c9d3d6",label="População 0–4 anos (2022)")
ax.bar(x-0.5*w,t.tec,w,color=PETROLEO,label="Distribuição técnica (251)")
ax.bar(x+0.5*w,t.cons,w,color=VERDE_CLARO,label="Distribuição consolidada (300)")
ax.bar(x+1.5*w,t.pub,w,color=LARANJA,label="Lista publicada, Res. 219/2024 (303)")
for i in range(len(ordem)):
    for dx,v in [(-1.5*w,t.pop04.iloc[i]),(-0.5*w,t.tec.iloc[i]),(0.5*w,t.cons.iloc[i]),(1.5*w,t.pub.iloc[i])]:
        ax.text(x[i]+dx,v+0.6,f"{v:.0f}",ha="center",fontsize=6,color=GRAFITE)
ax.set_xticks(x); ax.set_xticklabels(["G2\n>1 mi","G1\n500 mil–1 mi","M2\n200–500 mil","M1\n100–200 mil","P4\n70–100 mil","P3\n20–70 mil","P2\n5–20 mil","P1\n≤5 mil"],fontsize=6.8)
ax.set_ylabel("Participação (%)",fontsize=7.5); ax.spines[["top","right"]].set_visible(False); ax.tick_params(axis="y",labelsize=7)
ax.legend(frameon=False,fontsize=7,loc="upper left"); ax.set_title("Gráfico 1. Participação de cada porte na população-alvo e nas três etapas de distribuição",loc="left",fontsize=9,color=GRAFITE)
fig.text(0.01,-0.02,"Fonte: Elaboração própria. Portes segundo a classificação da etapa consolidada.",fontsize=6.3,color=GRAFITE_CLARO)
salvar(fig,OUT+"grafico01_participacao_por_porte"); plt.close(fig)
# --- Gráfico 2: cenários — cobertura municipal x participação do quintil de maior PCM ---
lab={"S1 População total":"S1 População","S2 População 0-4":"S2 População 0–4","S3 Vulnerabilidade (ranking FS)":"S3 Ranking FS","S3b Vulnerabilidade ponderada (pop 0-4 × FS)":"S3b Pop. 0–4 × FS","S4 PCM sem faixas (pop 0-4 × PCM)":"S4 Pop. 0–4 × PCM","S4b PCM sem faixas (ranking PCM)":"S4b Ranking PCM","S5 PCM com faixas (regra consolidada, 300)":"S5 PCM com faixas","Técnica (observada, 251)":"Técnica (obs.)","Consolidada (observada, 300)":"Consolidada (obs.)","Publicada (observada, 303)":"Publicada, Res. 219 (obs.)"}
fig,ax=plt.subplots(figsize=(6.3,3.6))
for k,r in M.iterrows():
    obs=k.startswith("Técnica") or k.startswith("Consolidada") or k.startswith("Publicada")
    ax.scatter(r["cobertura_mun_%"],r["share_quintil_maior_PCM_%"],s=60 if obs else 40,color=VERDE_CLARO if obs else PETROLEO,marker="D" if obs else "o",zorder=3,edgecolor="white",linewidth=0.6)
    dx,dy=(1.2,0.4)
    if k.startswith("S3 ") : dx,dy=(-1.2,0.6); 
    if k.startswith("S4b"): continue
    if k.startswith("S5"): dx,dy=(-1.2,0.4)
    if k.startswith("Consolidada"): dx,dy=(1.2,-1.2)
    if k.startswith("Publicada"): dx,dy=(1.2,0.4)
    if k.startswith("S3 "): lab[k]="S3 Ranking FS e S4b Ranking PCM\n(mesma posição)"
    ax.annotate(lab[k],(r["cobertura_mun_%"],r["share_quintil_maior_PCM_%"]),xytext=(r["cobertura_mun_%"]+dx,r["share_quintil_maior_PCM_%"]+dy),fontsize=6.8,color=GRAFITE,ha="left" if dx>0 else "right")
ax.set_xlabel("Municípios contemplados (% dos 399)",fontsize=7.5); ax.set_ylabel("Creches no quintil de maior PCM (% de 300)",fontsize=7.5)
ax.spines[["top","right"]].set_visible(False); ax.tick_params(labelsize=7); ax.grid(color="#eeeeee",lw=0.5,zorder=0)
ax.set_title("Gráfico 2. Cobertura municipal e focalização nos cenários simulados",loc="left",fontsize=9,color=GRAFITE)
fig.text(0.01,-0.02,"Fonte: Elaboração própria. Losangos: distribuições observadas; círculos: simulações com 300 creches.",fontsize=6.3,color=GRAFITE_CLARO)
salvar(fig,OUT+"grafico02_cenarios"); plt.close(fig)
# --- Gráfico 3: cobertura por quintil de PCM x quintil de população 0-4 (heatmap consolidada) ---
ct=pd.read_csv("03_resultados/T4d_cobertura_cons_pop_x_pcm.csv",index_col=0)
fig,ax=plt.subplots(figsize=(5.2,3.2))
im=ax.imshow(ct.values*100,cmap=matplotlib.colors.LinearSegmentedColormap.from_list("p",RAMP_VERDE),vmin=0,vmax=100)
ax.set_xticks(range(5)); ax.set_xticklabels(["Q1\nmenor","Q2","Q3","Q4","Q5\nmaior"],fontsize=6.8); ax.set_yticks(range(5)); ax.set_yticklabels(["Q1 menor","Q2","Q3","Q4","Q5 maior"],fontsize=6.8)
ax.set_xlabel("Quintil de PCM",fontsize=7.5); ax.set_ylabel("Quintil de população 0–4 anos",fontsize=7.5)
for i in range(5):
    for j in range(5):
        v=ct.values[i,j]*100; ax.text(j,i,f"{v:.0f}%",ha="center",va="center",fontsize=6.8,color="white" if v>55 else GRAFITE)
ax.set_title("Gráfico 3. Proporção de municípios contemplados na consolidada,\npor quintis de PCM e de população-alvo",loc="left",fontsize=9,color=GRAFITE)
for s in ax.spines.values(): s.set_visible(False)
fig.text(0.01,-0.03,"Fonte: Elaboração própria. Quintis com cerca de 80 municípios cada.",fontsize=6.3,color=GRAFITE_CLARO)
salvar(fig,OUT+"grafico03_cobertura_quintis"); plt.close(fig)
print("graficos ok")
