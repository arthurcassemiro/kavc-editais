# LOG

## 2026-09-28
- Replicado o modelo final da dissertacao a partir de data/original (0224_tri_estmeq.txt em log10; 0124_inexo.txt).
  Especificacao que reproduz: VAR(diff(infmeq), p=3, type="both", exogen=diff(exo)). Script: scripts/replica_original.py.
- Resultado: impacto 0,0118; resposta acumulada de PVD em 40 trimestres 0,0194; resposta acumulada do proprio INF 0,0465;
  elasticidade de longo prazo 0,42 (IC 90% bootstrap 0,07 a 0,67).
- Granger da Tabela 12 vem do VAR em nivel (df 3 e 116). No VAR em diferenca: INF->PVD F=3,27, p=0,024.
  PVD->INF: F=1,91, p correto = 0,13 (a dissertacao reporta 0,56).
- Exogenas entram diferenciadas (PIB vira aceleracao; dummy vira pulsos). Dummy do arquivo: 2018T2-2019T1 e 2019T3-2019T4.
- Robustez rapida em results/robustez_rapida.csv (scripts/robustez_rapida.py): efeito sensivel a ordem de Cholesky,
  a forma como o PIB entra e ao numero de defasagens (2 lags).
- A serie INF do modelo nao e a do Apendice A (apendice parece nominal e sem ajuste sazonal).
- PIB diferenciado mantido no baseline pelo principio do acelerador (decisao do autor); versao em taxa de crescimento vira robustez.
- Recebido data/raw/federal_siga_analitico_real.parquet: anual, 2001-2026, sem 2017, inclui GND 5 e 6 (filtrar GND 4),
  so governo federal; parcela atribuivel a UF: 74% (economica) e 43% (social). Serve para o painel de estados (Parte B),
  nao para o VAR trimestral.
- Encontrado o bruto mensal do SIGA (~/financas-publicas-br/dados/federal/Novo documento (1).csv, 2,1 GB, nominal):
  tem Mes/Ano e Elemento. 2017 falta tambem no bruto. Gerados federal_gnd4_mensal.csv e
  federal_inv_direto_trimestral_nominal.csv (filtro da dissertacao). A serie federal soma R$ 5,0 bi em 2002 e R$ 23,1 bi
  em 2013 (nominal); comparada ao Apendice A (R$ 24,7 e 128,8 bi), confirma que o apendice e nominal e que as estatais
  sao a maior parte de INF.
- Extraidos do dashboard (index.html do GitHub Pages): SEST boletim trimestral 2003-2019 e OI trimestral 2016-2025
  (com grupo Petrobras), FGV-Ibre anual, BNDES anual.
- Checagem: federal (filtro da dissertacao) + SEST boletim reproduz o Ipub do Apendice A em 2003-2019
  (razao media 0,97; correlacao das diferencas dos logs = 1,0). Na sobreposicao 2016-2019, OI fica 10-15% acima do boletim.
- 2017: o dashboard tem a serie federal trimestral de 2017 (execucao direta R$ 25,0 bi nominal), sem filtro de elemento.
  Razao filtro/dashboard (execucao direta): 0,62 em 2016, 0,72 em 2018; correlacao das diferencas dos logs 0,99.
- Nova pergunta: efeito por esfera (Uniao, estados, estatais) e tipo (economica x social).
- Uniao, 2003-2025 (nominal): infraestrutura social 70% via transferencias (R$ 192 bi x R$ 82 bi diretos);
  economica 92% direta (R$ 182 bi x R$ 16 bi). Serie so com modalidade 90 subestima a social.
- Estados: dados locais so anuais (DCA 2014-2024; MSC por funcao 2019+). Sem serie trimestral antes de 2015.
