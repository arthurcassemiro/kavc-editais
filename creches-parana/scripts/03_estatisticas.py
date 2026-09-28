"""Estatísticas descritivas, comparação beneficiados x não beneficiados, mobilidade nos rankings,
ajustes técnica -> consolidada, análise regional."""
import pandas as pd, numpy as np
from scipy import stats
b=pd.read_csv("02_base_tratada/base_municipal.csv")
ordem=["G2","G1","M2","M1","P4","P3","P2","P1"]
b["porte_dc"]=pd.Categorical(b.porte_dc,ordem,ordered=True); b["porte_ic"]=pd.Categorical(b.porte_ic,ordem,ordered=True)
out={}
# ---- T1: por porte (classificação consolidada) ----
g=b.groupby("porte_dc",observed=True)
t1=pd.DataFrame({"municipios":g.size(),"pop_total":g["pop"].sum(),"pop04":g.pop04.sum(),"share_pop04":g.pop04.sum()/b.pop04.sum()*100,
 "pcm_medio":g.pcm_padrao.mean(),"pcm_min":g.pcm_padrao.min(),"pcm_max":g.pcm_padrao.max(),"fe_medio":g.fe.mean(),"fd_medio":g.fd.mean(),"fs_medio":g.fs.mean(),
 "creches_tec":g.tec_ic.sum(),"mun_tec":g.contemplado_tec.sum(),"creches_prev43":g.cons_prev43.sum(),"creches_pcm257":g.cons_pcm257.sum(),"creches_cons":g.cons_total300.sum(),"mun_cons":g.contemplado_cons.sum()})
t1["share_creches_cons"]=t1.creches_cons/t1.creches_cons.sum()*100; t1["share_creches_tec"]=t1.creches_tec/t1.creches_tec.sum()*100
t1["cobertura_mun_cons"]=t1.mun_cons/t1.municipios*100; t1["cobertura_mun_tec"]=t1.mun_tec/t1.municipios*100
t1["creches_10mil_04_cons"]=t1.creches_cons/t1.pop04*10000; t1["creches_10mil_04_tec"]=t1.creches_tec/t1.pop04*10000
t1.loc["Total"]=t1.sum(numeric_only=True); 
for c in ["pcm_medio","fe_medio","fd_medio","fs_medio"]: t1.loc["Total",c]=b[c.replace("_medio","").replace("pcm","pcm_padrao")].mean()
t1.loc["Total","pcm_min"]=b.pcm_padrao.min(); t1.loc["Total","pcm_max"]=b.pcm_padrao.max()
t1.loc["Total","cobertura_mun_cons"]=b.contemplado_cons.mean()*100; t1.loc["Total","cobertura_mun_tec"]=b.contemplado_tec.mean()*100
t1.loc["Total","creches_10mil_04_cons"]=b.cons_total300.sum()/b.pop04.sum()*10000; t1.loc["Total","creches_10mil_04_tec"]=b.tec_ic.sum()/b.pop04.sum()*10000
t1.loc["Total","share_pop04"]=100; t1.loc["Total","share_creches_cons"]=100; t1.loc["Total","share_creches_tec"]=100
t1.round(3).to_csv("03_resultados/T1_por_porte.csv")
# ---- T1b: por porte IC ----
g=b.groupby("porte_ic",observed=True)
t1b=pd.DataFrame({"municipios":g.size(),"pop04":g.pop04.sum(),"creches_tec":g.tec_ic.sum(),"mun_tec":g.contemplado_tec.sum()})
t1b["share_pop04"]=t1b.pop04/t1b.pop04.sum()*100; t1b["share_creches_tec"]=t1b.creches_tec/t1b.creches_tec.sum()*100
t1b.round(2).to_csv("03_resultados/T1b_por_porte_ic.csv")
# ---- T2: descritivas do PCM e componentes ----
desc=b[["fe","fd","fs","pcm_padrao","pcm_p3","pop","pop04","prop_creche","cad_prop","ipdm_r","mort_inf","prop04"]].describe(percentiles=[.1,.25,.5,.75,.9]).T
desc.round(4).to_csv("03_resultados/T2_descritivas.csv")
corr=b[["fe","fd","fs","pcm_padrao","pop","pop04","ipdm_r","cad_prop","prop_creche"]].corr(method="spearman").round(3)
corr.to_csv("03_resultados/T2b_correlacoes_spearman.csv")
# ---- T3: distribuição das quantidades ----
t3=pd.DataFrame({"tec":b.tec_ic.value_counts().sort_index(),"cons":b.cons_total300.value_counts().sort_index()}).fillna(0).astype(int)
t3.to_csv("03_resultados/T3_distribuicao_quantidades.csv")
# ---- T4: beneficiados x não beneficiados ----
def cmp(flag,label):
    rows=[]
    for var in ["pop","pop04","fe","fd","fs","pcm_padrao","ipdm_r","cad_prop","prop_creche","mort_inf"]:
        a=b.loc[b[flag]==1,var]; c=b.loc[b[flag]==0,var]
        u=stats.mannwhitneyu(a,c,alternative="two-sided")
        rows.append({"etapa":label,"variavel":var,"n_benef":len(a),"n_nao":len(c),"media_benef":a.mean(),"media_nao":c.mean(),"mediana_benef":a.median(),"mediana_nao":c.median(),"p_mannwhitney":u.pvalue})
    return pd.DataFrame(rows)
t4=pd.concat([cmp("contemplado_tec","técnica"),cmp("contemplado_cons","consolidada")])
t4.round(5).to_csv("03_resultados/T4_beneficiados_vs_nao.csv",index=False)
# por quintil de PCM e de população
b["quintil_pcm"]=pd.qcut(b.pcm_padrao,5,labels=["Q1 (menor PCM)","Q2","Q3","Q4","Q5 (maior PCM)"])
b["quintil_pop04"]=pd.qcut(b.pop04,5,labels=["Q1 (menor pop 0-4)","Q2","Q3","Q4","Q5 (maior pop 0-4)"])
t4b=b.groupby("quintil_pcm",observed=True).agg(municipios=("mun","size"),benef_tec=("contemplado_tec","sum"),creches_tec=("tec_ic","sum"),benef_cons=("contemplado_cons","sum"),creches_cons=("cons_total300","sum"),pop04=("pop04","sum"))
t4b["cob_tec_%"]=t4b.benef_tec/t4b.municipios*100; t4b["cob_cons_%"]=t4b.benef_cons/t4b.municipios*100; t4b["share_creches_cons_%"]=t4b.creches_cons/300*100; t4b["share_pop04_%"]=t4b.pop04/b.pop04.sum()*100
t4b.round(1).to_csv("03_resultados/T4b_por_quintil_pcm.csv")
t4c=b.groupby("quintil_pop04",observed=True).agg(municipios=("mun","size"),benef_tec=("contemplado_tec","sum"),creches_tec=("tec_ic","sum"),benef_cons=("contemplado_cons","sum"),creches_cons=("cons_total300","sum"),pop04=("pop04","sum"),pcm_medio=("pcm_padrao","mean"))
t4c["cob_cons_%"]=t4c.benef_cons/t4c.municipios*100; t4c["share_creches_cons_%"]=t4c.creches_cons/300*100; t4c["share_pop04_%"]=t4c.pop04/b.pop04.sum()*100
t4c.round(2).to_csv("03_resultados/T4c_por_quintil_pop04.csv")
# cruzamento quintil pcm x quintil pop
ct=pd.crosstab(b.quintil_pop04,b.quintil_pcm,values=b.contemplado_cons,aggfunc="mean").round(2)
ct.to_csv("03_resultados/T4d_cobertura_cons_pop_x_pcm.csv")
# ---- T5: mobilidade nos rankings ----
b["rank_cons"]=b.cons_total300.rank(ascending=False,method="min").astype(int)
b["rank_tec"]=b.tec_ic.rank(ascending=False,method="min").astype(int)
# posição relativa: creches per capita de crianças vs ranking populacional
b["rank_cons_pc"]=b.creches_por_10mil_04_cons.rank(ascending=False,method="min")
b["sobe_vs_pop"]=b.rank_cons-b.rank_pop   # negativo = ficou acima da posição populacional
b["sobe_vs_pcm"]=b.rank_cons-b.rank_pcm
# quem recebeu estando fora do top-224 populacional; quem não recebeu estando no top-224 populacional
n_cons=int(b.contemplado_cons.sum())
top_pop=set(b.nsmallest(n_cons,"rank_pop").mun); top_pcm=set(b.nsmallest(n_cons,"rank_pcm").mun); top_pop04=set(b.nsmallest(n_cons,"rank_pop04").mun); top_fs=set(b.nsmallest(n_cons,"rank_fs").mun)
rec=set(b[b.contemplado_cons==1].mun)
mob={"n_contemplados_cons":n_cons,
 "contemplados_fora_top_pop":len(rec-top_pop),"nao_contemplados_dentro_top_pop":len(top_pop-rec),
 "contemplados_fora_top_pop04":len(rec-top_pop04),"nao_contemplados_dentro_top_pop04":len(top_pop04-rec),
 "contemplados_fora_top_pcm":len(rec-top_pcm),"nao_contemplados_dentro_top_pcm":len(top_pcm-rec),
 "contemplados_fora_top_fs":len(rec-top_fs),"nao_contemplados_dentro_top_fs":len(top_fs-rec)}
n_tec=int(b.contemplado_tec.sum()); rect=set(b[b.contemplado_tec==1].mun)
top_pop_t=set(b.nsmallest(n_tec,"rank_pop").mun); top_pcm_t=set(b.nsmallest(n_tec,"rank_pcm").mun)
mob.update({"n_contemplados_tec":n_tec,"tec_contemplados_fora_top_pop":len(rect-top_pop_t),"tec_contemplados_fora_top_pcm":len(rect-top_pcm_t)})
pd.Series(mob).to_csv("03_resultados/T5_mobilidade_resumo.csv")
# listas: maiores "subidas" (contemplados com pior posição populacional) e "descidas" (não contemplados populosos / alto PCM)
sub=b[b.contemplado_cons==1].sort_values("rank_pop",ascending=False)[["mun","porte_dc","pop","pop04","rank_pop","rank_pcm","pcm_padrao","cons_total300","tec_ic"]].head(25)
sub.to_csv("03_resultados/T5a_contemplados_menor_populacao.csv",index=False)
desc_pop=b[(b.contemplado_cons==0)].sort_values("rank_pop")[["mun","porte_dc","pop","pop04","rank_pop","rank_pcm","pcm_padrao","tec_ic"]].head(25)
desc_pop.to_csv("03_resultados/T5b_nao_contemplados_mais_populosos.csv",index=False)
desc_pcm=b[(b.contemplado_cons==0)].sort_values("rank_pcm")[["mun","porte_dc","pop","pop04","rank_pop","rank_pcm","pcm_padrao","fs","tec_ic"]].head(25)
desc_pcm.to_csv("03_resultados/T5c_nao_contemplados_maior_pcm.csv",index=False)
# Spearman entre creches e rankings
sp={"spearman_cons_pop04":stats.spearmanr(b.cons_total300,b.pop04).statistic,"spearman_cons_pcm":stats.spearmanr(b.cons_total300,b.pcm_padrao).statistic,
    "spearman_tec_pop04":stats.spearmanr(b.tec_ic,b.pop04).statistic,"spearman_tec_pcm":stats.spearmanr(b.tec_ic,b.pcm_padrao).statistic,
    "spearman_cons_pc_pcm":stats.spearmanr(b.creches_por_10mil_04_cons,b.pcm_padrao).statistic}
pd.Series(sp).round(3).to_csv("03_resultados/T5d_spearman.csv")
# ---- T6: ajustes técnica -> consolidada ----
t6=b.groupby("porte_dc",observed=True).agg(municipios=("mun","size"),tec=("tec_ic","sum"),cons=("cons_total300","sum"),ganho=("dif_cons_tec",lambda x:x[x>0].sum()),perda=("dif_cons_tec",lambda x:-x[x<0].sum()),
   mun_ganham=("dif_cons_tec",lambda x:(x>0).sum()),mun_perdem=("dif_cons_tec",lambda x:(x<0).sum()),mun_iguais=("dif_cons_tec",lambda x:(x==0).sum()))
t6.loc["Total"]=t6.sum(); t6.to_csv("03_resultados/T6_ajustes_por_porte.csv")
tip=b.groupby(["porte_dc","tipologia"],observed=True).size().unstack(fill_value=0); tip.loc["Total"]=tip.sum(); tip.to_csv("03_resultados/T6b_tipologia_por_porte.csv")
lst=b[b.dif_cons_tec!=0].sort_values("dif_cons_tec")[["mun","porte_ic","porte_dc","pop","pcm_padrao","pcm_dc","rank_pcm","tec_ic","cons_prev43","cons_pcm257","cons_total300","dif_cons_tec","tipologia"]]
lst.to_csv("03_resultados/T6c_lista_municipios_com_diferenca.csv",index=False)
# decomposição das mudanças: reclassificação de porte
b["mudou_porte"]=(b.porte_ic.astype(str)!=b.porte_dc.astype(str))
t6d=pd.crosstab(b.porte_ic,b.porte_dc); t6d.to_csv("03_resultados/T6d_reclassificacao_portes.csv")
# os 52 'somente consolidada': quantos vieram da etapa prévia (43) e quantos do ranking PCM
sc=b[b.tipologia=="Somente consolidada"]; st=b[b.tipologia=="Somente técnica"]
res6={"somente_cons_n":len(sc),"somente_cons_via_prev43":int((sc.cons_prev43>0).sum()),"somente_cons_via_pcm257":int((sc.cons_pcm257>0).sum()),
      "somente_tec_n":len(st),"somente_tec_pcm_medio":st.pcm_padrao.mean(),"somente_cons_pcm_medio":sc.pcm_padrao.mean(),"ambos_pcm_medio":b[b.tipologia=="Técnica e consolidada"].pcm_padrao.mean(),"nao_pcm_medio":b[b.tipologia=="Não contemplado"].pcm_padrao.mean(),
      "somente_tec_porte":st.porte_dc.value_counts().to_dict(),"somente_cons_porte":sc.porte_dc.value_counts().to_dict()}
pd.Series(res6).to_csv("03_resultados/T6e_tipologia_resumo.csv")
# ---- T7: regional ----
for reg in ["mesorregiao","regiao_intermediaria"]:
    g=b.groupby(reg)
    t7=pd.DataFrame({"municipios":g.size(),"pop04":g.pop04.sum(),"pcm_medio":g.pcm_padrao.mean(),"fs_medio":g.fs.mean(),"creches_tec":g.tec_ic.sum(),"creches_cons":g.cons_total300.sum(),"mun_cons":g.contemplado_cons.sum()})
    t7["share_pop04_%"]=t7.pop04/b.pop04.sum()*100; t7["share_cons_%"]=t7.creches_cons/300*100; t7["razao_share"]=t7["share_cons_%"]/t7["share_pop04_%"]
    t7["creches_10mil_04"]=t7.creches_cons/t7.pop04*1e4; t7["cob_mun_%"]=t7.mun_cons/t7.municipios*100
    t7.round(3).sort_values("razao_share",ascending=False).to_csv(f"03_resultados/T7_regional_{reg}.csv")
# regressão exploratória: creches per capita ~ pcm + log pop + mesorregião (OLS simples via numpy) -> usar statsmodels se disponível
try:
    import statsmodels.formula.api as smf
    b["lpop04"]=np.log(b.pop04); b["creches_pc"]=b.creches_por_10mil_04_cons
    m1=smf.ols("cons_total300 ~ pcm_padrao + lpop04",data=b).fit(cov_type="HC1")
    m2=smf.ols("cons_total300 ~ pcm_padrao + lpop04 + C(mesorregiao)",data=b).fit(cov_type="HC1")
    m3=smf.logit("contemplado_cons ~ pcm_padrao + lpop04",data=b).fit(disp=0)
    with open("03_resultados/T8_regressoes_exploratorias.txt","w") as f:
        f.write(m1.summary().as_text()+"\n\n"+m2.summary().as_text()+"\n\n"+m3.summary().as_text())
        ft=m2.f_test(" , ".join([f"C(mesorregiao)[T.{k}] = 0" for k in sorted(b.mesorregiao.unique())[1:]]))
        f.write(f"\n\nTeste F conjunto das dummies de mesorregião (m2): F={ft.fvalue:.3f}, p={ft.pvalue:.4f}\n")
except Exception as e:
    open("03_resultados/T8_regressoes_exploratorias.txt","w").write("statsmodels indisponível: "+str(e))
b.to_csv("02_base_tratada/base_municipal_com_rankings.csv",index=False)
print(t1.round(2).to_string()); print(); print(t3.T); print(); print(pd.Series(mob)); print(); print(pd.Series(sp).round(3)); print(); print(t6); print(); print(tip); print(); print(pd.Series(res6)); print(); print(t4b.round(1)); print(); print(t4c.round(1)); print(ct)
