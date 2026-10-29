"""Números de apoio à revisão (parecer RPD): contrafactual populacional, sensibilidade a pesos e normalização,
efeito dos pesos sobre a seleção territorial."""
import sys, pandas as pd, numpy as np
# uso (na raiz de creches-parana): python3 10_revisao_parecer/scripts/13_numeros_parecer.py 02_base_tratada/base_municipal.csv
B=sys.argv[1] if len(sys.argv)>1 else "02_base_tratada/base_municipal.csv"
b=pd.read_csv(B)
def mm(x): return (x-x.min())/(x.max()-x.min())*100
def pct(x): return x.rank(pct=True,method="average")*100
def sp(a,c): return pd.Series(a).rank().corr(pd.Series(c).rank())
N=["creche_norm","mat_norm","priv_norm","mi_norm","prop04_norm","nat_norm","desnut_norm","cad_norm","ipdm_norm"]
# --- correlações entre pilares e com o PCM
print("Spearman pilares x PCM:", {k:round(sp(b[k],b.pcm_padrao),3) for k in ["fe","fd","fs"]})
print("Spearman entre pilares:", {"fe-fd":round(sp(b.fe,b.fd),3),"fe-fs":round(sp(b.fe,b.fs),3),"fd-fs":round(sp(b.fd,b.fs),3)})
print("Pearson entre pilares:", {"fe-fd":round(b.fe.corr(b.fd),3),"fe-fs":round(b.fe.corr(b.fs),3),"fd-fs":round(b.fd.corr(b.fs),3)})
print("PCM x pop spearman", round(sp(b.pcm_padrao,b["pop"]),3), "pearson", round(b.pcm_padrao.corr(b["pop"]),3))
print("PCM desc", b.pcm_padrao.describe().round(3).to_dict())
# --- variantes de peso
V={"padrao (2,1,2)":(2,1,2),"iguais (1,1,1)":(1,1,1),"FS triplo (1,1,3)":(1,1,3),"FE triplo (3,1,1)":(3,1,1),"FD duplo (1,2,1)":(1,2,1),"(2,2,1)":(2,2,1),"(1,2,2)":(1,2,2)}
pcmv={k:(w[0]*b.fe+w[1]*b.fd+w[2]*b.fs)/(100*sum(w)) for k,w in V.items()}
top80=set(b.nlargest(80,"pcm_padrao").index)
for k,v in pcmv.items():
    t=set(v.nlargest(80).index)
    print(f"{k:20s} rho={sp(v,b.pcm_padrao):.3f}  top80 mantidos={len(t&top80)}")
# --- normalização por percentis (indicadores e fatores)
fe_p=pct((2*pct(b.creche_norm)+pct(b.mat_norm)+pct(b.priv_norm))/4)
fd_p=pct((pct(b.mi_norm)+pct(b.prop04_norm)+pct(b.nat_norm))/3)
fs_p=pct((pct(b.desnut_norm)+pct(b.cad_norm)+pct(b.ipdm_norm))/3)
p1=(2*fe_p+fd_p+2*fs_p)/500
fe_q=mm((2*pct(b.creche_norm)+pct(b.mat_norm)+pct(b.priv_norm))/4)
fd_q=mm((pct(b.mi_norm)+pct(b.prop04_norm)+pct(b.nat_norm))/3)
fs_q=mm((pct(b.desnut_norm)+pct(b.cad_norm)+pct(b.ipdm_norm))/3)
p2=(2*fe_q+fd_q+2*fs_q)/500
for nm,p in [("percentil (ind+fatores)",p1),("percentil ind, minmax fatores",p2)]:
    t=set(p.nlargest(80).index); print(f"{nm:32s} rho={sp(p,b.pcm_padrao):.3f} top80={len(t&top80)}")
# --- qualidade dos dados do fator demográfico (mortalidade infantil em municípios pequenos)
b["nasc"]=b.natalidade*b["pop"]/1000
print("mortalidade infantil zero:", int((b.mort_inf==0).sum()), "de", len(b), "| P1:", int(((b.porte_dc=="P1")&(b.mort_inf==0)).sum()), "de", int((b.porte_dc=="P1").sum()))
p1n=b.loc[b.porte_dc=="P1","nasc"].median(); print("P1: nascimentos medianos", round(p1n,1), "-> um óbito =", round(1000/p1n,1), "por mil | média municipal da taxa", round(b.mort_inf.mean(),1))
# --- seleção nos portes pequenos sob pesos alternativos (regra de maio: mesmas cotas 27/100/30, excluída etapa prévia)
prev=b.cons_prev43>0
cot={"P3":27,"P2":100,"P1":30}
def sel(score):
    s=set()
    for pt,n in cot.items():
        m=(b.porte_dc==pt)&~prev
        s|=set(score[m].nlargest(n).index)
    return s
base_sel=sel(b.pcm_padrao)
# confere com cons_pcm257 nos pequenos (rodada de março usou pcm_p3 em P3)
obs=set(b.index[(b.cons_pcm257>0)&b.porte_dc.isin(list(cot))])
print("seleção padrão = observada (março)?", len(base_sel&obs), "de", len(obs), "| com pcm_p3 em P3:", end=" ")
sc=b.pcm_padrao.where(b.porte_dc!="P3", b.pcm_p3); print(len(sel(sc)&obs))
for k,v in pcmv.items():
    s=sel(v); print(f"seleção 157 sob {k:20s}: mantidos {len(s&base_sel)} | trocas {157-len(s&base_sel)}")
for nm,p in [("percentil (ind+fatores)",p1),("percentil ind, minmax fatores",p2)]:
    s=sel(p); print(f"seleção 157 sob {nm:30s}: mantidos {len(s&base_sel)}")
# por faixa, sob pesos iguais
for pt,n in cot.items():
    m=(b.porte_dc==pt)&~prev
    a=set(b.pcm_padrao[m].nlargest(n).index); c=set(pcmv["iguais (1,1,1)"][m].nlargest(n).index); d=set(pcmv["FS triplo (1,1,3)"][m].nlargest(n).index)
    print(pt, "elegíveis", int(m.sum()), "cota", n, "mantidos iguais", len(a&c), "mantidos FS3", len(a&d))
# --- linhas de corte por faixa (PCM padrão)
for pt,n in cot.items():
    m=(b.porte_dc==pt)&~prev; s=b.pcm_padrao[m].sort_values(ascending=False)
    print(pt,"último contemplado",round(s.iloc[n-1],4),"primeiro excluído",round(s.iloc[n],4))
# --- contrafactual populacional vs versão de maio (cedca_258) vs publicada
def hamilton(w,total):
    w=np.asarray(w,float); q=w/w.sum()*total; fl=np.floor(q); rem=int(round(total-fl.sum()))
    order=np.argsort(-(q-fl),kind="stable"); add=np.zeros(len(w)); add[order[:rem]]=1
    return fl+add
S2=hamilton(b.pop04,300)
def met(v,nome):
    v=np.asarray(v,float); tot=v.sum()
    cur=v[(b.mun=="Curitiba").values].sum()
    print(f"{nome:28s} total={tot:.0f} mun={int((v>0).sum())} Curitiba={cur:.0f} top10={np.sort(v)[::-1][:10].sum()/tot*100:.1f}% quintilPCM={v[list(top80)].sum()/tot*100:.1f}% cobQuintil={(v[list(top80)]>0).mean()*100:.1f}% pop04cob={b.pop04[v>0].sum()/b.pop04.sum()*100:.1f}% max={v.max():.0f} PCMmedPond={np.average(b.pcm_padrao,weights=v):.3f}")
met(S2,"S2 pop 0-4 (300)")
met(b.cedca_258,"maio/2024 (cedca_258)")
met(b.pub_res219,"publicada (303)")
met(b.cons_total300,"março/2024 (300)")
print("pop04 total", int(b.pop04.sum()))
s2=S2>0; m5=b.cedca_258.values>0
print("S2 contemplados também em maio:", int((s2&m5).sum()), "| só S2:", int((s2&~m5).sum()), "| só maio:", int((~s2&m5).sum()))
print("S2 por porte:", pd.Series(S2).groupby(b.porte_dc.values).sum().to_dict())
print("S2 municípios c/ unidade por porte:", pd.Series(S2>0).groupby(b.porte_dc.values).sum().to_dict())
print("maio por porte:", b.groupby("porte_dc").cedca_258.sum().to_dict())
# quantos municípios precisariam de x crianças p/ 1 unidade em S2: limiar
q=b.pop04/b.pop04.sum()*300
print("S2: pop04 mínima entre contemplados:", int(b.pop04[s2].min()), "| quota exata máx entre não contemplados:", round(q[~s2].max(),3))
print("S2: municípios P1/P2 contemplados:", int(((b.porte_dc.isin(["P1","P2"]))&s2).sum()))
