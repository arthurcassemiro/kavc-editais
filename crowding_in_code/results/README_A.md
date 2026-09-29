# Parte A: scripts e saidas

Rodar sempre da pasta `crowding_in_code/`: `Rscript R/<script>.R`. Todo script comeca com `source("R/00_setup.R")` (caminhos, protecao de `data/original` e `data/raw`, helpers de escrita, log e sessionInfo). Decisoes de cada etapa em `results/log_parts/<etapa>.md`; consolidacao em `results/LOG.md`.

## Ordem de execucao

1. `R/A1_replica.R`: replica o VAR da dissertacao a partir de `data/original` (bootstrap, diagnosticos, alvos das tabelas do texto).
2. `R/A2_download.R`: script mestre da A2. Roda `A2_download_bcb.R`, `A2_download_ibge.R`, `A2_download_ipea.R`, `A2_download_comex.R`, `A2_download_bndes.R` e `A2_validacao_anual.R` (helpers em `A2_util_ipea_comex_bndes.R`) e consolida a base trimestral. Com `--sem-download` (ou `A2_SEM_DOWNLOAD=1`) so reconstroi a base a partir de `data/processed`.
3. `R/A3_investimento_publico.R`: series de investimento publico por esfera e tipo (deflacao, X-11, indices, choques, reconstrucao do INF).
4. `R/A4_quebras.R`: testes de quebra estrutural e dummies para a A5.
5. `R/A5_estimacao.R`: script mestre da A5; roda `R/A5_var.R` (VAR replicado, corrigido e estendido, Johansen com Reinsel-Ahn e bootstrap, VEC, robustez) e `R/A5_lp.R` (projecoes locais, elasticidades, multiplicadores, comparacoes, robustez).
6. `R/A6_saidas.R`: tabelas, numeros, macros e figuras para Halle, so a partir dos CSV de `data/processed` e `results`.
7. Resumo estendido: `cd results && latexmk -pdf -auxdir=latex_aux -emulate-aux-dir A_extended_abstract.tex` (texto escrito a mao; todos os numeros vem de `A_numeros_macros.tex`).

## Saidas principais

| Etapa | Arquivos |
|---|---|
| A1 | `results/A1_replica.md`, `results/A1_replica.tex`, `results/figuras/A1_irf_acumulada.*`, `data/processed/A1_*.csv` |
| A2 | `data/processed/A2_series_trimestrais.csv`, `A2_metadados.csv` e demais `A2_*.csv`; `results/A2_resumo.md`, `results/A2_validacao_anual.*`, `results/figuras/A2_series.*` |
| A3 | `data/processed/A3_choques_wide.csv`, `A3_niveis_wide.csv`, `A3_choques_semao_wide.csv`, `A3_invpub_trimestral.csv`, `A3_metadados_series.csv`, `A3_dummies_outliers.csv`; `results/A3_*.md`, `results/A3_*.csv`, `results/A3_participacoes_ano.tex`, `results/figuras/A3_*` |
| A4 | `results/A_quebras.tex`, `results/A4_quebras.md`, `results/A4_quebras_resumo.csv`, `data/processed/A4_dummies_quebra*.csv`, `results/figuras/A4_recursivo.*` |
| A5 | `data/processed/A5_var_resultados.csv`, `A5_johansen.csv`, `A5_lp_irf.csv`, `A5_lp_cumulativo.csv`, `A5_lp_comparacoes.csv`; `results/A5_var.md`, `results/A5_lp.md`, `results/figuras/A5_*`; verificacao em `results/verificacao/` |
| A6 | `results/A_robustez.tex`, `results/A_lp.tex`, `results/A_numeros_halle.md`, `results/A_numeros_macros.tex`, `results/figuras/A6_fig1_econ_social.pdf`, `results/figuras/A6_fig2_direta_transf_estatais.pdf` (e png) |
| Resumo | `results/A_extended_abstract.tex` e `.pdf` (auxiliares em `results/latex_aux/`) |

As tabelas `A_robustez.tex`, `A_lp.tex` e `A_quebras.tex` pedem `\usepackage{booktabs}`; as da A6 tambem `\usepackage{adjustbox}`. `results/session_info.txt` traz o sessionInfo da ultima execucao; `results/session_info/` guarda um por script.
