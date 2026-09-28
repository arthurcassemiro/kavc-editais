import sys; sys.path.insert(0,"scripts")
from estilo import *
import pandas as pd, numpy as np, matplotlib.pyplot as plt
from matplotlib.lines import Line2D
OUT="03_resultados/figuras/"
b=pd.read_csv("02_base_tratada/base_municipal.csv"); ordem=["G2","G1","M2","M1","P4","P3","P2","P1"]
M=pd.read_csv("04_simulacoes/metricas_cenarios.csv",index_col=0)
# ---- Gráfico 1: gráfico de pontos, participação por porte ----
t=b.groupby("porte_dc").agg(pop04=("pop04","sum"),tec=("tec_ic","sum"),cons=("cons_total300","sum"),pub=("pub_res219","sum")).reindex(ordem); t=t/t.sum()*100
rot=["G2 (acima de 1 milhão)","G1 (500 mil a 1 milhão)","M2 (200 a 500 mil)","M1 (100 a 200 mil)","P4 (70 a 100 mil)","P3 (20 a 70 mil)","P2 (5 a 20 mil)","P1 (até 5 mil)"]
fig,ax=plt.subplots(figsize=(LARG,LARG*0.5))
y=np.arange(len(ordem))[::-1]
for i,p in enumerate(ordem):
    lo=min(t.tec.iloc[i],t.cons.iloc[i],t.pub.iloc[i]); hi=max(t.tec.iloc[i],t.cons.iloc[i],t.pub.iloc[i])
    ax.plot([lo,hi],[y[i],y[i]],color=CINZA_CLARO,lw=1.2,zorder=1)
    ax.axhline(y[i],color="#eeeeee",lw=0.5,zorder=0)
ax.scatter(t.pop04,y,marker="|",s=160,color=ACENTO,linewidths=1.6,zorder=3,label="População de 0 a 4 anos (referência)")
ax.scatter(t.tec,y,marker="o",s=30,color=CINZAS[0],zorder=4,label="Distribuição técnica (251 creches)")
ax.scatter(t.cons,y,marker="o",s=30,color=CINZAS[1],zorder=4,label="Distribuição consolidada (300)")
ax.scatter(t.pub,y,marker="o",s=30,color=CINZAS[2],zorder=4,label="Lista publicada (303)")
ax.set_yticks(y); ax.set_yticklabels(rot,fontsize=8); ax.set_xlabel("Participação (%)",fontsize=8); ax.tick_params(axis="x",labelsize=8)
ax.set_xlim(0,52); ax.xaxis.set_major_formatter(lambda v,_: fmt_br(v,0))
ax.spines[["top","right"]].set_visible(False); ax.legend(frameon=False,fontsize=7.5,loc="upper right",bbox_to_anchor=(1.0,1.0))
ax.set_title("Gráfico S2. Participação de cada porte na população-alvo e nas três etapas de distribuição",loc="left",fontsize=9,color=TINTA)
salvar(fig,OUT+"graficoS2_participacao_por_porte"); plt.close(fig)
pd.DataFrame({"porte":rot,"pop_0_4_%":t.pop04.round(1).values,"tecnica_%":t.tec.round(1).values,"consolidada_%":t.cons.round(1).values,"publicada_%":t.pub.round(1).values}).to_csv(OUT+"graficoS2_dados.csv",index=False)
# ---- Gráfico 2: cobertura x focalização ----
lab={"S1 Proporcional à população total":"S1 População total","S2 Proporcional à população 0-4":"S2 População 0–4","S3 Proporcional a população 0-4 × FS":"S3 Pop. 0–4 × FS","S4 Proporcional a população 0-4 × PCM (sem faixas)":"S4 Pop. 0–4 × PCM","S5 Ranking do fator socioeconômico":"S5 Ranking FS","S6 Ranking do PCM (sem faixas)":"S6 Ranking PCM","S7 PCM com faixas (regra consolidada, 300)":"S7 PCM com faixas","Técnica (observada, 251)":"Técnica (observada)","Consolidada (observada, 300)":"Consolidada (observada)","Publicada (observada, 303)":"Lista publicada (observada)"}
off={"S1 População total":(1.5,-0.4),"S2 População 0–4":(1.5,0.3),"S3 Pop. 0–4 × FS":(1.5,-0.2),"S4 Pop. 0–4 × PCM":(1.5,0.2),"S5 Ranking FS":(-1.5,1.6),"S6 Ranking PCM":(-1.5,-3.6),"S7 PCM com faixas":(-1.5,1.3),"Técnica (observada)":(1.5,0.4),"Consolidada (observada)":(0.4,-1.4),"Lista publicada (observada)":(0.8,-2.6)}
fig,ax=plt.subplots(figsize=(LARG,LARG*0.58))
for k,r in M.iterrows():
    obs=k.startswith(("Técnica","Consolidada","Publicada")); x,yv=r["cobertura_mun_%"],r["share_quintil_maior_PCM_%"]; nome=lab[k]
    ax.scatter(x,yv,s=46 if obs else 34,color=TINTA if obs else CINZA_MEDIO,marker="D" if obs else "o",zorder=3,edgecolor="white",linewidth=0.6)
    dx,dy=off[nome]
    ax.annotate(nome,(x,yv),xytext=(x+dx,yv+dy),fontsize=7.5,color=TINTA,ha="left" if dx>0 else "right",va="center",arrowprops=dict(arrowstyle="-",color=BORDA,lw=0.6,shrinkA=0,shrinkB=3))
ax.set_xlabel("Municípios contemplados (% dos 399)",fontsize=8); ax.set_ylabel("Creches no quintil de maior PCM\n(% das unidades distribuídas)",fontsize=8)
ax.tick_params(labelsize=8); ax.grid(color="#eeeeee",lw=0.5,zorder=0); ax.spines[["top","right"]].set_visible(False)
ax.xaxis.set_major_formatter(lambda v,_: fmt_br(v,0)); ax.yaxis.set_major_formatter(lambda v,_: fmt_br(v,0))
ax.legend(handles=[Line2D([],[],marker="D",color=TINTA,linestyle="",markersize=6,label="Distribuições observadas"),Line2D([],[],marker="o",color=CINZA_MEDIO,linestyle="",markersize=6,label="Simulações com 300 creches")],frameon=False,fontsize=7.5,loc="lower right")
ax.set_title("Gráfico 1. Cobertura municipal e focalização nos cenários simulados e nas distribuições observadas",loc="left",fontsize=9,color=TINTA)
salvar(fig,OUT+"grafico01_cenarios"); plt.close(fig)
M[["cobertura_mun_%","share_quintil_maior_PCM_%"]].rename(index=lab).round(1).to_csv(OUT+"grafico01_dados.csv")
# ---- Gráfico S1: cobertura por quintis (suplementar) ----
ct=pd.read_csv("03_resultados/T4d_cobertura_cons_pop_x_pcm.csv",index_col=0)
fig,ax=plt.subplots(figsize=(LARG*0.7,LARG*0.45))
im=ax.imshow(ct.values*100,cmap=matplotlib.colors.LinearSegmentedColormap.from_list("p",PCM_RAMPA),vmin=0,vmax=100)
ax.set_xticks(range(5)); ax.set_xticklabels(["Q1 (menor)","Q2","Q3","Q4","Q5 (maior)"],fontsize=7.5); ax.set_yticks(range(5)); ax.set_yticklabels(["Q1 (menor)","Q2","Q3","Q4","Q5 (maior)"],fontsize=7.5)
ax.set_xlabel("Quintil de PCM",fontsize=8); ax.set_ylabel("Quintil de população de 0 a 4 anos",fontsize=8)
for i in range(5):
    for j in range(5):
        v=ct.values[i,j]*100; ax.text(j,i,f"{fmt_br(v,0)}%",ha="center",va="center",fontsize=7.5,color="white" if v>55 else TINTA)
for s in ax.spines.values(): s.set_visible(False)
ax.set_title("Gráfico S1. Municípios contemplados na consolidada por quintis de PCM e de população-alvo (%)",loc="left",fontsize=9,color=TINTA)
salvar(fig,OUT+"graficoS1_cobertura_quintis"); plt.close(fig)
print("graficos ok")
