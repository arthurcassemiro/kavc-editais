# Verificacao adversarial independente das etapas A4 e A5 (revisor unico, modo enxuto).
# Uso: cd crowding_in_code && Rscript results/verificacao/A5_verificacao.R
# Nao edita scripts nem dados das etapas; so le data/processed e data/original e grava em results/verificacao/.
# Codigo proprio: data.frame com dplyr::lag/lead, lm + sandwich::NeweyWest, MQ2E em dois passos com residuos
# corrigidos (bread/estfun do lm), VAR por MQO equacao a equacao com IRF por recursao propria, ca.jo e
# bootstrap selvagem proprio sob r = 0.

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(sandwich)
  library(urca)
})
set.seed(42)
OUT <- "results/verificacao"
dir.create(OUT, showWarnings = FALSE)
rd <- function(f) readr::read_csv(file.path(PATHS$processed, f), show_col_types = FALSE)
Z90 <- qnorm(0.95)

a2 <- rd("A2_series_trimestrais.csv")
ch <- rd("A3_choques_wide.csv")
nv <- rd("A3_niveis_wide.csv")
dq <- rd("A4_dummies_quebra.csv")
irf <- rd("A5_lp_irf.csv")
cum <- rd("A5_lp_cumulativo.csv")
cmp <- rd("A5_lp_comparacoes.csv")
vres <- rd("A5_var_resultados.csv")
joh <- rd("A5_johansen.csv")

res <- list()
add <- function(item, descricao, meu, deles, tol = 1e-6) {
  ok <- if (is.character(meu) || is.character(deles)) identical(as.character(meu), as.character(deles)) else abs(meu - deles) <= tol
  res[[length(res) + 1]] <<- tibble(item = item, descricao = descricao, meu = as.character(meu),
                                    deles = as.character(deles), confere = ok)
}

# ------------------------------------------------------------------------------------------------
# Base de dados na janela 2003T1-2025T4 (nada de 2002 entra: as defasagens so existem dentro da janela)
# ------------------------------------------------------------------------------------------------
Q <- q_seq("2003Q1", "2025Q4")
d0 <- tibble(q = Q, tt = seq_along(Q)) %>%
  left_join(a2 %>% transmute(q = trimestre, y = fbcf_me_l10, Y = fbcf_real_rs_bi, PIB = pib_real_rs_bi,
                             pib_acel, selic = selic_fim), by = "q") %>%
  left_join(ch %>% transmute(q = trimestre, x = inf_diss), by = "q") %>%
  left_join(dq %>% transmute(q = trimestre, p2 = pulso_2020T2, p3 = pulso_2020T3), by = "q")
# selic: a diferenca e calculada na serie inteira (2002 disponivel), como no script; so importa em 2003T1, que nao entra
sel_full <- a2 %>% transmute(q = trimestre, dsel = selic_fim - dplyr::lag(selic_fim))
d0 <- d0 %>% left_join(sel_full, by = "q")

mk_lp <- function(d, h, p = 3) {
  d %>% mutate(dx = x - lag(x), dy = y - lag(y),
               lhs = lead(y, h) - lag(y, 1),
               lhs_x = lead(x, h) - lag(x, 1),
               cy = Reduce(`+`, lapply(0:h, function(j) lead(y, j))) - (h + 1) * lag(y, 1),
               cx = Reduce(`+`, lapply(0:h, function(j) lead(x, j))) - (h + 1) * lag(x, 1),
               dx1 = lag(dx, 1), dx2 = lag(dx, 2), dx3 = lag(dx, 3),
               dy1 = lag(dy, 1), dy2 = lag(dy, 2), dy3 = lag(dy, 3))
}
FML <- lhs ~ dx + dx1 + dx2 + dx3 + dy1 + dy2 + dy3 + pib_acel + dsel + p2 + p3 + tt

# MQ2E exatamente identificado com HAC: segundo estagio por lm em Xhat, residuos trocados por y - X b
iv_nw <- function(dd, y, endog, inst, ctrl, lag) {
  dd <- dd[complete.cases(dd[, c(y, endog, inst, ctrl)]), ]
  fs <- lapply(endog, function(e) lm(reformulate(c(inst, ctrl), e), data = dd))
  dh <- dd
  for (k in seq_along(endog)) dh[[paste0(endog[k], "_hat")]] <- fitted(fs[[k]])
  f2 <- lm(reformulate(c(paste0(endog, "_hat"), ctrl), y), data = dh)
  b <- coef(f2)
  Xo <- model.matrix(reformulate(c(endog, ctrl), y), data = dd)
  f2$residuals <- setNames(drop(dd[[y]] - Xo %*% b), rownames(model.matrix(f2)))
  V <- sandwich::NeweyWest(f2, lag = lag, prewhite = FALSE, adjust = FALSE)
  list(b = b, V = V, n = nrow(dd), q0 = dd$q[1], q1 = dd$q[nrow(dd)], dd = dd)
}

# ------------------------------------------------------------------------------------------------
# (a) Alinhamento temporal: n, primeiro e ultimo t para h = 0..12 (inf_diss -> fbcf_me, baseline)
# ------------------------------------------------------------------------------------------------
tq <- function(k) gsub("Q", "T", k)
for (h in 0:12) {
  dd <- mk_lp(d0, h)
  cc <- dd[complete.cases(dd[, all.vars(FML)]), ]
  r <- irf %>% filter(choque == "inf_diss", resposta == "fbcf_me", variavel == "resposta", especificacao == "baseline",
                      modelo == "diferenca", h == !!h)
  add("a", sprintf("h = %d: n", h), nrow(cc), r$n, 0)
  add("a", sprintf("h = %d: primeiro t", h), tq(cc$q[1]), r$t_ini)
  add("a", sprintf("h = %d: ultimo t (= 2025T4 - h)", h), tq(cc$q[nrow(cc)]), r$t_fim)
  # a resposta do ultimo t usa exatamente y(2025T4) e a primeira usa y(2003T4) como y(t-1)
  add("a", sprintf("h = %d: ultimo t + h = 2025T4", h), tq(Q[match(cc$q[nrow(cc)], Q) + h]), "2025T4")
}

# ------------------------------------------------------------------------------------------------
# (b) beta_h e EP de Newey-West (lag h + 1) de inf_diss -> fbcf_me, h = 4 e 8, lm + sandwich
# ------------------------------------------------------------------------------------------------
tab_b <- list()
for (h in c(4, 8)) {
  dd <- mk_lp(d0, h)
  f <- lm(FML, data = dd)
  v0 <- sandwich::NeweyWest(f, lag = h + 1, prewhite = FALSE, adjust = FALSE)
  v1 <- sandwich::NeweyWest(f, lag = h + 1, prewhite = FALSE, adjust = TRUE)
  v2 <- tryCatch(sandwich::NeweyWest(f, lag = h + 1), error = function(e) matrix(NA_real_, 1, 1, dimnames = list("dx", "dx")))  # prewhite = TRUE falha com os pulsos
  f_sem <- lm(update(FML, . ~ . - p2 - p3), data = dd)
  r <- irf %>% filter(choque == "inf_diss", resposta == "fbcf_me", variavel == "resposta", especificacao == "baseline",
                      modelo == "diferenca", h == !!h)
  add("b", sprintf("h = %d: beta_h", h), round(coef(f)[["dx"]], 10), round(r$beta, 10), 1e-9)
  add("b", sprintf("h = %d: EP NW (lag %d, sem prewhite, sem ajuste)", h, h + 1), round(sqrt(v0["dx", "dx"]), 10), round(r$ep, 10), 1e-9)
  add("b", sprintf("h = %d: IC 90%% inferior", h), round(coef(f)[["dx"]] - Z90 * sqrt(v0["dx", "dx"]), 10), round(r$ic90_inf, 10), 1e-9)
  tab_b[[length(tab_b) + 1]] <- tibble(h = h, beta = coef(f)[["dx"]], ep_nw = sqrt(v0["dx", "dx"]),
                                       ep_nw_ajuste_gl = sqrt(v1["dx", "dx"]), ep_nw_prewhite = sqrt(v2["dx", "dx"]),
                                       beta_sem_pulsos = coef(f_sem)[["dx"]], n = nobs(f), beta_csv = r$beta, ep_csv = r$ep)
  # Elasticidade acumulada (MQ2E, instrumento dx)
  ctrl <- c("dx1", "dx2", "dx3", "dy1", "dy2", "dy3", "pib_acel", "dsel", "p2", "p3", "tt")
  e <- iv_nw(dd, "cy", "cx", "dx", ctrl, h + 1)
  rc <- cum %>% filter(medida == "elasticidade", choque == "inf_diss", resposta == "fbcf_me", especificacao == "baseline", h == !!h)
  add("b", sprintf("h = %d: elasticidade acumulada (MQ2E)", h), round(e$b[["cx_hat"]], 10), round(rc$estimativa, 10), 1e-9)
  add("b", sprintf("h = %d: EP NW da elasticidade", h), round(sqrt(e$V["cx_hat", "cx_hat"]), 10), round(rc$ep, 10), 1e-9)
}
tab_b <- bind_rows(tab_b)
write_csv_safe(tab_b, file.path(OUT, "A5_verif_b_lp_inf_fbcf.csv"))

# ------------------------------------------------------------------------------------------------
# (c) Multiplicador acumulado em R$ em h = 8 (MQ2E): uniao_econ_dir, uniao_soc_dir e comparacao conjunta
# ------------------------------------------------------------------------------------------------
dm0 <- d0 %>% select(q, tt, Y, PIB, pib_acel, dsel, p2, p3) %>%
  left_join(nv %>% transmute(q = trimestre, Ga = uniao_econ_dir, Gb = uniao_soc_dir,
                             Gc = uniao_transf_soc_g1), by = "q")
mk_mult <- function(d, h, gs) {
  d <- d %>% mutate(Pl = lag(PIB), gY = (Y - lag(Y)) / Pl, cY = (Reduce(`+`, lapply(0:h, function(j) lead(Y, j))) - (h + 1) * lag(Y)) / Pl)
  for (g in gs) {
    G <- d[[g]]
    d[[paste0("g_", g)]] <- (G - dplyr::lag(G)) / d$Pl
    d[[paste0("c_", g)]] <- (Reduce(`+`, lapply(0:h, function(j) dplyr::lead(G, j))) - (h + 1) * dplyr::lag(G)) / d$Pl
    for (l in 1:3) d[[paste0("g_", g, "_l", l)]] <- dplyr::lag(d[[paste0("g_", g)]], l)
  }
  for (l in 1:3) d[[paste0("gY_l", l)]] <- dplyr::lag(d$gY, l)
  d
}
tab_c <- list()
h <- 8
for (g in c("Ga", "Gb")) {
  dd <- mk_mult(dm0, h, g)
  ctrl <- c(paste0("g_", g, "_l", 1:3), paste0("gY_l", 1:3), "pib_acel", "dsel", "p2", "p3", "tt")
  e <- iv_nw(dd, "cY", paste0("c_", g), paste0("g_", g), ctrl, h + 1)
  nome <- c(Ga = "uniao_econ_dir", Gb = "uniao_soc_dir")[[g]]
  rc <- cum %>% filter(medida == "multiplicador", choque == nome, resposta == "fbcf_real_rs_bi", especificacao == "baseline", h == !!h)
  bb <- e$b[[paste0("c_", g, "_hat")]]; ee <- sqrt(e$V[paste0("c_", g, "_hat"), paste0("c_", g, "_hat")])
  add("c", sprintf("M_8 %s (separado)", nome), round(bb, 8), round(rc$estimativa, 8), 1e-7)
  add("c", sprintf("EP de M_8 %s", nome), round(ee, 8), round(rc$ep, 8), 1e-7)
  add("c", sprintf("n de M_8 %s", nome), e$n, rc$n, 0)
  tab_c[[length(tab_c) + 1]] <- tibble(medida = paste("M_8", nome), estimativa = bb, ep = ee, n = e$n, csv = rc$estimativa, csv_ep = rc$ep)
}
# Conjunta: dois endogenos, dois instrumentos, defasagens dos dois dG/PIB e de dY/PIB
dd <- mk_mult(dm0, h, c("Ga", "Gb"))
ctrl <- c(paste0("g_Ga_l", 1:3), paste0("g_Gb_l", 1:3), paste0("gY_l", 1:3), "pib_acel", "dsel", "p2", "p3", "tt")
e <- iv_nw(dd, "cY", c("c_Ga", "c_Gb"), c("g_Ga", "g_Gb"), ctrl, h + 1)
ba <- e$b[["c_Ga_hat"]]; bb <- e$b[["c_Gb_hat"]]
vd <- e$V["c_Ga_hat", "c_Ga_hat"] + e$V["c_Gb_hat", "c_Gb_hat"] - 2 * e$V["c_Ga_hat", "c_Gb_hat"]
pw <- pchisq((ba - bb)^2 / vd, 1, lower.tail = FALSE)
rp <- cmp %>% filter(choque_a == "uniao_econ_dir", choque_b == "uniao_soc_dir", resposta == "fbcf_real_rs_bi", h == 8)
add("c", "Conjunta h = 8: M_a (econ direta)", round(ba, 8), round(rp$mult_a, 8), 1e-7)
add("c", "Conjunta h = 8: M_b (social direta)", round(bb, 8), round(rp$mult_b, 8), 1e-7)
add("c", "Conjunta h = 8: p de Wald (M_a = M_b)", round(pw, 8), round(rp$p_wald, 8), 1e-7)
tab_c[[length(tab_c) + 1]] <- tibble(medida = c("conjunta M_a", "conjunta M_b", "p Wald"), estimativa = c(ba, bb, pw),
                                     ep = c(sqrt(e$V["c_Ga_hat", "c_Ga_hat"]), sqrt(e$V["c_Gb_hat", "c_Gb_hat"]), NA),
                                     n = e$n, csv = c(rp$mult_a, rp$mult_b, rp$p_wald), csv_ep = c(rp$ep_a, rp$ep_b, NA))

# Leitura adversarial: a comparacao social direta x transferencia em R$ (p < 0,001) sobrevive em elasticidade?
# MQ2E conjunto em log10: soma de y(t+j) - y(t-1) (FBCF das Contas Nacionais, volume) nas duas somas dos choques.
ce <- d0 %>% select(q, tt, pib_acel, dsel, p2, p3) %>%
  left_join(a2 %>% transmute(q = trimestre, y = fbcf_cnt_vol_l10), by = "q") %>%
  left_join(ch %>% transmute(q = trimestre, xa = uniao_soc_dir, xb = uniao_transf_soc_g1, xe = uniao_econ_dir), by = "q")
el_pair <- function(d, h, a, b) {
  d <- d %>% mutate(dy = y - lag(y), cy = Reduce(`+`, lapply(0:h, function(j) lead(y, j))) - (h + 1) * lag(y))
  for (v in c(a, b)) {
    x <- d[[v]]
    d[[paste0("d", v)]] <- x - dplyr::lag(x)
    d[[paste0("c", v)]] <- Reduce(`+`, lapply(0:h, function(j) dplyr::lead(x, j))) - (h + 1) * dplyr::lag(x)
    for (l in 1:3) d[[paste0("d", v, "_l", l)]] <- dplyr::lag(d[[paste0("d", v)]], l)
  }
  for (l in 1:3) d[[paste0("dy_l", l)]] <- dplyr::lag(d$dy, l)
  ctrl <- c(paste0("d", a, "_l", 1:3), paste0("d", b, "_l", 1:3), paste0("dy_l", 1:3), "pib_acel", "dsel", "p2", "p3", "tt")
  e <- iv_nw(d, "cy", c(paste0("c", a), paste0("c", b)), c(paste0("d", a), paste0("d", b)), ctrl, h + 1)
  na <- paste0("c", a, "_hat"); nb <- paste0("c", b, "_hat")
  vd <- e$V[na, na] + e$V[nb, nb] - 2 * e$V[na, nb]
  tibble(par = paste(a, "x", b), h = h, el_a = e$b[[na]], ep_a = sqrt(e$V[na, na]), el_b = e$b[[nb]], ep_b = sqrt(e$V[nb, nb]),
         p_wald = pchisq((e$b[[na]] - e$b[[nb]])^2 / vd, 1, lower.tail = FALSE), n = e$n)
}
tab_el_pair <- bind_rows(lapply(c(4, 8, 12), function(h) bind_rows(
  el_pair(ce, h, "xa", "xb") %>% mutate(par = "uniao_soc_dir x uniao_transf_soc_g1 (fbcf_cnt_vol)"),
  el_pair(ce, h, "xe", "xa") %>% mutate(par = "uniao_econ_dir x uniao_soc_dir (fbcf_cnt_vol)"))))
write_csv_safe(bind_rows(tab_c), file.path(OUT, "A5_verif_c_multiplicadores.csv"))
write_csv_safe(tab_el_pair, file.path(OUT, "A5_verif_c_elasticidades_conjuntas.csv"))

# ------------------------------------------------------------------------------------------------
# (d) Baseline corrigido (INF real, 2003-2019): VAR(3) em diferenca por MQO proprio, elasticidade em h = 40;
#     Johansen corrigido (K = 3, trend, DUM) e bootstrap selvagem proprio sob r = 0
# ------------------------------------------------------------------------------------------------
orig_exo <- read.table(file.path(PATHS$original, "0124_inexo.txt"), header = TRUE)
KO <- q_seq("2002Q1", "2019Q4")
dum <- setNames(orig_exo$DUM, KO)
var_el <- function(inf, pvd, exo, p = 3, H = 40) {
  Y <- cbind(INF = inf, PVD = pvd)
  dY <- diff(Y); dX <- diff(exo)
  T0 <- nrow(dY)
  rows <- (p + 1):T0
  Xr <- cbind(1, rows - p)  # constante e tendencia (a origem da tendencia nao muda as inclinacoes)
  for (l in 1:p) Xr <- cbind(Xr, dY[rows - l, , drop = FALSE])
  Xr <- cbind(Xr, dX[rows, , drop = FALSE])
  B <- solve(crossprod(Xr), crossprod(Xr, dY[rows, ]))
  U <- dY[rows, ] - Xr %*% B
  S <- crossprod(U) / (nrow(U) - ncol(Xr))  # mesma escala do vars (a razao nao depende dela)
  A <- lapply(1:p, function(l) t(B[2 + (l - 1) * 2 + 1:2, ]))
  P <- t(chol(S))
  R <- matrix(0, 2, H + 1); R[, 1] <- P[, 1]
  for (i in 1:H) for (j in 1:min(i, p)) R[, i + 1] <- R[, i + 1] + A[[j]] %*% R[, i - j + 1]
  cs <- t(apply(R, 1, cumsum))
  list(el = cs[2, H + 1] / cs[1, H + 1], imp = R[2, 1], c_pvd = cs[2, H + 1], c_inf = cs[1, H + 1], n = nrow(U))
}
K19 <- q_seq("2003Q1", "2019Q4")
g <- function(df, col, keys) df[[col]][match(keys, df$trimestre)]
inf19 <- g(ch, "inf_diss", K19); pvd19 <- g(a2, "fbcf_me_l10", K19)
exo19 <- cbind(PIB = g(a2, "pib_cresc", K19), SEL = g(a2, "selic_fim", K19) / 100, DUM = unname(dum[K19]))
v_c <- var_el(inf19, pvd19, exo19)
rv <- vres %>% filter(id == "corr_c")
add("d", "Baseline corrigido (c) 2003-2019: n", v_c$n, rv$n, 0)
add("d", "Baseline corrigido (c): impacto", round(v_c$imp, 10), round(rv$impacto, 10), 1e-8)
add("d", "Baseline corrigido (c): elasticidade h = 40", round(v_c$el, 10), round(rv$elasticidade, 10), 1e-8)
# Estendida 2003-2025: com e sem imp2017 (a A4 diz que a imputacao de 2017 nao entra)
K25 <- q_seq("2003Q1", "2025Q4")
inf25 <- g(ch, "inf_diss", K25); pvd25 <- g(a2, "fbcf_me_l10", K25)
cum_pulse <- function(qq) cumsum(as.numeric(K25 == qq))  # nivel cuja diferenca e o pulso
exo25 <- cbind(PIB = g(a2, "pib_cresc", K25), SEL = g(a2, "selic_fim", K25) / 100, P2 = cum_pulse("2020Q2"), P3 = cum_pulse("2020Q3"))
imp_lvl <- cumsum(c(0, g(ch, "imp2017", K25)[-1]))  # nivel cuja diferenca e imp2017 (1 em 2017T1-T4)
v_e_imp <- var_el(inf25, pvd25, cbind(exo25, IMP = imp_lvl))
v_e_sem <- var_el(inf25, pvd25, exo25)
v_e_nada <- var_el(inf25, pvd25, exo25[, 1:2])
re <- vres %>% filter(id == "ext")
add("d", "Estendida com pulsos e imp2017: elasticidade h = 40 (como no CSV)", round(v_e_imp$el, 8), round(re$elasticidade, 8), 1e-7)
tab_d <- tibble(especificacao = c("corrigido (c) 2003-2019", "estendida, pulsos + imp2017 (A5)", "estendida, so pulsos (regra da A4)",
                                  "estendida, sem dummies"),
                elasticidade = c(v_c$el, v_e_imp$el, v_e_sem$el, v_e_nada$el), impacto = c(v_c$imp, v_e_imp$imp, v_e_sem$imp, v_e_nada$imp),
                n = c(v_c$n, v_e_imp$n, v_e_sem$n, v_e_nada$n))

# Johansen corrigido 2003-2019: K = 3, ecdet trend, dumvar = DUM em nivel
X19 <- cbind(INF = inf19, PVD = pvd19)
D19 <- matrix(unname(dum[K19]), ncol = 1, dimnames = list(NULL, "DUM"))
cj <- urca::ca.jo(X19, type = "trace", ecdet = "trend", K = 3, spec = "transitory", dumvar = D19)
tr0 <- cj@teststat[2]; tr1 <- cj@teststat[1]   # ordem do urca: r <= 1, r = 0
Tn <- nrow(X19) - 3; fra <- (Tn - 2 * 3) / Tn
jr <- joh %>% filter(amostra == "2003-2019", ecdet == "trend")
add("d", "Johansen 2003-2019 trend: traco r = 0", round(tr0, 8), round(jr$traco[jr$hipotese == "r = 0"], 8), 1e-6)
add("d", "Johansen 2003-2019 trend: traco r <= 1", round(tr1, 8), round(jr$traco[jr$hipotese == "r <= 1"], 8), 1e-6)
add("d", "Johansen 2003-2019 trend: traco Reinsel-Ahn r = 0", round(tr0 * fra, 8), round(jr$traco_ra[jr$hipotese == "r = 0"], 8), 1e-6)
# Bootstrap selvagem proprio sob r = 0: dX(t) = c + G1 dX(t-1) + G2 dX(t-2) + phi DUM(t) + e, e* = e w, w Rademacher
dX <- diff(X19); nd <- nrow(dX)
rw <- 3:nd
Rm <- cbind(1, dX[rw - 1, ], dX[rw - 2, ], D19[rw + 1, ])
Bh <- solve(crossprod(Rm), crossprod(Rm, dX[rw, ])); Eh <- dX[rw, ] - Rm %*% Bh
boot_tr <- function(B = 999) {
  set.seed(42)
  vapply(if (B == 0) 0 else seq_len(B), function(b) {
    w <- if (b == 0) rep(1, nrow(Eh)) else sample(c(-1, 1), nrow(Eh), replace = TRUE)
    dXs <- dX; for (i in seq_along(rw)) {
      t <- rw[i]
      dXs[t, ] <- c(1, dXs[t - 1, ], dXs[t - 2, ], D19[t + 1, ]) %*% Bh + Eh[i, ] * w[i]
    }
    Xs <- rbind(X19[1, ], sweep(apply(dXs, 2, cumsum), 2, X19[1, ], "+")); colnames(Xs) <- colnames(X19)
    if (b == 0) return(max(abs(Xs - X19)))
    urca::ca.jo(Xs, type = "trace", ecdet = "trend", K = 3, spec = "transitory", dumvar = D19)@teststat[2]
  }, 0)
}
stopifnot(boot_tr(0) < 1e-10)  # com pesos iguais a 1 a recursao reproduz os dados
st <- boot_tr()
p_boot_meu <- mean(st >= tr0)
tab_j <- tibble(amostra = "2003-2019", ecdet = "trend", traco_r0 = tr0, cv5 = cj@cval[2, 2], traco_ra = tr0 * fra,
                rejeita_assint = tr0 > cj@cval[2, 2], rejeita_ra = tr0 * fra > cj@cval[2, 2], p_boot_meu = p_boot_meu,
                p_boot_csv = jr$p_boot[jr$hipotese == "r = 0"])
write_csv_safe(tab_d, file.path(OUT, "A5_verif_d_var.csv"))
write_csv_safe(tab_j, file.path(OUT, "A5_verif_d_johansen.csv"))

# ------------------------------------------------------------------------------------------------
# (e) Tabelas .md dizem o mesmo que os CSVs (celulas formatadas a partir do CSV procuradas no .md)
# ------------------------------------------------------------------------------------------------
fmt <- function(x, d) formatC(round(x, d), format = "f", digits = d, decimal.mark = ",")
md_lp <- readLines("results/A5_lp.md"); md_var <- readLines("results/A5_var.md")
achou <- function(txt, md) any(grepl(txt, md, fixed = TRUE))
for (s in c("inf_diss", "uniao_econ_dir", "uniao_soc_dir", "uniao_transf_soc_g1", "estatais_total")) {
  z <- cum %>% filter(medida == "elasticidade", choque == s, resposta == "fbcf_me", especificacao == "baseline", h == 12)
  cel <- sprintf("%s [%s; %s]", fmt(z$estimativa, 3), fmt(z$ic90_inf, 3), fmt(z$ic90_sup, 3))
  add("e", paste("A5_lp.md: elasticidade h = 12 de", s), achou(cel, md_lp), TRUE)
  z <- cum %>% filter(medida == "multiplicador", choque == s, resposta == "fbcf_real_rs_bi", especificacao == "baseline", h == 12)
  cel <- sprintf("%s [%s; %s]", fmt(z$estimativa, 2), fmt(z$ic90_inf, 2), fmt(z$ic90_sup, 2))
  add("e", paste("A5_lp.md: M_12 FBCF de", s), achou(cel, md_lp), TRUE)
}
for (i in seq_len(nrow(cmp))) {
  z <- cmp[i, ]
  cel <- sprintf("| %s | %s | %d | %s [", z$rotulo, z$resposta, z$h, fmt(z$mult_a, 2))
  add("e", sprintf("A5_lp.md: comparacao %s, %s, h = %d", z$par, z$resposta, z$h), achou(cel, md_lp), TRUE)
}
for (i in which(vres$bloco %in% c("baseline", "baseline corrigido", "baseline estendido"))) {
  z <- vres[i, ]
  cel <- sprintf("| %s | %s | [%s; %s] |", fmt(z$resp_acum_40_pub, 4), fmt(z$elasticidade, 2), fmt(z$ic90_inf, 2), fmt(z$ic90_sup, 2))
  add("e", paste("A5_var.md: linha", z$id), achou(cel, md_var), TRUE)
}
for (i in seq_len(nrow(joh))) {
  z <- joh[i, ]
  cel <- sprintf("| %s | %s | %s | %s |", fmt(z$traco, 2), fmt(z$traco_ra, 2), fmt(z$cv5, 2), fmt(z$cv10, 2))
  add("e", sprintf("A5_var.md: Johansen %s %s %s", z$amostra, z$ecdet, z$hipotese), achou(cel, md_var), TRUE)
}
# Tabela de elasticidades da A4 (tex) contra o VAR proprio
tex <- readLines("results/A_quebras.tex")
ext_sem <- var_el(inf25, pvd25, exo25[, 1:2])
add("e", "A_quebras.tex: VAR estendido sem dummies, elasticidade h = 40 = 0,154 (recalculada)",
    achou(sprintf("Estendido: Amostra completa (88 obs.) & %s & %s", gsub(",", "{,}", fmt(ext_sem$el, 3)), gsub(",", "{,}", fmt(ext_sem$el, 3))), tex) ||
      achou(sprintf("& %s & 0{,}0", gsub(",", "{,}", fmt(ext_sem$el, 3))), tex), TRUE)

# ------------------------------------------------------------------------------------------------
# (f) Dummies da A4: baseline das LP com pulsos (conferido em b); robustez dummies_A4 recalculada
# ------------------------------------------------------------------------------------------------
dA <- d0 %>% left_join(dq %>% select(q = trimestre, starts_with("d_"), degrau_2011T1), by = "q")
DI <- c("d_ls2018T2", "d_ao2018T3", "d_ls2019T1", "d_ls2019T3", "d_ao2020T3", "d_ao2021T1", "d_ao2021T2")
dd <- mk_lp(dA, 8)
f <- lm(reformulate(c(attr(terms(FML), "term.labels"), DI), "lhs"), data = dd)
r <- irf %>% filter(choque == "inf_diss", resposta == "fbcf_me", variavel == "resposta", especificacao == "dummies_A4", h == 8)
add("f", "LP inf_diss -> fbcf_me h = 8 com as 7 dummies do X-11 da A4 (dummies_A4)", round(coef(f)[["dx"]], 10), round(r$beta, 10), 1e-9)
dS <- dA %>% select(-x) %>% left_join(ch %>% transmute(q = trimestre, x = uniao_soc_dir), by = "q")
dd <- mk_lp(dS, 8)
f <- lm(update(FML, . ~ . + degrau_2011T1), data = dd)
r <- irf %>% filter(choque == "uniao_soc_dir", resposta == "fbcf_me", variavel == "resposta", especificacao == "dummies_A4", h == 8)
add("f", "LP uniao_soc_dir -> fbcf_me h = 8 com degrau_2011T1 (dummies_A4)", round(coef(f)[["dx"]], 10), round(r$beta, 10), 1e-9)
# VAR estendido: a A4 manda so os pulsos da pandemia; o A5_var inclui imp2017
add("f", "VAR estendido do A5 inclui imp2017 (A4: imputacao de 2017 nao entra)", grepl("imp2017", re$obs), FALSE)

# ------------------------------------------------------------------------------------------------
# (g) Regras: nada em data/original e data/raw depois das execucoes; sem travessao; session_info
# ------------------------------------------------------------------------------------------------
logs <- c(list.files("results/log_parts", full.names = TRUE), "results/A4_quebras.md", "results/A5_lp.md", "results/A5_var.md")
tem_trav <- vapply(logs, function(f) any(grepl("—", readLines(f, warn = FALSE), fixed = TRUE)), TRUE)
add("g", "Arquivos de log e .md com travessao", sum(tem_trav), 0, 0)
for (s in c("A4_quebras", "A5_var", "A5_lp", "A5_estimacao")) {
  add("g", paste("session_info de", s), file.exists(file.path("results/session_info", paste0(s, ".txt"))), TRUE)
}

# ------------------------------------------------------------------------------------------------
# A4, conferencias pontuais: Chow em 2020T2 e supF nas equacoes do VAR estendido; elasticidade recursiva
# ------------------------------------------------------------------------------------------------
suppressPackageStartupMessages(library(strucchange))
Y25 <- cbind(inf = inf25, fbcf = pvd25); dY25 <- diff(Y25); dX25 <- diff(exo25[, 1:2]); kd <- K25[-1]
rr <- 4:nrow(dY25)
eqd <- data.frame(q = kd[rr], tr = seq_along(rr), dY25[rr, ], i1 = dY25[rr - 1, 1], f1 = dY25[rr - 1, 2],
                  i2 = dY25[rr - 2, 1], f2 = dY25[rr - 2, 2], i3 = dY25[rr - 3, 1], f3 = dY25[rr - 3, 2],
                  pib = dX25[rr, 1], sel = dX25[rr, 2])
chow_meu <- function(dep, dq) {
  f <- reformulate(c("i1", "f1", "i2", "f2", "i3", "f3", "tr", "pib", "sel"), dep)
  a <- lm(f, eqd); b1 <- lm(f, eqd[eqd$q < dq, ]); b2 <- lm(f, eqd[eqd$q >= dq, ])
  k <- length(coef(a)); r1 <- sum(resid(b1)^2) + sum(resid(b2)^2)
  Fst <- ((sum(resid(a)^2) - r1) / k) / (r1 / (nrow(eqd) - 2 * k))
  pf(Fst, k, nrow(eqd) - 2 * k, lower.tail = FALSE)
}
sup_meu <- function(dep) {
  f <- reformulate(c("i1", "f1", "i2", "f2", "i3", "f3", "tr", "pib", "sel"), dep)
  fs <- strucchange::Fstats(f, data = eqd, from = 0.15)
  c(stat = unname(strucchange::sctest(fs, type = "supF")$statistic), data = eqd$q[fs$breakpoint + 1])
}
a4log <- readLines("results/log_parts/A4.md")
p_ci <- chow_meu("inf", "2020Q2"); p_cf <- chow_meu("fbcf", "2020Q2")
s_i <- sup_meu("inf"); s_f <- sup_meu("fbcf")
add("A4", "Chow em 2020T2, equacao estendida de inf_diss: p (log diz 0,002)", round(p_ci, 3), 0.002, 5e-4)
add("A4", "Chow em 2020T2, equacao estendida de fbcf_me: p < 0,001", p_cf < 0.001, TRUE)
add("A4", "supF da equacao estendida de inf_diss (log: 31,25, max em 2020T2)", sprintf("%.2f %s", as.numeric(s_i["stat"]), s_i["data"]), "31.25 2020Q2")
add("A4", "supF da equacao estendida de fbcf_me (log: 38,68, max em 2020T2)", sprintf("%.2f %s", as.numeric(s_f["stat"]), s_f["data"]), "38.68 2020Q2")
for (fim in c("2019Q4", "2020Q4", "2021Q4")) {
  kk <- q_seq("2003Q1", fim)
  v <- var_el(g(ch, "inf_diss", kk), g(a2, "fbcf_me_l10", kk), cbind(g(a2, "pib_cresc", kk), g(a2, "selic_fim", kk) / 100))
  alvo <- c("2019Q4" = 0.451, "2020Q4" = 0.287, "2021Q4" = 0.154)[[fim]]
  add("A4", paste("Elasticidade recursiva do VAR estendido com fim em", tq(fim)), round(v$el, 3), alvo, 5e-4)
}

tab <- bind_rows(res)
write_csv_safe(tab, file.path(OUT, "A5_verificacao.csv"))
print(as.data.frame(tab %>% filter(!confere)))
cat("\nConferencias:", sum(tab$confere), "de", nrow(tab), "\n")
print(as.data.frame(tab_b)); print(as.data.frame(bind_rows(tab_c))); print(as.data.frame(tab_el_pair))
print(as.data.frame(tab_d)); print(as.data.frame(tab_j))
# sessionInfo so em results/verificacao (nao sobrescreve results/session_info.txt das etapas)
write_lines_safe(c(sprintf("# A5_verificacao, executado em %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
                   capture.output(sessionInfo())), file.path(OUT, "A5_verificacao_session_info.txt"))
