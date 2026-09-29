---
trecho: 4.1
---

## 4.1 Adaptação para o Programa Infância Feliz

O PCM ordena os municípios, mas não diz quantas unidades cada um deve receber. Para converter o ordenamento em uma distribuição, o programa dividiu as 300 unidades em três blocos, definidos em momentos e por regras diferentes (Figura 4). O primeiro são 43 unidades de uma etapa prévia, aprovada pelo conselho antes do PCM. O segundo são 100 unidades para os 30 municípios das cinco faixas superiores de porte, repartidas na proporção da população-alvo, corrigidas pelo PCM e limitadas por tetos. O terceiro são 157 unidades para os 369 municípios das três faixas inferiores, atribuídas por ranqueamento do PCM dentro de cada faixa, uma unidade por município. Os dois regimes respondem a uma diferença de escala: em uma cidade grande, uma unidade atende a uma fração pequena das crianças, e faz sentido repartir várias unidades na proporção da população; em um município pequeno, uma unidade já altera a cobertura, e a decisão relevante é quem entra na lista.

DIAGRAMA: blocos | Figura 4. Da cota populacional às unidades inteiras: os três blocos da distribuição | Fonte: Elaboração própria a partir das planilhas do estudo (abas Metodologia e Dados), de CEDCA (2023) e de Paraná (2024a).

A etapa prévia antecedeu o índice. A Deliberação nº 60/2023 do CEDCA/PR aprovou R$ 70,95 milhões do Fundo Estadual para a Infância e Adolescência para 43 creches, uma em cada um de 43 municípios selecionados por um índice de prioridade do Ipardes, construído a partir do déficit de vagas, do crescimento da população de zero a três anos e do número de crianças com perfil do Bolsa Família (CEDCA, 2023). Por isso, a regra descrita a seguir distribui as 257 unidades restantes e desconta, em cada município, a unidade já recebida.

Nos municípios grandes, o cálculo parte de uma cota por faixa de porte, proporcional à parcela da faixa na população-alvo do estado. O total a repartir é reduzido pelo fator 1 + m, em que m é o PCM médio ponderado pela população-alvo (0,503), porque no passo seguinte a cota de cada município é ampliada pelo seu próprio PCM; sem a redução, a soma ultrapassaria o total disponível:

EQ: C_p = s_p \cdot \frac{N_r}{1 + m} | 6

em que C_p é a cota da faixa p, s_p é a parcela da faixa na população-alvo e N_r = 257 é o número de unidades restantes após a etapa prévia. A cota da faixa é então repartida entre seus municípios na proporção da população-alvo, e o índice entra como multiplicador:

EQ: K_i = \frac{a_i}{A_p} \cdot C_p \cdot (1 + PCM_i) - E_i | 7

em que K_i é o número de unidades do município i, a_i é sua população-alvo, A_p é a população-alvo da faixa e E_i é a unidade eventualmente recebida na etapa prévia. Um município com PCM de 0,50 recebe 50% a mais do que receberia pela população. Curitiba ilustra o cálculo: a cota de sua faixa, que ocupa sozinha, é de 23,1 unidades; multiplicada por 1 + 0,286, seu PCM, chega a 29,7.

Como K_i é fracionário, a conversão em unidades inteiras segue o método do maior resto, como implementado na planilha: a parte inteira é atribuída de imediato e as unidades restantes vão, uma a uma, aos municípios com as maiores frações (BALINSKI; YOUNG, 2001). Curitiba passa de 29,7 a 30 unidades. Sobre esse resultado incidem os tetos por município, de 10, 8, 7, 4 e 2 unidades nas cinco faixas, em ordem decrescente de porte, que reduziram o total dos 30 municípios grandes de 142 para 100 unidades e o de Curitiba, de 30 para 10.

Nos municípios pequenos não há cálculo proporcional. Em cada uma das três faixas inferiores, os municípios são ordenados pelo PCM, excluídos os da etapa prévia, e os primeiros da fila recebem uma unidade: 27 dos 62 municípios de 20 a 70 mil habitantes, 100 dos 205 de 5 a 20 mil e 30 dos 102 com até 5 mil, o que soma 157 unidades. O PCM do último contemplado é a linha de corte da faixa; abaixo dela, os demais permanecem na ordem do índice, como suplentes.

Os três blocos somam 300 unidades, em 224 municípios, na versão de março de 2024. A versão apresentada ao conselho em maio manteve o índice e as cotas e reduziu os tetos dos municípios grandes, o que deslocou 38 unidades para as faixas inferiores e elevou o alcance para 258 municípios. A Resolução SEDEF nº 219/2024 acrescentou uma unidade a três municípios e publicou 303 unidades em 261 municípios.
