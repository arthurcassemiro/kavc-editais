# Indicadores multidimensionais e faixas de porte na alocação territorial de creches no Paraná

Material completo do estudo empírico preparado para o dossiê "Consequências Econômicas do Planejamento Municipal" (Revista Paranaense de Desenvolvimento, nº 150, edição especial com o TCE-PR; prazo de submissão 30/09/2026).

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `00_originais/` | Planilhas e apresentação originais (intactas, com SHA-256), Resolução SEDEF 219/2024 e Deliberação CEDCA 25/2024 |
| `01_auditoria/` | `auditoria_planilhas.md` (fórmulas, abas, ausências, divergências, decisões de limpeza), dump de valores e fórmulas de todas as abas, cruzamento da aba "Municipios" |
| `02_base_tratada/` | `base_municipal.csv/.xlsx` (399 municípios, 70 variáveis), `base_municipal_geo.gpkg` (com geometria IBGE 2022), `dicionario_variaveis.csv`, Anexo I da Res. 219/2024 em CSV |
| `03_resultados/` | Tabelas T1 a T9 (porte, descritivas, correlações, beneficiados x não, quintis, mobilidade nos rankings, ajustes entre etapas, tipologia, regional, regressões exploratórias) e gráficos |
| `04_simulacoes/` | Alocação de 300 creches sob sete regras alternativas, métricas de cobertura/concentração/focalização e sobreposição com as distribuições observadas |
| `05_mapas/` | Mapa 1 (PCM e fatores, 2 × 2), Mapa 2 (tipologia) e mapas suplementares S1 a S4 em SVG editável, PDF vetorial e PNG 300 dpi; `dados_dos_mapas.xlsx`; subpasta `sem_rotulo/` com as versões do manuscrito (PNG e JPEG) |
| `06_diagramas/` | Figuras 1 e 2 (arquitetura do PCM e regra de conversão) e Figura S1 (etapas até a execução) em SVG, PDF e PNG |
| `07_log/` | `log_metodologico.md` e `levantamento_noticias.md` (linha do tempo, atos oficiais, ~80 fontes com URL, título, veículo e data) |
| `08_artigo/` | `artigo.md` (fonte do manuscrito), `artigo_creches_parana_anonimizado.docx` (22 páginas, Arial 12, espaçamento 1,5, ABNT, nota de rodapé, sem metadados de autoria), PDF de conferência, tabelas do artigo e `suplementares/` (XLSX com gráficos nativos e tabelas, SVG/PDF dos diagramas, JPEG 300 dpi dos mapas) |
| `scripts/` | Pipeline reprodutível (01 a 10) em Python; `09_politico_eleitoral.py` preparado para os arquivos do TSE |

## Reprodução

```
pip install openpyxl pandas geopandas matplotlib python-docx pdfplumber scipy statsmodels
python3 scripts/01_carregar_auditar.py && python3 scripts/02_base_tratada.py && python3 scripts/03_estatisticas.py
python3 scripts/04_simulacoes.py && python3 scripts/06_mapas.py && python3 scripts/07_diagramas.py && python3 scripts/08_graficos.py
MAPAS_SEM_ROTULO=1 python3 scripts/06_mapas.py   # versões sem título/fonte para o manuscrito (idem 07 e 08)
python3 scripts/10_docx.py
```

Os scripts esperam a fonte IBM Plex Sans e a malha municipal IBGE 2022 nos caminhos indicados em `scripts/estilo.py` e `scripts/02_base_tratada.py`.
