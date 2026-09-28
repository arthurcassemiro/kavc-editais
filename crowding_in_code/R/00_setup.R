# Convencoes comuns a todos os scripts da Parte A.
# Uso: source("R/00_setup.R") a partir da raiz do projeto (pasta crowding_in_code/).

suppressPackageStartupMessages({
  library(tidyverse)
  library(zoo)
})

options(stringsAsFactors = FALSE, scipen = 999, width = 150)
set.seed(42)

PATHS <- list(
  original  = "data/original",
  raw       = "data/raw",
  downloads = "data/downloads",
  processed = "data/processed",
  results   = "results",
  figuras   = "results/figuras",
  log_parts = "results/log_parts"
)
for (p in PATHS[c("downloads", "processed", "results", "figuras", "log_parts")]) {
  dir.create(p, showWarnings = FALSE, recursive = TRUE)
}

HOJE <- format(Sys.Date(), "%Y-%m-%d")

# Protecao: nunca escrever em data/original nem em data/raw.
# O conteiner roda como root, entao chmod nao protege: toda escrita deve passar por guard_path
# (write_csv_safe, write_lines_safe, ggsave_safe, log_part, save_session_info).
# Caminho absoluto: relativo ao diretorio de trabalho, com "." e ".." resolvidos e links
# simbolicos resolvidos no maior prefixo que existe (vale para arquivos e pastas ainda inexistentes).
abs_path <- function(path) {
  p <- path.expand(as.character(path))
  if (!startsWith(p, "/")) p <- file.path(getwd(), p)
  pilha <- character(0)
  for (s in strsplit(p, "/", fixed = TRUE)[[1]]) {
    if (s %in% c("", ".")) next
    if (s == "..") pilha <- head(pilha, -1) else pilha <- c(pilha, s)
  }
  n <- length(pilha)
  for (k in n:0) {
    pref <- paste0("/", paste(pilha[seq_len(k)], collapse = "/"))
    if (file.exists(pref)) {
      base <- normalizePath(pref, mustWork = TRUE)
      resto <- pilha[setdiff(seq_len(n), seq_len(k))]
      return(if (length(resto)) paste(c(sub("/$", "", base), resto), collapse = "/") else base)
    }
  }
}

guard_path <- function(path) {
  alvo <- abs_path(path)
  for (d in c(PATHS$original, PATHS$raw)) {
    pd <- abs_path(d)
    if (identical(alvo, pd) || startsWith(alvo, paste0(pd, "/"))) {
      stop("Escrita proibida em ", d, ": ", path)
    }
  }
  invisible(path)
}

write_csv_safe <- function(x, path, ...) {
  guard_path(path)
  readr::write_csv(x, path, na = "", ...)
  invisible(path)
}

write_lines_safe <- function(text, path, ...) {
  guard_path(path)
  writeLines(text, path, ...)
  invisible(path)
}

ggsave_safe <- function(filename, plot = ggplot2::last_plot(), ...) {
  guard_path(filename)
  ggplot2::ggsave(filename, plot, ...)
  invisible(filename)
}

# Arquivo de download com a data no nome: data/downloads/AAAA-MM-DD_<fonte>_<codigo>.csv
download_path <- function(fonte, codigo, ext = "csv") {
  file.path(PATHS$downloads, sprintf("%s_%s_%s.%s", HOJE, fonte, codigo, ext))
}

# Registro de decisoes. Cada script escreve em results/log_parts/<etapa>.md;
# o LOG.md principal e consolidado a partir dessas partes.
log_part <- function(etapa, ...) {
  f <- guard_path(file.path(PATHS$log_parts, paste0(etapa, ".md")))
  txt <- paste0(...)
  cat(txt, "\n", file = f, append = TRUE, sep = "")
  invisible(txt)
}
log_reset <- function(etapa) {
  f <- guard_path(file.path(PATHS$log_parts, paste0(etapa, ".md")))
  cat(sprintf("### %s (execucao de %s)\n", etapa, format(Sys.time(), "%Y-%m-%d %H:%M")), file = f)
}

save_session_info <- function(script) {
  si <- capture.output(sessionInfo())
  hdr <- sprintf("# %s, executado em %s", script, format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  write_lines_safe(c(hdr, si), file.path(PATHS$results, "session_info.txt"))
  dir.create(file.path(PATHS$results, "session_info"), showWarnings = FALSE)
  write_lines_safe(c(hdr, si), file.path(PATHS$results, "session_info", paste0(script, ".txt")))
}

# Trimestres: chave textual "2003Q1" e conversoes.
q_key <- function(ano, tri) sprintf("%dQ%d", as.integer(ano), as.integer(tri))
q_from_date <- function(d) q_key(lubridate::year(d), lubridate::quarter(d))
q_to_yearqtr <- function(k) zoo::as.yearqtr(gsub("Q", " Q", k))
q_seq <- function(de, ate) {
  a <- q_to_yearqtr(de); b <- q_to_yearqtr(ate)
  s <- seq(as.numeric(a), as.numeric(b), by = 0.25)
  format(zoo::as.yearqtr(s), "%YQ%q")
}
ts_from_q <- function(x, keys) {
  y0 <- q_to_yearqtr(keys[1])
  ts(x, start = c(as.integer(floor(as.numeric(y0))), as.integer(format(y0, "%q"))), frequency = 4)
}

# Ajuste sazonal X-11 (X-13ARIMA-SEATS, modo X-11) com o pacote seasonal.
# Retorna a serie ajustada; o objeto seas vai como atributo para registro.
x11_sa <- function(x_ts, ...) {
  m <- seasonal::seas(x_ts, x11 = "", ...)
  out <- seasonal::final(m)
  attr(out, "seas_model") <- m
  out
}

# Classificacao por funcao (Portaria MOG 42/1999), definida pelo autor.
FUNCOES_ECONOMICA <- c("24" = "COMUNICACOES", "25" = "ENERGIA", "26" = "TRANSPORTE")
FUNCOES_SOCIAL <- c("08" = "ASSISTENCIA SOCIAL", "10" = "SAUDE", "12" = "EDUCACAO",
                    "15" = "URBANISMO", "16" = "HABITACAO", "17" = "SANEAMENTO",
                    "27" = "DESPORTO E LAZER")

# Filtro de elementos da dissertacao (modalidade 90).
ELEMENTOS_DISSERTACAO <- c("OBRAS E INSTALACOES", "EQUIPAMENTOS E MATERIAL PERMANENTE",
                           "AQUISICAO DE IMOVEIS", "DESPESAS DE EXERCICIOS ANTERIORES",
                           "SENTENCAS JUDICIAIS", "INDENIZACOES E RESTITUICOES")
