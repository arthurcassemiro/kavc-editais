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

# Rscript roda em locale C neste conteiner; UTF-8 e necessario para os acentos da figura e do texto da dissertacao
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

ETAPA <- "A1"

# ------------------------------------------------------------------------------------------------
# 0. Entradas: conferidas antes de qualquer calculo demorado (clone novo sem os arquivos para aqui)
# ------------------------------------------------------------------------------------------------
arq_end <- file.path(PATHS$original, "0224_tri_estmeq.txt")
arq_exo <- file.path(PATHS$original, "0124_inexo.txt")
arq_rmd <- file.path(PATHS$original, "VAR_Trimestral.Rmd")
arq_ap <- "data/dados_dissertacao_apendiceA.csv"
# Alvos da dissertacao: o txt fica fora do git (docs/dissertacao/ no .gitignore); a transcricao vai para o git
f_txt <- "docs/dissertacao/dissertacao.txt"
f_alvos <- file.path(PATHS$processed, "A1_alvos_dissertacao.csv")
# Artefatos estruturados de outras etapas usados so para ressalvas do relatorio
f_a3_var <- file.path(PATHS$results, "A3_reconstrucao_INF_variantes.csv")
f_a2_selic <- file.path(PATHS$results, "A2_comparacao_selic_jur.csv")
f_a2_pib <- file.path(PATHS$results, "A2_comparacao_pib_inexo.csv")
f_a2_meta <- file.path(PATHS$processed, "A2_metadados_bcb_ibge.csv")

entradas <- c(arq_end, arq_exo, file.path(PATHS$original, c("0124_tri_estmeq.txt", "0224_inexo.txt")), arq_rmd, arq_ap,
              f_a3_var, f_a2_selic, f_a2_pib, f_a2_meta)
faltam <- entradas[!file.exists(entradas)]
if (length(faltam)) {
  stop("A1: entradas ausentes: ", paste(faltam, collapse = ", "),
       ". Os arquivos de results/ e data/processed/ de A2 e A3 sao gerados por R/A2_download_bcb.R, R/A2_download_ibge.R ",
       "e R/A3_investimento_publico.R.", call. = FALSE)
}
if (!file.exists(f_txt) && !file.exists(f_alvos)) {
  stop("A1: faltam os alvos da dissertacao. Precisa de ", f_txt, " (fora do git) ou de ", f_alvos,
       " (transcricao versionada). Restaure o CSV do git ou coloque o txt da dissertacao em docs/dissertacao/.", call. = FALSE)
}

log_reset(ETAPA)
t_ini <- Sys.time()

# ------------------------------------------------------------------------------------------------
# Helpers de formatacao (virgula decimal) e de comparacao com alvos
# ------------------------------------------------------------------------------------------------
num <- function(x, d = 4) {
  if (length(d) > 1) return(unname(mapply(num, x, d)))
  formatC(x, format = "f", digits = d, decimal.mark = ",")
}
sig <- function(x, d = 6) trimws(formatC(signif(x, d), format = "fg", digits = d, decimal.mark = ","))
sci <- function(x, d = 1) formatC(x, format = "e", digits = d, decimal.mark = ",")
tnum <- function(x, d = 4) gsub(",", "{,}", num(x, d), fixed = TRUE)
pval <- function(p) ifelse(p < 0.0001, "< 0,0001", num(p, 4))
tpval <- function(p) ifelse(p < 0.0001, "$<$ 0{,}0001", tnum(p, 4))
ic_txt <- function(a, b, d = 4) sprintf("[%s; %s]", num(a, d), num(b, d))
p3 <- function(p) ifelse(p < 0.001, "< 0,001", num(p, 3))
faixa <- function(x, d = 3) { a <- num(min(x), d); b <- num(max(x), d); if (a == b) a else paste(a, "a", b) }
tic_txt <- function(a, b, d = 4) sprintf("[%s; %s]", tnum(a, d), tnum(b, d))

md_table <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- vapply(seq_len(nrow(df)), function(i) paste0("| ", paste(unlist(df[i, ]), collapse = " | "), " |"), "")
  c(hdr, sep, rows, "")
}

# Classifica a reproducao de um numero impresso com 'casas' decimais:
# "arredondamento", "truncamento", "arredondamento duplo" (primeiro a casas + 1, como no print do R,
# depois a 'casas' com metade para cima, como no editor de texto) ou "nao".
classifica <- function(obtido, alvo, casas) {
  if (is.na(obtido) || is.na(alvo)) return("nao")
  tol <- 10^-(casas + 2)
  if (abs(round(obtido, casas) - alvo) < tol) return("arredondamento")
  esc <- obtido * 10^casas
  if (abs(trunc(esc + sign(esc) * 1e-7) / 10^casas - alvo) < tol) return("truncamento")
  r1 <- round(obtido, casas + 1) * 10^casas
  if (abs(sign(r1) * floor(abs(r1) + 0.5 + 1e-7) / 10^casas - alvo) < tol) return("arredondamento duplo")
  "nao"
}
compara <- function(obtido, alvo, casas) {
  switch(classifica(obtido, alvo, casas),
         arredondamento = "sim",
         truncamento = sprintf("sim, por truncamento (arredondado: %s)", num(round(obtido, casas), casas)),
         `arredondamento duplo` = sprintf("sim, por arredondamento duplo (%s, depois %s)", num(round(obtido, casas + 1), casas + 1),
                                          num(alvo, casas)),
         nao = "nao")
}
# Leitura de um p-valor para H0
leitura_p <- function(p) {
  ifelse(p < 0.01, "rejeita a 1%", ifelse(p < 0.05, "rejeita a 5%", ifelse(p < 0.10, "rejeita a 10%", "nao rejeita a 10%")))
}

# ------------------------------------------------------------------------------------------------
# 1. Dados
# ------------------------------------------------------------------------------------------------
end_df <- read.table(arq_end, header = TRUE)
exo_df <- read.table(arq_exo, header = TRUE)
stopifnot(identical(names(end_df), c("INF", "PVD")), identical(names(exo_df), c("PIB", "JUR", "DUM")),
          nrow(end_df) == 72, nrow(exo_df) == 72)

TRIM <- q_seq("2002Q1", "2019Q4")
infmeq <- ts_from_q(as.matrix(end_df), TRIM)
exo <- ts_from_q(as.matrix(exo_df), TRIM)

log_part(ETAPA, "- Dados: ", arq_end, " (INF e PVD em log10) e ", arq_exo,
         " (PIB, JUR e DUM; definicao pela fonte mais abaixo). 72 linhas cada, sem coluna de data; ",
         "datas atribuidas de 2002Q1 a 2019Q4, como no Rmd (ts com start = c(2002, 1)).")

# Conferencia do alinhamento das datas com o Apendice A da dissertacao (arquivo com coluna de trimestre)
ap <- read.csv(arq_ap)
stopifnot(identical(ap$trimestre, TRIM))
dif_selic <- max(abs(ap$selic - exo[, "JUR"]))
dif_pib <- max(abs(ap$cpib_pct / 100 - exo[, "PIB"]))
cor_pvd <- cor(diff(log10(ap$imeq_indice)), diff(infmeq[, "PVD"]))
log_part(ETAPA, "- Alinhamento das datas conferido com data/dados_dissertacao_apendiceA.csv (coluna trimestre 2002Q1 a 2019Q4): ",
         "diferenca maxima Selic x JUR = ", sci(dif_selic), "; PIB x cpib_pct/100 = ", sci(dif_pib),
         "; correlacao entre diff(log10(imeq_indice)) e diff(PVD) = ", num(cor_pvd, 4), ".")

# Definicao de JUR e PIB pela fonte (comparacoes feitas na A2 com as series do BCB e do SIDRA)
cmp_selic <- read.csv(f_a2_selic)
cmp_pib <- read.csv(f_a2_pib)
meta_a2 <- read.csv(f_a2_meta)
stopifnot(identical(cmp_selic$periodo, TRIM), identical(cmp_pib$periodo, TRIM),
          all(c("JUR", "selic_meta_fim", "selic_meta_media") %in% names(cmp_selic)),
          all(c("PIB_dissertacao", "pib_var_tri_sa_1621") %in% names(cmp_pib)),
          max(abs(cmp_selic$JUR - exo[, "JUR"])) < 1e-12, max(abs(cmp_pib$PIB_dissertacao - exo[, "PIB"])) < 1e-12)
tit_432 <- meta_a2$titulo_nos_metadados[meta_a2$serie == "selic_meta"]
tit_1621 <- meta_a2$titulo_nos_metadados[meta_a2$serie == "pib_vol_sa_1621"]
stopifnot(length(tit_432) == 1, length(tit_1621) == 1, grepl("^432$", meta_a2$codigo[meta_a2$serie == "selic_meta"]))
# "Igual" com a mesma tolerancia da A2: diferenca menor que 0,0001 (0,01 p.p.)
n_fim <- sum(abs(cmp_selic$JUR - cmp_selic$selic_meta_fim) < 1e-4)
n_media <- sum(abs(cmp_selic$JUR - cmp_selic$selic_meta_media) < 1e-4)
dam_media <- 100 * mean(abs(cmp_selic$JUR - cmp_selic$selic_meta_media))
dam_pib <- 100 * mean(abs(cmp_pib$PIB_dissertacao - cmp_pib$pib_var_tri_sa_1621))
max_pib <- 100 * max(abs(cmp_pib$PIB_dissertacao - cmp_pib$pib_var_tri_sa_1621))
cor_pib <- cor(cmp_pib$PIB_dissertacao, cmp_pib$pib_var_tri_sa_1621)
stopifnot(n_fim == length(TRIM))
txt_jur <- paste0("JUR e a Meta Selic do BCB/SGS 432 (\"", tit_432, "\", % a.a., em fracao) no ultimo dia do trimestre: ", n_fim, " de ",
                  length(TRIM), " trimestres iguais (diferenca menor que 0,01 p.p., criterio da A2). Contra a media diaria do trimestre, que e a regra de conversao da A2 para taxas, so ",
                  n_media, " de ", length(TRIM), " sao iguais (diferenca media absoluta ", num(dam_media, 2), " p.p.).")
txt_pib <- paste0("PIB e a variacao trimestral (x_t/x_{t-1} - 1) do indice de volume com ajuste sazonal da SIDRA 1621 (\"",
                  sub(" \\|.*$", "", tit_1621), "\", PIB a precos de mercado), numa safra anterior a atual: diferenca media absoluta de ",
                  num(dam_pib, 2), " p.p. (maxima ", num(max_pib, 2), " p.p.) e correlacao ", num(cor_pib, 4), " com a safra baixada pela A2.")
log_part(ETAPA, "- Definicao das exogenas pela fonte (", f_a2_selic, " e ", f_a2_pib, "). ", txt_jur, " ", txt_pib,
         " Para a A5: a extensao do baseline deve usar a Meta Selic no fim do trimestre, para ser comparavel com a dissertacao, ",
         "e a media do trimestre como robustez; o PIB vem da safra atual da 1621, com a diferenca de safra registrada.")

# Datas da dummy no arquivo. O esperado vem do LOG.md (2018T2-2019T1 e 2019T3-2019T4).
DUM_ESPERADA <- "2018Q2-2019Q1 e 2019Q3-2019Q4"
datas_dum <- TRIM[exo_df$DUM == 1]
blocos_dum <- split(datas_dum, cumsum(c(1, diff(match(datas_dum, TRIM)) != 1)))
txt_dum <- paste(vapply(blocos_dum, function(b) if (length(b) > 1) paste0(b[1], "-", b[length(b)]) else b[1], ""),
                 collapse = " e ")
stopifnot(identical(txt_dum, DUM_ESPERADA))
dd <- diff(exo_df$DUM)
pulsos <- paste(sprintf("%s: %+d", TRIM[-1][dd != 0], dd[dd != 0]), collapse = "; ")
log_part(ETAPA, "- Dummy DUM = 1 no arquivo em ", txt_dum, " (", length(datas_dum), " trimestres), igual ao registrado no LOG.md. ",
         "Com exogen = diff(exo) a dummy vira pulsos: ", pulsos, ".")

# Outros arquivos da pasta original, so para registro (conferidos, nao entram no modelo final)
o124 <- read.table(file.path(PATHS$original, "0124_tri_estmeq.txt"), header = TRUE)
i224 <- read.table(file.path(PATHS$original, "0224_inexo.txt"), header = TRUE)
dif_o124 <- max(abs(as.matrix(o124[-1, c("INF", "PVD")]) - diff(as.matrix(end_df))))
stopifnot(identical(names(i224), c("PIB", "JUR", "CAM", "DUM")), dif_o124 > 0.01)
log_part(ETAPA, "- data/original/0124_tri_estmeq.txt nao e a diferenca do 0224_tri_estmeq (diferenca maxima entre as linhas 2 a 72 e ",
         "diff(0224_tri_estmeq): ", num(dif_o124, 3), "). data/original/0224_inexo.txt tem as colunas ", paste(names(i224), collapse = ", "),
         " (PIB entre ", num(min(i224$PIB), 3), " e ", num(max(i224$PIB), 3), ", faixa de log10 de indice); nele exo[, 3] seria CAM. ",
         "Nenhum dos dois entra no modelo final.")

# ------------------------------------------------------------------------------------------------
# 2. Modelo baseline
# ------------------------------------------------------------------------------------------------
dinfmeq <- diff(infmeq)
dexo <- diff(exo)
modelo <- vars::VAR(dinfmeq, p = 3, type = "both", exogen = dexo)
sm <- summary(modelo)
S <- sm$covres
R <- sm$corres
P_chol <- t(chol(S))
TRIM_EF <- c(TRIM[2 + modelo$p], TRIM[length(TRIM)])
stopifnot(modelo$obs == length(TRIM) - 1 - modelo$p)
log_part(ETAPA, "- Baseline: vars::VAR(diff(infmeq), p = 3, type = \"both\", exogen = diff(exo)); ",
         modelo$obs, " observacoes efetivas (", TRIM_EF[1], " a ", TRIM_EF[2], "). Ordem de Cholesky: INF, PVD.")

# Ressalva de unidade: a A3 reconstroi INF em varias variantes (nominal e deflacionadas) e grava o ajuste de cada uma contra
# o INF do arquivo original em results/A3_reconstrucao_INF_variantes.csv. A conclusao sai dessa tabela, nao do texto do log da A3.
a3v <- read.csv(f_a3_var)
if (!all(c("deflator", "span", "dam_nivel", "desvio_medio_nivel", "corr_dif") %in% names(a3v)) || !any(a3v$span == "2003T1-2019T4")) {
  stop("A1: ", f_a3_var, " mudou de formato (colunas deflator, span, dam_nivel, desvio_medio_nivel, corr_dif; janela 2003T1-2019T4). ",
       "Rever a ressalva de unidade do INF.", call. = FALSE)
}
a3v <- a3v %>% filter(span == "2003T1-2019T4")
# Compara so variantes com ajuste sazonal (coluna ajuste diferente de "nenhum"); as sem ajuste entram como evidencia do ajuste
a3_sa <- if ("ajuste" %in% names(a3v)) filter(a3v, ajuste != "nenhum") else a3v
a3_nsa <- if ("ajuste" %in% names(a3v)) filter(a3v, ajuste == "nenhum", deflator == "nominal") else a3v[0, ]
a3_melhor <- a3_sa %>% slice_min(dam_nivel, n = 1, with_ties = FALSE)
a3_defl <- a3_sa %>% filter(deflator != "nominal")
a3_nom <- a3_sa %>% filter(deflator == "nominal")
# Nominal se a variante de menor desvio em nivel e nominal e toda variante deflacionada fica bem mais longe (fator 10)
a3_nominal <- nrow(a3_nom) > 0 && nrow(a3_defl) > 0 && a3_melhor$deflator == "nominal" &&
  min(a3_defl$dam_nivel) > 10 * max(a3_nom$dam_nivel)
if (!a3_nominal) {
  stop("A1: a tabela de variantes da A3 (", f_a3_var, ") nao sustenta mais que o INF do arquivo original e nominal com ajuste sazonal ",
       "(variante com ajuste de menor desvio em nivel: deflator ", a3_melhor$deflator, "). Rever a ressalva de unidade antes de publicar.",
       call. = FALSE)
}
txt_unidade <- paste0(
  "O INF do arquivo original e nominal com ajuste sazonal, embora a secao 4.4 da dissertacao diga que foi deflacionado. ",
  "Evidencia da A3 (", f_a3_var, ", janela 2003T1-2019T4, ", nrow(a3_sa), " variantes com ajuste sazonal): nas nominais o desvio absoluto medio ",
  "em nivel contra INF fica entre ", num(min(a3_nom$dam_nivel), 4), " e ", num(max(a3_nom$dam_nivel), 4), " log10; nas deflacionadas pelo IPCA, entre ",
  num(min(a3_defl$dam_nivel), 3), " e ", num(max(a3_defl$dam_nivel), 3), " log10 (desvio medio de ", num(mean(a3_defl$desvio_medio_nivel), 2),
  ", a inflacao acumulada). A correlacao das diferencas nao distingue as duas: a maior e ", num(max(a3_nom$corr_dif), 3),
  " nas nominais e ", num(max(a3_defl$corr_dif), 3), " nas deflacionadas. ",
  if (nrow(a3_nsa)) paste0("A serie nominal sem ajuste sazonal fica mais longe (desvio absoluto medio em nivel ",
                           faixa(a3_nsa$dam_nivel, 3), " log10; correlacao das diferencas ", faixa(a3_nsa$corr_dif, 2), "). ") else "",
  "A replica reproduz a dissertacao; a elasticidade de longo prazo aqui e medida contra o INF nominal. O baseline corrigido, com INF real, fica na A5.")
log_part(ETAPA, "- Ressalva de unidade. ", txt_unidade)

# Porte a partir do Rmd: a chamada literal do modelo final nao usa diff(exo)
rmd <- readLines(arq_rmd, warn = FALSE, encoding = "UTF-8")
i_sec <- grep("^infmeq<-read.table\\(\"0224_tri_estmeq.txt\"", rmd)
i_d2uci <- grep("^dados2 <- UCI\\[,1\\]", rmd)
i_var <- grep("^modelo=VAR\\(dados,p=3", rmd)
i_d2diff <- grep("^dados2 <- diff\\(exo\\)", rmd)
i_d2diff <- max(i_d2diff[i_d2diff > i_sec & i_d2diff < i_d2uci])
i_uci <- grep("^\\s*UCI\\s*<-", rmd)
stopifnot(length(i_sec) == 1, length(i_d2uci) == 1, length(i_var) == 1, i_sec < i_d2diff, i_d2diff < i_d2uci,
          i_d2uci < i_var, all(i_uci < i_sec))

# ------------------------------------------------------------------------------------------------
# 3. IRF acumulada com bootstrap do vars (2000 replicas, IC 90%, seed 42)
# ------------------------------------------------------------------------------------------------
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
# 4. Bootstrap proprio para a elasticidade de longo prazo
# Desenho igual ao de vars:::.boot: recursivo, deterministicos e exogenas fixos, p valores iniciais
# observados, residuos centrados reamostrados com reposicao. Mesma semente e mesma sequencia de sorteios,
# de modo que as replicas coincidem com as do irf(); aqui guardamos a razao em cada replica.
# ------------------------------------------------------------------------------------------------
K <- modelo$K; p <- modelo$p; KP <- K * p
B_ols <- vars::Bcoef(modelo)
Zdet <- as.matrix(modelo$datamat[, (K * (p + 1) + 1):ncol(modelo$datamat), drop = FALSE])  # const, trend, exogenas
stopifnot(identical(colnames(B_ols), colnames(modelo$datamat)[-(1:K)]))
i_inf <- which(colnames(modelo$y) == "INF"); i_pvd <- which(colnames(modelo$y) == "PVD")

# Covariancia dos residuos como em vars::Psi (divide por obs menos numero de regressores)
sigma_vars <- function(mod) crossprod(resid(mod)) / (mod$obs - ncol(mod$datamat[, -(1:mod$K)]))

# Respostas ortogonais a partir dos coeficientes das defasagens (mesma recursao de vars::Phi)
psi_de <- function(A, Sigma, h = 40) {
  As <- lapply(seq_len(p), function(i) A[, ((i - 1) * K + 1):(i * K), drop = FALSE])
  Phi <- array(0, c(K, K, h + 1)); Phi[, , 1] <- diag(K)
  for (i in seq_len(h)) {
    acc <- matrix(0, K, K)
    for (j in seq_len(min(i, p))) acc <- acc + Phi[, , i - j + 1] %*% As[[j]]
    Phi[, , i + 1] <- acc
  }
  Pm <- t(chol(Sigma))
  Psi <- array(0, dim(Phi))
  for (i in seq_len(h + 1)) Psi[, , i] <- Phi[, , i] %*% Pm
  Psi
}
medidas <- function(Psi) {
  c_pvd <- sum(Psi[i_pvd, i_inf, ]); c_inf <- sum(Psi[i_inf, i_inf, ])
  c(impacto_PVD = Psi[i_pvd, i_inf, 1], acum40_PVD = c_pvd, acum40_INF = c_inf, elasticidade = c_pvd / c_inf)
}
stopifnot(max(abs(psi_de(B_ols[, 1:KP], sigma_vars(modelo)) - vars::Psi(modelo, nstep = 40))) < 1e-12)

# Gera uma serie bootstrap a partir dos coeficientes B e dos residuos centrados U
simula <- function(B, U, idx) {
  ys <- matrix(0, modelo$totobs, K, dimnames = list(NULL, colnames(modelo$y)))
  ys[1:p, ] <- modelo$y[1:p, ]
  for (t in seq_len(modelo$obs)) {
    lags <- c(t(ys[(t + p - 1):t, , drop = FALSE]))  # y_{t-1}, ..., y_{t-p}
    ys[t + p, ] <- B %*% c(lags, Zdet[t, ]) + U[idx[t], ]
  }
  ys
}
U_c <- scale(resid(modelo), scale = FALSE)
estima <- function(ys) {
  mb <- vars::VAR(ys, p = p, type = modelo$type, exogen = dexo)
  list(B = vars::Bcoef(mb), S = sigma_vars(mb), mod = mb)
}

boot_elasticidade <- function(runs = 2000, seed = 42, h = 40) {
  set.seed(seed)
  out <- matrix(NA_real_, runs, 4, dimnames = list(NULL, c("impacto_PVD", "acum40_PVD", "acum40_INF", "elasticidade")))
  for (r in seq_len(runs)) {
    idx <- sample(seq_len(modelo$obs), replace = TRUE)
    mb <- estima(simula(B_ols, U_c, idx))$mod
    ps <- vars::Psi(mb, nstep = h)
    out[r, ] <- medidas(ps)
  }
  out
}

t0 <- Sys.time()
bt <- boot_elasticidade(runs = 2000, seed = 42, h = 40)
t_boot <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
bt_df <- tibble(replica = seq_len(nrow(bt)), as_tibble(bt))
f_boot <- file.path(PATHS$processed, "A1_bootstrap.csv")
write_csv_safe(bt_df, f_boot)

q_el <- quantile(bt[, "elasticidade"], c(0.05, 0.95), type = 7)
q_pvd <- quantile(bt[, "acum40_PVD"], c(0.05, 0.95), type = 7)
q_inf <- quantile(bt[, "acum40_INF"], c(0.05, 0.95), type = 7)
bate_vars <- isTRUE(all.equal(unname(q_pvd), unname(c(lo[41, "PVD"], up[41, "PVD"])), tolerance = 1e-10)) &&
  isTRUE(all.equal(unname(q_inf), unname(c(lo[41, "INF"], up[41, "INF"])), tolerance = 1e-10))
# Sem essa conferencia o IC da elasticidade nao e publicado
stopifnot(bate_vars)
el_neg <- mean(bt[, "elasticidade"] < 0)
den_neg <- mean(bt[, "acum40_INF"] <= 0)
pvd_neg <- mean(bt[, "acum40_PVD"] < 0)

log_part(ETAPA, "- Bootstrap do vars: irf com impulso INF, respostas INF e PVD, 40 trimestres, acumulada, 2000 replicas, IC de 90% e ",
         "seed 42; ", num(t_irf, 0), " s. IC 90% da resposta acumulada de PVD em h = 40: ", ic_txt(lo[41, "PVD"], up[41, "PVD"]), ".")
log_part(ETAPA, "- Bootstrap proprio de residuos (2000 replicas; recursivo; constante, tendencia e exogenas fixas; ",
         p, " valores iniciais observados; residuos centrados; set.seed(42) e mesmos sorteios de vars:::.boot). ",
         "Percentis 5% e 95% das respostas acumuladas em h = 40 coincidem com as bandas do irf() (imposto por stopifnot; ",
         "se falhar, o script para antes de publicar o IC da elasticidade), o que confere a implementacao. Replicas em ", f_boot, ".")
log_part(ETAPA, "- Elasticidade de longo prazo (razao das respostas acumuladas de PVD e INF em h = 40): ", num(elast, 4),
         "; IC 90% percentil ", ic_txt(q_el[1], q_el[2], 2), " com 2000 replicas (Python, 500 replicas: [0,07; 0,67]). ",
         "Replicas com elasticidade negativa: ", num(100 * el_neg, 1), "%; com resposta acumulada de INF <= 0: ",
         num(100 * den_neg, 1), "%.")

# ---- 4b. Vies do bootstrap e intervalos corrigidos (robustez) ----
# Intervalo basico de Hall, calculado a partir das replicas gravadas em disco
bt_csv <- readr::read_csv(f_boot, show_col_types = FALSE)
stopifnot(nrow(bt_csv) == 2000, max(abs(as.matrix(bt_csv[, colnames(bt)]) - bt)) < 1e-12)
MEDIDAS <- c(impacto_PVD = "Impacto de INF em PVD (h = 0)", acum40_PVD = "Resposta acumulada de PVD (h = 40)",
             acum40_INF = "Resposta acumulada de INF (h = 40)", elasticidade = "Elasticidade de longo prazo")
ponto_ols <- c(impacto_PVD = impacto, acum40_PVD = acum_pvd, acum40_INF = acum_inf, elasticidade = elast)
stopifnot(max(abs(ponto_ols - medidas(vars::Psi(modelo, nstep = 40)))) < 1e-12)
hall <- tibble(medida = names(MEDIDAS), ponto = ponto_ols,
               media = colMeans(as.matrix(bt_csv[, names(MEDIDAS)])),
               mediana = apply(as.matrix(bt_csv[, names(MEDIDAS)]), 2, median),
               q05 = apply(as.matrix(bt_csv[, names(MEDIDAS)]), 2, quantile, probs = 0.05, type = 7),
               q95 = apply(as.matrix(bt_csv[, names(MEDIDAS)]), 2, quantile, probs = 0.95, type = 7)) %>%
  mutate(vies_mediana = ponto - mediana, vies_media = ponto - media,
         hall_inf = 2 * ponto - q95, hall_sup = 2 * ponto - q05)

# Bootstrap-after-bootstrap de Kilian (1998). Estagio 1: vies dos coeficientes das defasagens com B1 replicas geradas
# pelos coeficientes de MQO. Correcao com ajuste de estacionariedade (se o VAR corrigido sair nao estacionario, o vies
# e encolhido por delta, reduzido de 0,01 em 0,01; se o VAR estimado ja e nao estacionario, nao corrige).
# Estagio 2: B2 replicas geradas pelos coeficientes corrigidos; cada replica e corrigida com o vies do estagio 1.
# Deterministicos e exogenas ficam nos valores de MQO (as respostas dependem so das defasagens e da covariancia).
modulo_max <- function(A) {
  C <- matrix(0, KP, KP); C[1:K, ] <- A
  if (p > 1) C[(K + 1):KP, 1:(K * (p - 1))] <- diag(K * (p - 1))
  max(Mod(eigen(C, only.values = TRUE)$values))
}
corrige_kilian <- function(A, vies) {
  if (modulo_max(A) >= 1) return(list(A = A, tipo = "nao estacionario, sem correcao"))
  psi_i <- vies; delta <- 1
  while (modulo_max(A - psi_i) >= 1 && delta > 0) { psi_i <- delta * psi_i; delta <- delta - 0.01 }
  list(A = A - psi_i, tipo = if (identical(psi_i, vies)) "correcao completa" else "correcao encolhida")
}
kilian_bab <- function(B1 = 1000, B2 = 2000, seed = 42, h = 40) {
  A <- B_ols[, 1:KP]
  set.seed(seed)
  soma <- matrix(0, K, KP)
  for (r in seq_len(B1)) {
    idx <- sample(seq_len(modelo$obs), replace = TRUE)
    soma <- soma + estima(simula(B_ols, U_c, idx))$B[, 1:KP]
  }
  vies <- soma / B1 - A
  cc <- corrige_kilian(A, vies)
  Bc <- B_ols; Bc[, 1:KP] <- cc$A
  # Estagio 2 continua o fluxo do gerador (sem nova semente): sorteios independentes dos do estagio 1
  out <- matrix(NA_real_, B2, 4, dimnames = list(NULL, names(MEDIDAS)))
  tipos <- character(B2)
  for (r in seq_len(B2)) {
    idx <- sample(seq_len(modelo$obs), replace = TRUE)
    e <- estima(simula(Bc, U_c, idx))
    cr <- corrige_kilian(e$B[, 1:KP], vies)
    tipos[r] <- cr$tipo
    out[r, ] <- medidas(psi_de(cr$A, e$S, h))
  }
  list(vies = vies, A_c = cc$A, tipo_ponto = cc$tipo, ponto = medidas(psi_de(cc$A, sigma_vars(modelo), h)),
       reps = out, tipos = table(tipos), mod_ols = modulo_max(A), mod_c = modulo_max(cc$A))
}
t0 <- Sys.time()
kb <- kilian_bab(B1 = 1000, B2 = 2000, seed = 42, h = 40)
t_kil <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
f_kil <- file.path(PATHS$processed, "A1_bootstrap_kilian.csv")
write_csv_safe(tibble(replica = seq_len(nrow(kb$reps)), as_tibble(kb$reps)), f_kil)
kil <- tibble(medida = names(MEDIDAS), ponto_c = unname(kb$ponto[names(MEDIDAS)]),
              bab_inf = apply(kb$reps, 2, quantile, probs = 0.05, type = 7),
              bab_sup = apply(kb$reps, 2, quantile, probs = 0.95, type = 7),
              bab_mediana = apply(kb$reps, 2, median))
boot_tab <- left_join(hall, kil, by = "medida")
bel <- boot_tab %>% filter(medida == "elasticidade")
# Dependencia entre as replicas do estagio 2 e as do bootstrap principal (antes, com a semente reiniciada, era 0,98)
cor_kil_boot <- cor(kb$reps[, "elasticidade"], bt[, "elasticidade"])
txt_rng_kil <- paste0("Sementes do Kilian: set.seed(42) uma vez, no inicio do estagio 1 (os sorteios do estagio 1 sao os mesmos das 1000 ",
                      "primeiras replicas do bootstrap principal); o estagio 2 continua o fluxo do gerador, sem nova semente, para que os ",
                      "sorteios dos dois estagios sejam independentes, como supoe Kilian (1998). Ate a execucao anterior o estagio 2 refazia ",
                      "set.seed(42) e repetia os sorteios do estagio 1 (correlacao de 0,98 entre as elasticidades das replicas do estagio 2 e as ",
                      "do bootstrap principal); agora a correlacao e ", num(cor_kil_boot, 2), ".")
todas_abaixo <- all(boot_tab$mediana < boot_tab$ponto)
txt_tipos <- paste(sprintf("%s: %d", names(kb$tipos), as.integer(kb$tipos)), collapse = "; ")
# A elasticidade nao depende da escala da covariancia dos residuos (razao de respostas ao mesmo choque)
n_reg <- ncol(modelo$datamat) - K
fator_s <- (modelo$obs - n_reg) / modelo$obs
stopifnot(abs(medidas(psi_de(B_ols[, 1:KP], fator_s * sigma_vars(modelo)))["elasticidade"] - elast) < 1e-12)
txt_escala <- paste0(
  "Parte do vies das respostas em nivel vem da escala da covariancia: vars:::.boot reamostra os residuos centrados sem reescala ",
  "pelos graus de liberdade (", modelo$obs, " observacoes, ", n_reg, " regressores por equacao), e a covariancia das replicas tem valor ",
  "esperado de cerca de ", modelo$obs - n_reg, "/", modelo$obs, " = ", num(fator_s, 2), " da original, o que reduz as respostas em cerca de ",
  num(sqrt(fator_s), 2), " (mediana do impacto dividida pelo ponto: ", num(boot_tab$mediana[1] / boot_tab$ponto[1], 2), "). ",
  "A elasticidade e uma razao entre respostas ao mesmo choque e nao depende dessa escala (conferido); o vies dela vem dos coeficientes ",
  "das defasagens e da razao cov(u_INF, u_PVD)/var(u_INF). A correcao de Kilian atua so nos coeficientes das defasagens; por isso o ",
  "impacto corrigido e igual ao de MQO, e as bandas das respostas em nivel continuam afetadas pela escala.")

txt_vies <- paste0(
  "Vies do bootstrap: a mediana das replicas fica ", ifelse(todas_abaixo, "abaixo do ponto em todas as medidas", "abaixo do ponto em parte das medidas"),
  " (ponto menos mediana: impacto ", num(boot_tab$vies_mediana[1], 4), "; acumulada de PVD ", num(boot_tab$vies_mediana[2], 4),
  "; acumulada de INF ", num(boot_tab$vies_mediana[3], 4), "; elasticidade ", num(bel$vies_mediana, 2),
  ", com mediana ", num(bel$mediana, 2), " contra ponto ", num(bel$ponto, 2), "). O IC percentil replica o metodo do vars e nao corrige esse vies. ",
  "Robustez: intervalo basico de Hall (2 x ponto menos os percentis 95% e 5%, das replicas em ", f_boot, ") para a elasticidade ",
  ic_txt(bel$hall_inf, bel$hall_sup, 2), "; bootstrap-after-bootstrap de Kilian (1998), 1000 replicas no estagio 1 e 2000 no estagio 2, ",
  "set.seed(42), ", num(t_kil, 0), " s: elasticidade corrigida de vies ", num(bel$ponto_c, 2), ", IC 90% ", ic_txt(bel$bab_inf, bel$bab_sup, 2),
  "; acumulada de PVD corrigida ", num(boot_tab$ponto_c[2], 4), " ", ic_txt(boot_tab$bab_inf[2], boot_tab$bab_sup[2]),
  "; acumulada de INF corrigida ", num(boot_tab$ponto_c[3], 4), " ", ic_txt(boot_tab$bab_inf[3], boot_tab$bab_sup[3]),
  ". Modulo maximo das raizes: ", num(kb$mod_ols, 4), " (MQO) e ", num(kb$mod_c, 4), " (corrigido; ", kb$tipo_ponto, "). ",
  "Replicas do estagio 2 por tipo de correcao: ", txt_tipos, ". Replicas em ", f_kil, ". ", txt_rng_kil, " ", txt_escala)
log_part(ETAPA, "- ", txt_vies)

# ------------------------------------------------------------------------------------------------
# 5. Diagnosticos
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

# O Rmd chamou BG e ES com lags.pt = 16; esses testes usam lags.bg (padrao 5). Conferencia:
stopifnot(formals(vars::serial.test)$lags.bg == 5, formals(vars::arch.test)$lags.multi == LAGS_ARCH,
          isTRUE(all.equal(serial.test(modelo, lags.pt = 16, type = "BG")$serial$statistic, bg$statistic)),
          isTRUE(all.equal(serial.test(modelo, lags.pt = 16, type = "ES")$serial$statistic, es$statistic)))

bg_lags <- tibble(lags.bg = 1:8,
                  p_bg = vapply(1:8, function(l) serial.test(modelo, lags.bg = l, type = "BG")$serial$p.value, 0),
                  p_es = vapply(1:8, function(l) serial.test(modelo, lags.bg = l, type = "ES")$serial$p.value, 0))
# Mesmos testes (5 defasagens) com outras ordens do VAR
bg_ordens <- map_dfr(2:6, function(pp) {
  m <- vars::VAR(dinfmeq, p = pp, type = "both", exogen = dexo)
  tibble(p_var = pp, p_bg = serial.test(m, lags.bg = 5, type = "BG")$serial$p.value,
         p_es = serial.test(m, lags.bg = 5, type = "ES")$serial$p.value)
})
# Breusch-Godfrey por equacao (lmtest::bgtest, 5 defasagens, versao F), nas regressoes MQO de cada equacao do VAR
X_var <- as.data.frame(modelo$datamat[, -(1:K)])
bg_eq <- map_dfr(colnames(modelo$y), function(v) {
  yv <- modelo$datamat[, v]
  le <- lm(yv ~ -1 + ., data = X_var)
  stopifnot(max(abs(coef(le) - coef(modelo$varresult[[v]]))) < 1e-12)
  b <- bgtest(le, order = 5, type = "F")
  tibble(equacao = v, F = unname(b$statistic), gl1 = unname(b$parameter)[1], gl2 = unname(b$parameter)[2], p = unname(b$p.value))
})

# Rotulos: texto sem acento (md e log) e LaTeX com acento
diag_row <- function(nome, nome_tex, ht, obs) {
  tibble(teste = nome, teste_tex = nome_tex, estatistica = unname(ht$statistic)[1],
         gl = paste(num(unname(ht$parameter), 0), collapse = "; "),
         p = unname(ht$p.value)[1], obs = obs)
}
diag <- bind_rows(
  diag_row("Portmanteau assintotico (16 defasagens)", "Portmanteau assint\\'otico (16 defasagens)", pt_asy, "qui-quadrado"),
  diag_row("Portmanteau ajustado (16 defasagens)", "Portmanteau ajustado (16 defasagens)", pt_adj, "qui-quadrado"),
  diag_row("Breusch-Godfrey LM (5 defasagens)", "Breusch-Godfrey LM (5 defasagens)", bg, "qui-quadrado"),
  diag_row("Edgerton-Shukur F (5 defasagens)", "Edgerton-Shukur F (5 defasagens)", es, "F"),
  diag_row(sprintf("ARCH-LM multivariado (%d defasagens)", LAGS_ARCH), sprintf("ARCH-LM multivariado (%d defasagens)", LAGS_ARCH), arch, "qui-quadrado"),
  diag_row("Jarque-Bera multivariado", "Jarque-Bera multivariado", norm_t$jb.mul$JB, "qui-quadrado"),
  diag_row("Assimetria multivariada", "Assimetria multivariada", norm_t$jb.mul$Skewness, "qui-quadrado"),
  diag_row("Curtose multivariada", "Curtose multivariada", norm_t$jb.mul$Kurtosis, "qui-quadrado"),
  diag_row("Jarque-Bera univariado, INF", "Jarque-Bera univariado, INF", norm_t$jb.uni$INF, "qui-quadrado"),
  diag_row("Jarque-Bera univariado, PVD", "Jarque-Bera univariado, PVD", norm_t$jb.uni$PVD, "qui-quadrado")
)
dp <- setNames(diag$p, diag$teste)

# Autocorrelacao residual: contagens geradas a partir dos p-valores
n_bg1 <- sum(bg_lags$p_bg < 0.01); n_es1 <- sum(bg_lags$p_es < 0.01); n_es5 <- sum(bg_lags$p_es < 0.05)
n_ord_bg5 <- sum(bg_ordens$p_bg < 0.05); n_ord_es10 <- sum(bg_ordens$p_es < 0.10)
autocorr_resid <- dp[1] >= 0.10 && dp[2] >= 0.10 && n_bg1 == 8 && n_es5 == 8 && all(bg_eq$p < 0.01)
txt_autocorr <- paste0(
  "O Portmanteau (16 defasagens) nao rejeita ausencia de autocorrelacao (p = ", num(dp[1], 2), " assintotico e ", num(dp[2], 2), " ajustado), ",
  "mas o Breusch-Godfrey rejeita a 1% em ", n_bg1, " de 8 numeros de defasagens (1 a 8; maior p = ", num(max(bg_lags$p_bg), 3), ") e o ",
  "Edgerton-Shukur rejeita a 5% em ", n_es5, " de 8 e a 1% em ", n_es1, " de 8 (maior p = ", num(max(bg_lags$p_es), 3), ", com ",
  bg_lags$lags.bg[which.max(bg_lags$p_es)], " defasagens). Por equacao (bgtest, 5 defasagens): ",
  paste(sprintf("%s F = %s, p = %s", bg_eq$equacao, num(bg_eq$F, 2), p3(bg_eq$p)), collapse = "; "), ". Com o VAR de ordem 2 a 6 ",
  "(5 defasagens no teste), o BG rejeita a 5% em ", n_ord_bg5, " de 5 ordens e o ES a 10% em ", n_ord_es10, " de 5 (p do BG: ",
  paste(sprintf("p = %d: %s", bg_ordens$p_var, p3(bg_ordens$p_bg)), collapse = "; "), "; p do ES: ",
  paste(sprintf("p = %d: %s", bg_ordens$p_var, p3(bg_ordens$p_es)), collapse = "; "), "). ",
  if (autocorr_resid) "A especificacao tem autocorrelacao residual; o texto da dissertacao afirma ausencia com base so no Portmanteau. " else "",
  "Os IC por bootstrap iid de residuos (percentil, Hall e Kilian) supoem residuos nao autocorrelacionados e ficam condicionados a isso. ",
  "Na A5: bootstrap em blocos ou wild, ou projecoes locais com erros HAC (plano em results/log_parts/A0_ambiente.md).")

# Leitura gerada a partir dos p-valores
txt_diag <- paste0(
  "Portmanteau assintotico (16 defasagens): ", leitura_p(dp[1]), "; ajustado: ", leitura_p(dp[2]),
  ". Breusch-Godfrey (5 defasagens): ", leitura_p(dp[3]), "; Edgerton-Shukur: ", leitura_p(dp[4]),
  ". BG por numero de defasagens (1 a 8): ", n_bg1, " de 8 rejeitam a 1%, maior p-valor ", num(max(bg_lags$p_bg), 3),
  "; ES: ", n_es1, " de 8 rejeitam a 1% e ", n_es5, " de 8 a 5%, maior p-valor ", num(max(bg_lags$p_es), 3),
  ". ARCH-LM multivariado: ", leitura_p(dp[5]), ". Jarque-Bera multivariado: ", leitura_p(dp[6]), " (assimetria: ", leitura_p(dp[7]),
  "; curtose: ", leitura_p(dp[8]), "). Jarque-Bera univariado, equacao de INF: ", leitura_p(dp[9]), "; de PVD: ", leitura_p(dp[10]), ".")

log_part(ETAPA, "- Diagnosticos (H0 de cada teste: ausencia de autocorrelacao, de ARCH, normalidade): ",
         paste(sprintf("%s: estat. %s, p = %s", diag$teste, num(diag$estatistica, 2), pval(diag$p)), collapse = "; "), ".")
log_part(ETAPA, "- Leitura: ", txt_diag, " p-valor do BG e do ES por numero de defasagens: ",
         paste(sprintf("%d: %s e %s", bg_lags$lags.bg, num(bg_lags$p_bg, 3), num(bg_lags$p_es, 3)), collapse = "; "), ".")
log_part(ETAPA, "- Autocorrelacao residual. ", txt_autocorr)
log_part(ETAPA, "- No Rmd, serial.test(type = \"BG\"/\"ES\") foi chamado com lags.pt = 16, que esses testes ignoram; ",
         "o lag efetivo era o padrao lags.bg = 5 (conferido: mesma estatistica), o mesmo usado aqui. ARCH multivariado com lags.multi = ",
         LAGS_ARCH, " (padrao do vars, o mesmo do Rmd).")
log_part(ETAPA, "- Raizes do polinomio caracteristico (modulos): ", paste(num(raizes, 4), collapse = ", "),
         ". Todas menores que 1: ", ifelse(all(raizes < 1), "sim", "nao"), ".")
sel <- vsel$selection
crit_p <- names(sel)[sel == p]
crit_outros <- names(sel)[sel != p]
txt_vsel <- paste0("p = ", p, " e a escolha de ", paste(sub("\\(n\\)", "", crit_p), collapse = ", "),
                   if (length(crit_outros)) paste0("; ", paste(sprintf("%s prefere %s", sub("\\(n\\)", "", crit_outros), sel[crit_outros]), collapse = "; ")) else "",
                   ".")
log_part(ETAPA, "- VARselect(lag.max = 8, type = \"both\", exogen = diff(exo)): AIC = ", sel["AIC(n)"],
         ", HQ = ", sel["HQ(n)"], ", SC = ", sel["SC(n)"], ", FPE = ", sel["FPE(n)"], ". ", txt_vsel)

# ------------------------------------------------------------------------------------------------
# 6. Granger
# ------------------------------------------------------------------------------------------------
modelo_nivel <- vars::VAR(infmeq, p = 3, type = "both", exogen = exo)
gr <- function(mod, causa, rotulo) {
  g <- causality(mod, cause = causa)$Granger
  efeito <- setdiff(colnames(mod$y), causa)
  tibble(modelo = rotulo, hipotese = paste0(causa, " -> ", efeito), causa = causa, efeito = efeito, F = unname(g$statistic)[1],
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
alguma_056 <- any(vapply(var_pvd[, "p"], function(x) classifica(x, 0.56, 2) != "nao", TRUE))
gl_tab12 <- g_n_pvd$gl1 == 3 && g_n_pvd$gl2 == 116 && g_n_inf$gl1 == 3 && g_n_inf$gl2 == 116

log_part(ETAPA, "- Granger no VAR em diferenca (gl ", g_d_inf$gl1, " e ", g_d_inf$gl2, "): INF -> PVD F = ", num(g_d_inf$F, 2),
         ", p = ", num(g_d_inf$p, 3), "; PVD -> INF F = ", num(g_d_pvd$F, 2), ", p = ", num(g_d_pvd$p, 3), ".")
log_part(ETAPA, "- Granger no VAR em nivel (VAR(infmeq, p = 3, type = \"both\", exogen = exo)): INF -> PVD F = ", num(g_n_inf$F, 2),
         " (gl ", g_n_inf$gl1, " e ", g_n_inf$gl2, "), p = ", num(g_n_inf$p, 3), "; PVD -> INF F = ", num(g_n_pvd$F, 2),
         ", p = ", num(g_n_pvd$p, 3), ". ",
         ifelse(gl_tab12, "Os graus de liberdade 3 e 116 coincidem com os da Tabela 12: ela vem deste VAR.",
                "ATENCAO: os graus de liberdade nao coincidem com os da Tabela 12 (3 e 116)."))
# Convencao dos graus de liberdade: vars::causality usa gl2 = K(T - k) (sistema empilhado). Conferencia com o F classico
# equacao por equacao (gl2 = T - k) e com erros robustos a heterocedasticidade (HC3, padrao de sandwich::vcovHC).
X_gr <- as.data.frame(modelo$datamat[, -(1:K)])
f_eq <- function(causa, vc = NULL) {
  efeito <- setdiff(colnames(modelo$y), causa)
  yv <- modelo$datamat[, efeito]
  lu <- lm(yv ~ -1 + ., data = X_gr)
  lr <- lm(yv ~ -1 + ., data = X_gr[, !startsWith(names(X_gr), paste0(causa, ".l")), drop = FALSE])
  w <- if (is.null(vc)) waldtest(lu, lr, test = "F") else waldtest(lu, lr, vcov = vc(lu), test = "F")
  tibble(hipotese = paste0(causa, " -> ", efeito), F = w$F[2], gl1 = abs(w$Df[2]), gl2 = w$Res.Df[1], p = w$`Pr(>F)`[2])
}
g_hc_sis <- function(causa) {
  g <- causality(modelo, cause = causa, vcov. = sandwich::vcovHC(modelo))$Granger
  tibble(hipotese = paste0(causa, " -> ", setdiff(colnames(modelo$y), causa)), F = unname(g$statistic)[1],
         gl1 = unname(g$parameter)[1], gl2 = unname(g$parameter)[2], p = unname(g$p.value)[1])
}
granger_conv <- bind_rows(
  f_eq("INF") %>% mutate(versao = "F classico por equacao"),
  f_eq("PVD") %>% mutate(versao = "F classico por equacao"),
  f_eq("INF", function(m) sandwich::vcovHC(m, type = "HC3")) %>% mutate(versao = "por equacao, vcovHC (HC3)"),
  g_hc_sis("INF") %>% mutate(versao = "vars::causality, vcovHC (sistema)")
)
stopifnot(abs(granger_conv$F[1] - g_d_inf$F) < 1e-8, abs(granger_conv$F[2] - g_d_pvd$F) < 1e-8)
ge_inf <- granger_conv[1, ]; ge_pvd <- granger_conv[2, ]; gh_eq <- granger_conv[3, ]; gh_sis <- granger_conv[4, ]
conv_mantem <- all(c(ge_inf$p, gh_eq$p, gh_sis$p, g_d_inf$p) < 0.05) && ge_pvd$p >= 0.10 && g_d_pvd$p >= 0.10
txt_gr_conv <- paste0(
  "Convencao dos graus de liberdade: vars::causality testa no sistema empilhado, com gl ", g_d_inf$gl1, " e ", g_d_inf$gl2, " (K(T - k)). ",
  "O F classico equacao por equacao tem o mesmo F e gl ", ge_inf$gl1, " e ", ge_inf$gl2, ": INF -> PVD p = ", num(ge_inf$p, 3),
  "; PVD -> INF p = ", num(ge_pvd$p, 3), ". Com erros robustos a heterocedasticidade, INF -> PVD: F = ", num(gh_sis$F, 2), ", p = ",
  num(gh_sis$p, 3), " (vars::causality com sandwich::vcovHC, gl ", gh_sis$gl1, " e ", gh_sis$gl2, ") e p = ", num(gh_eq$p, 3),
  " (por equacao, HC3, gl ", gh_eq$gl1, " e ", gh_eq$gl2, "). O p = ", num(g_d_inf$p, 3), " depende da convencao; a conclusao ",
  ifelse(conv_mantem, "se mantem: INF Granger-causa PVD a 5% e PVD nao Granger-causa INF a 10%.", "muda com a convencao (ver tabela)."))
log_part(ETAPA, "- Granger, convencao. ", txt_gr_conv)
log_part(ETAPA, "- Correcao (A1, 28/09/2026) ao item de Granger de results/LOG.md, que atribui PVD -> INF F = 1,91 e p = 0,13 ao VAR em ",
         "diferenca: esse par e do VAR em nivel (Tabela 12, gl ", g_n_pvd$gl1, " e ", g_n_pvd$gl2, "). No VAR em diferenca, PVD -> INF tem F = ",
         num(g_d_pvd$F, 2), " e p = ", num(g_d_pvd$p, 2), "; INF -> PVD tem F = ", num(g_d_inf$F, 2), " e p = ", num(g_d_inf$p, 3),
         ", como o LOG ja diz. O texto do LOG.md fica como o autor escreveu; a correcao vale a partir deste registro. ",
         ifelse(alguma_056, "Alguma das variantes testadas reproduz o p = 0,56 (ver md).",
                "Nenhuma das variantes testadas (grangertest com 3 e 4 lags, VAR com vcov HC, VAR com p = 4) reproduz o p = 0,56 da dissertacao."))

# ------------------------------------------------------------------------------------------------
# 7. Johansen
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
spec_dif <- joh %>% group_by(ecdet, K, dumvar) %>% summarise(d = diff(range(traco_r0)), .groups = "drop") %>% pull(d) %>% max()
spec_neutro <- spec_dif < 1e-8
JOH_ROT_TEX <- "tend\\^encia restrita ao vetor de cointegra\\c{c}\\~ao, K = 2, dummy DUM irrestrita"
JOH_ROT_TXT <- "tendencia restrita ao vetor de cointegracao, K = 2, dummy DUM irrestrita"
txt_joh_nota <- paste0(
  "Ressalvas: as linhas com dumvar = exo (PIB e JUR sao regressores estocasticos) sao so descritivas, porque os valores criticos ",
  "tabelados de Osterwald-Lenum nao valem com regressores estocasticos no termo de curto prazo. Com DUM em degraus e amostra de ",
  length(TRIM), " trimestres, os valores criticos tabelados sao so aproximados. A correcao de Reinsel-Ahn e o bootstrap ficam para a A5. ",
  "Em urca::ca.jo com ecdet = \"trend\", a tendencia entra restrita ao vetor de cointegracao (ZK), e a constante e a dumvar entram no ",
  "termo de curto prazo irrestrito (Z1).")

# Contagem sobre as configuracoes distintas (spec nao altera o traco: fica so spec = longrun, a do Rmd)
stopifnot(spec_neutro)
joh_dist <- joh %>% filter(spec == "longrun")
joh_tab <- joh_dist %>% filter(dumvar != "exo (PIB, JUR, DUM)")  # valores criticos tabelados ou aproximados
n_joh <- nrow(joh_tab)
n_rej5 <- sum(joh_tab$traco_r0 > joh_tab$cv5_r0); n_rej10 <- sum(joh_tab$traco_r0 > joh_tab$cv10_r0)
n_rej5_r1 <- sum(joh_tab$traco_r1 > joh_tab$cv5_r1)
n_rej5_todas <- sum(joh_dist$traco_r0 > joh_dist$cv5_r0); n_rej10_todas <- sum(joh_dist$traco_r0 > joh_dist$cv10_r0)
j_semdum <- joh_dist %>% filter(ecdet == "trend", K == 2, dumvar == "nenhuma")
stopifnot(nrow(j_semdum) == 1, nrow(joh_ok) >= 1)
limitrofe <- joh_ok$traco_r0[1] < joh_ok$cv5_r0[1] && n_rej5 > 0 && n_rej10 == n_joh && n_rej5_r1 == 0
txt_joh_leitura <- paste0(
  "Nas ", n_joh, " configuracoes distintas sem regressores estocasticos (ecdet const ou trend, K 2 a 4, dumvar nenhuma ou DUM), ",
  n_rej5, " rejeitam r = 0 a 5% e ", n_rej10, " a 10%; ", if (n_rej5_r1 == 0) "nenhuma rejeita" else paste(n_rej5_r1, "rejeitam"),
  " r <= 1 a 5%. A configuracao do Rmd fica ",
  num(joh_ok$cv5_r0[1] - joh_ok$traco_r0[1], 2), " abaixo do valor critico de 5% (", num(joh_ok$traco_r0[1], 2), " contra ",
  num(joh_ok$cv5_r0[1], 2), "); sem a DUM, com tendencia e K = 2, o traco e ", num(j_semdum$traco_r0, 2), " contra ",
  num(j_semdum$cv5_r0, 2), ". Incluindo as ", nrow(joh_dist) - n_joh, " configuracoes com exo como dumvar (so descritivas), ",
  n_rej5_todas, " de ", nrow(joh_dist), " rejeitam a 5% e ", n_rej10_todas, " a 10%. ",
  if (limitrofe) "Leitura: evidencia limitrofe de um vetor de cointegracao, e nao ausencia de cointegracao. " else
    "Leitura: rever, o padrao de rejeicoes mudou. ",
  "Isso pesa na escolha entre VAR em diferenca e VEC: na A5, Johansen com correcao de Reinsel-Ahn e bootstrap (Cavaliere, Rahbek e ",
  "Taylor, 2012), VECM com r = 1 e VAR em nivel como robustez (plano em results/log_parts/A0_ambiente.md).")

if (nrow(joh_ok) > 0) {
  j1 <- joh_ok[1, ]
  concl_5 <- ifelse(j1$traco_r0 < j1$cv5_r0, "nao rejeita r = 0 a 5%", "rejeita r = 0 a 5%")
  concl_10 <- ifelse(j1$traco_r0 < j1$cv10_r0, "nao rejeita a 10%", "rejeita a 10%")
  concl_r1 <- ifelse(j1$traco_r1 < j1$cv5_r1, "nao rejeita r <= 1 a 5%", "rejeita r <= 1 a 5%")
  log_part(ETAPA, "- Johansen: ", nrow(joh), " configuracoes testadas (ecdet const/trend, K 2 a 4, spec transitory/longrun, ",
           "dumvar nenhuma/exo/DUM). Reproduzem traco 25,01 contra 25,32 (r = 0): ",
           paste(sprintf("ecdet = %s, K = %d, spec = %s, dumvar = %s", joh_ok$ecdet, joh_ok$K, joh_ok$spec, joh_ok$dumvar), collapse = "; "),
           ". E a chamada do Rmd (ca.jo(infmeq, type = \"trace\", ecdet = \"trend\", K = 2, spec = \"longrun\", dumvar = exo[, 3])). ",
           ifelse(spec_neutro, "spec nao altera a estatistica traco. ", "spec altera a estatistica traco. "),
           "Traco ", num(j1$traco_r0, 2), " contra ", num(j1$cv5_r0, 2), ": ", concl_5, "; ", concl_10, " (valor critico ", num(j1$cv10_r0, 2),
           "). Para r <= 1: ", num(j1$traco_r1, 2), " contra ", num(j1$cv5_r1, 2), ", ", concl_r1, ". Com dumvar = exo completo a estatistica e ",
           num(joh %>% filter(ecdet == "trend", K == 2, dumvar == "exo (PIB, JUR, DUM)") %>% pull(traco_r0) %>% first(), 2), ".")
} else {
  log_part(ETAPA, "- Johansen: nenhuma das ", nrow(joh), " configuracoes reproduz traco 25,01 contra 25,32.")
}
log_part(ETAPA, "- Johansen, leitura da grade. ", txt_joh_leitura)
log_part(ETAPA, "- Johansen. ", txt_joh_nota, " Na tabela LaTeX, o painel D passa a dizer '", JOH_ROT_TXT,
         "' (antes dizia 'dummy restrita', o que estava errado).")

# ------------------------------------------------------------------------------------------------
# 8. Decomposicao da variancia
# ------------------------------------------------------------------------------------------------
fv <- fevd(modelo, n.ahead = 40)
H_FEVD <- c(4, 8, 20, 40)
fevd_tab <- tibble(h = H_FEVD,
                   INF_por_INF = 100 * fv$INF[H_FEVD, "INF"], INF_por_PVD = 100 * fv$INF[H_FEVD, "PVD"],
                   PVD_por_INF = 100 * fv$PVD[H_FEVD, "INF"], PVD_por_PVD = 100 * fv$PVD[H_FEVD, "PVD"])
log_part(ETAPA, "- FEVD da variacao de PVD explicada pelo choque de INF: ",
         paste(sprintf("h = %d: %s%%", fevd_tab$h, num(fevd_tab$PVD_por_INF, 1)), collapse = "; "), ".")

# ------------------------------------------------------------------------------------------------
# 9. Transcricao das tabelas da dissertacao (capitulo 4 e Apendice B)
# Fonte: docs/dissertacao/dissertacao.txt (texto extraido do PDF; fora do git). A transcricao e gravada em
# data/processed/A1_alvos_dissertacao.csv, que vai para o git; sem o txt, o script le esse CSV (f_txt e f_alvos
# definidos e conferidos na secao 0).
# ------------------------------------------------------------------------------------------------

le_num <- function(s) {
  s <- gsub("\\*", "", gsub("−", "-", trimws(s)))
  dec <- regmatches(s, regexpr("[.,][0-9]+$", s))
  casas <- if (length(dec)) nchar(dec) - 1L else 0L
  list(valor = as.numeric(sub(",", ".", s, fixed = TRUE)), casas = casas, texto = s)
}

transcreve <- function(f) {
  L <- gsub("−", "-", readLines(f, warn = FALSE, encoding = "UTF-8"))
  toc_fim <- grep("^\\s*Tabela 18 .*\\. \\.", L)[1]
  stopifnot(!is.na(toc_fim))
  titulo <- function(n) { i <- grep(paste0("^\\s*Tabela ", n, " "), L); i <- i[i > toc_fim]; stopifnot(length(i) >= 1); i[1] }
  ate <- function(ini, padrao) { j <- grep(padrao, L); j <- j[j > ini]; stopifnot(length(j) >= 1); j[1] - 1 }
  reg <- list()
  add <- function(tabela, chave, descricao, s, linha) {
    v <- le_num(s)
    reg[[length(reg) + 1]] <<- tibble(tabela = tabela, chave = chave, descricao = descricao, valor_texto = v$texto,
                                       valor = v$valor, casas = v$casas, linha_txt = linha)
  }
  casa <- function(rx, i) regmatches(L[i], regexec(rx, L[i], perl = TRUE))[[1]]
  NUM <- "(-?[0-9]+(?:[.,][0-9]+)?\\**)"

  # Tabela 6: selecao da ordem
  i6 <- titulo(6); j <- i6 + which(grepl("^\\s*[0-9]+\\s+[0-9]+\\s+[0-9]+\\s+[0-9]+\\s*$", L[(i6 + 1):(i6 + 8)]))[1]
  m <- casa("^\\s*([0-9]+)\\s+([0-9]+)\\s+([0-9]+)\\s+([0-9]+)\\s*$", j)
  for (k in 1:4) add(6, paste0("t6_sel_", c("AIC", "HQ", "SC", "FPE")[k]), paste0("Defasagem escolhida pelo ", c("AIC", "HQ", "SC", "FPE")[k]), m[k + 1], j)

  # Tabela 7: testes estatisticos (colunas como impressas no texto)
  i7 <- titulo(7); rx7 <- paste0("^\\s*", NUM, "\\s+", NUM, "\\s+", NUM, "\\s+", NUM, "\\s*$")
  j <- i7 + which(grepl(rx7, L[(i7 + 1):(i7 + 6)], perl = TRUE))[1]
  m <- casa(rx7, j)
  add(7, "t7_col_autocorrelacao_estat", "Coluna 'Autocorrelacao' (nota: Portmanteau pequenas amostras, 16 lags), estatistica", m[2], j)
  add(7, "t7_col_autocorrelacao_p", "Coluna 'Autocorrelacao', p-valor", m[3], j)
  add(7, "t7_col_homocedasticidade_estat", "Coluna 'Homocedasticidade' (nota: ARCH-LM multivariado), estatistica", m[4], j)
  add(7, "t7_col_homocedasticidade_p", "Coluna 'Homocedasticidade', p-valor", m[5], j)

  # Tabela 8: Johansen
  i8 <- titulo(8); f8 <- ate(i8, "Fonte:")
  for (i in (i8 + 1):f8) {
    m <- casa(paste0("^\\s*r\\s*(<=\\s*1|=\\s*0)\\s+", NUM, "\\s+", NUM, "\\s*$"), i)
    if (length(m)) {
      r <- if (grepl("<=", m[2])) "r1" else "r0"
      add(8, paste0("t8_traco_", r), paste0("Johansen, traco, ", ifelse(r == "r0", "r = 0", "r <= 1")), m[3], i)
      add(8, paste0("t8_cv5_", r), paste0("Johansen, valor critico 5%, ", ifelse(r == "r0", "r = 0", "r <= 1")), m[4], i)
    }
  }

  # Tabelas 9 e 10: coeficientes das equacoes de INF (Ipub) e PVD (Imeq)
  mapa <- c("Ipub l1" = "INF.l1", "Imeq l1" = "PVD.l1", "Ipub l2" = "INF.l2", "Imeq l2" = "PVD.l2", "Ipub l3" = "INF.l3",
            "Imeq l3" = "PVD.l3", "k" = "const", "t" = "trend", "Cpib" = "PIB", "Cjur" = "JUR", "Cdummy" = "DUM")
  i9 <- titulo(9); i10 <- titulo(10); f10 <- ate(i10, "^4\\.5\\.3 ")
  rx9 <- paste0("^\\s*(Ipub l[1-3]|Imeq l[1-3]|k|t|Cpib|Cjur|Cdummy)\\s+", NUM, "\\s+", NUM, "\\s+", NUM, "\\s+", NUM, "\\s*$")
  for (i in i9:f10) {
    m <- casa(rx9, i)
    if (length(m)) {
      eq <- if (i < i10) "INF" else "PVD"; tb <- if (i < i10) 9 else 10
      est <- c("coef", "ep", "t", "p")
      for (k in 1:4) add(tb, sprintf("t%d_%s_%s_%s", tb, eq, mapa[[m[2]]], est[k]),
                         sprintf("Equacao de %s, %s (%s), %s", eq, m[2], mapa[[m[2]]], c("coeficiente", "erro padrao", "valor t", "p-valor")[k]),
                         m[k + 2], i)
    }
  }

  # Tabela 11: covariancia, correlacao e Cholesky
  i11 <- titulo(11); f11 <- ate(i11, "^\\s*Procedeu-se")
  linhas11 <- (i11 + 1):f11
  linhas11 <- linhas11[grepl(paste0("^\\s*(Ipub|Imeq)\\s+", NUM, "\\s+", NUM, "\\s*$"), L[linhas11], perl = TRUE)]
  stopifnot(length(linhas11) == 6)
  blocos <- c("cov", "cov", "cor", "cor", "chol", "chol")
  for (k in seq_along(linhas11)) {
    m <- casa(paste0("^\\s*(Ipub|Imeq)\\s+", NUM, "\\s+", NUM, "\\s*$"), linhas11[k])
    lin <- ifelse(m[2] == "Ipub", "INF", "PVD")
    add(11, sprintf("t11_%s_%s_INF", blocos[k], lin), sprintf("Tabela 11, %s, linha %s, coluna INF", blocos[k], lin), m[3], linhas11[k])
    add(11, sprintf("t11_%s_%s_PVD", blocos[k], lin), sprintf("Tabela 11, %s, linha %s, coluna PVD", blocos[k], lin), m[4], linhas11[k])
  }

  # Tabela 12: Granger (linha Ipub = INF como causa)
  i12 <- titulo(12); f12 <- ate(i12, "Fonte:")
  for (i in (i12 + 1):f12) {
    m <- casa(paste0("^\\s*(Ipub|Imeq)\\s+", NUM, "\\s+([0-9]+)\\s+([0-9]+)\\s+", NUM, "\\s*$"), i)
    if (length(m)) {
      cz <- ifelse(m[2] == "Ipub", "INF", "PVD")
      for (k in 1:4) add(12, sprintf("t12_causa_%s_%s", cz, c("F", "gl1", "gl2", "p")[k]),
                         sprintf("Granger, causa %s, %s", cz, c("F", "gl1", "gl2", "p-valor")[k]), m[k + 2], i)
    }
  }

  # Tabela 14: criterios de informacao
  i14 <- titulo(14)
  for (i in (i14 + 1):(i14 + 12)) {
    m <- casa(paste0("^\\s*(AIC|HQ|SC|FPE)", paste(rep(paste0("\\s+", NUM), 8), collapse = ""), "\\s*$"), i)
    if (length(m)) for (k in 1:8) add(14, sprintf("t14_%s_%d", m[2], k), sprintf("VARselect, %s com %d defasagens", m[2], k), m[k + 2], i)
  }

  # Tabela 15: raizes
  i15 <- titulo(15)
  for (i in (i15 + 1):(i15 + 6)) {
    m <- casa(paste0("^\\s*", paste(rep(NUM, 6), collapse = "\\s+"), "\\s*$"), i)
    if (length(m)) { for (k in 1:6) add(15, sprintf("t15_raiz_%d", k), sprintf("Modulo da raiz %d", k), m[k + 1], i); break }
  }

  # Tabela 16: resposta acumulada de PVD ao choque de INF, h = 0 a 40 (so a coluna do ponto)
  i16 <- titulo(16); f16 <- ate(i16, "^B\\.3 ")
  h <- 0
  for (i in (i16 + 1):f16) {
    m <- casa(paste0("^\\s*", NUM, "\\s+", NUM, "\\s+", NUM, "\\s*$"), i)
    if (length(m)) { add(16, sprintf("t16_irfcum_PVD_h%02d", h), sprintf("Resposta acumulada de PVD ao choque de INF, h = %d", h), m[2], i); h <- h + 1 }
  }

  # Tabelas 17 e 18: FEVD (n.ahead = 30)
  i17 <- titulo(17); i18 <- titulo(18)
  for (tb in c(17, 18)) {
    ini <- if (tb == 17) i17 else i18; fim <- if (tb == 17) i18 - 1 else length(L)
    eq <- if (tb == 17) "INF" else "PVD"; h <- 1
    for (i in (ini + 1):fim) {
      m <- casa(paste0("^\\s*", NUM, "\\s+", NUM, "\\s*$"), i)
      if (length(m)) {
        add(tb, sprintf("t%d_fevd_%s_por_INF_h%02d", tb, eq, h), sprintf("FEVD de %s, parcela do choque de INF, h = %d", eq, h), m[2], i)
        add(tb, sprintf("t%d_fevd_%s_por_PVD_h%02d", tb, eq, h), sprintf("FEVD de %s, parcela do choque de PVD, h = %d", eq, h), m[3], i)
        h <- h + 1
      }
    }
  }
  out <- bind_rows(reg)
  cont <- table(out$tabela)
  stopifnot(cont[["6"]] == 4, cont[["7"]] == 4, cont[["8"]] == 4, cont[["9"]] == 44, cont[["10"]] == 44, cont[["11"]] == 12,
            cont[["12"]] == 8, cont[["14"]] == 32, cont[["15"]] == 6, cont[["16"]] == 41, cont[["17"]] == 60, cont[["18"]] == 60,
            !anyDuplicated(out$chave), !anyNA(out$valor))
  out
}

if (file.exists(f_txt)) {
  alvos_diss <- transcreve(f_txt)
  write_csv_safe(alvos_diss, f_alvos)
  origem_alvos <- paste0("transcritos por codigo de ", f_txt, " e gravados em ", f_alvos)
} else {
  alvos_diss <- readr::read_csv(f_alvos, show_col_types = FALSE, col_types = readr::cols(valor_texto = "c"))
  origem_alvos <- paste0("lidos de ", f_alvos, " (", f_txt, " ausente)")
}

# Valores obtidos com as mesmas chaves
fv30 <- fevd(modelo, n.ahead = 30)
cf <- list(INF = coef(modelo)$INF, PVD = coef(modelo)$PVD)
obt <- c(
  setNames(as.numeric(sel), paste0("t6_sel_", sub("\\(n\\)", "", names(sel)))),
  # Tabela 7 com os rotulos corrigidos: a coluna 'Autocorrelacao' traz o ARCH-LM e a 'Homocedasticidade' o Portmanteau ajustado
  t7_col_autocorrelacao_estat = unname(arch$statistic), t7_col_autocorrelacao_p = unname(arch$p.value),
  t7_col_homocedasticidade_estat = unname(pt_adj$statistic), t7_col_homocedasticidade_p = unname(pt_adj$p.value),
  t8_traco_r0 = joh_ok$traco_r0[1], t8_cv5_r0 = joh_ok$cv5_r0[1], t8_traco_r1 = joh_ok$traco_r1[1], t8_cv5_r1 = joh_ok$cv5_r1[1],
  t11_cov_INF_INF = S["INF", "INF"], t11_cov_INF_PVD = S["INF", "PVD"], t11_cov_PVD_INF = S["PVD", "INF"], t11_cov_PVD_PVD = S["PVD", "PVD"],
  t11_cor_INF_INF = R["INF", "INF"], t11_cor_INF_PVD = R["INF", "PVD"], t11_cor_PVD_INF = R["PVD", "INF"], t11_cor_PVD_PVD = R["PVD", "PVD"],
  t11_chol_INF_INF = P_chol["INF", "INF"], t11_chol_INF_PVD = P_chol["INF", "PVD"], t11_chol_PVD_INF = P_chol["PVD", "INF"],
  t11_chol_PVD_PVD = P_chol["PVD", "PVD"],
  t12_causa_INF_F = g_n_inf$F, t12_causa_INF_gl1 = g_n_inf$gl1, t12_causa_INF_gl2 = g_n_inf$gl2, t12_causa_INF_p = g_n_inf$p,
  t12_causa_PVD_F = g_n_pvd$F, t12_causa_PVD_gl1 = g_n_pvd$gl1, t12_causa_PVD_gl2 = g_n_pvd$gl2, t12_causa_PVD_p = g_n_pvd$p,
  setNames(as.vector(t(vsel$criteria)), sprintf("t14_%s_%d", rep(sub("\\(n\\)", "", rownames(vsel$criteria)), each = 8), rep(1:8, 4))),
  setNames(as.numeric(raizes), sprintf("t15_raiz_%d", seq_along(raizes))),
  setNames(cum[, "PVD"], sprintf("t16_irfcum_PVD_h%02d", 0:40)),
  setNames(fv30$INF[, "INF"], sprintf("t17_fevd_INF_por_INF_h%02d", 1:30)), setNames(fv30$INF[, "PVD"], sprintf("t17_fevd_INF_por_PVD_h%02d", 1:30)),
  setNames(fv30$PVD[, "INF"], sprintf("t18_fevd_PVD_por_INF_h%02d", 1:30)), setNames(fv30$PVD[, "PVD"], sprintf("t18_fevd_PVD_por_PVD_h%02d", 1:30))
)
for (eq in c("INF", "PVD")) {
  tb <- if (eq == "INF") 9 else 10
  m <- cf[[eq]]
  for (rg in rownames(m)) {
    v <- m[rg, c("Estimate", "Std. Error", "t value", "Pr(>|t|)")]
    obt[sprintf("t%d_%s_%s_%s", tb, eq, rg, c("coef", "ep", "t", "p"))] <- unname(v)
  }
}
cmp_diss <- alvos_diss %>%
  mutate(obtido = unname(obt[chave]),
         reproduz = pmap_chr(list(obtido, valor, casas), classifica),
         dif = abs(obtido - valor))
stopifnot(!anyNA(cmp_diss$obtido))

# Nao reproduzidos esperados: o 42,33 da Tabela 7 (o ARCH da 42,23) e o p = 0,56 da Tabela 12.
NAO_ESPERADOS <- c("t7_col_autocorrelacao_estat", "t12_causa_PVD_p")
nao_repr <- cmp_diss$chave[cmp_diss$reproduz == "nao"]
if (!setequal(nao_repr, NAO_ESPERADOS)) {
  print(as.data.frame(cmp_diss %>% filter(chave %in% union(setdiff(nao_repr, NAO_ESPERADOS), setdiff(NAO_ESPERADOS, nao_repr)))))
  stop("Reproducao das tabelas da dissertacao diferente da esperada.")
}
dif16 <- max(cmp_diss$dif[cmp_diss$tabela == 16])
stopifnot(dif16 < 1e-8)

# Tabela 7: os rotulos do texto estao trocados. Conferencia nos dois sentidos.
t7 <- function(ch) alvos_diss$valor[alvos_diss$chave == ch]
t7c <- function(ch) alvos_diss$casas[alvos_diss$chave == ch]
rot_texto_falha <- classifica(pt_adj$statistic, t7("t7_col_autocorrelacao_estat"), 2) == "nao" &&
  classifica(arch$statistic, t7("t7_col_homocedasticidade_estat"), 2) == "nao"
rot_troca_bate <- classifica(pt_adj$statistic, t7("t7_col_homocedasticidade_estat"), 2) != "nao" &&
  classifica(pt_adj$p.value, t7("t7_col_homocedasticidade_p"), t7c("t7_col_homocedasticidade_p")) != "nao" &&
  classifica(arch$p.value, t7("t7_col_autocorrelacao_p"), t7c("t7_col_autocorrelacao_p")) != "nao" &&
  abs(arch$statistic - t7("t7_col_autocorrelacao_estat")) < 0.15
stopifnot(rot_texto_falha, rot_troca_bate)

# p = 0,56 da Tabela 12 contra a propria estatistica impressa
F12 <- alvos_diss$valor[alvos_diss$chave == "t12_causa_PVD_F"]
gl12 <- c(alvos_diss$valor[alvos_diss$chave == "t12_causa_PVD_gl1"], alvos_diss$valor[alvos_diss$chave == "t12_causa_PVD_gl2"])
p12 <- alvos_diss$valor[alvos_diss$chave == "t12_causa_PVD_p"]
p_impl <- 1 - pf(F12, gl12[1], gl12[2])
F_p056 <- qf(1 - p12, gl12[1], gl12[2])
txt_p056 <- paste0("p = ", num(p12, 2), " e incompativel com F = ", num(F12, 2), " e gl (", gl12[1], ", ", gl12[2],
                   ") da propria Tabela 12, que implicam p = ", num(p_impl, 3), "; para dar p = ", num(p12, 2), " seria preciso F = ",
                   num(F_p056, 2), ". Logo, 0,56 e erro de transcricao, e nao outra especificacao.")

resumo_diss <- cmp_diss %>% group_by(tabela) %>%
  summarise(n = n(), arredondamento = sum(reproduz == "arredondamento"), truncamento = sum(reproduz == "truncamento"),
            duplo = sum(reproduz == "arredondamento duplo"), nao = sum(reproduz == "nao"), dif_max = max(dif), .groups = "drop") %>%
  mutate(conteudo = recode(as.character(tabela), "6" = "Selecao da ordem", "7" = "Portmanteau ajustado e ARCH-LM (rotulos corrigidos)",
                           "8" = "Johansen", "9" = "Coeficientes, equacao de INF", "10" = "Coeficientes, equacao de PVD",
                           "11" = "Covariancia, correlacao e Cholesky", "12" = "Granger (VAR em nivel)",
                           "14" = "VARselect, criterios 1 a 8", "15" = "Modulos das raizes",
                           "16" = "Resposta acumulada de PVD, h = 0 a 40", "17" = "FEVD de INF, h = 1 a 30", "18" = "FEVD de PVD, h = 1 a 30"))

log_part(ETAPA, "- Alvos da dissertacao (Tabelas 6 a 12 e 14 a 18): ", nrow(alvos_diss), " valores ", origem_alvos, ". ",
         paste(sprintf("Tabela %d: %d valores, %d por arredondamento, %d por truncamento, %d por arredondamento duplo, %d nao reproduzidos",
                       resumo_diss$tabela, resumo_diss$n, resumo_diss$arredondamento, resumo_diss$truncamento, resumo_diss$duplo,
                       resumo_diss$nao), collapse = "; "),
         ". Tabela 16 (41 valores com 9 casas): diferenca maxima ", sci(dif16), " (stopifnot < 1e-8). ",
         "Os nao reproduzidos sao so os esperados: ", paste(NAO_ESPERADOS, collapse = " e "), ".")
duplos <- cmp_diss %>% filter(reproduz == "arredondamento duplo")
txt_duplo <- if (nrow(duplos)) paste0(
  "Arredondamento duplo: ", paste(sprintf("%s (obtido %s, impresso %s)", duplos$descricao, num(duplos$obtido, 4), duplos$valor_texto), collapse = "; "),
  ". Batem se o valor foi primeiro impresso pelo R com uma casa a mais (summary.lm mostra o valor t com 3 casas: ",
  paste(num(round(duplos$obtido, duplos$casas + 1), duplos$casas + 1), collapse = " e "),
  ") e depois arredondado para ", paste(unique(duplos$casas), collapse = " e "), " casas com metade para cima.") else
  "Nenhum valor exigiu arredondamento duplo."
log_part(ETAPA, "- ", txt_duplo)
log_part(ETAPA, "- Correcao do texto, Tabela 7: os rotulos estao trocados. A coluna 'Autocorrelacao' traz ", num(t7("t7_col_autocorrelacao_estat"), 2),
         " (p = ", alvos_diss$valor_texto[alvos_diss$chave == "t7_col_autocorrelacao_p"], "), que e o ARCH-LM multivariado (", num(arch$statistic, 2),
         ", p = ", num(arch$p.value, 4), "; o 42,33 e erro de digitacao de ", num(arch$statistic, 2), "). A coluna 'Homocedasticidade' traz ",
         num(t7("t7_col_homocedasticidade_estat"), 2), " (p = ", alvos_diss$valor_texto[alvos_diss$chave == "t7_col_homocedasticidade_p"],
         "), que e o Portmanteau ajustado com 16 lags (", num(pt_adj$statistic, 2), ", p = ", num(pt_adj$p.value, 4), "). As conclusoes nao mudam.")
log_part(ETAPA, "- Tabela 12, p-valor de PVD -> INF: ", txt_p056)
log_part(ETAPA, "- Porte do Rmd: na ultima secao (a partir da linha ", i_sec, "), a linha ", i_d2uci, " (dados2 <- UCI[,1]) vem logo antes de ",
         "modelo=VAR(dados,p=3,...,exogen = dados2) (linha ", i_var, ") e sobrescreve o dados2 <- diff(exo) da linha ", i_d2diff, ". ",
         "UCI nao e definido nessa secao (so nas linhas ", paste(i_uci, collapse = " e "), ", de secoes anteriores). A chamada literal do Rmd ",
         "nao usa diff(exo). A especificacao com exogen = diff(exo) foi identificada por reproduzir as Tabelas 9 e 10 (",
         sum(cmp_diss$tabela %in% 9:10 & cmp_diss$reproduz != "nao"), " de ", sum(cmp_diss$tabela %in% 9:10), " valores) e a Tabela 16 ",
         "(diferenca maxima ", sci(dif16), "), e pelas equacoes 4.22 e 4.23, que trazem Cpib, Cjur e Cdummy como exogenas.")

# ------------------------------------------------------------------------------------------------
# 10. Tabela de alvos principal
# ------------------------------------------------------------------------------------------------
av <- function(ch) alvos_diss$valor[alvos_diss$chave == ch]
ac <- function(ch) alvos_diss$casas[alvos_diss$chave == ch]
alvos <- tribble(
  ~item, ~fonte, ~alvo, ~casas, ~obtido,
  "Impacto ortogonal de INF em PVD (h = 0)", "LOG (Python); Tabelas 11 e 16", 0.0118, 4, impacto,
  "Resposta acumulada de PVD, h = 40", "LOG (Python); Tabela 16", 0.0194, 4, acum_pvd,
  "Resposta acumulada de INF, h = 40", "LOG (Python)", 0.0465, 4, acum_inf,
  "Elasticidade de longo prazo (PVD/INF acumulados, h = 40)", "LOG (Python)", 0.42, 2, elast,
  "var(u_INF)", "Tabela 11", av("t11_cov_INF_INF"), ac("t11_cov_INF_INF"), S["INF", "INF"],
  "cov(u_INF, u_PVD)", "Tabela 11", av("t11_cov_INF_PVD"), ac("t11_cov_INF_PVD"), S["INF", "PVD"],
  "var(u_PVD)", "Tabela 11", av("t11_cov_PVD_PVD"), ac("t11_cov_PVD_PVD"), S["PVD", "PVD"],
  "corr(u_INF, u_PVD)", "Tabela 11", av("t11_cor_INF_PVD"), ac("t11_cor_INF_PVD"), R["INF", "PVD"],
  "Cholesky, elemento (INF, INF)", "Tabela 11", av("t11_chol_INF_INF"), ac("t11_chol_INF_INF"), P_chol["INF", "INF"],
  "Cholesky, elemento (PVD, PVD)", "Tabela 11", av("t11_chol_PVD_PVD"), ac("t11_chol_PVD_PVD"), P_chol["PVD", "PVD"],
  "Granger INF -> PVD, VAR em diferenca, F", "LOG (Python)", 3.27, 2, g_d_inf$F,
  "Granger INF -> PVD, VAR em diferenca, p", "LOG (Python)", 0.024, 3, g_d_inf$p,
  "Granger PVD -> INF, VAR em diferenca, F", "LOG anterior (atribuicao errada)", 1.91, 2, g_d_pvd$F,
  "Granger PVD -> INF, VAR em diferenca, p", "LOG anterior (atribuicao errada)", 0.13, 2, g_d_pvd$p,
  "Granger INF -> PVD, VAR em nivel, F", "Tabela 12", av("t12_causa_INF_F"), ac("t12_causa_INF_F"), g_n_inf$F,
  "Granger INF -> PVD, VAR em nivel, p", "Tabela 12", av("t12_causa_INF_p"), ac("t12_causa_INF_p"), g_n_inf$p,
  "Granger PVD -> INF, VAR em nivel, F", "Tabela 12", av("t12_causa_PVD_F"), ac("t12_causa_PVD_F"), g_n_pvd$F,
  "Granger PVD -> INF, VAR em nivel, p", "Tabela 12", av("t12_causa_PVD_p"), ac("t12_causa_PVD_p"), g_n_pvd$p,
  "Johansen, traco r = 0 (config. do Rmd)", "Tabela 8", av("t8_traco_r0"), ac("t8_traco_r0"), joh_ok$traco_r0[1],
  "Johansen, valor critico 5% r = 0", "Tabela 8", av("t8_cv5_r0"), ac("t8_cv5_r0"), joh_ok$cv5_r0[1],
  "Johansen, traco r <= 1", "Tabela 8", av("t8_traco_r1"), ac("t8_traco_r1"), joh_ok$traco_r1[1],
  "Johansen, valor critico 5% r <= 1", "Tabela 8", av("t8_cv5_r1"), ac("t8_cv5_r1"), joh_ok$cv5_r1[1],
  "Portmanteau ajustado (16 lags), estatistica (impressa na coluna 'Homocedasticidade')", "Tabela 7",
  av("t7_col_homocedasticidade_estat"), ac("t7_col_homocedasticidade_estat"), unname(pt_adj$statistic),
  "Portmanteau ajustado (16 lags), p-valor", "Tabela 7", av("t7_col_homocedasticidade_p"), ac("t7_col_homocedasticidade_p"), unname(pt_adj$p.value),
  "ARCH-LM multivariado (5 lags), estatistica (impressa na coluna 'Autocorrelacao')", "Tabela 7",
  av("t7_col_autocorrelacao_estat"), ac("t7_col_autocorrelacao_estat"), unname(arch$statistic),
  "ARCH-LM multivariado (5 lags), p-valor", "Tabela 7", av("t7_col_autocorrelacao_p"), ac("t7_col_autocorrelacao_p"), unname(arch$p.value),
  "VARselect, defasagem pelo AIC", "Tabela 6", av("t6_sel_AIC"), 0, as.numeric(sel["AIC(n)"]),
  "VARselect, defasagem pelo HQ", "Tabela 6", av("t6_sel_HQ"), 0, as.numeric(sel["HQ(n)"]),
  "VARselect, defasagem pelo SC", "Tabela 6", av("t6_sel_SC"), 0, as.numeric(sel["SC(n)"]),
  "VARselect, defasagem pelo FPE", "Tabela 6", av("t6_sel_FPE"), 0, as.numeric(sel["FPE(n)"])
) %>% mutate(classe = pmap_chr(list(obtido, alvo, casas), classifica),
             reproduz = pmap_chr(list(obtido, alvo, casas), compara))

# Nao reproduzidos esperados na tabela principal (protege os textos abaixo)
NAO_PRINC <- c("Granger PVD -> INF, VAR em diferenca, F", "Granger PVD -> INF, VAR em diferenca, p",
               "Granger PVD -> INF, VAR em nivel, p", "ARCH-LM multivariado (5 lags), estatistica (impressa na coluna 'Autocorrelacao')")
stopifnot(setequal(alvos$item[alvos$classe == "nao"], NAO_PRINC))

for (i in seq_len(nrow(alvos))) {
  log_part(ETAPA, "- Alvo: ", alvos$item[i], " [", alvos$fonte[i], "]: alvo ", num(alvos$alvo[i], alvos$casas[i]), ", obtido ",
           num(alvos$obtido[i], 4), " (", sig(alvos$obtido[i], 6), "); reproduz: ", alvos$reproduz[i], ".")
}
trunc_itens <- alvos %>% filter(classe == "truncamento")
txt_trunc <- paste0(
  "Batem so por truncamento, nao por arredondamento: ",
  paste(sprintf("%s (%s no texto; arredondado seria %s)", trunc_itens$item, num(trunc_itens$alvo, trunc_itens$casas),
                num(round(trunc_itens$obtido, trunc_itens$casas), trunc_itens$casas)), collapse = "; "),
  ". Nas Tabelas 6 a 18, ", sum(cmp_diss$reproduz == "truncamento"), " de ", nrow(cmp_diss),
  " valores batem so por truncamento; o texto trunca parte dos numeros. As respostas ao impulso da tabela principal batem por ",
  ifelse(all(alvos$classe[1:3] == "arredondamento"), "arredondamento", "truncamento em parte"), ".")
log_part(ETAPA, "- ", txt_trunc)

# ------------------------------------------------------------------------------------------------
# 11. Correcoes ao texto antigo (lista gerada a partir dos valores)
# ------------------------------------------------------------------------------------------------
j1 <- joh_ok[1, ]
correcoes <- c(
  sprintf("Granger. Tabela 12 (VAR em nivel, gl %d e %d): INF -> PVD F = %s, p = %s (o texto imprime %s e %s); PVD -> INF F = %s, p = %s (o texto imprime %s e %s). VAR em diferenca (baseline, gl %d e %d): INF -> PVD F = %s, p = %s; PVD -> INF F = %s, p = %s.",
          g_n_inf$gl1, g_n_inf$gl2, num(g_n_inf$F, 2), num(g_n_inf$p, 3), alvos_diss$valor_texto[alvos_diss$chave == "t12_causa_INF_F"],
          alvos_diss$valor_texto[alvos_diss$chave == "t12_causa_INF_p"], num(g_n_pvd$F, 2), num(g_n_pvd$p, 2),
          alvos_diss$valor_texto[alvos_diss$chave == "t12_causa_PVD_F"], alvos_diss$valor_texto[alvos_diss$chave == "t12_causa_PVD_p"],
          g_d_inf$gl1, g_d_inf$gl2, num(g_d_inf$F, 2), num(g_d_inf$p, 3), num(g_d_pvd$F, 2), num(g_d_pvd$p, 2)),
  paste0("Granger, p = 0,56: ", txt_p056),
  sprintf("Tabela 7: rotulos trocados. Portmanteau ajustado (16 defasagens) = %s, p = %s; ARCH-LM multivariado = %s, p = %s (o texto imprime 42,33 e 0,589 sob 'Autocorrelacao' e 52,34 e 0,46 sob 'Homocedasticidade'). A leitura desses dois testes nao muda; a de autocorrelacao muda com os testes do item seguinte.",
          num(pt_adj$statistic, 2), num(pt_adj$p.value, 2), num(arch$statistic, 2), num(arch$p.value, 2)),
  paste0("Autocorrelacao residual (secao 4.5.1: 'ausencia de autocorrelacao residual', com base so no Portmanteau). ", txt_autocorr),
  sprintf("Johansen (Tabela 8): traco %s contra valor critico de 5%% de %s, %s; %s (valor critico %s). %sEvidencia limitrofe de um vetor de cointegracao (%d de %d configuracoes sem regressores estocasticos rejeitam r = 0 a 5%%, %d de %d a 10%%; a configuracao do Rmd fica %s abaixo do valor critico de 5%%), e nao ausencia de cointegracao. O texto diz que a nula de nao cointegracao e rejeitada e, na frase seguinte, que as variaveis nao sao cointegradas. Plano da A5: Johansen com correcao de Reinsel-Ahn e bootstrap, VECM com r = 1 e VAR em nivel como robustez.",
          num(j1$traco_r0, 2), num(j1$cv5_r0, 2), concl_5, concl_10, num(j1$cv10_r0, 2),
          if (limitrofe) "" else "ATENCAO: o padrao de rejeicoes da grade mudou; rever esta leitura. ",
          n_rej5, n_joh, n_rej10, n_joh, num(j1$cv5_r0 - j1$traco_r0, 2)),
  sprintf("Dummy: no arquivo, DUM = 1 em %s; o texto (secoes 4.5.2 e 4.5.3) diz do terceiro trimestre de 2018 ao quarto de 2019.", txt_dum),
  sprintf("Magnitude: o texto diz que um choque de 1%% gera cerca de 2%%. A resposta acumulada de PVD em 40 trimestres e %s em log10, a um choque de um desvio padrao que eleva INF em %s no impacto e %s no acumulado; a elasticidade de longo prazo e %s (IC 90%% percentil %s; basico de Hall %s; Kilian %s, IC %s). Os tres IC vem de bootstrap iid de residuos e ficam condicionados a ausencia de autocorrelacao residual (ver o item de autocorrelacao).",
          num(acum_pvd, 4), num(cum[1, "INF"], 4), num(acum_inf, 4), num(elast, 2), ic_txt(q_el[1], q_el[2], 2),
          ic_txt(bel$hall_inf, bel$hall_sup, 2), num(bel$ponto_c, 2), ic_txt(bel$bab_inf, bel$bab_sup, 2)),
  paste0("Unidade de INF. ", txt_unidade),
  "Truncamento: parte dos numeros do texto e truncada, nao arredondada (ver a tabela de alvos). Na versao nova, arredondar."
)
log_part(ETAPA, "- Correcoes ao texto antigo (lista para o paper): ", paste(sprintf("(%d) %s", seq_along(correcoes), correcoes), collapse = " "))

# ------------------------------------------------------------------------------------------------
# 12. Figura: IRF acumulada com IC 90%
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
  painel("INF", "Investimento público (INF, nominal)") +
  plot_annotation(caption = paste0("Choque ortogonal de um desvio padrão em INF (Cholesky, INF antes de PVD). ",
                                   "\nFaixa: IC 90% por bootstrap de resíduos (percentil), 2000 réplicas.",
                                   " INF do arquivo original é nominal."),
                  theme = theme(plot.caption = element_text(size = 8, colour = "grey30", hjust = 0)))
f_png <- file.path(PATHS$figuras, "A1_irf_acumulada.png")
f_pdf <- file.path(PATHS$figuras, "A1_irf_acumulada.pdf")
ggsave_safe(f_png, fig, width = 8, height = 3.4, dpi = 300, bg = "white")
ggsave_safe(f_pdf, fig, width = 8, height = 3.4, device = if (capabilities("cairo")) cairo_pdf else "pdf")

# ------------------------------------------------------------------------------------------------
# 13. Relatorio em markdown
# ------------------------------------------------------------------------------------------------
H_TAB <- c(0, 1, 2, 4, 8, 12, 20, 40)
irf_tab <- tibble(h = H_TAB,
                  PVD = num(cum[H_TAB + 1, "PVD"]), `IC90 PVD` = ic_txt(lo[H_TAB + 1, "PVD"], up[H_TAB + 1, "PVD"]),
                  INF = num(cum[H_TAB + 1, "INF"]), `IC90 INF` = ic_txt(lo[H_TAB + 1, "INF"], up[H_TAB + 1, "INF"]),
                  `PVD/INF` = num(cum[H_TAB + 1, "PVD"] / cum[H_TAB + 1, "INF"], 2))

vsel_tab <- as_tibble(t(vsel$criteria), rownames = "p") %>%
  mutate(across(c(`AIC(n)`, `HQ(n)`, `SC(n)`), ~ num(.x, 4)), `FPE(n)` = formatC(`FPE(n)`, format = "e", digits = 4, decimal.mark = ","))

dig_b <- c(4, 4, 4, 2)
md <- c(
  "# A1. Replica em R do modelo final da dissertacao",
  "",
  sprintf("Gerado por `R/A1_replica.R` em %s. Numeros com virgula decimal. Respostas em log10 (os dados estao em log10).", format(Sys.time(), "%Y-%m-%d %H:%M")),
  "",
  "## Especificacao",
  "",
  sprintf("- Dados: `data/original/0224_tri_estmeq.txt` (INF e PVD em log10) e `data/original/0124_inexo.txt` (PIB, JUR e DUM), %d trimestres de %s a %s.", length(TRIM), TRIM[1], TRIM[length(TRIM)]),
  sprintf("- %s Fonte da comparacao: `%s` (A2). Para estender o baseline na A5, usar a Meta Selic no fim do trimestre, para ser comparavel, e a media do trimestre como robustez.", txt_jur, f_a2_selic),
  sprintf("- %s Fonte da comparacao: `%s` (A2).", txt_pib, f_a2_pib),
  sprintf("- Modelo: `vars::VAR(diff(infmeq), p = 3, type = \"both\", exogen = diff(exo))`, %d observacoes efetivas (%s a %s). Choque ortogonal por Cholesky com INF antes de PVD.", modelo$obs, TRIM_EF[1], TRIM_EF[2]),
  sprintf("- Datas conferidas com `data/dados_dissertacao_apendiceA.csv` (que tem a coluna de trimestre): Selic identica ao JUR (diferenca maxima %s), PIB identico a cpib_pct/100 (diferenca maxima %s), correlacao de diff(log10(imeq_indice)) com diff(PVD) = %s.", sci(dif_selic), sci(dif_pib), num(cor_pvd, 4)),
  sprintf("- Dummy: DUM = 1 em %s, igual ao registrado no LOG.md. Em diferenca vira pulsos (%s).", txt_dum, pulsos),
  sprintf("- Porte do Rmd: na ultima secao, `dados2 <- UCI[,1]` (linha %d) vem logo antes de `modelo=VAR(dados,p=3,...,exogen = dados2)` (linha %d) e sobrescreve `dados2 <- diff(exo)` (linha %d); `UCI` nao e definido nessa secao. A chamada literal nao usa `diff(exo)`. A especificacao com `exogen = diff(exo)` foi identificada por reproduzir as Tabelas 9, 10 e 16 (abaixo) e pelas equacoes 4.22 e 4.23 (Cpib, Cjur e Cdummy como exogenas).", i_d2uci, i_var, i_d2diff),
  "",
  "## Ressalva de unidade",
  "",
  txt_unidade,
  "",
  "## Comparacao com os alvos",
  "",
  md_table(alvos %>% transmute(Item = item, Fonte = fonte, Alvo = num(alvo, casas), `Obtido (4 casas)` = num(obtido, 4),
                               `Obtido (6 alg.)` = sig(obtido, 6), Reproduz = reproduz)),
  "Notas:",
  "",
  paste0("- ", txt_trunc),
  sprintf("- O par F = 1,91 e p = 0,13 para PVD -> INF nao vem do VAR em diferenca: nele F = %s e p = %s. Vem do VAR em nivel (gl %d e %d), o da Tabela 12. O item de Granger de `results/LOG.md` atribui esse par ao VAR em diferenca; a correcao datada esta em `results/log_parts/A1.md` (o coordenador consolida no LOG).",
          num(g_d_pvd$F, 2), num(g_d_pvd$p, 3), g_n_pvd$gl1, g_n_pvd$gl2),
  paste0("- Tabela 12: ", txt_p056),
  sprintf("- Tabela 7: os rotulos do texto estao trocados. O Portmanteau ajustado da %s (p = %s), impresso sob 'Homocedasticidade'; o ARCH-LM multivariado da %s (p = %s), impresso sob 'Autocorrelacao' como 42,33 (erro de digitacao) e 0,589 (truncado). A leitura desses dois testes nao muda, mas BG e ES rejeitam ausencia de autocorrelacao (ver Diagnosticos).",
          num(pt_adj$statistic, 2), num(pt_adj$p.value, 4), num(arch$statistic, 2), num(arch$p.value, 4)),
  sprintf("- Conversao so para leitura: o impacto de %s em log10 equivale a %s em log natural (cerca de %s%% no nivel de PVD); o choque de um desvio padrao eleva INF em %s em log10 no impacto. A elasticidade e a razao entre respostas na mesma unidade e nao depende da base do log.",
          num(impacto), num(impacto * log(10)), num(100 * (10^impacto - 1), 1), num(cum[1, "INF"])),
  "",
  "## Tabelas da dissertacao (capitulo 4 e Apendice B)",
  "",
  sprintf("%d valores %s. Colunas: valores que batem ao arredondar, so ao truncar, so com arredondamento duplo, ou que nao batem; diferenca maxima absoluta entre o obtido e o impresso. A Tabela 7 esta com os rotulos corrigidos (ver acima). Da Tabela 16 so entra a coluna do ponto: as bandas impressas vem de outro bootstrap (IC 95%%, semente desconhecida).", nrow(alvos_diss), origem_alvos),
  "",
  md_table(resumo_diss %>% transmute(Tabela = tabela, Conteudo = conteudo, Valores = n, Arredondamento = arredondamento,
                                     Truncamento = truncamento, `Arredondamento duplo` = duplo, `Nao reproduz` = nao,
                                     `Diferenca maxima` = sci(dif_max, 1))),
  txt_duplo,
  "",
  sprintf("Tabela 16: diferenca maxima de %s nos 41 valores impressos com 9 casas (`stopifnot(max(abs(diferenca)) < 1e-8)`). Nao reproduzidos: %s, ambos explicados acima.",
          sci(dif16), paste(sprintf("`%s` (texto %s, obtido %s)", cmp_diss$chave[cmp_diss$reproduz == "nao"],
                                    cmp_diss$valor_texto[cmp_diss$reproduz == "nao"], num(cmp_diss$obtido[cmp_diss$reproduz == "nao"], 4)), collapse = " e ")),
  "",
  "## Bootstrap",
  "",
  "`irf(modelo, impulse = \"INF\", response = c(\"INF\", \"PVD\"), n.ahead = 40, cumulative = TRUE, boot = TRUE, runs = 2000, ci = 0.90, seed = 42)`; bandas nos percentis 5% e 95%.",
  "",
  sprintf("Bootstrap proprio de residuos para a elasticidade: 2000 replicas, desenho recursivo, constante, tendencia e exogenas fixas, %d valores iniciais observados, residuos centrados, `set.seed(42)` e a mesma sequencia de sorteios de `vars:::.boot`. Em cada replica, elasticidade = resposta acumulada de PVD em h = 40 / resposta acumulada de INF em h = 40. Replicas em `%s`.", p, f_boot),
  "",
  "Conferencia: os percentis 5% e 95% das respostas acumuladas do bootstrap proprio coincidem exatamente com as bandas do `irf()` (`stopifnot`; sem isso o script para antes de publicar o IC da elasticidade).",
  "",
  md_table(tibble(
    Medida = unname(MEDIDAS[boot_tab$medida]),
    Ponto = num(boot_tab$ponto, dig_b),
    Mediana = num(boot_tab$mediana, dig_b),
    `Vies (ponto - mediana)` = num(boot_tab$vies_mediana, dig_b),
    `IC 90% percentil (replica do vars)` = unname(mapply(ic_txt, boot_tab$q05, boot_tab$q95, dig_b)),
    `IC 90% basico de Hall` = unname(mapply(ic_txt, boot_tab$hall_inf, boot_tab$hall_sup, dig_b)),
    `Kilian: ponto corrigido` = num(boot_tab$ponto_c, dig_b),
    `Kilian: IC 90% BaB` = unname(mapply(ic_txt, boot_tab$bab_inf, boot_tab$bab_sup, dig_b)))),
  txt_vies,
  "",
  sprintf("Python com 500 replicas: elasticidade IC 90%% [0,07; 0,67]. R com 2000 replicas, percentil: %s. Replicas com elasticidade negativa: %s%%; com resposta acumulada de PVD negativa: %s%%; com resposta acumulada de INF <= 0: %s%%.",
          ic_txt(q_el[1], q_el[2], 2), num(100 * el_neg, 1), num(100 * pvd_neg, 1), num(100 * den_neg, 1)),
  "",
  "O IC percentil fica como replica do metodo do vars (e da dissertacao). O intervalo basico de Hall e o bootstrap-after-bootstrap de Kilian (1998) sao robustez contra o vies do bootstrap. Os tres reamostram residuos iid e supoem ausencia de autocorrelacao residual, que o BG e o ES rejeitam (ver Diagnosticos); os IC ficam condicionados a isso.",
  "",
  "## Resposta acumulada a um choque de INF (IC 90%)",
  "",
  md_table(irf_tab),
  "Figura: `results/figuras/A1_irf_acumulada.png` e `.pdf`. Serie completa em `data/processed/A1_irf_acumulada.csv`.",
  "",
  "## Matriz de covariancia dos residuos (summary(modelo)$covres)",
  "",
  md_table(tibble(` ` = c("INF", "PVD"), INF = sig(S[, "INF"], 6), PVD = sig(S[, "PVD"], 6))),
  sprintf("Correlacao dos residuos: %s. Cholesky (t(chol(covres))): INF,INF = %s; PVD,INF = %s; PVD,PVD = %s.", num(R["INF", "PVD"], 4),
          num(P_chol["INF", "INF"], 5), num(P_chol["PVD", "INF"], 5), num(P_chol["PVD", "PVD"], 5)),
  "",
  "## Diagnosticos dos residuos",
  "",
  md_table(diag %>% transmute(Teste = teste, Estatistica = num(estatistica, 2), gl = gl, `p-valor` = pval(p), Distribuicao = obs)),
  paste0("Leitura: ", txt_diag),
  "",
  md_table(tibble(Defasagens = as.character(bg_lags$lags.bg), `p-valor BG` = num(bg_lags$p_bg, 4), `p-valor ES` = num(bg_lags$p_es, 4))),
  "Mesmos testes (5 defasagens) com o VAR de ordem 2 a 6:",
  "",
  md_table(tibble(`Ordem do VAR` = as.character(bg_ordens$p_var), `p-valor BG` = num(bg_ordens$p_bg, 4), `p-valor ES` = num(bg_ordens$p_es, 4))),
  "Breusch-Godfrey por equacao (`lmtest::bgtest`, 5 defasagens, versao F):",
  "",
  md_table(bg_eq %>% transmute(Equacao = equacao, F = num(F, 2), gl = paste0(gl1, " e ", gl2), `p-valor` = num(p, 4))),
  paste0("Autocorrelacao residual. ", txt_autocorr),
  "",
  sprintf("ARCH multivariado com lags.multi = %d (padrao do vars, o mesmo usado no Rmd). No Rmd, BG e ES foram chamados com lags.pt = 16, que esses testes ignoram; o lag efetivo e lags.bg = 5 (conferido: mesma estatistica).", LAGS_ARCH),
  "",
  sprintf("Raizes (modulos do polinomio caracteristico): %s. Todas menores que 1: %s.", paste(num(raizes, 4), collapse = ", "), ifelse(all(raizes < 1), "sim", "nao")),
  "",
  "## Selecao de defasagens: VARselect(lag.max = 8, type = \"both\", exogen = diff(exo))",
  "",
  md_table(vsel_tab),
  sprintf("Selecao: AIC = %s, HQ = %s, SC = %s, FPE = %s. %s", sel["AIC(n)"], sel["HQ(n)"], sel["SC(n)"], sel["FPE(n)"], txt_vsel),
  "",
  "## Causalidade de Granger (vars::causality, teste F)",
  "",
  md_table(granger %>% transmute(Modelo = modelo, Hipotese = paste0("H0: ", causa, " nao Granger-causa ", efeito), F = num(F, 2),
                                 gl = paste0(gl1, " e ", gl2), `p-valor` = num(p, 4))),
  paste0("VAR em nivel: `VAR(infmeq, p = 3, type = \"both\", exogen = exo)`, a chamada do Rmd (`var.est`). ",
         ifelse(gl_tab12, "Os graus de liberdade 3 e 116 coincidem com os da Tabela 12 da dissertacao.", "ATENCAO: os graus de liberdade nao coincidem com os da Tabela 12.")),
  "",
  "Convencao dos graus de liberdade no VAR em diferenca:",
  "",
  md_table(granger_conv %>% transmute(Versao = versao, Hipotese = paste0("H0: ", sub(" -> ", " nao Granger-causa ", hipotese)), F = num(F, 2),
                                      gl = paste0(gl1, " e ", gl2), `p-valor` = num(p, 4))),
  txt_gr_conv,
  "",
  sprintf("Variantes testadas para PVD -> INF, na tentativa de localizar o p = 0,56 da dissertacao (%s):", ifelse(alguma_056, "alguma o reproduz", "nenhuma o reproduz")),
  "",
  md_table(tibble(Variante = rownames(var_pvd), F = num(var_pvd[, "F"], 2), gl = paste0(var_pvd[, "gl1"], " e ", var_pvd[, "gl2"]),
                  `p-valor` = num(var_pvd[, "p"], 4))),
  paste0("O argumento mais direto: ", txt_p056),
  "",
  "## Johansen (ca.jo, type = \"trace\")",
  "",
  if (nrow(joh_ok)) sprintf("Configuracoes que reproduzem traco 25,01 contra 25,32 para r = 0: %s. E a chamada do Rmd, com `dumvar = exo[, 3]`, que no arquivo 0124_inexo.txt e a DUM. %s Conclusao: %s contra %s, %s; %s (valor critico %s).",
                            paste(sprintf("ecdet = %s, K = %d, spec = %s", joh_ok$ecdet, joh_ok$K, joh_ok$spec), collapse = "; "),
                            ifelse(spec_neutro, "spec (transitory ou longrun) nao altera a estatistica traco.", "spec altera a estatistica traco."),
                            num(joh_ok$traco_r0[1], 2), num(joh_ok$cv5_r0[1], 2), concl_5, concl_10, num(joh_ok$cv10_r0[1], 2))
  else "Nenhuma configuracao reproduz traco 25,01 contra 25,32.",
  "",
  txt_joh_leitura,
  "",
  txt_joh_nota,
  "",
  md_table(joh %>% transmute(ecdet, K, spec, dumvar, `traco r = 0` = num(traco_r0, 2), `vc 10%` = num(cv10_r0, 2),
                             `vc 5%` = num(cv5_r0, 2), `vc 1%` = num(cv1_r0, 2), `traco r <= 1` = num(traco_r1, 2),
                             `vc 5% r <= 1` = num(cv5_r1, 2), `bate 25,01/25,32` = ifelse(bate, "sim", ""),
                             `valores criticos` = case_when(dumvar == "exo (PIB, JUR, DUM)" ~ "nao valem (so descritiva)",
                                                            dumvar == "nenhuma" ~ "tabelados",
                                                            TRUE ~ "aproximados (DUM em degraus)"))),
  "## Decomposicao da variancia do erro de previsao (%, variaveis em diferenca)",
  "",
  md_table(fevd_tab %>% transmute(h, `dINF: choque INF` = num(INF_por_INF, 1), `dINF: choque PVD` = num(INF_por_PVD, 1),
                                  `dPVD: choque INF` = num(PVD_por_INF, 1), `dPVD: choque PVD` = num(PVD_por_PVD, 1))),
  "## Correcoes ao texto antigo",
  "",
  sprintf("%d. %s", seq_along(correcoes), correcoes),
  "",
  "## Arquivos",
  "",
  "- `R/A1_replica.R`",
  "- `results/A1_replica.md`, `results/A1_replica.tex`",
  "- `results/figuras/A1_irf_acumulada.png`, `results/figuras/A1_irf_acumulada.pdf`",
  "- `data/processed/A1_bootstrap.csv` (2000 replicas: impacto, respostas acumuladas em h = 40 e elasticidade)",
  "- `data/processed/A1_bootstrap_kilian.csv` (2000 replicas do estagio 2 do bootstrap-after-bootstrap, corrigidas de vies)",
  "- `data/processed/A1_irf_acumulada.csv` (resposta acumulada h = 0 a 40 com IC 90%)",
  "- `data/processed/A1_alvos_dissertacao.csv` (valores das Tabelas 6 a 12 e 14 a 18 da dissertacao, com linha do txt e casas decimais)",
  "- `results/log_parts/A1.md`, `results/session_info/A1_replica.txt`"
)
write_lines_safe(md, file.path(PATHS$results, "A1_replica.md"))

# ------------------------------------------------------------------------------------------------
# 14. Tabela LaTeX (baseline e diagnosticos)
# ------------------------------------------------------------------------------------------------
tl <- function(...) paste0(...)
jx <- joh_ok[1, ]
tex <- c(
  "% Gerado por R/A1_replica.R. Requer \\usepackage{booktabs}.",
  "\\begin{table}[htbp]",
  "\\centering",
  tl("\\caption{R\\'eplica do modelo da disserta\\c{c}\\~ao: VAR(3) em diferen\\c{c}as; dados de ", sub("Q", "T", TRIM[1]), " a ",
     sub("Q", "T", TRIM[length(TRIM)]), ", amostra efetiva ", sub("Q", "T", TRIM_EF[1]), "--", sub("Q", "T", TRIM_EF[2]), "}"),
  "\\label{tab:a1_baseline}",
  "\\small",
  "\\begin{tabular}{lcc}",
  "\\toprule",
  " & Estimativa & IC 90\\% \\\\",
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{A. Choque ortogonal em INF (Cholesky: INF, PVD)}} \\\\",
  tl("Impacto em PVD ($h = 0$) & ", tnum(impacto), " & ", tic_txt(lo[1, "PVD"], up[1, "PVD"]), " \\\\"),
  tl("Resposta acumulada de PVD ($h = 40$) & ", tnum(acum_pvd), " & ", tic_txt(lo[41, "PVD"], up[41, "PVD"]), " \\\\"),
  tl("Resposta acumulada de INF ($h = 40$) & ", tnum(acum_inf), " & ", tic_txt(lo[41, "INF"], up[41, "INF"]), " \\\\"),
  tl("Elasticidade de longo prazo (IC percentil) & ", tnum(elast, 2), " & ", tic_txt(q_el[1], q_el[2], 2), " \\\\"),
  tl("\\quad IC b\\'asico de Hall & & ", tic_txt(bel$hall_inf, bel$hall_sup, 2), " \\\\"),
  tl("\\quad Corrigida de vi\\'es (Kilian, 1998) & ", tnum(bel$ponto_c, 2), " & ", tic_txt(bel$bab_inf, bel$bab_sup, 2), " \\\\"),
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
  "\\midrule",
  "\\multicolumn{3}{l}{\\textit{D. Johansen, tra\\c{c}o}} \\\\",
  tl("\\multicolumn{3}{l}{\\quad \\footnotesize ", JOH_ROT_TEX, "} \\\\"),
  tl("$r = 0$ (valor cr\\'itico 5\\%: ", tnum(jx$cv5_r0, 2), "; 10\\%: ", tnum(jx$cv10_r0, 2), ") & ", tnum(jx$traco_r0, 2), " & \\\\"),
  tl("$r \\leq 1$ (valor cr\\'itico 5\\%: ", tnum(jx$cv5_r1, 2), ") & ", tnum(jx$traco_r1, 2), " & \\\\"),
  tl("Configura\\c{c}\\~oes que rejeitam $r = 0$ a 5\\% (a 10\\%) & \\multicolumn{2}{c}{", n_rej5, " de ", n_joh, " (", n_rej10, " de ", n_joh, ")} \\\\"),
  tl("\\multicolumn{3}{l}{\\quad \\footnotesize ",
     if (limitrofe) "Evid\\^encia lim\\'itrofe de um vetor de cointegra\\c{c}\\~ao: " else "Rever a leitura: ",
     "a configura\\c{c}\\~ao do Rmd fica ", tnum(jx$cv5_r0 - jx$traco_r0, 2), " abaixo do valor cr\\'itico de 5\\%.} \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{minipage}{0.95\\linewidth}\\footnotesize",
  tl("\\medskip Notas: VAR(3) em primeiras diferen\\c{c}as de INF e PVD (log10), com constante, tend\\^encia e as ex\\'ogenas diferenciadas ",
     "(PIB, Selic e dummy); ", modelo$obs, " observa\\c{c}\\~oes efetivas. Respostas em log10. Elasticidade = resposta acumulada de PVD / ",
     "resposta acumulada de INF em $h = 40$. IC 90\\% por bootstrap de res\\'iduos com 2000 r\\'eplicas (percentis 5\\% e 95\\%, como no pacote vars); ",
     "o intervalo b\\'asico de Hall e o bootstrap-after-bootstrap de Kilian (1998; 1000 e 2000 r\\'eplicas) corrigem o vi\\'es do bootstrap. ",
     "Os tr\\^es IC reamostram res\\'iduos iid e sup\\~oem aus\\^encia de autocorrela\\c{c}\\~ao residual, que os testes BG e ES rejeitam ",
     "(Tabela \\ref{tab:a1_diagnosticos}). ",
     "INF do arquivo original \\'e nominal com ajuste sazonal (ver A3). ", "VAR em n\\'ivel: VAR(3) nos log10 com ex\\'ogenas em n\\'ivel. ",
     "Johansen: valores cr\\'iticos tabelados (Osterwald-Lenum), aproximados com dummy em degraus e amostra curta; a contagem de rejei\\c{c}\\~oes ",
     "cobre ", n_joh, " configura\\c{c}\\~oes (tend\\^encia restrita ou constante restrita, K de 2 a 4, sem dummy ou com DUM), sem as ex\\'ogenas ",
     "estoc\\'asticas (PIB, Selic) como dumvar."),
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
  vapply(seq_len(nrow(diag)), function(i) tl(diag$teste_tex[i], " & ", tnum(diag$estatistica[i], 2), " & ",
                                             gsub(",", "{,}", diag$gl[i], fixed = TRUE), " & ", tpval(diag$p[i]), " \\\\"), ""),
  "\\midrule",
  tl("Breusch-Godfrey, 1 a 8 defasagens: maior p-valor & & & ", tpval(max(bg_lags$p_bg)), " \\\\"),
  tl("Edgerton-Shukur, 1 a 8 defasagens: maior p-valor & & & ", tpval(max(bg_lags$p_es)), " \\\\"),
  "\\midrule",
  tl("M\\'odulo m\\'aximo das ra\\'izes & ", tnum(max(raizes), 4), " & & \\\\"),
  tl("VARselect (m\\'aximo 8): AIC, HQ, SC, FPE & \\multicolumn{3}{c}{", sel["AIC(n)"], ", ", sel["HQ(n)"], ", ",
     sel["SC(n)"], ", ", sel["FPE(n)"], "} \\\\"),
  "\\bottomrule",
  "\\end{tabular}",
  "\\begin{minipage}{0.95\\linewidth}\\footnotesize",
  tl("\\medskip Notas: H0 de aus\\^encia de autocorrela\\c{c}\\~ao (Portmanteau, BG, ES), de efeitos ARCH e de normalidade (Jarque-Bera). Testes do pacote vars. ",
     "O Portmanteau (16 defasagens) n\\~ao rejeita aus\\^encia de autocorrela\\c{c}\\~ao. Com 1 a 8 defasagens, o Breusch-Godfrey rejeita a 1\\% em ",
     n_bg1, " de 8 casos e o Edgerton-Shukur rejeita a 5\\% em ", n_es5, " de 8 (a 1\\% em ", n_es1, " de 8). BG por equa\\c{c}\\~ao, 5 defasagens: ",
     "INF, p = ", tnum(bg_eq$p[bg_eq$equacao == "INF"], 3), "; PVD, p = ", tnum(bg_eq$p[bg_eq$equacao == "PVD"], 3), ". ",
     if (autocorr_resid) "A especifica\\c{c}\\~ao tem autocorrela\\c{c}\\~ao residual; " else "",
     "os IC por bootstrap iid de res\\'iduos ficam condicionados a isso. ",
     "Na Tabela 7 da disserta\\c{c}\\~ao, os r\\'otulos de autocorrela\\c{c}\\~ao e homocedasticidade est\\~ao trocados."),
  "\\end{minipage}",
  "\\end{table}"
)
write_lines_safe(tex, file.path(PATHS$results, "A1_replica.tex"))

# ------------------------------------------------------------------------------------------------
# 15. Conferencia do guard_path (sem escrever nada) e registro das acoes feitas a mao fora do script
# ------------------------------------------------------------------------------------------------
casos_guard <- c("data/raw/teste_guard.csv", "data/raw/sub/teste_guard.csv", "data/raw", "data/raw/", "./data/raw/teste_guard.csv",
                 "data/processed/../raw/teste_guard.csv", file.path(getwd(), "data/raw/teste_guard.csv"), "data/original/sub/teste_guard.txt",
                 "data/rawteste_guard.csv", "data/processed/teste_guard.csv")
bloqueia <- vapply(casos_guard, function(k) inherits(try(guard_path(k), silent = TRUE), "try-error"), TRUE)
stopifnot(all(bloqueia[1:8]), !any(bloqueia[9:10]), !any(file.exists(casos_guard[c(1, 2, 5, 6, 7, 8, 9, 10)])))
log_part(ETAPA, "- Conferencia do guard_path de R/00_setup.R nesta execucao, sem escrever: bloqueia ",
         paste(casos_guard[bloqueia], collapse = ", "), "; permite ", paste(casos_guard[!bloqueia], collapse = " e "), ". ",
         "Todas as escritas da A1 passam por write_csv_safe, write_lines_safe, ggsave_safe, log_reset, log_part e save_session_info.")

# Texto fixo: registra acoes feitas a mao nas revisoes da A1, que este script nao executa
log_part(ETAPA, "- Registro de acoes feitas a mao, fora deste script (texto fixo e datado; nao sao acoes desta execucao). ",
         "(a) Primeira revisao adversarial da A1, 28/09/2026 por volta de 20h40: R/00_setup.R alterado (guard_path com caminho absoluto, ",
         "novos write_lines_safe e ggsave_safe; log_part, log_reset e save_session_info passam pelo guard) e os itens de 28/09 de ",
         "results/LOG.md (IC da elasticidade e Granger) reescritos no lugar. As duas edicoes sairam do escopo da A1. ",
         "(b) Segunda revisao, 28/09/2026: results/LOG.md voltou ao texto do autor (versao do commit 26b479d); a correcao do item de ",
         "Granger fica neste log, datada, para o coordenador consolidar. R/00_setup.R foi mantido, porque R/A3_investimento_publico.R ja ",
         "usa write_lines_safe e ggsave_safe. Compatibilidade com a A2 conferida sem mexer nas saidas da A2: o setup novo tem as mesmas ",
         "funcoes e assinaturas do antigo, mais abs_path, write_lines_safe e ggsave_safe; o guard novo e o antigo dao a mesma decisao ",
         "nos 17 caminhos de saida da A2 testados; os 7 scripts R/A2_*.R foram rerodados numa copia do projeto fora do repositorio ",
         "(o de BNDES com o download bruto ja comprimido), e todas as saidas em data/processed e results sairam identicas byte a byte ",
         "as do projeto, exceto o horario no cabecalho de results/A2_validacao_anual.md. ",
         "(c) data/raw/x.csv: arquivo de teste de 4 bytes (conteudo 'a' e '1'), versionado desde o commit 26b479d; nenhum script le esse ",
         "arquivo. A A1 nao o remove: a remocao (git rm) fica com o coordenador, com o ok do autor.")

log_part(ETAPA, "- Saidas: results/A1_replica.md, results/A1_replica.tex, results/figuras/A1_irf_acumulada.png e .pdf, ",
         "data/processed/A1_bootstrap.csv, data/processed/A1_bootstrap_kilian.csv, data/processed/A1_irf_acumulada.csv, ",
         "data/processed/A1_alvos_dissertacao.csv. Todas as escritas passam por guard_path (write_csv_safe, write_lines_safe, ggsave_safe, log_part). ",
         "Tempo total: ", num(as.numeric(difftime(Sys.time(), t_ini, units = "secs")), 0), " s.")

save_session_info("A1_replica")
cat("A1 concluida.\n")
