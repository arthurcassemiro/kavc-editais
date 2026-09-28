# A3: reconstrucao de INF

Gerado por R/A3_investimento_publico.R em 2026-09-28 20:08.

INF da dissertacao: data/original/0224_tri_estmeq.txt, log10, 2002T1-2019T4. Reconstrucao: federal com o filtro da dissertacao
(modalidade 90 e 6 elementos; 2017 imputado) + boletim da SEST (Brasil), em R$ de 2025, X-11, indice e log10.
Comparacao em 2003T2-2019T4 (67 diferencas trimestrais). Indices com base media 2003 = 100 nas medidas de nivel.

## Serie entregue (inf_diss)

IPCA medio do trimestre, X-11 depois de somar os componentes, janela do X-11 2003T1-2025T4, imputacao baseline de 2017.

- correlacao das diferencas do log10: 0,9186
- desvio absoluto medio das diferencas: 0,0158 (log10)
- desvio medio em nivel (reconstruida menos original, indices base 2003): -0,1907 em log10 (-35,5%); absoluto medio 0,1907; maximo 0,4432
- desvio absoluto medio das diferencas de 2017T1 a 2018T1: 0,0402

## Variantes

Mais proxima (maior correlacao das diferencas): deflator nominal, ajuste soma, janela 2003T1-2019T4, imputacao base, correlacao 0,9975.

Dez melhores (dam = desvio absoluto medio; tabela completa em results/A3_reconstrucao_INF_variantes.csv):

| deflator | ajuste | janela_x11 | imputacao_2017 | corr_dif | dam_dif | desvio_medio_nivel | dam_nivel | dam_dif_2017 |
|---|---|---|---|---|---|---|---|---|
| nominal | soma | 2003T1-2019T4 | base | 0,9975 | 0,0029 | 0,0049 | 0,0054 | 0,0118 |
| nominal | soma | 2003T1-2019T4 | razao | 0,9974 | 0,0027 | 0,0049 | 0,0053 | 0,0133 |
| nominal | componentes | 2003T1-2019T4 | base | 0,9952 | 0,0049 | 0,0069 | 0,0073 | 0,0153 |
| media_tri | componentes | 2003T1-2019T4 | base | 0,9947 | 0,0078 | -0,1881 | 0,1881 | 0,0136 |
| fim_tri | componentes | 2003T1-2019T4 | base | 0,9947 | 0,0080 | -0,1875 | 0,1875 | 0,0146 |
| media_tri | componentes | 2003T1-2019T4 | razao | 0,9944 | 0,0077 | -0,1882 | 0,1882 | 0,0152 |
| nominal | componentes | 2003T1-2019T4 | razao | 0,9944 | 0,0051 | 0,0070 | 0,0073 | 0,0173 |
| fim_tri | componentes | 2003T1-2019T4 | razao | 0,9943 | 0,0079 | -0,1875 | 0,1875 | 0,0162 |
| anual | componentes | 2003T1-2019T4 | base | 0,9938 | 0,0082 | -0,1887 | 0,1887 | 0,0155 |
| nominal | componentes | 2003T1-2025T4 | base | 0,9932 | 0,0056 | 0,0068 | 0,0075 | 0,0161 |

Media das metricas por nivel de cada fator (sobre todas as variantes):

| fator | nivel | corr_media | dam_dif_media |
|---|---|---|---|
| deflator | media_tri | 0,8270 | 0,0339 |
| deflator | fim_tri | 0,8396 | 0,0335 |
| deflator | anual | 0,8130 | 0,0361 |
| deflator | nominal | 0,8897 | 0,0270 |
| ajuste | soma | 0,8723 | 0,0165 |
| ajuste | componentes | 0,9906 | 0,0082 |
| ajuste | nenhum | 0,4856 | 0,1139 |
| imputacao | base | 0,8412 | 0,0326 |
| imputacao | razao | 0,8434 | 0,0327 |

Deflatores: media_tri = IPCA medio do trimestre; fim_tri = IPCA do ultimo mes do trimestre; anual = IPCA medio do ano;
nominal = sem deflacao. Ajuste: soma = X-11 depois de somar; componentes = X-11 em cada componente e soma; nenhum = sem X-11.

Figura: results/figuras/A3_INF_reconstruida.png.
