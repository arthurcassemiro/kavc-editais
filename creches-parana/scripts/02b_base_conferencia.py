"""Incorpora à base tratada a versão de 21/05/2024 da planilha (aba oculta Conferência: 'versão atual, limitador menor',
300 creches em 258 municípios, apresentada ao CEDCA) e registra a entrega do PPA 2024-2027 relacionada a creches."""
import pandas as pd, geopandas as gpd
b=pd.read_csv("02_base_tratada/base_municipal.csv")
c=pd.read_csv("01_auditoria/dump/CF__Conferência__valores.csv",header=None); c.columns=c.iloc[0]; c=c.iloc[1:]
c=c.rename(columns={"MUNICÍPIO":"mun","VERSÃO ATUAL (LIMITADOR MENOR)":"cedca_258","VERSÃO ANTIGA (LIMITADOR MAIOR)":"cons_conf"})
c["cedca_258"]=pd.to_numeric(c["cedca_258"]).astype(int); c["cons_conf"]=pd.to_numeric(c["cons_conf"]).astype(int)
m=b.drop(columns=[x for x in ["cedca_258"] if x in b]).merge(c[["mun","cedca_258","cons_conf"]],on="mun",how="left")
assert m.cedca_258.notna().all() and (m.cons_conf==m.cons_total300).all()
m=m.drop(columns=["cons_conf"])
m["dif_pub_cedca"]=m.pub_res219-m.cedca_258
m.to_csv("02_base_tratada/base_municipal.csv",index=False); m.to_excel("02_base_tratada/base_municipal.xlsx",index=False)
g=gpd.read_file("02_base_tratada/base_municipal_geo.gpkg")
g=g.drop(columns=[x for x in ["cedca_258","dif_pub_cedca"] if x in g]).merge(m[["cod7","cedca_258","dif_pub_cedca"]],on="cod7",how="left")
g.to_file("02_base_tratada/base_municipal_geo.gpkg",driver="GPKG")
d=pd.read_csv("02_base_tratada/dicionario_variaveis.csv")
d=d[~d.variavel.isin(["cedca_258","dif_pub_cedca"])]
d=pd.concat([d,pd.DataFrame({"variavel":["cedca_258","dif_pub_cedca"],"descricao":["Creches na versão de 21/05/2024 apresentada ao CEDCA (aba Conferência, 'versão atual, limitador menor'; 300 creches em 258 municípios)","Lista publicada (Res. SEDEF 219/2024) menos versão de 21/05/2024 (+1 em três municípios)"]})])
d.to_csv("02_base_tratada/dicionario_variaveis.csv",index=False)
print("cedca_258: creches",m.cedca_258.sum(),"municípios",(m.cedca_258>0).sum(),"| difere da publicada em",(m.dif_pub_cedca!=0).sum(),"municípios:",m.loc[m.dif_pub_cedca!=0,"mun"].tolist())
