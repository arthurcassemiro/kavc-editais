# A1. Replica em R do modelo final da dissertacao

Gerado por `R/A1_replica.R` em 2026-09-28 21:41. Numeros com virgula decimal. Respostas em log10 (os dados estao em log10).

## Especificacao

- Dados: `data/original/0224_tri_estmeq.txt` (INF e PVD em log10) e `data/original/0124_inexo.txt` (PIB, JUR e DUM), 72 trimestres de 2002Q1 a 2019Q4.
- JUR e a Meta Selic do BCB/SGS 432 ("Taxa de juros - Meta Selic definida pelo Copom", % a.a., em fracao) no ultimo dia do trimestre: 72 de 72 trimestres iguais (diferenca menor que 0,01 p.p., criterio da A2). Contra a media diaria do trimestre, que e a regra de conversao da A2 para taxas, so 19 de 72 sao iguais (diferenca media absoluta 0,45 p.p.). Fonte da comparacao: `results/A2_comparacao_selic_jur.csv` (A2). Para estender o baseline na A5, usar a Meta Selic no fim do trimestre, para ser comparavel, e a media do trimestre como robustez.
- PIB e a variacao trimestral (x_t/x_{t-1} - 1) do indice de volume com ajuste sazonal da SIDRA 1621 ("Série encadeada do índice de volume trimestral com ajuste sazonal (Base: média 1995 = 100)", PIB a precos de mercado), numa safra anterior a atual: diferenca media absoluta de 0,05 p.p. (maxima 0,28 p.p.) e correlacao 0,9984 com a safra baixada pela A2. Fonte da comparacao: `results/A2_comparacao_pib_inexo.csv` (A2).
- Modelo: `vars::VAR(diff(infmeq), p = 3, type = "both", exogen = diff(exo))`, 68 observacoes efetivas (2003Q1 a 2019Q4). Choque ortogonal por Cholesky com INF antes de PVD.
- Datas conferidas com `data/dados_dissertacao_apendiceA.csv` (que tem a coluna de trimestre): Selic identica ao JUR (diferenca maxima 0,0e+00), PIB identico a cpib_pct/100 (diferenca maxima 3,5e-18), correlacao de diff(log10(imeq_indice)) com diff(PVD) = 1,0000.
- Dummy: DUM = 1 em 2018Q2-2019Q1 e 2019Q3-2019Q4, igual ao registrado no LOG.md. Em diferenca vira pulsos (2018Q2: +1; 2019Q2: -1; 2019Q3: +1).
- Porte do Rmd: na ultima secao, `dados2 <- UCI[,1]` (linha 884) vem logo antes de `modelo=VAR(dados,p=3,...,exogen = dados2)` (linha 886) e sobrescreve `dados2 <- diff(exo)` (linha 870); `UCI` nao e definido nessa secao. A chamada literal nao usa `diff(exo)`. A especificacao com `exogen = diff(exo)` foi identificada por reproduzir as Tabelas 9, 10 e 16 (abaixo) e pelas equacoes 4.22 e 4.23 (Cpib, Cjur e Cdummy como exogenas).

## Ressalva de unidade

O INF do arquivo original e nominal com ajuste sazonal, embora a secao 4.4 da dissertacao diga que foi deflacionado. Evidencia da A3 (results/A3_reconstrucao_INF_variantes.csv, janela 2003T1-2019T4, 48 variantes com ajuste sazonal): nas nominais o desvio absoluto medio em nivel contra INF fica entre 0,0053 e 0,0073 log10; nas deflacionadas pelo IPCA, entre 0,187 e 0,192 log10 (desvio medio de -0,19, a inflacao acumulada). A correlacao das diferencas nao distingue as duas: a maior e 0,998 nas nominais e 0,998 nas deflacionadas. A serie nominal sem ajuste sazonal fica mais longe (desvio absoluto medio em nivel 0,067 log10; correlacao das diferencas 0,49). A replica reproduz a dissertacao; a elasticidade de longo prazo aqui e medida contra o INF nominal. O baseline corrigido, com INF real, fica na A5.

## Comparacao com os alvos

| Item | Fonte | Alvo | Obtido (4 casas) | Obtido (6 alg.) | Reproduz |
|---|---|---|---|---|---|
| Impacto ortogonal de INF em PVD (h = 0) | LOG (Python); Tabelas 11 e 16 | 0,0118 | 0,0118 | 0,0118311 | sim |
| Resposta acumulada de PVD, h = 40 | LOG (Python); Tabela 16 | 0,0194 | 0,0194 | 0,0193671 | sim |
| Resposta acumulada de INF, h = 40 | LOG (Python) | 0,0465 | 0,0465 | 0,0465203 | sim |
| Elasticidade de longo prazo (PVD/INF acumulados, h = 40) | LOG (Python) | 0,42 | 0,4163 | 0,416315 | sim |
| var(u_INF) | Tabela 11 | 0,0039 | 0,0040 | 0,00398433 | sim, por truncamento (arredondado: 0,0040) |
| cov(u_INF, u_PVD) | Tabela 11 | 0,0007 | 0,0007 | 0,000746794 | sim |
| var(u_PVD) | Tabela 11 | 0,0008 | 0,0009 | 0,000850646 | sim, por truncamento (arredondado: 0,0009) |
| corr(u_INF, u_PVD) | Tabela 11 | 0,405 | 0,4056 | 0,405648 | sim, por truncamento (arredondado: 0,406) |
| Cholesky, elemento (INF, INF) | Tabela 11 | 0,063 | 0,0631 | 0,0631215 | sim |
| Cholesky, elemento (PVD, PVD) | Tabela 11 | 0,0266 | 0,0267 | 0,0266584 | sim, por truncamento (arredondado: 0,0267) |
| Granger INF -> PVD, VAR em diferenca, F | LOG (Python) | 3,27 | 3,2710 | 3,27095 | sim |
| Granger INF -> PVD, VAR em diferenca, p | LOG (Python) | 0,024 | 0,0238 | 0,0238242 | sim |
| Granger PVD -> INF, VAR em diferenca, F | LOG anterior (atribuicao errada) | 1,91 | 1,2694 | 1,2694 | nao |
| Granger PVD -> INF, VAR em diferenca, p | LOG anterior (atribuicao errada) | 0,13 | 0,2883 | 0,288303 | nao |
| Granger INF -> PVD, VAR em nivel, F | Tabela 12 | 2,91 | 2,9173 | 2,91732 | sim, por truncamento (arredondado: 2,92) |
| Granger INF -> PVD, VAR em nivel, p | Tabela 12 | 0,03 | 0,0372 | 0,0371745 | sim, por truncamento (arredondado: 0,04) |
| Granger PVD -> INF, VAR em nivel, F | Tabela 12 | 1,90 | 1,9088 | 1,90879 | sim, por truncamento (arredondado: 1,91) |
| Granger PVD -> INF, VAR em nivel, p | Tabela 12 | 0,56 | 0,1320 | 0,13201 | nao |
| Johansen, traco r = 0 (config. do Rmd) | Tabela 8 | 25,01 | 25,0060 | 25,006 | sim |
| Johansen, valor critico 5% r = 0 | Tabela 8 | 25,32 | 25,3200 | 25,32 | sim |
| Johansen, traco r <= 1 | Tabela 8 | 2,53 | 2,5320 | 2,53201 | sim |
| Johansen, valor critico 5% r <= 1 | Tabela 8 | 12,25 | 12,2500 | 12,25 | sim |
| Portmanteau ajustado (16 lags), estatistica (impressa na coluna 'Homocedasticidade') | Tabela 7 | 52,34 | 52,3428 | 52,3428 | sim |
| Portmanteau ajustado (16 lags), p-valor | Tabela 7 | 0,46 | 0,4606 | 0,460596 | sim |
| ARCH-LM multivariado (5 lags), estatistica (impressa na coluna 'Autocorrelacao') | Tabela 7 | 42,33 | 42,2321 | 42,2321 | nao |
| ARCH-LM multivariado (5 lags), p-valor | Tabela 7 | 0,589 | 0,5899 | 0,589886 | sim, por truncamento (arredondado: 0,590) |
| VARselect, defasagem pelo AIC | Tabela 6 | 3 | 3,0000 | 3 | sim |
| VARselect, defasagem pelo HQ | Tabela 6 | 3 | 3,0000 | 3 | sim |
| VARselect, defasagem pelo SC | Tabela 6 | 2 | 2,0000 | 2 | sim |
| VARselect, defasagem pelo FPE | Tabela 6 | 3 | 3,0000 | 3 | sim |

Notas:

- Batem so por truncamento, nao por arredondamento: var(u_INF) (0,0039 no texto; arredondado seria 0,0040); var(u_PVD) (0,0008 no texto; arredondado seria 0,0009); corr(u_INF, u_PVD) (0,405 no texto; arredondado seria 0,406); Cholesky, elemento (PVD, PVD) (0,0266 no texto; arredondado seria 0,0267); Granger INF -> PVD, VAR em nivel, F (2,91 no texto; arredondado seria 2,92); Granger INF -> PVD, VAR em nivel, p (0,03 no texto; arredondado seria 0,04); Granger PVD -> INF, VAR em nivel, F (1,90 no texto; arredondado seria 1,91); ARCH-LM multivariado (5 lags), p-valor (0,589 no texto; arredondado seria 0,590). Nas Tabelas 6 a 18, 10 de 319 valores batem so por truncamento; o texto trunca parte dos numeros. As respostas ao impulso da tabela principal batem por arredondamento.
- O par F = 1,91 e p = 0,13 para PVD -> INF nao vem do VAR em diferenca: nele F = 1,27 e p = 0,288. Vem do VAR em nivel (gl 3 e 116), o da Tabela 12. O item de Granger de `results/LOG.md` atribui esse par ao VAR em diferenca; a correcao datada esta em `results/log_parts/A1.md` (o coordenador consolida no LOG).
- Tabela 12: p = 0,56 e incompativel com F = 1,90 e gl (3, 116) da propria Tabela 12, que implicam p = 0,133; para dar p = 0,56 seria preciso F = 0,69. Logo, 0,56 e erro de transcricao, e nao outra especificacao.
- Tabela 7: os rotulos do texto estao trocados. O Portmanteau ajustado da 52,34 (p = 0,4606), impresso sob 'Homocedasticidade'; o ARCH-LM multivariado da 42,23 (p = 0,5899), impresso sob 'Autocorrelacao' como 42,33 (erro de digitacao) e 0,589 (truncado). A leitura desses dois testes nao muda, mas BG e ES rejeitam ausencia de autocorrelacao (ver Diagnosticos).
- Conversao so para leitura: o impacto de 0,0118 em log10 equivale a 0,0272 em log natural (cerca de 2,8% no nivel de PVD); o choque de um desvio padrao eleva INF em 0,0631 em log10 no impacto. A elasticidade e a razao entre respostas na mesma unidade e nao depende da base do log.

## Tabelas da dissertacao (capitulo 4 e Apendice B)

319 valores transcritos por codigo de docs/dissertacao/dissertacao.txt e gravados em data/processed/A1_alvos_dissertacao.csv. Colunas: valores que batem ao arredondar, so ao truncar, so com arredondamento duplo, ou que nao batem; diferenca maxima absoluta entre o obtido e o impresso. A Tabela 7 esta com os rotulos corrigidos (ver acima). Da Tabela 16 so entra a coluna do ponto: as bandas impressas vem de outro bootstrap (IC 95%, semente desconhecida).

| Tabela | Conteudo | Valores | Arredondamento | Truncamento | Arredondamento duplo | Nao reproduz | Diferenca maxima |
|---|---|---|---|---|---|---|---|
| 6 | Selecao da ordem | 4 | 4 | 0 | 0 | 0 | 0,0e+00 |
| 7 | Portmanteau ajustado e ARCH-LM (rotulos corrigidos) | 4 | 2 | 1 | 0 | 1 | 9,8e-02 |
| 8 | Johansen | 4 | 4 | 0 | 0 | 0 | 4,0e-03 |
| 9 | Coeficientes, equacao de INF | 44 | 42 | 1 | 1 | 0 | 5,1e-03 |
| 10 | Coeficientes, equacao de PVD | 44 | 43 | 0 | 1 | 0 | 5,1e-03 |
| 11 | Covariancia, correlacao e Cholesky | 12 | 7 | 5 | 0 | 0 | 6,5e-04 |
| 12 | Granger (VAR em nivel) | 8 | 4 | 3 | 0 | 1 | 4,3e-01 |
| 14 | VARselect, criterios 1 a 8 | 32 | 32 | 0 | 0 | 0 | 5,0e-04 |
| 15 | Modulos das raizes | 6 | 6 | 0 | 0 | 0 | 2,9e-04 |
| 16 | Resposta acumulada de PVD, h = 0 a 40 | 41 | 41 | 0 | 0 | 0 | 4,9e-10 |
| 17 | FEVD de INF, h = 1 a 30 | 60 | 60 | 0 | 0 | 0 | 5,0e-08 |
| 18 | FEVD de PVD, h = 1 a 30 | 60 | 60 | 0 | 0 | 0 | 4,8e-08 |

Arredondamento duplo: Equacao de INF, Cpib (PIB), valor t (obtido 0,0149, impresso 0,02); Equacao de PVD, Imeq l3 (PVD.l3), valor t (obtido 1,1049, impresso 1,11). Batem se o valor foi primeiro impresso pelo R com uma casa a mais (summary.lm mostra o valor t com 3 casas: 0,015 e 1,105) e depois arredondado para 2 casas com metade para cima.

Tabela 16: diferenca maxima de 4,9e-10 nos 41 valores impressos com 9 casas (`stopifnot(max(abs(diferenca)) < 1e-8)`). Nao reproduzidos: `t7_col_autocorrelacao_estat` (texto 42,33, obtido 42,2321) e `t12_causa_PVD_p` (texto 0,56, obtido 0,1320), ambos explicados acima.

## Bootstrap

`irf(modelo, impulse = "INF", response = c("INF", "PVD"), n.ahead = 40, cumulative = TRUE, boot = TRUE, runs = 2000, ci = 0.90, seed = 42)`; bandas nos percentis 5% e 95%.

Bootstrap proprio de residuos para a elasticidade: 2000 replicas, desenho recursivo, constante, tendencia e exogenas fixas, 3 valores iniciais observados, residuos centrados, `set.seed(42)` e a mesma sequencia de sorteios de `vars:::.boot`. Em cada replica, elasticidade = resposta acumulada de PVD em h = 40 / resposta acumulada de INF em h = 40. Replicas em `data/processed/A1_bootstrap.csv`.

Conferencia: os percentis 5% e 95% das respostas acumuladas do bootstrap proprio coincidem exatamente com as bandas do `irf()` (`stopifnot`; sem isso o script para antes de publicar o IC da elasticidade).

| Medida | Ponto | Mediana | Vies (ponto - mediana) | IC 90% percentil (replica do vars) | IC 90% basico de Hall | Kilian: ponto corrigido | Kilian: IC 90% BaB |
|---|---|---|---|---|---|---|---|
| Impacto de INF em PVD (h = 0) | 0,0118 | 0,0105 | 0,0013 | [0,0036; 0,0175] | [0,0062; 0,0201] | 0,0118 | [0,0035; 0,0174] |
| Resposta acumulada de PVD (h = 40) | 0,0194 | 0,0145 | 0,0049 | [0,0016; 0,0315] | [0,0072; 0,0371] | 0,0246 | [0,0038; 0,0574] |
| Resposta acumulada de INF (h = 40) | 0,0465 | 0,0388 | 0,0078 | [0,0263; 0,0584] | [0,0346; 0,0667] | 0,0517 | [0,0296; 0,0802] |
| Elasticidade de longo prazo | 0,42 | 0,36 | 0,05 | [0,05; 0,66] | [0,17; 0,78] | 0,48 | [0,11; 0,82] |

Vies do bootstrap: a mediana das replicas fica abaixo do ponto em todas as medidas (ponto menos mediana: impacto 0,0013; acumulada de PVD 0,0049; acumulada de INF 0,0078; elasticidade 0,05, com mediana 0,36 contra ponto 0,42). O IC percentil replica o metodo do vars e nao corrige esse vies. Robustez: intervalo basico de Hall (2 x ponto menos os percentis 95% e 5%, das replicas em data/processed/A1_bootstrap.csv) para a elasticidade [0,17; 0,78]; bootstrap-after-bootstrap de Kilian (1998), 1000 replicas no estagio 1 e 2000 no estagio 2, set.seed(42), 13 s: elasticidade corrigida de vies 0,48, IC 90% [0,11; 0,82]; acumulada de PVD corrigida 0,0246 [0,0038; 0,0574]; acumulada de INF corrigida 0,0517 [0,0296; 0,0802]. Modulo maximo das raizes: 0,7358 (MQO) e 0,7335 (corrigido; correcao completa). Replicas do estagio 2 por tipo de correcao: correcao completa: 2000. Replicas em data/processed/A1_bootstrap_kilian.csv. Sementes do Kilian: set.seed(42) uma vez, no inicio do estagio 1 (os sorteios do estagio 1 sao os mesmos das 1000 primeiras replicas do bootstrap principal); o estagio 2 continua o fluxo do gerador, sem nova semente, para que os sorteios dos dois estagios sejam independentes, como supoe Kilian (1998). Ate a execucao anterior o estagio 2 refazia set.seed(42) e repetia os sorteios do estagio 1 (correlacao de 0,98 entre as elasticidades das replicas do estagio 2 e as do bootstrap principal); agora a correlacao e -0,01. Parte do vies das respostas em nivel vem da escala da covariancia: vars:::.boot reamostra os residuos centrados sem reescala pelos graus de liberdade (68 observacoes, 11 regressores por equacao), e a covariancia das replicas tem valor esperado de cerca de 57/68 = 0,84 da original, o que reduz as respostas em cerca de 0,92 (mediana do impacto dividida pelo ponto: 0,89). A elasticidade e uma razao entre respostas ao mesmo choque e nao depende dessa escala (conferido); o vies dela vem dos coeficientes das defasagens e da razao cov(u_INF, u_PVD)/var(u_INF). A correcao de Kilian atua so nos coeficientes das defasagens; por isso o impacto corrigido e igual ao de MQO, e as bandas das respostas em nivel continuam afetadas pela escala.

Python com 500 replicas: elasticidade IC 90% [0,07; 0,67]. R com 2000 replicas, percentil: [0,05; 0,66]. Replicas com elasticidade negativa: 3,3%; com resposta acumulada de PVD negativa: 3,3%; com resposta acumulada de INF <= 0: 0,0%.

O IC percentil fica como replica do metodo do vars (e da dissertacao). O intervalo basico de Hall e o bootstrap-after-bootstrap de Kilian (1998) sao robustez contra o vies do bootstrap. Os tres reamostram residuos iid e supoem ausencia de autocorrelacao residual, que o BG e o ES rejeitam (ver Diagnosticos); os IC ficam condicionados a isso.

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

Correlacao dos residuos: 0,4056. Cholesky (t(chol(covres))): INF,INF = 0,06312; PVD,INF = 0,01183; PVD,PVD = 0,02666.

## Diagnosticos dos residuos

| Teste | Estatistica | gl | p-valor | Distribuicao |
|---|---|---|---|---|
| Portmanteau assintotico (16 defasagens) | 44,79 | 52 | 0,7506 | qui-quadrado |
| Portmanteau ajustado (16 defasagens) | 52,34 | 52 | 0,4606 | qui-quadrado |
| Breusch-Godfrey LM (5 defasagens) | 41,81 | 20 | 0,0029 | qui-quadrado |
| Edgerton-Shukur F (5 defasagens) | 2,10 | 20; 92 | 0,0093 | F |
| ARCH-LM multivariado (5 defasagens) | 42,23 | 45 | 0,5899 | qui-quadrado |
| Jarque-Bera multivariado | 18,03 | 4 | 0,0012 | qui-quadrado |
| Assimetria multivariada | 5,44 | 2 | 0,0659 | qui-quadrado |
| Curtose multivariada | 12,59 | 2 | 0,0018 | qui-quadrado |
| Jarque-Bera univariado, INF | 15,10 | 2 | 0,0005 | qui-quadrado |
| Jarque-Bera univariado, PVD | 3,63 | 2 | 0,1632 | qui-quadrado |

Leitura: Portmanteau assintotico (16 defasagens): nao rejeita a 10%; ajustado: nao rejeita a 10%. Breusch-Godfrey (5 defasagens): rejeita a 1%; Edgerton-Shukur: rejeita a 1%. BG por numero de defasagens (1 a 8): 8 de 8 rejeitam a 1%, maior p-valor 0,008; ES: 7 de 8 rejeitam a 1% e 8 de 8 a 5%, maior p-valor 0,023. ARCH-LM multivariado: nao rejeita a 10%. Jarque-Bera multivariado: rejeita a 1% (assimetria: rejeita a 10%; curtose: rejeita a 1%). Jarque-Bera univariado, equacao de INF: rejeita a 1%; de PVD: nao rejeita a 10%.

| Defasagens | p-valor BG | p-valor ES |
|---|---|---|
| 1 | 0,0032 | 0,0081 |
| 2 | 0,0018 | 0,0053 |
| 3 | 0,0080 | 0,0234 |
| 4 | 0,0015 | 0,0048 |
| 5 | 0,0029 | 0,0093 |
| 6 | 0,0006 | 0,0013 |
| 7 | 0,0017 | 0,0040 |
| 8 | 0,0026 | 0,0072 |

Mesmos testes (5 defasagens) com o VAR de ordem 2 a 6:

| Ordem do VAR | p-valor BG | p-valor ES |
|---|---|---|
| 2 | 0,0004 | 0,0007 |
| 3 | 0,0029 | 0,0093 |
| 4 | 0,0041 | 0,0201 |
| 5 | 0,0119 | 0,0778 |
| 6 | 0,0012 | 0,0128 |

Breusch-Godfrey por equacao (`lmtest::bgtest`, 5 defasagens, versao F):

| Equacao | F | gl | p-valor |
|---|---|---|---|
| INF | 4,22 | 5 e 52 | 0,0027 |
| PVD | 3,49 | 5 e 52 | 0,0085 |

Autocorrelacao residual. O Portmanteau (16 defasagens) nao rejeita ausencia de autocorrelacao (p = 0,75 assintotico e 0,46 ajustado), mas o Breusch-Godfrey rejeita a 1% em 8 de 8 numeros de defasagens (1 a 8; maior p = 0,008) e o Edgerton-Shukur rejeita a 5% em 8 de 8 e a 1% em 7 de 8 (maior p = 0,023, com 3 defasagens). Por equacao (bgtest, 5 defasagens): INF F = 4,22, p = 0,003; PVD F = 3,49, p = 0,009. Com o VAR de ordem 2 a 6 (5 defasagens no teste), o BG rejeita a 5% em 5 de 5 ordens e o ES a 10% em 5 de 5 (p do BG: p = 2: < 0,001; p = 3: 0,003; p = 4: 0,004; p = 5: 0,012; p = 6: 0,001; p do ES: p = 2: < 0,001; p = 3: 0,009; p = 4: 0,020; p = 5: 0,078; p = 6: 0,013). A especificacao tem autocorrelacao residual; o texto da dissertacao afirma ausencia com base so no Portmanteau. Os IC por bootstrap iid de residuos (percentil, Hall e Kilian) supoem residuos nao autocorrelacionados e ficam condicionados a isso. Na A5: bootstrap em blocos ou wild, ou projecoes locais com erros HAC (plano em results/log_parts/A0_ambiente.md).

ARCH multivariado com lags.multi = 5 (padrao do vars, o mesmo usado no Rmd). No Rmd, BG e ES foram chamados com lags.pt = 16, que esses testes ignoram; o lag efetivo e lags.bg = 5 (conferido: mesma estatistica).

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

Selecao: AIC = 3, HQ = 3, SC = 2, FPE = 3. p = 3 e a escolha de AIC, HQ, FPE; SC prefere 2.

## Causalidade de Granger (vars::causality, teste F)

| Modelo | Hipotese | F | gl | p-valor |
|---|---|---|---|---|
| VAR em diferenca (baseline) | H0: INF nao Granger-causa PVD | 3,27 | 3 e 114 | 0,0238 |
| VAR em diferenca (baseline) | H0: PVD nao Granger-causa INF | 1,27 | 3 e 114 | 0,2883 |
| VAR em nivel, exo em nivel | H0: INF nao Granger-causa PVD | 2,92 | 3 e 116 | 0,0372 |
| VAR em nivel, exo em nivel | H0: PVD nao Granger-causa INF | 1,91 | 3 e 116 | 0,1320 |

VAR em nivel: `VAR(infmeq, p = 3, type = "both", exogen = exo)`, a chamada do Rmd (`var.est`). Os graus de liberdade 3 e 116 coincidem com os da Tabela 12 da dissertacao.

Convencao dos graus de liberdade no VAR em diferenca:

| Versao | Hipotese | F | gl | p-valor |
|---|---|---|---|---|
| F classico por equacao | H0: INF nao Granger-causa PVD | 3,27 | 3 e 57 | 0,0276 |
| F classico por equacao | H0: PVD nao Granger-causa INF | 1,27 | 3 e 57 | 0,2935 |
| por equacao, vcovHC (HC3) | H0: INF nao Granger-causa PVD | 4,17 | 3 e 57 | 0,0097 |
| vars::causality, vcovHC (sistema) | H0: INF nao Granger-causa PVD | 4,17 | 3 e 114 | 0,0077 |

Convencao dos graus de liberdade: vars::causality testa no sistema empilhado, com gl 3 e 114 (K(T - k)). O F classico equacao por equacao tem o mesmo F e gl 3 e 57: INF -> PVD p = 0,028; PVD -> INF p = 0,294. Com erros robustos a heterocedasticidade, INF -> PVD: F = 4,17, p = 0,008 (vars::causality com sandwich::vcovHC, gl 3 e 114) e p = 0,010 (por equacao, HC3, gl 3 e 57). O p = 0,024 depende da convencao; a conclusao se mantem: INF Granger-causa PVD a 5% e PVD nao Granger-causa INF a 10%.

Variantes testadas para PVD -> INF, na tentativa de localizar o p = 0,56 da dissertacao (nenhuma o reproduz):

| Variante | F | gl | p-valor |
|---|---|---|---|
| grangertest(INF ~ PVD, order = 4), niveis, sem exogenas (chamada do Rmd) | 2,89 | 4 e 59 | 0,0299 |
| grangertest(INF ~ PVD, order = 3), niveis, sem exogenas | 3,78 | 3 e 62 | 0,0149 |
| grangertest(INF ~ PVD, order = 4), diferencas, sem exogenas | 1,26 | 4 e 58 | 0,2975 |
| causality, VAR em nivel, vcov HC | 1,14 | 3 e 116 | 0,3347 |
| causality, VAR em diferenca, vcov HC | 0,84 | 3 e 114 | 0,4740 |
| causality, VAR em diferenca com p = 4 | 0,94 | 4 e 108 | 0,4455 |

O argumento mais direto: p = 0,56 e incompativel com F = 1,90 e gl (3, 116) da propria Tabela 12, que implicam p = 0,133; para dar p = 0,56 seria preciso F = 0,69. Logo, 0,56 e erro de transcricao, e nao outra especificacao.

## Johansen (ca.jo, type = "trace")

Configuracoes que reproduzem traco 25,01 contra 25,32 para r = 0: ecdet = trend, K = 2, spec = transitory; ecdet = trend, K = 2, spec = longrun. E a chamada do Rmd, com `dumvar = exo[, 3]`, que no arquivo 0124_inexo.txt e a DUM. spec (transitory ou longrun) nao altera a estatistica traco. Conclusao: 25,01 contra 25,32, nao rejeita r = 0 a 5%; rejeita a 10% (valor critico 22,76).

Nas 12 configuracoes distintas sem regressores estocasticos (ecdet const ou trend, K 2 a 4, dumvar nenhuma ou DUM), 7 rejeitam r = 0 a 5% e 12 a 10%; nenhuma rejeita r <= 1 a 5%. A configuracao do Rmd fica 0,31 abaixo do valor critico de 5% (25,01 contra 25,32); sem a DUM, com tendencia e K = 2, o traco e 26,00 contra 25,32. Incluindo as 6 configuracoes com exo como dumvar (so descritivas), 13 de 18 rejeitam a 5% e 18 a 10%. Leitura: evidencia limitrofe de um vetor de cointegracao, e nao ausencia de cointegracao. Isso pesa na escolha entre VAR em diferenca e VEC: na A5, Johansen com correcao de Reinsel-Ahn e bootstrap (Cavaliere, Rahbek e Taylor, 2012), VECM com r = 1 e VAR em nivel como robustez (plano em results/log_parts/A0_ambiente.md).

Ressalvas: as linhas com dumvar = exo (PIB e JUR sao regressores estocasticos) sao so descritivas, porque os valores criticos tabelados de Osterwald-Lenum nao valem com regressores estocasticos no termo de curto prazo. Com DUM em degraus e amostra de 72 trimestres, os valores criticos tabelados sao so aproximados. A correcao de Reinsel-Ahn e o bootstrap ficam para a A5. Em urca::ca.jo com ecdet = "trend", a tendencia entra restrita ao vetor de cointegracao (ZK), e a constante e a dumvar entram no termo de curto prazo irrestrito (Z1).

| ecdet | K | spec | dumvar | traco r = 0 | vc 10% | vc 5% | vc 1% | traco r <= 1 | vc 5% r <= 1 | bate 25,01/25,32 | valores criticos |
|---|---|---|---|---|---|---|---|---|---|---|---|
| const | 2 | transitory | nenhuma | 19,14 | 17,85 | 19,96 | 24,60 | 3,28 | 9,24 |  | tabelados |
| const | 2 | transitory | exo (PIB, JUR, DUM) | 24,59 | 17,85 | 19,96 | 24,60 | 3,84 | 9,24 |  | nao valem (so descritiva) |
| const | 2 | transitory | exo[, 3] = DUM (como no Rmd) | 21,38 | 17,85 | 19,96 | 24,60 | 3,35 | 9,24 |  | aproximados (DUM em degraus) |
| const | 2 | longrun | nenhuma | 19,14 | 17,85 | 19,96 | 24,60 | 3,28 | 9,24 |  | tabelados |
| const | 2 | longrun | exo (PIB, JUR, DUM) | 24,59 | 17,85 | 19,96 | 24,60 | 3,84 | 9,24 |  | nao valem (so descritiva) |
| const | 2 | longrun | exo[, 3] = DUM (como no Rmd) | 21,38 | 17,85 | 19,96 | 24,60 | 3,35 | 9,24 |  | aproximados (DUM em degraus) |
| const | 3 | transitory | nenhuma | 19,26 | 17,85 | 19,96 | 24,60 | 4,08 | 9,24 |  | tabelados |
| const | 3 | transitory | exo (PIB, JUR, DUM) | 24,28 | 17,85 | 19,96 | 24,60 | 3,40 | 9,24 |  | nao valem (so descritiva) |
| const | 3 | transitory | exo[, 3] = DUM (como no Rmd) | 23,49 | 17,85 | 19,96 | 24,60 | 4,12 | 9,24 |  | aproximados (DUM em degraus) |
| const | 3 | longrun | nenhuma | 19,26 | 17,85 | 19,96 | 24,60 | 4,08 | 9,24 |  | tabelados |
| const | 3 | longrun | exo (PIB, JUR, DUM) | 24,28 | 17,85 | 19,96 | 24,60 | 3,40 | 9,24 |  | nao valem (so descritiva) |
| const | 3 | longrun | exo[, 3] = DUM (como no Rmd) | 23,49 | 17,85 | 19,96 | 24,60 | 4,12 | 9,24 |  | aproximados (DUM em degraus) |
| const | 4 | transitory | nenhuma | 24,69 | 17,85 | 19,96 | 24,60 | 4,80 | 9,24 |  | tabelados |
| const | 4 | transitory | exo (PIB, JUR, DUM) | 27,99 | 17,85 | 19,96 | 24,60 | 3,67 | 9,24 |  | nao valem (so descritiva) |
| const | 4 | transitory | exo[, 3] = DUM (como no Rmd) | 27,73 | 17,85 | 19,96 | 24,60 | 4,81 | 9,24 |  | aproximados (DUM em degraus) |
| const | 4 | longrun | nenhuma | 24,69 | 17,85 | 19,96 | 24,60 | 4,80 | 9,24 |  | tabelados |
| const | 4 | longrun | exo (PIB, JUR, DUM) | 27,99 | 17,85 | 19,96 | 24,60 | 3,67 | 9,24 |  | nao valem (so descritiva) |
| const | 4 | longrun | exo[, 3] = DUM (como no Rmd) | 27,73 | 17,85 | 19,96 | 24,60 | 4,81 | 9,24 |  | aproximados (DUM em degraus) |
| trend | 2 | transitory | nenhuma | 26,00 | 22,76 | 25,32 | 30,45 | 2,68 | 12,25 |  | tabelados |
| trend | 2 | transitory | exo (PIB, JUR, DUM) | 26,53 | 22,76 | 25,32 | 30,45 | 3,84 | 12,25 |  | nao valem (so descritiva) |
| trend | 2 | transitory | exo[, 3] = DUM (como no Rmd) | 25,01 | 22,76 | 25,32 | 30,45 | 2,53 | 12,25 | sim | aproximados (DUM em degraus) |
| trend | 2 | longrun | nenhuma | 26,00 | 22,76 | 25,32 | 30,45 | 2,68 | 12,25 |  | tabelados |
| trend | 2 | longrun | exo (PIB, JUR, DUM) | 26,53 | 22,76 | 25,32 | 30,45 | 3,84 | 12,25 |  | nao valem (so descritiva) |
| trend | 2 | longrun | exo[, 3] = DUM (como no Rmd) | 25,01 | 22,76 | 25,32 | 30,45 | 2,53 | 12,25 | sim | aproximados (DUM em degraus) |
| trend | 3 | transitory | nenhuma | 23,59 | 22,76 | 25,32 | 30,45 | 3,59 | 12,25 |  | tabelados |
| trend | 3 | transitory | exo (PIB, JUR, DUM) | 27,50 | 22,76 | 25,32 | 30,45 | 6,81 | 12,25 |  | nao valem (so descritiva) |
| trend | 3 | transitory | exo[, 3] = DUM (como no Rmd) | 24,19 | 22,76 | 25,32 | 30,45 | 4,15 | 12,25 |  | aproximados (DUM em degraus) |
| trend | 3 | longrun | nenhuma | 23,59 | 22,76 | 25,32 | 30,45 | 3,59 | 12,25 |  | tabelados |
| trend | 3 | longrun | exo (PIB, JUR, DUM) | 27,50 | 22,76 | 25,32 | 30,45 | 6,81 | 12,25 |  | nao valem (so descritiva) |
| trend | 3 | longrun | exo[, 3] = DUM (como no Rmd) | 24,19 | 22,76 | 25,32 | 30,45 | 4,15 | 12,25 |  | aproximados (DUM em degraus) |
| trend | 4 | transitory | nenhuma | 26,79 | 22,76 | 25,32 | 30,45 | 3,81 | 12,25 |  | tabelados |
| trend | 4 | transitory | exo (PIB, JUR, DUM) | 29,17 | 22,76 | 25,32 | 30,45 | 5,40 | 12,25 |  | nao valem (so descritiva) |
| trend | 4 | transitory | exo[, 3] = DUM (como no Rmd) | 28,56 | 22,76 | 25,32 | 30,45 | 5,18 | 12,25 |  | aproximados (DUM em degraus) |
| trend | 4 | longrun | nenhuma | 26,79 | 22,76 | 25,32 | 30,45 | 3,81 | 12,25 |  | tabelados |
| trend | 4 | longrun | exo (PIB, JUR, DUM) | 29,17 | 22,76 | 25,32 | 30,45 | 5,40 | 12,25 |  | nao valem (so descritiva) |
| trend | 4 | longrun | exo[, 3] = DUM (como no Rmd) | 28,56 | 22,76 | 25,32 | 30,45 | 5,18 | 12,25 |  | aproximados (DUM em degraus) |

## Decomposicao da variancia do erro de previsao (%, variaveis em diferenca)

| h | dINF: choque INF | dINF: choque PVD | dPVD: choque INF | dPVD: choque PVD |
|---|---|---|---|---|
| 4 | 96,2 | 3,8 | 27,3 | 72,7 |
| 8 | 95,5 | 4,5 | 30,5 | 69,5 |
| 20 | 95,5 | 4,5 | 30,6 | 69,4 |
| 40 | 95,5 | 4,5 | 30,6 | 69,4 |

## Correcoes ao texto antigo

1. Granger. Tabela 12 (VAR em nivel, gl 3 e 116): INF -> PVD F = 2,92, p = 0,037 (o texto imprime 2,91 e 0,03); PVD -> INF F = 1,91, p = 0,13 (o texto imprime 1,90 e 0,56). VAR em diferenca (baseline, gl 3 e 114): INF -> PVD F = 3,27, p = 0,024; PVD -> INF F = 1,27, p = 0,29.
2. Granger, p = 0,56: p = 0,56 e incompativel com F = 1,90 e gl (3, 116) da propria Tabela 12, que implicam p = 0,133; para dar p = 0,56 seria preciso F = 0,69. Logo, 0,56 e erro de transcricao, e nao outra especificacao.
3. Tabela 7: rotulos trocados. Portmanteau ajustado (16 defasagens) = 52,34, p = 0,46; ARCH-LM multivariado = 42,23, p = 0,59 (o texto imprime 42,33 e 0,589 sob 'Autocorrelacao' e 52,34 e 0,46 sob 'Homocedasticidade'). A leitura desses dois testes nao muda; a de autocorrelacao muda com os testes do item seguinte.
4. Autocorrelacao residual (secao 4.5.1: 'ausencia de autocorrelacao residual', com base so no Portmanteau). O Portmanteau (16 defasagens) nao rejeita ausencia de autocorrelacao (p = 0,75 assintotico e 0,46 ajustado), mas o Breusch-Godfrey rejeita a 1% em 8 de 8 numeros de defasagens (1 a 8; maior p = 0,008) e o Edgerton-Shukur rejeita a 5% em 8 de 8 e a 1% em 7 de 8 (maior p = 0,023, com 3 defasagens). Por equacao (bgtest, 5 defasagens): INF F = 4,22, p = 0,003; PVD F = 3,49, p = 0,009. Com o VAR de ordem 2 a 6 (5 defasagens no teste), o BG rejeita a 5% em 5 de 5 ordens e o ES a 10% em 5 de 5 (p do BG: p = 2: < 0,001; p = 3: 0,003; p = 4: 0,004; p = 5: 0,012; p = 6: 0,001; p do ES: p = 2: < 0,001; p = 3: 0,009; p = 4: 0,020; p = 5: 0,078; p = 6: 0,013). A especificacao tem autocorrelacao residual; o texto da dissertacao afirma ausencia com base so no Portmanteau. Os IC por bootstrap iid de residuos (percentil, Hall e Kilian) supoem residuos nao autocorrelacionados e ficam condicionados a isso. Na A5: bootstrap em blocos ou wild, ou projecoes locais com erros HAC (plano em results/log_parts/A0_ambiente.md).
5. Johansen (Tabela 8): traco 25,01 contra valor critico de 5% de 25,32, nao rejeita r = 0 a 5%; rejeita a 10% (valor critico 22,76). Evidencia limitrofe de um vetor de cointegracao (7 de 12 configuracoes sem regressores estocasticos rejeitam r = 0 a 5%, 12 de 12 a 10%; a configuracao do Rmd fica 0,31 abaixo do valor critico de 5%), e nao ausencia de cointegracao. O texto diz que a nula de nao cointegracao e rejeitada e, na frase seguinte, que as variaveis nao sao cointegradas. Plano da A5: Johansen com correcao de Reinsel-Ahn e bootstrap, VECM com r = 1 e VAR em nivel como robustez.
6. Dummy: no arquivo, DUM = 1 em 2018Q2-2019Q1 e 2019Q3-2019Q4; o texto (secoes 4.5.2 e 4.5.3) diz do terceiro trimestre de 2018 ao quarto de 2019.
7. Magnitude: o texto diz que um choque de 1% gera cerca de 2%. A resposta acumulada de PVD em 40 trimestres e 0,0194 em log10, a um choque de um desvio padrao que eleva INF em 0,0631 no impacto e 0,0465 no acumulado; a elasticidade de longo prazo e 0,42 (IC 90% percentil [0,05; 0,66]; basico de Hall [0,17; 0,78]; Kilian 0,48, IC [0,11; 0,82]). Os tres IC vem de bootstrap iid de residuos e ficam condicionados a ausencia de autocorrelacao residual (ver o item de autocorrelacao).
8. Unidade de INF. O INF do arquivo original e nominal com ajuste sazonal, embora a secao 4.4 da dissertacao diga que foi deflacionado. Evidencia da A3 (results/A3_reconstrucao_INF_variantes.csv, janela 2003T1-2019T4, 48 variantes com ajuste sazonal): nas nominais o desvio absoluto medio em nivel contra INF fica entre 0,0053 e 0,0073 log10; nas deflacionadas pelo IPCA, entre 0,187 e 0,192 log10 (desvio medio de -0,19, a inflacao acumulada). A correlacao das diferencas nao distingue as duas: a maior e 0,998 nas nominais e 0,998 nas deflacionadas. A serie nominal sem ajuste sazonal fica mais longe (desvio absoluto medio em nivel 0,067 log10; correlacao das diferencas 0,49). A replica reproduz a dissertacao; a elasticidade de longo prazo aqui e medida contra o INF nominal. O baseline corrigido, com INF real, fica na A5.
9. Truncamento: parte dos numeros do texto e truncada, nao arredondada (ver a tabela de alvos). Na versao nova, arredondar.

## Arquivos

- `R/A1_replica.R`
- `results/A1_replica.md`, `results/A1_replica.tex`
- `results/figuras/A1_irf_acumulada.png`, `results/figuras/A1_irf_acumulada.pdf`
- `data/processed/A1_bootstrap.csv` (2000 replicas: impacto, respostas acumuladas em h = 40 e elasticidade)
- `data/processed/A1_bootstrap_kilian.csv` (2000 replicas do estagio 2 do bootstrap-after-bootstrap, corrigidas de vies)
- `data/processed/A1_irf_acumulada.csv` (resposta acumulada h = 0 a 40 com IC 90%)
- `data/processed/A1_alvos_dissertacao.csv` (valores das Tabelas 6 a 12 e 14 a 18 da dissertacao, com linha do txt e casas decimais)
- `results/log_parts/A1.md`, `results/session_info/A1_replica.txt`
