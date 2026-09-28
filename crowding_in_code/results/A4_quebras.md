# A4. Quebras estruturais

Gerado por `R/A4_quebras.R` em 2026-09-28 23:25. Numeros com virgula decimal. Tabelas LaTeX em `results/A_quebras.tex`; resumo por serie e equacao em `results/A4_quebras_resumo.csv`; dummies para a A5 em `data/processed/A4_dummies_quebra.csv` (metadados em `A4_dummies_quebra_metadados.csv`); figura em `results/figuras/A4_recursivo.png`.

Convencao: toda data de quebra e o primeiro trimestre do novo regime.

## Quais quebras importam

Quais quebras importam para o resultado. Pela regra deste script (muda o resultado a quebra que troca o sinal da elasticidade ou a desloca em mais de 25% em h = 12 ou h = 40, contra a amostra completa do mesmo modelo), IMPORTAM: (1) o periodo 2020-2021. Com dados ate 2019T4 o VAR estendido da elasticidade de 0,451 em h = 40, perto dos 0,42 da dissertacao; com 2020-2025, 0,154. A estimativa recursiva cai de 0,451 (fim em 2019T4) para 0,287 (2020T4) e 0,154 (2021T4) e depois fica de 0,123 a 0,157. Os testes apontam a mesma data: o supF das duas equacoes estendidas tem maximo em 2020T2 (p = 0,013 e <0,001) e o Chow em 2020T2 rejeita (p = 0,002 e <0,001). Parte do efeito vem dos picos das estatais que o X-11 manteve na serie ajustada (AO2020.3, AO2021.1, AO2021.2, alem dos de 2018-2019): com os pulsos de 2020T2 e 2020T3 a elasticidade vai a 0,173; com os outliers do X-11 de 2020-2021, a 0,364; com todos os outliers do X-11 e os pulsos, a 0,344; com inf_diss sem o efeito dos AO, a 0,277. (2) A divisao em 2014T4. O sinal se mantem no VAR, mas a magnitude muda: 0,227 ate 2014T4 e 0,059 de 2015T1 em diante; na projecao local simples o sinal muda (0,094 ate 2014T4, EP 0,312; -0,270 depois, EP 0,116). No VAR da dissertacao, a amostra ate 2014T4 da 0,028 contra 0,416 na amostra completa: a elasticidade de 0,42 vem de 2015-2019. Mesmo assim, o Chow em 2014T4 e 2015T1 nao rejeita nas equacoes estendidas (p de 0,336 a 0,749) e, na dissertacao, so rejeita na equacao de INF sem os trimestres da DUM (menor p 0,023); um degrau ou pulso nessas datas quase nao move a elasticidade (0,135 a 0,152): a diferenca entre as subamostras esta na dinamica (inclinacoes), nao no intercepto, e uma dummy nao resolve; a A5 deve reportar as subamostras. DETECTADAS PELOS TESTES, MAS SEM EFEITO RELEVANTE NA ELASTICIDADE: (3) a turbulencia de 2018-2019 no boletim da SEST (LS2018.2, AO2018.3, LS2019.1 e LS2019.3 de estatais_total, o trecho que a DUM da dissertacao cobre). A equacao de INF da dissertacao e instavel no fim da amostra: sem a DUM, Bai-Perron pelo BIC poe uma quebra em 2017T2 e o supF rejeita (p < 0,001); tirando os tres trimestres dos pulsos da DUM a quebra continua (2016T3; supF p < 0,001), e o Chow preditivo, que nao estima o segundo regime, tambem rejeita. Como o ultimo segmento tem 11 observacoes (11 sem os trimestres da DUM) para 10 coeficientes, o p assintotico do supF exagera. A equacao de PVD e estavel (supF p = 0,396). No VAR estendido, o Chow da equacao de inf_diss em 2018T4 rejeita (p = 0,020), mas os quatro outliers do X-11 de 2018-2019 deixam a elasticidade em 0,140 e a DUM da dissertacao em 0,141. O pulso ida e volta de 2018T4 sozinho vai a 0,227 porque pega o maior residuo da equacao de inf_diss (2019T1, a queda do boletim marcada pelo LS2019.1), e nao um efeito eleitoral: o grupo de T4 eleitorais fica em 0,158. NAO IMPORTAM: 2008T4, 2016T4 e 2017T1 (teto de gastos) e 2023T3 (arcabouco fiscal), como degrau ou pulso (elasticidade de 0,122 a 0,171 no estendido; 0,349 a 0,490 no VAR da dissertacao); a emenda boletim/OI da SEST (degrau em 2020T1: 0,134; variantes de encadeamento da A3: 0,154 a 0,173; nenhum Chow das datas de emenda rejeita em estatais_total ou inf_diss); a imputacao de 2017 (variantes da A3: 0,150 a 0,152; pulsos de 2017T1 a 2018T1: 0,180; F dos pulsos sem significancia nas series e nas equacoes); o T4 eleitoral como grupo (0,158; com Newey-West so uniao_econ_dir rejeita a 5%, com coeficiente negativo e maior t em 2014); a mudanca de composicao por elemento em 2011-2016 (a janela nao e significativa em nenhuma serie da Uniao; ela nao afeta inf_diss, que usa o filtro da dissertacao); e a saida da Eletrobras em 2022T3 (Chow sem significancia). Nas series, Bai-Perron na media da diferenca nao seleciona quebra em 21 de 21 series (BIC e LWZ), o supF classico nao rejeita em nenhuma e o supF com Newey-West rejeita a 5% so em uniao_gnd4_dir, uniao_filtro_diss (maximo em 2010T3), no fim da aceleracao do investimento federal de 2007-2010, a mesma quebra que o Chow com Newey-West acha em 2011T1 nas series da Uniao. Resumo para a A5: estimar com a amostra 2003T1-2025T4 com os pulsos de 2020T2 e 2020T3 no baseline, reportar a amostra ate 2019T4 e as subamostras antes e depois de 2014T4, tratar os AO de 2020-2021 das estatais (variante sem AO ou dummies do X-11) como a robustez que mais move o numero, e nao gastar graus de liberdade com dummies de 2008T4, 2016T4/2017T1, 2023T3, emenda da SEST, imputacao de 2017 ou T4 eleitoral. Referencia do VAR estendido de base (com os pulsos): 0,173 em h = 40.

## 1. Series: Bai-Perron, supF, CUSUM e MOSUM (media da diferenca do log10)

| serie | amostra | m BIC/LWZ | datas BIC [IC 95%] | cresc. % a.a. | supF | p | data max | p NW | p CUSUM | p CUSUM VLP | p MOSUM |
|---|---|---|---|---|---|---|---|---|---|---|---|
| uniao_econ_dir | 2003T1-2025T4 | 0/0 | nenhuma | 6,3 | 1,74 | 0,858 | 2011T2 | 0,237 | 0,825 | 0,178 | 0,539 |
| uniao_econ_dt_g1 | 2003T1-2025T4 | 0/0 | nenhuma | 5,9 | 1,98 | 0,800 | 2011T2 | 0,137 | 0,763 | 0,142 | 0,540 |
| uniao_soc_dir | 2003T1-2025T4 | 0/0 | nenhuma | 6,1 | 5,13 | 0,240 | 2010T4 | 0,093 | 0,228 | 0,061 | 0,420 |
| uniao_soc_dt_g1 | 2003T1-2025T4 | 0/0 | nenhuma | 8,1 | 1,36 | 0,946 | 2008T4 | 0,463 | 0,939 | 0,504 | 0,628 |
| uniao_transf_soc_g1 | 2003T1-2025T4 | 0/0 | nenhuma | 9,4 | 1,06 | 0,995 | 2008T4 | 0,682 | 0,990 | 0,737 | 0,673 |
| uniao_gnd4_dir | 2003T1-2025T4 | 0/0 | nenhuma | 5,1 | 4,19 | 0,354 | 2010T3 | 0,031 | 0,343 | 0,048 | 0,477 |
| uniao_filtro_diss | 2003T1-2025T4 | 0/0 | nenhuma | 3,9 | 3,92 | 0,395 | 2010T3 | 0,041 | 0,382 | 0,057 | 0,462 |
| estatais_total | 2003T1-2025T4 | 0/0 | nenhuma | 1,8 | 0,78 | 1,000 | 2014T1 | 0,567 | 0,990 | 0,960 | 0,523 |
| estatais_petro | 2016T1-2025T4 | 0/0 | nenhuma | -1,1 | 0,89 | 1,000 | 2017T4 | 0,610 | 0,994 | 0,952 | 0,526 |
| estatais_sempetro | 2016T1-2025T4 | 0/0 | nenhuma | -4,0 | 0,89 | 1,000 | 2020T2 | 0,195 | 0,983 | 0,229 | 0,475 |
| estatais_econ | 2016T1-2025T4 | 0/0 | nenhuma | -15,8 | 0,99 | 1,000 | 2023T3 | 0,717 | 0,991 | 0,983 | 0,494 |
| estatais_grupopetro | 2016T1-2025T4 | 0/0 | nenhuma | -1,0 | 0,90 | 1,000 | 2017T4 | 0,601 | 0,994 | 0,948 | 0,525 |
| estatais_semgrupopetro | 2016T1-2025T4 | 0/0 | nenhuma | -4,5 | 0,81 | 1,000 | 2020T2 | 0,218 | 0,990 | 0,281 | 0,478 |
| inf_diss | 2003T1-2025T4 | 0/0 | nenhuma | 2,1 | 1,22 | 0,973 | 2010T3 | 0,465 | 0,938 | 0,821 | 0,497 |
| fbcf_me | 2002T1-2025T4 | 0/0 | nenhuma | 2,4 | 2,16 | 0,750 | 2013T3 | 0,451 | 0,662 | 0,641 | 0,384 |
| fbcf_constr | 2002T1-2025T4 | 0/0 | nenhuma | 1,9 | 4,06 | 0,368 | 2012T2 | 0,390 | 0,293 | 0,252 | 0,105 |
| fbcf_total | 2002T1-2025T4 | 0/0 | nenhuma | 2,3 | 4,11 | 0,361 | 2013T3 | 0,323 | 0,274 | 0,459 | 0,113 |
| pim_bk | 2002T1-2025T4 | 0/0 | nenhuma | 1,4 | 2,99 | 0,560 | 2008T4 | 0,273 | 0,606 | 0,703 | 0,360 |
| imp_bk_quantum | 2002T1-2025T4 | 0/0 | nenhuma | 6,7 | 0,79 | 1,000 | 2010T4 | 0,925 | 0,994 | 0,728 | 0,555 |
| bndes_priv | 2002T1-2025T4 | 0/0 | nenhuma | 1,9 | 1,85 | 0,827 | 2010T4 | 0,222 | 0,794 | 0,326 | 0,443 |
| pvd_diss | 2002T1-2019T4 | 0/0 | nenhuma | 3,0 | 4,01 | 0,383 | 2013T3 | 0,428 | 0,334 | 0,376 | 0,181 |

## 2. Equacoes do VAR

| equacao | n | k | h | m BIC/LWZ | datas BIC [IC 95%] | supF | p | data max | p CUSUM | p MOSUM |
|---|---|---|---|---|---|---|---|---|---|---|
| Dissertacao, equacao de INF | 68 | 10 | 11 | 1/0 | 2017T2 [2017T1; 2017T3] | 103,03 | <0,001 | 2017T2 | 0,946 | 0,354 |
| Dissertacao, equacao de PVD | 68 | 10 | 11 | 0/0 | nenhuma | 18,67 | 0,396 | 2017T2 | 0,981 | 0,392 |
| Dissertacao, INF, sem 2018T2, 2019T2 e 2019T3 | 65 | 10 | 11 | 1/0 | 2016T3 [2016T2; 2016T4] | 62,81 | <0,001 | 2016T3 | 0,851 | 0,377 |
| Dissertacao, PVD, sem 2018T2, 2019T2 e 2019T3 | 65 | 10 | 11 | 0/0 | nenhuma | 20,14 | 0,285 | 2016T1 | 0,981 | 0,412 |
| Estendido, equacao de inf_diss | 88 | 10 | 13 | 0/0 | nenhuma | 31,25 | 0,013 | 2020T2 | 0,813 | 0,347 |
| Estendido, equacao de fbcf_me | 88 | 10 | 13 | 0/0 | nenhuma | 38,68 | <0,001 | 2020T2 | 0,974 | 0,353 |

## 3. Chow nas datas candidatas (p do F classico; nas series, entre parenteses, p do degrau com Newey-West)

| nome | 2008T4 | 2014T4 | 2015T1 | 2016T4 | 2017T1 | 2020T2 | 2023T3 | 2018T4 |
|---|---|---|---|---|---|---|---|---|
| uniao_econ_dir | 0,37 (0,15) | 0,39 (0,12) | 0,59 (0,34) | 0,75 (0,56) | 0,70 (0,47) | 0,87 (0,76) | 0,78 (0,48) | 0,70 (0,47) |
| uniao_econ_dt_g1 | 0,28 (0,07) | 0,37 (0,11) | 0,59 (0,36) | 0,76 (0,59) | 0,70 (0,49) | 0,88 (0,79) | 0,80 (0,52) | 0,71 (0,49) |
| uniao_soc_dir | 0,25 (0,21) | 0,08 (0,02) | 0,12 (0,04) | 0,37 (0,23) | 0,34 (0,21) | 0,67 (0,55) | 0,54 (0,24) | 0,59 (0,45) |
| uniao_soc_dt_g1 | 0,25 (0,06) | 0,35 (0,17) | 0,64 (0,50) | 0,68 (0,55) | 0,54 (0,40) | 0,85 (0,82) | 0,86 (0,68) | 0,80 (0,74) |
| uniao_transf_soc_g1 | 0,31 (0,12) | 0,45 (0,29) | 0,86 (0,81) | 0,76 (0,66) | 0,63 (0,50) | 0,82 (0,78) | 0,81 (0,57) | 0,84 (0,79) |
| uniao_gnd4_dir | 0,19 (0,04) | 0,07 (0,01) | 0,26 (0,10) | 0,48 (0,29) | 0,46 (0,27) | 0,74 (0,60) | 0,89 (0,71) | 0,51 (0,32) |
| uniao_filtro_diss | 0,21 (0,06) | 0,11 (0,03) | 0,31 (0,15) | 0,63 (0,48) | 0,68 (0,55) | 0,78 (0,67) | 0,81 (0,52) | 0,56 (0,37) |
| estatais_total | 0,71 (0,47) | 0,56 (0,42) | 0,61 (0,50) | 0,86 (0,83) | 0,75 (0,71) | 0,83 (0,81) | 0,69 (0,47) | 0,52 (0,59) |
| estatais_petro |  |  |  |  |  | 0,90 (0,89) | 0,68 (0,46) | 0,66 (0,68) |
| estatais_sempetro |  |  |  |  |  | 0,35 (0,16) | 0,79 (0,68) | 0,97 (0,95) |
| estatais_econ |  |  |  |  |  | 0,52 (0,47) | 0,33 (0,24) | 0,87 (0,83) |
| estatais_grupopetro |  |  |  |  |  | 0,90 (0,89) | 0,67 (0,45) | 0,66 (0,68) |
| estatais_semgrupopetro |  |  |  |  |  | 0,38 (0,16) | 0,74 (0,59) | 0,99 (0,98) |
| inf_diss | 0,57 (0,28) | 0,39 (0,24) | 0,51 (0,38) | 0,94 (0,93) | 0,83 (0,80) | 0,80 (0,77) | 0,75 (0,52) | 0,47 (0,53) |
| fbcf_me | 0,18 (0,06) | 0,28 (0,21) | 0,30 (0,22) | 0,94 (0,93) | 0,94 (0,93) | 0,63 (0,62) | 0,95 (0,89) | 0,47 (0,45) |
| fbcf_constr | 0,43 (0,45) | 0,16 (0,15) | 0,16 (0,15) | 0,97 (0,97) | 0,82 (0,81) | 0,58 (0,54) | 0,75 (0,58) | 0,55 (0,50) |
| fbcf_total | 0,12 (0,10) | 0,15 (0,14) | 0,16 (0,16) | 0,92 (0,91) | 0,82 (0,81) | 0,95 (0,95) | 0,99 (0,99) | 0,96 (0,96) |
| pim_bk | 0,09 (0,03) | 0,30 (0,30) | 0,41 (0,39) | 0,88 (0,88) | 0,85 (0,85) | 0,90 (0,91) | 1,00 (1,00) | 0,84 (0,85) |
| imp_bk_quantum | 0,46 (0,29) | 0,74 (0,63) | 0,78 (0,68) | 0,66 (0,50) | 0,63 (0,46) | 0,77 (0,73) | 0,70 (0,42) | 0,73 (0,68) |
| bndes_priv | 0,65 (0,45) | 0,52 (0,33) | 0,57 (0,38) | 0,84 (0,75) | 0,73 (0,59) | 0,26 (0,06) | 0,45 (0,06) | 0,50 (0,28) |
| pvd_diss | 0,10 (0,08) | 0,15 (0,19) | 0,16 (0,21) | 0,61 (0,51) | 0,62 (0,52) |  |  | 0,20 (0,15) |
| orig_INF | 0,336 | 0,072 | 0,103 | 0,011 | 0,000 |  |  | 0,000 (P) |
| orig_PVD | 0,371 | 0,661 | 0,525 | 0,366 | 0,158 |  |  | 0,440 (P) |
| orig_INF_sd | 0,120 | 0,023 | 0,024 | 0,000 (P) | 0,000 (P) |  |  | 0,000 (P) |
| orig_PVD_sd | 0,403 | 0,572 | 0,261 | 0,077 (P) | 0,056 (P) |  |  | 0,282 (P) |
| ext_inf | 0,984 | 0,336 | 0,388 | 0,210 | 0,171 | 0,002 | 0,988 (P) | 0,020 |
| ext_fbcf | 0,841 | 0,749 | 0,742 | 0,325 | 0,337 | 0,000 | 0,987 (P) | 0,314 |

(P) = teste preditivo de Chow (um dos regimes tem menos observacoes que regressores).

## 4. Quebras nos dados

| serie | origem | data | F | p | p NW | cresc. antes | cresc. depois |
|---|---|---|---|---|---|---|---|
| estatais_total | Emenda boletim/OI da SEST | 2016T1 | 0,02 | 0,875 | 0,842 | 3,1 | 0,1 |
| estatais_total | Emenda boletim/OI da SEST | 2017T1 | 0,10 | 0,749 | 0,705 | -0,7 | 5,6 |
| estatais_total | Emenda boletim/OI da SEST | 2018T1 | 0,11 | 0,745 | 0,715 | -0,5 | 6,0 |
| estatais_total | Emenda boletim/OI da SEST | 2019T1 | 0,02 | 0,894 | 0,887 | 2,6 | -0,1 |
| estatais_total | Emenda boletim/OI da SEST | 2020T1 | 0,02 | 0,901 | 0,883 | 2,5 | -0,2 |
| inf_diss | Emenda boletim/OI da SEST | 2016T1 | 0,04 | 0,839 | 0,798 | 3,6 | 0,2 |
| inf_diss | Emenda boletim/OI da SEST | 2017T1 | 0,05 | 0,829 | 0,796 | 0,7 | 4,3 |
| inf_diss | Emenda boletim/OI da SEST | 2018T1 | 0,03 | 0,859 | 0,836 | 1,0 | 4,1 |
| inf_diss | Emenda boletim/OI da SEST | 2019T1 | 0,05 | 0,830 | 0,811 | 3,2 | -0,5 |
| inf_diss | Emenda boletim/OI da SEST | 2020T1 | 0,04 | 0,837 | 0,807 | 3,1 | -0,7 |
| uniao_filtro_diss | Imputacao de 2017 | 2017T1 | 0,17 | 0,682 | 0,546 | 6,6 | -0,0 |
| uniao_filtro_diss | Imputacao de 2017 | 2018T1 | 0,32 | 0,575 | 0,398 | 7,3 | -2,0 |
| inf_diss | Imputacao de 2017 | 2017T1 | 0,05 | 0,829 | 0,796 | 0,7 | 4,3 |
| inf_diss | Imputacao de 2017 | 2018T1 | 0,03 | 0,859 | 0,836 | 1,0 | 4,1 |
| uniao_econ_dir | Composicao por elemento (2011-2016) | 2011T1 | 1,20 | 0,276 | 0,055 | 33,7 | -5,6 |
| uniao_econ_dir | Composicao por elemento (2011-2016) | 2017T1 | 0,15 | 0,695 | 0,466 | 11,5 | -1,2 |
| uniao_econ_dt_g1 | Composicao por elemento (2011-2016) | 2011T1 | 1,49 | 0,225 | 0,029 | 34,2 | -6,4 |
| uniao_econ_dt_g1 | Composicao por elemento (2011-2016) | 2017T1 | 0,15 | 0,702 | 0,489 | 10,6 | -1,0 |
| uniao_gnd4_dir | Composicao por elemento (2011-2016) | 2011T1 | 3,61 | 0,061 | 0,004 | 25,9 | -4,2 |
| uniao_gnd4_dir | Composicao por elemento (2011-2016) | 2017T1 | 0,55 | 0,461 | 0,270 | 9,6 | -1,4 |
| uniao_soc_dir | Composicao por elemento (2011-2016) | 2011T1 | 3,39 | 0,069 | 0,026 | 28,1 | -3,8 |
| uniao_soc_dir | Composicao por elemento (2011-2016) | 2017T1 | 0,92 | 0,340 | 0,208 | 12,4 | -2,9 |
| estatais_econ | Saida da Eletrobras (2022T3) | 2022T3 | 0,04 | 0,841 | 0,841 | -14,0 | -19,0 |
| estatais_sempetro | Saida da Eletrobras (2022T3) | 2022T3 | 0,02 | 0,886 | 0,769 | -6,0 | -0,5 |
| estatais_semgrupopetro | Saida da Eletrobras (2022T3) | 2022T3 | 0,01 | 0,925 | 0,842 | -5,8 | -2,2 |

| serie | teste | coef | F | p | p NW | t 2006 | t 2010 | t 2014 | t 2018 | t 2022 |
|---|---|---|---|---|---|---|---|---|---|---|
| uniao_econ_dir | eleicao | -0,081 | NA | 0,142 | 0,032 | -0,24 | -0,58 | -1,80 | 0,08 | -0,66 |
| uniao_econ_dt_g1 | eleicao | -0,079 | NA | 0,124 | 0,055 | 0,04 | -0,43 | -2,09 | 0,11 | -0,71 |
| uniao_soc_dir | eleicao | -0,023 | NA | 0,399 | 0,354 | 1,13 | -1,72 | -0,90 | 0,54 | 0,37 |
| uniao_soc_dt_g1 | eleicao | -0,074 | NA | 0,128 | 0,172 | 0,56 | -1,02 | -2,34 | 0,92 | -0,66 |
| uniao_transf_soc_g1 | eleicao | -0,114 | NA | 0,091 | 0,239 | 0,24 | -0,85 | -3,26 | 1,05 | -0,48 |
| uniao_gnd4_dir | eleicao | -0,044 | NA | 0,080 | 0,076 | -0,43 | -0,17 | -2,57 | -0,28 | -0,54 |
| uniao_filtro_diss | eleicao | -0,040 | NA | 0,152 | 0,108 | -0,78 | -0,16 | -2,26 | -0,09 | -0,41 |
| estatais_total | eleicao | 0,005 | NA | 0,891 | 0,882 | -1,19 | 0,07 | -0,15 | 0,95 | -0,59 |
| estatais_petro | eleicao | -0,004 | NA | 0,962 | 0,957 | NA | NA | NA | 0,61 | -0,68 |
| estatais_sempetro | eleicao | -0,041 | NA | 0,517 | 0,163 | NA | NA | NA | -0,89 | -0,04 |
| estatais_econ | eleicao | -0,007 | NA | 0,891 | 0,682 | NA | NA | NA | -0,44 | 0,24 |
| estatais_grupopetro | eleicao | -0,004 | NA | 0,958 | 0,953 | NA | NA | NA | 0,60 | -0,67 |
| estatais_semgrupopetro | eleicao | -0,041 | NA | 0,523 | 0,194 | NA | NA | NA | -0,88 | -0,04 |
| inf_diss | eleicao | -0,009 | NA | 0,753 | 0,710 | -1,23 | 0,02 | -0,63 | 0,59 | -0,61 |
| fbcf_me | eleicao | 0,004 | NA | 0,779 | 0,745 | 0,17 | -0,25 | 0,41 | -0,93 | 1,34 |
| fbcf_constr | eleicao | 0,001 | NA | 0,852 | 0,625 | -0,13 | 0,06 | 0,54 | -0,40 | 0,18 |
| fbcf_total | eleicao | 0,002 | NA | 0,795 | 0,510 | -0,12 | -0,27 | 0,47 | -0,10 | 0,42 |
| pim_bk | eleicao | 0,002 | NA | 0,886 | 0,652 | -0,28 | 0,25 | -0,14 | -0,08 | 0,26 |
| imp_bk_quantum | eleicao | -0,046 | NA | 0,060 | 0,203 | -0,10 | -0,61 | -0,17 | -3,73 | 0,51 |
| bndes_priv | eleicao | -0,032 | NA | 0,363 | 0,504 | 0,58 | -2,82 | -0,09 | 0,87 | 0,11 |
| pvd_diss | eleicao | -0,003 | NA | 0,826 | 0,747 | 0,21 | -0,31 | 0,60 | -0,67 | NA |
| uniao_econ_dir | eleicao2006 | -0,070 | NA | 0,155 | 0,026 | -0,24 | -0,58 | -1,80 | 0,08 | -0,66 |
| uniao_econ_dt_g1 | eleicao2006 | -0,063 | NA | 0,175 | 0,081 | 0,04 | -0,43 | -2,09 | 0,11 | -0,71 |
| uniao_soc_dir | eleicao2006 | -0,006 | NA | 0,803 | 0,807 | 1,13 | -1,72 | -0,90 | 0,54 | 0,37 |
| uniao_soc_dt_g1 | eleicao2006 | -0,049 | NA | 0,267 | 0,323 | 0,56 | -1,02 | -2,34 | 0,92 | -0,66 |
| uniao_transf_soc_g1 | eleicao2006 | -0,085 | NA | 0,162 | 0,299 | 0,24 | -0,85 | -3,26 | 1,05 | -0,48 |
| uniao_gnd4_dir | eleicao2006 | -0,040 | NA | 0,079 | 0,052 | -0,43 | -0,17 | -2,57 | -0,28 | -0,54 |
| uniao_filtro_diss | eleicao2006 | -0,041 | NA | 0,103 | 0,043 | -0,78 | -0,16 | -2,26 | -0,09 | -0,41 |
| estatais_total | eleicao2006 | -0,012 | NA | 0,686 | 0,672 | -1,19 | 0,07 | -0,15 | 0,95 | -0,59 |
| estatais_petro | eleicao2006 | -0,004 | NA | 0,962 | 0,957 | NA | NA | NA | 0,61 | -0,68 |
| estatais_sempetro | eleicao2006 | -0,041 | NA | 0,517 | 0,163 | NA | NA | NA | -0,89 | -0,04 |
| estatais_econ | eleicao2006 | -0,007 | NA | 0,891 | 0,682 | NA | NA | NA | -0,44 | 0,24 |
| estatais_grupopetro | eleicao2006 | -0,004 | NA | 0,958 | 0,953 | NA | NA | NA | 0,60 | -0,67 |
| estatais_semgrupopetro | eleicao2006 | -0,041 | NA | 0,523 | 0,194 | NA | NA | NA | -0,88 | -0,04 |
| inf_diss | eleicao2006 | -0,021 | NA | 0,408 | 0,338 | -1,23 | 0,02 | -0,63 | 0,59 | -0,61 |
| fbcf_me | eleicao2006 | 0,004 | NA | 0,744 | 0,676 | 0,17 | -0,25 | 0,41 | -0,93 | 1,34 |
| fbcf_constr | eleicao2006 | 0,001 | NA | 0,913 | 0,771 | -0,13 | 0,06 | 0,54 | -0,40 | 0,18 |
| fbcf_total | eleicao2006 | 0,001 | NA | 0,859 | 0,652 | -0,12 | -0,27 | 0,47 | -0,10 | 0,42 |
| pim_bk | eleicao2006 | 0,000 | NA | 0,996 | 0,988 | -0,28 | 0,25 | -0,14 | -0,08 | 0,26 |
| imp_bk_quantum | eleicao2006 | -0,038 | NA | 0,085 | 0,205 | -0,10 | -0,61 | -0,17 | -3,73 | 0,51 |
| bndes_priv | eleicao2006 | -0,018 | NA | 0,579 | 0,665 | 0,58 | -2,82 | -0,09 | 0,87 | 0,11 |
| pvd_diss | eleicao2006 | -0,001 | NA | 0,932 | 0,892 | 0,21 | -0,31 | 0,60 | -0,67 | NA |
| uniao_filtro_diss | imp2017 | NA | 0,59 | 0,707 | NA | NA | NA | NA | NA | NA |
| inf_diss | imp2017 | NA | 0,34 | 0,885 | NA | NA | NA | NA | NA | NA |
| uniao_econ_dir | composicao | -0,027 | NA | 0,462 | 0,195 | NA | NA | NA | NA | NA |
| uniao_econ_dt_g1 | composicao | -0,030 | NA | 0,381 | 0,128 | NA | NA | NA | NA | NA |
| uniao_gnd4_dir | composicao | -0,020 | NA | 0,236 | 0,155 | NA | NA | NA | NA | NA |
| uniao_soc_dir | composicao | -0,016 | NA | 0,377 | 0,228 | NA | NA | NA | NA | NA |

| equacao | teste | coef | F | p | p NW |
|---|---|---|---|---|---|
| orig_INF | eleicao | -0,0169 | NA | 0,565 | 0,515 |
| orig_INF | eleicao2006 | -0,0414 | NA | 0,099 | 0,123 |
| orig_INF | imp2017 | NA | 0,36 | 0,871 | NA |
| orig_PVD | eleicao | -0,0048 | NA | 0,725 | 0,588 |
| orig_PVD | eleicao2006 | -0,0023 | NA | 0,847 | 0,789 |
| orig_PVD | imp2017 | NA | 0,81 | 0,550 | NA |
| ext_inf | eleicao | -0,0017 | NA | 0,952 | 0,946 |
| ext_inf | eleicao2006 | -0,0147 | NA | 0,550 | 0,478 |
| ext_inf | imp2017 | NA | 0,51 | 0,768 | NA |
| ext_inf | pandemia | NA | 1,22 | 0,300 | NA |
| ext_fbcf | eleicao | -0,0055 | NA | 0,706 | 0,767 |
| ext_fbcf | eleicao2006 | -0,0031 | NA | 0,814 | 0,836 |
| ext_fbcf | imp2017 | NA | 0,32 | 0,898 | NA |
| ext_fbcf | pandemia | NA | 7,01 | 0,002 | NA |

## 5. Raiz unitaria com quebra (valores criticos de LP e CMR simulados)

| serie | T | lag ZA/LP | lag CMR | ZA | ZA rejeita 5% | LP | p LP | CMR-IO | p IO | CMR-AO | p AO |
|---|---|---|---|---|---|---|---|---|---|---|---|
| uniao_econ_dir | 92 | 1 | 1 | -4,61 (2005T2) | nao | -6,12 (2011T2, 2021T1) | 0,101 | -3,79 (2006T3, 2014T3) | 0,703 | -3,85 (2006T3, 2014T2) | 0,682 |
| uniao_econ_dt_g1 | 92 | 1 | 1 | -4,13 (2005T3) | nao | -6,38 (2011T2, 2021T1) | 0,050 | -3,88 (2006T3, 2014T3) | 0,655 | -3,89 (2006T3, 2014T2) | 0,658 |
| uniao_soc_dir | 92 | 1 | 1 | -4,20 (2009T2) | nao | -6,57 (2010T1, 2015T2) | 0,033 | -4,76 (2008T4, 2015T1) | 0,202 | -4,52 (2008T4, 2014T4) | 0,323 |
| uniao_soc_dt_g1 | 92 | 1 | 1 | -5,10 (2009T3) | sim | -6,45 (2010T1, 2021T1) | 0,042 | -5,31 (2007T3, 2016T4) | 0,044 | -5,17 (2007T3, 2016T3) | 0,080 |
| uniao_transf_soc_g1 | 92 | 1 | 1 | -5,62 (2008T2) | sim | -6,64 (2013T1, 2022T3) | 0,027 | -6,05 (2007T3, 2016T4) | 0,004 | -5,97 (2007T4, 2016T3) | 0,010 |
| uniao_gnd4_dir | 92 | 1 | 1 | -3,82 (2014T4) | nao | -5,28 (2011T2, 2014T4) | 0,438 | -3,87 (2008T3, 2014T3) | 0,659 | -3,86 (2008T1, 2014T2) | 0,675 |
| uniao_filtro_diss | 92 | 1 | 1 | -3,85 (2014T4) | nao | -5,88 (2011T2, 2014T4) | 0,167 | -4,13 (2008T3, 2014T3) | 0,521 | -4,11 (2008T1, 2014T2) | 0,547 |
| estatais_total | 92 | 0 | 0 | -4,49 (2014T3) | nao | -5,81 (2014T3, 2021T3) | 0,194 | -5,07 (2008T1, 2015T1) | 0,094 | -5,15 (2008T1, 2015T1) | 0,083 |
| estatais_petro | 40 | 0 | 0 | -5,46 (2021T3) | sim | -6,44 (2019T1, 2021T3) | 0,083 | -4,89 (2020T3, 2024T2) | 0,156 | -5,02 (2020T3, 2024T2) | 0,139 |
| estatais_sempetro | 40 | 0 | 0 | -8,02 (2020T3) | sim | -8,90 (2020T1, 2021T4) | <0,001 | -7,48 (2019T1, 2020T3) | <0,001 | -7,79 (2019T1, 2020T3) | <0,001 |
| estatais_econ | 40 | 0 | 0 | -5,26 (2022T3) | sim | -6,31 (2020T4, 2022T3) | 0,110 | -5,15 (2018T3, 2022T2) | 0,093 | -5,25 (2018T3, 2022T2) | 0,087 |
| estatais_grupopetro | 40 | 0 | 0 | -5,47 (2021T3) | sim | -6,43 (2019T1, 2021T3) | 0,084 | -4,89 (2020T3, 2024T2) | 0,157 | -5,01 (2020T3, 2024T2) | 0,139 |
| estatais_semgrupopetro | 40 | 0 | 0 | -8,48 (2020T3) | sim | -9,11 (2018T3, 2020T3) | <0,001 | -7,86 (2019T1, 2020T3) | <0,001 | -8,20 (2019T1, 2020T3) | <0,001 |
| inf_diss | 92 | 0 | 0 | -4,54 (2014T4) | nao | -5,71 (2014T4, 2021T3) | 0,224 | -4,86 (2008T1, 2015T1) | 0,157 | -4,94 (2008T1, 2015T1) | 0,138 |
| fbcf_me | 96 | 0 | 0 | -4,56 (2014T2) | nao | -5,71 (2013T1, 2017T2) | 0,228 | -4,15 (2006T3, 2014T4) | 0,458 | -4,21 (2006T3, 2014T4) | 0,436 |
| fbcf_constr | 96 | 0 | 0 | -3,63 (2015T1) | nao | -4,51 (2012T1, 2020T3) | 0,863 | -3,37 (2006T3, 2020T2) | 0,847 | -3,35 (2006T3, 2020T2) | 0,864 |
| fbcf_total | 96 | 0 | 0 | -4,19 (2015T1) | nao | -5,46 (2009T3, 2015T2) | 0,344 | -3,40 (2006T3, 2020T2) | 0,839 | -3,40 (2006T3, 2020T2) | 0,848 |
| pim_bk | 96 | 0 | 0 | -4,07 (2014T4) | nao | -5,12 (2009T1, 2014T4) | 0,531 | -4,04 (2006T3, 2014T3) | 0,524 | -4,10 (2006T3, 2014T3) | 0,501 |
| imp_bk_quantum | 96 | 1 | 1 | -3,45 (2014T1) | nao | -5,30 (2012T2, 2016T3) | 0,428 | -3,16 (2006T1, 2020T3) | 0,911 | -3,04 (2005T4, 2021T4) | 0,942 |
| bndes_priv | 96 | 1 | 1 | -3,33 (2015T3) | nao | -5,24 (2012T3, 2019T2) | 0,455 | -4,15 (2007T2, 2015T2) | 0,455 | -4,15 (2007T3, 2015T1) | 0,468 |
| pvd_diss | 72 | 0 | 0 | -3,39 (2009T4) | nao | -4,86 (2009T4, 2015T2) | 0,698 | -3,41 (2006T3, 2014T4) | 0,822 | -3,45 (2006T3, 2014T4) | 0,823 |

| T | teste | 1% | 5% | 10% | replicas |
|---|---|---|---|---|---|
| 40 | LP | -7,42 | -6,68 | -6,34 | 1000 |
| 40 | IO | -6,35 | -5,51 | -5,13 | 1000 |
| 40 | AO | -6,45 | -5,57 | -5,16 | 1000 |
| 72 | LP | -7,00 | -6,45 | -6,12 | 1000 |
| 72 | IO | -5,99 | -5,43 | -5,07 | 1000 |
| 72 | AO | -6,08 | -5,44 | -5,11 | 1000 |
| 92 | LP | -6,97 | -6,37 | -6,12 | 1000 |
| 92 | IO | -5,97 | -5,28 | -5,05 | 1000 |
| 92 | AO | -5,91 | -5,31 | -5,09 | 1000 |
| 96 | LP | -6,83 | -6,40 | -6,15 | 1000 |
| 96 | IO | -5,89 | -5,30 | -4,97 | 1000 |
| 96 | AO | -5,93 | -5,36 | -5,01 | 1000 |

Valores criticos de LP e CMR simulados por Monte Carlo (1000 replicas de passeio aleatorio com erros normais, mesmo T e mesma regra de lags, set.seed(42)); ZA com os valores assintoticos do urca (-5,57; -5,08; -4,82).

## 6. Estimacao: amostras, janelas e dummies

VAR da dissertacao (arquivos originais, niveis 2002T1-2019T4, 68 observacoes efetivas): elasticidade 0,416 em h = 40 (observacoes efetivas ate 2014T4: 0,028). VAR estendido, amostra completa, sem dummies: 0,154 em h = 12 e 0,154 em h = 40; com os pulsos de 2020T2 e 2020T3 (especificacao de base da A5, referencia do VAR estendido): 0,173 e 0,173. Projecao local simples (sem tendencia e sem pulsos; diagnostico, nao e a LP da A5), resposta acumulada de fbcf_me em h = 8: -0,086 (EP 0,163). Subamostras: observacoes efetivas ate 2014T4 e de 2015T1 em diante (na projecao local, t e t + 8 dentro da subamostra).

| amostra | n | el h=12 | el h=40 | LP h=8 | EP LP | efeito |
|---|---|---|---|---|---|---|
| Amostra completa | 88 | 0,154 | 0,154 | -0,086 | 0,163 | nao muda |
| Ate 2014T4 | 44 | 0,219 | 0,227 | 0,094 | 0,312 | muda mais de 25% |
| De 2015T1 | 44 | 0,060 | 0,059 | -0,270 | 0,116 | muda mais de 25% |
| Ate 2019T4 | 64 | 0,412 | 0,451 | 0,190 | 0,276 | muda mais de 25% |

| modelo | experimento | el h=12 | el h=40 | resp. priv. h=40 | resp. publ. h=40 | efeito |
|---|---|---|---|---|---|---|
| ext | Degrau em 2008T4 | 0,141 | 0,141 | 0,0079 | 0,0560 | nao muda |
| ext | Pulso em 2008T4 | 0,170 | 0,171 | 0,0094 | 0,0553 | nao muda |
| orig | Degrau em 2008T4 | 0,432 | 0,440 | 0,0206 | 0,0469 | nao muda |
| orig | Pulso em 2008T4 | 0,485 | 0,490 | 0,0228 | 0,0465 | nao muda |
| ext | Degrau em 2014T4 | 0,135 | 0,135 | 0,0069 | 0,0509 | nao muda |
| ext | Pulso em 2014T4 | 0,152 | 0,152 | 0,0084 | 0,0556 | nao muda |
| orig | Degrau em 2014T4 | 0,460 | 0,466 | 0,0188 | 0,0404 | nao muda |
| orig | Pulso em 2014T4 | 0,429 | 0,439 | 0,0199 | 0,0452 | nao muda |
| ext | Degrau em 2015T1 | 0,141 | 0,141 | 0,0075 | 0,0530 | nao muda |
| ext | Pulso em 2015T1 | 0,148 | 0,148 | 0,0084 | 0,0567 | nao muda |
| orig | Degrau em 2015T1 | 0,428 | 0,434 | 0,0187 | 0,0432 | nao muda |
| orig | Pulso em 2015T1 | 0,395 | 0,402 | 0,0188 | 0,0466 | nao muda |
| ext | Degrau em 2016T4 | 0,135 | 0,135 | 0,0075 | 0,0558 | nao muda |
| ext | Pulso em 2016T4 | 0,166 | 0,166 | 0,0091 | 0,0552 | nao muda |
| orig | Degrau em 2016T4 | 0,349 | 0,356 | 0,0163 | 0,0458 | nao muda |
| orig | Pulso em 2016T4 | 0,426 | 0,433 | 0,0198 | 0,0458 | nao muda |
| ext | Degrau em 2017T1 | 0,122 | 0,122 | 0,0066 | 0,0545 | nao muda |
| ext | Pulso em 2017T1 | 0,155 | 0,155 | 0,0087 | 0,0565 | nao muda |
| orig | Degrau em 2017T1 | 0,342 | 0,349 | 0,0153 | 0,0440 | nao muda |
| orig | Pulso em 2017T1 | 0,410 | 0,418 | 0,0195 | 0,0467 | nao muda |
| ext | Degrau em 2020T2 | 0,156 | 0,156 | 0,0088 | 0,0560 | nao muda |
| ext | Pulso em 2020T2 | 0,186 | 0,186 | 0,0109 | 0,0585 | nao muda |
| ext | Degrau em 2023T3 | 0,140 | 0,140 | 0,0074 | 0,0527 | nao muda |
| ext | Pulso em 2023T3 | 0,158 | 0,158 | 0,0090 | 0,0567 | nao muda |
| ext | Pulsos em 2020T2 e 2020T3 | 0,173 | 0,173 | 0,0098 | 0,0567 | nao muda |
| ext | T4 eleitoral (2010, 2014, 2018, 2022) | 0,158 | 0,158 | 0,0090 | 0,0569 | nao muda |
| ext | T4 eleitoral com 2006 | 0,155 | 0,155 | 0,0089 | 0,0572 | nao muda |
| orig | T4 eleitoral (2010, 2014, 2018) | 0,409 | 0,418 | 0,0199 | 0,0476 | nao muda |
| ext | Degrau em 2020T1 (emenda da SEST) | 0,134 | 0,134 | 0,0071 | 0,0532 | nao muda |
| ext | T4 eleitoral de 2018 so | 0,227 | 0,227 | 0,0126 | 0,0555 | muda mais de 25% |
| ext | Pulsos de 2017T1 a 2018T1 (imputacao) | 0,180 | 0,180 | 0,0103 | 0,0572 | nao muda |
| ext | DUM da dissertacao (2018T2-2019T1, 2019T3-2019T4) | 0,141 | 0,141 | 0,0083 | 0,0588 | nao muda |
| ext | Outliers do X-11 de inf_diss (ls2018T2, ao2018T3, ls2019T1, ls2019T3, ao2020T3, ao2021T1, ao2021T2) | 0,381 | 0,381 | 0,0211 | 0,0552 | muda mais de 25% |
| ext | Outliers do X-11 de 2018-2019 | 0,139 | 0,140 | 0,0098 | 0,0705 | nao muda |
| ext | Outliers do X-11 de 2020-2021 | 0,358 | 0,364 | 0,0172 | 0,0472 | muda mais de 25% |
| ext | Outliers do X-11 e pulsos em 2020T2 e 2020T3 | 0,343 | 0,344 | 0,0195 | 0,0568 | muda mais de 25% |
| ext | Imputacao de 2017 pela razao do trimestre | 0,152 | 0,152 | 0,0085 | 0,0560 | nao muda |
| ext | Imputacao de 2017 pelo Apendice A | 0,150 | 0,150 | 0,0084 | 0,0559 | nao muda |
| ext | Emenda da SEST em 2017T1 | 0,173 | 0,173 | 0,0102 | 0,0593 | nao muda |
| ext | Emenda da SEST em 2018T1 | 0,173 | 0,173 | 0,0102 | 0,0590 | nao muda |
| ext | Emenda da SEST em 2019T1 | 0,171 | 0,171 | 0,0101 | 0,0592 | nao muda |
| ext | Emenda em 2020T1, razao de 2019 | 0,154 | 0,154 | 0,0089 | 0,0579 | nao muda |
| ext | Emenda em 2020T1, razao de 2016-2018 | 0,154 | 0,154 | 0,0086 | 0,0558 | nao muda |
| ext | X-11 depois de somar | 0,154 | 0,154 | 0,0089 | 0,0578 | nao muda |
| ext | Sem o efeito dos AO do X-11 | 0,275 | 0,277 | 0,0126 | 0,0456 | muda mais de 25% |

| esquema | fim | el h=12 | el h=40 | resp. publ. | resp. priv. |
|---|---|---|---|---|---|
| Recursiva | 2013T4 | 0,141 | 0,143 | 0,0360 | 0,0051 |
| Recursiva | 2014T4 | 0,219 | 0,227 | 0,0490 | 0,0111 |
| Recursiva | 2015T4 | 0,491 | 0,547 | 0,0728 | 0,0398 |
| Recursiva | 2016T4 | 0,359 | 0,366 | 0,0525 | 0,0192 |
| Recursiva | 2017T4 | 0,391 | 0,398 | 0,0461 | 0,0183 |
| Recursiva | 2018T4 | 0,438 | 0,443 | 0,0750 | 0,0332 |
| Recursiva | 2019T4 | 0,412 | 0,451 | 0,0463 | 0,0209 |
| Recursiva | 2020T4 | 0,282 | 0,287 | 0,0475 | 0,0136 |
| Recursiva | 2021T4 | 0,154 | 0,154 | 0,0547 | 0,0084 |
| Recursiva | 2022T4 | 0,150 | 0,150 | 0,0530 | 0,0080 |
| Recursiva | 2023T4 | 0,134 | 0,134 | 0,0541 | 0,0073 |
| Recursiva | 2024T4 | 0,150 | 0,150 | 0,0569 | 0,0086 |
| Recursiva | 2025T4 | 0,154 | 0,154 | 0,0563 | 0,0087 |
| Janela movel (40) | 2013T4 | 0,141 | 0,143 | 0,0360 | 0,0051 |
| Janela movel (40) | 2014T4 | 0,127 | 0,129 | 0,0456 | 0,0059 |
| Janela movel (40) | 2015T4 | 0,254 | 0,259 | 0,0609 | 0,0158 |
| Janela movel (40) | 2016T4 | 0,315 | 0,314 | 0,0335 | 0,0105 |
| Janela movel (40) | 2017T4 | 0,691 | 0,691 | 0,0376 | 0,0260 |
| Janela movel (40) | 2018T4 | 0,507 | 0,513 | 0,1001 | 0,0514 |
| Janela movel (40) | 2019T4 | 0,442 | 0,562 | 0,0553 | 0,0311 |
| Janela movel (40) | 2020T4 | 0,253 | 0,235 | 0,0511 | 0,0120 |
| Janela movel (40) | 2021T4 | 0,129 | 0,128 | 0,0681 | 0,0087 |
| Janela movel (40) | 2022T4 | 0,107 | 0,107 | 0,0672 | 0,0072 |
| Janela movel (40) | 2023T4 | 0,065 | 0,064 | 0,0632 | 0,0041 |
| Janela movel (40) | 2024T4 | 0,040 | 0,039 | 0,0620 | 0,0024 |
| Janela movel (40) | 2025T4 | 0,049 | 0,048 | 0,0634 | 0,0031 |

| esquema | fim (choque) | LP h=8 | EP | n |
|---|---|---|---|---|
| Recursiva | 2013T4 | -0,128 | 0,318 | 40 |
| Recursiva | 2014T4 | 0,313 | 0,366 | 44 |
| Recursiva | 2015T4 | 0,256 | 0,345 | 48 |
| Recursiva | 2016T4 | 0,160 | 0,325 | 52 |
| Recursiva | 2017T4 | 0,190 | 0,276 | 56 |
| Recursiva | 2018T4 | -0,020 | 0,200 | 60 |
| Recursiva | 2019T4 | 0,018 | 0,163 | 64 |
| Recursiva | 2020T4 | -0,067 | 0,162 | 68 |
| Recursiva | 2021T4 | -0,115 | 0,146 | 72 |
| Recursiva | 2022T4 | -0,097 | 0,162 | 76 |
| Recursiva | 2023T4 | -0,086 | 0,163 | 80 |
| Janela movel (40) | 2013T4 | -0,128 | 0,318 | 40 |
| Janela movel (40) | 2014T4 | 0,346 | 0,371 | 40 |
| Janela movel (40) | 2015T4 | 0,127 | 0,507 | 40 |
| Janela movel (40) | 2016T4 | 0,316 | 0,484 | 40 |
| Janela movel (40) | 2017T4 | 0,435 | 0,551 | 40 |
| Janela movel (40) | 2018T4 | -0,072 | 0,172 | 40 |
| Janela movel (40) | 2019T4 | -0,286 | 0,099 | 40 |
| Janela movel (40) | 2020T4 | -0,349 | 0,091 | 40 |
| Janela movel (40) | 2021T4 | -0,326 | 0,068 | 40 |
| Janela movel (40) | 2022T4 | -0,309 | 0,100 | 40 |
| Janela movel (40) | 2023T4 | -0,223 | 0,150 | 40 |

## 7. Dummies para a A5

| nome | tipo | datas | series_ou_equacoes | uso |
|---|---|---|---|---|
| pulso_2020T2 | pulso | 2020T2 | VAR estendido e LP com amostra ate 2025 | baseline |
| pulso_2020T3 | pulso | 2020T3 | VAR estendido e LP com amostra ate 2025 | baseline |
| d_ls2018T2 | pulso | 2018T2 | VAR estendido e LP com inf_diss ou estatais_total | robustez |
| d_ao2018T3 | pulso (+1 e -1 no trimestre seguinte) | 2018T3 2018T4 | VAR estendido e LP com inf_diss ou estatais_total | robustez |
| d_ls2019T1 | pulso | 2019T1 | VAR estendido e LP com inf_diss ou estatais_total | robustez |
| d_ls2019T3 | pulso | 2019T3 | VAR estendido e LP com inf_diss ou estatais_total | robustez |
| d_ao2020T3 | pulso (+1 e -1 no trimestre seguinte) | 2020T3 2020T4 | VAR estendido e LP com inf_diss ou estatais | robustez |
| d_ao2021T1 | pulso (+1 e -1 no trimestre seguinte) | 2021T1 2021T2 | VAR estendido e LP com inf_diss ou estatais | robustez |
| d_ao2021T2 | pulso (+1 e -1 no trimestre seguinte) | 2021T2 2021T3 | VAR estendido e LP com inf_diss ou estatais | robustez |
| degrau_2011T1 | degrau | de 2011T1 em diante | uniao_econ_dt_g1 uniao_gnd4_dir uniao_soc_dir | robustez nas LP com choques da Uniao |

Justificativas em `data/processed/A4_dummies_quebra_metadados.csv`. As colunas de `A4_dummies_quebra.csv` sao regressores da equacao em diferenca e entram como estao, sem diferenciar de novo.

