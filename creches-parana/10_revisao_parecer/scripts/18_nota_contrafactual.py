"""Números da nota técnica do contrafactual populacional (material suplementar da revisão RPD).
Uso, na raiz de creches-parana: python3 10_revisao_parecer/scripts/18_nota_contrafactual.py"""
import json
import numpy as np, pandas as pd

b = pd.read_csv("02_base_tratada/base_municipal.csv")

def hamilton(w, total):
    w = np.asarray(w, float); q = w / w.sum() * total; fl = np.floor(q); rem = int(round(total - fl.sum()))
    order = np.argsort(-(q - fl), kind="stable"); add = np.zeros(len(w)); add[order[:rem]] = 1
    return fl + add

prev = b.cons_prev43.values
V = {
    "marco": b.cons_total300.values,
    "maio": b.cedca_258.values,
    "contraf": hamilton(b.pop04, 300),
    "contraf43": prev + hamilton(b.pop04, 257),
}
top80 = b.pcm_padrao.rank(ascending=False, method="first").values <= 80
curitiba = (b.mun == "Curitiba").values
ate20 = b.porte_dc.isin(["P1", "P2"]).values
out = {}
for k, v in V.items():
    v = np.asarray(v, float); tot = v.sum(); c = v > 0
    out[k] = {
        "unidades": int(tot),
        "municipios": int(c.sum()),
        "curitiba": int(v[curitiba].sum()),
        "max_mun": int(v.max()),
        "top10_pct": round(np.sort(v)[::-1][:10].sum() / tot * 100, 1),
        "top80pcm_pct": round(v[top80].sum() / tot * 100, 1),
        "top80pcm_mun": int((c & top80).sum()),
        "ate20mil_mun": int((c & ate20).sum()),
        "ate20mil_unid": int(v[ate20].sum()),
        "p1_mun": int((c & (b.porte_dc == "P1").values).sum()),
        "cob_pop04_pct": round(b.pop04[c].sum() / b.pop04.sum() * 100, 1),
        "pcm_medio_unid": round(float(np.average(b.pcm_padrao, weights=v)), 3),
        "comuns_maio": int((c & (b.cedca_258.values > 0)).sum()),
    }
q = b.pop04 / b.pop04.sum() * 300
out["limiar"] = {"pop04_total": int(b.pop04.sum()), "criancas_por_unidade": round(b.pop04.sum() / 300, 1),
                 "pop04_min_contemplado": int(b.pop04[V["contraf"] > 0].min()),
                 "cota_max_nao_contemplado": round(float(q[V["contraf"] == 0].max()), 3)}
out["pcm_medio_estado"] = round(float(b.pcm_padrao.mean()), 3)
print(json.dumps(out, ensure_ascii=False, indent=1))
