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
qt <- function(q) sub("Q", "T", q)  # notacao do texto: 2003T1

# Regra de aptidao para as projecoes locais (A5): fica fora toda serie com Q do X-11 > Q_MAX,
# erro maximo de arredondamento > ERRO_MAX ou sem log10. Dashboard, OI e boletim da SEST vem em R$ bi com
# 4 casas: cada parcela somada tem erro de ate ARRED.
Q_MAX <- 1
ERRO_MAX <- 0.02
ARRED <- 0.00005

SEG_PETRO <- "Oil, gas & derivatives"
SEG_ECON <- c("Electricity", "Transport", "Port administration", "Airport administration")
SEG_OUTRAS <- c("Financial", "Commerce & services", "Industry", "Research, development & planning", "Food supply")
MOD_DIRETA <- c("90", "91")
MOD_OUTRA <- c("67", "99")
MOD_ESTMUN <- c("30", "31", "32", "40", "41", "42", "71", "72")
MOD_PRIVADA <- c("50", "60")
MOD_EXTERIOR <- c("80")
TXT_MOD_NAO_ESTMUN <- "50 e 60 (entidades privadas), 70 (instituicoes multigovernamentais) e 80 (exterior)"

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
  "data/processed/A2_deflator_ipca.csv e data/original/0224_tri_estmeq.txt. Janela das series: ", qt(Q_INI), " a ", qt(Q_FIM), ".")

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
# Limite do erro quando o gasto se concentra no ultimo mes do trimestre (dezembro no T4)
dif_fim <- DEFL %>% filter(q %in% QS) %>% mutate(d = fim_tri / media_tri - 1, t = substr(q, 6, 6))
dif_fim_t4 <- dif_fim %>% filter(t == "4")
L("Deflator: fator trimestral de data/processed/A2_deflator_ipca.csv (100 / media dos tres indices mensais do IPCA no ",
  "trimestre, media de 2025 = 100); real = nominal x fator, em R$ de 2025. Conferido: o fator do arquivo e igual a ",
  "100 / media dos indices mensais (diferenca maxima ", format(max(abs(chk_q$fator_calc - chk_q$fator_media), na.rm = TRUE), digits = 2, decimal.mark = ","), ").")
L("Nao ha bruto mensal no conteiner (so series trimestrais nominais), entao o IPCA mensal nao pode ser aplicado antes de ",
  "agregar, como pede o briefing. Com gasto uniforme dentro do trimestre, o fator exato seria a media dos fatores mensais ",
  "(media harmonica dos indices), e a diferenca para o fator usado seria de no maximo ", fmt(100 * max(abs(dif_harm)), 4),
  "% (", qt(Q_INI), "-", qt(Q_FIM), "). Mas a execucao federal nao e uniforme: concentra-se em dezembro. O limite do erro e ",
  "a diferenca entre o fator do ultimo mes e o fator do indice medio (todo o gasto no ultimo mes): de ",
  fmt(100 * min(abs(dif_fim$d)), 2), "% a ", fmt(100 * max(abs(dif_fim$d)), 2), "% em modulo (media ",
  fmt(100 * mean(abs(dif_fim$d)), 2), "%), com o fator medio acima do fator do ultimo mes em ", sum(dif_fim$d < 0), " de ",
  nrow(dif_fim), " trimestres, ou seja, o valor real sai superestimado. No T4, onde a concentracao em dezembro pesa, a ",
  "diferenca vai de ", fmt(100 * min(abs(dif_fim_t4$d)), 2), "% a ", fmt(100 * max(abs(dif_fim_t4$d)), 2), "% (media ",
  fmt(100 * mean(abs(dif_fim_t4$d)), 2), "%). O vies e sobretudo sazonal (4o trimestre) e a parte estavel dele vai para o ",
  "fator sazonal do X-11; a parte que varia com a inflacao de cada trimestre nao e absorvida. Refazer com o IPCA mensal ",
  "quando houver o bruto mensal (federal_gnd4_mensal.csv).")

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

L("Serie federal filtrada (modalidade 90 e os 6 elementos da dissertacao): ", nrow(fil_raw), " trimestres, ",
  qt(min(fil_raw$q)), " a ", qt(max(fil_raw$q)), "; faltam os 4 trimestres de 2017: ",
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

# O grupo 2 do dashboard nao e 67 e 99: confere contra as modalidades da base anual
g2_ano <- dash %>% filter(grupo == 2) %>% group_by(ano) %>% summarise(g2 = sum(nom), .groups = "drop")
m_ano <- pan %>% group_by(ano) %>%
  summarise(m3242 = sum(v[modalidade %in% c("32", "42")]), m6799 = sum(v[modalidade %in% MOD_OUTRA]),
            m15 = sum(v[modalidade == "15"]), transf = sum(v[grupo_mod == "transferencia"]), .groups = "drop")
g12_ano <- dash %>% filter(grupo %in% 1:2) %>% group_by(ano) %>% summarise(g12 = sum(nom), g1 = sum(nom[grupo == 1]), .groups = "drop")
chk_g2 <- m_ano %>% left_join(g2_ano, by = "ano") %>% left_join(g12_ano, by = "ano") %>% mutate(g2 = coalesce(g2, 0))
chk_g2_j <- chk_g2 %>% filter(ano >= 2003, ano <= 2025)
anos_g2 <- chk_g2_j$ano[chk_g2_j$g2 > 0]
L("Grupo 2 do dashboard trimestral: nao contem as modalidades 67 e 99 (a base anual nao tem nenhuma linha com 67 ou 99, soma ",
  fmt(sum(chk_g2$m6799), 3), "). Em 2003-2025 ele so tem valores de ", min(anos_g2), " em diante e coincide com as modalidades 32 e 42 ",
  "(execucao orcamentaria delegada a estados e a municipios) da base anual: diferenca maxima em modulo R$ ",
  fmt(max(abs(chk_g2_j$g2 - chk_g2_j$m3242)), 4), " bi por ano (em 2001, o grupo 2 e a modalidade 15). Antes de ", min(anos_g2),
  " as modalidades 32 e 42 nao aparecem. Os grupos 1 e 2 somados reproduzem as transferencias da base anual (todas as modalidades ",
  "exceto 90, 91, 67 e 99): diferenca maxima R$ ", fmt(max(abs(chk_g2_j$g12 - chk_g2_j$transf)), 4), " bi por ano; so o grupo 1 fica ",
  "abaixo em ate R$ ", fmt(max(chk_g2_j$transf - chk_g2_j$g1), 3), " bi por ano.")
L("Decisao: nas series de transferencia e de direta + transferencia, transferencia = grupos 1 e 2 do dashboard (todas as ",
  "modalidades exceto 90 e 91; em 2003-2025 o grupo 2 e so 32 e 42). Motivo: 32 e 42 sao execucao delegada a estados e ",
  "municipios, estao na lista de modalidades de estados e municipios pedida para o destino das transferencias, e as parcelas ",
  "do LOG (R$ 192 bi e R$ 16 bi de transferencias) so batem com elas incluidas. Na economica o efeito e grande (transporte ",
  "delegado a estados a partir de 2012). Variantes literais so com o grupo 1 ficam com sufixo _g1 (uniao_econ_dt_g1, ",
  "uniao_soc_dt_g1, uniao_transf_econ_g1, uniao_transf_soc_g1). O autor deve confirmar.")

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
# Diferenca para o LOG do autor (0,62 em 2016 e 0,72 em 2018): media das razoes trimestrais x razao das somas anuais,
# e denominador so com a modalidade 90 (sem a 91)
r_med_q <- razao_q %>% group_by(ano) %>% summarise(r = mean(r), .groups = "drop")
r_m90 <- pan %>% filter(ano %in% c(2016, 2018)) %>% group_by(ano) %>%
  summarise(r = sum(v[modalidade == "90" & elemento %in% ELEMENTOS_DISSERTACAO]) / sum(v[modalidade == "90"]), .groups = "drop")
L2("Diferenca para o LOG do autor (0,62 em 2016 e 0,72 em 2018): a razao anual acima e a razao das somas (",
   paste0(c(2016, 2018), " ", sapply(c(2016, 2018), function(a) with(filter(razao_q, ano == a), fmt(sum(fil) / sum(g0), 3))), collapse = "; "),
   "). A media das quatro razoes trimestrais da ", paste0(r_med_q$ano, " ", fmt(r_med_q$r, 3), collapse = " e "),
   ", que arredonda para os valores do LOG. A modalidade 91 nao explica a diferenca: com denominador so na modalidade 90 ",
   "(base anual), a razao e ", paste0(r_m90$ano, " ", fmt(r_m90$r, 3), collapse = " e "), ". Os dois valores do LOG batem ",
   "com a media das razoes trimestrais. O numero anual nao entra na imputacao: a baseline usa so o perfil do grupo 0 de 2017 e ",
   "a robustez usa a razao de cada trimestre (media de 2016 e 2018).")

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

# Conferencia pelo Apendice A da dissertacao (Ipub nominal, com 2017 observado na epoca):
# (filtro + SEST)/Ipub varia de forma suave; interpolando essa razao em 2017, Ipub x razao - SEST
# recupera o filtro trimestral de 2017 usado na dissertacao.
bol0 <- read_csv("data/raw/sest_boletim_trimestral_2003_2019.csv", show_col_types = FALSE) %>%
  filter(regiao == "Brazil (total)") %>% transmute(q = q_key(ano, trimestre), sest = valor_nominal_bi)
apx <- read_csv("data/dados_dissertacao_apendiceA.csv", show_col_types = FALSE) %>%
  transmute(q = trimestre, ipub = ipub_rs / 1e9) %>%
  inner_join(bol0, by = "q") %>% left_join(fil_raw %>% select(q, fil = nom), by = "q") %>%
  mutate(r = (fil + sest) / ipub, c_sest = sest / (ipub - fil))
r_ok <- apx %>% filter(!is.na(r))
q17 <- q_seq("2017Q1", "2017Q4")
interp <- function(v) v[apx$q == "2016Q4"] + (v[apx$q == "2018Q1"] - v[apx$q == "2016Q4"]) * (1:4) / 5
r17 <- interp(apx$r); c17 <- interp(apx$c_sest)
a17 <- apx %>% filter(q %in% q17) %>% arrange(q)
impl_tot <- r17 * a17$ipub - a17$sest
impl_sest <- a17$ipub - a17$sest / c17
imp_apx <- tibble(q = q17, tri = 1:4, bruto = impl_tot, nom = impl_tot * TOT_2017 / sum(impl_tot))
L("Conferencia pelo Apendice A (data/dados_dissertacao_apendiceA.csv, Ipub nominal 2002-2019, com 2017): a razao ",
  "(filtro + SEST boletim)/Ipub sobe de forma suave de ", fmt(r_ok$r[1], 3), " (2003T1) a ", fmt(r_ok$r[nrow(r_ok)], 3),
  " (2019T4), desvio padrao das variacoes trimestrais ", fmt(sd(diff(r_ok$r)), 5), ". Interpolando linearmente a razao entre ",
  "2016T4 e 2018T1, Ipub x razao - SEST da o filtro de 2017 usado na dissertacao: ",
  paste0("T", 1:4, " ", fmt(impl_tot, 3), collapse = "; "), "; soma R$ ", fmt(sum(impl_tot), 3), " bi contra R$ ",
  fmt(TOT_2017, 3), " bi exatos da base anual (diferenca ", pct(sum(impl_tot) / TOT_2017 - 1, 2), "). Supondo a diferenca so ",
  "na SEST (razao SEST/(Ipub - filtro), menos suave: desvio padrao ", fmt(sd(diff(r_ok$c_sest)), 5), "), o resultado quase nao muda: ",
  paste0("T", 1:4, " ", fmt(impl_sest, 3), collapse = "; "), "; soma ", fmt(sum(impl_sest), 3), ".")
L("Perfil trimestral de 2017 (participacao no ano): baseline (grupo 0) ", paste(pct(imp_base$nom / TOT_2017), collapse = ", "),
  "; razao do trimestre ", paste(pct(imp_raz$nom / TOT_2017), collapse = ", "), "; implicito no Apendice A ",
  paste(pct(imp_apx$bruto / sum(imp_apx$bruto)), collapse = ", "), ". Desvio absoluto medio contra o Apendice A: baseline ",
  fmt(mean(abs(imp_base$nom - imp_apx$nom)), 3), " bi; razao ", fmt(mean(abs(imp_raz$nom - imp_apx$nom)), 3), " bi. ",
  "A serie implicita no Apendice A, reescalada ao total exato, entra como terceira variante (uniao_filtro_diss_impapendice).")

fil_base <- bind_rows(fil_raw %>% select(q, nom), imp_base %>% select(q, nom)) %>% arrange(q)
fil_raz <- bind_rows(fil_raw %>% select(q, nom), imp_raz %>% select(q, nom)) %>% arrange(q)
fil_apx <- bind_rows(fil_raw %>% select(q, nom), imp_apx %>% select(q, nom)) %>% arrange(q)
FIL <- list(base = fil_base, razao = fil_raz, apendice = fil_apx)
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
oi_tot <- oi %>% group_by(q) %>% summarise(oi = sum(valor_nominal_bi), n_parc = n(), .groups = "drop")
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
     "; minimo ", fmt(s$r_min, 3), ", maximo ", fmt(s$r_max, 3), "; OI/boletim - 1 = ", pct(1 / s$r_soma - 1), ".")
}
L2("2016T1-2019T4: media das razoes trimestrais ", fmt(R_BASE, 4), " (usada no baseline); razao das somas ", fmt(R_SOMA, 4), ".")
L("Leitura: o OI fica ", pct(min(1 / sobre_ano$r_soma[sobre_ano$ano <= 2018] - 1)), " a ", pct(max(1 / sobre_ano$r_soma[sobre_ano$ano <= 2018] - 1)),
  " acima do boletim em 2016-2018, mas ", pct(1 - 1 / sobre_ano$r_soma[sobre_ano$ano == 2019]), " abaixo em 2019, sobretudo em 2019T4 ",
  "(razao boletim/OI ", fmt(sobre$r[sobre$q == "2019Q4"], 3), "). O LOG anterior (OI 10% a 15% acima) vale para 2016-2018. Por isso a ",
  "razao media da sobreposicao (", fmt(R_BASE, 4), ") e a razao so de 2019 (", fmt(sobre_ano$r_media[sobre_ano$ano == 2019], 4),
  ") levam a niveis bem diferentes depois de 2020.")

encadeia <- function(ano_emenda, r) {
  q_em <- q_key(ano_emenda, 1)
  # err: limite do erro de arredondamento (4 casas por parcela), na unidade da serie
  bind_rows(bol %>% filter(q < q_em) %>% transmute(q, nom, err = ARRED),
            oi_tot %>% filter(q >= q_em) %>% transmute(q, nom = oi * r, err = n_parc * ARRED * r)) %>% arrange(q)
}
est_base <- encadeia(2020, R_BASE)
# Emendas alternativas: razao media so do ano anterior; e2020_r1618 usa 2016-2018 (sem 2019, ano anomalo)
R_1618 <- mean(sobre$r[sobre$ano %in% 2016:2018])
EMENDAS <- tibble(ano = c(2017, 2018, 2019, 2020)) %>%
  rowwise() %>% mutate(r = sobre_ano$r_media[sobre_ano$ano == ano - 1]) %>% ungroup() %>%
  mutate(nome = paste0("estatais_total_e", ano), razao_de = as.character(ano - 1)) %>%
  bind_rows(tibble(ano = 2020, r = R_1618, nome = "estatais_total_e2020_r1618", razao_de = "2016-2018"))
est_var <- setNames(lapply(seq_len(nrow(EMENDAS)), function(i) encadeia(EMENDAS$ano[i], EMENDAS$r[i])), EMENDAS$nome)
L("Encadeamento baseline: boletim ate 2019T4 e OI x ", fmt(R_BASE, 4), " a partir de 2020T1. Indicadora emenda_sest = 1 a ",
  "partir de 2020T1 (degrau). Sensibilidade: emenda em 2017T1, 2018T1, 2019T1 e 2020T1 com a razao media so do ano anterior, ",
  "e emenda em 2020T1 com a razao media de 2016-2018, sem 2019 (", paste0(EMENDAS$nome, ": ", fmt(EMENDAS$r, 4), collapse = "; "),
  "); indicadoras emenda_sest_AAAA com degrau na data de cada emenda. A variante e2020 usa a razao de 2019, ano em que a razao ",
  "boletim/OI salta (2019T4); por isso a variante e2020_r1618 e a comparacao natural com o baseline.")

# ---------------------------------------------------------------------------
# 5. Ajuste sazonal (X-11) e indices
# ---------------------------------------------------------------------------
# Serie positiva: X-11 multiplicativo (transform.function = "log"), coerente com o uso em log10.
# Serie com zero ou negativo: X-11 aditivo ("none"). transf = "auto" deixa o X-13 escolher (so nas variantes de INF).
SA_INFO <- list()
ULTIMOS_OUT <- character(0)
nomes_out <- function(m) grep("^(AO|LS|TC)", names(coef(m)), value = TRUE)
# reg: outliers fixos (ex.: c("ao2018.3")); com reg, a deteccao automatica fica desligada (outlier = NULL).
# semout = TRUE: sem deteccao e sem outliers fixos.
roda_x11 <- function(x, nome = NULL, transf = NULL, reg = NULL, semout = FALSE) {
  if (is.null(transf)) transf <- if (any(x <= 0)) "none" else "log"
  if (!is.null(reg)) {
    specs <- list(list(regression.variables = reg, outlier = NULL),
                  list(regression.variables = reg, regression.aictest = NULL, outlier = NULL))
    rot <- paste0(c("outliers fixos ", "outliers fixos, sem td/pascoa "), "(", paste(toupper(reg), collapse = " "), "), sem deteccao")
  } else if (semout) {
    specs <- list(list(outlier = NULL), list(regression.aictest = NULL, outlier = NULL))
    rot <- c("sem outliers", "sem outliers e sem td/pascoa")
  } else {
    specs <- list(list(), list(outlier = NULL), list(regression.aictest = NULL, outlier = NULL))
    rot <- c("padrao", "sem outliers", "sem outliers e sem td/pascoa")
  }
  y <- NULL
  k <- 0
  while (is.null(y) && k < length(specs)) {
    k <- k + 1
    y <- tryCatch(do.call(x11_sa, c(list(x, transform.function = transf), specs[[k]])), error = function(e) NULL)
  }
  if (is.null(y)) stop("X-11 falhou em ", nome)
  ULTIMOS_OUT <<- c(ULTIMOS_OUT, paste(nomes_out(attr(y, "seas_model")), collapse = " "))
  if (!is.null(nome)) {
    m <- attr(y, "seas_model")
    u <- function(k) tryCatch(as.character(seasonal::udg(m, k)), error = function(e) NA_character_)
    auto <- if (all(x > 0)) {
      tryCatch(seasonal::transformfunction(attr(x11_sa(x), "seas_model")), error = function(e) NA_character_)
    } else NA_character_
    SA_INFO[[nome]] <<- tibble(
      serie = nome, inicio = format(zoo::as.yearqtr(time(x)[1]), "%YQ%q"), n = length(x),
      transformacao = seasonal::transformfunction(m), transformacao_auto = auto, arima = u("arimamdl"),
      outliers = paste(nomes_out(m), collapse = " "),
      m7 = u("f3.m07"), q_x11 = u("f3.q"), especificacao = rot[k])
  }
  ULTIMO_MOD <<- attr(y, "seas_model")
  as.numeric(y)
}
# Converte "AO2018.3 LS2019.1" em c("ao2018.3", "ls2019.1") para regression.variables
reg_de <- function(s) { v <- strsplit(trimws(s), " +")[[1]]; tolower(v[nzchar(v)]) }

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
  est <- if (span_fim > "2019Q4") est_base else bol %>% transmute(q, nom, err = ARRED)
  list(q = qq,
       fed = fil_tab$nom[match(qq, fil_tab$q)] * f,
       est = est$nom[match(qq, est$q)] * f)
}
variantes <- expand_grid(deflator = c("media_tri", "fim_tri", "anual", "nominal"),
                         ajuste = c("soma", "componentes", "nenhum"),
                         transformacao = c("log", "auto"),
                         span = c("2019Q4", "2025Q4"),
                         imputacao = c("base", "razao", "apendice")) %>%
  filter(!(ajuste == "nenhum" & (span == "2025Q4" | transformacao == "auto"))) %>%
  mutate(transformacao = ifelse(ajuste == "nenhum", "-", transformacao))
res_var <- vector("list", nrow(variantes))
for (i in seq_len(nrow(variantes))) {
  v <- variantes[i, ]
  cp <- componentes_inf(v$deflator, FIL[[v$imputacao]], v$span)
  tsf <- function(x) ts_from_q(x, cp$q)
  ULTIMOS_OUT <- character(0)
  rec <- switch(v$ajuste,
                soma = roda_x11(tsf(cp$fed + cp$est), transf = v$transformacao),
                componentes = roda_x11(tsf(cp$fed), transf = v$transformacao) + roda_x11(tsf(cp$est), transf = v$transformacao),
                nenhum = cp$fed + cp$est)
  res_var[[i]] <- bind_cols(v, metricas(cp$q, rec), outliers = paste(ULTIMOS_OUT, collapse = " ; "))
}
res_var <- bind_rows(res_var) %>%
  mutate(span = paste0("2003T1-", sub("Q", "T", span))) %>%
  arrange(desc(corr_dif), dam_dif)
write_csv_safe(res_var, "results/A3_reconstrucao_INF_variantes.csv")
pega <- function(defl, aj, tr = "log", sp = "2003T1-2019T4", imp = "base") {
  res_var %>% filter(deflator == defl, ajuste == aj, transformacao == tr, span == sp, imputacao == imp)
}
melhor <- res_var[1, ]
# Destaque: nominal, X-11 depois de somar, janela 2003T1-2019T4, imputacao baseline (= inf_diss_nominal_2019).
# A imputacao pelo Apendice A usa o Ipub, a mesma fonte de INF: fica so como conferencia (circular em 2017).
dest_v <- pega("nominal", "soma")
apx_v <- pega("nominal", "soma", imp = "apendice")
base_v <- pega("media_tri", "componentes", sp = "2003T1-2025T4")
soma_v <- pega("media_tri", "soma", sp = "2003T1-2025T4")
nomi_v <- pega("nominal", "soma", sp = "2003T1-2025T4")

# INF da dissertacao contra o X-11 do Ipub nominal do Apendice A (2002T1-2019T4)
ipub_ts <- ts_from_q(read_csv("data/dados_dissertacao_apendiceA.csv", show_col_types = FALSE)$ipub_rs / 1e9, "2002Q1")
ipub_sa <- roda_x11(ipub_ts, transf = "log")
ipub_auto <- seasonal::transformfunction(attr(x11_sa(ipub_ts), "seas_model"))
d_apx <- diff(log10(ipub_sa)); d_inf <- diff(inf_orig$INF)
gap_apx <- log10(ipub_sa) - inf_orig$INF
k03 <- inf_orig$q[-1] >= "2003Q2"

# Outliers cruzados: cada deflator com os outliers da nominal fixos, e a nominal com os da real (IPCA medio)
out_nom <- dest_v$outliers
out_real <- pega("media_tri", "soma")$outliers
cruz <- function(dc, out_str) {
  cp <- componentes_inf(dc, fil_base, "2019Q4")
  y <- x11_sa(ts_from_q(cp$fed + cp$est, cp$q), transform.function = "log", regression.variables = reg_de(out_str), outlier = NULL)
  metricas(cp$q, as.numeric(y))$corr_dif
}
cruzado <- bind_rows(
  tibble(deflator = c("media_tri", "fim_tri", "anual", "nominal"), outliers_fixos = out_nom, origem = "nominal") %>%
    rowwise() %>% mutate(corr_dif = cruz(deflator, outliers_fixos)) %>% ungroup(),
  tibble(deflator = "nominal", outliers_fixos = out_real, origem = "real, IPCA medio") %>%
    rowwise() %>% mutate(corr_dif = cruz(deflator, outliers_fixos)) %>% ungroup())
sem_out <- sapply(c("nominal", "media_tri"), function(dc) {
  cp <- componentes_inf(dc, fil_base, "2019Q4")
  y <- x11_sa(ts_from_q(cp$fed + cp$est, cp$q), transform.function = "log", outlier = NULL)
  metricas(cp$q, as.numeric(y))$corr_dif
})
cz_nom <- cruzado %>% filter(origem == "nominal")
cz_real <- cruzado %>% filter(origem != "nominal")

L("Reconstrucao de INF: federal (filtro, com 2017 imputado) + SEST boletim (Brasil), X-11 (x11_sa: X-13ARIMA-SEATS em modo ",
  "X-11, com regARIMA, outliers e testes de dias uteis e Pascoa automaticos), indice e log10. Comparacao com INF de ",
  "data/original/0224_tri_estmeq.txt em 2003T2-2019T4 (67 diferencas). ", nrow(res_var), " variantes: deflator (IPCA medio do ",
  "trimestre, IPCA do ultimo mes, IPCA medio do ano, nominal), X-11 depois de somar ou antes (em cada componente) ou sem ",
  "ajuste, transformacao do X-11 (log imposto ou escolha automatica do X-13), janela do X-11 (2003T1-2019T4 ou 2003T1-2025T4, ",
  "esta com as estatais encadeadas) e imputacao de 2017 (baseline, razao, Apendice A). Tabela completa em ",
  "results/A3_reconstrucao_INF_variantes.csv.")
L("Resultado principal: o INF da dissertacao e o investimento NOMINAL com ajuste sazonal, nao o real. O que identifica isso e o ",
  "nivel: o desvio padrao da diferenca de nivel contra INF (log10) e ", fmt(dest_v$dp_escala, 4), " na serie nominal e ",
  fmt(pega("media_tri", "soma")$dp_escala, 3), " a ", fmt(pega("anual", "soma")$dp_escala, 3), " nas reais, que se afastam de INF ",
  "com a inflacao acumulada. A correlacao das diferencas quase nao distingue real de nominal: ela depende sobretudo do conjunto de ",
  "outliers que o X-11 detecta em 2017-2019 (ver abaixo). Variante de destaque (nominal, X-11 depois de somar, log, janela ",
  dest_v$span, ", imputacao baseline; e a serie inf_diss_nominal_2019): correlacao das diferencas ", fmt(dest_v$corr_dif, 4),
  "; desvio absoluto medio das diferencas ", fmt(dest_v$dam_dif, 4), " (log10); desvio medio em nivel ",
  fmt(dest_v$desvio_medio_nivel, 4), " (indices base 2003 = 100, log10). Conferencia: com a imputacao de 2017 pelo Apendice A a ",
  "correlacao vai a ", fmt(apx_v$corr_dif, 4), ", mas essa imputacao usa o Ipub, a mesma fonte de INF, e e em parte circular em 2017; ",
  "por isso nao e o numero de destaque. ",
  "Conferencia direta: X-11 multiplicativo do Ipub nominal do Apendice A (2002T1-2019T4; a escolha automatica do X-13 tambem e ",
  ipub_auto, ") contra INF: correlacao das diferencas ", fmt(cor(d_apx, d_inf), 4), " em 2002T2-2019T4 (", fmt(cor(d_apx[k03], d_inf[k03]), 4),
  " em 2003T2-2019T4); desvio padrao da diferenca de nivel em log10 ", fmt(sd(gap_apx), 4), ". Logo INF = log10(X-11 do Ipub nominal) ",
  "mais uma constante de ", fmt(-mean(gap_apx), 3), " em log10 (unidade ou base diferente de R$ bi). Com deflator, a diferenca de nivel contra INF cresce ",
  "com a inflacao acumulada (desvio medio em nivel ", fmt(pega("media_tri", "soma")$desvio_medio_nivel, 3), ", maximo ",
  fmt(pega("media_tri", "soma")$max_nivel, 3), " em log10).")
L("Series entregues para INF (imputacao baseline): inf_diss (real, IPCA medio do trimestre) passa a ser o ajuste INDIRETO, soma dos ",
  "niveis com ajuste de uniao_filtro_diss e estatais_total (cada um com seu X-11 em 2003T1-2025T4), e depois indice e log10. ",
  "Motivo: o X-11 depois de somar muda com o conjunto de outliers detectado na serie real e deixa o agregado com fatores sazonais ",
  "inconsistentes com os componentes, que sao entregues como choques separados. Correlacao das diferencas com INF (2003T2-2019T4): ",
  "inf_diss (indireto) ", fmt(base_v$corr_dif, 4), ", desvio absoluto medio ", fmt(base_v$dam_dif, 4), "; variante inf_diss_x11soma ",
  "(X-11 depois de somar, a definicao anterior) ", fmt(soma_v$corr_dif, 4), ", desvio absoluto medio ", fmt(soma_v$dam_dif, 4),
  ". Nominais, para replicar a dissertacao (X-11 depois de somar, como a dissertacao fez com o Ipub): inf_diss_nominal (janela do ",
  "X-11 2003T1-2025T4) correlacao ", fmt(nomi_v$corr_dif, 4), ", desvio absoluto medio ", fmt(nomi_v$dam_dif, 4), ", desvio medio em nivel ",
  fmt(nomi_v$desvio_medio_nivel, 4), "; inf_diss_nominal_2019 (janela 2003T1-2019T4) correlacao ", fmt(dest_v$corr_dif, 4),
  ". Nominal com ajuste indireto, janela ate 2025: ", fmt(pega("nominal", "componentes", sp = "2003T1-2025T4")$corr_dif, 4), ".")
L("Efeito de cada escolha (demais fixas em: X-11 depois de somar, log, janela 2003T1-2019T4, imputacao baseline):")
L2("deflator: ", paste0(c("media_tri", "fim_tri", "anual", "nominal"), " ",
                        sapply(c("media_tri", "fim_tri", "anual", "nominal"), function(d) fmt(pega(d, "soma")$corr_dif, 4)), collapse = "; "),
   " (correlacao das diferencas); desvio padrao da diferenca de nivel ",
   paste0(c("media_tri", "fim_tri", "anual", "nominal"), " ",
          sapply(c("media_tri", "fim_tri", "anual", "nominal"), function(d) fmt(pega(d, "soma")$dp_escala, 4)), collapse = "; "),
   ". Com a imputacao do Apendice A, o IPCA medio do ano chega a correlacao ", fmt(pega("anual", "soma", imp = "apendice")$corr_dif, 4),
   " (outliers ", pega("anual", "soma", imp = "apendice")$outliers, "), mas o nivel continua afastado (",
   fmt(pega("anual", "soma", imp = "apendice")$dp_escala, 3), ").")
L2("ordem do X-11 (IPCA medio do trimestre): depois de somar ", fmt(pega("media_tri", "soma")$corr_dif, 4), "; em cada componente ",
   fmt(pega("media_tri", "componentes")$corr_dif, 4), "; sem ajuste ", fmt(pega("media_tri", "nenhum", tr = "-")$corr_dif, 4),
   ". Nominal: depois de somar ", fmt(pega("nominal", "soma")$corr_dif, 4), "; em cada componente ", fmt(pega("nominal", "componentes")$corr_dif, 4), ".")
L2("transformacao (IPCA medio do trimestre, depois de somar): log ", fmt(pega("media_tri", "soma")$corr_dif, 4), "; automatica ",
   fmt(pega("media_tri", "soma", tr = "auto")$corr_dif, 4), ". Nominal: log ", fmt(pega("nominal", "soma")$corr_dif, 4),
   "; automatica ", fmt(pega("nominal", "soma", tr = "auto")$corr_dif, 4), ".")
L2("janela do X-11 (nominal, depois de somar): 2003T1-2019T4 ", fmt(pega("nominal", "soma")$corr_dif, 4), "; 2003T1-2025T4 ",
   fmt(nomi_v$corr_dif, 4), ". Real: ", fmt(pega("media_tri", "soma")$corr_dif, 4), " e ", fmt(soma_v$corr_dif, 4),
   " (depois de somar); ", fmt(pega("media_tri", "componentes")$corr_dif, 4), " e ", fmt(base_v$corr_dif, 4),
   " (em cada componente). A janela longa muda os fatores sazonais de 2003-2019.")
L2("imputacao de 2017 (nominal, depois de somar), desvio absoluto medio das diferencas de 2017T1 a 2018T1 contra INF: baseline ",
   fmt(pega("nominal", "soma")$dam_dif_2017, 4), "; razao ", fmt(pega("nominal", "soma", imp = "razao")$dam_dif_2017, 4),
   "; Apendice A ", fmt(pega("nominal", "soma", imp = "apendice")$dam_dif_2017, 4), " (media em 2003T2-2019T4: ",
   fmt(pega("nominal", "soma")$dam_dif, 4), ").")
L2("outliers automaticos do X-11 (depois de somar, janela 2003T1-2019T4): nominal ", out_nom, " (correlacao ",
   fmt(dest_v$corr_dif, 4), "); real ", out_real, " (", fmt(pega("media_tri", "soma")$corr_dif, 4), "). Com os outliers da ",
   "nominal fixos (regression.variables, outlier = NULL): ", paste0(cz_nom$deflator, " ", fmt(cz_nom$corr_dif, 4), collapse = "; "),
   ". Nominal com os outliers da real fixos: ", fmt(cz_real$corr_dif, 4), ". Sem deteccao de outliers: nominal ",
   fmt(sem_out[["nominal"]], 4), "; real ", fmt(sem_out[["media_tri"]], 4), ". A diferenca entre real e nominal na correlacao ",
   "vem do conjunto de outliers, nao da deflacao. O casamento quase exato sugere que a dissertacao usou o X-11 com deteccao ",
   "automatica de outliers na serie nominal.")

# ---------------------------------------------------------------------------
# 7. Series de choque
# ---------------------------------------------------------------------------
serie_dash <- function(funcoes = NULL, grupos) {
  d <- dash %>% filter(grupo %in% grupos, q %in% QS)
  if (!is.null(funcoes)) d <- d %>% filter(funcao %in% funcoes)
  out <- d %>% group_by(q) %>% summarise(nom = sum(nom), err = n() * ARRED, .groups = "drop")
  tibble(q = QS) %>% left_join(out, by = "q") %>% mutate(nom = coalesce(nom, 0), err = coalesce(err, 0))
}
serie_oi <- function(filtro) {
  oi %>% filter({{ filtro }}) %>% group_by(q) %>% summarise(nom = sum(valor_nominal_bi), err = n() * ARRED, .groups = "drop") %>%
    right_join(tibble(q = q_seq("2016Q1", Q_FIM)), by = "q") %>% mutate(nom = coalesce(nom, 0), err = coalesce(err, 0)) %>% arrange(q)
}
soma_series <- function(a, b) inner_join(a, b, by = "q") %>% transmute(q, nom = nom.x + nom.y, err = err.x + err.y)
ECON <- names(FUNCOES_ECONOMICA)
SOC <- names(FUNCOES_SOCIAL)
TRANSF <- 1:2
# S(): definicao de uma serie. oi = TRUE: X-11 com os AO comuns ao total (ver abaixo); comp: ajuste indireto
# (soma dos niveis com ajuste dos componentes); semout: X-11 sem outliers; nominal: sem deflacao.
S <- function(d, def, fonte, nominal = FALSE, oi = FALSE, comp = NULL, semout = FALSE) {
  list(d = d, def = def, fonte = fonte, nominal = nominal, oi = oi, comp = comp, semout = semout)
}
# Filtro da dissertacao: valores em R$ com centavos, sem erro de arredondamento relevante
fq <- function(tab) tab %>% filter(q %in% QS) %>% transmute(q, nom, err = 0)
C_INF <- c("uniao_filtro_diss", "estatais_total")
DEF <- list(
  uniao_econ_dir = S(serie_dash(ECON, 0), "Uniao, funcoes economicas (24, 25, 26), aplicacao direta (grupo 0: modalidades 90 e 91), GND 4, todos os elementos", "dashboard"),
  uniao_econ_dt = S(serie_dash(ECON, c(0, TRANSF)), "Uniao, funcoes economicas, direta + transferencias (grupos 0, 1 e 2: todas as modalidades), GND 4, todos os elementos", "dashboard"),
  uniao_soc_dir = S(serie_dash(SOC, 0), "Uniao, funcoes sociais (08, 10, 12, 15, 16, 17, 27), aplicacao direta (grupo 0), GND 4, todos os elementos", "dashboard"),
  uniao_soc_dt = S(serie_dash(SOC, c(0, TRANSF)), "Uniao, funcoes sociais, direta + transferencias (grupos 0, 1 e 2), GND 4, todos os elementos", "dashboard"),
  uniao_transf_econ = S(serie_dash(ECON, TRANSF), "Uniao, funcoes economicas, transferencias (grupos 1 e 2: todas exceto 90 e 91, com execucao delegada 32 e 42), GND 4", "dashboard"),
  uniao_transf_soc = S(serie_dash(SOC, TRANSF), "Uniao, funcoes sociais, transferencias (grupos 1 e 2), GND 4", "dashboard"),
  uniao_gnd4_dir = S(serie_dash(NULL, 0), "Uniao, todas as funcoes, aplicacao direta (grupo 0), GND 4, todos os elementos", "dashboard"),
  uniao_filtro_diss = S(fq(fil_base), "Uniao, filtro da dissertacao (modalidade 90, 6 elementos); 2017 com total anual exato e perfil trimestral do grupo 0", "federal filtrado + base anual (2017)"),
  estatais_total = S(est_base, "Estatais federais: boletim SEST (Brasil) ate 2019T4; OI x razao media boletim/OI 2016-2019 a partir de 2020T1", "SEST boletim + OI"),
  estatais_petro = S(serie_oi(segmento == SEG_PETRO), "Estatais, segmento Oil, gas & derivatives (OI, sem encadeamento)", "SEST OI", oi = TRUE),
  estatais_sempetro = S(serie_oi(segmento != SEG_PETRO), "Estatais, todos os segmentos exceto Oil, gas & derivatives (OI, sem encadeamento)", "SEST OI", oi = TRUE),
  estatais_econ = S(serie_oi(segmento %in% SEG_ECON), "Estatais, segmentos Electricity, Transport, Port administration e Airport administration (OI, sem encadeamento)", "SEST OI", oi = TRUE),
  estatais_outras = S(serie_oi(segmento %in% SEG_OUTRAS), "Estatais, segmentos Financial, Commerce & services, Industry, Research, development & planning e Food supply (OI, sem encadeamento)", "SEST OI", oi = TRUE),
  estatais_grupopetro = S(serie_oi(grupo_petrobras), "Estatais do grupo Petrobras, todos os segmentos (OI, grupo_petrobras = True, sem encadeamento)", "SEST OI", oi = TRUE),
  estatais_semgrupopetro = S(serie_oi(!grupo_petrobras), "Estatais fora do grupo Petrobras (OI, grupo_petrobras = False, sem encadeamento)", "SEST OI", oi = TRUE),
  inf_diss = S(soma_series(fq(fil_base), est_base), "Agregado da dissertacao, real: ajuste indireto, uniao_filtro_diss com ajuste + estatais_total com ajuste", "composto", comp = C_INF),
  # Variantes de robustez
  uniao_econ_dt_g1 = S(serie_dash(ECON, 0:1), "Como uniao_econ_dt, so grupos 0 e 1 (sem execucao delegada 32 e 42)", "dashboard"),
  uniao_soc_dt_g1 = S(serie_dash(SOC, 0:1), "Como uniao_soc_dt, so grupos 0 e 1", "dashboard"),
  uniao_transf_econ_g1 = S(serie_dash(ECON, 1), "Como uniao_transf_econ, so grupo 1", "dashboard"),
  uniao_transf_soc_g1 = S(serie_dash(SOC, 1), "Como uniao_transf_soc, so grupo 1", "dashboard"),
  uniao_filtro_diss_imprazao = S(fq(fil_raz), "Como uniao_filtro_diss, 2017 pela razao filtro/dashboard do trimestre (media de 2016 e 2018), reescalada ao total anual", "federal filtrado + base anual (2017)"),
  uniao_filtro_diss_impapendice = S(fq(fil_apx), "Como uniao_filtro_diss, 2017 implicito no Apendice A (Ipub x razao interpolada - SEST), reescalado ao total anual", "federal filtrado + base anual + Apendice A"),
  inf_diss_imprazao = S(soma_series(fq(fil_raz), est_base), "Como inf_diss (ajuste indireto), com uniao_filtro_diss_imprazao", "composto", comp = c("uniao_filtro_diss_imprazao", "estatais_total")),
  inf_diss_impapendice = S(soma_series(fq(fil_apx), est_base), "Como inf_diss (ajuste indireto), com uniao_filtro_diss_impapendice", "composto", comp = c("uniao_filtro_diss_impapendice", "estatais_total")),
  inf_diss_x11soma = S(soma_series(fq(fil_base), est_base), "Como inf_diss, mas com X-11 depois de somar (definicao anterior de inf_diss)", "composto"),
  inf_diss_nominal = S(soma_series(fq(fil_base), est_base), "Agregado da dissertacao NOMINAL (sem deflacao), como o INF da dissertacao; X-11 depois de somar, janela 2003T1-2025T4; colunas reais vazias", "composto", nominal = TRUE),
  inf_diss_nominal_2019 = S(soma_series(fq(fil_base), bol %>% transmute(q, nom, err = ARRED)), "Como inf_diss_nominal, com X-11 so em 2003T1-2019T4 (boletim da SEST, sem OI): a variante que reproduz INF; colunas reais vazias", "composto", nominal = TRUE),
  estatais_petro_semout = S(serie_oi(segmento == SEG_PETRO), "Como estatais_petro, X-11 sem outliers (nem detectados nem fixos)", "SEST OI", semout = TRUE),
  estatais_sempetro_semout = S(serie_oi(segmento != SEG_PETRO), "Como estatais_sempetro, X-11 sem outliers (nem detectados nem fixos)", "SEST OI", semout = TRUE)
)
for (i in seq_len(nrow(EMENDAS))) {
  nm <- EMENDAS$nome[i]
  DEF[[nm]] <- S(est_var[[nm]], paste0("Como estatais_total, emenda em ", EMENDAS$ano[i], "T1 com a razao media boletim/OI de ",
                                       EMENDAS$razao_de[i], " (", fmt(EMENDAS$r[i], 4), ")"), "SEST boletim + OI")
}
for (nm in EMENDAS$nome) {
  DEF[[sub("estatais_total", "inf_diss", nm)]] <- S(soma_series(fq(fil_base), est_var[[nm]]),
                                                    paste0("Como inf_diss (ajuste indireto), com ", nm), "composto",
                                                    comp = c("uniao_filtro_diss", nm))
}
# Conjunto base de choques (classificacao do briefing). PRINCIPAIS = as do conjunto base que passam na regra de
# aptidao para as LP (Q do X-11, erro de arredondamento, log10); definido depois do X-11.
SERIES_BASE <- c("uniao_econ_dir", "uniao_econ_dt", "uniao_soc_dir", "uniao_soc_dt", "uniao_transf_econ", "uniao_transf_soc",
                 "uniao_gnd4_dir", "uniao_filtro_diss", "estatais_total", "estatais_petro", "estatais_sempetro",
                 "estatais_econ", "estatais_outras", "estatais_grupopetro", "estatais_semgrupopetro", "inf_diss")
# Pares que a A5 deve estimar juntos (transferencia com grupos 1 e 2 x so grupo 1), pendentes do autor
PAR_G1 <- c(uniao_econ_dt = "uniao_econ_dt_g1", uniao_soc_dt = "uniao_soc_dt_g1",
            uniao_transf_econ = "uniao_transf_econ_g1", uniao_transf_soc = "uniao_transf_soc_g1")
eh_nominal <- function(nm) isTRUE(DEF[[nm]]$nominal)

# Outliers do regARIMA: tabela por serie (nome X-13, tipo, trimestre, coeficiente, z, efeito)
nome_dummy <- function(o) paste0(tolower(substr(o, 1, 2)), substr(o, 3, 6), "T", sub(".*\\.", "", o))
tab_out <- function(m, nm, origem, mult) {
  ct <- coef(summary(m))
  k <- grepl("^(AO|LS|TC)", rownames(ct))
  if (!any(k)) return(NULL)
  o <- rownames(ct)[k]
  tibble(serie = nm, outlier = o, tipo = substr(o, 1, 2),
         trimestre = q_key(as.integer(substr(o, 3, 6)), as.integer(sub(".*\\.", "", o))),
         coef = ct[k, "Estimate"], z = ct[k, "z value"],
         efeito = if (mult) exp(ct[k, "Estimate"]) - 1 else ct[k, "Estimate"],
         unidade_efeito = if (mult) "proporcao (fator - 1)" else "R$ bi (X-11 aditivo)",
         origem = origem, dummy = nome_dummy(o))
}
# Fator de AO do regARIMA (tabela A8.AO): razao no X-11 multiplicativo, nivel no aditivo. Conferido contra os coeficientes.
fator_ao <- function(m, x, mult, tb) {
  neutro <- if (mult) 1 else 0
  a <- tryCatch(suppressMessages(seasonal::series(m, "regression.aoutlier", verbose = FALSE)), error = function(e) NULL)
  ao <- if (is.null(tb)) tibble() else filter(tb, tipo == "AO")
  if (is.null(a) || !length(a)) {
    if (nrow(ao)) stop("Tabela A8.AO ausente com AO no modelo")
    return(rep(neutro, length(x)))
  }
  a <- as.numeric(window(a, start = start(x), end = end(x)))
  stopifnot(length(a) == length(x))
  esp <- rep(neutro, length(x))
  qx <- format(zoo::as.yearqtr(time(x)), "%YQ%q")
  if (nrow(ao)) esp[match(ao$trimestre, qx)] <- if (mult) exp(ao$coef) else ao$coef
  stopifnot(max(abs(a - esp)) < 1e-4)
  a
}

# Regra para zero ou negativo: nao entra em log; X-11 aditivo e so nivel.
MODS <- list()
OUT_TAB <- list()
INFO_LP <- list()
AO_COMUM <- character(0)
processa <- function(nm) {
  e <- DEF[[nm]]
  d <- e$d %>% arrange(q)
  stopifnot(!anyNA(d$nom), !anyNA(d$err), identical(d$q, q_seq(d$q[1], d$q[nrow(d)])))
  nomi <- e$nominal
  d <- d %>% mutate(real = nom * DEFL$media_tri[match(q, DEFL$q)])
  x <- if (nomi) d$nom else d$real
  n_np <- sum(x <= 0)
  if (!is.null(e$comp)) {
    # Ajuste indireto: soma dos niveis com ajuste dos componentes (ja processados)
    cc <- lapply(e$comp, function(k) longo[[k]])
    stopifnot(all(sapply(cc, function(z) identical(z$trimestre, d$q))),
              max(abs(Reduce(`+`, lapply(cc, `[[`, "real_rs_bi_2025")) - d$real)) < 1e-9)
    sa <- Reduce(`+`, lapply(cc, `[[`, "real_sa_rs_bi_2025"))
    semao <- Reduce(`+`, lapply(cc, `[[`, "real_sa_semao_rs_bi_2025"))
    SA_INFO[[nm]] <<- tibble(serie = nm, inicio = d$q[1], n = nrow(d), transformacao = "indireto", transformacao_auto = NA_character_,
                             arima = NA_character_, outliers = NA_character_, m7 = NA_character_, q_x11 = NA_character_,
                             especificacao = paste0("indireto: ", paste(e$comp, collapse = " + "), ", cada um com ajuste"))
    OUT_TAB[[nm]] <<- bind_rows(lapply(e$comp, function(k) {
      t <- OUT_TAB[[k]]
      if (is.null(t)) NULL else mutate(t, serie = nm, origem = paste0("componente ", k, ": ", origem))
    }))
  } else {
    usa_reg <- e$oi && length(AO_COMUM) > 0
    xt <- ts_from_q(x, d$q)
    sa <- roda_x11(xt, nm, reg = if (usa_reg) AO_COMUM else NULL, semout = e$semout || (e$oi && !usa_reg))
    m <- ULTIMO_MOD
    MODS[[nm]] <<- m
    mult <- seasonal::transformfunction(m) == "log"
    tb <- tab_out(m, nm, if (usa_reg) "fixo (AO comum da OI)" else "detectado (X-13 automatico)", mult)
    OUT_TAB[[nm]] <<- tb
    fao <- fator_ao(m, xt, mult, tb)
    semao <- if (mult) sa / fao else sa - fao
  }
  base_ano <- ano_q(d$q[1])
  b <- ano_q(d$q) == base_ano
  idx <- 100 * sa / mean(sa[b])
  idx_semao <- 100 * semao / mean(semao[b])
  ok_log <- n_np == 0 && all(sa > 0)
  ok_log_semao <- n_np == 0 && all(semao > 0)
  if (!ok_log) {
    L("ATENCAO: ", nm, " tem ", n_np, " trimestre(s) com valor <= 0 (", paste(qt(d$q[x <= 0]), collapse = ", "), ") e ",
      sum(sa <= 0), " com ajuste sazonal <= 0; ficou sem log10 (X-11 aditivo, so nivel).")
  }
  # Erro maximo de arredondamento: parcelas com 4 casas somadas no trimestre / valor do trimestre
  rel <- ifelse(d$nom == 0, ifelse(d$err > 0, Inf, 0), d$err / abs(d$nom))
  INFO_LP[[nm]] <<- tibble(serie = nm, erro_arred_max = max(rel), q_erro_max = d$q[which.max(rel)],
                           n_trim_erro_acima = sum(rel > ERRO_MAX),
                           q_erro_acima = paste(qt(d$q[rel > ERRO_MAX]), collapse = " "),
                           ok_log = ok_log, n_sa_np = sum(sa <= 0))
  d %>% transmute(trimestre = q, serie = nm, nominal_rs_bi = nom,
                  nominal_sa_rs_bi = if (nomi) sa else NA_real_,
                  real_rs_bi_2025 = if (nomi) NA_real_ else real,
                  real_sa_rs_bi_2025 = if (nomi) NA_real_ else sa, indice_sa = idx,
                  log10_indice_sa = if (ok_log) log10(idx) else NA_real_,
                  base_indice = paste0("media ", base_ano, " = 100", if (nomi) " (nominal)" else ""),
                  nominal_sa_semao_rs_bi = if (nomi) semao else NA_real_,
                  real_sa_semao_rs_bi_2025 = if (nomi) NA_real_ else semao, indice_sa_semao = idx_semao,
                  log10_indice_sa_semao = if (ok_log_semao) log10(idx_semao) else NA_real_)
}
# Fase 1: series com X-11 proprio (inclui estatais_total); fase 2: series so da OI, com os AO de estatais_total
# datados de 2016 em diante fixos; fase 3: ajuste indireto.
fase <- sapply(DEF, function(e) if (!is.null(e$comp)) 3L else if (e$oi) 2L else 1L)
longo <- list()
for (nm in names(DEF)[fase == 1]) longo[[nm]] <- processa(nm)
out_tot <- reg_de(SA_INFO[["estatais_total"]]$outliers)
AO_COMUM <- out_tot[grepl("^ao", out_tot) & as.integer(substr(out_tot, 3, 6)) >= 2016]
for (nm in names(DEF)[fase == 2]) longo[[nm]] <- processa(nm)
for (nm in names(DEF)[fase == 3]) longo[[nm]] <- processa(nm)
longo <- bind_rows(longo[names(DEF)])
n_np_total <- longo %>% group_by(serie) %>%
  summarise(np = sum(coalesce(real_rs_bi_2025, nominal_rs_bi) <= 0), minimo = min(coalesce(real_rs_bi_2025, nominal_rs_bi)),
            q_np = paste(qt(trimestre[coalesce(real_rs_bi_2025, nominal_rs_bi) <= 0]), collapse = " "), .groups = "drop")
np_af <- n_np_total %>% filter(np > 0)
pos <- n_np_total %>% filter(np == 0)
L("Regra para valores zero ou negativos: serie com algum trimestre <= 0 nao vai para log10; roda X-11 aditivo ",
  "(transform.function = \"none\") e fica so em nivel (real_sa_rs_bi_2025, util para multiplicadores). Nenhum valor e ",
  "substituido, interpolado ou somado a constante. Series afetadas: ",
  if (nrow(np_af)) paste0(np_af$serie, " (", np_af$q_np, ")", collapse = "; ") else "nenhuma", ". ",
  "Menor valor trimestral entre as demais: R$ ", fmt(min(pos$minimo), 4), " bi (", pos$serie[which.min(pos$minimo)], "). ",
  "Componentes da OI com zeros (Transport, 8 trimestres todos zero; Oil fora do grupo Petrobras; Electricity do grupo ",
  "Petrobras) so entram somados em agregados positivos.")

sa_info <- bind_rows(SA_INFO[names(DEF)])
write_csv_safe(sa_info, "results/A3_x11_diagnostico.csv")
auto_none <- sa_info$serie[!is.na(sa_info$transformacao_auto) & sa_info$transformacao_auto == "none"]
n_esp <- sa_info %>% mutate(esp = sub(":.*", "", sub(" \\(.*", "", especificacao))) %>% count(esp)
L("X-11 em cada serie sobre a propria janela (2003T1-2025T4, 2003T1-2019T4 em inf_diss_nominal_2019, ou 2016T1-2025T4 nas ",
  "series so da OI), em R$ de 2025. Decisao: X-11 multiplicativo (transform.function = \"log\") imposto em toda serie positiva, ",
  "porque a serie entra em log10 e o nivel cresce muito no periodo; com a escolha automatica do X-13, ", length(auto_none),
  " series sairiam aditivas (", paste(auto_none, collapse = ", "), "), e o aditivo gerou ajuste sazonal negativo em uniao_econ_dir ",
  "(2003T4) numa rodada de teste. Na reconstrucao de INF, log e automatico foram comparados (acima). Transformacao usada: log em ",
  sum(sa_info$transformacao == "log"), " de ", sum(sa_info$transformacao != "indireto"), " series com X-11 proprio; ",
  sum(sa_info$transformacao == "indireto"), " series com ajuste indireto (inf_diss e variantes). Especificacoes: ",
  paste0(n_esp$esp, " ", n_esp$n, collapse = "; "), ". Modelo, outliers, M7 e Q por serie em results/A3_x11_diagnostico.csv. ",
  "Indices: base media 2003 = 100 (ou media 2016 = 100 nas series da OI), log10 do indice.")
q_ruim <- sa_info %>% filter(!is.na(q_x11), as.numeric(q_x11) > 1)
m7_ruim <- sa_info %>% filter(!is.na(m7), as.numeric(m7) > 1)
L2("Estatistica Q do X-11 acima de 1 (ajuste sazonal de qualidade baixa pelo criterio do X-11): ",
   if (nrow(q_ruim)) paste0(q_ruim$serie, " (", sub("\\.", ",", q_ruim$q_x11), ")", collapse = "; ") else "nenhuma",
   ". M7 acima de 1 (sazonalidade nao identificavel): ", if (nrow(m7_ruim)) paste(m7_ruim$serie, collapse = ", ") else "nenhuma", ".")
for (i in which(sa_info$serie %in% SERIES_BASE)) {
  s <- sa_info[i, ]
  if (s$transformacao == "indireto") {
    L2(s$serie, ": ", s$especificacao, ".")
  } else {
    L2(s$serie, ": ", s$transformacao, ", ARIMA ", s$arima, ", outliers ", ifelse(nzchar(s$outliers), s$outliers, "nenhum"),
       " (", s$especificacao, "), M7 ", sub("\\.", ",", s$m7), ", Q ", sub("\\.", ",", s$q_x11), ".")
  }
}

# Regra de aptidao para as LP
apt <- sa_info %>% transmute(serie, transformacao, q_x11 = suppressWarnings(as.numeric(q_x11))) %>%
  left_join(bind_rows(INFO_LP), by = "serie") %>%
  mutate(q_ok = is.na(q_x11) | q_x11 <= Q_MAX, arred_ok = erro_arred_max <= ERRO_MAX)
comp_ruim <- function(nm) {
  cm <- DEF[[nm]]$comp
  if (is.null(cm)) return(character(0))
  cm[!apt$q_ok[match(cm, apt$serie)]]
}
apt$comp_ruim <- sapply(apt$serie, function(nm) paste(comp_ruim(nm), collapse = " "))
apt <- apt %>%
  mutate(apta_lp = q_ok & arred_ok & ok_log & !nzchar(comp_ruim),
         motivo_fora_lp = pmap_chr(list(q_ok, q_x11, arred_ok, erro_arred_max, q_erro_max, q_erro_acima, ok_log, comp_ruim),
                                   function(qo, qx, ao, em, qm, qa, ol, cr) {
                                     m <- character(0)
                                     if (!qo) m <- c(m, paste0("Q do X-11 ", fmt(qx), " > ", fmt(Q_MAX, 0)))
                                     if (!ao) m <- c(m, paste0("erro de arredondamento de ate ",
                                                               if (is.finite(em)) pct(em) else "100% ou mais (trimestre arredondado a zero)",
                                                               " (", qt(qm), ") > ", pct(ERRO_MAX, 0), "; trimestres acima: ", qa))
                                     if (!ol) m <- c(m, "sem log10 (valor ou ajuste <= 0)")
                                     if (nzchar(cr)) m <- c(m, paste0("componente com Q > ", fmt(Q_MAX, 0), ": ", cr))
                                     paste(m, collapse = "; ")
                                   }))
PRINCIPAIS <- SERIES_BASE[SERIES_BASE %in% apt$serie[apt$apta_lp]]
DESCRITIVAS <- setdiff(SERIES_BASE, PRINCIPAIS)
APTAS <- apt$serie[apt$apta_lp]
fora <- apt %>% filter(!apta_lp)
# uniao_transf_econ so em 2003T1-2014T4: a restricao resolve?
te_d <- DEF[["uniao_transf_econ"]]$d %>% filter(q <= "2014Q4") %>% mutate(real = nom * DEFL$media_tri[match(q, DEFL$q)])
te_m <- attr(x11_sa(ts_from_q(te_d$real, te_d$q), transform.function = "log"), "seas_model")
te_q14 <- as.numeric(seasonal::udg(te_m, "f3.q"))
te_err14 <- max(te_d$err / te_d$nom)
L("Regra de aptidao para as projecoes locais (A5): fica fora das LP, como choque, toda serie com Q do X-11 acima de ",
  fmt(Q_MAX, 0), ", com erro maximo de arredondamento acima de ", pct(ERRO_MAX, 0), " em algum trimestre, ou sem log10. ",
  "Erro de arredondamento: o dashboard trimestral, a OI e o boletim da SEST vem em R$ bi com 4 casas, entao o limite no ",
  "trimestre e (numero de parcelas somadas) x R$ 0,00005 bi / valor do trimestre; o filtro da dissertacao vem em R$ com ",
  "centavos. Nas series de ajuste indireto, vale tambem o Q de cada componente. Series fora das LP (", nrow(fora), " de ",
  nrow(apt), "):")
for (i in seq_len(nrow(fora))) L2(fora$serie[i], ": ", fora$motivo_fora_lp[i], ".")
L2("Do conjunto base saem ", paste(DESCRITIVAS, collapse = " e "), ": continuam em A3_invpub_trimestral.csv, A3_niveis_wide.csv ",
   "e nas participacoes, como series descritivas, mas nao em A3_choques_wide.csv. PRINCIPAIS passa a ter ", length(PRINCIPAIS),
   " series. Colunas apta_lp, motivo_fora_lp, q_x11 e erro_arred_max_pct em data/processed/A3_metadados_series.csv.")
L2("uniao_transf_econ restrita a 2003T1-2014T4 tambem nao passa: o X-11 so nessa janela tem Q de ", fmt(te_q14),
   " (erro maximo de arredondamento ", pct(te_err14), "). Sem choque de transferencia na infraestrutura economica, a ",
   "comparacao aplicacao direta x transferencia da A5 fica so na social (uniao_soc_dir x uniao_transf_soc). Na economica, ",
   "uniao_econ_dt e uniao_econ_dir quase coincidem depois de 2014 (ver Pontos de atencao).")

# Outliers mantidos na serie ajustada: tabela por serie, dummies e variante sem AO
out_all <- bind_rows(OUT_TAB[names(DEF)]) %>% arrange(match(serie, names(DEF)), trimestre, tipo)
write_csv_safe(out_all %>% mutate(apta_lp = serie %in% APTAS), "data/processed/A3_outliers_series.csv")
TC_RATE <- 0.7^(12 / 4)  # taxa padrao do TC no X-13 para serie trimestral
dum_def <- out_all %>% distinct(dummy, tipo, trimestre) %>% arrange(trimestre, tipo)
dummies <- tibble(trimestre = QS)
for (i in seq_len(nrow(dum_def))) {
  t0 <- match(dum_def$trimestre[i], QS); k <- seq_along(QS) - t0
  dummies[[dum_def$dummy[i]]] <- switch(dum_def$tipo[i], AO = as.numeric(k == 0), LS = as.numeric(k >= 0),
                                        TC = ifelse(k >= 0, TC_RATE^pmax(k, 0), 0))
}
write_csv_safe(dummies, "data/processed/A3_dummies_outliers.csv")
ao_princ <- out_all %>% filter(serie %in% PRINCIPAIS, tipo == "AO", !grepl("^componente", origem))
ao_txt <- ao_princ %>% group_by(serie) %>%
  summarise(t = paste0(outlier, " ", ifelse(efeito > 0, "+", ""), pct(efeito, 1), collapse = ", "), .groups = "drop") %>%
  arrange(match(serie, PRINCIPAIS))
L("Outliers na serie ajustada: x11_sa devolve seasonal::final, a tabela D11 do X-11. Ela tira o fator sazonal, mas mantem os ",
  "efeitos de AO (no irregular) e de LS (na tendencia) estimados no regARIMA. Os AO protegem o fator sazonal dos picos; os ",
  "picos continuam na serie ajustada e nos choques em log10, e podem dominar as projecoes locais. Efeito dos AO sobre o nivel ",
  "nas series principais (fator do regARIMA - 1): ", paste0(ao_txt$serie, " (", ao_txt$t, ")", collapse = "; "), ". ",
  "LS nas principais: ", paste0(unique(out_all$serie[out_all$serie %in% PRINCIPAIS & out_all$tipo == "LS" & !grepl("^componente", out_all$origem)]),
                                collapse = ", "), " (ver tabela).")
L2("Para a A4 e a A5: (1) data/processed/A3_outliers_series.csv lista, por serie, cada outlier (nome no X-13, tipo, trimestre, ",
   "coeficiente, z, efeito, origem, nome da dummy); nas series de ajuste indireto entram os outliers dos componentes; ",
   "(2) data/processed/A3_dummies_outliers.csv tem uma coluna por outlier (", nrow(dum_def), " no total): AO = impulso (1 no ",
   "trimestre), LS = degrau (0 antes e 1 do trimestre em diante; o regressor LS do X-13 vale -1 antes e 0 depois, a diferenca e ",
   "uma constante), TC = decaimento ", fmt(TC_RATE, 3), " por trimestre (nenhum TC detectado nesta rodada); a coluna ",
   "dummies_outliers dos metadados diz quais valem para cada serie; (3) variante sem o efeito dos AO: nivel com ajuste dividido ",
   "pelo fator de AO do regARIMA (tabela A8.AO do X-13, conferida contra exp(coeficiente); no X-11 aditivo, subtraido), ",
   "colunas *_semao em A3_invpub_trimestral.csv e log10 do indice em data/processed/A3_choques_semao_wide.csv. Os LS ficam na ",
   "variante sem AO. Nas series de ajuste indireto, a variante sem AO e a soma dos componentes sem AO.")

# Pares da definicao de transferencia (grupos 1 e 2 x so grupo 1)
par_cmp <- bind_rows(lapply(names(PAR_G1), function(a) {
  b <- PAR_G1[[a]]
  za <- longo %>% filter(serie == a) %>% arrange(trimestre)
  zb <- longo %>% filter(serie == b) %>% arrange(trimestre)
  k12 <- ano_q(za$trimestre) >= 2012
  tibble(serie = a, par = b,
         corr = if (all(!is.na(zb$log10_indice_sa))) cor(diff(za$log10_indice_sa), diff(zb$log10_indice_sa)) else NA_real_,
         corr12 = if (all(!is.na(zb$log10_indice_sa))) cor(diff(za$log10_indice_sa[k12]), diff(zb$log10_indice_sa[k12])) else NA_real_,
         razao12 = sum(za$real_rs_bi_2025[k12]) / sum(zb$real_rs_bi_2025[k12]))
}))
L("Para o LOG consolidado: a A3 alterou a definicao de transferencia do briefing. O briefing le o grupo 2 do dashboard como ",
  "'outra'; os dados mostram que, em 2003-2025, o grupo 2 e a execucao delegada a estados e municipios (modalidades 32 e 42, ",
  "de 2012 em diante). As series de transferencia e de direta + transferencia usam os grupos 1 e 2; as variantes _g1 seguem ",
  "a leitura literal. A escolha esta pendente de confirmacao do autor e decide qual serie a A5 usa. Ate la, a A5 deve estimar ",
  "obrigatoriamente os dois membros de cada par (coluna par_a5 dos metadados) e reportar a diferenca. Diferenca entre os ",
  "pares (correlacao das diferencas do log10 do indice com ajuste em 2003T2-2025T4 e em 2012T1-2025T4; razao dos niveis ",
  "reais somados em 2012-2025):")
for (i in seq_len(nrow(par_cmp))) {
  r <- par_cmp[i, ]
  L2(r$serie, " x ", r$par, ": ", if (is.na(r$corr)) paste0("sem log10 em ", r$par) else
    paste0("correlacao ", fmt(r$corr, 4), " e ", fmt(r$corr12, 4)), "; razao dos niveis ", fmt(r$razao12, 3),
    if (!all(c(r$serie, r$par) %in% APTAS)) " (fora das LP pela regra de aptidao)" else "", ".")
}

# Conferencia: inf_diss entregue (indireto) contra INF e contra a tabela de variantes
serie_l <- function(nm) longo %>% filter(serie == nm) %>% arrange(trimestre)
inf_ent <- serie_l("inf_diss")
m_ent <- metricas(inf_ent$trimestre, inf_ent$real_sa_rs_bi_2025)
stopifnot(abs(m_ent$corr_dif - base_v$corr_dif) < 1e-8)
ad <- max(abs(inf_ent$real_sa_rs_bi_2025 - serie_l("uniao_filtro_diss")$real_sa_rs_bi_2025 - serie_l("estatais_total")$real_sa_rs_bi_2025))
m_n19 <- with(serie_l("inf_diss_nominal_2019"), metricas(trimestre, nominal_sa_rs_bi))
stopifnot(abs(m_n19$corr_dif - dest_v$corr_dif) < 1e-8)
L("Conferencia das series entregues contra INF (2003T2-2019T4): inf_diss correlacao das diferencas ", fmt(m_ent$corr_dif, 4),
  " (igual a variante real, X-11 em cada componente, janela ate 2025); inf_diss_nominal_2019 ", fmt(m_n19$corr_dif, 4),
  ". Aditividade: inf_diss com ajuste menos (uniao_filtro_diss com ajuste + estatais_total com ajuste), diferenca maxima em ",
  "modulo R$ ", format(ad, digits = 2, decimal.mark = ","), " bi.")

# Series so da OI: especificacao de outliers comum, sensibilidade e fatores sazonais de T3
OI_SER <- names(DEF)[fase == 2]
AO_2 <- intersect(AO_COMUM, c("ao2018.3", "ao2020.3"))
fator <- function(nm) { z <- serie_l(nm); setNames(z$real_rs_bi_2025 / z$real_sa_rs_bi_2025, z$trimestre) }
f_tot <- fator("estatais_total")
T3_1621 <- paste0(2016:2021, "Q3")
faixa <- function(r, k) paste0(fmt(r[[paste0(k, "_min")]], 3), " a ", fmt(r[[paste0(k, "_max")]], 3))
mm <- function(k, v) setNames(list(min(v), max(v)), paste0(k, c("_min", "_max")))
dlog <- function(v) diff(log10(v))
LS_TOT16 <- out_tot[grepl("^ls", out_tot) & as.integer(substr(out_tot, 3, 6)) >= 2016]
# X-11 com fallback sem teste de dias uteis e Pascoa (como em roda_x11)
x11_try <- function(xt, ...) {
  y <- tryCatch(x11_sa(xt, transform.function = "log", ...), error = function(e) NULL)
  if (is.null(y)) y <- x11_sa(xt, transform.function = "log", regression.aictest = NULL, ...)
  y
}
z_de <- function(y, nomes) {
  ct <- coef(summary(attr(y, "seas_model")))
  setNames(ct[match(toupper(nomes), rownames(ct)), "z value"], toupper(nomes))
}
# Conferencia na propria OI: total da OI (sem encadeamento), R$ de 2025, com os AO comuns e com AO + LS do total
oi_real <- oi_tot %>% mutate(real = oi * DEFL$media_tri[match(q, DEFL$q)])
oi_ts <- ts_from_q(oi_real$real, oi_real$q)
oi_y_ao <- x11_try(oi_ts, regression.variables = AO_COMUM, outlier = NULL)
oi_y_aols <- x11_try(oi_ts, regression.variables = c(AO_COMUM, LS_TOT16), outlier = NULL)
oi_y_auto <- x11_try(oi_ts)
z_oi_ao <- z_de(oi_y_ao, AO_COMUM)
z_oi_aols <- z_de(oi_y_aols, c(AO_COMUM, LS_TOT16))
fmt_z <- function(z) paste0(names(z), " ", fmt(z, 2), collapse = ", ")
sens_oi <- bind_rows(lapply(OI_SER, function(nm) {
  z <- serie_l(nm)
  xt <- ts_from_q(z$real_rs_bi_2025, z$trimestre)
  m_auto <- x11_sa(xt, transform.function = "log")
  sa_auto <- as.numeric(m_auto)
  sa_ind <- z$real_rs_bi_2025 / f_tot[z$trimestre]
  f_base <- setNames(z$real_rs_bi_2025 / z$real_sa_rs_bi_2025, z$trimestre)
  f_auto <- setNames(z$real_rs_bi_2025 / sa_auto, z$trimestre)
  # Variante com so os AO dos picos da Petrobras apontados na revisao (2018T3 e 2020T3)
  m_2ao <- x11_sa(xt, transform.function = "log", regression.variables = AO_2, outlier = NULL)
  f_2ao <- setNames(z$real_rs_bi_2025 / as.numeric(m_2ao), z$trimestre)
  # Variante: so os AO comuns com |z| > 2 na propria serie (repete ate estabilizar)
  sel <- AO_COMUM
  for (it in 1:5) {
    m_z2 <- if (length(sel)) x11_try(xt, regression.variables = sel, outlier = NULL) else x11_try(xt, outlier = NULL)
    keep <- if (length(sel)) sel[abs(z_de(m_z2, sel)) > 2] else character(0)
    if (identical(keep, sel)) break
    sel <- keep
  }
  f_z2 <- setNames(z$real_rs_bi_2025 / as.numeric(m_z2), z$trimestre)
  # Variante: AO e LS do total de 2016 em diante
  m_aols <- x11_try(xt, regression.variables = c(AO_COMUM, LS_TOT16), outlier = NULL)
  f_aols <- setNames(z$real_rs_bi_2025 / as.numeric(m_aols), z$trimestre)
  z_ls <- z_de(m_aols, LS_TOT16)
  ct <- tryCatch(coef(summary(MODS[[nm]])), error = function(e) NULL)
  zv <- if (!is.null(ct)) ct[grepl("^AO", rownames(ct)), "z value"] else numeric(0)
  tibble(serie = nm, outliers_auto = paste(nomes_out(attr(m_auto, "seas_model")), collapse = " "),
         ao_fixos = paste(toupper(AO_COMUM), collapse = " "),
         z_ao = paste0(names(zv), " ", sprintf("%.2f", zv), collapse = "; "),
         !!!mm("t3_1621_auto", f_auto[T3_1621]), !!!mm("t3_1621_base", f_base[T3_1621]),
         !!!mm("t3_1621_2ao", f_2ao[T3_1621]), !!!mm("t3_1621_total", f_tot[T3_1621]),
         q_auto = seasonal::udg(attr(m_auto, "seas_model"), "f3.q"), q_base = SA_INFO[[nm]]$q_x11,
         corr_base_auto = cor(dlog(z$real_sa_rs_bi_2025), dlog(sa_auto)),
         corr_base_indireto = cor(dlog(z$real_sa_rs_bi_2025), dlog(sa_ind)),
         corr_base_2ao = cor(dlog(z$real_sa_rs_bi_2025), dlog(as.numeric(m_2ao))),
         ao_z2 = paste(toupper(sel), collapse = " "), !!!mm("t3_1621_z2", f_z2[T3_1621]),
         q_z2 = seasonal::udg(attr(m_z2, "seas_model"), "f3.q"),
         corr_base_z2 = cor(dlog(z$real_sa_rs_bi_2025), dlog(as.numeric(m_z2))),
         z_ls_aols = paste0(names(z_ls), " ", sprintf("%.2f", z_ls), collapse = "; "), !!!mm("t3_1621_aols", f_aols[T3_1621]),
         q_aols = seasonal::udg(attr(m_aols, "seas_model"), "f3.q"),
         corr_base_aols = cor(dlog(z$real_sa_rs_bi_2025), dlog(as.numeric(m_aols))))
}))
write_csv_safe(sens_oi, "results/A3_sensibilidade_outliers_oi.csv")
c_semout <- sapply(c("estatais_petro", "estatais_sempetro"), function(nm)
  cor(dlog(serie_l(nm)$real_sa_rs_bi_2025), dlog(serie_l(paste0(nm, "_semout"))$real_sa_rs_bi_2025)))
zc <- function(s) gsub(" (-?[0-9]+)\\.([0-9]+)", " \\1,\\2", s)
L("Series so da OI (40 trimestres): a deteccao automatica de outliers nao marca os picos de 2018T3 e 2020T3 da Petrobras, e eles ",
  "viravam sazonalidade de T3. Decisao: especificacao de outliers comum ao total e as subseries, com outlier = NULL (sem ",
  "deteccao automatica). Regra: entram os AO de estatais_total datados de 2016 em diante (", paste(toupper(AO_COMUM), collapse = ", "),
  "), conferidos na propria OI: impostos no total da OI (2016T1-2025T4, sem encadeamento, R$ de 2025), tem z de ",
  zc(fmt_z(z_oi_ao)), " (a deteccao automatica no total da OI marca ", ifelse(nzchar(paste(nomes_out(attr(oi_y_auto, "seas_model")), collapse = " ")),
  paste(nomes_out(attr(oi_y_auto, "seas_model")), collapse = " "), "nenhum"), "). O AO2018.3 foi detectado no trecho do boletim de ",
  "estatais_total, mas o mesmo pico esta na OI, e por isso entra. Os LS do total de 2016 em diante (",
  paste(toupper(LS_TOT16), collapse = ", "), ") ficam de fora por escolha, nao por falta de significancia: impostos junto com os AO ",
  "no total da OI, tem z de ", zc(fmt_z(z_oi_aols[toupper(LS_TOT16)])), ". A especificacao existe para impedir que picos isolados ",
  "virem fator sazonal de T3; um deslocamento de nivel vai para a tendencia do X-11. A versao anterior deste log dizia que os LS ",
  "descreviam so o nivel do boletim; isso nao se confirma na OI. Nas subseries, os AO comuns nem sempre sao significativos ",
  "(z por serie abaixo; em estatais_econ nenhum passa de 2 em modulo). Variantes de sensibilidade, na tabela ",
  "results/A3_sensibilidade_outliers_oi.csv: (a) so os AO comuns com |z| > 2 na propria serie, reestimando ate estabilizar; ",
  "(b) AO e LS do total de 2016 em diante; (c) so ", paste(toupper(AO_2), collapse = " e "), "; (d) sem outliers (series _semout). ",
  "Fatores sazonais de T3 (serie / serie com ajuste), 2016-2021, estatais_total ", faixa(sens_oi[1, ], "t3_1621_total"), ".")
for (i in seq_len(nrow(sens_oi))) {
  r <- sens_oi[i, ]
  L2(r$serie, ": automatica marcou ", ifelse(nzchar(r$outliers_auto), r$outliers_auto, "nenhum"), "; T3 antes ", faixa(r, "t3_1621_auto"),
     ", baseline ", faixa(r, "t3_1621_base"), "; z ", zc(r$z_ao), "; Q ", sub("\\.", ",", r$q_auto), " antes e ", sub("\\.", ",", r$q_base),
     " no baseline; correlacao das diferencas do log10 com o baseline: deteccao automatica ", fmt(r$corr_base_auto, 4),
     ", ajuste indireto ", fmt(r$corr_base_indireto, 4), "; (a) AO com |z| > 2 (", ifelse(nzchar(r$ao_z2), r$ao_z2, "nenhum"),
     "): T3 ", faixa(r, "t3_1621_z2"), ", Q ", sub("\\.", ",", r$q_z2), ", correlacao ", fmt(r$corr_base_z2, 4),
     "; (b) AO e LS (z dos LS ", zc(r$z_ls_aols), "): T3 ", faixa(r, "t3_1621_aols"), ", Q ", sub("\\.", ",", r$q_aols),
     ", correlacao ", fmt(r$corr_base_aols, 4), "; (c) so ", paste(toupper(AO_2), collapse = " e "), ": T3 ", faixa(r, "t3_1621_2ao"),
     ", correlacao ", fmt(r$corr_base_2ao, 4), ".")
}
semout_ok <- apt$apta_lp[match(c("estatais_petro_semout", "estatais_sempetro_semout"), apt$serie)]
L2("Robustez entregue: estatais_petro_semout e estatais_sempetro_semout (X-11 sem outliers). Correlacao das diferencas do log10 ",
   "contra o baseline: petro ", fmt(c_semout[["estatais_petro"]], 4), "; sem petro ", fmt(c_semout[["estatais_sempetro"]], 4),
   ". Pela regra de aptidao, estatais_petro_semout ", ifelse(semout_ok[1], "pode", "nao pode"), " entrar nas LP e ",
   "estatais_sempetro_semout ", ifelse(semout_ok[2], "pode", paste0("nao pode (Q ", fmt(apt$q_x11[apt$serie == "estatais_sempetro_semout"]), ")")),
   ". Na A5, a comparacao petroleo x sem petroleo deve ser refeita com a variante sem o efeito dos AO (colunas _semao) e, para ",
   "petroleo, tambem com a variante _semout; a sensibilidade da sem petro ao conjunto de outliers fica documentada nas ",
   "correlacoes acima. O ajuste indireto pelo fator de estatais_total nao serve para as series sem petroleo: o padrao sazonal ",
   "delas difere do total, dominado pela Petrobras (correlacao com o ajuste indireto de ",
   fmt(sens_oi$corr_base_indireto[sens_oi$serie == "estatais_sempetro"], 2), " na sem petro).")

# Sensibilidade das variantes contra a serie baseline
compara <- function(base, var, janela = QS) {
  a <- longo %>% filter(serie == base, trimestre %in% janela) %>% arrange(trimestre)
  b <- longo %>% filter(serie == var, trimestre %in% janela) %>% arrange(trimestre)
  r25 <- sum(b$real_rs_bi_2025[ano_q(b$trimestre) == 2025]) / sum(a$real_rs_bi_2025[ano_q(a$trimestre) == 2025])
  tibble(var = var, corr = cor(diff(a$log10_indice_sa), diff(b$log10_indice_sa)),
         dam = mean(abs(diff(a$log10_indice_sa) - diff(b$log10_indice_sa))), r2025 = r25)
}
sens_est <- bind_rows(lapply(names(est_var), function(v) compara("estatais_total", v)))
sens_inf <- bind_rows(lapply(sub("estatais_total", "inf_diss", names(est_var)), function(v) compara("inf_diss", v)))
sens_x11 <- compara("inf_diss", "inf_diss_x11soma")
L("Sensibilidade a emenda boletim/OI (contra o baseline, 2003T2-2025T4; correlacao das diferencas do log10 do indice com ajuste; ",
  "razao do nivel real de 2025):")
L2("estatais_total: ", paste0(sub("estatais_total_", "", sens_est$var), " correlacao ", fmt(sens_est$corr, 4), ", nivel 2025 ",
                              fmt(sens_est$r2025, 3), collapse = "; "), ".")
L2("inf_diss: ", paste0(sub("inf_diss_", "", sens_inf$var), " correlacao ", fmt(sens_inf$corr, 4), ", nivel 2025 ",
                        fmt(sens_inf$r2025, 3), collapse = "; "), ".")
L2("inf_diss contra inf_diss_x11soma (X-11 depois de somar): correlacao ", fmt(sens_x11$corr, 4), ", desvio absoluto medio ",
   fmt(sens_x11$dam, 4), " (log10).")
j17 <- q_seq("2016Q4", "2018Q1")
sens_imp <- bind_rows(lapply(c("uniao_filtro_diss_imprazao", "uniao_filtro_diss_impapendice"), function(v) compara("uniao_filtro_diss", v, j17)))
L2("imputacao de 2017, uniao_filtro_diss, diferencas de 2017T1 a 2018T1: desvio absoluto medio contra o baseline ",
   paste0(sub("uniao_filtro_diss_", "", sens_imp$var), " ", fmt(sens_imp$dam, 4), collapse = "; "), " (log10).")

# Comparacao do real com o valor em R$ de 2025 do dashboard (fator anual): so conferencia
cmp_dash <- dash %>% filter(q %in% QS) %>% group_by(ano) %>%
  summarise(nom = sum(nom), real_dash = sum(real_dash), .groups = "drop") %>%
  left_join(dash %>% filter(q %in% QS) %>% group_by(ano, q) %>% summarise(nom = sum(nom), .groups = "drop") %>%
              mutate(real = nom * DEFL$media_tri[match(q, DEFL$q)]) %>% group_by(ano) %>%
              summarise(real = sum(real), .groups = "drop"), by = "ano")
L("Conferencia do deflator com o dashboard (coluna R$ bi de 2025, fator anual): soma anual do federal GND 4 deflacionado ",
  "por trimestre / valor do dashboard entre ", fmt(min(cmp_dash$real / cmp_dash$real_dash), 4), " e ",
  fmt(max(cmp_dash$real / cmp_dash$real_dash), 4), " (2003-2025). A diferenca vem da distribuicao do gasto dentro do ano ",
  "(concentrado no 4o trimestre, cujo fator e menor que o fator anual).")

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
L("Destino das transferencias da base anual (todas as modalidades exceto 90, 91, 67 e 99; equivale aos grupos 1 e 2 do dashboard), ",
  "somas nominais 2003-2025. Estados e municipios = modalidades ",
  paste(MOD_ESTMUN, collapse = ", "), "; entidades privadas = 50 e 60; exterior = 80; outras = ",
  if (length(mods_outras)) paste(sort(mods_outras), collapse = ", ") else "nenhuma",
  if (identical(sort(mods_outras), "70")) " (instituicoes multigovernamentais)" else "", ".")
for (tp in c("economica", "social")) {
  x <- dest_tot %>% filter(tipo == tp)
  L2(tp, ": ", paste0(x$destino, " ", pct(x$participacao), " (R$ ", fmt(x$nominal_rs_bi, 1), " bi)", collapse = "; "), ".")
}
x_ano <- dest %>% filter(destino == "estados e municipios")
L2("Parcela de estados e municipios por ano: economica entre ", pct(min(x_ano$participacao[x_ano$tipo == "economica"])), " e ",
   pct(max(x_ano$participacao[x_ano$tipo == "economica"])), "; social entre ", pct(min(x_ano$participacao[x_ano$tipo == "social"])),
   " e ", pct(max(x_ano$participacao[x_ano$tipo == "social"])), ". Tabela por ano em results/A3_transferencias_destino.csv.")

parc <- function(dd) {
  dd %>% filter(tipo != "outras") %>% group_by(tipo) %>%
    summarise(dir9091 = sum(v[modalidade %in% MOD_DIRETA]), dir90 = sum(v[modalidade == "90"]),
              transf = sum(v[grupo_mod == "transferencia"]), estmun = sum(v[modalidade %in% MOD_ESTMUN]), .groups = "drop")
}
p_all <- parc(pan_j); p_s17 <- parc(pan_j %>% filter(ano != 2017)); p_a24 <- parc(pan_j %>% filter(ano <= 2024))
parc_dash <- dash %>% filter(ano >= 2003, ano <= 2025, tipo != "outras") %>%
  group_by(tipo) %>% summarise(g0 = sum(nom[grupo == 0]), g1 = sum(nom[grupo == 1]), g2 = sum(nom[grupo == 2]), .groups = "drop")
L("Conferencia das parcelas do LOG (social 70% via transferencias, R$ 192 bi x R$ 82 bi diretos; economica 92% direta, ",
  "R$ 182 bi x R$ 16 bi), somas nominais 2003-2025 da base anual, direta = 90 e 91, transferencia = demais exceto 67 e 99:")
for (tp in c("economica", "social")) {
  p <- p_all %>% filter(tipo == tp); dd <- parc_dash %>% filter(tipo == tp)
  L2(tp, ": direta R$ ", fmt(p$dir9091, 1), " bi, transferencias R$ ", fmt(p$transf, 1), " bi (estados e municipios R$ ",
     fmt(p$estmun, 1), " bi); direta ", pct(p$dir9091 / (p$dir9091 + p$transf)), ", transferencias ",
     pct(p$transf / (p$dir9091 + p$transf)), ". Dashboard trimestral: grupo 0 R$ ", fmt(dd$g0, 1), " bi, grupo 1 R$ ",
     fmt(dd$g1, 1), " bi, grupo 2 R$ ", fmt(dd$g2, 1), " bi.")
}
L2("As parcelas do LOG (70% e 92%) se confirmam. Os valores de transferencia do LOG (192 e 16) batem com a base anual ",
   "(estados e municipios: ", fmt(p_all$estmun[p_all$tipo == "social"], 1), " e ", fmt(p_all$estmun[p_all$tipo == "economica"], 1),
   "). Os valores diretos do LOG (82 e 182) ficam abaixo dos da base anual (", fmt(p_all$dir9091[p_all$tipo == "social"], 1), " e ",
   fmt(p_all$dir9091[p_all$tipo == "economica"], 1), "); sem 2017 seriam ", fmt(p_s17$dir9091[p_s17$tipo == "social"], 1), " e ",
   fmt(p_s17$dir9091[p_s17$tipo == "economica"], 1), "; ate 2024, ", fmt(p_a24$dir9091[p_a24$tipo == "social"], 1), " e ",
   fmt(p_a24$dir9091[p_a24$tipo == "economica"], 1), "; so com a modalidade 90, ", fmt(p_all$dir90[p_all$tipo == "social"], 1), " e ",
   fmt(p_all$dir90[p_all$tipo == "economica"], 1), ". A diferenca nos diretos nao altera as parcelas.")

# Composicao por elemento da aplicacao direta (base anual): as series por funcao do dashboard sao GND 4 com todos
# os elementos, nao o filtro da dissertacao.
EL39 <- grep("^OUTROS SERVI.OS DE TERCEIROS - PESSOA JUR", unique(pan$elemento), value = TRUE)
stopifnot(length(EL39) == 1)
comp_el <- pan_j %>% filter(grupo_mod == "direta") %>%
  bind_rows(mutate(., tipo = "total")) %>%
  group_by(ano, tipo) %>%
  summarise(direta_nominal_rs_bi = sum(v),
            parc_filtro_diss = sum(v[modalidade == "90" & elemento %in% ELEMENTOS_DISSERTACAO]) / direta_nominal_rs_bi,
            parc_elemento_39 = sum(v[elemento == EL39]) / direta_nominal_rs_bi, .groups = "drop")
comp_tot <- pan_j %>% filter(grupo_mod == "direta") %>% bind_rows(mutate(., tipo = "total")) %>% group_by(tipo) %>%
  summarise(parc_filtro_diss = sum(v[modalidade == "90" & elemento %in% ELEMENTOS_DISSERTACAO]) / sum(v),
            parc_elemento_39 = sum(v[elemento == EL39]) / sum(v), .groups = "drop")
write_csv_safe(bind_rows(comp_el %>% mutate(ano = as.character(ano)), comp_tot %>% mutate(ano = "2003-2025")) %>%
                 select(ano, tipo, direta_nominal_rs_bi, parc_filtro_diss, parc_elemento_39),
               "results/A3_composicao_elementos_direta.csv")
ce <- function(tp, a, col = "parc_filtro_diss") comp_el[[col]][comp_el$tipo == tp & comp_el$ano == a]
ANOS_CE <- c(2003, 2010, 2011, 2013, 2016, 2019, 2025)
el39_26 <- function(a) sum(pan_j$v[pan_j$ano == a & pan_j$grupo_mod == "direta" & pan_j$funcao_cod == "26" & pan_j$elemento == EL39])
L("Composicao por elemento da aplicacao direta (modalidades 90 e 91), base anual do painel fed_B, nominal. As series por funcao ",
  "(uniao_econ_*, uniao_soc_*, uniao_transf_*, uniao_gnd4_dir) vem do dashboard trimestral, que nao tem elemento: sao GND 4 com ",
  "todos os elementos, nao o filtro da dissertacao (modalidade 90 e os 6 elementos). Parcela do filtro da dissertacao e do ",
  "elemento 39 (", EL39, ") na direta, por tipo (tabela anual em results/A3_composicao_elementos_direta.csv e em ",
  "results/A3_classificacao.md):")
for (tp in c("economica", "social", "outras", "total")) {
  L2(tp, ": filtro da dissertacao ", paste0(ANOS_CE, " ", pct(sapply(ANOS_CE, function(a) ce(tp, a))), collapse = "; "),
     "; elemento 39 ", paste0(ANOS_CE, " ", pct(sapply(ANOS_CE, function(a) ce(tp, a, "parc_elemento_39"))), collapse = "; "),
     "; em 2003-2025, filtro ", pct(comp_tot$parc_filtro_diss[comp_tot$tipo == tp]), " e elemento 39 ",
     pct(comp_tot$parc_elemento_39[comp_tot$tipo == tp]), ".")
}
L2("Leitura: na economica a parcela do filtro cai de ", pct(ce("economica", 2010)), " em 2010 para ", pct(ce("economica", 2011)),
   " em 2011 e ", pct(ce("economica", 2016)), " em 2016, com a entrada do elemento 39 no transporte (elemento 39 da funcao 26: R$ ",
   fmt(el39_26(2010), 2), " bi em 2010, ", fmt(el39_26(2011), 2), " bi em 2011, ", fmt(el39_26(2016), 2), " bi em 2016, nominais). ",
   "Depois fica entre ", pct(min(sapply(2017:2022, function(a) ce("economica", a)))), " e ",
   pct(max(sapply(2017:2022, function(a) ce("economica", a)))), " em 2017-2022 e volta a cair em 2023-2025 (",
   pct(ce("economica", 2024)), " em 2024). Candidata a quebra de composicao para a A4: 2011-2016 em uniao_econ_dir, ",
   "uniao_econ_dt e uniao_gnd4_dir (e, com menor peso, uniao_soc_dir). A versao so direta por funcao nao e comparavel a ",
   "dissertacao em composicao; o que e comparavel e uniao_filtro_diss, que nao tem abertura por funcao no trimestre.")

# ---------------------------------------------------------------------------
# 9. Participacoes anuais (R$ de 2025, sem ajuste sazonal)
# ---------------------------------------------------------------------------
defq <- DEFL %>% select(q, f = media_tri)
uni_ano <- dash %>% filter(q %in% QS) %>% left_join(defq, by = "q") %>%
  mutate(categoria = paste0("uniao_", c(economica = "econ", social = "soc", outras = "outras")[tipo],
                            ifelse(grupo == 0, "_dir", "_transf"))) %>%
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
  est_ano %>% inner_join(oi_gp, by = "ano") %>% transmute(ano, real = est * sh_gp, categoria = "memo_estatais_grupopetro"),
  dash %>% filter(q %in% QS, grupo == 2) %>% left_join(defq, by = "q") %>% group_by(ano) %>%
    summarise(real = sum(nom * f), .groups = "drop") %>% mutate(categoria = "memo_uniao_delegada_32_42")
) %>% left_join(part %>% group_by(ano) %>% summarise(tot = sum(real), .groups = "drop"), by = "ano") %>%
  mutate(part_total = real / tot, bloco = "memo", part_bloco = NA_real_) %>% select(-tot)
part_out <- bind_rows(part, memo) %>%
  transmute(ano, bloco, categoria, real_rs_bi_2025 = real, part_total_pct = 100 * part_total, part_bloco_pct = 100 * part_bloco) %>%
  arrange(ano, bloco, categoria)
write_csv_safe(part_out, "results/A3_participacoes_ano.csv")
L("Participacoes anuais (results/A3_participacoes_ano.csv e .tex): total = Uniao GND 4 (todas as funcoes e modalidades) + ",
  "estatais encadeadas, em R$ de 2025 sem ajuste sazonal. Uniao por tipo (economica, social, outras) e modalidade (direta = ",
  "grupo 0; transferencia = grupos 1 e 2). Estatais por segmento de 2016 em diante: participacao do segmento na OI aplicada ao ",
  "total encadeado do ano; antes de 2016 so o total. Linhas memo (filtro da dissertacao, estatais total, grupo Petrobras, ",
  "execucao delegada 32 e 42) nao somam na particao.")

# Tabela LaTeX
cols_uni <- c("uniao_econ_dir", "uniao_econ_transf", "uniao_soc_dir", "uniao_soc_transf", "uniao_outras_dir", "uniao_outras_transf")
cols_est <- c("estatais_petro", "estatais_econ", "estatais_outras")
tab <- part %>% select(ano, categoria, part_total) %>%
  pivot_wider(names_from = categoria, values_from = part_total) %>%
  left_join(part %>% group_by(ano) %>% summarise(total = sum(real), .groups = "drop"), by = "ano") %>%
  mutate(estatais = rowSums(across(any_of(c(cols_est, "estatais_sem_abertura"))), na.rm = TRUE)) %>%
  arrange(ano)
tex_num <- function(x, d = 1) ifelse(is.na(x), "--", gsub("\\.", "{,}", formatC(x, format = "f", digits = d)))
for (k in c(cols_uni, cols_est)) if (!k %in% names(tab)) tab[[k]] <- NA_real_
linhas <- vapply(seq_len(nrow(tab)), function(i) {
  r <- tab[i, ]
  vals <- c(tex_num(r$total, 1), vapply(cols_uni, function(k) tex_num(100 * r[[k]]), ""),
            tex_num(100 * r$estatais), vapply(cols_est, function(k) tex_num(100 * r[[k]]), ""))
  paste0(r$ano, " & ", paste(vals, collapse = " & "), " \\\\")
}, "")
tex <- c(
  "% Gerado por R/A3_investimento_publico.R. Requer \\usepackage{booktabs}.",
  "\\begin{table}[htbp]", "\\centering",
  "\\caption{Participa\\c{c}\\~ao anual no investimento p\\'ublico federal (Uni\\~ao GND 4 e estatais), \\% do total, 2003--2025}",
  "\\label{tab:a3_participacoes}", "\\scriptsize", "\\setlength{\\tabcolsep}{3pt}",
  "\\begin{tabular}{lrrrrrrrrrrr}", "\\toprule",
  " & Total & \\multicolumn{6}{c}{Uni\\~ao} & \\multicolumn{4}{c}{Estatais} \\\\",
  "\\cmidrule(lr){3-8}\\cmidrule(lr){9-12}",
  " & R\\$ bi & \\multicolumn{2}{c}{Econ\\^omica} & \\multicolumn{2}{c}{Social} & \\multicolumn{2}{c}{Outras} & Total & Petr\\'oleo & Econ. & Outras \\\\",
  "\\cmidrule(lr){3-4}\\cmidrule(lr){5-6}\\cmidrule(lr){7-8}",
  "Ano & de 2025 & Dir. & Transf. & Dir. & Transf. & Dir. & Transf. & & & & \\\\", "\\midrule",
  linhas, "\\bottomrule", "\\end{tabular}",
  "\\begin{minipage}{0.95\\linewidth}\\footnotesize",
  paste0("\\medskip Notas: Uni\\~ao: valores pagos + restos a pagar pagos em GND 4 (todos os elementos); estatais: investimento das ",
         "estatais federais. Valores deflacionados pelo IPCA m\\'edio do trimestre (R\\$ de 2025) e somados no ano. Dir. = aplica\\c{c}\\~ao ",
         "direta (modalidades 90 e 91); Transf. = demais modalidades, inclusive a execu\\c{c}\\~ao delegada a estados e munic\\'ipios ",
         "(32 e 42, a partir de 2012). Econ\\^omica: fun\\c{c}\\~oes 24, 25 e 26; social: 08, 10, 12, 15, 16, 17 e 27; outras: demais. ",
         "Estatais: boletim da SEST at\\'e 2019 e OI encadeado pela raz\\~ao m\\'edia boletim/OI de 2016--2019 a partir de 2020; abertura ",
         "por segmento (participa\\c{c}\\~ao na OI) s\\'o a partir de 2016. Petr\\'oleo: Oil, gas \\& derivatives; Econ.: Electricity, ",
         "Transport, Port e Airport administration; Outras: demais segmentos. Federal de 2017 pelo dashboard trimestral (GND 4 completo, ",
         "sem imputa\\c{c}\\~ao)."),
  "\\end{minipage}", "\\end{table}")
write_lines_safe(tex, "results/A3_participacoes_ano.tex")

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
ordem_apt <- ordem[ordem %in% APTAS]
# Choques: so series aptas para as LP (regra de aptidao); niveis: todas
wide_de <- function(col, series) {
  ind %>% left_join(longo %>% filter(serie %in% series) %>% select(trimestre, serie, v = all_of(col)) %>%
                      pivot_wider(names_from = serie, values_from = v), by = "trimestre") %>%
    select(trimestre, starts_with("imp"), starts_with("emenda"), all_of(series))
}
choques <- wide_de("log10_indice_sa", ordem_apt)
choques_semao <- wide_de("log10_indice_sa_semao", ordem_apt)
niveis <- tibble(trimestre = QS) %>%
  left_join(longo %>% transmute(trimestre, serie, v = coalesce(real_sa_rs_bi_2025, nominal_sa_rs_bi)) %>%
              pivot_wider(names_from = serie, values_from = v), by = "trimestre") %>%
  select(trimestre, all_of(ordem))
# Toda serie apta tem log10 em toda a sua janela
stopifnot(all(sapply(ordem_apt, function(nm) !anyNA(longo$log10_indice_sa[longo$serie == nm]))))
write_csv_safe(choques, "data/processed/A3_choques_wide.csv")
write_csv_safe(choques_semao, "data/processed/A3_choques_semao_wide.csv")
write_csv_safe(niveis, "data/processed/A3_niveis_wide.csv")

# Metadados: unidade, ajuste e observacoes por serie
eh_oi <- function(nm) DEF[[nm]]$fonte == "SEST OI"
tipo_serie <- function(nm) case_when(grepl("_econ", nm) & grepl("^uniao", nm) ~ "economica",
                                     grepl("_soc", nm) ~ "social", grepl("gnd4", nm) ~ "total", TRUE ~ NA_character_)
nao_estmun <- dest_tot %>% filter(destino != "estados e municipios") %>% group_by(tipo) %>%
  summarise(p = sum(participacao), .groups = "drop")
pne <- function(tp) pct(nao_estmun$p[nao_estmun$tipo == tp])
obs_serie <- function(nm) {
  e <- DEF[[nm]]; o <- character(0)
  tp <- tipo_serie(nm)
  if (e$fonte == "dashboard" && !(grepl("_dir$|_dt", nm) && !is.na(tp))) {
    o <- c(o, "GND 4 com todos os elementos (o dashboard trimestral nao tem elemento).")
  }
  if (e$fonte == "dashboard" && grepl("_dir$|_dt", nm) && !is.na(tp)) {
    o <- c(o, paste0("GND 4 com todos os elementos (o dashboard trimestral nao tem elemento), nao o filtro da dissertacao. ",
                     "Parcela do filtro da dissertacao na direta (", tp, "): 2003 ", pct(ce(tp, 2003)), ", 2010 ", pct(ce(tp, 2010)),
                     ", 2016 ", pct(ce(tp, 2016)), ", 2025 ", pct(ce(tp, 2025)), "; elemento 39 (servicos de terceiros PJ) ",
                     pct(comp_tot$parc_elemento_39[comp_tot$tipo == tp]), " da direta em 2003-2025. Candidata a quebra de ",
                     "composicao 2011-2016 (A4)."))
  }
  if (e$fonte == "dashboard" && grepl("_dt|transf", nm)) {
    tps <- if (grepl("econ", nm)) "economica" else "social"
    o <- c(o, paste0("Transferencia inclui as modalidades ", TXT_MOD_NAO_ESTMUN, ", alem de estados e ",
                     "municipios: ", pne(tps), " da transferencia ", tps, " em 2003-2025 (base anual); o dashboard ",
                     "trimestral nao permite separa-las.",
                     if (!grepl("_g1$", nm)) " Transferencia = grupos 1 e 2 (inclui a execucao delegada 32 e 42): escolha a confirmar pelo autor antes da A5; ver variantes _g1." else ""))
  }
  if (eh_oi(nm)) {
    o <- c(o, paste0("Nivel da OI, sem encadeamento; multiplicar por ", fmt(R_BASE, 4), " (razao media boletim/OI 2016-2019) ",
                     "para comparar ou somar com estatais_total (coluna fator_escala_boletim)."))
  }
  if (!is.null(e$comp)) o <- c(o, paste0("Ajuste indireto: nivel com ajuste = soma de ", paste(e$comp, collapse = " + "), " com ajuste."))
  if (e$nominal) o <- c(o, "Nominal: nivel com ajuste na coluna nominal_sa_rs_bi; colunas reais vazias.")
  paste(o, collapse = " ")
}
# Outliers por serie (nas series de ajuste indireto, os dos componentes) e texto sobre o que a serie ajustada mantem
out_serie <- out_all %>% group_by(serie) %>%
  summarise(outliers_x11 = paste(unique(outlier), collapse = " "), dummies_outliers = paste(unique(dummy), collapse = " "),
            tem_ao = any(tipo == "AO"), .groups = "drop")
obs_out <- function(nm) {
  o <- out_serie %>% filter(serie == nm)
  if (!nrow(o)) return("Sem outliers no regARIMA; a variante sem AO (_semao) e igual a serie ajustada.")
  paste0("A serie ajustada (tabela D11 do X-11) mantem os efeitos de AO e LS do regARIMA (", o$outliers_x11,
         if (!is.null(DEF[[nm]]$comp)) ", dos componentes" else "", "): os picos de AO ficam no choque. Dummies em ",
         "A3_dummies_outliers.csv (", o$dummies_outliers, ")",
         if (!o$tem_ao) "; sem AO, a variante _semao e igual a serie ajustada." else
           paste0("; variante sem o efeito dos AO nas colunas _semao de A3_invpub_trimestral.csv",
                  if (nm %in% APTAS) " e em A3_choques_semao_wide.csv." else "."))
}
obs_lp <- function(nm) {
  a <- apt %>% filter(serie == nm)
  if (a$apta_lp) "" else paste0("NAO usar como choque nas LP da A5 (fora de A3_choques_wide.csv): ", a$motivo_fora_lp, ".")
}
par_a5 <- c(PAR_G1, setNames(names(PAR_G1), PAR_G1))
meta <- tibble(serie = names(DEF), definicao = sapply(DEF, `[[`, "def"), fonte = sapply(DEF, `[[`, "fonte")) %>%
  left_join(longo %>% group_by(serie) %>% summarise(inicio = min(trimestre), fim = max(trimestre), n = n(),
                                                    base_indice = first(base_indice),
                                                    tem_log10 = any(!is.na(log10_indice_sa)), .groups = "drop"), by = "serie") %>%
  left_join(sa_info %>% select(serie, especificacao, transformacao_x11 = transformacao), by = "serie") %>%
  left_join(apt %>% transmute(serie, q_x11, erro_arred_max_pct = round(100 * erro_arred_max, 3), trimestre_erro_max = q_erro_max,
                              apta_lp, motivo_fora_lp), by = "serie") %>%
  left_join(out_serie %>% select(serie, outliers_x11, dummies_outliers), by = "serie") %>%
  mutate(outliers_x11 = coalesce(outliers_x11, "nenhum"), dummies_outliers = coalesce(dummies_outliers, ""),
         conjunto_base = serie %in% SERIES_BASE,
         principal = serie %in% PRINCIPAIS,
         par_a5 = unname(par_a5[serie]),
         unidade_nivel = case_when(sapply(serie, eh_nominal) ~ "R$ bi correntes (sem deflacao)",
                                   sapply(serie, eh_oi) ~ paste0("R$ bi de 2025 (IPCA medio do trimestre), nivel da OI sem encadeamento; multiplicar por ",
                                                                 fmt(R_BASE, 4), " para comparar com estatais_total"),
                                   TRUE ~ "R$ bi de 2025 (IPCA medio do trimestre)"),
         fator_escala_boletim = ifelse(sapply(serie, eh_oi), R_BASE, NA_real_),
         ajuste = ifelse(grepl("^indireto", especificacao), especificacao,
                         paste0("X-11 ", ifelse(transformacao_x11 == "log", "multiplicativo (transform.function = log)",
                                                "aditivo (transform.function = none)"),
                                " (x11_sa) sobre ", qt(inicio), "-", qt(fim), ", ", especificacao,
                                "; serie ajustada = D11, com os efeitos de AO e LS")),
         transformacao_choque = ifelse(tem_log10, "log10 do indice com ajuste sazonal",
                                       "sem log10 (serie com valor ou ajuste <= 0); so nivel"),
         observacao = paste(sapply(serie, obs_lp), sapply(serie, obs_serie), sapply(serie, obs_out)) %>% str_squish()) %>%
  select(-especificacao, -tem_log10)
write_csv_safe(meta, "data/processed/A3_metadados_series.csv")
L("Indicadoras: imp2017 = 1 em 2017T1-2017T4; emenda_sest = 1 de 2020T1 em diante; emenda_sest_2017 a _2020 para as emendas ",
  "alternativas (emenda_sest_2020 vale tambem para e2020_r1618).")
L("Metadados (data/processed/A3_metadados_series.csv): unidade_nivel, fator_escala_boletim e observacao por serie. As series por ",
  "funcao estao marcadas como GND 4 completo (nao o filtro da dissertacao); as de transferencia, com a parcela das modalidades ",
  TXT_MOD_NAO_ESTMUN, " (", pne("social"), " na social, ", pne("economica"), " na economica, 2003-2025); as series so da OI, com o fator ",
  fmt(R_BASE, 4), " para comparar com estatais_total.")
L("Saidas: data/processed/A3_invpub_trimestral.csv (longo, ", length(unique(longo$serie)), " series; coluna nominal_sa_rs_bi so nas ",
  "series nominais; colunas _semao com a variante sem o efeito dos AO), A3_choques_wide.csv (log10 do indice com ajuste, so as ",
  length(ordem_apt), " series aptas para as LP), A3_choques_semao_wide.csv (idem, sem o efeito dos AO), A3_niveis_wide.csv (nivel ",
  "com ajuste de todas as series: R$ bi de 2025; nas series _nominal, R$ bi correntes), A3_outliers_series.csv, ",
  "A3_dummies_outliers.csv, A3_metadados_series.csv; results/A3_participacoes_ano.csv e .tex, A3_reconstrucao_INF.md, ",
  "A3_reconstrucao_INF_variantes.csv, A3_classificacao.md, A3_transferencias_destino.csv, A3_composicao_elementos_direta.csv, ",
  "A3_sensibilidade_outliers_oi.csv, A3_x11_diagnostico.csv; results/figuras/A3_series.png e .pdf, A3_series_demais.png, ",
  "A3_series_semao.png, A3_series_variantes.png e A3_INF_reconstruida.png.")

# Resumo de niveis para o log
niv_ano <- longo %>% filter(serie %in% SERIES_BASE) %>% mutate(ano = ano_q(trimestre)) %>%
  group_by(serie, ano) %>% summarise(v = sum(real_rs_bi_2025), .groups = "drop")
L("Niveis anuais do conjunto base, R$ bi de 2025 sem ajuste (2003 ou 2016 / 2019 / 2025):")
for (s in SERIES_BASE) {
  x <- niv_ano %>% filter(serie == s)
  L2(s, ": ", fmt(x$v[1], 1), " (", x$ano[1], ") / ", fmt(x$v[x$ano == 2019], 1), " / ", fmt(x$v[x$ano == 2025], 1), ".",
     if (s %in% DESCRITIVAS) " Descritiva, fora das LP." else "")
}

# Pontos de atencao para A4 e A5
sh_te <- longo %>% filter(serie %in% c("uniao_transf_econ", "uniao_econ_dt")) %>%
  mutate(per = ifelse(ano_q(trimestre) <= 2014, "2003-2014", "2015-2025")) %>%
  group_by(per, serie) %>% summarise(v = sum(real_rs_bi_2025), .groups = "drop") %>%
  pivot_wider(names_from = serie, values_from = v) %>% mutate(sh = uniao_transf_econ / uniao_econ_dt)
dd_e <- longo %>% filter(serie %in% c("uniao_econ_dt", "uniao_econ_dir"), trimestre >= "2015Q1") %>%
  select(trimestre, serie, log10_indice_sa) %>% pivot_wider(names_from = serie, values_from = log10_indice_sa)
ele <- oi %>% filter(segmento == "Electricity", !grupo_petrobras) %>% mutate(ano = ano_q(q)) %>%
  group_by(ano) %>% summarise(v = sum(valor_nominal_bi), .groups = "drop")
L("Pontos de atencao:")
L2("Transferencias na infraestrutura economica: ", pct(sh_te$sh[sh_te$per == "2003-2014"]), " de uniao_econ_dt em 2003-2014 e ",
   pct(sh_te$sh[sh_te$per == "2015-2025"]), " em 2015-2025 (R$ de 2025). Depois de 2014, uniao_econ_dt quase coincide com ",
   "uniao_econ_dir (correlacao das diferencas do log10 em 2015T1-2025T4: ", fmt(cor(diff(dd_e$uniao_econ_dt), diff(dd_e$uniao_econ_dir)), 3),
   "), e uniao_transf_econ tem valores trimestrais muito pequenos (minimo R$ ", fmt(min(pos$minimo[pos$serie == "uniao_transf_econ"]), 4),
   " bi), log muito volatil e Q do X-11 acima de 1; pela regra de aptidao, fica fora das LP. A comparacao direta x transferencia ",
   "na economica tem pouca informacao depois de 2014.")
L2("Estatais, segmento Electricity fora do grupo Petrobras (OI, R$ bi nominais por ano): ", paste0(ele$ano, " ", fmt(ele$v, 2), collapse = "; "),
   ". A queda a partir de 2022T3 e compativel com a saida da Eletrobras do conjunto das estatais depois da capitalizacao de 2022 ",
   "(a confirmar pelo autor); seria quebra de composicao em estatais_econ e estatais_sempetro, a testar na A4.")
L2("2017 so afeta uniao_filtro_diss e inf_diss (e variantes): as series do dashboard (uniao_*_dir, _dt, _transf, gnd4) tem 2017 ",
   "observado trimestralmente, sem imputacao.")

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
       title = "Series principais de investimento publico (aptas para as LP), R$ de 2025, X-11, 2003T1-2025T4",
       caption = paste0("Faixa cinza: 2017 (distribuicao trimestral imputada no filtro da dissertacao). Linha tracejada: 2020T1 (emenda ",
                        "boletim/OI da SEST).\nA serie ajustada mantem os efeitos de AO e LS (ver A3_series_semao.png). Demais series e ",
                        "variantes em A3_series_demais.png.")) +
  tema
ggsave_safe("results/figuras/A3_series.png", p_series, width = 11, height = 9, dpi = 200, bg = "white")
ggsave_safe("results/figuras/A3_series.pdf", p_series, width = 11, height = 9, bg = "white")

# Demais series e variantes, em log10 do indice, um painel por familia (a primeira serie e a referencia)
nm_emendas_inf <- sub("estatais_total", "inf_diss", names(est_var))
FAM <- list(
  "uniao_econ_dt: grupos 1 e 2 x so grupo 1" = c("uniao_econ_dt", "uniao_econ_dt_g1"),
  "uniao_soc_dt: grupos 1 e 2 x so grupo 1" = c("uniao_soc_dt", "uniao_soc_dt_g1"),
  "uniao_transf_soc: grupos 1 e 2 x so grupo 1" = c("uniao_transf_soc", "uniao_transf_soc_g1"),
  "uniao_transf_econ (o _g1 nao tem log10)" = c("uniao_transf_econ"),
  "estatais_outras" = c("estatais_outras"),
  "uniao_filtro_diss: imputacao de 2017" = c("uniao_filtro_diss", "uniao_filtro_diss_imprazao", "uniao_filtro_diss_impapendice"),
  "inf_diss: imputacao de 2017 e X-11 depois de somar" = c("inf_diss", "inf_diss_imprazao", "inf_diss_impapendice", "inf_diss_x11soma"),
  "inf_diss nominal: janela do X-11 ate 2025 e ate 2019" = c("inf_diss_nominal", "inf_diss_nominal_2019"),
  "estatais_total: emendas boletim/OI" = c("estatais_total", names(est_var)),
  "inf_diss: emendas boletim/OI" = c("inf_diss", nm_emendas_inf),
  "estatais_petro: AO comuns x sem outliers" = c("estatais_petro", "estatais_petro_semout"),
  "estatais_sempetro: AO comuns x sem outliers" = c("estatais_sempetro", "estatais_sempetro_semout"))
PAL_F <- c("#2a78d6", "#eb6834", "#1baf7a", "#4a3aa7", "#d4a72c", "#c2185b")
painel_fam <- function(tit, ss) {
  rot <- setNames(paste0(ss, ifelse(ss %in% APTAS, "", " (fora das LP)")), ss)
  z <- longo %>% filter(serie %in% ss, !is.na(log10_indice_sa)) %>%
    mutate(x = dq(trimestre), r = factor(rot[serie], levels = rot))
  ggplot(z, aes(x, log10_indice_sa, colour = r)) +
    geom_line(aes(linewidth = ifelse(serie == ss[1], 0.7, 0.4))) +
    scale_linewidth_identity() +
    scale_colour_manual(values = setNames(PAL_F[seq_along(rot)], rot), name = NULL) +
    scale_x_continuous(breaks = seq(2004, 2024, 4)) +
    guides(colour = guide_legend(ncol = 2)) +
    labs(x = NULL, y = NULL, title = tit) + tema +
    theme(legend.position = "bottom", legend.text = element_text(size = 6.5), plot.title = element_text(size = 8.5, face = "bold"),
          legend.key.height = unit(0.3, "cm"), legend.margin = margin(0, 0, 0, 0))
}
p_demais <- wrap_plots(lapply(names(FAM), function(k) painel_fam(k, FAM[[k]])), ncol = 3) +
  plot_annotation(title = "Demais series e variantes de robustez: log10 do indice com ajuste sazonal (media 2003 = 100; OI: media 2016 = 100)",
                  caption = "A primeira serie de cada painel (linha grossa) e a referencia. uniao_transf_econ_g1 (sem log10) esta em nivel em A3_series_variantes.png.",
                  theme = tema)
ggsave_safe("results/figuras/A3_series_demais.png", p_demais, width = 13, height = 15, dpi = 170, bg = "white")

# Serie ajustada (D11, com AO) x variante sem o efeito dos AO, series principais com AO
com_ao <- PRINCIPAIS[PRINCIPAIS %in% out_serie$serie[out_serie$tem_ao]]
semao_d <- longo %>% filter(serie %in% com_ao) %>%
  select(trimestre, serie, `com AO (D11, choque baseline)` = log10_indice_sa, `sem o efeito dos AO (_semao)` = log10_indice_sa_semao) %>%
  pivot_longer(-c(trimestre, serie), names_to = "versao", values_to = "v") %>%
  mutate(x = dq(trimestre), serie = factor(serie, levels = com_ao))
p_semao <- ggplot(semao_d, aes(x, v, colour = versao)) +
  geom_line(aes(linewidth = ifelse(grepl("^com", versao), 0.6, 0.45))) +
  scale_linewidth_identity() +
  facet_wrap(~serie, ncol = 3, scales = "free_y") +
  scale_colour_manual(values = c("com AO (D11, choque baseline)" = "#a9a8a3", "sem o efeito dos AO (_semao)" = "#2a78d6"), name = NULL) +
  scale_x_continuous(breaks = seq(2004, 2024, 4)) +
  labs(x = NULL, y = "log10 do indice com ajuste sazonal",
       title = "Series principais com AO: serie ajustada (mantem AO e LS) x variante sem o efeito dos AO",
       caption = "Variante sem AO: serie ajustada dividida pelo fator de AO do regARIMA (tabela A8.AO). Os LS ficam nas duas versoes.") + tema
ggsave_safe("results/figuras/A3_series_semao.png", p_semao, width = 11, height = 3 * ceiling(length(com_ao) / 3) + 1.2, dpi = 200, bg = "white")

ROT <- c("estatais_total" = "Baseline", "inf_diss" = "Baseline", "uniao_filtro_diss" = "Baseline", "uniao_transf_econ" = "Baseline",
         "uniao_filtro_diss_imprazao" = "Imputacao 2017: razao", "uniao_filtro_diss_impapendice" = "Imputacao 2017: Apendice A",
         "uniao_transf_econ_g1" = "So grupo 1", "inf_diss_x11soma" = "X-11 depois de somar",
         "estatais_petro" = "Baseline", "estatais_sempetro" = "Baseline",
         "estatais_petro_semout" = "Sem outliers", "estatais_sempetro_semout" = "Sem outliers")
COR_V <- c("Baseline" = "#2a78d6", "Emendas alternativas" = "#a9a8a3", "Imputacao 2017: razao" = "#eb6834",
           "Imputacao 2017: Apendice A" = "#1baf7a", "So grupo 1" = "#4a3aa7", "X-11 depois de somar" = "#d4a72c",
           "Sem outliers" = "#c2185b")
var_d <- bind_rows(
  longo %>% filter(serie %in% c("estatais_total", names(est_var))) %>% mutate(painel = "estatais_total: emenda em 2017T1 a 2020T1"),
  longo %>% filter(serie %in% c("inf_diss", "inf_diss_x11soma", sub("estatais_total", "inf_diss", names(est_var)))) %>%
    mutate(painel = "inf_diss (ajuste indireto): emenda em 2017T1 a 2020T1 e X-11 depois de somar"),
  longo %>% filter(serie %in% c("estatais_petro", "estatais_petro_semout")) %>%
    mutate(painel = paste0("estatais_petro: AO comuns (", paste(toupper(AO_COMUM), collapse = ", "), ") x sem outliers")),
  longo %>% filter(serie %in% c("estatais_sempetro", "estatais_sempetro_semout")) %>%
    mutate(painel = "estatais_sempetro: AO comuns x sem outliers"),
  longo %>% filter(serie %in% c("uniao_filtro_diss", "uniao_filtro_diss_imprazao", "uniao_filtro_diss_impapendice"),
                   ano_q(trimestre) %in% 2015:2020) %>% mutate(painel = "uniao_filtro_diss: imputacao de 2017 (2015-2020)"),
  longo %>% filter(serie %in% c("uniao_transf_econ", "uniao_transf_econ_g1")) %>% mutate(painel = "uniao_transf_econ: com e sem execucao delegada (32 e 42)")
) %>% mutate(x = dq(trimestre), rotulo = factor(coalesce(ROT[serie], "Emendas alternativas"), levels = names(COR_V)),
             lw = ifelse(rotulo == "Baseline", 0.7, 0.45)) %>%
  arrange(desc(rotulo))
p_var <- ggplot(var_d, aes(x, real_sa_rs_bi_2025, group = serie, colour = rotulo)) +
  geom_line(aes(linewidth = lw)) +
  facet_wrap(~painel, ncol = 1, scales = "free") +
  scale_colour_manual(values = COR_V, name = NULL, drop = FALSE) +
  scale_linewidth_identity() +
  labs(x = NULL, y = "R$ bi de 2025, com ajuste sazonal", title = "Series baseline e variantes de robustez") + tema
ggsave_safe("results/figuras/A3_series_variantes.png", p_var, width = 8, height = 14, dpi = 200, bg = "white")

rec_d <- longo %>% filter(serie %in% c("inf_diss", "inf_diss_nominal", "inf_diss_nominal_2019")) %>%
  transmute(q = trimestre, v = log10_indice_sa, serie = ifelse(serie == "inf_diss", "inf_diss (real)", serie))
b03 <- inf_orig %>% filter(q %in% q_seq("2003Q1", "2003Q4"))
orig_d <- inf_orig %>% transmute(q, v = log10(100 * 10^INF / mean(10^b03$INF)), serie = "INF (dissertacao)")
COR2 <- c("INF (dissertacao)" = "#eb6834", "inf_diss_nominal_2019" = "#4a3aa7", "inf_diss_nominal" = "#1baf7a",
          "inf_diss (real)" = "#2a78d6")
niv_d <- bind_rows(orig_d, rec_d) %>% mutate(x = dq(q), serie = factor(serie, levels = names(COR2)))
# Rotulos no fim de cada serie; o de inf_diss_nominal_2019 (fim em 2019T4) sobe acima das linhas, com um traco
lab_d <- niv_d %>% filter(serie != "INF (dissertacao)") %>% group_by(serie) %>% filter(x == max(x)) %>% ungroup() %>%
  mutate(n19 = serie == "inf_diss_nominal_2019", xl = x + ifelse(n19, 0.15, 0.3), yl = ifelse(n19, max(niv_d$v) + 0.07, v))
p1 <- ggplot(niv_d, aes(x, v, colour = serie)) +
  geom_line(linewidth = 0.6) +
  geom_segment(data = filter(lab_d, n19), aes(x = x, xend = xl, y = v, yend = yl - 0.02), linewidth = 0.3, show.legend = FALSE) +
  geom_text(data = lab_d, aes(x = xl, y = yl, label = serie), hjust = 0, size = 2.8, show.legend = FALSE) +
  scale_colour_manual(values = COR2, name = NULL) +
  scale_x_continuous(breaks = seq(2002, 2026, 2), expand = expansion(mult = c(0.02, 0.13))) +
  labs(x = NULL, y = "log10 do indice com ajuste (media 2003 = 100)",
       title = "Nivel: INF da dissertacao (2002T1-2019T4) e series reconstruidas (2003T1-2025T4)") + tema
dif_d <- niv_d %>% filter(q %in% Q_CMP) %>% group_by(serie) %>% arrange(x, .by_group = TRUE) %>%
  mutate(d = v - lag(v)) %>% filter(!is.na(d)) %>% ungroup()
p2 <- ggplot(dif_d, aes(x, d, colour = serie)) +
  geom_hline(yintercept = 0, colour = TINTA2, linewidth = 0.3) +
  geom_line(linewidth = 0.45) +
  scale_colour_manual(values = COR2, name = NULL, guide = "none") +
  scale_x_continuous(breaks = seq(2003, 2019, 2)) +
  labs(x = NULL, y = "diferenca trimestral do log10",
       title = paste0("Diferencas, 2003T2-2019T4. Correlacao com INF: nominal_2019 ", fmt(dest_v$corr_dif, 3), "; nominal ",
                      fmt(nomi_v$corr_dif, 3), "; real indireto ", fmt(base_v$corr_dif, 3))) + tema
p_inf <- p1 / p2
ggsave_safe("results/figuras/A3_INF_reconstruida.png", p_inf, width = 9, height = 7.5, dpi = 200, bg = "white")

# Toda serie aparece em pelo menos uma figura
fig_cob <- unique(c(PRINCIPAIS, unlist(FAM), unique(var_d$serie), c("inf_diss", "inf_diss_nominal", "inf_diss_nominal_2019")))
sem_fig <- setdiff(names(DEF), fig_cob)
if (length(sem_fig)) stop("Series sem figura: ", paste(sem_fig, collapse = ", "))
L("Figuras: A3_series.png e .pdf (", length(PRINCIPAIS), " series principais, log10 do indice); A3_series_demais.png (",
  length(unique(unlist(FAM))), " series em ", length(FAM), " paineis por familia, log10 do indice: descritivas fora das LP e ",
  "variantes); A3_series_semao.png (", length(com_ao), " series principais com AO: com AO x sem o efeito dos AO); ",
  "A3_series_variantes.png (niveis, inclui uniao_transf_econ_g1, que nao tem log10); A3_INF_reconstruida.png. Conferido: ",
  "todas as ", length(DEF), " series aparecem em pelo menos uma figura.")

# ---------------------------------------------------------------------------
# 12. Relatorios em markdown
# ---------------------------------------------------------------------------
md_tab <- function(df) {
  cel <- function(x) gsub("\\|", "/", as.character(x))
  c(paste0("| ", paste(cel(names(df)), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(cel(r), collapse = " | "), " |")))
}
linha_v <- function(rotulo, v) {
  tibble(variante = rotulo, deflator = v$deflator, ajuste = v$ajuste, transformacao = v$transformacao, janela_x11 = v$span,
         imputacao_2017 = v$imputacao, corr_dif = fmt(v$corr_dif, 4), dam_dif = fmt(v$dam_dif, 4),
         desvio_medio_nivel = fmt(v$desvio_medio_nivel, 4), dp_nivel = fmt(v$dp_escala, 4), dam_dif_2017 = fmt(v$dam_dif_2017, 4),
         outliers_x11 = v$outliers)
}
tab_foco <- bind_rows(
  linha_v("destaque: nominal (inf_diss_nominal_2019)", dest_v),
  linha_v("conferencia: nominal, imputacao Apendice A (circular em 2017)", apx_v),
  linha_v("nominal, transformacao automatica", pega("nominal", "soma", tr = "auto")),
  linha_v("nominal, X-11 nos componentes", pega("nominal", "componentes")),
  linha_v("nominal, janela ate 2025 (inf_diss_nominal)", nomi_v),
  linha_v("nominal, imputacao razao", pega("nominal", "soma", imp = "razao")),
  linha_v("real, IPCA medio", pega("media_tri", "soma")),
  linha_v("real, transformacao automatica", pega("media_tri", "soma", tr = "auto")),
  linha_v("real, X-11 nos componentes", pega("media_tri", "componentes")),
  linha_v("real, X-11 nos componentes, janela ate 2025 (inf_diss)", base_v),
  linha_v("real, X-11 depois de somar, janela ate 2025 (inf_diss_x11soma)", soma_v),
  linha_v("real, IPCA do ultimo mes", pega("fim_tri", "soma")),
  linha_v("real, IPCA medio do ano", pega("anual", "soma")),
  linha_v("real, IPCA medio do ano, imputacao Apendice A", pega("anual", "soma", imp = "apendice")),
  linha_v("real, sem ajuste sazonal", pega("media_tri", "nenhum", tr = "-")))
top <- res_var %>% slice(1:10) %>%
  transmute(deflator, ajuste, transformacao, janela_x11 = span, imputacao_2017 = imputacao, corr_dif = fmt(corr_dif, 4),
            dam_dif = fmt(dam_dif, 4), desvio_medio_nivel = fmt(desvio_medio_nivel, 4), dam_dif_2017 = fmt(dam_dif_2017, 4))
cruz_md <- cruzado %>% transmute(deflator, `outliers fixos (origem)` = paste0(outliers_fixos, " (", origem, ")"),
                                 corr_dif = fmt(corr_dif, 4))
md_inf <- c(
  "# A3: reconstrucao de INF", "",
  paste0("Gerado por R/A3_investimento_publico.R em ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "INF da dissertacao: data/original/0224_tri_estmeq.txt, log10, 2002T1-2019T4. Reconstrucao: federal com o filtro da",
  "dissertacao (modalidade 90 e 6 elementos; 2017 com total anual exato e perfil trimestral imputado) + boletim da SEST",
  "(Brasil), X-11, indice e log10. Comparacao em 2003T2-2019T4 (67 diferencas trimestrais).", "",
  "## Resultado", "",
  paste0("O INF da dissertacao e o investimento NOMINAL com ajuste sazonal X-11 multiplicativo. O nivel decide: o desvio padrao da ",
         "diferenca de nivel contra INF (log10) e ", fmt(dest_v$dp_escala, 4), " na serie nominal e cerca de ",
         fmt(pega("media_tri", "soma")$dp_escala, 2), " nas reais. A reconstrucao nominal (X-11 depois de somar, janela ",
         dest_v$span, ", imputacao baseline de 2017; serie inf_diss_nominal_2019) reproduz INF com correlacao das diferencas de ",
         fmt(dest_v$corr_dif, 4), " e desvio medio em nivel de ", fmt(dest_v$desvio_medio_nivel, 4), " em log10 (",
         pct(10^dest_v$desvio_medio_nivel - 1, 1), "). Com a imputacao de 2017 implicita no Apendice A a correlacao vai a ",
         fmt(apx_v$corr_dif, 4), ", mas essa imputacao usa o Ipub, a mesma fonte de INF, e e em parte circular em 2017: fica so como ",
         "conferencia. O X-11 multiplicativo do Ipub nominal do Apendice A reproduz INF com correlacao das diferencas de ",
         fmt(cor(d_apx, d_inf), 4), " em 2002T2-2019T4 e desvio padrao da diferenca de nivel de ", fmt(sd(gap_apx), 4),
         " em log10: INF = log10(X-11 do Ipub nominal) + constante."), "",
  paste0("A serie real (inf_diss, pedida no briefing) e o ajuste indireto: soma de uniao_filtro_diss e estatais_total, cada uma ",
         "com seu X-11 em 2003T1-2025T4. Correlacao das diferencas com INF: ", fmt(base_v$corr_dif, 4), "; com X-11 depois de ",
         "somar (inf_diss_x11soma, a definicao anterior), ", fmt(soma_v$corr_dif, 4), ". Em nivel a serie real se afasta de INF ",
         "com a inflacao acumulada (desvio medio ", fmt(base_v$desvio_medio_nivel, 3), " em log10, maximo ", fmt(base_v$max_nivel, 3),
         "). Para replicar a dissertacao use inf_diss_nominal_2019 (2003-2019) e inf_diss_nominal (janela do X-11 ate 2025, ",
         "correlacao ", fmt(nomi_v$corr_dif, 4), ")."), "",
  paste0("A correlacao das diferencas depende sobretudo dos outliers que o X-11 detecta em 2017-2019. Deteccao automatica, X-11 ",
         "depois de somar, janela 2003T1-2019T4: nominal ", out_nom, " (correlacao ", fmt(dest_v$corr_dif, 4), "); real (IPCA medio) ",
         out_real, " (", fmt(pega("media_tri", "soma")$corr_dif, 4), "). Fixando os outliers de uma serie na outra ",
         "(regression.variables, outlier = NULL):"), "",
  md_tab(cruz_md), "",
  paste0("Sem deteccao de outliers: nominal ", fmt(sem_out[["nominal"]], 4), ", real ", fmt(sem_out[["media_tri"]], 4),
         ". A diferenca entre real e nominal na correlacao vem do conjunto de outliers, nao da deflacao."), "",
  "## Comparacao das variantes", "",
  "corr_dif: correlacao das diferencas do log10; dam_dif: desvio absoluto medio das diferencas; desvio_medio_nivel: media de",
  "reconstruida menos INF, indices base media 2003 = 100, em log10; dp_nivel: desvio padrao de log10(reconstruida) - INF;",
  "dam_dif_2017: desvio absoluto medio das diferencas de 2017T1 a 2018T1. Demais escolhas fixas em X-11 depois de somar, log,",
  "janela 2003T1-2019T4 e imputacao baseline, salvo indicacao. Na coluna outliers_x11, ' ; ' separa as chamadas do X-11",
  "(uma por componente quando ajuste = componentes).", "",
  md_tab(tab_foco), "",
  paste0("Dez variantes com maior correlacao (tabela completa, ", nrow(res_var), " variantes, com os outliers do X-11, em ",
         "results/A3_reconstrucao_INF_variantes.csv). As com imputacao Apendice A sao parcialmente circulares em 2017:"), "",
  md_tab(top), "",
  "Deflatores: media_tri = IPCA medio do trimestre; fim_tri = IPCA do ultimo mes do trimestre; anual = IPCA medio do ano;",
  "nominal = sem deflacao. Ajuste: soma = X-11 depois de somar; componentes = X-11 em cada componente e soma; nenhum = sem X-11.",
  "Transformacao: log = X-11 multiplicativo imposto; auto = escolha do X-13 por AIC.", "",
  "## 2017", "",
  paste0("Perfil trimestral imputado (participacao no total anual de R$ ", fmt(TOT_2017, 3), " bi): baseline ",
         paste(pct(imp_base$nom / TOT_2017), collapse = ", "), "; razao ", paste(pct(imp_raz$nom / TOT_2017), collapse = ", "),
         "; implicito no Apendice A ", paste(pct(imp_apx$nom / TOT_2017), collapse = ", "), ". O Apendice A tem o Ipub nominal de 2017 ",
         "observado na epoca; com a razao (filtro + SEST)/Ipub interpolada entre 2016T4 e 2018T1, a soma implicita de 2017 e R$ ",
         fmt(sum(impl_tot), 3), " bi, contra R$ ", fmt(TOT_2017, 3), " bi exatos."), "",
  "Figura: results/figuras/A3_INF_reconstruida.png.")
write_lines_safe(md_inf, "results/A3_reconstrucao_INF.md")

fun_tab <- tibble(funcao = names(FUNCOES_NOMES), nome = FUNCOES_NOMES, tipo = tipo_funcao(names(FUNCOES_NOMES))) %>%
  left_join(dash %>% filter(q %in% QS) %>% mutate(grupo = pmin(grupo, 1)) %>% group_by(funcao, grupo) %>%
              summarise(v = sum(nom), .groups = "drop") %>%
              pivot_wider(names_from = grupo, values_from = v, names_prefix = "g", values_fill = 0), by = "funcao") %>%
  mutate(across(c(g0, g1), ~ fmt(coalesce(.x, 0), 1))) %>%
  rename(`direta R$ bi` = g0, `transf. R$ bi` = g1)
seg_tab <- oi %>% group_by(segmento, classe) %>%
  summarise(`R$ bi nominais 2016-2025` = fmt(sum(valor_nominal_bi), 1),
            `grupo Petrobras R$ bi` = fmt(sum(valor_nominal_bi[grupo_petrobras]), 1),
            trimestres = paste0(min(q), "-", max(q)), .groups = "drop") %>%
  arrange(match(classe, c("petroleo", "economica", "outras")), segmento)
dest_md <- dest_tot %>% transmute(tipo, destino, `R$ bi nominais` = fmt(nominal_rs_bi, 1), participacao = pct(participacao))
comp_md <- comp_el %>% select(ano, tipo, parc_filtro_diss, parc_elemento_39) %>%
  pivot_longer(c(parc_filtro_diss, parc_elemento_39)) %>%
  mutate(col = paste0(tipo, ifelse(name == "parc_filtro_diss", " filtro", " el. 39")), value = pct(value)) %>%
  select(ano, col, value) %>% pivot_wider(names_from = col, values_from = value) %>%
  select(ano, any_of(paste0(rep(c("economica", "social", "outras", "total"), each = 2), c(" filtro", " el. 39")))) %>%
  arrange(ano)
md_cl <- c(
  "# A3: classificacao das series de investimento publico", "",
  paste0("Gerado por R/A3_investimento_publico.R em ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "## Uniao: funcoes (Portaria MOG 42/1999)", "",
  "Economica: 24, 25, 26. Social: 08, 10, 12, 15, 16, 17, 27. Outras: demais funcoes. Valores: GND 4, somas nominais 2003-2025",
  "do dashboard trimestral (direta = grupo 0, modalidades 90 e 91; transferencia = grupos 1 e 2, todas as demais modalidades).", "",
  md_tab(fun_tab), "",
  "## Uniao: modalidades", "",
  "- aplicacao direta (grupo 0 do dashboard): 90 e 91;",
  "- transferencia (grupos 1 e 2 do dashboard): todas as demais. O grupo 2 do dashboard trimestral nao e 67 e 99 (que nao",
  "  aparecem na base anual): em 2012-2025 ele e exatamente a execucao orcamentaria delegada a estados (32) e a municipios (42);",
  "  as series _g1 excluem esse grupo;",
  "- destino das transferencias: estados e municipios = 30, 31, 32, 40, 41, 42, 71, 72; entidades privadas = 50 e 60;",
  "  exterior = 80; outras = demais (na base, so a 70, instituicoes multigovernamentais).", "",
  "Destino das transferencias, base anual, 2003-2025 (somas nominais):", "",
  md_tab(dest_md), "",
  "## Uniao: composicao por elemento da aplicacao direta", "",
  paste0("As series por funcao vem do dashboard trimestral, sem elemento: sao GND 4 com todos os elementos, nao o filtro da ",
         "dissertacao. Parcela do filtro da dissertacao (modalidade 90 e 6 elementos) e do elemento 39 (", EL39, ") na aplicacao ",
         "direta (90 e 91), base anual do painel fed_B, nominal. Candidata a quebra de composicao para a A4: 2011-2016 ",
         "(economica: filtro ", pct(ce("economica", 2010)), " em 2010, ", pct(ce("economica", 2011)), " em 2011, ",
         pct(ce("economica", 2016)), " em 2016)."), "",
  md_tab(comp_md), "",
  paste0("Em 2003-2025: ", paste0(comp_tot$tipo, " filtro ", pct(comp_tot$parc_filtro_diss), ", elemento 39 ",
                                  pct(comp_tot$parc_elemento_39), collapse = "; "), ". Tabela em results/A3_composicao_elementos_direta.csv."), "",
  "## Estatais: segmentos da OI", "",
  paste0("Classificacao aprovada pelo autor em 2026-09-28, conforme o registro do coordenador em results/log_parts/A0_ambiente.md ",
         "(incluido no commit 862af3f), que lista as tres classes: petroleo = Oil, gas & derivatives; economica = Electricity, ",
         "Transport, Port administration, Airport administration; outras = Financial, Commerce & services, Industry, Research, ",
         "development & planning, Food supply. O registro nao diz o meio da aprovacao; o briefing cobre so petroleo e economica."), "",
  md_tab(seg_tab), "",
  "Antes de 2016 (boletim) nao ha abertura por segmento: so o total Brasil.", "",
  paste0("Series so da OI: nivel da OI sem encadeamento (multiplicar por ", fmt(R_BASE, 4), " para comparar com estatais_total). ",
         "X-11 com os AO de estatais_total de 2016 em diante fixos (", paste(toupper(AO_COMUM), collapse = ", "),
         "), sem deteccao automatica. Sensibilidade em results/A3_sensibilidade_outliers_oi.csv."), "",
  "## Itens para aprovacao do autor antes da A5", "",
  paste0("1. Transferencia = grupos 1 e 2 do dashboard (inclui a execucao delegada 32 e 42, a partir de 2012) contra so o grupo 1 ",
         "(leitura literal do briefing; variantes _g1). A definicao do briefing foi alterada e isso vai para o LOG consolidado. Ate a ",
         "confirmacao, a A5 estima obrigatoriamente os dois membros de cada par (coluna par_a5 dos metadados) e reporta a diferenca. ",
         "As series de transferencia incluem ainda as modalidades ", TXT_MOD_NAO_ESTMUN, " (",
         pne("social"), " na social, ", pne("economica"), " na economica), que o dashboard trimestral nao separa."),
  paste0("2. Outliers das series so da OI: AO do total de 2016 em diante (", paste(toupper(AO_COMUM), collapse = ", "), "), conferidos ",
         "no total da OI, no baseline; variantes na tabela de sensibilidade (so AO com |z| > 2 na propria serie; AO e LS; sem ",
         "outliers: estatais_petro_semout, estatais_sempetro_semout)."),
  "3. inf_diss real por ajuste indireto (decisao do coordenador em results/log_parts/A0_ambiente.md); inf_diss_x11soma como variante.",
  paste0("4. Encadeamento boletim/OI pela razao media 2016-2019 (", fmt(R_BASE, 4), "); variante e2020_r1618 (razao 2016-2018, ",
         fmt(R_1618, 4), ") para isolar 2019."),
  "5. Series por funcao sao GND 4 completo; quebra de composicao 2011-2016 a testar na A4.",
  "6. Queda de Electricity fora do grupo Petrobras a partir de 2022T3 (saida da Eletrobras?), a confirmar.",
  paste0("7. Regra de aptidao para as LP: fora toda serie com Q do X-11 > ", fmt(Q_MAX, 0), ", erro de arredondamento > ",
         pct(ERRO_MAX, 0), " ou sem log10. Saem do conjunto base: ", paste(DESCRITIVAS, collapse = " e "), "."),
  paste0("8. As series ajustadas mantem AO e LS do regARIMA. Dummies em data/processed/A3_dummies_outliers.csv; variante sem o ",
         "efeito dos AO em data/processed/A3_choques_semao_wide.csv."), "",
  "## Series de choque", "",
  paste0("Principais (conjunto base, aptas para as LP; log10 do indice em data/processed/A3_choques_wide.csv):"), "",
  md_tab(meta %>% filter(principal) %>% select(serie, definicao, inicio, fim, base_indice, unidade_nivel, q_x11, observacao)), "",
  "Fora das LP (regra de aptidao):", "",
  md_tab(meta %>% filter(!apta_lp) %>% select(serie, definicao, q_x11, erro_arred_max_pct, motivo_fora_lp)), "",
  "Variantes de robustez:", "",
  md_tab(meta %>% filter(!principal) %>% select(serie, definicao, inicio, fim, apta_lp, par_a5, observacao)))
write_lines_safe(md_cl, "results/A3_classificacao.md")

L("Classificacao das funcoes (para aprovacao do autor) e dos segmentos da SEST (aprovada pelo autor em 2026-09-28, conforme o ",
  "registro do coordenador em results/log_parts/A0_ambiente.md, commit 862af3f, com as tres classes, inclusive outras; o registro ",
  "nao diz o meio da aprovacao; o briefing cobre so petroleo e economica):")
L2("Uniao economica: ", paste0(names(FUNCOES_ECONOMICA), " ", FUNCOES_ECONOMICA, collapse = "; "), ".")
L2("Uniao social: ", paste0(names(FUNCOES_SOCIAL), " ", FUNCOES_SOCIAL, collapse = "; "), ".")
L2("Uniao outras: todas as demais funcoes, inclusive 00 (sem funcao) e 28 (encargos especiais).")
for (cl in c("petroleo", "economica", "outras")) {
  x <- seg_tab %>% filter(classe == cl)
  L2("Estatais ", cl, ": ", paste0(x$segmento, " (R$ ", x$`R$ bi nominais 2016-2025`, " bi)", collapse = "; "), ".")
}
L2("Variante por grupo_petrobras: estatais_grupopetro = grupo_petrobras True (Oil, gas & derivatives e Electricity do grupo); ",
   "estatais_semgrupopetro = demais. Tabela completa em results/A3_classificacao.md.")
L("Itens para aprovacao do autor antes da A5 (lista tambem em results/A3_classificacao.md): (1) transferencia = grupos 1 e 2 do ",
  "dashboard contra so o grupo 1 (variantes _g1); (2) AO comuns ao total nas series so da OI contra sem outliers; (3) inf_diss ",
  "real por ajuste indireto, com inf_diss_x11soma como variante; (4) encadeamento pela razao 2016-2019 contra a variante ",
  "e2020_r1618; (5) series por funcao em GND 4 completo, com quebra de composicao 2011-2016 a testar na A4; (6) Electricity ",
  "fora do grupo Petrobras a partir de 2022T3; (7) regra de aptidao para as LP, que tira ", paste(DESCRITIVAS, collapse = " e "),
  " do conjunto de choques; (8) series ajustadas com AO e LS, com dummies e variante sem AO para a A4 e a A5.")
md5_x <- if (file.exists("data/raw/x.csv")) unname(tools::md5sum("data/raw/x.csv")) else NA_character_
L("Fora do escopo da A3: data/raw/x.csv (conteudo 'a' e '1') esta versionado desde o commit 26b479d dentro da pasta protegida; ",
  "nao foi criado pela A3 (md5 ", md5_x, " no fim desta execucao; a A3 so le data/raw). Cabe ao coordenador remover com git rm ",
  "e descobrir qual script gravou em data/raw fora de guard_path.")

save_session_info("A3_investimento_publico")
L("Tempo total: ", round(as.numeric(difftime(Sys.time(), t_ini, units = "secs"))), " s.")
