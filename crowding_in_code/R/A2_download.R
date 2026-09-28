# Etapa A2, script mestre e consolidacao da base trimestral.
# 1. Roda, em ordem, os modulos de download da A2 (cada um dentro de tryCatch, com registro de falhas):
#    R/A2_download_bcb.R, R/A2_download_ibge.R, R/A2_download_ipea.R, R/A2_download_comex.R,
#    R/A2_download_bndes.R e R/A2_validacao_anual.R.
# 2. Constroi a base unica a partir de data/processed:
#    data/processed/A2_series_trimestrais.csv (2002Q1 a 2025Q4, coluna trimestre "2003Q1") e
#    data/processed/A2_metadados.csv (uma linha por variavel final).
# 3. Escreve results/A2_resumo.md, results/A2_correlacoes_privadas.csv e results/figuras/A2_series.{png,pdf}.
# Uso, da raiz do projeto:
#   Rscript R/A2_download.R                      roda os modulos (baixa tudo de novo) e reconstroi a base
#   Rscript R/A2_download.R --sem-download       pula os modulos e so reconstroi a base a partir de data/processed
#   A2_SEM_DOWNLOAD=1 Rscript R/A2_download.R    idem (evita baixar de novo os 720 MB do BNDES)

source("R/00_setup.R")
suppressPackageStartupMessages(library(patchwork))

# Nomes proprios deste script (os modulos definem ETAPA, lp e num_br no ambiente global).
ETAPA_CONS <- "A2_consolidacao"
SEM_DOWNLOAD <- "--sem-download" %in% commandArgs(trailingOnly = TRUE) ||
  identical(Sys.getenv("A2_SEM_DOWNLOAD"), "1")
Q_INI <- "2002Q1"
Q_FIM <- "2025Q4"
X11_INI <- "2000Q1"          # janela do X-11 das series ajustadas aqui: 2000Q1 a 2025Q4
TRI <- q_seq(Q_INI, Q_FIM)
qn <- function(k) as.numeric(q_to_yearqtr(k))

lc <- function(...) log_part(ETAPA_CONS, ...)
nb <- function(x, d = 3) formatC(round(x, d) + 0, format = "f", digits = d, decimal.mark = ",", big.mark = ".")
nsci <- function(x) sub(".", ",", formatC(x, format = "e", digits = 1), fixed = TRUE)

log_reset(ETAPA_CONS)
lc(sprintf("- Script mestre R/A2_download.R. Modo: %s.",
           if (SEM_DOWNLOAD) "sem download (--sem-download ou A2_SEM_DOWNLOAD=1); os modulos foram pulados e a base foi reconstruida a partir de data/processed"
           else "completo; os seis modulos rodaram em ordem antes da consolidacao"))

# ---------------------------------------------------------------------------
# 1. Modulos
# ---------------------------------------------------------------------------
MODULOS <- c("R/A2_download_bcb.R", "R/A2_download_ibge.R", "R/A2_download_ipea.R",
             "R/A2_download_comex.R", "R/A2_download_bndes.R", "R/A2_validacao_anual.R")
status_mod <- tibble(modulo = MODULOS, status = "pulado", minutos = NA_real_, erro = NA_character_)
if (!SEM_DOWNLOAD) {
  for (i in seq_along(MODULOS)) {
    t0 <- Sys.time()
    message("== Rodando ", MODULOS[i])
    err <- tryCatch({
      source(MODULOS[i], local = new.env(parent = globalenv()))
      NA_character_
    }, error = function(e) conditionMessage(e))
    status_mod$status[i] <- if (is.na(err)) "ok" else "falhou"
    status_mod$erro[i] <- err
    status_mod$minutos[i] <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  }
  set.seed(42)
}
for (i in seq_len(nrow(status_mod))) {
  lc(sprintf("  - %s: %s%s%s", status_mod$modulo[i], status_mod$status[i],
             if (!is.na(status_mod$minutos[i])) sprintf(" (%s min)", nb(status_mod$minutos[i], 1)) else "",
             if (!is.na(status_mod$erro[i])) paste0("; erro: ", status_mod$erro[i]) else ""))
}
if (any(status_mod$status == "falhou")) {
  lc("- Houve falha em modulo: a base abaixo usa os arquivos de data/processed que ja existiam para as fontes que falharam.")
}

# ---------------------------------------------------------------------------
# 2. Entradas (data/processed e data/original)
# ---------------------------------------------------------------------------
ENTRADAS <- c(
  ipea = "data/processed/A2_ipea_trimestral.csv",
  ibge = "data/processed/A2_ibge_trimestral.csv",
  bcb = "data/processed/A2_bcb_trimestral.csv",
  comex_m = "data/processed/A2_comex_mensal.csv",
  bndes_m = "data/processed/A2_bndes_mensal.csv",
  deflator = "data/processed/A2_deflator_ipca.csv",
  meta_bcb_ibge = "data/processed/A2_metadados_bcb_ibge.csv",
  meta_icb = "data/processed/A2_metadados_ipea_comex_bndes.csv",
  pvd = file.path(PATHS$original, "0224_tri_estmeq.txt")
)
falta <- ENTRADAS[!file.exists(ENTRADAS)]
if (length(falta)) {
  lc("- Entradas ausentes: ", paste(falta, collapse = ", "), ". Base nao construida.")
  stop("Entradas ausentes: ", paste(falta, collapse = ", "))
}
lc("- Entradas: ", paste(sprintf("%s (modificado em %s)", ENTRADAS,
                                  format(file.mtime(ENTRADAS), "%Y-%m-%d %H:%M")), collapse = "; "), ".")

rd <- function(f) read_csv(f, show_col_types = FALSE, guess_max = 100000)
ipea <- rd(ENTRADAS[["ipea"]])
ibge <- rd(ENTRADAS[["ibge"]]) %>% rename(trimestre = periodo) %>% arrange(qn(trimestre))
bcb <- rd(ENTRADAS[["bcb"]]) %>% rename(trimestre = periodo) %>% arrange(qn(trimestre))
comex_m <- rd(ENTRADAS[["comex_m"]])
bndes_m <- rd(ENTRADAS[["bndes_m"]])
defl_m <- rd(ENTRADAS[["deflator"]]) %>% filter(frequencia == "mensal") %>% select(periodo, fator_para_2025)
stopifnot(all(diff(qn(ibge$trimestre)) == 0.25), all(diff(qn(bcb$trimestre)) == 0.25))

# ---------------------------------------------------------------------------
# 3. Series em R$ de 2025 (deflacionadas mes a mes pelo IPCA e somadas no trimestre)
# ---------------------------------------------------------------------------
# Fator do mes: media de 2025 do indice IPCA / indice do mes (A2_deflator_ipca.csv, a partir de 2000-01).
real_tri <- function(df, col, divisor) {
  df %>%
    select(periodo, v = all_of(col)) %>%
    left_join(defl_m, by = "periodo") %>%
    mutate(v = v * fator_para_2025 / divisor,
           trimestre = q_key(as.integer(substr(periodo, 1, 4)), (as.integer(substr(periodo, 6, 7)) - 1) %/% 3 + 1)) %>%
    group_by(trimestre) %>%
    summarise(n_ok = sum(!is.na(v)), v = if (n_ok[1] == 3) sum(v) else NA_real_, .groups = "drop") %>%
    select(trimestre, v) %>%
    arrange(qn(trimestre))
}
imp_real_nsa <- real_tri(comex_m, "imp_bk_fob_rs", 1e9)            # R$ -> R$ bi
bndes_priv_nsa <- real_tri(bndes_m, "desemb_exc_adm_publica", 1e3) # R$ milhoes -> R$ bi
bndes_total_nsa <- real_tri(bndes_m, "desemb_total", 1e3)

# ---------------------------------------------------------------------------
# 4. X-11 (X-13ARIMA-SEATS em modo X-11, multiplicativo, como na A3) nas series sem ajuste
# ---------------------------------------------------------------------------
X11_DIAG <- list()
ajusta_x11 <- function(nome, trimestres, v) {
  d <- tibble(trimestre = trimestres, v = v) %>%
    filter(!is.na(v), qn(trimestre) >= qn(X11_INI), qn(trimestre) <= qn(Q_FIM)) %>%
    arrange(qn(trimestre))
  stopifnot(nrow(d) > 20, all(diff(qn(d$trimestre)) == 0.25), all(d$v > 0))
  xt <- ts_from_q(d$v, d$trimestre)
  espec <- "padrao do seas (regARIMA automatico, outliers automaticos, teste de dias uteis e Pascoa)"
  y <- tryCatch(x11_sa(xt, transform.function = "log"), error = function(e) NULL)
  if (is.null(y)) {
    y <- x11_sa(xt, transform.function = "log", regression.aictest = NULL)
    espec <- "sem teste de dias uteis e Pascoa (a especificacao padrao falhou)"
  }
  m <- attr(y, "seas_model")
  u <- function(k) tryCatch(as.numeric(seasonal::udg(m, k)), error = function(e) NA_real_)
  qsv <- tryCatch(seasonal::qs(m), error = function(e) NULL)
  qsp <- function(r) if (!is.null(qsv) && r %in% rownames(qsv)) as.numeric(qsv[r, "p-val"]) else NA_real_
  reg <- names(coef(m))
  arima <- tryCatch(as.character(seasonal::udg(m, "arimamdl")), error = function(e) NA_character_)
  X11_DIAG[[nome]] <<- tibble(
    variavel = nome, janela = sprintf("%s a %s", d$trimestre[1], d$trimestre[nrow(d)]), n = nrow(d),
    especificacao = espec, arima = arima,
    regressores = paste(reg[!grepl("^(MA|AR)-", reg)], collapse = " "),
    q_x11 = u("f3.q"), m7 = u("f3.m07"), qs_p_original = qsp("qsori"), qs_p_ajustada = qsp("qssadj"),
    qs_p_ajustada_sem_extremos = qsp("qssadjevadj"))
  tibble(trimestre = d$trimestre, valor = as.numeric(y))
}

ip_q <- ipea %>% arrange(qn(trimestre))
imp_q_sa <- ajusta_x11("imp_bk_quantum", ip_q$trimestre, ip_q$funcex_imp_bk_quantum)
imp_real_sa <- ajusta_x11("imp_bk_real", imp_real_nsa$trimestre, imp_real_nsa$v)
bndes_priv_sa <- ajusta_x11("bndes_priv", bndes_priv_nsa$trimestre, bndes_priv_nsa$v)
bndes_total_sa <- ajusta_x11("bndes_total", bndes_total_nsa$trimestre, bndes_total_nsa$v)
x11_diag <- bind_rows(X11_DIAG)

# ---------------------------------------------------------------------------
# 5. Niveis em R$ bi de 2025 com ajuste sazonal (Contas Nacionais)
# ---------------------------------------------------------------------------
# Volume encadeado com ajuste (6613, R$ milhoes de 1995) reescalado para que a media dos 4 trimestres
# de 2025 iguale a media dos 4 trimestres de 2025 a precos correntes (1846). Resultado: fluxo trimestral
# (nao anualizado) em R$ bi a precos medios de 2025 do proprio agregado.
em2025 <- substr(ibge$trimestre, 1, 4) == "2025"
stopifnot(sum(em2025) == 4, !anyNA(ibge[em2025, c("fbcf_encad95_sa_6613", "fbcf_corrente_1846",
                                                  "pib_encad95_sa_6613", "pib_corrente_1846")]))
k_fbcf <- mean(ibge$fbcf_corrente_1846[em2025]) / mean(ibge$fbcf_encad95_sa_6613[em2025])
k_pib <- mean(ibge$pib_corrente_1846[em2025]) / mean(ibge$pib_encad95_sa_6613[em2025])
ibge <- ibge %>%
  mutate(fbcf_real_rs_bi = k_fbcf * fbcf_encad95_sa_6613 / 1e3,
         pib_real_rs_bi = k_pib * pib_encad95_sa_6613 / 1e3,
         pib_acel = pib_var_tri_sa_1621 - lag(pib_var_tri_sa_1621))

# ---------------------------------------------------------------------------
# 6. PVD da dissertacao (data/original/0224_tri_estmeq.txt, log10, 2002Q1 a 2019Q4)
# ---------------------------------------------------------------------------
est <- read.table(ENTRADAS[["pvd"]], header = TRUE)
stopifnot(nrow(est) == 72, "PVD" %in% names(est))
pvd <- tibble(trimestre = q_seq("2002Q1", "2019Q4"), pvd_diss = 10^est$PVD)

# ---------------------------------------------------------------------------
# 7. Base unica
# ---------------------------------------------------------------------------
junta <- function(df, nome) df %>% rename(!!nome := valor)
base <- tibble(trimestre = TRI) %>%
  left_join(ipea %>% transmute(trimestre, fbcf_me = fbcf_me_sa, fbcf_constr = fbcf_constr_sa,
                               fbcf_outros = fbcf_outros_sa, fbcf_total = fbcf_total_sa, ca_bk_sa,
                               brent_usd = brent_usd_barril), by = "trimestre") %>%
  left_join(ibge %>% transmute(trimestre, pim_bk = pim_bk_sa_8887, fbcf_cnt_vol = fbcf_vol_sa_1621,
                               pib_vol_sa = pib_vol_sa_1621, pib_cresc = pib_var_tri_sa_1621, pib_acel,
                               fbcf_real_rs_bi, pib_real_rs_bi), by = "trimestre") %>%
  left_join(junta(imp_q_sa, "imp_bk_quantum"), by = "trimestre") %>%
  left_join(junta(imp_real_sa, "imp_bk_real"), by = "trimestre") %>%
  left_join(junta(bndes_priv_sa, "bndes_priv"), by = "trimestre") %>%
  left_join(junta(bndes_total_sa, "bndes_total"), by = "trimestre") %>%
  left_join(pvd, by = "trimestre") %>%
  left_join(bcb %>% transmute(trimestre, selic_fim = selic_meta_fim, selic_media = selic_meta_media,
                              ipca_tri = ipca_var_acum_tri, cambio_real = cambio_real_efetivo, icbr_usd),
            by = "trimestre")

# Especificacao das variaveis finais: ordem das colunas e metadados.
# origem: chaves de A2_metadados_bcb_ibge.csv / A2_metadados_ipea_comex_bndes.csv (coluna serie).
ESPEC <- tribble(
  ~nome, ~grupo, ~nivel, ~descricao, ~origem, ~unidade, ~transformacoes, ~ajuste_sazonal_origem,
  "fbcf_me", "privada", TRUE, "Indicador Ipea de FBCF: consumo aparente de maquinas e equipamentos, com ajuste sazonal",
    "fbcf_me_sa", "indice, media de 1995 = 100", "mensal -> trimestral pela media dos 3 meses", "dessazonalizada pelo Ipea (publicada)",
  "fbcf_constr", "privada", TRUE, "Indicador Ipea de FBCF: construcao civil, com ajuste sazonal",
    "fbcf_constr_sa", "indice, media de 1995 = 100", "mensal -> trimestral pela media dos 3 meses", "dessazonalizada pelo Ipea (publicada)",
  "fbcf_outros", "privada", TRUE, "Indicador Ipea de FBCF: consumo aparente de outros ativos, com ajuste sazonal",
    "fbcf_outros_sa", "indice, media de 1995 = 100", "mensal -> trimestral pela media dos 3 meses", "dessazonalizada pelo Ipea (publicada)",
  "fbcf_total", "privada", TRUE, "Indicador Ipea de FBCF total, com ajuste sazonal",
    "fbcf_total_sa", "indice, media de 1995 = 100", "mensal -> trimestral pela media dos 3 meses", "dessazonalizada pelo Ipea (publicada)",
  "ca_bk_sa", "privada", TRUE, "Consumo aparente de bens de capital (Ipea), dessazonalizado",
    "ca_bk_sa", "indice, media de 2012 = 100", "mensal -> trimestral pela media dos 3 meses", "dessazonalizada na fonte (Ipeadata)",
  "pim_bk", "privada", TRUE, "PIM-PF, producao fisica de bens de capital, com ajuste sazonal (proxy da producao nacional de M&E)",
    "pim_bk_sa_8887", "indice, 2022 = 100", "mensal -> trimestral pela media dos 3 meses", "com ajuste sazonal do IBGE (tabela 8887, variavel 12607)",
  "imp_bk_quantum", "privada", TRUE, "Importacao de bens de capital, indice de quantum da Funcex (proxy do componente importado de M&E)",
    "funcex_imp_bk_quantum", "indice, media de 2018 = 100", "mensal -> trimestral pela media dos 3 meses; X-11 multiplicativo em 2000Q1-2025Q4 (serie D11)", "sem ajuste na fonte; X-11 aplicado aqui",
  "imp_bk_real", "privada", TRUE, "Importacao de bens de capital (CGCE 1), valor FOB em R$ de 2025 com ajuste sazonal",
    "imp_bk_fob_usd;ptax_venda_media;ipca_var", "R$ bi de 2025 por trimestre", "US$ FOB x PTAX media do mes = R$ nominais; x fator IPCA do mes para media de 2025; soma dos 3 meses; X-11 multiplicativo em 2000Q1-2025Q4 (serie D11)", "sem ajuste na fonte; X-11 aplicado aqui",
  "bndes_priv", "privada", TRUE, "Desembolsos do BNDES exceto subsetor CNAE Administracao Publica (inclui estatais; proxy de desembolsos a empresas), R$ de 2025 com ajuste sazonal",
    "desemb_exc_adm_publica;ipca_var", "R$ bi de 2025 por trimestre", "R$ milhoes nominais do mes x fator IPCA do mes para media de 2025; soma dos 3 meses; X-11 multiplicativo em 2000Q1-2025Q4 (serie D11)", "sem ajuste na fonte; X-11 aplicado aqui",
  "bndes_total", "privada", TRUE, "Desembolsos totais do BNDES, R$ de 2025 com ajuste sazonal",
    "desemb_total;ipca_var", "R$ bi de 2025 por trimestre", "R$ milhoes nominais do mes x fator IPCA do mes para media de 2025; soma dos 3 meses; X-11 multiplicativo em 2000Q1-2025Q4 (serie D11)", "sem ajuste na fonte; X-11 aplicado aqui",
  "fbcf_cnt_vol", "privada", TRUE, "FBCF das Contas Nacionais Trimestrais, indice de volume encadeado com ajuste sazonal",
    "fbcf_vol_sa_1621", "indice, media de 1995 = 100", "nenhuma", "com ajuste sazonal do IBGE (tabela 1621)",
  "pvd_diss", "privada", TRUE, "PVD da dissertacao (consumo aparente de M&E do Indicador Ipea, safra da dissertacao), em nivel: 10^PVD",
    "", "indice (10^PVD = 0,9426 x indice Ipea de M&E, 1995 = 100, safra da dissertacao)", "pvd_diss = 10^PVD; pvd_diss_l10 = coluna PVD do arquivo original, sem alteracao", "com ajuste sazonal (Ipea, safra da dissertacao)",
  "pib_vol_sa", "controle", TRUE, "PIB, indice de volume encadeado com ajuste sazonal",
    "pib_vol_sa_1621", "indice, media de 1995 = 100", "nenhuma", "com ajuste sazonal do IBGE (tabela 1621)",
  "pib_cresc", "controle", FALSE, "PIB, variacao trimestral do indice de volume com ajuste sazonal",
    "pib_vol_sa_1621", "fracao (0,01 = 1%)", "x_t/x_{t-1} - 1 da tabela 1621 (mesmo conceito da coluna PIB de 0124_inexo.txt)", "com ajuste sazonal do IBGE (tabela 1621)",
  "pib_acel", "controle", FALSE, "PIB, aceleracao: diferenca da variacao trimestral (como diff(exo) na dissertacao)",
    "pib_vol_sa_1621", "fracao", "pib_cresc_t - pib_cresc_{t-1}", "com ajuste sazonal do IBGE (tabela 1621)",
  "selic_fim", "controle", FALSE, "Meta Selic no ultimo dia do trimestre (identica ao JUR da dissertacao, que esta em fracao)",
    "selic_meta", "% a.a.", "diaria -> valor do ultimo dia do trimestre", "nao se aplica",
  "selic_media", "controle", FALSE, "Meta Selic, media diaria do trimestre (robustez)",
    "selic_meta", "% a.a.", "diaria -> media dos dias do trimestre", "nao se aplica",
  "ipca_tri", "controle", FALSE, "IPCA, variacao acumulada no trimestre",
    "ipca_var", "% no trimestre", "produto de (1 + variacao mensal/100) nos 3 meses, menos 1, em %", "sem ajuste sazonal",
  "cambio_real", "controle", TRUE, "Indice da taxa de cambio real efetiva (IPCA); alta = depreciacao real",
    "cambio_real_efetivo", "indice, jun/1994 = 100", "mensal -> trimestral pela media dos 3 meses", "sem ajuste sazonal",
  "icbr_usd", "controle", TRUE, "Indice de Commodities - Brasil em US$ (IC-Br)",
    "icbr_usd", "indice", "mensal -> trimestral pela media dos 3 meses", "sem ajuste sazonal",
  "brent_usd", "controle", TRUE, "Preco do petroleo Brent (FOB)",
    "brent_usd_barril", "US$ por barril", "diaria -> mensal pela media dos dias cotados -> trimestral pela media dos 3 meses", "sem ajuste sazonal",
  "fbcf_real_rs_bi", "nivel_rs", TRUE, "FBCF em R$ bi de 2025 com ajuste sazonal (para multiplicadores)",
    "fbcf_encad95_sa_6613;fbcf_corrente_1846", "R$ bi de 2025 por trimestre (precos medios de 2025 da FBCF)", "6613 x k, k = media de 2025 da 1846 / media de 2025 da 6613; / 1000", "com ajuste sazonal do IBGE (tabela 6613)",
  "pib_real_rs_bi", "nivel_rs", TRUE, "PIB em R$ bi de 2025 com ajuste sazonal (para multiplicadores)",
    "pib_encad95_sa_6613;pib_corrente_1846", "R$ bi de 2025 por trimestre (precos medios de 2025 do PIB)", "6613 x k, k = media de 2025 da 1846 / media de 2025 da 6613; / 1000", "com ajuste sazonal do IBGE (tabela 6613)"
)
stopifnot(all(ESPEC$nome %in% names(base)))

# Versao log10 para as variaveis de nivel, logo depois do nivel.
cols <- character(0)
for (i in seq_len(nrow(ESPEC))) {
  v <- ESPEC$nome[i]
  cols <- c(cols, v)
  if (ESPEC$nivel[i]) {
    stopifnot(all(base[[v]] > 0, na.rm = TRUE))
    base[[paste0(v, "_l10")]] <- log10(base[[v]])
    cols <- c(cols, paste0(v, "_l10"))
  }
}
# pvd_diss_l10 e a coluna PVD do arquivo original, sem ida e volta pela potencia.
base$pvd_diss_l10 <- NA_real_
base$pvd_diss_l10[match(q_seq("2002Q1", "2019Q4"), base$trimestre)] <- est$PVD
base <- base %>% select(trimestre, all_of(cols))
stopifnot(nrow(base) == 96, identical(base$trimestre, TRI))

# Comparacao com a base anterior, se houver (reprodutibilidade).
F_BASE <- file.path(PATHS$processed, "A2_series_trimestrais.csv")
F_META <- file.path(PATHS$processed, "A2_metadados.csv")
base_ant <- if (file.exists(F_BASE)) read_csv(F_BASE, show_col_types = FALSE, guess_max = 1000) else NULL
write_csv_safe(base, F_BASE)
base_rel <- read_csv(F_BASE, show_col_types = FALSE, guess_max = 1000)
if (is.null(base_ant)) {
  lc("- Nao havia A2_series_trimestrais.csv anterior: base construida do zero.")
} else if (!identical(names(base_ant), names(base_rel)) || nrow(base_ant) != nrow(base_rel)) {
  lc("- A base anterior tinha outras colunas ou linhas; substituida.")
} else {
  num_cols <- setdiff(names(base_rel), "trimestre")
  dmax <- max(vapply(num_cols, function(v) {
    a <- base_ant[[v]]; b <- base_rel[[v]]
    if (!identical(is.na(a), is.na(b))) return(Inf)
    if (all(is.na(a))) 0 else max(abs(a - b), na.rm = TRUE)
  }, numeric(1)))
  lc(sprintf("- Reprodutibilidade: a base reconstruida foi comparada com o A2_series_trimestrais.csv que existia antes desta execucao: mesmas %d colunas, mesmas %d linhas, mesmo padrao de NA, diferenca absoluta maxima %s.%s",
             ncol(base_rel), nrow(base_rel), if (dmax == 0) "0" else nsci(dmax),
             if (dmax == 0) " A base e reproduzida exatamente." else ""))
}

# ---------------------------------------------------------------------------
# 8. Metadados
# ---------------------------------------------------------------------------
meta_fontes <- bind_rows(
  rd(ENTRADAS[["meta_bcb_ibge"]]) %>% mutate(across(everything(), as.character)),
  rd(ENTRADAS[["meta_icb"]]) %>% mutate(across(everything(), as.character))
) %>% distinct(serie, .keep_all = TRUE)
pega <- function(chaves, campo) {
  if (!nzchar(chaves)) return(NA_character_)
  k <- strsplit(chaves, ";", fixed = TRUE)[[1]]
  stopifnot(all(k %in% meta_fontes$serie))
  x <- meta_fontes[[campo]][match(k, meta_fontes$serie)]
  paste(if (campo == "fonte") unique(x) else x, collapse = " + ")
}
periodo_de <- function(v) {
  x <- base[[v]]; ok <- which(!is.na(x))
  if (!length(ok)) return("sem dados")
  sprintf("%s a %s (%d trimestres%s)", base$trimestre[min(ok)], base$trimestre[max(ok)], length(ok),
          if (length(ok) < (max(ok) - min(ok) + 1)) ", com lacunas" else "")
}
meta_linha <- function(i, l10) {
  e <- ESPEC[i, ]
  nome <- if (l10) paste0(e$nome, "_l10") else e$nome
  pvd <- e$nome == "pvd_diss"
  tibble(
    nome = nome,
    grupo = e$grupo,
    descricao = if (l10) paste0("log10 de ", e$nome, ": ", e$descricao) else e$descricao,
    fonte = if (pvd) "Dissertacao do autor (arquivo do VAR)" else pega(e$origem, "fonte"),
    codigo = if (pvd) "data/original/0224_tri_estmeq.txt, coluna PVD" else pega(e$origem, "codigo"),
    titulo_nos_metadados = if (pvd) "PVD: consumo aparente de maquinas e equipamentos do Indicador Ipea de FBCF, trimestral com ajuste sazonal (1995 = 100), em log10 (secao 4.3.2 da dissertacao)" else pega(e$origem, "titulo_nos_metadados"),
    unidade = if (l10) paste0("log10 (", e$unidade, ")") else e$unidade,
    transformacoes = if (l10 && !pvd) paste0(e$transformacoes, "; log10") else e$transformacoes,
    periodo = periodo_de(nome),
    ajuste_sazonal_origem = e$ajuste_sazonal_origem
  )
}
meta <- map_dfr(seq_len(nrow(ESPEC)), function(i) {
  bind_rows(meta_linha(i, FALSE), if (ESPEC$nivel[i]) meta_linha(i, TRUE))
})
stopifnot(identical(meta$nome, setdiff(names(base), "trimestre")))
write_csv_safe(meta, F_META)

# ---------------------------------------------------------------------------
# 9. Conferencias e registro
# ---------------------------------------------------------------------------
lc(sprintf("- Base: data/processed/A2_series_trimestrais.csv, %s a %s, %d trimestres, %d variaveis (%d de nivel com versao _l10 e %d taxas). Metadados em data/processed/A2_metadados.csv (uma linha por coluna).",
           Q_INI, Q_FIM, nrow(base), ncol(base) - 1, sum(ESPEC$nivel), sum(!ESPEC$nivel)))
lc("- Decisoes do A0_ambiente.md aplicadas: M&E, construcao, outros e total do Ipea na versao dessazonalizada publicada; PIM-PF BK com ajuste do IBGE (8887, variavel 12607); Selic meta no fim do trimestre como principal e media como robustez; IC-Br em US$ como indice de commodities e Brent como alternativa; PIB da safra de 2026-09-28; BNDES exceto Administracao Publica como proxy dos desembolsos a empresas (inclui estatais como Petrobras e Eletrobras); sem incerteza (FGV IBRE).")
lc("- Sem interpolacao: cada trimestre vem de 3 meses observados ou do dado trimestral da fonte; lacunas ficam vazias. pvd_diss so existe de 2002Q1 a 2019Q4.")
cobertura <- meta %>% filter(!grepl("_l10$", nome)) %>% transmute(txt = paste0(nome, " ", periodo))
lc("- Cobertura: ", paste(cobertura$txt, collapse = "; "), ".")

for (i in seq_len(nrow(x11_diag))) {
  d <- x11_diag[i, ]
  lc(sprintf("- X-11 de %s (%s, %d trimestres; %s): ARIMA %s; regressores %s; Q = %s; M7 = %s; QS da original p = %s; QS da ajustada p = %s (sem os valores extremos, p = %s). Serie ajustada = D11 (mantem os efeitos de AO e LS, como na A3).",
             d$variavel, d$janela, d$n, d$especificacao, d$arima, if (nzchar(d$regressores)) d$regressores else "nenhum",
             nb(d$q_x11, 2), nb(d$m7, 2), nb(d$qs_p_original, 3), nb(d$qs_p_ajustada, 3), nb(d$qs_p_ajustada_sem_extremos, 3)))
}
resid_sz <- x11_diag %>% filter(qs_p_ajustada < 0.05)
if (nrow(resid_sz)) {
  lc(sprintf("- QS da ajustada rejeita a 5%% em %s, mas sem os valores extremos nao rejeita em nenhuma (p minimo %s): a sazonalidade residual aparente vem dos AO mantidos na D11 (no BNDES, AO2009.3 e AO2010.3 caem no mesmo trimestre do ano).",
             paste(resid_sz$variavel, collapse = ", "), nb(min(resid_sz$qs_p_ajustada_sem_extremos), 3)))
}
qs_fx <- x11_diag$qs_p_original[x11_diag$variavel == "imp_bk_quantum"]
lc(sprintf("- Funcex: o titulo do FUNCEX12_MDQBKGCE12 no Ipeadata nao indica ajuste sazonal (o Ipeadata publica versoes dessazonalizadas com DESSAZ no codigo, e nao ha uma para este quantum); teste QS da media trimestral original: p = %s (%s). Por isso o X-11.",
           nb(qs_fx, 3), if (qs_fx < 0.05) "rejeita ausencia de sazonalidade a 5%" else "nao rejeita ausencia de sazonalidade a 5%; X-11 mantido pela regra do titulo"))

# Deflator e totais anuais das series em R$ de 2025.
tot_ano <- function(df, anos) df %>% mutate(ano = substr(trimestre, 1, 4)) %>% filter(ano %in% anos) %>%
  group_by(ano) %>% summarise(v = sum(v), .groups = "drop")
ta_imp <- tot_ano(imp_real_nsa, c("2003", "2013", "2025"))
ta_bp <- tot_ano(bndes_priv_nsa, c("2003", "2013", "2025"))
lc(sprintf("- R$ de 2025: fator IPCA mensal de A2_deflator_ipca.csv (media de 2025 = 100). Importacao de BK sem ajuste, soma anual em R$ bi de 2025: %s. BNDES exceto Administracao Publica: %s.",
           paste(sprintf("%s %s", ta_imp$ano, nb(ta_imp$v, 1)), collapse = "; "),
           paste(sprintf("%s %s", ta_bp$ano, nb(ta_bp$v, 1)), collapse = "; ")))

# Niveis em R$ bi de 2025.
chk <- ibge %>% mutate(ano = substr(trimestre, 1, 4))
sum_ano <- function(v, a) sum(chk[[v]][chk$ano == a])
fb25_cor <- sum_ano("fbcf_corrente_1846", "2025") / 1e3
pib25_cor <- sum_ano("pib_corrente_1846", "2025") / 1e3
fb25_sa <- sum_ano("fbcf_real_rs_bi", "2025")
pib25_sa <- sum_ano("pib_real_rs_bi", "2025")
sa_nsa_fb <- sum_ano("fbcf_encad95_sa_6613", "2025") / sum_ano("fbcf_encad95_nsa_6612", "2025")
sa_nsa_pib <- sum_ano("pib_encad95_sa_6613", "2025") / sum_ano("pib_encad95_nsa_6612", "2025")
g_fb <- diff(log(chk$fbcf_real_rs_bi)) - diff(log(chk$fbcf_vol_sa_1621))
g_pib <- diff(log(chk$pib_real_rs_bi)) - diff(log(chk$pib_vol_sa_1621))
# Deflator implicito da FBCF contra o IPCA: FBCF corrente de 2003 levada a 2025 pelo IPCA x FBCF real de 2003.
fat_ano <- rd(ENTRADAS[["deflator"]]) %>% filter(frequencia == "mensal") %>%
  mutate(ano = substr(periodo, 1, 4)) %>% group_by(ano) %>% summarise(ind = mean(100 / fator_para_2025), .groups = "drop")
ipca_2003_2025 <- fat_ano$ind[fat_ano$ano == "2025"] / fat_ano$ind[fat_ano$ano == "2003"]
defl_fbcf_2003_2025 <- (sum_ano("fbcf_corrente_1846", "2025") / sum_ano("fbcf_encad95_nsa_6612", "2025")) /
  (sum_ano("fbcf_corrente_1846", "2003") / sum_ano("fbcf_encad95_nsa_6612", "2003"))
defl_pib_2003_2025 <- (sum_ano("pib_corrente_1846", "2025") / sum_ano("pib_encad95_nsa_6612", "2025")) /
  (sum_ano("pib_corrente_1846", "2003") / sum_ano("pib_encad95_nsa_6612", "2003"))
fbpib_03 <- sum_ano("fbcf_real_rs_bi", "2003") / sum_ano("pib_real_rs_bi", "2003")
fbpib_25 <- fb25_sa / pib25_sa
NIVEIS_CHK <- list(k_fbcf = k_fbcf, k_pib = k_pib, fb25_cor = fb25_cor, pib25_cor = pib25_cor, fb25_sa = fb25_sa,
                   pib25_sa = pib25_sa, sa_nsa_fb = sa_nsa_fb, sa_nsa_pib = sa_nsa_pib,
                   ipca = ipca_2003_2025, defl_fbcf = defl_fbcf_2003_2025, defl_pib = defl_pib_2003_2025,
                   fbpib_03 = fbpib_03, fbpib_25 = fbpib_25)
lc(sprintf("- fbcf_real_rs_bi e pib_real_rs_bi: 6613 (valores encadeados a precos de 1995 com ajuste sazonal) x k, com k = media de 2025 da 1846 (precos correntes) / media de 2025 da 6613. k da FBCF = %s; k do PIB = %s. Soma de 2025 da serie reescalada: FBCF R$ %s bi e PIB R$ %s bi, iguais por construcao a soma corrente de 2025 da 1846 (R$ %s bi e R$ %s bi). As series sao fluxos trimestrais com ajuste sazonal, nao anualizados.",
           nb(k_fbcf, 4), nb(k_pib, 4), nb(fb25_sa, 1), nb(pib25_sa, 1), nb(fb25_cor, 1), nb(pib25_cor, 1)))
lc(sprintf("- Conferencias: diferenca maxima entre as variacoes do log da serie reescalada e do indice 1621: FBCF %s e PIB %s (mesma serie encadeada). Em 2025, soma da 6613 com ajuste / soma da 6612 sem ajuste = %s (FBCF) e %s (PIB): o ajuste sazonal preserva o total anual a menos de %s%%. FBCF/PIB nas series reescaladas: %s%% em 2003 e %s%% em 2025.",
           nsci(max(abs(g_fb), na.rm = TRUE)), nsci(max(abs(g_pib), na.rm = TRUE)),
           nb(sa_nsa_fb, 4), nb(sa_nsa_pib, 4), nb(100 * max(abs(c(sa_nsa_fb, sa_nsa_pib) - 1)), 2),
           nb(100 * fbpib_03, 1), nb(100 * fbpib_25, 1)))
lc(sprintf("- Precos: de 2003 a 2025 o deflator implicito da FBCF (1846 / 6612, anual) foi multiplicado por %s, o do PIB por %s e o IPCA medio por %s. As series de investimento publico da A3 estao em R$ de 2025 pelo IPCA; a FBCF aqui esta a precos de 2025 da propria FBCF. Na A5, para o multiplicador em reais, a razao entre as duas precisa usar o mesmo deflator ou registrar a diferenca de precos relativos (fator %s em 2003).",
           nb(defl_fbcf_2003_2025, 3), nb(defl_pib_2003_2025, 3), nb(ipca_2003_2025, 3), nb(defl_fbcf_2003_2025 / ipca_2003_2025, 3)))

# ---------------------------------------------------------------------------
# 10. Correlacoes
# ---------------------------------------------------------------------------
PRIV <- c("fbcf_me", "fbcf_constr", "fbcf_outros", "fbcf_total", "ca_bk_sa", "pim_bk",
          "imp_bk_quantum", "imp_bk_real", "bndes_priv", "bndes_total", "fbcf_cnt_vol")
dl <- base %>% transmute(trimestre, across(all_of(paste0(c(PRIV, "pvd_diss"), "_l10")), ~ .x - lag(.x))) %>%
  rename_with(~ sub("_l10$", "", .x))
dl_full <- dl %>% filter(trimestre != Q_INI)
cm <- cor(dl_full[, PRIV], use = "pairwise.complete.obs")
n_full <- sum(complete.cases(dl_full[, PRIV]))
dl_diss <- dl %>% filter(qn(trimestre) >= qn("2002Q2"), qn(trimestre) <= qn("2019Q4"))
cor_pvd <- tibble(variavel = PRIV,
                  cor_dif_pvd = vapply(PRIV, function(v) cor(dl_diss[[v]], dl_diss$pvd_diss, use = "complete.obs"), numeric(1)),
                  n = vapply(PRIV, function(v) sum(complete.cases(dl_diss[[v]], dl_diss$pvd_diss)), integer(1)),
                  cor_nivel_pvd = vapply(PRIV, function(v) {
                    k <- qn(base$trimestre) <= qn("2019Q4")
                    cor(base[[paste0(v, "_l10")]][k], base$pvd_diss_l10[k], use = "complete.obs")
                  }, numeric(1)))
cor_out <- as_tibble(cm, rownames = "variavel") %>%
  left_join(cor_pvd %>% select(variavel, cor_dif_pvd_2002_2019 = cor_dif_pvd, n_pvd = n), by = "variavel")
write_csv_safe(cor_out, file.path(PATHS$results, "A2_correlacoes_privadas.csv"))

me <- cor_pvd %>% filter(variavel == "fbcf_me")
lc(sprintf("- Correlacao das diferencas do log10 com diff(pvd_diss), 2002Q2 a 2019Q4 (%d trimestres): %s. fbcf_me reproduz o 0,9931 registrado na A2 (%s).",
           me$n, paste(sprintf("%s %s", cor_pvd$variavel, nb(cor_pvd$cor_dif_pvd, 3)), collapse = "; "), nb(me$cor_dif_pvd, 4)))
lc(sprintf("- Correlacoes das diferencas entre as privadas (2002Q2 a 2025Q4, %d trimestres) em results/A2_correlacoes_privadas.csv e results/A2_resumo.md. fbcf_me com: pim_bk %s, imp_bk_quantum %s, imp_bk_real %s, bndes_priv %s, fbcf_constr %s, fbcf_cnt_vol %s.",
           n_full, nb(cm["fbcf_me", "pim_bk"], 2), nb(cm["fbcf_me", "imp_bk_quantum"], 2), nb(cm["fbcf_me", "imp_bk_real"], 2),
           nb(cm["fbcf_me", "bndes_priv"], 2), nb(cm["fbcf_me", "fbcf_constr"], 2), nb(cm["fbcf_me", "fbcf_cnt_vol"], 2)))
lc(sprintf("- fbcf_total e fbcf_cnt_vol tem correlacao %s nas diferencas (o indicador Ipea e ancorado nas Contas Nacionais, como visto na validacao anual). Os desembolsos do BNDES quase nao se correlacionam com as medidas de investimento nas diferencas (de %s a %s com as demais privadas; %s com o PVD), o que vale registrar antes de usa-los como resposta na A5.",
           nb(cm["fbcf_total", "fbcf_cnt_vol"], 3),
           nb(min(cm["bndes_priv", setdiff(PRIV, c("bndes_priv", "bndes_total"))]), 2),
           nb(max(cm["bndes_priv", setdiff(PRIV, c("bndes_priv", "bndes_total"))]), 2),
           nb(cor_pvd$cor_dif_pvd[cor_pvd$variavel == "bndes_priv"], 3)))

# ---------------------------------------------------------------------------
# 11. Figura
# ---------------------------------------------------------------------------
ROT <- c(
  fbcf_me = "fbcf_me: Ipea M&E (1995 = 100)", fbcf_constr = "fbcf_constr: Ipea construcao (1995 = 100)",
  fbcf_outros = "fbcf_outros: Ipea outros (1995 = 100)", fbcf_total = "fbcf_total: Ipea FBCF (1995 = 100)",
  ca_bk_sa = "ca_bk_sa: cons. aparente BK (2012 = 100)", pim_bk = "pim_bk: PIM-PF BK (2022 = 100)",
  imp_bk_quantum = "imp_bk_quantum: Funcex (2018 = 100)", imp_bk_real = "imp_bk_real: import. BK (R$ bi 2025)",
  bndes_priv = "bndes_priv: BNDES exc. adm. publ. (R$ bi)", bndes_total = "bndes_total: BNDES (R$ bi 2025)",
  fbcf_cnt_vol = "fbcf_cnt_vol: FBCF CNT (1995 = 100)", pvd_diss = "pvd_diss: 10^PVD da dissertacao",
  pib_vol_sa = "pib_vol_sa: PIB (1995 = 100)", pib_cresc = "pib_cresc: PIB, var. trimestral (fracao)",
  pib_acel = "pib_acel: PIB, aceleracao (fracao)", selic_fim = "selic_fim: meta Selic, fim (% a.a.)",
  selic_media = "selic_media: meta Selic, media (% a.a.)", ipca_tri = "ipca_tri: IPCA no trimestre (%)",
  cambio_real = "cambio_real: cambio real efetivo", icbr_usd = "icbr_usd: IC-Br em US$",
  brent_usd = "brent_usd: Brent (US$/barril)", fbcf_real_rs_bi = "fbcf_real_rs_bi: FBCF (R$ bi 2025)",
  pib_real_rs_bi = "pib_real_rs_bi: PIB (R$ bi 2025)")
stopifnot(setequal(names(ROT), ESPEC$nome))
COR_LINHA <- "#1f5a96"
long <- base %>% select(trimestre, all_of(ESPEC$nome)) %>%
  pivot_longer(-trimestre, names_to = "variavel", values_to = "valor") %>%
  mutate(data = as.numeric(q_to_yearqtr(trimestre)),
         painel = factor(ROT[variavel], levels = ROT[ESPEC$nome]),
         grupo = ESPEC$grupo[match(variavel, ESPEC$nome)])
tema <- theme_minimal(base_size = 8) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
        strip.text = element_text(hjust = 0, size = 7), axis.title = element_blank(),
        plot.title = element_text(size = 9, face = "bold"), plot.background = element_rect(fill = "white", color = NA))
painel <- function(g, titulo, ncol) {
  ggplot(long %>% filter(grupo %in% g, !is.na(valor)), aes(data, valor)) +
    geom_line(color = COR_LINHA, linewidth = 0.45) +
    facet_wrap(~painel, scales = "free_y", ncol = ncol) +
    scale_y_continuous(labels = scales::label_number(decimal.mark = ",", big.mark = ".")) +
    scale_x_continuous(breaks = seq(2002, 2026, 6), limits = c(2002, 2026)) +
    labs(title = titulo) + tema
}
fig <- painel("privada", "Investimento privado e atividade (com ajuste sazonal)", 4) /
  painel(c("controle", "nivel_rs"), "Controles e niveis em R$ para multiplicadores", 4) +
  plot_layout(heights = c(3, 3)) +
  plot_annotation(caption = sprintf("Base A2_series_trimestrais.csv, %s a %s. pvd_diss so de 2002 a 2019. Fontes em A2_metadados.csv.", Q_INI, Q_FIM),
                  theme = theme(plot.caption = element_text(size = 7, hjust = 0)))
for (ext in c("png", "pdf")) {
  ggsave_safe(file.path(PATHS$figuras, paste0("A2_series.", ext)), fig, width = 10, height = 11, dpi = 200, bg = "white")
}
lc("- Figura: results/figuras/A2_series.png e .pdf (um painel por variavel, em nivel).")

# ---------------------------------------------------------------------------
# 12. Resumo em markdown
# ---------------------------------------------------------------------------
md_tab <- function(df) {
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
tab_var <- meta %>% filter(!grepl("_l10$", nome)) %>%
  mutate(l10 = ifelse(ESPEC$nivel[match(nome, ESPEC$nome)], "sim", "nao"),
         fonte = gsub("\\|", "/", fonte), descricao = gsub("\\|", "/", descricao)) %>%
  transmute(variavel = paste0("`", nome, "`"), descricao, fonte, unidade, periodo, `ajuste sazonal` = ajuste_sazonal_origem, `_l10` = l10)
tab_cor <- as_tibble(cm, rownames = "variavel") %>%
  mutate(across(-variavel, ~ nb(.x, 2)), variavel = paste0("`", variavel, "`"))
tab_pvd <- cor_pvd %>% transmute(variavel = paste0("`", variavel, "`"), `cor. das diferencas com pvd_diss` = nb(cor_dif_pvd, 3),
                                 `cor. em nivel (log10)` = nb(cor_nivel_pvd, 3), n = n)
tab_x11 <- x11_diag %>% transmute(variavel = paste0("`", variavel, "`"), janela, ARIMA = arima,
                                  regressores = ifelse(nzchar(regressores), regressores, "nenhum"),
                                  Q = nb(q_x11, 2), M7 = nb(m7, 2), `QS original (p)` = nb(qs_p_original, 3),
                                  `QS ajustada (p)` = nb(qs_p_ajustada, 3),
                                  `QS ajustada sem extremos (p)` = nb(qs_p_ajustada_sem_extremos, 3))
resumo <- c(
  "# A2: base trimestral consolidada",
  "",
  sprintf("Gerado por `R/A2_download.R` em %s (modo %s). Base: `data/processed/A2_series_trimestrais.csv`, %s a %s, %d trimestres, coluna `trimestre` no formato 2003Q1. Metadados: `data/processed/A2_metadados.csv`. Figura: `results/figuras/A2_series.png` e `.pdf`.",
          format(Sys.time(), "%Y-%m-%d %H:%M"), if (SEM_DOWNLOAD) "sem download" else "completo", Q_INI, Q_FIM, nrow(base)),
  "",
  "Toda variavel de nivel tem tambem a versao `_l10` (log10). Nao ha interpolacao: lacunas ficam vazias. `pvd_diss_l10` e a coluna PVD de `data/original/0224_tri_estmeq.txt` sem alteracao (2002Q1 a 2019Q4).",
  "",
  "## Variaveis",
  "",
  md_tab(tab_var),
  "",
  "## Ajuste sazonal feito aqui (X-11 multiplicativo, serie D11)",
  "",
  md_tab(tab_x11),
  "",
  "Q e M7 abaixo de 1 indicam ajuste aceitavel e sazonalidade identificavel. O teste QS tem como hipotese nula a ausencia de sazonalidade.",
  "",
  sprintf("## Correlacoes das diferencas do log10 entre as series privadas (2002Q2 a 2025Q4, %d trimestres)", n_full),
  "",
  md_tab(tab_cor),
  "",
  sprintf("## Correlacao com o PVD da dissertacao (2002Q2 a 2019Q4, %d diferencas)", me$n),
  "",
  md_tab(tab_pvd),
  "",
  "## Niveis em R$ de 2025 (multiplicadores)",
  "",
  sprintf("- `fbcf_real_rs_bi` e `pib_real_rs_bi`: tabela 6613 (valores encadeados a precos de 1995 com ajuste sazonal) x k, com k = media de 2025 da 1846 / media de 2025 da 6613 (k = %s na FBCF e %s no PIB). Soma de 2025: FBCF R$ %s bi e PIB R$ %s bi, iguais a soma corrente de 2025 da 1846. Fluxos trimestrais, nao anualizados.",
          nb(k_fbcf, 4), nb(k_pib, 4), nb(fb25_sa, 1), nb(pib25_sa, 1)),
  sprintf("- Variacoes identicas as do indice 1621 (diferenca maxima %s na FBCF). Em 2025, soma com ajuste / soma sem ajuste = %s (FBCF) e %s (PIB). FBCF/PIB: %s%% em 2003 e %s%% em 2025.",
          nsci(max(abs(g_fb), na.rm = TRUE)), nb(sa_nsa_fb, 4), nb(sa_nsa_pib, 4), nb(100 * fbpib_03, 1), nb(100 * fbpib_25, 1)),
  sprintf("- Precos relativos: de 2003 a 2025 o deflator implicito da FBCF foi multiplicado por %s e o IPCA por %s. O investimento publico da A3 esta em R$ de 2025 pelo IPCA; a FBCF aqui, a precos de 2025 da propria FBCF (razao %s em 2003).",
          nb(defl_fbcf_2003_2025, 3), nb(ipca_2003_2025, 3), nb(defl_fbcf_2003_2025 / ipca_2003_2025, 3)),
  "",
  "## Ressalvas",
  "",
  "- `bndes_priv` exclui so o subsetor CNAE Administracao Publica e inclui estatais (Petrobras, Eletrobras); a base mensal do BNDES nao separa empresas privadas.",
  "- Os componentes nacional e importado do M&E do Ipea nao sao publicados como serie: `pim_bk` e as importacoes de BK entram como proxies.",
  "- O Indicador de Incerteza da FGV IBRE ficou fora (sem fonte aberta acessivel no conteiner).",
  "- `pvd_diss` e a safra da dissertacao; `fbcf_me` e a safra de 2026 da mesma serie."
)
write_lines_safe(resumo, file.path(PATHS$results, "A2_resumo.md"))
lc("- Resumo em results/A2_resumo.md.")

save_session_info("A2_download")
message("A2_download: base com ", nrow(base), " trimestres e ", ncol(base) - 1, " variaveis.")
