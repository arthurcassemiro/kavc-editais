# A1. Replica em R do modelo final da dissertacao

Gerado por `R/A1_replica.R` em 2026-09-28 19:48. Numeros com virgula decimal. Respostas em log10 (os dados estao em log10).

## Especificacao

- Dados: `data/original/0224_tri_estmeq.txt` (INF e PVD em log10) e `data/original/0124_inexo.txt` (PIB em variacao trimestral, JUR = Selic, DUM), 72 trimestres de 2002Q1 a 2019Q4.
- Modelo: `vars::VAR(diff(infmeq), p = 3, type = "both", exogen = diff(exo))`, 68 observacoes efetivas (2003Q1 a 2019Q4). Choque ortogonal por Cholesky com INF antes de PVD.
- Datas conferidas com `data/dados_dissertacao_apendiceA.csv` (que tem a coluna de trimestre): Selic identica ao JUR (diferenca maxima 0), PIB identico a cpib_pct/100, correlacao de diff(log10(imeq_indice)) com diff(PVD) = 1,0000.
- Dummy: DUM = 1 em 2018Q2-2019Q1 e 2019Q3-2019Q4. Confere com o esperado. Em diferenca vira pulsos (2018Q2: +1; 2019Q2: -1; 2019Q3: +1).

## Comparacao com os alvos

| Item | Alvo | Obtido (4 casas) | Obtido (6 alg.) | Reproduz |
|---|---|---|---|---|
| Impacto ortogonal de INF em PVD (h = 0) | 0,0118 | 0,0118 | 0,0118311 | sim |
| Resposta acumulada de PVD, h = 40 | 0,0194 | 0,0194 | 0,0193671 | sim |
| Resposta acumulada de INF, h = 40 | 0,0465 | 0,0465 | 0,0465203 | sim |
| Elasticidade de longo prazo (PVD/INF acumulados, h = 40) | 0,42 | 0,4163 | 0,416315 | sim |
| var(u_INF) | 0,0039 | 0,0040 | 0,00398433 | sim, por truncamento (arredondado: 0,0040) |
| cov(u_INF, u_PVD) | 0,0007 | 0,0007 | 0,000746794 | sim |
| var(u_PVD) | 0,0008 | 0,0009 | 0,000850646 | sim, por truncamento (arredondado: 0,0009) |
| corr(u_INF, u_PVD) | 0,405 | 0,4056 | 0,405648 | sim, por truncamento (arredondado: 0,406) |
| Granger INF -> PVD, VAR em diferenca, F | 3,27 | 3,2710 | 3,27095 | sim |
| Granger INF -> PVD, VAR em diferenca, p | 0,024 | 0,0238 | 0,0238242 | sim |
| Granger PVD -> INF, VAR em diferenca, F | 1,91 | 1,2694 |  1,2694 | nao |
| Granger PVD -> INF, VAR em diferenca, p | 0,13 | 0,2883 | 0,288303 | nao |
| Granger PVD -> INF, VAR em nivel, F | 1,91 | 1,9088 | 1,90879 | sim |
| Granger PVD -> INF, VAR em nivel, p | 0,13 | 0,1320 | 0,13201 | sim |
| Johansen, traco r = 0 (config. do Rmd) | 25,01 | 25,0060 |  25,006 | sim |
| Johansen, valor critico 5% r = 0 | 25,32 | 25,3200 |   25,32 | sim |

Notas:

- Os alvos da matriz de covariancia batem por truncamento, nao por arredondamento (0,003984 vira 0,0039; 0,000851 vira 0,0008; 0,4056 vira 0,405). As respostas ao impulso batem por arredondamento.
- O par F = 1,91 e p = 0,13 para PVD -> INF nao vem do VAR em diferenca: nele F = 1,27 e p = 0,288. Vem do VAR em nivel (gl 3 e 116). O LOG anterior atribuia esse par ao VAR em diferenca; corrigido no log da A1.
- Conversao so para leitura: o impacto de 0,0118 em log10 equivale a 0,0272 em log natural (cerca de 2,8% no nivel de PVD); o choque de um desvio padrao eleva INF em 0,0631 em log10 no impacto. A elasticidade e a razao entre respostas na mesma unidade e nao depende da base do log.

## Bootstrap

`irf(modelo, impulse = "INF", response = c("INF", "PVD"), n.ahead = 40, cumulative = TRUE, boot = TRUE, runs = 2000, ci = 0.90, seed = 42)`; bandas nos percentis 5% e 95%.

Bootstrap proprio de residuos para a elasticidade: 2000 replicas, desenho recursivo, constante, tendencia e exogenas fixas, 3 valores iniciais observados, residuos centrados, `set.seed(42)` e a mesma sequencia de sorteios de `vars:::.boot`. Em cada replica, elasticidade = resposta acumulada de PVD em h = 40 / resposta acumulada de INF em h = 40. Replicas em `data/processed/A1_bootstrap.csv`.

Conferencia: os percentis 5% e 95% das respostas acumuladas do bootstrap proprio coincidem exatamente com as bandas do `irf()`.

| Medida | Ponto | IC 90% (2000 replicas) | Mediana bootstrap |
|---|---|---|---|
| Impacto de INF em PVD (h = 0) | 0,0118 | [0,0036; 0,0175] | 0,0105 |
| Resposta acumulada de PVD (h = 40) | 0,0194 | [0,0016; 0,0315] | 0,0145 |
| Resposta acumulada de INF (h = 40) | 0,0465 | [0,0263; 0,0584] | 0,0388 |
| Elasticidade de longo prazo | 0,4163 | [0,05; 0,66] | 0,36 |

Python com 500 replicas: elasticidade IC 90% [0,07; 0,67]. R com 2000 replicas: [0,05; 0,66]. Replicas com elasticidade negativa: 3,3%; com resposta acumulada de PVD negativa: 3,3%; com resposta acumulada de INF <= 0: 0,0%.

## Resposta acumulada a um choque de INF (IC 90%)

| h | PVD | IC90 PVD | INF | IC90 INF | PVD/INF |
|---|---|---|---|---|---|
| 0 | 0,0118 | [0,0036; 0,0175] | 0,0631 | [0,0464; 0,0698] | 0,19 |
| 1 | 0,0133 | [0,0019; 0,0209] | 0,0645 | [0,0416; 0,0747] | 0,21 |
| 2 | 0,0061 | [-0,0064; 0,0151] | 0,0347 | [0,0142; 0,0468] | 0,17 |
| 4 | 0,0216 | [0,0042; 0,0317] | 0,0450 | [0,0249; 0,0566] | 0,48 |
| 8 | 0,0191 | [0,0015; 0,0306] | 0,0445 | [0,0230; 0,0569] | 0,43 |
| 12 | 0,0190 | [0,0013; 0,0307] | 0,0464 | [0,0256; 0,0580] | 0,41 |
| 20 | 0,0194 | [0,0016; 0,0317] | 0,0465 | [0,0263; 0,0584] | 0,42 |
| 40 | 0,0194 | [0,0016; 0,0315] | 0,0465 | [0,0263; 0,0584] | 0,42 |

Figura: `results/figuras/A1_irf_acumulada.png` e `.pdf`. Serie completa em `data/processed/A1_irf_acumulada.csv`.

## Matriz de covariancia dos residuos (summary(modelo)$covres)

|   | INF | PVD |
|---|---|---|
| INF | 0,00398433 | 0,000746794 |
| PVD | 0,000746794 | 0,000850646 |

Correlacao dos residuos: 0,4056.

## Diagnosticos dos residuos

| Teste | Estatistica | gl | p-valor | Distribuicao |
|---|---|---|---|---|
| Portmanteau assintotico (lags.pt = 16) | 44,79 | 52 | 0,7506 | qui-quadrado |
| Portmanteau ajustado (lags.pt = 16) | 52,34 | 52 | 0,4606 | qui-quadrado |
| Breusch-Godfrey LM (lags.bg = 5) | 41,81 | 20 | 0,0029 | qui-quadrado |
| Edgerton-Shukur F (lags.bg = 5) | 2,10 | 20; 92 | 0,0093 | F |
| ARCH-LM multivariado (lags.multi = 5) | 42,23 | 45 | 0,5899 | qui-quadrado |
| Jarque-Bera multivariado | 18,03 | 4 | 0,0012 | qui-quadrado |
| Assimetria multivariada | 5,44 | 2 | 0,0659 | qui-quadrado |
| Curtose multivariada | 12,59 | 2 | 0,0018 | qui-quadrado |
| Jarque-Bera univariado, INF | 15,10 | 2 | 0,0005 | qui-quadrado |
| Jarque-Bera univariado, PVD | 3,63 | 2 | 0,1632 | qui-quadrado |

ARCH multivariado com lags.multi = 5 (padrao do vars, o mesmo usado no Rmd). No Rmd, BG e ES foram chamados com lags.pt = 16, que esses testes ignoram; o lag efetivo e lags.bg = 5.

Raizes (modulos do polinomio caracteristico): 0,7358, 0,7358, 0,6939, 0,6939, 0,6697, 0,5632. Todas menores que 1: sim.

## Selecao de defasagens: VARselect(lag.max = 8, type = "both", exogen = diff(exo))

| p | AIC(n) | HQ(n) | SC(n) | FPE(n) |
|---|---|---|---|---|
| 1 | -12,1884 | -12,0011 | -11,7121 | 5,0987e-06 |
| 2 | -12,3745 | -12,1337 | -11,7622 | 4,2414e-06 |
| 3 | -12,4681 | -12,1737 | -11,7197 | 3,8755e-06 |
| 4 | -12,4170 | -12,0692 | -11,5326 | 4,0980e-06 |
| 5 | -12,3158 | -11,9144 | -11,2953 | 4,5645e-06 |
| 6 | -12,2728 | -11,8179 | -11,1162 | 4,8072e-06 |
| 7 | -12,2049 | -11,6964 | -10,9122 | 5,2037e-06 |
| 8 | -12,3155 | -11,7536 | -10,8867 | 4,7255e-06 |

Selecao: AIC = 3, HQ = 3, SC = 2, FPE = 3.

## Causalidade de Granger (vars::causality, teste F)

| Modelo | Hipotese | F | gl | p-valor |
|---|---|---|---|---|
| VAR em diferenca (baseline) | H0: INF -> PVD nao causa | 3,27 | 3 e 114 | 0,0238 |
| VAR em diferenca (baseline) | H0: PVD -> INF nao causa | 1,27 | 3 e 114 | 0,2883 |
| VAR em nivel, exo em nivel | H0: INF -> PVD nao causa | 2,92 | 3 e 116 | 0,0372 |
| VAR em nivel, exo em nivel | H0: PVD -> INF nao causa | 1,91 | 3 e 116 | 0,1320 |

VAR em nivel: `VAR(infmeq, p = 3, type = "both", exogen = exo)`, a chamada do Rmd (`var.est`). Os graus de liberdade 3 e 116 coincidem com os da Tabela 12 da dissertacao.

Variantes testadas para PVD -> INF, na tentativa de localizar o p = 0,56 da dissertacao (nenhuma o reproduz):

| Variante | F | gl | p-valor |
|---|---|---|---|
| grangertest(INF ~ PVD, order = 4), niveis, sem exogenas (chamada do Rmd) | 2,89 | 4 e 59 | 0,0299 |
| grangertest(INF ~ PVD, order = 3), niveis, sem exogenas | 3,78 | 3 e 62 | 0,0149 |
| grangertest(INF ~ PVD, order = 4), diferencas, sem exogenas | 1,26 | 4 e 58 | 0,2975 |
| causality, VAR em nivel, vcov HC | 1,14 | 3 e 116 | 0,3347 |
| causality, VAR em diferenca, vcov HC | 0,84 | 3 e 114 | 0,4740 |
| causality, VAR em diferenca com p = 4 | 0,94 | 4 e 108 | 0,4455 |

## Johansen (ca.jo, type = "trace")

Configuracoes que reproduzem traco 25,01 contra 25,32 para r = 0: ecdet = trend, K = 2, spec = transitory; ecdet = trend, K = 2, spec = longrun. E a chamada do Rmd, com `dumvar = exo[, 3]`, que no arquivo 0124_inexo.txt e a DUM. spec (transitory ou longrun) nao altera a estatistica traco. Conclusao: 25,01 < 25,32, nao rejeita r = 0 a 5%; rejeita a 10% (valor critico 22,76).

| ecdet | K | spec | dumvar | traco r = 0 | vc 10% | vc 5% | vc 1% | traco r <= 1 | vc 5% r <= 1 | bate 25,01/25,32 |
|---|---|---|---|---|---|---|---|---|---|---|
| const | 2 | transitory | nenhuma | 19,14 | 17,85 | 19,96 | 24,60 | 3,28 | 9,24 |  |
| const | 2 | transitory | exo (PIB, JUR, DUM) | 24,59 | 17,85 | 19,96 | 24,60 | 3,84 | 9,24 |  |
| const | 2 | transitory | exo[, 3] = DUM (como no Rmd) | 21,38 | 17,85 | 19,96 | 24,60 | 3,35 | 9,24 |  |
| const | 2 | longrun | nenhuma | 19,14 | 17,85 | 19,96 | 24,60 | 3,28 | 9,24 |  |
| const | 2 | longrun | exo (PIB, JUR, DUM) | 24,59 | 17,85 | 19,96 | 24,60 | 3,84 | 9,24 |  |
| const | 2 | longrun | exo[, 3] = DUM (como no Rmd) | 21,38 | 17,85 | 19,96 | 24,60 | 3,35 | 9,24 |  |
| const | 3 | transitory | nenhuma | 19,26 | 17,85 | 19,96 | 24,60 | 4,08 | 9,24 |  |
| const | 3 | transitory | exo (PIB, JUR, DUM) | 24,28 | 17,85 | 19,96 | 24,60 | 3,40 | 9,24 |  |
| const | 3 | transitory | exo[, 3] = DUM (como no Rmd) | 23,49 | 17,85 | 19,96 | 24,60 | 4,12 | 9,24 |  |
| const | 3 | longrun | nenhuma | 19,26 | 17,85 | 19,96 | 24,60 | 4,08 | 9,24 |  |
| const | 3 | longrun | exo (PIB, JUR, DUM) | 24,28 | 17,85 | 19,96 | 24,60 | 3,40 | 9,24 |  |
| const | 3 | longrun | exo[, 3] = DUM (como no Rmd) | 23,49 | 17,85 | 19,96 | 24,60 | 4,12 | 9,24 |  |
| const | 4 | transitory | nenhuma | 24,69 | 17,85 | 19,96 | 24,60 | 4,80 | 9,24 |  |
| const | 4 | transitory | exo (PIB, JUR, DUM) | 27,99 | 17,85 | 19,96 | 24,60 | 3,67 | 9,24 |  |
| const | 4 | transitory | exo[, 3] = DUM (como no Rmd) | 27,73 | 17,85 | 19,96 | 24,60 | 4,81 | 9,24 |  |
| const | 4 | longrun | nenhuma | 24,69 | 17,85 | 19,96 | 24,60 | 4,80 | 9,24 |  |
| const | 4 | longrun | exo (PIB, JUR, DUM) | 27,99 | 17,85 | 19,96 | 24,60 | 3,67 | 9,24 |  |
| const | 4 | longrun | exo[, 3] = DUM (como no Rmd) | 27,73 | 17,85 | 19,96 | 24,60 | 4,81 | 9,24 |  |
| trend | 2 | transitory | nenhuma | 26,00 | 22,76 | 25,32 | 30,45 | 2,68 | 12,25 |  |
| trend | 2 | transitory | exo (PIB, JUR, DUM) | 26,53 | 22,76 | 25,32 | 30,45 | 3,84 | 12,25 |  |
| trend | 2 | transitory | exo[, 3] = DUM (como no Rmd) | 25,01 | 22,76 | 25,32 | 30,45 | 2,53 | 12,25 | sim |
| trend | 2 | longrun | nenhuma | 26,00 | 22,76 | 25,32 | 30,45 | 2,68 | 12,25 |  |
| trend | 2 | longrun | exo (PIB, JUR, DUM) | 26,53 | 22,76 | 25,32 | 30,45 | 3,84 | 12,25 |  |
| trend | 2 | longrun | exo[, 3] = DUM (como no Rmd) | 25,01 | 22,76 | 25,32 | 30,45 | 2,53 | 12,25 | sim |
| trend | 3 | transitory | nenhuma | 23,59 | 22,76 | 25,32 | 30,45 | 3,59 | 12,25 |  |
| trend | 3 | transitory | exo (PIB, JUR, DUM) | 27,50 | 22,76 | 25,32 | 30,45 | 6,81 | 12,25 |  |
| trend | 3 | transitory | exo[, 3] = DUM (como no Rmd) | 24,19 | 22,76 | 25,32 | 30,45 | 4,15 | 12,25 |  |
| trend | 3 | longrun | nenhuma | 23,59 | 22,76 | 25,32 | 30,45 | 3,59 | 12,25 |  |
| trend | 3 | longrun | exo (PIB, JUR, DUM) | 27,50 | 22,76 | 25,32 | 30,45 | 6,81 | 12,25 |  |
| trend | 3 | longrun | exo[, 3] = DUM (como no Rmd) | 24,19 | 22,76 | 25,32 | 30,45 | 4,15 | 12,25 |  |
| trend | 4 | transitory | nenhuma | 26,79 | 22,76 | 25,32 | 30,45 | 3,81 | 12,25 |  |
| trend | 4 | transitory | exo (PIB, JUR, DUM) | 29,17 | 22,76 | 25,32 | 30,45 | 5,40 | 12,25 |  |
| trend | 4 | transitory | exo[, 3] = DUM (como no Rmd) | 28,56 | 22,76 | 25,32 | 30,45 | 5,18 | 12,25 |  |
| trend | 4 | longrun | nenhuma | 26,79 | 22,76 | 25,32 | 30,45 | 3,81 | 12,25 |  |
| trend | 4 | longrun | exo (PIB, JUR, DUM) | 29,17 | 22,76 | 25,32 | 30,45 | 5,40 | 12,25 |  |
| trend | 4 | longrun | exo[, 3] = DUM (como no Rmd) | 28,56 | 22,76 | 25,32 | 30,45 | 5,18 | 12,25 |  |

## Decomposicao da variancia do erro de previsao (%, variaveis em diferenca)

| h | dINF: choque INF | dINF: choque PVD | dPVD: choque INF | dPVD: choque PVD |
|---|---|---|---|---|
| 4 | 96,2 | 3,8 | 27,3 | 72,7 |
| 8 | 95,5 | 4,5 | 30,5 | 69,5 |
| 20 | 95,5 | 4,5 | 30,6 | 69,4 |
| 40 | 95,5 | 4,5 | 30,6 | 69,4 |

## Arquivos

- `R/A1_replica.R`
- `results/A1_replica.md`, `results/A1_replica.tex`
- `results/figuras/A1_irf_acumulada.png`, `results/figuras/A1_irf_acumulada.pdf`
- `data/processed/A1_bootstrap.csv` (2000 replicas: impacto, respostas acumuladas em h = 40 e elasticidade)
- `data/processed/A1_irf_acumulada.csv` (resposta acumulada h = 0 a 40 com IC 90%)
- `results/log_parts/A1.md`, `results/session_info/A1_replica.txt`
