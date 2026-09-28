# Robustez rapida em torno do baseline replicado (modelo A). Intervalos por simulacao Monte Carlo do statsmodels (indicativos).
import pandas as pd, numpy as np, warnings
warnings.filterwarnings("ignore")
from statsmodels.tsa.api import VAR
idx=pd.period_range("2002Q1",periods=72,freq="Q")
L=pd.read_csv("data/original/0224_tri_estmeq.txt",sep=r"\s+"); L.index=idx
X=pd.read_csv("data/original/0124_inexo.txt",sep=r"\s+"); X.index=idx
D=L.diff().dropna()
dum_txt=pd.Series((idx>=pd.Period("2018Q3")).astype(float),index=idx)   # dummy como descrita no texto (nivel)
rng=np.random.default_rng(42)
def run(label,Y,exog,p=3,trend="ct",order=None,reps=500):
    Y=Y.copy()
    if order: Y=Y[order]
    ex=exog.loc[Y.index] if exog is not None else None
    m=VAR(Y,exog=ex).fit(p,trend=trend)
    i,j=list(Y.columns).index("INF"),list(Y.columns).index("PVD")
    irf=m.irf(40); c=irf.orth_cum_effects
    # bootstrap de residuos (recursivo, exogenas fixas, valores iniciais observados)
    Yv=Y.values; T,K=Yv.shape; U=m.resid.values; U=U-U.mean(0)
    fitted=m.fittedvalues.values
    detx=m.endog_lagged if False else None
    rp=[];el=[]
    coefs=m.coefs; # (p,K,K)
    # componente deterministico+exogeno por periodo = fitted - parte autoregressiva
    ar=np.zeros_like(fitted)
    for t in range(p,T):
        ar[t-p]=sum(coefs[l]@Yv[t-l-1] for l in range(p))
    det=fitted-ar
    for r in range(reps):
        e=U[rng.integers(0,len(U),len(U))]
        Ys=Yv.copy()
        for t in range(p,T):
            Ys[t]=det[t-p]+sum(coefs[l]@Ys[t-l-1] for l in range(p))+e[t-p]
        try:
            mb=VAR(pd.DataFrame(Ys,index=Y.index,columns=Y.columns),exog=ex).fit(p,trend=trend)
            cb=mb.irf(40).orth_cum_effects
            rp.append(cb[40,j,i]); el.append(cb[40,j,i]/cb[40,i,i])
        except Exception: pass
    rp=np.array(rp); el=np.array(el)
    g=m.test_causality("PVD",["INF"],kind="f").pvalue
    return dict(modelo=label,granger_p=round(g,3),resp_acum_40=round(c[40,j,i],4),
                ic90_resp=f"[{np.percentile(rp,5):.4f}, {np.percentile(rp,95):.4f}]",
                elasticidade=round(c[40,j,i]/c[40,i,i],2),
                ic90_elast=f"[{np.percentile(el,5):.2f}, {np.percentile(el,95):.2f}]")
dx=X.diff()
rows=[
 run("A. Baseline replicado",D,dx),
 run("Ordem inversa (PVD antes de INF)",D,dx,order=["PVD","INF"]),
 run("Exogenas em nivel (nao diferenciadas)",D,X),
 run("Dummy como no texto (nivel, 2018T3-2019T4)",D,pd.DataFrame({"dPIB":dx.PIB,"dJUR":dx.JUR,"dum":dum_txt})),
 run("Sem dummy",D,dx[["PIB","JUR"]]),
 run("PIB em nivel de crescimento, Selic em diferenca, sem dummy",D,pd.DataFrame({"PIB":X.PIB,"dJUR":dx.JUR})),
 run("Sem tendencia (so constante)",D,dx,trend="c"),
 run("2 defasagens",D,dx,p=2),
 run("4 defasagens",D,dx,p=4),
 run("PIB endogeno (VAR INF, PIB, PVD), Selic dif.",pd.concat([D.INF,X.PIB.loc[D.index],D.PVD],axis=1),pd.DataFrame({"dJUR":dx.JUR})),
]
out=pd.DataFrame(rows); pd.set_option("display.width",220); print(out.to_string(index=False))
out.to_csv("results/robustez_rapida.csv",index=False)
