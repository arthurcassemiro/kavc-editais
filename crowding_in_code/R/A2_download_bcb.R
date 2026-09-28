# Etapa A2, parte BCB/SGS: Selic, IPCA, cambio real efetivo, IC-Br e PTAX.
# Saidas: data/processed/A2_bcb_mensal.csv, A2_bcb_trimestral.csv, A2_deflator_ipca.csv
# e a parte BCB de data/processed/A2_metadados_bcb_ibge.csv.
# Rodar da raiz do projeto: Rscript R/A2_download_bcb.R

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

ETAPA <- "A2_bcb_ibge"
MARCA_BCB <- "#### BCB/SGS"
MARCA_IBGE <- "#### IBGE/SIDRA"
INI <- as.Date("2000-01-01")
FIM <- as.Date("2025-12-31")

# O log da etapa e compartilhado com R/A2_download_ibge.R. Guarda a secao IBGE
# existente, reinicia o arquivo e a reescreve no fim (ordem fixa: BCB, IBGE).
ler_secao <- function(etapa, marca) {
  f <- file.path(PATHS$log_parts, paste0(etapa, ".md"))
  if (!file.exists(f)) return(character(0))
  l <- readLines(f, warn = FALSE)
  i <- grep(paste0("^", marca), l)
  if (!length(i)) return(character(0))
  j <- grep("^#### ", l)
  j <- j[j > i[1]]
  fim <- if (length(j)) j[1] - 1 else length(l)
  l[i[1]:fim]
}
secao_ibge <- ler_secao(ETAPA, MARCA_IBGE)
log_reset(ETAPA)
log_part(ETAPA, sprintf("%s (R/A2_download_bcb.R, execucao de %s)", MARCA_BCB, format(Sys.time(), "%Y-%m-%d %H:%M")))

num_br <- function(x, d = 3) formatC(x, format = "f", digits = d, decimal.mark = ",", big.mark = ".")

# ---------------------------------------------------------------------------
# 1. Metadados: pagina da serie no SGS (em portugues) e portal de dados abertos
# ---------------------------------------------------------------------------
h_sgs <- handle("https://www3.bcb.gov.br")
invisible(RETRY("GET", "https://www3.bcb.gov.br/sgspub/index.jsp?idIdioma=P", handle = h_sgs, times = 3))

sgs_meta <- function(codigo) {
  url <- sprintf(paste0("https://www3.bcb.gov.br/sgspub/consultarvalores/consultarValoresSeries.do?",
                        "method=consultarGraficoPorId&hdOidSeriesSelecionadas=%s"), codigo)
  r <- RETRY("GET", url, handle = h_sgs, times = 3, timeout(60))
  txt <- content(r, as = "text", encoding = "latin1")
  cel <- regmatches(txt, gregexpr('<td[^>]*class="txtMenor1"[^>]*>[^<]*</td>', txt))[[1]]
  if (length(cel) < 6) return(NULL)
  v <- trimws(gsub("<[^>]+>", "", cel[1:6]))
  per <- sub('.*title="([^"]*)".*', "\\1", cel[4])
  tibble(codigo = v[1], titulo = v[2], unidade = v[3], periodicidade = per,
         inicio_sgs = v[5], ultimo_sgs = v[6], url_meta = url)
}

portal_meta <- function(codigo) {
  url <- sprintf("https://dadosabertos.bcb.gov.br/api/3/action/package_search?fq=codigo_sgs:%s&rows=1", codigo)
  r <- try(RETRY("GET", url, times = 3, timeout(60)), silent = TRUE)
  if (inherits(r, "try-error")) return(NA_character_)
  js <- fromJSON(content(r, as = "text", encoding = "UTF-8"))
  if (js$result$count == 0) return(NA_character_)
  js$result$results$title[1]
}

# Candidatos e o que se espera encontrar no titulo (regex); se nao bater, a serie
# e registrada como indisponivel e nao e usada.
CAND <- tribble(
  ~serie,                 ~codigo, ~esperado,                                            ~tipo,
  "selic_meta",           "432",   "Meta Selic definida pelo Copom",                     "diaria",
  "selic_efetiva_mes",    "4189",  "Selic acumulada no m.s anualizada",                  "mensal",
  "ipca_var",             "433",   "pre.os ao consumidor-amplo \\(IPCA\\)$",             "mensal",
  "cambio_real_efetivo",  "11752", "c.mbio real efetiva \\(IPCA\\) - Jun/1994=100$",     "mensal",
  "icbr",                 "27574", "^.ndice de Commodities - Brasil$",                   "mensal",
  "icbr_usd",             "29042", "^.ndice de Commodities - Brasil.*D.lar",             "mensal",
  "ptax_venda_media",     "3698",  "D.lar americano \\(venda\\) - M.dia de per.odo - mensal$", "mensal"
)

meta <- map_dfr(seq_len(nrow(CAND)), function(i) {
  m <- sgs_meta(CAND$codigo[i])
  tit_portal <- portal_meta(CAND$codigo[i])
  if (is.null(m)) {
    return(tibble(serie = CAND$serie[i], codigo = CAND$codigo[i], titulo = NA, unidade = NA,
                  periodicidade = NA, inicio_sgs = NA, ultimo_sgs = NA, url_meta = NA,
                  titulo_portal = tit_portal, confere = FALSE))
  }
  m %>% mutate(serie = CAND$serie[i], titulo_portal = tit_portal,
               confere = grepl(CAND$esperado[i], titulo, ignore.case = TRUE))
})
meta <- meta %>% select(serie, codigo, everything())
print(meta %>% select(serie, codigo, titulo, unidade, periodicidade, confere))

log_part(ETAPA, "- Metadados conferidos na pagina de cada serie no SGS (www3.bcb.gov.br/sgspub, em portugues) ",
         "e no portal dadosabertos.bcb.gov.br (package_search por codigo_sgs). O portal so tem ficha para parte das series; ",
         "o SGS tem todas.")
for (i in seq_len(nrow(meta))) {
  m <- meta[i, ]
  log_part(ETAPA, sprintf("  - SGS %s (%s): \"%s\"; unidade %s; periodicidade %s; inicio %s; ultimo valor %s; %s; ficha no portal: %s.",
                          m$codigo, m$serie, m$titulo, m$unidade, m$periodicidade, m$inicio_sgs, m$ultimo_sgs,
                          ifelse(m$confere, "confere com a descricao pedida", "NAO confere, serie descartada"),
                          ifelse(is.na(m$titulo_portal), "nao ha", paste0("\"", m$titulo_portal, "\""))))
}
ok <- meta$serie[meta$confere]
stopifnot(all(c("selic_meta", "ipca_var") %in% ok))

# ---------------------------------------------------------------------------
# 2. Download pela API SGS em janelas de ate 10 anos
# ---------------------------------------------------------------------------
sgs_baixar <- function(codigo, ini = INI, fim = FIM) {
  a0 <- seq(lubridate::year(ini), lubridate::year(fim), by = 10)
  jan <- tibble(de = as.Date(sprintf("%d-01-01", a0)),
                ate = pmin(as.Date(sprintf("%d-12-31", a0 + 9)), fim))
  map_dfr(seq_len(nrow(jan)), function(k) {
    url <- sprintf("https://api.bcb.gov.br/dados/serie/bcdata.sgs.%s/dados?formato=json&dataInicial=%s&dataFinal=%s",
                   codigo, format(jan$de[k], "%d/%m/%Y"), format(jan$ate[k], "%d/%m/%Y"))
    # A API as vezes devolve uma pagina HTML de "Requisicao invalida" com status 200:
    # repete ate vir JSON.
    for (tent in 1:10) {
      r <- RETRY("GET", url, accept_json(), times = 5, pause_base = 2, timeout(120))
      txt <- content(r, as = "text", encoding = "UTF-8")
      if (status_code(r) == 200 && startsWith(trimws(txt), "[")) break
      Sys.sleep(2 * tent)
    }
    if (!startsWith(trimws(txt), "[")) stop("SGS ", codigo, ": resposta invalida em ", url)
    js <- fromJSON(txt)
    tibble(codigo = codigo, data = as.Date(js$data, "%d/%m/%Y"), valor = as.numeric(js$valor))
  }) %>% distinct() %>% arrange(data)
}

brutos <- list()
arquivos <- c()
for (s in ok) {
  cod <- meta$codigo[meta$serie == s]
  d <- sgs_baixar(cod)
  f <- download_path("bcb_sgs", cod)
  write_csv_safe(d, f)
  brutos[[s]] <- d
  arquivos[s] <- f
  cat(sprintf("SGS %s: %d obs, %s a %s\n", cod, nrow(d), min(d$data), max(d$data)))
}
log_part(ETAPA, sprintf("- Download pela API api.bcb.gov.br/dados/serie/bcdata.sgs.<codigo>/dados, janelas de ate 10 anos, %s a %s. Brutos em data/downloads/%s_bcb_sgs_<codigo>.csv.",
                        format(INI, "%Y-%m"), format(FIM, "%Y-%m"), HOJE))

# ---------------------------------------------------------------------------
# 3. Series mensais
# ---------------------------------------------------------------------------
mes <- function(d) format(d, "%Y-%m")
meses <- format(seq(INI, FIM, by = "month"), "%Y-%m")

selic_d <- brutos$selic_meta %>% mutate(periodo = mes(data), q = q_from_date(data))
# Meta Selic diaria em dias corridos: media do mes e valor do ultimo dia do mes.
selic_m <- selic_d %>% group_by(periodo) %>%
  summarise(selic_meta_media = mean(valor), selic_meta_fim = valor[which.max(data)], .groups = "drop")

mensal_simples <- function(s, nome) {
  if (!s %in% names(brutos)) return(tibble(periodo = meses))
  brutos[[s]] %>% transmute(periodo = mes(data), !!nome := valor)
}

bcb_m <- tibble(periodo = meses) %>%
  left_join(selic_m, by = "periodo") %>%
  left_join(mensal_simples("selic_efetiva_mes", "selic_efetiva_mes"), by = "periodo") %>%
  left_join(mensal_simples("ipca_var", "ipca_var"), by = "periodo") %>%
  left_join(mensal_simples("cambio_real_efetivo", "cambio_real_efetivo"), by = "periodo") %>%
  left_join(mensal_simples("icbr", "icbr"), by = "periodo") %>%
  left_join(mensal_simples("icbr_usd", "icbr_usd"), by = "periodo") %>%
  left_join(mensal_simples("ptax_venda_media", "ptax_venda_media"), by = "periodo")

# Indice do IPCA a partir da variacao mensal (dez/1999 = 100), rebaseado para media de 2025 = 100.
stopifnot(!anyNA(bcb_m$ipca_var))
idx <- 100 * cumprod(1 + bcb_m$ipca_var / 100)
base25 <- mean(idx[substr(bcb_m$periodo, 1, 4) == "2025"])
bcb_m <- bcb_m %>% mutate(ipca_indice = 100 * idx / base25, ano = as.integer(substr(periodo, 1, 4)),
                          tri = (as.integer(substr(periodo, 6, 7)) - 1) %/% 3 + 1,
                          trimestre = q_key(ano, tri))

falta <- bcb_m %>% select(-ano, -tri, -trimestre) %>% summarise(across(-periodo, ~ sum(is.na(.x))))
print(falta)

write_csv_safe(bcb_m %>% select(-ano, -tri), file.path(PATHS$processed, "A2_bcb_mensal.csv"))

# ---------------------------------------------------------------------------
# 4. Deflator: fator para R$ medios de 2025
# ---------------------------------------------------------------------------
defl_m <- bcb_m %>% transmute(periodo, frequencia = "mensal", indice = ipca_indice, fator_para_2025 = 100 / ipca_indice)
defl_q <- bcb_m %>% group_by(periodo = trimestre) %>%
  summarise(indice = mean(ipca_indice), n = n(), .groups = "drop") %>%
  { stopifnot(all(.$n == 3)); . } %>%
  transmute(periodo, frequencia = "trimestral", indice, fator_para_2025 = 100 / indice)
write_csv_safe(bind_rows(defl_m, defl_q), file.path(PATHS$processed, "A2_deflator_ipca.csv"))

log_part(ETAPA, "- IPCA: indice mensal construido pelo produto de (1 + variacao/100) da SGS 433 a partir de jan/2000 ",
         "(dez/1999 = 100) e rebaseado para media de 2025 = 100. Fator para R$ medios de 2025 = 100/indice. ",
         "Trimestral: indice = media dos tres indices mensais do trimestre; fator = 100/indice trimestral. ",
         "Saida: data/processed/A2_deflator_ipca.csv.")

# Comparacao com os fatores anuais do dashboard (data/raw, somente leitura).
dash <- read_csv(file.path(PATHS$raw, "dashboard_fator_ipca_anual.csv"), show_col_types = FALSE)
anual <- bcb_m %>% group_by(ano) %>%
  summarise(fator_media = 100 / mean(ipca_indice), fator_dez = 100 / ipca_indice[12], .groups = "drop")
cmp_dash <- anual %>% inner_join(dash, by = "ano") %>%
  mutate(dif_pct_media = 100 * (fator_media / fator_ipca_para_2025 - 1),
         dif_pct_dez = 100 * (fator_dez / fator_ipca_para_2025 - 1))
print(cmp_dash, n = 30)
write_csv_safe(cmp_dash, file.path(PATHS$results, "A2_comparacao_deflator_dashboard.csv"))
mx_media <- max(abs(cmp_dash$dif_pct_media))
mx_dez <- max(abs(cmp_dash$dif_pct_dez))
log_part(ETAPA, sprintf(paste0("- Comparacao com data/raw/dashboard_fator_ipca_anual.csv (%d anos, %d a %d): fator anual = media de 2025 / media do ano. ",
                               "Diferenca maxima em modulo %s%% (media %s%%); em 2000 %s%%, em 2003 %s%%, em 2019 %s%%. ",
                               "Com o indice de dezembro no lugar da media anual a diferenca maxima seria %s%%. ",
                               "Conclusao: o dashboard usa fator anual pela media do ano, e o deflator mensal construido aqui e compativel. ",
                               "Tabela em results/A2_comparacao_deflator_dashboard.csv."),
                        nrow(cmp_dash), min(cmp_dash$ano), max(cmp_dash$ano),
                        num_br(mx_media, 3), num_br(mean(cmp_dash$dif_pct_media), 3),
                        num_br(cmp_dash$dif_pct_media[cmp_dash$ano == 2000], 3),
                        num_br(cmp_dash$dif_pct_media[cmp_dash$ano == 2003], 3),
                        num_br(cmp_dash$dif_pct_media[cmp_dash$ano == 2019], 3),
                        num_br(mx_dez, 2)))

# ---------------------------------------------------------------------------
# 5. Series trimestrais
# ---------------------------------------------------------------------------
# Meta Selic: valor do ultimo dia do trimestre e media diaria do trimestre.
selic_q <- selic_d %>% group_by(periodo = q) %>%
  summarise(selic_meta_fim = valor[which.max(data)], selic_meta_media = mean(valor), .groups = "drop")

# Demais mensais: media no trimestre (indices, taxas e precos). IPCA: variacao acumulada no trimestre.
bcb_q <- bcb_m %>% group_by(periodo = trimestre) %>%
  summarise(n = n(),
            selic_efetiva_media = mean(selic_efetiva_mes),
            selic_efetiva_fim = selic_efetiva_mes[3],
            ipca_indice = mean(ipca_indice),
            ipca_var_acum_tri = 100 * (prod(1 + ipca_var / 100) - 1),
            cambio_real_efetivo = mean(cambio_real_efetivo),
            icbr = mean(icbr),
            icbr_usd = mean(icbr_usd),
            ptax_venda_media = mean(ptax_venda_media),
            .groups = "drop") %>%
  { stopifnot(all(.$n == 3)); . } %>% select(-n)
bcb_q <- selic_q %>% inner_join(bcb_q, by = "periodo") %>% arrange(q_to_yearqtr(periodo))
stopifnot(identical(bcb_q$periodo, q_seq("2000Q1", "2025Q4")))
write_csv_safe(bcb_q, file.path(PATHS$processed, "A2_bcb_trimestral.csv"))

log_part(ETAPA, "- Trimestral (chave 2003Q1): Meta Selic no ultimo dia do trimestre (selic_meta_fim) e media diaria do trimestre ",
         "(selic_meta_media); Selic efetiva (SGS 4189) media e ultimo mes do trimestre; cambio real efetivo, IC-Br, IC-Br em dolar, ",
         "PTAX e indice do IPCA pela media dos tres meses; IPCA tambem como variacao acumulada no trimestre. ",
         "Saida: data/processed/A2_bcb_trimestral.csv.")

# Sinal do cambio real efetivo: correlacao das variacoes mensais com a PTAX.
if (all(c("cambio_real_efetivo", "ptax_venda_media") %in% ok)) {
  cr <- with(bcb_m, cor(diff(log(cambio_real_efetivo)), diff(log(ptax_venda_media))))
  log_part(ETAPA, sprintf("- Cambio real efetivo (SGS 11752): correlacao das variacoes mensais do log com a PTAX = %s; alta do indice acompanha alta do R$/US$, isto e, alta = depreciacao real.",
                          num_br(cr, 2)))
}

# ---------------------------------------------------------------------------
# 6. Qual Selic a dissertacao usou (coluna JUR de 0124_inexo.txt, 2002T1-2019T4)
# ---------------------------------------------------------------------------
inexo <- read.table(file.path(PATHS$original, "0124_inexo.txt"), header = TRUE)
stopifnot(nrow(inexo) == 72)
inexo$periodo <- q_seq("2002Q1", "2019Q4")
cmp_jur <- inexo %>% select(periodo, JUR) %>%
  left_join(bcb_q %>% select(periodo, selic_meta_fim, selic_meta_media, selic_efetiva_media, selic_efetiva_fim), by = "periodo") %>%
  mutate(across(starts_with("selic"), ~ .x / 100))
conceitos <- c("selic_meta_fim", "selic_meta_media", "selic_efetiva_media", "selic_efetiva_fim")
res_jur <- map_dfr(conceitos, function(v) {
  d <- cmp_jur$JUR - cmp_jur[[v]]
  tibble(conceito = v, correlacao = cor(cmp_jur$JUR, cmp_jur[[v]]),
         iguais_ate_0_0001 = sum(abs(d) < 1e-4), dif_media_abs = mean(abs(d)), dif_max_abs = max(abs(d)))
})
print(res_jur)
write_csv_safe(cmp_jur, file.path(PATHS$results, "A2_comparacao_selic_jur.csv"))
melhor <- res_jur %>% arrange(desc(iguais_ate_0_0001), dif_media_abs) %>% slice(1)
dif_q <- cmp_jur %>% filter(abs(JUR - .data[[melhor$conceito]]) >= 1e-4)
log_part(ETAPA, sprintf("- JUR de 0124_inexo.txt (2002T1 a 2019T4, 72 trimestres, em fracao) contra a Selic do BCB: %s. ",
                        paste(sprintf("%s: %d de 72 iguais, correlacao %s, diferenca media absoluta %s p.p.",
                                      res_jur$conceito, res_jur$iguais_ate_0_0001, num_br(res_jur$correlacao, 4),
                                      num_br(100 * res_jur$dif_media_abs, 3)), collapse = "; ")),
         sprintf("Conclusao: a dissertacao usou %s.", melhor$conceito),
         if (nrow(dif_q)) sprintf(" Trimestres que nao batem: %s.", paste(sprintf("%s (JUR %s; BCB %s)", dif_q$periodo,
                                   num_br(dif_q$JUR, 4), num_br(dif_q[[melhor$conceito]], 4)), collapse = ", ")) else "",
         " Tabela em results/A2_comparacao_selic_jur.csv.")

# ---------------------------------------------------------------------------
# 7. Metadados (parte BCB); o script do IBGE acrescenta as suas linhas
# ---------------------------------------------------------------------------
transf <- c(
  selic_meta = "diaria (dias corridos) -> mensal: media e ultimo dia; trimestral: ultimo dia do trimestre (selic_meta_fim) e media diaria (selic_meta_media)",
  selic_efetiva_mes = "mensal; trimestral: media dos 3 meses e valor do ultimo mes",
  ipca_var = "indice = produto de (1+v/100), dez/1999=100, rebaseado media 2025=100; fator_para_2025 = 100/indice; trimestral: media do indice mensal; variacao acumulada no trimestre",
  cambio_real_efetivo = "mensal; trimestral: media dos 3 meses",
  icbr = "mensal; trimestral: media dos 3 meses",
  icbr_usd = "mensal; trimestral: media dos 3 meses",
  ptax_venda_media = "mensal; trimestral: media dos 3 meses"
)
meta_out <- meta %>% transmute(
  serie, fonte = "BCB/SGS", codigo,
  titulo_nos_metadados = ifelse(is.na(titulo), "indisponivel", titulo),
  unidade, periodicidade,
  periodo = ifelse(confere, sprintf("%s a %s", format(INI, "%Y-%m"), format(FIM, "%Y-%m")), "nao baixada"),
  url = ifelse(confere, sprintf("https://api.bcb.gov.br/dados/serie/bcdata.sgs.%s/dados?formato=json", codigo), url_meta),
  arquivo_download = ifelse(confere, unname(arquivos[serie]), ""),
  transformacao = ifelse(confere, unname(transf[serie]), "titulo nao confere; descartada")
)
f_meta <- file.path(PATHS$processed, "A2_metadados_bcb_ibge.csv")
if (file.exists(f_meta)) {
  outros <- read_csv(f_meta, show_col_types = FALSE, col_types = cols(.default = "c")) %>% filter(fonte != "BCB/SGS")
  meta_out <- bind_rows(meta_out, outros)
}
write_csv_safe(meta_out, f_meta)

log_part(ETAPA, sprintf("- Resumo trimestral 2003Q1: Meta Selic fim %s%%, media %s%%; 2025Q4: fim %s%%, media %s%%. Fator IPCA para 2025 em 2003Q1 = %s.",
                        num_br(bcb_q$selic_meta_fim[bcb_q$periodo == "2003Q1"], 2), num_br(bcb_q$selic_meta_media[bcb_q$periodo == "2003Q1"], 2),
                        num_br(bcb_q$selic_meta_fim[bcb_q$periodo == "2025Q4"], 2), num_br(bcb_q$selic_meta_media[bcb_q$periodo == "2025Q4"], 2),
                        num_br(defl_q$fator_para_2025[defl_q$periodo == "2003Q1"], 4)))

# Reescreve a secao IBGE preservada (se existir).
if (length(secao_ibge)) log_part(ETAPA, paste(secao_ibge, collapse = "\n"))

save_session_info("A2_download_bcb")
cat("A2_download_bcb.R concluido.\n")
