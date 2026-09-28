# A4. Quebras estruturais nas series de investimento publico e privado e nas equacoes do VAR.
# Uso: cd crowding_in_code && Rscript R/A4_quebras.R
# Variavel de ambiente opcional A4_NREP (replicas de Monte Carlo; padrao 1000, o valor do registro).

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(strucchange)
  library(urca)
  library(vars)
  library(sandwich)
  library(lmtest)
  library(patchwork)
  library(parallel)
})
set.seed(42)
t_ini <- Sys.time()
NREP <- as.integer(Sys.getenv("A4_NREP", "1000"))
NCORES <- max(1L, min(4L, parallel::detectCores()))
log_reset("A4")

# ---------------------------------------------------------------------------------------------
# Utilitarios
# ---------------------------------------------------------------------------------------------
fnum <- function(x, d = 2) {
  out <- formatC(round(as.numeric(x), d), format = "f", digits = d, decimal.mark = ",")
  out[is.na(x)] <- "NA"
  out
}
fp <- function(p) ifelse(is.na(p), "NA", ifelse(p < 0.001, "<0,001", fnum(p, 3)))
ftex <- function(x, d = 2) gsub(",", "{,}", fnum(x, d), fixed = TRUE)
fptex <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "$<$0{,}001", ftex(p, 3)))
qt <- function(k) sub("Q", "T", k)                  # 2014Q4 -> 2014T4
tex_esc <- function(s) gsub("%", "\\\\%", gsub("_", "\\\\_", s))
tex_ef <- function(s) tex_esc(sub("^nao muda$", "n\\\\~ao muda", sub("^Ate ", "At\\\\'e ", s)))
q_next <- function(k) format(q_to_yearqtr(k) + 0.25, "%YQ%q")
q_idx <- function(k, keys) match(k, keys)
cresc_aa <- function(m) (10^(4 * m) - 1) * 100      # media de diff(log10) por trimestre -> % ao ano

NW_LAG <- 3
MIN_SEG <- 4   # Chow em media: pelo menos 4 diferencas em cada regime
nw <- function(x, ...) sandwich::NeweyWest(x, lag = NW_LAG, prewhite = FALSE, adjust = TRUE)

# ---------------------------------------------------------------------------------------------
# Dados
# ---------------------------------------------------------------------------------------------
f_ch <- file.path(PATHS$processed, "A3_choques_wide.csv")
f_chs <- file.path(PATHS$processed, "A3_choques_semao_wide.csv")
f_meta <- file.path(PATHS$processed, "A3_metadados_series.csv")
f_a2 <- file.path(PATHS$processed, "A2_series_trimestrais.csv")
ch <- readr::read_csv(f_ch, show_col_types = FALSE)
chs <- readr::read_csv(f_chs, show_col_types = FALSE)
meta <- readr::read_csv(f_meta, show_col_types = FALSE)
a2 <- readr::read_csv(f_a2, show_col_types = FALSE)
orig_end <- read.table(file.path(PATHS$original, "0224_tri_estmeq.txt"), header = TRUE)
orig_exo <- read.table(file.path(PATHS$original, "0124_inexo.txt"), header = TRUE)
keys_orig <- q_seq("2002Q1", "2019Q4")
stopifnot(nrow(orig_end) == 72, nrow(orig_exo) == 72)

# Series de investimento publico: principais e aptas para as LP (A3_metadados_series.csv),
# com transferencia = grupo 1 (sufixo _g1) no lugar da versao com os grupos 1 e 2 (decisao do coordenador).
sel <- meta$serie[meta$principal %in% TRUE & meta$apta_lp %in% TRUE]
sel <- vapply(sel, function(s) {
  g1 <- paste0(s, "_g1")
  if (g1 %in% meta$serie && isTRUE(meta$apta_lp[meta$serie == g1])) g1 else s
}, character(1), USE.NAMES = FALSE)
SERIES_PUB <- sel
SERIES_PRIV <- c("fbcf_me", "fbcf_constr", "fbcf_total", "pim_bk", "imp_bk_quantum", "bndes_priv", "pvd_diss")
stopifnot(all(SERIES_PUB %in% names(ch)), all(paste0(SERIES_PRIV, "_l10") %in% names(a2)))

serie_y <- function(s) {
  if (s %in% SERIES_PUB) {
    d <- tibble(trimestre = ch$trimestre, y = ch[[s]])
  } else {
    d <- tibble(trimestre = a2$trimestre, y = a2[[paste0(s, "_l10")]])
  }
  d <- d[!is.na(d$y), ]
  stopifnot(identical(d$trimestre, q_seq(d$trimestre[1], d$trimestre[nrow(d)])))  # sem lacunas
  d
}
SERIES <- c(SERIES_PUB, SERIES_PRIV)
dados_series <- setNames(lapply(SERIES, serie_y), SERIES)

log_part("A4", sprintf("- Entradas: %s, %s, %s, %s, data/original/0224_tri_estmeq.txt e 0124_inexo.txt. Sem download.",
                       f_ch, f_chs, f_meta, f_a2))
log_part("A4", sprintf("- Series testadas (%d): publicas principais e aptas para as LP de A3_metadados_series.csv, com transferencia = grupo 1 (_g1) como baseline (%s); privadas (%s). Todas em log10 (indice com ajuste sazonal nas publicas; _l10 da A2 nas privadas). Amostra de cada serie: todos os trimestres observados (2003T1-2025T4 nas publicas; 2016T1-2025T4 nas series so da OI; 2002T1-2025T4 nas privadas; 2002T1-2019T4 em pvd_diss).",
                       length(SERIES), paste(SERIES_PUB, collapse = ", "), paste(SERIES_PRIV, collapse = ", ")))

# ---------------------------------------------------------------------------------------------
# Datas candidatas
# ---------------------------------------------------------------------------------------------
DATAS_APRIORI <- c("2008Q4", "2014Q4", "2015Q1", "2016Q4", "2017Q1", "2020Q2", "2023Q3")
ELEICOES <- c("2010Q4", "2014Q4", "2018Q4", "2022Q4")
ELEICOES_COM2006 <- c("2006Q4", ELEICOES)
DATAS_DADOS <- list(
  sest = list(datas = c("2016Q1", "2017Q1", "2018Q1", "2019Q1", "2020Q1"),
              series = c("estatais_total", "inf_diss"),
              rotulo = "Emenda boletim/OI da SEST"),
  imp2017 = list(datas = c("2017Q1", "2018Q1"), series = c("uniao_filtro_diss", "inf_diss"),
                 rotulo = "Imputacao de 2017"),
  eleicao = list(datas = "2018Q4", series = SERIES_PUB, rotulo = "T4 eleitoral de 2018"),
  composicao = list(datas = c("2011Q1", "2017Q1"),
                    series = c("uniao_econ_dir", "uniao_econ_dt_g1", "uniao_gnd4_dir", "uniao_soc_dir"),
                    rotulo = "Composicao por elemento (2011-2016)"),
  eletrobras = list(datas = "2022Q3", series = c("estatais_econ", "estatais_sempetro", "estatais_semgrupopetro"),
                    rotulo = "Saida da Eletrobras (2022T3)")
)
log_part("A4", "- Convencao de datas: toda data de quebra reportada e o PRIMEIRO trimestre do novo regime. O strucchange e o urca devolvem o ultimo trimestre do regime anterior; o script soma um trimestre. O Chow na data d compara o periodo ate o trimestre anterior a d com o periodo de d em diante.")
log_part("A4", sprintf("- Datas a priori: %s. Quebras nos dados: emenda da SEST (%s, em estatais_total e inf_diss), imputacao de 2017 (2017T1 e 2018T1, e os pulsos de 2017T1 a 2018T1, em uniao_filtro_diss e inf_diss), T4 de anos eleitorais (dummy com %s; variante com 2006T4), composicao por elemento na execucao direta (2011T1 e 2017T1 e uma dummy de 2011T1 a 2016T4, em uniao_econ_dir, uniao_econ_dt_g1, uniao_gnd4_dir e uniao_soc_dir) e saida da Eletrobras (2022T3, em estatais_econ, estatais_sempetro e estatais_semgrupopetro; ponto de atencao da A3).",
                       paste(qt(DATAS_APRIORI), collapse = ", "), paste(qt(DATAS_DADOS$sest$datas), collapse = ", "),
                       paste(qt(ELEICOES), collapse = ", ")))

# ---------------------------------------------------------------------------------------------
# Testes em series: media da diferenca do log10
# ---------------------------------------------------------------------------------------------
lwz_crit <- function(rss, n, q, m) {
  pstar <- (m + 1) * q + m
  ifelse(n - pstar > 0, log(rss / (n - pstar)) + pstar / n * 0.299 * log(n)^(2.1), NA)
}

bp_datas <- function(bp, m, keys_dy) {
  if (m == 0) return(list(datas = character(0), lo = character(0), hi = character(0), idx = integer(0)))
  b <- breakpoints(bp, breaks = m)$breakpoints
  ci <- tryCatch(confint(bp, breaks = m, level = 0.95)$confint, error = function(e) NULL)
  n <- length(keys_dy)
  nx <- function(i) ifelse(is.na(i), NA, keys_dy[pmin(pmax(i, 1), n - 1) + 1])
  list(datas = nx(b),
       lo = if (is.null(ci)) rep(NA, m) else nx(ci[, 1]),
       hi = if (is.null(ci)) rep(NA, m) else nx(ci[, 3]),
       idx = b)
}

teste_serie <- function(s) {
  d <- dados_series[[s]]
  keys <- d$trimestre
  dy <- diff(d$y)
  keys_dy <- keys[-1]
  n <- length(dy)
  df <- data.frame(dy = dy)
  # (1) Bai-Perron na media
  bp <- breakpoints(dy ~ 1, data = df, h = 0.15, breaks = 5)
  sm <- summary(bp)$RSS
  mm <- as.integer(colnames(sm))
  bic <- sm["BIC", ]
  lwz <- lwz_crit(sm["RSS", ], n, 1, mm)
  m_bic <- mm[which.min(bic)]
  m_lwz <- mm[which.min(lwz)]
  db <- bp_datas(bp, m_bic, keys_dy)
  dl <- bp_datas(bp, m_lwz, keys_dy)
  seg_means <- function(idx) {
    cuts <- c(0, idx, n)
    vapply(seq_len(length(cuts) - 1), function(j) mean(dy[(cuts[j] + 1):cuts[j + 1]]), numeric(1))
  }
  # (2) sup-Wald (Andrews): classico e com Newey-West
  fs <- Fstats(dy ~ 1, data = df, from = 0.15)
  st <- sctest(fs, type = "supF")
  fs_h <- Fstats(dy ~ 1, data = df, from = 0.15, vcov. = nw)
  st_h <- sctest(fs_h, type = "supF")
  sup_data <- keys_dy[breakpoints(fs)$breakpoints + 1]
  # (4) CUSUM e MOSUM
  e1 <- sctest(efp(dy ~ 1, data = df, type = "OLS-CUSUM"))
  e1l <- sctest(efp(dy ~ 1, data = df, type = "OLS-CUSUM", lrvar = TRUE))
  e2 <- sctest(efp(dy ~ 1, data = df, type = "OLS-MOSUM", h = 0.15))
  list(serie = s, n_nivel = length(d$y), n = n, inicio = keys[1], fim = keys[length(keys)],
       m_bic = m_bic, m_lwz = m_lwz, bp_bic = db, bp_lwz = dl,
       medias_bic = cresc_aa(seg_means(db$idx)),
       supF = unname(st$statistic), supF_p = st$p.value, supF_data = sup_data,
       supF_hac = unname(st_h$statistic), supF_hac_p = st_h$p.value, supF_hac_data = keys_dy[breakpoints(fs_h)$breakpoints + 1],
       cusum = unname(e1$statistic), cusum_p = e1$p.value,
       cusum_lr = unname(e1l$statistic), cusum_lr_p = e1l$p.value,
       mosum = unname(e2$statistic), mosum_p = e2$p.value,
       media_total = cresc_aa(mean(dy)))
}
res_series <- setNames(lapply(SERIES, teste_serie), SERIES)

# (3) Chow em media nas datas candidatas, com F classico e t de Newey-West do degrau
chow_media <- function(s, data_q) {
  d <- dados_series[[s]]
  keys_dy <- d$trimestre[-1]
  dy <- diff(d$y)
  n <- length(dy)
  i <- match(data_q, keys_dy) - 1     # observacoes no primeiro regime
  if (is.na(i) || i < MIN_SEG || n - i < MIN_SEG) return(NULL)
  st <- sctest(dy ~ 1, type = "Chow", point = i)
  deg <- as.numeric(seq_len(n) > i)
  fit <- lm(dy ~ deg)
  ct <- lmtest::coeftest(fit, vcov. = nw(fit))
  tibble(serie = s, data = data_q, F = unname(st$statistic), p = st$p.value,
         t_hac = ct["deg", "t value"], p_hac = ct["deg", "Pr(>|t|)"],
         cresc_antes = cresc_aa(mean(dy[1:i])), cresc_depois = cresc_aa(mean(dy[(i + 1):n])))
}
chow_series <- bind_rows(lapply(SERIES, function(s) {
  bind_rows(lapply(c(DATAS_APRIORI, "2018Q4"), function(dq) {
    r <- chow_media(s, dq)
    if (!is.null(r)) r$origem <- if (dq %in% DATAS_APRIORI) "a priori" else "dados: T4 eleitoral de 2018"
    r
  }))
}))
chow_dados <- bind_rows(lapply(names(DATAS_DADOS), function(nm) {
  dd <- DATAS_DADOS[[nm]]
  if (nm == "eleicao") return(NULL)
  bind_rows(lapply(dd$series, function(s) bind_rows(lapply(dd$datas, function(dq) {
    r <- chow_media(s, dq)
    if (!is.null(r)) r$origem <- paste0("dados: ", dd$rotulo)
    r
  }))))
}))

# Dummies de dados testadas na media: T4 eleitoral (pulso no nivel = +1 no T4 e -1 no T1 seguinte na diferenca),
# pulsos de 2017T1 a 2018T1 (imputacao) e janela 2011T1-2016T4 (composicao).
dif_pulso <- function(keys_dy, datas) {
  x <- as.numeric(keys_dy %in% datas) - as.numeric(keys_dy %in% vapply(datas, q_next, ""))
  x
}
teste_dummy_media <- function(s, tipo) {
  d <- dados_series[[s]]
  keys_dy <- d$trimestre[-1]
  dy <- diff(d$y)
  if (tipo %in% c("eleicao", "eleicao2006")) {
    x <- dif_pulso(keys_dy, if (tipo == "eleicao") ELEICOES else ELEICOES_COM2006)
    if (sum(abs(x)) == 0) return(NULL)
    fit <- lm(dy ~ x)
    ct <- lmtest::coeftest(fit, vcov. = nw(fit))
    ind <- vapply(ELEICOES_COM2006, function(e) {
      xe <- dif_pulso(keys_dy, e)
      if (sum(abs(xe)) == 0) return(NA_real_)
      fe <- lm(dy ~ xe)
      coef(summary(fe))["xe", "t value"]
    }, numeric(1))
    return(tibble(serie = s, teste = tipo, coef = coef(fit)["x"], t = coef(summary(fit))["x", "t value"],
                  p = coef(summary(fit))["x", "Pr(>|t|)"], t_hac = ct["x", "t value"], p_hac = ct["x", "Pr(>|t|)"],
                  efeito_pct = (10^coef(fit)["x"] - 1) * 100,
                  t_2006 = ind[1], t_2010 = ind[2], t_2014 = ind[3], t_2018 = ind[4], t_2022 = ind[5]))
  }
  if (tipo == "imp2017") {
    datas <- q_seq("2017Q1", "2018Q1")
    X <- sapply(datas, function(k) as.numeric(keys_dy == k))
    if (sum(X) < length(datas)) return(NULL)
    f0 <- lm(dy ~ 1); f1 <- lm(dy ~ X)
    a <- anova(f0, f1)
    return(tibble(serie = s, teste = tipo, coef = NA, t = NA, p = a$`Pr(>F)`[2], t_hac = NA, p_hac = NA,
                  efeito_pct = NA, F = a$F[2]))
  }
  if (tipo == "composicao") {
    x <- as.numeric(keys_dy >= "2011Q1" & keys_dy <= "2016Q4")
    fit <- lm(dy ~ x)
    ct <- lmtest::coeftest(fit, vcov. = nw(fit))
    return(tibble(serie = s, teste = tipo, coef = coef(fit)["x"], t = coef(summary(fit))["x", "t value"],
                  p = coef(summary(fit))["x", "Pr(>|t|)"], t_hac = ct["x", "t value"], p_hac = ct["x", "Pr(>|t|)"],
                  efeito_pct = cresc_aa(coef(fit)["x"] + coef(fit)[1]) - cresc_aa(coef(fit)[1])))
  }
}
dummies_media <- bind_rows(
  bind_rows(lapply(SERIES, teste_dummy_media, tipo = "eleicao")),
  bind_rows(lapply(SERIES, teste_dummy_media, tipo = "eleicao2006")),
  bind_rows(lapply(DATAS_DADOS$imp2017$series, teste_dummy_media, tipo = "imp2017")),
  bind_rows(lapply(DATAS_DADOS$composicao$series, teste_dummy_media, tipo = "composicao"))
)

# ---------------------------------------------------------------------------------------------
# Raiz unitaria com quebra: Zivot-Andrews (urca), Lumsdaine-Papell e Clemente-Montanes-Reyes (IO e AO)
# ---------------------------------------------------------------------------------------------
PMAX <- 4
TRIM_UR <- 0.15
# Regra de lags comum aos tres testes e a simulacao: p de 0 a 4 que minimiza o BIC da regressao ADF sem quebra
# (constante e tendencia para ZA e LP; so constante para CMR), na amostra comum t = PMAX + 2, ..., n.
lag_bic <- function(y, tendencia = TRUE, pmax = PMAX) {
  n <- length(y)
  dyf <- c(NA, diff(y))
  tt <- (pmax + 2):n
  ne <- length(tt)
  bics <- vapply(0:pmax, function(p) {
    X <- cbind(1, if (tendencia) tt, y[tt - 1])
    if (p > 0) X <- cbind(X, sapply(1:p, function(i) dyf[tt - i]))
    f <- .lm.fit(X, dyf[tt])
    ne * log(sum(f$residuals^2) / ne) + ncol(X) * log(ne)
  }, numeric(1))
  (0:pmax)[which.min(bics)]
}

t_ultima <- function(X, y) {
  k <- ncol(X)
  f <- .lm.fit(X, y)
  if (f$rank < k || f$pivot[k] != k) return(NA_real_)
  s2 <- sum(f$residuals^2) / (length(y) - k)
  f$coefficients[k] / (sqrt(s2) / abs(f$qr[k, k]))
}

# Busca em grade de duas quebras. TB = ultimo trimestre do regime anterior; TB em [h, n - h] e TB2 - TB1 >= h,
# com h = piso(0,15 n). Estatistica = minimo do t do coeficiente de y_{t-1} (LP e IO) ou de ytil_{t-1} (AO).
ur_duas_quebras <- function(y, p, modelo) {
  n <- length(y)
  h <- max(3L, floor(TRIM_UR * n))
  tt <- (p + 2):n
  ne <- length(tt)
  dyf <- c(NA, diff(y))
  best <- Inf; b1 <- NA_integer_; b2 <- NA_integer_
  if (modelo %in% c("LP", "IO")) {
    dep <- dyf[tt]
    L <- if (p > 0) sapply(1:p, function(i) dyf[tt - i]) else NULL
    base <- if (modelo == "LP") cbind(rep(1, ne), tt, L) else cbind(rep(1, ne), L)
    nb <- NCOL(base)
    X <- cbind(base, matrix(0, ne, 4), y[tt - 1])
    for (T1 in h:(n - 2 * h)) for (T2 in (T1 + h):(n - h)) {
      if (modelo == "LP") {
        X[, nb + 1] <- tt > T1; X[, nb + 2] <- pmax(tt - T1, 0)
        X[, nb + 3] <- tt > T2; X[, nb + 4] <- pmax(tt - T2, 0)
      } else {
        X[, nb + 1] <- tt > T1; X[, nb + 2] <- tt == T1 + 1
        X[, nb + 3] <- tt > T2; X[, nb + 4] <- tt == T2 + 1
      }
      tst <- t_ultima(X, dep)
      if (!is.na(tst) && tst < best) { best <- tst; b1 <- T1; b2 <- T2 }
    }
  } else {
    ti <- seq_len(n)
    Z <- cbind(1, numeric(n), numeric(n))
    for (T1 in h:(n - 2 * h)) for (T2 in (T1 + h):(n - h)) {
      Z[, 2] <- ti > T1; Z[, 3] <- ti > T2
      yt <- .lm.fit(Z, y)$residuals
      dyt <- c(NA, diff(yt))
      D <- cbind(sapply(0:p, function(i) as.numeric(tt - i == T1 + 1)),
                 sapply(0:p, function(i) as.numeric(tt - i == T2 + 1)))
      L <- if (p > 0) sapply(1:p, function(i) dyt[tt - i]) else NULL
      X <- cbind(D, L, yt[tt - 1])
      tst <- t_ultima(X, dyt[tt])
      if (!is.na(tst) && tst < best) { best <- tst; b1 <- T1; b2 <- T2 }
    }
  }
  list(stat = best, tb1 = b1, tb2 = b2, h = h)
}

testes_ur <- function(y) {
  p_t <- lag_bic(y, tendencia = TRUE)
  p_c <- lag_bic(y, tendencia = FALSE)
  c(LP = ur_duas_quebras(y, p_t, "LP")$stat,
    IO = ur_duas_quebras(y, p_c, "IO")$stat,
    AO = ur_duas_quebras(y, p_c, "AO")$stat)
}

# Valores criticos por Monte Carlo sob a nula (passeio aleatorio, erros N(0,1), y_0 = 0), mesmo T de cada serie
# e mesma regra de lags. Todas as series simuladas sao sorteadas antes, com set.seed(42), no processo principal.
Ts <- sort(unique(vapply(dados_series, function(d) nrow(d), integer(1))))
set.seed(42)
sims <- lapply(Ts, function(Tn) matrix(apply(matrix(rnorm(Tn * NREP), Tn, NREP), 2, cumsum), Tn, NREP))
names(sims) <- as.character(Ts)
t_mc <- Sys.time()
mc <- lapply(names(sims), function(nm) {
  S <- sims[[nm]]
  r <- parallel::mclapply(seq_len(ncol(S)), function(j) testes_ur(S[, j]), mc.cores = NCORES)
  do.call(rbind, r)
})
names(mc) <- names(sims)
t_mc <- as.numeric(difftime(Sys.time(), t_mc, units = "secs"))
cv_mc <- bind_rows(lapply(names(mc), function(nm) {
  M <- mc[[nm]]
  bind_rows(lapply(colnames(M), function(te) tibble(T = as.integer(nm), teste = te,
                                                    cv1 = quantile(M[, te], 0.01, na.rm = TRUE),
                                                    cv5 = quantile(M[, te], 0.05, na.rm = TRUE),
                                                    cv10 = quantile(M[, te], 0.10, na.rm = TRUE),
                                                    n_valid = sum(!is.na(M[, te])))))
}))
p_mc <- function(stat, Tn, te) mean(mc[[as.character(Tn)]][, te] <= stat, na.rm = TRUE)

ur_serie <- function(s) {
  d <- dados_series[[s]]
  y <- d$y; keys <- d$trimestre; n <- length(y)
  p_t <- lag_bic(y, tendencia = TRUE)
  p_c <- lag_bic(y, tendencia = FALSE)
  za <- urca::ur.za(y, model = "both", lag = p_t)
  h <- floor(TRIM_UR * n)
  ok <- seq_along(za@tstats) >= h & seq_along(za@tstats) <= n - h
  za_trim_i <- which(ok)[which.min(za@tstats[ok])]
  lp <- ur_duas_quebras(y, p_t, "LP")
  io <- ur_duas_quebras(y, p_c, "IO")
  ao <- ur_duas_quebras(y, p_c, "AO")
  nx <- function(i) ifelse(is.na(i), NA, keys[i + 1])
  cvs <- function(te) cv_mc[cv_mc$T == n & cv_mc$teste == te, ]
  tibble(serie = s, n = n, lag_tend = p_t, lag_const = p_c,
         za_stat = za@teststat, za_data = nx(za@bpoint), za_cv5 = za@cval[2], za_cv1 = za@cval[1], za_cv10 = za@cval[3],
         za_trim_stat = za@tstats[za_trim_i], za_trim_data = nx(za_trim_i),
         lp_stat = lp$stat, lp_d1 = nx(lp$tb1), lp_d2 = nx(lp$tb2), lp_cv5 = cvs("LP")$cv5, lp_p = p_mc(lp$stat, n, "LP"),
         io_stat = io$stat, io_d1 = nx(io$tb1), io_d2 = nx(io$tb2), io_cv5 = cvs("IO")$cv5, io_p = p_mc(io$stat, n, "IO"),
         ao_stat = ao$stat, ao_d1 = nx(ao$tb1), ao_d2 = nx(ao$tb2), ao_cv5 = cvs("AO")$cv5, ao_p = p_mc(ao$stat, n, "AO"))
}
ur_tab <- bind_rows(lapply(SERIES, ur_serie))

# ---------------------------------------------------------------------------------------------
# VAR da dissertacao (arquivos originais) e VAR estendido 2003T1-2025T4
# ---------------------------------------------------------------------------------------------
var_fit <- function(dY, dX, p = 3) {
  dX <- dX[, apply(dX, 2, function(v) sd(v) > 0), drop = FALSE]
  vars::VAR(dY, p = p, type = "both", exogen = dX)
}
var_elast <- function(m, hs = c(12, 40)) {
  imp <- colnames(m$y)[1]
  ir <- vars::irf(m, impulse = imp, response = colnames(m$y), n.ahead = max(hs), ortho = TRUE,
                  cumulative = TRUE, boot = FALSE)$irf[[imp]]
  out <- c()
  for (h in hs) {
    out[paste0("acum_inv_h", h)] <- ir[h + 1, 1]
    out[paste0("acum_priv_h", h)] <- ir[h + 1, 2]
    out[paste0("el_h", h)] <- ir[h + 1, 2] / ir[h + 1, 1]
  }
  out["impacto"] <- ir[1, 2]
  out["raiz_max"] <- max(vars::roots(m, modulus = TRUE))   # estabilidade: modulo da maior raiz do polinomio
  out
}

# Original: VAR(diff(infmeq), p = 3, type = "both", exogen = diff(exo)), 2002T1-2019T4.
Y_orig <- as.matrix(orig_end[, c("INF", "PVD")])
X_orig <- as.matrix(orig_exo[, c("PIB", "JUR", "DUM")])
dY_orig <- diff(Y_orig); dX_orig <- diff(X_orig)
keys_dorig <- keys_orig[-1]
m_orig <- var_fit(dY_orig, dX_orig)
el_orig <- var_elast(m_orig)
stopifnot(abs(el_orig["el_h40"] - 0.4163) < 5e-4, abs(el_orig["impacto"] - 0.0118) < 5e-5)

# Estendido: inf_diss (A3, real, X-11 por componente) e fbcf_me (A2), log10; exogenas diff do PIB (variacao trimestral)
# e diff da Selic meta no fim do trimestre (em fracao, como o JUR do arquivo original).
ext <- tibble(trimestre = ch$trimestre, inf = ch$inf_diss) %>%
  inner_join(a2 %>% transmute(trimestre, fbcf = fbcf_me_l10, pib = pib_cresc, selic = selic_fim / 100), by = "trimestre") %>%
  filter(trimestre >= "2003Q1", trimestre <= "2025Q4")
stopifnot(nrow(ext) == 92, !anyNA(ext))
keys_ext <- ext$trimestre
keys_dext <- keys_ext[-1]
dY_ext <- diff(as.matrix(ext[, c("inf", "fbcf")]))
dX_ext <- diff(as.matrix(ext[, c("pib", "selic")]))
m_ext <- var_fit(dY_ext, dX_ext)
el_ext <- var_elast(m_ext)

log_part("A4", sprintf("- VAR da dissertacao (arquivos originais): conferido, impacto %s e elasticidade de longo prazo %s em h = 40 (A1: 0,0118 e 0,4163). VAR estendido: diff de inf_diss e fbcf_me (log10), p = 3, constante e tendencia, exogenas diff(pib_cresc) e diff(selic_fim/100), dados 2003T1-2025T4, %d observacoes efetivas (%s a %s). Elasticidade (resposta acumulada de fbcf_me / de inf_diss, Cholesky com inf_diss primeiro): h = 12 %s; h = 40 %s; impacto %s.",
                       fnum(el_orig["impacto"], 4), fnum(el_orig["el_h40"], 4), nrow(m_ext$datamat),
                       qt(keys_dext[4]), qt(keys_dext[length(keys_dext)]),
                       fnum(el_ext["el_h12"], 3), fnum(el_ext["el_h40"], 3), fnum(el_ext["impacto"], 4)))

# Equacoes como regressoes lineares (mesmos regressores do VAR). No original, a dummy diferenciada (pulsos em 2018T2,
# 2019T2 e 2019T3) fica fora dos testes de quebra: ela e zero em qualquer segmento antes de 2018 e torna as
# regressoes por segmento singulares.
eq_data <- function(m, keys_d) {
  dm <- as.data.frame(m$datamat)
  dm$trimestre <- keys_d[(m$p + 1):length(keys_d)]
  dm
}
dm_orig <- eq_data(m_orig, keys_dorig)
dm_ext <- eq_data(m_ext, keys_dext)
lags_f <- function(vn) paste(as.vector(outer(vn, 1:3, function(a, b) paste0(a, ".l", b))), collapse = " + ")
EQS <- list(
  orig_INF = list(dm = dm_orig, f = as.formula(paste("INF ~", lags_f(c("INF", "PVD")), "+ trend + PIB + JUR")),
                  rotulo = "Dissertacao, equacao de INF", dep = "INF"),
  orig_PVD = list(dm = dm_orig, f = as.formula(paste("PVD ~", lags_f(c("INF", "PVD")), "+ trend + PIB + JUR")),
                  rotulo = "Dissertacao, equacao de PVD", dep = "PVD"),
  orig_INF_sd = list(dm = dm_orig[!dm_orig$trimestre %in% c("2018Q2", "2019Q2", "2019Q3"), ],
                     f = as.formula(paste("INF ~", lags_f(c("INF", "PVD")), "+ trend + PIB + JUR")),
                     rotulo = "Dissertacao, INF, sem 2018T2, 2019T2 e 2019T3", dep = "INF"),
  orig_PVD_sd = list(dm = dm_orig[!dm_orig$trimestre %in% c("2018Q2", "2019Q2", "2019Q3"), ],
                     f = as.formula(paste("PVD ~", lags_f(c("INF", "PVD")), "+ trend + PIB + JUR")),
                     rotulo = "Dissertacao, PVD, sem 2018T2, 2019T2 e 2019T3", dep = "PVD"),
  ext_inf = list(dm = dm_ext, f = as.formula(paste("inf ~", lags_f(c("inf", "fbcf")), "+ trend + pib + selic")),
                 rotulo = "Estendido, equacao de inf_diss", dep = "inf"),
  ext_fbcf = list(dm = dm_ext, f = as.formula(paste("fbcf ~", lags_f(c("inf", "fbcf")), "+ trend + pib + selic")),
                  rotulo = "Estendido, equacao de fbcf_me", dep = "fbcf")
)
# conferencia: a equacao estendida reproduz o VAR
stopifnot(max(abs(coef(lm(EQS$ext_fbcf$f, data = dm_ext))[-1] -
                    coef(m_ext$varresult$fbcf)[names(coef(lm(EQS$ext_fbcf$f, data = dm_ext)))[-1]])) < 1e-10)

rss_idx <- function(X, y, idx) sum(.lm.fit(X[idx, , drop = FALSE], y[idx])$residuals^2)
chow_eq <- function(X, y, i) {
  n <- nrow(X); k <- ncol(X); n1 <- i; n2 <- n - i
  R <- rss_idx(X, y, 1:n)
  if (n1 > k && n2 > k) {
    R1 <- rss_idx(X, y, 1:n1); R2 <- rss_idx(X, y, (n1 + 1):n)
    Fv <- ((R - R1 - R2) / k) / ((R1 + R2) / (n - 2 * k))
    return(tibble(tipo = "quebra", F = Fv, gl1 = k, gl2 = n - 2 * k, p = pf(Fv, k, n - 2 * k, lower.tail = FALSE)))
  }
  if (n1 > k && n2 >= 1) {
    R1 <- rss_idx(X, y, 1:n1)
    Fv <- ((R - R1) / n2) / (R1 / (n1 - k))
    return(tibble(tipo = "preditivo", F = Fv, gl1 = n2, gl2 = n1 - k, p = pf(Fv, n2, n1 - k, lower.tail = FALSE)))
  }
  if (n2 > k && n1 >= 1) {
    R2 <- rss_idx(X, y, (n1 + 1):n)
    Fv <- ((R - R2) / n1) / (R2 / (n2 - k))
    return(tibble(tipo = "preditivo (retro)", F = Fv, gl1 = n1, gl2 = n2 - k, p = pf(Fv, n1, n2 - k, lower.tail = FALSE)))
  }
  NULL
}

teste_eq <- function(nm) {
  E <- EQS[[nm]]
  dm <- E$dm; f <- E$f
  X <- model.matrix(f, dm); y <- dm[[E$dep]]
  n <- nrow(X); k <- ncol(X)
  h <- max(floor(0.15 * n), k + 1)
  maxb <- min(5, floor(n / h) - 1)   # no maximo 5 quebras, limitado por (m + 1) h <= n
  bp <- breakpoints(f, data = dm, h = h, breaks = maxb)
  sm <- summary(bp)$RSS
  mm <- as.integer(colnames(sm))
  bic <- sm["BIC", ]
  lwz <- lwz_crit(sm["RSS", ], n, k, mm)
  m_bic <- mm[which.min(bic)]
  m_lwz <- mm[which.min(lwz)]
  keys <- dm$trimestre
  db <- bp_datas(bp, m_bic, keys)
  dl <- bp_datas(bp, m_lwz, keys)
  fs <- Fstats(f, data = dm, from = h, to = n - h)
  st <- sctest(fs, type = "supF")
  e1 <- sctest(efp(f, data = dm, type = "OLS-CUSUM"))
  e1l <- sctest(efp(f, data = dm, type = "OLS-CUSUM", lrvar = TRUE))
  e2 <- sctest(efp(f, data = dm, type = "OLS-MOSUM", h = 0.15))
  datas_chow <- c(DATAS_APRIORI, "2018Q4",
                  if (grepl("^ext", nm)) c(DATAS_DADOS$sest$datas, "2018Q1") else character(0))
  datas_chow <- unique(datas_chow)
  ch_tab <- bind_rows(lapply(datas_chow, function(dq) {
    i <- match(dq, keys) - 1
    if (is.na(i) || i < 1) return(NULL)
    r <- chow_eq(X, y, i)
    if (is.null(r)) return(NULL)
    r$data <- dq
    r$origem <- if (dq %in% DATAS_APRIORI) "a priori" else "dados"
    r
  }))
  list(eq = nm, rotulo = E$rotulo, n = n, k = k, h = h, maxb = maxb, m_bic = m_bic, m_lwz = m_lwz, bp_bic = db, bp_lwz = dl,
       bic = bic, lwz = lwz,
       supF = unname(st$statistic), supF_p = st$p.value, supF_data = keys[breakpoints(fs)$breakpoints + 1],
       cusum = unname(e1$statistic), cusum_p = e1$p.value, cusum_lr = unname(e1l$statistic), cusum_lr_p = e1l$p.value,
       mosum = unname(e2$statistic), mosum_p = e2$p.value, chow = ch_tab)
}
res_eqs <- setNames(lapply(names(EQS), teste_eq), names(EQS))

# Dummies nas equacoes (acrescentadas aos regressores do VAR, com a dummy do arquivo no original)
teste_dummy_eq <- function(nm, tipo) {
  E <- EQS[[nm]]
  dm <- E$dm
  keys <- dm$trimestre
  if (grepl("_sd$", nm)) return(NULL)
  f0 <- if (grepl("^orig", nm)) update(E$f, . ~ . + DUM) else E$f
  if (tipo %in% c("eleicao", "eleicao2006")) {
    x <- dif_pulso(keys, if (tipo == "eleicao") ELEICOES else ELEICOES_COM2006)
    if (sum(abs(x)) == 0) return(NULL)
    dm$x_d <- x
    fit <- lm(update(f0, . ~ . + x_d), data = dm)
    ct <- lmtest::coeftest(fit, vcov. = nw(fit))
    return(tibble(eq = nm, teste = tipo, coef = coef(fit)["x_d"], t = coef(summary(fit))["x_d", "t value"],
                  p = coef(summary(fit))["x_d", "Pr(>|t|)"], t_hac = ct["x_d", "t value"], p_hac = ct["x_d", "Pr(>|t|)"],
                  F = NA, gl1 = 1))
  }
  datas <- switch(tipo, imp2017 = q_seq("2017Q1", "2018Q1"), pandemia = c("2020Q2", "2020Q3"))
  if (!all(datas %in% keys)) return(NULL)
  for (j in seq_along(datas)) dm[[paste0("pz", j)]] <- as.numeric(keys == datas[j])
  f1 <- update(f0, as.formula(paste(". ~ . +", paste0("pz", seq_along(datas), collapse = " + "))))
  a <- anova(lm(f0, data = dm), lm(f1, data = dm))
  tibble(eq = nm, teste = tipo, coef = NA, t = NA, p = a$`Pr(>F)`[2], t_hac = NA, p_hac = NA, F = a$F[2], gl1 = length(datas))
}
dummies_eq <- bind_rows(lapply(names(EQS), function(nm) bind_rows(
  teste_dummy_eq(nm, "eleicao"), teste_dummy_eq(nm, "eleicao2006"),
  teste_dummy_eq(nm, "imp2017"), teste_dummy_eq(nm, "pandemia"))))

# ---------------------------------------------------------------------------------------------
# Estimacao: recursiva, janela movel, subamostras e dummies
# ---------------------------------------------------------------------------------------------
JAN <- 40
p_var <- 3
n_d <- nrow(dY_ext)
var_janela <- function(r1, r2) {
  m <- var_fit(dY_ext[r1:r2, , drop = FALSE], dX_ext[r1:r2, , drop = FALSE])
  var_elast(m)
}
# Janela crescente: inicio fixo em 2003T2 (primeira diferenca), fim variando; primeira janela com 40 observacoes efetivas.
rec <- bind_rows(lapply((JAN + p_var):n_d, function(e) {
  v <- var_janela(1, e)
  tibble(esquema = "Recursiva", fim = keys_dext[e], !!!as.list(v))
}))
rol <- bind_rows(lapply((JAN + p_var):n_d, function(e) {
  v <- var_janela(e - JAN - p_var + 1, e)
  tibble(esquema = "Janela movel (40)", fim = keys_dext[e], !!!as.list(v))
}))

# Janelas com VAR explosivo (maior raiz com modulo >= 1) ficam fora da figura e dos resumos: nelas a resposta
# acumulada nao converge e a razao nao e uma elasticidade.
rec$estavel <- rec$raiz_max < 1
rol$estavel <- rol$raiz_max < 1

# Projecao local simples: fbcf_{t+h} - fbcf_{t-1} sobre diff(inf)_t, com 3 defasagens das duas diferencas,
# diff do PIB e da Selic em t e constante; erros de Newey-West com h + 1 defasagens.
LP_H <- 8
lp_base <- local({
  inf <- ext$inf; fb <- ext$fbcf
  n <- length(inf)
  dinf <- c(NA, diff(inf)); dfb <- c(NA, diff(fb))
  dpib <- c(NA, diff(ext$pib)); dsel <- c(NA, diff(ext$selic))
  lagv <- function(v, j) c(rep(NA, j), v[seq_len(n - j)])
  tibble(t = seq_len(n), trimestre = keys_ext, dinf = dinf,
         dinf_l1 = lagv(dinf, 1), dinf_l2 = lagv(dinf, 2), dinf_l3 = lagv(dinf, 3),
         dfb_l1 = lagv(dfb, 1), dfb_l2 = lagv(dfb, 2), dfb_l3 = lagv(dfb, 3),
         dpib = dpib, dsel = dsel,
         yfb = c(fb[(1 + LP_H):n], rep(NA, LP_H)) - lagv(fb, 1),
         yinf = c(inf[(1 + LP_H):n], rep(NA, LP_H)) - lagv(inf, 1))
})
lp_rows <- which(complete.cases(lp_base))
lp_fit <- function(rows) {
  d <- lp_base[rows, ]
  f1 <- lm(yfb ~ dinf + dinf_l1 + dinf_l2 + dinf_l3 + dfb_l1 + dfb_l2 + dfb_l3 + dpib + dsel, data = d)
  f2 <- lm(yinf ~ dinf + dinf_l1 + dinf_l2 + dinf_l3 + dfb_l1 + dfb_l2 + dfb_l3 + dpib + dsel, data = d)
  se <- sqrt(sandwich::NeweyWest(f1, lag = LP_H + 1, prewhite = FALSE, adjust = TRUE)["dinf", "dinf"])
  c(lp_fbcf_h8 = unname(coef(f1)["dinf"]), lp_se_h8 = se, lp_inf_h8 = unname(coef(f2)["dinf"]),
    lp_el_h8 = unname(coef(f1)["dinf"] / coef(f2)["dinf"]), lp_n = nrow(d))
}
lp_full <- lp_fit(lp_rows)
nl <- length(lp_rows)
lp_rec <- bind_rows(lapply(JAN:nl, function(e) {
  tibble(esquema = "Recursiva", fim = lp_base$trimestre[lp_rows[e]], !!!as.list(lp_fit(lp_rows[1:e])))
}))
lp_rol <- bind_rows(lapply(JAN:nl, function(e) {
  tibble(esquema = "Janela movel (40)", fim = lp_base$trimestre[lp_rows[e]], !!!as.list(lp_fit(lp_rows[(e - JAN + 1):e])))
}))
# No LP, a data de fim da janela e a data do choque t da ultima observacao (a resposta vai ate t + 8).

# Subamostras antes e depois de 2014T4 (observacoes efetivas ate 2014T4 e de 2015T1 em diante; as defasagens
# iniciais da segunda subamostra vem de 2014). Mesmo corte e mesma definicao no A5_var e no A5_lp. Na projecao local,
# observacao efetiva = t e t + 8 dentro da subamostra (a resposta nao atravessa o corte); as defasagens podem vir de antes.
sub_var <- function(de, ate) {
  rows <- which(keys_dext >= de & keys_dext <= ate)
  stopifnot(rows[1] > p_var)
  v <- var_janela(rows[1] - p_var, rows[length(rows)])
  c(v, n_ef = length(rows))
}
sub_lp <- function(de, ate) lp_fit(lp_rows[lp_base$trimestre[lp_rows] >= de & keys_ext[lp_rows + LP_H] <= ate])
subs <- list(
  c("Amostra completa", "2004Q1", "2025Q4"),
  c("Ate 2014T4", "2004Q1", "2014Q4"),
  c("De 2015T1", "2015Q1", "2025Q4"),
  c("Ate 2019T4", "2004Q1", "2019Q4")
)
tab_sub <- bind_rows(lapply(subs, function(s) {
  v <- sub_var(s[2], s[3])
  l <- sub_lp(s[2], s[3])
  tibble(amostra = s[1], de = s[2], ate = s[3], !!!as.list(v), !!!as.list(l))
}))
# original, ate 2014T4
rows_o <- which(keys_dorig <= "2014Q4")
el_orig_pre <- var_elast(var_fit(dY_orig[rows_o, ], dX_orig[rows_o, ]))

# Dummies no VAR (exogenas adicionais na equacao em diferenca): degrau = mudanca de drift; pulso = salto de nivel.
dummy_d <- function(keys_d, tipo, datas) {
  switch(tipo,
         degrau = as.numeric(keys_d >= datas[1]),
         pulso = as.numeric(keys_d %in% datas),
         janela = as.numeric(keys_d >= datas[1] & keys_d <= datas[2]),
         eleicao = dif_pulso(keys_d, datas))
}
exp_dummy <- function(tipo, datas, rotulo, alvo = "ext") {
  kd <- if (alvo == "ext") keys_dext else keys_dorig
  # pulsos em varias datas entram como regressores separados, um por data
  Dm <- if (tipo == "pulso") sapply(datas, function(dq) dummy_d(kd, "pulso", dq)) else cbind(dummy_d(kd, tipo, datas))
  Dm <- matrix(Dm, nrow = length(kd), dimnames = list(NULL, paste0("dm", seq_len(NCOL(Dm)))))
  if (any(apply(Dm, 2, sd) == 0)) return(NULL)
  m <- if (alvo == "ext") var_fit(dY_ext, cbind(dX_ext, Dm)) else var_fit(dY_orig, cbind(dX_orig, Dm))
  tibble(modelo = alvo, experimento = rotulo, tipo = tipo, !!!as.list(var_elast(m)))
}
exps <- list()
for (dq in DATAS_APRIORI) {
  exps[[length(exps) + 1]] <- exp_dummy("degrau", dq, paste0("Degrau em ", qt(dq)))
  exps[[length(exps) + 1]] <- exp_dummy("pulso", dq, paste0("Pulso em ", qt(dq)))
  if (dq <= "2019Q4") {
    exps[[length(exps) + 1]] <- exp_dummy("degrau", dq, paste0("Degrau em ", qt(dq)), "orig")
    exps[[length(exps) + 1]] <- exp_dummy("pulso", dq, paste0("Pulso em ", qt(dq)), "orig")
  }
}
exps[[length(exps) + 1]] <- exp_dummy("pulso", c("2020Q2", "2020Q3"), "Pulsos em 2020T2 e 2020T3")
exps[[length(exps) + 1]] <- exp_dummy("eleicao", ELEICOES, "T4 eleitoral (2010, 2014, 2018, 2022)")
exps[[length(exps) + 1]] <- exp_dummy("eleicao", ELEICOES_COM2006, "T4 eleitoral com 2006")
exps[[length(exps) + 1]] <- exp_dummy("eleicao", c("2010Q4", "2014Q4", "2018Q4"), "T4 eleitoral (2010, 2014, 2018)", "orig")
exps[[length(exps) + 1]] <- exp_dummy("degrau", "2020Q1", "Degrau em 2020T1 (emenda da SEST)")
exps[[length(exps) + 1]] <- exp_dummy("eleicao", "2018Q4", "T4 eleitoral de 2018 so")
# Pulsos da imputacao de 2017 (5 pulsos de 2017T1 a 2018T1)
local({
  D <- cbind(dX_ext, sapply(q_seq("2017Q1", "2018Q1"), function(k) as.numeric(keys_dext == k)))
  colnames(D)[-(1:2)] <- paste0("imp", 1:5)
  exps[[length(exps) + 1]] <<- tibble(modelo = "ext", experimento = "Pulsos de 2017T1 a 2018T1 (imputacao)", tipo = "pulso",
                                      !!!as.list(var_elast(var_fit(dY_ext, D))))
})
# DUM da dissertacao (1 em 2018T2-2019T1 e 2019T3-2019T4, zero no resto, inclusive depois de 2019) e os outliers do
# X-11 de inf_diss da A3 (A3_dummies_outliers.csv, em nivel: AO = impulso, LS = degrau), todos diferenciados como as
# exogenas do VAR.
dum_nivel <- as.numeric(keys_ext %in% c(q_seq("2018Q2", "2019Q1"), "2019Q3", "2019Q4"))
out_a3 <- readr::read_csv(file.path(PATHS$processed, "A3_dummies_outliers.csv"), show_col_types = FALSE)
dums_inf <- strsplit(meta$dummies_outliers[meta$serie == "inf_diss"], " ")[[1]]
stopifnot(all(dums_inf %in% names(out_a3)))
exp_nivel <- function(M, rotulo) {
  D <- cbind(dX_ext, diff(as.matrix(M)))
  tibble(modelo = "ext", experimento = rotulo, tipo = "nivel diferenciado", !!!as.list(var_elast(var_fit(dY_ext, D))))
}
M_out <- out_a3[match(keys_ext, out_a3$trimestre), dums_inf]
exps[[length(exps) + 1]] <- exp_nivel(tibble(DUM = dum_nivel), "DUM da dissertacao (2018T2-2019T1, 2019T3-2019T4)")
exps[[length(exps) + 1]] <- exp_nivel(M_out, paste0("Outliers do X-11 de inf_diss (", paste(dums_inf, collapse = ", "), ")"))
exps[[length(exps) + 1]] <- exp_nivel(M_out[, grepl("2018|2019", dums_inf)], "Outliers do X-11 de 2018-2019")
exps[[length(exps) + 1]] <- exp_nivel(M_out[, grepl("2020|2021", dums_inf)], "Outliers do X-11 de 2020-2021")
exps[[length(exps) + 1]] <- exp_nivel(cbind(M_out, p2 = as.numeric(keys_ext >= "2020Q2"), p3 = as.numeric(keys_ext >= "2020Q3")),
                                      "Outliers do X-11 e pulsos em 2020T2 e 2020T3")
# Dummies nas datas de Bai-Perron das equacoes estendidas (degrau)
datas_bp_ext <- unique(c(res_eqs$ext_inf$bp_bic$datas, res_eqs$ext_fbcf$bp_bic$datas,
                         res_eqs$ext_inf$bp_lwz$datas, res_eqs$ext_fbcf$bp_lwz$datas))
for (dq in datas_bp_ext) exps[[length(exps) + 1]] <- exp_dummy("degrau", dq, paste0("Degrau em ", qt(dq), " (Bai-Perron)"))
tab_exp <- bind_rows(exps)

# Variantes de dados de inf_diss (A3): imputacao de 2017, emenda da SEST, X-11 na soma, sem o efeito dos AO
variantes <- c(inf_diss_imprazao = "Imputacao de 2017 pela razao do trimestre",
               inf_diss_impapendice = "Imputacao de 2017 pelo Apendice A",
               inf_diss_e2017 = "Emenda da SEST em 2017T1", inf_diss_e2018 = "Emenda da SEST em 2018T1",
               inf_diss_e2019 = "Emenda da SEST em 2019T1", inf_diss_e2020 = "Emenda em 2020T1, razao de 2019",
               inf_diss_e2020_r1618 = "Emenda em 2020T1, razao de 2016-2018",
               inf_diss_x11soma = "X-11 depois de somar")
tab_var <- bind_rows(lapply(names(variantes), function(v) {
  yv <- ch[[v]][match(keys_ext, ch$trimestre)]
  dY <- diff(cbind(inf = yv, fbcf = ext$fbcf))
  tibble(modelo = "ext", experimento = variantes[[v]], serie = v, !!!as.list(var_elast(var_fit(dY, dX_ext))))
}))
local({
  yv <- chs$inf_diss[match(keys_ext, chs$trimestre)]
  dY <- diff(cbind(inf = yv, fbcf = ext$fbcf))
  tab_var <<- bind_rows(tab_var, tibble(modelo = "ext", experimento = "Sem o efeito dos AO do X-11", serie = "inf_diss (semao)",
                                        !!!as.list(var_elast(var_fit(dY, dX_ext)))))
})

# Regra: uma quebra "importa" se muda o sinal da elasticidade em h = 40 ou a desloca em mais de 25% do valor da amostra
# completa (em modulo); o mesmo em h = 12.
base_el <- c(ext = unname(el_ext["el_h40"]), orig = unname(el_orig["el_h40"]))
base_el12 <- c(ext = unname(el_ext["el_h12"]), orig = unname(el_orig["el_h12"]))
marca <- function(modelo, e40, e12) {
  b40 <- base_el[modelo]; b12 <- base_el12[modelo]
  sinal <- sign(e40) != sign(b40) | sign(e12) != sign(b12)
  desl <- abs(e40 - b40) / abs(b40) > 0.25 | abs(e12 - b12) / abs(b12) > 0.25
  ifelse(sinal, "muda o sinal", ifelse(desl, "muda mais de 25%", "nao muda"))
}
tab_exp$efeito <- marca(tab_exp$modelo, tab_exp$el_h40, tab_exp$el_h12)
tab_var$efeito <- marca(tab_var$modelo, tab_var$el_h40, tab_var$el_h12)
tab_sub$efeito <- marca("ext", tab_sub$el_h40, tab_sub$el_h12)

# ---------------------------------------------------------------------------------------------
# Selecao das dummies para a A5 (regra explicita, a partir dos testes acima)
# ---------------------------------------------------------------------------------------------
eqx <- function(nm, dq) { r <- res_eqs[[nm]]$chow; if (is.null(r) || !nrow(r)) return(NA_real_); r$p[match(dq, r$data)] }
p_pand_fbcf <- dummies_eq$p[dummies_eq$eq == "ext_fbcf" & dummies_eq$teste == "pandemia"]
p_pand_inf <- dummies_eq$p[dummies_eq$eq == "ext_inf" & dummies_eq$teste == "pandemia"]
p_chow_2018_inf <- eqx("ext_inf", "2018Q4")
comp <- chow_dados %>% filter(grepl("Composicao", origem), data == "2011Q1")
n_comp_hac <- sum(comp$p_hac < 0.05)
el_row <- function(tab, exper) tab[tab$experimento == exper, , drop = FALSE]
e_pand <- el_row(tab_exp, "Pulsos em 2020T2 e 2020T3")
e_out1819 <- el_row(tab_exp, "Outliers do X-11 de 2018-2019")
e_out2021 <- el_row(tab_exp, "Outliers do X-11 de 2020-2021")
e_outall <- el_row(tab_exp, "Outliers do X-11 e pulsos em 2020T2 e 2020T3")
e_dum <- el_row(tab_exp, "DUM da dissertacao (2018T2-2019T1, 2019T3-2019T4)")
elec_hac <- dummies_media %>% filter(teste == "eleicao")
elec_eq <- dummies_eq %>% filter(teste == "eleicao", !grepl("_sd$", eq))

keys_dum <- q_seq("2002Q1", "2025Q4")
dum_meta <- list()
dum_cols <- list()
add_dummy <- function(nome, x, tipo, series_alvo, uso, justificativa) {
  dum_cols[[nome]] <<- x
  dts <- if (tipo == "degrau") paste0("de ", qt(keys_dum[x != 0][1]), " em diante") else paste(qt(keys_dum[x != 0]), collapse = " ")
  dum_meta[[length(dum_meta) + 1]] <<- tibble(nome = nome, tipo = tipo, datas = dts,
                                              series_ou_equacoes = series_alvo, uso = uso, justificativa = justificativa)
}
if (min(p_pand_fbcf, p_pand_inf) < 0.05) {
  just <- sprintf("Pandemia. supF das equacoes do VAR estendido com maximo em 2020T2 (inf_diss p = %s; fbcf_me p = %s); Chow em 2020T2 p = %s e %s; os dois pulsos juntos na equacao de fbcf_me: F = %s, p = %s. Com os pulsos a elasticidade em h = 40 vai de %s para %s.",
                  fp(res_eqs$ext_inf$supF_p), fp(res_eqs$ext_fbcf$supF_p), fp(eqx("ext_inf", "2020Q2")), fp(eqx("ext_fbcf", "2020Q2")),
                  fnum(dummies_eq$F[dummies_eq$eq == "ext_fbcf" & dummies_eq$teste == "pandemia"], 2), fp(p_pand_fbcf),
                  fnum(el_ext["el_h40"], 3), fnum(e_pand$el_h40, 3))
  add_dummy("pulso_2020T2", as.numeric(keys_dum == "2020Q2"), "pulso", "VAR estendido e LP com amostra ate 2025", "baseline", just)
  add_dummy("pulso_2020T3", as.numeric(keys_dum == "2020Q3"), "pulso", "VAR estendido e LP com amostra ate 2025", "baseline", just)
}
if (!is.na(p_chow_2018_inf) && p_chow_2018_inf < 0.05) {
  for (dn in dums_inf[grepl("2018|2019", dums_inf)]) {
    lv <- out_a3[[dn]][match(keys_dum, out_a3$trimestre)]
    lv[is.na(lv)] <- 0
    x <- c(0, diff(lv))
    add_dummy(paste0("d_", dn), x, if (grepl("^ao", dn)) "pulso (+1 e -1 no trimestre seguinte)" else "pulso",
              "VAR estendido e LP com inf_diss ou estatais_total", "robustez",
              sprintf("Outlier do X-11 de inf_diss (A3, via estatais_total, trecho do boletim da SEST), diferenciado para a equacao em diferenca (%s no nivel). Chow da equacao de inf_diss em 2018T4: p = %s; a equacao de INF da dissertacao sem a DUM tem quebra no fim da amostra (supF p = %s). Nao move o resultado: os quatro outliers de 2018-2019 levam a elasticidade em h = 40 de %s para %s; a DUM da dissertacao, para %s.",
                      if (grepl("^ao", dn)) "impulso" else "degrau", fp(p_chow_2018_inf), fp(res_eqs$orig_INF$supF_p),
                      fnum(el_ext["el_h40"], 3), fnum(e_out1819$el_h40, 3), fnum(e_dum$el_h40, 3)))
  }
}
p_chow_2020 <- min(eqx("ext_inf", "2020Q1"), eqx("ext_inf", "2020Q2"), eqx("ext_fbcf", "2020Q1"), eqx("ext_fbcf", "2020Q2"), na.rm = TRUE)
if (p_chow_2020 < 0.05) {
  for (dn in dums_inf[grepl("2020|2021", dums_inf)]) {
    lv <- out_a3[[dn]][match(keys_dum, out_a3$trimestre)]
    lv[is.na(lv)] <- 0
    add_dummy(paste0("d_", dn), c(0, diff(lv)), "pulso (+1 e -1 no trimestre seguinte)",
              "VAR estendido e LP com inf_diss ou estatais", "robustez",
              sprintf("AO do X-11 de inf_diss (A3, via estatais_total; picos da OI que a serie ajustada D11 mantem), diferenciado para a equacao em diferenca (impulso no nivel). Chow das equacoes estendidas em 2020T1 e 2020T2 com p minimo %s. E a quebra de dados que mais move o resultado: os tres AO de 2020-2021 levam a elasticidade em h = 40 de %s para %s (com os pulsos da pandemia, todos os outliers do X-11 dao %s). A A3 manteve os AO no baseline (decisao do coordenador); estas dummies sao a robustez equivalente a variante sem AO (%s).",
                      fp(p_chow_2020), fnum(el_ext["el_h40"], 3), fnum(e_out2021$el_h40, 3), fnum(e_outall$el_h40, 3),
                      fnum(tab_var$el_h40[tab_var$experimento == "Sem o efeito dos AO do X-11"], 3)))
  }
}
if (n_comp_hac >= 2) {
  add_dummy("degrau_2011T1", as.numeric(keys_dum >= "2011Q1"), "degrau", paste(comp$serie[comp$p_hac < 0.05], collapse = " "),
            "robustez nas LP com choques da Uniao",
            sprintf("Queda do crescimento medio da execucao direta da Uniao a partir de 2011 (fim da aceleracao de 2007-2010). Chow em media com t de Newey-West em 2011T1: p = %s. Bai-Perron (BIC e LWZ) nao seleciona quebra nessas series; a janela 2011T1-2016T4 da mudanca de composicao por elemento nao e significativa (p de Newey-West de %s a %s). Na equacao em diferenca, um degrau muda o drift.",
                    paste(sprintf("%s %s", comp$serie, fp(comp$p_hac)), collapse = "; "),
                    fp(min(dummies_media$p_hac[dummies_media$teste == "composicao"])),
                    fp(max(dummies_media$p_hac[dummies_media$teste == "composicao"]))))
}
dummies_out <- bind_cols(tibble(trimestre = keys_dum), as_tibble(dum_cols))
dummies_meta <- bind_rows(dum_meta) %>% mutate(justificativa = gsub("= <0,001", "< 0,001", justificativa, fixed = TRUE)) %>%
  mutate(forma = "Regressor da equacao em diferenca (VAR em diferenca, LP em diferenca): entra como esta, sem diferenciar de novo.")

# ---------------------------------------------------------------------------------------------
# Tabelas LaTeX
# ---------------------------------------------------------------------------------------------
tex_tab <- function(caption, label, spec, header, rows, notes, size = "\\scriptsize") {
  c("\\begin{table}[htbp]", "\\centering", sprintf("\\caption{%s}", caption), sprintf("\\label{%s}", label), size,
    sprintf("\\begin{tabular}{%s}", spec), "\\toprule", header, "\\midrule", rows, "\\bottomrule", "\\end{tabular}",
    "\\begin{minipage}{0.97\\linewidth}\\footnotesize", paste0("\\medskip Notas: ", notes), "\\end{minipage}", "\\end{table}", "")
}
painel <- function(txt, ncol) sprintf("\\multicolumn{%d}{l}{\\textit{%s}} \\\\", ncol, txt)
bp_txt <- function(b, tex = TRUE) {
  if (length(b$datas) == 0) return("nenhuma")
  paste0(qt(b$datas), " [", ifelse(is.na(b$lo), "NA", qt(b$lo)), "; ", ifelse(is.na(b$hi), "NA", qt(b$hi)), "]", collapse = "; ")
}
eq_nomes <- names(res_eqs)
eq_lab <- c(orig_INF = "Disserta\\c{c}\\~ao, eq. INF", orig_PVD = "Disserta\\c{c}\\~ao, eq. PVD",
            orig_INF_sd = "Disserta\\c{c}\\~ao, eq. INF, sem pulsos DUM", orig_PVD_sd = "Disserta\\c{c}\\~ao, eq. PVD, sem pulsos DUM",
            ext_inf = "Estendido, eq. inf\\_diss", ext_fbcf = "Estendido, eq. fbcf\\_me")

# Tabela 1: Bai-Perron
t1_rows <- c(painel("A. S\\'eries: m\\'edia da diferen\\c{c}a do log10", 6),
             vapply(res_series, function(r) sprintf("%s & %s--%s & %d & %d & %d & %s \\\\", tex_esc(r$serie), qt(r$inicio), qt(r$fim), r$n,
                                                   r$m_bic, r$m_lwz,
                                                   if (r$m_bic == 0) paste0("nenhuma (", ftex(r$media_total, 1), "\\% a.a.)") else
                                                     paste0(bp_txt(r$bp_bic), "; regimes: ", paste(ftex(r$medias_bic, 1), collapse = " / "), "\\% a.a.")), ""),
             "\\midrule", painel("B. Equa\\c{c}\\~oes do VAR: todos os coeficientes", 6),
             vapply(res_eqs, function(r) sprintf("%s & %s--%s & %d & %d & %d & %s \\\\", eq_lab[r$eq], qt(EQS[[r$eq]]$dm$trimestre[1]),
                                                qt(tail(EQS[[r$eq]]$dm$trimestre, 1)), r$n, r$m_bic, r$m_lwz,
                                                paste0(bp_txt(r$bp_bic), if (r$m_lwz != r$m_bic) paste0("; LWZ: ", bp_txt(r$bp_lwz)) else "")), ""))
tex1 <- tex_tab("Quebras m\\'ultiplas de Bai-Perron (\\texttt{strucchange::breakpoints}, at\\'e 5 quebras)", "tab:a4_bp",
                "llcccl", "S\\'erie ou equa\\c{c}\\~ao & Amostra & $n$ & $m$ (BIC) & $m$ (LWZ) & Datas pelo BIC [IC 95\\%] \\\\",
                t1_rows,
                sprintf("Datas = primeiro trimestre do novo regime. S\\'eries: regress\\~ao da diferen\\c{c}a do log10 numa constante, segmento m\\'inimo $h = 0{,}15n$; entre par\\^enteses, crescimento m\\'edio da amostra em \\%% ao ano. Equa\\c{c}\\~oes: todos os coeficientes mudam; $h = \\max(0{,}15n, k + 1)$, que d\\'a %d observa\\c{c}\\~oes nas equa\\c{c}\\~oes da disserta\\c{c}\\~ao (%d regressores; a dummy diferenciada fica fora porque \\'e zero antes de 2018) e %d nas estendidas (%d regressores). As linhas ``sem pulsos DUM'' excluem 2018T2, 2019T2 e 2019T3, os tr\\^es trimestres em que a DUM diferenciada \\'e diferente de zero (com 65 observa\\c{c}\\~oes e $h = 11$, no m\\'aximo 4 quebras). LWZ: crit\\'erio de Liu, Wu e Zidek (1997), $c_0 = 0{,}299$, $\\delta_0 = 0{,}1$. IC das datas pelo m\\'etodo de Bai (1997) com erros heteroced\\'asticos entre segmentos.",
                        res_eqs$orig_INF$h, res_eqs$orig_INF$k, res_eqs$ext_inf$h, res_eqs$ext_inf$k))

# Tabela 2: supF
t2_rows <- c(painel("A. S\\'eries", 5),
             vapply(res_series, function(r) sprintf("%s & %s & %s & %s & %s \\\\", tex_esc(r$serie), ftex(r$supF, 2), fptex(r$supF_p),
                                                   qt(r$supF_data), fptex(r$supF_hac_p)), ""),
             "\\midrule", painel("B. Equa\\c{c}\\~oes do VAR", 5),
             vapply(res_eqs, function(r) sprintf("%s & %s & %s & %s & \\\\", eq_lab[r$eq], ftex(r$supF, 2), fptex(r$supF_p), qt(r$supF_data)), ""))
tex2 <- tex_tab("Teste sup-Wald de Andrews (1993) para uma quebra de data desconhecida", "tab:a4_supf", "lcccc",
                "S\\'erie ou equa\\c{c}\\~ao & sup$F$ & $p$ & Data do m\\'aximo & $p$ (Newey-West) \\\\", t2_rows,
                "\\texttt{Fstats} e \\texttt{sctest(type = \"supF\")}, trimming de 15\\% (nas equa\\c{c}\\~oes da disserta\\c{c}\\~ao, o mesmo $h$ da Tabela \\ref{tab:a4_bp}); $p$ assint\\'otico de Hansen (1997). Coluna Newey-West: estat\\'isticas de Wald com matriz de Newey-West (3 defasagens, sem pr\\'e-branqueamento), porque a diferen\\c{c}a das s\\'eries tem autocorrela\\c{c}\\~ao.")

# Tabela 3: Chow
datas_grid <- c(DATAS_APRIORI, "2018Q4")
chow_cell_s <- function(s, dq) {
  r <- chow_series[chow_series$serie == s & chow_series$data == dq, ]
  if (!nrow(r)) return("")
  sprintf("%s (%s)", ftex(r$p, 2), ftex(r$p_hac, 2))
}
chow_cell_e <- function(nm, dq) {
  r <- res_eqs[[nm]]$chow
  r <- r[r$data == dq, ]
  if (!nrow(r)) return("")
  paste0(ftex(r$p, 3), if (r$tipo != "quebra") "\\textsuperscript{P}" else "")
}
t3_rows <- c(painel("A. S\\'eries: $p$ do $F$ cl\\'assico ($p$ do $t$ de Newey-West)", 9),
             vapply(SERIES, function(s) paste0(tex_esc(s), " & ", paste(vapply(datas_grid, function(dq) chow_cell_s(s, dq), ""), collapse = " & "), " \\\\"), ""),
             "\\midrule", painel("B. Equa\\c{c}\\~oes do VAR: $p$ do $F$", 9),
             vapply(eq_nomes, function(nm) paste0(eq_lab[nm], " & ", paste(vapply(datas_grid, function(dq) chow_cell_e(nm, dq), ""), collapse = " & "), " \\\\"), ""))
tex3 <- tex_tab("Teste de Chow nas datas candidatas", "tab:a4_chow", paste0("l", strrep("c", length(datas_grid))),
                paste0("S\\'erie ou equa\\c{c}\\~ao & ", paste(qt(datas_grid), collapse = " & "), " \\\\"), t3_rows,
                sprintf("A data \\'e o primeiro trimestre do novo regime. 2018T4: execu\\c{c}\\~ao concentrada no T4 do ano eleitoral. S\\'eries: quebra na m\\'edia da diferen\\c{c}a do log10, com pelo menos %d diferen\\c{c}as em cada regime (c\\'elulas vazias: data fora da amostra ou regime curto demais); entre par\\^enteses, $p$ do degrau com erros de Newey-West (3 defasagens). Equa\\c{c}\\~oes: todos os coeficientes; P = teste preditivo de Chow, usado quando um dos regimes tem menos observa\\c{c}\\~oes que regressores.", MIN_SEG),
                size = "\\tiny")

# Tabela 4: quebras nos dados
t4_rows <- c(painel("A. Chow em m\\'edia nas datas das quebras de dados", 6),
             apply(chow_dados, 1, function(r) sprintf("%s & %s & %s & %s & %s & %s \\\\", tex_esc(r[["serie"]]),
                                                     gsub("dados: ", "", r[["origem"]]), qt(r[["data"]]), ftex(as.numeric(r[["F"]]), 2),
                                                     fptex(as.numeric(r[["p"]])), fptex(as.numeric(r[["p_hac"]])))),
             "\\midrule", painel("B. Dummies na m\\'edia da diferen\\c{c}a (coeficiente; $p$; $p$ Newey-West)", 6),
             apply(dummies_media[dummies_media$teste != "eleicao2006", ], 1, function(r) {
               te <- r[["teste"]]
               rot <- switch(te, eleicao = "T4 eleitoral 2010-2022", eleicao2006 = "T4 eleitoral 2006-2022",
                             imp2017 = "Pulsos 2017T1-2018T1 ($F$)", composicao = "Janela 2011T1-2016T4")
               est <- if (te == "imp2017") ftex(as.numeric(r[["F"]]), 2) else ftex(as.numeric(r[["coef"]]), 3)
               sprintf("%s & %s & & %s & %s & %s \\\\", tex_esc(r[["serie"]]), rot, est, fptex(as.numeric(r[["p"]])), fptex(as.numeric(r[["p_hac"]])))
             }),
             "\\midrule", painel("C. Dummies nas equa\\c{c}\\~oes do VAR", 6),
             apply(dummies_eq, 1, function(r) {
               te <- r[["teste"]]
               rot <- switch(te, eleicao = "T4 eleitoral", eleicao2006 = "T4 eleitoral com 2006",
                             imp2017 = "Pulsos 2017T1-2018T1 ($F$)", pandemia = "Pulsos 2020T2 e 2020T3 ($F$)")
               est <- if (te %in% c("imp2017", "pandemia")) ftex(as.numeric(r[["F"]]), 2) else ftex(as.numeric(r[["coef"]]), 3)
               sprintf("%s & %s & & %s & %s & %s \\\\", eq_lab[r[["eq"]]], rot, est, fptex(as.numeric(r[["p"]])), fptex(as.numeric(r[["p_hac"]])))
             }))
tex4 <- tex_tab("Quebras nos dados: emenda da SEST, imputa\\c{c}\\~ao de 2017, T4 eleitoral, composi\\c{c}\\~ao e Eletrobras", "tab:a4_dados",
                "lllccc", "S\\'erie ou equa\\c{c}\\~ao & Teste & Data & Estat\\'istica & $p$ & $p$ (Newey-West) \\\\", t4_rows,
                "Painel A: $F$ de Chow na m\\'edia e $p$ do degrau com Newey-West. Painel B: a dummy do T4 eleitoral \\'e um pulso no n\\'ivel (+1 no T4 e $-1$ no T1 seguinte na diferen\\c{c}a), com 2010, 2014, 2018 e 2022 (a variante com 2006 est\\'a em A4\\_quebras.md); coeficiente em log10. Pulsos de 2017: cinco pulsos de 2017T1 a 2018T1 (as diferen\\c{c}as afetadas pela distribui\\c{c}\\~ao trimestral imputada de 2017), teste $F$ conjunto. Janela 2011T1-2016T4: mudan\\c{c}a de drift no per\\'iodo da mudan\\c{c}a de composi\\c{c}\\~ao por elemento. Painel C: as mesmas dummies acrescentadas \\`as equa\\c{c}\\~oes do VAR (na disserta\\c{c}\\~ao, com a DUM do arquivo).",
                size = "\\tiny")

# Tabela 5: CUSUM e MOSUM
t5_rows <- c(painel("A. S\\'eries", 7),
             vapply(res_series, function(r) sprintf("%s & %s & %s & %s & %s & %s & %s \\\\", tex_esc(r$serie), ftex(r$cusum, 2), fptex(r$cusum_p),
                                                   ftex(r$cusum_lr, 2), fptex(r$cusum_lr_p), ftex(r$mosum, 2), fptex(r$mosum_p)), ""),
             "\\midrule", painel("B. Equa\\c{c}\\~oes do VAR", 7),
             vapply(res_eqs, function(r) sprintf("%s & %s & %s & %s & %s & %s & %s \\\\", eq_lab[r$eq], ftex(r$cusum, 2), fptex(r$cusum_p),
                                                ftex(r$cusum_lr, 2), fptex(r$cusum_lr_p), ftex(r$mosum, 2), fptex(r$mosum_p)), ""))
tex5 <- tex_tab("Testes de flutua\\c{c}\\~ao OLS-CUSUM e OLS-MOSUM", "tab:a4_cusum", "lcccccc",
                "S\\'erie ou equa\\c{c}\\~ao & CUSUM & $p$ & CUSUM (VLP) & $p$ & MOSUM & $p$ \\\\", t5_rows,
                "\\texttt{efp} e \\texttt{sctest}. CUSUM (VLP): vari\\^ancia de longo prazo por kernel (\\texttt{lrvar = TRUE}). MOSUM com janela de 15\\% da amostra; o $p$ do MOSUM vem de valores cr\\'iticos tabelados e fica truncado em 0,01 e 0,10 nas pontas.")

# Tabela 6: raiz unitaria com quebra
star <- function(p) ifelse(!is.na(p) & p < 0.01, "$^{***}$", ifelse(!is.na(p) & p < 0.05, "$^{**}$", ifelse(!is.na(p) & p < 0.10, "$^{*}$", "")))
za_star <- function(st, cv1, cv5, cv10) ifelse(st < cv1, "$^{***}$", ifelse(st < cv5, "$^{**}$", ifelse(st < cv10, "$^{*}$", "")))
t6_rows <- apply(ur_tab, 1, function(r) {
  num <- function(k) as.numeric(r[[k]])
  sprintf("%s & %d & %d/%d & %s%s (%s) & %s%s (%s, %s) & %s%s (%s, %s) & %s%s (%s, %s) \\\\",
          tex_esc(r[["serie"]]), num("n"), num("lag_tend"), num("lag_const"),
          ftex(num("za_stat"), 2), za_star(num("za_stat"), num("za_cv1"), num("za_cv5"), num("za_cv10")), qt(r[["za_data"]]),
          ftex(num("lp_stat"), 2), star(num("lp_p")), qt(r[["lp_d1"]]), qt(r[["lp_d2"]]),
          ftex(num("io_stat"), 2), star(num("io_p")), qt(r[["io_d1"]]), qt(r[["io_d2"]]),
          ftex(num("ao_stat"), 2), star(num("ao_p")), qt(r[["ao_d1"]]), qt(r[["ao_d2"]]))
})
cv_rows <- vapply(Ts, function(Tn) {
  g <- function(te, k) ftex(cv_mc[[k]][cv_mc$T == Tn & cv_mc$teste == te], 2)
  sprintf("\\multicolumn{7}{l}{$T = %d$: LP %s / %s / %s; CMR-IO %s / %s / %s; CMR-AO %s / %s / %s} \\\\", Tn,
          g("LP", "cv1"), g("LP", "cv5"), g("LP", "cv10"), g("IO", "cv1"), g("IO", "cv5"), g("IO", "cv10"),
          g("AO", "cv1"), g("AO", "cv5"), g("AO", "cv10"))
}, "")
tex6 <- tex_tab("Raiz unit\\'aria com quebra: Zivot-Andrews, Lumsdaine-Papell e Clemente-Monta\\~n\\'es-Reyes (log10 em n\\'ivel)", "tab:a4_ur",
                "lcccccc", "S\\'erie & $T$ & Lags & ZA (data) & LP (datas) & CMR-IO (datas) & CMR-AO (datas) \\\\",
                c(t6_rows, "\\midrule", painel(sprintf("Valores cr\\'iticos simulados (1\\%% / 5\\%% / 10\\%%), %d r\\'eplicas", NREP), 7), cv_rows),
                sprintf("H0: raiz unit\\'aria. Estat\\'istica $t$ do coeficiente de $y_{t-1}$; datas = primeiro trimestre do novo regime. ZA: \\texttt{urca::ur.za}, modelo com quebra em intercepto e tend\\^encia, valores cr\\'iticos assint\\'oticos de Zivot e Andrews (1992: $-5{,}57$, $-5{,}08$, $-4{,}82$); a busca do \\texttt{ur.za} n\\'ao tem trimming. LP: Lumsdaine e Papell (1997), duas quebras em intercepto e tend\\^encia (modelo CC). CMR: Clemente, Monta\\~n\\'es e Reyes (1998), duas quebras na m\\'edia, outlier inovativo (IO) e aditivo (AO, em dois passos, com pulsos defasados de 0 a $p$). LP e CMR implementados no script, busca em grade com cada quebra entre $0{,}15T$ e $0{,}85T$ e dist\\^ancia m\\'inima de $0{,}15T$ entre elas. Lags: $p$ de 0 a 4 pelo BIC da regress\\~ao ADF sem quebra (constante e tend\\^encia para ZA e LP; constante para CMR), na amostra comum; a coluna mostra $p$ de ZA e LP / $p$ de CMR. Valores cr\\'iticos e $p$ de LP e CMR SIMULADOS por Monte Carlo sob a nula (passeio aleat\\'orio com erros normais, mesmo $T$ da s\\'erie e mesma regra de lags, %d r\\'eplicas, \\texttt{set.seed(42)}). $^{***}$, $^{**}$, $^{*}$: rejeita a 1\\%%, 5\\%%, 10\\%%.", NREP),
                size = "\\tiny")

# Tabela 7: elasticidade
ex_row <- function(rot, e12, e40, pr40, ef) sprintf("%s & %s & %s & %s & %s \\\\", rot, ftex(e12, 3), ftex(e40, 3), ftex(pr40, 4), tex_ef(ef))
pick <- function(d, fimq, col) { v <- d[[col]][d$fim == fimq]; if (length(v)) v else NA }
t7_rows <- c(painel("A. Amostra completa e subamostras (VAR estendido)", 5),
             ex_row(sprintf("Disserta\\c{c}\\~ao, n\\'iveis 2002T1--2019T4 (%d obs. efetivas, arquivo original)", nrow(m_orig$datamat)),
                    el_orig["el_h12"], el_orig["el_h40"], el_orig["acum_priv_h40"], "refer\\^encia"),
             ex_row(sprintf("Disserta\\c{c}\\~ao, obs. efetivas at\\'e 2014T4 (%d obs.)", length(rows_o) - p_var), el_orig_pre["el_h12"], el_orig_pre["el_h40"], el_orig_pre["acum_priv_h40"], ""),
             apply(tab_sub, 1, function(r) ex_row(paste0("Estendido, sem dummies: ", { lb <- tex_ef(r[["amostra"]]); paste0(tolower(substr(lb, 1, 1)), substring(lb, 2)) }, " (", r[["n_ef"]], " obs. efetivas)"), as.numeric(r[["el_h12"]]),
                                                  as.numeric(r[["el_h40"]]), as.numeric(r[["acum_priv_h40"]]),
                                                  if (r[["amostra"]] == "Amostra completa") "refer\\^encia (sem dummies)" else r[["efeito"]])),
             ex_row("Estendido, amostra completa, com os pulsos de 2020T2 e 2020T3 (base da A5)", e_pand$el_h12, e_pand$el_h40, e_pand$acum_priv_h40, e_pand$efeito),
             "\\midrule", painel("B. Estimativas recursivas e em janela m\\'ovel de 40 trimestres (fim da janela)", 5),
             ex_row("Recursiva, fim em 2014T4", pick(rec, "2014Q4", "el_h12"), pick(rec, "2014Q4", "el_h40"), pick(rec, "2014Q4", "acum_priv_h40"), ""),
             ex_row("Recursiva, fim em 2019T4", pick(rec, "2019Q4", "el_h12"), pick(rec, "2019Q4", "el_h40"), pick(rec, "2019Q4", "acum_priv_h40"), ""),
             ex_row("Recursiva, fim em 2021T4", pick(rec, "2021Q4", "el_h12"), pick(rec, "2021Q4", "el_h40"), pick(rec, "2021Q4", "acum_priv_h40"), ""),
             sprintf("Recursiva, m\\'inimo e m\\'aximo ($h = 40$; %d de %d janelas est\\'aveis) & & %s a %s & & \\\\", sum(rec$estavel), nrow(rec),
                     ftex(min(rec$el_h40[rec$estavel]), 3), ftex(max(rec$el_h40[rec$estavel]), 3)),
             sprintf("Janela m\\'ovel, m\\'inimo e m\\'aximo ($h = 40$; %d de %d janelas est\\'aveis) & & %s a %s & & \\\\", sum(rol$estavel), nrow(rol),
                     ftex(min(rol$el_h40[rol$estavel]), 3), ftex(max(rol$el_h40[rol$estavel]), 3)),
             ex_row("Janela m\\'ovel, 2016T1--2025T4", pick(rol, "2025Q4", "el_h12"), pick(rol, "2025Q4", "el_h40"), pick(rol, "2025Q4", "acum_priv_h40"), ""),
             "\\midrule", painel("C. Dummies no VAR estendido (ex\\'ogenas adicionais na equa\\c{c}\\~ao em diferen\\c{c}a)", 5),
             apply(tab_exp[tab_exp$modelo == "ext", ], 1, function(r) ex_row(tex_esc(r[["experimento"]]), as.numeric(r[["el_h12"]]), as.numeric(r[["el_h40"]]),
                                                                          as.numeric(r[["acum_priv_h40"]]), r[["efeito"]])),
             "\\midrule", painel("D. Dummies no VAR da disserta\\c{c}\\~ao", 5),
             apply(tab_exp[tab_exp$modelo == "orig", ], 1, function(r) ex_row(tex_esc(r[["experimento"]]), as.numeric(r[["el_h12"]]), as.numeric(r[["el_h40"]]),
                                                                           as.numeric(r[["acum_priv_h40"]]), r[["efeito"]])),
             "\\midrule", painel("E. Variantes de inf\\_diss da A3 (VAR estendido)", 5),
             apply(tab_var, 1, function(r) ex_row(tex_esc(r[["experimento"]]), as.numeric(r[["el_h12"]]), as.numeric(r[["el_h40"]]),
                                                  as.numeric(r[["acum_priv_h40"]]), r[["efeito"]])),
             "\\midrule", painel("F. Proje\\c{c}\\~ao local simples (sem tend\\^encia e sem pulsos; n\\~ao \\'e a LP da A5): resposta acumulada de fbcf\\_me em $h = 8$ (EP Newey-West)", 5),
             apply(tab_sub, 1, function(r) sprintf("%s & \\multicolumn{2}{c}{%s (%s)} & & %s \\\\", tex_ef(r[["amostra"]]), ftex(as.numeric(r[["lp_fbcf_h8"]]), 3),
                                                   ftex(as.numeric(r[["lp_se_h8"]]), 3), if (sign(as.numeric(r[["lp_fbcf_h8"]])) != sign(lp_full["lp_fbcf_h8"])) "muda o sinal" else "")))
tex7 <- tex_tab("Elasticidade do investimento privado ao investimento p\\'ublico: amostras, janelas e dummies de quebra", "tab:a4_elast",
                "lcccl", "Especifica\\c{c}\\~ao & El. $h = 12$ & El. $h = 40$ & Resp. acum. priv. $h = 40$ & Efeito \\\\", t7_rows,
                sprintf("VAR(3) em diferen\\c{c}a com constante e tend\\^encia; estendido: inf\\_diss e fbcf\\_me (log10), ex\\'ogenas diff do PIB e diff da Selic, dados 2003T1--2025T4. Elasticidade = resposta acumulada do investimento privado / resposta acumulada do investimento p\\'ublico ao choque ortogonal no p\\'ublico (Cholesky com o p\\'ublico primeiro). Efeito: ``muda o sinal'' ou ``muda mais de 25\\%%'' da elasticidade da amostra completa do mesmo modelo (%s no estendido; %s na disserta\\c{c}\\~ao) em $h = 12$ ou $h = 40$. Degrau na diferen\\c{c}a = mudan\\c{c}a de drift; pulso = salto de n\\'ivel. As dummies em n\\'ivel (DUM e outliers do X-11 da A3) entram diferenciadas, como as ex\\'ogenas. Proje\\c{c}\\~ao local simples (diagn\\'ostico, sem tend\\^encia e sem os pulsos de 2020; por isso difere da IRF da A5): $y_{t+8} - y_{t-1}$ sobre $\\Delta$inf\\_diss$_t$, tr\\^es defasagens das duas diferen\\c{c}as, diff do PIB e da Selic e constante; nas subamostras, $t$ e $t + 8$ dentro da subamostra.",
                        ftex(el_ext["el_h40"], 3), ftex(el_orig["el_h40"], 3)),
                size = "\\tiny")

tex_all <- c("% Gerado por R/A4_quebras.R. Requer \\usepackage{booktabs}.",
             sprintf("%% Execucao de %s. Numeros com virgula decimal.", format(Sys.time(), "%Y-%m-%d %H:%M")),
             tex1, tex2, tex3, tex4, tex5, tex6, tex7)
tex_all <- gsub("\u2014", "-", tex_all)
write_lines_safe(tex_all, file.path(PATHS$results, "A_quebras.tex"))

# ---------------------------------------------------------------------------------------------
# Resumo CSV (uma linha por serie ou equacao)
# ---------------------------------------------------------------------------------------------
chow_sig <- function(s, col) {
  r <- chow_series[chow_series$serie == s & chow_series[[col]] < 0.05, ]
  paste(qt(r$data), collapse = " ")
}
resumo <- bind_rows(
  bind_rows(lapply(res_series, function(r) {
    u <- ur_tab[ur_tab$serie == r$serie, ]
    el <- elec_hac[elec_hac$serie == r$serie, ]
    tibble(tipo = "serie", nome = r$serie, amostra = paste0(qt(r$inicio), "-", qt(r$fim)), n = r$n,
           bp_m_bic = r$m_bic, bp_datas_bic = paste(qt(r$bp_bic$datas), collapse = " "),
           bp_ic95_bic = paste0(ifelse(is.na(r$bp_bic$lo), "NA", qt(r$bp_bic$lo)), "/", ifelse(is.na(r$bp_bic$hi), "NA", qt(r$bp_bic$hi)), collapse = " "),
           bp_m_lwz = r$m_lwz, bp_datas_lwz = paste(qt(r$bp_lwz$datas), collapse = " "),
           supF = r$supF, supF_p = r$supF_p, supF_data = qt(r$supF_data), supF_hac_p = r$supF_hac_p,
           cusum_p = r$cusum_p, cusum_vlp_p = r$cusum_lr_p, mosum_p = r$mosum_p,
           chow_rejeita5 = chow_sig(r$serie, "p"), chow_hac_rejeita5 = chow_sig(r$serie, "p_hac"),
           eleicao_coef = el$coef, eleicao_p_hac = el$p_hac,
           za_lag = u$lag_tend, za_stat = u$za_stat, za_data = qt(u$za_data), za_rejeita5 = u$za_stat < u$za_cv5,
           lp_stat = u$lp_stat, lp_datas = paste(qt(u$lp_d1), qt(u$lp_d2)), lp_p_mc = u$lp_p,
           cmr_lag = u$lag_const, cmr_io_stat = u$io_stat, cmr_io_datas = paste(qt(u$io_d1), qt(u$io_d2)), cmr_io_p_mc = u$io_p,
           cmr_ao_stat = u$ao_stat, cmr_ao_datas = paste(qt(u$ao_d1), qt(u$ao_d2)), cmr_ao_p_mc = u$ao_p)
  })),
  bind_rows(lapply(res_eqs, function(r) {
    ch <- r$chow
    tibble(tipo = "equacao", nome = r$eq, amostra = paste0(qt(EQS[[r$eq]]$dm$trimestre[1]), "-", qt(tail(EQS[[r$eq]]$dm$trimestre, 1))), n = r$n,
           bp_m_bic = r$m_bic, bp_datas_bic = paste(qt(r$bp_bic$datas), collapse = " "),
           bp_ic95_bic = paste0(ifelse(is.na(r$bp_bic$lo), "NA", qt(r$bp_bic$lo)), "/", ifelse(is.na(r$bp_bic$hi), "NA", qt(r$bp_bic$hi)), collapse = " "),
           bp_m_lwz = r$m_lwz, bp_datas_lwz = paste(qt(r$bp_lwz$datas), collapse = " "),
           supF = r$supF, supF_p = r$supF_p, supF_data = qt(r$supF_data), supF_hac_p = NA,
           cusum_p = r$cusum_p, cusum_vlp_p = r$cusum_lr_p, mosum_p = r$mosum_p,
           chow_rejeita5 = paste(qt(ch$data[ch$p < 0.05]), collapse = " "), chow_hac_rejeita5 = NA,
           eleicao_coef = elec_eq$coef[elec_eq$eq == r$eq][1], eleicao_p_hac = elec_eq$p_hac[elec_eq$eq == r$eq][1])
  })))
resumo$bp_ic95_bic[resumo$bp_m_bic == 0] <- ""
write_csv_safe(resumo, file.path(PATHS$results, "A4_quebras_resumo.csv"))
write_csv_safe(dummies_out, file.path(PATHS$processed, "A4_dummies_quebra.csv"))
write_csv_safe(dummies_meta, file.path(PATHS$processed, "A4_dummies_quebra_metadados.csv"))

# ---------------------------------------------------------------------------------------------
# Figura: estimativas recursivas e em janela movel
# ---------------------------------------------------------------------------------------------
yq <- function(k) as.numeric(q_to_yearqtr(k))
vlin <- yq(c("2014Q4", "2016Q4", "2020Q2", "2023Q3"))
d_var <- bind_rows(rec, rol) %>% filter(estavel) %>%
  dplyr::select(esquema, fim, el_h12, el_h40) %>%
  pivot_longer(c(el_h12, el_h40), names_to = "h", values_to = "el") %>%
  mutate(h = ifelse(h == "el_h12", "h = 12", "h = 40"), x = yq(fim))
g1 <- ggplot(d_var, aes(x, el, colour = esquema, linetype = h)) +
  geom_vline(xintercept = vlin, colour = "grey75", linetype = "dotted") +
  geom_hline(yintercept = el_ext["el_h40"], colour = "grey40") +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_line() +
  scale_colour_manual(values = c("Recursiva" = "#1f5a99", "Janela movel (40)" = "#c1571a")) +
  labs(title = "A. VAR estendido: elasticidade (resp. acum. fbcf_me / inf_diss)",
       x = "Fim da janela de estimacao", y = "Elasticidade", colour = NULL, linetype = NULL) +
  theme_minimal(base_size = 9) + theme(legend.position = "bottom")
d_acc <- bind_rows(rec, rol) %>% filter(estavel) %>% dplyr::select(esquema, fim, acum_inv_h40, acum_priv_h40) %>%
  pivot_longer(c(acum_inv_h40, acum_priv_h40), names_to = "resp", values_to = "v") %>%
  mutate(resp = ifelse(resp == "acum_inv_h40", "inf_diss", "fbcf_me"), x = yq(fim))
g2 <- ggplot(d_acc, aes(x, v, colour = resp, linetype = esquema)) +
  geom_vline(xintercept = vlin, colour = "grey75", linetype = "dotted") +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_line() +
  scale_colour_manual(values = c("inf_diss" = "#4d4d4d", "fbcf_me" = "#1a8c5b")) +
  labs(title = "B. VAR estendido: respostas acumuladas em h = 40 (log10)", x = "Fim da janela de estimacao", y = "Resposta acumulada",
       colour = NULL, linetype = NULL) +
  theme_minimal(base_size = 9) + theme(legend.position = "bottom")
d_lp <- bind_rows(lp_rec, lp_rol) %>% mutate(x = yq(fim), lo = lp_fbcf_h8 - 1.645 * lp_se_h8, hi = lp_fbcf_h8 + 1.645 * lp_se_h8)
g3 <- ggplot(d_lp, aes(x, lp_fbcf_h8, colour = esquema, fill = esquema)) +
  geom_vline(xintercept = vlin, colour = "grey75", linetype = "dotted") +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, colour = NA) +
  geom_line() +
  scale_colour_manual(values = c("Recursiva" = "#1f5a99", "Janela movel (40)" = "#c1571a")) +
  scale_fill_manual(values = c("Recursiva" = "#1f5a99", "Janela movel (40)" = "#c1571a")) +
  labs(title = "C. Projecao local: resp. acumulada de fbcf_me, h = 8 (IC 90%)",
       x = "Data do choque da ultima observacao da janela", y = "Resposta acumulada", colour = NULL, fill = NULL) +
  theme_minimal(base_size = 9) + theme(legend.position = "bottom")
d_sub <- tibble(amostra = factor(tab_sub$amostra, levels = tab_sub$amostra), el = tab_sub$el_h40, lp = tab_sub$lp_fbcf_h8) %>%
  pivot_longer(c(el, lp), names_to = "medida", values_to = "v") %>%
  mutate(medida = ifelse(medida == "el", "VAR: elasticidade h = 40", "LP: resposta acumulada h = 8"))
g4 <- ggplot(d_sub, aes(amostra, v, fill = medida)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  scale_fill_manual(values = c("VAR: elasticidade h = 40" = "#1f5a99", "LP: resposta acumulada h = 8" = "#c1571a")) +
  labs(title = "D. Subamostras (VAR estendido e projecao local)", x = NULL, y = NULL, fill = NULL) +
  theme_minimal(base_size = 9) + theme(legend.position = "bottom", axis.text.x = element_text(size = 7))
fig <- (g1 + g2) / (g3 + g4) +
  plot_annotation(caption = sprintf("Linhas pontilhadas: 2014T4, 2016T4, 2020T2 e 2023T3. Janela movel de 40 trimestres; recursiva com inicio fixo e pelo menos 40 observacoes.\nPaineis A e B sem as janelas com VAR explosivo (%d de %d na janela movel; %d de %d na recursiva).",
                                    sum(!rol$estavel), nrow(rol), sum(!rec$estavel), nrow(rec)))
ggsave_safe(file.path(PATHS$figuras, "A4_recursivo.png"), fig, width = 12, height = 8.5, dpi = 150)
ggsave_safe(file.path(PATHS$figuras, "A4_recursivo.pdf"), fig, width = 12, height = 8.5)

# ---------------------------------------------------------------------------------------------
# Relatorio em markdown
# ---------------------------------------------------------------------------------------------
md_tab <- function(df) {
  df <- as.data.frame(df)
  c(paste0("| ", paste(names(df), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
v <- function(tab, exper, col = "el_h40") tab[[col]][tab$experimento == exper]
sub_v <- function(am, col) tab_sub[[col]][tab_sub$amostra == am]
n_ser_bp <- sum(vapply(res_series, function(r) r$m_bic > 0 || r$m_lwz > 0, logical(1)))
ser_suph <- names(res_series)[vapply(res_series, function(r) r$supF_hac_p < 0.05, logical(1))]
ser_sup <- names(res_series)[vapply(res_series, function(r) r$supF_p < 0.05, logical(1))]
ser_cus <- names(res_series)[vapply(res_series, function(r) min(r$cusum_p, r$mosum_p) < 0.05, logical(1))]
ser_cuslr <- names(res_series)[vapply(res_series, function(r) r$cusum_lr_p < 0.05, logical(1))]
za_rej <- ur_tab$serie[ur_tab$za_stat < ur_tab$za_cv5]
lp_rej <- ur_tab$serie[ur_tab$lp_p < 0.05]
io_rej <- ur_tab$serie[ur_tab$io_p < 0.05]
ao_rej <- ur_tab$serie[ur_tab$ao_p < 0.05]
ur_nada <- ur_tab$serie[!(ur_tab$serie %in% c(za_rej, lp_rej, io_rej, ao_rej))]
lst <- function(x) if (length(x)) paste(x, collapse = ", ") else "nenhuma"
elec_sig <- elec_hac$serie[elec_hac$p_hac < 0.05]
rec19 <- pick(rec, "2019Q4", "el_h40"); rec21 <- pick(rec, "2021Q4", "el_h40"); rec20 <- pick(rec, "2020Q4", "el_h40")
rs <- rol[rol$estavel, ]
rol_max_fim <- rs$fim[which.max(rs$el_h40)]; rol_min_fim <- rs$fim[which.min(rs$el_h40)]
ext_nm <- tab_exp[tab_exp$modelo == "ext", ]
ext_nm_ok <- ext_nm$experimento[ext_nm$efeito == "nao muda"]
ext_nm_muda <- ext_nm[ext_nm$efeito != "nao muda", ]
orig_nm <- tab_exp[tab_exp$modelo == "orig", ]
var_muda <- tab_var[tab_var$efeito != "nao muda", ]
rng <- function(x) paste0(fnum(min(x), 3), " a ", fnum(max(x), 3))
sest_vars <- tab_var[grepl("Emenda", tab_var$experimento), ]
imp_vars <- tab_var[grepl("Imputacao", tab_var$experimento), ]
exp_apriori <- ext_nm[grepl("^(Degrau|Pulso) em (2008T4|2016T4|2017T1|2023T3)$", ext_nm$experimento), ]
exp_apriori_o <- orig_nm[grepl("^(Degrau|Pulso) em (2008T4|2016T4|2017T1)$", orig_nm$experimento), ]
chow_1415_ext <- c(eqx("ext_inf", "2014Q4"), eqx("ext_inf", "2015Q1"), eqx("ext_fbcf", "2014Q4"), eqx("ext_fbcf", "2015Q1"))
chow_1415_o <- sapply(c("orig_INF", "orig_PVD", "orig_INF_sd", "orig_PVD_sd"), function(e) min(eqx(e, "2014Q4"), eqx(e, "2015Q1")))
el_i <- elec_hac[elec_hac$serie %in% elec_sig, ]
el_ano <- if (nrow(el_i)) c("2006", "2010", "2014", "2018", "2022")[apply(abs(as.matrix(el_i[, c("t_2006", "t_2010", "t_2014", "t_2018", "t_2022")])), 1, which.max)] else character(0)
priv_inf <- c(SERIES_PRIV, "inf_diss")
priv_rej <- priv_inf[priv_inf %in% c(za_rej, lp_rej, io_rej, ao_rej)]
oi_series <- ur_tab$serie[ur_tab$n == 40]
maior_res_inf <- dm_ext$trimestre[which.max(abs(residuals(m_ext$varresult$inf)))]
lp2021 <- ur_tab$serie[ur_tab$serie %in% SERIES_PUB & grepl("^uniao", ur_tab$serie) & ur_tab$lp_d2 == "2021Q1"]

paragrafo <- paste0(
  "Quais quebras importam para o resultado. Pela regra deste script (muda o resultado a quebra que troca o sinal da elasticidade ou a desloca em mais de 25% em h = 12 ou h = 40, contra a amostra completa do mesmo modelo), IMPORTAM: ",
  sprintf("(1) o periodo 2020-2021. Com dados ate 2019T4 o VAR estendido da elasticidade de %s em h = 40, perto dos %s da dissertacao; com 2020-2025, %s. A estimativa recursiva cai de %s (fim em 2019T4) para %s (2020T4) e %s (2021T4) e depois fica de %s. Os testes apontam a mesma data: o supF das duas equacoes estendidas tem maximo em 2020T2 (p = %s e %s) e o Chow em 2020T2 rejeita (p = %s e %s). Parte do efeito vem dos picos das estatais que o X-11 manteve na serie ajustada (AO2020.3, AO2021.1, AO2021.2, alem dos de 2018-2019): com os pulsos de 2020T2 e 2020T3 a elasticidade vai a %s; com os outliers do X-11 de 2020-2021, a %s; com todos os outliers do X-11 e os pulsos, a %s; com inf_diss sem o efeito dos AO, a %s. ",
          fnum(sub_v("Ate 2019T4", "el_h40"), 3), fnum(el_orig["el_h40"], 2), fnum(el_ext["el_h40"], 3), fnum(rec19, 3), fnum(rec20, 3), fnum(rec21, 3), rng(rec$el_h40[rec$fim >= "2021Q4"]),
          fp(res_eqs$ext_inf$supF_p), fp(res_eqs$ext_fbcf$supF_p), fp(eqx("ext_inf", "2020Q2")), fp(eqx("ext_fbcf", "2020Q2")),
          fnum(e_pand$el_h40, 3), fnum(e_out2021$el_h40, 3), fnum(e_outall$el_h40, 3), fnum(v(tab_var, "Sem o efeito dos AO do X-11"), 3)),
  sprintf("(2) A divisao em 2014T4. O sinal se mantem no VAR, mas a magnitude muda: %s ate 2014T4 e %s de 2015T1 em diante; na projecao local simples o sinal muda (%s ate 2014T4, EP %s; %s depois, EP %s). No VAR da dissertacao, a amostra ate 2014T4 da %s contra %s na amostra completa: a elasticidade de 0,42 vem de 2015-2019. Mesmo assim, o Chow em 2014T4 e 2015T1 nao rejeita nas equacoes estendidas (p de %s) e, na dissertacao, so rejeita na equacao de INF sem os trimestres da DUM (menor p %s); um degrau ou pulso nessas datas quase nao move a elasticidade (%s): a diferenca entre as subamostras esta na dinamica (inclinacoes), nao no intercepto, e uma dummy nao resolve; a A5 deve reportar as subamostras. ",
          fnum(sub_v("Ate 2014T4", "el_h40"), 3), fnum(sub_v("De 2015T1", "el_h40"), 3), fnum(sub_v("Ate 2014T4", "lp_fbcf_h8"), 3), fnum(sub_v("Ate 2014T4", "lp_se_h8"), 3),
          fnum(sub_v("De 2015T1", "lp_fbcf_h8"), 3), fnum(sub_v("De 2015T1", "lp_se_h8"), 3), fnum(el_orig_pre["el_h40"], 3), fnum(el_orig["el_h40"], 3),
          rng(chow_1415_ext), fp(min(chow_1415_o)), rng(ext_nm$el_h40[grepl("2014T4|2015T1", ext_nm$experimento)])),
  sprintf("DETECTADAS PELOS TESTES, MAS SEM EFEITO RELEVANTE NA ELASTICIDADE: (3) a turbulencia de 2018-2019 no boletim da SEST (LS2018.2, AO2018.3, LS2019.1 e LS2019.3 de estatais_total, o trecho que a DUM da dissertacao cobre). A equacao de INF da dissertacao e instavel no fim da amostra: sem a DUM, Bai-Perron pelo BIC poe uma quebra em %s e o supF rejeita (p = %s); tirando os tres trimestres dos pulsos da DUM a quebra continua (%s; supF p = %s), e o Chow preditivo, que nao estima o segundo regime, tambem rejeita. Como o ultimo segmento tem %d observacoes (%d sem os trimestres da DUM) para %d coeficientes, o p assintotico do supF exagera. A equacao de PVD e estavel (supF p = %s). No VAR estendido, o Chow da equacao de inf_diss em 2018T4 rejeita (p = %s), mas os quatro outliers do X-11 de 2018-2019 deixam a elasticidade em %s e a DUM da dissertacao em %s. O pulso ida e volta de 2018T4 sozinho vai a %s porque pega o maior residuo da equacao de inf_diss (%s, a queda do boletim marcada pelo LS2019.1), e nao um efeito eleitoral: o grupo de T4 eleitorais fica em %s. ",
          qt(res_eqs$orig_INF$bp_bic$datas[1]), fp(res_eqs$orig_INF$supF_p), qt(res_eqs$orig_INF_sd$bp_bic$datas[1]), fp(res_eqs$orig_INF_sd$supF_p),
          as.integer(res_eqs$orig_INF$n - tail(res_eqs$orig_INF$bp_bic$idx, 1)), as.integer(res_eqs$orig_INF_sd$n - tail(res_eqs$orig_INF_sd$bp_bic$idx, 1)),
          res_eqs$orig_INF$k, fp(res_eqs$orig_PVD$supF_p), fp(p_chow_2018_inf), fnum(e_out1819$el_h40, 3), fnum(e_dum$el_h40, 3),
          fnum(v(tab_exp, "T4 eleitoral de 2018 so"), 3), qt(maior_res_inf), fnum(v(tab_exp, "T4 eleitoral (2010, 2014, 2018, 2022)"), 3)),
  sprintf("NAO IMPORTAM: 2008T4, 2016T4 e 2017T1 (teto de gastos) e 2023T3 (arcabouco fiscal), como degrau ou pulso (elasticidade de %s no estendido; %s no VAR da dissertacao); a emenda boletim/OI da SEST (degrau em 2020T1: %s; variantes de encadeamento da A3: %s; nenhum Chow das datas de emenda rejeita em estatais_total ou inf_diss); a imputacao de 2017 (variantes da A3: %s; pulsos de 2017T1 a 2018T1: %s; F dos pulsos sem significancia nas series e nas equacoes); o T4 eleitoral como grupo (%s; com Newey-West so %s rejeita a 5%%, com coeficiente negativo e maior t em %s); a mudanca de composicao por elemento em 2011-2016 (a janela nao e significativa em nenhuma serie da Uniao; ela nao afeta inf_diss, que usa o filtro da dissertacao); e a saida da Eletrobras em 2022T3 (Chow sem significancia). ",
          rng(exp_apriori$el_h40), rng(exp_apriori_o$el_h40), fnum(v(tab_exp, "Degrau em 2020T1 (emenda da SEST)"), 3), rng(sest_vars$el_h40),
          rng(imp_vars$el_h40), fnum(v(tab_exp, "Pulsos de 2017T1 a 2018T1 (imputacao)"), 3),
          fnum(v(tab_exp, "T4 eleitoral (2010, 2014, 2018, 2022)"), 3), lst(elec_sig), lst(el_ano)),
  sprintf("Nas series, Bai-Perron na media da diferenca nao seleciona quebra em %d de %d series (BIC e LWZ), o supF classico %s e o supF com Newey-West rejeita a 5%% so em %s (maximo em %s), no fim da aceleracao do investimento federal de 2007-2010, a mesma quebra que o Chow com Newey-West acha em 2011T1 nas series da Uniao. Resumo para a A5: estimar com a amostra 2003T1-2025T4 com os pulsos de 2020T2 e 2020T3 no baseline, reportar a amostra ate 2019T4 e as subamostras antes e depois de 2014T4, tratar os AO de 2020-2021 das estatais (variante sem AO ou dummies do X-11) como a robustez que mais move o numero, e nao gastar graus de liberdade com dummies de 2008T4, 2016T4/2017T1, 2023T3, emenda da SEST, imputacao de 2017 ou T4 eleitoral. Referencia do VAR estendido de base (com os pulsos): %s em h = 40.",
          length(res_series) - n_ser_bp, length(res_series),
          if (length(ser_sup)) paste("rejeita em", lst(ser_sup)) else "nao rejeita em nenhuma", lst(ser_suph),
          paste(unique(vapply(res_series[ser_suph], function(r) qt(r$supF_hac_data), "")), collapse = " e "), fnum(e_pand$el_h40, 3))
)

md <- c("# A4. Quebras estruturais", "",
        sprintf("Gerado por `R/A4_quebras.R` em %s. Numeros com virgula decimal. Tabelas LaTeX em `results/A_quebras.tex`; resumo por serie e equacao em `results/A4_quebras_resumo.csv`; dummies para a A5 em `data/processed/A4_dummies_quebra.csv` (metadados em `A4_dummies_quebra_metadados.csv`); figura em `results/figuras/A4_recursivo.png`.", format(Sys.time(), "%Y-%m-%d %H:%M")), "",
        "Convencao: toda data de quebra e o primeiro trimestre do novo regime.", "",
        "## Quais quebras importam", "", paragrafo, "",
        "## 1. Series: Bai-Perron, supF, CUSUM e MOSUM (media da diferenca do log10)", "",
        md_tab(tibble(serie = names(res_series),
                      amostra = vapply(res_series, function(r) paste0(qt(r$inicio), "-", qt(r$fim)), ""),
                      `m BIC/LWZ` = vapply(res_series, function(r) paste0(r$m_bic, "/", r$m_lwz), ""),
                      `datas BIC [IC 95%]` = vapply(res_series, function(r) bp_txt(r$bp_bic), ""),
                      `cresc. % a.a.` = vapply(res_series, function(r) fnum(r$media_total, 1), ""),
                      supF = vapply(res_series, function(r) fnum(r$supF, 2), ""),
                      `p` = vapply(res_series, function(r) fp(r$supF_p), ""),
                      `data max` = vapply(res_series, function(r) qt(r$supF_data), ""),
                      `p NW` = vapply(res_series, function(r) fp(r$supF_hac_p), ""),
                      `p CUSUM` = vapply(res_series, function(r) fp(r$cusum_p), ""),
                      `p CUSUM VLP` = vapply(res_series, function(r) fp(r$cusum_lr_p), ""),
                      `p MOSUM` = vapply(res_series, function(r) fp(r$mosum_p), ""))), "",
        "## 2. Equacoes do VAR", "",
        md_tab(tibble(equacao = vapply(res_eqs, function(r) r$rotulo, ""),
                      n = vapply(res_eqs, function(r) r$n, 0), k = vapply(res_eqs, function(r) r$k, 0), h = vapply(res_eqs, function(r) r$h, 0),
                      `m BIC/LWZ` = vapply(res_eqs, function(r) paste0(r$m_bic, "/", r$m_lwz), ""),
                      `datas BIC [IC 95%]` = vapply(res_eqs, function(r) bp_txt(r$bp_bic), ""),
                      supF = vapply(res_eqs, function(r) fnum(r$supF, 2), ""), p = vapply(res_eqs, function(r) fp(r$supF_p), ""),
                      `data max` = vapply(res_eqs, function(r) qt(r$supF_data), ""),
                      `p CUSUM` = vapply(res_eqs, function(r) fp(r$cusum_p), ""), `p MOSUM` = vapply(res_eqs, function(r) fp(r$mosum_p), ""))), "",
        "## 3. Chow nas datas candidatas (p do F classico; nas series, entre parenteses, p do degrau com Newey-West)", "",
        md_tab(bind_cols(tibble(nome = c(SERIES, eq_nomes)),
                         as_tibble(setNames(lapply(datas_grid, function(dq) c(
                           vapply(SERIES, function(s) { r <- chow_series[chow_series$serie == s & chow_series$data == dq, ]
                           if (!nrow(r)) "" else sprintf("%s (%s)", fnum(r$p, 2), fnum(r$p_hac, 2)) }, ""),
                           vapply(eq_nomes, function(nm) { r <- res_eqs[[nm]]$chow; r <- r[r$data == dq, ]
                           if (!nrow(r)) "" else paste0(fnum(r$p, 3), if (r$tipo != "quebra") " (P)" else "") }, ""))), qt(datas_grid))))), "",
        "(P) = teste preditivo de Chow (um dos regimes tem menos observacoes que regressores).", "",
        "## 4. Quebras nos dados", "",
        md_tab(chow_dados %>% transmute(serie, origem = gsub("dados: ", "", origem), data = qt(data), F = fnum(F, 2), p = fp(p), `p NW` = fp(p_hac),
                                        `cresc. antes` = fnum(cresc_antes, 1), `cresc. depois` = fnum(cresc_depois, 1))), "",
        md_tab(dummies_media %>% transmute(serie, teste, coef = fnum(coef, 3), F = fnum(F, 2), p = fp(p), `p NW` = fp(p_hac),
                                           `t 2006` = fnum(t_2006, 2), `t 2010` = fnum(t_2010, 2), `t 2014` = fnum(t_2014, 2),
                                           `t 2018` = fnum(t_2018, 2), `t 2022` = fnum(t_2022, 2))), "",
        md_tab(dummies_eq %>% transmute(equacao = eq, teste, coef = fnum(coef, 4), F = fnum(F, 2), p = fp(p), `p NW` = fp(p_hac))), "",
        "## 5. Raiz unitaria com quebra (valores criticos de LP e CMR simulados)", "",
        md_tab(ur_tab %>% transmute(serie, T = n, `lag ZA/LP` = lag_tend, `lag CMR` = lag_const,
                                    ZA = paste0(fnum(za_stat, 2), " (", qt(za_data), ")"), `ZA rejeita 5%` = ifelse(za_stat < za_cv5, "sim", "nao"),
                                    LP = paste0(fnum(lp_stat, 2), " (", qt(lp_d1), ", ", qt(lp_d2), ")"), `p LP` = fp(lp_p),
                                    `CMR-IO` = paste0(fnum(io_stat, 2), " (", qt(io_d1), ", ", qt(io_d2), ")"), `p IO` = fp(io_p),
                                    `CMR-AO` = paste0(fnum(ao_stat, 2), " (", qt(ao_d1), ", ", qt(ao_d2), ")"), `p AO` = fp(ao_p))), "",
        md_tab(cv_mc %>% transmute(T, teste, `1%` = fnum(cv1, 2), `5%` = fnum(cv5, 2), `10%` = fnum(cv10, 2), replicas = n_valid)), "",
        sprintf("Valores criticos de LP e CMR simulados por Monte Carlo (%d replicas de passeio aleatorio com erros normais, mesmo T e mesma regra de lags, set.seed(42)); ZA com os valores assintoticos do urca (-5,57; -5,08; -4,82).", NREP), "",
        "## 6. Estimacao: amostras, janelas e dummies", "",
        sprintf("VAR da dissertacao (arquivos originais, niveis 2002T1-2019T4, %d observacoes efetivas): elasticidade %s em h = 40 (observacoes efetivas ate 2014T4: %s). VAR estendido, amostra completa, sem dummies: %s em h = 12 e %s em h = 40; com os pulsos de 2020T2 e 2020T3 (especificacao de base da A5, referencia do VAR estendido): %s e %s. Projecao local simples (sem tendencia e sem pulsos; diagnostico, nao e a LP da A5), resposta acumulada de fbcf_me em h = 8: %s (EP %s). Subamostras: observacoes efetivas ate 2014T4 e de 2015T1 em diante (na projecao local, t e t + 8 dentro da subamostra).",
                nrow(m_orig$datamat), fnum(el_orig["el_h40"], 3), fnum(el_orig_pre["el_h40"], 3), fnum(el_ext["el_h12"], 3), fnum(el_ext["el_h40"], 3),
                fnum(e_pand$el_h12, 3), fnum(e_pand$el_h40, 3), fnum(lp_full["lp_fbcf_h8"], 3), fnum(lp_full["lp_se_h8"], 3)), "",
        md_tab(tab_sub %>% transmute(amostra, n = n_ef, `el h=12` = fnum(el_h12, 3), `el h=40` = fnum(el_h40, 3),
                                     `LP h=8` = fnum(lp_fbcf_h8, 3), `EP LP` = fnum(lp_se_h8, 3), efeito)), "",
        md_tab(bind_rows(tab_exp %>% mutate(serie = ""), tab_var %>% mutate(tipo = "variante de dados")) %>%
                 transmute(modelo, experimento, `el h=12` = fnum(el_h12, 3), `el h=40` = fnum(el_h40, 3),
                           `resp. priv. h=40` = fnum(acum_priv_h40, 4), `resp. publ. h=40` = fnum(acum_inv_h40, 4), efeito)), "",
        md_tab(bind_rows(rec, rol) %>% filter(substr(fim, 6, 6) == "4") %>%
                 transmute(esquema, fim = qt(fim), `el h=12` = fnum(el_h12, 3), `el h=40` = fnum(el_h40, 3),
                           `resp. publ.` = fnum(acum_inv_h40, 4), `resp. priv.` = fnum(acum_priv_h40, 4))), "",
        md_tab(bind_rows(lp_rec, lp_rol) %>% filter(substr(fim, 6, 6) == "4") %>%
                 transmute(esquema, `fim (choque)` = qt(fim), `LP h=8` = fnum(lp_fbcf_h8, 3), EP = fnum(lp_se_h8, 3), n = lp_n)), "",
        "## 7. Dummies para a A5", "",
        if (nrow(dummies_meta)) md_tab(dummies_meta %>% dplyr::select(nome, tipo, datas, series_ou_equacoes, uso)) else "Nenhuma.", "",
        "Justificativas em `data/processed/A4_dummies_quebra_metadados.csv`. As colunas de `A4_dummies_quebra.csv` sao regressores da equacao em diferenca e entram como estao, sem diferenciar de novo.", "")
md <- gsub("= <0,001", "< 0,001", gsub("\u2014", "-", md), fixed = TRUE)
write_lines_safe(md, file.path(PATHS$results, "A4_quebras.md"))

# ---------------------------------------------------------------------------------------------
# Log
# ---------------------------------------------------------------------------------------------
log_a4 <- function(txt) log_part("A4", gsub("= <0,001", "< 0,001", txt, fixed = TRUE))
log_a4(sprintf("- Bai-Perron (strucchange::breakpoints, h = 0,15, ate 5 quebras, BIC e LWZ com c0 = 0,299 e delta0 = 0,1, IC 95%% das datas): nas series, regressao da diferenca do log10 numa constante; %d de %d series sem quebra pelo BIC e pelo LWZ. Nas equacoes, todos os coeficientes mudam; como h = 0,15 x 68 = 10 nao passa do numero de regressores (10) nas equacoes da dissertacao, usei h = k + 1 = 11 (16,2%%) nelas; a dummy diferenciada da dissertacao fica fora dos testes de quebra (e zero antes de 2018 e torna os segmentos singulares), e as linhas _sd tiram os tres trimestres em que ela e diferente de zero (2018T2, 2019T2, 2019T3). Resultado: %s.",
                       length(res_series) - n_ser_bp, length(res_series),
                       paste(vapply(res_eqs, function(r) sprintf("%s m = %d pelo BIC (%s) e %d pelo LWZ", r$eq, r$m_bic, bp_txt(r$bp_bic), r$m_lwz), ""), collapse = "; ")))
log_a4(sprintf("- sup-Wald de Andrews (Fstats, trimming 15%%, p de Hansen): series com p < 0,05: %s; com matriz de Newey-West (3 defasagens): %s. Equacoes: %s.",
                       lst(ser_sup), lst(ser_suph),
                       paste(vapply(res_eqs, function(r) sprintf("%s supF = %s, p = %s, maximo em %s", r$eq, fnum(r$supF, 2), fp(r$supF_p), qt(r$supF_data)), ""), collapse = "; ")))
log_a4(sprintf("- OLS-CUSUM e OLS-MOSUM (efp e sctest; MOSUM com janela de 15%%): series que rejeitam a 5%% em algum dos dois: %s; CUSUM com variancia de longo prazo: %s. Equacoes que rejeitam a 5%% em algum dos tres: %s (menor p: %s).",
                       lst(ser_cus), lst(ser_cuslr),
                       lst(names(res_eqs)[vapply(res_eqs, function(r) min(r$cusum_p, r$mosum_p, r$cusum_lr_p) < 0.05, logical(1))]),
                       fp(min(vapply(res_eqs, function(r) min(r$cusum_p, r$mosum_p, r$cusum_lr_p), 0)))))
chow_sig_all <- chow_series %>% filter(p < 0.05 | p_hac < 0.05)
log_a4(sprintf("- Chow nas datas a priori e em 2018T4 (series: F classico e t de Newey-West do degrau, pelo menos %d diferencas por regime; equacoes: F de todos os coeficientes, preditivo quando um regime tem menos observacoes que regressores). Series com p < 0,05 em algum dos dois: %s. Equacoes com p < 0,05: %s.",
                       MIN_SEG,
                       if (nrow(chow_sig_all)) paste(sprintf("%s em %s (p %s; NW %s)", chow_sig_all$serie, qt(chow_sig_all$data), fp(chow_sig_all$p), fp(chow_sig_all$p_hac)), collapse = "; ") else "nenhuma",
                       paste(unlist(lapply(res_eqs, function(r) { x <- r$chow[r$chow$p < 0.05, ]; if (nrow(x)) sprintf("%s em %s (p %s%s)", r$eq, qt(x$data), fp(x$p), ifelse(x$tipo == "quebra", "", ", preditivo")) })), collapse = "; ")))
log_a4(sprintf("- Quebras nos dados. Emenda da SEST: Chow em media em 2016T1, 2017T1, 2018T1, 2019T1 e 2020T1, menor p %s (classico) e %s (Newey-West) em estatais_total e inf_diss. Imputacao de 2017: pulsos de 2017T1 a 2018T1, F conjunto com p %s nas series (uniao_filtro_diss, inf_diss) e %s nas equacoes. T4 eleitoral (pulso no nivel em 2010T4, 2014T4, 2018T4 e 2022T4): rejeita a 5%% com Newey-West so em %s; nas equacoes do VAR, menor p %s; o t de 2018T4 sozinho vai de %s a %s nas series. Composicao 2011-2016 (uniao_econ_dir, uniao_econ_dt_g1, uniao_gnd4_dir, uniao_soc_dir): janela 2011T1-2016T4 com p de Newey-West de %s a %s; Chow em 2011T1 com Newey-West: %s. Eletrobras (2022T3): p de %s a %s.",
                       fp(min(chow_dados$p[grepl("SEST", chow_dados$origem)])), fp(min(chow_dados$p_hac[grepl("SEST", chow_dados$origem)])),
                       rng(dummies_media$p[dummies_media$teste == "imp2017"]), rng(dummies_eq$p[dummies_eq$teste == "imp2017"]),
                       lst(elec_sig), fp(min(elec_eq$p_hac)), fnum(min(elec_hac$t_2018, na.rm = TRUE), 2), fnum(max(elec_hac$t_2018, na.rm = TRUE), 2),
                       fp(min(dummies_media$p_hac[dummies_media$teste == "composicao"])), fp(max(dummies_media$p_hac[dummies_media$teste == "composicao"])),
                       paste(sprintf("%s %s", comp$serie, fp(comp$p_hac)), collapse = "; "),
                       fp(min(chow_dados$p[grepl("Eletrobras", chow_dados$origem)])), fp(max(chow_dados$p[grepl("Eletrobras", chow_dados$origem)]))))
log_a4(sprintf("- Raiz unitaria com quebra (log10 em nivel). Regra de lags comum: p de 0 a 4 pelo BIC da regressao ADF sem quebra na amostra comum (constante e tendencia para ZA e LP; constante para CMR). ZA (urca::ur.za, model both, sem trimming, valores criticos assintoticos): rejeita a 5%% em %s. Lumsdaine-Papell (duas quebras em intercepto e tendencia) e Clemente-Montanes-Reyes (duas quebras na media, IO e AO), implementados no script, com busca em grade (cada quebra entre 0,15T e 0,85T, distancia minima de 0,15T). VALORES CRITICOS SIMULADOS por Monte Carlo sob a nula (passeio aleatorio com erros N(0,1), mesmo T da serie e mesma regra de lags, %d replicas, set.seed(42), T = %s; %s s em %d nucleos). LP rejeita a 5%% em %s; CMR-IO em %s; CMR-AO em %s. Nenhum dos quatro rejeita em %s. Nas series so da OI (T = 40), as datas do ZA sao %s; os AO de 2020T3 e 2021T2 ficam na serie ajustada e pesam nessas datas. Nas series da Uniao, o LP data a segunda quebra em 2021T1 (AO2021.1) em %s. Entre as privadas e inf_diss, rejeitam em algum teste: %s. Leitura: as rejeicoes se concentram em series curtas ou com picos isolados mantidos pelo X-11; nas privadas e em inf_diss a raiz unitaria nao e rejeitada mesmo com quebras (salvo as listadas), o que mantem o VAR em diferenca.",
                       lst(za_rej), NREP, paste(Ts, collapse = ", "), fnum(t_mc, 0), NCORES, lst(lp_rej), lst(io_rej), lst(ao_rej), lst(ur_nada),
                       paste(sprintf("%s %s", oi_series, qt(ur_tab$za_data[match(oi_series, ur_tab$serie)])), collapse = "; "),
                       lst(lp2021), lst(priv_rej)))
log_a4(sprintf("- Estimacao. VAR estendido, amostra completa, sem dummies: elasticidade %s (h = 12) e %s (h = 40); com os pulsos de 2020T2 e 2020T3 (especificacao de base da A5): %s e %s. Recursiva (inicio fixo, 40 a 88 observacoes efetivas): de %s a %s; janela movel de 40 trimestres: de %s (fim em %s) a %s (fim em %s). Janelas com VAR explosivo (maior raiz com modulo >= 1), fora desses resumos e da figura: %d de %d na recursiva e %d de %d na janela movel (%s). Maior raiz do VAR estendido na amostra completa: %s. Subamostras: ate 2014T4 %s; de 2015T1 %s; ate 2019T4 %s. Projecao local simples (sem tendencia e sem pulsos, diagnostico, nao e a LP da A5; nas subamostras t e t + 8 dentro da subamostra), resposta acumulada de fbcf_me em h = 8: amostra completa %s (EP %s); ate 2014T4 %s; de 2015T1 %s; recursiva de %s a %s; janela movel de %s a %s. VAR da dissertacao ate 2014T4: %s.",
                       fnum(el_ext["el_h12"], 3), fnum(el_ext["el_h40"], 3), fnum(e_pand$el_h12, 3), fnum(e_pand$el_h40, 3),
                       fnum(min(rec$el_h40[rec$estavel]), 3), fnum(max(rec$el_h40[rec$estavel]), 3),
                       fnum(min(rol$el_h40[rol$estavel]), 3), qt(rol_min_fim), fnum(max(rol$el_h40[rol$estavel]), 3), qt(rol_max_fim),
                       sum(!rec$estavel), nrow(rec), sum(!rol$estavel), nrow(rol),
                       if (any(!rol$estavel | !rec$estavel)) paste("fim em", paste(qt(unique(c(rec$fim[!rec$estavel], rol$fim[!rol$estavel]))), collapse = ", ")) else "nenhuma",
                       fnum(el_ext["raiz_max"], 3),
                       fnum(sub_v("Ate 2014T4", "el_h40"), 3), fnum(sub_v("De 2015T1", "el_h40"), 3), fnum(sub_v("Ate 2019T4", "el_h40"), 3),
                       fnum(lp_full["lp_fbcf_h8"], 3), fnum(lp_full["lp_se_h8"], 3), fnum(sub_v("Ate 2014T4", "lp_fbcf_h8"), 3), fnum(sub_v("De 2015T1", "lp_fbcf_h8"), 3),
                       fnum(min(lp_rec$lp_fbcf_h8), 3), fnum(max(lp_rec$lp_fbcf_h8), 3), fnum(min(lp_rol$lp_fbcf_h8), 3), fnum(max(lp_rol$lp_fbcf_h8), 3),
                       fnum(el_orig_pre["el_h40"], 3)))
log_a4(sprintf("- Dummies no VAR que mudam a elasticidade em mais de 25%% ou o sinal: %s. Variantes de inf_diss da A3 que mudam: %s. Todas as demais (%d experimentos) ficam dentro de 25%%.",
                       if (nrow(ext_nm_muda)) paste(sprintf("%s (%s)", ext_nm_muda$experimento, fnum(ext_nm_muda$el_h40, 3)), collapse = "; ") else "nenhuma",
                       if (nrow(var_muda)) paste(sprintf("%s (%s)", var_muda$experimento, fnum(var_muda$el_h40, 3)), collapse = "; ") else "nenhuma",
                       sum(tab_exp$efeito == "nao muda") + sum(tab_var$efeito == "nao muda")))
log_a4(sprintf("- Dummies para a A5 (data/processed/A4_dummies_quebra.csv, 2002T1-2025T4; nome, tipo, uso e justificativa em A4_dummies_quebra_metadados.csv): %s. Sao regressores da equacao em diferenca e entram como estao (nao diferenciar de novo). Regra: pulsos da pandemia se o F dos pulsos rejeita a 5%% numa equacao estendida; AO do X-11 de 2020-2021 se o Chow das equacoes estendidas em 2020T1 ou 2020T2 rejeita a 5%%; outliers do X-11 de 2018-2019 se o Chow da equacao de inf_diss em 2018T4 rejeita a 5%%; degrau de 2011T1 se o Chow com Newey-West rejeita a 5%% em pelo menos duas series da Uniao. Nao entram: 2014T4/2015T1 (a diferenca e de inclinacao; usar subamostras), 2008T4, 2016T4/2017T1, 2023T3, emenda da SEST, imputacao de 2017, T4 eleitoral e Eletrobras (testes sem significancia ou efeito menor que 25%%).",
                       if (nrow(dummies_meta)) paste(sprintf("%s (%s; %s)", dummies_meta$nome, dummies_meta$tipo, dummies_meta$uso), collapse = "; ") else "nenhuma"))
log_a4("- Saidas: results/A_quebras.tex (Tabelas tab:a4_bp, tab:a4_supf, tab:a4_chow, tab:a4_dados, tab:a4_cusum, tab:a4_ur, tab:a4_elast), results/A4_quebras.md, results/A4_quebras_resumo.csv, data/processed/A4_dummies_quebra.csv, data/processed/A4_dummies_quebra_metadados.csv, results/figuras/A4_recursivo.png e .pdf.")
log_a4(paste0("- ", paragrafo))
log_a4(sprintf("- Correcoes da revisao adversarial (2026-09-28): (1) rotulos da Tabela tab:a4_elast: a linha da dissertacao diz niveis 2002T1-2019T4 com %d observacoes efetivas (a A5 chama de 2003-2019 a amostra com niveis desde 2003T1); a amostra completa do estendido aparece como 'sem dummies' (%s em h = 40), e a referencia do VAR estendido de base passa a ser a versao com os pulsos de 2020 (%s), que a A5 usa. (2) A projecao local simples da A4 (sem tendencia e sem pulsos) foi rotulada como diagnostico; ela nao e a LP da A5 e por isso difere da IRF da A5. (3) Corte unico das subamostras na A4, no A5_var e no A5_lp: observacoes efetivas ate 2014T4 e de 2015T1 em diante; na projecao local simples, t e t + 8 dentro da subamostra (antes, a subamostra ate 2014T4 e a ate 2019T4 usavam respostas depois do corte): ate 2014T4 %s (EP %s), de 2015T1 %s (EP %s), ate 2019T4 %s (EP %s).",
               nrow(m_orig$datamat), fnum(el_ext["el_h40"], 3), fnum(e_pand$el_h40, 3),
               fnum(sub_v("Ate 2014T4", "lp_fbcf_h8"), 3), fnum(sub_v("Ate 2014T4", "lp_se_h8"), 3),
               fnum(sub_v("De 2015T1", "lp_fbcf_h8"), 3), fnum(sub_v("De 2015T1", "lp_se_h8"), 3),
               fnum(sub_v("Ate 2019T4", "lp_fbcf_h8"), 3), fnum(sub_v("Ate 2019T4", "lp_se_h8"), 3)))
log_a4(sprintf("- Tempo total: %s s.", fnum(as.numeric(difftime(Sys.time(), t_ini, units = "secs")), 0)))
save_session_info("A4_quebras")
