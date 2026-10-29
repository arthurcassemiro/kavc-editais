"""Coluna de população da aba Demográfico, valor de m e cota fixa dos portes grandes (revisão do parecer RPD).
Uso, na raiz de creches-parana: python3 10_revisao_parecer/scripts/17_populacao_alvo_e_m.py"""
import json, csv
import numpy as np, pandas as pd

b = pd.read_csv("02_base_tratada/base_municipal.csv")
D = "01_auditoria/dump"

# 1. A coluna "População 0 a 4" da aba Demográfico (março) é a população de 5 a 14 anos
de = pd.read_csv(f"{D}/DC__Demográfico__valores.csv").rename(columns={"Unnamed: 0": "mun"})
m = b.merge(de[["mun", "População 0 a 4"]], on="mun", how="left")
print("Demográfico 'População 0 a 4' = pop 5-14 da aba Educacional? dif. máx.:", float((m["População 0 a 4"] - m.pop514).abs().max()))
print("soma estadual da coluna:", int(m["População 0 a 4"].sum()), "| pop 0-4 (Educacional):", int(b.pop04.sum()))
sid = pd.DataFrame(json.load(open("10_revisao_parecer/scripts/sidra_9514_censo2022_idade_uf.json"))[1:])
sid["V"] = pd.to_numeric(sid.V)
p = sid.pivot_table(index="D1N", columns="D5N", values="V", aggfunc="sum")
p["s04"] = p["0 a 4 anos"] / p["Total"] * 100
p["s514"] = (p["5 a 9 anos"] + p["10 a 14 anos"]) / p["Total"] * 100
uf = p.drop(index="Brasil")
print("Censo 2022, PR 5-14:", int(p.loc["Paraná", "5 a 9 anos"] + p.loc["Paraná", "10 a 14 anos"]),
      "| participação 5-14 PR/BR: %.2f / %.2f, posição PR (menor=1): %d" % (p.loc["Paraná", "s514"], p.loc["Brasil", "s514"], uf.s514.rank(method="min")["Paraná"]),
      "| 0-4 PR/BR: %.2f / %.2f, posição %d" % (p.loc["Paraná", "s04"], p.loc["Brasil", "s04"], uf.s04.rank(method="min")["Paraná"]))

# 2. Efeito de usar a população de 0 a 4 anos no indicador PC
def mm(x): return (x - x.min()) / (x.max() - x.min()) * 100
def sp(a, c): return pd.Series(a).rank().corr(pd.Series(c).rank())
fd2 = mm((b.mi_norm + mm(b.pop04 / b["pop"]) + b.nat_norm) / 3)
pcm2 = (2 * b.fe + fd2 + 2 * b.fs) / 500
prev = b.cons_prev43 > 0
cot = {"P3": 27, "P2": 100, "P1": 30}
def sel(score):
    s = set()
    for pt, n in cot.items():
        msk = (b.porte_dc == pt) & ~prev
        s |= set(score[msk].nlargest(n).index)
    return s
print("PC com 0-4 anos: Spearman PCM = %.3f | seleção mantida %d/157 | quintil superior mantido %d/80"
      % (sp(b.pcm_padrao, pcm2), len(sel(b.pcm_padrao) & sel(pcm2)), len(set(b.nlargest(80, "pcm_padrao").index) & set(pcm2.nlargest(80).index))))

# 3. Valor de m: fórmula na planilha técnica inicial (IC) e valor digitado nas de março (DC) e maio (CF)
for pref in ["IC", "DC", "CF"]:
    for nome in ["Controle", "Metodologia"]:
        try:
            rows = list(csv.reader(open(f"{D}/{pref}__{nome}__formulas.csv", encoding="utf8")))
        except FileNotFoundError:
            continue
        for r in rows:
            if r and r[0] == "PCM Ponderado":
                print(f"{pref} {nome}: PCM Ponderado = {r[2]}")
ci = list(csv.reader(open(f"{D}/IC__CI__valores.csv", encoding="utf8")))
print("IC CI!T402 (valor):", ci[401][19], "| PCM ponderado pela coluna de 5-14 anos:", round(np.average(b.pcm_padrao, weights=b.pop514), 5))

# 4. Bloco 2: cota fixa de 100 com maior resto e tetos; efeito de m e da população
big = b.porte_dc.isin(["G2", "G1", "M2", "M1", "P4"]).values
caps = b.porte_dc[big].map({"G2": 10, "G1": 8, "M2": 7, "M1": 4, "P4": 2}).values
def hamilton(w, total):
    w = np.asarray(w, float); q = w / w.sum() * total; fl = np.floor(q); rem = int(round(total - fl.sum()))
    order = np.argsort(-(q - fl), kind="stable"); add = np.zeros(len(w)); add[order[:rem]] = 1
    return fl + add
def hamilton_cap(w, total, cap):
    w = np.asarray(w, float); alloc = np.zeros(len(w)); active = np.ones(len(w), bool); rem = total
    for _ in range(30):
        a = hamilton(w[active], rem); tmp = np.zeros(len(w)); tmp[active] = a
        over = (tmp > cap) & active
        if not over.any():
            alloc[active] = a; break
        alloc[over] = cap[over]; rem -= int(cap[over].sum()); active &= ~over
    return alloc
def bloco2(pop, mval):
    K = (pop / pop.sum()).values * 257 / (1 + mval) * (1 + b.pcm_padrao.values) - b.cons_prev43.values
    return hamilton_cap(K[big], 100, caps)
obs = b.cons_pcm257.values[big]
a503, a438, a04 = bloco2(b.pop514, 0.50314), bloco2(b.pop514, 0.43813), bloco2(b.pop04, 0.50314)
print("Bloco 2 reproduzido (5-14, m=0,503): %d/30 iguais ao observado | m=0,438 idêntico: %s" % ((a503 == obs).sum(), bool((a503 == a438).all())))
print("Bloco 2 com pop 0-4: %d municípios diferentes, %d unidades deslocadas" % (((a04 - a503) != 0).sum(), (a04 - a503)[(a04 - a503) > 0].sum()))
print("Só tetos sobre o maior resto (sem cota fixa):", int(np.minimum(b.total_dc.values[big], caps).sum()), "unidades")
