# A3: classificacao das series de investimento publico

Gerado por R/A3_investimento_publico.R em 2026-09-28 20:08.

## Uniao: funcoes (Portaria MOG 42/1999)

Economica: 24, 25, 26. Social: 08, 10, 12, 15, 16, 17, 27. Outras: demais funcoes. Valores: GND 4, somas nominais 2003-2025
do dashboard trimestral (direta = grupo 0, modalidades 90 e 91; transferencia = grupo 1, demais exceto 67 e 99).

| funcao | nome | tipo | direta R$ bi | transf. R$ bi |
|---|---|---|---|---|
| 00 | SEM FUNCAO INFORMADA | outras | 0,0 | 0,0 |
| 01 | LEGISLATIVA | outras | 2,4 | 0,0 |
| 02 | JUDICIARIA | outras | 21,0 | 0,0 |
| 03 | ESSENCIAL A JUSTICA | outras | 3,7 | 0,0 |
| 04 | ADMINISTRACAO | outras | 12,1 | 1,4 |
| 05 | DEFESA NACIONAL | outras | 140,4 | 1,6 |
| 06 | SEGURANCA PUBLICA | outras | 13,4 | 18,8 |
| 07 | RELACOES EXTERIORES | outras | 0,9 | 0,0 |
| 08 | ASSISTENCIA SOCIAL | social | 0,7 | 7,2 |
| 09 | PREVIDENCIA SOCIAL | outras | 1,7 | 0,0 |
| 10 | SAUDE | social | 19,6 | 59,4 |
| 11 | TRABALHO | outras | 0,4 | 0,4 |
| 12 | EDUCACAO | social | 48,5 | 49,0 |
| 13 | CULTURA | outras | 1,2 | 2,0 |
| 14 | DIREITOS DA CIDADANIA | outras | 2,3 | 5,0 |
| 15 | URBANISMO | social | 14,6 | 51,7 |
| 16 | HABITACAO | social | 0,0 | 4,2 |
| 17 | SANEAMENTO | social | 0,7 | 20,7 |
| 18 | GESTAO AMBIENTAL | outras | 24,8 | 16,6 |
| 19 | CIENCIA E TECNOLOGIA | outras | 7,7 | 10,9 |
| 20 | AGRICULTURA | outras | 9,5 | 16,5 |
| 21 | ORGANIZACAO AGRARIA | outras | 7,4 | 4,5 |
| 22 | INDUSTRIA | outras | 1,0 | 0,7 |
| 23 | COMERCIO E SERVICOS | outras | 0,5 | 11,6 |
| 24 | COMUNICACOES | economica | 1,4 | 0,1 |
| 25 | ENERGIA | economica | 0,8 | 0,1 |
| 26 | TRANSPORTE | economica | 189,0 | 12,2 |
| 27 | DESPORTO E LAZER | social | 1,4 | 9,0 |
| 28 | ENCARGOS ESPECIAIS | outras | 2,7 | 24,2 |
| 99 | RESERVA DE CONTINGENCIA | outras | 0,0 | 0,0 |

## Uniao: modalidades

- aplicacao direta (grupo 0): 90 e 91;
- transferencia (grupo 1): todas as demais exceto 67 e 99; destino estados e municipios = 30, 31, 32, 40, 41, 42, 71, 72;
  entidades privadas = 50 e 60; exterior = 80; outras = demais (na base, 70);
- outra (grupo 2): 67 e 99.

Destino das transferencias (grupo 1), base anual, 2003-2025:

| tipo | destino | R$ bi nominais | participacao |
|---|---|---|---|
| economica | entidades privadas | 0,2 | 1,3% |
| economica | estados e municipios | 16,4 | 98,5% |
| economica | exterior | 0,0 | 0,2% |
| social | entidades privadas | 9,4 | 4,7% |
| social | estados e municipios | 191,5 | 95,1% |
| social | exterior | 0,3 | 0,1% |
| social | outras | 0,2 | 0,1% |

## Estatais: segmentos da OI (classificacao aprovada pelo autor em 2026-09-28)

| segmento | classe | R$ bi nominais 2016-2025 | grupo Petrobras R$ bi | trimestres |
|---|---|---|---|---|
| Oil, gas & derivatives | petroleo | 624,0 | 624,0 | 2016Q1-2025Q4 |
| Airport administration | economica | 3,8 | 0,0 | 2016Q1-2025Q4 |
| Electricity | economica | 28,7 | 1,6 | 2016Q1-2025Q4 |
| Port administration | economica | 1,8 | 0,0 | 2016Q1-2025Q4 |
| Transport | economica | 0,0 | 0,0 | 2022Q1-2023Q4 |
| Commerce & services | outras | 17,9 | 0,0 | 2016Q1-2025Q4 |
| Financial | outras | 37,0 | 0,0 | 2016Q1-2025Q4 |
| Food supply | outras | 0,0 | 0,0 | 2016Q1-2025Q4 |
| Industry | outras | 1,5 | 0,0 | 2016Q1-2025Q4 |
| Research, development & planning | outras | 0,0 | 0,0 | 2016Q1-2019Q4 |

Antes de 2016 (boletim) nao ha abertura por segmento: so o total Brasil.

## Series de choque

| serie | definicao | inicio | fim | base_indice |
|---|---|---|---|---|
| uniao_econ_dir | Uniao, funcoes economicas (24, 25, 26), aplicacao direta (grupo 0: modalidades 90 e 91), GND 4, todos os elementos | 2003Q1 | 2025Q4 | media 2003 = 100 |
| uniao_econ_dt | Uniao, funcoes economicas, direta + transferencias (grupos 0 e 1) | 2003Q1 | 2025Q4 | media 2003 = 100 |
| uniao_soc_dir | Uniao, funcoes sociais (08, 10, 12, 15, 16, 17, 27), aplicacao direta (grupo 0) | 2003Q1 | 2025Q4 | media 2003 = 100 |
| uniao_soc_dt | Uniao, funcoes sociais, direta + transferencias (grupos 0 e 1) | 2003Q1 | 2025Q4 | media 2003 = 100 |
| uniao_transf_econ | Uniao, funcoes economicas, transferencias (grupo 1) | 2003Q1 | 2025Q4 | media 2003 = 100 |
| uniao_transf_soc | Uniao, funcoes sociais, transferencias (grupo 1) | 2003Q1 | 2025Q4 | media 2003 = 100 |
| uniao_gnd4_dir | Uniao, todas as funcoes, aplicacao direta (grupo 0), GND 4 | 2003Q1 | 2025Q4 | media 2003 = 100 |
| uniao_filtro_diss | Uniao, filtro da dissertacao (modalidade 90, 6 elementos); 2017 imputado pelo perfil do grupo 0 | 2003Q1 | 2025Q4 | media 2003 = 100 |
| estatais_total | Estatais federais: boletim SEST (Brasil) ate 2019T4; OI x razao media boletim/OI 2016-2019 a partir de 2020T1 | 2003Q1 | 2025Q4 | media 2003 = 100 |
| estatais_petro | Estatais, segmento Oil, gas & derivatives (OI, sem encadeamento) | 2016Q1 | 2025Q4 | media 2016 = 100 |
| estatais_sempetro | Estatais, todos os segmentos exceto Oil, gas & derivatives (OI) | 2016Q1 | 2025Q4 | media 2016 = 100 |
| estatais_econ | Estatais, segmentos Electricity, Transport, Port administration e Airport administration (OI) | 2016Q1 | 2025Q4 | media 2016 = 100 |
| estatais_outras | Estatais, segmentos Financial, Commerce & services, Industry, Research, development & planning e Food supply (OI) | 2016Q1 | 2025Q4 | media 2016 = 100 |
| estatais_grupopetro | Estatais do grupo Petrobras, todos os segmentos (OI, grupo_petrobras = True) | 2016Q1 | 2025Q4 | media 2016 = 100 |
| estatais_semgrupopetro | Estatais fora do grupo Petrobras (OI, grupo_petrobras = False) | 2016Q1 | 2025Q4 | media 2016 = 100 |
| inf_diss | Agregado da dissertacao: uniao_filtro_diss + estatais_total | 2003Q1 | 2025Q4 | media 2003 = 100 |

Variantes de robustez:

| serie | definicao | inicio | fim |
|---|---|---|---|
| uniao_filtro_diss_imprazao | Como uniao_filtro_diss, 2017 imputado pela razao filtro/dashboard do trimestre (media de 2016 e 2018) | 2003Q1 | 2025Q4 |
| estatais_total_e2017 | Como estatais_total, emenda em 2017T1 com a razao media boletim/OI de 2016 | 2003Q1 | 2025Q4 |
| estatais_total_e2018 | Como estatais_total, emenda em 2018T1 com a razao media boletim/OI de 2017 | 2003Q1 | 2025Q4 |
| estatais_total_e2019 | Como estatais_total, emenda em 2019T1 com a razao media boletim/OI de 2018 | 2003Q1 | 2025Q4 |
| estatais_total_e2020 | Como estatais_total, emenda em 2020T1 com a razao media boletim/OI de 2019 | 2003Q1 | 2025Q4 |
| inf_diss_imprazao | Como inf_diss, com 2017 imputado pela razao do trimestre | 2003Q1 | 2025Q4 |
| inf_diss_e2017 | Como inf_diss, com estatais_total_e2017 | 2003Q1 | 2025Q4 |
| inf_diss_e2018 | Como inf_diss, com estatais_total_e2018 | 2003Q1 | 2025Q4 |
| inf_diss_e2019 | Como inf_diss, com estatais_total_e2019 | 2003Q1 | 2025Q4 |
| inf_diss_e2020 | Como inf_diss, com estatais_total_e2020 | 2003Q1 | 2025Q4 |
