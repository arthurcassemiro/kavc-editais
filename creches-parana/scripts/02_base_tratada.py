"""Constrói a base municipal tratada: códigos IBGE, regiões, portes, PCM (duas variantes),
etapas de distribuição (técnica IC / consolidada DC) e flags. Documenta decisões de limpeza."""
import pandas as pd, numpy as np, json, unicodedata, re, geopandas as gpd
SP="/tmp/claude-0/-home-user-kavc-editais/98e3c548-b4ab-5729-ad4a-337524077c70/scratchpad/"
def norm(s): return re.sub(r"\s+"," ",unicodedata.normalize("NFKD",str(s)).encode("ascii","ignore").decode().upper().strip())
b=pd.read_csv("02_base_tratada/base_municipal_bruta.csv")
dec=[]
# --- IBGE regiões ---
ib=pd.DataFrame(json.load(open(SP+"ibge/municipios_pr_regioes.json")))
ib=ib.rename(columns={"municipio-id":"cod7","municipio-nome":"nome_ibge","mesorregiao-nome":"mesorregiao","microrregiao-nome":"microrregiao","regiao-imediata-nome":"regiao_imediata","regiao-intermediaria-nome":"regiao_intermediaria"})
b=b.merge(ib[["cod7","nome_ibge","mesorregiao","microrregiao","regiao_imediata","regiao_intermediaria"]],on="cod7",how="left")
dec.append(f"Junção com IBGE (API localidades) pelo código de 7 dígitos: {b.nome_ibge.notna().sum()} de {len(b)} casados.")
dn=b[b.mun.map(norm)!=b.nome_ibge.map(norm)][["mun","nome_ibge","cod7"]]
dec.append(f"Nomes divergentes entre planilha e IBGE (mantido o código): {dn.values.tolist()}")
# --- malha ---
g=gpd.read_file(SP+"malha/PR_Municipios_2022.shp")
g["cod7"]=g.CD_MUN.astype(int)
dec.append(f"Malha IBGE 2022: {len(g)} polígonos; casados com a base: {g.cod7.isin(b.cod7).sum()}; CRS {g.crs}")
# --- variáveis derivadas ---
b["pcm_padrao"]=(2*b.fe+b.fd+2*b.fs)/500          # (2FE+FD+2FS)/5/100
b["pcm_p3"]=(1*b.fe+b.fd+3*b.fs)/500              # variante usada na faixa P3 da consolidada
b["pcm_dc"]=b.pcm                                  # valor efetivamente usado na consolidada (padrão, exceto P3)
b["pcm_ic"]=b.pcm_ic
assert np.allclose(b.pcm_ic,b.pcm_padrao)
assert np.allclose(np.where(b.porte_dc=="P3",b.pcm_p3,b.pcm_padrao),b.pcm_dc)
dec.append("PCM padrão = (2·FE + FD + 2·FS)/5/100 reproduzido para 399 municípios (IC e DC exceto P3). Na aba Dados da planilha de 27/03/2024, as 62 linhas do porte P3 usam (1·FE + FD + 3·FS)/5/100.")
# etapas
b["tec_ic"]=b.total_ic.astype(int)                 # distribuição técnica inicial (IC, 251 efetivas)
b["cons_prev43"]=b.ipardes43.astype(int)           # etapa prévia (43)
b["cons_pcm257"]=b.pcm257.astype(int)              # etapa PCM consolidada (257)
b["cons_total300"]=b.total300.astype(int)          # consolidada (300)
b["dif_cons_tec"]=b.cons_total300-b.tec_ic
b["contemplado_tec"]=(b.tec_ic>0).astype(int); b["contemplado_cons"]=(b.cons_total300>0).astype(int)
def tipo(r):
    if r.tec_ic>0 and r.cons_total300>0: return "Técnica e consolidada"
    if r.tec_ic>0: return "Somente técnica"
    if r.cons_total300>0: return "Somente consolidada"
    return "Não contemplado"
b["tipologia"]=b.apply(tipo,axis=1)
# rankings
b["rank_pop"]=b["pop"].rank(ascending=False,method="min").astype(int)
b["rank_pop04"]=b.pop04.rank(ascending=False,method="min").astype(int)
b["rank_pcm"]=b.pcm_padrao.rank(ascending=False,method="min").astype(int)
b["rank_fs"]=b.fs.rank(ascending=False,method="min").astype(int)
b["creches_por_10mil_04_cons"]=b.cons_total300/b.pop04*10000
b["creches_por_10mil_04_tec"]=b.tec_ic/b.pop04*10000
ordem=["G2","G1","M2","M1","P4","P3","P2","P1"]
b["porte_dc"]=pd.Categorical(b.porte_dc,ordem,ordered=True); b["porte_ic"]=pd.Categorical(b.porte_ic,ordem,ordered=True)
cols=["cod7","mun","nome_ibge","mesorregiao","microrregiao","regiao_intermediaria","regiao_imediata","pop","pop04","pop514","porte_ic","porte_dc",
 "mat_creche","prop_creche","mat_pre_fund","prop_pre_fund","oferta_priv","oferta_tot","prop_priv","creche_norm","mat_norm","priv_norm","fe",
 "mort_inf","prop04","natalidade","mi_norm","prop04_norm","nat_norm","fd",
 "desnut_prop","cadunico","cad_prop","ipdm_r","desnut_norm","cad_norm","ipdm_norm","fs",
 "pcm_padrao","pcm_p3","pcm_dc","aprox_ic","floor_ic","frac_ic","rank_ic","tec_ic","prop","aprox","total_dc","cons_prev43","cons_pcm257","cons_total300","dif_cons_tec",
 "contemplado_tec","contemplado_cons","tipologia","rank_pop","rank_pop04","rank_pcm","rank_fs","creches_por_10mil_04_cons","creches_por_10mil_04_tec"]
base=b[cols].sort_values("cod7")
base.to_csv("02_base_tratada/base_municipal.csv",index=False)
base.to_excel("02_base_tratada/base_municipal.xlsx",index=False)
gm=g[["cod7","NM_MUN","AREA_KM2","geometry"]].merge(base,on="cod7",how="left")
gm.to_file("02_base_tratada/base_municipal_geo.gpkg",driver="GPKG")
dec.append("Colunas mantidas: "+", ".join(cols))
dec.append(f"Tipologia: {base.tipologia.value_counts().to_dict()}")
open("01_auditoria/log_base_tratada.txt","w").write("\n".join(dec))
print("\n".join(dec))
# dicionário de variáveis
dic={"cod7":"Código IBGE (7 dígitos), aba Educacional","mun":"Nome do município (planilhas)","pop":"População total 2022 (Censo), aba Dados/Demográfico","pop04":"População 0 a 4 anos (Censo 2022) = população-alvo",
"porte_ic":"Porte na planilha Indicador_Criterio_VF (P1 ≤20 mil; P2 20–40 mil; P3 40–70 mil; P4 70–100 mil; M1 100–200 mil; M2 200–500 mil; G1 500 mil–1 mi; G2 >1 mi)",
"porte_dc":"Porte na planilha 20240327 (P1 ≤5 mil; P2 5–20 mil; P3 20–70 mil; demais iguais)",
"fe":"Fator Educação (0–100, min-max sobre média ponderada 2·creche_norm + mat_norm + priv_norm)/4)","fd":"Fator Demográfico (0–100)","fs":"Fator Socioeconômico (0–100)",
"pcm_padrao":"PCM = (2·FE + FD + 2·FS)/500","pcm_p3":"Variante (1·FE + FD + 3·FS)/500 usada na faixa P3 da consolidada","pcm_dc":"PCM efetivamente usado na consolidada",
"tec_ic":"Creches na distribuição técnica inicial (coluna TOTAL CRECHES, Indicador_Criterio_VF; soma 251)","cons_prev43":"Creches da etapa prévia (coluna 'IPARDES (43 creches)')","cons_pcm257":"Creches da etapa PCM consolidada (257)","cons_total300":"Creches na distribuição consolidada (300)",
"aprox":"Valor contínuo J·(1+PCM) − prévia (coluna APROX. CRECHES da aba Dados)","total_dc":"Coluna TOTAL CRECHES da aba Dados (cálculo proporcional sem tetos; não é o resultado final)","tipologia":"Não contemplado / Somente técnica / Somente consolidada / Técnica e consolidada"}
pd.Series(dic).rename_axis("variavel").rename("descricao").to_csv("02_base_tratada/dicionario_variaveis.csv")
