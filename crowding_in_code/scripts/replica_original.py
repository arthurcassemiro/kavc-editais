# Replicacao do modelo final da dissertacao a partir dos arquivos originais (VAR_Trimestral.Rmd, ultima secao)
import pandas as pd, numpy as np, warnings
warnings.filterwarnings("ignore")
from statsmodels.tsa.api import VAR
idx=pd.period_range("2002Q1",periods=72,freq="Q")
L=pd.read_csv("data/original/0224_tri_estmeq.txt",sep=r"\s+"); L.index=idx      # INF, PVD em log10
X=pd.read_csv("data/original/0124_inexo.txt",sep=r"\s+"); X.index=idx           # PIB (var. trim.), JUR (nivel), DUM
ap=pd.read_csv("data/dados_dissertacao_apendiceA.csv"); ap.index=idx
print("Base do log de PVD vs apendice: 10^PVD(2002Q1)=",round(10**L.PVD.iloc[0],2),"| apendice imeq=",ap.imeq_indice.iloc[0])
print("corr dlog10(ipub apendice) vs dINF:",round(np.corrcoef(np.diff(np.log10(ap.ipub_rs)),np.diff(L.INF))[0,1],3))
print("corr dlog10(imeq apendice) vs dPVD:",round(np.corrcoef(np.diff(np.log10(ap.imeq_indice)),np.diff(L.PVD))[0,1],3))
print("Dummy=1 em:",list(X.index[X.DUM==1].astype(str)))
D=L.diff().dropna()
def fit(exog,trend="ct",p=3,label=""):
    m=VAR(D,exog=exog.loc[D.index] if exog is not None else None).fit(p,trend=trend)
    s=m.sigma_u.values; c=m.irf(40).orth_cum_effects
    print(f"{label:45s} var_INF={s[0,0]:.4f} cov={s[0,1]:.4f} var_PVD={s[1,1]:.4f} corr={s[0,1]/np.sqrt(s[0,0]*s[1,1]):.3f} "
          f"impacto={c[0,1,0]:.4f} acum40 PVD={c[40,1,0]:.4f} acum40 INF={c[40,0,0]:.4f} elast={c[40,1,0]/c[40,0,0]:.2f}")
    return m
print("\nAlvo (dissertacao): var_INF=0.0039 cov=0.0007 var_PVD=0.0008 corr=0.405 impacto=0.0118 acum40 PVD=0.0194")
m_a=fit(X.diff(),label="A: exog = diff(exo) [PIB, JUR, DUM]")
m_b=fit(X,label="B: exog = exo em nivel")
m_c=fit(X.diff()[["PIB","JUR"]],label="C: exog = diff(PIB, JUR), sem dummy")
m_d=fit(None,label="D: sem exogenas")
# Granger no VAR em NIVEIS com exo em nivel (var.est do Rmd): df2 = 116 bate com a Tabela 12
v=VAR(L,exog=X).fit(3,trend="ct")
for cause,eff in [("INF","PVD"),("PVD","INF")]:
    t=v.test_causality(eff,[cause],kind="f"); print(f"Granger {cause}->{eff} (VAR em NIVEL): F={t.test_statistic:.2f} p={t.pvalue:.3f} df={t.df}")
t=m_a.test_causality("PVD",["INF"],kind="f"); print(f"Granger INF->PVD (VAR em DIFERENCA, modelo A): F={t.test_statistic:.2f} p={t.pvalue:.3f} df={t.df}")
