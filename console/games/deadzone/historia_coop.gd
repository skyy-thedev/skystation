extends "res://historia.gd"
## Histórias do coop: cada dupla vive outro lado da mesma semana em Sumaré.
##   coop_cr — "O Preço do Ar" (Corvo e Rocha): uma semana antes do contrato. Os filtros de ar do bunker
##             estão acabando; o comandante sai pela primeira vez em um ano e descobre o preço que o Rio cobra.
##   coop_in — "Fuga" (Iara e Nina): a Iara ouve o rádio, entende que vai ser vendida e foge com a Nina,
##             uma catadora que entrou no bunker para roubar comida. O destino delas é a Serra, não o Rio.
## Os mesmos lugares da cidade (bunker, mercado, delegacia, posto, garagem, pedágio), outras conversas e escolhas.

const ETAPAS_CR := [
	{"obj": "Peguem o equipamento no arsenal do bunker (segure ✕)", "alvo": "armario_bunker"},
	{"obj": "Saiam do bunker (agachados ninguém ouve os passos: R3)", "alvo": "saida_bunker"},
	{"obj": "Achem filtros de ar no mercado: revirem 2 prateleiras", "alvo": "mercado"},
	{"obj": "O rádio da delegacia está chamando o bunker", "alvo": "radio"},
	{"obj": "Voltem para o bunker com os filtros", "alvo": "saida_bunker"},
]
const ETAPAS_IN := [
	{"obj": "Saiam do bunker sem chamar atenção (agachem: R3)", "alvo": "saida_bunker"},
	{"obj": "Juntem comida e remédio para a estrada: revirem 3 lugares", "alvo": ""},
	{"obj": "Na delegacia, escutem o rádio: quem está procurando a Iara?", "alvo": "radio"},
	{"obj": "Encham um galão: bomba do posto ou tanque de carro quebrado", "alvo": "posto"},
	{"obj": "Peguem o carro que a Nina conhece (farol piscando) e abasteçam", "alvo": "carro_bom"},
	{"obj": "Dirijam até o pedágio da Anhanguera, ao norte", "alvo": "ponte"},
]

var prateleiras := 0
var juntou := 0


func _ready() -> void:
	etapas = ETAPAS_CR if modo == "coop_cr" else ETAPAS_IN


func cr() -> bool:
	return modo == "coop_cr"


func alvo() -> Variant:
	if concluido:
		return null
	var a: String = etapas[etapa]["alvo"]
	if a == "":
		return null
	if a == "carro_bom":
		var c = main.locais.get("carro_bom")
		return c.global_position if c and is_instance_valid(c) else null      # a Nina sabe qual pega
	if a == "posto":
		return main.locais.get("posto")
	return main.locais.get(a)


func estado_salvo() -> Dictionary:
	var d := super.estado_salvo()
	d["prateleiras"] = prateleiras
	d["juntou"] = juntou
	return d


func restaurar(d: Dictionary) -> void:
	super.restaurar(d)
	prateleiras = int(d.get("prateleiras", 0))
	juntou = int(d.get("juntou", 0))


func tiao_pode_chamar() -> bool:
	return not cr() and not concluido and etapa >= 4


func entardecer() -> void:
	if not concluido:
		secundario = "Noite chegando: barricadem uma casa e durmam na cama (salva o jogo)"


# ---------------------------------------------------------------- começo

func iniciar() -> void:
	var abertura := [
		_q("c1_abertura", 0, {"quem": "", "txt": "2032. Angra dos Reis. O reator experimental falhou numa terça-feira à tarde."}),
		_q("c1_abertura", 1, {"quem": "", "txt": "A nuvem verde chegou a São Paulo antes do jornal da noite. Ninguém sabia o que era. Todo mundo filmou."}),
		_q("c1_abertura", 2, {"quem": "", "txt": "Quem respirou, mudou."}),
		_q("c1_abertura", 3, {"quem": "", "txt": "Quem chegou a tempo num bunker fechou a porta. E não abriu mais para ninguém."}),
	]
	if cr():
		dizer(abertura + [
			_q("c1_contrato", 0, {"quem": "", "txt": "Um ano depois. Uma semana antes do contrato. Bunker de Sumaré."}),
			_q("c1_contrato", 0, {"quem": "Rocha", "txt": "Os filtros de ar morrem em seis dias, Corvo. Depois disso, quem respira aqui embaixo respira Angra."}),
			_q("c1_contrato", 0, {"quem": "Corvo", "txt": "Seis dias. Quarenta e duas pessoas. E você me chamou porque…"}),
			{"quem": "Rocha", "cara": "duvida", "txt": "Porque eu vou junto. Faz um ano que eu não piso lá em cima."},
			{"quem": "Corvo", "cara": "sorriso", "txt": "Um comandante com barriga de bunker e um mercenário fumante. Os zumbis vão rir da gente."},
			{"quem": "Rocha", "cara": "rindo", "txt": "Eles que riam. Arsenal, depois mercado. Filtro de geladeira industrial serve."},
			_q("c1_contrato", 1, {"quem": "Iara", "txt": "Traz chocolate, Rocha! E não morre, que você me deve um baralho!"}),
			{"quem": "Rocha", "cara": "culpado", "txt": "(baixinho) Ela não sabe que é por causa dela que o Rio responde os nossos rádios."},
			{"quem": "Corvo", "cara": "neutro", "txt": "Não é da minha conta. Ainda."},
		])
	else:
		dizer(abertura + [
			_q("c1_contrato", 1, {"quem": "", "txt": "Um ano depois. Uma semana antes do contrato. Bunker de Sumaré, três da manhã."}),
			_q("c1_contrato", 1, {"quem": "Iara", "txt": "Psiu! Você aí, de cabelo rosa. Você não é daqui."}),
			{"quem": "Nina", "cara": "rindo", "txt": "E você tá presa num aquário, princesa. Cada um com seu problema."},
			{"quem": "Iara", "cara": "brava", "txt": "Eu ouvi o Rocha no rádio. Vão me levar pro Rio. Pra me abrir. Eu sou imune, sabia?"},
			{"quem": "Nina", "cara": "medo", "txt": "…Imune tipo, mordida não pega?"},
			{"quem": "Iara", "cara": "determinada", "txt": "Três mordidas. Nada. Me tira daqui que eu te mostro a Serra. Minha avó conhecia as trilhas."},
			{"quem": "Nina", "cara": "rindo", "txt": "Fechou. Mas regra da rua: quem faz barulho morre primeiro. Agacha e me segue. O Rocha não dorme cedo."},
		])


# ---------------------------------------------------------------- eventos

func evento(nome: String, dados: Dictionary) -> void:
	if concluido:
		return
	if cr():
		_evento_cr(nome, dados)
	else:
		_evento_in(nome, dados)
	if nome == "dormiu" and secundario != "":
		secundario = ""
		escolhas["acampou"] = true


func _no(chave: String, o: Variant) -> bool:
	## o objeto está dentro do prédio desse lugar? (locais guarda o centro do mercado)
	if o == null or not main.locais.has(chave):
		return false
	for p in main.predios:
		if p["r"].has_point(main.locais[chave]) and p["r"].grow(8).has_point(o.global_position):
			return true
	return false


func _evento_cr(nome: String, dados: Dictionary) -> void:
	match nome:
		"revirou":
			revirados += 1
			if etapa == 0 and dados.get("tipo", "") == "arsenal":
				_proxima()
				dizer([
					{"quem": "Corvo", "txt": "Espingarda pro senhor, taco pra garantir. E cigarro, que ninguém é de ferro."},
					{"quem": "Rocha", "cara": "aviso", "txt": "Isso mata, sabia?"},
					{"quem": "Corvo", "cara": "sorriso", "txt": "Tudo mata. Eu só escolho o quê."},
				])
			elif etapa == 2 and dados.get("tipo", "") == "prateleira" and _no("mercado", dados.get("obj")):
				prateleiras += 1
				if prateleiras >= 2:
					_proxima()
					dizer([
						{"quem": "Rocha", "cara": "sorriso", "txt": "Achei! Dois cartuchos de filtro. Dá pra um mês."},
						{"quem": "Corvo", "cara": "neutro", "txt": "Um mês. E depois?"},
						{"quem": "Rocha", "cara": "culpado", "txt": "Depois, o Rio. A doutora prometeu filtros novos pra vida toda."},
						{"quem": "Corvo", "cara": "irritado", "txt": "Prometeu em troca de quê?"},
						{"quem": "Rocha", "cara": "culpado", "txt": "…O rádio da delegacia está chamando. Vamos ouvir."},
					])
				else:
					main.aviso("Rocha: \"Esse cheira a mofo. Tem que ter mais.\"", Color("c9b48a"))


func checar_saida() -> void:
	## saiu do bunker / voltou para o bunker
	if concluido or not main.locais.has("bunker"):
		return
	var r: Rect2 = main.predios[main.locais["bunker"]]["r"]
	var dentro := r.grow(-10).has_point(main.jogadores[0].global_position)
	if cr():
		if etapa == 1 and not dentro:
			_proxima()
			dizer([
				{"quem": "Rocha", "cara": "duvida", "txt": "…O céu é desse jeito agora?"},
				{"quem": "Corvo", "cara": "neutro", "txt": "Verde nas bordas, laranja no meio. Bem-vindo. Agacha quando eu agachar: eles ouvem passo."},
				{"quem": "Rocha", "cara": "severo", "txt": "Eu comandei quarenta e duas pessoas por um ano. Sei andar quieto."},
				{"quem": "Corvo", "cara": "sorriso", "txt": "Então pisa como quem deve dinheiro."},
			])
		elif etapa == 4 and dentro:
			_final_cr()
	else:
		if etapa == 0 and not dentro:
			_proxima()
			dizer([
				{"quem": "Iara", "cara": "rindo", "txt": "O céu! Olha o céu, Nina!"},
				{"quem": "Nina", "cara": "rindo", "txt": "Tá, tá, é lindo, é verde, é radioativo. Agora: comida, remédio e um carro. Nessa ordem."},
				{"quem": "Iara", "cara": "deboche", "txt": "Os torrados gemem igual panela de pressão. Vou chamar de Queimados."},
				{"quem": "Nina", "cara": "brava", "txt": "Pode chamar do que quiser, só não chama eles pra cá."},
			])


func _evento_in(nome: String, dados: Dictionary) -> void:
	match nome:
		"revirou":
			revirados += 1
			if etapa == 1:
				juntou += 1
				if juntou >= 3:
					_proxima()
					dizer([
						{"quem": "Nina", "cara": "rindo", "txt": "Já dá pra três dias. Sabe o que vale mais que comida? Informação."},
						{"quem": "Nina", "cara": "rindo", "txt": "O rádio da delegacia pega o Rio. Bora ouvir quem tá atrás de você."},
					])
				else:
					main.aviso("Suprimentos: %d de 3 lugares" % juntou, Color("7ff0c4"))
		"gasolina":
			if etapa == 3:
				_proxima()
				dizer([{"quem": "Nina", "cara": "rindo", "txt": "Dez litros. Eu sei qual carro pega: deixei marcado no teu mapa."}])
		"abasteceu":
			if etapa == 4:
				_proxima()
				dizer([
					{"quem": "Iara", "cara": "rindo", "txt": "Você sabe dirigir?!"},
					{"quem": "Nina", "cara": "rindo", "txt": "Sei roubar carro. Dirigir é a parte fácil."},
				])


# ---------------------------------------------------------------- rádio

func radio_ativo() -> bool:
	return not concluido and ((cr() and etapa == 3) or (not cr() and etapa == 2))


func rotulo_radio() -> String:
	return "Usar o rádio" if radio_ativo() else "Rádio (só chiado)"


func usar_radio() -> void:
	if not radio_ativo():
		main.aviso("Só chiado…", Color(1, 1, 1, 0.6))
		return
	if cr():
		dizer([
			{"quem": "Rádio", "txt": "Chhh… Bunker Sumaré, aqui é Helena Vasconcelos, Bunker Rio. Comandante Rocha, o senhor me ouve, meu bem?"},
			{"quem": "Rocha", "cara": "severo", "txt": "Na escuta, doutora."},
			{"quem": "Helena", "cara": "calma", "txt": "A proposta continua de pé: filtros novos para o seu bunker inteiro, por dez anos. Escolta paga. E vocês mandam a menina."},
			{"quem": "Corvo", "cara": "irritado", "txt": "Que menina?"},
			{"quem": "Helena", "cara": "fria", "txt": "O comandante sabe. Ela é imune, Corvo. É a chance de uma vacina. Uma vida por quarenta e duas. Por milhões, talvez."},
			{"quem": "Rocha", "cara": "culpado", "txt": "…", "opcoes": [
				{"txt": "Rocha: \"Aceito. Mande a escolta.\"", "set": {"acordo": "aceitou"}, "seguir": [
					{"quem": "Helena", "cara": "calma", "txt": "Sabia que o senhor era razoável, meu bem. E o mercenário serve de escolta."},
					{"quem": "Corvo", "cara": "neutro", "txt": "O mercenário cobra caro."},
					{"quem": "Helena", "cara": "fria", "txt": "O mercenário vai ser bem pago. Câmbio."},
					{"quem": "Rocha", "cara": "culpado", "txt": "Não conta pra ela, Corvo. Por favor."}]},
				{"txt": "Rocha: \"Ela não é moeda de troca.\"", "set": {"acordo": "recusou"}, "seguir": [
					{"quem": "Helena", "cara": "fria", "txt": "Então o seu bunker tem seis dias, comandante. Quando mudar de ideia, o rádio está ligado."},
					{"quem": "Rocha", "cara": "bravo", "txt": "Seis dias e dois filtros. A gente se vira."},
					{"quem": "Corvo", "cara": "sorriso", "txt": "Gostei do senhor, comandante. Pela primeira vez."}]},
			]},
		], _proxima, true)
	else:
		dizer([
			{"quem": "Rádio", "txt": "Chhh… Atenção, sobreviventes. Aqui é a Dra. Helena Vasconcelos, Bunker Rio."},
			{"quem": "Helena", "cara": "calma", "txt": "Pagamos cinquenta litros de água limpa por notícia de uma menina de quinze anos, cabelo preto, trança. Atende por Iara. Ela está doente e precisa de tratamento, meu bem."},
			{"quem": "Iara", "cara": "chorando", "txt": "Doente… eu não tô doente."},
			{"quem": "Tião", "cara": "locutor", "txt": "Aqui é o Tião, na Rádio Pedágio AM! Cinquenta litros, meu povo! Se a menininha passar no meu pedágio, o Tião fica rico!"},
			{"quem": "Nina", "cara": "brava", "txt": "Ótimo. Agora a estrada inteira sabe."},
			{"quem": "Iara", "cara": "determinada", "txt": "Então a gente passa pelo pedágio do jeito que ninguém espera."},
		], _proxima, true)


# ---------------------------------------------------------------- gente

func tem_conversa(id: String) -> bool:
	match id:
		"tiao":
			return not cr()
		"rocha":
			return not cr() and not falou.has("rocha_viu")
		"nina":
			return false
	return false


func falar(id: String) -> void:
	match id:
		"rocha":
			if not cr():
				falou["rocha_viu"] = true
				escolhas["rocha_viu"] = true
				dizer([
					{"quem": "Rocha", "cara": "grito", "txt": "IARA?! Volta pro quarto agora!"},
					{"quem": "Iara", "cara": "brava", "txt": "Você ia me vender, Rocha!"},
					{"quem": "Rocha", "cara": "culpado", "txt": "…Pelos outros quarenta e dois."},
					{"quem": "Nina", "cara": "brava", "txt": "Bora, princesa! Ele não vai atirar numa menina."},
					{"quem": "Rocha", "cara": "culpado", "txt": "(e não atira)"},
				])
		"tiao":
			_tiao_in()


func _tiao_in() -> void:
	if etapa < 5 or not _de_carro_perto():
		dizer([{"quem": "Tião", "cara": "locutor", "txt": "Freguesa sem carro é freguesa a pé! Volta com carro, que o Tião abre a cancela… pelo preço certo."}])
		return
	var saida := [
		_q("c1_pedagio", 2, {"quem": "", "txt": "A Anhanguera segue para o norte. A Nina vira à direita, para a Serra."}),
		{"quem": "Nina", "cara": "rindo", "txt": "Pro Rio não. Pras trilhas da tua avó."},
		{"quem": "Iara", "cara": "rindo", "txt": "Se aparecer um menino de uma perna só assobiando…"},
		{"quem": "Nina", "cara": "rindo", "txt": "…a gente segue. Não pergunta. Segue."},
	]
	dizer([
		_q("c1_pedagio", 0, {"quem": "Tião", "txt": "Atenção, meu povo! Olha quem chegou no pedágio do Tião: a menininha dos cinquenta litros!"}),
		{"quem": "Tião", "cara": "ganancia", "txt": "E uma acompanhante de cabelo rosa. Desce do carro, freguesa."},
		{"quem": "Nina", "cara": "brava", "txt": "Tião, seu velho pão-duro. Lembra de mim? A que consertou o teu rádio."},
		{"quem": "Tião", "cara": "assustado", "txt": "Nina?! …Lembro. Mas cinquenta litros é cinquenta litros."},
		{"quem": "Iara", "cara": "medo", "txt": "…", "opcoes": [
			{"txt": "Nina: dar tudo o que tem na mochila", "set": {"ponte": "pagou"}, "faz": _pagar_tiao, "seguir": [
				{"quem": "Tião", "cara": "ganancia", "txt": "Negócio é negócio! Passa, passa, que o Tião não viu nada."}] + saida},
			{"txt": "Iara: mostrar a mordida no braço", "set": {"ponte": "mordida"}, "seguir": [
				{"quem": "Iara", "cara": "determinada", "txt": "Olha meu braço, Tião. Mordida. Ainda quer me levar pro teu barraco?"},
				{"quem": "Tião", "cara": "assustado", "txt": "MORDIDA?! Some daqui! Abre a cancela, abre, abre!"},
				{"quem": "Nina", "cara": "rindo", "txt": "Ela é imune, seu… deixa pra lá."}] + saida},
			{"txt": "Nina: acelerar e furar a cancela", "set": {"ponte": "furou"}, "seguir": [
				{"quem": "", "txt": "CRASH! A cancela voa por cima do carro."},
				{"quem": "Tião", "cara": "bravo", "txt": "MEU PEDÁGIO! A doutora vai saber disso, ouviu?!"}] + saida},
		]},
	], main.fim_capitulo)


func _pagar_tiao() -> void:
	for j in main.jogadores:
		for k in ["enlatado", "salgadinho", "agua", "bandagem", "pilhas"]:
			j.mochila.erase(k)


func _final_cr() -> void:
	var fim := []
	if escolhas.get("acordo", "") == "aceitou":
		fim = [
			{"quem": "Iara", "cara": "rindo", "txt": "Cadê meu chocolate?"},
			{"quem": "Rocha", "cara": "culpado", "txt": "…Não tinha, menina. Amanhã eu procuro."},
			{"quem": "", "txt": "Uma semana depois, o Comandante Rocha contratou o Corvo para levar uma carga ao Rio. O Corvo aceitou sem perguntar o que era. Ele já sabia."},
		]
	else:
		fim = [
			{"quem": "Iara", "cara": "rindo", "txt": "Cadê meu chocolate?"},
			{"quem": "Rocha", "cara": "sorriso", "txt": "Não tinha. Mas trouxe um mês de ar, serve?"},
			{"quem": "", "txt": "Os filtros duraram um mês. Na quarta semana, o rádio chamou de novo. Dessa vez, o Rocha atendeu sozinho."},
		]
	dizer(fim, main.fim_capitulo)


# ---------------------------------------------------------------- fim

func capitulo() -> Dictionary:
	if cr():
		return {"titulo": "COOP CONCLUÍDO: O PREÇO DO AR", "sub": "Corvo e Rocha · uma semana antes da carga", "cor": "azul",
			"fim": ["Agora você sabe por que o Rocha contratou o Corvo.", "Jogue a história solo para ver o que acontece com a carga."]}
	return {"titulo": "COOP CONCLUÍDO: FUGA", "sub": "Iara e Nina · a noite em que a carga fugiu", "cor": "azul",
		"fim": ["Duas garotas, um carro roubado e as trilhas da Serra.", "Esta é a outra estrada. Na história solo, a Iara não fugiu."]}


func resumo() -> Array:
	var r := []
	if cr():
		match escolhas.get("acordo", ""):
			"aceitou": r.append("Rocha aceitou trocar a Iara pelos filtros do Rio. O Corvo ouviu tudo.")
			"recusou": r.append("Rocha recusou o acordo. Por enquanto.")
	else:
		if escolhas.get("rocha_viu", false):
			r.append("O Rocha viu a Iara fugir. E deixou.")
		else:
			r.append("Ninguém no bunker viu vocês saírem.")
		match escolhas.get("ponte", ""):
			"pagou": r.append("Pedágio: a Nina deu tudo o que tinha ao Tião.")
			"mordida": r.append("Pedágio: a Iara mostrou a mordida. O Tião fugiu de medo.")
			"furou": r.append("Pedágio: vocês furaram a cancela. O Tião vai contar à Dra. Helena.")
	if escolhas.get("acampou", false):
		r.append("Vocês passaram uma noite barricadas, ouvindo os mortos lá fora.")
	return r


func vendeu() -> bool:
	return false
