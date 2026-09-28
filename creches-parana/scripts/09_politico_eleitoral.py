"""Análise exploratória político-eleitoral (executar quando os CSV do TSE estiverem em 02_base_tratada/tse/).
Entradas esperadas (Repositório de Dados Eleitorais do TSE, arquivos por UF, latin-1, separador ';'):
  02_base_tratada/tse/votacao_candidato_munzona_2020_PR.csv
  02_base_tratada/tse/votacao_candidato_munzona_2022_PR.csv
Saídas: 03_resultados/T9_politico_eleitoral.csv"""
import pandas as pd, numpy as np, os, sys
from scipy import stats
B="02_base_tratada/"; T=B+"tse/"
if not (os.path.exists(T+"votacao_candidato_munzona_2020_PR.csv") and os.path.exists(T+"votacao_candidato_munzona_2022_PR.csv")):
    sys.exit("Arquivos do TSE ausentes; ver 07_log/log_metodologico.md")
b=pd.read_csv(B+"base_municipal.csv")
def ler(p): return pd.read_csv(p,sep=";",encoding="latin-1",low_memory=False)
v20=ler(T+"votacao_candidato_munzona_2020_PR.csv"); v22=ler(T+"votacao_candidato_munzona_2022_PR.csv")
# prefeito eleito 2020 (situação de totalização ELEITO), partido
p=v20[(v20.DS_CARGO.str.upper()=="PREFEITO")&(v20.DS_SIT_TOT_TURNO.str.upper().str.startswith("ELEITO"))]
p=p.groupby(["CD_MUNICIPIO","NM_MUNICIPIO","SG_PARTIDO"],as_index=False).QT_VOTOS_NOMINAIS.sum().sort_values("QT_VOTOS_NOMINAIS",ascending=False).drop_duplicates("CD_MUNICIPIO")
# governador 2022, 1º turno, percentual do candidato mais votado no estado
g=v22[(v22.DS_CARGO.str.upper()=="GOVERNADOR")&(v22.NR_TURNO==1)]
gm=g.groupby(["CD_MUNICIPIO","NM_MUNICIPIO","NM_URNA_CANDIDATO"],as_index=False).QT_VOTOS_NOMINAIS.sum()
tot=gm.groupby("CD_MUNICIPIO").QT_VOTOS_NOMINAIS.sum().rename("tot")
venc=gm.groupby("NM_URNA_CANDIDATO").QT_VOTOS_NOMINAIS.sum().idxmax()
gv=gm[gm.NM_URNA_CANDIDATO==venc].merge(tot,on="CD_MUNICIPIO"); gv["pct_gov"]=gv.QT_VOTOS_NOMINAIS/gv.tot*100
# junção por nome normalizado (TSE usa código próprio); recomenda-se tabela de correspondência TSE-IBGE
import unicodedata,re
def norm(s): return re.sub(r"\s+"," ",unicodedata.normalize("NFKD",str(s)).encode("ascii","ignore").decode().upper().strip())
b["key"]=b.mun.map(norm); p["key"]=p.NM_MUNICIPIO.map(norm); gv["key"]=gv.NM_MUNICIPIO.map(norm)
m=b.merge(p[["key","SG_PARTIDO"]],on="key",how="left").merge(gv[["key","pct_gov"]],on="key",how="left")
m["prefeito_mesmo_partido_gov"]=(m.SG_PARTIDO==p.SG_PARTIDO.mode()[0]).astype(int)  # ajustar para o partido do governador
rows=[]
for var in ["contemplado_cons","cons_total300","creches_por_10mil_04_cons","dif_cons_tec"]:
    a=m.loc[m.prefeito_mesmo_partido_gov==1,var].dropna(); c=m.loc[m.prefeito_mesmo_partido_gov==0,var].dropna()
    rows.append({"variavel":var,"media_mesmo_partido":a.mean(),"media_outros":c.mean(),"p_mannwhitney":stats.mannwhitneyu(a,c).pvalue,"spearman_pct_gov":stats.spearmanr(m[var],m.pct_gov,nan_policy="omit").statistic})
pd.DataFrame(rows).to_csv("03_resultados/T9_politico_eleitoral.csv",index=False); print(pd.DataFrame(rows))
