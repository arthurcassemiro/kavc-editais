import json, sys
# Versão 10 (pesos como critério de focalização, ajustes da verificação; contrafactual na lição 1); base v6. Versão 5: v4 + segunda rodada de verificação (fatos, coerência e parecer, método).
# Índices de elemento = filhos de w:body do manuscrito de entrada (entrada/texto.txt).
T = {}
T["018"] = "A seção 2 situa a educação infantil no federalismo e nas evidências empíricas e descreve o programa. A seção 3 reconstrói o PCM, e a seção 4 apresenta a regra de conversão e seus resultados alocativos. A seção 5 reúne as considerações finais."
T["049"] = "Para orientar a distribuição das unidades, a Casa Civil construiu o PCM, com três pilares (educacional, demográfico e socioeconômico), apresentados a seguir."
T["074"] = "**a proporção de crianças na população total (PC):** prevista para a faixa de 0 a 4 anos, foi calculada na planilha com a de 5 a 14 anos do Censo de 2022[^8]; "
T["nota8"] = ("A coluna da planilha rotulada como população de 0 a 4 anos, faixa que a Resolução SEDEF nº 219/2024 indica para PC (PARANÁ, 2024a, art. 3º), contém a de 5 a 14 anos (IBGE, 2023), "
 "usada também nas cotas dos portes grandes (seção 4.1). Calculado como descrito no texto, com a população de 0 a 4 anos e o operador N também em PC e TN, o PCM teria correlação de postos de 0,99 com o adotado; "
 "153 dos 157 municípios que ele seleciona nas faixas de menor porte se manteriam, e duas unidades mudariam de município entre os 30 maiores.")
T["113a"] = ("Os pesos da Figura 3 traduzem um critério de focalização social. A Deliberação nº 60/2023 do CEDCA/PR incumbiu a SEDEF de definir e ordenar por prioridade as localidades de maior vulnerabilidade, risco social e elevada demanda para a educação infantil (CEDCA, 2023, art. 2º). "
 "A lei do programa destina as creches às crianças em situação de vulnerabilidade (PARANÁ, 2023), e o Plano Nacional de Educação fixou como estratégia reduzir a menos de 10% a diferença de frequência à creche entre o quinto de renda mais alto e o mais baixo (BRASIL, 2014, estratégia 1.2). "
 "A demanda priorizada aparece sobretudo na lacuna de vagas, que o fator educacional mede, e o retorno do acesso à creche é maior entre as famílias pobres (seção 2.2). "
 "Por isso, os fatores educacional e socioeconômico recebem peso 2, e o demográfico, que capta a pressão potencial da demanda por indicadores indiretos, peso 1. "
 "A equipe técnica da Casa Civil converteu a orientação nesses valores, aplicados no ranqueamento que o CEDCA/PR aprovou com o estudo; a Deliberação nº 25/2024 registra que o estudo considerou os dados de vulnerabilidade, risco social e demanda (CEDCA, 2024). "
 "Na classificação de Decancq e Lugo (2013), a ponderação é normativa, sem estimação estatística, e o manual da OCDE admite pesos que reflitam prioridades de política (OECD; JRC, 2008, p. 31).")
T["113b"] = ("Dois argumentos técnicos, verificados *a posteriori*, reforçam a escolha. Com correlações de postos de 0,02 a 0,23 entre os fatores, é improvável uma dimensão latente comum, e pesos de análise fatorial ou de componentes principais seriam pouco informativos (OECD; JRC, 2008, p. 32, 89). "
 "A qualidade dos dados, critério que o manual admite com ressalvas (OECD; JRC, 2008, p. 32), corrobora o peso menor do fator demográfico, cuja variação vem sobretudo da mortalidade infantil, instável nos municípios pequenos. "
 "Em 2020, 133 dos 399 municípios não registraram óbito infantil, e, nos de até 5 mil habitantes, com mediana de 42 nascimentos por ano, um único óbito altera a taxa em cerca de 24 por mil. "
 "A equação (5) consolida o cálculo, e o Mapa 4 mostra o resultado:")
T["119"] = ("Na normalização mínimo-máximo, um único município define o zero ou o cem de cada indicador, o que torna o índice sensível a valores extremos (OECD; JRC, 2008). "
 "Testamos pesos iguais, peso 3 no fator socioeconômico e 1 nos demais (variante ainda mais focalizada na vulnerabilidade, que as planilhas de março e maio usaram na faixa de 20 a 70 mil habitantes), normalização por percentis e retirada da mortalidade infantil. "
 "A correlação de postos com o PCM adotado fica entre 0,93 e 0,97, e de 138 a 146 dos 157 municípios que o PCM seleciona nas faixas de menor porte (seção 4.1) se manteriam, com trocas a menos de sete centésimos das linhas de corte. "
 "A seção 4 converte esse ordenamento em unidades.")
T["139"] = ("O conjunto dos 30 municípios grandes recebeu, porém, uma cota fixa de 100 unidades, repartida pelo maior resto na proporção de ⟦K_i⟧, com tetos de 10, 8, 7, 4 e 2 unidades por município, em ordem decrescente de porte, "
 "o que reduziu o total desses municípios de 142 para 100 e o de Curitiba, de 30 para 10. Com o total fixo e os tetos, a alocação reproduzida é a mesma com os dois valores de m.")
T["157"] = ("A Tabela 7 apresenta as versões sucessivas em todas as faixas. Ao reproduzir as regras, verificamos que, nas faixas de até 20 mil habitantes, os 130 contemplados do bloco 3 são exatamente os de maior PCM, com menos de um centésimo entre o último contemplado e o primeiro suplente; "
 "na faixa de 20 a 70 mil, as planilhas de março e maio usaram a variante com peso 3 no fator socioeconômico (seção 3.4), e 26 dos 27 contemplados coincidem com os de maior PCM. Nos portes grandes, o maior resto com tetos reproduz 28 dos 30 valores. "
 "As versões seguintes se afastaram da ordem do índice: os 35 municípios que entraram em maio e dois dos três acrescentados pela resolução passaram à frente de suplentes com PCM maior. "
 "Nenhum contemplado em março ficou fora da lista publicada[^6].")
T["nota6"] = ("A versão de maio reduziu os tetos dos portes grandes e retirou 37 unidades de 17 municípios dessas faixas, nem todas por efeito dos tetos, e a unidade de Santa Terezinha de Itaipu (20 a 70 mil habitantes); "
 "as 38 unidades foram para 38 municípios, 37 deles das faixas inferiores (35 sem unidade em março), e a versão alcançou 300 unidades em 258 municípios, números anunciados em 10 de junho de 2024 (PARANÁ, 2024b). "
 "A Resolução SEDEF nº 219/2024 devolveu a unidade de Santa Terezinha de Itaipu, acrescentou uma unidade a Corbélia e a Pranchita, de 5 a 20 mil habitantes, e publicou 303 unidades em 261 municípios, "
 "com substituição do desistente pelo próximo ranqueado (PARANÁ, 2024a).")
T["novo4_2"] = ("Para medir o efeito da distribuição adotada sobre a seleção territorial, comparamos a versão de maio de 2024, aprovada pelo CEDCA/PR, com um critério apenas populacional, "
 "que repartiria as mesmas 300 unidades em proporção à população de zero a quatro anos[^7]. A versão aprovada contemplou 258 municípios, contra 147, deu 6 unidades a Curitiba, contra 37, "
 "e destinou 28% das unidades aos 80 municípios de maior PCM, contra 13%; 89% das crianças de zero a quatro anos viviam em municípios contemplados, contra 85%. "
 "Na versão de março, anterior à redistribuição, eram 224 municípios contemplados, com 82% das crianças.")
T["nota7"] = ("O critério populacional é uma simulação contrafactual da distribuição que se observaria na ausência da regra adotada: reparte as 300 unidades entre os 399 municípios em proporção à população de zero a quatro anos "
 "do Censo Demográfico de 2022 (IBGE, 2023), pelo maior resto usado no bloco 2 (BALINSKI; YOUNG, 2001), sem PCM, faixas, cotas, tetos ou etapa prévia. A versão de maio soma as mesmas 300 unidades e inclui as 43 da etapa prévia, anteriores ao índice; "
 "mantidas essas 43 e repartidas as outras 257 pela população, seriam 152 municípios, 31 unidades em Curitiba e 17% das unidades nos 80 municípios de maior PCM. "
 "A simulação é estática e não considera adesões, desistências nem capacidade de execução.")
T["162"] = ("O artigo perguntou como converter evidências de necessidade em uma regra efetiva de alocação. No caso paranaense, a resposta combinou um índice, que ordena os municípios, "
 "e uma regra de conversão, que transforma o ordenamento em unidades. Três lições decorrem dos resultados:")
T["163"] = ("**Índice e regra decidem juntos o resultado territorial.** Com PCM igual à média estadual, 0,48 (Tabela 5), um município de 5 a 20 mil habitantes seria contemplado no bloco 3, cuja linha de corte nessa faixa ficou em 0,469. "
 "Um de até 5 mil seria suplente, pois ali o corte foi 0,513; entre os 30 maiores, o mesmo valor apenas ponderaria a população, multiplicada por 1,48 no cálculo. "
 "Com o índice inalterado, a redução dos tetos e a redistribuição das unidades elevaram de 224 para 258 os municípios contemplados, e o contrafactual apenas populacional da seção 4.2 alcançaria 147. "
 "A regra de conversão exige, por isso, a mesma documentação que o índice.")
T["164"] = ("**Medir a necessidade exigiu dados de vários setores.** Os fatores reúnem registros da educação, da saúde, da assistência social e da economia regional e têm correlações de postos de 0,02 a 0,23 entre si (seção 3.4), "
 "de modo que cada um acrescenta informação própria. Como o fator educacional cresce com o porte e o socioeconômico diminui, o PCM médio fica entre 0,415 e 0,498 em todas as faixas, exceto em Curitiba (Tabela 5); "
 "um índice só educacional favoreceria as cidades maiores, e um só socioeconômico, as menores. A decisão também envolveu vários órgãos, do estudo da Casa Civil e do Ipardes à adesão dos municípios (Figura 1).")
T["165"] = ("**A reconstrução da regra tornou verificável a margem de decisão.** Confrontada com o estudo aprovado pelo CEDCA/PR e com as planilhas, a lista publicada (PARANÁ, 2024a) mostra onde a decisão seguiu o índice e onde se afastou dele. "
 "Nas faixas de até 20 mil habitantes, o bloco 3 segue a ordem do PCM, com menos de um centésimo entre o último contemplado e o primeiro suplente, dentro da margem em que pesos alternativos trocam municípios (seção 3.4). "
 "Os municípios que entraram em maio, ao contrário, passaram à frente de suplentes com PCM maior (seção 4.2). "
 "Terreno e capacidade de licitar, que o índice não capta, entram pela adesão (PARANÁ, 2024c), e a vaga de quem desiste passa ao próximo ranqueado (PARANÁ, 2024a).")
T["167"] = ("A terceira lição remete à economia política do gasto público. Mogues (2015) parte da incongruência entre o retorno elevado de certos investimentos e sua negligência nas carteiras orçamentárias "
 "e atribui a alocação aos incentivos e às restrições de políticos, burocratas, grupos de interesse e doadores, às características dos bens e ao ambiente de governança. "
 "No Paraná, a decisão de investir em creches precedeu a regra, e o que ficou exposto a esses determinantes foi a escolha dos municípios. "
 "A regra explícita não impediu os ajustes posteriores; a reconstrução das planilhas os tornou identificáveis, e, publicados a ordem e os pesos, que a Resolução nº 219/2024 omite, cada prefeito poderia conferir sua posição e planejar o custeio.")
T["169"] = ("Como todo indicador composto, o índice depende da qualidade e da data dos registros administrativos e é sensível a valores extremos na normalização; seus pesos são normativos, e suas *proxies* podem se afastar da necessidade vivida pelas famílias. "
 "A reconstrução revelou ainda erros na planilha, na faixa etária de PC e na normalização de dois indicadores, de efeito pequeno sobre a seleção (seção 3.2).")
T["170"] = ("O resultado analisado aqui é a alocação. Uma avaliação *ex post*, com as unidades em funcionamento, poderá examinar a execução das obras, as matrículas e o emprego dos cuidadores, "
 "e verificar se o investimento produziu efeitos onde o índice apontou maior carência.")
T["171"] = ("Até lá, a contribuição do caso é mostrar como um indicador de dados públicos, aplicado por uma regra de conversão documentada, pode tornar reprodutível a decisão sobre onde o Estado investe "
 "e identificáveis os ajustes que se afastam do índice.")
REF_DECANCQ = "DECANCQ, K.; LUGO, M. A. Weights in multidimensional indices of wellbeing: an overview. Econometric Reviews, v. 32, n. 1, p. 7-34, 2013. DOI: 10.1080/07474938.2012.690641."
S = {
 "text_subs": [
  {"el": 4, "old": "e uma regra que contemplou 258 municípios", "new": "e uma versão aprovada que contemplou 258 municípios"},
  {"el": 7, "old": "and a rule that reached 258 municipalities", "new": "and an approved version that reached 258 municipalities"},
  {"el": 10, "old": "y una regla que alcanzó 258 municipios", "new": "y una versión aprobada que alcanzó 258 municipios"},
  {"el": 35, "old": "vistoria obras (PARANÁ, 2025). ", "new": "vistoria obras (PARANÁ, 2025). A Figura 1 sintetiza o processo decisório e os atores:"},
  {"el": 41, "old": "No que tange ao aspecto das finanças públicas, o instrumento é", "new": "O instrumento financeiro é"},
  {"el": 44, "old": "Os recursos vieram da Secretaria da Fazenda Estadual, em complementação ao FIA, e da devolução de duodécimo pela Assembleia Legislativa.", "new": "Os recursos vieram do saldo do FIA/PR, da complementação da Secretaria da Fazenda Estadual e da devolução de duodécimo pela Assembleia Legislativa."},
  {"el": 44, "old": "Sendo assim, a figura 2 demonstra o processo financeiro: ", "new": "A Figura 2 resume o fluxo financeiro:"},
  {"el": 77, "old": "normalizados pelo operador N, e o fator", "new": "normalizados pelo operador N (na planilha, PC e TN foram apenas divididos pelo maior valor municipal), e o fator"},
  {"el": 84, "old": "e as crianças de zero a quatro anos eram 6,1% da população em 2022, contra 6,3% (IBGE, 2023).", "new": "e a população de 5 a 14 anos, usada no indicador PC, era 13,1% do total em 2022, contra 13,5% (IBGE, 2023)."},
  {"el": 122, "old": " unidades em três momentos, conforme demonstrado nas subseções a seguir e sintetizado na figura 4. ", "new": " unidades em três blocos, descritos nas subseções a seguir e sintetizados na Figura 4."},
  {"el": 124, "old": "3. Tetos por município: 10, 8, 7, 4 e 2 unidades (de 142 para 100)", "new": "3. Cota fixa de 100 unidades, com tetos de 10, 8, 7, 4 e 2 por município"},
  {"el": 133, "old": "proporcional à parcela da faixa na população-alvo do estado.", "new": "proporcional à parcela da faixa na população-alvo do estado, que na planilha, pelo mesmo erro da seção 3.2, é a população de 5 a 14 anos."},
  {"el": 133, "old": ", em que m é o ", "new": ", em que m deveria ser o "},
  {"el": 133, "old": "população-alvo (0,503), porque,", "new": "população-alvo, porque,"},
  {"el": 135, "old": "após a etapa prévia. A cota da faixa", "new": "após a etapa prévia. As planilhas de março e maio usam m = 0,503, valor digitado sem cálculo que o reproduza, também adotado na Figura 4 e na Tabela 6; uma versão anterior calculava 0,438. A cota da faixa"},
  {"el": 137, "old": "Um município com PCM de 0,50 recebe 50% a mais do que receberia pela população.", "new": "O índice pondera a população-alvo, que, com PCM de 0,50, entra no cálculo multiplicada por 1,5."},
  {"el": 141, "old": ", excluídos os da etapa prévia, e os primeiros da fila", "new": " (na faixa de 20 a 70 mil, pela variante com peso 3 no fator socioeconômico), excluídos os da etapa prévia, e os primeiros da fila"},
  {"el": 142, "old": "A versão apresentada ao conselho em maio manteve o índice e as cotas e reduziu os tetos dos municípios grandes, o que deslocou 38 unidades para as faixas inferiores e elevou o alcance para 258 municípios.",
             "new": "A versão apresentada ao conselho em maio manteve o índice, reduziu os tetos dos municípios grandes e redistribuiu 38 unidades, 37 delas para as três faixas inferiores, o que elevou o alcance para 258 municípios."},
  {"el": 159, "old": "03/2024", "new": "05/2024"},
 ],
 "cell_subs": [
  {"el": 81, "row_first": "Proporção de crianças pequenas (PC)", "col": 1, "old": "População da faixa etária infantil / população total", "new": "População de 5 a 14 anos / população total"},
  {"el": 81, "row_first": "Proporção de crianças pequenas (PC)", "col": 5, "old": "6,1% de 0 a 4 anos (2022)", "new": "13,1% de 5 a 14 anos (2022)"},
  {"el": 81, "row_first": "Proporção de crianças pequenas (PC)", "col": 6, "old": "6,3% (2022)", "new": "13,5% (2022)"},
  {"el": 81, "row_first": "Proporção de crianças pequenas (PC)", "col": 7, "old": "6ª menor", "new": "8ª menor"},
  {"el": 81, "row_first": "Proporção de crianças pequenas (PC)", "col": 0, "old": "Proporção de crianças pequenas (PC)", "new": "Proporção de crianças (PC)"},
  {"el": 154, "row_first": "Porte (habitantes)", "col": 1, "old": "Mun/", "new": "Mun."},
  {"el": 154, "row_first": "Porte (habitantes)", "col": 2, "old": "Pop. 0–4 (%)", "new": "Pop. 5–14 (%)"},
  {"el": 154, "row_first": "G2 (acima de 1 milhão)", "col": 2, "old": "12,2", "new": "13,5"},
  {"el": 154, "row_first": "G1 (500 mil a 1 milhão)", "col": 2, "old": "4,3", "new": "4,5"},
  {"el": 154, "row_first": "M1 (100 a 200 mil)", "col": 2, "old": "17,4", "new": "17,6"},
  {"el": 154, "row_first": "P4 (70 a 100 mil)", "col": 2, "old": "6,4", "new": "6,1"},
  {"el": 154, "row_first": "G2 a P4", "col": 1, "old": "399", "new": "30"},
  {"el": 154, "row_first": "G2 a P4", "col": 2, "old": "100,0", "new": "59,1"},
  {"el": 154, "row_first": "G2 a P4", "col": 3, "old": "100,9", "new": "101,0"},
  {"el": 154, "row_first": "G2 a P4", "col": 7, "old": "100 após tetos", "new": "100 (cota fixa)"},
 ],
 "footnote_subs": [
  {"id": 2, "old": "Ressalta-se que esse trabalho não avalia", "new": "Este trabalho não avalia"},
 ],
 "footnote_replace": {"6": T["nota6"]},
 "math_subs": [ {"el": 97, "old": "s", "new": "S"}, {"el": 104, "old": "s", "new": "S"} ],
 "replace": {
  "18": [T["018"]], "49": [T["049"]], "74": [T["074"]], "113": [T["113a"], T["113b"]], "119": [T["119"]], "139": [T["139"]], "157": [T["157"]],
  "162": [T["162"]], "163": [T["163"]], "164": [T["164"]], "165": [T["165"]], "167": [T["167"]],
  "169": [T["169"]], "170": [T["170"]], "171": [T["171"]],
 },
 "insert_after": {"160": [{"ppr_from": 157, "text": T["novo4_2"]}]},
 "remove": [36, 40, 56, 61, 76, 79, 83, 96, 100, 112, 115, 126, 129, 156, 166, 168],
 "footnotes": {"7": T["nota7"], "8": T["nota8"]},
 "ref_insert_before": {"190": [REF_DECANCQ]},
}
S["text_subs"] += [
  {"el": 2, "old": "INFÂNCIA FELIZ “", "new": "INFÂNCIA FELIZ”"},
  {"el": 17, "old": "reconstruir essa metodologia e replicar como o indicador serviu de instrumento para essa política pública.  Com isso", "new": "reconstruir essa metodologia, replicar seus cálculos e mostrar como o indicador serviu de instrumento para essa política pública. Com isso"},
  {"el": 35, "old": "Em maio de 2024 aprovou", "new": "Em maio de 2024, o conselho aprovou"},
  {"el": 35, "old": "Por fim, Paranacidade, serviço social autônomo da Secretaria das Cidades,", "new": "Por fim, o Paranacidade, serviço social autônomo vinculado à Secretaria das Cidades,"},
  {"el": 41, "old": "e regulamentado pelo Decreto Estadual nº 10.455/2014", "new": "e no Decreto Estadual nº 10.455/2014"},
  {"el": 103, "old": " (Mapa 3), regiões que a seção 4 mostrará entre as mais contempladas.", "new": " (Mapa 3)."},
  {"el": 131, "old": "Os blocos 2 e 3 utilizados pelo PCM respondem à seguinte questão:", "new": "Os blocos 2 e 3 aplicam o PCM de formas distintas por uma razão de escala:"},
  {"el": 144, "old": "e a cobertura de creche cresce à medida que o porte diminui, de 20,9% em Curitiba a 41,8% nos", "new": "e a cobertura de creche é menor nos portes acima de 100 mil habitantes, de 7,6% a 25,5%, e chega a 41,8% nos"},
]
S["move_before"] = [[177, 176], [184, 183]]
json.dump(S, open(sys.argv[1], 'w', encoding='utf8'), ensure_ascii=False, indent=1)
json.dump(T, open(sys.argv[1].replace('.json','_textos.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
