extends Node
## A história. 2032: um acidente nuclear em Angra dos Reis transformou quem respirou a nuvem em zumbi.
## Sobrou quem estava longe demais ou debaixo da terra, nos bunkers.
## O Corvo é um mercenário contratado para levar uma "carga" do Bunker de Sumaré até o Bunker do Rio de Janeiro.
## A carga é a Iara — e ela é imune. No Rio, um hospital quer estudá-la. A estrada vai mudar os dois.
##
## Capítulo 1 — "A Carga" (Sumaré): sair do bunker, achar a rota, descobrir o segredo da Iara, chegar ao pedágio.
## (os próximos capítulos estão descritos em claude/zona-morta.md (bíblia) e no doc "DEADZONE — Direção de arte": São Paulo, a Serra, o Rio, e depois o norte)

var main: Node2D
var etapa := 0
var escolhas := {}
var revirados := 0
var conversa: Array = []          # falas na tela agora
var linha := 0
var opcao := 0
var ao_fim: Callable
var falou := {}
var modo := "historia"            # "historia" ou "sobrevivencia" (sem objetivos)
var concluido := false
var secundario := ""
var no_radio := false             # chiado do rádio tocando durante a conversa
var revelado := false             # já sabem que a Iara é imune

const ETAPAS := [
	{"obj": "Fale com o Comandante Rocha", "alvo": "rocha"},
	{"obj": "Pegue o seu equipamento no armário do bunker (segure ✕)", "alvo": "armario_bunker"},
	{"obj": "Saia do bunker com a carga", "alvo": "saida_bunker"},
	{"obj": "Vá até a delegacia: o rádio de lá alcança o Bunker do Rio", "alvo": "radio"},
	{"obj": "Encha um galão: bomba do posto ou tanque de carro quebrado", "alvo": "posto"},
	{"obj": "Ache um carro que funcione (farol piscando) e abasteça", "alvo": "carro_bom"},
	{"obj": "Dirija até o pedágio da Anhanguera, ao norte", "alvo": "ponte"},
	{"obj": "Fale com o homem do pedágio", "alvo": "ponte"},
]


func coop() -> bool:
	return main.jogadores.size() > 1


func objetivo() -> String:
	if modo != "historia" or concluido:
		return ""
	return ETAPAS[etapa]["obj"]


func alvo() -> Variant:
	if modo != "historia" or concluido:
		return null
	var a: String = ETAPAS[etapa]["alvo"]
	if a == "carro_bom":
		var c = main.locais.get("carro_bom")
		if escolhas.get("nina") == "ajudou" and c and is_instance_valid(c):
			return c.global_position
		return null      # sem a dica da Nina, você procura
	if a == "posto":
		return main.locais.get("posto") if main.jogadores[0].tem("galao") else null
	if a == "rocha":
		for n in main.npcs:
			if n.id == "rocha":
				return n.global_position
	return main.locais.get(a)


func estado_salvo() -> Dictionary:
	return {"etapa": etapa, "escolhas": escolhas, "revirados": revirados, "falou": falou, "revelado": revelado,
		"secundario": secundario}


func restaurar(d: Dictionary) -> void:
	etapa = int(d.get("etapa", 0))
	escolhas = d.get("escolhas", {})
	revirados = int(d.get("revirados", 0))
	falou = d.get("falou", {})
	revelado = d.get("revelado", false)
	secundario = d.get("secundario", "")


func iniciar() -> void:
	if modo != "historia":
		main.aviso("Sobrevivência: aguente o máximo de dias que conseguir.", Color("ffd166"))
		return
	dizer([
		{"quem": "", "txt": "2032. O mundo seguia normal."},
		{"quem": "", "txt": "Até o acidente no reator experimental de Angra dos Reis. A nuvem viajou com o vento. Quem respirou, mudou."},
		{"quem": "", "txt": "Sobrou quem estava longe demais… ou debaixo da terra, nos bunkers."},
		{"quem": "", "txt": "Um ano depois. Bunker de Sumaré, interior de São Paulo."},
		{"quem": "Rocha", "txt": "Corvo. Você é o melhor mercenário que sobrou. E o mais barato."},
		{"quem": "Corvo", "txt": "Qual é o serviço, comandante?"},
		{"quem": "Rocha", "txt": "Levar uma carga até o Bunker do Rio de Janeiro. Quinhentos quilômetros de estrada morta, cidade queimada e radiação."},
		{"quem": "Corvo", "txt": "Que carga?"},
		{"quem": "Rocha", "txt": "Ela. O nome dela é Iara. Não faça perguntas e não deixe ninguém encostar nela."},
		{"quem": "Iara", "txt": "Eu sei me cuidar sozinha, tá?"},
		{"quem": "Rocha", "txt": "O pagamento: um lugar no Bunker do Rio. Comida, água limpa, ar filtrado. Para sempre."},
		{"quem": "Corvo", "txt": "…", "opcoes": [
			{"txt": "\"Fechado.\"", "set": {"contrato": "aceitou"}, "seguir": [
				{"quem": "Rocha", "txt": "Sabia que podia contar com a sua ganância."}]},
			{"txt": "\"Quero metade adiantada.\"", "set": {"contrato": "adiantado"}, "faz": _adiantamento, "seguir": [
				{"quem": "Rocha", "txt": "Você não muda. Leva umas balas a mais. É tudo que eu tenho."}]},
			{"txt": "\"Quem é ela de verdade?\"", "set": {"contrato": "perguntou"}, "seguir": [
				{"quem": "Rocha", "txt": "Alguém que vale mais do que nós dois juntos. Pegue seu equipamento e vá."},
				{"quem": "Iara", "txt": "(baixinho) Eu também queria saber o que eu sou pra eles."}]},
		]},
	], _depois_intro)


func _adiantamento() -> void:
	main.jogadores[0].receber("balas_9mm", 6)


func _depois_intro() -> void:
	if etapa == 0:
		_proxima()


# ---------------------------------------------------------------- conversa na tela

func dizer(falas: Array, depois := Callable(), radio := false) -> void:
	conversa = _filtrar(falas)
	linha = 0
	opcao = 0
	ao_fim = depois
	no_radio = radio
	if not conversa.is_empty():
		main.estado = main.CONVERSA


func _filtrar(falas: Array) -> Array:
	return falas.filter(func(f): return (not f.get("coop", false) or coop()) and (not f.get("solo", false) or not coop()))


func fala_atual() -> Dictionary:
	return conversa[linha] if linha < conversa.size() else {}


func comando(c: String) -> void:
	if conversa.is_empty():
		return
	var f := fala_atual()
	var ops: Array = f.get("opcoes", [])
	if c == "cima" and not ops.is_empty():
		opcao = wrapi(opcao - 1, 0, ops.size())
		main.sons.tocar("ui", null, -10.0)
	elif c == "baixo" and not ops.is_empty():
		opcao = wrapi(opcao + 1, 0, ops.size())
		main.sons.tocar("ui", null, -10.0)
	elif c == "ok":
		main.sons.tocar("ui_ok", null, -12.0)
		if not ops.is_empty():
			var o: Dictionary = ops[opcao]
			for k in o.get("set", {}):
				escolhas[k] = o["set"][k]
			if o.has("faz"):
				o["faz"].call()
			if o.has("seguir"):
				var resto: Array = conversa.slice(linha + 1)
				conversa = _filtrar(o["seguir"]) + resto
				linha = 0
				opcao = 0
				return
		linha += 1
		opcao = 0
		if linha >= conversa.size():
			conversa = []
			no_radio = false
			main.estado = main.JOGANDO
			var depois := ao_fim
			ao_fim = Callable()
			if depois.is_valid():
				depois.call()


# ---------------------------------------------------------------- eventos do jogo

func evento(nome: String, dados: Dictionary) -> void:
	if modo != "historia" or concluido:
		return
	match nome:
		"revirou":
			revirados += 1
			if etapa == 1 and dados.get("tipo", "") == "arsenal":
				_proxima()
				dizer([
					{"quem": "Corvo", "txt": "Faca, balas, iodo pra radiação. Já viajei com menos."},
					{"quem": "Iara", "txt": "Você sempre fala sozinho assim?"},
					{"quem": "Corvo", "txt": "Só quando tem gente ouvindo. Fica perto de mim. Se eu mandar esperar (✕ perto de você), você espera."},
				])
		"saiu":
			if etapa == 2:
				_proxima()
				dizer([
					{"quem": "Iara", "txt": "Faz um ano que eu não vejo o céu."},
					{"quem": "Corvo", "txt": "Não se acostuma. Aqui em cima tudo quer te matar. Até o ar."},
					{"quem": "Corvo", "txt": "Ouviu esse estalo? É o contador geiger. Quanto mais rápido, mais radiação. A gente contorna."},
				])
		"gasolina":
			if etapa == 4:
				_proxima()
				dizer([{"quem": "Corvo", "txt": "Dez litros. Agora um carro que ainda pegue. Os bons piscam o farol."}])
		"abasteceu":
			if etapa == 5:
				_proxima()
				dizer([
					{"quem": "Iara", "txt": "Ele pegou! Ele pegou mesmo!"},
					{"quem": "Corvo", "txt": "Cinto. Pedágio da Anhanguera, ao norte. Depois disso, São Paulo."},
				])
		"iara_mordida":
			if not revelado and etapa >= 2 and main.estado == main.JOGANDO:
				_revelacao("Um deles pegou o braço da Iara!")
		"dormiu":
			if secundario != "":
				secundario = ""
				escolhas["acampou"] = true


func _proxima() -> void:
	etapa = mini(etapa + 1, ETAPAS.size() - 1)
	main.aviso("Novo objetivo: " + ETAPAS[etapa]["obj"], Color("9db4ff"))
	for j in main.jogadores:
		j.ganhar_xp(20)
	if etapa == 4 and not falou.has("nina_criada"):
		falou["nina_criada"] = true
		main.criar_npc("nina")


func entardecer() -> void:
	if modo == "historia" and not concluido:
		secundario = "Noite chegando: barricade as portas de uma casa e durmam na cama (salva o jogo)"


func checar_saida() -> void:
	## chamado pelo main: a carga saiu do bunker?
	if etapa != 2 or modo != "historia":
		return
	var r: Rect2 = main.predios[main.locais["bunker"]]["r"]
	if not r.grow(-10).has_point(main.jogadores[0].global_position):
		evento("saiu", {})


# ---------------------------------------------------------------- o segredo da Iara

func _revelacao(como: String) -> void:
	revelado = true
	dizer([
		{"quem": "", "txt": como},
		{"quem": "Iara", "txt": "Ele… ele me mordeu."},
		{"quem": "Corvo", "txt": "Mostra o braço. Agora."},
		{"quem": "Corvo", "txt": "…", "opcoes": [
			{"txt": "Apontar a arma para ela", "set": {"mordida": "arma"}, "seguir": [
				{"quem": "Iara", "txt": "Faz. Se for pra virar uma daquelas coisas… faz."}]},
			{"txt": "Segurar a mão dela e esperar", "set": {"mordida": "esperou"}, "seguir": [
				{"quem": "Iara", "txt": "Fica comigo. Por favor. Não me deixa sozinha."}]},
		]},
		{"quem": "", "txt": "Um minuto. Cinco. Dez. Nada acontece."},
		{"quem": "Iara", "txt": "Eu não viro. Nunca virei. Já fui mordida três vezes."},
		{"quem": "Corvo", "txt": "Imune."},
		{"quem": "Iara", "txt": "Por isso o Rio me quer. Tem um hospital lá. Querem me abrir e descobrir por quê."},
		{"quem": "Corvo", "txt": "…", "opcoes": [
			{"txt": "\"Contrato é contrato. Vamos pro Rio.\"", "set": {"rumo": "contrato"}, "seguir": [
				{"quem": "Iara", "txt": "Claro. Eu sou só a carga."}]},
			{"txt": "\"Ninguém vai te abrir enquanto eu estiver vivo.\"", "set": {"rumo": "protetor"}, "seguir": [
				{"quem": "Iara", "txt": "…Você nem me conhece."},
				{"quem": "Corvo", "txt": "Conheço o suficiente."}]},
		]},
	])


# ---------------------------------------------------------------- rádio e pessoas

func radio_ativo() -> bool:
	return modo == "historia" and etapa == 3


func rotulo_radio() -> String:
	if modo != "historia":
		return ""
	return "Usar o rádio" if radio_ativo() else "Rádio (só chiado)"


func usar_radio() -> void:
	if not radio_ativo():
		main.aviso("Só chiado…", Color(1, 1, 1, 0.6))
		return
	dizer([
		{"quem": "Rádio", "txt": "Chhh… Bunker Rio, Dra. Helena Vasconcelos. Identifique-se."},
		{"quem": "Corvo", "txt": "Corvo. Escolta do Bunker Sumaré. Estou com a carga."},
		{"quem": "Helena", "txt": "Ela está bem? Algum ferimento? Qualquer arranhão, qualquer mordida, você me avisa na hora."},
		{"quem": "Corvo", "txt": "Por quê?"},
		{"quem": "Helena", "txt": "Porque esse é o meu trabalho. A rota: pedágio da Anhanguera, depois São Paulo por baixo, pelo metrô. A superfície da capital está quente demais."},
		{"quem": "Corvo", "txt": "…", "opcoes": [
			{"txt": "\"Ela chega inteira. Palavra.\"", "set": {"helena": "promessa"}, "seguir": [
				{"quem": "Helena", "txt": "Eu vou cobrar essa palavra, Corvo."}]},
			{"txt": "\"O que ela tem de tão especial?\"", "set": {"helena": "desconfia"}, "seguir": [
				{"quem": "Helena", "txt": "Entregue a garota e talvez eu te conte."}]},
		]},
		{"quem": "Helena", "txt": "E cuidado com o pedágio. Tem um tal de Tião lá. Ele ouve este rádio também. Câmbio."},
	], _depois_radio, true)


func _depois_radio() -> void:
	_proxima()
	if not revelado:
		# emboscada na sala do rádio: o segredo vem à tona
		for v in main.alvos():
			if v.get("vip"):
				main.sons.tocar("grito", v.global_position)
				v.hp = maxf(10.0, v.hp - 15.0)
		_revelacao("Um policial morto-vivo salta de trás do balcão e crava os dentes no braço da Iara. O Corvo derruba a coisa com uma coronhada.")
	main.aviso("Dica: galões aparecem em porta-malas e caixas de ferramentas", Color(1, 1, 1, 0.7))


func tem_conversa(id: String) -> bool:
	match id:
		"nina":
			return not falou.has("nina")
		"tiao":
			return true
		"rocha":
			return etapa == 0
	return false


func falar(id: String) -> void:
	match id:
		"nina":
			_nina()
		"tiao":
			_tiao()
		"rocha":
			if etapa == 0:
				iniciar()
			else:
				dizer([{"quem": "Rocha", "txt": "Ainda aqui? A estrada não vai ficar mais segura esperando."}])


func _nina() -> void:
	if falou.has("nina"):
		dizer([{"quem": "Nina", "txt": "Vai logo. A noite aqui é pior do que você imagina."}])
		return
	falou["nina"] = true
	var tem_bandagem := false
	for j in main.jogadores:
		if j.tem("bandagem"):
			tem_bandagem = true
	var ops := []
	if tem_bandagem:
		ops.append({"txt": "Dar uma bandagem", "set": {"nina": "ajudou"}, "faz": _dar_bandagem, "seguir": [
			{"quem": "Nina", "txt": "…Obrigada. Pouca gente ainda faz isso."},
			{"quem": "Nina", "txt": "No pátio da garagem tem um carro que ainda pega. Marquei no seu mapa. Só falta gasolina."},
			{"quem": "Nina", "txt": "E se vocês forem pela Serra… procurem as trilhas dos índios. Se um menino de uma perna só aparecer assobiando, sigam ele."},
			{"quem": "Iara", "txt": "O Saci? Minha avó contava essa."},
			{"quem": "Nina", "txt": "Sua avó sabia das coisas."},
		]})
	ops.append({"txt": "\"Não tenho nada pra você.\"", "set": {"nina": "recusou"}, "seguir": [
		{"quem": "Nina", "txt": "Claro que não. Ninguém tem."},
		{"quem": "Iara", "txt": "A gente podia ter ajudado."},
	]})
	ops.append({"txt": "\"Passa a mochila.\"", "set": {"nina": "roubou"}, "faz": _roubar_nina, "seguir": [
		{"quem": "Nina", "txt": "…Toma. Espero que valha a pena, monstro."},
		{"quem": "Iara", "txt": "…"},
	]})
	dizer([
		{"quem": "Nina", "txt": "Não atira! Eu tô viva, tá? Só… meu braço tá aberto."},
		{"quem": "Nina", "txt": "Você tem uma bandagem? Por favor." if tem_bandagem else "Você tem alguma coisa pra estancar isso? Qualquer coisa."},
		{"quem": "Corvo", "txt": "…", "opcoes": ops},
	], _depois_nina)


func _dar_bandagem() -> void:
	for j in main.jogadores:
		if j.tem("bandagem"):
			j.gastar("bandagem", 1)
			return


func _roubar_nina() -> void:
	main.jogadores[0].receber("balas_9mm", 3)
	main.jogadores[0].receber("agua", 1)


func _depois_nina() -> void:
	if escolhas.get("nina") != "ajudou":
		for npc in main.npcs:
			if npc.id == "nina":
				npc.sumir = true


func _tiao() -> void:
	if etapa < 6:
		dizer([{"quem": "Tião", "txt": "Pedágio do Tião. Sem carro e sem gasolina você não chega nem em Campinas. Volta quando tiver os dois."}])
		return
	if etapa == 6 and not _de_carro_perto():
		dizer([{"quem": "Tião", "txt": "Cadê o carro? Volta com ele, que eu abro a cancela."}])
		return
	etapa = 7
	var tem_fogo := false
	for j in main.jogadores:
		for a in ["pistola", "espingarda", "rifle"]:
			if j.tem_arma(a):
				tem_fogo = true
	var ops := []
	if tem_fogo:
		ops.append({"txt": "Entregar a sua arma de fogo", "set": {"ponte": "arma"}, "faz": _entregar_arma,
			"seguir": [{"quem": "Tião", "txt": "Boa escolha. Arma é o que mais falta do lado de lá."}]})
	ops.append({"txt": "Dar metade da gasolina", "set": {"ponte": "gasolina"}, "faz": _metade_gasolina,
		"seguir": [{"quem": "Tião", "txt": "Metade. Vai dar pra chegar em São Paulo… se você não se perder."}]})
	ops.append({"txt": "Ameaçar: \"Abre a cancela, Tião.\"", "set": {"ponte": "ameaca"}, "seguir": [
		{"quem": "Tião", "txt": "Calma, calma! Tá aberta! Mas a doutora do rádio vai saber disso."}]})
	ops.append({"txt": "Entregar a Iara", "set": {"ponte": "vendeu"}, "seguir": [
		{"quem": "Iara", "txt": "Corvo…? Corvo, não. NÃO!"},
		{"quem": "Tião", "txt": "Homem de negócios. Toma a sua liberdade, mercenário."},
		{"quem": "", "txt": "O carro segue sozinho para o norte. No retrovisor, a Iara para de gritar."}]})
	var falas := [
		{"quem": "Tião", "txt": "Opa, opa. Carro bonito. Pedágio do Tião: ninguém passa de graça."},
		{"quem": "Tião", "txt": "E essa aí… é a menina que a doutora do Rio procura? O rádio não fala de outra coisa. Ela vale um bunker inteiro."},
		{"quem": "Iara", "txt": "Corvo…"},
		{"quem": "Tião", "txt": "Escolhe: sua arma de fogo, metade da gasolina… ou a menina." if tem_fogo else "Escolhe: metade da gasolina… ou a menina."},
		{"quem": "Corvo", "txt": "…", "opcoes": ops},
	]
	if escolhas.get("nina") == "ajudou":
		falas.insert(2, {"quem": "Nina", "txt": "Deixa eles passarem, Tião. Eles me ajudaram."})
		falas.insert(3, {"quem": "Tião", "txt": "Nina?! …Tá. Mas a regra é a regra."})
	dizer(falas, main.fim_capitulo)


func _entregar_arma() -> void:
	for j in main.jogadores:
		for a in ["rifle", "espingarda", "pistola"]:
			if j.tem_arma(a):
				j.armas.erase(a)
				if j.arma == a:
					j.arma = j.melhor_corpo()
				return


func _metade_gasolina() -> void:
	var c = main.locais.get("carro_atual")
	if c and is_instance_valid(c):
		c.combustivel *= 0.5


func _de_carro_perto() -> bool:
	for c in main.carros:
		if c.motorista and c.global_position.distance_to(main.locais["ponte"]) < 420:
			main.locais["carro_atual"] = c
			return true
	return false


func atacou_npc(id: String) -> void:
	if not falou.has("atacou_" + id):
		falou["atacou_" + id] = true
		escolhas["violencia"] = true
		main.aviso("Ei! Não atira em gente!", Color("ff6b6b"))


func resumo() -> Array:
	## o que as escolhas significam, para a tela do fim do capítulo
	var r := []
	match escolhas.get("contrato", ""):
		"adiantado": r.append("Contrato: você cobrou adiantado. O Rocha não vai esquecer.")
		"perguntou": r.append("Contrato: você perguntou quem ela era. Ninguém respondeu.")
		_: r.append("Contrato: você aceitou sem perguntar.")
	match escolhas.get("mordida", ""):
		"arma": r.append("A mordida: você apontou a arma para a Iara. Ela viu nos seus olhos.")
		"esperou": r.append("A mordida: você segurou a mão dela e esperou.")
	match escolhas.get("rumo", ""):
		"protetor": r.append("Você prometeu que ninguém vai abrir a Iara. Promessas pesam.")
		"contrato": r.append("Para você, ela ainda é a carga.")
	r.append("Rádio: " + ("você deu sua palavra à Dra. Helena." if escolhas.get("helena") == "promessa" else "a Dra. Helena sabe que você desconfia."))
	match escolhas.get("nina", ""):
		"ajudou": r.append("Nina: você a ajudou. Ela contou das trilhas da Serra… e do Saci.")
		"recusou": r.append("Nina: você a deixou sangrando.")
		"roubou": r.append("Nina: você a roubou. A Iara não esqueceu.")
	match escolhas.get("ponte", ""):
		"arma": r.append("Pedágio: você entregou sua arma ao Tião.")
		"gasolina": r.append("Pedágio: você deu metade da gasolina.")
		"ameaca": r.append("Pedágio: você ameaçou o Tião. A Dra. Helena vai saber.")
		"vendeu": r.append("Pedágio: você VENDEU a Iara. O Corvo segue sozinho.")
	if escolhas.get("acampou", false):
		r.append("Vocês passaram uma noite barricados, ouvindo os mortos lá fora.")
	return r


func vendeu() -> bool:
	return escolhas.get("ponte", "") == "vendeu"
