# Log metodológico

Registro cronológico das decisões, procedimentos e verificações do estudo "Indicadores multidimensionais e faixas municipais na distribuição territorial de creches no Paraná". Todos os scripts estão em `scripts/` e rodam em sequência (01 a 08); a base tratada e os resultados são regenerados integralmente a partir dos originais em `00_originais/`.

## Ambiente
Python 3.11; pandas 3.0.6; geopandas 1.2.0; matplotlib 3.11; statsmodels; openpyxl 3.1.5. Fonte IBM Plex Sans 1.1.0 (IBM, licença OFL). Malha municipal IBGE 2022 (`PR_Municipios_2022.shp`, SIRGAS 2000, EPSG:4674; mapas projetados em EPSG:5880). Divisões regionais (mesorregiões, regiões intermediárias e imediatas) obtidas da API de localidades do IBGE.

## Etapas

1. Leitura das normas da revista (Arial 12, espaçamento 1,5, A4, margens 2,5 cm, 12 a 22 páginas, título com até 15 palavras, resumo de 100 a 250 palavras com cinco palavras-chave nos três idiomas, sistema autor-data ABNT NBR 6023, arquivo Word/ODT anonimizado, no máximo quatro autores) e da chamada do dossiê "Consequências Econômicas do Planejamento Municipal" (prazo 30/09/2026, publicação em novembro de 2026, preferência por trabalhos com dados abertos).
2. Preservação dos originais com hash SHA-256 e exportação de valores e fórmulas de todas as abas (`01_auditoria/dump/`).
3. Reconstrução das fórmulas do PCM, dos fatores e das duas distribuições (`scripts/01_carregar_auditar.py`); resultados em `01_auditoria/auditoria_planilhas.md` e `log_carregamento.txt`.
4. Construção da base municipal (`scripts/02_base_tratada.py`): junção por código IBGE, regiões, variantes do PCM, etapas de distribuição, tipologia e rankings. Dicionário em `02_base_tratada/dicionario_variaveis.csv`.
5. Estatísticas descritivas, comparações e mobilidade nos rankings (`scripts/03_estatisticas.py`), tabelas T1 a T8 em `03_resultados/`.
6. Simulações contrafactuais com 300 creches (`scripts/04_simulacoes.py`): S1 população total; S2 população 0–4; S3 ranking do fator socioeconômico (uma creche para cada um dos 300 municípios de maior FS); S3b proporcional a população 0–4 × FS; S4 proporcional a população 0–4 × PCM; S4b ranking do PCM; S5 regra consolidada com as cotas por faixa reescaladas para 300 (117 para G2–P4, 31 para P3, 117 para P2, 35 para P1). Alocações proporcionais usam o método do maior resto (Hamilton) com tetos por porte quando aplicável.
7. Mapas (`scripts/06_mapas.py`), diagramas (`scripts/07_diagramas.py`) e gráficos (`scripts/08_graficos.py`) exportados em SVG editável (texto como texto), PDF vetorial e PNG 300 dpi, com os dados de cada mapa em `05_mapas/dados_dos_mapas.xlsx`.
8. Levantamento documental de notícias e atos oficiais (`07_log/levantamento_noticias.md`), com leitura integral de 21 atos da SEDEF e do CEDCA. O Anexo I da Resolução SEDEF 219/2024 foi extraído e incorporado à base como terceira etapa (lista publicada: 303 creches, 261 municípios); ver auditoria, item 6.
9. Redação do artigo após o fechamento dos números; geração do DOCX anonimizado (`08_artigo/`).

## Decisões relevantes

- Lista publicada = Anexo I da Resolução SEDEF 219/2024 (303 creches, 261 municípios), que é o ato com efeitos jurídicos sobre a elegibilidade. Habilitação, licitação, obras e entregas são etapas posteriores, documentadas apenas por atos e notícias (não há base municipal pública consolidada de execução).
- Distribuição técnica inicial = coluna TOTAL CRECHES da aba CI do arquivo Indicador_Criterio_VF (251 creches, 209 municípios). Distribuição consolidada = aba Resultados do arquivo 20240327_Distribuicao_Creches (300 creches, 224 municípios). A denominação "técnica inicial" e "consolidada" segue a ordem lógica dos arquivos (o segundo incorpora a etapa prévia, tetos, cotas e a reclassificação dos portes); não há data no primeiro arquivo.
- População-alvo nas estatísticas: população de 0 a 4 anos (Censo 2022), coluna da aba Educacional. Ver auditoria, item 4.
- Quintis de PCM e de população 0–4 com cerca de 80 municípios cada.
- Regressões exploratórias (OLS com erros robustos e logit) apenas para descrever associações entre número de creches, PCM e log da população 0–4, com dummies de mesorregião; não há interpretação causal.
- Não atribuímos motivação aos registros da aba "Municipios" nem aos ajustes entre etapas.

## O que não foi possível fazer

- Análise político-eleitoral: os repositórios de dados do TSE (cdn.tse.jus.br e dadosabertos.tse.jus.br), a API do CepespData e o portal de resultados retornaram HTTP 403/404 a partir do ambiente de execução. O script `scripts/09_politico_eleitoral.py` está preparado para rodar quando os arquivos `votacao_candidato_munzona_2020_PR.csv` e `votacao_candidato_munzona_2022_PR.csv` forem colocados em `02_base_tratada/tse/`; ele calcula o partido do prefeito eleito em 2020, o percentual do governador reeleito em 2022 por município e cruza com a tipologia e com o número de creches, com testes de diferença de médias. Os resultados devem ser lidos apenas como associações descritivas.
- Reprodução exata da regra de redução para 100 creches no bloco de municípios grandes (28 de 30 valores reproduzidos).
- Reprodução exata de três subnormalizações do fator educacional e do demográfico (valores digitados nas planilhas).

## Manuscrito

Gerado por `scripts/10_docx.py` a partir de `08_artigo/artigo.md`: A4, margens de 2,5 cm, Arial 12, espaçamento 1,5, recuo de 1,5 cm, títulos e resumos em português, inglês e espanhol, cinco palavras-chave, citações autor-data e referências ABNT NBR 6023, tabelas e figuras inseridas no corpo com legenda e fonte. Metadados de autoria removidos. Conferência de paginação por conversão para PDF no LibreOffice: 22 páginas (limite da revista: 12 a 22). Título com 12 palavras. Figuras usadas no manuscrito em `05_mapas/sem_rotulo/`, `06_diagramas/sem_rotulo/` e `03_resultados/figuras/sem_rotulo/`; os originais com título e fonte embutidos permanecem nas pastas principais. Mapas 3, 4, 5, 6, 8, 9 e 10 e o Gráfico 3 não entraram no manuscrito por limite de páginas e ficam como material suplementar.

## Ajuste de enquadramento solicitado durante o trabalho

O artigo trata a metodologia como instrumento de alocação sob escassez e registra explicitamente que o estudo serviu de base à decisão sem que o resultado final coincida integralmente com a seleção do modelo: a lista publicada acrescentou 37 municípios logo abaixo da linha de corte, sem retirar nenhum selecionado, o que é descrito como a margem entre a seleção do modelo e a decisão, na qual entram necessidades e negociação político-institucional que o índice não capta.
