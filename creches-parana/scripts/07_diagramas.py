"""Diagramas (revisão editorial): 16 cm, corpo >= 7 pt, caixas com altura automática e margem interna,
setas terminando na borda, cores dos pilares (FE laranja, FD azul, FS verde), PCM roxo, etapas em cinzas."""
import sys; sys.path.insert(0,"scripts")
from estilo import *
import matplotlib.pyplot as plt, textwrap
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
OUT="06_diagramas/"
LH=0.0353*1.25   # altura de linha em cm por pt
def canvas(wcm,hcm):
    fig,ax=plt.subplots(figsize=(wcm*CM,hcm*CM)); ax.set_xlim(0,wcm); ax.set_ylim(0,hcm); ax.set_axis_off(); return fig,ax
def quebrar(texto,w,fs,bold,pad):
    cpp=fs*(0.0235 if bold else 0.0215)
    wrap=max(10,int((w-2*pad)/cpp)); return "\n".join(textwrap.fill(l,wrap) for l in texto.split("\n"))
def box(ax,x,ytop,w,texto,fc="white",ec=TINTA,fs=7,bold=False,tc=TINTA,lw=0.6,pad=0.25,hmin=0.0):
    """Desenha caixa com o topo em ytop e altura automática; devolve o y da base."""
    t=quebrar(texto,w,fs,bold,pad); n=t.count("\n")+1
    h=max(hmin,n*fs*LH+2*pad*0.8)
    ax.add_patch(FancyBboxPatch((x,ytop-h),w,h,boxstyle="round,pad=0,rounding_size=0.1",fc=fc,ec=ec,lw=lw))
    ax.text(x+w/2,ytop-h/2,t,ha="center",va="center",fontsize=fs,fontweight="bold" if bold else "normal",color=tc,linespacing=1.15)
    return ytop-h
def seta(ax,x0,y0,x1,y1,color=TINTA,lw=0.6):
    ax.add_patch(FancyArrowPatch((x0,y0),(x1,y1),arrowstyle="-|>",mutation_scale=7,color=color,lw=lw,shrinkA=0,shrinkB=0))
# ---------------- Figura 1 ----------------
W,H=16,11.2; fig,ax=canvas(W,H)
ax.text(0,H-0.05,"Figura 1. Arquitetura do Potencial de Creche por Município (PCM)",fontsize=9,color=TINTA,va="top")
cw=5.0; gap=0.5
pil=[("Situação do ensino básico",FE_ESC,FE_RAMPA[0],["Matrículas em creche / pop. de 0 a 4 anos. Censo Escolar 2023; Censo 2022. Peso 2, sentido inverso","Matrículas em pré-escola e fundamental / pop. de 5 a 14 anos. Censo Escolar 2023; Censo 2022. Peso 1, sentido inverso","Oferta privada / oferta total. Censo Escolar 2023. Peso 1, sentido inverso"],"Fator educacional (FE): (2·a + b + c)/4, reescalado de 0 a 100","peso 2 no PCM"),
     ("Perfil demográfico",FD_ESC,FD_RAMPA[0],["Mortalidade infantil (óbitos até 1 ano por mil nascidos vivos). Datasus 2020. Peso 1","População de 0 a 4 anos / população total. Censo 2022. Peso 1","Taxa de natalidade por mil habitantes. Ipardes 2022. Peso 1"],"Fator demográfico (FD): (a + b + c)/3, reescalado de 0 a 100","peso 1 no PCM"),
     ("Quadro socioeconômico",FS_ESC,FS_RAMPA[0],["Desnutrição infantil (baixo peso para a idade, 0 a 4 anos). Ministério da Saúde 2023. Peso 1","Crianças a acompanhar no CadÚnico / pop. de 0 a 9 anos. Ministério da Saúde 2023. Peso 1","IPDM renda, emprego e produção agropecuária. Ipardes 2021. Peso 1, sentido inverso"],"Fator socioeconômico (FS): (a + b + c)/3, reescalado de 0 a 100","peso 2 no PCM")]
ytop=H-0.65; ybase=[]
for i,(tit,esc,claro,inds,fator,peso) in enumerate(pil):
    x=i*(cw+gap); y=box(ax,x,ytop,cw,tit,fc=esc,ec=esc,fs=8,bold=True,tc="white")
    for ind in inds: y=box(ax,x,y-0.12,cw,ind,fc=claro,ec=claro,fs=7,hmin=1.05)
    ybase.append(y)
y=min(ybase)-0.3
ynorm=box(ax,0,y,W,"Normalização mínimo–máximo de cada indicador, de 0 a 100",fc="#F2F2F2",ec=BORDA,fs=7.5)
yf=ynorm-0.35; ybf=[]
for i,(tit,esc,claro,inds,fator,peso) in enumerate(pil):
    x=i*(cw+gap); seta(ax,x+cw/2,ynorm,x+cw/2,yf)
    yb=box(ax,x,yf,cw,fator,fc=esc,ec=esc,fs=7.5,bold=True,tc="white",hmin=0.9); ybf.append(yb)
    ax.text(x+cw/2,yb-0.2,peso,ha="center",va="center",fontsize=7,color=TINTA)
ybar=min(ybf)-0.45
ax.plot([cw/2,2*(cw+gap)+cw/2],[ybar,ybar],color=TINTA,lw=0.6)
for i in range(3): ax.plot([i*(cw+gap)+cw/2]*2,[min(ybf)-0.35,ybar],color=TINTA,lw=0.6)
ypcm=ybar-0.3; seta(ax,W/2,ybar,W/2,ypcm)
yend=box(ax,1.5,ypcm,W-3,"PCM = (2·FE + FD + 2·FS)/5/100, entre 0 e 1 (observado: 0,240 a 0,789)\nVariante usada só na faixa P3 da consolidada: (1·FE + FD + 3·FS)/5/100",fc=PCM_ESC,ec=PCM_ESC,fs=7.5,bold=True,tc="white")
ax.set_ylim(yend-0.2,H)
fig.text(0,0,"Fonte: Elaboração própria a partir das planilhas do PCM, da apresentação do programa e da Resolução SEDEF 219/2024.",fontsize=7,color=TINTA2,va="top")
salvar(fig,OUT+"diagrama01_arquitetura_pcm"); plt.close(fig)
# ---------------- Figura 2 ----------------
W,H=16,12.5; fig,ax=canvas(W,H)
ax.text(0,H-0.05,"Figura 2. Regra de conversão do PCM em creches na distribuição consolidada (300 unidades)",fontsize=9,color=TINTA,va="top")
y=box(ax,0,H-0.65,W,"Entradas por município: população total de 2022 (define o porte), população-alvo, PCM e creches já atribuídas na etapa prévia (43 unidades)",fc="#F2F2F2",ec=BORDA,fs=7.5)
seta(ax,W/2,y,W/2,y-0.3); y=box(ax,3.5,y-0.3,9,"Classificação em oito portes e definição de cotas por bloco",fc=CINZAS[1],ec=CINZAS[1],fs=8,bold=True,tc="white")
wl=7.7; xr=W-wl; ytop=y-0.4
seta(ax,6.5,y,wl/2,ytop); seta(ax,9.5,y,xr+wl/2,ytop)
yl=box(ax,0,ytop,wl,"Portes G2 a P4: 30 municípios, 100 creches",fc=CINZAS[0],ec=CINZAS[0],fs=7.5,bold=True,tc="white")
yr=box(ax,xr,ytop,wl,"Portes P3, P2 e P1: 369 municípios, 157 creches",fc=CINZAS[0],ec=CINZAS[0],fs=7.5,bold=True,tc="white")
esq=["1. Cota populacional: J = parcela do município na população-alvo do porte × cota do porte",
     "2. Correção pelo PCM: K = J × (1 + PCM), descontadas as creches da etapa prévia",
     "3. Arredondamento: parte inteira de K; unidades restantes às maiores frações (maior resto)",
     "4. Tetos por município: G2 10, G1 8, M2 7, M1 4 e P4 2; excedente redistribuído até fechar 100"]
dir_=["1. Exclusão: municípios já contemplados na etapa prévia não entram no ranking",
      "2. Ordenação pelo PCM dentro do porte: P3 usa a variante (1·FE + FD + 3·FS)/5/100; P2 e P1 usam o PCM padrão",
      "3. Cotas por porte: P3, 27 de 62 municípios; P2, 100 de 205; P1, 30 de 102 (uma creche cada)",
      "4. Resultado: 157 municípios com uma creche; os demais ficam fora nesta etapa"]
for i in range(4):
    seta(ax,wl/2,yl,wl/2,yl-0.3); seta(ax,xr+wl/2,yr,xr+wl/2,yr-0.3)
    yl=box(ax,0,yl-0.3,wl,esq[i],fc="white",ec=CINZAS[1],fs=7,hmin=0.95); yr=box(ax,xr,yr-0.3,wl,dir_[i],fc="white",ec=CINZAS[1],fs=7,hmin=0.95)
yb=min(yl,yr); seta(ax,wl/2,yl,wl/2,yb-0.35); seta(ax,xr+wl/2,yr,xr+wl/2,yb-0.35)
yend=box(ax,0,yb-0.35,W,"Distribuição consolidada: 43 (etapa prévia) + 100 (portes grandes) + 157 (ranking nos portes pequenos) = 300 creches em 224 municípios",fc=CINZAS[2],ec=CINZAS[2],fs=7.5,bold=True,tc="white")
ax.set_ylim(yend-0.2,H)
fig.text(0,0,"Fonte: Elaboração própria a partir da planilha de 27/03/2024 (abas Metodologia, Dados e Resultados).",fontsize=7,color=TINTA2,va="top")
salvar(fig,OUT+"diagrama02_regra_conversao"); plt.close(fig)
# ---------------- Figura S1 (suplementar) ----------------
W,H=16,13; fig,ax=canvas(W,H)
ax.text(0,H-0.05,"Figura S1. Da distribuição técnica à execução: etapas, decisões e marcos",fontsize=9,color=TINTA,va="top")
etapas=[("Base de dados e PCM: nove indicadores, três fatores, PCM para 399 municípios","#F2F2F2",BORDA,TINTA),
 ("Distribuição técnica inicial: fórmula com piso quase uniforme por município e maior resto; 251 creches em 209 municípios",CINZAS[0],CINZAS[0],"white"),
 ("Distribuição consolidada (planilha de 27/03/2024): etapa prévia de 43 + 100 aos portes grandes com tetos + 157 por ranking nos portes pequenos; 300 creches em 224 municípios",CINZAS[1],CINZAS[1],"white"),
 ("Lista publicada (Deliberação CEDCA 25/2024; Resolução SEDEF 219/2024): 303 creches em 261 municípios; 17 municípios grandes cedem 37 unidades e 37 municípios entram logo abaixo da linha de corte",ACENTO,ACENTO,"white"),
 ("Habilitação (jun/2024 a 2025): adesão até 19/06/2024; terreno de 1.200 m², projeto padrão de 456,86 m²; vagas remanescentes reofertadas; prazos prorrogados; segunda etapa com 108 unidades em 2025","white",TINTA,TINTA),
 ("Licitação e obras (2025 a 2026): teto de R$ 1,30 milhão a R$ 1,99 milhão por unidade; Paranacidade autoriza licitação; 52 licitações em ago/2025, 107 em out/2025; 48 obras em fev/2026 e 110 em mai/2026","white",TINTA,TINTA),
 ("Entregas: nenhuma unidade concluída localizada em fonte oficial até set/2026; obra mais adiantada com 54% em mai/2026","#F2F2F2",BORDA,TINTA)]
y=H-0.65
for k,(t,fc,ec,tc) in enumerate(etapas):
    y=box(ax,0,y,W,t,fc=fc,ec=ec,fs=7.5,tc=tc,hmin=0.8)
    if k<len(etapas)-1: seta(ax,W/2,y,W/2,y-0.3); y=y-0.3
ax.set_ylim(y-0.2,H)
fig.text(0,0,"Fonte: Elaboração própria a partir das planilhas do PCM, da Deliberação CEDCA 25/2024, das Resoluções SEDEF 212, 219 e 285/2024, 029, 075 e 479/2025 e de notícias da Agência Estadual de Notícias (2024 a 2026).",fontsize=7,color=TINTA2,va="top")
salvar(fig,OUT+"diagramaS1_etapas_execucao"); plt.close(fig)
print("diagramas ok")
