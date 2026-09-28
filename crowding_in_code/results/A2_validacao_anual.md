# A2. Validacao anual: FBCF privada contra o Indicador Ipea de FBCF

Gerado por R/A2_validacao_anual.R em 2026-09-28 20:23.

Fontes: data/raw/fgv_ibre_investimento_anual.csv (investimento por esfera e FBCF total, R$ bilhoes nominais);
IBGE, Contas Nacionais anuais, via Ipeadata (SCN10_FBKFN10, FBCF nominal; SCN10_FBKFG10, variacao real da FBCF);
data/processed/A2_ipea_mensal.csv (Indicador Ipea de FBCF sem ajuste sazonal, media dos 12 meses do ano).

Definicoes:

- Identidades conferidas: GG = GC + GE + GM (diferenca maxima 0,0010) e SP = GG + EPU (diferenca maxima 0,0010), em R$ bilhoes.
- FBCF privada = FBCF - SP (nominal).
- Variacao real da FBCF privada: variacao nominal deflacionada pelo deflator implicito da FBCF total do IBGE (mesmo deflator para os setores).
- Series do Ipea: variacao da media anual dos indices mensais sem ajuste sazonal; anos com 12 meses; nada interpolado.

## Niveis (R$ bilhoes nominais) e variacoes anuais (%)

| Ano | FBCF (R$ bi) | Setor publico (R$ bi) | FBCF privada (R$ bi) | Publico/FBCF (%) | Var. FBCF real IBGE (%) | Var. FBCF privada real (%) | Var. Ipea total (%) | Var. Ipea M&E (%) | Var. Ipea construcao (%) | Var. Ipea outros (%) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1997 | 182,1 | 33,5 | 148,6 | 18,4 | 8,4 | 10,7 | 8,4 | 9,8 | 9,1 | 1,0 |
| 1998 | 185,9 | 39,1 | 146,8 | 21,0 | -0,2 | -3,4 | -0,2 | -2,3 | 1,6 | -3,5 |
| 1999 | 185,1 | 26,5 | 158,6 | 14,3 | -8,9 | -1,1 | -8,9 | -15,8 | -4,1 | 5,2 |
| 2000 | 219,5 | 30,6 | 188,9 | 13,9 | 4,8 | 5,2 | 4,8 | 9,7 | 2,0 | 3,4 |
| 2001 | 242,3 | 36,9 | 205,4 | 15,2 | 1,3 | -0,2 | 1,3 | 1,7 | -0,8 | 8,8 |
| 2002 | 266,9 | 48,3 | 218,6 | 18,1 | -1,4 | -4,8 | -1,4 | -6,6 | 0,8 | 1,7 |
| 2003 | 285,3 | 44,5 | 240,8 | 15,6 | -4,0 | -1,0 | -4,0 | -3,1 | -7,4 | 8,7 |
| 2004 | 339,1 | 50,9 | 288,2 | 15,0 | 8,5 | 9,2 | 8,5 | 11,7 | 7,6 | 2,3 |
| 2005 | 370,2 | 56,9 | 313,3 | 15,4 | 2,0 | 1,5 | 2,0 | 5,7 | -1,4 | 7,2 |
| 2006 | 414,7 | 70,1 | 344,6 | 16,9 | 6,7 | 4,8 | 6,7 | 12,0 | 2,1 | 1,5 |
| 2007 | 489,5 | 77,2 | 412,4 | 15,8 | 12,0 | 13,5 | 12,0 | 21,6 | 6,0 | 6,9 |
| 2008 | 602,8 | 109,4 | 493,4 | 18,2 | 12,3 | 9,1 | 12,3 | 21,2 | 7,2 | 6,8 |
| 2009 | 636,7 | 133,9 | 502,8 | 21,0 | -2,1 | -5,6 | -2,1 | -10,8 | 5,3 | 3,5 |
| 2010 | 797,9 | 183,3 | 614,6 | 23,0 | 17,9 | 15,0 | 17,9 | 29,6 | 12,1 | 4,7 |
| 2011 | 901,9 | 170,9 | 731,1 | 18,9 | 6,8 | 12,4 | 6,8 | 5,8 | 7,4 | 8,7 |
| 2012 | 997,5 | 194,1 | 803,4 | 19,5 | 0,8 | 0,1 | 0,8 | -4,0 | 4,0 | 2,4 |
| 2013 | 1.114,9 | 221,0 | 893,9 | 19,8 | 5,8 | 5,3 | 5,8 | 9,5 | 4,2 | 1,6 |
| 2014 | 1.148,5 | 230,0 | 918,4 | 20,0 | -4,2 | -4,5 | -4,2 | -7,0 | -3,2 | 0,5 |
| 2015 | 1.069,4 | 173,4 | 895,9 | 16,2 | -13,9 | -9,8 | -13,9 | -22,3 | -10,1 | -4,7 |
| 2016 | 973,3 | 145,4 | 827,9 | 14,9 | -12,1 | -10,8 | -12,1 | -17,3 | -10,8 | -3,8 |
| 2017 | 958,8 | 127,8 | 831,0 | 13,3 | -2,6 | -0,7 | -2,6 | 5,2 | -8,8 | 3,0 |
| 2018 | 1.057,4 | 180,7 | 876,8 | 17,1 | 5,2 | 0,7 | 5,2 | 15,4 | -1,5 | 3,5 |
| 2019 | 1.143,2 | 151,6 | 991,6 | 13,3 | 4,0 | 8,8 | 4,0 | 2,1 | 4,8 | 6,8 |
| 2020 | 1.260,2 | 199,9 | 1.060,4 | 15,9 | -1,7 | -4,7 | -1,7 | -4,2 | 0,7 | -1,7 |
| 2021 | 1.614,8 | 179,9 | 1.434,9 | 11,1 | 12,9 | 19,2 | 12,9 | 11,1 | 11,9 | 21,5 |
| 2022 | 1.794,2 | 254,3 | 1.539,9 | 14,2 | 1,1 | -2,4 | 1,1 | -7,4 | 5,9 | 12,8 |
| 2023 | 1.795,9 | 287,7 | 1.508,2 | 16,0 | -3,0 | -5,1 | -3,0 | -9,0 | -0,3 | 5,0 |
| 2024 | 1.991,8 | 359,3 | 1.632,5 | 18,0 | 6,9 | 4,3 | 6,9 | 9,8 | 4,4 | 9,5 |
| 2025 | 2.145,1 | 345,6 | 1.799,4 | 16,1 | 2,9 | 5,3 | 2,9 | 4,2 | 0,5 | 5,5 |

## Aderencia das variacoes anuais

| Periodo | Anos | Referencia | Serie | Correlacao | Diferenca media absoluta (p.p.) | Anos com mesmo sinal |
|---|---|---|---|---|---|---|
| 1997-2025 | 29 | FBCF privada real | Ipea total | 0,90 | 2,7 | 27 |
| 1997-2025 | 29 | FBCF privada real | Ipea M&E | 0,83 | 5,8 | 26 |
| 1997-2025 | 29 | FBCF privada real | Ipea construcao | 0,78 | 3,9 | 22 |
| 1997-2025 | 29 | FBCF privada real | Ipea outros | 0,57 | 5,5 | 20 |
| 1997-2025 | 29 | FBCF total real (IBGE) | Ipea total | 1,00 | 0,0 | 29 |
| 1997-2025 | 29 | FBCF total real (IBGE) | FBCF privada real | 0,90 | 2,7 | 27 |
| 2003-2025 | 23 | FBCF privada real | Ipea total | 0,92 | 2,6 | 22 |
| 2003-2025 | 23 | FBCF privada real | Ipea M&E | 0,84 | 6,3 | 21 |
| 2003-2025 | 23 | FBCF privada real | Ipea construcao | 0,78 | 4,0 | 18 |
| 2003-2025 | 23 | FBCF privada real | Ipea outros | 0,63 | 5,4 | 17 |
| 2003-2025 | 23 | FBCF total real (IBGE) | Ipea total | 1,00 | 0,0 | 23 |
| 2003-2025 | 23 | FBCF total real (IBGE) | FBCF privada real | 0,92 | 2,6 | 22 |
| 2003-2019 | 17 | FBCF privada real | Ipea total | 0,94 | 2,4 | 17 |
| 2003-2019 | 17 | FBCF privada real | Ipea M&E | 0,87 | 7,1 | 15 |
| 2003-2019 | 17 | FBCF privada real | Ipea construcao | 0,83 | 3,7 | 14 |
| 2003-2019 | 17 | FBCF privada real | Ipea outros | 0,67 | 5,2 | 13 |
| 2003-2019 | 17 | FBCF total real (IBGE) | Ipea total | 1,00 | 0,0 | 17 |
| 2003-2019 | 17 | FBCF total real (IBGE) | FBCF privada real | 0,94 | 2,4 | 17 |

Tabelas completas: results/A2_validacao_anual.csv e results/A2_validacao_anual_estatisticas.csv.
