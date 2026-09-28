import sys; sys.path.insert(0,"scripts")
from estilo import *
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import textwrap
OUT="06_diagramas/"
def box(ax,x,y,w,h,texto,fc="white",ec=GRAFITE,fs=7.5,bold=False,lw=0.9,wrap=None,tc=GRAFITE,align="center"):
    p=FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0,rounding_size=0.12",fc=fc,ec=ec,lw=lw); ax.add_patch(p)
    if wrap is None: wrap=max(12,int((w-0.6)/(fs*(0.0245 if bold else 0.0225))))
    texto=texto.replace("$","\\$")
    t="\n".join(textwrap.fill(l,wrap) for l in texto.split("\n"))
    if align=="center": ax.text(x+w/2,y+h/2,t,ha="center",va="center",fontsize=fs,fontweight="semibold" if bold else "normal",color=tc,linespacing=1.25)
    else: ax.text(x+0.25,y+h/2,t,ha="left",va="center",fontsize=fs,fontweight="semibold" if bold else "normal",color=tc,linespacing=1.25)
def arrow(ax,x0,y0,x1,y1,color=GRAFITE,lw=0.9,style="-|>",cs="arc3,rad=0"):
    ax.add_patch(FancyArrowPatch((x0,y0),(x1,y1),arrowstyle=style,mutation_scale=9,color=color,lw=lw,connectionstyle=cs,shrinkA=0,shrinkB=0))
def canvas(w,h):
    fig,ax=plt.subplots(figsize=(w,h)); ax.set_xlim(0,w*2.54); ax.set_ylim(0,h*2.54); ax.set_axis_off(); return fig,ax   # unidades em cm
# ---------------- D1: arquitetura do PCM ----------------
fig,ax=canvas(7.4,5.0)   # 18.8 x 12.7 cm
W,H=18.8,12.7
ax.text(0.2,H-0.35,"Figura 1. Arquitetura do Potencial de Creche por Município (PCM)",fontsize=10,fontweight="medium",color=GRAFITE,va="top")
cols=[("Fator educacional (FE)","Situação do ensino básico",[("Matrículas em creche / pop. 0–4 anos","Censo Escolar 2023; Censo 2022","peso 2, sentido inverso"),("Matrículas pré-escola e fundamental / pop. 5–14","Censo Escolar 2023; Censo 2022","peso 1, sentido inverso"),("Oferta privada / oferta total","Censo Escolar 2023","peso 1, sentido inverso")],"(2·a + b + c) / 4",PETROLEO),
      ("Fator demográfico (FD)","Perfil demográfico",[("Mortalidade infantil (óbitos < 1 ano por mil nascidos)","Datasus 2020","peso 1"),("População 0–4 anos / população total","Censo 2022","peso 1"),("Taxa de natalidade (por mil hab.)","Ipardes 2022","peso 1")],"(a + b + c) / 3",PETROLEO),
      ("Fator socioeconômico (FS)","Quadro socioeconômico",[("Desnutrição infantil (baixo peso para idade, 0–4 anos)","Ministério da Saúde 2023","peso 1"),("Crianças a acompanhar no CadÚnico / pop. 0–9 anos","Ministério da Saúde 2023","peso 1"),("IPDM renda, emprego e produção agropecuária","Ipardes 2021","peso 1, sentido inverso")],"(a + b + c) / 3",PETROLEO)]
cw=5.7; gap=0.45; x0=0.5; ytop=H-1.1
for i,(nome,sub,inds,formula,cor) in enumerate(cols):
    x=x0+i*(cw+gap)
    for j,(ind,fonte,peso) in enumerate(inds):
        y=ytop-0.55-j*1.35
        box(ax,x,y-1.05,cw,1.05,f"{ind}\n{fonte} · {peso}",fc="#f4f6f7",ec="#c9d3d6",fs=6.4,wrap=44)
    # normalização
    yn=ytop-0.55-3*1.35-0.25
    box(ax,x,yn-0.75,cw,0.75,"Normalização mín–máx (0–100) de cada indicador",fc="white",ec=GRAFITE_CLARO,fs=6.6)
    for j in range(3):
        arrow(ax,x+cw/2,ytop-0.55-j*1.35-1.05,x+cw/2,yn if j==2 else ytop-0.55-(j+1)*1.35, color=GRAFITE_CLARO,lw=0.7)
    yf=yn-0.75-0.6
    box(ax,x,yf-1.15,cw,1.15,f"{nome}\nmédia ponderada {formula}, reescalada 0–100",fc=cor,ec=cor,fs=7,bold=True,tc="white",wrap=40)
    arrow(ax,x+cw/2,yn-0.75,x+cw/2,yf,color=GRAFITE_CLARO,lw=0.7)
    ax.text(x+cw/2,ytop-0.15,sub,ha="center",va="center",fontsize=7.5,color=GRAFITE,fontweight="medium")
# PCM
yp=0.35; 
box(ax,x0+1.5,yp,3*cw+2*gap-3.0,1.35,"PCM = (2·FE + FD + 2·FS) / 5 / 100, valor entre 0 e 1 (observado: 0,24 a 0,79)\nVariante usada apenas na faixa P3 da distribuição consolidada: (1·FE + FD + 3·FS) / 5 / 100",fc=VERDE,ec=VERDE,fs=7,bold=True,tc="white")
for i in range(3):
    x=x0+i*(cw+gap)+cw/2
    arrow(ax,x,yf-1.15,x0+cw+gap+cw/2+(i-1)*3.5,yp+1.35,color=GRAFITE,lw=0.9)
ax.text(x0,yf-1.15-0.32,"peso 2",fontsize=6.5,color=GRAFITE_CLARO); ax.text(x0+cw+gap,yf-1.15-0.32,"peso 1",fontsize=6.5,color=GRAFITE_CLARO); ax.text(x0+2*(cw+gap),yf-1.15-0.32,"peso 2",fontsize=6.5,color=GRAFITE_CLARO)
fig.text(0.01,0.005,"Fonte: Elaboração própria a partir das planilhas Indicador_Criterio_VF e 20240327_Distribuicao_Creches e da apresentação do programa. Sentido inverso: quanto maior a cobertura ou a renda, menor o escore.",fontsize=6.3,color=GRAFITE_CLARO)
salvar(fig,OUT+"diagrama01_arquitetura_pcm"); plt.close(fig)
# ---------------- D2: regra de conversão ----------------
fig,ax=canvas(7.4,5.9); W,H=18.8,15.0
ax.text(0.2,H-0.35,"Figura 2. Regra de conversão do PCM em creches na distribuição consolidada (300 unidades)",fontsize=10,fontweight="medium",color=GRAFITE,va="top")
box(ax,0.5,H-2.1,17.8,1.05,"Entradas por município: população total 2022 (define o porte), população-alvo 0–4 anos, PCM, creches já atribuídas na etapa prévia (43 unidades)",fc="#f4f6f7",ec="#c9d3d6",fs=7.2)
box(ax,4.9,H-3.75,9.0,1.05,"Classificação em oito portes (G2, G1, M2, M1, P4, P3, P2, P1)\ne definição de cotas por bloco",fc=PETROLEO,ec=PETROLEO,fs=7.2,bold=True,tc="white")
arrow(ax,9.4,H-2.1,9.4,H-2.7)
# ramo grandes
xl=0.5; wl=8.4; xr=9.9; wr=8.4; yb=H-4.5
ax.text(xl+wl/2,yb-0.1,"Portes G2 a P4 (30 municípios, 100 creches)",ha="center",fontsize=7.8,fontweight="semibold",color=GRAFITE)
ax.text(xr+wr/2,yb-0.1,"Portes P3, P2 e P1 (369 municípios, 157 creches)",ha="center",fontsize=7.8,fontweight="semibold",color=GRAFITE)
arrow(ax,6.5,H-3.75,xl+wl/2,yb-0.35,cs="arc3,rad=0.15"); arrow(ax,12.3,H-3.75,xr+wr/2,yb-0.35,cs="arc3,rad=-0.15")
stepsL=[("1. Cota populacional",  "J = (pop. 0–4 do município / pop. 0–4 do porte) × ponderação do porte (parcela da população-alvo × total ajustado)"),
        ("2. Correção pelo PCM",  "K = J × (1 + PCM) − creches da etapa prévia"),
        ("3. Arredondamento",     "parte inteira de K; unidades restantes distribuídas às maiores frações (maior resto)"),
        ("4. Tetos por porte",    "G2: 10 · G1: 8 · M2: 7 · M1: 4 · P4: 2 creches por município; excedente redistribuído até fechar 100")]
stepsR=[("1. Exclusão",           "municípios já contemplados na etapa prévia não entram no ranking"),
        ("2. Ordenação pelo PCM", "P3 usa a variante (1·FE + FD + 3·FS)/5; P2 e P1 usam o PCM padrão"),
        ("3. Cotas por porte",    "P3: 27 de 62 municípios · P2: 100 de 205 · P1: 30 de 102 (uma creche cada)"),
        ("4. Resultado",          "157 municípios com uma creche; os demais ficam fora nesta etapa")]
for i,(t,d) in enumerate(stepsL):
    y=yb-0.55-i*1.7
    box(ax,xl,y-1.45,wl,1.45,f"{t}\n{d}",fc="white",ec=PETROLEO,fs=6.6)
    if i<3: arrow(ax,xl+wl/2,y-1.45,xl+wl/2,y-1.7,color=GRAFITE_CLARO,lw=0.7)
for i,(t,d) in enumerate(stepsR):
    y=yb-0.55-i*1.7
    box(ax,xr,y-1.45,wr,1.45,f"{t}\n{d}",fc="white",ec=VERDE,fs=6.6)
    if i<3: arrow(ax,xr+wr/2,y-1.45,xr+wr/2,y-1.7,color=GRAFITE_CLARO,lw=0.7)
yend=yb-0.55-3*1.7-1.45-0.5
box(ax,0.5,yend-1.25,17.8,1.25,"Distribuição consolidada: 43 (etapa prévia) + 100 (portes grandes) + 157 (ranking nos portes pequenos) = 300 creches em 224 municípios",fc=VERDE,ec=VERDE,fs=7.2,bold=True,tc="white")
arrow(ax,xl+wl/2,yb-0.55-3*1.7-1.45,xl+wl/2,yend); arrow(ax,xr+wr/2,yb-0.55-3*1.7-1.45,xr+wr/2,yend)
fig.text(0.01,0.005,"Fonte: Elaboração própria a partir das abas Metodologia, Dados e Resultados da planilha 20240327_Distribuicao_Creches. O passo 4 do bloco grande reproduz 28 dos 30 valores observados; a regra do bloco pequeno reproduz os 157 casos.",fontsize=6.3,color=GRAFITE_CLARO)
salvar(fig,OUT+"diagrama02_regra_conversao"); plt.close(fig)
print("D1, D2 ok")
# ---------------- D3: da etapa técnica à execução ----------------
fig,ax=canvas(7.4,6.2); W,H=18.8,15.7
ax.text(0.2,H-0.35,"Figura 3. Da distribuição técnica à execução: etapas, decisões e marcos",fontsize=10,fontweight="medium",color=GRAFITE,va="top")
etapas=[
 ("Base de dados e PCM","Nove indicadores (Censo 2022, Censo Escolar 2023, Datasus, CadÚnico, IPDM); três fatores; PCM = (2·FE + FD + 2·FS)/5/100 para 399 municípios","#f4f6f7","#c9d3d6",GRAFITE),
 ("Distribuição técnica inicial","Oito portes (P1 até 20 mil hab.); fórmula L = [J·(1+PCM) + 3·(PCM + K)]/4 e maior resto; 251 creches em 209 municípios; piso quase uniforme por município",PETROLEO,PETROLEO,"white"),
 ("Distribuição consolidada (planilha de 27/03/2024)","Etapa prévia de 43 unidades (índice de prioridade do Ipardes) + 100 para os 30 municípios grandes (cota populacional × (1+PCM), tetos) + 157 por ranking do PCM em P3, P2 e P1 (portes reclassificados); 300 creches em 224 municípios",VERDE,VERDE,"white"),
 ("Lista publicada (Deliberação CEDCA 25/2024, de 24/05; Resolução SEDEF 219/2024, de 04/06/2024)","Anexo I com 303 creches em 261 municípios: 17 municípios grandes cedem 37 unidades; 37 municípios entram com uma unidade, todos logo abaixo da linha de corte do ranking em seu porte; nenhum município selecionado é retirado",LARANJA,LARANJA,"white"),
 ("Habilitação (jun/2024 a 2025)","Adesão no sistema fundo a fundo até 19/06/2024; terreno de 1.200 m², projeto padrão de 456,86 m², conselho e fundo municipais ativos; 11 vagas remanescentes reofertadas em 24/06/2024; prazos prorrogados três vezes em 2024; segunda etapa em 2025 (108 unidades, 100 municípios)","white",GRAFITE,GRAFITE),
 ("Licitação e obras (2025 a 2026)","Teto por unidade de R$ 1,30 milhão (2024) a R$ 1,99 milhão (2025); Paranacidade analisa projetos e autoriza licitação; 52 licitações autorizadas em ago/2025, 107 em out/2025; 48 obras em fev/2026 e 110 obras em 106 municípios em mai/2026","white",GRAFITE,GRAFITE),
 ("Entregas","Nenhuma unidade concluída localizada em fonte oficial até set/2026; obra mais adiantada com 54% em mai/2026","#f4f6f7","#c9d3d6",GRAFITE)]
y=H-1.2; hbox=[1.25,1.55,1.85,1.85,1.85,1.7,1.1]
for i,(t,d,fc,ec,tc) in enumerate(etapas):
    hb=hbox[i]
    box(ax,0.6,y-hb,17.6,hb,f"{t}\n{d}",fc=fc,ec=ec,fs=6.8,tc=tc,bold=False)
    ax.text(0.6+0.25,y-0.28,t,fontsize=7.2,fontweight="semibold",color=tc,va="center",ha="left") if False else None
    if i<len(etapas)-1: arrow(ax,9.4,y-hb,9.4,y-hb-0.3,color=GRAFITE,lw=0.9)
    y=y-hb-0.3
fig.text(0.01,0.005,"Fonte: Elaboração própria a partir das planilhas do PCM, da Deliberação CEDCA 25/2024, das Resoluções SEDEF 212, 219 e 285/2024, 029, 075 e 479/2025 e de notícias da Agência Estadual de Notícias (2024 a 2026).",fontsize=6.3,color=GRAFITE_CLARO)
salvar(fig,OUT+"diagrama03_etapas_execucao"); plt.close(fig)
print("D3 ok")
