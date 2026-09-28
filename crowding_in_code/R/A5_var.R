# A5, parte VAR/VEC: baseline replicado, baseline corrigido correcao a correcao, Johansen com correcao de
# Reinsel-Ahn e bootstrap selvagem (Cavaliere, Rahbek e Taylor, 2012), escolha VAR x VEC, VECM com r = 1,
# VAR em nivel, amostra estendida 2003T1-2025T4 e robustez do VAR.
# Uso: cd crowding_in_code && Rscript R/A5_var.R
# Entradas: data/original/0224_tri_estmeq.txt e 0124_inexo.txt; data/processed/A3_choques_wide.csv,
# A3_choques_semao_wide.csv, A2_ipea_trimestral.csv, A2_ibge_trimestral.csv, A2_bcb_trimestral.csv,
# A2_bndes_trimestral.csv, A2_deflator_ipca.csv, A4_dummies_quebra.csv (so na robustez). Nao usa A2_series_trimestrais.csv.

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(vars)
  library(urca)
  library(patchwork)
})

ETAPA <- "A5_var"
log_reset(ETAPA)
set.seed(42)
t_ini <- Sys.time()

H <- 40
# Variaveis de ambiente so para teste rapido; a execucao oficial usa os padroes (2000, 1000, 999)
RUNS_MAIN <- as.integer(Sys.getenv("A5_RUNS_MAIN", "2000"))
RUNS_ROB <- as.integer(Sys.getenv("A5_RUNS_ROB", "1000"))
B_JOH <- as.integer(Sys.getenv("A5_B_JOH", "999"))
K_JOH <- 3

# ------------------------------------------------------------------------------------------------
# Formatacao
# ------------------------------------------------------------------------------------------------
num <- function(x, d = 4) ifelse(is.na(x), "NA", formatC(round(x, d), format = "f", digits = d, decimal.mark = ","))
ic_txt <- function(a, b, d = 2) ifelse(is.na(a), "NA", sprintf("[%s; %s]", num(a, d), num(b, d)))
pv <- function(p) ifelse(is.na(p), "NA", ifelse(p < 0.001, "< 0,001", num(p, 3)))
md_table <- function(df) {
  df <- as.data.frame(df)
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- vapply(seq_len(nrow(df)), function(i) paste0("| ", paste(unlist(df[i, ]), collapse = " | "), " |"), "")
  c(hdr, sep, rows)
}

# ------------------------------------------------------------------------------------------------
# 1. Dados
# ------------------------------------------------------------------------------------------------
arq_end <- file.path(PATHS$original, "0224_tri_estmeq.txt")
arq_exo <- file.path(PATHS$original, "0124_inexo.txt")
end_df <- read.table(arq_end, header = TRUE)
exo_df <- read.table(arq_exo, header = TRUE)
stopifnot(identical(names(end_df), c("INF", "PVD")), identical(names(exo_df), c("PIB", "JUR", "DUM")),
          nrow(end_df) == 72, nrow(exo_df) == 72)
TRIM_O <- q_seq("2002Q1", "2019Q4")

rd <- function(f) readr::read_csv(file.path(PATHS$processed, f), show_col_types = FALSE)
ch <- rd("A3_choques_wide.csv")
chs <- rd("A3_choques_semao_wide.csv")
ipea <- rd("A2_ipea_trimestral.csv")
ibge <- rd("A2_ibge_trimestral.csv") %>% rename(trimestre = periodo)
bcb <- rd("A2_bcb_trimestral.csv") %>% rename(trimestre = periodo)
bnd <- rd("A2_bndes_trimestral.csv")
defl <- rd("A2_deflator_ipca.csv") %>% filter(frequencia == "trimestral") %>%
  transmute(trimestre = periodo, fator = fator_para_2025)
dqa4 <- rd("A4_dummies_quebra.csv")

sv <- function(df, col) setNames(as.numeric(df[[col]]), df$trimestre)
TODOS <- q_seq("2000Q1", "2026Q4")
pulso <- function(q) setNames(as.numeric(TODOS == q), TODOS)

S <- list(
  INF_o = setNames(end_df$INF, TRIM_O), PVD_o = setNames(end_df$PVD, TRIM_O),
  PIB_o = setNames(exo_df$PIB, TRIM_O), JUR_o = setNames(exo_df$JUR, TRIM_O), DUM = setNames(exo_df$DUM, TRIM_O),
  PVD = log10(sv(ipea, "fbcf_me_sa")),
  PIB = sv(ibge, "pib_var_tri_sa_1621"),
  SELIC = sv(bcb, "selic_meta_fim") / 100,
  SELIC_MED = sv(bcb, "selic_meta_media") / 100,
  CAMBIO = log10(sv(bcb, "cambio_real_efetivo")),
  ICBR = log10(sv(bcb, "icbr_usd")),
  BRENT = log10(sv(ipea, "brent_usd_barril")),
  imp2017 = sv(ch, "imp2017"),
  p2020Q2 = pulso("2020Q2"), p2020Q3 = pulso("2020Q3")
)
for (q in q_seq("2016Q4", "2018Q1")) S[[paste0("p", q)]] <- pulso(q)
# Outliers do X-11 de inf_diss diferenciados (A4_dummies_quebra.csv): regressores da equacao em diferenca, entram como estao
DUMS_A4_INF <- c("d_ls2018T2", "d_ao2018T3", "d_ls2019T1", "d_ls2019T3", "d_ao2020T3", "d_ao2021T1", "d_ao2021T2")
stopifnot(all(DUMS_A4_INF %in% names(dqa4)))
for (d in DUMS_A4_INF) S[[d]] <- setNames(as.numeric(dqa4[[d]]), dqa4$trimestre)
VAR_INF <- c("inf_diss", "inf_diss_nominal_2019", "inf_diss_e2017", "inf_diss_e2018", "inf_diss_e2019",
             "inf_diss_e2020", "inf_diss_e2020_r1618", "inf_diss_imprazao", "inf_diss_x11soma")
for (v in VAR_INF) S[[v]] <- sv(ch, v)
S$inf_diss_semao <- sv(chs, "inf_diss")

# Selic do BCB (meta no fim do trimestre, em fracao) contra JUR do arquivo original
dif_jur <- max(abs(S$SELIC[TRIM_O] - S$JUR_o))
stopifnot(dif_jur < 1e-4)
# PIB: safra atual contra o arquivo original
cor_pib <- cor(S$PIB[TRIM_O], S$PIB_o)
dmax_pib <- max(abs(S$PIB[TRIM_O] - S$PIB_o))
cor_pvd <- cor(diff(S$PVD[TRIM_O]), diff(S$PVD_o))

# BNDES: desembolsos exceto administracao publica (R$ milhoes nominais, soma do trimestre, sem ajuste),
# deflacionados pelo fator trimestral do IPCA (R$ de 2025) e com X-11 multiplicativo, depois log10.
bn <- bnd %>% dplyr::select(trimestre, desemb_exc_adm_publica) %>% inner_join(defl, by = "trimestre") %>%
  filter(trimestre %in% q_seq("2000Q1", "2025Q4")) %>% arrange(trimestre) %>%
  mutate(real = desemb_exc_adm_publica * fator)
stopifnot(nrow(bn) == length(q_seq("2000Q1", "2025Q4")), !anyNA(bn$real))
bn_sa <- x11_sa(ts_from_q(bn$real, bn$trimestre), transform.function = "log")
S$BNDES <- setNames(log10(as.numeric(bn_sa)), bn$trimestre)
bn_mod <- attr(bn_sa, "seas_model")
bn_out <- tryCatch(paste(names(coef(bn_mod))[grepl("^(AO|LS|TC)", names(coef(bn_mod)))], collapse = ", "),
                   error = function(e) "")

log_part(ETAPA, "- Entradas: ", arq_end, " e ", arq_exo, " (baseline replicado); data/processed/A3_choques_wide.csv ",
         "(inf_diss real, X-11 por componente, e variantes; imp2017), A3_choques_semao_wide.csv (inf_diss sem o efeito dos AO), ",
         "A2_ipea_trimestral.csv (fbcf_me_sa; brent_usd_barril), A2_ibge_trimestral.csv (pib_var_tri_sa_1621), ",
         "A2_bcb_trimestral.csv (selic_meta_fim, selic_meta_media, cambio_real_efetivo, icbr_usd), A2_bndes_trimestral.csv ",
         "(desemb_exc_adm_publica), A2_deflator_ipca.csv (fator trimestral) e A4_dummies_quebra.csv (outliers do X-11 de inf_diss, so na ",
         "robustez dummies_A4). A2_series_trimestrais.csv nao e usado.")
log_part(ETAPA, "- Unidades: INF e PVD em log10 (PVD atual = log10 do indice fbcf_me_sa do Ipea, com ajuste); PIB = variacao ",
         "trimestral do indice com ajuste (fracao); Selic em fracao (meta do BCB dividida por 100, como o JUR do arquivo). ",
         "Selic meta no fim do trimestre contra JUR do arquivo: diferenca maxima ", format(signif(dif_jur, 2), decimal.mark = ","),
         ". PIB da safra atual contra o PIB do arquivo (2002T1-2019T4): correlacao ", num(cor_pib, 4), ", diferenca maxima ",
         num(dmax_pib, 4), ". PVD atual contra PVD do arquivo: correlacao das diferencas ", num(cor_pvd, 4), ".")
log_part(ETAPA, "- Controles (robustez): cambio real efetivo, IC-Br em US$ e Brent (medias trimestrais das series da A2) em log10; ",
         "BNDES exceto administracao publica: soma trimestral nominal vezes o fator trimestral do IPCA (R$ de 2025), X-11 ",
         "multiplicativo em 2000T1-2025T4 (a serie da A2 nao tem ajuste sazonal) e log10. Outliers do X-13 no BNDES: ",
         ifelse(nzchar(bn_out), bn_out, "nenhum"), ". Todos entram como exogenos em primeira diferenca, no maximo dois por vez. ",
         "A serie inclui estatais (Petrobras, Eletrobras): nao e desembolso privado puro.")

# ------------------------------------------------------------------------------------------------
# 2. Ferramentas de estimacao
# ------------------------------------------------------------------------------------------------
get_win <- function(v, keys, nome) {
  if (is.null(S[[v]])) stop("serie inexistente: ", v)
  x <- unname(S[[v]][keys])
  if (anyNA(x)) stop("NA em ", v, " (", nome, ") na janela ", keys[1], "-", tail(keys, 1))
  x
}

# Especificacao: inf, pvd (nomes em S), exo (lista nome = "d" diferenca ou "n" sem diferenciar), janela, p, ordem
prep <- function(sp) {
  keys <- q_seq(sp$de, sp$ate)
  Y <- cbind(INF = get_win(sp$inf, keys, "INF"), PVD = get_win(sp$pvd, keys, "PVD"))
  Y <- Y[, sp$ordem, drop = FALSE]
  Xd <- NULL; Xl <- NULL
  for (nm in names(sp$exo)) {
    x <- get_win(nm, keys, nm)
    Xd <- cbind(Xd, if (sp$exo[[nm]] == "d") diff(x) else x[-1])
    Xl <- cbind(Xl, x)
  }
  nomes <- paste0(ifelse(unlist(sp$exo) == "d", "d_", ""), names(sp$exo))
  colnames(Xd) <- nomes; colnames(Xl) <- names(sp$exo)
  # Exogenas sem variacao na amostra efetiva (depois das p defasagens) saem
  ef_d <- (sp$p + 1):nrow(Xd); ef_l <- (sp$p + 1):nrow(Xl)
  keep_d <- apply(Xd[ef_d, , drop = FALSE], 2, function(z) any(z != 0))
  keep_l <- apply(Xl[ef_l, , drop = FALSE], 2, function(z) any(z != 0))
  list(keys = keys, Y = Y, Xd = Xd[, keep_d, drop = FALSE], Xl = Xl[, keep_l, drop = FALSE],
       fora = unique(c(colnames(Xd)[!keep_d], colnames(Xl)[!keep_l])))
}

# Respostas ortogonais ao choque em INF a partir das defasagens A (K x Kp) e da covariancia
resp_fast <- function(A, Sigma, K, p, i_inf, h = H) {
  Pm <- t(chol(Sigma))
  R <- matrix(0, K, h + 1)
  R[, 1] <- Pm[, i_inf]
  As <- lapply(seq_len(p), function(i) A[, ((i - 1) * K + 1):(i * K), drop = FALSE])
  for (i in seq_len(h)) {
    acc <- numeric(K)
    for (j in seq_len(min(i, p))) acc <- acc + As[[j]] %*% R[, i - j + 1]
    R[, i + 1] <- acc
  }
  R
}

# Bootstrap de residuos com o desenho de vars:::.boot (recursivo, deterministicos e exogenas fixos,
# p valores iniciais observados, residuos centrados, mesma sequencia de sorteios), com MQO direto.
boot_var <- function(mod, runs, cumulative, seed = 42) {
  K <- mod$K; p <- mod$p; obs <- mod$obs; tot <- mod$totobs; nl <- K * p
  B <- vars::Bcoef(mod); A <- B[, 1:nl, drop = FALSE]
  Zdet <- as.matrix(mod$datamat[, (K * (p + 1) + 1):ncol(mod$datamat), drop = FALSE])
  detp <- Zdet %*% t(B[, -(1:nl), drop = FALSE])
  U <- scale(resid(mod), scale = FALSE)
  y0 <- as.matrix(mod$y)
  i_inf <- which(colnames(y0) == "INF"); i_pvd <- which(colnames(y0) == "PVD")
  P_pvd <- matrix(NA_real_, runs, H + 1); P_inf <- P_pvd
  ys <- matrix(0, tot, K)
  set.seed(seed)
  for (r in seq_len(runs)) {
    idx <- sample(c(1:obs), replace = TRUE)
    E <- U[idx, , drop = FALSE] + detp
    ys[1:p, ] <- y0[1:p, ]
    for (t in seq_len(obs)) {
      lags <- c(t(ys[(t + p - 1):t, , drop = FALSE]))
      ys[t + p, ] <- A %*% lags + E[t, ]
    }
    Xe <- embed(ys, p + 1)
    Yb <- Xe[, 1:K, drop = FALSE]; Xb <- cbind(Xe[, -(1:K), drop = FALSE], Zdet)
    Bb <- t(solve(crossprod(Xb), crossprod(Xb, Yb)))
    res <- Yb - Xb %*% t(Bb)
    Sig <- crossprod(res) / (obs - ncol(Xb))
    rr <- resp_fast(Bb[, 1:nl, drop = FALSE], Sig, K, p, i_inf)
    if (cumulative) rr <- t(apply(rr, 1, cumsum))
    P_pvd[r, ] <- rr[i_pvd, ]; P_inf[r, ] <- rr[i_inf, ]
  }
  list(pvd = P_pvd, inf = P_inf)
}

q90 <- function(x) unname(quantile(x, c(0.05, 0.95), na.rm = TRUE))

# Granger de Toda e Yamamoto (1995) no VAR em nivel: VAR(p + 1), Wald nas p primeiras defasagens
granger_ty <- function(Y, X, p) {
  m <- do.call(vars::VAR, list(y = Y, p = p + 1, type = "both", exogen = X))
  f <- function(eq, causa) {
    l <- m$varresult[[eq]]; b <- coef(l); V <- vcov(l); nm <- paste0(causa, ".l", 1:p)
    Fst <- as.numeric(t(b[nm]) %*% solve(V[nm, nm]) %*% b[nm]) / p
    pf(Fst, p, df.residual(l), lower.tail = FALSE)
  }
  c(pub_priv = f("PVD", "INF"), priv_pub = f("INF", "PVD"))
}

RES <- list()     # linhas do CSV
PATHS_IRF <- list() # trajetorias para figuras
push_row <- function(...) RES[[length(RES) + 1]] <<- tibble(...)

# VAR em diferenca
fit_dif <- function(sp, runs, irf_check = FALSE) {
  pr <- prep(sp)
  dY <- diff(pr$Y)
  mod <- do.call(vars::VAR, list(y = dY, p = sp$p, type = "both", exogen = pr$Xd))
  K <- mod$K; i_inf <- which(colnames(mod$y) == "INF"); i_pvd <- which(colnames(mod$y) == "PVD")
  ps <- vars::Psi(mod, nstep = H)
  rr <- resp_fast(vars::Bcoef(mod)[, 1:(K * sp$p)], crossprod(resid(mod)) / (mod$obs - ncol(mod$datamat[, -(1:K)])),
                  K, sp$p, i_inf)
  stopifnot(max(abs(rr - ps[, i_inf, ])) < 1e-12)
  c_pvd <- sum(ps[i_pvd, i_inf, ]); c_inf <- sum(ps[i_inf, i_inf, ])
  bt <- boot_var(mod, runs, cumulative = TRUE)
  el_b <- bt$pvd[, H + 1] / bt$inf[, H + 1]
  chk <- NA
  if (irf_check) {
    ir <- vars::irf(mod, impulse = "INF", response = c("INF", "PVD"), n.ahead = H, cumulative = TRUE,
                    boot = TRUE, runs = runs, ci = 0.90, seed = 42)
    lo <- ir$Lower$INF; up <- ir$Upper$INF
    band_own <- rbind(apply(bt$pvd, 2, q90), apply(bt$inf, 2, q90))
    band_irf <- rbind(rbind(lo[, "PVD"], up[, "PVD"]), rbind(lo[, "INF"], up[, "INF"]))
    chk <- max(abs(band_own - band_irf))
    stopifnot(chk < 1e-10, max(abs(cumsum(ps[i_pvd, i_inf, ]) - ir$irf$INF[, "PVD"])) < 1e-12)
  }
  g1 <- causality(mod, cause = "INF")$Granger; g2 <- causality(mod, cause = "PVD")$Granger
  bg <- serial.test(mod, lags.bg = 5, type = "BG")$serial$p.value
  list(mod = mod, pr = pr, impacto = ps[i_pvd, i_inf, 1], c_pvd = c_pvd, c_inf = c_inf, el = c_pvd / c_inf,
       ic = q90(el_b), ic_pvd = q90(bt$pvd[, H + 1]), neg = mean(el_b < 0), g_pub_priv = as.numeric(g1$p.value),
       g_priv_pub = as.numeric(g2$p.value), f_pub_priv = as.numeric(g1$statistic), bg = as.numeric(bg),
       raiz = max(roots(mod)), chk = chk, boot = bt, path = cumsum(ps[i_pvd, i_inf, ]),
       path_inf = cumsum(ps[i_inf, i_inf, ]), runs = runs)
}

reg_dif <- function(f, sp, amostra, modelo, espec, bloco, obs_extra = "") {
  fora <- if (length(f$pr$fora)) paste0(" Exogenas sem variacao na amostra efetiva, retiradas: ", paste(f$pr$fora, collapse = ", "), ".") else ""
  exo_txt <- paste(colnames(f$pr$Xd), collapse = ", ")
  push_row(amostra = amostra, modelo = modelo, especificacao = espec, n = f$mod$obs, impacto = f$impacto,
          resp_acum_40_priv = f$c_pvd, resp_acum_40_pub = f$c_inf, elasticidade = f$el, ic90_inf = f$ic[1], ic90_sup = f$ic[2],
          granger_p_pub_priv = f$g_pub_priv, granger_p_priv_pub = f$g_priv_pub,
          obs = paste0("VAR(", sp$p, ") em diferenca, type both; janela dos niveis ", sp$de, "-", sp$ate, "; INF = ", sp$inf,
                       "; PVD = ", sp$pvd, "; ordem ", paste(sp$ordem, collapse = ", "), "; exogenas: ", exo_txt,
                       ". Bootstrap de residuos com ", f$runs, " replicas; replicas com elasticidade negativa: ",
                       num(100 * f$neg, 1), "%. BG (5 defasagens) p = ", pv(f$bg), "; maior raiz ", num(f$raiz, 3), ".",
                       fora, obs_extra),
          id = sp$id, bloco = bloco, ic90_acum_priv_inf = f$ic_pvd[1], ic90_acum_priv_sup = f$ic_pvd[2],
          prop_boot_elast_neg = f$neg, runs = f$runs, elasticidade_beta = NA_real_, elast_beta_ic90_inf = NA_real_,
          elast_beta_ic90_sup = NA_real_)
}

# VAR em nivel (exogenas em nivel)
fit_niv <- function(sp, runs) {
  pr <- prep(sp)
  mod <- do.call(vars::VAR, list(y = pr$Y, p = sp$p, type = "both", exogen = pr$Xl))
  i_inf <- which(colnames(mod$y) == "INF"); i_pvd <- which(colnames(mod$y) == "PVD")
  ps <- vars::Psi(mod, nstep = H)
  bt <- boot_var(mod, runs, cumulative = FALSE)
  el_b <- bt$pvd[, H + 1] / bt$inf[, H + 1]
  soma_b <- rowSums(bt$pvd) / rowSums(bt$inf)
  ty <- granger_ty(pr$Y, pr$Xl, sp$p)
  g1 <- causality(mod, cause = "INF")$Granger$p.value; g2 <- causality(mod, cause = "PVD")$Granger$p.value
  list(mod = mod, pr = pr, impacto = ps[i_pvd, i_inf, 1], n_pvd = ps[i_pvd, i_inf, H + 1], n_inf = ps[i_inf, i_inf, H + 1],
       el = ps[i_pvd, i_inf, H + 1] / ps[i_inf, i_inf, H + 1], ic = q90(el_b), ic_pvd = q90(bt$pvd[, H + 1]),
       soma = sum(ps[i_pvd, i_inf, ]) / sum(ps[i_inf, i_inf, ]), ic_soma = q90(soma_b), neg = mean(el_b < 0),
       ty = ty, g_std = c(as.numeric(g1), as.numeric(g2)), raiz = max(roots(mod)), runs = runs,
       path = ps[i_pvd, i_inf, ])
}
reg_niv <- function(f, sp, amostra, espec, bloco) {
  push_row(amostra = amostra, modelo = "VAR em nivel", especificacao = espec, n = f$mod$obs, impacto = f$impacto,
          resp_acum_40_priv = f$n_pvd, resp_acum_40_pub = f$n_inf, elasticidade = f$el, ic90_inf = f$ic[1], ic90_sup = f$ic[2],
          granger_p_pub_priv = f$ty[["pub_priv"]], granger_p_priv_pub = f$ty[["priv_pub"]],
          obs = paste0("VAR(", sp$p, ") em nivel, type both, exogenas em nivel (", paste(colnames(f$pr$Xl), collapse = ", "),
                       "); janela ", sp$de, "-", sp$ate, "; INF = ", sp$inf, "; PVD = ", sp$pvd, ". Respostas em nivel em h = 40 ",
                       "(nivel = acumulada da diferenca) e razao entre elas; maior raiz ", num(f$raiz, 3),
                       ". Razao das somas das respostas de h = 0 a 40: ", num(f$soma, 3), " ", ic_txt(f$ic_soma[1], f$ic_soma[2]),
                       ". Granger nas colunas: Toda-Yamamoto (VAR(", sp$p + 1, "), Wald nas ", sp$p, " primeiras defasagens); ",
                       "Granger padrao do vars no VAR em nivel: INF -> PVD p = ", pv(f$g_std[1]), ", PVD -> INF p = ", pv(f$g_std[2]),
                       ". Bootstrap de residuos com ", f$runs, " replicas; replicas com razao negativa em h = 40: ",
                       num(100 * f$neg, 1), "%."),
          id = paste0(sp$id, "_nivel"), bloco = bloco, ic90_acum_priv_inf = f$ic_pvd[1], ic90_acum_priv_sup = f$ic_pvd[2],
          prop_boot_elast_neg = f$neg, runs = f$runs, elasticidade_beta = NA_real_, elast_beta_ic90_inf = NA_real_,
          elast_beta_ic90_sup = NA_real_)
}

# ------------------------------------------------------------------------------------------------
# 3. Baseline replicado (arquivos originais, 2002T1-2019T4)
# ------------------------------------------------------------------------------------------------
EXO_O <- list(PIB_o = "d", JUR_o = "d", DUM = "d")
EXO_C <- list(PIB = "d", SELIC = "d", DUM = "d")
# Regra da A4: so os pulsos da pandemia no baseline estendido; a indicadora da imputacao de 2017 vai na robustez (com_imp2017)
EXO_E <- list(PIB = "d", SELIC = "d", p2020Q2 = "n", p2020Q3 = "n")
mk <- function(id, inf, pvd, exo, de, ate, p = 3, ordem = c("INF", "PVD"))
  list(id = id, inf = inf, pvd = pvd, exo = exo, de = de, ate = ate, p = p, ordem = ordem)

sp_rep <- mk("replicado", "INF_o", "PVD_o", EXO_O, "2002Q1", "2019Q4")
t0 <- Sys.time()
f_rep <- fit_dif(sp_rep, RUNS_MAIN, irf_check = TRUE)
t_rep <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
alvos <- c(impacto = 0.0118, acum_pvd = 0.0194, acum_inf = 0.0465, elasticidade = 0.42)
obtidos <- c(f_rep$impacto, f_rep$c_pvd, f_rep$c_inf, f_rep$el)
stopifnot(all(round(obtidos[1:3], 4) == alvos[1:3]), round(obtidos[4], 2) == alvos[4], f_rep$mod$obs == 68)
# Mesmas replicas do bootstrap proprio da A1
a1b <- readr::read_csv(file.path(PATHS$processed, "A1_bootstrap.csv"), show_col_types = FALSE)
dif_a1 <- if (RUNS_MAIN == nrow(a1b)) max(abs(a1b$elasticidade - f_rep$boot$pvd[, H + 1] / f_rep$boot$inf[, H + 1])) else NA
stopifnot(RUNS_MAIN != nrow(a1b) || dif_a1 < 1e-8)
reg_dif(f_rep, sp_rep, "2002-2019 original", "VAR em diferenca", "baseline replicado (arquivos da dissertacao)", "baseline",
        paste0(" Alvos: impacto 0,0118, acumulada de PVD 0,0194, de INF 0,0465, elasticidade 0,42: reproduzidos."))
log_part(ETAPA, "- Baseline replicado: VAR(diff(infmeq), p = 3, type = \"both\", exogen = diff(exo)) com os arquivos originais, ",
         f_rep$mod$obs, " observacoes efetivas. Alvos: impacto ", num(f_rep$impacto, 4), " (alvo 0,0118); acumulada de PVD em h = 40 ",
         num(f_rep$c_pvd, 4), " (alvo 0,0194); acumulada de INF ", num(f_rep$c_inf, 4), " (alvo 0,0465); elasticidade ",
         num(f_rep$el, 4), " (alvo 0,42). IC 90% da elasticidade ", ic_txt(f_rep$ic[1], f_rep$ic[2]), " (2000 replicas). ",
         "Granger no VAR em diferenca: INF -> PVD p = ", pv(f_rep$g_pub_priv), "; PVD -> INF p = ", pv(f_rep$g_priv_pub), ".")
log_part(ETAPA, "- Bootstrap: irf() do vars com runs = 2000, seed = 42, IC 90%, acumulada; bootstrap proprio da elasticidade com o ",
         "mesmo desenho de vars:::.boot e MQO direto (sem refazer vars::VAR a cada replica). As bandas do bootstrap proprio coincidem ",
         "com as do irf() em todos os horizontes (diferenca maxima ", format(signif(f_rep$chk, 2), decimal.mark = ","),
         ", imposto por stopifnot em cada especificacao principal) e as elasticidades das 2000 replicas coincidem com as de ",
         "data/processed/A1_bootstrap.csv (diferenca maxima ", format(signif(dif_a1, 2), decimal.mark = ","), "). Tempo: ",
         num(t_rep, 0), " s.")

# ------------------------------------------------------------------------------------------------
# 4. Baseline corrigido, correcao a correcao (niveis 2003T1-2019T4)
# ------------------------------------------------------------------------------------------------
passos <- list(
  list(sp = mk("corr_a0", "INF_o", "PVD_o", EXO_O, "2003Q1", "2019Q4"),
       esp = "(a0) arquivos originais, niveis de 2003T1 a 2019T4 (so a amostra muda)"),
  list(sp = mk("corr_a", "inf_diss_nominal_2019", "PVD_o", EXO_O, "2003Q1", "2019Q4"),
       esp = "(a) INF nominal reconstruido (inf_diss_nominal_2019), PVD e exogenas originais"),
  list(sp = mk("corr_b", "inf_diss", "PVD_o", EXO_O, "2003Q1", "2019Q4"),
       esp = "(b) INF real (inf_diss), PVD e exogenas originais"),
  list(sp = mk("corr_c0", "inf_diss", "PVD", EXO_O, "2003Q1", "2019Q4"),
       esp = "(c0) INF real, PVD atual (fbcf_me_sa), exogenas originais"),
  list(sp = mk("corr_c", "inf_diss", "PVD", EXO_C, "2003Q1", "2019Q4"),
       esp = "(c) INF real, PVD atual, PIB (safra atual) e Selic meta fim do BCB, DUM (baseline corrigido)")
)
F_CORR <- list()
for (ps_ in passos) {
  f <- fit_dif(ps_$sp, RUNS_MAIN, irf_check = TRUE)
  F_CORR[[ps_$sp$id]] <- f
  reg_dif(f, ps_$sp, "2003-2019", "VAR em diferenca", ps_$esp, "baseline corrigido")
  log_part(ETAPA, "- Corrigido ", ps_$esp, ": n = ", f$mod$obs, "; impacto ", num(f$impacto, 4), "; acumuladas em h = 40: PVD ",
           num(f$c_pvd, 4), " ", ic_txt(f$ic_pvd[1], f$ic_pvd[2], 4), ", INF ", num(f$c_inf, 4), "; elasticidade ", num(f$el, 2),
           ", IC 90% ", ic_txt(f$ic[1], f$ic[2]), "; Granger INF -> PVD p = ", pv(f$g_pub_priv), ", PVD -> INF p = ",
           pv(f$g_priv_pub), "; BG p = ", pv(f$bg), ".")
}

# ------------------------------------------------------------------------------------------------
# 5. Amostra estendida 2003T1-2025T4 (VAR em diferenca)
# ------------------------------------------------------------------------------------------------
sp_ext <- mk("ext", "inf_diss", "PVD", EXO_E, "2003Q1", "2025Q4")
f_ext <- fit_dif(sp_ext, RUNS_MAIN, irf_check = TRUE)
reg_dif(f_ext, sp_ext, "2003-2025", "VAR em diferenca",
        "estendida: INF real, PVD atual, diff PIB, diff Selic, pulsos 2020T2 e 2020T3", "baseline estendido")
log_part(ETAPA, "- Estendida (niveis 2003T1-2025T4; exogenas diff PIB, diff Selic meta fim e pulsos 2020T2 e 2020T3 sem ",
         "diferenciar, como manda a regra da A4; sem imp2017, que vai na robustez com_imp2017): n = ", f_ext$mod$obs, "; impacto ",
         num(f_ext$impacto, 4), "; acumulada de PVD ", num(f_ext$c_pvd, 4), " ", ic_txt(f_ext$ic_pvd[1], f_ext$ic_pvd[2], 4),
         "; de INF ", num(f_ext$c_inf, 4), "; elasticidade ", num(f_ext$el, 2), ", IC 90% ", ic_txt(f_ext$ic[1], f_ext$ic[2]),
         "; Granger INF -> PVD p = ", pv(f_ext$g_pub_priv), ", PVD -> INF p = ", pv(f_ext$g_priv_pub), "; BG p = ", pv(f_ext$bg), ".")

# ------------------------------------------------------------------------------------------------
# 6. Johansen: traco, Reinsel-Ahn e bootstrap selvagem de Cavaliere, Rahbek e Taylor (2012)
# ------------------------------------------------------------------------------------------------
cajo <- function(X, ecdet, dumvar, K = K_JOH, type = "trace")
  urca::ca.jo(X, type = type, ecdet = ecdet, K = K, spec = "transitory", dumvar = dumvar)
lin_r <- function(cj, r0) {
  rn <- trimws(gsub("\\|", "", rownames(cj@cval)))
  which(rn == if (r0 == 0) "r = 0" else paste0("r <= ", r0))
}

# Gera dados sob H0: posto r0, a partir do modelo restrito estimado (beta de Johansen com posto r0; alfa,
# termos de curto prazo e deterministicos por MQO dado beta); residuos restritos vezes Rademacher.
joh_boot <- function(X, ecdet, dumvar, r0, B = B_JOH, seed = 42) {
  cj <- cajo(X, ecdet, dumvar)
  Z0 <- cj@Z0; Z1 <- cj@Z1; ZK <- cj@ZK; P <- ncol(X); Tn <- nrow(Z0); Kl <- K_JOH
  if (r0 == 0) {
    R <- Z1
  } else {
    beta <- cj@V[, 1:r0, drop = FALSE]
    R <- cbind(ZK %*% beta, Z1)
  }
  cf <- solve(crossprod(R), crossprod(R, Z0))
  E <- Z0 - R %*% cf
  if (r0 == 0) {
    Pi <- matrix(0, P, ncol(ZK)); Gam <- t(cf)
  } else {
    Pi <- t(cf[1:r0, , drop = FALSE]) %*% t(beta); Gam <- t(cf[-(1:r0), , drop = FALSE])
  }
  colnames(Gam) <- colnames(Z1)
  lagc <- grep("\\.dl[0-9]+$", colnames(Z1)); detc <- setdiff(seq_len(ncol(Z1)), lagc)
  stopifnot(identical(colnames(Z1)[lagc], as.vector(outer(colnames(cj@x), 1:(Kl - 1), paste, sep = ".dl"))))
  Gl <- Gam[, lagc, drop = FALSE]
  fixo <- Z1[, detc, drop = FALSE] %*% t(Gam[, detc, drop = FALSE])
  if (ncol(ZK) > P) fixo <- fixo + ZK[, -(1:P), drop = FALSE] %*% t(Pi[, -(1:P), drop = FALSE])
  PiX <- Pi[, 1:P, drop = FALSE]
  simula <- function(w) {
    Xs <- X; Es <- E * w + fixo
    for (j in seq_len(Tn)) {
      t <- j + Kl
      dl <- as.vector(sapply(1:(Kl - 1), function(i) Xs[t - i, ] - Xs[t - i - 1, ]))
      Xs[t, ] <- Xs[t - 1, ] + PiX %*% Xs[t - 1, ] + Gl %*% dl + Es[j, ]
    }
    Xs
  }
  # Conferencia: com w = 1 a recursao reproduz os dados
  stopifnot(max(abs(simula(rep(1, Tn)) - X)) < 1e-9)
  st_obs <- cj@teststat[lin_r(cj, r0)]
  set.seed(seed)
  st <- numeric(B)
  for (b in seq_len(B)) {
    w <- sample(c(-1, 1), Tn, replace = TRUE)
    cb <- cajo(simula(w), ecdet, dumvar)
    st[b] <- cb@teststat[lin_r(cb, r0)]
  }
  list(cj = cj, st_obs = st_obs, st = st, p = mean(st >= st_obs), Tn = Tn)
}

AMOSTRAS_J <- list(
  list(nome = "2002-2019 original", inf = "INF_o", pvd = "PVD_o", de = "2002Q1", ate = "2019Q4", dum = "DUM"),
  list(nome = "2003-2019", inf = "inf_diss", pvd = "PVD", de = "2003Q1", ate = "2019Q4", dum = "DUM"),
  list(nome = "2003-2025", inf = "inf_diss", pvd = "PVD", de = "2003Q1", ate = "2025Q4", dum = c("p2020Q2", "p2020Q3"))
)
JOH <- list(); JOH_ST <- list()
t0 <- Sys.time()
for (am in AMOSTRAS_J) {
  keys <- q_seq(am$de, am$ate)
  X <- cbind(INF = get_win(am$inf, keys, "INF"), PVD = get_win(am$pvd, keys, "PVD"))
  D <- sapply(am$dum, function(d) get_win(d, keys, d)); D <- matrix(D, ncol = length(am$dum), dimnames = list(NULL, am$dum))
  for (ec in c("trend", "const")) {
    for (r0 in 0:1) {
      jb <- joh_boot(X, ec, D, r0)
      cj <- jb$cj; li <- lin_r(cj, r0)
      fra <- (jb$Tn - ncol(X) * K_JOH) / jb$Tn
      JOH[[length(JOH) + 1]] <- tibble(
        amostra = am$nome, janela = paste0(am$de, "-", am$ate), ecdet = ec, K = K_JOH, dumvar = paste(am$dum, collapse = ", "),
        T_efetivo = jb$Tn, hipotese = if (r0 == 0) "r = 0" else "r <= 1", traco = jb$st_obs, fator_ra = fra,
        traco_ra = jb$st_obs * fra, cv10 = cj@cval[li, 1], cv5 = cj@cval[li, 2], cv1 = cj@cval[li, 3],
        rejeita5_assintotico = jb$st_obs > cj@cval[li, 2], rejeita5_ra = jb$st_obs * fra > cj@cval[li, 2],
        p_boot = jb$p, B = B_JOH, autovalor = cj@lambda[r0 + 1])
      JOH_ST[[paste(am$nome, ec, r0)]] <- tibble(amostra = am$nome, ecdet = ec, hipotese = if (r0 == 0) "r = 0" else "r <= 1",
                                               estat = jb$st, obs = jb$st_obs)
    }
  }
}
t_joh <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
JOH <- bind_rows(JOH)
write_csv_safe(JOH, file.path(PATHS$processed, "A5_johansen.csv"))

decisao <- JOH %>% filter(ecdet == "trend", hipotese == "r = 0") %>%
  transmute(amostra, traco, traco_ra, cv5, cv10, rej_ass = rejeita5_assintotico, rej_ra = rejeita5_ra, p_boot, vec = p_boot < 0.05)
dec_const <- JOH %>% filter(ecdet == "const", hipotese == "r = 0") %>% transmute(amostra, p_boot_const = p_boot)
decisao <- left_join(decisao, dec_const, by = "amostra") %>%
  mutate(evidencia = case_when(vec ~ "rejeita r = 0 (bootstrap a 5%)",
                               rej_ass | rej_ra | p_boot < 0.10 | p_boot_const < 0.05 ~ "limitrofe",
                               TRUE ~ "nao rejeita r = 0"))

log_part(ETAPA, "- Johansen (traco), K = ", K_JOH, ", spec transitory (a estatistica nao depende de spec), ecdet trend e const, ",
         "dumvar so deterministicas: DUM do arquivo (em nivel, como na A1) nas amostras 2002-2019 e 2003-2019; pulsos 2020T2 e ",
         "2020T3 na 2003-2025. Reinsel-Ahn: traco vezes (T - pK)/T, com T = observacoes efetivas do VECM (niveis menos K), ",
         "p = 2 variaveis e K = 3. Bootstrap selvagem (Cavaliere, Rahbek e Taylor, 2012): ", B_JOH, " replicas, set.seed(42) em ",
         "cada teste; dados gerados sob H0 (posto r0) a partir do modelo restrito estimado (beta de Johansen com posto r0; alfa, ",
         "termos de curto prazo e deterministicos por MQO dado beta; com r0 = 0, so curto prazo e deterministicos), residuos ",
         "restritos multiplicados por Rademacher (mesmo sinal nas duas equacoes em cada t), valores iniciais observados; a ",
         "recursao com pesos iguais a 1 reproduz os dados (stopifnot). p-valor = proporcao de replicas com traco maior ou igual ",
         "ao observado (a correcao de Reinsel-Ahn e um fator comum e nao muda o p-valor do bootstrap). Tempo: ", num(t_joh, 0), " s.")
for (i in seq_len(nrow(JOH))) {
  j <- JOH[i, ]
  log_part(ETAPA, "  - ", j$amostra, ", ecdet ", j$ecdet, ", ", j$hipotese, ": traco ", num(j$traco, 2), " (Reinsel-Ahn ",
           num(j$traco_ra, 2), ", fator ", num(j$fator_ra, 3), ") contra valor critico de 5% ", num(j$cv5, 2), " (10%: ",
           num(j$cv10, 2), "); p bootstrap ", num(j$p_boot, 3), ".")
}
log_part(ETAPA, "- Regra de escolha (A0_ambiente.md): Johansen com Reinsel-Ahn e bootstrap; rejeitar r = 0 a 5% leva ao VECM com r = 1 ",
         "como baseline. Quando as leituras divergem, prevalece o bootstrap, por dois motivos. (i) Nas amostras 2002-2019 e 2003-2019 ",
         "a DUM da dissertacao entra em nivel na parte irrestrita do VECM (bloco de uns que vai ate o fim da amostra); isso gera ",
         "tendencia quebrada nos niveis e muda a distribuicao assintotica do traco (Johansen, Mosconi e Nielsen, 2000), de modo que ",
         "os valores criticos tabelados do urca, com ou sem Reinsel-Ahn, nao valem; o bootstrap gera os dados com a mesma DUM. ",
         "(ii) Com T de 64 a 88, o teste assintotico rejeita demais em amostra pequena, e Reinsel-Ahn e so um fator de escala; o ",
         "bootstrap selvagem tambem e robusto a heterocedasticidade. Na amostra 2003-2025 so ha pulsos, que nao mudam a ",
         "distribuicao assintotica, e vale o motivo (ii). Decisao lida no caso ecdet = trend (o mesmo da dissertacao e coerente com ",
         "o VAR com constante e tendencia); ecdet = const vai como conferencia. ",
         paste(sprintf("%s: traco %s (Reinsel-Ahn %s) contra valor critico de 5%% %s, %s pelo assintotico e %s com Reinsel-Ahn; p bootstrap %s (const: %s); evidencia %s; %s",
                       decisao$amostra, num(decisao$traco, 2), num(decisao$traco_ra, 2), num(decisao$cv5, 2),
                       ifelse(decisao$rej_ass, "rejeita", "nao rejeita"), ifelse(decisao$rej_ra, "rejeita", "nao rejeita"),
                       num(decisao$p_boot, 3), num(decisao$p_boot_const, 3), decisao$evidencia,
                       ifelse(decisao$vec, "baseline VECM r = 1 e VAR em diferenca como comparacao",
                              "baseline VAR em diferenca pelo bootstrap e VECM ao lado")), collapse = "; "), ".")

# ------------------------------------------------------------------------------------------------
# 7. VECM com r = 1 (cajorls e vec2var), IRF em nivel com IC bootstrap, e VAR em nivel
# ------------------------------------------------------------------------------------------------
fit_vecm <- function(am, ecdet, exo_dif, runs, irf_check = FALSE) {
  keys <- q_seq(am$de, am$ate)
  X <- cbind(INF = get_win(am$inf, keys, "INF"), PVD = get_win(am$pvd, keys, "PVD"))
  if (is.null(exo_dif)) {
    D <- sapply(am$dum, function(d) get_win(d, keys, d)); D <- matrix(D, ncol = length(am$dum), dimnames = list(NULL, am$dum))
  } else {
    # mesmas exogenas do VAR em diferenca; a primeira linha nao entra (ca.jo usa as linhas K+1 em diante)
    D <- sapply(names(exo_dif), function(nm) { x <- get_win(nm, keys, nm); if (exo_dif[[nm]] == "d") c(0, diff(x)) else x })
    colnames(D) <- paste0(ifelse(unlist(exo_dif) == "d", "d_", ""), names(exo_dif))
    D <- D[, apply(D[-(1:K_JOH), , drop = FALSE], 2, function(z) any(z != 0)), drop = FALSE]
  }
  cj <- urca::ca.jo(X, type = "trace", ecdet = ecdet, K = K_JOH, spec = "transitory", dumvar = D)
  cr <- urca::cajorls(cj, r = 1)
  v2 <- vars::vec2var(cj, r = 1)
  b <- cj@V[, 1]; bn <- b / b["PVD.l1"]
  el_beta <- -bn[["INF.l1"]]
  alpha <- cj@W[, 1] * b["PVD.l1"]
  # t de alfa (cajorls normaliza beta em INF; com beta normalizado em PVD o sinal muda se o coeficiente de PVD for negativo)
  sm <- summary(cr$rlm)
  t_alpha <- sapply(sm, function(z) coef(z)["ect1", "t value"]) * sign(cr$beta["PVD.l1", 1])
  stopifnot(max(abs(sapply(sm, function(z) coef(z)["ect1", "Estimate"]) * cr$beta["PVD.l1", 1] - alpha)) < 1e-8)
  ps <- vars::Psi(v2, nstep = H)
  stopifnot(identical(colnames(v2$y), c("INF", "PVD")))
  dimnames(ps) <- list(c("INF", "PVD"), c("INF", "PVD"), NULL)
  # Bootstrap proprio com o desenho de vars:::.bootirfvec2var (mesmos sorteios)
  Zdet <- matrix(v2$datamat[, colnames(v2$deterministic)], ncol = ncol(v2$deterministic))
  Bm <- v2$deterministic; for (i in 1:v2$p) Bm <- cbind(Bm, v2$A[[i]])
  p <- v2$p; K <- v2$K; obs <- v2$obs; tot <- v2$totobs
  U <- scale(resid(v2), scale = FALSE)
  out <- matrix(NA_real_, runs, 4, dimnames = list(NULL, c("impacto", "n_pvd", "n_inf", "el_beta")))
  P_pvd <- matrix(NA_real_, runs, H + 1); P_inf <- P_pvd
  ys <- matrix(0, tot, K, dimnames = list(NULL, colnames(v2$y)))
  set.seed(42)
  for (r in seq_len(runs)) {
    idx <- sample(c(1:obs), replace = TRUE)
    Ub <- U[idx, , drop = FALSE]
    lasty <- c(t(v2$y[p:1, ]))
    ys[1:p, ] <- v2$y[1:p, ]
    for (j in seq_len(obs)) {
      lasty <- lasty[1:(K * p)]
      ys[j + p, ] <- Bm %*% c(Zdet[j, ], lasty) + Ub[j, ]
      lasty <- c(ys[j + p, ], lasty)
    }
    vb <- urca::ca.jo(ys, ecdet = cj@ecdet, season = cj@season, dumvar = cj@dumvar, K = cj@lag, spec = cj@spec)
    v2b <- vars::vec2var(vb, r = 1)
    pb <- vars::Psi(v2b, nstep = H)
    dimnames(pb) <- list(c("INF", "PVD"), c("INF", "PVD"), NULL)
    P_pvd[r, ] <- pb["PVD", "INF", ]; P_inf[r, ] <- pb["INF", "INF", ]
    bb <- vb@V[, 1]
    out[r, ] <- c(pb["PVD", "INF", 1], pb["PVD", "INF", H + 1], pb["INF", "INF", H + 1], -bb[["INF.l1"]] / bb[["PVD.l1"]])
  }
  chk <- NA
  if (irf_check) {
    ir <- vars::irf(v2, impulse = "INF", response = c("INF", "PVD"), n.ahead = H, boot = TRUE, runs = runs, ci = 0.90, seed = 42)
    band_own <- rbind(apply(P_pvd, 2, q90), apply(P_inf, 2, q90))
    band_irf <- rbind(rbind(ir$Lower$INF[, "PVD"], ir$Upper$INF[, "PVD"]), rbind(ir$Lower$INF[, "INF"], ir$Upper$INF[, "INF"]))
    chk <- max(abs(band_own - band_irf))
    stopifnot(chk < 1e-10)
  }
  el_b <- out[, "n_pvd"] / out[, "n_inf"]
  list(cj = cj, cr = cr, v2 = v2, D = D, bn = bn, el_beta = el_beta, alpha = alpha, t_alpha = unname(t_alpha), impacto = ps["PVD", "INF", 1],
       n_pvd = ps["PVD", "INF", H + 1], n_inf = ps["INF", "INF", H + 1], el = ps["PVD", "INF", H + 1] / ps["INF", "INF", H + 1],
       ic = q90(el_b), ic_pvd = q90(out[, "n_pvd"]), ic_beta = q90(out[, "el_beta"]), neg = mean(el_b < 0),
       neg_beta = mean(out[, "el_beta"] < 0), chk = chk, runs = runs, path = ps["PVD", "INF", ], boot_pvd = P_pvd,
       n = nrow(cj@Z0))
}
reg_vecm <- function(f, am, espec, bloco, id) {
  cf <- coef(f$cr$rlm)
  push_row(amostra = am$nome, modelo = "VECM r = 1", especificacao = espec, n = f$n, impacto = f$impacto,
          resp_acum_40_priv = f$n_pvd, resp_acum_40_pub = f$n_inf, elasticidade = f$el, ic90_inf = f$ic[1], ic90_sup = f$ic[2],
          granger_p_pub_priv = NA_real_, granger_p_priv_pub = NA_real_,
          obs = paste0("ca.jo K = ", K_JOH, ", ecdet ", f$cj@ecdet, ", spec transitory, dumvar: ", paste(colnames(f$D), collapse = ", "),
                       "; vec2var r = 1; respostas em nivel em h = 40 (nivel = acumulada da diferenca), choque ortogonal em INF ",
                       "(INF antes de PVD). Vetor normalizado em PVD: PVD ", ifelse(-f$bn[["INF.l1"]] >= 0, "= ", "= -"),
                       num(abs(f$el_beta), 3), " x INF", if (length(f$bn) > 2) paste0(" + ", num(-f$bn[[3]], 5), " x ", names(f$bn)[3]) else "",
                       " + erro estacionario; elasticidade de longo prazo pelo vetor ", num(f$el_beta, 2), " ",
                       ic_txt(f$ic_beta[1], f$ic_beta[2]), " (replicas com sinal negativo: ", num(100 * f$neg_beta, 1),
                       "%). Carregamentos (alfa) com beta normalizado: INF ", num(f$alpha[1], 3), ", PVD ", num(f$alpha[2], 3),
                       ". Bootstrap de residuos com o desenho de vars:::.bootirfvec2var, ", f$runs, " replicas; replicas com razao ",
                       "negativa em h = 40: ", num(100 * f$neg, 1), "%. Granger nao se aplica ao VECM (ver VAR em diferenca e em nivel)."),
          id = id, bloco = bloco, ic90_acum_priv_inf = f$ic_pvd[1], ic90_acum_priv_sup = f$ic_pvd[2],
          prop_boot_elast_neg = f$neg, runs = f$runs, elasticidade_beta = f$el_beta, elast_beta_ic90_inf = f$ic_beta[1],
          elast_beta_ic90_sup = f$ic_beta[2], alfa_inf = f$alpha[[1]], t_alfa_inf = f$t_alpha[1], alfa_pvd = f$alpha[[2]],
          t_alfa_pvd = f$t_alpha[2])
}

EXO_VECM <- list("2002-2019 original" = EXO_O, "2003-2019" = EXO_C, "2003-2025" = EXO_E)
SP_NIV <- list("2002-2019 original" = mk("nivel_orig", "INF_o", "PVD_o", list(PIB_o = "n", JUR_o = "n", DUM = "n"), "2002Q1", "2019Q4"),
               "2003-2019" = mk("nivel_2019", "inf_diss", "PVD", list(PIB = "n", SELIC = "n", DUM = "n"), "2003Q1", "2019Q4"),
               "2003-2025" = mk("nivel_2025", "inf_diss", "PVD", list(PIB = "n", SELIC = "n", p2020Q2 = "n", p2020Q3 = "n"),
                                "2003Q1", "2025Q4"))
F_VECM <- list(); F_NIV <- list()
t0 <- Sys.time()
for (am in AMOSTRAS_J) {
  dec <- decisao %>% filter(amostra == am$nome)
  papel <- if (dec$vec) "baseline (Johansen rejeita r = 0)" else if (dec$evidencia == "limitrofe")
    "ao lado do VAR (evidencia limitrofe; bootstrap nao rejeita r = 0)" else "robustez (Johansen nao rejeita r = 0)"
  fv <- fit_vecm(am, "trend", EXO_VECM[[am$nome]], RUNS_MAIN, irf_check = (am$nome == "2002-2019 original"))
  F_VECM[[am$nome]] <- fv
  reg_vecm(fv, am, paste0("VECM r = 1, ecdet trend, exogenas do VAR em diferenca; ", papel),
           if (dec$vec) "baseline VECM" else "robustez VECM", paste0("vecm_", am$nome))
  fv2 <- fit_vecm(am, "trend", NULL, RUNS_ROB)
  reg_vecm(fv2, am, "VECM r = 1, ecdet trend, so dumvar deterministicas do teste", "robustez VECM", paste0("vecm_det_", am$nome))
  fv3 <- fit_vecm(am, "const", EXO_VECM[[am$nome]], RUNS_ROB)
  reg_vecm(fv3, am, "VECM r = 1, ecdet const, exogenas do VAR em diferenca", "robustez VECM", paste0("vecm_const_", am$nome))
  F_VECM[[paste(am$nome, "det")]] <- fv2; F_VECM[[paste(am$nome, "const")]] <- fv3
  log_part(ETAPA, "- VECM ", am$nome, " (", papel, "; ecdet trend, exogenas do VAR em diferenca como dumvar no curto prazo): ",
           "impacto ", num(fv$impacto, 4), "; resposta em nivel em h = 40: PVD ", num(fv$n_pvd, 4), " ", ic_txt(fv$ic_pvd[1], fv$ic_pvd[2], 4),
           ", INF ", num(fv$n_inf, 4), "; razao ", num(fv$el, 2), " ", ic_txt(fv$ic[1], fv$ic[2]), "; vetor normalizado em PVD: ",
           "elasticidade de longo prazo ", num(fv$el_beta, 2), " ", ic_txt(fv$ic_beta[1], fv$ic_beta[2]), "; alfa (PVD) ", num(fv$alpha[2], 3),
           " (t = ", num(fv$t_alpha[2], 2), "), alfa (INF) ", num(fv$alpha[1], 3), " (t = ", num(fv$t_alpha[1], 2), "). So deterministicas: razao ", num(fv2$el, 2), " ", ic_txt(fv2$ic[1], fv2$ic[2]),
           ", vetor ", num(fv2$el_beta, 2), ". ecdet const: razao ", num(fv3$el, 2), " ", ic_txt(fv3$ic[1], fv3$ic[2]), ", vetor ",
           num(fv3$el_beta, 2), ".",
           if (!is.na(fv$chk)) paste0(" Bandas do bootstrap proprio iguais as do irf() do vec2var (diferenca maxima ",
                                      format(signif(fv$chk, 2), decimal.mark = ","), ").") else "")
  sp_n <- SP_NIV[[am$nome]]
  fn <- fit_niv(sp_n, RUNS_MAIN)
  F_NIV[[am$nome]] <- fn
  reg_niv(fn, sp_n, am$nome, "VAR(3) em nivel, exogenas em nivel", "VAR em nivel")
  log_part(ETAPA, "- VAR em nivel ", am$nome, ": impacto ", num(fn$impacto, 4), "; resposta em nivel em h = 40: PVD ", num(fn$n_pvd, 4),
           ", INF ", num(fn$n_inf, 4), "; razao ", num(fn$el, 2), " ", ic_txt(fn$ic[1], fn$ic[2]), "; razao das somas (h = 0 a 40) ",
           num(fn$soma, 2), " ", ic_txt(fn$ic_soma[1], fn$ic_soma[2]), "; maior raiz ", num(fn$raiz, 3), "; Granger Toda-Yamamoto: ",
           "INF -> PVD p = ", pv(fn$ty[["pub_priv"]]), ", PVD -> INF p = ", pv(fn$ty[["priv_pub"]]), ".")
}
t_vecm <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
lim <- decisao %>% filter(evidencia == "limitrofe")
if (nrow(lim)) {
  log_part(ETAPA, "- Evidencia de cointegracao limitrofe em ", paste(lim$amostra, collapse = ", "), ": a escolha entre VAR e VECM pesa no ",
           "numero e nao e decidida pelos dados com folga. Por isso a A6 deve mostrar o VECM ao lado do VAR em diferenca em cada amostra: ",
           paste(vapply(lim$amostra, function(a) {
             fd <- switch(a, "2002-2019 original" = f_rep, "2003-2019" = F_CORR$corr_c, "2003-2025" = f_ext)
             fv <- F_VECM[[a]]
             sprintf("%s, VAR em diferenca %s %s contra VECM (vetor normalizado em PVD) %s %s", a, num(fd$el, 2), ic_txt(fd$ic[1], fd$ic[2]),
                     num(fv$el_beta, 2), ic_txt(fv$ic_beta[1], fv$ic_beta[2]))
           }, ""), collapse = "; "), ".")
}

# ------------------------------------------------------------------------------------------------
# 8. Robustez do VAR em diferenca (runs = 1000)
# ------------------------------------------------------------------------------------------------
base <- list("2003-2019" = F_CORR$corr_c, "2003-2025" = f_ext)
BASE_SP <- list("2003-2019" = passos[[5]]$sp, "2003-2025" = sp_ext)
rob_specs <- list()
addr <- function(am, id, esp, sp) rob_specs[[length(rob_specs) + 1]] <<- list(am = am, id = id, esp = esp, sp = sp)
CONTROLES <- c(CAMBIO = "cambio real efetivo", ICBR = "IC-Br em US$", BRENT = "Brent", BNDES = "BNDES exceto adm. publica")
for (am in names(BASE_SP)) {
  b0 <- BASE_SP[[am]]
  s <- b0; s$exo$PIB <- "n"; addr(am, "pib_taxa", "PIB em taxa de crescimento (sem diferenciar)", s)
  s <- b0; s$ordem <- c("PVD", "INF"); addr(am, "chol_inv", "ordem de Cholesky invertida (PVD antes de INF)", s)
  for (pp in c(2, 4)) { s <- b0; s$p <- pp; addr(am, paste0("p", pp), paste0("p = ", pp), s) }
  for (cc in names(CONTROLES)) { s <- b0; s$exo[[cc]] <- "d"; addr(am, paste0("ctrl_", cc), paste0("controle: ", CONTROLES[[cc]]), s) }
  pares <- combn(names(CONTROLES), 2)
  for (k in seq_len(ncol(pares))) {
    s <- b0; s$exo[[pares[1, k]]] <- "d"; s$exo[[pares[2, k]]] <- "d"
    addr(am, paste0("ctrl_", pares[1, k], "_", pares[2, k]), paste0("controles: ", CONTROLES[[pares[1, k]]], " e ", CONTROLES[[pares[2, k]]]), s)
  }
  s <- b0; s$exo$SELIC <- NULL; s$exo <- c(s$exo[1], list(SELIC_MED = "d"), s$exo[-1]); addr(am, "selic_media", "Selic meta, media do trimestre", s)
  s <- b0
  for (q in q_seq("2016Q4", "2018Q1")) s$exo[[paste0("p", q)]] <- "n"
  addr(am, "excl_2016T4_2018T1", "excluir 2016T4-2018T1 (um pulso por trimestre)", s)
  s <- b0; s$exo$imp2017 <- "n"; addr(am, "com_imp2017", "com imp2017 (indicadora de 2017, sem diferenciar)", s)
  for (v in c("inf_diss_e2017", "inf_diss_e2018", "inf_diss_e2019", "inf_diss_e2020", "inf_diss_e2020_r1618",
              "inf_diss_imprazao", "inf_diss_x11soma", "inf_diss_semao")) {
    s <- b0; s$inf <- v; addr(am, v, paste0("INF = ", v), s)
  }
  if (am == "2003-2019") {
    s <- b0; s$exo$DUM <- NULL; addr(am, "sem_dum", "sem a DUM da dissertacao", s)
  }
  if (am == "2003-2025") {
    s <- b0; for (d in DUMS_A4_INF) s$exo[[d]] <- "n"
    addr(am, "dummies_A4", "dummies_A4: outliers do X-11 de inf_diss de 2018-2021 (A4_dummies_quebra.csv), alem dos pulsos", s)
  }
}
# Subamostras com o corte da A4 (quebra entre 2014T4 e 2015T1): observacoes efetivas ate 2014T4 e de 2015T1 em diante.
# Na segunda, a janela dos niveis comeca em 2014T1 para que as p = 3 defasagens da diferenca venham de 2014.
s <- sp_ext; s$ate <- "2014Q4"; addr("ate 2014T4", "sub_ate_2014T4", "subamostra: observacoes efetivas 2004T1-2014T4", s)
s <- sp_ext; s$de <- "2014Q1"; addr("de 2015T1", "sub_de_2015T1", "subamostra: observacoes efetivas 2015T1-2025T4 (niveis desde 2014T1)", s)

t0 <- Sys.time()
nota_iguais <- character(0)
for (rs in rob_specs) {
  # Variante de INF identica ao baseline na janela: registra e pula
  if (rs$sp$inf != "inf_diss") {
    keys <- q_seq(rs$sp$de, rs$sp$ate)
    if (max(abs(diff(get_win(rs$sp$inf, keys, "x")) - diff(get_win("inf_diss", keys, "x")))) < 1e-10) {
      nota_iguais <- c(nota_iguais, paste0(rs$sp$inf, " (", rs$am, ")"))
      next
    }
  }
  rs$sp$id <- paste0(rs$id, "_", rs$am)
  f <- fit_dif(rs$sp, RUNS_ROB)
  reg_dif(f, rs$sp, rs$am, "VAR em diferenca", rs$esp, "robustez VAR")
}
t_rob <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
if (length(nota_iguais)) log_part(ETAPA, "- Variantes de INF identicas a inf_diss nas diferencas da janela (nao estimadas): ",
                                  paste(nota_iguais, collapse = "; "), ".")
log_part(ETAPA, "- Subamostras com o mesmo corte da A4 (quebra entre 2014T4 e 2015T1; definido por observacoes efetivas, isto e, pela ",
         "data da variavel dependente, com as defasagens podendo vir de antes do corte): ate 2014T4 (observacoes efetivas 2004T1-2014T4) ",
         "e de 2015T1 (2015T1-2025T4; niveis desde 2014T1). Partem da especificacao estendida (exogenas sem variacao na subamostra saem ",
         "e vao listadas na coluna obs). A subamostra de 2015T1 a 2019T4 da amostra 2003-2019 nao foi estimada: 20 observacoes ",
         "efetivas para 11 ou mais regressores por equacao.")

# ------------------------------------------------------------------------------------------------
# 9. Resultados
# ------------------------------------------------------------------------------------------------
RES <- bind_rows(RES)
COLS <- c("amostra", "modelo", "especificacao", "n", "impacto", "resp_acum_40_priv", "resp_acum_40_pub", "elasticidade",
          "ic90_inf", "ic90_sup", "granger_p_pub_priv", "granger_p_priv_pub", "obs")
RES <- RES %>% dplyr::select(all_of(COLS), everything())
f_res <- file.path(PATHS$processed, "A5_var_resultados.csv")
write_csv_safe(RES, f_res)

rob <- RES %>% filter(bloco == "robustez VAR")
# Robustez principal (pedida pelo autor no briefing): PIB em taxa, Cholesky invertida, 2 e 4 defasagens e subamostras.
# Vem em linha propria, antes da contagem das demais variantes (controles e variantes de INF, quase iguais entre si).
PRINC <- c(pib_taxa = "PIB em taxa", chol_inv = "Cholesky invertida", p2 = "p = 2", p4 = "p = 4",
           com_imp2017 = "com imp2017", dummies_A4 = "dummies_A4", inf_diss_semao = "INF sem AO")
rob <- rob %>% mutate(tipo_id = sub("_(2003-2019|2003-2025|ate 2014T4|de 2015T1)$", "", id),
                      principal = tipo_id %in% c(names(PRINC), "sub_ate_2014T4", "sub_de_2015T1"))
el_txt <- function(r) sprintf("%s %s", num(r$elasticidade, 3), ic_txt(r$ic90_inf, r$ic90_sup))
base_row <- RES %>% filter(id %in% c("corr_c", "ext"))
for (am in c("2003-2019", "2003-2025")) {
  b <- base_row %>% filter(amostra == am)
  pr <- rob %>% filter(amostra == am, tipo_id %in% names(PRINC)) %>% mutate(rot = PRINC[tipo_id])
  extra <- if (am == "2003-2025") {
    sb <- rob %>% filter(tipo_id %in% c("sub_ate_2014T4", "sub_de_2015T1"))
    paste0("; subamostra ate 2014T4 ", el_txt(sb[sb$tipo_id == "sub_ate_2014T4", ]), "; de 2015T1 ", el_txt(sb[sb$tipo_id == "sub_de_2015T1", ]))
  } else ""
  log_part(ETAPA, "- Robustez principal ", am, " (baseline ", el_txt(b), "): ",
           paste(sprintf("%s %s", pr$rot, vapply(seq_len(nrow(pr)), function(i) el_txt(pr[i, ]), "")), collapse = "; "), extra,
           ". IC 90% inclui zero em: ", {
             z <- bind_rows(pr, if (am == "2003-2025") rob %>% filter(tipo_id %in% c("sub_ate_2014T4", "sub_de_2015T1")) %>%
                              mutate(rot = ifelse(tipo_id == "sub_ate_2014T4", "ate 2014T4", "de 2015T1")) else NULL) %>% filter(ic90_inf <= 0)
             if (nrow(z)) paste(z$rot, collapse = ", ") else "nenhuma"
           }, ".")
}
resumo_rob <- rob %>% filter(!principal) %>% group_by(amostra) %>%
  summarise(n_esp = n(), min_el = min(elasticidade), max_el = max(elasticidade), med_el = median(elasticidade),
            n_ic_pos = sum(ic90_inf > 0), n_g5 = sum(granger_p_pub_priv < 0.05), .groups = "drop")
for (i in seq_len(nrow(resumo_rob))) {
  r <- resumo_rob[i, ]
  log_part(ETAPA, "- Demais variantes ", r$amostra, " (controles, Selic media, variantes de INF da A3, exclusao de 2016T4-2018T1",
           if (r$amostra == "2003-2019") ", sem DUM" else "", "; quase iguais entre si, nao sao a sintese da robustez): ", r$n_esp,
           " especificacoes; elasticidade de ", num(r$min_el, 2), " a ", num(r$max_el, 2),
           " (mediana ", num(r$med_el, 2), "); IC 90% acima de zero em ", r$n_ic_pos, " de ", r$n_esp,
           "; Granger INF -> PVD a 5% em ", r$n_g5, " de ", r$n_esp, ".")
}
chol <- rob %>% filter(grepl("Cholesky", especificacao))
ci17 <- rob %>% filter(id == "com_imp2017_2003-2025")
da4 <- rob %>% filter(id == "dummies_A4_2003-2025")
log_part(ETAPA, "- Correcoes da revisao adversarial (2026-09-28). (1) imp2017 saiu do VAR estendido de base, do VAR em nivel e do VECM ",
         "2003-2025, que agora seguem a regra da A4 (so os pulsos de 2020T2 e 2020T3; a imputacao de 2017 nao entra porque o F dos ",
         "pulsos de 2017 nao e significativo); as LP e o Johansen 2003-2025 ja usavam so os pulsos. Elasticidade estendida: ",
         el_txt(RES %>% filter(id == "ext")), "; com imp2017 (robustez com_imp2017, o numero anterior): ", el_txt(ci17), ". (2) Decisao VAR x VEC: ",
         "o log e o A5_var.md dizem que o assintotico e Reinsel-Ahn rejeitam r = 0 em 2003-2019, que o bootstrap prevalece e por que, ",
         "e classificam a evidencia como limitrofe; VECM ao lado do VAR na A6. (3) Robustez principal (PIB em taxa, Cholesky invertida, ",
         "p = 2 e 4, subamostras) em linha propria, antes da contagem das demais variantes. (4) dummies_A4 (outliers do X-11 de 2018-2021 ",
         "da A4) na robustez 2003-2025: ", el_txt(da4), ". (5) Subamostras com o corte da A4 (ate 2014T4 e de 2015T1, por observacoes efetivas).")
log_part(ETAPA, "- Tempo: replicado ", num(t_rep, 0), " s; Johansen com bootstrap ", num(t_joh, 0), " s; VECM e VAR em nivel ",
         num(t_vecm, 0), " s; robustez ", num(t_rob, 0), " s.")

# ------------------------------------------------------------------------------------------------
# 10. Figuras
# ------------------------------------------------------------------------------------------------
COR <- "#1f5a91"; COR2 <- "#b5541c"
tema <- theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey90", linewidth = 0.3),
        plot.title = element_text(size = 10, face = "bold"), strip.text = element_text(face = "bold", size = 8.5),
        axis.title = element_text(colour = "grey30"), axis.text = element_text(colour = "grey30"))
salva <- function(fig, nome, w, h) {
  ggsave_safe(file.path(PATHS$figuras, paste0(nome, ".png")), fig, width = w, height = h, dpi = 300, bg = "white")
  ggsave_safe(file.path(PATHS$figuras, paste0(nome, ".pdf")), fig, width = w, height = h,
              device = if (capabilities("cairo")) cairo_pdf else "pdf")
}
banda <- function(f, rot) {
  tibble(h = 0:H, ponto = f$path, lo = apply(f$boot$pvd, 2, q90)[1, ], up = apply(f$boot$pvd, 2, q90)[2, ], esp = rot)
}
rot <- c("Replicado 2002-2019", "(a0) amostra 2003-2019", "(a) INF nominal reconstruido", "(b) INF real",
         "(c0) PVD atual", "(c) exogenas atuais", "Estendida 2003-2025")
d1 <- bind_rows(banda(f_rep, rot[1]), banda(F_CORR$corr_a0, rot[2]), banda(F_CORR$corr_a, rot[3]), banda(F_CORR$corr_b, rot[4]),
                banda(F_CORR$corr_c0, rot[5]), banda(F_CORR$corr_c, rot[6]), banda(f_ext, rot[7])) %>%
  mutate(esp = factor(esp, levels = rot))
fig1 <- ggplot(d1, aes(h, ponto)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_ribbon(aes(ymin = lo, ymax = up), fill = COR, alpha = 0.15) +
  geom_line(colour = COR, linewidth = 0.7) +
  facet_wrap(~esp, ncol = 4) +
  scale_x_continuous(breaks = seq(0, 40, 10)) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.01, decimal.mark = ",")) +
  labs(x = "Trimestres apos o choque", y = "Resposta acumulada de PVD (log10)",
       caption = paste0("VAR(3) em diferenca; choque ortogonal de um desvio padrao em INF (INF antes de PVD). ",
                        "Faixa: IC 90% por bootstrap de residuos, 2000 replicas.")) +
  tema + theme(plot.caption = element_text(size = 8, colour = "grey30", hjust = 0))
salva(fig1, "A5_var_irf_corrigido", 9, 4.6)

d2 <- bind_rows(lapply(names(EXO_VECM), function(am) {
  fv <- F_VECM[[am]]
  fd <- switch(am, "2002-2019 original" = f_rep, "2003-2019" = F_CORR$corr_c, "2003-2025" = f_ext)
  bind_rows(tibble(h = 0:H, ponto = fv$path, lo = apply(fv$boot_pvd, 2, q90)[1, ], up = apply(fv$boot_pvd, 2, q90)[2, ],
                   modelo = "VECM r = 1 (nivel)", amostra = am),
            tibble(h = 0:H, ponto = fd$path, lo = NA_real_, up = NA_real_, modelo = "VAR em diferenca (acumulada)", amostra = am))
})) %>% mutate(amostra = factor(amostra, levels = names(EXO_VECM)))
fig2 <- ggplot(d2, aes(h, ponto, colour = modelo, fill = modelo)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_ribbon(data = filter(d2, !is.na(lo)), aes(ymin = lo, ymax = up), alpha = 0.15, colour = NA) +
  geom_line(linewidth = 0.7) +
  facet_wrap(~amostra, ncol = 3) +
  scale_colour_manual(values = c(COR2, COR), name = NULL) + scale_fill_manual(values = c(COR2, COR), name = NULL) +
  scale_x_continuous(breaks = seq(0, 40, 10)) +
  scale_y_continuous(labels = scales::label_number(accuracy = 0.01, decimal.mark = ",")) +
  labs(x = "Trimestres apos o choque", y = "Resposta de PVD em nivel (log10)",
       caption = "Choque ortogonal em INF (INF antes de PVD). Faixa: IC 90% do VECM por bootstrap de residuos, 2000 replicas.") +
  tema + theme(legend.position = "bottom", plot.caption = element_text(size = 8, colour = "grey30", hjust = 0))
salva(fig2, "A5_var_vecm", 9, 3.6)

d3 <- RES %>% mutate(k = row_number(),
                     lab = paste0(sprintf("%03d", k), "|", modelo, ": ", stringr::str_trunc(especificacao, 75)),
                     lab = factor(lab, levels = rev(lab)), amostra = factor(amostra, levels = unique(amostra)),
                     lo = pmax(ic90_inf, -1.5), hi = pmin(ic90_sup, 2.5))
fig3 <- ggplot(d3, aes(elasticidade, lab, colour = modelo)) +
  geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_vline(xintercept = 0.42, colour = "grey70", linewidth = 0.3, linetype = "dashed") +
  geom_segment(aes(x = lo, xend = hi, y = lab, yend = lab), linewidth = 0.4) +
  geom_point(size = 1.2) +
  facet_grid(amostra ~ ., scales = "free_y", space = "free_y") +
  scale_y_discrete(labels = function(x) sub("^[0-9]+\\|", "", x)) +
  scale_x_continuous(labels = scales::label_number(accuracy = 0.1, decimal.mark = ",")) +
  coord_cartesian(xlim = c(-1.5, 2.5)) +
  labs(x = "Elasticidade de longo prazo (PVD/INF em h = 40)", y = NULL, colour = NULL,
       caption = "Barras: IC 90% por bootstrap (cortadas em -1,5 e 2,5). Linha tracejada: 0,42 da dissertacao.") +
  tema + theme(axis.text.y = element_text(size = 5.5), strip.text.y = element_text(angle = 0, size = 7),
               legend.position = "bottom", plot.caption = element_text(size = 7, colour = "grey30", hjust = 0))
salva(fig3, "A5_var_robustez", 9.5, 15)

d4 <- bind_rows(JOH_ST) %>% filter(ecdet == "trend") %>% mutate(amostra = factor(amostra, levels = names(EXO_VECM)))
fig4 <- ggplot(d4, aes(estat)) +
  geom_histogram(bins = 40, fill = COR, alpha = 0.6) +
  geom_vline(aes(xintercept = obs), colour = COR2, linewidth = 0.6) +
  facet_grid(hipotese ~ amostra, scales = "free") +
  scale_x_continuous(labels = scales::label_number(accuracy = 1, decimal.mark = ",")) +
  labs(x = "Traco de Johansen nas replicas (ecdet trend, K = 3)", y = "Replicas",
       caption = "Bootstrap selvagem (Rademacher) sob H0, 999 replicas. Linha: traco observado.") +
  tema + theme(plot.caption = element_text(size = 8, colour = "grey30", hjust = 0))
salva(fig4, "A5_var_johansen", 9, 4.6)

# ------------------------------------------------------------------------------------------------
# 11. Relatorio
# ------------------------------------------------------------------------------------------------
tab_main <- function(df) df %>% transmute(
  Amostra = amostra, Modelo = modelo, Especificacao = especificacao, n = n, Impacto = num(impacto, 4),
  `PVD h40` = num(resp_acum_40_priv, 4), `INF h40` = num(resp_acum_40_pub, 4), Elasticidade = num(elasticidade, 2),
  `IC 90%` = ic_txt(ic90_inf, ic90_sup), `Granger INF->PVD` = pv(granger_p_pub_priv), `Granger PVD->INF` = pv(granger_p_priv_pub))
jtab <- JOH %>% transmute(Amostra = amostra, ecdet, H0 = hipotese, T = T_efetivo, Traco = num(traco, 2), `Traco RA` = num(traco_ra, 2),
                          `VC 5%` = num(cv5, 2), `VC 10%` = num(cv10, 2), `p bootstrap` = num(p_boot, 3))
dtab <- decisao %>% transmute(Amostra = amostra, `Traco (trend)` = num(traco, 2), `Traco RA` = num(traco_ra, 2), `VC 5%` = num(cv5, 2),
                              `Assintotico a 5%` = ifelse(rej_ass, "rejeita", "nao rejeita"), `Reinsel-Ahn a 5%` = ifelse(rej_ra, "rejeita", "nao rejeita"),
                              `p boot r = 0 (trend)` = num(p_boot, 3), `p boot r = 0 (const)` = num(p_boot_const, 3), Evidencia = evidencia,
                              Decisao = ifelse(vec, "VECM r = 1 baseline; VAR em diferenca como comparacao",
                                               "VAR em diferenca baseline pelo bootstrap; VECM ao lado na A6"))
ptab <- rob %>% filter(principal) %>% transmute(Amostra = amostra, Especificacao = especificacao, n = n, Elasticidade = num(elasticidade, 3),
                                                `IC 90%` = ic_txt(ic90_inf, ic90_sup), `IC inclui zero` = ifelse(ic90_inf <= 0, "sim", "nao"))
ptab <- bind_rows(base_row %>% transmute(Amostra = amostra, Especificacao = paste0("BASELINE: ", especificacao), n = n,
                                         Elasticidade = num(elasticidade, 3), `IC 90%` = ic_txt(ic90_inf, ic90_sup),
                                         `IC inclui zero` = ifelse(ic90_inf <= 0, "sim", "nao")), ptab) %>% arrange(Amostra)
vtab <- RES %>% filter(modelo == "VECM r = 1") %>% transmute(
  Amostra = amostra, Especificacao = especificacao, n = n, Impacto = num(impacto, 4), `PVD h40 (nivel)` = num(resp_acum_40_priv, 4),
  `INF h40 (nivel)` = num(resp_acum_40_pub, 4), `Razao h40` = num(elasticidade, 2), `IC 90%` = ic_txt(ic90_inf, ic90_sup),
  `Vetor (PVD)` = num(elasticidade_beta, 2), `IC 90% vetor` = ic_txt(elast_beta_ic90_inf, elast_beta_ic90_sup),
  `alfa INF (t)` = paste0(num(alfa_inf, 3), " (", num(t_alfa_inf, 2), ")"), `alfa PVD (t)` = paste0(num(alfa_pvd, 3), " (", num(t_alfa_pvd, 2), ")"))
rtab <- rob %>% transmute(Amostra = amostra, Especificacao = especificacao, n = n, Impacto = num(impacto, 4),
                          `PVD h40` = num(resp_acum_40_priv, 4), Elasticidade = num(elasticidade, 2), `IC 90%` = ic_txt(ic90_inf, ic90_sup),
                          `Granger INF->PVD` = pv(granger_p_pub_priv))

md <- c(
  "# A5: VAR e VEC (baseline replicado, corrigido, estendido e robustez)", "",
  paste0("Gerado por R/A5_var.R em ", format(Sys.time(), "%Y-%m-%d %H:%M"), ". Numeros com virgula decimal. Elasticidade de longo prazo = ",
         "resposta acumulada de PVD em h = 40 dividida pela de INF, ao mesmo choque ortogonal em INF (INF antes de PVD). IC 90% por ",
         "bootstrap de residuos (percentil). Tabela completa em data/processed/A5_var_resultados.csv; Johansen em data/processed/A5_johansen.csv."), "",
  "## 1. Baseline replicado e corrigido, correcao a correcao", "",
  md_table(tab_main(RES %>% filter(bloco %in% c("baseline", "baseline corrigido", "baseline estendido")))), "",
  paste0("Alvos do replicado: impacto 0,0118, acumulada de PVD 0,0194, de INF 0,0465 e elasticidade 0,42: reproduzidos (",
         num(f_rep$impacto, 4), "; ", num(f_rep$c_pvd, 4), "; ", num(f_rep$c_inf, 4), "; ", num(f_rep$el, 4), ")."), "",
  "Leitura dos passos: (a0) so muda a amostra (niveis a partir de 2003T1, perde 2002); (a) troca o INF do arquivo pela reconstrucao nominal; ",
  "(b) passa a INF real; (c0) troca o PVD pelo indice atual do Ipea; (c) troca o PIB pela safra atual e a Selic pela serie do BCB (identica ao JUR).", "",
  "## 2. Johansen e escolha VAR x VEC", "",
  md_table(jtab), "",
  "Traco RA: com correcao de Reinsel-Ahn, (T - pK)/T. VC: valores criticos assintoticos do urca. p bootstrap: bootstrap selvagem de Cavaliere, Rahbek e Taylor (2012), 999 replicas.", "",
  md_table(dtab), "",
  "Quando as leituras divergem, prevalece o bootstrap: (i) nas amostras 2002-2019 e 2003-2019 a DUM da dissertacao entra em nivel na parte irrestrita do VECM, o que gera tendencia quebrada nos niveis e muda a distribuicao assintotica do traco (Johansen, Mosconi e Nielsen, 2000), de modo que os valores criticos tabelados, com ou sem Reinsel-Ahn, nao valem; o bootstrap gera os dados com a mesma DUM; (ii) com T de 64 a 88 o teste assintotico rejeita demais, e Reinsel-Ahn e so um fator de escala. Evidencia limitrofe: o bootstrap nao rejeita a 5%, mas o assintotico, Reinsel-Ahn, o bootstrap a 10% ou o caso ecdet const rejeitam. Em 2003-2019 o traco assintotico e o corrigido por Reinsel-Ahn rejeitam r = 0 a 5%; so o bootstrap nao rejeita. A escolha pesa no numero, e a A6 deve mostrar o VECM ao lado do VAR em diferenca.", "",
  "## 3. VECM com r = 1 e VAR em nivel", "",
  md_table(vtab), "",
  "Razao h40: resposta de PVD em nivel em h = 40 sobre a de INF (nivel = acumulada da diferenca). Vetor (PVD): elasticidade de longo prazo do vetor de cointegracao normalizado em PVD (PVD = elasticidade x INF + tendencia + erro estacionario). alfa: carregamentos do termo de correcao com beta normalizado em PVD (t de MQO do cajorls entre parenteses); alfa negativo em PVD indica que PVD corrige desvios do equilibrio, alfa positivo em INF indica que INF sobe quando PVD esta acima do equilibrio.", "",
  md_table(tab_main(RES %>% filter(modelo == "VAR em nivel"))), "",
  "No VAR em nivel, as colunas de Granger trazem o teste de Toda-Yamamoto; o Granger padrao esta na coluna obs do CSV.", "",
  "## 4. Robustez principal (PIB em taxa, Cholesky invertida, 2 e 4 defasagens, subamostras, dummies)", "",
  paste0("Estas sao as robustezes pedidas no briefing e a sintese da robustez. IC de 90% inclui zero: ",
         paste(vapply(c("2003-2019", "2003-2025"), function(am) {
           z <- ptab %>% filter(Amostra == am | (am == "2003-2025" & Amostra %in% c("ate 2014T4", "de 2015T1")), `IC inclui zero` == "sim")
           paste0(am, ": ", if (nrow(z)) paste(z$Especificacao, collapse = "; ") else "nenhuma")
         }, ""), collapse = ". "), "."), "",
  md_table(ptab), "",
  "## 5. Robustez do VAR em diferenca, todas as especificacoes (1000 replicas)", "",
  md_table(rtab), "",
  "## 6. Resumo das demais variantes (controles, Selic media, variantes de INF da A3, exclusao de 2016T4-2018T1, sem DUM)", "",
  "Estas variantes sao quase iguais entre si e nao resumem a robustez; a robustez principal esta na secao 4.", "",
  md_table(resumo_rob %>% transmute(Amostra = amostra, Especificacoes = n_esp, `Elasticidade min` = num(min_el, 2),
                                    `Elasticidade max` = num(max_el, 2), Mediana = num(med_el, 2), `IC acima de zero` = n_ic_pos,
                                    `Granger a 5%` = n_g5))
)
write_lines_safe(md, file.path(PATHS$results, "A5_var.md"))

log_part(ETAPA, "- Saidas: ", f_res, " (", nrow(RES), " especificacoes), data/processed/A5_johansen.csv, results/A5_var.md, ",
         "results/figuras/A5_var_irf_corrigido, A5_var_vecm, A5_var_robustez e A5_var_johansen (png e pdf). Tempo total: ",
         num(as.numeric(difftime(Sys.time(), t_ini, units = "secs")), 0), " s.")
save_session_info("A5_var")
cat("A5_var concluido\n")
