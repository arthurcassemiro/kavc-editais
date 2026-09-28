# Etapa A2, validacao anual (item 5 do briefing): FBCF privada = FBCF total - setor publico
# (data/raw/fgv_ibre_investimento_anual.csv) contra as medias anuais das series mensais do
# Indicador Ipea de FBCF (total, M&E, construcao, outros). Nada e interpolado.
# Requer data/processed/A2_ipea_mensal.csv (R/A2_download_ipea.R).
# Saidas: results/A2_validacao_anual.csv e results/A2_validacao_anual.md.
# Rodar da raiz do projeto: Rscript R/A2_validacao_anual.R

source("R/00_setup.R")
source("R/A2_util_ipea_comex_bndes.R")
suppressPackageStartupMessages(library(ipeadatar))
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

MARCA <- "#### Validacao anual"
log_secao_inicio(MARCA, "A2_validacao_anual")
sem_acento <- function(x) iconv(x, "UTF-8", "ASCII//TRANSLIT")

# ---------------------------------------------------------------------------
# 1. Investimento por esfera (FGV IBRE) e identidades contabeis
# ---------------------------------------------------------------------------
fgv <- read_csv(file.path(PATHS$raw, "fgv_ibre_investimento_anual.csv"), show_col_types = FALSE) %>%
  rename(ano = y) %>% mutate(ano = as.integer(ano))
stopifnot(identical(names(fgv), c("ano", "GC", "GE", "GM", "EPU", "SP", "GG", "FBCF")))
fgv <- fgv %>% mutate(dif_gg = GG - (GC + GE + GM), dif_sp = SP - (GG + EPU))
TOL <- 0.005  # valores com 3 casas decimais
lp(sprintf("- data/raw/fgv_ibre_investimento_anual.csv: %d anos (%d a %d), R$ bilhoes nominais. GG = GC + GE + GM: diferenca maxima em modulo %s (anos fora da tolerancia de %s: %s). SP = GG + EPU: diferenca maxima %s (fora da tolerancia: %s).",
           nrow(fgv), min(fgv$ano), max(fgv$ano), num_br(max(abs(fgv$dif_gg)), 4), num_br(TOL, 3),
           ifelse(any(abs(fgv$dif_gg) > TOL), paste(fgv$ano[abs(fgv$dif_gg) > TOL], collapse = ", "), "nenhum"),
           num_br(max(abs(fgv$dif_sp)), 4),
           ifelse(any(abs(fgv$dif_sp) > TOL), paste(fgv$ano[abs(fgv$dif_sp) > TOL], collapse = ", "), "nenhum")))

# ---------------------------------------------------------------------------
# 2. Deflator implicito da FBCF (IBGE, Contas Nacionais anuais, via Ipeadata)
# ---------------------------------------------------------------------------
CAND <- tribble(
  ~serie,               ~codigo,         ~esperado,
  "fbcf_nominal_ibge",  "SCN10_FBKFN10", "^PIB - FBCF$",
  "fbcf_var_real_ibge", "SCN10_FBKFG10", "^PIB - FBCF - var real anual$"
)
meta <- metadata(CAND$codigo, language = "br") %>% mutate(across(everything(), as.character)) %>%
  transmute(codigo = code, titulo = name, fonte = source, freq = freq,
            unidade = trimws(paste(ifelse(is.na(unity), "", unity), ifelse(is.na(mf), "", mf))))
meta <- CAND %>% left_join(meta, by = "codigo") %>%
  mutate(confere = str_detect(sem_acento(titulo), esperado) & freq == "Anual" & grepl("IBGE/SCN", fonte))
print(meta)
stopifnot(all(meta$confere))
arq <- c()
scn <- list()
for (i in seq_len(nrow(meta))) {
  d <- ipeadata(meta$codigo[i], language = "br", quiet = TRUE) %>% select(code, date, value)
  f <- download_path("ipeadata", meta$codigo[i])
  write_csv_safe(d, f)
  arq[meta$serie[i]] <- f
  scn[[meta$serie[i]]] <- d %>% transmute(ano = as.integer(format(date, "%Y")), !!meta$serie[i] := value)
}
for (i in seq_len(nrow(meta))) {
  lp(sprintf("  - Ipeadata %s: \"%s\"; fonte %s; periodicidade %s; unidade \"%s\"; confere. Bruto em %s.",
             meta$codigo[i], sem_acento(meta$titulo[i]), meta$fonte[i], meta$freq[i], sem_acento(meta$unidade[i]), arq[meta$serie[i]]))
}
ibge <- reduce(scn, full_join, by = "ano")
chk <- fgv %>% inner_join(ibge, by = "ano") %>% mutate(r = FBCF / (fbcf_nominal_ibge / 1e3))
lp(sprintf("- A coluna FBCF do arquivo da FGV e a FBCF nominal do IBGE (SCN10_FBKFN10, R$ milhoes): razao entre %s e %s em %d anos. O deflator implicito da FBCF sai de (1 + variacao nominal) / (1 + variacao real do SCN10_FBKFG10) - 1 e e aplicado tambem a FBCF privada e a do setor publico (hipotese: mesmo deflator; nao ha deflator por setor institucional).",
           num_br(min(chk$r), 5), num_br(max(chk$r), 5), nrow(chk)))

# ---------------------------------------------------------------------------
# 3. Medias anuais das series mensais do Ipea (so anos com 12 meses)
# ---------------------------------------------------------------------------
ipea <- read_csv(file.path(PATHS$processed, "A2_ipea_mensal.csv"), show_col_types = FALSE)
SERIES <- c(ipea_total = "fbcf_total_nsa", ipea_me = "fbcf_me_nsa", ipea_constr = "fbcf_constr_nsa", ipea_outros = "fbcf_outros_nsa")
ipea_a <- ipea %>% mutate(ano = as.integer(substr(periodo, 1, 4))) %>%
  select(ano, all_of(SERIES)) %>%
  group_by(ano) %>%
  summarise(n_meses = sum(!is.na(ipea_total)), across(all_of(names(SERIES)), mean), .groups = "drop") %>%
  filter(n_meses == 12) %>% select(-n_meses)

# ---------------------------------------------------------------------------
# 4. Tabela anual e variacoes
# ---------------------------------------------------------------------------
v <- function(x) 100 * (x / lag(x) - 1)
tab <- fgv %>% select(ano, GC, GE, GM, EPU, SP, GG, FBCF, dif_gg, dif_sp) %>%
  left_join(ibge, by = "ano") %>% left_join(ipea_a, by = "ano") %>% arrange(ano) %>%
  mutate(fbcf_privada = FBCF - SP,
         part_setor_publico_pct = 100 * SP / FBCF,
         var_fbcf_nominal = v(FBCF),
         var_fbcf_real_ibge = fbcf_var_real_ibge,
         var_deflator_fbcf = 100 * ((1 + var_fbcf_nominal / 100) / (1 + var_fbcf_real_ibge / 100) - 1),
         var_privada_nominal = v(fbcf_privada),
         var_privada_real = 100 * ((1 + var_privada_nominal / 100) / (1 + var_deflator_fbcf / 100) - 1),
         var_sp_real = 100 * ((1 + v(SP) / 100) / (1 + var_deflator_fbcf / 100) - 1),
         across(all_of(names(SERIES)), v, .names = "var_{.col}")) %>%
  select(ano, GC, GE, GM, EPU, SP, GG, FBCF, dif_gg, dif_sp, fbcf_privada, part_setor_publico_pct,
         var_fbcf_nominal, var_fbcf_real_ibge, var_deflator_fbcf, var_privada_nominal, var_privada_real, var_sp_real,
         all_of(names(SERIES)), starts_with("var_ipea"))
write_csv_safe(tab, file.path(PATHS$results, "A2_validacao_anual.csv"))

estat <- function(de, ate) {
  x <- tab %>% filter(ano >= de, ano <= ate, !is.na(var_ipea_total), !is.na(var_privada_real))
  alvo <- c(var_ipea_total = "Ipea total", var_ipea_me = "Ipea M&E", var_ipea_constr = "Ipea construcao",
            var_ipea_outros = "Ipea outros")
  bind_rows(
    map_dfr(names(alvo), function(s) tibble(
      periodo = sprintf("%d-%d", min(x$ano), max(x$ano)), n = nrow(x), referencia = "FBCF privada real",
      serie = alvo[[s]], correlacao = cor(x$var_privada_real, x[[s]]),
      dif_media_abs_pp = mean(abs(x[[s]] - x$var_privada_real)),
      mesmo_sinal = sum(sign(x[[s]]) == sign(x$var_privada_real)))),
    tibble(periodo = sprintf("%d-%d", min(x$ano), max(x$ano)), n = nrow(x), referencia = "FBCF total real (IBGE)",
           serie = "Ipea total", correlacao = cor(x$var_fbcf_real_ibge, x$var_ipea_total),
           dif_media_abs_pp = mean(abs(x$var_ipea_total - x$var_fbcf_real_ibge)),
           mesmo_sinal = sum(sign(x$var_ipea_total) == sign(x$var_fbcf_real_ibge))),
    tibble(periodo = sprintf("%d-%d", min(x$ano), max(x$ano)), n = nrow(x), referencia = "FBCF total real (IBGE)",
           serie = "FBCF privada real", correlacao = cor(x$var_fbcf_real_ibge, x$var_privada_real),
           dif_media_abs_pp = mean(abs(x$var_privada_real - x$var_fbcf_real_ibge)),
           mesmo_sinal = sum(sign(x$var_privada_real) == sign(x$var_fbcf_real_ibge)))
  )
}
est <- bind_rows(estat(1997, 2025), estat(2003, 2025), estat(2003, 2019))
print(est)
write_csv_safe(est, file.path(PATHS$results, "A2_validacao_anual_estatisticas.csv"))

# ---------------------------------------------------------------------------
# 5. Relatorio em markdown
# ---------------------------------------------------------------------------
f1 <- function(x) ifelse(is.na(x), "", num_br(x, 1))
linhas_tab <- tab %>% filter(ano >= 1997) %>%
  transmute(l = sprintf("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", ano, num_br(FBCF, 1), num_br(SP, 1),
                        num_br(fbcf_privada, 1), f1(part_setor_publico_pct), f1(var_fbcf_real_ibge), f1(var_privada_real),
                        f1(var_ipea_total), f1(var_ipea_me), f1(var_ipea_constr), f1(var_ipea_outros))) %>% pull(l)
linhas_est <- est %>% transmute(l = sprintf("| %s | %d | %s | %s | %s | %s | %d |", periodo, n, referencia, serie,
                                            num_br(correlacao, 2), num_br(dif_media_abs_pp, 1), mesmo_sinal)) %>% pull(l)
md <- c(
  "# A2. Validacao anual: FBCF privada contra o Indicador Ipea de FBCF",
  "",
  sprintf("Gerado por R/A2_validacao_anual.R em %s.", format(Sys.time(), "%Y-%m-%d %H:%M")),
  "",
  "Fontes: data/raw/fgv_ibre_investimento_anual.csv (investimento por esfera e FBCF total, R$ bilhoes nominais);",
  "IBGE, Contas Nacionais anuais, via Ipeadata (SCN10_FBKFN10, FBCF nominal; SCN10_FBKFG10, variacao real da FBCF);",
  "data/processed/A2_ipea_mensal.csv (Indicador Ipea de FBCF sem ajuste sazonal, media dos 12 meses do ano).",
  "",
  "Definicoes:",
  "",
  sprintf("- Identidades conferidas: GG = GC + GE + GM (diferenca maxima %s) e SP = GG + EPU (diferenca maxima %s), em R$ bilhoes.",
          num_br(max(abs(tab$dif_gg)), 4), num_br(max(abs(tab$dif_sp)), 4)),
  "- FBCF privada = FBCF - SP (nominal).",
  "- Variacao real da FBCF privada: variacao nominal deflacionada pelo deflator implicito da FBCF total do IBGE (mesmo deflator para os setores).",
  "- Series do Ipea: variacao da media anual dos indices mensais sem ajuste sazonal; anos com 12 meses; nada interpolado.",
  "",
  "## Niveis (R$ bilhoes nominais) e variacoes anuais (%)",
  "",
  "| Ano | FBCF (R$ bi) | Setor publico (R$ bi) | FBCF privada (R$ bi) | Publico/FBCF (%) | Var. FBCF real IBGE (%) | Var. FBCF privada real (%) | Var. Ipea total (%) | Var. Ipea M&E (%) | Var. Ipea construcao (%) | Var. Ipea outros (%) |",
  "|---|---|---|---|---|---|---|---|---|---|---|",
  linhas_tab,
  "",
  "## Aderencia das variacoes anuais",
  "",
  "| Periodo | Anos | Referencia | Serie | Correlacao | Diferenca media absoluta (p.p.) | Anos com mesmo sinal |",
  "|---|---|---|---|---|---|---|",
  linhas_est,
  "",
  "Tabelas completas: results/A2_validacao_anual.csv e results/A2_validacao_anual_estatisticas.csv."
)
writeLines(md, file.path(PATHS$results, "A2_validacao_anual.md"))

g <- function(p, s, r = "FBCF privada real") est %>% filter(periodo == p, serie == s, referencia == r)
p1 <- est$periodo[1]
lp(sprintf("- FBCF privada = FBCF - SP. Participacao do setor publico na FBCF: %s%% em 2003, %s%% em 2010, %s%% em 2017, %s%% em 2025 (minimo %s%% em %d, maximo %s%% em %d).",
           num_br(tab$part_setor_publico_pct[tab$ano == 2003], 1), num_br(tab$part_setor_publico_pct[tab$ano == 2010], 1),
           num_br(tab$part_setor_publico_pct[tab$ano == 2017], 1), num_br(tab$part_setor_publico_pct[tab$ano == 2025], 1),
           num_br(min(tab$part_setor_publico_pct), 1), tab$ano[which.min(tab$part_setor_publico_pct)],
           num_br(max(tab$part_setor_publico_pct), 1), tab$ano[which.max(tab$part_setor_publico_pct)]))
for (p in unique(est$periodo)) {
  lp(sprintf("- %s: correlacao da variacao real da FBCF privada com a variacao da media anual do Ipea total %s, M&E %s, construcao %s, outros %s (diferenca media absoluta %s, %s, %s e %s p.p.). Ipea total contra a FBCF real do IBGE: %s. FBCF privada real contra FBCF total real: %s.",
             p, num_br(g(p, "Ipea total")$correlacao, 2), num_br(g(p, "Ipea M&E")$correlacao, 2),
             num_br(g(p, "Ipea construcao")$correlacao, 2), num_br(g(p, "Ipea outros")$correlacao, 2),
             num_br(g(p, "Ipea total")$dif_media_abs_pp, 1), num_br(g(p, "Ipea M&E")$dif_media_abs_pp, 1),
             num_br(g(p, "Ipea construcao")$dif_media_abs_pp, 1), num_br(g(p, "Ipea outros")$dif_media_abs_pp, 1),
             num_br(g(p, "Ipea total", "FBCF total real (IBGE)")$correlacao, 2),
             num_br(g(p, "FBCF privada real", "FBCF total real (IBGE)")$correlacao, 2)))
}
dmax <- with(tab %>% filter(!is.na(var_ipea_total), !is.na(var_fbcf_real_ibge)), max(abs(var_ipea_total - var_fbcf_real_ibge)))
lp(sprintf("- A variacao da media anual do Ipea total coincide com a variacao real anual da FBCF do IBGE (diferenca maxima %s p.p.): o indicador mensal e ancorado nas Contas Nacionais. Assim, a distancia entre Ipea total e FBCF privada real mede so o peso do setor publico, e as componentes (M&E, construcao, outros) sao a parte informativa da validacao.",
           sub(".", ",", sprintf("%.1e", dmax), fixed = TRUE)))
lp("- Saidas: results/A2_validacao_anual.csv (tabela anual), results/A2_validacao_anual_estatisticas.csv e results/A2_validacao_anual.md.")

meta_out <- meta %>% transmute(
  serie, fonte = "Ipeadata (IBGE/SCN)", codigo, titulo_nos_metadados = titulo, unidade, periodicidade = freq,
  periodo = map_chr(serie, ~ sprintf("%d a %d", min(scn[[.x]]$ano), max(scn[[.x]]$ano))),
  url = sprintf("https://www.ipeadata.gov.br/api/odata4/ValoresSerie(SERCODIGO='%s')", codigo),
  arquivo_download = unname(arq[serie]),
  transformacao = "anual; so para o deflator implicito da FBCF na validacao anual (nao vai para as series trimestrais)")
gravar_metadados(meta_out, "Ipeadata (IBGE/SCN)")

log_secao_fim()
save_session_info("A2_validacao_anual")
cat("A2_validacao_anual.R concluido.\n")
