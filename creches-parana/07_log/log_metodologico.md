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

## Revisão editorial da parte visual (28/09/2026, segunda versão)

Aplicada a crítica de visualização editorial recebida após a primeira versão:
- Tabelas reconstruídas com estilo próprio (Arial 9, recuo zero nas células, cabeçalho em dois níveis com células mescladas, cabeçalho repetido, linhas indivisíveis, casas decimais fixas por coluna, unidades no rótulo das linhas da Tabela 2, traço para zero, fio no total). A antiga Tabela 3 (ajustes) foi fundida na Tabela 1 como colunas de variação; a Tabela 4 (regional) ganhou a linha do Paraná.
- Elementos reduzidos de 15 para 10: Figuras 1 e 2, Mapa 1 (PCM e três fatores em grade 2 × 2), Mapa 2 (tipologia), Gráfico 1 (cenários), Tabelas 1 a 4 e Quadro 1 (etapas até a execução, no lugar da antiga Figura 3). Mapas das faixas de porte, das três etapas, das diferenças e da intensidade por criança e o gráfico de pontos por porte passaram ao material suplementar (`05_mapas/mapaS1..S4`, `03_resultados/figuras/graficoS1, graficoS2`, `06_diagramas/diagramaS1`).
- Figuras regeradas no tamanho final (16 cm, ou 14 cm no Mapa 1), com corpo mínimo de 7 pt, Arial (Liberation Sans), vírgula decimal, classes sem repetição de limites, contorno estadual pela malha de UF do IBGE 2022, limites municipais cinza 0,3 pt, escala e norte uma vez por figura, caixas de diagrama com altura automática e setas terminando na borda.
- Sistema de cores com um sentido por cor: laranja (FE), azul (FD) e verde (FS) tomados da apresentação do programa; roxo para o PCM; cinzas em ordem de luminosidade para as três etapas; acento único (#B2182B) para a margem decisória (37 municípios acrescidos na lista publicada); hachura para exclusões e reduções.
- Cenários renumerados S1 a S7 (proporcionais, rankings, regra com faixas); eixo do Gráfico 1 em "% das unidades distribuídas"; rótulos com linhas de chamada e legenda de forma.
- Divergências corrigidas: creches por 10 mil crianças no porte P1 (17,5); legenda do antigo Mapa 4 ("+3 a +16") substituída por classes corretas (máximo +3); referências das fontes das ilustrações (malha IBGE, Censo Escolar, Datasus, Ministério da Saúde, IPDM, taxa de natalidade) e das Resoluções SEDEF 285/2024, 029/2025 e 075/2025 incluídas; frase sobre os dados eleitorais reescrita como limitação de dados.
- Nota de rodapé na primeira menção ao material suplementar, com link omitido para avaliação cega (implementada no DOCX via parte footnotes.xml).
- Arquivos editáveis para a submissão em `08_artigo/suplementares/` (XLSX com gráficos nativos e tabelas, SVG/PDF dos diagramas, JPEG 300 dpi dos mapas).
- Paginação verificada no LibreOffice: 22 páginas; DOCX de 0,8 MB sem metadados de autoria.

## Versão 3 (29/09/2026): reenquadramento do artigo com foco no PCM

- Nova estrutura (21 páginas, 7.197 palavras com referências): introdução com função alocativa do Estado e infraestrutura social; creche como política pública (evidência internacional e responsabilidade federativa, com citações diretas longas em formato ABNT); programa (base legal, PPA 2024-2027 entrega 4670, CEDCA, resoluções SEDEF como linha de base, modalidade fundo a fundo e dimensão fiscal, cobertura e benchmarking); PCM (pilares, normalização, ponderação, equações 1 a 5, comparação com o INC, sensibilidade); aplicação (equações 6 a 10, maior resto, tetos, Tabela 2); discussão e conclusões. O foco passou ao indicador; a comparação entre versões das planilhas ficou restrita a uma tabela e ao material suplementar.
- Novos originais: `20240521_Distribuicao_Creches_Conferencia.xlsx` (versão levada ao CEDCA; aba oculta Conferência mostra que a lista de 300 creches em 258 municípios decorre de tetos menores nos portes grandes; a Resolução 219/2024 acrescentou 3 municípios) e `Base_entregas_PPA_18_12_2023.xlsx` (entrega 4670: 72 municípios/ano em 2024-2026). Auditoria: seções 7 e 8. Base tratada: variáveis `cedca_258` e `dif_pub_cedca` (`scripts/02b_base_conferencia.py`).
- Modalidade de pagamento verificada nas Resoluções SEDEF 212/2024 e 029/2025: incentivo financeiro fundo a fundo (FIA/PR aos fundos municipais), termo de adesão, cinco parcelas (10%, 20%, três iguais após 40%, 70% e 100%), custo excedente e custeio por conta do município; não há convênio nem operação de crédito.
- Diagramas editáveis (SVG e PPTX) em `06_diagramas/`: figura_institucional, figura_calculo_ponderado, figura_perguntas_pcm, figura_perguntas_aplicacao (`scripts/11_diagramas_institucional.py`). Gerador do DOCX com blocos `EQ:` (equações numeradas, com subscritos) e `CIT:` (citação direta longa, recuo de 4 cm, fonte 10).
- Levantamento de literatura, legislação, benchmarking e contexto em `07_log/levantamento_literatura_contexto.md`.
- Pendências: o artigo ficou com 21 páginas (limite do dossiê: 22; meta interna de 20); a Casa Civil não é citada como autora da metodologia nas referências; as figuras de perguntas da aplicação e os gráficos de cenários ficaram no material suplementar.

## Versão 4 (29/09/2026): estudo de caso metodológico e institucional

- Reposicionamento: pergunta (como converter evidências em regra efetiva de alocação), objetivo (reconstruir, sistematizar e analisar o indicador e o método de distribuição) e contribuição (indicador que ultrapassou a função informacional). Vocabulário: impacto alocativo, consequências distributivas, efeito sobre a seleção territorial; avaliação ex ante da regra por reconstrução documental, auditoria das planilhas e sensibilidade.
- Seção do PCM com subseções por pilar (fontes, equação com coeficientes numéricos, mapa por pilar em `05_mapas/mapa_fe_educacional`, `mapa_fd_demografico`, `mapa_fs_socioeconomico`, `mapa_pcm`; `scripts/06b_mapas_pilares.py`) e posição do Paraná no Brasil; perguntas no início da metodologia; ponderação apresentada em diagrama.
- Diagramas editáveis no próprio DOCX: construídos como tabelas do Word (`scripts/diagramas_word.py`, bloco `DIAGRAMA:` em `10_docx.py`), sem sobreposição; versões SVG/PPTX no material suplementar. Equações nativas do Word (OMML) via `scripts/omml.py` (bloco `EQ:` com sintaxe LaTeX reduzida).
- Figura institucional dividida em processo decisório (Figura 1) e fluxo financeiro (Figura 2); Figura 6 com o mecanismo Dados → PCM → faixas e parâmetros → deliberação → lista → alocação.
- Tabela 1 movida aos resultados; Tabela 3 de cenários contrafactuais reduzida (S2, S6 e versões da regra, incluindo a de 21/05/2024, coluna "Total (mai/2024)" da Tabela 2, conferida contra a aba Conferência).
- Anexo IV do ajustamento do PPA (LDO 2026), enviado pelo autor, não trata de creches; usado para descrever o processo de revisão anual (`07_log/leitura_revisao_ppa.md`).
- Versão cega: retirada a frase sobre a participação de autor na construção da metodologia; metadados do DOCX limpos.
- Números estaduais por pilar (v4): creche 0–3 em 2024, PR 42,0% vs BR 41,2%, 4ª UF (Anuário TPE 2025); mortalidade infantil 2023, PR 10,8‰ vs BR 12,6‰, 3ª menor (SIM/Sinasc, cálculo próprio); natalidade 2023, PR 12,2‰ vs 12,5‰; população 0–4, PR 6,10% vs 6,26% (Censo 2022); renda domiciliar per capita 2024, PR R$ 2.482 vs R$ 2.069, 6ª maior (IBGE); pobreza 2024, PR 13,9% vs 23,4%, 4ª menor (IJSN/PNAD). Não confirmados por UF: CadÚnico 0–6, Sisvan baixo peso, matrículas de creche por rede (INEP bloqueado por TLS). Detalhes em `07_log/levantamento_revisao_v4.md`.
- Pendências: paginação do cap. 1 de Musgrave e Musgrave (1980) não confirmada (citado como "cap. 1"); notícias AEN originais retornam 404, espelhos indicados na nota de rodapé; artigo com 22 páginas (limite do dossiê), 0,58 MB.
