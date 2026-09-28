"""Carrega os dois workbooks originais, recalcula fórmulas e audita divergências.
Saídas: 01_auditoria/*.csv e 02_base_tratada/base_municipal.csv"""
import openpyxl, pandas as pd, numpy as np, unicodedata, json, re
ORIG="00_originais/"
def norm(s):
    s=str(s).strip()
    s=unicodedata.normalize("NFKD",s).encode("ascii","ignore").decode().upper()
    return re.sub(r"\s+"," ",s)
def sheet_df(wb, name, header_row=1, ncols=None):
    ws=wb[name]
    rows=list(ws.iter_rows(values_only=True))
    hdr=rows[header_row-1]; body=rows[header_row:]
    df=pd.DataFrame(body, columns=[f"c{i}" if h is None else str(h).strip() for i,h in enumerate(hdr)])
    return df
ic=openpyxl.load_workbook(ORIG+"Indicador_Criterio_VF.xlsx",data_only=True)
dc=openpyxl.load_workbook(ORIG+"20240327_Distribuicao_Creches.xlsx",data_only=True)
log=[]
# ---------- CI (IC) ----------
ci=sheet_df(ic,"CI"); ci=ci[ci["MUNICÍPIO"].notna()].copy()
ci.columns=["mun","pop","porte_ic","faixa1","faixa2","fe","fd","fs","pcm","prop1","prop2","aprox","int_","n_pcm","floor_","frac","rank_","total_ic","c18","t_pop_pcm"][:len(ci.columns)]
log.append(f"IC!CI linhas com município: {len(ci)}")
# ---------- Dados (DC) ----------
dd=sheet_df(dc,"Dados"); dd=dd[dd["MUNICÍPIO"].notna()].copy()
dd.columns=["mun","pop","porte_dc","prop_faixa","fe","fd","fs","pcm","ipardes","prop","aprox","int_","n_pcm","floor_","frac","rank_","total_dc","r18","s","t","u"][:len(dd.columns)]
log.append(f"DC!Dados linhas com município: {len(dd)}")
res=sheet_df(dc,"Resultados"); res=res[res["MUNICÍPIO"].notna()].copy()
res.columns=["mun","ipardes43","pcm257","total300"]
log.append(f"DC!Resultados linhas: {len(res)}; somas: {res.ipardes43.sum()}, {res.pcm257.sum()}, {res.total300.sum()}")
# ---------- componentes ----------
def comp(wb,tag):
    ed=sheet_df(wb,"Educacional"); ed=ed.iloc[:, :16]
    ed.columns=["mun","cod7","mat_creche","pop04","prop_creche","creche_norm","mat_pre_fund","pop514","prop_pre_fund","mat_norm","oferta_priv","oferta_tot","prop_priv","priv_norm","fe_bruto","fe"]
    de=sheet_df(wb,"Demográfico"); de=de.iloc[:, :13]
    de.columns=["mun","cod7","mort_inf","mi_norm","pop04","pop_total","prop04","prop04_norm","natalidade","nat_norm","fd_bruto","fd","porte_lookup"]
    so=sheet_df(wb,"Socioeconômico"); so=so.iloc[:, :13]
    so.columns=["mun","cod6","desnut_n","desnut_prop","desnut_norm","cadunico","pop514","cad_prop","cad_norm","ipdm_r","ipdm_norm","fs_bruto","fs"]
    return ed,de,so
ed_ic,de_ic,so_ic=comp(ic,"IC"); ed_dc,de_dc,so_dc=comp(dc,"DC")
# linhas de min/max no rodapé
for nm,df in [("Educacional",ed_ic),("Demográfico",de_ic),("Socioeconômico",so_ic)]:
    tail=df[df["mun"].isna()]
    log.append(f"IC!{nm}: linhas sem município (rodapé min/max): {len(tail)} -> {tail.iloc[:, -2].tolist()}")
    df.drop(tail.index,inplace=True)
for nm,df in [("Educacional",ed_dc),("Demográfico",de_dc),("Socioeconômico",so_dc)]:
    tail=df[df["mun"].isna()]; df.drop(tail.index,inplace=True)
# identidade dos componentes entre os arquivos
for nm,a,b in [("Educacional",ed_ic,ed_dc),("Demográfico",de_ic,de_dc),("Socioeconômico",so_ic,so_dc)]:
    a2=a.set_index("mun"); b2=b.set_index("mun")
    common=a2.index.intersection(b2.index)
    numcols=[c for c in a2.columns if c not in ("porte_lookup",) and pd.api.types.is_numeric_dtype(pd.to_numeric(a2[c],errors="coerce"))]
    diff=0
    for c in numcols:
        x=pd.to_numeric(a2.loc[common,c],errors="coerce"); y=pd.to_numeric(b2.loc[common,c],errors="coerce")
        d=((x-y).abs()>1e-9).sum()
        if d: diff+=d; log.append(f"  {nm}.{c}: {d} divergências IC vs DC")
    log.append(f"Componente {nm}: {len(a)} (IC) x {len(b)} (DC) municípios; {len(common)} comuns; células numéricas divergentes: {diff}")
# ---------- recálculo dos fatores ----------
ed=ed_dc.copy(); de=de_dc.copy(); so=so_dc.copy()
for df in (ed,de,so):
    for c in df.columns[1:]:
        if c!="porte_lookup": df[c]=pd.to_numeric(df[c],errors="coerce")
def mm(x): return (x-x.min())/(x.max()-x.min())*100
ed["fe_bruto_rc"]=(2*ed.creche_norm+ed.mat_norm+ed.priv_norm)/4
ed["fe_rc"]=mm(ed.fe_bruto_rc)
de["fd_bruto_rc"]=(de.mi_norm+de.prop04_norm+de.nat_norm)/3
de["fd_rc"]=mm(de.fd_bruto_rc)
so["fs_bruto_rc"]=(so.ipdm_norm+so.cad_norm+so.desnut_norm)/3
so["fs_rc"]=mm(so.fs_bruto_rc)
for nm,df,a,b in [("FE",ed,"fe","fe_rc"),("FD",de,"fd","fd_rc"),("FS",so,"fs","fs_rc")]:
    log.append(f"Recalculo {nm}: max |dif| = {(df[a]-df[b]).abs().max():.2e}")
# sub-normalizações: verificar se creche_norm etc. são min-max ou outra coisa
ed["creche_norm_rc"]=mm(ed.prop_creche); log.append(f"creche_norm vs minmax(prop): maxdif {(ed.creche_norm-ed.creche_norm_rc).abs().max():.3f}; corr {ed.creche_norm.corr(ed.prop_creche):.4f}")
ed["mat_norm_rc"]=mm(ed.prop_pre_fund); log.append(f"mat_norm vs minmax: maxdif {(ed.mat_norm-ed.mat_norm_rc).abs().max():.3f}; corr {ed.mat_norm.corr(ed.prop_pre_fund):.4f}")
ed["priv_norm_rc"]=mm(ed.prop_priv); log.append(f"priv_norm vs minmax: maxdif {(ed.priv_norm-ed.priv_norm_rc).abs().max():.3f}; corr {ed.priv_norm.corr(ed.prop_priv):.4f}")
de["mi_norm_rc"]=mm(de.mort_inf); log.append(f"mi_norm vs minmax: maxdif {(de.mi_norm-de.mi_norm_rc).abs().max():.3f}; corr {de.mi_norm.corr(de.mort_inf):.4f}")
de["prop04_norm_rc"]=mm(de.prop04); log.append(f"prop04_norm vs minmax: maxdif {(de.prop04_norm-de.prop04_norm_rc).abs().max():.3f}; corr {de.prop04_norm.corr(de.prop04):.4f}")
de["nat_norm_rc"]=mm(de.natalidade); log.append(f"nat_norm vs minmax: maxdif {(de.nat_norm-de.nat_norm_rc).abs().max():.3f}; corr {de.nat_norm.corr(de.natalidade):.4f}")
so["desnut_norm_rc"]=mm(so.desnut_prop); log.append(f"desnut_norm vs minmax: maxdif {(so.desnut_norm-so.desnut_norm_rc).abs().max():.3f}; corr {so.desnut_norm.corr(so.desnut_prop):.4f}")
so["cad_norm_rc"]=mm(so.cad_prop); log.append(f"cad_norm vs minmax: maxdif {(so.cad_norm-so.cad_norm_rc).abs().max():.3f}; corr {so.cad_norm.corr(so.cad_prop):.4f}")
so["ipdm_norm_rc"]=mm(-so.ipdm_r); log.append(f"ipdm_norm vs minmax(-ipdm): maxdif {(so.ipdm_norm-so.ipdm_norm_rc).abs().max():.3f}; corr {so.ipdm_norm.corr(so.ipdm_r):.4f}")
# ---------- base municipal integrada ----------
for df in (ci,dd,res):
    for c in df.columns[1:]:
        if c not in ("porte_ic","porte_dc"): df[c]=pd.to_numeric(df[c],errors="coerce")
base=dd[["mun","pop","porte_dc","prop_faixa","fe","fd","fs","pcm","ipardes","prop","aprox","floor_","frac","rank_","total_dc"]].merge(
    res,on="mun",how="outer",indicator="m_res")
log.append(f"merge Dados x Resultados: {base.m_res.value_counts().to_dict()}")
base=base.merge(ci[["mun","porte_ic","faixa1","faixa2","pcm","prop1","prop2","aprox","floor_","frac","rank_","total_ic"]].rename(columns={"pcm":"pcm_ic","aprox":"aprox_ic","floor_":"floor_ic","frac":"frac_ic","rank_":"rank_ic"}),on="mun",how="outer",indicator="m_ic")
log.append(f"merge x IC!CI: {base.m_ic.value_counts().to_dict()}")
log.append(f"PCM IC vs DC: maxdif {(base.pcm-base.pcm_ic).abs().max():.2e}")
base=base.merge(ed[["mun","cod7","mat_creche","pop04","prop_creche","mat_pre_fund","pop514","prop_pre_fund","oferta_priv","oferta_tot","prop_priv","creche_norm","mat_norm","priv_norm"]],on="mun",how="left",indicator="m_ed")
base=base.merge(de[["mun","mort_inf","pop_total","prop04","natalidade","mi_norm","prop04_norm","nat_norm"]],on="mun",how="left",indicator="m_de")
base=base.merge(so[["mun","cod6","desnut_prop","cadunico","cad_prop","ipdm_r","desnut_norm","cad_norm","ipdm_norm"]],on="mun",how="left",indicator="m_so")
for c in ("m_ed","m_de","m_so"): log.append(f"{c}: {base[c].value_counts().to_dict()}")
base["pcm_rc"]=(2*base.fe+base.fd+2*base.fs)/500
log.append(f"PCM recalculado (2FE+FD+2FS)/5/100: maxdif {(base.pcm-base.pcm_rc).abs().max():.2e}")
log.append(f"pop (Dados) vs pop_total (Demográfico): divergências {((base['pop']-base.pop_total).abs()>0).sum()}")
# porte recalculado
def porte_dc(p):
    if p>1_000_000: return "G2"
    if p>500_000: return "G1"
    if p>200_000: return "M2"
    if p>100_000: return "M1"
    if p>70_000: return "P4"
    if p>20_000: return "P3"
    if p>5_000: return "P2"
    return "P1"
def porte_ic(p):
    if p>1_000_000: return "G2"
    if p>500_000: return "G1"
    if p>200_000: return "M2"
    if p>100_000: return "M1"
    if p>70_000: return "P4"
    if p>40_000: return "P3"
    if p>20_000: return "P2"
    return "P1"
base["porte_dc_rc"]=base["pop"].apply(porte_dc); base["porte_ic_rc"]=base["pop"].apply(porte_ic)
log.append(f"porte DC recalculado ≠ planilha: {(base.porte_dc!=base.porte_dc_rc).sum()} -> {base.loc[base.porte_dc!=base.porte_dc_rc,['mun','pop','porte_dc','porte_dc_rc']].values.tolist()}")
log.append(f"porte IC recalculado ≠ planilha: {(base.porte_ic!=base.porte_ic_rc).sum()} -> {base.loc[base.porte_ic!=base.porte_ic_rc,['mun','pop','porte_ic','porte_ic_rc']].values.tolist()}")
log.append("Contagem por porte DC: "+str(base.porte_dc.value_counts().to_dict()))
log.append("Contagem por porte IC: "+str(base.porte_ic.value_counts().to_dict()))
# codigo IBGE
base["cod7"]=base.cod7.astype("Int64")
log.append(f"cod7 nulos: {base.cod7.isna().sum()}; duplicados: {base.cod7.duplicated().sum()}; cod6*10 vs cod7: {((base.cod6*10 - base.cod7//10*10)!=0).sum()} inconsistências")
base.to_csv("02_base_tratada/base_municipal_bruta.csv",index=False)
with open("01_auditoria/log_carregamento.txt","w") as f: f.write("\n".join(log))
print("\n".join(log))
