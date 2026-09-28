# A3: reconstrucao de INF

Gerado por R/A3_investimento_publico.R em 2026-09-28 21:22.

INF da dissertacao: data/original/0224_tri_estmeq.txt, log10, 2002T1-2019T4. Reconstrucao: federal com o filtro da
dissertacao (modalidade 90 e 6 elementos; 2017 com total anual exato e perfil trimestral imputado) + boletim da SEST
(Brasil), X-11, indice e log10. Comparacao em 2003T2-2019T4 (67 diferencas trimestrais).

## Resultado

O INF da dissertacao e o investimento NOMINAL com ajuste sazonal X-11 multiplicativo. O nivel decide: o desvio padrao da diferenca de nivel contra INF (log10) e 0,0053 na serie nominal e cerca de 0,12 nas reais. A reconstrucao nominal (X-11 depois de somar, janela 2003T1-2019T4, imputacao baseline de 2017; serie inf_diss_nominal_2019) reproduz INF com correlacao das diferencas de 0,9975 e desvio medio em nivel de 0,0049 em log10 (1,1%). Com a imputacao de 2017 implicita no Apendice A a correlacao vai a 0,9984, mas essa imputacao usa o Ipub, a mesma fonte de INF, e e em parte circular em 2017: fica so como conferencia. O X-11 multiplicativo do Ipub nominal do Apendice A reproduz INF com correlacao das diferencas de 0,9993 em 2002T2-2019T4 e desvio padrao da diferenca de nivel de 0,0020 em log10: INF = log10(X-11 do Ipub nominal) + constante.

A serie real (inf_diss, pedida no briefing) e o ajuste indireto: soma de uniao_filtro_diss e estatais_total, cada uma com seu X-11 em 2003T1-2025T4. Correlacao das diferencas com INF: 0,9803; com X-11 depois de somar (inf_diss_x11soma, a definicao anterior), 0,9186. Em nivel a serie real se afasta de INF com a inflacao acumulada (desvio medio -0,188 em log10, maximo 0,403). Para replicar a dissertacao use inf_diss_nominal_2019 (2003-2019) e inf_diss_nominal (janela do X-11 ate 2025, correlacao 0,9764).

A correlacao das diferencas depende sobretudo dos outliers que o X-11 detecta em 2017-2019. Deteccao automatica, X-11 depois de somar, janela 2003T1-2019T4: nominal LS2018.2 AO2018.3 LS2019.1 LS2019.3 (correlacao 0,9975); real (IPCA medio) AO2017.3 LS2018.2 LS2019.1 AO2019.4 (0,7520). Fixando os outliers de uma serie na outra (regression.variables, outlier = NULL):

| deflator | outliers fixos (origem) | corr_dif |
|---|---|---|
| media_tri | LS2018.2 AO2018.3 LS2019.1 LS2019.3 (nominal) | 0,9976 |
| fim_tri | LS2018.2 AO2018.3 LS2019.1 LS2019.3 (nominal) | 0,9975 |
| anual | LS2018.2 AO2018.3 LS2019.1 LS2019.3 (nominal) | 0,9976 |
| nominal | LS2018.2 AO2018.3 LS2019.1 LS2019.3 (nominal) | 0,9975 |
| nominal | AO2017.3 LS2018.2 LS2019.1 AO2019.4 (real, IPCA medio) | 0,7535 |

Sem deteccao de outliers: nominal 0,8536, real 0,8492. A diferenca entre real e nominal na correlacao vem do conjunto de outliers, nao da deflacao.

## Comparacao das variantes

corr_dif: correlacao das diferencas do log10; dam_dif: desvio absoluto medio das diferencas; desvio_medio_nivel: media de
reconstruida menos INF, indices base media 2003 = 100, em log10; dp_nivel: desvio padrao de log10(reconstruida) - INF;
dam_dif_2017: desvio absoluto medio das diferencas de 2017T1 a 2018T1. Demais escolhas fixas em X-11 depois de somar, log,
janela 2003T1-2019T4 e imputacao baseline, salvo indicacao. Na coluna outliers_x11, ' ; ' separa as chamadas do X-11
(uma por componente quando ajuste = componentes).

| variante | deflator | ajuste | transformacao | janela_x11 | imputacao_2017 | corr_dif | dam_dif | desvio_medio_nivel | dp_nivel | dam_dif_2017 | outliers_x11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| destaque: nominal (inf_diss_nominal_2019) | nominal | soma | log | 2003T1-2019T4 | base | 0,9975 | 0,0029 | 0,0049 | 0,0053 | 0,0118 | LS2018.2 AO2018.3 LS2019.1 LS2019.3 |
| conferencia: nominal, imputacao Apendice A (circular em 2017) | nominal | soma | log | 2003T1-2019T4 | apendice | 0,9984 | 0,0026 | 0,0049 | 0,0051 | 0,0064 | LS2018.2 AO2018.3 LS2019.1 LS2019.3 |
| nominal, transformacao automatica | nominal | soma | auto | 2003T1-2019T4 | base | 0,9975 | 0,0029 | 0,0049 | 0,0053 | 0,0118 | LS2018.2 AO2018.3 LS2019.1 LS2019.3 |
| nominal, X-11 nos componentes | nominal | componentes | log | 2003T1-2019T4 | base | 0,9952 | 0,0049 | 0,0069 | 0,0069 | 0,0153 |  ; LS2018.2 AO2018.3 LS2019.1 LS2019.3 |
| nominal, janela ate 2025 (inf_diss_nominal) | nominal | soma | log | 2003T1-2025T4 | base | 0,9764 | 0,0073 | 0,0046 | 0,0106 | 0,0238 | AO2018.3 LS2019.1 AO2020.3 AO2021.2 |
| nominal, imputacao razao | nominal | soma | log | 2003T1-2019T4 | razao | 0,9974 | 0,0027 | 0,0049 | 0,0053 | 0,0133 | LS2018.2 AO2018.3 LS2019.1 LS2019.3 |
| real, IPCA medio | media_tri | soma | log | 2003T1-2019T4 | base | 0,7520 | 0,0237 | -0,1904 | 0,1210 | 0,0601 | AO2017.3 LS2018.2 LS2019.1 AO2019.4 |
| real, transformacao automatica | media_tri | soma | auto | 2003T1-2019T4 | base | 0,7520 | 0,0237 | -0,1904 | 0,1210 | 0,0601 | AO2017.3 LS2018.2 LS2019.1 AO2019.4 |
| real, X-11 nos componentes | media_tri | componentes | log | 2003T1-2019T4 | base | 0,9947 | 0,0078 | -0,1881 | 0,1162 | 0,0136 |  ; LS2018.2 AO2018.3 LS2019.1 LS2019.3 |
| real, X-11 nos componentes, janela ate 2025 (inf_diss) | media_tri | componentes | log | 2003T1-2025T4 | base | 0,9803 | 0,0105 | -0,1883 | 0,1167 | 0,0249 | AO2021.1 ; LS2018.2 AO2018.3 LS2019.1 LS2019.3 AO2020.3 AO2021.2 |
| real, X-11 depois de somar, janela ate 2025 (inf_diss_x11soma) | media_tri | soma | log | 2003T1-2025T4 | base | 0,9186 | 0,0158 | -0,1907 | 0,1187 | 0,0402 | LS2019.1 AO2020.3 AO2021.2 |
| real, IPCA do ultimo mes | fim_tri | soma | log | 2003T1-2019T4 | base | 0,7541 | 0,0236 | -0,1895 | 0,1209 | 0,0608 | AO2017.3 LS2018.2 LS2019.1 AO2019.4 |
| real, IPCA medio do ano | anual | soma | log | 2003T1-2019T4 | base | 0,7196 | 0,0256 | -0,1925 | 0,1220 | 0,0628 | AO2017.3 LS2018.2 LS2019.1 AO2019.4 |
| real, IPCA medio do ano, imputacao Apendice A | anual | soma | log | 2003T1-2019T4 | apendice | 0,9984 | 0,0066 | -0,1910 | 0,1172 | 0,0072 | LS2018.2 AO2018.3 LS2019.1 LS2019.3 |
| real, sem ajuste sazonal | media_tri | nenhum | - | 2003T1-2019T4 | base | 0,4893 | 0,1116 | -0,1912 | 0,1388 | 0,1384 |  |

Dez variantes com maior correlacao (tabela completa, 108 variantes, com os outliers do X-11, em results/A3_reconstrucao_INF_variantes.csv). As com imputacao Apendice A sao parcialmente circulares em 2017:

| deflator | ajuste | transformacao | janela_x11 | imputacao_2017 | corr_dif | dam_dif | desvio_medio_nivel | dam_dif_2017 |
|---|---|---|---|---|---|---|---|---|
| nominal | soma | log | 2003T1-2019T4 | apendice | 0,9984 | 0,0026 | 0,0049 | 0,0064 |
| nominal | soma | auto | 2003T1-2019T4 | apendice | 0,9984 | 0,0026 | 0,0049 | 0,0064 |
| anual | soma | log | 2003T1-2019T4 | apendice | 0,9984 | 0,0066 | -0,1910 | 0,0072 |
| anual | soma | auto | 2003T1-2019T4 | apendice | 0,9984 | 0,0066 | -0,1910 | 0,0072 |
| nominal | soma | log | 2003T1-2019T4 | base | 0,9975 | 0,0029 | 0,0049 | 0,0118 |
| nominal | soma | auto | 2003T1-2019T4 | base | 0,9975 | 0,0029 | 0,0049 | 0,0118 |
| nominal | soma | log | 2003T1-2019T4 | razao | 0,9974 | 0,0027 | 0,0049 | 0,0133 |
| nominal | soma | auto | 2003T1-2019T4 | razao | 0,9974 | 0,0027 | 0,0049 | 0,0133 |
| nominal | componentes | log | 2003T1-2019T4 | apendice | 0,9962 | 0,0044 | 0,0070 | 0,0100 |
| nominal | componentes | auto | 2003T1-2019T4 | apendice | 0,9962 | 0,0044 | 0,0070 | 0,0100 |

Deflatores: media_tri = IPCA medio do trimestre; fim_tri = IPCA do ultimo mes do trimestre; anual = IPCA medio do ano;
nominal = sem deflacao. Ajuste: soma = X-11 depois de somar; componentes = X-11 em cada componente e soma; nenhum = sem X-11.
Transformacao: log = X-11 multiplicativo imposto; auto = escolha do X-13 por AIC.

## 2017

Perfil trimestral imputado (participacao no total anual de R$ 16,196 bi): baseline 15,1%, 22,8%, 21,3%, 40,7%; razao 15,0%, 24,9%, 22,0%, 38,2%; implicito no Apendice A 16,0%, 21,7%, 24,1%, 38,2%. O Apendice A tem o Ipub nominal de 2017 observado na epoca; com a razao (filtro + SEST)/Ipub interpolada entre 2016T4 e 2018T1, a soma implicita de 2017 e R$ 16,199 bi, contra R$ 16,196 bi exatos.

Figura: results/figuras/A3_INF_reconstruida.png.
