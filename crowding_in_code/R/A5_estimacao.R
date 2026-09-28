# A5, script mestre: roda a parte VAR/VEC (R/A5_var.R) e depois a parte de projecoes locais (R/A5_lp.R),
# cada uma num processo R separado, na ordem, e para no primeiro erro.
# Uso: cd crowding_in_code && Rscript R/A5_estimacao.R            (roda as duas partes)
#      cd crowding_in_code && Rscript R/A5_estimacao.R A5_lp      (roda so as partes nomeadas, na ordem padrao)
# As decisoes de cada parte ficam em results/log_parts/A5_var.md e A5_lp.md; este script registra so a execucao.

source("R/00_setup.R")

ETAPA <- "A5_estimacao"
PARTES <- c("A5_var", "A5_lp")
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  stopifnot(all(args %in% PARTES))
  PARTES <- PARTES[PARTES %in% args]
}

log_reset(ETAPA)
set.seed(42)
t0 <- Sys.time()
for (pt in PARTES) {
  arq <- file.path("R", paste0(pt, ".R"))
  stopifnot(file.exists(arq))
  cat(sprintf("== %s: %s\n", format(Sys.time(), "%H:%M:%S"), arq))
  ti <- Sys.time()
  st <- system2("Rscript", arq)
  dt <- as.numeric(difftime(Sys.time(), ti, units = "secs"))
  log_part(ETAPA, sprintf("- %s: status %d, %s s.", arq, st, formatC(dt, format = "f", digits = 0)))
  if (st != 0) stop("Falhou: ", arq, " (status ", st, ")")
}
log_part(ETAPA, sprintf("- Partes executadas, nesta ordem: %s. Tempo total: %s s.", paste(PARTES, collapse = ", "),
                        formatC(as.numeric(difftime(Sys.time(), t0, units = "secs")), format = "f", digits = 0)))
save_session_info("A5_estimacao")
