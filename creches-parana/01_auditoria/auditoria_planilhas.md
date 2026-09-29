# Auditoria das planilhas do PCM e das distribuições de creches

Data da auditoria: 28/09/2026. Arquivos originais preservados em `00_originais/` (SHA-256 em `SHA256SUMS.txt`). Nenhuma célula dos arquivos originais foi alterada; todas as leituras foram feitas em cópias, com exportação integral de valores e fórmulas para `01_auditoria/dump/` (um CSV de valores e um CSV de fórmulas por aba).

## 1. Inventário dos arquivos

| Arquivo | SHA-256 (prefixo) | Abas | Conteúdo |
|---|---|---|---|
| Indicador_Criterio_VF.xlsx | 98fae995… | CI, Controle, Educacional, Demográfico, Socioeconômico, Municipios | Cálculo do PCM e distribuição técnica inicial (252 creches previstas; 251 efetivamente atribuídas), classificação em oito portes com P1 ≤ 20 mil habitantes; aba "Municipios" com 34 registros codificados |
| 20240327_Distribuicao_Creches.xlsx | 3aabe679… | Resultados, Metodologia, Dados, Educacional, Demográfico, Socioeconômico, Planilha1 (oculta) | Distribuição consolidada de 300 creches (43 da etapa prévia + 257 pelo PCM), reclassificação dos portes pequenos (P3 20–70 mil, P2 5–20 mil, P1 ≤ 5 mil), tetos por porte e cotas por faixa |
| Apresentacao_Creches.pdf | cf51d7ac… | 10 páginas | Apresentação institucional (Casa Civil, Casa Civil) com a arquitetura do PCM, fontes dos indicadores e a tabela de classificação por porte (idêntica à da planilha de 27/03/2024) |

## 2. Estrutura das fórmulas (reconstruídas e verificadas)

### 2.1 Componentes (abas Educacional, Demográfico, Socioeconômico; idênticas nos dois arquivos, 0 células divergentes)

Fator educacional (FE): `O = (2·Creche_Normalizado + Matrícula_Normalizado + Privado_Normalizado)/4`; `P = (O − mín)/(máx − mín)·100`. Os três subindicadores normalizados são valores hardcoded (não há fórmula); a verificação mostra correlação −1,00 entre `Creche_Normalizado` e a proporção de matrícula em creche (normalização em sentido inverso: mais cobertura, menor escore), correlação −0,57 para pré-escola/fundamental e −0,95 para oferta privada (normalizações inversas com truncamento ou referência distinta do mín–máx simples; não reproduzíveis exatamente a partir das colunas presentes). O rodapé da aba está rotulado "Quartil Mínimo/Máximo", mas os valores são o mínimo e o máximo da coluna.

Fator demográfico (FD): `K = (MI_Normalizado + Proporção_Normalizado + Natalidade_Normalizado)/3`; `L = mín–máx·100`. `MI_Normalizado` reproduz exatamente o mín–máx da mortalidade infantil; `Proporção_Normalizado` e `Natalidade_Normalizado` são lineares nos indicadores brutos (correlação 1,00), mas com amplitude diferente do mín–máx sobre os 399 municípios (diferença máxima de 60,6 e 19,1 pontos), o que indica normalização feita sobre outra base (por exemplo, incluindo valores de referência externos). A aba tem cinco linhas de rodapé, duas com mínimos e máximos.

Fator socioeconômico (FS): `L = (IPDM_normalizado + CadÚnico_Normalizado + Desnutrição_Normalizado)/3`; `M = mín–máx·100`. Os três subindicadores reproduzem exatamente o mín–máx (IPDM em sentido inverso). Curitiba tem FS = 0 (referência mínima). Duas células `#NUM!` no rodapé (colunas N e O, sem uso a jusante).

### 2.2 PCM

Fórmula padrão (aba CI do arquivo VF e aba Dados do arquivo de 27/03/2024): `PCM = (2·FE + FD + 2·FS)/5/100`. Reproduzida para 399 municípios (diferença máxima 0). Amplitude observada: 0,240 (Palotina) a 0,789.

Divergência relevante: na aba Dados do arquivo de 27/03/2024, as 62 linhas do porte P3 (20–70 mil habitantes) têm a fórmula `(1·FE + FD + 3·FS)/5/100`, com peso triplo no fator socioeconômico, coerente com a nota da aba Metodologia ("Ranking do PCM (com maior peso no fator socioeconômico)"). A variante altera a seleção de um município entre os 27 contemplados nessa faixa em relação ao PCM padrão.

### 2.3 Distribuição técnica inicial (arquivo VF, aba CI)

Colunas: `D = Ponderação Pop (bloco 1)`, `E = Ponderação Pop (bloco 2)`, `J = pop04/pop04_porte·D`, `K = pop04/pop04_porte·E`, `L = ((J·(1+PCM)) + 3·(PCM + K))/4`, `O = FLOOR(L)`, `P = L − O`, `Q = RANK(P)`, `R = O + IF(Q < Q$1, 1, 0)`, com `Q$1 = SUM(L) − SUM(O)`.

Bloco 1 da aba Controle: total ajustado `F10 = 252/(1 + PCM ponderado 0,438) = 175,2`; bloco 2: `F24 = 252 − soma dos PCM (191,35) = 60,6`. A soma de L é exatamente 252,000; a soma das partes inteiras é 60; Q$1 = 192. Como o critério usa desigualdade estrita (`<`), o município com rank 192 (Nova Esperança do Sudoeste, fração 0,4649) não recebe a unidade e o total efetivamente atribuído é 251, não 252. Decisão de tratamento: mantivemos o valor da coluna R (251) como "distribuição técnica inicial", por ser o resultado que consta do arquivo; registramos a diferença.

Decomposição: dos 252 pontos da coluna L, 63 vêm do termo populacional `J·(1+PCM)/4` e 189 do termo `3·(PCM + K)/4`; deste, 143,5 correspondem a `0,75·PCM`, um piso quase uniforme por município, independente da população. Essa estrutura explica por que 191 municípios recebem exatamente uma creche e por que os 307 municípios com até 20 mil habitantes recebem 119 unidades.

### 2.4 Distribuição consolidada (arquivo de 27/03/2024)

Aba Resultados: `IPARDES (43 creches)` + `PCM (257 creches)` = `TOTAL (300 creches)`; 224 municípios com pelo menos uma unidade. Aba Dados: `K = J·(1 + PCM) − IPARDES` (a etapa prévia é descontada do cálculo proporcional). A coluna `Q (TOTAL CRECHES)` da aba Dados é um cálculo proporcional sem tetos (soma 142 para os 30 municípios grandes; Curitiba 30) e não corresponde ao resultado final; o resultado final está apenas na aba Resultados, em valores digitados.

Regras reconstruídas e testadas:
- Portes P3, P2 e P1: seleção dos n municípios de maior PCM dentro do porte, excluídos os já contemplados na etapa prévia, com n = 27, 100 e 30. Reprodução exata (27/27, 100/100, 30/30). O PCM mínimo entre os selecionados supera o máximo entre os não selecionados em cada faixa (P3: 0,4168 > 0,4158; P2: 0,4688 > 0,4653; P1: 0,5126 > 0,5115).
- Portes G2 a P4 (30 municípios, 100 creches): a melhor regra testada (maior resto sobre `K`, total 100, tetos de 10, 8, 7, 4 e 2 por porte, com redistribuição do excedente) reproduz 28 dos 30 valores; Guarapuava e Sarandi diferem em uma unidade cada (a regra dá 4 e 3, o arquivo registra 3 e 1). Os tetos constam da coluna "Limite de Creches Por Município" da aba Metodologia.
- Cobertura registrada na aba Metodologia: P3 27/62 (43,5%), P2 100/205 (48,8%), P1 30/102 (29,4%).

## 3. Aba "Municipios" (arquivo VF) e "Planilha1" (arquivo de 27/03/2024)

A aba Municipios lista 34 municípios em caixa alta com uma quantidade (soma 40) e um código de texto: SD (20 casos), PREFEITO (9), R (4) e YAN (1). Os códigos não são documentados no arquivo e não os interpretamos. As demais colunas cruzam a quantidade com o total da distribuição técnica (`E = B − D`) e com um arquivo externo não disponível (`[1]CI`). A quantidade registrada coincide com o total da distribuição consolidada em 10 dos 34 casos; 11 dos 34 municípios receberam creche pelo ranking do PCM na consolidada, e todos os 11 estão dentro da regra de seleção reproduzida, ou seja, teriam sido selecionados independentemente do registro. Cascavel (quantidade 7) recebeu 6; Ponta Grossa (quantidade 1, técnica 4) recebeu 7; Sarandi (quantidade 1, técnica 2) recebeu 2. A aba contém ainda uma lista de 135 nomes (coluna L) e 16 números sem rótulo nem fórmula (coluna P), que não puderam ser interpretados.

A Planilha1 (oculta) lista os 43 municípios da etapa prévia com fórmulas `#REF!` (referência quebrada), sem efeito no resultado.

## 4. Ausências e limitações

- Não há, nos arquivos, o cálculo da etapa prévia (43 creches). A apresentação a descreve como "índice de prioridade de creche" (déficit de vagas, crescimento da população 0–3 anos e crianças com perfil Bolsa Família), elaborado pelo Ipardes.
- Os subindicadores normalizados são valores digitados; os indicadores brutos estão presentes, mas três normalizações não são reproduzíveis exatamente.
- Não há registro de data, autoria ou versão dentro das planilhas; a data de 27/03/2024 vem do nome do arquivo.
- Não há documentação da regra de redução de 142 para 100 unidades no bloco de municípios grandes; a reprodução é aproximada (28/30).
- A população-alvo total (1.497.164) nas abas Controle/Metodologia é a soma da coluna "População 0 a 4" da aba Demográfico. Essa coluna vale, em média, 2,1 vezes a população de 0 a 4 anos da aba Educacional (698.133 no estado; Curitiba 202.402 contra 85.003), com correlação 0,998 entre as duas. A magnitude e a razão são compatíveis com a população de 0 a 9 anos do Censo 2022, o que sugere erro de rótulo. A coluna alimenta o subindicador "proporção da população 0 a 4" do fator demográfico e as cotas proporcionais por porte. Como as participações por porte diferem em no máximo 1,3 ponto percentual entre as duas colunas, o efeito sobre a distribuição é pequeno. Adotamos a coluna da aba Educacional como população-alvo (0 a 4 anos) nas estatísticas descritivas e nas simulações, e a da aba Demográfico apenas para reproduzir as fórmulas originais.

## 5. Decisões de limpeza

1. Junção pelo código IBGE de sete dígitos da aba Educacional (399/399 municípios; nomes idênticos aos do IBGE).
2. Variáveis derivadas documentadas em `02_base_tratada/dicionario_variaveis.csv`.
3. Tipologia: "Não contemplado" (138), "Somente técnica" (37), "Somente consolidada" (52), "Técnica e consolidada" (172).
4. Diferença consolidada − técnica calculada por município; positivo indica acréscimo.

## 6. Adendo: lista publicada (Resolução SEDEF nº 219/2024, retificada, de 04/06/2024)

Após o levantamento documental, incorporamos ao estudo o Anexo I da Resolução SEDEF nº 219/2024 (cópia em `00_originais/Resolucao_SEDEF_219_2024_retificada.pdf`), que estabelece os critérios de ranqueamento do Programa Infância Feliz Paraná (Lei Estadual nº 21.870/2023) com base no PCM e lista os municípios elegíveis. A tabela foi extraída do PDF (261 linhas, soma 303, sem duplicidades) e casada por nome normalizado com a base (261 de 261 casados). A Deliberação CEDCA/PR nº 25/2024, de 24/05/2024 (cópia em `00_originais/Deliberacao_CEDCA_25_2024.pdf`), aprovou o estudo, o ranqueamento e a lista de unidades, e registra que "o estudo prévio desenvolvido [pelo] IPARDES para a criação do PCM foi aprimorado considerando os dados de vulnerabilidade, risco social e elevada demanda".

Comparação com a distribuição consolidada de 27/03/2024 (300 creches, 224 municípios): a lista publicada tem 303 creches em 261 municípios. Nenhum município da consolidada foi retirado. Dezessete municípios dos portes G2 a P4 tiveram redução de 37 unidades (Ponta Grossa −5; Curitiba, Londrina e São José dos Pinhais −4; Foz do Iguaçu e Colombo −3; Guarapuava, Cascavel e Maringá −2; oito municípios −1). Quarenta municípios ganharam 40 unidades: 37 entraram com uma unidade (16 do porte P3, 16 do P2 e 5 do P1) e três receberam uma segunda unidade (Campina Grande do Sul e Rio Branco do Sul, porte P3; um município do porte P4). Os 37 entrantes têm PCM médio de 0,395 (posição média 306 no ranking estadual) e ocupam, dentro de seus portes, as posições 30 a 57 (P3, com corte da consolidada em 27), 106 a 173 (P2, corte em 100) e 38 a 81 (P1, corte em 30), ou seja, situam-se abaixo da linha de corte, sem seguir estritamente a ordem do ranking. Dezessete deles haviam recebido uma unidade na distribuição técnica inicial e a perderam na consolidada. Sete dos 37 constam da aba "Municipios" da planilha VF (Brasilândia do Sul, Cafelândia, Dois Vizinhos, Goioerê, Nova Londrina, Planalto e São Pedro do Paraná).

Tipologia em três etapas (variável `tipologia3`): nas três etapas, 172; entrou na consolidada e permaneceu, 52; técnica, excluído na consolidada e reincluído na publicada, 17; somente na lista publicada, 20; somente na técnica, 20; não contemplado em nenhuma, 118.

Fontes oficiais posteriores (Resoluções SEDEF 285/2024, 325/2024, 029/2025, 075/2025, 479/2025, 084/2026 e notícias da AEN) documentam a habilitação, as vagas remanescentes, a segunda etapa e as obras; estão registradas em `07_log/levantamento_noticias.md`.

## 7. Adendo: planilha de conferência de 21/05/2024 (`20240521_Distribuicao_Creches_Conferencia.xlsx`)

Terceira versão das planilhas, recebida após a primeira auditoria (hash em `00_originais/SHA256SUMS.txt`; dumps `CF__*` em `01_auditoria/dump/`). Abas: Dados (399 municípios), Conferência (oculta), Metodologia, Educacional, Demográfico, Socioeconômico e Planilha1 (oculta). As abas dos três pilares são idênticas às das versões anteriores. Diferenças relevantes:

- A coluna PCM da aba Dados usa a fórmula padrão `(2·FE + FD + 2·FS)/5/100` para os 399 municípios (a variante com peso 3 no fator socioeconômico para o porte P3, presente na versão de 27/03/2024, não consta desta versão).
- A aba Dados calcula a cota populacional `J = (pop. 0 a 4 do município / pop. 0 a 4 do porte) × Ponderação Pop do porte`, com `Ponderação Pop = proporção do porte na população-alvo × 257/(1 + 0,50314)` (aba Metodologia, célula F10 = 170,98), a aproximação `K = J·(1 + PCM) − IPARDES`, a parte inteira `N = FLOOR(K)`, a fração `O = K − N`, o ranking `P = RANK(O)` e `Q = N + IF(P < P$1, 1, 0)`, com `P$1 = SUM(K) − SUM(N) = 111,44`. Somas: K = 201,4; N = 90; Q = 201. A coluna Q, por porte, alimenta a coluna Total da aba Metodologia (G2 30, G1 11, M2 44, M1 41, P4 16, P3 57, P2 5, P1 −3), que é o cálculo proporcional sem tetos; a distribuição final por faixa (10 + 90 nos portes grandes; 27, 100 e 30 nos pequenos) e os tetos por município (10, 8, 7, 4, 2 e 1) constam das colunas "Distribuição por Faixa" e "Limite de Creches Por Município".
- A aba Conferência compara, município a município, a "versão antiga (limitador maior)" com a "versão atual (limitador menor)". A versão antiga coincide integralmente com a distribuição consolidada de 27/03/2024 (399/399 municípios; 300 creches em 224 municípios). A versão atual tem 300 creches em 258 municípios e coincide com a lista publicada na Resolução SEDEF nº 219/2024 em 396 dos 399 municípios; a resolução acrescentou uma unidade a Santa Terezinha de Itaipu (P3), Corbélia (P2) e Pranchita (P2), chegando a 303 creches em 261 municípios. Os números da versão atual (300 creches, 258 municípios) são os anunciados oficialmente em 10/06/2024.
- A passagem da versão antiga para a atual retirou 38 unidades de 18 municípios (Curitiba 10 → 6; Londrina 8 → 4; Ponta Grossa 7 → 2; São José dos Pinhais 7 → 3; Foz do Iguaçu 6 → 3; Colombo 5 → 2; Maringá e Cascavel 6 → 4; Guarapuava 4 → 2; oito municípios −1, entre eles Santa Terezinha de Itaipu, do porte P3, reincluído na resolução) e distribuiu 38 unidades a 38 municípios: Cianorte (P4) e 37 municípios dos portes P3, P2 e P1 (35 novos; Campina Grande do Sul e Rio Branco do Sul passaram a 2). O rótulo da própria planilha atribui a mudança aos tetos ("limitador").
- Rastreabilidade: variável `cedca_258` na base tratada (`scripts/02b_base_conferencia.py`).

## 8. Adendo: base de entregas do PPA 2024-2027 (`Base_entregas_PPA_18_12_2023.xlsx`)

Base de conferência das entregas do Plano Plurianual 2024-2027 (Lei Estadual nº 21.861/2023), com 21.566 linhas (uma por entrega, ano e marcação). Filtro por "creche", "primeira infância" e "educação infantil" (`01_auditoria/ppa_entregas_creches_filtro.csv`): a construção de creches está na entrega 4670, "Municípios beneficiados com repasses de recursos para projetos e/ou estruturas físicas voltados à primeira infância", da Secretaria de Estado do Desenvolvimento Social e Família, Eixo 4 (Inclusão Social, Direitos Humanos e Cidadania), Programa 29 (Paraná que Cuida), Ação Orçamentária 7010 (Projetos Estratégicos Integrados). Descrição: "Contempla os municípios que receberem repasses de recursos financeiros para desenvolvimento do projeto de instalação de creches sustentáveis (cujos tamanhos variam entre 300 m² e 750 m², dependendo da necessidade da comunidade do município)". Meta: 72 municípios beneficiados por ano em 2024, 2025 e 2026 (216 no quadriênio) e zero em 2027; marcação Criança e Adolescente; Plano de Governo "Rede Materno Infantil"; ODS 3, 4, 10 e 16. A entrega 4671, da mesma ação, prevê kits para famílias de recém-nascidos (2.000 famílias por ano). Não há entrega com a palavra "creche" na Secretaria de Estado da Educação (a entrega 4113, da ação 8093, refere-se a materiais pedagógicos para a educação infantil).
