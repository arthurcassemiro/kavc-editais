# A5: VAR e VEC (baseline replicado, corrigido, estendido e robustez)

Gerado por R/A5_var.R em 2026-09-28 23:30. Numeros com virgula decimal. Elasticidade de longo prazo = resposta acumulada de PVD em h = 40 dividida pela de INF, ao mesmo choque ortogonal em INF (INF antes de PVD). IC 90% por bootstrap de residuos (percentil). Tabela completa em data/processed/A5_var_resultados.csv; Johansen em data/processed/A5_johansen.csv.

## 1. Baseline replicado e corrigido, correcao a correcao

| Amostra | Modelo | Especificacao | n | Impacto | PVD h40 | INF h40 | Elasticidade | IC 90% | Granger INF->PVD | Granger PVD->INF |
|---|---|---|---|---|---|---|---|---|---|---|
| 2002-2019 original | VAR em diferenca | baseline replicado (arquivos da dissertacao) | 68 | 0,0118 | 0,0194 | 0,0465 | 0,42 | [0,05; 0,66] | 0,024 | 0,288 |
| 2003-2019 | VAR em diferenca | (a0) arquivos originais, niveis de 2003T1 a 2019T4 (so a amostra muda) | 64 | 0,0125 | 0,0217 | 0,0445 | 0,49 | [0,11; 0,76] | 0,016 | 0,395 |
| 2003-2019 | VAR em diferenca | (a) INF nominal reconstruido (inf_diss_nominal_2019), PVD e exogenas originais | 64 | 0,0127 | 0,0216 | 0,0452 | 0,48 | [0,11; 0,75] | 0,019 | 0,463 |
| 2003-2019 | VAR em diferenca | (b) INF real (inf_diss), PVD e exogenas originais | 64 | 0,0132 | 0,0230 | 0,0482 | 0,48 | [0,14; 0,72] | 0,027 | 0,336 |
| 2003-2019 | VAR em diferenca | (c0) INF real, PVD atual (fbcf_me_sa), exogenas originais | 64 | 0,0122 | 0,0220 | 0,0482 | 0,46 | [0,11; 0,70] | 0,020 | 0,295 |
| 2003-2019 | VAR em diferenca | (c) INF real, PVD atual, PIB (safra atual) e Selic meta fim do BCB, DUM (baseline corrigido) | 64 | 0,0120 | 0,0217 | 0,0483 | 0,45 | [0,10; 0,69] | 0,017 | 0,297 |
| 2003-2025 | VAR em diferenca | estendida: INF real, PVD atual, diff PIB, diff Selic, pulsos 2020T2 e 2020T3 | 88 | 0,0023 | 0,0098 | 0,0567 | 0,17 | [-0,03; 0,36] | 0,404 | 0,180 |

Alvos do replicado: impacto 0,0118, acumulada de PVD 0,0194, de INF 0,0465 e elasticidade 0,42: reproduzidos (0,0118; 0,0194; 0,0465; 0,4163).

Leitura dos passos: (a0) so muda a amostra (niveis a partir de 2003T1, perde 2002); (a) troca o INF do arquivo pela reconstrucao nominal; 
(b) passa a INF real; (c0) troca o PVD pelo indice atual do Ipea; (c) troca o PIB pela safra atual e a Selic pela serie do BCB (identica ao JUR).

## 2. Johansen e escolha VAR x VEC

| Amostra | ecdet | H0 | T | Traco | Traco RA | VC 5% | VC 10% | p bootstrap |
|---|---|---|---|---|---|---|---|---|
| 2002-2019 original | trend | r = 0 | 69 | 24,19 | 22,09 | 25,32 | 22,76 | 0,170 |
| 2002-2019 original | trend | r <= 1 | 69 | 4,15 | 3,79 | 12,25 | 10,49 | 0,840 |
| 2002-2019 original | const | r = 0 | 69 | 23,49 | 21,45 | 19,96 | 17,85 | 0,036 |
| 2002-2019 original | const | r <= 1 | 69 | 4,12 | 3,76 | 9,24 | 7,52 | 0,483 |
| 2003-2019 | trend | r = 0 | 65 | 28,79 | 26,13 | 25,32 | 22,76 | 0,086 |
| 2003-2019 | trend | r <= 1 | 65 | 7,81 | 7,09 | 12,25 | 10,49 | 0,469 |
| 2003-2019 | const | r = 0 | 65 | 19,51 | 17,71 | 19,96 | 17,85 | 0,175 |
| 2003-2019 | const | r <= 1 | 65 | 3,47 | 3,15 | 9,24 | 7,52 | 0,629 |
| 2003-2025 | trend | r = 0 | 89 | 26,29 | 24,52 | 25,32 | 22,76 | 0,124 |
| 2003-2025 | trend | r <= 1 | 89 | 6,20 | 5,78 | 12,25 | 10,49 | 0,494 |
| 2003-2025 | const | r = 0 | 89 | 16,31 | 15,21 | 19,96 | 17,85 | 0,241 |
| 2003-2025 | const | r <= 1 | 89 | 4,39 | 4,09 | 9,24 | 7,52 | 0,295 |

Traco RA: com correcao de Reinsel-Ahn, (T - pK)/T. VC: valores criticos assintoticos do urca. p bootstrap: bootstrap selvagem de Cavaliere, Rahbek e Taylor (2012), 999 replicas.

| Amostra | Traco (trend) | Traco RA | VC 5% | Assintotico a 5% | Reinsel-Ahn a 5% | p boot r = 0 (trend) | p boot r = 0 (const) | Evidencia | Decisao |
|---|---|---|---|---|---|---|---|---|---|
| 2002-2019 original | 24,19 | 22,09 | 25,32 | nao rejeita | nao rejeita | 0,170 | 0,036 | limitrofe | VAR em diferenca baseline pelo bootstrap; VECM ao lado na A6 |
| 2003-2019 | 28,79 | 26,13 | 25,32 | rejeita | rejeita | 0,086 | 0,175 | limitrofe | VAR em diferenca baseline pelo bootstrap; VECM ao lado na A6 |
| 2003-2025 | 26,29 | 24,52 | 25,32 | rejeita | nao rejeita | 0,124 | 0,241 | limitrofe | VAR em diferenca baseline pelo bootstrap; VECM ao lado na A6 |

Quando as leituras divergem, prevalece o bootstrap: (i) nas amostras 2002-2019 e 2003-2019 a DUM da dissertacao entra em nivel na parte irrestrita do VECM, o que gera tendencia quebrada nos niveis e muda a distribuicao assintotica do traco (Johansen, Mosconi e Nielsen, 2000), de modo que os valores criticos tabelados, com ou sem Reinsel-Ahn, nao valem; o bootstrap gera os dados com a mesma DUM; (ii) com T de 64 a 88 o teste assintotico rejeita demais, e Reinsel-Ahn e so um fator de escala. Evidencia limitrofe: o bootstrap nao rejeita a 5%, mas o assintotico, Reinsel-Ahn, o bootstrap a 10% ou o caso ecdet const rejeitam. Em 2003-2019 o traco assintotico e o corrigido por Reinsel-Ahn rejeitam r = 0 a 5%; so o bootstrap nao rejeita. A escolha pesa no numero, e a A6 deve mostrar o VECM ao lado do VAR em diferenca.

## 3. VECM com r = 1 e VAR em nivel

| Amostra | Especificacao | n | Impacto | PVD h40 (nivel) | INF h40 (nivel) | Razao h40 | IC 90% | Vetor (PVD) | IC 90% vetor | alfa INF (t) | alfa PVD (t) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2002-2019 original | VECM r = 1, ecdet trend, exogenas do VAR em diferenca; ao lado do VAR (evidencia limitrofe; bootstrap nao rejeita r = 0) | 69 | 0,0138 | 0,0151 | 0,0260 | 0,58 | [0,42; 0,82] | 0,58 | [0,42; 0,82] | 0,719 (3,81) | -0,032 (-0,32) |
| 2002-2019 original | VECM r = 1, ecdet trend, so dumvar deterministicas do teste | 69 | 0,0131 | 0,0129 | 0,0229 | 0,56 | [0,37; 0,94] | 0,56 | [0,37; 0,93] | 0,751 (3,94) | -0,045 (-0,44) |
| 2002-2019 original | VECM r = 1, ecdet const, exogenas do VAR em diferenca | 69 | 0,0131 | 0,0123 | 0,0238 | 0,52 | [0,39; 0,68] | 0,52 | [0,39; 0,68] | 0,632 (3,90) | 0,024 (0,28) |
| 2003-2019 | VECM r = 1, ecdet trend, exogenas do VAR em diferenca; ao lado do VAR (evidencia limitrofe; bootstrap nao rejeita r = 0) | 65 | 0,0138 | 0,0183 | 0,0332 | 0,55 | [0,40; 0,76] | 0,55 | [0,40; 0,76] | 0,727 (3,36) | -0,131 (-1,14) |
| 2003-2019 | VECM r = 1, ecdet trend, so dumvar deterministicas do teste | 65 | 0,0142 | 0,0177 | 0,0318 | 0,56 | [0,38; 0,81] | 0,56 | [0,38; 0,81] | 0,761 (3,40) | -0,159 (-1,35) |
| 2003-2019 | VECM r = 1, ecdet const, exogenas do VAR em diferenca | 65 | 0,0124 | 0,0250 | 0,0428 | 0,58 | [0,38; 0,82] | 0,58 | [0,38; 0,82] | 0,241 (1,33) | -0,195 (-2,27) |
| 2003-2025 | VECM r = 1, ecdet trend, exogenas do VAR em diferenca; ao lado do VAR (evidencia limitrofe; bootstrap nao rejeita r = 0) | 89 | 0,0060 | 0,0179 | 0,0352 | 0,51 | [0,36; 0,66] | 0,51 | [0,36; 0,66] | 0,618 (3,36) | -0,256 (-2,72) |
| 2003-2025 | VECM r = 1, ecdet trend, so dumvar deterministicas do teste | 89 | 0,0064 | 0,0189 | 0,0363 | 0,52 | [0,35; 0,74] | 0,52 | [0,35; 0,74] | 0,557 (3,01) | -0,251 (-2,73) |
| 2003-2025 | VECM r = 1, ecdet const, exogenas do VAR em diferenca | 89 | 0,0042 | 0,0209 | 0,0445 | 0,47 | [0,24; 0,71] | 0,47 | [0,24; 0,71] | 0,232 (1,79) | -0,179 (-2,83) |

Razao h40: resposta de PVD em nivel em h = 40 sobre a de INF (nivel = acumulada da diferenca). Vetor (PVD): elasticidade de longo prazo do vetor de cointegracao normalizado em PVD (PVD = elasticidade x INF + tendencia + erro estacionario). alfa: carregamentos do termo de correcao com beta normalizado em PVD (t de MQO do cajorls entre parenteses); alfa negativo em PVD indica que PVD corrige desvios do equilibrio, alfa positivo em INF indica que INF sobe quando PVD esta acima do equilibrio.

| Amostra | Modelo | Especificacao | n | Impacto | PVD h40 | INF h40 | Elasticidade | IC 90% | Granger INF->PVD | Granger PVD->INF |
|---|---|---|---|---|---|---|---|---|---|---|
| 2002-2019 original | VAR em nivel | VAR(3) em nivel, exogenas em nivel | 69 | 0,0085 | 0,0029 | 0,0054 | 0,54 | [0,44; 0,69] | 0,030 | 0,521 |
| 2003-2019 | VAR em nivel | VAR(3) em nivel, exogenas em nivel | 65 | 0,0082 | 0,0022 | 0,0040 | 0,56 | [0,46; 0,68] | 0,038 | 0,490 |
| 2003-2025 | VAR em nivel | VAR(3) em nivel, exogenas em nivel | 89 | 0,0054 | 0,0013 | 0,0027 | 0,50 | [0,38; 0,71] | 0,243 | 0,030 |

No VAR em nivel, as colunas de Granger trazem o teste de Toda-Yamamoto; o Granger padrao esta na coluna obs do CSV.

## 4. Robustez principal (PIB em taxa, Cholesky invertida, 2 e 4 defasagens, subamostras, dummies)

Estas sao as robustezes pedidas no briefing e a sintese da robustez. IC de 90% inclui zero: 2003-2019: ordem de Cholesky invertida (PVD antes de INF); p = 2. 2003-2025: BASELINE: estendida: INF real, PVD atual, diff PIB, diff Selic, pulsos 2020T2 e 2020T3; PIB em taxa de crescimento (sem diferenciar); ordem de Cholesky invertida (PVD antes de INF); p = 2; com imp2017 (indicadora de 2017, sem diferenciar); subamostra: observacoes efetivas 2004T1-2014T4; subamostra: observacoes efetivas 2015T1-2025T4 (niveis desde 2014T1).

| Amostra | Especificacao | n | Elasticidade | IC 90% | IC inclui zero |
|---|---|---|---|---|---|
| 2003-2019 | BASELINE: (c) INF real, PVD atual, PIB (safra atual) e Selic meta fim do BCB, DUM (baseline corrigido) | 64 | 0,449 | [0,10; 0,69] | nao |
| 2003-2019 | PIB em taxa de crescimento (sem diferenciar) | 64 | 0,227 | [0,02; 0,39] | nao |
| 2003-2019 | ordem de Cholesky invertida (PVD antes de INF) | 64 | 0,074 | [-0,25; 0,30] | sim |
| 2003-2019 | p = 2 | 65 | 0,062 | [-0,25; 0,31] | sim |
| 2003-2019 | p = 4 | 63 | 0,431 | [0,12; 0,64] | nao |
| 2003-2019 | com imp2017 (indicadora de 2017, sem diferenciar) | 64 | 0,453 | [0,16; 0,67] | nao |
| 2003-2019 | INF = inf_diss_semao | 64 | 0,440 | [0,03; 0,73] | nao |
| 2003-2025 | BASELINE: estendida: INF real, PVD atual, diff PIB, diff Selic, pulsos 2020T2 e 2020T3 | 88 | 0,173 | [-0,03; 0,36] | sim |
| 2003-2025 | PIB em taxa de crescimento (sem diferenciar) | 88 | 0,099 | [-0,06; 0,24] | sim |
| 2003-2025 | ordem de Cholesky invertida (PVD antes de INF) | 88 | 0,139 | [-0,00; 0,27] | sim |
| 2003-2025 | p = 2 | 89 | 0,108 | [-0,08; 0,28] | sim |
| 2003-2025 | p = 4 | 87 | 0,279 | [0,05; 0,44] | nao |
| 2003-2025 | com imp2017 (indicadora de 2017, sem diferenciar) | 88 | 0,195 | [-0,01; 0,37] | sim |
| 2003-2025 | INF = inf_diss_semao | 88 | 0,296 | [0,09; 0,49] | nao |
| 2003-2025 | dummies_A4: outliers do X-11 de inf_diss de 2018-2021 (A4_dummies_quebra.csv), alem dos pulsos | 88 | 0,344 | [0,12; 0,55] | nao |
| ate 2014T4 | subamostra: observacoes efetivas 2004T1-2014T4 | 44 | 0,227 | [-0,37; 0,53] | sim |
| de 2015T1 | subamostra: observacoes efetivas 2015T1-2025T4 (niveis desde 2014T1) | 44 | 0,059 | [-0,17; 0,26] | sim |

## 5. Robustez do VAR em diferenca, todas as especificacoes (1000 replicas)

| Amostra | Especificacao | n | Impacto | PVD h40 | Elasticidade | IC 90% | Granger INF->PVD |
|---|---|---|---|---|---|---|---|
| 2003-2019 | PIB em taxa de crescimento (sem diferenciar) | 64 | 0,0093 | 0,0094 | 0,23 | [0,02; 0,39] | 0,008 |
| 2003-2019 | ordem de Cholesky invertida (PVD antes de INF) | 64 | 0,0000 | 0,0027 | 0,07 | [-0,25; 0,30] | 0,017 |
| 2003-2019 | p = 2 | 65 | 0,0102 | 0,0029 | 0,06 | [-0,25; 0,31] | 0,139 |
| 2003-2019 | p = 4 | 63 | 0,0124 | 0,0207 | 0,43 | [0,12; 0,64] | 0,021 |
| 2003-2019 | controle: cambio real efetivo | 64 | 0,0125 | 0,0225 | 0,46 | [0,10; 0,73] | 0,017 |
| 2003-2019 | controle: IC-Br em US$ | 64 | 0,0126 | 0,0212 | 0,43 | [0,13; 0,66] | 0,010 |
| 2003-2019 | controle: Brent | 64 | 0,0123 | 0,0204 | 0,42 | [0,10; 0,65] | 0,031 |
| 2003-2019 | controle: BNDES exceto adm. publica | 64 | 0,0120 | 0,0227 | 0,46 | [0,12; 0,72] | 0,021 |
| 2003-2019 | controles: cambio real efetivo e IC-Br em US$ | 64 | 0,0127 | 0,0211 | 0,44 | [0,12; 0,67] | 0,011 |
| 2003-2019 | controles: cambio real efetivo e Brent | 64 | 0,0125 | 0,0206 | 0,43 | [0,10; 0,66] | 0,038 |
| 2003-2019 | controles: cambio real efetivo e BNDES exceto adm. publica | 64 | 0,0125 | 0,0236 | 0,47 | [0,12; 0,73] | 0,021 |
| 2003-2019 | controles: IC-Br em US$ e Brent | 64 | 0,0128 | 0,0211 | 0,43 | [0,13; 0,67] | 0,020 |
| 2003-2019 | controles: IC-Br em US$ e BNDES exceto adm. publica | 64 | 0,0127 | 0,0219 | 0,44 | [0,14; 0,66] | 0,012 |
| 2003-2019 | controles: Brent e BNDES exceto adm. publica | 64 | 0,0123 | 0,0213 | 0,43 | [0,11; 0,66] | 0,036 |
| 2003-2019 | Selic meta, media do trimestre | 64 | 0,0117 | 0,0211 | 0,45 | [0,09; 0,70] | 0,015 |
| 2003-2019 | excluir 2016T4-2018T1 (um pulso por trimestre) | 64 | 0,0136 | 0,0244 | 0,48 | [0,16; 0,70] | 0,019 |
| 2003-2019 | com imp2017 (indicadora de 2017, sem diferenciar) | 64 | 0,0122 | 0,0221 | 0,45 | [0,16; 0,67] | 0,009 |
| 2003-2019 | INF = inf_diss_e2017 | 64 | 0,0119 | 0,0221 | 0,45 | [0,11; 0,73] | 0,014 |
| 2003-2019 | INF = inf_diss_e2018 | 64 | 0,0121 | 0,0222 | 0,46 | [0,12; 0,74] | 0,016 |
| 2003-2019 | INF = inf_diss_e2019 | 64 | 0,0121 | 0,0225 | 0,46 | [0,12; 0,73] | 0,015 |
| 2003-2019 | INF = inf_diss_e2020 | 64 | 0,0118 | 0,0217 | 0,45 | [0,10; 0,70] | 0,014 |
| 2003-2019 | INF = inf_diss_e2020_r1618 | 64 | 0,0121 | 0,0217 | 0,45 | [0,10; 0,71] | 0,018 |
| 2003-2019 | INF = inf_diss_imprazao | 64 | 0,0123 | 0,0217 | 0,46 | [0,10; 0,71] | 0,025 |
| 2003-2019 | INF = inf_diss_x11soma | 64 | 0,0104 | 0,0204 | 0,42 | [0,09; 0,66] | 0,014 |
| 2003-2019 | INF = inf_diss_semao | 64 | 0,0097 | 0,0181 | 0,44 | [0,03; 0,73] | 0,042 |
| 2003-2019 | sem a DUM da dissertacao | 64 | 0,0130 | 0,0209 | 0,45 | [0,12; 0,70] | 0,037 |
| 2003-2025 | PIB em taxa de crescimento (sem diferenciar) | 88 | 0,0020 | 0,0053 | 0,10 | [-0,06; 0,24] | 0,741 |
| 2003-2025 | ordem de Cholesky invertida (PVD antes de INF) | 88 | 0,0000 | 0,0077 | 0,14 | [-0,00; 0,27] | 0,404 |
| 2003-2025 | p = 2 | 89 | 0,0021 | 0,0060 | 0,11 | [-0,08; 0,28] | 0,409 |
| 2003-2025 | p = 4 | 87 | 0,0043 | 0,0135 | 0,28 | [0,05; 0,44] | 0,250 |
| 2003-2025 | controle: cambio real efetivo | 88 | 0,0023 | 0,0099 | 0,17 | [-0,03; 0,35] | 0,410 |
| 2003-2025 | controle: IC-Br em US$ | 88 | 0,0037 | 0,0107 | 0,19 | [0,00; 0,34] | 0,383 |
| 2003-2025 | controle: Brent | 88 | 0,0036 | 0,0108 | 0,19 | [0,01; 0,35] | 0,349 |
| 2003-2025 | controle: BNDES exceto adm. publica | 88 | 0,0023 | 0,0107 | 0,19 | [-0,01; 0,36] | 0,323 |
| 2003-2025 | controles: cambio real efetivo e IC-Br em US$ | 88 | 0,0033 | 0,0108 | 0,19 | [0,02; 0,34] | 0,283 |
| 2003-2025 | controles: cambio real efetivo e Brent | 88 | 0,0031 | 0,0109 | 0,19 | [0,02; 0,35] | 0,267 |
| 2003-2025 | controles: cambio real efetivo e BNDES exceto adm. publica | 88 | 0,0023 | 0,0108 | 0,19 | [-0,01; 0,36] | 0,332 |
| 2003-2025 | controles: IC-Br em US$ e Brent | 88 | 0,0039 | 0,0109 | 0,19 | [0,01; 0,35] | 0,369 |
| 2003-2025 | controles: IC-Br em US$ e BNDES exceto adm. publica | 88 | 0,0037 | 0,0115 | 0,20 | [0,02; 0,35] | 0,316 |
| 2003-2025 | controles: Brent e BNDES exceto adm. publica | 88 | 0,0035 | 0,0117 | 0,20 | [0,02; 0,36] | 0,275 |
| 2003-2025 | Selic meta, media do trimestre | 88 | 0,0021 | 0,0091 | 0,16 | [-0,04; 0,34] | 0,469 |
| 2003-2025 | excluir 2016T4-2018T1 (um pulso por trimestre) | 88 | 0,0031 | 0,0112 | 0,20 | [-0,02; 0,39] | 0,353 |
| 2003-2025 | com imp2017 (indicadora de 2017, sem diferenciar) | 88 | 0,0027 | 0,0110 | 0,20 | [-0,01; 0,37] | 0,315 |
| 2003-2025 | INF = inf_diss_e2017 | 88 | 0,0030 | 0,0119 | 0,20 | [0,01; 0,37] | 0,288 |
| 2003-2025 | INF = inf_diss_e2018 | 88 | 0,0030 | 0,0118 | 0,20 | [0,01; 0,37] | 0,285 |
| 2003-2025 | INF = inf_diss_e2019 | 88 | 0,0031 | 0,0117 | 0,20 | [0,01; 0,37] | 0,298 |
| 2003-2025 | INF = inf_diss_e2020 | 88 | 0,0025 | 0,0106 | 0,18 | [-0,02; 0,35] | 0,357 |
| 2003-2025 | INF = inf_diss_e2020_r1618 | 88 | 0,0023 | 0,0095 | 0,17 | [-0,04; 0,35] | 0,420 |
| 2003-2025 | INF = inf_diss_imprazao | 88 | 0,0024 | 0,0096 | 0,17 | [-0,04; 0,35] | 0,417 |
| 2003-2025 | INF = inf_diss_x11soma | 88 | 0,0015 | 0,0103 | 0,18 | [-0,02; 0,34] | 0,244 |
| 2003-2025 | INF = inf_diss_semao | 88 | 0,0068 | 0,0143 | 0,30 | [0,09; 0,49] | 0,061 |
| 2003-2025 | dummies_A4: outliers do X-11 de inf_diss de 2018-2021 (A4_dummies_quebra.csv), alem dos pulsos | 88 | 0,0060 | 0,0195 | 0,34 | [0,12; 0,55] | 0,131 |
| ate 2014T4 | subamostra: observacoes efetivas 2004T1-2014T4 | 44 | 0,0006 | 0,0111 | 0,23 | [-0,37; 0,53] | 0,279 |
| de 2015T1 | subamostra: observacoes efetivas 2015T1-2025T4 (niveis desde 2014T1) | 44 | 0,0028 | 0,0036 | 0,06 | [-0,17; 0,26] | 0,961 |

## 6. Resumo das demais variantes (controles, Selic media, variantes de INF da A3, exclusao de 2016T4-2018T1, sem DUM)

Estas variantes sao quase iguais entre si e nao resumem a robustez; a robustez principal esta na secao 4.

| Amostra | Especificacoes | Elasticidade min | Elasticidade max | Mediana | IC acima de zero | Granger a 5% |
|---|---|---|---|---|---|---|
| 2003-2019 | 20 | 0,42 | 0,48 | 0,45 | 20 | 20 |
| 2003-2025 | 19 | 0,16 | 0,20 | 0,19 | 10 | 0 |
