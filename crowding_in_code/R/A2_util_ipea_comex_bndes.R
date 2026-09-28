# Helpers comuns aos scripts da etapa A2, parte Ipeadata, Comex Stat, BNDES e validacao anual.
# Uso: source("R/00_setup.R"); source("R/A2_util_ipea_comex_bndes.R")

ETAPA <- "A2_ipea_comex_bndes"
# Ordem fixa das secoes no log da etapa (um script por secao).
SECOES_A2ICB <- c("#### Ipeadata", "#### Comex Stat", "#### BNDES", "#### Validacao anual")
F_META_A2ICB <- file.path(PATHS$processed, "A2_metadados_ipea_comex_bndes.csv")

num_br <- function(x, d = 3) formatC(x, format = "f", digits = d, decimal.mark = ",", big.mark = ".")

# Le o log da etapa e separa as secoes "#### ...".
ler_secoes <- function() {
  f <- file.path(PATHS$log_parts, paste0(ETAPA, ".md"))
  if (!file.exists(f)) return(list())
  l <- readLines(f, warn = FALSE)
  i <- grep("^#### ", l)
  if (!length(i)) return(list())
  fim <- c(i[-1] - 1, length(l))
  out <- lapply(seq_along(i), function(k) l[i[k]:fim[k]])
  names(out) <- vapply(i, function(k) {
    m <- SECOES_A2ICB[vapply(SECOES_A2ICB, function(s) startsWith(l[k], s), logical(1))]
    if (length(m)) m[1] else l[k]
  }, character(1))
  out
}

# Reescreve o log com as secoes na ordem fixa.
escrever_secoes <- function(secoes) {
  force(secoes)  # avaliar antes de apagar o arquivo
  log_reset(ETAPA)
  ordem <- c(intersect(SECOES_A2ICB, names(secoes)), setdiff(names(secoes), SECOES_A2ICB))
  for (s in ordem) log_part(ETAPA, paste(secoes[[s]], collapse = "\n"))
}

# Inicio de um script: remove a secao antiga do proprio script e abre a nova no fim do arquivo.
log_secao_inicio <- function(marca, script) {
  sec <- ler_secoes()
  sec[[marca]] <- NULL
  escrever_secoes(sec)
  log_part(ETAPA, sprintf("%s (R/%s.R, execucao de %s)", marca, script, format(Sys.time(), "%Y-%m-%d %H:%M")))
}

# Fim de um script: reordena as secoes.
log_secao_fim <- function() escrever_secoes(ler_secoes())

lp <- function(...) log_part(ETAPA, ...)

# Metadados: substitui as linhas das fontes deste script e preserva as dos outros.
gravar_metadados <- function(meta, fontes) {
  cols <- c("serie", "fonte", "codigo", "titulo_nos_metadados", "unidade", "periodicidade",
            "periodo", "url", "arquivo_download", "transformacao")
  meta <- meta %>% mutate(across(everything(), as.character)) %>% select(all_of(cols))
  if (file.exists(F_META_A2ICB)) {
    velho <- read_csv(F_META_A2ICB, show_col_types = FALSE, col_types = cols(.default = "c")) %>%
      filter(!fonte %in% fontes)
    meta <- bind_rows(velho, meta)
  }
  ordem_fonte <- c("Ipea/Carta de Conjuntura", "Ipeadata", "Comex Stat/MDIC", "BCB/SGS", "BNDES/Dados Abertos",
                   "FGV IBRE", "Ipeadata (IBGE/SCN)")
  meta <- meta %>% mutate(o = match(fonte, ordem_fonte)) %>% arrange(o) %>% select(-o)
  write_csv_safe(meta, F_META_A2ICB)
}

# Agregacao mensal -> trimestral. Mantem so trimestres com os 3 meses observados.
# fun: "media" (indices, taxas e precos) ou "soma" (fluxos).
mensal_para_trimestral <- function(df, fun) {
  stopifnot(all(c("periodo") %in% names(df)))
  df %>%
    mutate(ano = as.integer(substr(periodo, 1, 4)), mes = as.integer(substr(periodo, 6, 7)),
           trimestre = q_key(ano, (mes - 1) %/% 3 + 1)) %>%
    select(-ano, -mes, -periodo) %>%
    pivot_longer(-trimestre, names_to = "serie", values_to = "valor") %>%
    group_by(trimestre, serie) %>%
    summarise(n_ok = sum(!is.na(valor)),
              valor = if (n_ok[1] == 3) (if (fun[serie[1]] == "soma") sum(valor) else mean(valor)) else NA_real_,
              .groups = "drop") %>%
    select(-n_ok) %>%
    pivot_wider(names_from = serie, values_from = valor) %>%
    arrange(q_to_yearqtr(trimestre))
}
