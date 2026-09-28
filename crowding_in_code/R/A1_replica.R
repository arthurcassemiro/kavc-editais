# A1. Replica em R do modelo final da dissertacao (ultima secao de data/original/VAR_Trimestral.Rmd).
# Modelo: vars::VAR(diff(infmeq), p = 3, type = "both", exogen = diff(exo)), Cholesky com INF antes de PVD.
# Referencia em Python: scripts/replica_original.py e scripts/robustez_rapida.py.
# Rodar da raiz do projeto: Rscript R/A1_replica.R

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(vars)
  library(urca)
  library(lmtest)
  library(patchwork)
})

ETAPA <- "A1"
log_reset(ETAPA)
t_ini <- Sys.time()

# ------------------------------------------------------------------------------------------------
# Helpers de formatacao (virgula decimal)
# ------------------------------------------------------------------------------------------------
num <- function(x, d = 4) formatC(x, format = "f", digits = d, decimal.mark = ",")
sig <- function(x, d = 6) formatC(signif(x, d), format = "fg", digits = d, decimal.mark = ",")
tnum <- function(x, d = 4) gsub(",", "{,}", num(x, d), fixed = TRUE)
pval <- function(p) ifelse(p < 0.0001, "< 0,0001", num(p, 4))
tpval <- function(p) ifelse(p < 0.0001, "$<$ 0{,}0001", tnum(p, 4))

md_table <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- vapply(seq_len(nrow(df)), function(i) paste0("| ", paste(unlist(df[i, ]), collapse = " | "), " |"), "")
  c(hdr, sep, rows, "")
}

# Compara com o alvo: igual ao arredondar, igual so ao truncar, ou diferente.
compara <- function(obtido, alvo, casas) {
  arred <- round(obtido, casas)
  trunc_ <- trunc(obtido * 10^casas) / 10^casas
  if (abs(arred - alvo) < 1e-9) return("sim")
  if (abs(trunc_ - alvo) < 1e-9) return(sprintf("sim, por truncamento (arredondado: %s)", num(arred, casas)))
  "nao"
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

TRIM <- q_seq("2002Q1", "2019Q4")
infmeq <- ts_from_q(as.matrix(end_df), TRIM)
exo <- ts_from_q(as.matrix(exo_df), TRIM)

log_part(ETAPA, "- Dados: ", arq_end, " (INF e PVD em log10) e ", arq_exo,
         " (PIB em variacao trimestral, JUR = Selic, DUM). 72 linhas cada, sem coluna de data; ",
         "datas atribuidas de 2002Q1 a 2019Q4, como no Rmd (ts com start = c(2002, 1)).")

# Conferencia do alinhamento das datas com o Apendice A da dissertacao (arquivo com coluna de trimestre)
ap <- read.csv("data/dados_dissertacao_apendiceA.csv")
stopifnot(identical(ap$trimestre, TRIM))
dif_selic <- max(abs(ap$selic - exo[, "JUR"]))
dif_pib <- max(abs(ap$cpib_pct / 100 - exo[, "PIB"]))
cor_pvd <- cor(diff(log10(ap$imeq_indice)), diff(infmeq[, "PVD"]))
log_part(ETAPA, "- Alinhamento das datas conferido com data/dados_dissertacao_apendiceA.csv (coluna trimestre 2002Q1 a 2019Q4): ",
         "diferenca maxima Selic x JUR = ", sig(dif_selic, 3), "; PIB x cpib_pct/100 = ", sig(dif_pib, 3),
         "; correlacao entre diff(log10(imeq_indice)) e diff(PVD) = ", num(cor_pvd, 4), ".")

# Datas da dummy no arquivo
datas_dum <- TRIM[exo_df$DUM == 1]
blocos_dum <- split(datas_dum, cumsum(c(1, diff(match(datas_dum, TRIM)) != 1)))
txt_dum <- paste(vapply(blocos_dum, function(b) if (length(b) > 1) paste0(b[1], "-", b[length(b)]) else b[1], ""),
                 collapse = " e ")
dd <- diff(exo_df$DUM)
pulsos <- paste(sprintf("%s: %+d", TRIM[-1][dd != 0], dd[dd != 0]), collapse = "; ")
log_part(ETAPA, "- Dummy DUM = 1 no arquivo em ", txt_dum, " (", length(datas_dum), " trimestres). ",
         "Confere com o esperado (2018Q2-2019Q1 e 2019Q3-2019Q4). Com exogen = diff(exo) a dummy vira pulsos: ", pulsos, ".")

# Outros arquivos da pasta original, so para registro
log_part(ETAPA, "- data/original/0124_tri_estmeq.txt e 0224_inexo.txt nao entram no modelo final: o primeiro nao e ",
         "a diferenca do 0224_tri_estmeq; o segundo tem PIB em log, JUR, CAM e DUM (nele exo[, 3] seria CAM).")

# ------------------------------------------------------------------------------------------------
# 2. Modelo baseline
# ------------------------------------------------------------------------------------------------
dinfmeq <- diff(infmeq)
dexo <- diff(exo)
modelo <- vars::VAR(dinfmeq, p = 3, type = "both", exogen = dexo)
sm <- summary(modelo)
S <- sm$covres
R <- sm$corres
log_part(ETAPA, "- Baseline: vars::VAR(diff(infmeq), p = 3, type = \"both\", exogen = diff(exo)); ",
         modelo$obs, " observacoes efetivas (", TRIM[2 + modelo$p], " a 2019Q4). Ordem de Cholesky: INF, PVD.")

# IRF acumulada com bootstrap do vars (2000 replicas, IC 90%, seed 42)
t0 <- Sys.time()
irf_boot <- vars::irf(modelo, impulse = "INF", response = c("INF", "PVD"), n.ahead = 40, cumulative = TRUE,
                      boot = TRUE, runs = 2000, ci = 0.90, seed = 42)
t_irf <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

cum <- irf_boot$irf$INF
lo <- irf_boot$Lower$INF
up <- irf_boot$Upper$INF
impacto <- cum[1, "PVD"]
acum_pvd <- cum[41, "PVD"]
acum_inf <- cum[41, "INF"]
elast <- acum_pvd / acum_inf

# ------------------------------------------------------------------------------------------------
# 3. Bootstrap proprio para a elasticidade de longo prazo
# Desenho igual ao de vars:::.boot: recursivo, deterministicos e exogenas fixos, p valores iniciais
# observados, residuos centrados reamostrados com reposicao. Mesma semente e mesma sequencia de sorteios,
# de modo que as replicas coincidem com as do irf(); aqui guardamos a razao em cada replica.
# ------------------------------------------------------------------------------------------------
boot_elasticidade <- function(mod, exog, runs = 2000, seed = 42, h = 40) {
  set.seed(seed)
  p <- mod$p; K <- mod$K; n <- mod$obs; tot <- mod$totobs
  B <- vars::Bcoef(mod)
  Zdet <- as.matrix(mod$datamat[, (K * (p + 1) + 1):ncol(mod$datamat), drop = FALSE])  # const, trend, exogenas
  U <- scale(resid(mod), scale = FALSE)
  y0 <- mod$y
  # Psi() nao traz nomes: [resposta, impulso, h], na ordem das colunas de y
  i_inf <- which(colnames(y0) == "INF"); i_pvd <- which(colnames(y0) == "PVD")
  out <- matrix(NA_real_, runs, 4, dimnames = list(NULL, c("impacto_PVD", "acum40_PVD", "acum40_INF", "elasticidade")))
  for (r in seq_len(runs)) {
    idx <- sample(seq_len(n), replace = TRUE)
    ys <- matrix(0, tot, K, dimnames = list(NULL, colnames(y0)))
    ys[1:p, ] <- y0[1:p, ]
    for (t in seq_len(n)) {
      lags <- c(t(ys[(t + p - 1):t, , drop = FALSE]))  # y_{t-1}, ..., y_{t-p}
      ys[t + p, ] <- B %*% c(lags, Zdet[t, ]) + U[idx[t], ]
    }
    mb <- vars::VAR(ys, p = p, type = mod$type, exogen = exog)
    ps <- vars::Psi(mb, nstep = h)
    c_pvd <- sum(ps[i_pvd, i_inf, ])
    c_inf <- sum(ps[i_inf, i_inf, ])
    out[r, ] <- c(ps[i_pvd, i_inf, 1], c_pvd, c_inf, c_pvd / c_inf)
  }
  out
}

t0 <- Sys.time()
bt <- boot_elasticidade(modelo, dexo, runs = 2000, seed = 42, h = 40)
t_boot <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
bt_df <- tibble(replica = seq_len(nrow(bt)), as_tibble(bt))
write_csv_safe(bt_df, file.path(PATHS$processed, "A1_bootstrap.csv"))

q_el <- quantile(bt[, "elasticidade"], c(0.05, 0.95), type = 7)
q_pvd <- quantile(bt[, "acum40_PVD"], c(0.05, 0.95), type = 7)
q_inf <- quantile(bt[, "acum40_INF"], c(0.05, 0.95), type = 7)
bate_vars <- isTRUE(all.equal(unname(q_pvd), unname(c(lo[41, "PVD"], up[41, "PVD"])), tolerance = 1e-10)) &&
  isTRUE(all.equal(unname(q_inf), unname(c(lo[41, "INF"], up[41, "INF"])), tolerance = 1e-10))
el_neg <- mean(bt[, "elasticidade"] < 0)
den_neg <- mean(bt[, "acum40_INF"] <= 0)
pvd_neg <- mean(bt[, "acum40_PVD"] < 0)

log_part(ETAPA, "- Bootstrap do vars: irf(impulse = \"INF\", response = c(\"INF\", \"PVD\"), n.ahead = 40, cumulative = TRUE, ",
         "boot = TRUE, runs = 2000, ci = 0,90, seed = 42); ", num(t_irf, 0), " s. IC 90% da resposta acumulada de PVD em h = 40: [",
         num(lo[41, "PVD"]), "; ", num(up[41, "PVD"]), "].")
log_part(ETAPA, "- Bootstrap proprio de residuos (2000 replicas; recursivo; constante, tendencia e exogenas fixas; ",
         "3 valores iniciais observados; residuos centrados; set.seed(42) e mesmos sorteios de vars:::.boot). ",
         "Percentis 5% e 95% das respostas acumuladas em h = 40 ", ifelse(bate_vars, "coincidem", "NAO coincidem"),
         " com as bandas do irf(), o que confere a implementacao. Replicas em data/processed/A1_bootstrap.csv.")
log_part(ETAPA, "- Elasticidade de longo prazo (razao das respostas acumuladas de PVD e INF em h = 40): ", num(elast, 4),
         "; IC 90% percentil [", num(q_el[1], 2), "; ", num(q_el[2], 2), "] com 2000 replicas (Python, 500 replicas: [0,07; 0,67]). ",
         "Replicas com elasticidade negativa: ", num(100 * el_neg, 1), "%; com resposta acumulada de INF <= 0: ",
         num(100 * den_neg, 1), "%.")

# ------------------------------------------------------------------------------------------------
# 4. Diagnosticos
# ------------------------------------------------------------------------------------------------
pt_asy <- serial.test(modelo, lags.pt = 16, type = "PT.asymptotic")$serial
pt_adj <- serial.test(modelo, lags.pt = 16, type = "PT.adjusted")$serial
bg <- serial.test(modelo, lags.bg = 5, type = "BG")$serial
es <- serial.test(modelo, lags.bg = 5, type = "ES")$serial
LAGS_ARCH <- 5
arch <- arch.test(modelo, lags.multi = LAGS_ARCH, multivariate.only = TRUE)$arch.mul
norm_t <- normality.test(modelo, multivariate.only = FALSE)
raizes <- roots(modelo, modulus = TRUE)
vsel <- VARselect(dinfmeq, lag.max = 8, type = "both", exogen = dexo)

diag_row <- function(nome, ht, obs) {
  tibble(teste = nome, estatistica = unname(ht$statistic)[1],
         gl = paste(num(unname(ht$parameter), 0), collapse = "; "),
         p = unname(ht$p.value)[1], obs = obs)
}
diag <- bind_rows(
  diag_row("Portmanteau assintotico (lags.pt = 16)", pt_asy, "qui-quadrado"),
  diag_row("Portmanteau ajustado (lags.pt = 16)", pt_adj, "qui-quadrado"),
  diag_row("Breusch-Godfrey LM (lags.bg = 5)", bg, "qui-quadrado"),
  diag_row("Edgerton-Shukur F (lags.bg = 5)", es, "F"),
  diag_row(sprintf("ARCH-LM multivariado (lags.multi = %d)", LAGS_ARCH), arch, "qui-quadrado"),
  diag_row("Jarque-Bera multivariado", norm_t$jb.mul$JB, "qui-quadrado"),
  diag_row("Assimetria multivariada", norm_t$jb.mul$Skewness, "qui-quadrado"),
  diag_row("Curtose multivariada", norm_t$jb.mul$Kurtosis, "qui-quadrado"),
  diag_row("Jarque-Bera univariado, INF", norm_t$jb.uni$INF, "qui-quadrado"),
  diag_row("Jarque-Bera univariado, PVD", norm_t$jb.uni$PVD, "qui-quadrado")
)

log_part(ETAPA, "- Diagnosticos (H0 de cada teste: ausencia de autocorrelacao, de ARCH, normalidade): ",
         paste(sprintf("%s: estat. %s, p = %s", diag$teste, num(diag$estatistica, 2), pval(diag$p)), collapse = "; "), ".")
log_part(ETAPA, "- No Rmd, serial.test(type = \"BG\"/\"ES\") foi chamado com lags.pt = 16, que esses testes ignoram; ",
         "o lag efetivo era o padrao lags.bg = 5, o mesmo usado aqui. ARCH multivariado com lags.multi = ", LAGS_ARCH,
         " (padrao do vars, o mesmo do Rmd).")
log_part(ETAPA, "- Raizes do polinomio caracteristico (modulos): ", paste(num(raizes, 4), collapse = ", "),
         ". Todas menores que 1: ", ifelse(all(raizes < 1), "sim", "nao"), ".")
log_part(ETAPA, "- VARselect(lag.max = 8, type = \"both\", exogen = diff(exo)): AIC = ", vsel$selection["AIC(n)"],
         ", HQ = ", vsel$selection["HQ(n)"], ", SC = ", vsel$selection["SC(n)"], ", FPE = ", vsel$selection["FPE(n)"],
         ". p = 3 e a escolha de AIC, HQ e FPE; SC prefere 2.")

# ------------------------------------------------------------------------------------------------
# 5. Granger
# ------------------------------------------------------------------------------------------------
modelo_nivel <- vars::VAR(infmeq, p = 3, type = "both", exogen = exo)
gr <- function(mod, causa, rotulo) {
  g <- causality(mod, cause = causa)$Granger
  efeito <- setdiff(colnames(mod$y), causa)
  tibble(modelo = rotulo, hipotese = paste0(causa, " -> ", efeito), F = unname(g$statistic)[1],
         gl1 = unname(g$parameter)[1], gl2 = unname(g$parameter)[2], p = unname(g$p.value)[1])
}
granger <- bind_rows(
  gr(modelo, "INF", "VAR em diferenca (baseline)"),
  gr(modelo, "PVD", "VAR em diferenca (baseline)"),
  gr(modelo_nivel, "INF", "VAR em nivel, exo em nivel"),
  gr(modelo_nivel, "PVD", "VAR em nivel, exo em nivel")
)
g_d_inf <- granger %>% filter(modelo == "VAR em diferenca (baseline)", hipotese == "INF -> PVD")
g_d_pvd <- granger %>% filter(modelo == "VAR em diferenca (baseline)", hipotese == "PVD -> INF")
g_n_inf <- granger %>% filter(modelo == "VAR em nivel, exo em nivel", hipotese == "INF -> PVD")
g_n_pvd <- granger %>% filter(modelo == "VAR em nivel, exo em nivel", hipotese == "PVD -> INF")

# Variantes para tentar localizar o p = 0,56 reportado na dissertacao para PVD -> INF
gt <- function(formula, ordem, dados) { x <- grangertest(formula, order = ordem, data = dados); c(x$F[2], x$Df[2] * -1, x$Res.Df[1], x$`Pr(>F)`[2]) }
g_hc <- function(mod) { g <- causality(mod, cause = "PVD", vcov. = sandwich::vcovHC(mod))$Granger; c(g$statistic, g$parameter, g$p.value) }
v4 <- vars::VAR(dinfmeq, p = 4, type = "both", exogen = dexo)
g_v4 <- causality(v4, cause = "PVD")$Granger
var_pvd <- rbind(
  "grangertest(INF ~ PVD, order = 4), niveis, sem exogenas (chamada do Rmd)" = gt(INF ~ PVD, 4, as.data.frame(infmeq)),
  "grangertest(INF ~ PVD, order = 3), niveis, sem exogenas" = gt(INF ~ PVD, 3, as.data.frame(infmeq)),
  "grangertest(INF ~ PVD, order = 4), diferencas, sem exogenas" = gt(INF ~ PVD, 4, as.data.frame(dinfmeq)),
  "causality, VAR em nivel, vcov HC" = g_hc(modelo_nivel),
  "causality, VAR em diferenca, vcov HC" = g_hc(modelo),
  "causality, VAR em diferenca com p = 4" = c(g_v4$statistic, g_v4$parameter, g_v4$p.value)
)
colnames(var_pvd) <- c("F", "gl1", "gl2", "p")

log_part(ETAPA, "- Granger no VAR em diferenca: INF -> PVD F = ", num(g_d_inf$F, 2), " (gl ", g_d_inf$gl1, " e ", g_d_inf$gl2,
         "), p = ", num(g_d_inf$p, 3), "; PVD -> INF F = ", num(g_d_pvd$F, 2), ", p = ", num(g_d_pvd$p, 3), ".")
log_part(ETAPA, "- Granger no VAR em nivel (VAR(infmeq, p = 3, type = \"both\", exogen = exo)): INF -> PVD F = ", num(g_n_inf$F, 2),
         " (gl ", g_n_inf$gl1, " e ", g_n_inf$gl2, "), p = ", num(g_n_inf$p, 3), "; PVD -> INF F = ", num(g_n_pvd$F, 2),
         ", p = ", num(g_n_pvd$p, 3), ". Os graus de liberdade 3 e 116 confirmam que a Tabela 12 vem deste VAR.")
log_part(ETAPA, "- Correcao ao LOG anterior: o par PVD -> INF F = 1,91, p = 0,13 e do VAR em nivel, nao do VAR em diferenca. ",
         "No VAR em diferenca, PVD -> INF tem F = ", num(g_d_pvd$F, 2), " e p = ", num(g_d_pvd$p, 2), ". ",
         "Nenhuma das variantes testadas (grangertest com 3 e 4 lags, VAR com vcov HC, VAR com p = 4) reproduz o p = 0,56 da dissertacao.")

# ------------------------------------------------------------------------------------------------
# 6. Johansen
# ------------------------------------------------------------------------------------------------
dum_rmd <- exo[, "DUM", drop = FALSE]  # no Rmd: dumvar = exo[, 3], que no 0124_inexo e DUM
grade <- expand_grid(ecdet = c("const", "trend"), K = 2:4, spec = c("transitory", "longrun"),
                     dumvar = c("nenhuma", "exo (PIB, JUR, DUM)", "exo[, 3] = DUM (como no Rmd)"))
joh <- pmap_dfr(grade, function(ecdet, K, spec, dumvar) {
  dv <- switch(dumvar, "nenhuma" = NULL, "exo (PIB, JUR, DUM)" = exo, "exo[, 3] = DUM (como no Rmd)" = dum_rmd)
  cj <- ca.jo(infmeq, type = "trace", ecdet = ecdet, K = K, spec = spec, dumvar = dv)
  i0 <- grep("r = 0", rownames(cj@cval), fixed = TRUE)
  i1 <- grep("r <= 1", rownames(cj@cval), fixed = TRUE)
  tibble(ecdet, K, spec, dumvar, traco_r0 = cj@teststat[i0], cv10_r0 = cj@cval[i0, "10pct"],
         cv5_r0 = cj@cval[i0, "5pct"], cv1_r0 = cj@cval[i0, "1pct"], traco_r1 = cj@teststat[i1], cv5_r1 = cj@cval[i1, "5pct"])
})
joh <- joh %>% mutate(bate = abs(round(traco_r0, 2) - 25.01) < 1e-9 & abs(cv5_r0 - 25.32) < 1e-9)
joh_ok <- joh %>% filter(bate)

if (nrow(joh_ok) > 0) {
  j1 <- joh_ok[1, ]
  log_part(ETAPA, "- Johansen: ", nrow(joh), " configuracoes testadas (ecdet const/trend, K 2 a 4, spec transitory/longrun, ",
           "dumvar nenhuma/exo/DUM). Reproduzem traco 25,01 contra 25,32 (r = 0): ",
           paste(sprintf("ecdet = %s, K = %d, spec = %s, dumvar = %s", joh_ok$ecdet, joh_ok$K, joh_ok$spec, joh_ok$dumvar), collapse = "; "),
           ". E a chamada do Rmd (ca.jo(infmeq, type = \"trace\", ecdet = \"trend\", K = 2, spec = \"longrun\", dumvar = exo[, 3])). ",
           "spec nao altera a estatistica traco. Traco ", num(j1$traco_r0, 2), " < ", num(j1$cv5_r0, 2),
           ": nao rejeita r = 0 a 5%; rejeita a 10% (valor critico ", num(j1$cv10_r0, 2), "). Para r <= 1: ", num(j1$traco_r1, 2),
           " contra ", num(j1$cv5_r1, 2), ". Com dumvar = exo completo a estatistica e ",
           num(joh %>% filter(ecdet == "trend", K == 2, dumvar == "exo (PIB, JUR, DUM)") %>% pull(traco_r0) %>% first(), 2), ".")
} else {
  log_part(ETAPA, "- Johansen: nenhuma das ", nrow(joh), " configuracoes reproduz traco 25,01 contra 25,32.")
}

# ------------------------------------------------------------------------------------------------
# 7. Decomposicao da variancia
# ------------------------------------------------------------------------------------------------
fv <- fevd(modelo, n.ahead = 40)
H_FEVD <- c(4, 8, 20, 40)
fevd_tab <- tibble(h = H_FEVD,
                   INF_por_INF = 100 * fv$INF[H_FEVD, "INF"], INF_por_PVD = 100 * fv$INF[H_FEVD, "PVD"],
                   PVD_por_INF = 100 * fv$PVD[H_FEVD, "INF"], PVD_por_PVD = 100 * fv$PVD[H_FEVD, "PVD"])
log_part(ETAPA, "- FEVD da variacao de PVD explicada pelo choque de INF: ",
         paste(sprintf("h = %d: %s%%", fevd_tab$h, num(fevd_tab$PVD_por_INF, 1)), collapse = "; "), ".")

# ------------------------------------------------------------------------------------------------
# 8. Tabela de alvos
# ------------------------------------------------------------------------------------------------
alvos <- tribble(
  ~item, ~alvo, ~casas, ~obtido,
  "Impacto ortogonal de INF em PVD (h = 0)", 0.0118, 4, impacto,
  "Resposta acumulada de PVD, h = 40", 0.0194, 4, acum_pvd,
  "Resposta acumulada de INF, h = 40", 0.0465, 4, acum_inf,
  "Elasticidade de longo prazo (PVD/INF acumulados, h = 40)", 0.42, 2, elast,
  "var(u_INF)", 0.0039, 4, S["INF", "INF"],
  "cov(u_INF, u_PVD)", 0.0007, 4, S["INF", "PVD"],
  "var(u_PVD)", 0.0008, 4, S["PVD", "PVD"],
  "corr(u_INF, u_PVD)", 0.405, 3, R["INF", "PVD"],
  "Granger INF -> PVD, VAR em diferenca, F", 3.27, 2, g_d_inf$F,
  "Granger INF -> PVD, VAR em diferenca, p", 0.024, 3, g_d_inf$p,
  "Granger PVD -> INF, VAR em diferenca, F", 1.91, 2, g_d_pvd$F,
  "Granger PVD -> INF, VAR em diferenca, p", 0.13, 2, g_d_pvd$p,
  "Granger PVD -> INF, VAR em nivel, F", 1.91, 2, g_n_pvd$F,
  "Granger PVD -> INF, VAR em nivel, p", 0.13, 2, g_n_pvd$p,
  "Johansen, traco r = 0 (config. do Rmd)", 25.01, 2, if (nrow(joh_ok)) joh_ok$traco_r0[1] else NA_real_,
  "Johansen, valor critico 5% r = 0", 25.32, 2, if (nrow(joh_ok)) joh_ok$cv5_r0[1] else NA_real_
) %>% mutate(reproduz = pmap_chr(list(obtido, alvo, casas), compara))

for (i in seq_len(nrow(alvos))) {
  log_part(ETAPA, "- Alvo: ", alvos$item[i], ": alvo ", num(alvos$alvo[i], alvos$casas[i]), ", obtido ", num(alvos$obtido[i], 4),
           " (", sig(alvos$obtido[i], 6), "); reproduz: ", alvos$reproduz[i], ".")
}
log_part(ETAPA, "- Os alvos da matriz de covariancia (0,0039; 0,0008; 0,405) batem so por truncamento: arredondando, ",
         "seriam 0,0040; 0,0009 e 0,406. As medidas de resposta ao impulso batem por arredondamento.")

# ------------------------------------------------------------------------------------------------
# 9. Figura: IRF acumulada com IC 90%
# ------------------------------------------------------------------------------------------------
irf_df <- bind_rows(lapply(c("PVD", "INF"), function(v)
  tibble(h = 0:40, resposta = v, ponto = cum[, v], ic90_inf = lo[, v], ic90_sup = up[, v])))
write_csv_safe(irf_df, file.path(PATHS$processed, "A1_irf_acumulada.csv"))

COR <- "#2a78d6"
painel <- function(v, titulo) {
  d <- filter(irf_df, resposta == v)
  ggplot(d, aes(h, ponto)) +
    geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
    geom_ribbon(aes(ymin = ic90_inf, ymax = ic90_sup), fill = COR, alpha = 0.15) +
    geom_line(colour = COR, linewidth = 0.8) +
    scale_x_continuous(breaks = seq(0, 40, 8), expand = expansion(mult = c(0.01, 0.02))) +
    scale_y_continuous(labels = scales::label_number(accuracy = 0.01, decimal.mark = ",")) +
    labs(title = titulo, x = "Trimestres após o choque", y = "Resposta acumulada (log10)") +
    theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "grey90", linewidth = 0.3),
          plot.title = element_text(size = 10, face = "bold"),
          axis.title = element_text(colour = "grey30"), axis.text = element_text(colour = "grey30"))
}
fig <- painel("PVD", "Investimento privado em máquinas (PVD)") +
  painel("INF", "Investimento público (INF)") +
  plot_annotation(caption = paste0("Choque ortogonal de um desvio padrão em INF (Cholesky, INF antes de PVD). ",
                                   "Faixa: IC 90% por bootstrap de resíduos, 2000 réplicas."),
                  theme = theme(plot.caption = element_text(size = 8, colour = "grey30", hjust = 0)))
f_png <- file.path(PATHS$figuras, "A1_irf_acumulada.png")
f_pdf <- file.path(PATHS$figuras, "A1_irf_acumulada.pdf")
ggsave(f_png, fig, width = 8, height = 3.4, dpi = 300, bg = "white")
ggsave(f_pdf, fig, width = 8, height = 3.4, device = if (capabilities("cairo")) cairo_pdf else "pdf")

# ------------------------------------------------------------------------------------------------
# 10. Relatorio em markdown
# ------------------------------------------------------------------------------------------------
H_TAB <- c(0, 1, 2, 4, 8, 12, 20, 40)
irf_tab <- tibble(h = H_TAB,
                  PVD = num(cum[H_TAB + 1, "PVD"]), `IC90 PVD` = sprintf("[%s; %s]", num(lo[H_TAB + 1, "PVD"]), num(up[H_TAB + 1, "PVD"])),
                  INF = num(cum[H_TAB + 1, "INF"]), `IC90 INF` = sprintf("[%s; %s]", num(lo[H_TAB + 1, "INF"]), num(up[H_TAB + 1, "INF"])),
                  `PVD/INF` = num(cum[H_TAB + 1, "PVD"] / cum[H_TAB + 1, "INF"], 2))

vsel_tab <- as_tibble(t(vsel$criteria), rownames = "p") %>%
  mutate(across(c(`AIC(n)`, `HQ(n)`, `SC(n)`), ~ num(.x, 4)), `FPE(n)` = formatC(`FPE(n)`, format = "e", digits = 4, decimal.mark = ","))

md <- c(
  "# A1. Replica em R do modelo final da dissertacao",
  "",
  sprintf("Gerado por `R/A1_replica.R` em %s. Numeros com virgula decimal. Respostas em log10 (os dados estao em log10).", format(Sys.time(), "%Y-%m-%d %H:%M")),
  "",
  "## Especificacao",
  "",
  "- Dados: `data/original/0224_tri_estmeq.txt` (INF e PVD em log10) e `data/original/0124_inexo.txt` (PIB em variacao trimestral, JUR = Selic, DUM), 72 trimestres de 2002Q1 a 2019Q4.",
  "- Modelo: `vars::VAR(diff(infmeq), p = 3, type = \"both\", exogen = diff(exo))`, 68 observacoes efetivas (2003Q1 a 2019Q4). Choque ortogonal por Cholesky com INF antes de PVD.",
  sprintf("- Datas conferidas com `data/dados_dissertacao_apendiceA.csv` (que tem a coluna de trimestre): Selic identica ao JUR (diferenca maxima %s), PIB identico a cpib_pct/100, correlacao de diff(log10(imeq_indice)) com diff(PVD) = %s.", sig(dif_selic, 3), num(cor_pvd, 4)),
  sprintf("- Dummy: DUM = 1 em %s. Confere com o esperado. Em diferenca vira pulsos (%s).", txt_dum, pulsos),
  "",
  "## Comparacao com os alvos",
  "",
  md_table(alvos %>% transmute(Item = item, Alvo = num(alvo, casas), `Obtido (4 casas)` = num(obtido, 4),
                               `Obtido (6 alg.)` = sig(obtido, 6), Reproduz = reproduz)),
  "Notas:",
  "",
  "- Os alvos da matriz de covariancia batem por truncamento, nao por arredondamento (0,003984 vira 0,0039; 0,000851 vira 0,0008; 0,4056 vira 0,405). As respostas ao impulso batem por arredondamento.",
  sprintf("- O par F = 1,91 e p = 0,13 para PVD -> INF nao vem do VAR em diferenca: nele F = %s e p = %s. Vem do VAR em nivel (gl %d e %d). O LOG anterior atribuia esse par ao VAR em diferenca; corrigido no log da A1.",
          num(g_d_pvd$F, 2), num(g_d_pvd$p, 3), g_n_pvd$gl1, g_n_pvd$gl2),
  sprintf("- Conversao so para leitura: o impacto de %s em log10 equivale a %s em log natural (cerca de %s%% no nivel de PVD); o choque de um desvio padrao eleva INF em %s em log10 no impacto. A elasticidade e a razao entre respostas na mesma unidade e nao depende da base do log.",
          num(impacto), num(impacto * log(10)), num(100 * (10^impacto - 1), 1), num(cum[1, "INF"])),
  "",
  "## Bootstrap",
  "",
  "`irf(modelo, impulse = \"INF\", response = c(\"INF\", \"PVD\"), n.ahead = 40, cumulative = TRUE, boot = TRUE, runs = 2000, ci = 0.90, seed = 42)`; bandas nos percentis 5% e 95%.",
  "",
  "Bootstrap proprio de residuos para a elasticidade: 2000 replicas, desenho recursivo, constante, tendencia e exogenas fixas, 3 valores iniciais observados, residuos centrados, `set.seed(42)` e a mesma sequencia de sorteios de `vars:::.boot`. Em cada replica, elasticidade = resposta acumulada de PVD em h = 40 / resposta acumulada de INF em h = 40. Replicas em `data/processed/A1_bootstrap.csv`.",
  "",
  sprintf("Conferencia: os percentis 5%% e 95%% das respostas acumuladas do bootstrap proprio %s com as bandas do `irf()`.", ifelse(bate_vars, "coincidem exatamente", "NAO coincidem")),
  "",
  md_table(tibble(
    Medida = c("Impacto de INF em PVD (h = 0)", "Resposta acumulada de PVD (h = 40)", "Resposta acumulada de INF (h = 40)", "Elasticidade de longo prazo"),
    Ponto = c(num(impacto), num(acum_pvd), num(acum_inf), num(elast, 4)),
    `IC 90% (2000 replicas)` = c(sprintf("[%s; %s]", num(lo[1, "PVD"]), num(up[1, "PVD"])),
                                 sprintf("[%s; %s]", num(lo[41, "PVD"]), num(up[41, "PVD"])),
                                 sprintf("[%s; %s]", num(lo[41, "INF"]), num(up[41, "INF"])),
                                 sprintf("[%s; %s]", num(q_el[1], 2), num(q_el[2], 2))),
    `Mediana bootstrap` = c(num(median(bt[, "impacto_PVD"])), num(median(bt[, "acum40_PVD"])), num(median(bt[, "acum40_INF"])),
                            num(median(bt[, "elasticidade"]), 2)))),
  sprintf("Python com 500 replicas: elasticidade IC 90%% [0,07; 0,67]. R com 2000 replicas: [%s; %s]. Replicas com elasticidade negativa: %s%%; com resposta acumulada de PVD negativa: %s%%; com resposta acumulada de INF <= 0: %s%%.",
          num(q_el[1], 2), num(q_el[2], 2), num(100 * el_neg, 1), num(100 * pvd_neg, 1), num(100 * den_neg, 1)),
  "",
  "## Resposta acumulada a um choque de INF (IC 90%)",
  "",
  md_table(irf_tab),
  "Figura: `results/figuras/A1_irf_acumulada.png` e `.pdf`. Serie completa em `data/processed/A1_irf_acumulada.csv`.",
  "",
  "## Matriz de covariancia dos residuos (summary(modelo)$covres)",
  "",
  md_table(tibble(` ` = c("INF", "PVD"), INF = sig(S[, "INF"], 6), PVD = sig(S[, "PVD"], 6))),
  sprintf("Correlacao dos residuos: %s.", num(R["INF", "PVD"], 4)),
  "",
  "## Diagnosticos dos residuos",
  "",
  md_table(diag %>% transmute(Teste = teste, Estatistica = num(estatistica, 2), gl = gl, `p-valor` = pval(p), Distribuicao = obs)),
  sprintf("ARCH multivariado com lags.multi = %d (padrao do vars, o mesmo usado no Rmd). No Rmd, BG e ES foram chamados com lags.pt = 16, que esses testes ignoram; o lag efetivo e lags.bg = 5.", LAGS_ARCH),
  "",
  sprintf("Raizes (modulos do polinomio caracteristico): %s. Todas menores que 1: %s.", paste(num(raizes, 4), collapse = ", "), ifelse(all(raizes < 1), "sim", "nao")),
  "",
  "## Selecao de defasagens: VARselect(lag.max = 8, type = \"both\", exogen = diff(exo))",
  "",
  md_table(vsel_tab),
  sprintf("Selecao: AIC = %s, HQ = %s, SC = %s, FPE = %s.", vsel$selection["AIC(n)"], vsel$selection["HQ(n)"], vsel$selection["SC(n)"], vsel$selection["FPE(n)"]),
  "",
  "## Causalidade de Granger (vars::causality, teste F)",
  "",
  md_table(granger %>% transmute(Modelo = modelo, Hipotese = paste("H0:", hipotese, "nao causa"), F = num(F, 2),
                                 gl = paste0(gl1, " e ", gl2), `p-valor` = num(p, 4))),
  "VAR em nivel: `VAR(infmeq, p = 3, type = \"both\", exogen = exo)`, a chamada do Rmd (`var.est`). Os graus de liberdade 3 e 116 coincidem com os da Tabela 12 da dissertacao.",
  "",
  "Variantes testadas para PVD -> INF, na tentativa de localizar o p = 0,56 da dissertacao (nenhuma o reproduz):",
  "",
  md_table(tibble(Variante = rownames(var_pvd), F = num(var_pvd[, "F"], 2), gl = paste0(var_pvd[, "gl1"], " e ", var_pvd[, "gl2"]),
                  `p-valor` = num(var_pvd[, "p"], 4))),
  "## Johansen (ca.jo, type = \"trace\")",
  "",
  if (nrow(joh_ok)) sprintf("Configuracoes que reproduzem traco 25,01 contra 25,32 para r = 0: %s. E a chamada do Rmd, com `dumvar = exo[, 3]`, que no arquivo 0124_inexo.txt e a DUM. spec (transitory ou longrun) nao altera a estatistica traco. Conclusao: %s < %s, nao rejeita r = 0 a 5%%; rejeita a 10%% (valor critico %s).",
                            paste(sprintf("ecdet = %s, K = %d, spec = %s", joh_ok$ecdet, joh_ok$K, joh_ok$spec), collapse = "; "),
                            num(joh_ok$traco_r0[1], 2), num(joh_ok$cv5_r0[1], 2), num(joh_ok$cv10_r0[1], 2))
  else "Nenhuma configuracao reproduz traco 25,01 contra 25,32.",
  "",
  md_table(joh %>% transmute(ecdet, K, spec, dumvar, `traco r = 0` = num(traco_r0, 2), `vc 10%` = num(cv10_r0, 2),
                             `vc 5%` = num(cv5_r0, 2), `vc 1%` = num(cv1_r0, 2), `traco r <= 1` = num(traco_r1, 2),
                             `vc 5% r <= 1` = num(cv5_r1, 2), `bate 25,01/25,32` = ifelse(bate, "sim", ""))),
  "## Decomposicao da variancia do erro de previsao (%, variaveis em diferenca)",
  "",
  md_table(fevd_tab %>% transmute(h, `dINF: choque INF` = num(INF_por_INF, 1), `dINF: choque PVD` = num(INF_por_PVD, 1),
                                  `dPVD: choque INF` = num(PVD_por_INF, 1), `dPVD: choque PVD` = num(PVD_por_PVD, 1))),
  "## Arquivos",
  "",
  "- `R/A1_replica.R`",
  "- `results/A1_replica.md`, `results/A1_replica.tex`",
  "- `results/figuras/A1_irf_acumulada.png`, `results/figuras/A1_irf_acumulada.pdf`",
  "- `data/processed/A1_bootstrap.csv` (2000 replicas: impacto, respostas acumuladas em h = 40 e elasticidade)",
  "- `data/processed/A1_irf_acumulada.csv` (resposta acumulada h = 0 a 40 com IC 90%)",
  "- `results/log_parts/A1.md`, `results/session_info/A1_replica.txt`"
)
writeLines(md, file.path(PATHS$results, "A1_replica.md"))

# ------------------------------------------------------------------------------------------------
# 11. Tabela LaTeX (baseline e diagnosticos)
# ------------------------------------------------------------------------------------------------
tl <- function(...) paste0(...)
jx <- if (nrow(joh_ok)) joh_ok[1, ] else NULL
tex <- c(
  "% Gerado por R/A1_replica.R. Requer \\usepackage{booktabs}.",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Replica do modelo da disserta\\c{c}\\~ao: VAR(3) em diferen\\c{c}as, 2002T1--2019T4}",
  "\\label{tab:a1_baseline}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Estimativa & IC 90\\% \\\\",
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{A. Choque ortogonal em INF (Cholesky: INF, PVD)}} \\\\",
  tl("Impacto em PVD ($h = 0$) & ", tnum(impacto), " & [", tnum(lo[1, "PVD"]), "; ", tnum(up[1, "PVD"]), "] \\\\"),
  tl("Resposta acumulada de PVD ($h = 40$) & ", tnum(acum_pvd), " & [", tnum(lo[41, "PVD"]), "; ", tnum(up[41, "PVD"]), "] \\\\"),
  tl("Resposta acumulada de INF ($h = 40$) & ", tnum(acum_inf), " & [", tnum(lo[41, "INF"]), "; ", tnum(up[41, "INF"]), "] \\\\"),
  tl("Elasticidade de longo prazo & ", tnum(elast, 2), " & [", tnum(q_el[1], 2), "; ", tnum(q_el[2], 2), "] \\\\"),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{B. Covari\\^ancia dos res\\'iduos}} \\\\",
  tl("$\\mathrm{var}(u_{INF})$ & ", tnum(S["INF", "INF"], 5), " & \\\\"),
  tl("$\\mathrm{cov}(u_{INF}, u_{PVD})$ & ", tnum(S["INF", "PVD"], 5), " & \\\\"),
  tl("$\\mathrm{var}(u_{PVD})$ & ", tnum(S["PVD", "PVD"], 5), " & \\\\"),
  tl("$\\mathrm{corr}(u_{INF}, u_{PVD})$ & ", tnum(R["INF", "PVD"], 3), " & \\\\"),
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{C. Causalidade de Granger (F; p-valor)}} \\\\",
  tl("INF $\\rightarrow$ PVD, VAR em diferen\\c{c}as (gl ", g_d_inf$gl1, " e ", g_d_inf$gl2, ") & ", tnum(g_d_inf$F, 2), " & ", tpval(g_d_inf$p), " \\\\"),
  tl("PVD $\\rightarrow$ INF, VAR em diferen\\c{c}as (gl ", g_d_pvd$gl1, " e ", g_d_pvd$gl2, ") & ", tnum(g_d_pvd$F, 2), " & ", tpval(g_d_pvd$p), " \\\\"),
  tl("INF $\\rightarrow$ PVD, VAR em n\\'ivel (gl ", g_n_inf$gl1, " e ", g_n_inf$gl2, ") & ", tnum(g_n_inf$F, 2), " & ", tpval(g_n_inf$p), " \\\\"),
  tl("PVD $\\rightarrow$ INF, VAR em n\\'ivel (gl ", g_n_pvd$gl1, " e ", g_n_pvd$gl2, ") & ", tnum(g_n_pvd$F, 2), " & ", tpval(g_n_pvd$p), " \\\\"),
  if (!is.null(jx)) c(
    "\\midrule",
    "\\multicolumn{3}{l}{\\textit{D. Johansen, tra\\c{c}o (ecdet = tend\\^encia, K = 2, dummy restrita)}} \\\\",
    tl("$r = 0$ (valor cr\\'itico 5\\%: ", tnum(jx$cv5_r0, 2), "; 10\\%: ", tnum(jx$cv10_r0, 2), ") & ", tnum(jx$traco_r0, 2), " & \\\\"),
    tl("$r \\leq 1$ (valor cr\\'itico 5\\%: ", tnum(jx$cv5_r1, 2), ") & ", tnum(jx$traco_r1, 2), " & \\\\")
  ),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{minipage}{0.95\\linewidth}\\footnotesize",
  tl("\\medskip Notas: VAR(3) em primeiras diferen\\c{c}as de INF e PVD (log10), com constante, tend\\^encia e as ex\\'ogenas diferenciadas ",
     "(PIB, Selic e dummy); ", modelo$obs, " observa\\c{c}\\~oes efetivas. Respostas em log10. Elasticidade = resposta acumulada de PVD / ",
     "resposta acumulada de INF em $h = 40$. IC 90\\% por bootstrap de res\\'iduos com 2000 r\\'eplicas (percentis 5\\% e 95\\%). ",
     "VAR em n\\'ivel: VAR(3) nos log10 com ex\\'ogenas em n\\'ivel."),
  "\\end{minipage}",
  "\\end{table}",
  "",
  "\\begin{table}[htbp]",
  "\\centering",
  "\\caption{Diagn\\'osticos dos res\\'iduos do VAR(3) em diferen\\c{c}as}",
  "\\label{tab:a1_diagnosticos}",
  "\\small",
  "\\begin{tabular}{lccc}",
  "\\toprule",
  "Teste & Estat\\'istica & gl & p-valor \\\\",
  "\\midrule",
  vapply(seq_len(nrow(diag)), function(i) tl(gsub("_", "\\_", diag$teste[i], fixed = TRUE), " & ", tnum(diag$estatistica[i], 2), " & ",
                                             gsub(",", "{,}", diag$gl[i], fixed = TRUE), " & ", tpval(diag$p[i]), " \\\\"), ""),
  "\\midrule",
  tl("M\\'odulo m\\'aximo das ra\\'izes & ", tnum(max(raizes), 4), " & & \\\\"),
  tl("VARselect (m\\'aximo 8): AIC, HQ, SC, FPE & \\multicolumn{3}{c}{", vsel$selection["AIC(n)"], ", ", vsel$selection["HQ(n)"], ", ",
     vsel$selection["SC(n)"], ", ", vsel$selection["FPE(n)"], "} \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{minipage}{0.95\\linewidth}\\footnotesize",
  "\\medskip Notas: H0 de aus\\^encia de autocorrela\\c{c}\\~ao (Portmanteau, BG, ES), de efeitos ARCH e de normalidade (Jarque-Bera). Testes do pacote vars.",
  "\\end{minipage}",
  "\\end{table}"
)
writeLines(tex, file.path(PATHS$results, "A1_replica.tex"))

log_part(ETAPA, "- Saidas: results/A1_replica.md, results/A1_replica.tex, results/figuras/A1_irf_acumulada.png e .pdf, ",
         "data/processed/A1_bootstrap.csv, data/processed/A1_irf_acumulada.csv. Tempo total: ",
         num(as.numeric(difftime(Sys.time(), t_ini, units = "secs")), 0), " s.")

save_session_info("A1_replica")
cat("A1 concluida.\n")
