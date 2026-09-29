# LOG

## 2026-09-28
- Replicado o modelo final da dissertacao a partir de data/original (0224_tri_estmeq.txt em log10; 0124_inexo.txt).
  Especificacao que reproduz: VAR(diff(infmeq), p=3, type="both", exogen=diff(exo)). Script: scripts/replica_original.py.
- Resultado: impacto 0,0118; resposta acumulada de PVD em 40 trimestres 0,0194; resposta acumulada do proprio INF 0,0465;
  elasticidade de longo prazo 0,42 (IC 90% bootstrap 0,07 a 0,67).
- Granger da Tabela 12 vem do VAR em nivel (df 3 e 116). No VAR em diferenca: INF->PVD F=3,27, p=0,024.
  PVD->INF: F=1,91, p correto = 0,13 (a dissertacao reporta 0,56).
- Exogenas entram diferenciadas (PIB vira aceleracao; dummy vira pulsos). Dummy do arquivo: 2018T2-2019T1 e 2019T3-2019T4.
- Robustez rapida em results/robustez_rapida.csv (scripts/robustez_rapida.py): efeito sensivel a ordem de Cholesky,
  a forma como o PIB entra e ao numero de defasagens (2 lags).
- A serie INF do modelo nao e a do Apendice A (apendice parece nominal e sem ajuste sazonal).
- PIB diferenciado mantido no baseline pelo principio do acelerador (decisao do autor); versao em taxa de crescimento vira robustez.
- Recebido data/raw/federal_siga_analitico_real.parquet: anual, 2001-2026, sem 2017, inclui GND 5 e 6 (filtrar GND 4),
  so governo federal; parcela atribuivel a UF: 74% (economica) e 43% (social). Serve para o painel de estados (Parte B),
  nao para o VAR trimestral.
- Encontrado o bruto mensal do SIGA (~/financas-publicas-br/dados/federal/Novo documento (1).csv, 2,1 GB, nominal):
  tem Mes/Ano e Elemento. 2017 falta tambem no bruto. Gerados federal_gnd4_mensal.csv e
  federal_inv_direto_trimestral_nominal.csv (filtro da dissertacao). A serie federal soma R$ 5,0 bi em 2002 e R$ 23,1 bi
  em 2013 (nominal); comparada ao Apendice A (R$ 24,7 e 128,8 bi), confirma que o apendice e nominal e que as estatais
  sao a maior parte de INF.
- Extraidos do dashboard (index.html do GitHub Pages): SEST boletim trimestral 2003-2019 e OI trimestral 2016-2025
  (com grupo Petrobras), FGV-Ibre anual, BNDES anual.
- Checagem: federal (filtro da dissertacao) + SEST boletim reproduz o Ipub do Apendice A em 2003-2019
  (razao media 0,97; correlacao das diferencas dos logs = 1,0). Na sobreposicao 2016-2019, OI fica 10-15% acima do boletim.
- 2017: o dashboard tem a serie federal trimestral de 2017 (execucao direta R$ 25,0 bi nominal), sem filtro de elemento.
  Razao filtro/dashboard (execucao direta): 0,62 em 2016, 0,72 em 2018; correlacao das diferencas dos logs 0,99.
- Nova pergunta: efeito por esfera (Uniao, estados, estatais) e tipo (economica x social).
- Uniao, 2003-2025 (nominal): infraestrutura social 70% via transferencias (R$ 192 bi x R$ 82 bi diretos);
  economica 92% direta (R$ 182 bi x R$ 16 bi). Serie so com modalidade 90 subestima a social.
- Estados: dados locais so anuais (DCA 2014-2024; MSC por funcao 2019+). Sem serie trimestral antes de 2015.

## 2026-09-28 e 29 (Parte A em R, sessao na nuvem)

Resumo condensado de results/log_parts/*.md (A0_ambiente, A1, A2_bcb_ibge, A2_ipea_comex_bndes, A2_consolidacao, A3, A4, A5_var, A5_lp, A5_estimacao, A6). Os detalhes e todos os numeros estao nessas partes e nos arquivos citados.

### Ambiente e dados de partida
- Conteiner na nuvem com R 4.6.1 e pacotes do briefing (vars, seasonal com X-13, strucchange, urca, fixest, lpirfs, sandwich, sidrar, rbcb, ipeadatar, tidyverse e auxiliares) e texlive. fwildclusterboot fica para a Parte B. Nada foi instalado na maquina do autor.
- ~/financas-publicas-br nao existe no conteiner. A extracao-fonte do dashboard (painel publicado, variavel FED_GZ) trouxe a base federal GND 4 anual por funcao, elemento e modalidade, com 2017: o filtro da dissertacao reproduz a serie trimestral filtrada com razao 1,000 em todos os anos e da R$ 16,196 bi nominais em 2017. So a distribuicao trimestral de 2017 e imputada.
- data/original e data/raw ficaram somente leitura; R/00_setup.R bloqueia escrita nelas (guard_path). data/raw/x.csv, arquivo de teste versionado por engano, foi removido pelo coordenador.
- Modo enxuto por custo (decisao do autor): um agente por etapa, uma verificacao adversarial dos numeros da A5, um agente para a A6.

### A1: replicacao em R
- VAR(diff(infmeq), p = 3, type = "both", exogen = diff(exo)), Cholesky INF antes de PVD, 68 observacoes efetivas: impacto 0,0118; acumulada de PVD em h = 40 0,0194; de INF 0,0465; elasticidade de longo prazo 0,4163. Todos os alvos reproduzidos. Das Tabelas 6 a 18 (319 valores), 10 batem so por truncamento e 2 nao se reproduzem, os esperados (42,33 da Tabela 7 e p = 0,56 da Tabela 12).
- IC 90% da elasticidade com 2000 replicas: [0,05; 0,66] (percentil); basico de Hall [0,17; 0,78]; Kilian 0,48 [0,11; 0,82]. Os tres supoem residuos sem autocorrelacao.
- No Rmd, a linha dados2 <- UCI[,1] sobrescreve dados2 <- diff(exo); a especificacao com diff(exo) foi identificada por reproduzir as Tabelas 9, 10 e 16.

### Correcoes ao texto antigo (lista para o paper)
- Magnitude: "1% gera cerca de 2%" esta errado. Elasticidade de longo prazo 0,42 [0,05; 0,66]; resposta acumulada de PVD 0,0194 para acumulada de INF 0,0465.
- Granger: a Tabela 12 vem do VAR em nivel (gl 3 e 116). O p = 0,56 de PVD -> INF e incompativel com F = 1,90 e gl (3, 116) do proprio texto, que implicam p = 0,133 (erro de transcricao). No VAR em diferenca: INF -> PVD F = 3,27, p = 0,024; PVD -> INF F = 1,27, p = 0,29. Correcao ao item de 2026-09-28 deste LOG: o par F = 1,91 e p = 0,13 e do VAR em nivel, nao do VAR em diferenca.
- Tabela 7: rotulos trocados. Portmanteau ajustado (16 defasagens) 52,34, p = 0,46; ARCH-LM multivariado 42,23 (o texto imprime 42,33), p = 0,59.
- Autocorrelacao residual: o texto afirma ausencia com base so no Portmanteau; Breusch-Godfrey rejeita a 1% em 8 de 8 defasagens e Edgerton-Shukur a 5% em 8 de 8.
- Johansen (Tabela 8): traco 25,01 contra valor critico de 5% de 25,32 nao rejeita r = 0 (rejeita a 10%, valor critico 22,76). Evidencia limitrofe de um vetor, e nao ausencia de cointegracao; o texto afirma as duas coisas em frases seguidas.
- Dummy: no arquivo, DUM = 1 em 2018T2 a 2019T1 e 2019T3 a 2019T4 (6 trimestres); o texto diz 2018T3 a 2019T4.
- INF nominal: o INF do arquivo 0224_tri_estmeq.txt e log10 do X-11 do Ipub nominal (correlacao das diferencas 0,9975, desvio medio em nivel 0,005 log10); a serie deflacionada fica 0,19 log10 abaixo, a inflacao acumulada. A secao 4.4 diz que houve deflacao; ela nao chegou ao arquivo do VAR.
- Parte dos numeros do texto e truncada, nao arredondada (10 de 319).

### A2: series privadas e controles
- BCB/SGS: Meta Selic 432 (JUR da dissertacao = meta no ultimo dia do trimestre, 72 de 72 iguais), IPCA 433, cambio real efetivo 11752, IC-Br em US$ 29042, PTAX 3698. IBGE/SIDRA: 1620, 1621, 1846, 6612, 6613 (PIB e FBCF) e 8887 (PIM-PF bens de capital, com ajuste). Ipea: planilha da Carta de Conjuntura (M&E, construcao, outros, total, com ajuste) e Ipeadata (consumo aparente de BK, Funcex, Brent). Comex Stat: importacao de BK (CGCE 1). BNDES: desembolsos mensais do portal de dados abertos (MD5 conferido).
- PVD da dissertacao = M&E do Ipea dessazonalizado (correlacao das diferencas 0,9931 com a serie atual).
- Sem fonte aberta: componentes nacional e importado de M&E (proxies: PIM-PF BK e importacao de BK) e Indicador de Incerteza da FGV (fora dos controles).
- BNDES exceto Administracao Publica e o recorte mais proximo de desembolso privado, mas inclui estatais (Petrobras, Eletrobras); quase nao se correlaciona com as medidas de investimento nas diferencas.
- Base consolidada: data/processed/A2_series_trimestrais.csv, 2002T1 a 2025T4, sem interpolacao; reproduzida byte a byte.

### A3: investimento publico por esfera e tipo
- Deflator: IPCA medio do trimestre (o bruto mensal nao esta no conteiner; erro maximo de 1,39% por concentracao do gasto em dezembro).
- 2017 do filtro da dissertacao: total anual exato, perfil trimestral do grupo 0 do dashboard; variantes pela razao do trimestre e pelo Apendice A.
- Estatais: boletim da SEST ate 2019T4 e OI x 0,9303 (razao media boletim/OI de 2016-2019) a partir de 2020T1. O OI fica 9,6% a 13,1% acima do boletim em 2016-2018, mas 8,1% abaixo em 2019.
- inf_diss (real) = X-11 por componente e soma (o X-11 na soma e instavel na serie real). inf_diss_nominal_2019 reproduz o INF do arquivo.
- Parcelas (somas nominais 2003-2025): social 70,2% via transferencias; economica 92,0% direta. Transferencias sao 95,1% (social) e 98,5% (economica) para estados e municipios.
- Petroleo nas estatais (OI): 82,5% a 90,8% por ano. Estatais sao 78,3% do total em 2003 e 60,7% em 2025.
- Regra de aptidao para as LP (Q do X-11 acima de 1, erro de arredondamento acima de 2% ou sem log10): saem uniao_transf_econ, uniao_transf_econ_g1, estatais_outras e estatais_sempetro_semout. Por isso a comparacao direta x transferencia fica so na social.
- Picos (AO) do X-11 ficam na serie ajustada (D11); variantes sem AO e dummies para A4 e A5. Composicao por elemento da execucao direta muda em 2011-2016 (entrada do elemento 39 no transporte).

### A4: quebras
- Importam para o resultado: (1) 2020-2021. O VAR estendido da 0,451 com dados ate 2019T4 e 0,154 com 2020-2025; o supF das duas equacoes estendidas tem maximo em 2020T2 (p = 0,013 e < 0,001) e o Chow em 2020T2 rejeita. (2) A divisao em 2014T4: 0,227 ate 2014T4 e 0,059 depois; a diferenca esta na dinamica, e uma dummy nao resolve.
- Detectada sem efeito relevante: turbulencia de 2018-2019 no boletim da SEST (equacao de INF da dissertacao instavel no fim da amostra).
- Nao importam: 2008T4, teto de gastos (2016T4/2017T1), arcabouco (2023T3), emenda boletim/OI, imputacao de 2017, T4 eleitoral, composicao 2011-2016 e saida da Eletrobras.
- Raiz unitaria com quebra: nas privadas e em inf_diss nao rejeita, o que mantem o VAR em diferenca. Baseline da A5: pulsos de 2020T2 e 2020T3; outliers do X-11 de 2018-2021 como robustez.

### A5: VAR e VEC
- Corrigido, uma correcao por vez (2003-2019, n = 64): so a amostra 0,49; INF nominal reconstruido 0,48; INF real 0,48; PVD atual 0,46; PIB e Selic atuais 0,45 [0,10; 0,69] (baseline corrigido). Estendido 2003-2025 (n = 88): 0,17 [-0,03; 0,36].
- Johansen (K = 3, ecdet trend), traco / Reinsel-Ahn / p do bootstrap selvagem (999 replicas): 2002-2019 original 24,19 / 22,09 / 0,170; 2003-2019 28,79 / 26,13 / 0,086; 2003-2025 26,29 / 24,52 / 0,124 (valor critico de 5% 25,32). As leituras discordam; evidencia limitrofe nas tres amostras. Pela regra (bootstrap a 5%), baseline = VAR em diferenca, com o VEC ao lado: 0,58 [0,42; 0,82], 0,55 [0,40; 0,76] e 0,51 [0,36; 0,66].
- Sensibilidade (2003-2019): Cholesky invertida 0,07 [-0,25; 0,30] e p = 2 0,06 [-0,25; 0,31], os dois com IC que inclui zero; PIB em taxa 0,23 [0,02; 0,39]. Em 2003-2025, Cholesky invertida, p = 2 e PIB em taxa tambem incluem zero; outliers do X-11 de 2018-2021 levam a 0,34 [0,12; 0,55].
- Correcoes da verificacao adversarial: imp2017 saiu do VAR estendido de base; subamostras com o corte da A4; robustez principal em linha propria; VEC ao lado do VAR.

### A5: projecoes locais
- Jorda (2005) em diferenca, h = 0 a 12, p = 3, choque antes da resposta, 2003T1-2025T4 (n = 88 em h = 0 e 76 em h = 12); series de 2016+ com p = 2 e h ate 8 (n = 33 e 29). Elasticidade e multiplicador acumulados por MQ2E (Ramey e Zubairy, 2018). Newey-West com colunas com e sem ajuste de graus de liberdade.
- inf_diss -> M&E, elasticidade em h = 12: 0,10, sem significancia. Multiplicador da FBCF em R$ em h = 12: inf_diss 1,83; estatais_total 1,83; uniao_gnd4_dir 6,64. Nas rubricas pequenas da Uniao (G medio de 0,3% a 1,1% da FBCF) o multiplicador separado nao se le em R$: uniao_soc_dir cai de 49,5 (separada) para 13,6 (conjunta).
- Comparacoes (regressao conjunta, elasticidade da FBCF em volume, p com ajuste de amostra pequena): economica x social sem diferenca (p de 0,40 a 0,82); social direta x transferencia 0,13 x 0,00 em h = 4 (p = 0,014), so a 10% em h = 8 e 12, e sem diferenca em M&E; estatais sem petroleo x petroleo 0,19 x -0,04 em h = 4 (p = 0,017, n = 33, gl = 19), baixo poder, sem diferenca em M&E; estatais x Uniao direta sem diferenca a 10%.
- Testes multiplos: IC pontuais; 104 de 264 elasticidades acumuladas do baseline excluem zero sem ajuste.

### A6: saidas para Halle
- R/A6_saidas.R gera results/A_robustez.tex, results/A_lp.tex, results/A_numeros_halle.md, results/A_numeros_macros.tex (290 macros) e as figuras A6_fig1_econ_social e A6_fig2_direta_transf_estatais, tudo lido dos CSV. results/A_quebras.tex (A4) nao foi alterado.
- Decisoes: nas LP, IC e p com o ajuste de graus de liberdade (Newey-West vezes n/(n - k), t e F com n - k graus), a versao sem ajuste entre parenteses no A_numeros_halle.md; com o ajuste, 84 de 264 elasticidades acumuladas excluem zero. Multiplicadores em R$ so nos agregados; nas rubricas, painel separado com G/FBCF. Comparacoes lidas em elasticidade da regressao conjunta. Decisao VAR x VEC com as tres estatisticas lado a lado e o VEC ao lado do VAR.
- Resumo estendido em ingles: results/A_extended_abstract.tex e .pdf (3 paginas, article 11pt, margens de 2,5 cm; auxiliares em results/latex_aux/). Todo numero do texto vem das macros; conferido por codigo que nao ha outro numero no corpo alem de indices de notacao e parametros de LaTeX, e que 111 macros batem com os CSV. Referencias: da lista da dissertacao (Reis, Araujo e Gonzales, 2019; Iasco-Pereira e Duregger, 2023; Jacinto e Ribeiro, 1998; Oliveira, 2020) e metodologicas usadas (Jorda, 2005; Ramey e Zubairy, 2018; Johansen, 1991; Reinsel e Ahn, 1992; Cavaliere, Rahbek e Taylor, 2012; Bai e Perron, 1998; Andrews, 1993; Zivot e Andrews, 1992). O resumo usa uma figura (A6_fig2); a A6_fig1 (economica x social) fica disponivel.

### Decisoes pendentes para o autor
- Transferencia = grupo 1 do dashboard (baseline, colunas _g1) ou grupos 1 e 2 (inclui execucao delegada, modalidades 32 e 42): na social sao identicos; na economica a razao dos niveis e 1,036 em 2012-2025.
- Regra VAR x VEC: com evidencia limitrofe nas tres amostras, confirmar o VAR em diferenca como baseline e o VEC ao lado, ou trocar a regra.
- Demais decisoes do coordenador sobre A2 e A3 (A0_ambiente.md, itens 1 a 12): AO do X-11 mantidos nos choques, OI so com AO, Selic no fim do trimestre, IC-Br em US$, safra atual do PIB, PIM-PF com ajuste do IBGE, M&E dessazonalizado publicado, BNDES exceto Administracao Publica, proxies de nacional e importado, incerteza fora, transferencia economica fora das LP.
- Itens da A3 para aprovacao: inf_diss real por ajuste indireto; encadeamento do OI pela razao 2016-2019 (a razao salta em 2019); series por funcao em GND 4 completo; queda do segmento Electricity a partir de 2022T3 (saida da Eletrobras, a confirmar); regra de aptidao das LP.
- Confirmar se a base de desembolsos do BNDES e a mesma do arquivo local do autor.
- Refazer a deflacao com o IPCA mensal antes de agregar quando o bruto mensal do SIGA estiver no conteiner.
- Conversao de fbcf_me em R$ (FBCF por tipo de ativo nas tabelas de recursos e usos do IBGE, fora do SIDRA): nao feita.
- Resumo estendido: revisar o texto (o autor escreve o texto final), a frase sobre a dissertacao ("In a master's dissertation we estimated") e a escolha da figura; o capitulo 1 da tese, com referencias mais atuais, ainda nao entrou.
