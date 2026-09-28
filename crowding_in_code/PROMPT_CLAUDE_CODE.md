# Projeto: que tipo de investimento público atrai investimento privado no Brasil?

Cole este arquivo no Claude Code, a partir da pasta `crowding_in_code/`. Trabalhe em ordem. Ao fim de cada etapa, pare, mostre os resultados e espere meu ok.

## Contexto

Sou Arthur Cassemiro Bispo, doutorando na Unicamp. Minha dissertação estimou, com VAR trimestral de 2002 a 2019, o efeito do investimento público federal (governo federal em aplicação direta + estatais da União) sobre o investimento privado em máquinas e equipamentos. Esse tema está muito explorado na macroeconometria. O paper novo muda a pergunta: **o efeito depende de quem investe (União, estados, estatais) e de que tipo de infraestrutura se constrói (econômica ou social)?**

Primeiro prazo: resumo estendido para o workshop macroeconométrico do IWH (Halle), até **quarta, 30/09/2026**. Para ele, bastam as etapas A1 a A6 com a amostra que estiver pronta. A Parte B é para 2027.

## O que já está feito (28/09/2026)

**Replicação exata da dissertação** (`scripts/replica_original.py`, `results/LOG.md`):
- dados: `data/original/0224_tri_estmeq.txt` (INF e PVD em log base 10) e `0124_inexo.txt` (PIB em variação trimestral, Selic, dummy);
- modelo: `VAR(diff(infmeq), p = 3, type = "both", exogen = diff(exo))`, Cholesky com INF antes de PVD;
- resultados: impacto 0,0118; resposta acumulada de PVD em 40 trimestres 0,0194; do próprio INF 0,0465; elasticidade de longo prazo 0,42 (IC 90% por bootstrap: 0,07 a 0,67).

**Escolhas mantidas, com justificativa no texto:** PIB diferenciado pelo princípio do acelerador (a versão com PIB em taxa de crescimento vai como robustez, porque a elasticidade cai para 0,20); Cholesky com o investimento público primeiro, pela defasagem de decisão orçamentária (com a ordem invertida, o efeito vai a zero).

**Correções a fazer no texto antigo:** magnitude ("1% gera 2%" está errado), Granger (a Tabela 12 veio do VAR em nível; no VAR em diferença, p = 0,024; o p-valor de PVD → INF é 0,13, não 0,56), Johansen (25,01 < 25,32 não rejeita r = 0), datas da dummy (no arquivo: 2018T2–2019T1 e 2019T3–2019T4).

**Reconstrução da série de investimento público:** governo federal (filtro da dissertação) + Boletim da SEST reproduz o Ipub do Apêndice A de 2003 a 2019 (razão média 0,97; correlação 1,0 nas diferenças dos logs). A amostra nova começa em 2003.

## Dados disponíveis

**Governo federal (mensal)**, em `~/financas-publicas-br/dados/federal/`:
- `Novo documento (1).csv` (2,1 GB): SIGA Brasil bruto, nominal, com Ano, Mês/Ano, UF, Localidade, UO, Função, Subfunção, Programa, Ação, Modalidade, Elemento, Sub-elemento, GND, Fonte, "Pago + RP Pago". Ler com DuckDB (`all_varchar = true`).
- `federal_gnd4_mensal.csv` (37 MB): o bruto em GND 4, agregado por ano, mês, modalidade, elemento, função, subfunção, UF e tipo de localidade.
- `data/raw/federal_inv_direto_trimestral_nominal.csv`: série trimestral com o filtro da dissertação (modalidade 90; elementos: obras e instalações, equipamentos e material permanente, aquisição de imóveis, despesas de exercícios anteriores, sentenças judiciais, indenizações e restituições).
- **2017 falta no bruto**, mas existe no dashboard (`data/raw/dashboard_fed_q_bruto.csv`: ano, trimestre, função, grupo de modalidade 0 = direta, 1 = transferência, 2 = outra, R$ bi nominal, R$ bi de 2025), sem filtro de elemento. Ordem de preferência: (1) achar a extração-fonte do dashboard (pasta `tese_dashboard` ou o projeto do GitHub Pages; pergunte onde está), que deve ter elemento; (2) imputar 2017 pela execução direta do dashboard × razão filtro/dashboard (0,62 em 2016, 0,72 em 2018), com variável indicadora e robustez sem 2016T4–2018T1; (3) eu reextraio no SIGA.

**Estatais (trimestral)**, em `data/raw/`:
- `sest_boletim_trimestral_2003_2019.csv`: total Brasil e por região;
- `sest_oi_trimestral_2016_2025.csv`: por segmento, com a marca `grupo_petrobras`. A Petrobras é de 82% a 91% do total em cada ano.
- Na sobreposição 2016–2019, o OI fica 10% a 15% acima do boletim. Encadear pela razão média e testar a sensibilidade ao ano de encadeamento.

**Estados (anual)**, em `~/financas-publicas-br/dados/`:
- `raw/ano=AAAA/ente_XX.parquet` (2014 a 2024): DCA por estado (colunas `anexo`, `coluna`, `cod_conta`, `conta`, `valor`);
- `raw/msc/ano=AAAA/ente_XX.parquet` (2019 em diante): MSC com `funcao`, `subfuncao`, `nat` (natureza da despesa; GND 4 começa com "44") e `componente` (pago, RP pago etc.);
- `final/siconfi_investimento_repasses.parquet`: investimento total por estado, 2014 em diante (DCA).
- Não há série trimestral de estados antes de 2015. O RREO é bimestral (API do SICONFI), e bimestres não coincidem com trimestres.

**Outros**, em `data/raw/`: `fgv_ibre_investimento_anual.csv` (investimento anual por esfera e FBCF total, 1995 a 2025), `bndes_anual.csv`, `bndes_regiao_anual_colunas_a_confirmar.csv`, `dashboard_fator_ipca_anual.csv`. Os desembolsos mensais do BNDES não estão aqui: pergunte onde estão.

## Matriz de disponibilidade

| Quem investe | Tipo (econômica × social) | Frequência | Período |
|---|---|---|---|
| União, aplicação direta | sim, por função | mensal | 2001–2025 (2017 a resolver) |
| União, transferências de capital a estados e municípios | sim, por função | mensal | 2001–2025 |
| Estatais | por segmento (quase tudo econômica ou petróleo) | trimestral | 2003–2025 (Petrobras separada só a partir de 2016) |
| Estados, execução própria | total; por função só a partir de 2019 | anual | 2014–2024 |

**Ponto crítico para a comparação social × econômica:** na União, 70% da infraestrutura social passa por transferências (sobretudo a municípios), enquanto 92% da econômica é aplicação direta (somas nominais de 2003 a 2025). Usar só a modalidade 90, como na dissertação, subestima a infraestrutura social. Construa as séries nas duas versões: só direta (comparável à dissertação) e direta + transferências de capital.

Classificação por função (registre no LOG e me mostre antes de estimar):
- econômica: TRANSPORTE, ENERGIA, COMUNICAÇÕES;
- social: EDUCAÇÃO, SAÚDE, SANEAMENTO, HABITAÇÃO, URBANISMO, ASSISTÊNCIA SOCIAL, DESPORTO E LAZER;
- estatais: petróleo e gás separado; energia elétrica, transporte, portos e aeroportos como econômica.

## Regras de trabalho

- Use **R** (`vars`, `seasonal`, `strucchange`, `urca`, `fixest`, `lpirfs` ou OLS com `sandwich`, `fwildclusterboot`, `sidrar`, `rbcb`, `ipeadatar`, `duckdb`, `arrow`, `tidyverse`). Se algo faltar, avise antes de instalar.
- Nunca sobrescreva `data/original/` nem `data/raw/`. Downloads em `data/downloads/` (com a data no nome), tratados em `data/processed/`, resultados em `results/`.
- `set.seed(42)`; `sessionInfo()` em `results/session_info.txt`; cada decisão em `results/LOG.md`.
- Não invente resultados nem códigos de série. Antes de cada download, diga a fonte e o código e confira nos metadados.
- Nunca interpole séries anuais ou bimestrais para trimestral num VAR: o choque viria da regra de interpolação.

---

## Parte A. Séries nacionais trimestrais, 2003–2025

### A1. Portar a replicação para R
`R/A1_replica.R`, da última seção do `VAR_Trimestral.Rmd`, com `exogen = diff(exo)`. Deve reproduzir 0,0118 e 0,0194. Bootstrap com `runs = 2000`. Diagnósticos: Portmanteau ajustado, ARCH-LM multivariado, Jarque-Bera, raízes.

### A2. Baixar as séries por API
`R/A2_download.R`. Variáveis de **investimento privado e atividade** (o PVD da dissertação não é a única opção; estime com todas as que estiverem disponíveis):
1. indicador Ipea mensal de FBCF: máquinas e equipamentos (total), com os componentes **produção nacional** e **importação**, se publicados, e **construção civil** (a mais próxima de infraestrutura). Procure no Ipeadata (`ipeadatar`); se não houver, use a planilha da Carta de Conjuntura do Ipea;
2. produção industrial de **bens de capital** (IBGE, PIM-PF; confirme a tabela no SIDRA);
3. importação de **bens de capital** por categoria de uso (Comex Stat/MDIC);
4. desembolsos mensais do **BNDES** a empresas privadas (arquivo local; pergunte onde está);
5. validação anual: FBCF privada = FBCF total − setor público, com `fgv_ibre_investimento_anual.csv`.

Controles: PIB (SIDRA, índice de volume trimestral com ajuste sazonal; confirme a tabela, candidata 1621), Selic e IPCA (BCB/SGS; candidatos 432 e 433), câmbio real efetivo (BCB), preço do petróleo Brent ou índice de commodities, e o Indicador de Incerteza da Economia (FGV IBRE), se houver fonte aberta.

### A3. Séries de investimento público por esfera e tipo
`R/A3_investimento_publico.R`:
1. deflacionar a série federal pelo IPCA mensal, antes de agregar em trimestres;
2. **reconstruir INF** (federal com o filtro da dissertação + SEST boletim), aplicar X-11, índice e log10, e conferir contra `0224_tri_estmeq.txt` de 2003 a 2019 (correlação das diferenças);
3. estender até 2025 (resolver 2017; encadear o OI da SEST);
4. construir as séries de choque: União econômica e União social (direta, e direta + transferências), estatais (total; petróleo e sem petróleo a partir de 2016), e o agregado da dissertação;
5. gráfico de todas as séries e tabela de participações por ano.

### A4. Quebras estruturais
`R/A4_quebras.R`, antes de qualquer estimação final:
- **datas candidatas, conhecidas a priori:** 2008T4 (crise financeira), 2014T4–2015T1 (recessão e colapso do investimento da Petrobras com a Lava Jato), 2016T4–2017T1 (teto de gastos, EC 95), 2020T2 (pandemia), 2023T3 (novo arcabouço fiscal, LC 200/2023);
- **quebras nos dados:** troca do Boletim pelo OI da SEST (2016), imputação de 2017, e o padrão de execução concentrada no 4º trimestre em anos eleitorais (2018);
- **testes:** Bai-Perron com múltiplas quebras desconhecidas em cada série e em cada equação do VAR (`strucchange::breakpoints`, com intervalos de confiança das datas); sup-Wald de Andrews; Chow nas datas candidatas; OLS-CUSUM e MOSUM; raiz unitária com quebra (Zivot-Andrews e Lumsdaine-Papell ou Clemente-Montañés-Reyes);
- **na estimação:** estimativas recursivas e em janela móvel da resposta acumulada; subamostras antes e depois de 2014T4; dummies de quebra quando os testes indicarem.
Saída: `results/A_quebras.tex` e um parágrafo no LOG dizendo quais quebras importam para o resultado.

### A5. Estimação
`R/A5_estimacao.R`:
- baseline replicado e corrigido, na amostra 2003–2019 e na estendida;
- **projeções locais** de Jordà (2005), h = 0 a 12, Newey-West, com os choques da A3 ordenados antes da resposta; resposta de cada variável privada da A2 a cada choque;
- comparação principal: União econômica contra União social; aplicação direta contra transferência; estatais sem petróleo contra petróleo;
- multiplicador acumulado em reais (no estilo de Ramey e Zubairy, 2018), convertendo índices com a FBCF das Contas Nacionais Trimestrais;
- robustez: PIB em taxa de crescimento; ordem de Cholesky invertida; 2 a 4 defasagens; controles da A2, no máximo dois por vez; subamostras da A4.

### A6. Saídas para Halle
`results/A_robustez.tex`, `results/A_lp.tex`, figuras e `results/A_numeros_halle.md` (só números; eu escrevo o texto).

---

## Parte B. Painel de estados, anual (para 2027)

### B1. Investimento público por UF
- União por UF e tipo, 2003–2025 (parquet anual ou o bruto mensal agregado), separando aplicação direta e transferência de capital;
- estados, execução própria: total de 2014 a 2024 (DCA) e por função de 2019 em diante (MSC, GND 4);
- estatais: só há corte regional (Boletim da SEST); use em painel de regiões ou como controle;
- diagnóstico obrigatório: parcela do gasto federal atribuível a uma UF por tipo e ano (74% na econômica e 43% na social no acumulado; em transporte, a parcela cai muito depois de 2020, o que parece mudança de registro).

### B2. Resultados privados por UF
Emprego formal privado e estabelecimentos (RAIS; atenção à quebra metodológica do CAGED em 2020), PIB estadual e valor adicionado por setor (IBGE), consumo industrial de energia elétrica (EPE), desembolsos do BNDES a empresas privadas por UF. Confirme fontes e acesso comigo.

### B3. Identificação
Choque de Bartik (investimento nacional em cada tipo, excluindo o próprio estado, × participação do estado num período-base); efeitos fixos de UF e de ano; projeções locais em painel com `fixest`, h = 0 a 5; erros agrupados por UF com wild cluster bootstrap. Testes: pré-tendências, exclusão de SP, RJ e DF, exclusão de 2020–2021, direta contra transferência.

### B4. Saídas
`results/B_painel_descritivo.tex`, `results/B_lp.tex`, figuras e `results/B_numeros.md`, com um parágrafo honesto sobre as fragilidades.

## Limitações a manter visíveis

- O PVD é consumo aparente e inclui compras de governo e estatais; os componentes nacional e importado e a produção de bens de capital ajudam a medir o quanto disso é mecânico.
- A Petrobras domina o investimento das estatais.
- Estados só entram no painel anual, não nas séries trimestrais.
- Parte relevante do gasto federal não tem UF registrada.
