"""Diagramas editáveis para o DOCX, construídos como tabelas do Word (caixas = células sombreadas; setas = células com símbolo).
Cada diagrama é uma lista de linhas; cada linha é uma lista de células: None (vazia), str (seta/texto solto) ou
dict(t=texto, fc=cor de fundo hex, tc=cor do texto, w=largura em cm, b=negrito, span=colunas mescladas, ec=cor da borda)."""
FE="#C24C12"; FD="#0171C1"; FS="#307E3E"; PCM="#54278F"; G1="#969696"; G2="#595959"; G3="#1F1F1F"; CL="#E6E6E6"; BR="#FFFFFF"; AC="#B2182B"
def cx(t,fc=BR,tc="#000000",w=None,b=False,span=1,ec="#7F7F7F",fs=8): return dict(t=t,fc=fc,tc=tc,w=w,b=b,span=span,ec=ec,fs=fs)
W16=16.0
def mecanismo():
    """Dados -> PCM -> faixas e parâmetros -> deliberação -> lista -> alocação (cadeia do mecanismo)."""
    w=2.35; a=0.38
    r1=[cx("Dados municipais\nnove indicadores oficiais (Inep, IBGE, Datasus, MS, Ipardes)",CL,w=w),"→",cx("PCM\nnormalização mínimo-máximo, três pilares, pesos 2:1:2",PCM,"#FFFFFF",w=w,b=True),"→",cx("Faixas e parâmetros\noito portes, cotas, tetos, maior resto",G2,"#FFFFFF",w=w),"→",cx("Deliberação\nCEDCA aprova estudo e ranqueamento (Del. 25/2024)",FS,"#FFFFFF",w=w),"→",cx("Lista de municípios\nRes. SEDEF 219/2024: 303 unidades, 261 municípios",FD,"#FFFFFF",w=w),"→",cx("Alocação do investimento\nadesão, habilitação, repasse fundo a fundo, obra",G3,"#FFFFFF",w=w)]
    r2=[cx("Auditoria das planilhas: fórmulas e fontes reproduzidas",BR,w=w,fs=7),None,cx("Sensibilidade: pesos e normalização (ρ ≥ 0,93)",BR,w=w,fs=7),None,cx("Regras reproduzidas: 157/157 nos portes pequenos; 28/30 nos grandes",BR,w=w,fs=7),None,cx("Margem de decisão: tetos menores e 3 municípios acrescidos",BR,w=w,fs=7),None,cx("Fila pública: o próximo ranqueado substitui o desistente",BR,w=w,fs=7),None,cx("Resultado analisado: quem recebe e quantas unidades (não os efeitos sociais)",BR,w=w,fs=7)]
    return dict(widths=[w,a,w,a,w,a,w,a,w,a,w],rows=[r1,r2])
def institucional():
    w=5.0; a=0.5
    return dict(widths=[w,a,w,a,w],rows=[
        [cx("Casa Civil\nEstudo técnico: PCM, portes e regra de alocação",G2,"#FFFFFF",b=True),"→",cx("CEDCA/PR (conselho paritário)\nAporte do FIA e aprovação do estudo (Deliberações 60/2023 e 25/2024)",FS,"#FFFFFF",b=True),"←",cx("Fontes: Tesouro do Estado, FIA/PR e Assembleia Legislativa (R$ 100 milhões em 2024)",CL)],
        ["↑",None,"↓",None,"↓"],
        [cx("Ipardes\nEstudo prévio (43 unidades) e bases de dados",CL),None,cx("SEDEF (gestora do FIA/PR)\nResoluções 212 e 219/2024: critério, lista, habilitação e repasse",FD,"#FFFFFF",b=True),"→",cx("Paranacidade / SECID\nProjeto padrão, análise, autorização para licitar e vistorias",FE,"#FFFFFF",b=True)],
        [None,None,"↓",None,"↓"],
        [cx("Municípios (399): adesão, terreno, projeto de implantação, licitação, obra e prestação de contas; conselhos municipais (CMDCA) e fundos municipais (FMDCA)",BR,span=5,ec="#000000")],
        [None,None,"↓",None,None],
        [cx("Controle: TCE-PR, MP-PR, Defensoria Pública, CEDCA e CMDCA",CL,span=2),None,cx("Resultado: 303 unidades em 261 municípios (2024); segunda etapa em 2025",CL,span=2)],
    ])
def financeiro():
    w=3.6; a=0.45
    return dict(widths=[w,a,w,a,w,a,w],rows=[
        [cx("Origem: Tesouro do Estado (aporte em complementação ao FIA), saldo livre do FIA/PR e devolução de duodécimo da Assembleia",CL,span=7)],
        [None,None,None,"↓",None,None,None],
        [cx("FIA/PR\nfundo gerido pela SEDEF, prioridades do CEDCA",FS,"#FFFFFF",b=True),"→",cx("Termo de Adesão e Resolução de Habilitação\nsem convênio e sem operação de crédito",FD,"#FFFFFF",b=True),"→",cx("Fundo Municipal (FMDCA)\nconta específica; cinco parcelas: 10%, 20% e três iguais após 40%, 70% e 100% da obra",PCM,"#FFFFFF",b=True),"→",cx("Licitação e obra pelo município\nprojeto padrão; vistorias do Paranacidade; teto de R$ 1,30 mi (2024) e R$ 1,99 mi (2025)",G2,"#FFFFFF",b=True)],
        [None,None,None,None,None,None,"↓"],
        [cx("Encargos municipais: terreno de 1.200 m², custo excedente ao teto e aditivos, conclusão em 36 meses (restituição em caso de descumprimento), custeio posterior com Fundeb e receitas próprias",BR,span=7,ec="#000000")],
    ])
def pcm_arquitetura():
    w=3.7; a=0.45
    return dict(widths=[w,a,w,a,w,a,w],rows=[
        [cx("Fator educacional (FE)\noferta existente",FE,"#FFFFFF",b=True),None,cx("Fator demográfico (FD)\npressão da demanda",FD,"#FFFFFF",b=True),None,cx("Fator socioeconômico (FS)\nvulnerabilidade",FS,"#FFFFFF",b=True),None,cx("Regras comuns",CL,b=True)],
        [cx("2 × matrículas em creche / pop. 0 a 4 (inverso)\n1 × matrículas pré-escola e fundamental / pop. 5 a 14 (inverso)\n1 × oferta privada / oferta total (inverso)",BR,fs=7),None,cx("1 × mortalidade infantil\n1 × pop. 0 a 4 / pop. total\n1 × taxa de natalidade",BR,fs=7),None,cx("1 × baixo peso para a idade (Sisvan)\n1 × crianças no CadÚnico / pop. 0 a 9\n1 × IPDM renda, emprego e produção (inverso)",BR,fs=7),None,cx("cada indicador em 0 a 100 (mínimo-máximo); sentido inverso quando o valor maior indica menor necessidade; cada fator reescalonado em 0 a 100",BR,fs=7)],
        ["↓",None,"↓",None,"↓",None,None],
        [cx("peso 2",FE,"#FFFFFF",b=True),None,cx("peso 1",FD,"#FFFFFF",b=True),None,cx("peso 2",FS,"#FFFFFF",b=True),None,None],
        [cx("PCM = (2·FE + FD + 2·FS) / 5 / 100, entre 0 e 1",PCM,"#FFFFFF",span=5,b=True),None,cx("média ponderada dos fatores; agregação aditiva (compensatória)",BR,fs=7)],
    ])
def perguntas():
    wq=5.2; wd=10.3; a=0.5
    rows=[]
    for tag,perg,dec,cor in [
        ("1. Necessidade","O que significa um município precisar de creche?","Três pilares: oferta educacional existente, pressão demográfica e vulnerabilidade socioeconômica",FE),
        ("2. Dados","Há dado oficial e recente para os 399 municípios?","Nove indicadores de bases públicas (Censo Escolar, Censo 2022, Datasus, Sisvan, CadÚnico, IPDM), unidos pelo código do IBGE",FD),
        ("3. Comparabilidade","Como pôr indicadores de unidades distintas na mesma escala?","Normalização mínimo-máximo de 0 a 100; cobertura, oferta privada e renda em sentido inverso",FD),
        ("4. Ponderação","Quanto pesa cada indicador e cada pilar?","Cobertura de creche com peso 2 no pilar educacional; pilares educacional e socioeconômico com peso 2 e demográfico com peso 1",FS),
        ("5. Escala","Como comparar a capital com um município de 3 mil habitantes?","Oito faixas de porte; cota de cada faixa proporcional à população-alvo; regimes distintos para portes grandes e pequenos",G1),
        ("6. Conversão","Como transformar um índice contínuo em unidades inteiras?","Cota do município × (1 + PCM); parte inteira; maior resto; tetos por município nos portes grandes e uma unidade por município nos pequenos",PCM),
        ("7. Validação","Quem aprova o critério e como ele vira lista?","Deliberação do CEDCA; Resolução SEDEF com critério e lista; o próximo ranqueado substitui quem não adere",G3),
        ("8. Limites","O que o índice não capta?","Terreno, capacidade de licitar e fila local; margem de decisão delimitada e documentada",AC)]:
        rows.append([cx(tag+"\n"+perg,cor,"#FFFFFF"),"→",cx(dec,BR,ec=cor)])
    return dict(widths=[wq,a,wd],rows=rows)
def aplicacao():
    w=7.6; a=0.8
    return dict(widths=[w,a,w],rows=[
        [cx("Parâmetros: 257 unidades a distribuir (300 menos 43 da etapa prévia), oito portes, população-alvo por porte, PCM por município, tetos e cotas por faixa",CL,span=3)],
        [None,"↓",None],
        [cx("1. Cota do porte: parcela na população-alvo × 257 / (1 + PCM médio ponderado)",BR,ec=G2),"→",cx("2. Cota do município: parcela do município na população-alvo do porte × cota do porte",BR,ec=G2)],
        [None,None,"↓"],
        [cx("3. Ajuste pelo indicador: K = cota do município × (1 + PCM) − unidades da etapa prévia",PCM,"#FFFFFF",span=3,b=True)],
        [None,"↓",None],
        [cx("4. Parte inteira de K atribuída de imediato (90 unidades)",BR,ec=G2),"→",cx("5. Maior resto: as 111 unidades restantes vão às maiores frações, uma por município",BR,ec=G2)],
        [None,"↓",None],
        [cx("6a. Portes grandes (30 municípios): teto por município de 10, 8, 7, 4 e 2; de 142 para 100 unidades",G3,"#FFFFFF"),None,cx("6b. Portes pequenos (369 municípios): uma unidade aos 27, 100 e 30 municípios de maior PCM de cada faixa (157 unidades)",G3,"#FFFFFF")],
        [None,"↓",None],
        [cx("Resultado: 43 + 100 + 157 = 300 unidades; tetos menores em maio de 2024 (300 em 258 municípios); Resolução 219/2024: 303 em 261",BR,span=3,ec="#000000",b=True)],
    ])
def blocos():
    w=5.2; g=0.2
    return dict(widths=[w,g,w,g,w],rows=[
        [cx("Bloco 1. Etapa prévia\n43 unidades",FS,"#FFFFFF",b=True),None,cx("Bloco 2. Portes grandes\n30 municípios, 100 unidades",PCM,"#FFFFFF",b=True),None,cx("Bloco 3. Portes pequenos\n369 municípios, 157 unidades",G2,"#FFFFFF",b=True)],
        [cx("Deliberação CEDCA 60/2023: índice de prioridade do Ipardes (déficit de vagas, crescimento da população de 0 a 3 anos, crianças com perfil Bolsa Família)",BR,ec=FS),None,cx("1. Cota da faixa de porte: parcela na população-alvo × 257 / (1 + 0,503)",BR,ec=PCM),None,cx("1. Ordenação pelo PCM dentro de cada faixa, excluídos os municípios da etapa prévia",BR,ec=G2)],
        [cx("Uma unidade em cada um dos 43 municípios",BR,ec=FS),None,cx("2. Cota do município: parcela na população-alvo da faixa × cota da faixa × (1 + PCM), menos a unidade da etapa prévia",BR,ec=PCM),None,cx("2. Cotas por faixa: 27 de 62 municípios (20 a 70 mil hab.), 100 de 205 (5 a 20 mil) e 30 de 102 (até 5 mil)",BR,ec=G2)],
        [cx("Descontada no cálculo dos blocos 2 e 3",BR,ec=FS),None,cx("3. Arredondamento: parte inteira e, depois, maior resto",BR,ec=PCM),None,cx("3. Uma unidade por município contemplado; os demais ficam como suplentes, na ordem do índice",BR,ec=G2)],
        [None,None,cx("4. Tetos por município: 10, 8, 7, 4 e 2 unidades (de 142 para 100)",BR,ec=PCM),None,None],
        [cx("Resultado: 43 + 100 + 157 = 300 unidades em 224 municípios (março de 2024). Tetos menores em maio de 2024: 300 unidades em 258 municípios. Resolução SEDEF 219/2024: 303 unidades em 261 municípios",CL,span=5,b=True)],
    ])
DIAGRAMAS={"blocos":blocos,"mecanismo":mecanismo,"institucional":institucional,"financeiro":financeiro,"pcm":pcm_arquitetura,"perguntas":perguntas,"aplicacao":aplicacao}
