# Etapa A2, parte IBGE/SIDRA: PIB e FBCF das Contas Nacionais Trimestrais e PIM-PF de bens de capital.
# Saidas: data/processed/A2_ibge_trimestral.csv e a parte IBGE de data/processed/A2_metadados_bcb_ibge.csv.
# Rodar da raiz do projeto, depois de R/A2_download_bcb.R: Rscript R/A2_download_ibge.R

source("R/00_setup.R")
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

ETAPA <- "A2_bcb_ibge"
MARCA_BCB <- "#### BCB/SGS"
MARCA_IBGE <- "#### IBGE/SIDRA"
Q_INI <- "2000Q1"
Q_FIM <- "2025Q4"

# O log da etapa e compartilhado com R/A2_download_bcb.R: preserva a secao BCB,
# reinicia o arquivo e escreve BCB e depois IBGE.
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
secao_bcb <- ler_secao(ETAPA, MARCA_BCB)
log_reset(ETAPA)
if (length(secao_bcb)) log_part(ETAPA, paste(secao_bcb, collapse = "\n"))
log_part(ETAPA, sprintf("%s (R/A2_download_ibge.R, execucao de %s)", MARCA_IBGE, format(Sys.time(), "%Y-%m-%d %H:%M")))

num_br <- function(x, d = 3) formatC(round(x, d) + 0, format = "f", digits = d, decimal.mark = ",", big.mark = ".")

# ---------------------------------------------------------------------------
# 1. Metadados das tabelas (API de agregados v3) e conferencia
# ---------------------------------------------------------------------------
sidra_meta <- function(tab) {
  url <- sprintf("https://servicodados.ibge.gov.br/api/v3/agregados/%s/metadados", tab)
  r <- RETRY("GET", url, times = 5, timeout(60))
  stop_for_status(r)
  txt <- content(r, as = "text", encoding = "UTF-8")
  f <- download_path("ibge_metadados", tab, "json")
  guard_path(f)
  writeLines(txt, f)
  m <- fromJSON(txt, simplifyVector = FALSE)
  m$url_meta <- url
  m$arquivo_meta <- f
  m
}

# Pedido: tabela, variavel, classificacao, categorias (nome da serie = codigo da categoria)
# e o que se espera nos metadados (regex no nome da tabela e da variavel).
PED <- list(
  list(tab = "1621", var = "584", cls = "11255", cats = c(pib = "90707", fbcf = "93406"),
       esp_tab = "ndice de volume trimestral com ajuste sazonal \\(Base: m.dia 1995 = 100\\)",
       esp_var = "com ajuste sazonal", suf = "vol_sa_1621", freq = "trimestral"),
  list(tab = "1620", var = "583", cls = "11255", cats = c(pib = "90707", fbcf = "93406"),
       esp_tab = "^S.rie encadeada do .ndice de volume trimestral \\(Base: m.dia 1995 = 100\\)$",
       esp_var = "volume trimestral \\(Base", suf = "vol_nsa_1620", freq = "trimestral"),
  list(tab = "1846", var = "585", cls = "11255", cats = c(pib = "90707", fbcf = "93406"),
       esp_tab = "^Valores a pre.os correntes$", esp_var = "correntes", suf = "corrente_1846", freq = "trimestral"),
  list(tab = "6612", var = "9318", cls = "11255", cats = c(pib = "90707", fbcf = "93406"),
       esp_tab = "^Valores encadeados a pre.os de 1995$", esp_var = "encadeados a pre.os de 1995$",
       suf = "encad95_nsa_6612", freq = "trimestral"),
  list(tab = "6613", var = "9319", cls = "11255", cats = c(pib = "90707", fbcf = "93406"),
       esp_tab = "^Valores encadeados a pre.os de 1995 com ajuste sazonal$", esp_var = "com ajuste sazonal",
       suf = "encad95_sa_6613", freq = "trimestral"),
  list(tab = "8887", var = "12606", cls = "543",
       cats = c(pim_bk = "129278", pim_bk_exc_transp = "129280", pim_bk_transp = "129282"),
       esp_tab = "Produ..o F.sica Industrial, por grandes categorias econ.micas$",
       esp_var = "N.mero-.ndice \\(2022=100\\)$", suf = "nsa_8887", freq = "mensal"),
  list(tab = "8887", var = "12607", cls = "543",
       cats = c(pim_bk = "129278", pim_bk_exc_transp = "129280", pim_bk_transp = "129282"),
       esp_tab = "Produ..o F.sica Industrial, por grandes categorias econ.micas$",
       esp_var = "com ajuste sazonal \\(2022=100\\)$", suf = "sa_8887", freq = "mensal"),
  list(tab = "1737", var = "2266", cls = NA, cats = c(ipca_numero_indice = NA),
       esp_tab = "^IPCA - S.rie hist.rica com n.mero-.ndice", esp_var = "base: dezembro de 1993 = 100",
       suf = "1737", freq = "mensal")
)

metas <- list()
conf <- map_dfr(PED, function(p) {
  if (is.null(metas[[p$tab]])) metas[[p$tab]] <<- sidra_meta(p$tab)
  m <- metas[[p$tab]]
  v <- keep(m$variaveis, ~ as.character(.x$id) == p$var)
  ok_tab <- grepl(p$esp_tab, m$nome)
  ok_var <- length(v) == 1 && grepl(p$esp_var, v[[1]]$nome)
  cat_nomes <- rep(NA_character_, length(p$cats))
  if (!is.na(p$cls)) {
    cl <- keep(m$classificacoes, ~ as.character(.x$id) == p$cls)
    if (length(cl) == 1) {
      ids <- map_chr(cl[[1]]$categorias, ~ as.character(.x$id))
      nms <- map_chr(cl[[1]]$categorias, ~ .x$nome)
      cat_nomes <- nms[match(p$cats, ids)]
    }
  }
  tibble(tab = p$tab, var = p$var, cls = p$cls, serie = names(p$cats), cat = unname(p$cats), suf = p$suf,
         titulo_tabela = m$nome, nome_variavel = if (length(v)) v[[1]]$nome else NA_character_,
         unidade = if (length(v)) v[[1]]$unidade else NA_character_,
         categoria_nome = cat_nomes,
         periodicidade = m$periodicidade$frequencia,
         cobertura = sprintf("%s a %s", m$periodicidade$inicio, m$periodicidade$fim),
         pesquisa = m$pesquisa, url_meta = m$url_meta, arquivo_meta = m$arquivo_meta,
         confere = ok_tab & ok_var & (is.na(p$cls) | !is.na(cat_nomes)))
})
print(conf %>% select(tab, var, serie, categoria_nome, unidade, cobertura, confere), n = 30)

log_part(ETAPA, "- Metadados conferidos na API de agregados do IBGE (servicodados.ibge.gov.br/api/v3/agregados/<tabela>/metadados); ",
         sprintf("JSON salvo em data/downloads/%s_ibge_metadados_<tabela>.json.", HOJE))
for (tb in unique(conf$tab)) {
  cc <- conf %>% filter(tab == tb)
  vv <- cc %>% distinct(var, nome_variavel, unidade)
  log_part(ETAPA, sprintf("  - Tabela %s (%s): \"%s\"; periodicidade %s; cobertura %s; variaveis %s; categorias %s; %s.",
                          tb, cc$pesquisa[1], cc$titulo_tabela[1], cc$periodicidade[1], cc$cobertura[1],
                          paste(sprintf("%s \"%s\" (%s)", vv$var, vv$nome_variavel, vv$unidade), collapse = " e "),
                          paste(unique(ifelse(is.na(cc$cat), "nenhuma", sprintf("%s \"%s\"", cc$cat, cc$categoria_nome))), collapse = ", "),
                          ifelse(all(cc$confere), "confere com a descricao pedida", "NAO confere")))
}
stopifnot(all(conf$confere))

cob_8887 <- conf$cobertura[conf$tab == "8887"][1]
log_part(ETAPA, sprintf("- PIM-PF: a tabela 8887 (base 2022 = 100) cobre %s, isto e, comeca em jan/2002. ", cob_8887),
         "Nao e preciso encadear com a tabela antiga 3651 (base 2012 = 100, encerrada em jan/2022); ela nao foi baixada.")

# ---------------------------------------------------------------------------
# 2. Download dos valores (sidrar)
# ---------------------------------------------------------------------------
baixar <- function(p) {
  api <- if (is.na(p$cls)) sprintf("/t/%s/n1/all/v/%s/p/all", p$tab, p$var) else
    sprintf("/t/%s/n1/all/v/%s/p/all/c%s/%s", p$tab, p$var, p$cls, paste(p$cats, collapse = ","))
  d <- NULL
  for (tent in 1:5) {
    d <- tryCatch(suppressMessages(sidrar::get_sidra(api = api)), error = function(e) NULL)
    if (is.data.frame(d) && nrow(d) > 0) break
    Sys.sleep(3 * tent)
  }
  if (!is.data.frame(d)) stop("SIDRA sem resposta: ", api)
  f <- download_path("ibge_sidra", sprintf("%s_v%s", p$tab, p$var))
  write_csv_safe(as_tibble(d), f)
  per <- names(d)[grepl("^(Trimestre|M.s) \\(C.digo\\)$", names(d))]
  cls_col <- names(d)[grepl("\\(C.digo\\)$", names(d)) & names(d) != per &
                        !grepl("^(N.vel Territorial|Unidade de Medida|Brasil|Vari.vel) \\(C.digo\\)$", names(d))]
  out <- tibble(p_cod = as.character(d[[per]]), valor = as.numeric(d$Valor),
                cat = if (length(cls_col)) as.character(d[[cls_col]]) else NA_character_)
  out$serie <- names(p$cats)[match(out$cat, p$cats)]
  if (is.na(p$cls)) out$serie <- names(p$cats)[1]
  out %>% mutate(tab = p$tab, var = p$var, suf = p$suf, freq = p$freq,
                 api = paste0("https://apisidra.ibge.gov.br/values", api), arquivo = f)
}
dados <- map_dfr(PED, baixar)
dados %>% group_by(tab, var, serie) %>% summarise(n = n(), ini = min(p_cod), fim = max(p_cod), na = sum(is.na(valor)), .groups = "drop") %>% print(n = 30)
log_part(ETAPA, sprintf("- Valores baixados com sidrar::get_sidra (apisidra.ibge.gov.br/values), serie completa de cada tabela; brutos em data/downloads/%s_ibge_sidra_<tabela>_v<variavel>.csv.", HOJE))

# ---------------------------------------------------------------------------
# 3. Base trimestral
# ---------------------------------------------------------------------------
trim <- dados %>% filter(freq == "trimestral") %>%
  mutate(periodo = q_key(substr(p_cod, 1, 4), substr(p_cod, 5, 6)), nome = paste(serie, suf, sep = "_")) %>%
  select(periodo, nome, valor) %>%
  pivot_wider(names_from = nome, values_from = valor) %>%
  arrange(q_to_yearqtr(periodo))

# Variacao trimestral do PIB com ajuste (conceito da coluna PIB de 0124_inexo.txt), calculada na serie completa.
trim <- trim %>% mutate(pib_var_tri_sa_1621 = pib_vol_sa_1621 / lag(pib_vol_sa_1621) - 1,
                        fbcf_var_tri_sa_1621 = fbcf_vol_sa_1621 / lag(fbcf_vol_sa_1621) - 1)

# PIM-PF: mensal -> trimestral pela media dos tres meses (indice). Trimestres incompletos ficam NA.
pim_q <- dados %>% filter(tab == "8887") %>%
  mutate(ano = as.integer(substr(p_cod, 1, 4)), mes = as.integer(substr(p_cod, 5, 6)),
         periodo = q_key(ano, (mes - 1) %/% 3 + 1), nome = paste(serie, suf, sep = "_")) %>%
  group_by(periodo, nome) %>%
  summarise(valor = if (n() == 3 && !anyNA(valor)) mean(valor) else NA_real_, .groups = "drop") %>%
  pivot_wider(names_from = nome, values_from = valor)

ibge_q <- tibble(periodo = q_seq(Q_INI, Q_FIM)) %>%
  left_join(trim, by = "periodo") %>%
  left_join(pim_q, by = "periodo")
ordem <- c("periodo",
           "pib_vol_sa_1621", "fbcf_vol_sa_1621", "pib_var_tri_sa_1621", "fbcf_var_tri_sa_1621",
           "pib_vol_nsa_1620", "fbcf_vol_nsa_1620",
           "pib_corrente_1846", "fbcf_corrente_1846",
           "pib_encad95_nsa_6612", "fbcf_encad95_nsa_6612", "pib_encad95_sa_6613", "fbcf_encad95_sa_6613",
           "pim_bk_nsa_8887", "pim_bk_sa_8887", "pim_bk_exc_transp_nsa_8887", "pim_bk_exc_transp_sa_8887",
           "pim_bk_transp_nsa_8887", "pim_bk_transp_sa_8887")
ibge_q <- ibge_q %>% select(all_of(ordem))
# Series sem nenhum valor na fonte (SIDRA devolve o campo vazio) saem da base.
vazias <- names(ibge_q)[map_lgl(ibge_q, ~ all(is.na(.x)))]
ibge_q <- ibge_q %>% select(-all_of(vazias))
if (length(vazias)) {
  log_part(ETAPA, sprintf("- Sem valores na fonte (a SIDRA devolve o campo vazio em todos os meses), fora da base: %s. So o total de bens de capital tem versao com ajuste sazonal na 8887.",
                          paste(vazias, collapse = ", ")))
}
nas <- ibge_q %>% summarise(across(-periodo, ~ sum(is.na(.x))))
print(t(nas))
write_csv_safe(ibge_q, file.path(PATHS$processed, "A2_ibge_trimestral.csv"))

pim_ini <- ibge_q$periodo[which(!is.na(ibge_q$pim_bk_sa_8887))[1]]
log_part(ETAPA, sprintf("- Trimestral (%s a %s, chave 2003Q1): Contas Nacionais sem transformacao; PIM-PF pela media dos tres meses (indice), a partir de %s; antes disso fica vazio (nao ha interpolacao). ",
                        Q_INI, Q_FIM, pim_ini),
         "Tambem a variacao trimestral do PIB e da FBCF com ajuste (1621), x_t/x_{t-1} - 1, calculada na serie completa. Saida: data/processed/A2_ibge_trimestral.csv.")

# Consistencia: indice encadeado (1620) e valores encadeados a precos de 1995 (6612) devem andar juntos.
cons <- ibge_q %>% filter(!is.na(pib_vol_nsa_1620), !is.na(pib_encad95_nsa_6612)) %>%
  summarise(cor_pib = cor(diff(log(pib_vol_nsa_1620)), diff(log(pib_encad95_nsa_6612))),
            cor_fbcf = cor(diff(log(fbcf_vol_nsa_1620)), diff(log(fbcf_encad95_nsa_6612))),
            cor_pib_sa = cor(diff(log(pib_vol_sa_1621)), diff(log(pib_encad95_sa_6613))),
            cor_fbcf_sa = cor(diff(log(fbcf_vol_sa_1621)), diff(log(fbcf_encad95_sa_6613))))
fbcf_pib <- ibge_q %>% mutate(ano = substr(periodo, 1, 4)) %>% filter(ano %in% c("2003", "2019", "2025")) %>%
  group_by(ano) %>% summarise(r = sum(fbcf_corrente_1846) / sum(pib_corrente_1846), .groups = "drop")
log_part(ETAPA, sprintf("- Consistencia: correlacao das variacoes do log entre indice 1620 e valores encadeados 6612 = %s (PIB) e %s (FBCF); entre 1621 e 6613 = %s (PIB) e %s (FBCF). ",
                        num_br(cons$cor_pib, 4), num_br(cons$cor_fbcf, 4), num_br(cons$cor_pib_sa, 4), num_br(cons$cor_fbcf_sa, 4)),
         sprintf("FBCF/PIB a precos correntes (1846): %s.", paste(sprintf("%s%% em %s", num_br(100 * fbcf_pib$r, 1), fbcf_pib$ano), collapse = ", ")))

# ---------------------------------------------------------------------------
# 4. PIB da dissertacao (coluna PIB de 0124_inexo.txt, 2002T1-2019T4) contra a 1621
# ---------------------------------------------------------------------------
inexo <- read.table(file.path(PATHS$original, "0124_inexo.txt"), header = TRUE)
stopifnot(nrow(inexo) == 72)
inexo$periodo <- q_seq("2002Q1", "2019Q4")
cmp_pib <- inexo %>% select(periodo, PIB_dissertacao = PIB) %>%
  left_join(trim %>% transmute(periodo, pib_var_tri_sa_1621,
                               pib_dlog_sa_1621 = log(pib_vol_sa_1621) - log(lag(pib_vol_sa_1621)),
                               pib_var_anual_nsa_1620 = pib_vol_nsa_1620 / lag(pib_vol_nsa_1620, 4) - 1),
            by = "periodo") %>%
  mutate(dif = PIB_dissertacao - pib_var_tri_sa_1621)
write_csv_safe(cmp_pib, file.path(PATHS$results, "A2_comparacao_pib_inexo.csv"))
r_qq <- cor(cmp_pib$PIB_dissertacao, cmp_pib$pib_var_tri_sa_1621)
r_dl <- cor(cmp_pib$PIB_dissertacao, cmp_pib$pib_dlog_sa_1621)
r_yy <- cor(cmp_pib$PIB_dissertacao, cmp_pib$pib_var_anual_nsa_1620)
iguais <- sum(abs(round(cmp_pib$pib_var_tri_sa_1621, 3) - cmp_pib$PIB_dissertacao) < 1e-9)
mad_qq <- mean(abs(cmp_pib$PIB_dissertacao - cmp_pib$pib_var_tri_sa_1621))
mad_dl <- mean(abs(cmp_pib$PIB_dissertacao - cmp_pib$pib_dlog_sa_1621))
conclusao_pib <- if (r_qq > 0.99 && r_qq > r_yy) {
  sprintf("Conclusao: a dissertacao usou a variacao trimestral do PIB com ajuste sazonal (%s, arredondada a 3 casas); as diferencas restantes sao compativeis com revisoes das Contas Nacionais e reestimacao do ajuste sazonal desde a safra usada na dissertacao.",
          ifelse(mad_qq <= mad_dl, "x_t/x_{t-1} - 1", "diferenca do log"))
} else {
  "Conclusao: o conceito da coluna PIB nao foi identificado com seguranca; ver tabela."
}
top <- cmp_pib %>% arrange(desc(abs(dif))) %>% slice(1:5)
sub_cor <- function(a, b) with(cmp_pib %>% filter(periodo >= a, periodo <= b), cor(PIB_dissertacao, pib_var_tri_sa_1621))
print(cmp_pib %>% summarise(r_qq, r_dl, r_yy, mad = mean(abs(dif)), maxd = max(abs(dif)), iguais))
log_part(ETAPA, sprintf(paste0("- PIB de 0124_inexo.txt (2002T1 a 2019T4) contra a variacao trimestral do indice com ajuste da tabela 1621 (safra de %s): ",
                               "correlacao %s (%s com a diferenca do log; %s com a variacao contra o mesmo trimestre do ano anterior da 1620, conceito descartado); ",
                               "diferenca media absoluta %s p.p., maxima %s p.p.; %d de 72 trimestres iguais apos arredondar a 3 casas. ",
                               "Correlacao 2002-2010 %s e 2011-2019 %s. Maiores diferencas: %s. ",
                               "%s Tabela em results/A2_comparacao_pib_inexo.csv."),
                        HOJE, num_br(r_qq, 4), num_br(r_dl, 4), num_br(r_yy, 2),
                        num_br(100 * mean(abs(cmp_pib$dif)), 3), num_br(100 * max(abs(cmp_pib$dif)), 3), iguais,
                        num_br(sub_cor("2002Q1", "2010Q4"), 4), num_br(sub_cor("2011Q1", "2019Q4"), 4),
                        paste(sprintf("%s (dissertacao %s%%; 1621 %s%%)", top$periodo, num_br(100 * top$PIB_dissertacao, 1),
                                      num_br(100 * top$pib_var_tri_sa_1621, 2)), collapse = ", "), conclusao_pib))

# ---------------------------------------------------------------------------
# 5. Checagem do deflator: indice do IPCA da SIDRA 1737 contra o indice construido da SGS 433
# ---------------------------------------------------------------------------
f_defl <- file.path(PATHS$processed, "A2_deflator_ipca.csv")
if (file.exists(f_defl)) {
  defl <- read_csv(f_defl, show_col_types = FALSE) %>% filter(frequencia == "mensal")
  ipca_sidra <- dados %>% filter(tab == "1737") %>%
    transmute(periodo = sprintf("%s-%s", substr(p_cod, 1, 4), substr(p_cod, 5, 6)), num_indice = valor) %>%
    filter(periodo >= "2000-01", periodo <= "2025-12")
  b25 <- mean(ipca_sidra$num_indice[substr(ipca_sidra$periodo, 1, 4) == "2025"])
  chk <- defl %>% inner_join(ipca_sidra, by = "periodo") %>%
    mutate(indice_sidra = 100 * num_indice / b25, dif_pct = 100 * (indice / indice_sidra - 1))
  stopifnot(nrow(chk) == 312)
  log_part(ETAPA, sprintf("- Checagem do deflator: o indice construido da SGS 433 (variacoes com 2 casas) contra o numero-indice da SIDRA 1737 (variavel 2266, dez/1993 = 100), ambos rebaseados para media de 2025 = 100: diferenca maxima em modulo %s%% em %s; em jan/2000 %s%%. %s",
                          num_br(max(abs(chk$dif_pct)), 4), chk$periodo[which.max(abs(chk$dif_pct))],
                          num_br(chk$dif_pct[1], 4),
                          ifelse(max(abs(chk$dif_pct)) < 0.1, "O acumulo do arredondamento das variacoes e desprezivel.",
                                 "A diferenca nao e desprezivel: preferir o numero-indice da SIDRA.")))
} else {
  log_part(ETAPA, "- Checagem do deflator contra a SIDRA 1737 nao feita: rode antes R/A2_download_bcb.R.")
}

# ---------------------------------------------------------------------------
# 6. Metadados (parte IBGE), preservando as linhas do BCB
# ---------------------------------------------------------------------------
transf <- function(tab, serie) {
  case_when(
    tab == "8887" ~ "mensal -> trimestral pela media dos 3 meses (indice); a partir de 2002Q1",
    tab == "1737" ~ "so para checar o indice do IPCA construido da SGS 433; nao entra na base trimestral",
    tab == "1621" ~ "trimestral, sem transformacao; tambem variacao trimestral x_t/x_{t-1} - 1",
    TRUE ~ "trimestral, sem transformacao"
  )
}
arq <- dados %>% distinct(tab, var, serie, api, arquivo)
meta_ibge <- conf %>% left_join(arq, by = c("tab", "var", "serie")) %>% rowwise() %>%
  transmute(serie = paste(serie, suf, sep = "_"), fonte = "IBGE/SIDRA",
            codigo = ifelse(is.na(cat), sprintf("tabela %s, variavel %s", tab, var),
                            sprintf("tabela %s, variavel %s, c%s/%s", tab, var, cls, cat)),
            titulo_nos_metadados = paste(c(titulo_tabela, if (nome_variavel != titulo_tabela) nome_variavel,
                                           if (!is.na(categoria_nome)) categoria_nome), collapse = " | "),
            unidade, periodicidade,
            periodo = sprintf("fonte %s; %s", cobertura,
                              case_when(tab == "1737" ~ "checagem 2000-01 a 2025-12",
                                        tab == "8887" ~ sprintf("base %s a %s", pim_ini, Q_FIM),
                                        TRUE ~ sprintf("base %s a %s", Q_INI, Q_FIM))),
            url = api, arquivo_download = arquivo,
            transformacao = transf(tab, serie)) %>%
  ungroup() %>%
  mutate(transformacao = ifelse(serie %in% vazias, "sem valores na fonte; nao entra na base", transformacao),
         periodo = ifelse(serie %in% vazias, sub(";.*", "; sem valores", periodo), periodo))
f_meta <- file.path(PATHS$processed, "A2_metadados_bcb_ibge.csv")
if (file.exists(f_meta)) {
  outros <- read_csv(f_meta, show_col_types = FALSE, col_types = cols(.default = "c")) %>% filter(fonte != "IBGE/SIDRA")
  meta_ibge <- bind_rows(outros, meta_ibge)
}
write_csv_safe(meta_ibge, f_meta)

log_part(ETAPA, sprintf("- Resumo: PIB com ajuste (1621) 2003Q1 = %s e 2025Q4 = %s (media 1995 = 100); FBCF com ajuste 2003Q1 = %s e 2025Q4 = %s; PIM-PF bens de capital com ajuste (2022 = 100) 2003Q1 = %s e 2025Q4 = %s.",
                        num_br(ibge_q$pib_vol_sa_1621[ibge_q$periodo == "2003Q1"], 2), num_br(ibge_q$pib_vol_sa_1621[ibge_q$periodo == "2025Q4"], 2),
                        num_br(ibge_q$fbcf_vol_sa_1621[ibge_q$periodo == "2003Q1"], 2), num_br(ibge_q$fbcf_vol_sa_1621[ibge_q$periodo == "2025Q4"], 2),
                        num_br(ibge_q$pim_bk_sa_8887[ibge_q$periodo == "2003Q1"], 2), num_br(ibge_q$pim_bk_sa_8887[ibge_q$periodo == "2025Q4"], 2)))

save_session_info("A2_download_ibge")
cat("A2_download_ibge.R concluido.\n")
