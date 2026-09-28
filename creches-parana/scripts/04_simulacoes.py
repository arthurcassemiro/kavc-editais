"""Simulações contrafactuais: mesmo total de creches (300) distribuído por regras alternativas."""
import pandas as pd, numpy as np
b=pd.read_csv("02_base_tratada/base_municipal.csv")
ordem=["G2","G1","M2","M1","P4","P3","P2","P1"]
N=300
def hamilton(w,total):
    w=np.asarray(w,float); q=w/w.sum()*total; fl=np.floor(q); rem=int(round(total-fl.sum()))
    order=np.argsort(-(q-fl),kind="stable"); add=np.zeros(len(w)); add[order[:rem]]=1
    return fl+add
def hamilton_cap(w,total,cap):
    w=np.asarray(w,float); cap=np.asarray(cap,float); alloc=np.zeros(len(w)); active=np.ones(len(w),bool); rem=total
    for _ in range(30):
        a=hamilton(w[active],rem); tmp=np.zeros(len(w)); tmp[active]=a
        over=(tmp>cap)&active
        if not over.any(): alloc[active]=a; break
        alloc[over]=cap[over]; rem-=int(cap[over].sum()); active&=~over
    return alloc
def topn(score,n):
    a=np.zeros(len(score)); idx=np.argsort(-np.asarray(score),kind="stable")[:n]; a[idx]=1; return a
S={}
S["S1 Proporcional à população total"]=hamilton(b["pop"],N)
S["S2 Proporcional à população 0-4"]=hamilton(b.pop04,N)
S["S5 Ranking do fator socioeconômico"]=topn(b.fs,N)
S["S3 Proporcional a população 0-4 × FS"]=hamilton(b.pop04*b.fs,N)
S["S4 Proporcional a população 0-4 × PCM (sem faixas)"]=hamilton(b.pop04*b.pcm_padrao,N)
S["S6 Ranking do PCM (sem faixas)"]=topn(b.pcm_padrao,N)
# S5: PCM com faixas -> regra consolidada com 300 creches: cotas por porte proporcionais às cotas efetivas (100/27/100/30 escaladas)
caps={"G2":10,"G1":8,"M2":7,"M1":4,"P4":2}
big=b.porte_dc.isin(list(caps)); 
q_eff={"grandes":100,"P3":27,"P2":100,"P1":30}
scale=N/257; quotas={k:v*scale for k,v in q_eff.items()}
# arredondar cotas para inteiros somando 300
qk=list(quotas); qv=hamilton(np.array([quotas[k] for k in qk]),N); quotas=dict(zip(qk,qv.astype(int)))
s5=np.zeros(len(b))
w=(b.pop04*(1+b.pcm_padrao)).values
s5[big.values]=hamilton_cap(w[big.values],quotas["grandes"],b.loc[big,"porte_dc"].map(caps).values)
for pt in ["P3","P2","P1"]:
    m=(b.porte_dc==pt).values; sc=np.where(pt=="P3",b.pcm_p3,b.pcm_padrao)
    s5[m]=topn(sc[m],quotas[pt])
S["S7 PCM com faixas (regra consolidada, 300)"]=s5
S=dict(sorted(S.items()))
S["Técnica (observada, 251)"]=b.tec_ic.values.astype(float)
S["Consolidada (observada, 300)"]=b.cons_total300.values.astype(float)
S["Publicada (observada, 303)"]=b.pub_res219.values.astype(float)
sim=pd.DataFrame(S); sim.insert(0,"cod7",b.cod7); sim.insert(1,"mun",b.mun); sim.insert(2,"porte_dc",b.porte_dc); sim.insert(3,"pop04",b.pop04); sim.insert(4,"pcm",b.pcm_padrao); sim.insert(5,"fs",b.fs)
sim.to_csv("04_simulacoes/simulacoes_por_municipio.csv",index=False)
# ---- métricas ----
def gini(x):
    x=np.sort(np.asarray(x,float)); n=len(x); 
    if x.sum()==0: return np.nan
    return (2*np.sum((np.arange(1,n+1))*x)/(n*x.sum()))-(n+1)/n
top_pcm80=set(b.nlargest(80,"pcm_padrao").index); top_fs80=set(b.nlargest(80,"fs").index); top_pcm40=set(b.nlargest(40,"pcm_padrao").index)
rows=[]
for k,v in S.items():
    v=np.asarray(v); tot=v.sum()
    shares=v/tot
    r={"cenario":k,"total":int(tot),"municipios_contemplados":int((v>0).sum()),"cobertura_mun_%":(v>0).mean()*100,
       "share_top10_mun_%":np.sort(v)[::-1][:10].sum()/tot*100,"hhi":(shares**2).sum()*10000,"gini_creches_por_mun":gini(v),
       "gini_creches_por_crianca":gini(v/b.pop04*1e4),
       "share_quintil_maior_PCM_%":v[list(top_pcm80)].sum()/tot*100,"cob_quintil_maior_PCM_%":(v[list(top_pcm80)]>0).mean()*100,
       "share_top40_PCM_%":v[list(top_pcm40)].sum()/tot*100,"share_quintil_maior_FS_%":v[list(top_fs80)].sum()/tot*100,
       "pcm_medio_ponderado":np.average(b.pcm_padrao,weights=v),"fs_medio_ponderado":np.average(b.fs,weights=v),
       "pop04_coberta_%":b.pop04[v>0].sum()/b.pop04.sum()*100,"creches_10mil_criancas_mun_contemplados":tot/b.pop04[v>0].sum()*1e4,
       "creche_max_mun":int(v.max()),"municipio_max":b.mun[np.argmax(v)]}
    for pt in ordem: r[f"creches_{pt}"]=int(v[(b.porte_dc==pt).values].sum())
    for grp,pts in [("grandes(G2-P4)",["G2","G1","M2","M1","P4"]),("P3",["P3"]),("P2",["P2"]),("P1",["P1"])]:
        r[f"share_{grp}_%"]=v[b.porte_dc.isin(pts).values].sum()/tot*100
    rows.append(r)
M=pd.DataFrame(rows).set_index("cenario")
M.round(2).to_csv("04_simulacoes/metricas_cenarios.csv")
# sobreposição de municípios contemplados com a consolidada
cons=S["Consolidada (observada, 300)"]>0
ov={k:{"jaccard":((v>0)&cons).sum()/((v>0)|cons).sum(),"contemplados_comuns":int(((v>0)&cons).sum()),"so_cenario":int(((v>0)&~cons).sum()),"so_consolidada":int((~(v>0)&cons).sum()),"L1_creches":int(np.abs(v-S["Consolidada (observada, 300)"]).sum())} for k,v in S.items()}
pd.DataFrame(ov).T.round(3).to_csv("04_simulacoes/sobreposicao_com_consolidada.csv")
pd.Series(quotas).to_csv("04_simulacoes/S5_cotas_por_faixa.csv")
print(M.round(1).T.to_string()); print(); print(pd.DataFrame(ov).T.round(3)); print(quotas)
