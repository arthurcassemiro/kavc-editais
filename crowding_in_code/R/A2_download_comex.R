# Etapa A2, parte Comex Stat: importacoes mensais de bens de capital (CGCE nivel 1),
# US$ FOB e quilograma liquido, 1997-2025, e PTAX media mensal (BCB/SGS) para converter em R$.
# Saidas: data/processed/A2_comex_mensal.csv, A2_comex_trimestral.csv e as linhas Comex/PTAX
# de data/processed/A2_metadados_ipea_comex_bndes.csv.
# Rodar da raiz do projeto: Rscript R/A2_download_comex.R

source("R/00_setup.R")
source("R/A2_util_ipea_comex_bndes.R")
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

MARCA <- "#### Comex Stat"
log_secao_inicio(MARCA, "A2_download_comex")

API <- "https://api-comexstat.mdic.gov.br"
DE <- "1997-01"
ATE <- "2025-12"

# A API responde 429 ("tente novamente em 10 segundos") quando o limite de requisicoes
# e atingido; o limite parece compartilhado pelo IP de saida. Repete com espera crescente.
comex_req <- function(metodo, rota, corpo = NULL, max_tent = 60) {
  url <- paste0(API, rota)
  for (k in seq_len(max_tent)) {
    r <- if (metodo == "GET") {
      try(GET(url, accept_json(), timeout(120)), silent = TRUE)
    } else {
      try(POST(url, body = toJSON(corpo, auto_unbox = TRUE), content_type_json(), accept_json(), timeout(300)),
          silent = TRUE)
    }
    if (!inherits(r, "try-error") && status_code(r) == 200) {
      return(content(r, as = "text", encoding = "UTF-8"))
    }
    st <- if (inherits(r, "try-error")) "erro de conexao" else status_code(r)
    espera <- min(15 * k, 90)
    message(sprintf("Comex %s %s: status %s; tentativa %d, espera %ds", metodo, rota, st, k, espera))
    Sys.sleep(espera)
  }
  stop("Comex Stat: sem resposta valida em ", url)
}

# ---------------------------------------------------------------------------
# 1. Tabelas auxiliares: codigo da categoria bens de capital e metricas
# ---------------------------------------------------------------------------
txt_f1 <- comex_req("GET", "/general/filters/BECLevel1?language=pt")
f_f1 <- download_path("comexstat", "filtro_BECLevel1", "json")
writeLines(txt_f1, f_f1)
cgce1 <- fromJSON(txt_f1)$data[[1]]
print(cgce1)
cod_bk <- cgce1$id[grepl("^BENS DE CAPITAL \\(BK\\)$", cgce1$noCgceN1pt)]
stopifnot(length(cod_bk) == 1)

txt_cl <- comex_req("GET", "/tables/classifications")
f_cl <- download_path("comexstat", "tabela_classificacoes_cgce", "json")
writeLines(txt_cl, f_cl)
cl <- fromJSON(txt_cl)$data$list
cl_bk <- cl %>% filter(coBECLevel1 == cod_bk) %>% distinct(coBECLevel2, BECLevel2, coBECLevel3, BECLevel3)
print(cl_bk)

txt_me <- comex_req("GET", "/general/metrics?language=pt")
f_me <- download_path("comexstat", "metricas", "json")
writeLines(txt_me, f_me)
metricas <- fromJSON(txt_me)$data$list
tit_fob <- metricas$text[metricas$id == "metricFOB"]
tit_kg <- metricas$text[metricas$id == "metricKG"]
stopifnot(grepl("US\\$ FOB", tit_fob), grepl("Quilograma", tit_kg))

txt_up <- comex_req("GET", "/general/dates/updated")
atualizado <- fromJSON(txt_up)$data

lp("- Fonte: API do Comex Stat (", API, "). A pagina de documentacao (", API, "/docs) devolve 403 do Cloudflare ",
   "neste conteiner; as rotas foram conferidas nas proprias respostas da API (/general/filters, /general/metrics, ",
   "/tables/classifications).")
lp(sprintf("- Categoria conferida em /general/filters/BECLevel1 (filtro \"CGCE Nivel 1\"): codigo %s = \"%s\". Categorias de nivel 1 disponiveis: %s.",
           cod_bk, cgce1$text[cgce1$id == cod_bk], paste(cgce1$text, collapse = "; ")))
lp(sprintf("- Subcategorias de BK em /tables/classifications: %s.",
           paste(sprintf("nivel 2 %s = \"%s\"", unique(cl_bk$coBECLevel2), unique(cl_bk$BECLevel2)), collapse = "; ")))
lp(sprintf("- Metricas conferidas em /general/metrics: metricFOB = \"%s\"; metricKG = \"%s\". Base atualizada em %s (ultimo mes %s/%s).",
           tit_fob, tit_kg, atualizado$updated, atualizado$monthNumber, atualizado$year))

# ---------------------------------------------------------------------------
# 2. Importacoes mensais de BK: nivel 1 e abertura em nivel 2
# ---------------------------------------------------------------------------
consulta <- function(detalhe) {
  list(flow = "import", monthDetail = TRUE, period = list(from = DE, to = ATE),
       filters = list(list(filter = "BECLevel1", values = list(cod_bk))),
       details = list(detalhe), metrics = list("metricFOB", "metricKG"))
}
baixar_general <- function(detalhe, nome) {
  txt <- comex_req("POST", "/general?language=pt", consulta(detalhe))
  f <- download_path("comexstat", nome, "json")
  writeLines(txt, f)
  js <- fromJSON(txt)
  stopifnot(isTRUE(js$success))
  list(dados = as_tibble(js$data$list), arquivo = f)
}
Sys.sleep(15)
n1 <- baixar_general("BECLevel1", "import_cgce_n1_bk_mensal")
Sys.sleep(15)
n2 <- baixar_general("BECLevel2", "import_cgce_n2_bk_mensal")

limpa <- function(d, cod) {
  d %>% transmute(periodo = sprintf("%s-%s", year, monthNumber), codigo = .data[[cod]],
                  fob_usd = as.numeric(metricFOB), kg = as.numeric(metricKG))
}
m1 <- limpa(n1$dados, "coBECLevel1")
m2 <- limpa(n2$dados, "coBECLevel2")
meses <- format(seq(as.Date(paste0(DE, "-01")), as.Date(paste0(ATE, "-01")), by = "month"), "%Y-%m")
stopifnot(setequal(m1$periodo, meses), !anyDuplicated(m1$periodo))

# Conferencia: nivel 1 = soma do nivel 2.
chk <- m2 %>% group_by(periodo) %>% summarise(fob2 = sum(fob_usd), kg2 = sum(kg), .groups = "drop") %>%
  inner_join(m1, by = "periodo")
dif_fob <- max(abs(chk$fob2 / chk$fob_usd - 1))
dif_kg <- max(abs(chk$kg2 / chk$kg - 1))
lp(sprintf("- Consulta POST /general: flow = import, monthDetail = true, periodo %s a %s, filtro BECLevel1 = %s, metricas metricFOB e metricKG; uma consulta com detalhe BECLevel1 e outra com BECLevel2. %d meses, sem lacunas. A soma do nivel 2 reproduz o nivel 1 (diferenca relativa maxima %s no FOB e %s no kg). Brutos em %s e %s.",
           DE, ATE, cod_bk, nrow(m1), format(dif_fob, digits = 2), format(dif_kg, digits = 2), n1$arquivo, n2$arquivo))

# ---------------------------------------------------------------------------
# 3. PTAX media mensal (BCB/SGS): metadados e download
# ---------------------------------------------------------------------------
COD_PTAX <- "3698"
h_sgs <- handle("https://www3.bcb.gov.br")
invisible(RETRY("GET", "https://www3.bcb.gov.br/sgspub/index.jsp?idIdioma=P", handle = h_sgs, times = 3))
url_meta <- sprintf(paste0("https://www3.bcb.gov.br/sgspub/consultarvalores/consultarValoresSeries.do?",
                           "method=consultarGraficoPorId&hdOidSeriesSelecionadas=%s"), COD_PTAX)
r <- RETRY("GET", url_meta, handle = h_sgs, times = 3, timeout(60))
txt <- content(r, as = "text", encoding = "latin1")
cel <- regmatches(txt, gregexpr('<td[^>]*class="txtMenor1"[^>]*>[^<]*</td>', txt))[[1]]
v <- trimws(gsub("<[^>]+>", "", cel[1:6]))
per_ptax <- sub('.*title="([^"]*)".*', "\\1", cel[4])
meta_ptax <- tibble(codigo = v[1], titulo = v[2], unidade = v[3], periodicidade = per_ptax, inicio = v[5], ultimo = v[6])
print(meta_ptax)
ok_ptax <- meta_ptax$codigo == COD_PTAX &&
  grepl("D.lar americano \\(venda\\) - M.dia de per.odo - mensal$", meta_ptax$titulo)
stopifnot(ok_ptax)

url_ptax <- sprintf("https://api.bcb.gov.br/dados/serie/bcdata.sgs.%s/dados?formato=json&dataInicial=01/01/1997&dataFinal=31/12/2025", COD_PTAX)
for (tent in 1:10) {
  r <- RETRY("GET", url_ptax, accept_json(), times = 5, pause_base = 2, timeout(120))
  txt <- content(r, as = "text", encoding = "UTF-8")
  if (status_code(r) == 200 && startsWith(trimws(txt), "[")) break
  Sys.sleep(2 * tent)
}
js <- fromJSON(txt)
ptax <- tibble(data = as.Date(js$data, "%d/%m/%Y"), ptax = as.numeric(js$valor)) %>%
  transmute(periodo = format(data, "%Y-%m"), ptax_venda_media = ptax)
f_ptax <- download_path("bcb_sgs_ptax_comex", COD_PTAX)
write_csv_safe(ptax, f_ptax)
stopifnot(all(meses %in% ptax$periodo))
lp(sprintf("- PTAX: SGS %s, titulo nos metadados do SGS \"%s\", unidade %s, periodicidade %s (inicio %s). Confere com a descricao pedida (media mensal, venda). Baixada de api.bcb.gov.br para %s. Conversao: R$ = US$ FOB do mes x PTAX media do mes (venda).",
           COD_PTAX, meta_ptax$titulo, meta_ptax$unidade, meta_ptax$periodicidade, meta_ptax$inicio, f_ptax))

# Coerencia com o download da parte BCB, se existir (arquivo de outra etapa, so leitura).
f_bcb <- download_path("bcb_sgs", COD_PTAX)
if (file.exists(f_bcb)) {
  b <- read_csv(f_bcb, show_col_types = FALSE) %>% transmute(periodo = format(data, "%Y-%m"), v = valor)
  cmpb <- inner_join(ptax, b, by = "periodo")
  lp(sprintf("- A PTAX baixada aqui coincide com %s em %d de %d meses comuns.", f_bcb,
             sum(abs(cmpb$ptax_venda_media - cmpb$v) < 1e-9), nrow(cmpb)))
}

# ---------------------------------------------------------------------------
# 4. Series mensais e trimestrais
# ---------------------------------------------------------------------------
comex_m <- tibble(periodo = meses) %>%
  left_join(m1 %>% transmute(periodo, imp_bk_fob_usd = fob_usd, imp_bk_kg = kg), by = "periodo") %>%
  left_join(m2 %>% filter(codigo == "11") %>% transmute(periodo, imp_bk_exc_transp_fob_usd = fob_usd,
                                                       imp_bk_exc_transp_kg = kg), by = "periodo") %>%
  left_join(m2 %>% filter(codigo == "12") %>% transmute(periodo, imp_bk_transp_fob_usd = fob_usd,
                                                       imp_bk_transp_kg = kg), by = "periodo") %>%
  mutate(across(-periodo, ~ replace_na(.x, 0))) %>%
  left_join(ptax, by = "periodo") %>%
  mutate(imp_bk_fob_rs = imp_bk_fob_usd * ptax_venda_media,
         imp_bk_exc_transp_fob_rs = imp_bk_exc_transp_fob_usd * ptax_venda_media,
         imp_bk_transp_fob_rs = imp_bk_transp_fob_usd * ptax_venda_media,
         trimestre = q_key(as.integer(substr(periodo, 1, 4)), (as.integer(substr(periodo, 6, 7)) - 1) %/% 3 + 1))
stopifnot(!anyNA(comex_m))
write_csv_safe(comex_m, file.path(PATHS$processed, "A2_comex_mensal.csv"))

fun <- c(imp_bk_fob_usd = "soma", imp_bk_kg = "soma", imp_bk_exc_transp_fob_usd = "soma",
         imp_bk_exc_transp_kg = "soma", imp_bk_transp_fob_usd = "soma", imp_bk_transp_kg = "soma",
         ptax_venda_media = "media", imp_bk_fob_rs = "soma", imp_bk_exc_transp_fob_rs = "soma",
         imp_bk_transp_fob_rs = "soma")
comex_q <- mensal_para_trimestral(comex_m %>% select(-trimestre), fun) %>%
  select(trimestre, all_of(names(fun))) %>%
  mutate(imp_bk_usd_por_kg = imp_bk_fob_usd / imp_bk_kg)
stopifnot(identical(comex_q$trimestre, q_seq("1997Q1", "2025Q4")), !anyNA(comex_q))
write_csv_safe(comex_q, file.path(PATHS$processed, "A2_comex_trimestral.csv"))

lp("- Mensal (data/processed/A2_comex_mensal.csv): US$ FOB, kg e R$ nominais (US$ x PTAX do mes) para BK total (CGCE 1), ",
   "BK exceto equipamentos de transporte industrial (CGCE 11) e equipamentos de transporte industrial (CGCE 12). ",
   "Meses sem registro numa subcategoria viram zero. Trimestral (A2_comex_trimestral.csv): soma dos tres meses para ",
   "US$, R$ e kg (fluxos); PTAX pela media dos tres meses; US$/kg = FOB/kg do trimestre. Valores nominais, sem ajuste sazonal.")

anual <- comex_m %>% group_by(ano = substr(periodo, 1, 4)) %>%
  summarise(usd_bi = sum(imp_bk_fob_usd) / 1e9, rs_bi = sum(imp_bk_fob_rs) / 1e9, .groups = "drop")
pega <- function(a, v) anual[[v]][anual$ano == a]
lp(sprintf("- Totais anuais de BK: 1997 US$ %s bi (R$ %s bi); 2003 US$ %s bi (R$ %s bi); 2013 US$ %s bi (R$ %s bi); 2019 US$ %s bi (R$ %s bi); 2025 US$ %s bi (R$ %s bi).",
           num_br(pega("1997", "usd_bi"), 1), num_br(pega("1997", "rs_bi"), 1),
           num_br(pega("2003", "usd_bi"), 1), num_br(pega("2003", "rs_bi"), 1),
           num_br(pega("2013", "usd_bi"), 1), num_br(pega("2013", "rs_bi"), 1),
           num_br(pega("2019", "usd_bi"), 1), num_br(pega("2019", "rs_bi"), 1),
           num_br(pega("2025", "usd_bi"), 1), num_br(pega("2025", "rs_bi"), 1)))

# Conferencia com o valor FOB de BK da Funcex (Ipeadata), se a parte Ipea ja rodou.
f_ipea <- file.path(PATHS$processed, "A2_ipea_mensal.csv")
if (file.exists(f_ipea)) {
  ip <- read_csv(f_ipea, show_col_types = FALSE)
  if ("funcex_imp_bk_valor_usd_mi" %in% names(ip)) {
    cf <- comex_m %>% select(periodo, imp_bk_fob_usd) %>%
      inner_join(ip %>% select(periodo, funcex_imp_bk_valor_usd_mi), by = "periodo") %>%
      filter(!is.na(funcex_imp_bk_valor_usd_mi))
    rz <- cf$imp_bk_fob_usd / 1e6 / cf$funcex_imp_bk_valor_usd_mi
    lp(sprintf("- Contra o valor FOB de BK da Funcex (FUNCEX12_MDVBKGCE12, Ipeadata), %d meses comuns (%s a %s): razao Comex/Funcex media %s (minimo %s, maximo %s); correlacao das variacoes mensais do log %s.",
               nrow(cf), min(cf$periodo), max(cf$periodo), num_br(mean(rz), 3), num_br(min(rz), 3), num_br(max(rz), 3),
               num_br(cor(diff(log(cf$imp_bk_fob_usd)), diff(log(cf$funcex_imp_bk_valor_usd_mi))), 3)))
  }
}

# ---------------------------------------------------------------------------
# 5. Metadados
# ---------------------------------------------------------------------------
per <- sprintf("%s a %s", DE, ATE)
tit_bk <- cgce1$text[cgce1$id == cod_bk]
meta <- tribble(
  ~serie, ~codigo, ~titulo_nos_metadados, ~unidade, ~arquivo_download, ~transformacao,
  "imp_bk_fob_usd", sprintf("CGCE N1 %s, metricFOB", cod_bk), sprintf("%s; %s", tit_bk, tit_fob), "US$ FOB", n1$arquivo,
  "mensal; trimestral = soma dos 3 meses",
  "imp_bk_kg", sprintf("CGCE N1 %s, metricKG", cod_bk), sprintf("%s; %s", tit_bk, tit_kg), "kg liquido", n1$arquivo,
  "mensal; trimestral = soma dos 3 meses",
  "imp_bk_exc_transp_fob_usd / _kg", "CGCE N2 11, metricFOB e metricKG",
  unique(cl_bk$BECLevel2[cl_bk$coBECLevel2 == "11"]), "US$ FOB; kg liquido", n2$arquivo,
  "mensal; trimestral = soma dos 3 meses",
  "imp_bk_transp_fob_usd / _kg", "CGCE N2 12, metricFOB e metricKG",
  unique(cl_bk$BECLevel2[cl_bk$coBECLevel2 == "12"]), "US$ FOB; kg liquido", n2$arquivo,
  "mensal; trimestral = soma dos 3 meses",
  "imp_bk_fob_rs (e subcategorias _rs)", sprintf("CGCE N1 %s x SGS %s", cod_bk, COD_PTAX),
  sprintf("%s; %s x %s", tit_bk, tit_fob, meta_ptax$titulo), "R$ nominais", paste(n1$arquivo, f_ptax, sep = "; "),
  "US$ FOB do mes x PTAX media do mes; trimestral = soma dos 3 meses"
) %>% mutate(fonte = "Comex Stat/MDIC", periodicidade = "mensal", periodo = per,
             url = paste0(API, "/general (POST); ", API, "/general/filters/BECLevel1"))
meta <- bind_rows(meta, tibble(
  serie = "ptax_venda_media", fonte = "BCB/SGS", codigo = COD_PTAX, titulo_nos_metadados = meta_ptax$titulo,
  unidade = meta_ptax$unidade, periodicidade = meta_ptax$periodicidade, periodo = per, url = url_ptax,
  arquivo_download = f_ptax, transformacao = "mensal; trimestral = media dos 3 meses; usada para converter US$ em R$"
))
gravar_metadados(meta, c("Comex Stat/MDIC", "BCB/SGS"))

log_secao_fim()
save_session_info("A2_download_comex")
cat("A2_download_comex.R concluido.\n")
