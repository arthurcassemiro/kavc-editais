# Etapa A3: series trimestrais de investimento publico por esfera e tipo, 2003T1-2025T4.
# Entradas: data/raw (federal filtrado, dashboard federal trimestral, SEST boletim e OI),
#   data/downloads/2026-09-28_painel_fed_B_funcao_elemento_modalidade_anual.csv (anual, com 2017),
#   data/processed/A2_deflator_ipca.csv e data/original/0224_tri_estmeq.txt (INF da dissertacao).
# Saidas: data/processed/A3_*.csv, results/A3_*, results/figuras/A3_*.
# Rodar da raiz do projeto: Rscript R/A3_investimento_publico.R

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(patchwork)
})
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

ETAPA <- "A3"
log_reset(ETAPA)
L <- function(...) log_part(ETAPA, "- ", ...)
L2 <- function(...) log_part(ETAPA, "  - ", ...)
fmt <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",", big.mark = "")
pct <- function(x, d = 1) paste0(fmt(100 * x, d), "%")
t_ini <- Sys.time()

Q_INI <- "2003Q1"
Q_FIM <- "2025Q4"
QS <- q_seq(Q_INI, Q_FIM)
ano_q <- function(q) as.integer(substr(q, 1, 4))
tri_q <- function(q) as.integer(substr(q, 6, 6))

SEG_PETRO <- "Oil, gas & derivatives"
SEG_ECON <- c("Electricity", "Transport", "Port administration", "Airport administration")
SEG_OUTRAS <- c("Financial", "Commerce & services", "Industry", "Research, development & planning", "Food supply")
MOD_DIRETA <- c("90", "91")
MOD_OUTRA <- c("67", "99")
MOD_ESTMUN <- c("30", "31", "32", "40", "41", "42", "71", "72")
MOD_PRIVADA <- c("50", "60")
MOD_EXTERIOR <- c("80")

# Nomes das funcoes (Portaria MOG 42/1999), sem acento. 00 e 99 aparecem no dashboard.
FUNCOES_NOMES <- c(
  "00" = "SEM FUNCAO INFORMADA", "01" = "LEGISLATIVA", "02" = "JUDICIARIA", "03" = "ESSENCIAL A JUSTICA",
  "04" = "ADMINISTRACAO", "05" = "DEFESA NACIONAL", "06" = "SEGURANCA PUBLICA", "07" = "RELACOES EXTERIORES",
  "08" = "ASSISTENCIA SOCIAL", "09" = "PREVIDENCIA SOCIAL", "10" = "SAUDE", "11" = "TRABALHO", "12" = "EDUCACAO",
  "13" = "CULTURA", "14" = "DIREITOS DA CIDADANIA", "15" = "URBANISMO", "16" = "HABITACAO", "17" = "SANEAMENTO",
  "18" = "GESTAO AMBIENTAL", "19" = "CIENCIA E TECNOLOGIA", "20" = "AGRICULTURA", "21" = "ORGANIZACAO AGRARIA",
  "22" = "INDUSTRIA", "23" = "COMERCIO E SERVICOS", "24" = "COMUNICACOES", "25" = "ENERGIA", "26" = "TRANSPORTE",
  "27" = "DESPORTO E LAZER", "28" = "ENCARGOS ESPECIAIS", "99" = "RESERVA DE CONTINGENCIA")
tipo_funcao <- function(f) {
  case_when(f %in% names(FUNCOES_ECONOMICA) ~ "economica",
            f %in% names(FUNCOES_SOCIAL) ~ "social",
            TRUE ~ "outras")
}

L("Entradas locais, sem download nesta etapa: data/raw/federal_inv_direto_trimestral_nominal.csv, ",
  "data/raw/dashboard_fed_q_bruto.csv, data/downloads/2026-09-28_painel_fed_B_funcao_elemento_modalidade_anual.csv, ",
  "data/raw/sest_boletim_trimestral_2003_2019.csv, data/raw/sest_oi_trimestral_2016_2025.csv, ",
  "data/processed/A2_deflator_ipca.csv e data/original/0224_tri_estmeq.txt. Janela das series: ", Q_INI, " a ", Q_FIM, ".")

# ---------------------------------------------------------------------------
# 1. Deflator
# ---------------------------------------------------------------------------
defl <- read_csv("data/processed/A2_deflator_ipca.csv", show_col_types = FALSE)
defl_m <- defl %>%
  filter(frequencia == "mensal") %>%
  mutate(ano = as.integer(substr(periodo, 1, 4)), mes = as.integer(substr(periodo, 6, 7)),
         q = q_key(ano, ceiling(mes / 3)))
defl_q <- defl %>% filter(frequencia == "trimestral") %>% transmute(q = periodo, fator_media = fator_para_2025)
chk_q <- defl_m %>%
  group_by(q) %>%
  summarise(fator_calc = 100 / mean(indice), fator_harm = mean(100 / indice),
            fator_fim = 100 / indice[mes %% 3 == 0], .groups = "drop") %>%
  left_join(defl_q, by = "q")
defl_ano <- defl_m %>% group_by(ano) %>% summarise(fator_anual = 100 / mean(indice), .groups = "drop")
DEFL <- chk_q %>%
  mutate(ano = ano_q(q)) %>%
  left_join(defl_ano, by = "ano") %>%
  transmute(q, media_tri = fator_media, fim_tri = fator_fim, anual = fator_anual, nominal = 1,
            harm = fator_harm)
stopifnot(all(QS %in% DEFL$q))
dif_harm <- with(filter(DEFL, q %in% QS), harm / media_tri - 1)
L("Deflator: fator trimestral de data/processed/A2_deflator_ipca.csv (100 / media dos tres indices mensais do IPCA no ",
  "trimestre, media de 2025 = 100); real = nominal x fator, em R$ de 2025. Conferido: o fator do arquivo e igual a ",
  "100 / media dos indices mensais (diferenca maxima ", format(max(abs(chk_q$fator_calc - chk_q$fator_media), na.rm = TRUE), digits = 2), ").")
L("Nao ha bruto mensal no conteiner (so series trimestrais nominais), entao o IPCA mensal nao pode ser aplicado antes de ",
  "agregar, como pede o briefing. Deflacionar o trimestre pelo indice medio equivale a deflacionar mes a mes sob gasto ",
  "uniforme dentro do trimestre, a menos de um termo de segunda ordem: com gasto uniforme, o fator exato seria a media dos ",
  "fatores mensais (media harmonica dos indices), e a diferenca para o fator usado e de no maximo ",
  fmt(100 * max(abs(dif_harm)), 4), "% em ", Q_INI, "-", Q_FIM, " (media ", fmt(100 * mean(dif_harm), 4), "%). ",
  "O autor pode refazer com o bruto mensal (federal_gnd4_mensal.csv) quando ele estiver disponivel.")

# ---------------------------------------------------------------------------
# 2. Federal: filtro da dissertacao, dashboard trimestral e base anual
# ---------------------------------------------------------------------------
fil_raw <- read_csv("data/raw/federal_inv_direto_trimestral_nominal.csv", show_col_types = FALSE) %>%
  transmute(q = q_key(ano, trimestre), ano = as.integer(ano), tri = as.integer(trimestre), nom = valor_nominal / 1e9)

dash <- read_csv("data/raw/dashboard_fed_q_bruto.csv", col_types = cols(.default = "c"))
names(dash) <- c("ano", "tri", "funcao", "grupo", "nom", "real_dash")
dash <- dash %>%
  mutate(ano = as.integer(ano), tri = as.integer(tri), grupo = as.integer(grupo),
         nom = as.numeric(nom), real_dash = as.numeric(real_dash), q = q_key(ano, tri),
         tipo = tipo_funcao(funcao))
stopifnot(all(nchar(dash$funcao) == 2))

pan <- read_csv("data/downloads/2026-09-28_painel_fed_B_funcao_elemento_modalidade_anual.csv",
                col_types = cols(.default = "c")) %>%
  mutate(ano = as.integer(ano), v = as.numeric(valor_nominal_rs_mi) / 1e3,
         funcao_cod = coalesce(funcao_cod, "00"),
         grupo_mod = case_when(modalidade %in% MOD_DIRETA ~ "direta",
                               modalidade %in% MOD_OUTRA ~ "outra",
                               TRUE ~ "transferencia"),
         tipo = tipo_funcao(funcao_cod))

anos_fil <- sort(unique(fil_raw$ano))
L("Serie federal filtrada (modalidade 90 e os 6 elementos da dissertacao): ", nrow(fil_raw), " trimestres, ",
  min(fil_raw$q), " a ", max(fil_raw$q), "; faltam os 4 trimestres de 2017: ",
  if (!any(fil_raw$ano == 2017)) "confirmado" else "NAO confirmado", ".")

# Conferencia anual: base anual (modalidade 90, 6 elementos) contra a soma da serie trimestral
fil_ano_pan <- pan %>%
  filter(modalidade == "90", elemento %in% ELEMENTOS_DISSERTACAO) %>%
  group_by(ano) %>% summarise(pan = sum(v), .groups = "drop")
conf_ano <- fil_raw %>% group_by(ano) %>% summarise(tri = sum(nom), n = n(), .groups = "drop") %>%
  inner_join(fil_ano_pan, by = "ano") %>% filter(n == 4)
TOT_2017 <- fil_ano_pan$pan[fil_ano_pan$ano == 2017]
L("Base anual do painel, modalidade 90 e os 6 elementos: razao contra a soma anual da serie trimestral entre ",
  fmt(min(conf_ano$pan / conf_ano$tri), 4), " e ", fmt(max(conf_ano$pan / conf_ano$tri), 4), " (", nrow(conf_ano),
  " anos completos). Total de 2017: R$ ", fmt(TOT_2017, 3), " bi nominais.")

g0_q <- dash %>% filter(grupo == 0) %>% group_by(q, ano, tri) %>% summarise(g0 = sum(nom), .groups = "drop")
dir_ano_pan <- pan %>% filter(grupo_mod == "direta") %>% group_by(ano) %>% summarise(pan = sum(v), .groups = "drop")
conf_g0 <- g0_q %>% group_by(ano) %>% summarise(g0 = sum(g0), n = n(), .groups = "drop") %>%
  inner_join(dir_ano_pan, by = "ano") %>% filter(n == 4)
L("Execucao direta (modalidades 90 e 91) da base anual contra o grupo 0 do dashboard trimestral somado no ano: razao entre ",
  fmt(min(conf_g0$pan / conf_g0$g0), 4), " e ", fmt(max(conf_g0$pan / conf_g0$g0), 4), " (", nrow(conf_g0), " anos).")

# ---------------------------------------------------------------------------
# 3. 2017 do filtro da dissertacao
# ---------------------------------------------------------------------------
razao_q <- g0_q %>% filter(ano %in% c(2016, 2018)) %>%
  left_join(fil_raw %>% select(q, fil = nom), by = "q") %>% mutate(r = fil / g0)
g0_2017 <- g0_q %>% filter(ano == 2017) %>% arrange(tri)
L("2017 do filtro da dissertacao: total anual exato da base anual (R$ ", fmt(TOT_2017, 3), " bi); so a distribuicao ",
  "trimestral e imputada. Grupo 0 do dashboard em 2017 (R$ bi nominais): ",
  paste0("T", g0_2017$tri, " ", fmt(g0_2017$g0, 3), collapse = "; "), "; soma ", fmt(sum(g0_2017$g0), 3), ".")
L("Razao filtro/dashboard (grupo 0) por trimestre:")
for (a in c(2016, 2018)) {
  rr <- razao_q %>% filter(ano == a) %>% arrange(tri)
  L2(a, ": ", paste0("T", rr$tri, " ", fmt(rr$r, 3), collapse = "; "), "; anual ", fmt(sum(rr$fil) / sum(rr$g0), 3), ".")
}
L2("2017: so anual, ", fmt(TOT_2017 / sum(g0_2017$g0), 3), " (R$ ", fmt(TOT_2017, 3), " bi / R$ ", fmt(sum(g0_2017$g0), 3), " bi).")

# Baseline: perfil trimestral do grupo 0 em 2017
imp_base <- g0_2017 %>% mutate(nom = TOT_2017 * g0 / sum(g0))
# Robustez: razao especifica do trimestre (media de 2016 e 2018) x grupo 0 de 2017, reescalada ao total anual
r_media <- razao_q %>% group_by(tri) %>% summarise(r = mean(r), .groups = "drop")
imp_raz <- g0_2017 %>% left_join(r_media, by = "tri") %>% mutate(bruto = r * g0, nom = bruto * TOT_2017 / sum(bruto))
L("Imputacao baseline: T_q = total anual x participacao do trimestre no grupo 0 de 2017. Resultado (R$ bi nominais): ",
  paste0("T", imp_base$tri, " ", fmt(imp_base$nom, 3), collapse = "; "), ".")
L("Imputacao de robustez: razao filtro/dashboard do trimestre, media de 2016 e 2018 (",
  paste0("T", r_media$tri, " ", fmt(r_media$r, 3), collapse = "; "), "), aplicada ao grupo 0 de 2017 e reescalada ao total ",
  "anual (fator de reescala ", fmt(TOT_2017 / sum(imp_raz$bruto), 4), "). Resultado: ",
  paste0("T", imp_raz$tri, " ", fmt(imp_raz$nom, 3), collapse = "; "), ".")

fil_base <- bind_rows(fil_raw %>% select(q, nom), imp_base %>% select(q, nom)) %>% arrange(q)
fil_raz <- bind_rows(fil_raw %>% select(q, nom), imp_raz %>% select(q, nom)) %>% arrange(q)
stopifnot(all(QS %in% fil_base$q))

# ---------------------------------------------------------------------------
# 4. Estatais: boletim (Brasil), OI por segmento e encadeamento
# ---------------------------------------------------------------------------
bol <- read_csv("data/raw/sest_boletim_trimestral_2003_2019.csv", show_col_types = FALSE) %>%
  filter(regiao == "Brazil (total)") %>%
  transmute(q = q_key(ano, trimestre), nom = valor_nominal_bi, real_dash = valor_real_bi_2025)
stopifnot(nrow(bol) == 68, identical(bol$q, q_seq("2003Q1", "2019Q4")))
oi <- read_csv("data/raw/sest_oi_trimestral_2016_2025.csv", show_col_types = FALSE) %>%
  mutate(q = q_key(ano, trimestre), grupo_petrobras = as.logical(grupo_petrobras),
         classe = case_when(segmento == SEG_PETRO ~ "petroleo",
                            segmento %in% SEG_ECON ~ "economica",
                            segmento %in% SEG_OUTRAS ~ "outras",
                            TRUE ~ NA_character_))
if (any(is.na(oi$classe))) stop("Segmento da SEST sem classificacao: ", paste(unique(oi$segmento[is.na(oi$classe)]), collapse = ", "))
oi_tot <- oi %>% group_by(q) %>% summarise(oi = sum(valor_nominal_bi), .groups = "drop")
stopifnot(identical(oi_tot$q, q_seq("2016Q1", "2025Q4")))

sobre <- bol %>% select(q, bol = nom) %>% inner_join(oi_tot, by = "q") %>% mutate(ano = ano_q(q), r = bol / oi)
R_BASE <- mean(sobre$r)
R_SOMA <- sum(sobre$bol) / sum(sobre$oi)
sobre_ano <- sobre %>% group_by(ano) %>%
  summarise(r_media = mean(r), r_soma = sum(bol) / sum(oi), r_min = min(r), r_max = max(r), .groups = "drop")
L("Estatais: boletim da SEST, regiao == \"Brazil (total)\", 2003T1-2019T4 (68 trimestres); OI por segmento 2016T1-2025T4. ",
  "Sobreposicao 2016T1-2019T4, razao boletim/OI:")
for (i in seq_len(nrow(sobre_ano))) {
  s <- sobre_ano[i, ]
  L2(s$ano, ": media das razoes trimestrais ", fmt(s$r_media, 3), "; razao das somas ", fmt(s$r_soma, 3),
     "; minimo ", fmt(s$r_min, 3), ", maximo ", fmt(s$r_max, 3), " (OI ", pct(1 / s$r_soma - 1), " em relacao ao boletim).")
}
L2("2016T1-2019T4: media das razoes trimestrais ", fmt(R_BASE, 4), " (usada no baseline); razao das somas ", fmt(R_SOMA, 4), ".")
L("Leitura: o OI fica acima do boletim em 2016-2018 (razao entre ", fmt(min(sobre_ano$r_soma[sobre_ano$ano <= 2018]), 3), " e ",
  fmt(max(sobre_ano$r_soma[sobre_ano$ano <= 2018]), 3), "), mas abaixo em 2019 (", fmt(sobre_ano$r_soma[sobre_ano$ano == 2019], 3),
  "), sobretudo em 2019T4 (", fmt(sobre$r[sobre$q == "2019Q4"], 3), "). O LOG anterior (OI 10% a 15% acima) vale so ate 2018.")

encadeia <- function(ano_emenda, r) {
  q_em <- q_key(ano_emenda, 1)
  bind_rows(bol %>% filter(q < q_em) %>% select(q, nom),
            oi_tot %>% filter(q >= q_em) %>% transmute(q, nom = oi * r)) %>% arrange(q)
}
est_base <- encadeia(2020, R_BASE)
EMENDAS <- tibble(ano = c(2017, 2018, 2019, 2020)) %>%
  rowwise() %>% mutate(r = sobre_ano$r_media[sobre_ano$ano == ano - 1]) %>% ungroup()
est_var <- setNames(lapply(seq_len(nrow(EMENDAS)), function(i) encadeia(EMENDAS$ano[i], EMENDAS$r[i])),
                    paste0("estatais_total_e", EMENDAS$ano))
L("Encadeamento baseline: boletim ate 2019T4 e OI x ", fmt(R_BASE, 4), " a partir de 2020T1. Indicadora emenda_sest = 1 a ",
  "partir de 2020T1 (degrau). Sensibilidade: emenda em 2017T1, 2018T1, 2019T1 e 2020T1 com a razao media so do ano anterior (",
  paste0(EMENDAS$ano, "T1: ", fmt(EMENDAS$r, 4), collapse = "; "), "); indicadoras emenda_sest_AAAA com degrau na data de cada emenda.")

# ---------------------------------------------------------------------------
# 5. Ajuste sazonal (X-11) e indices
# ---------------------------------------------------------------------------
SA_INFO <- list()
roda_x11 <- function(x, nome = NULL) {
  aditivo <- any(x <= 0)
  y <- NULL
  k <- 0
  while (is.null(y) && k < 3) {
    k <- k + 1
    y <- tryCatch({
      if (aditivo) {
        switch(k, x11_sa(x, transform.function = "none"),
               x11_sa(x, transform.function = "none", outlier = NULL),
               x11_sa(x, transform.function = "none", regression.aictest = NULL, outlier = NULL))
      } else {
        switch(k, x11_sa(x), x11_sa(x, outlier = NULL), x11_sa(x, regression.aictest = NULL, outlier = NULL))
      }
    }, error = function(e) NULL)
  }
  if (is.null(y)) stop("X-11 falhou em ", nome)
  if (!is.null(nome)) {
    m <- attr(y, "seas_model")
    u <- function(k) tryCatch(as.character(seasonal::udg(m, k)), error = function(e) NA_character_)
    SA_INFO[[nome]] <<- tibble(
      serie = nome, inicio = format(zoo::as.yearqtr(time(x)[1]), "%YQ%q"), n = length(x),
      transformacao = seasonal::transformfunction(m), arima = u("arimamdl"),
      outliers = paste(grep("^(AO|LS|TC)", names(coef(m)), value = TRUE), collapse = " "),
      m7 = u("f3.m07"), q_x11 = u("f3.q"), especificacao = c("padrao", "sem outliers", "sem outliers e sem td/pascoa")[k],
      aditivo = aditivo)
  }
  as.numeric(y)
}

# ---------------------------------------------------------------------------
# 6. Reconstrucao de INF e variantes
# ---------------------------------------------------------------------------
inf_txt <- readLines("data/original/0224_tri_estmeq.txt", warn = FALSE)
inf_txt <- trimws(gsub("\r", "", inf_txt))
inf_txt <- inf_txt[nzchar(inf_txt)][-1]
inf_orig <- tibble(q = q_seq("2002Q1", "2019Q4"),
                   INF = as.numeric(sapply(strsplit(inf_txt, "[[:space:]]+"), `[`, 1)))
stopifnot(nrow(inf_orig) == 72, !anyNA(inf_orig$INF))

Q_CMP <- q_seq("2003Q1", "2019Q4")
metricas <- function(rec_q, rec_v) {
  d <- tibble(q = rec_q, rec = rec_v) %>% inner_join(inf_orig, by = "q") %>% filter(q %in% Q_CMP) %>% arrange(q)
  lr <- log10(d$rec)
  dr <- diff(lr); di <- diff(d$INF)
  qd <- d$q[-1]
  # indices com base media 2003 = 100, em log10
  b <- d$q %in% q_seq("2003Q1", "2003Q4")
  ir <- log10(100 * d$rec / mean(d$rec[b]))
  ii <- log10(100 * 10^d$INF / mean(10^d$INF[b]))
  gap <- (ir - ii)[-1]
  i17 <- qd %in% q_seq("2017Q1", "2018Q1")
  tibble(corr_dif = cor(dr, di), dam_dif = mean(abs(dr - di)), desvio_medio_nivel = mean(gap),
         dam_nivel = mean(abs(gap)), max_nivel = max(abs(gap)), escala = 10^mean(lr - d$INF),
         dp_escala = sd(lr - d$INF), dam_dif_2017 = mean(abs(dr - di)[i17]))
}

componentes_inf <- function(defl_col, fil_tab, span_fim) {
  qq <- q_seq("2003Q1", span_fim)
  f <- DEFL[[defl_col]][match(qq, DEFL$q)]
  est <- if (span_fim > "2019Q4") est_base else bol %>% select(q, nom)
  list(q = qq,
       fed = fil_tab$nom[match(qq, fil_tab$q)] * f,
       est = est$nom[match(qq, est$q)] * f)
}
variantes <- expand_grid(deflator = c("media_tri", "fim_tri", "anual", "nominal"),
                         ajuste = c("soma", "componentes", "nenhum"),
                         span = c("2019Q4", "2025Q4"),
                         imputacao = c("base", "razao")) %>%
  filter(!(ajuste == "nenhum" & span == "2025Q4"))
res_var <- vector("list", nrow(variantes))
for (i in seq_len(nrow(variantes))) {
  v <- variantes[i, ]
  cp <- componentes_inf(v$deflator, if (v$imputacao == "base") fil_base else fil_raz, v$span)
  tsf <- function(x) ts_from_q(x, cp$q)
  rec <- switch(v$ajuste,
                soma = roda_x11(tsf(cp$fed + cp$est)),
                componentes = roda_x11(tsf(cp$fed)) + roda_x11(tsf(cp$est)),
                nenhum = cp$fed + cp$est)
  res_var[[i]] <- bind_cols(v, metricas(cp$q, rec))
}
res_var <- bind_rows(res_var) %>%
  mutate(span = paste0("2003T1-", sub("Q", "T", span))) %>%
  arrange(desc(corr_dif), dam_dif)
write_csv_safe(res_var, "results/A3_reconstrucao_INF_variantes.csv")
melhor <- res_var[1, ]
base_v <- res_var %>% filter(deflator == "media_tri", ajuste == "soma", span == "2003T1-2025T4", imputacao == "base")
L("Reconstrucao de INF: federal (filtro, com 2017 imputado) + SEST boletim (Brasil), real, X-11 (x11_sa: X-13ARIMA-SEATS ",
  "em modo X-11, com regARIMA, outliers e testes de dias uteis e Pascoa automaticos), indice e log10. Comparacao com INF de ",
  "data/original/0224_tri_estmeq.txt em 2003T2-2019T4 (67 diferencas). ", nrow(res_var), " variantes: deflator (IPCA medio do ",
  "trimestre, IPCA do ultimo mes, IPCA medio do ano, nominal), X-11 depois de somar ou antes (em cada componente) ou sem ",
  "ajuste, janela do X-11 (2003T1-2019T4 ou 2003T1-2025T4, esta com as estatais encadeadas) e imputacao de 2017. Tabela ",
  "completa em results/A3_reconstrucao_INF_variantes.csv.")
L("Serie entregue (inf_diss: IPCA medio do trimestre, X-11 depois de somar, janela 2003T1-2025T4, imputacao baseline): ",
  "correlacao das diferencas ", fmt(base_v$corr_dif, 4), "; desvio absoluto medio das diferencas ", fmt(base_v$dam_dif, 4),
  " (log10); desvio medio em nivel (indices base 2003 = 100, log10) ", fmt(base_v$desvio_medio_nivel, 4), ", absoluto medio ",
  fmt(base_v$dam_nivel, 4), ", maximo ", fmt(base_v$max_nivel, 4), ".")
L("Variante mais proxima (maior correlacao das diferencas): deflator ", melhor$deflator, ", ajuste ", melhor$ajuste, ", janela ",
  melhor$span, ", imputacao ", melhor$imputacao, ": correlacao ", fmt(melhor$corr_dif, 4), "; desvio absoluto medio das diferencas ",
  fmt(melhor$dam_dif, 4), "; desvio medio em nivel ", fmt(melhor$desvio_medio_nivel, 4), ".")
resumo_fator <- function(col, val) {
  res_var %>% filter(.data[[col]] == val) %>%
    summarise(c = mean(corr_dif), d = mean(dam_dif))
}
for (cc in list(c("deflator", "media_tri"), c("deflator", "fim_tri"), c("deflator", "anual"), c("deflator", "nominal"),
                c("ajuste", "soma"), c("ajuste", "componentes"), c("ajuste", "nenhum"),
                c("imputacao", "base"), c("imputacao", "razao"))) {
  r <- resumo_fator(cc[1], cc[2])
  L2(cc[1], " = ", cc[2], ": correlacao media ", fmt(r$c, 4), "; desvio absoluto medio das diferencas ", fmt(r$d, 4), ".")
}

# ---------------------------------------------------------------------------
# 7. Series de choque
# ---------------------------------------------------------------------------
serie_dash <- function(funcoes = NULL, grupos) {
  d <- dash %>% filter(grupo %in% grupos, q %in% QS)
  if (!is.null(funcoes)) d <- d %>% filter(funcao %in% funcoes)
  out <- d %>% group_by(q) %>% summarise(nom = sum(nom), .groups = "drop")
  tibble(q = QS) %>% left_join(out, by = "q") %>% mutate(nom = coalesce(nom, 0))
}
serie_oi <- function(filtro) {
  oi %>% filter({{ filtro }}) %>% group_by(q) %>% summarise(nom = sum(valor_nominal_bi), .groups = "drop") %>%
    right_join(tibble(q = q_seq("2016Q1", Q_FIM)), by = "q") %>% mutate(nom = coalesce(nom, 0)) %>% arrange(q)
}
soma_series <- function(a, b) inner_join(a, b, by = "q") %>% transmute(q, nom = nom.x + nom.y)
ECON <- names(FUNCOES_ECONOMICA)
SOC <- names(FUNCOES_SOCIAL)
DEF <- list(
  uniao_econ_dir = list(serie_dash(ECON, 0), "Uniao, funcoes economicas (24, 25, 26), aplicacao direta (grupo 0: modalidades 90 e 91), GND 4, todos os elementos", "dashboard"),
  uniao_econ_dt = list(serie_dash(ECON, 0:1), "Uniao, funcoes economicas, direta + transferencias (grupos 0 e 1)", "dashboard"),
  uniao_soc_dir = list(serie_dash(SOC, 0), "Uniao, funcoes sociais (08, 10, 12, 15, 16, 17, 27), aplicacao direta (grupo 0)", "dashboard"),
  uniao_soc_dt = list(serie_dash(SOC, 0:1), "Uniao, funcoes sociais, direta + transferencias (grupos 0 e 1)", "dashboard"),
  uniao_transf_econ = list(serie_dash(ECON, 1), "Uniao, funcoes economicas, transferencias (grupo 1)", "dashboard"),
  uniao_transf_soc = list(serie_dash(SOC, 1), "Uniao, funcoes sociais, transferencias (grupo 1)", "dashboard"),
  uniao_gnd4_dir = list(serie_dash(NULL, 0), "Uniao, todas as funcoes, aplicacao direta (grupo 0), GND 4", "dashboard"),
  uniao_filtro_diss = list(fil_base %>% filter(q %in% QS), "Uniao, filtro da dissertacao (modalidade 90, 6 elementos); 2017 imputado pelo perfil do grupo 0", "federal filtrado + base anual (2017)"),
  uniao_filtro_diss_imprazao = list(fil_raz %>% filter(q %in% QS), "Como uniao_filtro_diss, 2017 imputado pela razao filtro/dashboard do trimestre (media de 2016 e 2018)", "federal filtrado + base anual (2017)"),
  estatais_total = list(est_base, "Estatais federais: boletim SEST (Brasil) ate 2019T4; OI x razao media boletim/OI 2016-2019 a partir de 2020T1", "SEST boletim + OI"),
  estatais_petro = list(serie_oi(segmento == SEG_PETRO), "Estatais, segmento Oil, gas & derivatives (OI, sem encadeamento)", "SEST OI"),
  estatais_sempetro = list(serie_oi(segmento != SEG_PETRO), "Estatais, todos os segmentos exceto Oil, gas & derivatives (OI)", "SEST OI"),
  estatais_econ = list(serie_oi(segmento %in% SEG_ECON), "Estatais, segmentos Electricity, Transport, Port administration e Airport administration (OI)", "SEST OI"),
  estatais_outras = list(serie_oi(segmento %in% SEG_OUTRAS), "Estatais, segmentos Financial, Commerce & services, Industry, Research, development & planning e Food supply (OI)", "SEST OI"),
  estatais_grupopetro = list(serie_oi(grupo_petrobras), "Estatais do grupo Petrobras, todos os segmentos (OI, grupo_petrobras = True)", "SEST OI"),
  estatais_semgrupopetro = list(serie_oi(!grupo_petrobras), "Estatais fora do grupo Petrobras (OI, grupo_petrobras = False)", "SEST OI")
)
for (nm in names(est_var)) {
  a <- sub("estatais_total_e", "", nm)
  DEF[[nm]] <- list(est_var[[nm]], paste0("Como estatais_total, emenda em ", a, "T1 com a razao media boletim/OI de ", as.integer(a) - 1), "SEST boletim + OI")
}
DEF$inf_diss <- list(soma_series(DEF$uniao_filtro_diss[[1]], est_base), "Agregado da dissertacao: uniao_filtro_diss + estatais_total", "composto")
DEF$inf_diss_imprazao <- list(soma_series(DEF$uniao_filtro_diss_imprazao[[1]], est_base), "Como inf_diss, com 2017 imputado pela razao do trimestre", "composto")
for (nm in names(est_var)) {
  DEF[[sub("estatais_total", "inf_diss", nm)]] <- list(soma_series(DEF$uniao_filtro_diss[[1]], est_var[[nm]]),
                                                       paste0("Como inf_diss, com ", nm), "composto")
}
PRINCIPAIS <- c("uniao_econ_dir", "uniao_econ_dt", "uniao_soc_dir", "uniao_soc_dt", "uniao_transf_econ", "uniao_transf_soc",
                "uniao_gnd4_dir", "uniao_filtro_diss", "estatais_total", "estatais_petro", "estatais_sempetro",
                "estatais_econ", "estatais_outras", "estatais_grupopetro", "estatais_semgrupopetro", "inf_diss")

# Regra para zero ou negativo: nao entra em log; X-11 aditivo e so nivel.
longo <- list()
for (nm in names(DEF)) {
  d <- DEF[[nm]][[1]] %>% arrange(q)
  stopifnot(!anyNA(d$nom), identical(d$q, q_seq(d$q[1], d$q[nrow(d)])))
  d <- d %>% mutate(real = nom * DEFL$media_tri[match(q, DEFL$q)])
  n_np <- sum(d$real <= 0)
  sa <- roda_x11(ts_from_q(d$real, d$q), nm)
  base_ano <- ano_q(d$q[1])
  b <- ano_q(d$q) == base_ano
  idx <- 100 * sa / mean(sa[b])
  ok_log <- n_np == 0 && all(sa > 0)
  longo[[nm]] <- d %>% transmute(trimestre = q, serie = nm, nominal_rs_bi = nom, real_rs_bi_2025 = real,
                                 real_sa_rs_bi_2025 = sa, indice_sa = idx,
                                 log10_indice_sa = if (ok_log) log10(idx) else NA_real_,
                                 base_indice = paste0("media ", base_ano, " = 100"))
  if (!ok_log) {
    L("ATENCAO: ", nm, " tem ", n_np, " trimestres com valor real <= 0 ou ajuste sazonal <= 0; ficou sem log10 (X-11 aditivo, so nivel).")
  }
}
longo <- bind_rows(longo)
n_np_total <- longo %>% group_by(serie) %>% summarise(np = sum(real_rs_bi_2025 <= 0), minimo = min(real_rs_bi_2025), .groups = "drop")
L("Regra para valores zero ou negativos: serie com algum trimestre real <= 0 nao vai para log10; roda X-11 aditivo ",
  "(transform.function = \"none\") e fica so em nivel. Nenhum valor e substituido ou somado a constante. Series afetadas: ",
  if (any(n_np_total$np > 0)) paste(n_np_total$serie[n_np_total$np > 0], collapse = ", ") else "nenhuma", ". ",
  "Menor valor real trimestral entre as series: ", fmt(min(n_np_total$minimo), 4), " (", n_np_total$serie[which.min(n_np_total$minimo)], "). ",
  "Componentes da OI com zeros (Transport, com 8 trimestres, todos zero; Oil fora do grupo Petrobras; Electricity do grupo ",
  "Petrobras) so entram somados em agregados positivos.")

sa_info <- bind_rows(SA_INFO)
write_csv_safe(sa_info, "results/A3_x11_diagnostico.csv")
L("X-11 em cada serie de choque sobre a propria janela (2003T1-2025T4, ou 2016T1-2025T4 nas series so da OI), com as ",
  "series em R$ de 2025. Transformacao escolhida: log em ", sum(sa_info$transformacao == "log"), " de ", nrow(sa_info),
  " series; especificacao padrao em ", sum(sa_info$especificacao == "padrao"), ". Modelo, outliers, M7 e Q por serie em ",
  "results/A3_x11_diagnostico.csv. Indices: base media 2003 = 100 (ou media 2016 = 100 nas series da OI), log10 do indice.")
for (i in which(sa_info$serie %in% PRINCIPAIS)) {
  s <- sa_info[i, ]
  L2(s$serie, ": ", s$transformacao, ", ARIMA ", s$arima, ", outliers ", ifelse(nzchar(s$outliers), s$outliers, "nenhum"),
     ", M7 ", sub("\\.", ",", s$m7), ", Q ", sub("\\.", ",", s$q_x11), ".")
}

# Comparacao do real com o valor em R$ de 2025 do dashboard (fator anual): so conferencia
cmp_dash <- dash %>% filter(q %in% QS) %>% group_by(ano) %>%
  summarise(nom = sum(nom), real_dash = sum(real_dash), .groups = "drop") %>%
  left_join(dash %>% filter(q %in% QS) %>% group_by(ano, q) %>% summarise(nom = sum(nom), .groups = "drop") %>%
              mutate(real = nom * DEFL$media_tri[match(q, DEFL$q)]) %>% group_by(ano) %>%
              summarise(real = sum(real), .groups = "drop"), by = "ano")
L("Conferencia do deflator com o dashboard (coluna R$ bi de 2025, fator anual): soma anual do federal GND 4 deflacionado ",
  "por trimestre / valor do dashboard entre ", fmt(min(cmp_dash$real / cmp_dash$real_dash), 4), " e ",
  fmt(max(cmp_dash$real / cmp_dash$real_dash), 4), " (2003-2025). A diferenca vem so da distribuicao do gasto no ano.")

# ---------------------------------------------------------------------------
# 8. Destino das transferencias e parcelas do LOG (base anual, nominal)
# ---------------------------------------------------------------------------
pan_j <- pan %>% filter(ano >= 2003, ano <= 2025)
dest <- pan_j %>% filter(grupo_mod == "transferencia", tipo != "outras") %>%
  mutate(destino = case_when(modalidade %in% MOD_ESTMUN ~ "estados e municipios",
                             modalidade %in% MOD_PRIVADA ~ "entidades privadas",
                             modalidade %in% MOD_EXTERIOR ~ "exterior",
                             TRUE ~ "outras")) %>%
  group_by(ano, tipo, destino) %>% summarise(nominal_rs_bi = sum(v), .groups = "drop") %>%
  group_by(ano, tipo) %>% mutate(participacao = nominal_rs_bi / sum(nominal_rs_bi)) %>% ungroup()
dest_tot <- dest %>% group_by(tipo, destino) %>% summarise(nominal_rs_bi = sum(nominal_rs_bi), .groups = "drop") %>%
  group_by(tipo) %>% mutate(participacao = nominal_rs_bi / sum(nominal_rs_bi)) %>% ungroup()
write_csv_safe(bind_rows(dest %>% mutate(ano = as.character(ano)), dest_tot %>% mutate(ano = "2003-2025")) %>%
                 select(ano, tipo, destino, nominal_rs_bi, participacao),
               "results/A3_transferencias_destino.csv")
mods_outras <- pan_j %>% filter(grupo_mod == "transferencia", tipo != "outras",
                                !modalidade %in% c(MOD_ESTMUN, MOD_PRIVADA, MOD_EXTERIOR)) %>% distinct(modalidade) %>% pull()
L("Destino das transferencias (grupo 1) da base anual, somas nominais 2003-2025. Estados e municipios = modalidades ",
  paste(MOD_ESTMUN, collapse = ", "), "; entidades privadas = 50 e 60; exterior = 80; outras = ",
  if (length(mods_outras)) paste(sort(mods_outras), collapse = ", ") else "nenhuma", ".")
for (tp in c("economica", "social")) {
  x <- dest_tot %>% filter(tipo == tp)
  L2(tp, ": ", paste0(x$destino, " ", pct(x$participacao), " (R$ ", fmt(x$nominal_rs_bi, 1), " bi)", collapse = "; "), ".")
}
x_ano <- dest %>% filter(destino == "estados e municipios")
L2("Parcela de estados e municipios por ano: economica entre ", pct(min(x_ano$participacao[x_ano$tipo == "economica"])), " e ",
   pct(max(x_ano$participacao[x_ano$tipo == "economica"])), "; social entre ", pct(min(x_ano$participacao[x_ano$tipo == "social"])),
   " e ", pct(max(x_ano$participacao[x_ano$tipo == "social"])), ". Tabela por ano em results/A3_transferencias_destino.csv.")

parc_pan <- pan_j %>% filter(tipo != "outras", grupo_mod != "outra") %>%
  group_by(tipo, grupo_mod) %>% summarise(v = sum(v), .groups = "drop") %>%
  pivot_wider(names_from = grupo_mod, values_from = v)
parc_dash <- dash %>% filter(ano >= 2003, ano <= 2025, tipo != "outras", grupo %in% 0:1) %>%
  group_by(tipo, grupo) %>% summarise(v = sum(nom), .groups = "drop") %>%
  pivot_wider(names_from = grupo, values_from = v, names_prefix = "g")
L("Conferencia das parcelas do LOG (social 70% via transferencias, R$ 192 bi x R$ 82 bi diretos; economica 92% direta, ",
  "R$ 182 bi x R$ 16 bi), somas nominais 2003-2025, direta = 90 e 91, transferencia = demais exceto 67 e 99:")
for (tp in c("economica", "social")) {
  p <- parc_pan %>% filter(tipo == tp); dd <- parc_dash %>% filter(tipo == tp)
  L2(tp, ", base anual: direta R$ ", fmt(p$direta, 1), " bi, transferencias R$ ", fmt(p$transferencia, 1), " bi; ",
     "direta ", pct(p$direta / (p$direta + p$transferencia)), ", transferencias ", pct(p$transferencia / (p$direta + p$transferencia)),
     ". Dashboard trimestral: direta R$ ", fmt(dd$g0, 1), " bi, transferencias R$ ", fmt(dd$g1, 1), " bi.")
}

# ---------------------------------------------------------------------------
# 9. Participacoes anuais (R$ de 2025, sem ajuste sazonal)
# ---------------------------------------------------------------------------
defq <- DEFL %>% select(q, f = media_tri)
uni_ano <- dash %>% filter(q %in% QS) %>% left_join(defq, by = "q") %>%
  mutate(categoria = case_when(grupo == 2 ~ "uniao_outra_modalidade",
                               TRUE ~ paste0("uniao_", c(economica = "econ", social = "soc", outras = "outras")[tipo],
                                             c("_dir", "_transf")[grupo + 1]))) %>%
  group_by(ano, categoria) %>% summarise(real = sum(nom * f), .groups = "drop")
est_ano <- est_base %>% left_join(defq, by = "q") %>% mutate(ano = ano_q(q)) %>%
  group_by(ano) %>% summarise(est = sum(nom * f), .groups = "drop")
oi_sh <- oi %>% mutate(ano = ano_q(q)) %>% group_by(ano, classe) %>% summarise(v = sum(valor_nominal_bi), .groups = "drop") %>%
  group_by(ano) %>% mutate(sh = v / sum(v)) %>% ungroup()
oi_gp <- oi %>% mutate(ano = ano_q(q)) %>% group_by(ano) %>%
  summarise(sh_gp = sum(valor_nominal_bi[grupo_petrobras]) / sum(valor_nominal_bi), .groups = "drop")
est_seg <- est_ano %>% inner_join(oi_sh, by = "ano") %>%
  transmute(ano, categoria = paste0("estatais_", c(petroleo = "petro", economica = "econ", outras = "outras")[classe]), real = est * sh)
est_sem <- est_ano %>% filter(ano < 2016) %>% transmute(ano, categoria = "estatais_sem_abertura", real = est)
part <- bind_rows(uni_ano, est_seg, est_sem) %>%
  group_by(ano) %>% mutate(part_total = real / sum(real)) %>% ungroup() %>%
  mutate(bloco = ifelse(grepl("^uniao", categoria), "uniao", "estatais")) %>%
  group_by(ano, bloco) %>% mutate(part_bloco = real / sum(real)) %>% ungroup()
memo <- bind_rows(
  fil_base %>% filter(q %in% QS) %>% left_join(defq, by = "q") %>% mutate(ano = ano_q(q)) %>%
    group_by(ano) %>% summarise(real = sum(nom * f), .groups = "drop") %>% mutate(categoria = "memo_uniao_filtro_diss"),
  est_ano %>% transmute(ano, real = est, categoria = "memo_estatais_total"),
  est_ano %>% inner_join(oi_gp, by = "ano") %>% transmute(ano, real = est * sh_gp, categoria = "memo_estatais_grupopetro")
) %>% left_join(part %>% group_by(ano) %>% summarise(tot = sum(real), .groups = "drop"), by = "ano") %>%
  mutate(part_total = real / tot, bloco = "memo", part_bloco = NA_real_) %>% select(-tot)
part_out <- bind_rows(part, memo) %>%
  transmute(ano, bloco, categoria, real_rs_bi_2025 = real, part_total_pct = 100 * part_total, part_bloco_pct = 100 * part_bloco) %>%
  arrange(ano, bloco, categoria)
write_csv_safe(part_out, "results/A3_participacoes_ano.csv")
L("Participacoes anuais (results/A3_participacoes_ano.csv e .tex): total = Uniao GND 4 (grupos 0, 1 e 2, todas as funcoes) + ",
  "estatais encadeadas, em R$ de 2025 sem ajuste sazonal. Estatais por segmento de 2016 em diante: participacao do segmento na ",
  "OI aplicada ao total encadeado do ano; antes de 2016 so o total. Linhas memo (filtro da dissertacao, estatais total, grupo ",
  "Petrobras) nao somam na particao.")

# Tabela LaTeX
cols_tex <- c("uniao_econ_dir", "uniao_econ_transf", "uniao_soc_dir", "uniao_soc_transf", "uniao_outras_dir",
              "uniao_outras_transf", "uniao_outra_modalidade", "estatais_petro", "estatais_econ", "estatais_outras")
tab <- part %>% select(ano, categoria, part_total) %>%
  pivot_wider(names_from = categoria, values_from = part_total) %>%
  left_join(part %>% group_by(ano) %>% summarise(total = sum(real), .groups = "drop"), by = "ano") %>%
  mutate(estatais = rowSums(across(any_of(c("estatais_petro", "estatais_econ", "estatais_outras", "estatais_sem_abertura"))), na.rm = TRUE)) %>%
  arrange(ano)
tex_num <- function(x, d = 1) ifelse(is.na(x), "--", gsub("\\.", "{,}", formatC(x, format = "f", digits = d)))
for (k in cols_tex) if (!k %in% names(tab)) tab[[k]] <- NA_real_
linhas <- vapply(seq_len(nrow(tab)), function(i) {
  r <- tab[i, ]
  vals <- c(tex_num(r$total, 1), vapply(cols_tex[1:7], function(k) tex_num(100 * r[[k]]), ""),
            tex_num(100 * r$estatais), vapply(cols_tex[8:10], function(k) tex_num(100 * r[[k]]), ""))
  paste0(r$ano, " & ", paste(vals, collapse = " & "), " \\\\")
}, "")
tex <- c(
  "% Gerado por R/A3_investimento_publico.R. Requer \\usepackage{booktabs}.",
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Participa\\c{c}\\~ao anual no investimento p\\'ublico federal (Uni\\~ao GND 4 e estatais), \\% do total, 2003--2025}",
  "\\label{tab:a3_participacoes}", "\\scriptsize", "\\setlength{\\tabcolsep}{3pt}",
  "\\begin{tabular}{lrrrrrrrrrrrr}", "\\toprule",
  " & Total & \\multicolumn{7}{c}{Uni\\~ao} & \\multicolumn{4}{c}{Estatais} \\\\",
  "\\cmidrule(lr){3-9}\\cmidrule(lr){10-13}",
  " & R\\$ bi & \\multicolumn{2}{c}{Econ\\^omica} & \\multicolumn{2}{c}{Social} & \\multicolumn{2}{c}{Outras} & Outra & Total & Petr\\'oleo & Econ. & Outras \\\\",
  "\\cmidrule(lr){3-4}\\cmidrule(lr){5-6}\\cmidrule(lr){7-8}",
  "Ano & 2025 & Dir. & Transf. & Dir. & Transf. & Dir. & Transf. & mod. & & & & \\\\", "\\midrule",
  linhas, "\\bottomrule", "\\end{tabular}",
  "\\begin{minipage}{0.95\\linewidth}\\footnotesize",
  paste0("\\medskip Notas: valores pagos + restos a pagar pagos em GND 4 (todos os elementos) e investimento das estatais federais, ",
         "deflacionados pelo IPCA m\\'edio do trimestre (R\\$ de 2025) e somados no ano. Dir. = aplica\\c{c}\\~ao direta (modalidades 90 e 91); ",
         "Transf. = transfer\\^encias (demais modalidades, exceto 67 e 99); Outra mod. = modalidades 67 e 99, todas as fun\\c{c}\\~oes. ",
         "Econ\\^omica: fun\\c{c}\\~oes 24, 25 e 26; social: 08, 10, 12, 15, 16, 17 e 27. Estatais: boletim da SEST at\\'e 2019 e OI ",
         "encadeado pela raz\\~ao m\\'edia boletim/OI de 2016--2019 a partir de 2020; abertura por segmento (OI) s\\'o a partir de 2016. ",
         "Federal de 2017 pelo dashboard trimestral (GND 4 completo, sem imputa\\c{c}\\~ao)."),
  "\\end{minipage}", "\\end{table}")
guard_path("results/A3_participacoes_ano.tex")
writeLines(tex, "results/A3_participacoes_ano.tex")

sh_uni <- part %>% group_by(ano, bloco) %>% summarise(p = sum(part_total), .groups = "drop") %>% filter(bloco == "estatais")
L("Estatais no total: ", pct(sh_uni$p[sh_uni$ano == 2003]), " em 2003, ", pct(sh_uni$p[sh_uni$ano == 2013]), " em 2013, ",
  pct(sh_uni$p[sh_uni$ano == 2019]), " em 2019 e ", pct(sh_uni$p[sh_uni$ano == 2025]), " em 2025. Petroleo nas estatais ",
  "(OI): ", pct(min(oi_sh$sh[oi_sh$classe == "petroleo"])), " a ", pct(max(oi_sh$sh[oi_sh$classe == "petroleo"])),
  " (2016-2025); grupo Petrobras: ", pct(min(oi_gp$sh_gp)), " a ", pct(max(oi_gp$sh_gp)), ".")

# ---------------------------------------------------------------------------
# 10. Saidas trimestrais
# ---------------------------------------------------------------------------
write_csv_safe(longo, "data/processed/A3_invpub_trimestral.csv")
ind <- tibble(trimestre = QS) %>%
  mutate(imp2017 = as.integer(ano_q(trimestre) == 2017),
         emenda_sest = as.integer(trimestre >= "2020Q1"),
         emenda_sest_2017 = as.integer(trimestre >= "2017Q1"),
         emenda_sest_2018 = as.integer(trimestre >= "2018Q1"),
         emenda_sest_2019 = as.integer(trimestre >= "2019Q1"),
         emenda_sest_2020 = as.integer(trimestre >= "2020Q1"))
ordem <- c(PRINCIPAIS, setdiff(names(DEF), PRINCIPAIS))
choques <- ind %>% left_join(longo %>% select(trimestre, serie, log10_indice_sa) %>%
                               pivot_wider(names_from = serie, values_from = log10_indice_sa), by = "trimestre") %>%
  select(trimestre, starts_with("imp"), starts_with("emenda"), all_of(ordem))
niveis <- tibble(trimestre = QS) %>% left_join(longo %>% select(trimestre, serie, real_sa_rs_bi_2025) %>%
                                                 pivot_wider(names_from = serie, values_from = real_sa_rs_bi_2025), by = "trimestre") %>%
  select(trimestre, all_of(ordem))
write_csv_safe(choques, "data/processed/A3_choques_wide.csv")
write_csv_safe(niveis, "data/processed/A3_niveis_wide.csv")
meta <- tibble(serie = names(DEF), definicao = sapply(DEF, `[[`, 2), fonte = sapply(DEF, `[[`, 3)) %>%
  left_join(longo %>% group_by(serie) %>% summarise(inicio = min(trimestre), fim = max(trimestre), n = n(),
                                                    base_indice = first(base_indice), .groups = "drop"), by = "serie") %>%
  mutate(principal = serie %in% PRINCIPAIS, unidade_nivel = "R$ bi de 2025 (IPCA medio do trimestre)",
         ajuste = "X-11 (x11_sa) sobre a janela da serie", transformacao_choque = "log10 do indice com ajuste sazonal")
write_csv_safe(meta, "data/processed/A3_metadados_series.csv")
L("Indicadoras: imp2017 = 1 em 2017T1-2017T4; emenda_sest = 1 de 2020T1 em diante; emenda_sest_2017 a _2020 para as emendas alternativas.")
L("Saidas: data/processed/A3_invpub_trimestral.csv (longo, ", length(unique(longo$serie)), " series), A3_choques_wide.csv (log10 do indice ",
  "com ajuste), A3_niveis_wide.csv (R$ bi de 2025 com ajuste), A3_metadados_series.csv; results/A3_participacoes_ano.csv e .tex, ",
  "A3_reconstrucao_INF.md, A3_reconstrucao_INF_variantes.csv, A3_classificacao.md, A3_transferencias_destino.csv, ",
  "A3_x11_diagnostico.csv; results/figuras/A3_series.png e .pdf, A3_series_variantes.png e A3_INF_reconstruida.png.")

# Resumo de niveis para o log
niv_ano <- longo %>% filter(serie %in% PRINCIPAIS) %>% mutate(ano = ano_q(trimestre)) %>%
  group_by(serie, ano) %>% summarise(v = sum(real_rs_bi_2025), .groups = "drop")
L("Niveis anuais, R$ bi de 2025 sem ajuste (2003 ou 2016 / 2019 / 2025):")
for (s in PRINCIPAIS) {
  x <- niv_ano %>% filter(serie == s)
  L2(s, ": ", fmt(x$v[1], 1), " (", x$ano[1], ") / ", fmt(x$v[x$ano == 2019], 1), " / ", fmt(x$v[x$ano == 2025], 1), ".")
}

# ---------------------------------------------------------------------------
# 11. Figuras
# ---------------------------------------------------------------------------
COR <- c("Uniao" = "#2a78d6", "Estatais" = "#eb6834", "Agregado" = "#1baf7a")
TINTA <- "#0b0b0b"; TINTA2 <- "#52514e"; GRADE <- "#e4e3df"
tema <- theme_minimal(base_size = 9) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = GRADE, linewidth = 0.3),
        text = element_text(colour = TINTA), axis.text = element_text(colour = TINTA2),
        strip.text = element_text(face = "bold", hjust = 0), legend.position = "top",
        plot.background = element_rect(fill = "white", colour = NA))
dq <- function(q) as.numeric(q_to_yearqtr(q))

fig_d <- longo %>% filter(serie %in% PRINCIPAIS) %>%
  mutate(x = dq(trimestre), serie = factor(serie, levels = PRINCIPAIS),
         bloco = case_when(grepl("^uniao", serie) ~ "Uniao", grepl("^estatais", serie) ~ "Estatais", TRUE ~ "Agregado"),
         bloco = factor(bloco, levels = names(COR)))
p_series <- ggplot(fig_d, aes(x, log10_indice_sa, colour = bloco)) +
  annotate("rect", xmin = 2017, xmax = 2018, ymin = -Inf, ymax = Inf, fill = "#f0efec") +
  geom_vline(xintercept = 2020, linetype = "dashed", colour = TINTA2, linewidth = 0.3) +
  geom_line(linewidth = 0.5) +
  facet_wrap(~serie, ncol = 4, scales = "free_y") +
  scale_colour_manual(values = COR, name = NULL) +
  scale_x_continuous(breaks = seq(2004, 2024, 4)) +
  labs(x = NULL, y = "log10 do indice com ajuste sazonal (media 2003 = 100; series da OI: media 2016 = 100)",
       title = "Series de investimento publico, R$ de 2025, X-11, 2003T1-2025T4",
       caption = "Faixa cinza: 2017 (distribuicao trimestral imputada no filtro da dissertacao). Linha tracejada: 2020T1 (emenda boletim/OI da SEST).") +
  tema
ggsave("results/figuras/A3_series.png", p_series, width = 11, height = 9, dpi = 200, bg = "white")
ggsave("results/figuras/A3_series.pdf", p_series, width = 11, height = 9, bg = "white")

var_d <- bind_rows(
  longo %>% filter(serie %in% c("estatais_total", names(est_var))) %>% mutate(painel = "estatais_total: emendas"),
  longo %>% filter(serie %in% c("inf_diss", sub("estatais_total", "inf_diss", names(est_var)))) %>% mutate(painel = "inf_diss: emendas"),
  longo %>% filter(serie %in% c("uniao_filtro_diss", "uniao_filtro_diss_imprazao"), ano_q(trimestre) %in% 2014:2021) %>%
    mutate(painel = "uniao_filtro_diss: imputacao de 2017")
) %>% mutate(x = dq(trimestre), baseline = serie %in% c("estatais_total", "inf_diss", "uniao_filtro_diss"),
             tipo = ifelse(baseline, "Baseline", "Variantes"))
p_var <- ggplot(var_d, aes(x, real_sa_rs_bi_2025, group = serie, colour = tipo, linewidth = tipo)) +
  geom_line() +
  facet_wrap(~painel, ncol = 1, scales = "free") +
  scale_colour_manual(values = c("Baseline" = "#2a78d6", "Variantes" = "#a9a8a3"), name = NULL) +
  scale_linewidth_manual(values = c("Baseline" = 0.7, "Variantes" = 0.4), name = NULL) +
  labs(x = NULL, y = "R$ bi de 2025, com ajuste sazonal",
       title = "Sensibilidade: emenda boletim/OI (2017T1 a 2020T1) e imputacao de 2017") + tema
ggsave("results/figuras/A3_series_variantes.png", p_var, width = 8, height = 8, dpi = 200, bg = "white")

rec_d <- longo %>% filter(serie == "inf_diss") %>%
  transmute(q = trimestre, v = log10_indice_sa, serie = "Reconstruida (inf_diss)")
b03 <- inf_orig %>% filter(q %in% q_seq("2003Q1", "2003Q4"))
orig_d <- inf_orig %>% transmute(q, v = log10(100 * 10^INF / mean(10^b03$INF)), serie = "INF da dissertacao")
niv_d <- bind_rows(orig_d, rec_d) %>% mutate(x = dq(q))
lab_d <- niv_d %>% group_by(serie) %>% filter(x == max(x))
COR2 <- c("Reconstruida (inf_diss)" = "#2a78d6", "INF da dissertacao" = "#eb6834")
p1 <- ggplot(niv_d, aes(x, v, colour = serie)) +
  geom_line(linewidth = 0.6) +
  geom_text(data = lab_d, aes(label = serie), hjust = 1, vjust = -0.8, size = 2.8, colour = TINTA2) +
  scale_colour_manual(values = COR2, name = NULL) +
  labs(x = NULL, y = "log10 do indice (media 2003 = 100)", title = "Nivel") + tema
dif_d <- niv_d %>% filter(q %in% Q_CMP) %>% group_by(serie) %>% arrange(x) %>% mutate(d = v - lag(v)) %>% filter(!is.na(d))
p2 <- ggplot(dif_d, aes(x, d, colour = serie)) +
  geom_hline(yintercept = 0, colour = TINTA2, linewidth = 0.3) +
  geom_line(linewidth = 0.5) +
  scale_colour_manual(values = COR2, name = NULL) +
  labs(x = NULL, y = "diferenca trimestral do log10",
       title = paste0("Diferencas, 2003T2-2019T4: correlacao ", fmt(base_v$corr_dif, 3),
                      "; desvio absoluto medio ", fmt(base_v$dam_dif, 4))) + tema
p_inf <- (p1 / p2) + plot_layout(guides = "collect") & theme(legend.position = "top")
ggsave("results/figuras/A3_INF_reconstruida.png", p_inf, width = 8, height = 7, dpi = 200, bg = "white")

# ---------------------------------------------------------------------------
# 12. Relatorios em markdown
# ---------------------------------------------------------------------------
md_tab <- function(df) {
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
top <- res_var %>% slice(1:10) %>%
  transmute(deflator, ajuste, janela_x11 = span, imputacao_2017 = imputacao, corr_dif = fmt(corr_dif, 4),
            dam_dif = fmt(dam_dif, 4), desvio_medio_nivel = fmt(desvio_medio_nivel, 4), dam_nivel = fmt(dam_nivel, 4),
            dam_dif_2017 = fmt(dam_dif_2017, 4))
fatores <- bind_rows(lapply(list(c("deflator", "media_tri"), c("deflator", "fim_tri"), c("deflator", "anual"), c("deflator", "nominal"),
                                 c("ajuste", "soma"), c("ajuste", "componentes"), c("ajuste", "nenhum"),
                                 c("imputacao", "base"), c("imputacao", "razao")), function(cc) {
  r <- resumo_fator(cc[1], cc[2]); tibble(fator = cc[1], nivel = cc[2], corr_media = fmt(r$c, 4), dam_dif_media = fmt(r$d, 4))
}))
bv <- base_v
md_inf <- c(
  "# A3: reconstrucao de INF", "",
  paste0("Gerado por R/A3_investimento_publico.R em ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "INF da dissertacao: data/original/0224_tri_estmeq.txt, log10, 2002T1-2019T4. Reconstrucao: federal com o filtro da dissertacao",
  "(modalidade 90 e 6 elementos; 2017 imputado) + boletim da SEST (Brasil), em R$ de 2025, X-11, indice e log10.",
  "Comparacao em 2003T2-2019T4 (67 diferencas trimestrais). Indices com base media 2003 = 100 nas medidas de nivel.", "",
  "## Serie entregue (inf_diss)", "",
  paste0("IPCA medio do trimestre, X-11 depois de somar os componentes, janela do X-11 2003T1-2025T4, imputacao baseline de 2017."), "",
  paste0("- correlacao das diferencas do log10: ", fmt(bv$corr_dif, 4)),
  paste0("- desvio absoluto medio das diferencas: ", fmt(bv$dam_dif, 4), " (log10)"),
  paste0("- desvio medio em nivel (reconstruida menos original, indices base 2003): ", fmt(bv$desvio_medio_nivel, 4),
         " em log10 (", pct(10^bv$desvio_medio_nivel - 1, 1), "); absoluto medio ", fmt(bv$dam_nivel, 4), "; maximo ", fmt(bv$max_nivel, 4)),
  paste0("- desvio absoluto medio das diferencas de 2017T1 a 2018T1: ", fmt(bv$dam_dif_2017, 4)), "",
  "## Variantes", "",
  paste0("Mais proxima (maior correlacao das diferencas): deflator ", melhor$deflator, ", ajuste ", melhor$ajuste, ", janela ",
         melhor$span, ", imputacao ", melhor$imputacao, ", correlacao ", fmt(melhor$corr_dif, 4), "."), "",
  "Dez melhores (dam = desvio absoluto medio; tabela completa em results/A3_reconstrucao_INF_variantes.csv):", "",
  md_tab(top), "",
  "Media das metricas por nivel de cada fator (sobre todas as variantes):", "",
  md_tab(fatores), "",
  "Deflatores: media_tri = IPCA medio do trimestre; fim_tri = IPCA do ultimo mes do trimestre; anual = IPCA medio do ano;",
  "nominal = sem deflacao. Ajuste: soma = X-11 depois de somar; componentes = X-11 em cada componente e soma; nenhum = sem X-11.", "",
  "Figura: results/figuras/A3_INF_reconstruida.png.")
guard_path("results/A3_reconstrucao_INF.md")
writeLines(md_inf, "results/A3_reconstrucao_INF.md")

fun_tab <- tibble(funcao = names(FUNCOES_NOMES), nome = FUNCOES_NOMES, tipo = tipo_funcao(names(FUNCOES_NOMES))) %>%
  left_join(dash %>% filter(q %in% QS, grupo %in% 0:1) %>% group_by(funcao, grupo) %>% summarise(v = sum(nom), .groups = "drop") %>%
              pivot_wider(names_from = grupo, values_from = v, names_prefix = "g", values_fill = 0), by = "funcao") %>%
  mutate(across(c(g0, g1), ~ fmt(coalesce(.x, 0), 1))) %>%
  rename(`direta R$ bi` = g0, `transf. R$ bi` = g1)
seg_tab <- oi %>% group_by(segmento, classe) %>%
  summarise(`R$ bi nominais 2016-2025` = fmt(sum(valor_nominal_bi), 1),
            `grupo Petrobras R$ bi` = fmt(sum(valor_nominal_bi[grupo_petrobras]), 1),
            trimestres = paste0(min(q), "-", max(q)), .groups = "drop") %>%
  arrange(match(classe, c("petroleo", "economica", "outras")), segmento)
dest_md <- dest_tot %>% transmute(tipo, destino, `R$ bi nominais` = fmt(nominal_rs_bi, 1), participacao = pct(participacao))
md_cl <- c(
  "# A3: classificacao das series de investimento publico", "",
  paste0("Gerado por R/A3_investimento_publico.R em ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "## Uniao: funcoes (Portaria MOG 42/1999)", "",
  "Economica: 24, 25, 26. Social: 08, 10, 12, 15, 16, 17, 27. Outras: demais funcoes. Valores: GND 4, somas nominais 2003-2025",
  "do dashboard trimestral (direta = grupo 0, modalidades 90 e 91; transferencia = grupo 1, demais exceto 67 e 99).", "",
  md_tab(fun_tab), "",
  "## Uniao: modalidades", "",
  "- aplicacao direta (grupo 0): 90 e 91;",
  "- transferencia (grupo 1): todas as demais exceto 67 e 99; destino estados e municipios = 30, 31, 32, 40, 41, 42, 71, 72;",
  "  entidades privadas = 50 e 60; exterior = 80; outras = demais (na base, 70);",
  "- outra (grupo 2): 67 e 99.", "",
  "Destino das transferencias (grupo 1), base anual, 2003-2025:", "",
  md_tab(dest_md), "",
  "## Estatais: segmentos da OI (classificacao aprovada pelo autor em 2026-09-28)", "",
  md_tab(seg_tab), "",
  "Antes de 2016 (boletim) nao ha abertura por segmento: so o total Brasil.", "",
  "## Series de choque", "",
  md_tab(meta %>% filter(principal) %>% select(serie, definicao, inicio, fim, base_indice)), "",
  "Variantes de robustez:", "",
  md_tab(meta %>% filter(!principal) %>% select(serie, definicao, inicio, fim)))
guard_path("results/A3_classificacao.md")
writeLines(md_cl, "results/A3_classificacao.md")

L("Classificacao das funcoes e dos segmentos da SEST (para aprovacao do autor; os segmentos ja foram aprovados em 2026-09-28):")
L2("Uniao economica: ", paste0(names(FUNCOES_ECONOMICA), " ", FUNCOES_ECONOMICA, collapse = "; "), ".")
L2("Uniao social: ", paste0(names(FUNCOES_SOCIAL), " ", FUNCOES_SOCIAL, collapse = "; "), ".")
L2("Uniao outras: todas as demais funcoes, inclusive 00 (sem funcao) e 28 (encargos especiais).")
for (cl in c("petroleo", "economica", "outras")) {
  x <- seg_tab %>% filter(classe == cl)
  L2("Estatais ", cl, ": ", paste0(x$segmento, " (R$ ", x$`R$ bi nominais 2016-2025`, " bi)", collapse = "; "), ".")
}
L2("Variante por grupo_petrobras: estatais_grupopetro = grupo_petrobras True (Oil, gas & derivatives e Electricity do grupo); ",
   "estatais_semgrupopetro = demais. Tabela completa em results/A3_classificacao.md.")

save_session_info("A3_investimento_publico")
L("Tempo total: ", round(as.numeric(difftime(Sys.time(), t_ini, units = "secs"))), " s.")
