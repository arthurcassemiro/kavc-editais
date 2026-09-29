# A6: saidas para o workshop do IWH (Halle).
# Gera, a partir dos CSV de data/processed e results (nenhum numero digitado a mao):
#   results/A_robustez.tex        VAR replicado, corrigido correcao a correcao, estendido, decisao VAR x VEC,
#                                 robustez do VAR e das projecoes locais
#   results/A_lp.tex              elasticidades acumuladas, multiplicadores em R$ e comparacoes (regressao conjunta)
#   results/A_numeros_halle.md    so numeros, com o arquivo de origem de cada um
#   results/A_numeros_macros.tex  \newcommand para cada numero do resumo estendido (formato ingles)
#   results/figuras/A6_fig1_econ_social.pdf e A6_fig2_direta_transf_estatais.pdf (e png)
# Nao altera results/A_quebras.tex (A4).
# Uso: cd crowding_in_code && Rscript R/A6_saidas.R
# Entradas: data/processed/A5_var_resultados.csv, A5_johansen.csv, A5_lp_cumulativo.csv, A5_lp_comparacoes.csv,
# A5_lp_irf.csv, A3_invpub_trimestral.csv, A3_niveis_wide.csv, A2_series_trimestrais.csv, A1_alvos_dissertacao.csv;
# results/A4_quebras_resumo.csv, results/A3_reconstrucao_INF_variantes.csv; data/original/0124_inexo.txt (so leitura).

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(ggplot2)
})

ETAPA <- "A6"
ALFA <- 0.05; ALFA10 <- 0.10; NIVEL_IC <- 90   # nivel da regra de decisao, nivel de 10% e IC de 90% (colunas ic90_*)
log_reset(ETAPA)
set.seed(42)
t_ini <- Sys.time()

# ------------------------------------------------------------------------------------------------
# 0. Leitura
# ------------------------------------------------------------------------------------------------
rdp <- function(f) readr::read_csv(file.path(PATHS$processed, f), show_col_types = FALSE)
rdr <- function(f) readr::read_csv(file.path(PATHS$results, f), show_col_types = FALSE)
VAR <- rdp("A5_var_resultados.csv")
JOH <- rdp("A5_johansen.csv")
CUM <- rdp("A5_lp_cumulativo.csv")
CMP <- rdp("A5_lp_comparacoes.csv")
IRF <- rdp("A5_lp_irf.csv")
INV <- rdp("A3_invpub_trimestral.csv")
NIV <- rdp("A3_niveis_wide.csv")
A2 <- rdp("A2_series_trimestrais.csv")
ALV <- rdp("A1_alvos_dissertacao.csv")
Q4 <- rdr("A4_quebras_resumo.csv")
VARI <- rdr("A3_reconstrucao_INF_variantes.csv")
EXO <- read.table(file.path(PATHS$original, "0124_inexo.txt"), header = TRUE)

F_VAR <- "data/processed/A5_var_resultados.csv"
F_JOH <- "data/processed/A5_johansen.csv"
F_CUM <- "data/processed/A5_lp_cumulativo.csv"
F_CMP <- "data/processed/A5_lp_comparacoes.csv"
F_IRF <- "data/processed/A5_lp_irf.csv"
F_INV <- "data/processed/A3_invpub_trimestral.csv"
F_NIV <- "data/processed/A3_niveis_wide.csv"
F_A2 <- "data/processed/A2_series_trimestrais.csv"
F_ALV <- "data/processed/A1_alvos_dissertacao.csv"
F_Q4 <- "results/A4_quebras_resumo.csv"
F_VARI <- "results/A3_reconstrucao_INF_variantes.csv"
F_EXO <- "data/original/0124_inexo.txt"

# ------------------------------------------------------------------------------------------------
# 1. Formatacao: md (virgula), tex das tabelas (virgula como {,}), macros do resumo (ponto, ingles)
# ------------------------------------------------------------------------------------------------
fnum <- function(x, d = 2, dec = ",") {
  out <- ifelse(is.na(x), "NA", formatC(round(x, d), format = "f", digits = d))
  if (dec == ",") out <- chartr(".", ",", out)
  out
}
fmd <- function(x, d = 2) fnum(x, d, ",")
ftx <- function(x, d = 2) {
  s <- fnum(x, d, ",")
  s <- gsub(",", "{,}", s, fixed = TRUE)
  sub("^-", "$-$", s)
}
fen <- function(x, d = 2) {
  s <- fnum(x, d, ".")
  sub("^-", "\\\\ensuremath{-}", s)
}
pmd <- function(p) ifelse(is.na(p), "NA", ifelse(p < 0.001, "< 0,001", fmd(p, 3)))
ptx <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "$<$0{,}001", ftx(p, 3)))
pen <- function(p) ifelse(p < 0.001, "\\ensuremath{<}0.001", fen(p, 3))
cmd <- function(b, lo, hi, d = 2) sprintf("%s [%s; %s]", fmd(b, d), fmd(lo, d), fmd(hi, d))
ctx <- function(b, lo, hi, d = 2) ifelse(is.na(b), "", sprintf("%s [%s; %s]", ftx(b, d), ftx(lo, d), ftx(hi, d)))
exclui0 <- function(lo, hi) !is.na(lo) & (lo > 0 | hi < 0)
estr <- function(lo, hi) ifelse(exclui0(lo, hi), "$^{*}$", "")
tq <- function(k) gsub("Q", "T", k)
esc <- function(s) gsub("_", "\\\\_", s)

# ------------------------------------------------------------------------------------------------
# 2. Acesso aos resultados
# ------------------------------------------------------------------------------------------------
vr <- function(id) {
  z <- VAR %>% filter(.data$id == !!id)
  stopifnot(nrow(z) == 1)
  z
}
jo <- function(amostra, ecdet, hip) {
  z <- JOH %>% filter(.data$amostra == !!amostra, .data$ecdet == !!ecdet, .data$hipotese == !!hip)
  stopifnot(nrow(z) == 1)
  z
}
# medidas acumuladas do baseline em diferenca (e das especificacoes de robustez)
cu <- function(choque, resposta, h, medida = "elasticidade", esp = "baseline", modelo = "diferenca") {
  z <- CUM %>% filter(.data$choque == !!choque, .data$resposta == !!resposta, .data$h == !!h,
                      .data$medida == !!medida, .data$especificacao == !!esp, .data$modelo == !!modelo)
  if (nrow(z) == 0) return(NULL)
  stopifnot(nrow(z) == 1)
  z
}
# comparacoes: IC individuais e p com o ajuste de amostra pequena (variancia vezes n/gl, t com gl graus)
CMP <- CMP %>% mutate(
  fa = sqrt(n / gl), tq95 = qt(0.95, gl),
  ep_a_aj = ep_a * fa, ep_b_aj = ep_b * fa, ep_dif_aj = ep_diferenca * fa,
  lo_a = est_a - tq95 * ep_a_aj, hi_a = est_a + tq95 * ep_a_aj,
  lo_b = est_b - tq95 * ep_b_aj, hi_b = est_b + tq95 * ep_b_aj,
  p_aj_recalc = 2 * pt(-abs(diferenca / ep_dif_aj), gl))
# conferencia: o p de amostra pequena recalculado aqui e o p_wald_pa da A5
stopifnot(max(abs(CMP$p_aj_recalc - CMP$p_wald_pa)) < 1e-8)
# conferencia: o IC ajustado do CSV das medidas acumuladas usa o mesmo desenho
# (so no baseline em diferenca: nas especificacoes com dummies por observacao o n do CSV exclui as observacoes marcadas)
chk <- CUM %>% filter(!is.na(ep_aj), especificacao == "baseline", modelo == "diferenca") %>%
  mutate(lo2 = estimativa - qt(0.95, gl) * ep * sqrt(n / gl))
stopifnot(max(abs(chk$lo2 - chk$ic90_inf_aj)) < 1e-8)
cp <- function(a, b, resposta, h, medida = "elasticidade") {
  z <- CMP %>% filter(choque_a == a, choque_b == b, .data$resposta == !!resposta, .data$h == !!h, .data$medida == !!medida)
  stopifnot(nrow(z) == 1)
  z
}

# ------------------------------------------------------------------------------------------------
# 3. Numeros de apoio calculados aqui (sempre de CSV)
# ------------------------------------------------------------------------------------------------
# 3a. Parcelas da Uniao (somas nominais 2003-2025, A3_invpub_trimestral.csv, sem ajuste)
INV <- INV %>% mutate(ano = as.integer(substr(trimestre, 1, 4)))
ANO_INI <- min(INV$ano[INV$serie == "uniao_soc_dir"]); ANO_FIM <- max(INV$ano[INV$serie == "uniao_soc_dir"])
snom <- INV %>% filter(ano >= ANO_INI, ano <= ANO_FIM) %>% group_by(serie) %>% summarise(v = sum(nominal_rs_bi), .groups = "drop")
sv <- function(s) snom$v[snom$serie == s]
share_soc_transf <- 100 * sv("uniao_transf_soc") / (sv("uniao_transf_soc") + sv("uniao_soc_dir"))
share_soc_transf_g1 <- 100 * sv("uniao_transf_soc_g1") / (sv("uniao_transf_soc_g1") + sv("uniao_soc_dir"))
share_econ_dir <- 100 * sv("uniao_econ_dir") / sv("uniao_econ_dt")
share_econ_dir_g1 <- 100 * sv("uniao_econ_dir") / sv("uniao_econ_dt_g1")
stopifnot(abs(sv("uniao_econ_dt") - sv("uniao_econ_dir") - sv("uniao_transf_econ")) < 1e-6)
# 3b. Participacao do petroleo nas estatais (OI, nominal, por ano)
oi <- INV %>% filter(serie %in% c("estatais_petro", "estatais_sempetro")) %>% group_by(ano, serie) %>%
  summarise(v = sum(nominal_rs_bi), .groups = "drop") %>% tidyr::pivot_wider(names_from = serie, values_from = v) %>%
  mutate(sh = 100 * estatais_petro / (estatais_petro + estatais_sempetro))
petro_min <- min(oi$sh); petro_max <- max(oi$sh); OI_INI <- min(oi$ano); OI_FIM <- max(oi$ano)
CHW <- rdp("A3_choques_wide.csv")
EMENDA_INI <- CHW$trimestre[which(CHW$emenda_sest == 1)[1]]   # primeiro trimestre com a OI encadeada
BOLETIM_FIM <- as.integer(substr(EMENDA_INI, 1, 4)) - 1
stopifnot(substr(EMENDA_INI, 5, 6) == "Q1")
DQ <- rdp("A4_dummies_quebra.csv")
PULSOS <- sub("^pulso_", "", grep("^pulso_", names(DQ), value = TRUE))
# 3c. Escala: G medio / FBCF media na janela de cada choque (niveis com ajuste, R$ bi de 2025)
TRIM_A2 <- A2$trimestre
fbcf <- A2$fbcf_real_rs_bi
g_fbcf <- function(s, ini) {
  g <- NIV[[s]][match(TRIM_A2, NIV$trimestre)]
  ok <- !is.na(g) & !is.na(fbcf) & TRIM_A2 >= ini & TRIM_A2 <= "2025Q4"
  100 * mean(g[ok]) / mean(fbcf[ok])
}
CHOQ <- c("inf_diss", "uniao_filtro_diss", "uniao_gnd4_dir", "uniao_econ_dir", "uniao_soc_dir", "uniao_econ_dt_g1",
          "uniao_soc_dt_g1", "uniao_transf_soc_g1", "estatais_total", "estatais_petro", "estatais_sempetro", "estatais_econ")
CURTOS <- c("estatais_petro", "estatais_sempetro", "estatais_econ")
INI_CHOQ <- vapply(CHOQ, function(s) {
  z <- CUM %>% filter(choque == s, especificacao == "baseline", modelo == "diferenca")
  substr(unique(z$amostra), 1, 6)
}, "")
GY <- vapply(CHOQ, function(s) g_fbcf(s, sub("T", "Q", INI_CHOQ[[s]])), 0)
# conferencia com a razao FBCF / G da A5 (inf_diss 14; uniao_soc_dir 290; registradas em results/log_parts/A5_lp.md)
stopifnot(round(100 / GY[["inf_diss"]]) == 14, round(100 / GY[["uniao_soc_dir"]]) == 290,
          round(100 / GY[["estatais_sempetro"]]) == 165)
# 3d. Datas da DUM do arquivo original (72 linhas, 2002T1 a 2019T4)
TRIM_ORIG <- q_seq("2002Q1", "2019Q4")
stopifnot(nrow(EXO) == length(TRIM_ORIG))
dum_q <- TRIM_ORIG[EXO$DUM == 1]
blocos <- split(dum_q, cumsum(c(1, diff(match(dum_q, TRIM_ORIG)) != 1)))
dum_txt <- vapply(blocos, function(b) if (length(b) == 1) tq(b) else paste0(tq(b[1]), "--", tq(b[length(b)])), "")
dum_txt_md <- gsub("--", " a ", dum_txt)
# 3e. Reconstrucao do INF (A3): nominal x real, janela 2003-2019, imputacao base, log
vari <- function(defl, aj) {
  z <- VARI %>% filter(deflator == defl, ajuste == aj, transformacao == "log", span == "2003T1-2019T4", imputacao == "base")
  stopifnot(nrow(z) == 1)
  z
}
inf_nom <- vari("nominal", "soma"); inf_real <- vari("media_tri", "componentes")
# 3f. Alvos do texto da dissertacao
alv <- function(k) {
  z <- ALV %>% filter(chave == k)
  stopifnot(nrow(z) == 1)
  z$valor
}
p_implicito_t12 <- pf(alv("t12_causa_PVD_F"), alv("t12_causa_PVD_gl1"), alv("t12_causa_PVD_gl2"), lower.tail = FALSE)
# 3g. Tamanhos de amostra das LP
n_lp_h0 <- IRF %>% filter(especificacao == "baseline", choque == "inf_diss", resposta == "fbcf_me", h == 0, variavel == "resposta", modelo == "diferenca")
n_lp_h0_curto <- IRF %>% filter(especificacao == "baseline", choque == "estatais_petro", resposta == "fbcf_me", h == 0, variavel == "resposta", modelo == "diferenca")
stopifnot(nrow(n_lp_h0) == 1, nrow(n_lp_h0_curto) == 1)
N_Q <- length(q_seq("2003Q1", "2025Q4"))
HMAX <- max(IRF$h[IRF$especificacao == "baseline" & IRF$modelo == "diferenca" & IRF$choque == "inf_diss"])
HMAX_CURTO <- max(IRF$h[IRF$especificacao == "baseline" & IRF$choque == "estatais_petro"])
P_LP <- unique(CUM$p[CUM$especificacao == "baseline" & CUM$choque == "inf_diss"])
P_LP_CURTO <- unique(CUM$p[CUM$especificacao == "baseline" & CUM$choque == "estatais_petro"])
stopifnot(length(P_LP) == 1, length(P_LP_CURTO) == 1)
# 3h. Testes multiplos: IC de 90% das elasticidades acumuladas do baseline em diferenca que excluem zero
el_base <- CUM %>% filter(especificacao == "baseline", modelo == "diferenca", medida == "elasticidade")
n_el <- nrow(el_base)
n_el_excl <- sum(exclui0(el_base$ic90_inf, el_base$ic90_sup))
n_el_excl_aj <- sum(exclui0(el_base$ic90_inf_aj, el_base$ic90_sup_aj))
# 3h2. Desenho do VAR (ordem e horizonte da elasticidade de longo prazo), lidos do CSV
H_VAR <- as.integer(sub("^resp_acum_([0-9]+)_priv$", "\\1", grep("^resp_acum_[0-9]+_priv$", names(VAR), value = TRUE)))
P_VAR <- as.integer(sub("^VAR\\(([0-9]+)\\).*$", "\\1", rep_obs <- vr("replicado")$obs))
stopifnot(length(H_VAR) == 1, !is.na(P_VAR))
# 3i. Quebras (A4): equacoes do VAR estendido
q4e <- function(nm) {
  z <- Q4 %>% filter(tipo == "equacao", nome == nm)
  stopifnot(nrow(z) == 1)
  z
}
qi <- q4e("ext_inf"); qf <- q4e("ext_fbcf"); qo <- q4e("orig_INF"); qop <- q4e("orig_PVD")
stopifnot(qi$supF_data == qf$supF_data)

# ------------------------------------------------------------------------------------------------
# 4. Classificacao VAR x VEC em cada amostra (ecdet = trend decide; const confere)
# ------------------------------------------------------------------------------------------------
AMOSTRAS <- c("2002-2019 original", "2003-2019", "2003-2025")
ID_VAR <- c("2002-2019 original" = "replicado", "2003-2019" = "corr_c", "2003-2025" = "ext")
ID_VEC <- setNames(paste0("vecm_", AMOSTRAS), AMOSTRAS)
ID_NIV <- c("2002-2019 original" = "nivel_orig_nivel", "2003-2019" = "nivel_2019_nivel", "2003-2025" = "nivel_2025_nivel")
dec <- lapply(AMOSTRAS, function(a) {
  t0 <- jo(a, "trend", "r = 0"); c0 <- jo(a, "const", "r = 0")
  ass <- t0$traco > t0$cv5; ra <- t0$traco_ra > t0$cv5; bo <- t0$p_boot < ALFA
  stopifnot(ass == t0$rejeita5_assintotico, ra == t0$rejeita5_ra)
  lim <- (length(unique(c(ass, ra, bo))) > 1) || (t0$traco > t0$cv10) || (c0$p_boot < ALFA) || (t0$p_boot < ALFA10)
  motivo <- c(if (length(unique(c(ass, ra, bo))) > 1) "leituras a 5% discordam",
              if (!ass && t0$traco > t0$cv10) "assintotico rejeita a 10%",
              if (t0$p_boot < ALFA10) "bootstrap rejeita a 10%",
              if (c0$p_boot < ALFA) "bootstrap com ecdet const rejeita a 5%")
  list(amostra = a, T = t0$T_efetivo, ass = ass, ra = ra, bo = bo, lim = lim,
       motivo = paste(motivo, collapse = "; "),
       escolha = if (bo) "VEC com r = 1" else "VAR em diferenca (VEC ao lado)")
})
names(dec) <- AMOSTRAS
stopifnot(all(vapply(dec, function(d) d$lim, TRUE)))
stopifnot(!any(vapply(dec, function(d) d$bo, TRUE)))

# ------------------------------------------------------------------------------------------------
# 5. results/A_robustez.tex
# ------------------------------------------------------------------------------------------------
sim_nao <- function(x) ifelse(x, "sim", "n\\~ao")
tab_ini <- function(caption, label, cols, size = "\\scriptsize") c(
  "\\begin{table}[htbp]", "\\centering", sprintf("\\caption{%s}", caption), sprintf("\\label{%s}", label), size,
  "\\begin{adjustbox}{max width=\\linewidth}", sprintf("\\begin{tabular}{%s}", cols), "\\toprule")
# escapa o sublinhado dos caminhos de arquivo dentro de \texttt{...}
fix_tt <- function(x) {
  m <- gregexpr("\\\\texttt\\{[^}]*/[^}]*\\}", x)
  regmatches(x, m) <- lapply(regmatches(x, m), function(v) gsub("(?<!\\\\)_", "\\\\_", v, perl = TRUE))
  x
}
tab_fim <- function(nota) c("\\bottomrule", "\\end{tabular}", "\\end{adjustbox}",
  "\\begin{minipage}{0.97\\linewidth}\\footnotesize", fix_tt(paste0("\\medskip Notas: ", nota)), "\\end{minipage}", "\\end{table}", "")

# 5a. VAR: replicado, corrigido correcao a correcao, estendido
LAB_VAR <- c(replicado = "Replicado: arquivos originais",
             corr_a0 = "(a0) Arquivos originais, amostra nova",
             corr_a = "(a) INF nominal reconstru\\'ido (inf\\_diss\\_nominal\\_2019)",
             corr_b = "(b) INF real (inf\\_diss, X-11 por componente)",
             corr_c0 = "(c0) (b) + PVD atual (M\\&E do Ipea)",
             corr_c = "(c) (c0) + PIB e Selic atuais: baseline corrigido",
             ext = "Estendida: (c) sem DUM, com os pulsos da pandemia (A4)")
linha_var <- function(id) {
  z <- vr(id)
  sprintf("%s & %s & %d & %s & %s & %s & %s & %s & %s \\\\", LAB_VAR[[id]], z$amostra, z$n, ftx(z$impacto, 4),
          ctx(z$resp_acum_40_priv, z$ic90_acum_priv_inf, z$ic90_acum_priv_sup, 4), ftx(z$resp_acum_40_pub, 4),
          ctx(z$elasticidade, z$ic90_inf, z$ic90_sup), ptx(z$granger_p_pub_priv), ptx(z$granger_p_priv_pub))
}
runs_rep <- vr("replicado")$runs
tex_var <- c(
  tab_ini("VAR em diferen\\c{c}a: baseline replicado, corrigido corre\\c{c}\\~ao a corre\\c{c}\\~ao e amostra estendida",
          "tab:a6_var_base", "p{4.3cm}lccccccc"),
  sprintf("Especifica\\c{c}\\~ao & Amostra & $n$ & Impacto & Acum. PVD, $h=%d$ [IC 90\\%%] & Acum. INF & Elasticidade [IC 90\\%%] & $p$ INF$\\to$PVD & $p$ PVD$\\to$INF \\\\", H_VAR),
  "\\midrule",
  "\\multicolumn{9}{l}{\\textit{A. Replicado}} \\\\", linha_var("replicado"),
  "\\multicolumn{9}{l}{\\textit{B. Corrigido, uma corre\\c{c}\\~ao por vez}} \\\\",
  vapply(c("corr_a0", "corr_a", "corr_b", "corr_c0", "corr_c"), linha_var, ""),
  "\\multicolumn{9}{l}{\\textit{C. Amostra estendida}} \\\\", linha_var("ext"),
  tab_fim(sprintf(paste0(
    "VAR(%d) em diferen\\c{c}a do log10, constante e tend\\^encia, Cholesky com INF antes de PVD. Elasticidade de longo prazo = ",
    "resposta acumulada de PVD / resposta acumulada de INF em $h = %d$. IC de 90\\%% por bootstrap de res\\'iduos (%d r\\'eplicas; percentil). ",
    "$n$ = observa\\c{c}\\~oes efetivas. $p$ = Granger no VAR em diferen\\c{c}a (\\texttt{vars::causality}). ",
    "Amostra 2002-2019 original: n\\'iveis de 2002T1 a 2019T4; 2003-2019: n\\'iveis de 2003T1 a 2019T4; 2003-2025: n\\'iveis de 2003T1 a 2025T4. ",
    "A DUM entra diferenciada, como no arquivo original, em A e B. Fonte: \\texttt{%s}."), P_VAR, H_VAR, runs_rep, F_VAR)))

# 5b. Decisao VAR x VEC: Johansen com as tres leituras lado a lado
linha_joh <- function(a, ecd) {
  t0 <- jo(a, ecd, "r = 0"); t1 <- jo(a, ecd, "r <= 1")
  ass <- t0$traco > t0$cv5; ra <- t0$traco_ra > t0$cv5; bo <- t0$p_boot < ALFA
  esc_txt <- if (ecd == "trend") (if (dec[[a]]$bo) "VEC" else "VAR (VEC ao lado)") else "confer\\^encia"
  sprintf("%s & %d & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s \\\\", a, t0$T_efetivo, ftx(t0$traco), ftx(t0$traco_ra),
          ftx(t0$cv5), ptx(t0$p_boot), ftx(t1$traco), ptx(t1$p_boot), sim_nao(ass), sim_nao(ra), sim_nao(bo), esc_txt)
}
B_BOOT <- unique(JOH$B); K_JOH <- unique(JOH$K)
stopifnot(length(B_BOOT) == 1, length(K_JOH) == 1)
tex_joh <- c(
  tab_ini(sprintf("Decis\\~ao VAR x VEC: tra\\c{c}o de Johansen, $K = %d$, com as tr\\^es leituras lado a lado", K_JOH),
          "tab:a6_johansen", "lcccccccccccl"),
  "& & \\multicolumn{4}{c}{$H_0$: $r = 0$} & \\multicolumn{2}{c}{$H_0$: $r \\le 1$} & \\multicolumn{3}{c}{Rejeita $r=0$ a 5\\%} & \\\\",
  "\\cmidrule(lr){3-6}\\cmidrule(lr){7-8}\\cmidrule(lr){9-11}",
  "Amostra & $T$ & Tra\\c{c}o & Reinsel-Ahn & VC 5\\% & $p$ boot. & Tra\\c{c}o & $p$ boot. & Assint. & RA & Boot. & Escolha \\\\",
  "\\midrule",
  "\\multicolumn{12}{l}{\\textit{A. Tend\\^encia restrita ao vetor (ecdet = trend): regra de decis\\~ao}} \\\\",
  vapply(AMOSTRAS, linha_joh, "", ecd = "trend"),
  "\\multicolumn{12}{l}{\\textit{B. Constante restrita (ecdet = const): confer\\^encia}} \\\\",
  vapply(AMOSTRAS, linha_joh, "", ecd = "const"),
  tab_fim(sprintf(paste0(
    "Reinsel-Ahn: tra\\c{c}o vezes $(T - pK)/T$ (fator de %s a %s). Bootstrap selvagem de Cavaliere, Rahbek e Taylor (2012), %d r\\'eplicas, ",
    "dados gerados sob $H_0$; a corre\\c{c}\\~ao de Reinsel-Ahn \\'e um fator comum e n\\~ao muda o $p$ do bootstrap. ",
    "Regra fixada antes da estima\\c{c}\\~ao (A0): quando as leituras discordam prevalece o bootstrap a 5\\%%. ",
    "Evid\\^encia classificada como lim\\'itrofe nas tr\\^es amostras (%s). Dummies s\\'o determin\\'isticas: DUM nas amostras at\\'e 2019; pulsos de %s em 2003-2025. ",
    "Fonte: \\texttt{%s}."), ftx(min(JOH$fator_ra), 3), ftx(max(JOH$fator_ra), 3), B_BOOT,
    gsub("%", "\\%", paste(vapply(AMOSTRAS, function(a) paste0(a, ": ", dec[[a]]$motivo), ""), collapse = "; "), fixed = TRUE), paste(PULSOS, collapse = " e "), F_JOH)))

# 5c. Elasticidade de longo prazo: VAR ao lado do VEC em cada amostra
cel_el <- function(id, beta = FALSE) {
  z <- vr(id)
  if (beta) ctx(z$elasticidade_beta, z$elast_beta_ic90_inf, z$elast_beta_ic90_sup) else ctx(z$elasticidade, z$ic90_inf, z$ic90_sup)
}
linha_vv <- function(rot, f) paste0(rot, " & ", paste(vapply(AMOSTRAS, f, ""), collapse = " & "), " \\\\")
tex_vv <- c(
  tab_ini("Elasticidade de longo prazo: VAR em diferen\\c{c}a ao lado do VEC ($r = 1$) e do VAR em n\\'ivel", "tab:a6_var_vec", "lccc"),
  paste0("Modelo & ", paste(AMOSTRAS, collapse = " & "), " \\\\"), "\\midrule",
  linha_vv("VAR em diferen\\c{c}a (baseline pela regra)", function(a) cel_el(ID_VAR[[a]])),
  linha_vv("VEC, ecdet trend, ex\\'ogenas do VAR (vetor normalizado em PVD)", function(a) cel_el(ID_VEC[[a]], TRUE)),
  linha_vv("VEC, ecdet trend, s\\'o dummies determin\\'isticas", function(a) cel_el(paste0("vecm_det_", a), TRUE)),
  linha_vv("VEC, ecdet const", function(a) cel_el(paste0("vecm_const_", a), TRUE)),
  linha_vv(sprintf("VAR em n\\'ivel (raz\\~ao das respostas em $h = %d$)", H_VAR), function(a) cel_el(ID_NIV[[a]])),
  linha_vv("VEC: $\\alpha$ de PVD ($t$)", function(a) { z <- vr(ID_VEC[[a]]); sprintf("%s (%s)", ftx(z$alfa_pvd, 3), ftx(z$t_alfa_pvd, 2)) }),
  linha_vv("VEC: $\\alpha$ de INF ($t$)", function(a) { z <- vr(ID_VEC[[a]]); sprintf("%s (%s)", ftx(z$alfa_inf, 3), ftx(z$t_alfa_inf, 2)) }),
  linha_vv("$n$ (VAR em diferen\\c{c}a / VEC)", function(a) sprintf("%d / %d", vr(ID_VAR[[a]])$n, vr(ID_VEC[[a]])$n)),
  tab_fim(sprintf(paste0(
    "IC de 90\\%% por bootstrap. Pela regra (Tabela \\ref{tab:a6_johansen}) o baseline \\'e o VAR em diferen\\c{c}a nas tr\\^es amostras; ",
    "como a evid\\^encia \\'e lim\\'itrofe, o VEC vai ao lado. A coluna 2002-2019 original usa os arquivos da disserta\\c{c}\\~ao; ",
    "2003-2019 e 2003-2025 usam o baseline corrigido e o estendido. Fonte: \\texttt{%s}."), F_VAR)))

# 5d. Robustez do VAR em diferenca: variantes explicitas, cada uma em linha propria
ESP_ROB <- list(c("pib_taxa", "PIB em taxa de crescimento (sem diferenciar)"),
                c("chol_inv", "Ordem de Cholesky invertida (PVD antes de INF)"),
                c("p2", "Duas defasagens ($p = 2$)"),
                c("p4", "Quatro defasagens ($p = 4$)"),
                c("com_imp2017", "Com a indicadora da imputa\\c{c}\\~ao de 2017"),
                c("inf_diss_semao", "INF sem o efeito dos AO do X-11"),
                c("dummies_A4", "Outliers do X-11 de inf\\_diss de 2018-2021 (A4)"))
rob_cel <- function(id, base_id) {
  if (!(id %in% VAR$id)) return(c("", "", "", ""))
  z <- vr(id); b <- vr(base_id)
  c(as.character(z$n), ctx(z$elasticidade, z$ic90_inf, z$ic90_sup), sim_nao(!exclui0(z$ic90_inf, z$ic90_sup)),
    paste0(fnum(100 * z$elasticidade / b$elasticidade, 0, ","), "\\%"))
}
linha_rob <- function(pref, rot) {
  a <- rob_cel(paste0(pref, "_2003-2019"), "corr_c"); b <- rob_cel(paste0(pref, "_2003-2025"), "ext")
  paste0(rot, " & ", paste(c(a, b), collapse = " & "), " \\\\")
}
PREF_DEMAIS <- "^(ctrl_|selic_media_|excl_2016T4_2018T1_|inf_diss_e20|inf_diss_imprazao_|inf_diss_x11soma_|sem_dum_)"
demais <- function(am) {
  z <- VAR %>% filter(bloco == "robustez VAR", grepl(PREF_DEMAIS, id), amostra == am)
  list(k = nrow(z), min = min(z$elasticidade), med = median(z$elasticidade), max = max(z$elasticidade),
       pos = sum(z$ic90_inf > 0), gr = sum(z$granger_p_pub_priv < ALFA))
}
dm19 <- demais("2003-2019"); dm25 <- demais("2003-2025")
sub_a <- vr(grep("^sub_ate_", VAR$id, value = TRUE)); sub_b <- vr(grep("^sub_de_", VAR$id, value = TRUE))
CORTE_A <- sub("^sub_ate_([0-9T]+)_.*$", "\\1", sub_a$id); CORTE_B <- sub("^sub_de_([0-9T]+)_.*$", "\\1", sub_b$id)
linha_sub <- function(z, rot) sprintf("%s & & & & & %d & %s & %s & %s \\\\", rot, z$n, ctx(z$elasticidade, z$ic90_inf, z$ic90_sup),
                                      sim_nao(!exclui0(z$ic90_inf, z$ic90_sup)), paste0(fnum(100 * z$elasticidade / vr("ext")$elasticidade, 0, ","), "\\%"))
tex_rob <- c(
  tab_ini(sprintf("Robustez do VAR em diferen\\c{c}a: elasticidade de longo prazo ($h = %d$) por variante", H_VAR), "tab:a6_var_rob", "p{4.6cm}cccccccc"),
  "& \\multicolumn{4}{c}{2003-2019 (baseline corrigido)} & \\multicolumn{4}{c}{2003-2025 (estendido)} \\\\",
  "\\cmidrule(lr){2-5}\\cmidrule(lr){6-9}",
  "Variante & $n$ & Elasticidade [IC 90\\%] & IC inclui 0 & \\% do baseline & $n$ & Elasticidade [IC 90\\%] & IC inclui 0 & \\% do baseline \\\\",
  "\\midrule",
  paste0("Baseline & ", paste(c(rob_cel("corr_c", "corr_c"), rob_cel("ext", "ext")), collapse = " & "), " \\\\"),
  "\\multicolumn{9}{l}{\\textit{Robustez principal (cada variante em linha pr\\'opria)}} \\\\",
  vapply(ESP_ROB, function(e) linha_rob(e[1], e[2]), ""),
  linha_sub(sub_a, "Subamostra: observa\\c{c}\\~oes efetivas at\\'e 2014T4"),
  linha_sub(sub_b, "Subamostra: observa\\c{c}\\~oes efetivas de 2015T1 em diante"),
  "\\multicolumn{9}{l}{\\textit{Demais variantes (controles, Selic m\\'edia, variantes de INF da A3, exclus\\~ao de 2016T4-2018T1, sem DUM)}} \\\\",
  sprintf("N\\'umero de especifica\\c{c}\\~oes & \\multicolumn{4}{c}{%d} & \\multicolumn{4}{c}{%d} \\\\", dm19$k, dm25$k),
  sprintf("Elasticidade: m\\'inimo / mediana / m\\'aximo & \\multicolumn{4}{c}{%s / %s / %s} & \\multicolumn{4}{c}{%s / %s / %s} \\\\",
          ftx(dm19$min), ftx(dm19$med), ftx(dm19$max), ftx(dm25$min), ftx(dm25$med), ftx(dm25$max)),
  sprintf("IC de 90\\%% acima de zero & \\multicolumn{4}{c}{%d de %d} & \\multicolumn{4}{c}{%d de %d} \\\\", dm19$pos, dm19$k, dm25$pos, dm25$k),
  sprintf("Granger INF$\\to$PVD a 5\\%% & \\multicolumn{4}{c}{%d de %d} & \\multicolumn{4}{c}{%d de %d} \\\\", dm19$gr, dm19$k, dm25$gr, dm25$k),
  tab_fim(sprintf(paste0(
    "IC de 90\\%% por bootstrap (percentil). ``IC inclui 0'' = sim quando o intervalo cont\\'em zero: essas variantes perdem signific\\^ancia e n\\~ao ",
    "entram em faixa agregada. As subamostras partem da especifica\\c{c}\\~ao estendida (corte da A4 entre %s e %s); a subamostra de %s em diante ",
    "da amostra 2003-2019 n\\~ao foi estimada (poucas observa\\c{c}\\~oes). Fonte: \\texttt{%s}."), CORTE_A, CORTE_B, CORTE_B, F_VAR)))

# 5e. Robustez das LP: elasticidade acumulada de fbcf_me em h = 12 e multiplicador M_12 (agregados)
ESP_LP <- c("baseline", "pib_cresc", "ordem_invertida_dy_t", "p2", "p4", "exogenas_so_defasadas", "selic_media",
            "sub_ate_2014T4", "sub_de_2015T1", "ate_2019T4", "sem_2020_2021", "sem_2016T4_2018T1", "choques_sem_AO",
            "transferencia_grupos_1e2", "dummies_A4", "G_deflator_fbcf",
            "ctrl_cambio_real", "ctrl_icbr_usd", "ctrl_brent_usd", "ctrl_bndes_priv", "ctrl_cambio_real+icbr_usd",
            "ctrl_cambio_real+brent_usd", "ctrl_cambio_real+bndes_priv", "ctrl_icbr_usd+brent_usd",
            "ctrl_icbr_usd+bndes_priv", "ctrl_brent_usd+bndes_priv")
stopifnot(setequal(ESP_LP, unique(CUM$especificacao[CUM$modelo == "diferenca"])))
lp_rob_cel <- function(s, esp, medida = "elasticidade", resp = "fbcf_me", d = 2) {
  z <- cu(s, resp, 12, medida, esp)
  if (is.null(z)) return("")
  paste0(ctx(z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, d), estr(z$ic90_inf_aj, z$ic90_sup_aj))
}
n_esp <- function(esp, choques) {
  ns <- unlist(lapply(choques, function(s) { z <- cu(s, "fbcf_me", 12, "elasticidade", esp); if (is.null(z)) NULL else z$n }))
  if (!length(ns)) {
    ns <- unlist(lapply(choques, function(s) { z <- cu(s, "fbcf_real_rs_bi", 12, "multiplicador", esp); if (is.null(z)) NULL else z$n }))
  }
  stopifnot(length(unique(ns)) == 1)
  unique(ns)
}
ROB_AGR <- c("inf_diss", "estatais_total")
ROB_UNI <- c("uniao_econ_dir", "uniao_soc_dir", "uniao_econ_dt_g1", "uniao_soc_dt_g1", "uniao_transf_soc_g1")
tex_lprob_a <- c(
  tab_ini("Robustez das proje\\c{c}\\~oes locais, agregados: elasticidade acumulada de fbcf\\_me e multiplicador da FBCF em R\\$, $h = 12$",
          "tab:a6_lp_rob_agr", "lccccc"),
  "Especifica\\c{c}\\~ao & $n$ & Elast. inf\\_diss & Elast. estatais\\_total & $M_{12}$ inf\\_diss & $M_{12}$ estatais\\_total \\\\", "\\midrule",
  vapply(setdiff(ESP_LP, "transferencia_grupos_1e2"), function(e) sprintf("%s & %d & %s & %s & %s & %s \\\\", esc(e), n_esp(e, ROB_AGR),
         lp_rob_cel("inf_diss", e), lp_rob_cel("estatais_total", e),
         lp_rob_cel("inf_diss", e, "multiplicador", "fbcf_real_rs_bi"), lp_rob_cel("estatais_total", e, "multiplicador", "fbcf_real_rs_bi")), ""),
  tab_fim(sprintf(paste0(
    "Estimativa [IC de 90\\%%] com Newey-West vezes $n/(n-k)$ e $t$ com $n - k$ graus de liberdade (colunas \\texttt{ic90\\_*\\_aj}); ",
    "$^{*}$ = IC exclui zero. $n$ = observa\\c{c}\\~oes em $h = 12$. Em $h = 12$, sem\\_2020\\_2021 coincide com ate\\_2019T4 por constru\\c{c}\\~ao ",
    "(A5). transferencia\\_grupos\\_1e2 n\\~ao se aplica aos agregados (fica fora); G\\_deflator\\_fbcf s\\'o muda o multiplicador. Fonte: \\texttt{%s}."), F_CUM)))
tex_lprob_b <- c(
  tab_ini("Robustez das proje\\c{c}\\~oes locais, Uni\\~ao por tipo e modalidade: elasticidade acumulada de fbcf\\_me, $h = 12$",
          "tab:a6_lp_rob_uniao", "lcccccc"),
  paste0("Especifica\\c{c}\\~ao & $n$ & ", paste(esc(ROB_UNI), collapse = " & "), " \\\\"), "\\midrule",
  vapply(setdiff(ESP_LP, "G_deflator_fbcf"), function(e) sprintf("%s & %d & %s \\\\", esc(e), n_esp(e, ROB_UNI),
         paste(vapply(ROB_UNI, lp_rob_cel, "", esp = e), collapse = " & ")), ""),
  tab_fim(sprintf(paste0(
    "Como na Tabela \\ref{tab:a6_lp_rob_agr}. Regress\\~oes separadas, um choque por vez; para comparar rubricas valem as regress\\~oes conjuntas ",
    "(Tabela \\ref{tab:a6_lp_cmp} em \\texttt{A\\_lp.tex}). transferencia\\_grupos\\_1e2 s\\'o nos choques \\_g1. Fonte: \\texttt{%s}."), F_CUM)))

cab <- c(sprintf("%% Gerado por R/A6_saidas.R em %s. Requer \\usepackage{booktabs} e \\usepackage{adjustbox}. Numeros com virgula decimal.", format(Sys.time(), "%Y-%m-%d %H:%M")),
         "% Nenhum numero digitado a mao: tudo vem de data/processed/A5_*.csv, A3_*.csv, A1_alvos_dissertacao.csv e results/A4_quebras_resumo.csv.")
write_lines_safe(c(cab, tex_var, tex_joh, tex_vv, tex_rob, tex_lprob_a, tex_lprob_b), file.path(PATHS$results, "A_robustez.tex"))

# ------------------------------------------------------------------------------------------------
# 6. results/A_lp.tex
# ------------------------------------------------------------------------------------------------
hs_de <- function(s) if (s %in% CURTOS) c(4, 8) else c(4, 8, 12)
rot_choque <- function(s) paste0(esc(s), if (s %in% CURTOS) " (2016+)" else "")
# 6a. Elasticidades acumuladas: fbcf_me e fbcf_cnt_vol com IC ajustado
cel_aj <- function(z, d = 3) if (is.null(z)) "" else paste0(ctx(z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, d), estr(z$ic90_inf_aj, z$ic90_sup_aj))
linhas_el <- unlist(lapply(CHOQ, function(s) vapply(hs_de(s), function(h) {
  a <- cu(s, "fbcf_me", h); b <- cu(s, "fbcf_cnt_vol", h)
  sprintf("%s & %d & %s & %s & %s & %s & %d & %s \\\\", if (h == 4) rot_choque(s) else "", h, cel_aj(a), ptx(a$p_valor_aj),
          cel_aj(b), ptx(b$p_valor_aj), a$n, ftx(min(a$f_primeiro_estagio, b$f_primeiro_estagio), 1))
}, "")))
tex_el <- c(
  tab_ini("Elasticidades acumuladas (MQ2E) do investimento privado a cada choque de investimento p\\'ublico, baseline",
          "tab:a6_lp_elast", "lcccccccc"),
  "Choque & $h$ & fbcf\\_me [IC 90\\%] & $p$ & fbcf\\_cnt\\_vol [IC 90\\%] & $p$ & $n$ & $F_1$ m\\'in. \\\\", "\\midrule",
  linhas_el,
  tab_fim(sprintf(paste0(
    "Elasticidade acumulada = MQ2E de $\\sum_{j=0}^{h}(y_{t+j}-y_{t-1})$ em $\\sum_{j=0}^{h}(x_{t+j}-x_{t-1})$, instrumento $\\Delta x_t$ ",
    "(Ramey e Zubairy, 2018), com %d defasagens (%d nas s\\'eries de 2016+), constante, tend\\^encia, acelera\\c{c}\\~ao do PIB, $\\Delta$Selic e pulsos de %s. ",
    "fbcf\\_me = M\\&E do Ipea (o PVD da disserta\\c{c}\\~ao); fbcf\\_cnt\\_vol = FBCF em volume das Contas Nacionais Trimestrais. ",
    "IC de 90\\%% e $p$ com Newey-West (lag $h+1$) vezes $n/(n-k)$ e $t$ com $n-k$ graus de liberdade; $^{*}$ = IC exclui zero. ",
    "$F_1$ = menor F (Newey-West) do primeiro est\\'agio entre as duas respostas. S\\'eries de 2016+: baixo poder. ",
    "IC pontuais, sem corre\\c{c}\\~ao para testes m\\'ultiplos: no baseline, %d de %d elasticidades acumuladas t\\^em IC ajustado que exclui zero. Fonte: \\texttt{%s}."),
    P_LP, P_LP_CURTO, paste(PULSOS, collapse = " e "), n_el_excl_aj, n_el, F_CUM)))
# 6b. Demais respostas (estimativa com estrela)
OUTRAS <- c("fbcf_constr", "fbcf_total", "fbcf_outros", "pim_bk", "imp_bk_quantum", "bndes_priv")
linhas_el2 <- unlist(lapply(CHOQ, function(s) vapply(hs_de(s), function(h) {
  v <- vapply(OUTRAS, function(r) { z <- cu(s, r, h); paste0(ftx(z$estimativa, 3), estr(z$ic90_inf_aj, z$ic90_sup_aj)) }, "")
  sprintf("%s & %d & %s \\\\", if (h == 4) rot_choque(s) else "", h, paste(v, collapse = " & "))
}, "")))
tex_el2 <- c(
  tab_ini("Elasticidades acumuladas das demais respostas privadas, baseline", "tab:a6_lp_elast_outras", "lccccccc"),
  paste0("Choque & $h$ & ", paste(esc(OUTRAS), collapse = " & "), " \\\\"), "\\midrule",
  linhas_el2,
  tab_fim(sprintf(paste0(
    "Como na Tabela \\ref{tab:a6_lp_elast}; $^{*}$ = IC de 90\\%% ajustado exclui zero. pim\\_bk = produ\\c{c}\\~ao de bens de capital (PIM-PF); ",
    "imp\\_bk\\_quantum = quantum importado de bens de capital; bndes\\_priv = desembolsos do BNDES exceto administra\\c{c}\\~ao p\\'ublica (inclui estatais). ",
    "Fonte: \\texttt{%s}."), F_CUM)))
# 6c. Multiplicadores em R$
AGREG <- c("inf_diss", "estatais_total", "uniao_gnd4_dir", "uniao_filtro_diss")
RUBR <- setdiff(CHOQ, AGREG)
cel_m <- function(z) if (is.null(z)) "" else paste0(ctx(z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, 2), estr(z$ic90_inf_aj, z$ic90_sup_aj))
linhas_m <- function(ss) unlist(lapply(ss, function(s) vapply(hs_de(s), function(h) {
  a <- cu(s, "fbcf_real_rs_bi", h, "multiplicador"); b <- cu(s, "bndes_priv", h, "multiplicador"); i <- cu(s, "imp_bk_real", h, "multiplicador")
  sprintf("%s & %s & %d & %s & %s & %s & %s & %d \\\\", if (h == 4) rot_choque(s) else "", if (h == 4) paste0(ftx(GY[[s]], 1), "\\%") else "",
          h, cel_m(a), ptx(a$p_valor_aj), cel_m(b), cel_m(i), a$n)
}, "")))
tex_m <- c(
  tab_ini("Multiplicadores acumulados em R\\$ (estimativas separadas): FBCF, desembolsos do BNDES e importa\\c{c}\\~ao de bens de capital",
          "tab:a6_lp_mult", "lccccccc"),
  "Choque & G/FBCF & $h$ & $M_h$ FBCF [IC 90\\%] & $p$ & $M_h$ BNDES [IC 90\\%] & $M_h$ import. BK [IC 90\\%] & $n$ \\\\", "\\midrule",
  "\\multicolumn{8}{l}{\\textit{A. Agregados grandes: leitura em R\\$ por R\\$}} \\\\", linhas_m(AGREG),
  "\\multicolumn{8}{l}{\\textit{B. Rubricas: G \\'e uma fra\\c{c}\\~ao m\\'inima da FBCF; o $M_h$ separado n\\~ao se l\\^e em R\\$ por R\\$}} \\\\", linhas_m(RUBR),
  tab_fim(sprintf(paste0(
    "$M_h$ = MQ2E de $\\sum_{j=0}^{h}(Y_{t+j}-Y_{t-1})/\\mathrm{PIB}_{t-1}$ em $\\sum_{j=0}^{h}(G_{t+j}-G_{t-1})/\\mathrm{PIB}_{t-1}$, instrumento $\\Delta G_t/\\mathrm{PIB}_{t-1}$ ",
    "(Ramey e Zubairy, 2018). G/FBCF = m\\'edia de G / m\\'edia da FBCF na janela do choque (n\\'iveis com ajuste, R\\$ de 2025): $M_h$ \\'e aproximadamente a elasticidade ",
    "vezes FBCF/G, e nas rubricas pequenas elasticidades modestas viram dezenas de reais. Nas rubricas, a A5 mostra que o $M_h$ separado cai e perde ",
    "signific\\^ancia na regress\\~ao conjunta (Tabela \\ref{tab:a6_lp_cmp}). IC e $p$ ajustados como na Tabela \\ref{tab:a6_lp_elast}; $^{*}$ = IC exclui zero. Fonte: \\texttt{%s}; G/FBCF de \\texttt{%s} e \\texttt{%s}."),
    F_CUM, F_NIV, F_A2)))
# 6d. Comparacoes (regressao conjunta)
PARES <- list(c("uniao_econ_dir", "uniao_soc_dir", "Uni\\~ao econ\\^omica x social (direta)"),
              c("uniao_econ_dt_g1", "uniao_soc_dt_g1", "Uni\\~ao econ\\^omica x social (direta + transfer\\^encia)"),
              c("uniao_soc_dir", "uniao_transf_soc_g1", "Social: direta x transfer\\^encia"),
              c("estatais_sempetro", "estatais_petro", "Estatais sem petr\\'oleo x petr\\'oleo (2016+)"),
              c("estatais_total", "uniao_gnd4_dir", "Estatais x Uni\\~ao direta (GND 4)"))
stopifnot(length(unique(paste(CMP$choque_a, CMP$choque_b))) == length(PARES))
linhas_cmp <- function(resp, medida, d) unlist(lapply(PARES, function(pp) {
  hs <- sort(unique(CMP$h[CMP$choque_a == pp[1] & CMP$choque_b == pp[2]]))
  vapply(hs, function(h) {
    z <- cp(pp[1], pp[2], resp, h, medida)
    sprintf("%s & %d & %s & %s & %s (%s) & %s & %s & %s / %s & %d \\\\", if (h == min(hs)) pp[3] else "", h,
            paste0(ctx(z$est_a, z$lo_a, z$hi_a, d), estr(z$lo_a, z$hi_a)), paste0(ctx(z$est_b, z$lo_b, z$hi_b, d), estr(z$lo_b, z$hi_b)),
            ftx(z$diferenca, d), ftx(z$ep_dif_aj, d), ptx(z$p_wald), ptx(z$p_wald_pa), ftx(z$f1_a, 1), ftx(z$f1_b, 1), z$n)
  }, "")
}))
tex_cmp <- c(
  tab_ini("Compara\\c{c}\\~oes: regress\\~ao conjunta com os dois choques e Wald da igualdade", "tab:a6_lp_cmp", "p{3.4cm}cccccccc"),
  "Compara\\c{c}\\~ao (a x b) & $h$ & a [IC 90\\%] & b [IC 90\\%] & a $-$ b (EP) & $p$ Wald & $p$ amostra pequena & $F_1$ a / b & $n$ \\\\", "\\midrule",
  "\\multicolumn{9}{l}{\\textit{A. Elasticidade acumulada da FBCF em volume (fbcf\\_cnt\\_vol): resultado principal}} \\\\", linhas_cmp("fbcf_cnt_vol", "elasticidade", 3),
  "\\multicolumn{9}{l}{\\textit{B. Elasticidade acumulada de M\\&E (fbcf\\_me)}} \\\\", linhas_cmp("fbcf_me", "elasticidade", 3),
  "\\multicolumn{9}{l}{\\textit{C. Multiplicador acumulado da FBCF em R\\$ (ressalva de escala: G/FBCF na Tabela \\ref{tab:a6_lp_mult})}} \\\\", linhas_cmp("fbcf_real_rs_bi", "multiplicador", 2),
  tab_fim(sprintf(paste0(
    "Os dois choques entram na mesma regress\\~ao (somas acumuladas instrumentadas pelos dois $\\Delta x_t$), com as defasagens dos dois choques e da resposta. ",
    "$p$ Wald: qui-quadrado com 1 grau e Newey-West sem ajuste; $p$ amostra pequena: Newey-West vezes $n/(n-k)$ e $F(1, n-k)$ (coluna \\texttt{p\\_wald\\_pa}). ",
    "IC individuais e EP da diferen\\c{c}a com o mesmo ajuste; $^{*}$ = IC exclui zero. Estatais sem petr\\'oleo x petr\\'oleo: s\\'erie de 2016+, $n$ de %d a %d e ",
    "$n - k$ de %d a %d, baixo poder. Na econ\\^omica, a transfer\\^encia n\\~ao passa no crit\\'erio de qualidade da A3, e a compara\\c{c}\\~ao direta x transfer\\^encia fica s\\'o na social. ",
    "Compara\\c{c}\\~oes com BNDES e importa\\c{c}\\~ao de BK em \\texttt{%s}. Fonte: \\texttt{%s}."),
    min(CMP$n[CMP$baixo_poder]), max(CMP$n[CMP$baixo_poder]), min(CMP$gl[CMP$baixo_poder]), max(CMP$gl[CMP$baixo_poder]), F_CMP, F_CMP)))
write_lines_safe(c(cab, tex_el, tex_el2, tex_m, tex_cmp), file.path(PATHS$results, "A_lp.tex"))

# ------------------------------------------------------------------------------------------------
# 7. Figuras (ingles, para o resumo estendido): elasticidade conjunta da FBCF em volume, IC de 90% ajustado
# ------------------------------------------------------------------------------------------------
COR_A <- "#2a78d6"; COR_B <- "#eb6834"
fig_df <- function(pares) bind_rows(lapply(pares, function(pp) {
  z <- CMP %>% filter(choque_a == pp$a, choque_b == pp$b, resposta == "fbcf_cnt_vol", medida == "elasticidade")
  bind_rows(
    tibble(painel = pp$painel, h = z$h, serie = pp$lab_a, grupo = "a", est = z$est_a, lo = z$lo_a, hi = z$hi_a, p = z$p_wald_pa, n = z$n),
    tibble(painel = pp$painel, h = z$h, serie = pp$lab_b, grupo = "b", est = z$est_b, lo = z$lo_b, hi = z$hi_b, p = z$p_wald_pa, n = z$n))
}))
plota <- function(df, cores, arquivo, rotulos = NULL) {
  df$painel <- factor(df$painel, levels = unique(df$painel))
  df$serie <- factor(df$serie, levels = unique(df$serie))
  faixa <- max(df$hi) - min(df$lo)
  pl <- df %>% distinct(painel, h, p, n) %>%
    mutate(y = max(df$hi) + 0.06 * faixa,
           lab = paste0("p = ", ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)), "\nn = ", n))
  g <- ggplot(df, aes(x = factor(h), y = est, colour = serie)) +
    geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
    geom_linerange(aes(ymin = lo, ymax = hi), position = position_dodge(width = 0.5), linewidth = 0.7) +
    geom_point(position = position_dodge(width = 0.5), size = 1.8) +
    geom_text(data = pl, aes(x = factor(h), y = y, label = lab), inherit.aes = FALSE, size = 2.3, colour = "grey25",
              lineheight = 0.9, vjust = 0) +
    facet_wrap(~painel, nrow = 1, scales = "free_x") +
    scale_colour_manual(values = cores) +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.26))) +
    labs(x = "Horizon h (quarters)", y = "Cumulative elasticity of GFCF", colour = NULL) +
    theme_minimal(base_size = 8) +
    theme(legend.position = "top", legend.margin = margin(0, 0, 0, 0), panel.grid.minor = element_blank(),
          panel.grid.major.x = element_blank(), strip.text = element_text(face = "plain", size = 8),
          axis.text = element_text(colour = "grey25"), axis.title = element_text(colour = "grey25"))
  if (!is.null(rotulos)) {
    # rotulos diretos (texto em cinza escuro ao lado do primeiro horizonte de cada painel); sem legenda
    r1 <- df %>% group_by(painel) %>% filter(h == min(h)) %>% ungroup() %>%
      left_join(rotulos, by = c("painel", "grupo")) %>%
      mutate(x = ifelse(grupo == "a", 1 - 0.2, 1 + 0.2), hj = ifelse(grupo == "a", 1, 0))
    r1$painel <- factor(as.character(r1$painel), levels = levels(df$painel))
    g <- g + geom_text(data = r1, aes(x = x, y = est, label = rotulo, hjust = hj), inherit.aes = FALSE, size = 2.4, colour = "grey20") +
      theme(legend.position = "none")
  }
  for (ext in c("pdf", "png")) {
    ggsave_safe(file.path(PATHS$figuras, paste0(arquivo, ".", ext)), g, width = 5.2, height = 1.9, units = "in", dpi = 300)
  }
  invisible(g)
}
df1 <- fig_df(list(
  list(a = "uniao_econ_dir", b = "uniao_soc_dir", painel = "Federal, direct application", lab_a = "Economic infrastructure", lab_b = "Social infrastructure"),
  list(a = "uniao_econ_dt_g1", b = "uniao_soc_dt_g1", painel = "Federal, direct + capital transfers", lab_a = "Economic infrastructure", lab_b = "Social infrastructure")))
plota(df1, setNames(c(COR_A, COR_B), c("Economic infrastructure", "Social infrastructure")), "A6_fig1_econ_social")
df2 <- fig_df(list(
  list(a = "uniao_soc_dir", b = "uniao_transf_soc_g1", painel = "Federal social infrastructure", lab_a = "Direct application | non-oil SOEs", lab_b = "Capital transfers | oil SOEs"),
  list(a = "estatais_sempetro", b = "estatais_petro", painel = "Federal SOEs (short sample, low power)", lab_a = "Direct application | non-oil SOEs", lab_b = "Capital transfers | oil SOEs")))
plota(df2, setNames(c(COR_A, COR_B), c("Direct application | non-oil SOEs", "Capital transfers | oil SOEs")), "A6_fig2_direta_transf_estatais",
      rotulos = tibble(painel = c("Federal social infrastructure", "Federal social infrastructure",
                                  "Federal SOEs (short sample, low power)", "Federal SOEs (short sample, low power)"),
                       grupo = c("a", "b", "a", "b"), rotulo = c("Direct", "Transfers", "Non-oil", "Oil")))

# ------------------------------------------------------------------------------------------------
# 8. Macros do resumo estendido (ingles, ponto decimal)
# ------------------------------------------------------------------------------------------------
MAC <- character(0)
FONTE_MAC <- character(0)
mk <- function(nome, valor, fonte) {
  stopifnot(grepl("^[A-Za-z]+$", nome), !(nome %in% names(MAC)), length(valor) == 1, !is.na(valor))
  MAC[[nome]] <<- valor
  FONTE_MAC[[nome]] <<- fonte
}
mk_ci <- function(pref, b, lo, hi, d, fonte) {
  mk(pref, fen(b, d), fonte); mk(paste0(pref, "Lo"), fen(lo, d), fonte); mk(paste0(pref, "Hi"), fen(hi, d), fonte)
}
per <- function(a, b) paste0(a, "--", b)
# amostras e desenho
am_per <- function(a) { x <- strsplit(sub(" .*$", "", a), "-")[[1]]; per(x[1], x[2]) }
am_lp <- unique(CUM$amostra[CUM$choque == "inf_diss" & CUM$especificacao == "baseline"])
stopifnot(length(am_lp) == 1)
HS <- sort(unique(CUM$h)); stopifnot(length(HS) == 3)
mk("SampleStartYear", as.character(ANO_INI), F_INV); mk("SampleEndYear", as.character(ANO_FIM), F_INV)
mk("SampleFull", gsub("T", "Q", sub("-", "--", am_lp)), F_CUM); mk("NQuarters", as.character(N_Q), F_A2)
mk("SampleOrig", am_per(AMOSTRAS[1]), F_VAR); mk("SampleCorr", am_per(AMOSTRAS[2]), F_VAR); mk("SampleExt", am_per(AMOSTRAS[3]), F_VAR)
mk("CILevel", as.character(NIVEL_IC), F_CUM); mk("SigLevel", as.character(100 * ALFA), F_JOH); mk("SigLevelTen", as.character(100 * ALFA10), F_CMP)
mk("VARp", as.character(P_VAR), F_VAR); mk("VARh", as.character(H_VAR), F_VAR); mk("VARruns", as.character(runs_rep), F_VAR)
mk("JohK", as.character(K_JOH), F_JOH); mk("JohB", as.character(B_BOOT), F_JOH)
mk("LPp", as.character(P_LP), F_CUM); mk("LPpShort", as.character(P_LP_CURTO), F_CUM); mk("LPhmax", as.character(HMAX), F_IRF)
mk("LPhmaxShort", as.character(HMAX_CURTO), F_IRF); mk("hA", as.character(HS[1]), F_CUM); mk("hB", as.character(HS[2]), F_CUM); mk("hC", as.character(HS[3]), F_CUM)
mk("nLPA", as.character(cu("inf_diss", "fbcf_me", 4)$n), F_CUM); mk("nLPC", as.character(cu("inf_diss", "fbcf_me", 12)$n), F_CUM)
mk("nLPzero", as.character(n_lp_h0$n), F_IRF)
mk("PulseDates", paste(gsub("T", "Q", PULSOS), collapse = " and "), "data/processed/A4_dummies_quebra.csv")
# dados
mk("PerShares", per(as.character(ANO_INI), as.character(ANO_FIM)), F_INV)
mk("ShareSocTransf", fen(share_soc_transf, 0), F_INV); mk("ShareEconDir", fen(share_econ_dir, 0), F_INV)
mk("SestBoletimEnd", as.character(BOLETIM_FIM), F_INV); mk("SestOIStart", as.character(OI_INI), F_INV)
mk("PetroShareMin", fen(petro_min, 0), F_INV); mk("PetroShareMax", fen(petro_max, 0), F_INV); mk("PerOI", per(as.character(OI_INI), as.character(OI_FIM)), F_INV)
mk("BaseYear", as.character(ANO_FIM), F_INV)
# VAR replicado e corrigido
rep <- vr("replicado"); cc <- vr("corr_c"); ex <- vr("ext")
mk("nRep", as.character(rep$n), F_VAR); mk("nCorr", as.character(cc$n), F_VAR); mk("nExt", as.character(ex$n), F_VAR)
mk("ImpRep", fen(rep$impacto, 4), F_VAR); mk("AcumRep", fen(rep$resp_acum_40_priv, 4), F_VAR); mk("AcumInfRep", fen(rep$resp_acum_40_pub, 4), F_VAR)
mk_ci("ElastRep", rep$elasticidade, rep$ic90_inf, rep$ic90_sup, 2, F_VAR)
mk_ci("ElastCorr", cc$elasticidade, cc$ic90_inf, cc$ic90_sup, 2, F_VAR)
mk_ci("ElastExt", ex$elasticidade, ex$ic90_inf, ex$ic90_sup, 2, F_VAR)
mk("pGrangerRep", fen(rep$granger_p_pub_priv, 3), F_VAR); mk("pGrangerRevRep", fen(rep$granger_p_priv_pub, 2), F_VAR)
mk("pGrangerTextRev", fen(alv("t12_causa_PVD_p"), 2), F_ALV); mk("FGrangerTextRev", fen(alv("t12_causa_PVD_F"), 2), F_ALV)
mk("pGrangerImplied", fen(p_implicito_t12, 2), F_ALV)
mk("JohTextTrace", fen(alv("t8_traco_r0"), 2), F_ALV); mk("JohTextCV", fen(alv("t8_cv5_r0"), 2), F_ALV)
mk("DumDates", paste(gsub("T", "Q", dum_txt), collapse = " and "), F_EXO)
mk("CorrNominal", fen(inf_nom$corr_dif, 3), F_VARI); mk("DevNominal", fen(inf_nom$desvio_medio_nivel, 3), F_VARI)
mk("CorrReal", fen(inf_real$corr_dif, 3), F_VARI); mk("DevReal", fen(-inf_real$desvio_medio_nivel, 2), F_VARI)
# Johansen e VEC
for (a in AMOSTRAS) {
  suf <- c("2002-2019 original" = "Orig", "2003-2019" = "Corr", "2003-2025" = "Ext")[[a]]
  t0 <- jo(a, "trend", "r = 0")
  mk(paste0("JohTr", suf), fen(t0$traco, 2), F_JOH); mk(paste0("JohRa", suf), fen(t0$traco_ra, 2), F_JOH)
  mk(paste0("JohBoot", suf), fen(t0$p_boot, 3), F_JOH)
  zv <- vr(ID_VEC[[a]])
  mk_ci(paste0("Vec", suf), zv$elasticidade_beta, zv$elast_beta_ic90_inf, zv$elast_beta_ic90_sup, 2, F_VAR)
}
stopifnot(length(unique(JOH$cv5[JOH$ecdet == "trend" & JOH$hipotese == "r = 0"])) == 1)
mk("JohCV", fen(jo("2003-2019", "trend", "r = 0")$cv5, 2), F_JOH)
# sensibilidade do baseline corrigido e do estendido
for (sp in list(c("chol_inv", "Chol"), c("p2", "Ptwo"), c("pib_taxa", "Gdp"))) {
  z <- vr(paste0(sp[1], "_2003-2019")); mk_ci(paste0("Elast", sp[2], "Corr"), z$elasticidade, z$ic90_inf, z$ic90_sup, 2, F_VAR)
  z <- vr(paste0(sp[1], "_2003-2025")); mk_ci(paste0("Elast", sp[2], "Ext"), z$elasticidade, z$ic90_inf, z$ic90_sup, 2, F_VAR)
}
mk_ci("ElastSubA", sub_a$elasticidade, sub_a$ic90_inf, sub_a$ic90_sup, 2, F_VAR)
mk_ci("ElastSubB", sub_b$elasticidade, sub_b$ic90_inf, sub_b$ic90_sup, 2, F_VAR)
mk("SubAEnd", gsub("T", "Q", sub("^sub_ate_([0-9T]+)_.*$", "\\1", sub_a$id)), F_VAR); mk("SubBStart", gsub("T", "Q", sub("^sub_de_([0-9T]+)_.*$", "\\1", sub_b$id)), F_VAR)
zd <- vr("dummies_A4_2003-2025"); mk_ci("ElastDumA", zd$elasticidade, zd$ic90_inf, zd$ic90_sup, 2, F_VAR)
mk("SupFDate", gsub("T", "Q", qi$supF_data), F_Q4); mk("SupFpInf", pen(qi$supF_p), F_Q4); mk("SupFpFbcf", pen(qf$supF_p), F_Q4)
# LP: agregados
z <- cu("inf_diss", "fbcf_me", 12); mk_ci("LpInfElast", z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, 2, F_CUM)
z <- cu("inf_diss", "fbcf_real_rs_bi", 12, "multiplicador"); mk_ci("LpInfMult", z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, 2, F_CUM)
z <- cu("estatais_total", "fbcf_real_rs_bi", 12, "multiplicador"); mk_ci("LpSoeMult", z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, 2, F_CUM)
z <- cu("uniao_gnd4_dir", "fbcf_me", 12); mk_ci("LpGndElast", z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, 2, F_CUM)
z <- cu("uniao_gnd4_dir", "fbcf_real_rs_bi", 8, "multiplicador"); mk_ci("LpGndMultB", z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, 2, F_CUM)
z <- cu("uniao_gnd4_dir", "fbcf_real_rs_bi", 12, "multiplicador"); mk_ci("LpGndMult", z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, 2, F_CUM)
z <- cu("uniao_soc_dir", "fbcf_real_rs_bi", 12, "multiplicador"); mk("LpSocDirMultSep", fen(z$estimativa, 1), F_CUM)
zj <- cp("uniao_econ_dir", "uniao_soc_dir", "fbcf_real_rs_bi", 12, "multiplicador")
mk_ci("LpSocDirMultJoint", zj$est_b, zj$lo_b, zj$hi_b, 1, F_CMP)
mk("GshareInf", fen(GY[["inf_diss"]], 1), F_NIV); mk("GshareSoe", fen(GY[["estatais_total"]], 1), F_NIV)
mk("GshareSocDir", fen(GY[["uniao_soc_dir"]], 1), F_NIV); mk("GshareEconDir", fen(GY[["uniao_econ_dir"]], 1), F_NIV)
mk("GshareTransfSoc", fen(GY[["uniao_transf_soc_g1"]], 1), F_NIV)
mk("NexclZero", as.character(n_el_excl_aj), F_CUM); mk("NcumTotal", as.character(n_el), F_CUM)
# LP: comparacoes (elasticidade conjunta da FBCF em volume; p com ajuste de amostra pequena)
cmp_mac <- function(pref, a, b, h, resp = "fbcf_cnt_vol") {
  z <- cp(a, b, resp, h)
  mk(paste0(pref, "A"), fen(z$est_a, 2), F_CMP); mk(paste0(pref, "B"), fen(z$est_b, 2), F_CMP)
  mk(paste0(pref, "p"), pen(z$p_wald_pa), F_CMP); mk(paste0(pref, "pUnadj"), pen(z$p_wald), F_CMP)
  mk(paste0(pref, "n"), as.character(z$n), F_CMP); mk(paste0(pref, "df"), as.character(z$gl), F_CMP)
  mk(paste0(pref, "MEp"), pen(cp(a, b, "fbcf_me", h)$p_wald_pa), F_CMP)
  mk_ci(paste0(pref, "Ae"), z$est_a, z$lo_a, z$hi_a, 2, F_CMP); mk_ci(paste0(pref, "Be"), z$est_b, z$lo_b, z$hi_b, 2, F_CMP)
}
cmp_mac("EcoSocDirHA", "uniao_econ_dir", "uniao_soc_dir", 4); cmp_mac("EcoSocDirHC", "uniao_econ_dir", "uniao_soc_dir", 12)
cmp_mac("EcoSocDtHA", "uniao_econ_dt_g1", "uniao_soc_dt_g1", 4); cmp_mac("EcoSocDtHC", "uniao_econ_dt_g1", "uniao_soc_dt_g1", 12)
cmp_mac("SocTrHA", "uniao_soc_dir", "uniao_transf_soc_g1", 4); cmp_mac("SocTrHB", "uniao_soc_dir", "uniao_transf_soc_g1", 8)
cmp_mac("SocTrHC", "uniao_soc_dir", "uniao_transf_soc_g1", 12)
cmp_mac("SoeHA", "estatais_sempetro", "estatais_petro", 4); cmp_mac("SoeHB", "estatais_sempetro", "estatais_petro", 8)
cmp_mac("SoeUniHA", "estatais_total", "uniao_gnd4_dir", 4); cmp_mac("SoeUniHC", "estatais_total", "uniao_gnd4_dir", 12)
p_soc_me <- CMP$p_wald_pa[CMP$choque_a == "uniao_soc_dir" & CMP$choque_b == "uniao_transf_soc_g1" & CMP$resposta == "fbcf_me"]
mk("SocTrMEpMin", fen(min(p_soc_me), 3), F_CMP); mk("SocTrMEpMax", fen(max(p_soc_me), 3), F_CMP)
p_soe_uni <- CMP$p_wald_pa[CMP$choque_a == "estatais_total" & CMP$choque_b == "uniao_gnd4_dir" & CMP$resposta == "fbcf_cnt_vol"]
mk("SoeUnipMin", fen(min(p_soe_uni), 3), F_CMP); mk("SoeUnipMax", fen(max(p_soe_uni), 3), F_CMP)
p_eco_soc <- CMP$p_wald_pa[CMP$choque_a %in% c("uniao_econ_dir", "uniao_econ_dt_g1") & CMP$medida == "elasticidade"]
mk("EcoSocpMin", fen(floor(1000 * min(p_eco_soc)) / 1000, 3), F_CMP)   # truncado: o texto diz p >= este valor

mac_txt <- c(sprintf("%% Gerado por R/A6_saidas.R em %s. Nao editar a mao. Formato ingles (ponto decimal).", format(Sys.time(), "%Y-%m-%d %H:%M")),
             "% Cada macro traz, em comentario, o arquivo de origem.",
             sprintf("\\newcommand{\\%s}{%s} %% %s", names(MAC), MAC, FONTE_MAC[names(MAC)]))
write_lines_safe(mac_txt, file.path(PATHS$results, "A_numeros_macros.tex"))

# ------------------------------------------------------------------------------------------------
# 9. results/A_numeros_halle.md (so numeros, com a origem)
# ------------------------------------------------------------------------------------------------
src <- function(f, extra = NULL) paste0(" (", f, if (!is.null(extra)) paste0(", ", extra), ")")
bl <- function(...) paste0("- ", ...)
md_var <- function(id, rot) {
  z <- vr(id)
  bl(rot, ": n = ", z$n, "; impacto ", fmd(z$impacto, 4), "; acumulada de PVD (h = ", H_VAR, ") ", cmd(z$resp_acum_40_priv, z$ic90_acum_priv_inf, z$ic90_acum_priv_sup, 4),
     "; acumulada de INF ", fmd(z$resp_acum_40_pub, 4), "; elasticidade ", cmd(z$elasticidade, z$ic90_inf, z$ic90_sup),
     "; Granger INF -> PVD p = ", pmd(z$granger_p_pub_priv), ", PVD -> INF p = ", pmd(z$granger_p_priv_pub), src(F_VAR, paste0("id ", id)))
}
md_cu <- function(s, r, h, medida = "elasticidade", d = 3) {
  z <- cu(s, r, h, medida)
  paste0(cmd(z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj, d), ", p = ", pmd(z$p_valor_aj), " (sem ajuste: ", cmd(z$estimativa, z$ic90_inf, z$ic90_sup, d),
         ", p = ", pmd(z$p_valor), "), n = ", z$n)
}
md_cp <- function(a, b, r, h, medida = "elasticidade", d = 3) {
  z <- cp(a, b, r, h, medida)
  paste0("h = ", h, ": ", cmd(z$est_a, z$lo_a, z$hi_a, d), " x ", cmd(z$est_b, z$lo_b, z$hi_b, d), "; p amostra pequena ", pmd(z$p_wald_pa),
         " (p sem ajuste ", pmd(z$p_wald), "); n = ", z$n, ", n - k = ", z$gl, "; F1 ", fmd(z$f1_a, 1), " / ", fmd(z$f1_b, 1))
}
rob_md <- function(pref, am, base) {
  id <- paste0(pref, "_", am); z <- vr(id); b <- vr(base)
  paste0(cmd(z$elasticidade, z$ic90_inf, z$ic90_sup), " (", fmd(100 * z$elasticidade / b$elasticidade, 0), "% do baseline; IC inclui zero: ",
         if (exclui0(z$ic90_inf, z$ic90_sup)) "nao" else "sim", ")")
}
t19 <- jo("2003-2019", "trend", "r = 0")
md <- c(
  "# A6: numeros para Halle (so numeros)",
  "",
  sprintf("Gerado por R/A6_saidas.R em %s. Virgula decimal. IC de 90%%. Projecoes locais: IC e p com Newey-West vezes n/(n - k) e t (ou F) com n - k graus de liberdade (colunas _aj e p_wald_pa dos CSV da A5); entre parenteses, a versao sem ajuste. VAR e VEC: IC por bootstrap.", format(Sys.time(), "%Y-%m-%d %H:%M")),
  "",
  "## 1. Amostras e n",
  bl("VAR replicado: niveis 2002T1-2019T4, n = ", rep$n, src(F_VAR, "id replicado")),
  bl("VAR corrigido: niveis 2003T1-2019T4, n = ", cc$n, src(F_VAR, "id corr_c")),
  bl("VAR estendido: niveis 2003T1-2025T4, n = ", ex$n, src(F_VAR, "id ext")),
  bl("Subamostras do VAR estendido: ate 2014T4 n = ", sub_a$n, "; de 2015T1 n = ", sub_b$n, src(F_VAR)),
  bl("Johansen: T efetivo ", paste(vapply(AMOSTRAS, function(a) paste0(a, " ", dec[[a]]$T), ""), collapse = "; "), src(F_JOH)),
  bl("LP: ", N_Q, " trimestres de 2003T1 a 2025T4; primeiro t = ", n_lp_h0$t_ini, "; n = ", n_lp_h0$n, " (h = 0), ", cu("inf_diss", "fbcf_me", 4)$n,
     " (h = 4), ", cu("inf_diss", "fbcf_me", 8)$n, " (h = 8), ", cu("inf_diss", "fbcf_me", 12)$n, " (h = 12); p = ", P_LP, src(F_IRF)),
  bl("LP das series de 2016+ (estatais_petro, estatais_sempetro, estatais_econ): primeiro t = ", n_lp_h0_curto$t_ini, "; n = ", n_lp_h0_curto$n,
     " (h = 0), ", cu("estatais_petro", "fbcf_me", 4)$n, " (h = 4), ", cu("estatais_petro", "fbcf_me", 8)$n, " (h = 8); p = ", P_LP_CURTO, "; h ate ", HMAX_CURTO, src(F_IRF)),
  bl("Uniao, somas nominais ", ANO_INI, "-", ANO_FIM, ": social via transferencias ", fmd(share_soc_transf, 1), "% (so grupo 1: ", fmd(share_soc_transf_g1, 1),
     "%); economica direta ", fmd(share_econ_dir, 1), "% (contra direta + grupo 1: ", fmd(share_econ_dir_g1, 1), "%)", src(F_INV)),
  bl("Petroleo nas estatais (OI, nominal, por ano, ", OI_INI, "-", OI_FIM, "): ", fmd(petro_min, 1), "% a ", fmd(petro_max, 1), "%", src(F_INV)),
  "",
  "## 2. Baseline replicado",
  md_var("replicado", paste0("VAR(", P_VAR, ") em diferenca, arquivos originais")),
  bl("Bootstrap: ", runs_rep, " replicas; replicas com elasticidade negativa ", fmd(100 * rep$prop_boot_elast_neg, 1), "%", src(F_VAR, "id replicado")),
  "",
  "## 3. Correcoes ao texto antigo",
  bl("Magnitude: texto diz que 1% gera cerca de 2%; elasticidade de longo prazo ", cmd(rep$elasticidade, rep$ic90_inf, rep$ic90_sup),
     "; acumulada de PVD ", fmd(rep$resp_acum_40_priv, 4), " para acumulada de INF ", fmd(rep$resp_acum_40_pub, 4), src(F_VAR, "id replicado")),
  bl("Granger (VAR em diferenca): INF -> PVD p = ", pmd(rep$granger_p_pub_priv), "; PVD -> INF p = ", pmd(rep$granger_p_priv_pub), src(F_VAR, "id replicado")),
  bl("Granger (Tabela 12, VAR em nivel): texto F = ", fmd(alv("t12_causa_PVD_F"), 2), ", gl ", alv("t12_causa_PVD_gl1"), " e ", alv("t12_causa_PVD_gl2"),
     ", p = ", fmd(alv("t12_causa_PVD_p"), 2), "; p implicado pelo F e gl do proprio texto = ", pmd(p_implicito_t12), src(F_ALV, "t12_causa_PVD_*")),
  bl("Johansen (Tabela 8): traco ", fmd(alv("t8_traco_r0"), 2), " contra valor critico de 5% ", fmd(alv("t8_cv5_r0"), 2), " (nao rejeita r = 0 a 5%); valor critico de 10% ",
     fmd(jo("2002-2019 original", "trend", "r = 0")$cv10, 2), src(F_ALV, "t8_*"), "; ", src(F_JOH)),
  bl("Dummy: DUM = 1 no arquivo em ", paste(dum_txt_md, collapse = " e "), " (", length(dum_q), " trimestres)", src(F_EXO)),
  bl("INF nominal: reconstrucao nominal (X-11 na soma, 2003T1-2019T4) correlacao das diferencas ", fmd(inf_nom$corr_dif, 4), ", desvio medio em nivel ", fmd(inf_nom$desvio_medio_nivel, 4),
     " log10; real (IPCA medio do trimestre, X-11 por componente) correlacao ", fmd(inf_real$corr_dif, 4), ", desvio medio em nivel ", fmd(inf_real$desvio_medio_nivel, 3), " log10", src(F_VARI)),
  "",
  "## 4. Baseline corrigido (uma correcao por vez, 2003-2019)",
  md_var("corr_a0", "(a0) arquivos originais, niveis desde 2003T1"),
  md_var("corr_a", "(a) INF nominal reconstruido"),
  md_var("corr_b", "(b) INF real"),
  md_var("corr_c0", "(c0) + PVD atual"),
  md_var("corr_c", "(c) + PIB e Selic atuais (baseline corrigido)"),
  md_var("ext", "Estendido 2003-2025"),
  "",
  paste0("## 5. Decisao VAR x VEC (Johansen, traco, K = ", K_JOH, "; ecdet trend decide, const confere)"),
  unlist(lapply(AMOSTRAS, function(a) {
    t0 <- jo(a, "trend", "r = 0"); c0 <- jo(a, "const", "r = 0"); zv <- vr(ID_VEC[[a]]); zz <- vr(ID_VAR[[a]])
    c(bl(a, ": traco ", fmd(t0$traco), "; Reinsel-Ahn ", fmd(t0$traco_ra), "; valor critico de 5% ", fmd(t0$cv5), "; p bootstrap ", pmd(t0$p_boot),
         "; rejeita a 5%: assintotico ", if (dec[[a]]$ass) "sim" else "nao", ", Reinsel-Ahn ", if (dec[[a]]$ra) "sim" else "nao", ", bootstrap ",
         if (dec[[a]]$bo) "sim" else "nao", "; ecdet const: traco ", fmd(c0$traco), ", p bootstrap ", pmd(c0$p_boot), src(F_JOH)),
      bl(a, ": classificacao limitrofe (", dec[[a]]$motivo, "); regra = bootstrap a 5%; escolha: ", dec[[a]]$escolha),
      bl(a, ": VAR em diferenca ", cmd(zz$elasticidade, zz$ic90_inf, zz$ic90_sup), " (n = ", zz$n, ") x VEC ", cmd(zv$elasticidade_beta, zv$elast_beta_ic90_inf, zv$elast_beta_ic90_sup),
         " (n = ", zv$n, "); VAR em nivel ", cmd(vr(ID_NIV[[a]])$elasticidade, vr(ID_NIV[[a]])$ic90_inf, vr(ID_NIV[[a]])$ic90_sup), src(F_VAR)))
  })),
  "",
  "## 6. Sensibilidade do baseline (variantes que perdem significancia em linha propria)",
  bl("2003-2019, baseline ", cmd(cc$elasticidade, cc$ic90_inf, cc$ic90_sup), src(F_VAR, "id corr_c")),
  bl("2003-2019, Cholesky invertida: ", rob_md("chol_inv", "2003-2019", "corr_c"), src(F_VAR)),
  bl("2003-2019, p = 2: ", rob_md("p2", "2003-2019", "corr_c"), src(F_VAR)),
  bl("2003-2019, PIB em taxa de crescimento: ", rob_md("pib_taxa", "2003-2019", "corr_c"), src(F_VAR)),
  bl("2003-2019, p = 4: ", rob_md("p4", "2003-2019", "corr_c"), src(F_VAR)),
  bl("2003-2025, baseline ", cmd(ex$elasticidade, ex$ic90_inf, ex$ic90_sup), src(F_VAR, "id ext")),
  bl("2003-2025, Cholesky invertida: ", rob_md("chol_inv", "2003-2025", "ext"), src(F_VAR)),
  bl("2003-2025, p = 2: ", rob_md("p2", "2003-2025", "ext"), src(F_VAR)),
  bl("2003-2025, PIB em taxa de crescimento: ", rob_md("pib_taxa", "2003-2025", "ext"), src(F_VAR)),
  bl("2003-2025, p = 4: ", rob_md("p4", "2003-2025", "ext"), src(F_VAR)),
  bl("2003-2025, com imp2017: ", rob_md("com_imp2017", "2003-2025", "ext"), src(F_VAR)),
  bl("2003-2025, INF sem AO: ", rob_md("inf_diss_semao", "2003-2025", "ext"), src(F_VAR)),
  bl("2003-2025, dummies_A4: ", rob_md("dummies_A4", "2003-2025", "ext"), src(F_VAR)),
  bl("Subamostra ate 2014T4: ", cmd(sub_a$elasticidade, sub_a$ic90_inf, sub_a$ic90_sup), "; de 2015T1: ", cmd(sub_b$elasticidade, sub_b$ic90_inf, sub_b$ic90_sup), src(F_VAR)),
  bl("Demais variantes 2003-2019: ", dm19$k, " especificacoes, ", fmd(dm19$min), " a ", fmd(dm19$max), " (mediana ", fmd(dm19$med), "), IC acima de zero em ", dm19$pos, " de ", dm19$k, src(F_VAR)),
  bl("Demais variantes 2003-2025: ", dm25$k, " especificacoes, ", fmd(dm25$min), " a ", fmd(dm25$max), " (mediana ", fmd(dm25$med), "), IC acima de zero em ", dm25$pos, " de ", dm25$k,
     "; Granger a 5% em ", dm25$gr, " de ", dm25$k, src(F_VAR)),
  "",
  "## 7. Principais elasticidades e multiplicadores (LP, baseline)",
  bl("inf_diss -> fbcf_me, elasticidade acumulada h = 4: ", md_cu("inf_diss", "fbcf_me", 4), src(F_CUM)),
  bl("inf_diss -> fbcf_me, h = 12: ", md_cu("inf_diss", "fbcf_me", 12), src(F_CUM)),
  bl("uniao_gnd4_dir -> fbcf_me, h = 12: ", md_cu("uniao_gnd4_dir", "fbcf_me", 12), src(F_CUM)),
  bl("estatais_total -> fbcf_me, h = 12: ", md_cu("estatais_total", "fbcf_me", 12), src(F_CUM)),
  bl("Multiplicador FBCF em R$, inf_diss, h = 8: ", md_cu("inf_diss", "fbcf_real_rs_bi", 8, "multiplicador", 2), "; h = 12: ", md_cu("inf_diss", "fbcf_real_rs_bi", 12, "multiplicador", 2), src(F_CUM)),
  bl("Multiplicador FBCF em R$, estatais_total, h = 12: ", md_cu("estatais_total", "fbcf_real_rs_bi", 12, "multiplicador", 2), src(F_CUM)),
  bl("Multiplicador FBCF em R$, uniao_gnd4_dir, h = 8: ", md_cu("uniao_gnd4_dir", "fbcf_real_rs_bi", 8, "multiplicador", 2), "; h = 12: ", md_cu("uniao_gnd4_dir", "fbcf_real_rs_bi", 12, "multiplicador", 2), src(F_CUM)),
  bl("G/FBCF medio (%): ", paste(sprintf("%s %s", CHOQ, fmd(GY, 2)), collapse = "; "), src(F_NIV, F_A2)),
  bl("Rubricas, M_12 separado x conjunto: uniao_soc_dir ", md_cu("uniao_soc_dir", "fbcf_real_rs_bi", 12, "multiplicador", 2), " x conjunta com uniao_econ_dir ",
     cmd(zj$est_b, zj$lo_b, zj$hi_b), ", p = ", pmd(2 * pt(-abs(zj$est_b / zj$ep_b_aj), zj$gl)), src(F_CUM, F_CMP)),
  bl("Testes multiplos: elasticidades acumuladas do baseline com IC que exclui zero: ", n_el_excl_aj, " de ", n_el, " com ajuste (", n_el_excl, " sem ajuste)", src(F_CUM)),
  "",
  "## 8. Comparacoes (regressao conjunta; elasticidade da FBCF em volume, fbcf_cnt_vol; a x b)",
  unlist(lapply(PARES, function(pp) {
    hs <- sort(unique(CMP$h[CMP$choque_a == pp[1] & CMP$choque_b == pp[2]]))
    c(bl(pp[1], " x ", pp[2], ", FBCF em volume: ", paste(vapply(hs, function(h) md_cp(pp[1], pp[2], "fbcf_cnt_vol", h), ""), collapse = " | "), src(F_CMP)),
      bl(pp[1], " x ", pp[2], ", fbcf_me: ", paste(vapply(hs, function(h) md_cp(pp[1], pp[2], "fbcf_me", h), ""), collapse = " | "), src(F_CMP)),
      bl(pp[1], " x ", pp[2], ", M_h FBCF em R$: ", paste(vapply(hs, function(h) md_cp(pp[1], pp[2], "fbcf_real_rs_bi", h, "multiplicador", 2), ""), collapse = " | "), src(F_CMP)))
  })),
  "",
  "## 9. Quebras que importam",
  bl("VAR estendido: supF da equacao de inf_diss ", fmd(qi$supF, 2), ", p = ", pmd(qi$supF_p), ", maximo em ", qi$supF_data, "; equacao de fbcf_me ", fmd(qf$supF, 2),
     ", p = ", pmd(qf$supF_p), ", maximo em ", qf$supF_data, "; Chow rejeita a 5% em ", qi$chow_rejeita5, " (inf_diss) e ", qf$chow_rejeita5, " (fbcf_me)", src(F_Q4)),
  bl("VAR da dissertacao: supF equacao de INF ", fmd(qo$supF, 2), ", p = ", pmd(qo$supF_p), ", maximo em ", qo$supF_data, "; equacao de PVD p = ", pmd(qop$supF_p), src(F_Q4)),
  bl("Elasticidade do VAR: 2003-2019 ", fmd(cc$elasticidade), "; 2003-2025 ", fmd(ex$elasticidade), "; ate 2014T4 ", fmd(sub_a$elasticidade), "; de 2015T1 ", fmd(sub_b$elasticidade),
     "; com os outliers do X-11 de 2018-2021 ", fmd(zd$elasticidade), src(F_VAR)),
  "",
  "## 10. Robustez das LP em uma linha por item (h = 12; elasticidade de fbcf_me, IC ajustado)",
  unlist(lapply(setdiff(ESP_LP, c("baseline", "G_deflator_fbcf")), function(e) {
    v <- vapply(c(ROB_AGR, ROB_UNI), function(s) { z <- cu(s, "fbcf_me", 12, "elasticidade", e); if (is.null(z)) NA_character_ else
      paste0(s, " ", cmd(z$estimativa, z$ic90_inf_aj, z$ic90_sup_aj), if (exclui0(z$ic90_inf_aj, z$ic90_sup_aj)) "*" else "") }, "")
    bl(e, " (n = ", n_esp(e, c(ROB_AGR, ROB_UNI)[!is.na(v)]), "): ", paste(v[!is.na(v)], collapse = "; "), src(F_CUM))
  })),
  bl("* = IC ajustado exclui zero. Multiplicador M_12 de inf_diss (min / max entre as especificacoes): ",
     fmd(min(CUM$estimativa[CUM$choque == "inf_diss" & CUM$medida == "multiplicador" & CUM$resposta == "fbcf_real_rs_bi" & CUM$h == 12 & CUM$modelo == "diferenca"])), " / ",
     fmd(max(CUM$estimativa[CUM$choque == "inf_diss" & CUM$medida == "multiplicador" & CUM$resposta == "fbcf_real_rs_bi" & CUM$h == 12 & CUM$modelo == "diferenca"])), src(F_CUM)),
  "",
  "## Arquivos",
  "- results/A_robustez.tex, results/A_lp.tex, results/A_numeros_macros.tex, results/figuras/A6_fig1_econ_social.pdf, results/figuras/A6_fig2_direta_transf_estatais.pdf, results/A_quebras.tex (A4, sem alteracao)."
)
md <- gsub("p = < ", "p < ", md, fixed = TRUE)
md <- gsub(";  (", "; (", md, fixed = TRUE)
stopifnot(!any(grepl("\u2014", md, fixed = TRUE)), !any(grepl("\u2013", md, fixed = TRUE)))
write_lines_safe(md, file.path(PATHS$results, "A_numeros_halle.md"))

# ------------------------------------------------------------------------------------------------
# 10. Registro
# ------------------------------------------------------------------------------------------------
log_part(ETAPA, "- Entradas: ", paste(c(F_VAR, F_JOH, F_CUM, F_CMP, F_IRF, F_INV, F_NIV, F_A2, F_ALV, F_Q4, F_VARI, F_EXO), collapse = ", "),
         ". Sem download; nenhum numero digitado a mao nas saidas (tudo lido desses arquivos).")
log_part(ETAPA, "- Erros-padrao das projecoes locais: nas saidas de Halle uso a versao com ajuste de graus de liberdade (Newey-West vezes n/(n - k), t com n - k graus; colunas ep_aj, ic90_*_aj e p_valor_aj de A5_lp_cumulativo.csv e p_wald_pa de A5_lp_comparacoes.csv), mais conservadora; a versao sem ajuste vai entre parenteses no A_numeros_halle.md. Os IC individuais da regressao conjunta usam o mesmo ajuste (EP vezes raiz de n/gl, t com gl graus); conferido que o p recalculado assim reproduz p_wald_pa (diferenca maxima < 1e-8).")
log_part(ETAPA, sprintf("- Decisao VAR x VEC: evidencia limitrofe nas tres amostras (%s). Pela regra fixada (bootstrap a 5%%), baseline = VAR em diferenca, com o VEC ao lado em A_robustez.tex e no resumo.",
         paste(vapply(AMOSTRAS, function(a) paste0(a, ": ", dec[[a]]$motivo), ""), collapse = "; ")))
log_part(ETAPA, sprintf("- Sensibilidade do baseline corrigido (2003-2019) em linha propria: Cholesky invertida %s; p = 2 %s; PIB em taxa %s.",
         rob_md("chol_inv", "2003-2019", "corr_c"), rob_md("p2", "2003-2019", "corr_c"), rob_md("pib_taxa", "2003-2019", "corr_c")))
log_part(ETAPA, sprintf("- Multiplicadores em R$ so para os agregados (inf_diss, estatais_total, uniao_gnd4_dir, uniao_filtro_diss); nas rubricas, G/FBCF medio de %s%% (%s) a %s%% (%s), e os M_h separados ficam num painel com a ressalva. Comparacoes lidas em elasticidade da regressao conjunta.",
         fmd(min(GY[RUBR]), 2), names(which.min(GY[RUBR])), fmd(max(GY[RUBR]), 2), names(which.max(GY[RUBR]))))
log_part(ETAPA, sprintf("- Estatais sem petroleo x petroleo: n = %s, n - k = %s; p com ajuste de amostra pequena %s (FBCF em volume) e %s (M&E); baixo poder.",
         paste(CMP$n[CMP$choque_a == "estatais_sempetro" & CMP$resposta == "fbcf_cnt_vol"], collapse = " e "),
         paste(CMP$gl[CMP$choque_a == "estatais_sempetro" & CMP$resposta == "fbcf_cnt_vol"], collapse = " e "),
         paste(pmd(CMP$p_wald_pa[CMP$choque_a == "estatais_sempetro" & CMP$resposta == "fbcf_cnt_vol"]), collapse = " e "),
         paste(pmd(CMP$p_wald_pa[CMP$choque_a == "estatais_sempetro" & CMP$resposta == "fbcf_me"]), collapse = " e ")))
log_part(ETAPA, sprintf("- Conferencias no script: p_wald_pa recalculado; IC ajustado recalculado; razao FBCF/G igual a da A5 (inf_diss 14, uniao_soc_dir 290, estatais_sempetro 165); parcelas da Uniao de %d a %d: social via transferencias %s%%, economica direta %s%%; petroleo nas estatais %s%% a %s%%.",
         ANO_INI, ANO_FIM, fmd(share_soc_transf, 1), fmd(share_econ_dir, 1), fmd(petro_min, 1), fmd(petro_max, 1)))
log_part(ETAPA, sprintf("- Macros: %d em results/A_numeros_macros.tex (formato ingles). Figuras: results/figuras/A6_fig1_econ_social e A6_fig2_direta_transf_estatais (pdf e png), elasticidade conjunta da FBCF em volume com IC de 90%% ajustado.", length(MAC)))
log_part(ETAPA, sprintf("- Saidas: results/A_robustez.tex, results/A_lp.tex, results/A_numeros_halle.md, results/A_numeros_macros.tex, figuras. Tempo: %s s.",
         fmd(as.numeric(difftime(Sys.time(), t_ini, units = "secs")), 0)))
save_session_info("A6_saidas")
cat("A6 concluida:", length(MAC), "macros\n")
