# A5, parte LP: projecoes locais (Jorda, 2005) com o choque de investimento publico ordenado antes da resposta,
# elasticidades acumuladas e multiplicadores acumulados em R$ (Ramey e Zubairy, 2018), comparacoes com teste de
# Wald, LP em nivel com defasagens aumentadas (Montiel Olea e Plagborg-Moller, 2021) e robustez.
# Uso: cd crowding_in_code && Rscript R/A5_lp.R
# Entradas: data/processed/A2_series_trimestrais.csv, A2_ibge_trimestral.csv, A2_deflator_ipca.csv,
# A3_choques_wide.csv, A3_choques_semao_wide.csv, A3_niveis_wide.csv, A3_invpub_trimestral.csv, A4_dummies_quebra.csv.
# Saidas: data/processed/A5_lp_irf.csv, A5_lp_cumulativo.csv, A5_lp_comparacoes.csv, results/A5_lp.md,
# results/figuras/A5_lp_*.png e .pdf.

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(sandwich)
  library(patchwork)
})

ETAPA <- "A5_lp"
log_reset(ETAPA)
set.seed(42)
t_ini <- Sys.time()
Z90 <- qnorm(0.95)

# ------------------------------------------------------------------------------------------------
# Formatacao
# ------------------------------------------------------------------------------------------------
num <- function(x, d = 3) ifelse(is.na(x), "NA", formatC(round(x, d), format = "f", digits = d, decimal.mark = ","))
pv <- function(p) ifelse(is.na(p), "NA", ifelse(p < 0.001, "< 0,001", num(p, 3)))
cel <- function(b, lo, hi, d = 3) ifelse(is.na(b), "NA", sprintf("%s [%s; %s]", num(b, d), num(lo, d), num(hi, d)))
estrela <- function(lo, hi) ifelse(!is.na(lo) & (lo > 0 | hi < 0), "*", "")
tq <- function(k) gsub("Q", "T", k)
md_table <- function(df) {
  df <- as.data.frame(df)
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- vapply(seq_len(nrow(df)), function(i) paste0("| ", paste(unlist(df[i, ]), collapse = " | "), " |"), "")
  c(hdr, sep, rows)
}

# ------------------------------------------------------------------------------------------------
# 1. Dados (tudo alinhado em 2002T1-2025T4; cada especificacao recorta a sua janela)
# ------------------------------------------------------------------------------------------------
rd <- function(f) readr::read_csv(file.path(PATHS$processed, f), show_col_types = FALSE)
a2 <- rd("A2_series_trimestrais.csv")
ibge <- rd("A2_ibge_trimestral.csv") %>% rename(trimestre = periodo)
defl <- rd("A2_deflator_ipca.csv") %>% filter(frequencia == "trimestral") %>%
  transmute(trimestre = periodo, fator_ipca = fator_para_2025)
ch <- rd("A3_choques_wide.csv")
chs <- rd("A3_choques_semao_wide.csv")
nv <- rd("A3_niveis_wide.csv")
inv <- rd("A3_invpub_trimestral.csv")
dq <- rd("A4_dummies_quebra.csv")

TRIM <- q_seq("2002Q1", "2025Q4")
NT <- length(TRIM)
al <- function(df, col) {
  stopifnot(col %in% names(df))
  df[[col]][match(TRIM, df$trimestre)]
}
L <- function(v, k) {
  if (k == 0) return(v)
  if (k > 0) c(rep(NA, k), v[seq_len(NT - k)]) else c(v[(1 - k):NT], rep(NA, -k))
}
dl <- function(v) v - L(v, 1)

CHOQUES <- c("inf_diss", "uniao_filtro_diss", "uniao_gnd4_dir", "uniao_econ_dir", "uniao_soc_dir",
             "uniao_econ_dt_g1", "uniao_soc_dt_g1", "uniao_transf_soc_g1", "estatais_total",
             "estatais_petro", "estatais_sempetro", "estatais_econ")
CURTOS <- c("estatais_petro", "estatais_sempetro", "estatais_econ")
RESPOSTAS <- c("fbcf_me", "fbcf_constr", "fbcf_total", "fbcf_outros", "pim_bk", "imp_bk_quantum", "bndes_priv",
               "fbcf_cnt_vol")
Y_RS <- c("fbcf_real_rs_bi", "bndes_priv", "imp_bk_real")
MAP_T12 <- c(uniao_econ_dt_g1 = "uniao_econ_dt", uniao_soc_dt_g1 = "uniao_soc_dt",
             uniao_transf_soc_g1 = "uniao_transf_soc")
UNIAO <- grep("^uniao_", CHOQUES, value = TRUE)

YL10 <- setNames(lapply(RESPOSTAS, function(r) al(a2, paste0(r, "_l10"))), RESPOSTAS)
YRS <- setNames(lapply(Y_RS, function(r) al(a2, r)), Y_RS)
PIB <- al(a2, "pib_real_rs_bi")
EXO <- list(
  pib_acel = al(a2, "pib_acel"), pib_cresc = al(a2, "pib_cresc"),
  d_selic_fim = dl(al(a2, "selic_fim")), d_selic_media = dl(al(a2, "selic_media")),
  d_cambio_real = dl(al(a2, "cambio_real_l10")), d_icbr_usd = dl(al(a2, "icbr_usd_l10")),
  d_brent_usd = dl(al(a2, "brent_usd_l10")), d_bndes_priv = dl(al(a2, "bndes_priv_l10")))
DUMS <- setNames(lapply(setdiff(names(dq), "trimestre"), function(d) al(dq, d)), setdiff(names(dq), "trimestre"))
stopifnot(all(vapply(DUMS, function(v) !anyNA(v), TRUE)))
DUMS_A4_INF <- c("d_ls2018T2", "d_ao2018T3", "d_ls2019T1", "d_ls2019T3", "d_ao2020T3", "d_ao2021T1", "d_ao2021T2")

# Preco relativo IPCA / deflator implicito da FBCF (1846 corrente / 6612 encadeado, sem ajuste), base media de 2025:
# G em R$ de 2025 pelo IPCA vezes RP = G em precos de 2025 da FBCF (so na robustez do multiplicador).
ib <- ibge %>% filter(trimestre %in% TRIM)
p_fbcf <- al(ib, "fbcf_corrente_1846") / al(ib, "fbcf_encad95_nsa_6612")
i25 <- which(substr(TRIM, 1, 4) == "2025")
p_fbcf_25 <- sum(al(ib, "fbcf_corrente_1846")[i25]) / sum(al(ib, "fbcf_encad95_nsa_6612")[i25])
RP <- (1 / al(defl, "fator_ipca")) / (p_fbcf / p_fbcf_25)
rp_ano <- tapply(RP, substr(TRIM, 1, 4), mean)

get_nome <- function(choque, sp) if (isTRUE(sp$transf12) && choque %in% names(MAP_T12)) MAP_T12[[choque]] else choque
get_x <- function(choque, sp) {
  nm <- get_nome(choque, sp)
  al(if (identical(sp$fonte, "semao")) chs else ch, nm)
}
get_G <- function(choque, sp) {
  nm <- get_nome(choque, sp)
  g <- if (identical(sp$fonte, "semao")) {
    al(inv %>% filter(serie == nm), "real_sa_semao_rs_bi_2025")
  } else al(nv, nm)
  if (identical(sp$deflator, "fbcf")) g <- g * RP
  g
}

# ------------------------------------------------------------------------------------------------
# 2. Estimador: MQO ou MQ2E com Newey-West (Bartlett, lag L, sem prewhitening) ou HC1
# ------------------------------------------------------------------------------------------------
est_iv <- function(y, X1, Z1, W, lag, tipo = "NW") {
  X <- cbind(X1, W); Z <- cbind(Z1, W)
  n <- nrow(X); k <- ncol(X)
  Xh <- Z %*% solve(crossprod(Z), crossprod(Z, X))
  A <- solve(crossprod(Xh))
  b <- drop(A %*% crossprod(Xh, y))
  u <- drop(y - X %*% b)
  S <- Xh * u
  meat <- crossprod(S)
  if (tipo == "NW") {
    for (l in seq_len(min(lag, n - 1))) {
      w <- 1 - l / (lag + 1)
      G <- crossprod(S[(l + 1):n, , drop = FALSE], S[1:(n - l), , drop = FALSE])
      meat <- meat + w * (G + t(G))
    }
  } else if (tipo == "HC1") {
    meat <- meat * n / (n - k)
  }
  V <- A %*% meat %*% A
  list(b = b, V = V, n = n, k = k, u = u, X = X, Z = Z)
}

# Tira de W colunas constantes (fora a constante) e colunas colineares com os instrumentos e controles anteriores.
limpa_W <- function(Z1, W) {
  sdv <- apply(W, 2, sd)
  keepv <- sdv > 1e-12
  keepv[colnames(W) == "const"] <- TRUE
  W <- W[, keepv, drop = FALSE]
  M <- cbind(Z1, W)
  if (qr(M, tol = 1e-9)$rank < ncol(M)) {
    k1 <- ncol(Z1)
    keep <- seq_len(k1)
    for (j in seq_len(ncol(W))) {
      cand <- c(keep, k1 + j)
      if (qr(M[, cand, drop = FALSE], tol = 1e-9)$rank == length(cand)) keep <- cand
    }
    stopifnot(qr(M[, seq_len(k1), drop = FALSE])$rank == k1)
    W <- W[, keep[-seq_len(k1)] - k1, drop = FALSE]
  }
  W
}

# Monta a amostra: constante, tendencia, defasagens 1..p de 'lagged', 'contemp' em t, dummies e, se houver janela
# de exclusao, uma dummy por observacao cujo intervalo de datas usado (t - p - 1 a t + h) toca a janela.
monta <- function(lhs, X1, Z1, lagged, contemp, sp, h) {
  X1 <- as.matrix(X1); Z1 <- as.matrix(Z1)
  W <- cbind(const = 1, tend = seq_len(NT))
  for (nm in names(lagged)) for (l in seq_len(sp$p)) {
    W <- cbind(W, L(lagged[[nm]], l)); colnames(W)[ncol(W)] <- paste0(nm, "_l", l)
  }
  for (nm in names(contemp)) {
    W <- cbind(W, contemp[[nm]]); colnames(W)[ncol(W)] <- nm
  }
  for (d in sp$dums) {
    W <- cbind(W, DUMS[[d]]); colnames(W)[ncol(W)] <- d
  }
  idx <- which(complete.cases(lhs, X1, Z1, W))
  # Subamostra por observacoes efetivas: t a partir de t_min, com as defasagens podendo vir de antes do corte
  if (!is.null(sp$t_min)) idx <- idx[TRIM[idx] >= sp$t_min]
  n_exc <- 0L
  if (length(sp$excl)) {
    hit <- vapply(idx, function(i) {
      r <- TRIM[max(1, i - sp$p - 1):min(NT, i + h)]
      any(vapply(sp$excl, function(e) any(r >= e[1] & r <= e[2]), TRUE))
    }, TRUE)
    if (any(hit)) {
      D <- vapply(idx[hit], function(i) as.numeric(seq_len(NT) == i), numeric(NT))
      colnames(D) <- paste0("exc_", TRIM[idx[hit]])
      W <- cbind(W, D)
    }
    n_exc <- sum(hit)
  }
  list(y = lhs[idx], X1 = X1[idx, , drop = FALSE], Z1 = Z1[idx, , drop = FALSE], W = W[idx, , drop = FALSE],
       idx = idx, n_exc = n_exc)
}

ajusta <- function(m, lag, tipo = "NW", fs = FALSE) {
  W <- limpa_W(m$Z1, m$W)
  k1 <- ncol(m$X1)
  e <- est_iv(m$y, m$X1, m$Z1, W, lag, tipo)
  out <- list(b = e$b[seq_len(k1)], V = e$V[seq_len(k1), seq_len(k1), drop = FALSE], n = e$n - m$n_exc,
              t0 = TRIM[min(m$idx)], t1 = TRIM[max(m$idx)], f1 = rep(NA_real_, k1), W = W, e = e, m = m, tipo = tipo)
  if (fs) {
    q <- ncol(m$Z1)
    out$f1 <- vapply(seq_len(k1), function(j) {
      f <- est_iv(m$X1[, j], m$Z1, m$Z1, W, lag, tipo)
      bz <- f$b[seq_len(q)]
      drop(t(bz) %*% solve(f$V[seq_len(q), seq_len(q), drop = FALSE]) %*% bz) / q
    }, 0)
  }
  out
}

# ------------------------------------------------------------------------------------------------
# 3. Especificacoes e medidas
# ------------------------------------------------------------------------------------------------
SP0 <- list(nome = "baseline", p = 3, hmax = 12, ini = "2003Q1", fim = "2025Q4", z = c("pib_acel", "d_selic_fim"),
            z_lag = FALSE, extra = character(0), dums = c("pulso_2020T2", "pulso_2020T3"), dy0 = FALSE,
            excl = list(), fonte = "base", transf12 = FALSE, deflator = "ipca", t_min = NULL)
upd <- function(sp, ch) {
  for (nm in names(ch)) sp[[nm]] <- ch[[nm]]
  sp
}
sp_base <- function(choque) if (choque %in% CURTOS) upd(SP0, list(p = 2, hmax = 8, ini = "2016Q1")) else SP0
hs_cum <- function(sp) intersect(c(4, 8, 12), 0:sp$hmax)
jan <- function(v, sp) {
  v[TRIM < sp$ini | TRIM > sp$fim] <- NA
  v
}
cumd <- function(v, h) Reduce(`+`, lapply(0:h, function(j) L(v, -j))) - (h + 1) * L(v, 1)
cuml <- function(v, h) Reduce(`+`, lapply(0:h, function(j) L(v, -j)))
exog_parts <- function(sp) {
  z <- setNames(lapply(sp$z, function(nm) jan(EXO[[nm]], sp)), sp$z)
  ex <- setNames(lapply(sp$extra, function(nm) jan(EXO[[nm]], sp)), sp$extra)
  if (isTRUE(sp$z_lag)) list(lagged = z, contemp = ex) else list(lagged = list(), contemp = c(z, ex))
}

# LP em diferenca: y(t+h) - y(t-1) em dx(t), com dx e dy defasados (1..p), exogenas, dummies, constante e tendencia.
lp_dif <- function(x, y, sp, h, medida) {
  x <- jan(x, sp); y <- jan(y, sp)
  dx <- dl(x); dy <- dl(y)
  ex <- exog_parts(sp)
  lagged <- c(list(dx = dx, dy = dy), ex$lagged)
  contemp <- ex$contemp
  if (isTRUE(sp$dy0)) contemp$dy0 <- dy
  m <- switch(medida,
    irf_y = monta(L(y, -h) - L(y, 1), dx, dx, lagged, contemp, sp, h),
    irf_x = monta(L(x, -h) - L(x, 1), dx, dx, lagged, contemp, sp, h),
    elast = monta(cumd(y, h), cumd(x, h), dx, lagged, contemp, sp, h))
  ajusta(m, h + 1, "NW", fs = medida == "elast")
}

# Multiplicador acumulado em R$: soma_{j=0..h} (Y(t+j) - Y(t-1)) / PIB(t-1) em soma_{j=0..h} (G(t+j) - G(t-1)) / PIB(t-1),
# instrumento dG(t) / PIB(t-1); controles: dG/PIB e dY/PIB defasados (cada um com o PIB do trimestre anterior ao seu).
lp_mult <- function(Gs, Y, sp, h) {
  Pl <- L(jan(PIB, sp), 1)
  Y <- jan(Y, sp)
  Gs <- lapply(Gs, jan, sp = sp)
  gY <- dl(Y) / Pl
  gG <- setNames(lapply(Gs, function(G) dl(G) / Pl), paste0("gG", seq_along(Gs)))
  X1 <- do.call(cbind, lapply(Gs, function(G) cumd(G, h) / Pl))
  Z1 <- do.call(cbind, gG)
  ex <- exog_parts(sp)
  lagged <- c(gG, list(gY = gY), ex$lagged)
  contemp <- ex$contemp
  if (isTRUE(sp$dy0)) contemp$dy0 <- gY
  m <- monta(cumd(Y, h) / Pl, X1, Z1, lagged, contemp, sp, h)
  ajusta(m, h + 1, "NW", fs = TRUE)
}

# LP em nivel com defasagens aumentadas: y(t+h) em x(t), com p + 1 defasagens de x e y, erros HC1.
lp_nivel <- function(x, y, sp, h, medida) {
  x <- jan(x, sp); y <- jan(y, sp)
  sp2 <- upd(sp, list(p = sp$p + 1))
  ex <- exog_parts(sp)
  lagged <- list(x = x, y = y)
  m <- switch(medida,
    irf_y = monta(L(y, -h), x, x, lagged, ex$contemp, sp2, h),
    irf_x = monta(L(x, -h), x, x, lagged, ex$contemp, sp2, h),
    elast = monta(cuml(y, h), cuml(x, h), x, lagged, ex$contemp, sp2, h))
  r <- ajusta(m, NA, "HC1", fs = medida == "elast")
  r$p_aum <- sp2$p
  r
}

amostra_txt <- function(sp) paste0(tq(if (is.null(sp$t_min)) sp$ini else sp$t_min), "-", tq(sp$fim))
# Correcao de amostra pequena (robustez): Newey-West com ajuste n/(n - k), como sandwich::NeweyWest(adjust = TRUE), e
# valores criticos da t com n - k graus de liberdade (k inclui as dummies de exclusao). No HC1 o ajuste ja esta feito.
gl_aj <- function(r) r$e$n - r$e$k
fator_aj <- function(r) if (identical(r$tipo, "NW")) sqrt(r$e$n / (r$e$n - r$e$k)) else 1
linha_irf <- function(r, choque, resposta, variavel, esp, modelo, sp, h) {
  b <- r$b[1]; ep <- sqrt(r$V[1, 1]); epa <- ep * fator_aj(r); gl <- gl_aj(r); tc <- qt(0.95, gl)
  tibble(choque = choque, resposta = resposta, variavel = variavel, especificacao = esp, modelo = modelo,
         amostra = amostra_txt(sp), p = sp$p, h = h, beta = b, ep = ep, ic90_inf = b - Z90 * ep,
         ic90_sup = b + Z90 * ep, n = r$n, t_ini = tq(r$t0), t_fim = tq(r$t1), baixo_poder = choque %in% CURTOS,
         ep_aj = epa, gl = gl, ic90_inf_aj = b - tc * epa, ic90_sup_aj = b + tc * epa)
}
linha_cum <- function(r, medida, choque, resposta, esp, modelo, sp, h) {
  b <- r$b[1]; ep <- sqrt(r$V[1, 1])
  eh_fbcf <- medida == "multiplicador" && resposta == "fbcf_real_rs_bi"
  tibble(medida = medida, choque = choque, resposta = resposta, especificacao = esp, modelo = modelo,
         amostra = amostra_txt(sp), p = sp$p, h = h, estimativa = b, ep = ep, ic90_inf = b - Z90 * ep,
         ic90_sup = b + Z90 * ep, p_valor = 2 * pnorm(-abs(b / ep)),
         est_menos_1 = if (eh_fbcf) b - 1 else NA_real_,
         p_valor_igual_1 = if (eh_fbcf) 2 * pnorm(-abs((b - 1) / ep)) else NA_real_,
         f_primeiro_estagio = r$f1[1], n = r$n, t_ini = tq(r$t0), t_fim = tq(r$t1),
         baixo_poder = choque %in% CURTOS,
         ep_aj = ep * fator_aj(r), gl = gl_aj(r),
         ic90_inf_aj = b - qt(0.95, gl_aj(r)) * ep * fator_aj(r), ic90_sup_aj = b + qt(0.95, gl_aj(r)) * ep * fator_aj(r),
         p_valor_aj = 2 * pt(-abs(b / (ep * fator_aj(r))), gl_aj(r)))
}

# ------------------------------------------------------------------------------------------------
# 4. Conferencias do estimador
# ------------------------------------------------------------------------------------------------
chk_x <- get_x("inf_diss", SP0); chk_y <- YL10$fbcf_me
r_chk <- lp_dif(chk_x, chk_y, SP0, 4, "irf_y")
fit <- lm(r_chk$m$y ~ 0 + r_chk$e$X)
v_nw <- sandwich::NeweyWest(fit, lag = 5, prewhite = FALSE, adjust = FALSE)
stopifnot(abs(coef(fit)[1] - r_chk$b[1]) < 1e-10, abs(v_nw[1, 1] - r_chk$V[1, 1]) < 1e-12)
r_hc <- lp_nivel(chk_x, chk_y, SP0, 4, "irf_y")
fit_hc <- lm(r_hc$m$y ~ 0 + r_hc$e$X)
# (o aviso do sandwich sobre valores de alavanca iguais a 1 vem dos pulsos de 2020, que zeram o residuo do trimestre)
stopifnot(abs(suppressWarnings(sandwich::vcovHC(fit_hc, type = "HC1"))[1, 1] - r_hc$V[1, 1]) < 1e-12)
# IV exatamente identificado = forma reduzida / primeiro estagio (mesmos controles)
r_iv <- lp_dif(chk_x, chk_y, SP0, 8, "elast")
Wc <- r_iv$W
rf <- est_iv(r_iv$m$y, r_iv$m$Z1, r_iv$m$Z1, Wc, 9)$b[1]
fs1 <- est_iv(r_iv$m$X1[, 1], r_iv$m$Z1, r_iv$m$Z1, Wc, 9)$b[1]
stopifnot(abs(rf / fs1 - r_iv$b[1]) < 1e-10)
# Elasticidade em h = 0 = IRF em h = 0; resposta do proprio choque em h = 0 = 1
stopifnot(abs(lp_dif(chk_x, chk_y, SP0, 0, "elast")$b[1] - lp_dif(chk_x, chk_y, SP0, 0, "irf_y")$b[1]) < 1e-10,
          abs(lp_dif(chk_x, chk_y, SP0, 0, "irf_x")$b[1] - 1) < 1e-10)
log_part(ETAPA, "- Entradas: data/processed/A2_series_trimestrais.csv (respostas em log10 com sufixo _l10; FBCF, BNDES exceto administracao publica e importacao de BK em R$ bi de 2025; pib_real_rs_bi; pib_acel, pib_cresc, selic_fim, selic_media, cambio_real, icbr_usd, brent_usd), A3_choques_wide.csv (log10 do indice com ajuste), A3_choques_semao_wide.csv, A3_niveis_wide.csv (R$ bi de 2025 com ajuste), A3_invpub_trimestral.csv (niveis sem AO), A4_dummies_quebra.csv, A2_ibge_trimestral.csv e A2_deflator_ipca.csv (so para o preco relativo da robustez do multiplicador). Sem download.")
log_part(ETAPA, "- Estimador proprio (MQO e MQ2E) com Newey-West de Bartlett, lag h + 1, sem prewhitening e sem ajuste de graus de liberdade, igual a sandwich::NeweyWest(prewhite = FALSE, adjust = FALSE). Conferido no script: variancia igual a do sandwich (diferenca < 1e-12), HC1 igual ao sandwich::vcovHC, MQ2E exatamente identificado igual a forma reduzida dividida pelo primeiro estagio, elasticidade em h = 0 igual a IRF em h = 0 e resposta do proprio choque em h = 0 igual a 1. IC de 90% = estimativa +- 1,645 EP; p-valores pela normal.")

# ------------------------------------------------------------------------------------------------
# 5. Baseline: IRF, elasticidades e multiplicadores
# ------------------------------------------------------------------------------------------------
irf_rows <- list(); cum_rows <- list()
for (s in CHOQUES) {
  sp <- sp_base(s); x <- get_x(s, sp)
  for (r in RESPOSTAS) {
    y <- YL10[[r]]
    for (h in 0:sp$hmax) {
      irf_rows[[length(irf_rows) + 1]] <- linha_irf(lp_dif(x, y, sp, h, "irf_y"), s, r, "resposta", "baseline", "diferenca", sp, h)
      irf_rows[[length(irf_rows) + 1]] <- linha_irf(lp_dif(x, y, sp, h, "irf_x"), s, r, "proprio_choque", "baseline", "diferenca", sp, h)
    }
    for (h in hs_cum(sp)) {
      cum_rows[[length(cum_rows) + 1]] <- linha_cum(lp_dif(x, y, sp, h, "elast"), "elasticidade", s, r, "baseline", "diferenca", sp, h)
    }
  }
  G <- get_G(s, sp)
  for (yr in Y_RS) for (h in hs_cum(sp)) {
    cum_rows[[length(cum_rows) + 1]] <- linha_cum(lp_mult(list(G), YRS[[yr]], sp, h), "multiplicador", s, yr, "baseline", "diferenca", sp, h)
  }
}
t_base <- Sys.time()

# LP em nivel com defasagens aumentadas (pares principais: todos os choques x fbcf_me e fbcf_cnt_vol)
for (s in CHOQUES) {
  sp <- sp_base(s); x <- get_x(s, sp)
  for (r in c("fbcf_me", "fbcf_cnt_vol")) {
    y <- YL10[[r]]
    for (h in 0:sp$hmax) {
      irf_rows[[length(irf_rows) + 1]] <- linha_irf(lp_nivel(x, y, sp, h, "irf_y"), s, r, "resposta", "baseline", "nivel_defasagens_aumentadas", sp, h)
      irf_rows[[length(irf_rows) + 1]] <- linha_irf(lp_nivel(x, y, sp, h, "irf_x"), s, r, "proprio_choque", "baseline", "nivel_defasagens_aumentadas", sp, h)
    }
    for (h in hs_cum(sp)) {
      cum_rows[[length(cum_rows) + 1]] <- linha_cum(lp_nivel(x, y, sp, h, "elast"), "elasticidade_nivel", s, r, "baseline", "nivel_defasagens_aumentadas", sp, h)
    }
  }
}

# ------------------------------------------------------------------------------------------------
# 6. Comparacoes: regressao conjunta com os dois choques e Wald da igualdade dos multiplicadores
# ------------------------------------------------------------------------------------------------
PARES <- tribble(
  ~a, ~b, ~rotulo,
  "uniao_econ_dir", "uniao_soc_dir", "Uniao economica x social (direta)",
  "uniao_econ_dt_g1", "uniao_soc_dt_g1", "Uniao economica x social (direta + transferencia)",
  "uniao_soc_dir", "uniao_transf_soc_g1", "Social: direta x transferencia",
  "estatais_sempetro", "estatais_petro", "Estatais sem petroleo x petroleo (2016-2025)",
  "estatais_total", "uniao_gnd4_dir", "Estatais x Uniao direta (GND 4)")
# Elasticidade conjunta: MQ2E de soma [y(t+j) - y(t-1)] nas duas somas [x(t+j) - x(t-1)], instrumentos dx_a(t) e dx_b(t),
# defasagens de dx_a, dx_b e dy, mesmos controles do baseline.
lp_el2 <- function(xa, xb, y, sp, h) {
  xa <- jan(xa, sp); xb <- jan(xb, sp); y <- jan(y, sp)
  dxa <- dl(xa); dxb <- dl(xb); dy <- dl(y)
  ex <- exog_parts(sp)
  lagged <- c(list(dxa = dxa, dxb = dxb, dy = dy), ex$lagged)
  m <- monta(cumd(y, h), cbind(cumd(xa, h), cumd(xb, h)), cbind(dxa, dxb), lagged, ex$contemp, sp, h)
  ajusta(m, h + 1, "NW", fs = TRUE)
}
linha_cmp <- function(r, sa, sb, medida, i, a, b, resposta, sp, h) {
  d <- r$b[1] - r$b[2]; vd <- r$V[1, 1] + r$V[2, 2] - 2 * r$V[1, 2]
  n <- r$e$n; k <- r$e$k; w <- d^2 / vd
  tibble(medida = medida, par = paste(a, "x", b), rotulo = PARES$rotulo[i], choque_a = a, choque_b = b, resposta = resposta,
         amostra = amostra_txt(sp), p = sp$p, h = h,
         est_a = r$b[1], ep_a = sqrt(r$V[1, 1]), est_b = r$b[2], ep_b = sqrt(r$V[2, 2]),
         diferenca = d, ep_diferenca = sqrt(vd), wald = w, p_wald = pchisq(w, 1, lower.tail = FALSE),
         gl = n - k, p_wald_pa = pf(w * (n - k) / n, 1, n - k, lower.tail = FALSE),
         f1_a = r$f1[1], f1_b = r$f1[2], n = r$n,
         est_sep_a = sa$b[1], ep_sep_a = sqrt(sa$V[1, 1]), est_sep_b = sb$b[1], ep_sep_b = sqrt(sb$V[1, 1]),
         baixo_poder = a %in% CURTOS || b %in% CURTOS)
}
cmp_rows <- list()
for (i in seq_len(nrow(PARES))) {
  a <- PARES$a[i]; b <- PARES$b[i]
  sp <- if (a %in% CURTOS || b %in% CURTOS) sp_base(CURTOS[1]) else SP0
  Ga <- get_G(a, sp); Gb <- get_G(b, sp)
  for (yr in Y_RS) for (h in hs_cum(sp)) {
    r <- lp_mult(list(Ga, Gb), YRS[[yr]], sp, h)
    sa <- lp_mult(list(Ga), YRS[[yr]], sp, h); sb <- lp_mult(list(Gb), YRS[[yr]], sp, h)
    cmp_rows[[length(cmp_rows) + 1]] <- linha_cmp(r, sa, sb, "multiplicador", i, a, b, yr, sp, h)
  }
  xa <- get_x(a, sp); xb <- get_x(b, sp)
  for (yr in c("fbcf_cnt_vol", "fbcf_me")) for (h in hs_cum(sp)) {
    r <- lp_el2(xa, xb, YL10[[yr]], sp, h)
    sa <- lp_dif(xa, YL10[[yr]], sp, h, "elast"); sb <- lp_dif(xb, YL10[[yr]], sp, h, "elast")
    cmp_rows[[length(cmp_rows) + 1]] <- linha_cmp(r, sa, sb, "elasticidade", i, a, b, yr, sp, h)
  }
}
cmp <- bind_rows(cmp_rows)

# Trajetoria do multiplicador (FBCF em R$) de h = 0 ao horizonte maximo, da regressao conjunta de cada par (so para a
# figura): nas rubricas o M_h separado mistura o efeito do outro componente (revisao adversarial), entao a figura usa o conjunto.
mult_path <- bind_rows(lapply(seq_len(nrow(PARES)), function(i) {
  a <- PARES$a[i]; b <- PARES$b[i]
  sp <- if (a %in% CURTOS || b %in% CURTOS) sp_base(CURTOS[1]) else SP0
  Ga <- get_G(a, sp); Gb <- get_G(b, sp)
  bind_rows(lapply(0:sp$hmax, function(h) {
    r <- lp_mult(list(Ga, Gb), YRS$fbcf_real_rs_bi, sp, h)
    ep <- sqrt(diag(r$V))
    tibble(par = i, choque = c(a, b), h = h, estimativa = r$b, ic90_inf = r$b - Z90 * ep, ic90_sup = r$b + Z90 * ep)
  }))
}))
# Conferencia: nos horizontes da tabela, a trajetoria conjunta coincide com A5_lp_comparacoes.csv
chk_mp <- cmp %>% filter(medida == "multiplicador", resposta == "fbcf_real_rs_bi") %>%
  mutate(par = match(rotulo, PARES$rotulo)) %>% dplyr::select(par, h, est_a, est_b) %>%
  inner_join(mult_path %>% group_by(par, h) %>% summarise(pa = estimativa[1], pb = estimativa[2], .groups = "drop"), by = c("par", "h"))
stopifnot(nrow(chk_mp) > 0, max(abs(chk_mp$est_a - chk_mp$pa)) < 1e-10, max(abs(chk_mp$est_b - chk_mp$pb)) < 1e-10)

# ------------------------------------------------------------------------------------------------
# 7. Robustez: inf_diss e Uniao economica/social -> fbcf_me (IRF e elasticidade) e -> FBCF em R$ (multiplicador)
# ------------------------------------------------------------------------------------------------
ROB_CHOQUES <- c("inf_diss", "estatais_total", "uniao_econ_dir", "uniao_soc_dir", "uniao_econ_dt_g1", "uniao_soc_dt_g1", "uniao_transf_soc_g1")
CTRL <- c("d_cambio_real", "d_icbr_usd", "d_brent_usd", "d_bndes_priv")
combos <- c(as.list(CTRL), combn(CTRL, 2, simplify = FALSE))
ROB <- c(list(
  list(nome = "pib_cresc", z = c("pib_cresc", "d_selic_fim")),
  list(nome = "ordem_invertida_dy_t", dy0 = TRUE),
  list(nome = "p2", p = 2),
  list(nome = "p4", p = 4),
  list(nome = "exogenas_so_defasadas", z_lag = TRUE),
  list(nome = "selic_media", z = c("pib_acel", "d_selic_media")),
  list(nome = "sub_ate_2014T4", fim = "2014Q4"),
  list(nome = "sub_de_2015T1", t_min = "2015Q1"),
  list(nome = "ate_2019T4", fim = "2019Q4"),
  list(nome = "sem_2020_2021", excl = list(c("2020Q1", "2021Q4"))),
  list(nome = "sem_2016T4_2018T1", excl = list(c("2016Q4", "2018Q1"))),
  list(nome = "choques_sem_AO", fonte = "semao"),
  list(nome = "transferencia_grupos_1e2", transf12 = TRUE),
  list(nome = "dummies_A4", dums = "A4"),
  list(nome = "G_deflator_fbcf", deflator = "fbcf")),
  lapply(combos, function(cc) list(nome = paste0("ctrl_", paste(sub("^d_", "", cc), collapse = "+")), extra = cc)))
rob_info <- list()
for (s in ROB_CHOQUES) for (rb in ROB) {
  if (rb$nome == "transferencia_grupos_1e2" && !(s %in% names(MAP_T12))) next
  ch_sp <- rb[setdiff(names(rb), "nome")]
  if (identical(ch_sp$dums, "A4")) {
    ch_sp$dums <- c(SP0$dums, if (s %in% c("inf_diss", "estatais_total")) DUMS_A4_INF else "degrau_2011T1")
  }
  sp <- upd(SP0, ch_sp)
  G <- get_G(s, sp)
  for (h in hs_cum(sp)) {
    cum_rows[[length(cum_rows) + 1]] <- linha_cum(lp_mult(list(G), YRS$fbcf_real_rs_bi, sp, h), "multiplicador", s, "fbcf_real_rs_bi", rb$nome, "diferenca", sp, h)
  }
  if (rb$nome == "G_deflator_fbcf") next
  x <- get_x(s, sp); y <- YL10$fbcf_me
  for (h in 0:sp$hmax) {
    irf_rows[[length(irf_rows) + 1]] <- linha_irf(lp_dif(x, y, sp, h, "irf_y"), s, "fbcf_me", "resposta", rb$nome, "diferenca", sp, h)
    irf_rows[[length(irf_rows) + 1]] <- linha_irf(lp_dif(x, y, sp, h, "irf_x"), s, "fbcf_me", "proprio_choque", rb$nome, "diferenca", sp, h)
  }
  for (h in hs_cum(sp)) {
    cum_rows[[length(cum_rows) + 1]] <- linha_cum(lp_dif(x, y, sp, h, "elast"), "elasticidade", s, "fbcf_me", rb$nome, "diferenca", sp, h)
  }
}
irf <- bind_rows(irf_rows)
cum <- bind_rows(cum_rows)
t_fim_est <- Sys.time()

# Conferencia: nenhuma estimativa ausente
stopifnot(!anyNA(irf$beta), !anyNA(irf$ep), !anyNA(cum$estimativa), !anyNA(cum$ep), !anyNA(cmp$p_wald))

write_csv_safe(irf, file.path(PATHS$processed, "A5_lp_irf.csv"))
write_csv_safe(cum, file.path(PATHS$processed, "A5_lp_cumulativo.csv"))
write_csv_safe(cmp, file.path(PATHS$processed, "A5_lp_comparacoes.csv"))

# ------------------------------------------------------------------------------------------------
# 8. Figuras: IRF de fbcf_me e multiplicador acumulado (FBCF em R$) nas comparacoes principais
# ------------------------------------------------------------------------------------------------
COR <- c("#2a78d6", "#eb6834")
painel <- function(df, rot, ylab) {
  df$serie <- factor(df$choque, levels = unique(df$choque))
  ggplot(df, aes(h, beta, colour = serie, fill = serie)) +
    geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
    geom_ribbon(aes(ymin = ic90_inf, ymax = ic90_sup), alpha = 0.15, colour = NA) +
    geom_line(linewidth = 0.7) + geom_point(size = 1.2) +
    scale_colour_manual(values = COR, name = NULL) + scale_fill_manual(values = COR, name = NULL) +
    scale_x_continuous(breaks = seq(0, 12, 2)) +
    labs(title = rot, x = "h (trimestres)", y = ylab) +
    theme_minimal(base_size = 9) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "grey92", linewidth = 0.3), plot.title = element_text(size = 9))
}
pl_irf <- lapply(seq_len(nrow(PARES)), function(i) {
  df <- irf %>% filter(especificacao == "baseline", modelo == "diferenca", resposta == "fbcf_me", variavel == "resposta",
                       choque %in% c(PARES$a[i], PARES$b[i])) %>%
    mutate(choque = factor(choque, levels = c(PARES$a[i], PARES$b[i]))) %>% arrange(choque) %>%
    mutate(choque = as.character(choque))
  painel(df, PARES$rotulo[i], "beta_h (log10 de fbcf_me)")
})
g1 <- wrap_plots(pl_irf, ncol = 2) +
  plot_annotation(title = "LP: resposta de fbcf_me (M&E, Ipea) a choques de investimento publico, IC 90% (Newey-West)",
                  caption = "y(t+h) - y(t-1) em dx(t), log10; p = 3 (p = 2 e h ate 8 nas estatais de 2016+, baixo poder).",
                  theme = theme(plot.title = element_text(size = 10)))
ggsave_safe(file.path(PATHS$figuras, "A5_lp_irf_comparacoes.png"), g1, width = 9, height = 10, dpi = 200, bg = "white")
ggsave_safe(file.path(PATHS$figuras, "A5_lp_irf_comparacoes.pdf"), g1, width = 9, height = 10)
pl_mult <- lapply(seq_len(nrow(PARES)), function(i) {
  df <- mult_path %>% filter(par == i) %>%
    transmute(choque = factor(choque, levels = c(PARES$a[i], PARES$b[i])), h, beta = estimativa, ic90_inf, ic90_sup) %>%
    arrange(choque) %>% mutate(choque = as.character(choque))
  painel(df, PARES$rotulo[i], "M_h (R$ de FBCF por R$ de G)")
})
g2 <- wrap_plots(pl_mult, ncol = 2) +
  plot_annotation(title = "Multiplicador acumulado da FBCF (Contas Nacionais, R$) por R$ de investimento publico, IC 90%",
                  caption = "Soma de dY/PIB(t-1) em soma de dG/PIB(t-1), instrumentos dG(t)/PIB(t-1); regressao conjunta dos dois choques de cada par.",
                  theme = theme(plot.title = element_text(size = 10)))
ggsave_safe(file.path(PATHS$figuras, "A5_lp_mult_comparacoes.png"), g2, width = 9, height = 10, dpi = 200, bg = "white")
ggsave_safe(file.path(PATHS$figuras, "A5_lp_mult_comparacoes.pdf"), g2, width = 9, height = 10)

# ------------------------------------------------------------------------------------------------
# 9. Relatorio results/A5_lp.md
# ------------------------------------------------------------------------------------------------
hfin <- function(s) if (s %in% CURTOS) 8 else 12
base_cum <- cum %>% filter(especificacao == "baseline")
el <- function(s, r, h, med = "elasticidade") base_cum %>% filter(medida == med, choque == s, resposta == r, h == !!h)
ir <- function(s, r, h, mod = "diferenca", esp = "baseline") irf %>%
  filter(especificacao == esp, modelo == mod, choque == s, resposta == r, variavel == "resposta", h == !!h)

tab_irf <- bind_rows(lapply(CHOQUES, function(s) {
  cels <- vapply(c(0, 4, 8, 12), function(h) {
    if (h > hfin(s)) return("")
    z <- ir(s, "fbcf_me", h); cel(z$beta, z$ic90_inf, z$ic90_sup)
  }, "")
  tibble(choque = s, `h = 0` = cels[1], `h = 4` = cels[2], `h = 8` = cels[3], `h = 12` = cels[4],
         n_h0 = ir(s, "fbcf_me", 0)$n)
}))
tab_el <- bind_rows(lapply(CHOQUES, function(s) {
  cels <- vapply(c(4, 8, 12), function(h) {
    if (h > hfin(s)) return("")
    z <- el(s, "fbcf_me", h); paste0(cel(z$estimativa, z$ic90_inf, z$ic90_sup), " (p ", pv(z$p_valor), "; F1 ", num(z$f_primeiro_estagio, 1), ")")
  }, "")
  tibble(choque = s, `h = 4` = cels[1], `h = 8` = cels[2], `h = 12` = cels[3])
}))
tab_el_all <- bind_rows(lapply(CHOQUES, function(s) {
  h <- hfin(s)
  v <- vapply(RESPOSTAS, function(r) {
    z <- el(s, r, h); paste0(num(z$estimativa, 3), " (", num(z$ep, 3), ")", estrela(z$ic90_inf, z$ic90_sup))
  }, "")
  bind_cols(tibble(choque = s, h = h), as_tibble(as.list(v)))
}))
# Razao media FBCF / G na janela de cada choque: M_h e, aproximadamente, elasticidade x (Y / G)
razao_yg <- vapply(CHOQUES, function(s) {
  sp <- sp_base(s); G <- jan(get_G(s, sp), sp); Y <- jan(YRS$fbcf_real_rs_bi, sp); ok <- !is.na(G) & !is.na(Y)
  mean(Y[ok]) / mean(G[ok])
}, 0)
tab_mult <- bind_rows(lapply(CHOQUES, function(s) bind_rows(lapply(hs_cum(sp_base(s)), function(h) {
  z <- el(s, "fbcf_real_rs_bi", h, "multiplicador")
  zb <- el(s, "bndes_priv", h, "multiplicador"); zi <- el(s, "imp_bk_real", h, "multiplicador")
  tibble(choque = s, h = h, `M_h FBCF [IC 90%]` = cel(z$estimativa, z$ic90_inf, z$ic90_sup, 2), `p (M = 0)` = pv(z$p_valor),
         `M_h - 1` = num(z$est_menos_1, 2), `p (M = 1)` = pv(z$p_valor_igual_1), F1 = num(z$f_primeiro_estagio, 1),
         `M_h BNDES` = cel(zb$estimativa, zb$ic90_inf, zb$ic90_sup, 2), `M_h import. BK` = cel(zi$estimativa, zi$ic90_inf, zi$ic90_sup, 2),
         `FBCF / G medio` = num(razao_yg[[s]], 0), n = z$n)
}))))
tab_cmp_f <- function(med, d) cmp %>% filter(medida == med) %>% transmute(rotulo, resposta, h,
  `a [IC 90%]` = cel(est_a, est_a - Z90 * ep_a, est_a + Z90 * ep_a, d),
  `b [IC 90%]` = cel(est_b, est_b - Z90 * ep_b, est_b + Z90 * ep_b, d),
  `a - b (EP)` = paste0(num(diferenca, d), " (", num(ep_diferenca, d), ")"), `p Wald` = pv(p_wald), `p Wald amostra pequena` = pv(p_wald_pa),
  `F1 a / b` = paste0(num(f1_a, 1), " / ", num(f1_b, 1)),
  `separadas: a / b` = paste0(num(est_sep_a, d), " / ", num(est_sep_b, d)), n, `baixo poder` = ifelse(baixo_poder, "sim", ""))
tab_cmp <- tab_cmp_f("multiplicador", 2)
tab_cmp_el <- tab_cmp_f("elasticidade", 3)
tab_niv <- bind_rows(lapply(CHOQUES, function(s) {
  h <- hfin(s)
  zd <- el(s, "fbcf_me", h); zn <- el(s, "fbcf_me", h, "elasticidade_nivel")
  zd2 <- el(s, "fbcf_cnt_vol", h); zn2 <- el(s, "fbcf_cnt_vol", h, "elasticidade_nivel")
  tibble(choque = s, h = h, `fbcf_me dif.` = cel(zd$estimativa, zd$ic90_inf, zd$ic90_sup),
         `fbcf_me nivel aum.` = cel(zn$estimativa, zn$ic90_inf, zn$ic90_sup),
         `fbcf_cnt_vol dif.` = cel(zd2$estimativa, zd2$ic90_inf, zd2$ic90_sup),
         `fbcf_cnt_vol nivel aum.` = cel(zn2$estimativa, zn2$ic90_inf, zn2$ic90_sup))
}))
rob_nomes <- c("baseline", vapply(ROB, `[[`, "", "nome"))
rob_tab <- function(med, resp, d) {
  z <- cum %>% filter(medida == med, resposta == resp, h == 12, choque %in% ROB_CHOQUES)
  out <- tibble(especificacao = rob_nomes)
  for (s in ROB_CHOQUES) {
    zz <- z %>% filter(choque == s)
    out[[s]] <- vapply(rob_nomes, function(e) {
      w <- zz %>% filter(especificacao == e)
      if (!nrow(w)) return("")
      paste0(num(w$estimativa, d), " (", num(w$ep, d), ")", estrela(w$ic90_inf, w$ic90_sup))
    }, "")
  }
  out
}
tab_rob_el <- rob_tab("elasticidade", "fbcf_me", 3) %>% filter(especificacao != "G_deflator_fbcf")
tab_rob_m <- rob_tab("multiplicador", "fbcf_real_rs_bi", 2)
rob_el <- cum %>% filter(medida == "elasticidade", resposta == "fbcf_me", h == 12, choque %in% ROB_CHOQUES)
rob_m <- cum %>% filter(medida == "multiplicador", resposta == "fbcf_real_rs_bi", h == 12, choque %in% ROB_CHOQUES)
rob_resumo <- bind_rows(lapply(ROB_CHOQUES, function(s) {
  e <- rob_el %>% filter(choque == s); m <- rob_m %>% filter(choque == s)
  tibble(choque = s, n_esp = nrow(e),
         `elasticidade h = 12: min / mediana / max` = paste(num(min(e$estimativa)), num(median(e$estimativa)), num(max(e$estimativa)), sep = " / "),
         `IC exclui zero` = paste0(sum(e$ic90_inf > 0 | e$ic90_sup < 0), " de ", nrow(e)),
         `M_12 FBCF: min / mediana / max` = paste(num(min(m$estimativa), 2), num(median(m$estimativa), 2), num(max(m$estimativa), 2), sep = " / "),
         `IC de M exclui zero` = paste0(sum(m$ic90_inf > 0 | m$ic90_sup < 0), " de ", nrow(m)))
}))

# Contagem de testes (baseline, em diferenca): IRF das respostas + elasticidades + multiplicadores + comparacoes
n_irf_test <- irf %>% filter(especificacao == "baseline", modelo == "diferenca", variavel == "resposta") %>% nrow()
n_cum_test <- base_cum %>% filter(modelo == "diferenca") %>% nrow()
n_irf_sig <- irf %>% filter(especificacao == "baseline", modelo == "diferenca", variavel == "resposta", h > 0) %>%
  summarise(k = sum(ic90_inf > 0 | ic90_sup < 0), n = n())
n_el_sig <- base_cum %>% filter(medida == "elasticidade") %>% summarise(k = sum(ic90_inf > 0 | ic90_sup < 0), pos = sum(ic90_inf > 0), n = n())

# Leitura curta (so numeros)
fz <- function(z, d = 3) cel(z$estimativa, z$ic90_inf, z$ic90_sup, d)
ajm <- base_cum %>% filter(modelo == "diferenca") %>% mutate(f = ep_aj / ep) %>% pull(f)
leitura <- c(
  sprintf("- inf_diss -> fbcf_me, elasticidade acumulada: h = 4 %s; h = 8 %s; h = 12 %s. IRF em h = 0: %s.",
          fz(el("inf_diss", "fbcf_me", 4)), fz(el("inf_diss", "fbcf_me", 8)), fz(el("inf_diss", "fbcf_me", 12)),
          cel(ir("inf_diss", "fbcf_me", 0)$beta, ir("inf_diss", "fbcf_me", 0)$ic90_inf, ir("inf_diss", "fbcf_me", 0)$ic90_sup)),
  sprintf("- Elasticidade de fbcf_me em h = 12 (regressoes separadas, um choque por vez; para comparar rubricas valem as regressoes conjuntas abaixo): uniao_econ_dir %s; uniao_soc_dir %s; uniao_econ_dt_g1 %s; uniao_soc_dt_g1 %s; uniao_transf_soc_g1 %s; estatais_total %s; uniao_gnd4_dir %s.",
          fz(el("uniao_econ_dir", "fbcf_me", 12)), fz(el("uniao_soc_dir", "fbcf_me", 12)), fz(el("uniao_econ_dt_g1", "fbcf_me", 12)),
          fz(el("uniao_soc_dt_g1", "fbcf_me", 12)), fz(el("uniao_transf_soc_g1", "fbcf_me", 12)), fz(el("estatais_total", "fbcf_me", 12)),
          fz(el("uniao_gnd4_dir", "fbcf_me", 12))),
  sprintf("- Multiplicador acumulado da FBCF (R$) em h = 12, so nos agregados: inf_diss %s; estatais_total %s; uniao_gnd4_dir %s. Nas rubricas (Uniao por tipo e modalidade, estatais por segmento), os M_h de regressoes separadas nao sao lidos em R$: a razao FBCF / G vai de %s a %s, e o M_h separado cai quando o outro componente entra como controle (uniao_soc_dir em h = 12: %s na separada, %s na conjunta com uniao_econ_dir); isso indica comovimento com a FBCF agregada, nao efeito causal. Nas rubricas valem as comparacoes conjuntas abaixo, de preferencia em elasticidade.",
          fz(el("inf_diss", "fbcf_real_rs_bi", 12, "multiplicador"), 2), fz(el("estatais_total", "fbcf_real_rs_bi", 12, "multiplicador"), 2),
          fz(el("uniao_gnd4_dir", "fbcf_real_rs_bi", 12, "multiplicador"), 2),
          num(min(razao_yg[setdiff(CHOQUES, c("inf_diss", "estatais_total", "uniao_gnd4_dir", "uniao_filtro_diss"))]), 0),
          num(max(razao_yg[setdiff(CHOQUES, c("inf_diss", "estatais_total", "uniao_gnd4_dir", "uniao_filtro_diss"))]), 0),
          fz(el("uniao_soc_dir", "fbcf_real_rs_bi", 12, "multiplicador"), 2),
          { z <- cmp %>% filter(medida == "multiplicador", choque_a == "uniao_econ_dir", choque_b == "uniao_soc_dir", resposta == "fbcf_real_rs_bi", h == 12)
            cel(z$est_b, z$est_b - Z90 * z$ep_b, z$est_b + Z90 * z$ep_b, 2) }),
  vapply(seq_len(nrow(PARES)), function(i) {
    ze <- cmp %>% filter(medida == "elasticidade", choque_a == PARES$a[i], choque_b == PARES$b[i], resposta == "fbcf_cnt_vol")
    zm <- cmp %>% filter(medida == "multiplicador", choque_a == PARES$a[i], choque_b == PARES$b[i], resposta == "fbcf_real_rs_bi")
    paste0("- ", PARES$rotulo[i], ", regressao conjunta. Elasticidade da FBCF (fbcf_cnt_vol): ",
           paste(sprintf("h = %d: %s x %s, p de Wald %s (amostra pequena %s)", ze$h, num(ze$est_a, 3), num(ze$est_b, 3), pv(ze$p_wald), pv(ze$p_wald_pa)), collapse = "; "),
           ". M_h da FBCF em R$: ",
           paste(sprintf("h = %d: %s x %s, p de Wald %s (amostra pequena %s)", zm$h, num(zm$est_a, 2), num(zm$est_b, 2), pv(zm$p_wald), pv(zm$p_wald_pa)), collapse = "; "),
           if (any(zm$baixo_poder)) sprintf(". Serie de 2016+ com poucas observacoes (baixo poder; n = %s, gl = %s): com a correcao de amostra pequena (Newey-West vezes n/(n - k) e F(1, n - k)), p de %s no M_h em R$ e de %s na elasticidade; resultado so sugestivo",
             paste(zm$n, collapse = " e "), paste(zm$gl, collapse = " e "), paste(pv(zm$p_wald_pa), collapse = " e "), paste(pv(ze$p_wald_pa), collapse = " e ")) else "",
           ".")
  }, ""),
  sprintf("- Razao media FBCF / G na janela de cada choque (M_h e aproximadamente a elasticidade da FBCF vezes essa razao): %s.",
          paste(sprintf("%s %s", CHOQUES, num(razao_yg, 0)), collapse = "; ")),
  sprintf("- Erros de Newey-West sem ajuste de graus de liberdade e IC pela normal no baseline (como no sandwich com adjust = FALSE). Com o ajuste n/(n - k) o EP cresce %s%% a %s%% (mediana %s%%) nas medidas acumuladas do baseline em diferenca; as colunas ep_aj, ic90_inf_aj, ic90_sup_aj (t com n - k graus de liberdade) e p_valor_aj dos CSV trazem essa versao. Elasticidade de inf_diss em fbcf_me em h = 12 com o ajuste: %s.",
          num(100 * (min(ajm) - 1), 0), num(100 * (max(ajm) - 1), 0), num(100 * (median(ajm) - 1), 0),
          { z <- el("inf_diss", "fbcf_me", 12); cel(z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj) }),
  sprintf("- IRF do baseline em diferenca (h = 1 a 12, 12 choques x 8 respostas): IC de 90%% exclui zero em %d de %d coeficientes (%s%%; sem efeito algum, cerca de 10%% excluiriam zero por acaso, e os coeficientes de horizontes vizinhos sao correlacionados). Elasticidades acumuladas (h = 4, 8, 12): %d de %d excluem zero (%d positivas).",
          n_irf_sig$k, n_irf_sig$n, num(100 * n_irf_sig$k / n_irf_sig$n, 1), n_el_sig$k, n_el_sig$n, n_el_sig$pos))

md <- c(
  "# A5: projecoes locais, elasticidades e multiplicadores",
  "",
  paste0("Gerado por R/A5_lp.R em ", format(Sys.time(), "%Y-%m-%d %H:%M"), ". Numeros com virgula decimal. IC de 90% pontuais (estimativa +- 1,645 EP), sem correcao para testes multiplos. Newey-West sem ajuste de graus de liberdade: com n/(n - k) o EP cresce ", num(100 * (min(ajm) - 1), 0), "% a ", num(100 * (max(ajm) - 1), 0), "% (mediana ", num(100 * (median(ajm) - 1), 0), "%) nas medidas acumuladas do baseline, e os IC deste relatorio ficam um pouco estreitos; os CSV trazem a versao ajustada (ep_aj, ic90_inf_aj, ic90_sup_aj com t de n - k graus, p_valor_aj)."),
  "",
  "## Especificacao",
  "",
  "- Baseline (Jorda, 2005): y(t+h) - y(t-1) = a + b t + beta_h dx(t) + soma_{l=1..p} [phi_l dx(t-l) + psi_l dy(t-l)] + g' z(t) + d' D(t) + u, h = 0 a 12, p = 3, amostra 2003T1-2025T4 (primeiro t = 2004T1). x = log10 do indice com ajuste (A3), y = log10 da variavel privada (A2). z = pib_acel e diff(selic_fim). D = pulsos de 2020T2 e 2020T3 (A4). Sem dy(t): o choque vem antes da resposta. Newey-West com lag h + 1.",
  "- Series de 2016+ (estatais_petro, estatais_sempetro, estatais_econ): 2016T1-2025T4, p = 2, h ate 8, baixo poder (29 a 37 observacoes).",
  "- Elasticidade acumulada (Ramey e Zubairy, 2018): MQ2E de soma_{j=0..h} [y(t+j) - y(t-1)] em soma_{j=0..h} [x(t+j) - x(t-1)], instrumento dx(t), mesmos controles. F1 = F de Newey-West do instrumento no primeiro estagio.",
  "- Multiplicador acumulado em R$: MQ2E de soma_{j=0..h} [Y(t+j) - Y(t-1)] / PIB(t-1) em soma_{j=0..h} [G(t+j) - G(t-1)] / PIB(t-1), instrumento dG(t) / PIB(t-1); controles: p defasagens de dG/PIB e dY/PIB, z, D, constante e tendencia. Y = FBCF das Contas Nacionais (R$ bi de 2025, precos da FBCF), BNDES exceto administracao publica ou importacao de BK (R$ bi de 2025 pelo IPCA); G = nivel do choque em R$ bi de 2025 pelo IPCA (A3_niveis_wide.csv).",
  "- M_h - 1 so para a FBCF: parte de G nao e FBCF (sentencas, indenizacoes, despesas de exercicios anteriores, servicos de terceiros no GND 4) e a FBCF das Contas Nacionais inclui estados, municipios e as proprias estatais; M_h - 1 nao e o efeito sobre a FBCF privada, e sim sobre a FBCF que nao e o proprio G, sob a hipotese de que todo G entra na FBCF.",
  "- Conversao de fbcf_me em R$: nao feita. O SIDRA nao tem tabela anual de FBCF por tipo de ativo (a unica tabela das Contas Nacionais Anuais na API de agregados do IBGE e a 6784, PIB, PIB per capita, populacao e deflator; consulta de 2026-09-28).",
  "",
  "## Leitura curta",
  "",
  leitura,
  "",
  "## 1. IRF de fbcf_me (beta_h, log10 de fbcf_me para 1 log10 do choque) [IC 90%]",
  "",
  md_table(tab_irf),
  "",
  "## 2. Elasticidade acumulada de fbcf_me [IC 90%] (p-valor; F do primeiro estagio)",
  "",
  md_table(tab_el),
  "",
  "## 3. Elasticidade acumulada em h = 12 (h = 8 nas series de 2016+), todas as respostas: estimativa (EP); * = IC de 90% exclui zero",
  "",
  md_table(tab_el_all),
  "",
  "## 4. Multiplicadores acumulados em R$ (estimativas separadas)",
  "",
  "Leitura em R$ so nos agregados (inf_diss, estatais_total, uniao_gnd4_dir; uniao_filtro_diss como conferencia). Nas rubricas (Uniao por tipo e modalidade, estatais por segmento), o M_h separado mede o comovimento da rubrica com a FBCF agregada: a razao FBCF / G e de dezenas a centenas e o M_h cai quando o outro componente entra como controle. Para as rubricas, use os M_h e as elasticidades da regressao conjunta (secao 5).",
  "",
  md_table(tab_mult),
  "",
  "## 5. Comparacoes: regressao conjunta com os dois choques, Wald da igualdade",
  "",
  "Colunas a e b vem da regressao conjunta (dois endogenos, dois instrumentos, defasagens de ambos e da resposta); 'separadas' repete as estimativas de uma regressao por choque. F1 = F de Newey-West dos dois instrumentos no primeiro estagio de cada endogeno. p Wald: qui-quadrado com 1 grau e Newey-West sem ajuste; p Wald amostra pequena: Newey-West vezes n/(n - k) e F(1, n - k), com k = numero de regressores. Nas rubricas, a leitura em R$ nao e crivel (FBCF / G de dezenas a centenas; o M_h separado pode ficar muito acima do conjunto, como em uniao_soc_dir): use a elasticidade conjunta (5b) e os M_h conjuntos, nao os separados.",
  "",
  "### 5a. Multiplicador acumulado da FBCF, BNDES e importacao de BK em R$ (M_a x M_b)",
  "",
  md_table(tab_cmp),
  "",
  "### 5b. Elasticidade acumulada conjunta (fbcf_cnt_vol, FBCF das Contas Nacionais em volume, e fbcf_me)",
  "",
  md_table(tab_cmp_el),
  "",
  "## 6. LP em nivel com defasagens aumentadas (Montiel Olea e Plagborg-Moller, 2021): elasticidade acumulada [IC 90%]",
  "",
  "y(t+h) em x(t) em log10, com p + 1 defasagens de x e y, mesmas exogenas e dummies, erros HC1. Elasticidade = MQ2E de soma y(t+j) em soma x(t+j), instrumento x(t). Comparada com a LP em diferenca no mesmo horizonte.",
  "",
  md_table(tab_niv),
  "",
  "## 7. Robustez",
  "",
  "Resumo por choque (elasticidade de fbcf_me e multiplicador da FBCF em R$, h = 12, todas as especificacoes, inclusive o baseline):",
  "",
  md_table(rob_resumo),
  "",
  "Elasticidade acumulada de fbcf_me em h = 12: estimativa (EP); * = IC de 90% exclui zero.",
  "",
  md_table(tab_rob_el),
  "",
  "Multiplicador acumulado da FBCF em R$ em h = 12: estimativa (EP); * = IC de 90% exclui zero.",
  "",
  md_table(tab_rob_m),
  "",
  "Especificacoes: pib_cresc (PIB em crescimento em vez de aceleracao); ordem_invertida_dy_t (inclui dy(t); em h = 0 a IRF e zero por construcao); p2 e p4; exogenas_so_defasadas (z(t-1) a z(t-p) em vez de z(t)); selic_media; sub_ate_2014T4 (dados ate 2014T4, t + h <= 2014T4) e sub_de_2015T1 (t >= 2015T1, defasagens de 2014), com o corte da A4; ate_2019T4; sem_2020_2021 e sem_2016T4_2018T1 (uma dummy por observacao cujo intervalo de datas usado, t - p - 1 a t + h, toca a janela); choques_sem_AO (A3_choques_semao_wide.csv e niveis sem AO); transferencia_grupos_1e2 (colunas sem _g1); dummies_A4 (inf_diss e estatais_total: outliers do X-11 de 2018-2021; Uniao: degrau de 2011T1); G_deflator_fbcf (so multiplicador: G reexpresso a precos de 2025 da FBCF); ctrl_* (controles adicionais em diff do log10, contemporaneos, um ou dois por vez).",
  "",
  "## Figuras",
  "",
  "- results/figuras/A5_lp_irf_comparacoes.png e .pdf: IRF de fbcf_me aos dois choques de cada comparacao, IC 90%.",
  "- results/figuras/A5_lp_mult_comparacoes.png e .pdf: multiplicador acumulado da FBCF em R$, h = 0 ao horizonte maximo, IC 90%, da regressao conjunta dos dois choques de cada par.",
  "",
  "## Arquivos",
  "",
  "- data/processed/A5_lp_irf.csv: IRF (variavel = resposta ou proprio_choque; modelo = diferenca ou nivel_defasagens_aumentadas).",
  "- data/processed/A5_lp_cumulativo.csv: elasticidades (diferenca e nivel) e multiplicadores em h = 4, 8, 12, baseline e robustez.",
  "- data/processed/A5_lp_comparacoes.csv: pares, h, multiplicadores conjuntos e separados, diferenca e p-valor de Wald.")
write_lines_safe(md, file.path(PATHS$results, "A5_lp.md"))

# ------------------------------------------------------------------------------------------------
# 10. Log
# ------------------------------------------------------------------------------------------------
n_base <- irf %>% filter(especificacao == "baseline", modelo == "diferenca", variavel == "resposta", resposta == "fbcf_me")
log_part(ETAPA, sprintf("- Baseline (Jorda, 2005), como pedido: y(t+h) - y(t-1) em dx(t), com constante, tendencia, dx e dy defasados (p = 3), pib_acel e diff(selic_fim) contemporaneos e os pulsos de 2020T2 e 2020T3, sem dy(t) (choque antes da resposta). Dummies da A4: o paragrafo final da A4 manda usar so os pulsos da pandemia no baseline; o degrau de 2011T1 (choques da Uniao) e os outliers do X-11 de 2018-2021 (inf_diss) vao na robustez dummies_A4. Amostra 2003T1-2025T4 em todas as series (os dados de 2002 nao entram): primeiro t = 2004T1; n = %d em h = 0 e %d em h = 12. Series de 2016+: 2016T1-2025T4, p = 2, h ate 8; n = %d em h = 0 e %d em h = 8. Choques = %d; respostas = %d.",
  n_base %>% filter(choque == "inf_diss", h == 0) %>% pull(n), n_base %>% filter(choque == "inf_diss", h == 12) %>% pull(n),
  n_base %>% filter(choque == "estatais_petro", h == 0) %>% pull(n), n_base %>% filter(choque == "estatais_petro", h == 8) %>% pull(n),
  length(CHOQUES), length(RESPOSTAS)))
log_part(ETAPA, "- IRF do proprio choque: x(t+h) - x(t-1) na mesma especificacao da resposta (mesmos controles, inclusive dy defasado); guardada em A5_lp_irf.csv com variavel = proprio_choque. Em h = 0 e 1 por construcao.")
log_part(ETAPA, "- Elasticidade acumulada: MQ2E de soma_{j=0..h}[y(t+j) - y(t-1)] em soma_{j=0..h}[x(t+j) - x(t-1)], instrumento dx(t), mesmos controles, Newey-West com lag h + 1. Multiplicador: mesmo desenho com Y e G em R$ divididos pelo PIB real do trimestre anterior a t (as somas usam PIB(t-1) fixo); as defasagens de dG/PIB e dY/PIB usam, cada uma, o PIB do trimestre anterior a sua data. F do primeiro estagio (Newey-West) guardado em f_primeiro_estagio.")
log_part(ETAPA, sprintf("- Precos: G esta em R$ de 2025 pelo IPCA (A3) e a FBCF em R$ de 2025 a precos da propria FBCF (A2). O preco relativo IPCA/deflator da FBCF (1846/6612, base 2025) vale %s em 2003, %s em 2014 e %s em 2025 (media anual): um real de G de 2003 compra mais FBCF do que a conversao pelo IPCA indica. No baseline os dois deflatores ficam como estao (como pedido); a robustez G_deflator_fbcf reexpressa G a precos da FBCF.",
  num(rp_ano[["2003"]], 3), num(rp_ano[["2014"]], 3), num(rp_ano[["2025"]], 3)))
log_part(ETAPA, "- Unidades de G nas series de 2016+: nivel da OI da SEST sem encadeamento (o fator 0,9303 da A3 so serve para comparar com o boletim); estatais_total e o encadeado (boletim ate 2019, OI x razao depois). BNDES exceto administracao publica inclui estatais (Petrobras, Eletrobras): nao e desembolso privado puro.")
log_part(ETAPA, "- Conversao de fbcf_me em R$ (calculo secundario pedido): nao feita. Na API de agregados do IBGE (servicodados.ibge.gov.br/api/v3/agregados, consulta de 2026-09-28) as Contas Nacionais Anuais so tem a tabela 6784 (PIB, PIB per capita, populacao e deflator); nao ha FBCF anual por tipo de ativo (maquinas e equipamentos) no SIDRA. A busca do sidrar (search_sidra) nao devolveu nada e a apisidra.ibge.gov.br respondeu com desafio do Cloudflare. As elasticidades de fbcf_me e pim_bk ficam sem conversao; a FBCF por ativo esta nas tabelas de recursos e usos do IBGE (planilhas, fora do SIDRA) e pode entrar depois se o autor quiser.")
log_part(ETAPA, "- Comparacoes (A5_lp_comparacoes.csv): regressao conjunta com os dois G como endogenos (somas acumuladas / PIB(t-1)), os dois dG(t)/PIB(t-1) como instrumentos e p defasagens de dG_a/PIB, dG_b/PIB e dY/PIB; Wald de M_a = M_b com a matriz de Newey-West conjunta (qui-quadrado com 1 grau) e, como correcao de amostra pequena, com a matriz vezes n/(n - k) e F(1, n - k) (coluna p_wald_pa). Elasticidade conjunta (medida = elasticidade): soma das diferencas do log10 da resposta (fbcf_cnt_vol e fbcf_me) nas duas somas dos choques, instrumentos dx_a(t) e dx_b(t), defasagens de dx_a, dx_b e dy. Pares: uniao_econ_dir x uniao_soc_dir; uniao_econ_dt_g1 x uniao_soc_dt_g1; uniao_soc_dir x uniao_transf_soc_g1 (so social; a transferencia economica nao passa no criterio de qualidade da A3); estatais_sempetro x estatais_petro (2016T1-2025T4, p = 2, h = 4 e 8); estatais_total x uniao_gnd4_dir. Os componentes de cada par sao disjuntos. Feito para Y = FBCF (principal), BNDES e importacao de BK.")
log_part(ETAPA, "- LP em nivel com defasagens aumentadas (Montiel Olea e Plagborg-Moller, 2021): y(t+h) em x(t), log10, com p + 1 defasagens de x e y (4; 3 nas series de 2016+), constante, tendencia, as mesmas exogenas e dummies do baseline, erros HC1 (sem Newey-West, como no artigo). Pares: os 12 choques x fbcf_me e fbcf_cnt_vol. Elasticidade em nivel = MQ2E de soma y(t+j) em soma x(t+j), instrumento x(t).")
log_part(ETAPA, sprintf("- Robustez (%d especificacoes alem do baseline) para %s: IRF e elasticidade de fbcf_me e multiplicador da FBCF em R$. Controles adicionais em diff do log10 (cambio_real, icbr_usd, brent_usd, bndes_priv), contemporaneos como no VAR, um ou dois por vez (10 combinacoes). exogenas_so_defasadas: z(t-1) a z(t-p) no lugar de z(t). Subamostras com o corte da A4 (quebra entre 2014T4 e 2015T1), por observacoes efetivas: sub_ate_2014T4 usa so dados ate 2014T4 (t + h <= 2014T4; os pulsos de 2020 saem por serem nulos); sub_de_2015T1 usa t >= 2015T1, com as defasagens podendo vir de 2014. sem_2020_2021 e sem_2016T4_2018T1: uma dummy por observacao cujo intervalo de datas usado (t - p - 1 a t + h) toca a janela (equivale a tirar a observacao sem abrir buraco na ordem do tempo do Newey-West). choques_sem_AO: choque de A3_choques_semao_wide.csv e G sem AO (real_sa_semao_rs_bi_2025 de A3_invpub_trimestral.csv). transferencia_grupos_1e2 so nos choques _g1.",
  length(ROB), paste(ROB_CHOQUES, collapse = ", ")))
log_part(ETAPA, sprintf("- Muitos testes: so no baseline em diferenca sao %d coeficientes de IRF de resposta (12 choques x 8 respostas x h), %d medidas acumuladas (elasticidades e multiplicadores) e %d comparacoes de Wald, alem de %d estimativas de robustez. Os IC de 90%% sao pontuais, sem correcao para testes multiplos; por acaso, cerca de 10%% dos IC excluiriam zero. Na IRF do baseline (h = 1 a 12), %d de %d IC excluem zero (%s%%); nas elasticidades acumuladas do baseline, %d de %d (%d positivas).",
  n_irf_test, n_cum_test, nrow(cmp), nrow(cum %>% filter(especificacao != "baseline")) + nrow(irf %>% filter(especificacao != "baseline")),
  n_irf_sig$k, n_irf_sig$n, num(100 * n_irf_sig$k / n_irf_sig$n, 1), n_el_sig$k, n_el_sig$n, n_el_sig$pos))
for (l in leitura) log_part(ETAPA, sub("^- ", "- Resultado: ", l))
wk <- cum %>% filter(especificacao == "baseline", medida %in% c("elasticidade", "multiplicador"))
f1c <- c(cmp$f1_a, cmp$f1_b)
fracos <- cmp %>% filter(pmin(f1_a, f1_b) < 10) %>% mutate(txt = sprintf("%s, %s, h = %d (%s)", par, resposta, h, num(pmin(f1_a, f1_b), 1)))
log_part(ETAPA, sprintf("- Forca do instrumento (F de Newey-West do primeiro estagio): nas %d medidas acumuladas do baseline em diferenca, minimo %s (%d abaixo de 10). Nas regressoes conjuntas das comparacoes, minimo %s e %d de %d F abaixo de 10: %s. Com F abaixo de 10 o IC pela normal subestima a incerteza.",
  nrow(wk), num(min(wk$f_primeiro_estagio), 1), sum(wk$f_primeiro_estagio < 10), num(min(f1c), 1), sum(f1c < 10), length(f1c),
  paste(fracos$txt, collapse = "; ")))
ecv <- function(s) el(s, "fbcf_cnt_vol", 12)$estimativa
m12 <- function(s) el(s, "fbcf_real_rs_bi", 12, "multiplicador")$estimativa
log_part(ETAPA, sprintf("- Escala dos multiplicadores: M_h e aproximadamente a elasticidade da FBCF vezes a razao media FBCF / G, que vai de %s (inf_diss) a %s (uniao_soc_dir). Em h = 12: uniao_soc_dir, elasticidade de fbcf_cnt_vol %s x FBCF / G %s = %s, contra M_12 estimado de %s; uniao_econ_dir, %s x %s = %s, contra %s; uniao_transf_soc_g1, %s x %s = %s, contra %s; inf_diss, %s x %s = %s, contra %s. Nas rubricas pequenas da Uniao, elasticidades de 0,1 a 0,2 viram dezenas de reais de FBCF por real de G: o numero mede o comovimento da rubrica com a FBCF agregada, e a leitura em R$ por R$ exige cautela. A diferenca social direta x transferencia combina elasticidade maior e razao FBCF / G maior na direta.",
  num(razao_yg[["inf_diss"]], 0), num(razao_yg[["uniao_soc_dir"]], 0),
  num(ecv("uniao_soc_dir")), num(razao_yg[["uniao_soc_dir"]], 0), num(ecv("uniao_soc_dir") * razao_yg[["uniao_soc_dir"]], 1), num(m12("uniao_soc_dir"), 1),
  num(ecv("uniao_econ_dir")), num(razao_yg[["uniao_econ_dir"]], 0), num(ecv("uniao_econ_dir") * razao_yg[["uniao_econ_dir"]], 1), num(m12("uniao_econ_dir"), 1),
  num(ecv("uniao_transf_soc_g1")), num(razao_yg[["uniao_transf_soc_g1"]], 0), num(ecv("uniao_transf_soc_g1") * razao_yg[["uniao_transf_soc_g1"]], 1), num(m12("uniao_transf_soc_g1"), 1),
  num(ecv("inf_diss")), num(razao_yg[["inf_diss"]], 0), num(ecv("inf_diss") * razao_yg[["inf_diss"]], 1), num(m12("inf_diss"), 1)))
log_part(ETAPA, "- Em h = 12 a robustez sem_2020_2021 coincide com ate_2019T4 por construcao: toda observacao com t de 2017T1 em diante usa algum trimestre de 2020-2021 (t + 12 ou as defasagens), e o que sobra e t ate 2016T4, a mesma amostra. Em h menores as duas diferem (A5_lp_irf.csv).")
zpe <- cmp %>% filter(medida == "multiplicador", choque_a == "estatais_sempetro", resposta == "fbcf_real_rs_bi")
zsd <- cmp %>% filter(medida == "elasticidade", choque_a == "uniao_soc_dir", choque_b == "uniao_transf_soc_g1", resposta == "fbcf_cnt_vol")
zes <- cmp %>% filter(medida == "elasticidade", choque_a == "uniao_econ_dir", choque_b == "uniao_soc_dir", resposta == "fbcf_cnt_vol")
zpe_e <- cmp %>% filter(medida == "elasticidade", choque_a == "estatais_sempetro", resposta == "fbcf_cnt_vol")
sig_txt <- function(p) ifelse(p < 0.05, "a 5%", ifelse(p < 0.10, "so a 10%", "sem significancia a 10%"))
# As frases fixas do registro abaixo so valem se os numeros as sustentam
stopifnot(all(zes$p_wald_pa > 0.10), all(zpe$p_wald_pa > 0.05), nrow(zpe_e) == 2, all(zpe$gl < 20))
log_part(ETAPA, sprintf("- Correcoes da revisao adversarial (2026-09-28). (1) Leitura em R$ so nos agregados (inf_diss, estatais_total, uniao_gnd4_dir); nas rubricas, M_h e elasticidades da regressao conjunta. Elasticidade conjunta da FBCF (fbcf_cnt_vol), social direta x transferencia: p de Wald %s em h = 4, 8 e 12 (amostra pequena: %s); com a correcao de amostra pequena a diferenca fica %s em h = 4, %s em h = 8 e %s em h = 12. Economica x social (direta): %s (amostra pequena: %s), sem diferenca. (2) Estatais sem petroleo x petroleo (2016-2025, n = %s, gl = %s): no M_h em R$, p de Wald %s pela qui-quadrado sem ajuste e %s com Newey-West vezes n/(n - k) e F(1, n - k), em h = 4 e 8, acima de 5%% com a correcao; na elasticidade conjunta da FBCF, %s sem ajuste e %s com a correcao. Com 29 a 33 observacoes e 14 regressores o resultado e sugestivo, com a marca baixo_poder, e o M_h em R$ de estatais_sempetro (FBCF / G = %s) nao se le em R$. (3) Colunas com ajuste de graus de liberdade (ep_aj, ic90_*_aj, p_valor_aj, gl) em A5_lp_irf.csv e A5_lp_cumulativo.csv; nota no A5_lp.md. (4) estatais_total entrou na robustez, com as dummies d_* da A4 em dummies_A4. (5) Subamostras com o corte da A4: ate 2014T4 e de 2015T1 (por observacoes efetivas). (6) A figura A5_lp_mult_comparacoes passou a mostrar os M_h da regressao conjunta de cada par (antes, estimativas separadas), e a tabela 4 do A5_lp.md avisa que os M_h separados das rubricas nao se leem em R$.",
  paste(pv(zsd$p_wald), collapse = ", "), paste(pv(zsd$p_wald_pa), collapse = ", "),
  sig_txt(zsd$p_wald_pa[zsd$h == 4]), sig_txt(zsd$p_wald_pa[zsd$h == 8]), sig_txt(zsd$p_wald_pa[zsd$h == 12]),
  paste(pv(zes$p_wald), collapse = ", "), paste(pv(zes$p_wald_pa), collapse = ", "),
  paste(zpe$n, collapse = " e "), paste(zpe$gl, collapse = " e "), paste(pv(zpe$p_wald), collapse = " e "),
  paste(pv(zpe$p_wald_pa), collapse = " e "), paste(pv(zpe_e$p_wald), collapse = " e "), paste(pv(zpe_e$p_wald_pa), collapse = " e "),
  num(razao_yg[["estatais_sempetro"]], 0)))
log_part(ETAPA, "- Saidas: data/processed/A5_lp_irf.csv, A5_lp_cumulativo.csv, A5_lp_comparacoes.csv; results/A5_lp.md; results/figuras/A5_lp_irf_comparacoes e A5_lp_mult_comparacoes (png e pdf).")
log_part(ETAPA, sprintf("- Tempo: estimacao %s s (baseline %s s); total %s s.",
  num(as.numeric(difftime(t_fim_est, t_ini, units = "secs")), 0), num(as.numeric(difftime(t_base, t_ini, units = "secs")), 0),
  num(as.numeric(difftime(Sys.time(), t_ini, units = "secs")), 0)))

save_session_info("A5_lp")
cat("A5_lp concluido.\n")
