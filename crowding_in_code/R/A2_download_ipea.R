# Etapa A2, parte Ipeadata: Indicador Ipea mensal de FBCF (total, maquinas e equipamentos,
# construcao civil, outros; com e sem ajuste sazonal), consumo aparente de bens de capital,
# importacoes de bens de capital da Funcex, Brent (EIA) e busca do indicador de incerteza.
# Compara a serie de M&E do Ipea com o PVD da dissertacao.
# Saidas: data/processed/A2_ipea_mensal.csv, A2_ipea_trimestral.csv, results/A2_comparacao_pvd_ipea.csv
# e as linhas Ipea de data/processed/A2_metadados_ipea_comex_bndes.csv.
# Rodar da raiz do projeto: Rscript R/A2_download_ipea.R

source("R/00_setup.R")
source("R/A2_util_ipea_comex_bndes.R")
suppressPackageStartupMessages({
  library(ipeadatar)
  library(readxl)
  library(httr)
})
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

MARCA <- "#### Ipeadata"
log_secao_inicio(MARCA, "A2_download_ipea")

sem_acento <- function(x) iconv(x, "UTF-8", "ASCII//TRANSLIT")
num_sci <- function(x) sub(".", ",", sprintf("%.1e", x), fixed = TRUE)

# ---------------------------------------------------------------------------
# 1. Catalogo do Ipeadata: busca das series candidatas
# ---------------------------------------------------------------------------
cat_ipea <- available_series(language = "br")
busca <- cat_ipea %>%
  filter(grepl("Indicador IPEA de FBCF|Consumo aparente - bens de capital|Importa.+es - bens de capital|Brent|incerteza",
               name, ignore.case = TRUE)) %>%
  mutate(across(everything(), as.character))
f_busca <- download_path("ipeadata", "catalogo_busca")
write_csv_safe(busca, f_busca)
print(busca %>% select(code, name, freq, status), n = 50)

fbcf_ipeadata <- busca %>% filter(grepl("Indicador IPEA de FBCF", name))
tem_me <- any(grepl("m.quinas|equipamentos", sem_acento(fbcf_ipeadata$name), ignore.case = TRUE))
incerteza <- busca %>% filter(grepl("incerteza", name, ignore.case = TRUE))
lp(sprintf("- Catalogo do Ipeadata (ipeadatar::available_series, %d series). Busca por \"Indicador IPEA de FBCF\", \"Consumo aparente - bens de capital\", \"Importacoes - bens de capital\", \"Brent\" e \"incerteza\": %d series, lista em %s.",
           nrow(cat_ipea), nrow(busca), f_busca))
lp(sprintf("- Indicador Ipea de FBCF no Ipeadata: %d series (%s). %s",
           nrow(fbcf_ipeadata), paste(fbcf_ipeadata$code, collapse = ", "),
           if (tem_me) "Ha serie de maquinas e equipamentos." else
             "So total e construcao civil, com e sem ajuste; maquinas e equipamentos e outros ativos nao estao no Ipeadata. Por isso as quatro componentes vem da planilha da Carta de Conjuntura (secao 2)."))

# Candidatos e padrao esperado no titulo; se o titulo nao bater, a serie e descartada.
CAND <- tribble(
  ~serie,                        ~codigo,                   ~esperado,                                                         ~fonte_esp, ~freq_esp,
  "ipeadata_fbcf_total_nsa",     "GAC12_INDFBCF12",         "^Indicador IPEA de FBCF - indice real \\(media 1995 = 100\\)$",   "IPEA",   "Mensal",
  "ipeadata_fbcf_total_sa",      "GAC12_INDFBCFDESSAZ12",   "^Indicador IPEA de FBCF - indice real dessazonalizado \\(media 1995 = 100\\)$", "IPEA", "Mensal",
  "ipeadata_fbcf_constr_nsa",    "GAC12_INDFBCFCC12",       "^Indicador IPEA de FBCF - construcao civil - indice real \\(media ?1995 = 100\\)$", "IPEA", "Mensal",
  "ipeadata_fbcf_constr_sa",     "GAC12_INDFBCFCCDESSAZ12", "^Indicador IPEA de FBCF - construcao civil - indice real dessazonalizado \\(media 1995 = 100\\)$", "IPEA", "Mensal",
  "ca_bk_nsa",                   "GAC12_FBKFCAMI12",        "^Consumo aparente - bens de capital - indice real \\(media 2012 = 100\\)$", "IPEA", "Mensal",
  "ca_bk_sa",                    "GAC12_FBKFCAMIDESSAZ12",  "^Consumo aparente - bens de capital - indice dessazonalizado \\(media 2012 = 100\\)$", "IPEA", "Mensal",
  "funcex_imp_bk_quantum",       "FUNCEX12_MDQBKGCE12",     "^Importacoes - bens de capital - quantum - indice \\(media 2018 = 100\\)", "Funcex", "Mensal",
  "funcex_imp_bk_preco",         "FUNCEX12_MDPBKGCE12",     "^Importacoes - bens de capital - precos - indice \\(media 2018 = 100\\)", "Funcex", "Mensal",
  "funcex_imp_bk_valor_usd_mi",  "FUNCEX12_MDVBKGCE12",     "^Importacoes - bens de capital - \\(FOB\\)",                     "Funcex", "Mensal",
  "brent_usd_barril",            "EIA366_PBRENT366",        "^Preco - petroleo bruto - Brent \\(FOB\\)$",                       "EIA",    "Diaria"
)

meta_ip <- metadata(CAND$codigo, language = "br") %>%
  mutate(across(everything(), as.character)) %>%
  transmute(codigo = code, titulo = name, comentario = comment, fonte_meta = source, freq = freq,
            unidade = trimws(paste(ifelse(is.na(unity), "", unity), ifelse(is.na(mf), "", mf))),
            atualizacao = lastupdate, status = status)
meta_ip <- CAND %>% left_join(meta_ip, by = "codigo") %>%
  mutate(confere = str_detect(sem_acento(titulo), esperado) & sem_acento(fonte_meta) == fonte_esp &
           sem_acento(freq) == freq_esp)
print(meta_ip %>% select(serie, codigo, titulo, fonte_meta, freq, unidade, confere))
for (i in seq_len(nrow(meta_ip))) {
  m <- meta_ip[i, ]
  lp(sprintf("  - %s: \"%s\"; fonte %s; periodicidade %s; unidade \"%s\"; atualizada em %s; %s.",
             m$codigo, sem_acento(m$titulo), m$fonte_meta, sem_acento(m$freq), sem_acento(m$unidade), m$atualizacao,
             ifelse(m$confere, "confere com a descricao pedida", "NAO confere, serie descartada")))
}
if (any(meta_ip$codigo == "EIA366_PBRENT366")) {
  cm <- meta_ip$comentario[meta_ip$codigo == "EIA366_PBRENT366"]
  lp(sprintf("  - Brent: o comentario dos metadados diz \"%s\" e aponta a tabela da EIA (eia.gov/dnav/pet). Candidata EIA confirmada; preco em US$ por barril.",
             sem_acento(substr(gsub("\\s+", " ", cm), 1, 150))))
}
ok <- meta_ip %>% filter(confere)

# ---------------------------------------------------------------------------
# 2. Planilha do Indicador Ipea de FBCF (Carta de Conjuntura)
# ---------------------------------------------------------------------------
URL_CARTA <- "https://www.ipea.gov.br/cartadeconjuntura/"
pag <- content(RETRY("GET", URL_CARTA, times = 3, timeout(60)), as = "text", encoding = "UTF-8")
links <- unique(regmatches(pag, gregexpr('https://www\\.ipea\\.gov\\.br/cartadeconjuntura/[^"]+', pag))[[1]])
url_xlsx <- links[grepl("Dados-Indicador-Ipea-FBCF.*\\.xlsx$", links)][1]
url_post <- links[grepl("indicador-ipea-mensal-de-fbcf-resultado", links) & !grepl("#", links)][1]
if (is.na(url_xlsx)) {
  pag <- content(RETRY("GET", paste0(URL_CARTA, "index.php/tag/fbcf/"), times = 3, timeout(60)), as = "text", encoding = "UTF-8")
  links <- unique(regmatches(pag, gregexpr('https://www\\.ipea\\.gov\\.br/cartadeconjuntura/[^"]+', pag))[[1]])
  url_xlsx <- links[grepl("Dados-Indicador-Ipea-FBCF.*\\.xlsx$", links)][1]
}
stopifnot(!is.na(url_xlsx))
url_pdf <- links[grepl("FBCF.*\\.pdf$", links)][1]
f_xlsx <- download_path("ipea_carta", "indicador_ipea_fbcf", "xlsx")
RETRY("GET", url_xlsx, write_disk(f_xlsx, overwrite = TRUE), times = 3, timeout(120))
f_pdf <- NA_character_
if (!is.na(url_pdf)) {
  f_pdf <- download_path("ipea_carta", "nota_indicador_ipea_fbcf", "pdf")
  RETRY("GET", url_pdf, write_disk(f_pdf, overwrite = TRUE), times = 3, timeout(120))
}

bruto <- read_excel(f_xlsx, sheet = 1, col_names = FALSE, .name_repair = "minimal")
titulo_planilha <- na.omit(unlist(bruto[1, ]))[1]
cab <- sem_acento(unlist(bruto[2, ]))
CAB_ESP <- c("Mes", "Construcao Civil", "Consumo Aparente de Maquinas e Equipamentos", "Consumo Aparente de Outros",
             "Indicador Ipea de FBCF", "Construcao Civil - com ajuste sazonal",
             "Consumo Aparente de Maquinas e Equipamentos - com ajuste sazonal",
             "Consumo Aparente de Outros - com ajuste sazonal", "Indicador Ipea de FBCF - com ajuste sazonal")
stopifnot(identical(unname(cab), CAB_ESP))
NOMES <- c("data", "fbcf_constr_nsa", "fbcf_me_nsa", "fbcf_outros_nsa", "fbcf_total_nsa",
           "fbcf_constr_sa", "fbcf_me_sa", "fbcf_outros_sa", "fbcf_total_sa")
carta <- bruto[-(1:2), ] %>% setNames(NOMES) %>%
  mutate(across(everything(), as.numeric)) %>%
  filter(!is.na(data)) %>%
  mutate(periodo = format(as.Date(data, origin = "1899-12-30"), "%Y-%m")) %>%
  select(periodo, all_of(NOMES[-1]))
stopifnot(!anyDuplicated(carta$periodo), !anyNA(carta))
meses_carta <- format(seq(as.Date(paste0(min(carta$periodo), "-01")), as.Date(paste0(max(carta$periodo), "-01")), by = "month"), "%Y-%m")
stopifnot(identical(carta$periodo, meses_carta))

lp(sprintf("- Carta de Conjuntura do Ipea (%s): planilha \"%s\" baixada de %s para %s; nota tecnica em %s (%s). Titulo na planilha: \"%s\".",
           URL_CARTA, basename(url_xlsx), url_xlsx, f_xlsx, ifelse(is.na(url_pdf), "nao encontrada", url_pdf),
           ifelse(is.na(f_pdf), "", f_pdf), sem_acento(titulo_planilha)))
lp(sprintf("- A planilha tem uma aba com 9 colunas, conferidas pelo cabecalho: %s. %d meses, de %s a %s, indices com media de 1995 = 100.",
           paste(CAB_ESP, collapse = "; "), nrow(carta), min(carta$periodo), max(carta$periodo)))

# Componentes nacional e importado de M&E: so aparecem como taxas na tabela da nota.
txt_pdf <- ""
if (!is.na(f_pdf) && nzchar(Sys.which("pdftotext"))) {
  txt_pdf <- paste(system2("pdftotext", c("-layout", shQuote(f_pdf), "-"), stdout = TRUE), collapse = "\n")
}
tem_comp_pdf <- grepl("Nacionais", txt_pdf) && grepl("Importados", txt_pdf)
lp("- Componentes de M&E (producao nacional liquida de exportacoes e importacao): nao sao publicados como serie. ",
   "A planilha so traz o consumo aparente total de M&E. ",
   if (tem_comp_pdf) "Na nota tecnica, \"Nacionais\" e \"Importados\" aparecem so na Tabela 1, como taxas de crescimento do ultimo mes, trimestre e 12 meses. " else "",
   "O Ipeadata tambem nao tem essas series. Registrado como indisponivel; a importacao de BK entra pela Funcex e pelo Comex Stat.")

# ---------------------------------------------------------------------------
# 3. Download das series do Ipeadata
# ---------------------------------------------------------------------------
arquivos <- c()
dados_ip <- list()
for (i in seq_len(nrow(ok))) {
  d <- ipeadata(ok$codigo[i], language = "br", quiet = TRUE) %>% select(code, date, value)
  f <- download_path("ipeadata", ok$codigo[i])
  write_csv_safe(d, f)
  arquivos[ok$serie[i]] <- f
  dados_ip[[ok$serie[i]]] <- d
  cat(sprintf("%s: %d obs, %s a %s\n", ok$codigo[i], nrow(d), min(d$date), max(d$date)))
}
lp(sprintf("- Download com ipeadatar::ipeadata; brutos em data/downloads/%s_ipeadata_<codigo>.csv. Periodos: %s.", HOJE,
           paste(sprintf("%s %s a %s", ok$codigo, map_chr(ok$serie, ~ format(min(dados_ip[[.x]]$date), "%Y-%m")),
                         map_chr(ok$serie, ~ format(max(dados_ip[[.x]]$date), "%Y-%m"))), collapse = "; ")))

mensal_ip <- function(s) {
  d <- dados_ip[[s]]
  if (s == "brent_usd_barril") {
    # Diaria -> mensal: media dos dias com cotacao.
    d <- d %>% mutate(periodo = format(date, "%Y-%m")) %>% group_by(periodo) %>%
      summarise(value = mean(value, na.rm = TRUE), .groups = "drop")
  } else {
    d <- d %>% transmute(periodo = format(date, "%Y-%m"), value)
  }
  d %>% rename(!!s := value)
}

# Conferencia planilha x Ipeadata (total e construcao, com e sem ajuste).
pares <- c(fbcf_total_nsa = "ipeadata_fbcf_total_nsa", fbcf_total_sa = "ipeadata_fbcf_total_sa",
           fbcf_constr_nsa = "ipeadata_fbcf_constr_nsa", fbcf_constr_sa = "ipeadata_fbcf_constr_sa")
conf <- map_dfr(names(pares), function(p) {
  if (!pares[p] %in% names(dados_ip)) return(NULL)
  x <- carta %>% select(periodo, a = all_of(p)) %>% inner_join(mensal_ip(pares[p]) %>% rename(b = 2), by = "periodo")
  tibble(serie = p, n = nrow(x), dif_rel_max = max(abs(x$a / x$b - 1)), cor_dlog = cor(diff(log(x$a)), diff(log(x$b))))
})
print(conf)
lp(sprintf("- Planilha da Carta contra o Ipeadata, meses comuns: %s. As duas fontes publicam a mesma serie; usa-se a planilha, que tem as quatro componentes.",
           paste(sprintf("%s: %d meses, diferenca relativa maxima %s, correlacao das variacoes do log %s", conf$serie, conf$n,
                         num_sci(conf$dif_rel_max), num_br(conf$cor_dlog, 4)), collapse = "; ")))

# Fonte nao aberta: Indicador de Incerteza da Economia (FGV IBRE).
lp(sprintf("- Indicador de Incerteza da Economia (IIE-Br, FGV IBRE): %s no catalogo do Ipeadata (series com \"incerteza\" no nome: %s). Tambem nao ha no portal de dados abertos do BCB (package_search?q=incerteza: 0 conjuntos). O portal do IBRE (portalibre.fgv.br) recusa a conexao neste conteiner e a serie historica fica no FGV Dados/IBRE Data, que exige cadastro. Registrado como sem fonte aberta acessivel; o autor pode baixar a planilha manualmente se quiser o controle.",
           ifelse(nrow(incerteza) == 0, "nao ha serie", "nao ha a serie do IBRE"),
           ifelse(nrow(incerteza) == 0, "nenhuma", paste(sprintf("%s (\"%s\", fonte %s)", incerteza$code, incerteza$name, incerteza$source), collapse = ", "))))

# ---------------------------------------------------------------------------
# 4. Series mensais e trimestrais
# ---------------------------------------------------------------------------
series_ip <- setdiff(ok$serie, pares)  # as do Ipeadata que nao duplicam a planilha
ipea_m <- reduce(c(list(carta), map(series_ip, mensal_ip)), full_join, by = "periodo") %>%
  filter(periodo >= "1996-01") %>% arrange(periodo)
ipea_m <- tibble(periodo = format(seq(as.Date("1996-01-01"), as.Date(paste0(max(ipea_m$periodo), "-01")), by = "month"), "%Y-%m")) %>%
  left_join(ipea_m, by = "periodo") %>%
  mutate(trimestre = q_key(as.integer(substr(periodo, 1, 4)), (as.integer(substr(periodo, 6, 7)) - 1) %/% 3 + 1))
write_csv_safe(ipea_m, file.path(PATHS$processed, "A2_ipea_mensal.csv"))

fun <- setNames(rep("media", ncol(ipea_m) - 2), setdiff(names(ipea_m), c("periodo", "trimestre")))
if ("funcex_imp_bk_valor_usd_mi" %in% names(fun)) fun["funcex_imp_bk_valor_usd_mi"] <- "soma"
ipea_q <- mensal_para_trimestral(ipea_m %>% select(-trimestre), fun) %>%
  select(trimestre, all_of(names(fun)))
write_csv_safe(ipea_q, file.path(PATHS$processed, "A2_ipea_trimestral.csv"))

lp(sprintf("- Mensal (data/processed/A2_ipea_mensal.csv, %s a %s): as oito series da planilha (fbcf_{total,me,constr,outros}_{nsa,sa}, indices 1995 = 100) e, do Ipeadata, %s. Brent diario vira media mensal dos dias cotados.",
           min(ipea_m$periodo), max(ipea_m$periodo), paste(series_ip, collapse = ", ")))
lp("- Trimestral (data/processed/A2_ipea_trimestral.csv, chave 2003Q1): media dos tres meses para indices e precos; soma para o valor FOB da Funcex (US$ milhoes). ",
   "So entram trimestres com os tres meses observados. Nenhuma serie anual foi interpolada. As series sem ajuste sazonal ficam como estao; o ajuste fica para a consolidacao.")

# ---------------------------------------------------------------------------
# 5. O PVD da dissertacao e o indicador Ipea de M&E?
# ---------------------------------------------------------------------------
est <- read.table(file.path(PATHS$original, "0224_tri_estmeq.txt"), header = TRUE)
stopifnot(nrow(est) == 72)
apA <- read_csv("data/dados_dissertacao_apendiceA.csv", show_col_types = FALSE)
TRI <- q_seq("2002Q1", "2019Q4")
stopifnot(identical(apA$trimestre, TRI))
pvd <- tibble(trimestre = TRI, pvd = est$PVD, imeq = apA$imeq_indice)
rz_ap <- 10^pvd$pvd / pvd$imeq
lp(sprintf("- PVD (0224_tri_estmeq.txt, log10) e imeq_indice do Apendice A: 10^PVD / imeq_indice = %s em todos os 72 trimestres (desvio padrao %s); as duas sao a mesma serie em escalas diferentes.",
           num_br(mean(rz_ap), 4), num_sci(sd(rz_ap))))

q_ser <- ipea_q %>% select(trimestre, fbcf_me_sa, fbcf_me_nsa, ca_bk_sa, ca_bk_nsa, fbcf_total_sa)
q_ser <- q_ser %>% filter(!is.na(fbcf_me_nsa))
ajusta <- function(v) {
  k <- which(!is.na(v))
  out <- rep(NA_real_, length(v))
  out[k] <- as.numeric(x11_sa(ts_from_q(v[k], q_ser$trimestre[k])))
  out
}
q_ser <- q_ser %>% mutate(fbcf_me_nsa_x11 = ajusta(fbcf_me_nsa), ca_bk_nsa_x11 = ajusta(ca_bk_nsa))

cands <- c(fbcf_me_sa = "Ipea M&E dessazonalizado pelo Ipea, media trimestral",
           fbcf_me_nsa_x11 = "Ipea M&E sem ajuste, media trimestral com X-11 proprio",
           fbcf_me_nsa = "Ipea M&E sem ajuste, media trimestral",
           ca_bk_sa = "Consumo aparente de bens de capital dessazonalizado (Ipeadata), media trimestral",
           ca_bk_nsa_x11 = "Consumo aparente de bens de capital sem ajuste, media trimestral com X-11 proprio",
           fbcf_total_sa = "Indicador Ipea de FBCF total dessazonalizado, media trimestral")
base <- pvd %>% left_join(q_ser, by = "trimestre")
cmp <- map_dfr(names(cands), function(v) {
  x <- base[[v]]
  if (all(is.na(x))) return(NULL)
  dl <- diff(log10(x))
  r <- 10^base$pvd / x
  tibble(candidata = v, descricao = cands[[v]], n_dif = sum(!is.na(dl)),
         cor_dif_pvd = cor(dl, diff(base$pvd), use = "complete.obs"),
         cor_dif_imeq = cor(dl, diff(log10(base$imeq)), use = "complete.obs"),
         cor_nivel_pvd = cor(log10(x), base$pvd, use = "complete.obs"),
         razao_media = mean(r, na.rm = TRUE), razao_cv = sd(r, na.rm = TRUE) / mean(r, na.rm = TRUE),
         rmse_dif = sqrt(mean((dl - diff(base$pvd))^2, na.rm = TRUE)))
})
print(cmp)
write_csv_safe(cmp, file.path(PATHS$results, "A2_comparacao_pvd_ipea.csv"))

melhor <- cmp %>% arrange(desc(cor_dif_pvd)) %>% slice(1)
me_sa <- cmp %>% filter(candidata == "fbcf_me_sa")
veredito <- if (me_sa$cor_dif_pvd >= 0.99) {
  "o PVD e o indicador Ipea de M&E dessazonalizado (media trimestral, log10), a menos de revisoes da serie"
} else if (melhor$cor_dif_pvd >= 0.99) {
  sprintf("o PVD nao e o M&E dessazonalizado pelo Ipea tal como publicado hoje; a candidata mais proxima e \"%s\"", melhor$descricao)
} else if (me_sa$cor_dif_pvd >= 0.9) {
  "o PVD acompanha de perto o indicador Ipea de M&E dessazonalizado, mas nao coincide com a versao publicada hoje (revisoes ou outro ajuste sazonal)"
} else {
  "o PVD nao e o indicador Ipea de M&E dessazonalizado"
}
lp(sprintf("- Comparacao com o PVD, %s a %s (%d variacoes trimestrais): correlacao de diff(log10 da media trimestral) com diff(PVD): %s. Correlacao com diff(log10(imeq_indice)): identica, pois imeq e PVD sao a mesma serie. Razao 10^PVD / indice: %s. Tabela em results/A2_comparacao_pvd_ipea.csv.",
           TRI[2], TRI[72], me_sa$n_dif,
           paste(sprintf("%s %s", cmp$candidata, num_br(cmp$cor_dif_pvd, 4)), collapse = "; "),
           paste(sprintf("%s media %s e coeficiente de variacao %s", cmp$candidata, num_br(cmp$razao_media, 3), num_br(cmp$razao_cv, 3)), collapse = "; ")))
rz_imeq <- base$imeq / base$fbcf_me_sa
lp(sprintf("- Conclusao: %s. Melhor candidata: %s (correlacao %s; raiz do erro quadratico medio das diferencas %s). imeq_indice / media trimestral do M&E dessazonalizado de hoje: media %s, minimo %s, maximo %s; ou seja, imeq_indice e o proprio indice Ipea de M&E dessazonalizado (1995 = 100) na versao baixada para a dissertacao, e PVD = log10(0,9426 x imeq_indice). O X-11 proprio foi aplicado as medias trimestrais de %s a %s.",
           veredito, melhor$candidata, num_br(melhor$cor_dif_pvd, 4), num_br(melhor$rmse_dif, 4),
           num_br(mean(rz_imeq), 4), num_br(min(rz_imeq), 4), num_br(max(rz_imeq), 4),
           min(q_ser$trimestre), max(q_ser$trimestre)))

# ---------------------------------------------------------------------------
# 6. Metadados
# ---------------------------------------------------------------------------
per_m <- function(s) {
  v <- ipea_m[[s]]
  sprintf("%s a %s", min(ipea_m$periodo[!is.na(v)]), max(ipea_m$periodo[!is.na(v)]))
}
meta_carta <- tibble(
  serie = NOMES[-1], fonte = "Ipea/Carta de Conjuntura", codigo = basename(url_xlsx),
  titulo_nos_metadados = CAB_ESP[-1], unidade = "indice, media de 1995 = 100", periodicidade = "mensal",
  periodo = map_chr(NOMES[-1], per_m), url = url_xlsx, arquivo_download = f_xlsx,
  transformacao = "mensal; trimestral = media dos 3 meses"
)
meta_ipd <- meta_ip %>% transmute(
  serie, fonte = "Ipeadata", codigo, titulo_nos_metadados = titulo,
  unidade = ifelse(trimws(unidade) == "-", "indice", trimws(unidade)), periodicidade = freq,
  periodo = map_chr(serie, function(s) {
    if (!s %in% names(dados_ip)) return("nao baixada")
    fmt <- if (s == "brent_usd_barril") "%Y-%m-%d" else "%Y-%m"
    sprintf("%s a %s", format(min(dados_ip[[s]]$date), fmt), format(max(dados_ip[[s]]$date), fmt))
  }),
  url = sprintf("https://www.ipeadata.gov.br/api/odata4/ValoresSerie(SERCODIGO='%s')", codigo),
  arquivo_download = ifelse(serie %in% names(arquivos), arquivos[serie], ""),
  transformacao = case_when(
    !confere ~ "titulo nao confere; descartada",
    serie %in% pares ~ "so conferencia com a planilha da Carta (nao vai para os arquivos processados)",
    serie == "brent_usd_barril" ~ "diaria -> mensal pela media dos dias cotados; trimestral = media dos 3 meses",
    serie == "funcex_imp_bk_valor_usd_mi" ~ "mensal; trimestral = soma dos 3 meses",
    TRUE ~ "mensal; trimestral = media dos 3 meses")
)
meta_fgv <- tibble(serie = "incerteza_iie_br", fonte = "FGV IBRE", codigo = "indisponivel",
                   titulo_nos_metadados = "Indicador de Incerteza da Economia (IIE-Br): nao ha no Ipeadata nem no BCB",
                   unidade = "", periodicidade = "mensal", periodo = "nao baixada",
                   url = "https://portalibre.fgv.br (conexao recusada no conteiner)", arquivo_download = "",
                   transformacao = "sem fonte aberta acessivel")
meta_comp <- tibble(serie = "fbcf_me_nacional / fbcf_me_importado", fonte = "Ipea/Carta de Conjuntura", codigo = "indisponivel",
                    titulo_nos_metadados = "componentes de M&E so aparecem como taxas na Tabela 1 da nota tecnica",
                    unidade = "", periodicidade = "mensal", periodo = "nao baixada", url = ifelse(is.na(url_pdf), "", url_pdf),
                    arquivo_download = ifelse(is.na(f_pdf), "", f_pdf), transformacao = "nao publicados como serie")
gravar_metadados(bind_rows(meta_carta, meta_comp, meta_ipd, meta_fgv), c("Ipeadata", "Ipea/Carta de Conjuntura", "FGV IBRE"))

log_secao_fim()
save_session_info("A2_download_ipea")
cat("A2_download_ipea.R concluido.\n")
