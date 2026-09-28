# A2: base trimestral consolidada

Gerado por `R/A2_download.R` em 2026-09-28 22:05 (modo sem download). Base: `data/processed/A2_series_trimestrais.csv`, 2002Q1 a 2025Q4, 96 trimestres, coluna `trimestre` no formato 2003Q1. Metadados: `data/processed/A2_metadados.csv`. Figura: `results/figuras/A2_series.png` e `.pdf`.

Toda variavel de nivel tem tambem a versao `_l10` (log10). Nao ha interpolacao: lacunas ficam vazias. `pvd_diss_l10` e a coluna PVD de `data/original/0224_tri_estmeq.txt` sem alteracao (2002Q1 a 2019Q4).

## Variaveis

| variavel | descricao | fonte | unidade | periodo | ajuste sazonal | _l10 |
|---|---|---|---|---|---|---|
| `fbcf_me` | Indicador Ipea de FBCF: consumo aparente de maquinas e equipamentos, com ajuste sazonal | Ipea/Carta de Conjuntura | indice, media de 1995 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | dessazonalizada pelo Ipea (publicada) | sim |
| `fbcf_constr` | Indicador Ipea de FBCF: construcao civil, com ajuste sazonal | Ipea/Carta de Conjuntura | indice, media de 1995 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | dessazonalizada pelo Ipea (publicada) | sim |
| `fbcf_outros` | Indicador Ipea de FBCF: consumo aparente de outros ativos, com ajuste sazonal | Ipea/Carta de Conjuntura | indice, media de 1995 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | dessazonalizada pelo Ipea (publicada) | sim |
| `fbcf_total` | Indicador Ipea de FBCF total, com ajuste sazonal | Ipea/Carta de Conjuntura | indice, media de 1995 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | dessazonalizada pelo Ipea (publicada) | sim |
| `ca_bk_sa` | Consumo aparente de bens de capital (Ipea), dessazonalizado | Ipeadata | indice, media de 2012 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | dessazonalizada na fonte (Ipeadata) | sim |
| `pim_bk` | PIM-PF, producao fisica de bens de capital, com ajuste sazonal (proxy da producao nacional de M&E) | IBGE/SIDRA | indice, 2022 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | com ajuste sazonal do IBGE (tabela 8887, variavel 12607) | sim |
| `imp_bk_quantum` | Importacao de bens de capital, indice de quantum da Funcex (proxy do componente importado de M&E) | Ipeadata | indice, media de 2018 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste na fonte; X-11 aplicado aqui | sim |
| `imp_bk_real` | Importacao de bens de capital (CGCE 1), valor FOB em R$ de 2025 com ajuste sazonal | Comex Stat/MDIC + BCB/SGS | R$ bi de 2025 por trimestre | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste na fonte; X-11 aplicado aqui | sim |
| `bndes_priv` | Desembolsos do BNDES exceto subsetor CNAE Administracao Publica (inclui estatais; proxy de desembolsos a empresas), R$ de 2025 com ajuste sazonal | BNDES/Dados Abertos + BCB/SGS | R$ bi de 2025 por trimestre | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste na fonte; X-11 aplicado aqui | sim |
| `bndes_total` | Desembolsos totais do BNDES, R$ de 2025 com ajuste sazonal | BNDES/Dados Abertos + BCB/SGS | R$ bi de 2025 por trimestre | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste na fonte; X-11 aplicado aqui | sim |
| `fbcf_cnt_vol` | FBCF das Contas Nacionais Trimestrais, indice de volume encadeado com ajuste sazonal | IBGE/SIDRA | indice, media de 1995 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | com ajuste sazonal do IBGE (tabela 1621) | sim |
| `pvd_diss` | PVD da dissertacao (consumo aparente de M&E do Indicador Ipea, safra da dissertacao), em nivel: 10^PVD | Dissertacao do autor (arquivo do VAR) | indice (10^PVD = 0,9426 x indice Ipea de M&E, 1995 = 100, safra da dissertacao) | 2002Q1 a 2019Q4 (72 trimestres) | com ajuste sazonal (Ipea, safra da dissertacao) | sim |
| `pib_vol_sa` | PIB, indice de volume encadeado com ajuste sazonal | IBGE/SIDRA | indice, media de 1995 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | com ajuste sazonal do IBGE (tabela 1621) | sim |
| `pib_cresc` | PIB, variacao trimestral do indice de volume com ajuste sazonal | IBGE/SIDRA | fracao (0,01 = 1%) | 2002Q1 a 2025Q4 (96 trimestres) | com ajuste sazonal do IBGE (tabela 1621) | nao |
| `pib_acel` | PIB, aceleracao: diferenca da variacao trimestral (como diff(exo) na dissertacao) | IBGE/SIDRA | fracao | 2002Q1 a 2025Q4 (96 trimestres) | com ajuste sazonal do IBGE (tabela 1621) | nao |
| `selic_fim` | Meta Selic no ultimo dia do trimestre (identica ao JUR da dissertacao, que esta em fracao) | BCB/SGS | % a.a. | 2002Q1 a 2025Q4 (96 trimestres) | nao se aplica | nao |
| `selic_media` | Meta Selic, media diaria do trimestre (robustez) | BCB/SGS | % a.a. | 2002Q1 a 2025Q4 (96 trimestres) | nao se aplica | nao |
| `ipca_tri` | IPCA, variacao acumulada no trimestre | BCB/SGS | % no trimestre | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste sazonal | nao |
| `cambio_real` | Indice da taxa de cambio real efetiva (IPCA); alta = depreciacao real | BCB/SGS | indice, jun/1994 = 100 | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste sazonal | sim |
| `icbr_usd` | Indice de Commodities - Brasil em US$ (IC-Br) | BCB/SGS | indice | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste sazonal | sim |
| `brent_usd` | Preco do petroleo Brent (FOB) | Ipeadata | US$ por barril | 2002Q1 a 2025Q4 (96 trimestres) | sem ajuste sazonal | sim |
| `fbcf_real_rs_bi` | FBCF em R$ bi de 2025 com ajuste sazonal (para multiplicadores) | IBGE/SIDRA | R$ bi de 2025 por trimestre (precos medios de 2025 da FBCF) | 2002Q1 a 2025Q4 (96 trimestres) | com ajuste sazonal do IBGE (tabela 6613) | sim |
| `pib_real_rs_bi` | PIB em R$ bi de 2025 com ajuste sazonal (para multiplicadores) | IBGE/SIDRA | R$ bi de 2025 por trimestre (precos medios de 2025 do PIB) | 2002Q1 a 2025Q4 (96 trimestres) | com ajuste sazonal do IBGE (tabela 6613) | sim |

## Ajuste sazonal feito aqui (X-11 multiplicativo, serie D11)

| variavel | janela | ARIMA | regressores | Q | M7 | QS original (p) | QS ajustada (p) | QS ajustada sem extremos (p) |
|---|---|---|---|---|---|---|---|---|
| `imp_bk_quantum` | 2000Q1 a 2025Q4 | (0 1 1)(0 1 1) | Easter[15] AO2018.3 AO2020.1 | 0,91 | 0,63 | 0,004 | 0,071 | 1,000 |
| `imp_bk_real` | 2000Q1 a 2025Q4 | (0 1 0)(0 1 1) | Easter[15] AO2018.3 AO2020.1 | 0,72 | 0,52 | 0,008 | 0,010 | 1,000 |
| `bndes_priv` | 2000Q1 a 2025Q4 | (0 1 1)(0 1 1) | AO2009.3 AO2010.3 | 0,57 | 0,17 | 0,000 | 0,003 | 1,000 |
| `bndes_total` | 2000Q1 a 2025Q4 | (0 1 1)(0 1 1) | AO2009.3 AO2010.3 | 0,52 | 0,16 | 0,000 | 0,002 | 1,000 |

Q e M7 abaixo de 1 indicam ajuste aceitavel e sazonalidade identificavel. O teste QS tem como hipotese nula a ausencia de sazonalidade.

## Correlacoes das diferencas do log10 entre as series privadas (2002Q2 a 2025Q4, 95 trimestres)

| variavel | fbcf_me | fbcf_constr | fbcf_outros | fbcf_total | ca_bk_sa | pim_bk | imp_bk_quantum | imp_bk_real | bndes_priv | bndes_total | fbcf_cnt_vol |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `fbcf_me` | 1,00 | 0,42 | 0,31 | 0,81 | 0,82 | 0,74 | 0,69 | 0,56 | -0,15 | -0,14 | 0,81 |
| `fbcf_constr` | 0,42 | 1,00 | 0,27 | 0,65 | 0,52 | 0,56 | 0,30 | 0,21 | -0,07 | -0,06 | 0,65 |
| `fbcf_outros` | 0,31 | 0,27 | 1,00 | 0,29 | 0,23 | 0,32 | 0,16 | 0,07 | 0,05 | 0,04 | 0,29 |
| `fbcf_total` | 0,81 | 0,65 | 0,29 | 1,00 | 0,79 | 0,79 | 0,58 | 0,45 | -0,09 | -0,09 | 1,00 |
| `ca_bk_sa` | 0,82 | 0,52 | 0,23 | 0,79 | 1,00 | 0,82 | 0,83 | 0,68 | -0,20 | -0,20 | 0,79 |
| `pim_bk` | 0,74 | 0,56 | 0,32 | 0,79 | 0,82 | 1,00 | 0,50 | 0,34 | -0,16 | -0,17 | 0,79 |
| `imp_bk_quantum` | 0,69 | 0,30 | 0,16 | 0,58 | 0,83 | 0,50 | 1,00 | 0,90 | -0,15 | -0,14 | 0,59 |
| `imp_bk_real` | 0,56 | 0,21 | 0,07 | 0,45 | 0,68 | 0,34 | 0,90 | 1,00 | -0,12 | -0,11 | 0,45 |
| `bndes_priv` | -0,15 | -0,07 | 0,05 | -0,09 | -0,20 | -0,16 | -0,15 | -0,12 | 1,00 | 0,99 | -0,10 |
| `bndes_total` | -0,14 | -0,06 | 0,04 | -0,09 | -0,20 | -0,17 | -0,14 | -0,11 | 0,99 | 1,00 | -0,10 |
| `fbcf_cnt_vol` | 0,81 | 0,65 | 0,29 | 1,00 | 0,79 | 0,79 | 0,59 | 0,45 | -0,10 | -0,10 | 1,00 |

## Correlacao com o PVD da dissertacao (2002Q2 a 2019Q4, 71 diferencas)

| variavel | cor. das diferencas com pvd_diss | cor. em nivel (log10) | n |
|---|---|---|---|
| `fbcf_me` | 0,993 | 1,000 | 71 |
| `fbcf_constr` | 0,248 | 0,884 | 71 |
| `fbcf_outros` | 0,066 | 0,846 | 71 |
| `fbcf_total` | 0,731 | 0,977 | 71 |
| `ca_bk_sa` | 0,789 | 0,955 | 71 |
| `pim_bk` | 0,752 | 0,893 | 71 |
| `imp_bk_quantum` | 0,588 | 0,957 | 71 |
| `imp_bk_real` | 0,441 | 0,819 | 71 |
| `bndes_priv` | -0,004 | 0,636 | 71 |
| `bndes_total` | 0,012 | 0,653 | 71 |
| `fbcf_cnt_vol` | 0,734 | 0,977 | 71 |

## Niveis em R$ de 2025 (multiplicadores)

- `fbcf_real_rs_bi` e `pib_real_rs_bi`: tabela 6613 (valores encadeados a precos de 1995 com ajuste sazonal) x k, com k = media de 2025 da 1846 / media de 2025 da 6613 (k = 8,2837 na FBCF e 9,2742 no PIB). Soma de 2025: FBCF R$ 2.145,1 bi e PIB R$ 12.738,6 bi, iguais a soma corrente de 2025 da 1846. Fluxos trimestrais, nao anualizados.
- Variacoes identicas as do indice 1621 (diferenca maxima 7,3e-05 na FBCF). Em 2025, soma com ajuste / soma sem ajuste = 1,0006 (FBCF) e 1,0006 (PIB). FBCF/PIB: 15,5% em 2003 e 16,8% em 2025.
- Precos relativos: de 2003 a 2025 o deflator implicito da FBCF foi multiplicado por 4,173 e o IPCA por 3,357. O investimento publico da A3 esta em R$ de 2025 pelo IPCA; a FBCF aqui, a precos de 2025 da propria FBCF (razao 1,243 em 2003).

## Ressalvas

- `bndes_priv` exclui so o subsetor CNAE Administracao Publica e inclui estatais (Petrobras, Eletrobras); a base mensal do BNDES nao separa empresas privadas.
- Os componentes nacional e importado do M&E do Ipea nao sao publicados como serie: `pim_bk` e as importacoes de BK entram como proxies.
- O Indicador de Incerteza da FGV IBRE ficou fora (sem fonte aberta acessivel no conteiner).
- `pvd_diss` e a safra da dissertacao; `fbcf_me` e a safra de 2026 da mesma serie.
