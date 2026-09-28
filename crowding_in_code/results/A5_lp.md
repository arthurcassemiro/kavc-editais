# A5: projecoes locais, elasticidades e multiplicadores

Gerado por R/A5_lp.R em 2026-09-28 23:21. Numeros com virgula decimal. IC de 90% pontuais (estimativa +- 1,645 EP), sem correcao para testes multiplos. Newey-West sem ajuste de graus de liberdade: com n/(n - k) o EP cresce 9% a 27% (mediana 9%) nas medidas acumuladas do baseline, e os IC deste relatorio ficam um pouco estreitos; os CSV trazem a versao ajustada (ep_aj, ic90_inf_aj, ic90_sup_aj com t de n - k graus, p_valor_aj).

## Especificacao

- Baseline (Jorda, 2005): y(t+h) - y(t-1) = a + b t + beta_h dx(t) + soma_{l=1..p} [phi_l dx(t-l) + psi_l dy(t-l)] + g' z(t) + d' D(t) + u, h = 0 a 12, p = 3, amostra 2003T1-2025T4 (primeiro t = 2004T1). x = log10 do indice com ajuste (A3), y = log10 da variavel privada (A2). z = pib_acel e diff(selic_fim). D = pulsos de 2020T2 e 2020T3 (A4). Sem dy(t): o choque vem antes da resposta. Newey-West com lag h + 1.
- Series de 2016+ (estatais_petro, estatais_sempetro, estatais_econ): 2016T1-2025T4, p = 2, h ate 8, baixo poder (29 a 37 observacoes).
- Elasticidade acumulada (Ramey e Zubairy, 2018): MQ2E de soma_{j=0..h} [y(t+j) - y(t-1)] em soma_{j=0..h} [x(t+j) - x(t-1)], instrumento dx(t), mesmos controles. F1 = F de Newey-West do instrumento no primeiro estagio.
- Multiplicador acumulado em R$: MQ2E de soma_{j=0..h} [Y(t+j) - Y(t-1)] / PIB(t-1) em soma_{j=0..h} [G(t+j) - G(t-1)] / PIB(t-1), instrumento dG(t) / PIB(t-1); controles: p defasagens de dG/PIB e dY/PIB, z, D, constante e tendencia. Y = FBCF das Contas Nacionais (R$ bi de 2025, precos da FBCF), BNDES exceto administracao publica ou importacao de BK (R$ bi de 2025 pelo IPCA); G = nivel do choque em R$ bi de 2025 pelo IPCA (A3_niveis_wide.csv).
- M_h - 1 so para a FBCF: parte de G nao e FBCF (sentencas, indenizacoes, despesas de exercicios anteriores, servicos de terceiros no GND 4) e a FBCF das Contas Nacionais inclui estados, municipios e as proprias estatais; M_h - 1 nao e o efeito sobre a FBCF privada, e sim sobre a FBCF que nao e o proprio G, sob a hipotese de que todo G entra na FBCF.
- Conversao de fbcf_me em R$: nao feita. O SIDRA nao tem tabela anual de FBCF por tipo de ativo (a unica tabela das Contas Nacionais Anuais na API de agregados do IBGE e a 6784, PIB, PIB per capita, populacao e deflator; consulta de 2026-09-28).

## Leitura curta

- inf_diss -> fbcf_me, elasticidade acumulada: h = 4 0,086 [-0,076; 0,248]; h = 8 0,075 [-0,087; 0,237]; h = 12 0,099 [-0,038; 0,236]. IRF em h = 0: 0,032 [-0,101; 0,164].
- Elasticidade de fbcf_me em h = 12: uniao_econ_dir 0,176 [-0,043; 0,395]; uniao_soc_dir 0,162 [0,012; 0,312]; uniao_econ_dt_g1 0,191 [-0,027; 0,410]; uniao_soc_dt_g1 0,159 [-0,060; 0,377]; uniao_transf_soc_g1 0,088 [-0,083; 0,258]; estatais_total 0,027 [-0,089; 0,144]; uniao_gnd4_dir 0,276 [0,102; 0,450].
- Multiplicador acumulado da FBCF (R$) em h = 12, so nos agregados: inf_diss 1,83 [0,36; 3,30]; estatais_total 1,83 [0,08; 3,58]; uniao_gnd4_dir 6,64 [0,15; 13,12]. Nas rubricas (Uniao por tipo e modalidade, estatais por segmento), os M_h de regressoes separadas nao sao lidos em R$: a razao FBCF / G vai de 24 a 406, e o M_h separado cai quando o outro componente entra como controle (uniao_soc_dir em h = 12: 49,50 [30,50; 68,50] na separada, 13,64 [-24,59; 51,86] na conjunta com uniao_econ_dir); isso indica comovimento com a FBCF agregada, nao efeito causal. Nas rubricas valem as comparacoes conjuntas abaixo, de preferencia em elasticidade.
- Uniao economica x social (direta), regressao conjunta. Elasticidade da FBCF (fbcf_cnt_vol): h = 4: 0,018 x 0,089, p de Wald 0,338 (amostra pequena 0,396); h = 8: 0,036 x 0,079, p de Wald 0,664 (amostra pequena 0,701); h = 12: 0,075 x 0,037, p de Wald 0,792 (amostra pequena 0,817). M_h da FBCF em R$: h = 4: 6,35 x 24,31, p de Wald 0,348 (amostra pequena 0,404); h = 8: 9,93 x 22,45, p de Wald 0,610 (amostra pequena 0,652); h = 12: 16,38 x 13,64, p de Wald 0,928 (amostra pequena 0,936).
- Uniao economica x social (direta + transferencia), regressao conjunta. Elasticidade da FBCF (fbcf_cnt_vol): h = 4: 0,051 x -0,000, p de Wald 0,456 (amostra pequena 0,508); h = 8: 0,054 x 0,024, p de Wald 0,690 (amostra pequena 0,725); h = 12: 0,085 x 0,013, p de Wald 0,452 (amostra pequena 0,511). M_h da FBCF em R$: h = 4: 7,84 x 2,18, p de Wald 0,233 (amostra pequena 0,290); h = 8: 9,35 x 4,68, p de Wald 0,493 (amostra pequena 0,545); h = 12: 14,08 x 3,73, p de Wald 0,307 (amostra pequena 0,372).
- Social: direta x transferencia, regressao conjunta. Elasticidade da FBCF (fbcf_cnt_vol): h = 4: 0,129 x 0,001, p de Wald 0,005 (amostra pequena 0,014); h = 8: 0,144 x 0,022, p de Wald 0,032 (amostra pequena 0,061); h = 12: 0,146 x 0,023, p de Wald 0,044 (amostra pequena 0,082). M_h da FBCF em R$: h = 4: 42,61 x 1,39, p de Wald < 0,001 (amostra pequena < 0,001); h = 8: 53,01 x 3,95, p de Wald < 0,001 (amostra pequena < 0,001); h = 12: 53,76 x 2,73, p de Wald < 0,001 (amostra pequena < 0,001).
- Estatais sem petroleo x petroleo (2016-2025), regressao conjunta. Elasticidade da FBCF (fbcf_cnt_vol): h = 4: 0,189 x -0,044, p de Wald < 0,001 (amostra pequena 0,017); h = 8: 0,202 x -0,066, p de Wald < 0,001 (amostra pequena 0,016). M_h da FBCF em R$: h = 4: 29,69 x -0,79, p de Wald 0,015 (amostra pequena 0,080); h = 8: 31,91 x -1,38, p de Wald 0,004 (amostra pequena 0,055). Serie de 2016+ com poucas observacoes (baixo poder): com a correcao de amostra pequena (Newey-West vezes n/(n - k) e F(1, n - k)) o resultado e so sugestivo.
- Estatais x Uniao direta (GND 4), regressao conjunta. Elasticidade da FBCF (fbcf_cnt_vol): h = 4: -0,022 x 0,119, p de Wald 0,096 (amostra pequena 0,141); h = 8: -0,030 x 0,166, p de Wald 0,064 (amostra pequena 0,105); h = 12: 0,001 x 0,181, p de Wald 0,079 (amostra pequena 0,127). M_h da FBCF em R$: h = 4: 0,06 x 4,12, p de Wald 0,170 (amostra pequena 0,225); h = 8: -0,10 x 6,11, p de Wald 0,144 (amostra pequena 0,199); h = 12: 0,38 x 6,52, p de Wald 0,236 (amostra pequena 0,301).
- Razao media FBCF / G na janela de cada choque (M_h e aproximadamente a elasticidade da FBCF vezes essa razao): inf_diss 14; uniao_filtro_diss 62; uniao_gnd4_dir 46; uniao_econ_dir 127; uniao_soc_dir 290; uniao_econ_dt_g1 116; uniao_soc_dt_g1 88; uniao_transf_soc_g1 125; estatais_total 17; estatais_petro 24; estatais_sempetro 165; estatais_econ 406.
- Erros de Newey-West sem ajuste de graus de liberdade e IC pela normal no baseline (como no sandwich com adjust = FALSE). Com o ajuste n/(n - k) o EP cresce 9% a 27% (mediana 9%) nas medidas acumuladas do baseline em diferenca; as colunas ep_aj, ic90_inf_aj, ic90_sup_aj (t com n - k graus de liberdade) e p_valor_aj dos CSV trazem essa versao. Elasticidade de inf_diss em fbcf_me em h = 12 com o ajuste: 0,099 [-0,054; 0,252].
- IRF do baseline em diferenca (h = 1 a 12, 12 choques x 8 respostas): IC de 90% exclui zero em 329 de 1056 coeficientes (31,2%; sem efeito algum, cerca de 10% excluiriam zero por acaso, e os coeficientes de horizontes vizinhos sao correlacionados). Elasticidades acumuladas (h = 4, 8, 12): 104 de 264 excluem zero (99 positivas).

## 1. IRF de fbcf_me (beta_h, log10 de fbcf_me para 1 log10 do choque) [IC 90%]

| choque | h = 0 | h = 4 | h = 8 | h = 12 | n_h0 |
|---|---|---|---|---|---|
| inf_diss | 0,032 [-0,101; 0,164] | 0,175 [0,054; 0,296] | -0,153 [-0,382; 0,076] | 0,057 [-0,070; 0,185] | 88 |
| uniao_filtro_diss | 0,027 [-0,079; 0,132] | 0,238 [0,076; 0,400] | 0,149 [-0,043; 0,341] | 0,180 [0,008; 0,352] | 88 |
| uniao_gnd4_dir | 0,038 [-0,075; 0,151] | 0,273 [0,098; 0,448] | 0,186 [-0,014; 0,385] | 0,166 [-0,028; 0,359] | 88 |
| uniao_econ_dir | 0,001 [-0,057; 0,059] | 0,088 [-0,014; 0,189] | 0,071 [-0,025; 0,166] | 0,090 [-0,041; 0,221] | 88 |
| uniao_soc_dir | -0,048 [-0,151; 0,055] | 0,212 [0,080; 0,343] | 0,108 [-0,076; 0,293] | 0,158 [-0,009; 0,326] | 88 |
| uniao_econ_dt_g1 | 0,008 [-0,057; 0,073] | 0,091 [-0,016; 0,198] | 0,085 [-0,015; 0,185] | 0,120 [-0,032; 0,273] | 88 |
| uniao_soc_dt_g1 | -0,010 [-0,066; 0,047] | 0,074 [-0,026; 0,174] | 0,058 [-0,068; 0,184] | 0,087 [-0,041; 0,216] | 88 |
| uniao_transf_soc_g1 | -0,008 [-0,047; 0,032] | 0,037 [-0,034; 0,108] | 0,028 [-0,062; 0,118] | 0,047 [-0,039; 0,133] | 88 |
| estatais_total | 0,020 [-0,095; 0,135] | 0,114 [0,024; 0,203] | -0,183 [-0,343; -0,023] | 0,005 [-0,107; 0,116] | 88 |
| estatais_petro | 0,013 [-0,072; 0,098] | 0,103 [0,049; 0,157] | -0,225 [-0,368; -0,082] |  | 37 |
| estatais_sempetro | 0,062 [-0,082; 0,205] | 0,095 [-0,069; 0,260] | -0,053 [-0,193; 0,087] |  | 37 |
| estatais_econ | -0,030 [-0,118; 0,058] | 0,066 [-0,042; 0,173] | -0,117 [-0,242; 0,007] |  | 37 |

## 2. Elasticidade acumulada de fbcf_me [IC 90%] (p-valor; F do primeiro estagio)

| choque | h = 4 | h = 8 | h = 12 |
|---|---|---|---|
| inf_diss | 0,086 [-0,076; 0,248] (p 0,383; F1 34,6) | 0,075 [-0,087; 0,237] (p 0,446; F1 21,3) | 0,099 [-0,038; 0,236] (p 0,235; F1 18,9) |
| uniao_filtro_diss | 0,182 [0,044; 0,319] (p 0,029; F1 61,9) | 0,208 [0,048; 0,368] (p 0,032; F1 46,0) | 0,232 [0,077; 0,387] (p 0,014; F1 37,2) |
| uniao_gnd4_dir | 0,198 [0,042; 0,354] (p 0,037; F1 59,6) | 0,238 [0,055; 0,421] (p 0,033; F1 48,4) | 0,276 [0,102; 0,450] (p 0,009; F1 33,8) |
| uniao_econ_dir | 0,093 [-0,046; 0,233] (p 0,271; F1 24,8) | 0,119 [-0,043; 0,281] (p 0,226; F1 25,5) | 0,176 [-0,043; 0,395] (p 0,185; F1 20,3) |
| uniao_soc_dir | 0,152 [0,021; 0,282] (p 0,056; F1 83,1) | 0,168 [0,015; 0,320] (p 0,070; F1 43,2) | 0,162 [0,012; 0,312] (p 0,075; F1 28,1) |
| uniao_econ_dt_g1 | 0,102 [-0,049; 0,253] (p 0,268; F1 28,7) | 0,125 [-0,043; 0,294] (p 0,221; F1 29,3) | 0,191 [-0,027; 0,410] (p 0,149; F1 21,8) |
| uniao_soc_dt_g1 | 0,110 [-0,036; 0,256] (p 0,215; F1 100,8) | 0,148 [-0,024; 0,320] (p 0,157; F1 58,7) | 0,159 [-0,060; 0,377] (p 0,233; F1 76,5) |
| uniao_transf_soc_g1 | 0,054 [-0,054; 0,161] (p 0,411; F1 96,1) | 0,084 [-0,041; 0,210] (p 0,270; F1 72,1) | 0,088 [-0,083; 0,258] (p 0,399; F1 88,2) |
| estatais_total | 0,040 [-0,098; 0,178] (p 0,634; F1 30,4) | 0,019 [-0,113; 0,150] (p 0,814; F1 22,7) | 0,027 [-0,089; 0,144] (p 0,697; F1 24,5) |
| estatais_petro | 0,013 [-0,090; 0,116] (p 0,834; F1 106,5) | -0,039 [-0,105; 0,026] (p 0,322; F1 142,4) |  |
| estatais_sempetro | 0,139 [-0,086; 0,363] (p 0,309; F1 135,7) | 0,149 [-0,022; 0,319] (p 0,151; F1 119,2) |  |
| estatais_econ | 0,047 [-0,060; 0,155] (p 0,469; F1 28,5) | -0,035 [-0,150; 0,080] (p 0,616; F1 32,1) |  |

## 3. Elasticidade acumulada em h = 12 (h = 8 nas series de 2016+), todas as respostas: estimativa (EP); * = IC de 90% exclui zero

| choque | h | fbcf_me | fbcf_constr | fbcf_total | fbcf_outros | pim_bk | imp_bk_quantum | bndes_priv | fbcf_cnt_vol |
|---|---|---|---|---|---|---|---|---|---|
| inf_diss | 12 | 0,099 (0,083) | 0,087 (0,064) | 0,063 (0,083) | -0,044 (0,082) | 0,008 (0,084) | 0,254 (0,143)* | 0,645 (0,206)* | 0,063 (0,083) |
| uniao_filtro_diss | 12 | 0,232 (0,094)* | 0,046 (0,034) | 0,119 (0,071)* | 0,038 (0,034) | 0,178 (0,085)* | 0,444 (0,108)* | 0,523 (0,309)* | 0,120 (0,071)* |
| uniao_gnd4_dir | 12 | 0,276 (0,106)* | 0,068 (0,044) | 0,157 (0,083)* | 0,063 (0,041) | 0,257 (0,088)* | 0,477 (0,121)* | 0,611 (0,321)* | 0,157 (0,083)* |
| uniao_econ_dir | 12 | 0,176 (0,133) | 0,016 (0,044) | 0,085 (0,069) | 0,036 (0,039) | 0,161 (0,097)* | 0,386 (0,136)* | 0,202 (0,298) | 0,085 (0,069) |
| uniao_soc_dir | 12 | 0,162 (0,091)* | 0,115 (0,052)* | 0,133 (0,063)* | 0,004 (0,069) | 0,194 (0,061)* | 0,374 (0,095)* | 0,812 (0,226)* | 0,132 (0,064)* |
| uniao_econ_dt_g1 | 12 | 0,191 (0,133) | 0,022 (0,041) | 0,085 (0,070) | 0,047 (0,037) | 0,172 (0,091)* | 0,415 (0,139)* | 0,258 (0,297) | 0,085 (0,070) |
| uniao_soc_dt_g1 | 12 | 0,159 (0,133) | 0,061 (0,063) | 0,057 (0,080) | 0,021 (0,034) | 0,154 (0,110) | 0,205 (0,156) | 0,597 (0,234)* | 0,058 (0,080) |
| uniao_transf_soc_g1 | 12 | 0,088 (0,104) | 0,032 (0,059) | 0,022 (0,055) | -0,009 (0,029) | 0,099 (0,088) | 0,084 (0,120) | 0,374 (0,195)* | 0,023 (0,055) |
| estatais_total | 12 | 0,027 (0,071) | 0,078 (0,062) | 0,033 (0,068) | -0,054 (0,076) | -0,031 (0,071) | 0,129 (0,142) | 0,529 (0,179)* | 0,033 (0,069) |
| estatais_petro | 8 | -0,039 (0,040) | -0,005 (0,027) | -0,033 (0,025) | -0,102 (0,036)* | -0,100 (0,039)* | 0,061 (0,109) | 0,206 (0,063)* | -0,033 (0,025) |
| estatais_sempetro | 8 | 0,149 (0,104) | 0,060 (0,071) | 0,095 (0,044)* | 0,033 (0,105) | 0,018 (0,167) | 0,553 (0,315)* | -0,109 (0,192) | 0,095 (0,043)* |
| estatais_econ | 8 | -0,035 (0,070) | 0,068 (0,024)* | 0,040 (0,015)* | 0,019 (0,051) | 0,090 (0,052)* | 0,146 (0,159) | -0,219 (0,095)* | 0,040 (0,015)* |

## 4. Multiplicadores acumulados em R$ (estimativas separadas)

| choque | h | M_h FBCF [IC 90%] | p (M = 0) | M_h - 1 | p (M = 1) | F1 | M_h BNDES | M_h import. BK | FBCF / G medio | n |
|---|---|---|---|---|---|---|---|---|---|---|
| inf_diss | 4 | 0,89 [-0,34; 2,12] | 0,234 | -0,11 | 0,885 | 25,0 | 0,98 [0,62; 1,34] | 0,32 [0,08; 0,56] | 14 | 84 |
| inf_diss | 8 | 1,40 [0,05; 2,75] | 0,087 | 0,40 | 0,622 | 16,2 | 1,05 [0,63; 1,46] | 0,31 [0,08; 0,54] | 14 | 80 |
| inf_diss | 12 | 1,83 [0,36; 3,30] | 0,040 | 0,83 | 0,352 | 13,8 | 1,05 [0,62; 1,49] | 0,37 [0,12; 0,62] | 14 | 76 |
| uniao_filtro_diss | 4 | 4,71 [0,58; 8,84] | 0,061 | 3,71 | 0,139 | 61,3 | 3,11 [1,78; 4,44] | 0,01 [-0,44; 0,45] | 62 | 84 |
| uniao_filtro_diss | 8 | 6,20 [0,51; 11,90] | 0,073 | 5,20 | 0,133 | 28,3 | 2,83 [1,33; 4,33] | 0,28 [-0,36; 0,92] | 62 | 80 |
| uniao_filtro_diss | 12 | 7,35 [-0,42; 15,12] | 0,120 | 6,35 | 0,179 | 24,1 | 3,01 [1,25; 4,77] | 0,55 [-0,38; 1,49] | 62 | 76 |
| uniao_gnd4_dir | 4 | 4,59 [1,49; 7,68] | 0,015 | 3,59 | 0,057 | 48,3 | 2,27 [1,19; 3,34] | 0,03 [-0,39; 0,44] | 46 | 84 |
| uniao_gnd4_dir | 8 | 5,96 [1,52; 10,40] | 0,027 | 4,96 | 0,066 | 31,7 | 2,22 [1,03; 3,42] | 0,28 [-0,16; 0,72] | 46 | 80 |
| uniao_gnd4_dir | 12 | 6,64 [0,15; 13,12] | 0,092 | 5,64 | 0,153 | 31,8 | 2,19 [0,65; 3,74] | 0,50 [-0,06; 1,07] | 46 | 76 |
| uniao_econ_dir | 4 | 9,90 [3,91; 15,89] | 0,007 | 8,90 | 0,014 | 27,7 | 2,32 [-0,67; 5,30] | -0,07 [-1,08; 0,95] | 127 | 84 |
| uniao_econ_dir | 8 | 13,26 [4,16; 22,36] | 0,016 | 12,26 | 0,027 | 24,0 | 1,33 [-2,34; 4,99] | 0,66 [-0,45; 1,76] | 127 | 80 |
| uniao_econ_dir | 12 | 18,14 [4,57; 31,72] | 0,028 | 17,14 | 0,038 | 19,3 | 1,31 [-3,46; 6,08] | 1,23 [-0,28; 2,73] | 127 | 76 |
| uniao_soc_dir | 4 | 39,87 [24,15; 55,59] | < 0,001 | 38,87 | < 0,001 | 50,2 | 24,80 [18,79; 30,82] | 1,12 [-2,34; 4,58] | 290 | 84 |
| uniao_soc_dir | 8 | 47,87 [29,98; 65,76] | < 0,001 | 46,87 | < 0,001 | 41,1 | 23,43 [15,63; 31,22] | 3,24 [0,18; 6,31] | 290 | 80 |
| uniao_soc_dir | 12 | 49,50 [30,50; 68,50] | < 0,001 | 48,50 | < 0,001 | 24,8 | 24,33 [15,35; 33,30] | 4,27 [1,57; 6,97] | 290 | 76 |
| uniao_econ_dt_g1 | 4 | 8,69 [3,04; 14,34] | 0,011 | 7,69 | 0,025 | 27,9 | 2,32 [-0,85; 5,49] | 0,09 [-0,89; 1,07] | 116 | 84 |
| uniao_econ_dt_g1 | 8 | 11,60 [3,41; 19,79] | 0,020 | 10,60 | 0,033 | 22,2 | 1,65 [-1,75; 5,04] | 0,65 [-0,35; 1,66] | 116 | 80 |
| uniao_econ_dt_g1 | 12 | 16,40 [5,17; 27,64] | 0,016 | 15,40 | 0,024 | 15,5 | 2,19 [-1,50; 5,89] | 1,18 [-0,13; 2,49] | 116 | 76 |
| uniao_soc_dt_g1 | 4 | 5,06 [-1,48; 11,60] | 0,203 | 4,06 | 0,307 | 151,1 | 4,25 [1,82; 6,68] | 1,11 [0,14; 2,09] | 88 | 84 |
| uniao_soc_dt_g1 | 8 | 9,24 [1,45; 17,04] | 0,051 | 8,24 | 0,082 | 71,2 | 5,27 [2,57; 7,97] | 1,32 [0,53; 2,12] | 88 | 80 |
| uniao_soc_dt_g1 | 12 | 9,13 [-0,37; 18,63] | 0,114 | 8,13 | 0,159 | 107,2 | 5,86 [3,72; 7,99] | 1,23 [0,27; 2,19] | 88 | 76 |
| uniao_transf_soc_g1 | 4 | 2,66 [-4,35; 9,67] | 0,532 | 1,66 | 0,697 | 135,2 | 3,00 [0,85; 5,15] | 1,13 [0,05; 2,21] | 125 | 84 |
| uniao_transf_soc_g1 | 8 | 6,42 [-2,68; 15,52] | 0,246 | 5,42 | 0,327 | 88,3 | 4,22 [1,50; 6,93] | 1,19 [0,24; 2,13] | 125 | 80 |
| uniao_transf_soc_g1 | 12 | 6,13 [-5,77; 18,03] | 0,397 | 5,13 | 0,478 | 159,9 | 5,04 [2,27; 7,81] | 1,08 [-0,11; 2,26] | 125 | 76 |
| estatais_total | 4 | 0,81 [-0,69; 2,31] | 0,375 | -0,19 | 0,836 | 21,7 | 1,08 [0,62; 1,54] | 0,43 [0,16; 0,71] | 17 | 84 |
| estatais_total | 8 | 1,38 [-0,28; 3,04] | 0,172 | 0,38 | 0,708 | 15,3 | 1,22 [0,65; 1,79] | 0,40 [0,13; 0,67] | 17 | 80 |
| estatais_total | 12 | 1,83 [0,08; 3,58] | 0,085 | 0,83 | 0,434 | 14,4 | 1,23 [0,62; 1,84] | 0,46 [0,18; 0,75] | 17 | 76 |
| estatais_petro | 4 | -0,24 [-1,44; 0,96] | 0,741 | -1,24 | 0,088 | 73,2 | 0,33 [0,18; 0,47] | 0,51 [0,13; 0,88] | 24 | 33 |
| estatais_petro | 8 | -0,51 [-1,70; 0,67] | 0,476 | -1,51 | 0,036 | 84,0 | 0,26 [0,17; 0,35] | 0,47 [0,13; 0,80] | 24 | 29 |
| estatais_sempetro | 4 | 14,35 [1,78; 26,93] | 0,060 | 13,35 | 0,081 | 77,2 | -0,27 [-2,97; 2,44] | 3,97 [-3,66; 11,60] | 165 | 33 |
| estatais_sempetro | 8 | 12,66 [2,74; 22,58] | 0,036 | 11,66 | 0,053 | 60,3 | -0,14 [-2,96; 2,67] | 5,31 [-3,90; 14,53] | 165 | 29 |
| estatais_econ | 4 | 17,21 [2,53; 31,89] | 0,054 | 16,21 | 0,069 | 95,2 | -1,49 [-7,07; 4,09] | 6,58 [-2,28; 15,43] | 406 | 33 |
| estatais_econ | 8 | 17,69 [3,54; 31,84] | 0,040 | 16,69 | 0,052 | 58,7 | -1,39 [-7,45; 4,66] | 7,01 [-4,74; 18,76] | 406 | 29 |

## 5. Comparacoes: regressao conjunta com os dois choques, Wald da igualdade

Colunas a e b vem da regressao conjunta (dois endogenos, dois instrumentos, defasagens de ambos e da resposta); 'separadas' repete as estimativas de uma regressao por choque. F1 = F de Newey-West dos dois instrumentos no primeiro estagio de cada endogeno. p Wald: qui-quadrado com 1 grau e Newey-West sem ajuste; p Wald amostra pequena: Newey-West vezes n/(n - k) e F(1, n - k), com k = numero de regressores. Nas rubricas, a leitura em R$ nao e crivel (M_h separado muito acima do conjunto; FBCF / G de dezenas a centenas): use a elasticidade conjunta (5b) e os M_h conjuntos, nao os separados.

### 5a. Multiplicador acumulado da FBCF, BNDES e importacao de BK em R$ (M_a x M_b)

| rotulo | resposta | h | a [IC 90%] | b [IC 90%] | a - b (EP) | p Wald | p Wald amostra pequena | F1 a / b | separadas: a / b | n | baixo poder |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Uniao economica x social (direta) | fbcf_real_rs_bi | 4 | 6,35 [0,12; 12,58] | 24,31 [-2,39; 51,01] | -17,96 (19,12) | 0,348 | 0,404 | 18,5 / 31,5 | 9,90 / 39,87 | 84 |  |
| Uniao economica x social (direta) | fbcf_real_rs_bi | 8 | 9,93 [0,78; 19,08] | 22,45 [-11,38; 56,29] | -12,52 (24,55) | 0,610 | 0,652 | 12,3 / 23,4 | 13,26 / 47,87 | 80 |  |
| Uniao economica x social (direta) | fbcf_real_rs_bi | 12 | 16,38 [1,45; 31,31] | 13,64 [-24,59; 51,86] | 2,74 (30,17) | 0,928 | 0,936 | 8,4 / 14,5 | 18,14 / 49,50 | 76 |  |
| Uniao economica x social (direta) | bndes_priv | 4 | -1,87 [-4,81; 1,07] | 30,48 [21,17; 39,80] | -32,36 (7,08) | < 0,001 | < 0,001 | 16,8 / 43,5 | 2,32 / 24,80 | 84 |  |
| Uniao economica x social (direta) | bndes_priv | 8 | -3,20 [-7,01; 0,61] | 32,31 [22,14; 42,49] | -35,51 (8,00) | < 0,001 | < 0,001 | 12,9 / 19,4 | 1,33 / 23,43 | 80 |  |
| Uniao economica x social (direta) | bndes_priv | 12 | -4,72 [-10,76; 1,32] | 35,16 [23,85; 46,48] | -39,88 (9,93) | < 0,001 | < 0,001 | 13,1 / 13,4 | 1,31 / 24,33 | 76 |  |
| Uniao economica x social (direta) | imp_bk_real | 4 | -0,50 [-1,86; 0,86] | 1,62 [-3,68; 6,92] | -2,12 (3,87) | 0,584 | 0,626 | 19,5 / 68,8 | -0,07 / 1,12 | 84 |  |
| Uniao economica x social (direta) | imp_bk_real | 8 | -0,11 [-1,46; 1,24] | 2,84 [-1,94; 7,62] | -2,95 (3,53) | 0,404 | 0,462 | 14,4 / 27,1 | 0,66 / 3,24 | 80 |  |
| Uniao economica x social (direta) | imp_bk_real | 12 | 0,23 [-1,62; 2,08] | 3,57 [-0,73; 7,86] | -3,34 (3,46) | 0,335 | 0,399 | 12,1 / 14,9 | 1,23 / 4,27 | 76 |  |
| Uniao economica x social (direta + transferencia) | fbcf_real_rs_bi | 4 | 7,84 [3,03; 12,65] | 2,18 [-3,51; 7,87] | 5,66 (4,75) | 0,233 | 0,290 | 13,9 / 73,0 | 8,69 / 5,06 | 84 |  |
| Uniao economica x social (direta + transferencia) | fbcf_real_rs_bi | 8 | 9,35 [2,33; 16,36] | 4,68 [-2,27; 11,63] | 4,67 (6,81) | 0,493 | 0,545 | 10,1 / 50,0 | 11,60 / 9,24 | 80 |  |
| Uniao economica x social (direta + transferencia) | fbcf_real_rs_bi | 12 | 14,08 [3,20; 24,96] | 3,73 [-5,41; 12,86] | 10,35 (10,13) | 0,307 | 0,372 | 8,5 / 54,3 | 16,40 / 9,13 | 76 |  |
| Uniao economica x social (direta + transferencia) | bndes_priv | 4 | 1,16 [-1,72; 4,04] | 4,15 [1,94; 6,37] | -2,99 (2,31) | 0,194 | 0,250 | 16,3 / 57,3 | 2,32 / 4,25 | 84 |  |
| Uniao economica x social (direta + transferencia) | bndes_priv | 8 | -0,21 [-2,74; 2,31] | 5,76 [2,73; 8,79] | -5,97 (2,72) | 0,028 | 0,056 | 11,2 / 68,0 | 1,65 / 5,27 | 80 |  |
| Uniao economica x social (direta + transferencia) | bndes_priv | 12 | -0,52 [-3,98; 2,94] | 6,39 [3,48; 9,31] | -6,92 (3,49) | 0,048 | 0,086 | 10,0 / 46,8 | 2,19 / 5,86 | 76 |  |
| Uniao economica x social (direta + transferencia) | imp_bk_real | 4 | -0,22 [-1,01; 0,56] | 1,10 [0,10; 2,09] | -1,32 (0,85) | 0,121 | 0,170 | 18,0 / 82,1 | 0,09 / 1,11 | 84 |  |
| Uniao economica x social (direta + transferencia) | imp_bk_real | 8 | 0,24 [-0,54; 1,01] | 1,11 [0,14; 2,07] | -0,87 (0,92) | 0,343 | 0,403 | 15,0 / 71,0 | 0,65 / 1,32 | 80 |  |
| Uniao economica x social (direta + transferencia) | imp_bk_real | 12 | 0,71 [-0,26; 1,69] | 0,95 [0,01; 1,89] | -0,24 (0,99) | 0,810 | 0,833 | 16,0 / 45,6 | 1,18 / 1,23 | 76 |  |
| Social: direta x transferencia | fbcf_real_rs_bi | 4 | 42,61 [27,56; 57,67] | 1,39 [-3,59; 6,38] | 41,22 (9,09) | < 0,001 | < 0,001 | 24,6 / 49,6 | 39,87 / 2,66 | 84 |  |
| Social: direta x transferencia | fbcf_real_rs_bi | 8 | 53,01 [35,79; 70,24] | 3,95 [-1,38; 9,29] | 49,06 (10,41) | < 0,001 | < 0,001 | 19,6 / 59,4 | 47,87 / 6,42 | 80 |  |
| Social: direta x transferencia | fbcf_real_rs_bi | 12 | 53,76 [34,77; 72,75] | 2,73 [-5,26; 10,71] | 51,03 (12,70) | < 0,001 | < 0,001 | 14,2 / 81,2 | 49,50 / 6,13 | 76 |  |
| Social: direta x transferencia | bndes_priv | 4 | 22,96 [17,09; 28,82] | 1,53 [-0,43; 3,48] | 21,43 (4,16) | < 0,001 | < 0,001 | 26,2 / 48,7 | 24,80 / 3,00 | 84 |  |
| Social: direta x transferencia | bndes_priv | 8 | 21,67 [14,64; 28,69] | 2,35 [-0,13; 4,84] | 19,31 (5,14) | < 0,001 | 0,001 | 17,4 / 60,7 | 23,43 / 4,22 | 80 |  |
| Social: direta x transferencia | bndes_priv | 12 | 21,40 [12,61; 30,19] | 2,63 [-0,31; 5,56] | 18,77 (6,77) | 0,006 | 0,018 | 15,4 / 58,2 | 24,33 / 5,04 | 76 |  |
| Social: direta x transferencia | imp_bk_real | 4 | -0,28 [-3,60; 3,04] | 1,38 [0,21; 2,56] | -1,66 (2,49) | 0,505 | 0,554 | 31,7 / 60,3 | 1,12 / 1,13 | 84 |  |
| Social: direta x transferencia | imp_bk_real | 8 | 2,86 [-0,01; 5,72] | 1,08 [0,03; 2,14] | 1,77 (2,22) | 0,424 | 0,480 | 21,1 / 68,9 | 3,24 / 1,19 | 80 |  |
| Social: direta x transferencia | imp_bk_real | 12 | 3,50 [0,38; 6,62] | 0,83 [-0,55; 2,20] | 2,67 (2,55) | 0,295 | 0,360 | 14,7 / 57,9 | 4,27 / 1,08 | 76 |  |
| Estatais sem petroleo x petroleo (2016-2025) | fbcf_real_rs_bi | 4 | 29,69 [9,33; 50,06] | -0,79 [-1,32; -0,26] | 30,48 (12,52) | 0,015 | 0,080 | 68,2 / 69,5 | 14,35 / -0,24 | 33 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | fbcf_real_rs_bi | 8 | 31,91 [12,93; 50,90] | -1,38 [-1,90; -0,87] | 33,29 (11,49) | 0,004 | 0,055 | 73,5 / 86,0 | 12,66 / -0,51 | 29 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | bndes_priv | 4 | -1,35 [-3,40; 0,69] | 0,34 [0,23; 0,45] | -1,70 (1,26) | 0,178 | 0,320 | 43,1 / 90,1 | -0,27 / 0,33 | 33 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | bndes_priv | 8 | -2,44 [-5,89; 1,02] | 0,34 [0,25; 0,43] | -2,78 (2,13) | 0,193 | 0,364 | 9,4 / 121,0 | -0,14 / 0,26 | 29 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | imp_bk_real | 4 | 5,68 [0,15; 11,21] | 0,39 [0,22; 0,57] | 5,28 (3,35) | 0,115 | 0,246 | 68,7 / 60,8 | 3,97 / 0,51 | 33 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | imp_bk_real | 8 | 7,91 [1,43; 14,39] | 0,25 [0,10; 0,39] | 7,66 (3,93) | 0,051 | 0,182 | 55,8 / 134,1 | 5,31 / 0,47 | 29 | sim |
| Estatais x Uniao direta (GND 4) | fbcf_real_rs_bi | 4 | 0,06 [-1,52; 1,64] | 4,12 [0,31; 7,92] | -4,05 (2,96) | 0,170 | 0,225 | 15,4 / 33,3 | 0,81 / 4,59 | 84 |  |
| Estatais x Uniao direta (GND 4) | fbcf_real_rs_bi | 8 | -0,10 [-2,00; 1,80] | 6,11 [0,67; 11,54] | -6,21 (4,24) | 0,144 | 0,199 | 7,8 / 29,1 | 1,38 / 5,96 | 80 |  |
| Estatais x Uniao direta (GND 4) | fbcf_real_rs_bi | 12 | 0,38 [-1,59; 2,36] | 6,52 [-0,41; 13,46] | -6,14 (5,18) | 0,236 | 0,301 | 7,7 / 19,6 | 1,83 / 6,64 | 76 |  |
| Estatais x Uniao direta (GND 4) | bndes_priv | 4 | 0,87 [0,47; 1,28] | 1,21 [0,30; 2,11] | -0,34 (0,67) | 0,619 | 0,659 | 12,7 / 26,7 | 1,08 / 2,27 | 84 |  |
| Estatais x Uniao direta (GND 4) | bndes_priv | 8 | 1,01 [0,42; 1,60] | 0,98 [-0,05; 2,02] | 0,03 (0,90) | 0,972 | 0,975 | 6,6 / 22,6 | 1,22 / 2,22 | 80 |  |
| Estatais x Uniao direta (GND 4) | bndes_priv | 12 | 1,06 [0,39; 1,72] | 0,81 [-0,56; 2,17] | 0,25 (1,14) | 0,827 | 0,848 | 5,9 / 14,3 | 1,23 / 2,19 | 76 |  |
| Estatais x Uniao direta (GND 4) | imp_bk_real | 4 | 0,55 [0,28; 0,82] | -0,60 [-0,96; -0,24] | 1,15 (0,32) | < 0,001 | 0,002 | 14,1 / 35,4 | 0,43 / 0,03 | 84 |  |
| Estatais x Uniao direta (GND 4) | imp_bk_real | 8 | 0,44 [0,15; 0,74] | -0,21 [-0,54; 0,12] | 0,66 (0,34) | 0,052 | 0,089 | 6,6 / 31,7 | 0,40 / 0,28 | 80 |  |
| Estatais x Uniao direta (GND 4) | imp_bk_real | 12 | 0,48 [0,15; 0,82] | -0,09 [-0,43; 0,26] | 0,57 (0,38) | 0,139 | 0,197 | 6,0 / 17,7 | 0,46 / 0,50 | 76 |  |

### 5b. Elasticidade acumulada conjunta (fbcf_cnt_vol, FBCF das Contas Nacionais em volume, e fbcf_me)

| rotulo | resposta | h | a [IC 90%] | b [IC 90%] | a - b (EP) | p Wald | p Wald amostra pequena | F1 a / b | separadas: a / b | n | baixo poder |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Uniao economica x social (direta) | fbcf_cnt_vol | 4 | 0,018 [-0,032; 0,068] | 0,089 [-0,006; 0,185] | -0,071 (0,075) | 0,338 | 0,396 | 14,1 / 36,6 | 0,049 / 0,116 | 84 |  |
| Uniao economica x social (direta) | fbcf_cnt_vol | 8 | 0,036 [-0,035; 0,107] | 0,079 [-0,043; 0,202] | -0,043 (0,100) | 0,664 | 0,701 | 12,4 / 22,2 | 0,065 / 0,130 | 80 |  |
| Uniao economica x social (direta) | fbcf_cnt_vol | 12 | 0,075 [-0,051; 0,202] | 0,037 [-0,104; 0,177] | 0,038 (0,146) | 0,792 | 0,817 | 10,8 / 15,2 | 0,085 / 0,132 | 76 |  |
| Uniao economica x social (direta) | fbcf_me | 4 | 0,062 [-0,066; 0,189] | 0,083 [-0,063; 0,228] | -0,021 (0,139) | 0,880 | 0,893 | 13,9 / 46,2 | 0,093 / 0,152 | 84 |  |
| Uniao economica x social (direta) | fbcf_me | 8 | 0,096 [-0,062; 0,255] | 0,052 [-0,124; 0,227] | 0,045 (0,174) | 0,797 | 0,820 | 13,1 / 19,8 | 0,119 / 0,168 | 80 |  |
| Uniao economica x social (direta) | fbcf_me | 12 | 0,208 [-0,085; 0,501] | -0,067 [-0,311; 0,177] | 0,275 (0,311) | 0,377 | 0,439 | 11,8 / 13,6 | 0,176 / 0,162 | 76 |  |
| Uniao economica x social (direta + transferencia) | fbcf_cnt_vol | 4 | 0,051 [-0,011; 0,112] | -0,000 [-0,076; 0,075] | 0,051 (0,068) | 0,456 | 0,508 | 14,9 / 66,8 | 0,046 / 0,030 | 84 |  |
| Uniao economica x social (direta + transferencia) | fbcf_cnt_vol | 8 | 0,054 [-0,015; 0,123] | 0,024 [-0,069; 0,117] | 0,030 (0,076) | 0,690 | 0,725 | 11,8 / 49,9 | 0,062 / 0,063 | 80 |  |
| Uniao economica x social (direta + transferencia) | fbcf_cnt_vol | 12 | 0,085 [-0,010; 0,180] | 0,013 [-0,109; 0,135] | 0,072 (0,096) | 0,452 | 0,511 | 8,8 / 40,0 | 0,085 / 0,058 | 76 |  |
| Uniao economica x social (direta + transferencia) | fbcf_me | 4 | 0,090 [-0,040; 0,221] | 0,055 [-0,077; 0,186] | 0,036 (0,108) | 0,740 | 0,768 | 15,2 / 56,6 | 0,102 / 0,110 | 84 |  |
| Uniao economica x social (direta + transferencia) | fbcf_me | 8 | 0,096 [-0,037; 0,228] | 0,078 [-0,078; 0,233] | 0,018 (0,110) | 0,870 | 0,885 | 12,6 / 48,2 | 0,125 / 0,148 | 80 |  |
| Uniao economica x social (direta + transferencia) | fbcf_me | 12 | 0,160 [-0,012; 0,332] | 0,076 [-0,123; 0,274] | 0,084 (0,145) | 0,560 | 0,609 | 9,5 / 37,6 | 0,191 / 0,159 | 76 |  |
| Social: direta x transferencia | fbcf_cnt_vol | 4 | 0,129 [0,056; 0,202] | 0,001 [-0,040; 0,043] | 0,128 (0,045) | 0,005 | 0,014 | 42,7 / 39,8 | 0,116 / 0,007 | 84 |  |
| Social: direta x transferencia | fbcf_cnt_vol | 8 | 0,144 [0,046; 0,242] | 0,022 [-0,017; 0,062] | 0,122 (0,057) | 0,032 | 0,061 | 28,4 / 32,8 | 0,130 / 0,031 | 80 |  |
| Social: direta x transferencia | fbcf_cnt_vol | 12 | 0,146 [0,047; 0,246] | 0,023 [-0,039; 0,085] | 0,124 (0,061) | 0,044 | 0,082 | 15,9 / 42,6 | 0,132 / 0,023 | 76 |  |
| Social: direta x transferencia | fbcf_me | 4 | 0,144 [0,020; 0,268] | 0,052 [-0,041; 0,146] | 0,092 (0,094) | 0,332 | 0,390 | 42,4 / 44,9 | 0,152 / 0,054 | 84 |  |
| Social: direta x transferencia | fbcf_me | 8 | 0,170 [0,032; 0,309] | 0,069 [-0,023; 0,161] | 0,101 (0,089) | 0,254 | 0,315 | 26,3 / 36,6 | 0,168 / 0,084 | 80 |  |
| Social: direta x transferencia | fbcf_me | 12 | 0,156 [0,029; 0,283] | 0,082 [-0,041; 0,206] | 0,074 (0,086) | 0,392 | 0,454 | 15,3 / 57,2 | 0,162 / 0,088 | 76 |  |
| Estatais sem petroleo x petroleo (2016-2025) | fbcf_cnt_vol | 4 | 0,189 [0,087; 0,291] | -0,044 [-0,069; -0,019] | 0,233 (0,067) | < 0,001 | 0,017 | 59,2 / 68,5 | 0,105 / -0,025 | 33 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | fbcf_cnt_vol | 8 | 0,202 [0,082; 0,321] | -0,066 [-0,083; -0,049] | 0,268 (0,071) | < 0,001 | 0,016 | 50,8 / 75,9 | 0,095 / -0,033 | 29 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | fbcf_me | 4 | 0,163 [-0,135; 0,461] | -0,014 [-0,102; 0,073] | 0,177 (0,202) | 0,381 | 0,514 | 66,5 / 80,3 | 0,139 / 0,013 | 33 | sim |
| Estatais sem petroleo x petroleo (2016-2025) | fbcf_me | 8 | 0,211 [-0,057; 0,480] | -0,111 [-0,166; -0,056] | 0,322 (0,163) | 0,048 | 0,176 | 119,7 / 142,8 | 0,149 / -0,039 | 29 | sim |
| Estatais x Uniao direta (GND 4) | fbcf_cnt_vol | 4 | -0,022 [-0,102; 0,059] | 0,119 [0,027; 0,210] | -0,140 (0,084) | 0,096 | 0,141 | 22,2 / 27,0 | 0,010 / 0,104 | 84 |  |
| Estatais x Uniao direta (GND 4) | fbcf_cnt_vol | 8 | -0,030 [-0,114; 0,054] | 0,166 [0,049; 0,283] | -0,196 (0,106) | 0,064 | 0,105 | 13,9 / 20,9 | 0,025 / 0,134 | 80 |  |
| Estatais x Uniao direta (GND 4) | fbcf_cnt_vol | 12 | 0,001 [-0,090; 0,093] | 0,181 [0,063; 0,299] | -0,179 (0,102) | 0,079 | 0,127 | 15,3 / 15,4 | 0,033 / 0,157 | 76 |  |
| Estatais x Uniao direta (GND 4) | fbcf_me | 4 | -0,036 [-0,172; 0,100] | 0,187 [-0,011; 0,385] | -0,223 (0,171) | 0,192 | 0,248 | 19,6 / 28,8 | 0,040 / 0,198 | 84 |  |
| Estatais x Uniao direta (GND 4) | fbcf_me | 8 | -0,108 [-0,252; 0,035] | 0,291 [0,031; 0,552] | -0,400 (0,227) | 0,078 | 0,123 | 12,0 / 24,1 | 0,019 / 0,238 | 80 |  |
| Estatais x Uniao direta (GND 4) | fbcf_me | 12 | -0,063 [-0,214; 0,087] | 0,308 [0,062; 0,554] | -0,371 (0,218) | 0,089 | 0,139 | 12,7 / 16,4 | 0,027 / 0,276 | 76 |  |

## 6. LP em nivel com defasagens aumentadas (Montiel Olea e Plagborg-Moller, 2021): elasticidade acumulada [IC 90%]

y(t+h) em x(t) em log10, com p + 1 defasagens de x e y, mesmas exogenas e dummies, erros HC1. Elasticidade = MQ2E de soma y(t+j) em soma x(t+j), instrumento x(t). Comparada com a LP em diferenca no mesmo horizonte.

| choque | h | fbcf_me dif. | fbcf_me nivel aum. | fbcf_cnt_vol dif. | fbcf_cnt_vol nivel aum. |
|---|---|---|---|---|---|
| inf_diss | 12 | 0,099 [-0,038; 0,236] | 0,429 [0,182; 0,677] | 0,063 [-0,073; 0,199] | 0,194 [-0,031; 0,418] |
| uniao_filtro_diss | 12 | 0,232 [0,077; 0,387] | 0,465 [0,208; 0,721] | 0,120 [0,004; 0,236] | 0,242 [-0,030; 0,515] |
| uniao_gnd4_dir | 12 | 0,276 [0,102; 0,450] | 0,420 [0,052; 0,788] | 0,157 [0,021; 0,293] | 0,211 [-0,120; 0,541] |
| uniao_econ_dir | 12 | 0,176 [-0,043; 0,395] | 0,302 [0,035; 0,569] | 0,085 [-0,028; 0,198] | 0,126 [-0,077; 0,328] |
| uniao_soc_dir | 12 | 0,162 [0,012; 0,312] | 0,380 [0,139; 0,621] | 0,132 [0,027; 0,237] | 0,249 [0,049; 0,450] |
| uniao_econ_dt_g1 | 12 | 0,191 [-0,027; 0,410] | 0,320 [0,072; 0,568] | 0,085 [-0,030; 0,200] | 0,125 [-0,075; 0,324] |
| uniao_soc_dt_g1 | 12 | 0,159 [-0,060; 0,377] | 0,404 [0,161; 0,647] | 0,058 [-0,074; 0,190] | 0,129 [-0,100; 0,359] |
| uniao_transf_soc_g1 | 12 | 0,088 [-0,083; 0,258] | 0,351 [0,049; 0,653] | 0,023 [-0,067; 0,113] | 0,099 [-0,132; 0,330] |
| estatais_total | 12 | 0,027 [-0,089; 0,144] | 0,317 [-0,142; 0,776] | 0,033 [-0,079; 0,146] | 0,173 [-0,084; 0,430] |
| estatais_petro | 8 | -0,039 [-0,105; 0,026] | -0,046 [-0,225; 0,132] | -0,033 [-0,074; 0,009] | -0,061 [-0,099; -0,022] |
| estatais_sempetro | 8 | 0,149 [-0,022; 0,319] | -0,224 [-0,594; 0,145] | 0,095 [0,025; 0,166] | 0,015 [-0,115; 0,145] |
| estatais_econ | 8 | -0,035 [-0,150; 0,080] | 0,066 [-0,204; 0,336] | 0,040 [0,015; 0,064] | 0,084 [0,002; 0,166] |

## 7. Robustez

Resumo por choque (elasticidade de fbcf_me e multiplicador da FBCF em R$, h = 12, todas as especificacoes, inclusive o baseline):

| choque | n_esp | elasticidade h = 12: min / mediana / max | IC exclui zero | M_12 FBCF: min / mediana / max | IC de M exclui zero |
|---|---|---|---|---|---|
| inf_diss | 24 | -0,151 / 0,142 / 0,239 | 13 de 24 | -0,15 / 2,29 / 3,10 | 22 de 25 |
| estatais_total | 24 | -0,314 / 0,080 / 0,185 | 11 de 24 | -1,24 / 2,58 / 3,68 | 20 de 25 |
| uniao_econ_dir | 24 | 0,036 / 0,153 / 0,442 | 4 de 24 | 6,68 / 16,78 / 26,45 | 15 de 25 |
| uniao_soc_dir | 24 | 0,001 / 0,152 / 0,510 | 10 de 24 | 25,06 / 47,91 / 57,49 | 22 de 25 |
| uniao_econ_dt_g1 | 25 | -0,046 / 0,162 / 0,448 | 5 de 25 | 2,53 / 14,54 / 26,42 | 19 de 26 |
| uniao_soc_dt_g1 | 25 | -0,001 / 0,115 / 0,226 | 0 de 25 | 3,61 / 7,54 / 16,23 | 4 de 26 |
| uniao_transf_soc_g1 | 25 | -0,047 / 0,056 / 0,150 | 0 de 25 | 1,11 / 4,00 / 14,88 | 2 de 26 |

Elasticidade acumulada de fbcf_me em h = 12: estimativa (EP); * = IC de 90% exclui zero.

| especificacao | inf_diss | estatais_total | uniao_econ_dir | uniao_soc_dir | uniao_econ_dt_g1 | uniao_soc_dt_g1 | uniao_transf_soc_g1 |
|---|---|---|---|---|---|---|---|
| baseline | 0,099 (0,083) | 0,027 (0,071) | 0,176 (0,133) | 0,162 (0,091)* | 0,191 (0,133) | 0,159 (0,133) | 0,088 (0,104) |
| pib_cresc | 0,122 (0,053)* | 0,087 (0,051)* | 0,116 (0,104) | 0,156 (0,087)* | 0,115 (0,107) | 0,071 (0,114) | 0,030 (0,082) |
| ordem_invertida_dy_t | 0,063 (0,078) | 0,005 (0,066) | 0,165 (0,079)* | 0,232 (0,084)* | 0,169 (0,079)* | 0,169 (0,105) | 0,096 (0,083) |
| p2 | 0,096 (0,080) | 0,028 (0,063) | 0,130 (0,116) | 0,147 (0,098) | 0,140 (0,116) | 0,143 (0,139) | 0,081 (0,104) |
| p4 | 0,128 (0,095) | 0,025 (0,112) | 0,197 (0,112)* | 0,226 (0,067)* | 0,210 (0,105)* | 0,226 (0,142) | 0,150 (0,131) |
| exogenas_so_defasadas | 0,203 (0,046)* | 0,136 (0,041)* | 0,157 (0,098) | 0,177 (0,099)* | 0,162 (0,100) | 0,120 (0,115) | 0,058 (0,088) |
| selic_media | 0,126 (0,077) | 0,056 (0,065) | 0,177 (0,112) | 0,142 (0,100) | 0,181 (0,114) | 0,113 (0,126) | 0,054 (0,098) |
| sub_ate_2014T4 | 0,108 (0,125) | 0,041 (0,128) | 0,036 (0,139) | 0,001 (0,354) | -0,046 (0,170) | -0,001 (0,084) | -0,047 (0,059) |
| sub_de_2015T1 | 0,010 (0,140) | -0,024 (0,123) | 0,442 (0,290) | 0,510 (0,059)* | 0,448 (0,303) | 0,159 (0,207) | 0,056 (0,171) |
| ate_2019T4 | -0,151 (0,344) | -0,314 (0,505) | 0,071 (0,200) | 0,046 (0,342) | 0,075 (0,235) | 0,156 (0,178) | 0,057 (0,102) |
| sem_2020_2021 | -0,151 (0,344) | -0,314 (0,505) | 0,071 (0,200) | 0,046 (0,342) | 0,075 (0,235) | 0,156 (0,178) | 0,057 (0,102) |
| sem_2016T4_2018T1 | -0,045 (0,110) | -0,101 (0,079) | 0,119 (0,082) | 0,074 (0,139) | 0,128 (0,087) | 0,081 (0,101) | 0,024 (0,071) |
| choques_sem_AO | 0,227 (0,071)* | 0,148 (0,067)* | 0,253 (0,089)* | 0,162 (0,091)* | 0,265 (0,090)* | 0,176 (0,141) | 0,054 (0,093) |
| transferencia_grupos_1e2 |  |  |  |  | 0,196 (0,135) | 0,159 (0,133) | 0,088 (0,104) |
| dummies_A4 | 0,239 (0,079)* | 0,185 (0,075)* | 0,069 (0,158) | 0,049 (0,099) | 0,080 (0,171) | 0,118 (0,128) | 0,079 (0,092) |
| ctrl_cambio_real | 0,170 (0,084)* | 0,128 (0,076)* | 0,109 (0,139) | 0,103 (0,085) | 0,129 (0,133) | 0,115 (0,106) | 0,061 (0,082) |
| ctrl_icbr_usd | 0,165 (0,070)* | 0,102 (0,061)* | 0,149 (0,126) | 0,172 (0,097)* | 0,156 (0,126) | 0,083 (0,137) | 0,020 (0,102) |
| ctrl_brent_usd | 0,156 (0,064)* | 0,080 (0,053) | 0,173 (0,128) | 0,162 (0,094)* | 0,178 (0,127) | 0,076 (0,117) | 0,015 (0,081) |
| ctrl_bndes_priv | 0,100 (0,081) | 0,029 (0,067) | 0,186 (0,117) | 0,155 (0,096) | 0,201 (0,118)* | 0,154 (0,133) | 0,084 (0,103) |
| ctrl_cambio_real+icbr_usd | 0,187 (0,073)* | 0,140 (0,067)* | 0,112 (0,139) | 0,115 (0,088) | 0,125 (0,133) | 0,092 (0,114) | 0,037 (0,089) |
| ctrl_cambio_real+brent_usd | 0,183 (0,066)* | 0,128 (0,060)* | 0,137 (0,145) | 0,119 (0,090) | 0,146 (0,138) | 0,073 (0,106) | 0,021 (0,078) |
| ctrl_cambio_real+bndes_priv | 0,170 (0,083)* | 0,127 (0,075)* | 0,120 (0,122) | 0,091 (0,083) | 0,140 (0,116) | 0,112 (0,107) | 0,060 (0,082) |
| ctrl_icbr_usd+brent_usd | 0,171 (0,065)* | 0,100 (0,055)* | 0,165 (0,128) | 0,166 (0,094)* | 0,171 (0,128) | 0,063 (0,125) | 0,003 (0,088) |
| ctrl_icbr_usd+bndes_priv | 0,167 (0,067)* | 0,104 (0,059)* | 0,163 (0,109) | 0,162 (0,099) | 0,170 (0,110) | 0,072 (0,134) | 0,014 (0,099) |
| ctrl_brent_usd+bndes_priv | 0,157 (0,063)* | 0,081 (0,051) | 0,187 (0,111)* | 0,150 (0,097) | 0,192 (0,110)* | 0,066 (0,116) | 0,010 (0,080) |

Multiplicador acumulado da FBCF em R$ em h = 12: estimativa (EP); * = IC de 90% exclui zero.

| especificacao | inf_diss | estatais_total | uniao_econ_dir | uniao_soc_dir | uniao_econ_dt_g1 | uniao_soc_dt_g1 | uniao_transf_soc_g1 |
|---|---|---|---|---|---|---|---|
| baseline | 1,83 (0,89)* | 1,83 (1,06)* | 18,14 (8,25)* | 49,50 (11,55)* | 16,40 (6,83)* | 9,13 (5,77) | 6,13 (7,23) |
| pib_cresc | 1,94 (0,80)* | 2,21 (0,95)* | 12,53 (8,19) | 46,13 (10,15)* | 11,15 (6,45)* | 5,15 (5,84) | 2,12 (7,52) |
| ordem_invertida_dy_t | 1,09 (0,89) | 1,01 (1,05) | 9,57 (7,24) | 42,08 (13,94)* | 9,07 (5,52) | 4,53 (6,99) | 2,22 (8,42) |
| p2 | 1,83 (1,01)* | 1,68 (1,24) | 15,85 (6,49)* | 52,19 (10,99)* | 14,60 (5,40)* | 10,33 (5,07)* | 6,29 (6,13) |
| p4 | 2,40 (0,72)* | 2,73 (0,96)* | 18,08 (7,33)* | 57,49 (9,29)* | 15,72 (6,31)* | 16,23 (5,73)* | 13,60 (8,51) |
| exogenas_so_defasadas | 2,56 (0,59)* | 2,71 (0,75)* | 12,54 (8,23) | 45,88 (12,24)* | 12,61 (6,76)* | 7,98 (5,89) | 5,17 (6,75) |
| selic_media | 1,90 (0,81)* | 1,93 (0,96)* | 16,01 (7,63)* | 45,49 (11,84)* | 14,48 (6,22)* | 6,90 (6,44) | 3,83 (7,99) |
| sub_ate_2014T4 | 1,65 (0,46)* | 1,13 (0,72) | 22,27 (2,48)* | 50,39 (14,85)* | 19,79 (1,79)* | 7,09 (4,44) | 1,11 (4,87) |
| sub_de_2015T1 | 0,36 (1,04) | 0,27 (1,23) | 26,45 (16,86) | 51,10 (9,28)* | 26,42 (16,41) | 15,31 (10,31) | 14,88 (12,45) |
| ate_2019T4 | 2,32 (0,77)* | 2,64 (0,96)* | 16,78 (12,12) | 55,07 (22,21)* | 14,35 (10,86) | 8,98 (8,88) | 2,40 (10,15) |
| sem_2020_2021 | 2,32 (0,77)* | 2,64 (0,96)* | 16,78 (12,12) | 55,07 (22,21)* | 14,35 (10,86) | 8,98 (8,88) | 2,40 (10,15) |
| sem_2016T4_2018T1 | -0,15 (1,82) | -1,24 (2,38) | 17,27 (6,29)* | 28,95 (30,51) | 17,11 (4,32)* | 9,46 (3,73)* | 7,28 (4,41)* |
| choques_sem_AO | 3,08 (0,53)* | 3,54 (0,79)* | 18,42 (8,02)* | 49,50 (11,55)* | 17,20 (7,24)* | 10,90 (6,95) | 4,19 (8,09) |
| transferencia_grupos_1e2 |  |  |  |  | 17,51 (6,46)* | 9,14 (5,78) | 6,13 (7,25) |
| dummies_A4 | 3,10 (0,57)* | 3,68 (0,84)* | 6,68 (15,72) | 25,06 (19,99) | 2,53 (16,77) | 8,21 (4,20)* | 7,51 (4,43)* |
| G_deflator_fbcf | 1,86 (0,88)* | 1,85 (1,05)* | 16,91 (7,54)* | 47,12 (10,39)* | 14,93 (6,19)* | 8,75 (5,60) | 5,56 (6,82) |
| ctrl_cambio_real | 2,29 (0,77)* | 2,78 (0,91)* | 12,62 (8,81) | 34,38 (17,10)* | 11,69 (7,31) | 6,45 (5,42) | 4,47 (6,13) |
| ctrl_icbr_usd | 2,38 (0,77)* | 2,64 (0,95)* | 14,45 (8,70)* | 52,62 (10,10)* | 12,66 (7,19)* | 5,58 (5,28) | 2,55 (6,01) |
| ctrl_brent_usd | 2,11 (0,81)* | 2,14 (1,01)* | 19,38 (8,09)* | 47,91 (9,98)* | 17,00 (6,83)* | 4,39 (6,17) | 1,64 (6,96) |
| ctrl_bndes_priv | 1,83 (0,88)* | 1,81 (1,04)* | 18,48 (7,94)* | 47,94 (13,23)* | 16,80 (6,53)* | 8,48 (5,82) | 5,59 (7,16) |
| ctrl_cambio_real+icbr_usd | 2,47 (0,71)* | 2,95 (0,86)* | 12,07 (8,94) | 43,58 (14,44)* | 10,86 (7,45) | 5,33 (5,23) | 3,22 (5,68) |
| ctrl_cambio_real+brent_usd | 2,32 (0,72)* | 2,73 (0,90)* | 15,74 (9,30)* | 38,84 (14,81)* | 14,12 (7,71)* | 4,45 (5,68) | 2,56 (6,04) |
| ctrl_cambio_real+bndes_priv | 2,29 (0,77)* | 2,77 (0,92)* | 13,07 (8,40) | 30,01 (19,44) | 12,19 (6,89)* | 6,02 (5,59) | 4,16 (6,20) |
| ctrl_icbr_usd+brent_usd | 2,36 (0,78)* | 2,58 (0,98)* | 17,10 (8,51)* | 50,67 (9,64)* | 15,01 (7,08)* | 4,02 (5,75) | 1,17 (6,33) |
| ctrl_icbr_usd+bndes_priv | 2,38 (0,76)* | 2,63 (0,93)* | 15,05 (8,45)* | 50,63 (11,29)* | 13,32 (6,89)* | 4,66 (5,30) | 1,92 (6,04) |
| ctrl_brent_usd+bndes_priv | 2,11 (0,80)* | 2,12 (0,98)* | 19,88 (7,73)* | 44,63 (12,07)* | 17,55 (6,44)* | 3,61 (6,33) | 1,17 (6,99) |

Especificacoes: pib_cresc (PIB em crescimento em vez de aceleracao); ordem_invertida_dy_t (inclui dy(t); em h = 0 a IRF e zero por construcao); p2 e p4; exogenas_so_defasadas (z(t-1) a z(t-p) em vez de z(t)); selic_media; sub_ate_2014T4 (dados ate 2014T4, t + h <= 2014T4) e sub_de_2015T1 (t >= 2015T1, defasagens de 2014), com o corte da A4; ate_2019T4; sem_2020_2021 e sem_2016T4_2018T1 (uma dummy por observacao cujo intervalo de datas usado, t - p - 1 a t + h, toca a janela); choques_sem_AO (A3_choques_semao_wide.csv e niveis sem AO); transferencia_grupos_1e2 (colunas sem _g1); dummies_A4 (inf_diss e estatais_total: outliers do X-11 de 2018-2021; Uniao: degrau de 2011T1); G_deflator_fbcf (so multiplicador: G reexpresso a precos de 2025 da FBCF); ctrl_* (controles adicionais em diff do log10, contemporaneos, um ou dois por vez).

## Figuras

- results/figuras/A5_lp_irf_comparacoes.png e .pdf: IRF de fbcf_me aos dois choques de cada comparacao, IC 90%.
- results/figuras/A5_lp_mult_comparacoes.png e .pdf: multiplicador acumulado da FBCF em R$, h = 0 ao horizonte maximo, IC 90%.

## Arquivos

- data/processed/A5_lp_irf.csv: IRF (variavel = resposta ou proprio_choque; modelo = diferenca ou nivel_defasagens_aumentadas).
- data/processed/A5_lp_cumulativo.csv: elasticidades (diferenca e nivel) e multiplicadores em h = 4, 8, 12, baseline e robustez.
- data/processed/A5_lp_comparacoes.csv: pares, h, multiplicadores conjuntos e separados, diferenca e p-valor de Wald.
