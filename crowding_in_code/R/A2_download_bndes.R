# Etapa A2, parte BNDES: desembolsos mensais do Sistema BNDES (portal de dados abertos),
# serie total e recortes disponiveis; comparacao com os totais anuais ja extraidos.
# Saidas: data/processed/A2_bndes_mensal.csv, A2_bndes_trimestral.csv (R$ milhoes nominais),
# results/A2_bndes_recortes.csv, results/A2_bndes_comparacao_anual.csv e as linhas BNDES
# de data/processed/A2_metadados_ipea_comex_bndes.csv.
# Rodar da raiz do projeto: Rscript R/A2_download_bndes.R

source("R/00_setup.R")
source("R/A2_util_ipea_comex_bndes.R")
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})
invisible(Sys.setlocale("LC_CTYPE", "C.UTF-8"))

MARCA <- "#### BNDES"
log_secao_inicio(MARCA, "A2_download_bndes")

CKAN <- "https://dadosabertos.bndes.gov.br/api/3/action/"
ckan <- function(acao, ...) {
  r <- RETRY("GET", paste0(CKAN, acao), query = list(...), times = 5, timeout(120))
  stop_for_status(r)
  fromJSON(content(r, as = "text", encoding = "UTF-8"))
}

# ---------------------------------------------------------------------------
# 1. Busca no portal e escolha do conjunto
# ---------------------------------------------------------------------------
bus <- ckan("package_search", q = "desembolsos", rows = 50)$result
conj <- tibble(nome = bus$results$name, titulo = bus$results$title)
print(conj)
lp(sprintf("- Portal de dados abertos do BNDES, package_search?q=desembolsos: %d conjuntos (%s).",
           nrow(conj), paste(sprintf("%s = \"%s\"", conj$nome, conj$titulo), collapse = "; ")))
stopifnot("desembolsos-mensais" %in% conj$nome)

pkg <- ckan("package_show", id = "desembolsos-mensais")$result
f_pkg <- download_path("bndes", "package_desembolsos_mensais", "json")
writeLines(toJSON(pkg, auto_unbox = TRUE, pretty = TRUE), f_pkg)
rs <- as_tibble(pkg$resources)
res_csv <- rs %>% filter(format == "CSV", grepl("^Desembolsos Mensais$", name))
res_dic <- rs %>% filter(format == "PDF", grepl("Dicion", name))
stopifnot(nrow(res_csv) == 1, nrow(res_dic) == 1)
md5_pub <- sub(".*Hash MD5 do arquivo: `([0-9a-f]{32})`.*", "\\1", res_csv$description)
stopifnot(grepl("^[0-9a-f]{32}$", md5_pub))
lp(sprintf("- Conjunto escolhido: \"%s\" (desembolsos-mensais). Descricao: \"%s\" Recurso CSV \"%s\", atualizado em %s, %s bytes, MD5 publicado %s; encoding Windows-1252, separador \";\" e decimal \",\" (segundo a descricao do recurso). Ficha em %s.",
           pkg$title, gsub("\\s+", " ", sub("\n\nPara maiores.*", "", pkg$notes)), res_csv$name, res_csv$last_modified,
           num_br(as.numeric(res_csv$size), 0), md5_pub, f_pkg))

# ---------------------------------------------------------------------------
# 2. Dicionario de dados
# ---------------------------------------------------------------------------
f_dic <- download_path("bndes", "dicionario_desembolsos_mensais", "pdf")
RETRY("GET", res_dic$url, write_disk(f_dic, overwrite = TRUE), times = 5, timeout(120))
CAMPOS_DIC <- c("Ano", "Mes", "Forma de apoio", "Produto", "Instrumento financeiro", "Inovacao", "Porte da empresa",
                "Regiao", "UF", "Municipio", "Municipio - codigo", "Setor CNAE", "Subsetor CNAE agrupado",
                "Setor BNDES", "Subsetor BNDES", "Desembolsos (R$)")
if (nzchar(Sys.which("pdftotext"))) {
  txt_dic <- iconv(paste(system2("pdftotext", c("-layout", shQuote(f_dic), "-"), stdout = TRUE), collapse = "\n"),
                   "UTF-8", "ASCII//TRANSLIT")
  achou <- vapply(CAMPOS_DIC, function(cmp) grepl(cmp, txt_dic, fixed = TRUE), logical(1))
  stopifnot(all(achou))
  tem_natureza <- grepl("natureza do cliente|natureza_do_cliente", txt_dic, ignore.case = TRUE)
  lp(sprintf("- Dicionario (%s, baixado para %s): %d campos, %s. %s",
             res_dic$url, f_dic, length(CAMPOS_DIC), paste(CAMPOS_DIC, collapse = "; "),
             ifelse(tem_natureza, "Ha campo de natureza do cliente.",
                    "Nao ha campo de natureza do cliente (publico ou privado) nem de controle acionario; \"Porte da empresa\" segue a classificacao do BNDES vigente na epoca.")))
}

# ---------------------------------------------------------------------------
# 3. Download do CSV (720 MB). Guardado comprimido com xz; o MD5 e o do arquivo original.
# ---------------------------------------------------------------------------
f_csv <- download_path("bndes", "desembolsos_mensais", "csv")
f_xz <- paste0(f_csv, ".xz")
if (!file.exists(f_xz)) {
  if (!file.exists(f_csv)) {
    RETRY("GET", res_csv$url, write_disk(f_csv, overwrite = TRUE), times = 5, timeout(3600))
  }
  md5_local <- unname(tools::md5sum(f_csv))
  stopifnot(identical(md5_local, md5_pub))
  st <- system2("xz", c("-T0", "-6", shQuote(f_csv)))
  stopifnot(st == 0, file.exists(f_xz))
} else {
  md5_local <- sub(" .*", "", system2("sh", c("-c", shQuote(paste("xz -dc", shQuote(f_xz), "| md5sum"))), stdout = TRUE))
  stopifnot(identical(md5_local, md5_pub))
}
lp(sprintf("- Download de %s. MD5 do arquivo baixado = %s, igual ao publicado. Para caber no repositorio, o bruto foi comprimido sem alteracao com xz: %s (%s MB).",
           res_csv$url, md5_local, f_xz, num_br(file.size(f_xz) / 1e6, 1)))

d <- read_delim(f_xz, delim = ";",
                locale = locale(encoding = "windows-1252", decimal_mark = ",", grouping_mark = "."),
                col_types = cols(.default = "c", ano = "i", mes = "i", desembolsos_reais = "d"), progress = FALSE)
stopifnot(nrow(problems(d)) == 0)
COLS <- c("ano", "mes", "forma_de_apoio", "produto", "instrumento_financeiro", "inovacao", "porte_de_empresa",
          "regiao", "uf", "municipio", "municipio_codigo", "setor_cnae", "subsetor_cnae_agrupado", "setor_bndes",
          "subsetor_bndes", "desembolsos_reais")
stopifnot(identical(names(d), COLS), !anyNA(d$ano), !anyNA(d$mes), !anyNA(d$desembolsos_reais))
d <- d %>% mutate(periodo = sprintf("%04d-%02d", ano, mes))
lp(sprintf("- Arquivo lido: %s linhas, colunas %s (as 16 do dicionario). Periodo %s a %s. Soma %s bilhoes de R$ nominais. Valores negativos: %d.",
           num_br(nrow(d), 0), paste(COLS, collapse = ", "), min(d$periodo), max(d$periodo),
           num_br(sum(d$desembolsos_reais) / 1e9, 1), sum(d$desembolsos_reais < 0)))

# ---------------------------------------------------------------------------
# 4. Recortes existentes (registro exato)
# ---------------------------------------------------------------------------
campos_rec <- c("forma_de_apoio", "produto", "instrumento_financeiro", "inovacao", "porte_de_empresa", "regiao", "uf",
                "setor_cnae", "subsetor_cnae_agrupado", "setor_bndes", "subsetor_bndes")
tot <- sum(d$desembolsos_reais)
recortes <- map_dfr(campos_rec, function(cmp) {
  d %>% group_by(valor = .data[[cmp]]) %>%
    summarise(n_linhas = n(), rs_bi = sum(desembolsos_reais) / 1e9, .groups = "drop") %>%
    mutate(campo = cmp, participacao = rs_bi * 1e9 / tot) %>% arrange(desc(rs_bi))
}) %>% select(campo, valor, n_linhas, rs_bi, participacao)
write_csv_safe(recortes, file.path(PATHS$results, "A2_bndes_recortes.csv"))
limpa_txt <- function(x) gsub("[\u2013\u2014]", "-", iconv(x, "UTF-8", "ASCII//TRANSLIT"))
resumo_campo <- function(cmp, top = Inf) {
  x <- recortes %>% filter(campo == cmp) %>% head(top)
  limpa_txt(paste(sprintf("%s (%s%%)", ifelse(is.na(x$valor), "sem valor", x$valor), num_br(100 * x$participacao, 1)), collapse = ", "))
}
lp("- Recortes que existem na base mensal (participacao na soma 1995-2026; tabela completa em results/A2_bndes_recortes.csv): ",
   sprintf("forma de apoio: %s; ", resumo_campo("forma_de_apoio")),
   sprintf("porte da empresa: %s; ", resumo_campo("porte_de_empresa")),
   sprintf("setor BNDES: %s; ", resumo_campo("setor_bndes")),
   sprintf("setor CNAE: %s; ", resumo_campo("setor_cnae")),
   sprintf("inovacao: %s; ", resumo_campo("inovacao")),
   sprintf("produto (%d valores): %s; ", sum(recortes$campo == "produto"), resumo_campo("produto", 6)),
   sprintf("instrumento financeiro: %d valores; subsetor CNAE agrupado: %d valores; subsetor BNDES: %d valores; regiao, UF (%d valores) e municipio (%d valores).",
           sum(recortes$campo == "instrumento_financeiro"), sum(recortes$campo == "subsetor_cnae_agrupado"),
           sum(recortes$campo == "subsetor_bndes"), sum(recortes$campo == "uf"), n_distinct(d$municipio_codigo)))

ADM <- "ADMINISTRAÇÃO PÚBLICA"
adm <- recortes %>% filter(campo == "subsetor_cnae_agrupado", valor == ADM)
stopifnot(nrow(adm) == 1)
maior_mc <- d %>% filter(produto == "BNDES MERCADO DE CAPITAIS") %>% slice_max(desembolsos_reais, n = 1, with_ties = FALSE)
porte_adm <- d %>% filter(subsetor_cnae_agrupado == ADM) %>% count(porte_de_empresa, wt = desembolsos_reais) %>%
  mutate(p = n / sum(n)) %>% arrange(desc(p)) %>% filter(p >= 0.001)
lp(sprintf("- Nao ha campo que separe empresas privadas. O que mais se aproxima e o subsetor CNAE agrupado \"ADMINISTRACAO PUBLICA\" (%s%% da soma, R$ %s bi; porte registrado: %s), que identifica credito a entes publicos (estados e municipios). Empresas estatais (Petrobras, Eletrobras, companhias estaduais de saneamento e energia) ficam nos setores de atividade e nao podem ser separadas nesta base; por exemplo, o instrumento \"PROGRAMA PETROBRAS\" soma R$ %s bi, e o maior lancamento do produto \"BNDES MERCADO DE CAPITAIS\" e de R$ %s bi em %s, no subsetor %s (compativel com a participacao do BNDES na capitalizacao da Petrobras, que a base nao identifica pelo nome).",
           num_br(100 * adm$participacao, 1), num_br(adm$rs_bi, 1),
           limpa_txt(paste(sprintf("%s %s%%", porte_adm$porte_de_empresa, num_br(100 * porte_adm$p, 1)), collapse = ", ")),
           num_br(sum(d$desembolsos_reais[d$instrumento_financeiro %in% "PROGRAMA PETROBRAS"]) / 1e9, 1),
           num_br(maior_mc$desembolsos_reais / 1e9, 1), maior_mc$periodo, limpa_txt(maior_mc$subsetor_cnae_agrupado)))

# Bases por contrato tem natureza do cliente, mas datadas pela contratacao.
campos_op <- map(c(nao_automaticas = "6f56b78c-510f-44b6-8274-78a5b7e931f4", indiretas_automaticas = "612faa0b-b6be-4b2c-9317-da5dc2c0b901"),
                 function(id) try(ckan("datastore_search", resource_id = id, limit = 0)$result$fields$id, silent = TRUE))
if (all(map_lgl(campos_op, ~ !inherits(.x, "try-error")))) {
  lp(sprintf("- No conjunto \"operacoes-financiamento\" (operacoes nao automaticas e indiretas automaticas, uma linha por contrato ou operacao) ha o campo natureza_do_cliente (%s), mas o valor vem como valor contratado e valor desembolsado acumulado, datados pela data_da_contratacao. Nao da uma serie mensal de desembolso por data de liberacao; serve, no maximo, para a participacao das empresas privadas por coorte de contratacao.",
             ifelse(all(map_lgl(campos_op, ~ "natureza_do_cliente" %in% .x)), "confirmado nas duas bases pelo datastore_search", "presente em parte das bases")))
}

# ---------------------------------------------------------------------------
# 5. Series mensais e trimestrais (R$ milhoes nominais)
# ---------------------------------------------------------------------------
MERC <- "BNDES MERCADO DE CAPITAIS"
d <- d %>% mutate(v = desembolsos_reais / 1e6,
                  e_adm = subsetor_cnae_agrupado %in% ADM, e_merc = produto %in% MERC)
bndes_m <- d %>% group_by(periodo) %>% summarise(
  desemb_total = sum(v),
  desemb_direta = sum(v[forma_de_apoio == "DIRETA"]),
  desemb_indireta = sum(v[forma_de_apoio == "INDIRETA"]),
  desemb_porte_grande = sum(v[porte_de_empresa == "GRANDE"]),
  desemb_porte_mpme = sum(v[porte_de_empresa %in% c("MICRO", "PEQUENA", "MÉDIA")]),
  desemb_setor_infraestrutura = sum(v[setor_bndes == "INFRAESTRUTURA"]),
  desemb_setor_industria = sum(v[setor_bndes == "INDUSTRIA"]),
  desemb_setor_comercio_servicos = sum(v[setor_bndes == "COMÉRCIO E SERVIÇOS"]),
  desemb_setor_agropecuaria = sum(v[setor_bndes == "AGROPECUÁRIA"]),
  desemb_finame = sum(v[produto == "BNDES FINAME"]),
  desemb_mercado_capitais = sum(v[e_merc]),
  desemb_adm_publica = sum(v[e_adm]),
  desemb_exc_adm_publica = sum(v[!e_adm]),
  desemb_exc_adm_publica_merc_capitais = sum(v[!e_adm & !e_merc]),
  .groups = "drop")
meses <- format(seq(as.Date(paste0(min(bndes_m$periodo), "-01")), as.Date(paste0(max(bndes_m$periodo), "-01")), by = "month"), "%Y-%m")
stopifnot(identical(bndes_m$periodo, meses))
# Os recortes de cada grupo somam o total.
with(bndes_m, stopifnot(
  max(abs(desemb_direta + desemb_indireta - desemb_total)) < 1e-6,
  max(abs(desemb_porte_grande + desemb_porte_mpme - desemb_total)) < 1e-6,
  max(abs(desemb_setor_infraestrutura + desemb_setor_industria + desemb_setor_comercio_servicos + desemb_setor_agropecuaria - desemb_total)) < 1e-6,
  max(abs(desemb_adm_publica + desemb_exc_adm_publica - desemb_total)) < 1e-6))
bndes_m <- bndes_m %>%
  mutate(trimestre = q_key(as.integer(substr(periodo, 1, 4)), (as.integer(substr(periodo, 6, 7)) - 1) %/% 3 + 1))
write_csv_safe(bndes_m, file.path(PATHS$processed, "A2_bndes_mensal.csv"))

fun <- setNames(rep("soma", ncol(bndes_m) - 2), setdiff(names(bndes_m), c("periodo", "trimestre")))
bndes_q <- mensal_para_trimestral(bndes_m %>% select(-trimestre), fun) %>%
  select(trimestre, all_of(names(fun))) %>% filter(!is.na(desemb_total))
write_csv_safe(bndes_q, file.path(PATHS$processed, "A2_bndes_trimestral.csv"))

lp(sprintf("- Mensal (data/processed/A2_bndes_mensal.csv, %s a %s, R$ milhoes nominais): desemb_total; por forma de apoio (direta, indireta); por porte (grande; micro, pequena e media); por setor BNDES (infraestrutura, industria, comercio e servicos, agropecuaria); produto BNDES FINAME (maquinas e equipamentos); produto BNDES MERCADO DE CAPITAIS; subsetor CNAE ADMINISTRACAO PUBLICA; total exceto administracao publica (desemb_exc_adm_publica) e exceto administracao publica e mercado de capitais. Cada grupo de recortes soma o total. Trimestral (A2_bndes_trimestral.csv, %s a %s): soma dos tres meses. Sem deflacionar e sem ajuste sazonal.",
           min(bndes_m$periodo), max(bndes_m$periodo), min(bndes_q$trimestre), max(bndes_q$trimestre)))
lp("- A serie desemb_exc_adm_publica e o recorte mais proximo de \"empresas privadas\" que a base permite, mas inclui as estatais. ",
   "Nao deve ser chamada de privada no texto sem essa ressalva.")

# ---------------------------------------------------------------------------
# 6. Comparacao dos totais anuais
# ---------------------------------------------------------------------------
anual <- bndes_m %>% group_by(ano = as.integer(substr(periodo, 1, 4))) %>%
  summarise(meses = n(), mensal_bi = sum(desemb_total) / 1e3, .groups = "drop")
raw_a <- read_csv(file.path(PATHS$raw, "bndes_anual.csv"), show_col_types = FALSE) %>%
  transmute(ano = as.integer(y), raw_bndes_anual_bi = total)
pai <- read_csv(file.path(PATHS$downloads, "2026-09-28_painel_bndes_desembolsos_anual_uf.csv"), show_col_types = FALSE)
macro_pai <- sort(unique(pai$macrosector))
pai <- pai %>% group_by(ano = as.integer(year)) %>% summarise(painel_uf_bi = sum(disbursed) / 1e3, .groups = "drop")
infra <- bndes_m %>% group_by(ano = as.integer(substr(periodo, 1, 4))) %>%
  summarise(infra_bi = sum(desemb_setor_infraestrutura) / 1e3, .groups = "drop")
cmp_a <- anual %>% left_join(raw_a, by = "ano") %>% left_join(pai, by = "ano") %>% left_join(infra, by = "ano") %>%
  mutate(dif_pct_raw = 100 * (mensal_bi / raw_bndes_anual_bi - 1),
         painel_part_total_pct = 100 * painel_uf_bi / mensal_bi,
         painel_sobre_setor_infra = painel_uf_bi / infra_bi)
print(cmp_a, n = 40)
write_csv_safe(cmp_a, file.path(PATHS$results, "A2_bndes_comparacao_anual.csv"))
cr <- cmp_a %>% filter(!is.na(dif_pct_raw), meses == 12)
cp <- cmp_a %>% filter(!is.na(painel_uf_bi), meses == 12)
lp(sprintf("- Totais anuais (soma dos 12 meses, R$ bi nominais) contra data/raw/bndes_anual.csv (coluna total, %d a %d): diferenca maxima em modulo %s%%; as series coincidem. Exemplos: 2002 %s (raw %s); 2013 %s (raw %s); 2025 %s (raw %s).",
           min(cr$ano), max(cr$ano), num_br(max(abs(cr$dif_pct_raw)), 4),
           num_br(cmp_a$mensal_bi[cmp_a$ano == 2002], 1), num_br(cmp_a$raw_bndes_anual_bi[cmp_a$ano == 2002], 1),
           num_br(cmp_a$mensal_bi[cmp_a$ano == 2013], 1), num_br(cmp_a$raw_bndes_anual_bi[cmp_a$ano == 2013], 1),
           num_br(cmp_a$mensal_bi[cmp_a$ano == 2025], 1), num_br(cmp_a$raw_bndes_anual_bi[cmp_a$ano == 2025], 1)))
lp(sprintf("- O painel por UF (data/downloads/2026-09-28_painel_bndes_desembolsos_anual_uf.csv) nao e o total: so tem os macrossetores de infraestrutura da classificacao do painel (%s). Soma de disbursed de %d a %d: de %s%% a %s%% do total anual (2013: R$ %s bi, contra R$ %s bi no setor BNDES INFRAESTRUTURA da base mensal). Por isso a conferencia de total e feita contra data/raw/bndes_anual.csv. Tabela em results/A2_bndes_comparacao_anual.csv.",
           paste(macro_pai, collapse = ", "), min(cp$ano), max(cp$ano),
           num_br(min(cp$painel_part_total_pct), 1), num_br(max(cp$painel_part_total_pct), 1),
           num_br(cmp_a$painel_uf_bi[cmp_a$ano == 2013], 1), num_br(cmp_a$infra_bi[cmp_a$ano == 2013], 1)))
lp("- O autor mencionou um arquivo local de desembolsos mensais que nao esta neste conteiner; falta confirmar se e esta mesma base (desembolsos-mensais do portal de dados abertos).")

# ---------------------------------------------------------------------------
# 7. Metadados
# ---------------------------------------------------------------------------
desc_serie <- c(
  desemb_total = "total", desemb_direta = "forma_de_apoio = DIRETA", desemb_indireta = "forma_de_apoio = INDIRETA",
  desemb_porte_grande = "porte_de_empresa = GRANDE", desemb_porte_mpme = "porte_de_empresa em MICRO, PEQUENA, MEDIA",
  desemb_setor_infraestrutura = "setor_bndes = INFRAESTRUTURA", desemb_setor_industria = "setor_bndes = INDUSTRIA",
  desemb_setor_comercio_servicos = "setor_bndes = COMERCIO E SERVICOS", desemb_setor_agropecuaria = "setor_bndes = AGROPECUARIA",
  desemb_finame = "produto = BNDES FINAME", desemb_mercado_capitais = "produto = BNDES MERCADO DE CAPITAIS",
  desemb_adm_publica = "subsetor_cnae_agrupado = ADMINISTRACAO PUBLICA",
  desemb_exc_adm_publica = "total exceto subsetor_cnae_agrupado = ADMINISTRACAO PUBLICA (inclui estatais)",
  desemb_exc_adm_publica_merc_capitais = "total exceto ADMINISTRACAO PUBLICA e exceto produto BNDES MERCADO DE CAPITAIS"
)
meta <- tibble(
  serie = names(desc_serie), fonte = "BNDES/Dados Abertos", codigo = sprintf("desembolsos-mensais (recurso %s)", res_csv$id),
  titulo_nos_metadados = sprintf("%s; Desembolsos (R$): %s", pkg$title, desc_serie), unidade = "R$ milhoes nominais",
  periodicidade = "mensal", periodo = sprintf("%s a %s", min(bndes_m$periodo), max(bndes_m$periodo)),
  url = res_csv$url, arquivo_download = f_xz,
  transformacao = "soma de desembolsos_reais no mes / 1e6; trimestral = soma dos 3 meses"
)
gravar_metadados(meta, "BNDES/Dados Abertos")

log_secao_fim()
save_session_info("A2_download_bndes")
cat("A2_download_bndes.R concluido.\n")
