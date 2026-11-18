extends Node
## Capítulo 1 — "O Sinal". Objetivos em sequência, conversas com escolhas e o que cada escolha muda.
## As escolhas ficam em `escolhas` e aparecem no fim do capítulo (e vão valer no Capítulo 2).

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

const ETAPAS := [
	{"obj": "Revire a casa: armários e geladeira (segure ✕)", "alvo": ""},
	{"obj": "Vá até a delegacia e use o rádio", "alvo": "radio"},
	{"obj": "Encha um galão: bomba do posto ou tanque de carro quebrado", "alvo": "posto"},
	{"obj": "Ache um carro que funcione (farol piscando) e abasteça", "alvo": "carro_bom"},
	{"obj": "Dirija até a ponte ao norte", "alvo": "ponte"},
	{"obj": "Fale com o homem do portão", "alvo": "ponte"},
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
		return null      # sem a dica da Nina, o jogador procura
	if a == "posto" and main.jogadores[0].tem("galao"):
		return main.locais.get("posto")
	if a == "posto":
		return null
	return main.locais.get(a)


func iniciar() -> void:
	if modo != "historia":
		main.aviso("Sobrevivência: aguente o máximo de dias que conseguir.", Color("ffd166"))
		return
	dizer([
		{"quem": "Davi", "txt": "Quarenta e um dias. A comida acabou ontem."},
		{"quem": "Lia", "txt": "E esse rádio não para de chiar. Escuta…", "coop": true},
		{"quem": "Rádio", "txt": "…aqui é a Estação Norte… temos comida, remédio… a ponte do rio fica aberta por pouco tempo… chhhh…"},
		{"quem": "Davi", "txt": "Estação Norte. Do outro lado da ponte.", "solo": true},
		{"quem": "Lia", "txt": "A ponte ao norte. A gente consegue, Davi. Junto.", "coop": true},
		{"quem": "Davi", "txt": "Primeiro, algo pra comer. E algo pra bater."},
	])


# ---------------------------------------------------------------- conversa na tela

func dizer(falas: Array, depois := Callable()) -> void:
	conversa = falas.filter(func(f): return (not f.get("coop", false) or coop()) and (not f.get("solo", false) or not coop()))
	linha = 0
	opcao = 0
	ao_fim = depois
	if not conversa.is_empty():
		main.estado = main.CONVERSA


func fala_atual() -> Dictionary:
	return conversa[linha] if linha < conversa.size() else {}


func comando(c: String) -> void:
	if conversa.is_empty():
		return
	var f := fala_atual()
	var ops: Array = f.get("opcoes", [])
	if c == "cima" and not ops.is_empty():
		opcao = wrapi(opcao - 1, 0, ops.size())
	elif c == "baixo" and not ops.is_empty():
		opcao = wrapi(opcao + 1, 0, ops.size())
	elif c == "ok":
		if not ops.is_empty():
			var o: Dictionary = ops[opcao]
			for k in o.get("set", {}):
				escolhas[k] = o["set"][k]
			if o.has("faz"):
				o["faz"].call()
			if o.has("seguir"):
				var resto: Array = conversa.slice(linha + 1)
				conversa = o["seguir"].filter(func(x): return (not x.get("coop", false) or coop()) and (not x.get("solo", false) or not coop())) + resto
				linha = 0
				opcao = 0
				return
		linha += 1
		opcao = 0
		if linha >= conversa.size():
			conversa = []
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
			if etapa == 0 and revirados >= 2:
				_proxima()
				dizer([
					{"quem": "Davi", "txt": "Um taco e uma lata de feijão. Já é um começo."},
					{"quem": "Lia", "txt": "O rádio da delegacia alcança a Estação. Se a gente falar com eles, sabem que estamos indo.", "coop": true},
					{"quem": "Davi", "txt": "O rádio da delegacia tem alcance. Se eu falar com eles, sabem que estou indo.", "solo": true},
				])
		"gasolina":
			if etapa == 2:
				_proxima()
				dizer([{"quem": "Davi", "txt": "Dez litros. Agora falta um carro que ainda pegue. Os que funcionam estão com o farol piscando."}])
		"abasteceu":
			if etapa == 3:
				_proxima()
				dizer([{"quem": "Davi", "txt": "Pegou! Ponte ao norte. Vamos."}])
		"dirigiu":
			pass
		"dormiu":
			if secundario != "":
				secundario = ""
				escolhas["acampou"] = true


func _proxima() -> void:
	etapa = mini(etapa + 1, ETAPAS.size() - 1)
	main.aviso("Novo objetivo: " + ETAPAS[etapa]["obj"], Color("9db4ff"))
	for j in main.jogadores:
		j.ganhar_xp(20)
	if etapa == 2 and not falou.has("nina_criada"):
		falou["nina_criada"] = true
		main.criar_npc("nina")


func entardecer() -> void:
	if modo == "historia" and not concluido:
		secundario = "Noite chegando: barricade as portas de uma casa e durma na cama"


# ---------------------------------------------------------------- rádio e pessoas

func radio_ativo() -> bool:
	return modo == "historia" and etapa == 1


func rotulo_radio() -> String:
	return "Usar o rádio" if radio_ativo() else ("Rádio (só chiado)" if modo == "historia" else "")


func usar_radio() -> void:
	if not radio_ativo():
		main.aviso("Só chiado…", Color(1, 1, 1, 0.6))
		return
	var verdade := [
		{"quem": "Marta", "txt": "Então venham. A ponte fecha em três dias. E tragam combustível: depois da ponte são vinte quilômetros.", "coop": true},
		{"quem": "Marta", "txt": "Então venha. A ponte fecha em três dias. E traga combustível: depois da ponte são vinte quilômetros.", "solo": true},
	]
	var mentira := [
		{"quem": "Marta", "txt": "…Uma criança. Vou guardar um lugar. Não me faça me arrepender, Davi."},
		{"quem": "Lia", "txt": "Davi! Por que você disse isso?", "coop": true},
		{"quem": "Davi", "txt": "Porque com criança eles abrem a porta.", "coop": true},
	]
	dizer([
		{"quem": "Rádio", "txt": "Chhh… Estação Norte. Quem fala?"},
		{"quem": "Davi", "txt": "Meu nome é Davi. Estou na Vila Aurora. Ouvi o chamado."},
		{"quem": "Marta", "txt": "Aqui é a Marta. Quantos são vocês? Cada boca conta aqui."},
		{"quem": "Davi", "txt": "…", "opcoes": [
			{"txt": "Falar a verdade: \"Somos dois, eu e a Lia.\"" if coop() else "Falar a verdade: \"Sou só eu.\"",
				"set": {"radio": "verdade"}, "seguir": verdade},
			{"txt": "Mentir: \"Somos três. Tem uma criança com a gente.\"", "set": {"radio": "mentira"}, "seguir": mentira},
		]},
		{"quem": "Marta", "txt": "Na ponte tem um tal de Tião. Ele cobra pedágio. Não confie nele."},
		{"quem": "Marta", "txt": "Câmbio, desligo."},
	], _depois_radio)


func _depois_radio() -> void:
	_proxima()
	main.aviso("Dica: galões aparecem em porta-malas e caixas de ferramentas", Color(1, 1, 1, 0.7))


func tem_conversa(id: String) -> bool:
	if id == "nina":
		return not falou.has("nina")
	if id == "tiao":
		return true
	return false


func falar(id: String) -> void:
	match id:
		"nina":
			_nina()
		"tiao":
			_tiao()


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
		ops.append({"txt": "Dar uma bandagem", "set": {"nina": "ajudou"}, "faz": _dar_bandagem,
			"seguir": [
				{"quem": "Nina", "txt": "…Obrigada. Pouca gente ainda faz isso."},
				{"quem": "Nina", "txt": "Escuta: no pátio da garagem tem um carro que ainda pega. Marquei no seu mapa. Só falta gasolina."},
			]})
	ops.append({"txt": "\"Não tenho nada pra você.\"", "set": {"nina": "recusou"}, "seguir": [
		{"quem": "Nina", "txt": "Claro que não. Ninguém tem."},
	]})
	ops.append({"txt": "\"Me dá o que você tem na mochila.\"", "set": {"nina": "roubou"}, "faz": _roubar_nina,
		"seguir": [
			{"quem": "Nina", "txt": "…Toma. Espero que valha a pena, monstro."},
		]})
	dizer([
		{"quem": "Nina", "txt": "Não atira! Eu tô viva, tá? Só… meu braço tá aberto."},
		{"quem": "Nina", "txt": "Você tem uma bandagem? Por favor." if tem_bandagem else "Você tem alguma coisa pra estancar isso? Qualquer coisa."},
		{"quem": "Davi", "txt": "…", "opcoes": ops},
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
	if etapa < 4:
		dizer([
			{"quem": "Tião", "txt": "Ponte do Tião. Sem carro e sem gasolina você não chega na Estação. Volta quando tiver os dois."},
		])
		return
	if etapa == 4 and not _de_carro_perto():
		dizer([{"quem": "Tião", "txt": "Cadê o carro? Volta com ele, que eu abro o portão."}])
		return
	etapa = 5
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
		"seguir": [{"quem": "Tião", "txt": "Metade. Vai dar pra chegar… se você não se perder."}]})
	ops.append({"txt": "Ameaçar: \"Abre o portão, Tião.\"", "set": {"ponte": "ameaca"}, "seguir": [
		{"quem": "Tião", "txt": "Calma, calma! Tá aberto! Mas a Marta vai saber disso. Ela sabe de tudo."},
	]})
	var falas := [
		{"quem": "Tião", "txt": "Opa, opa. Carro bonito. Ponte do Tião: ninguém passa de graça."},
		{"quem": "Davi", "txt": "O que você quer?"},
		{"quem": "Tião", "txt": "Sua arma de fogo. Ou metade da gasolina. Escolhe." if tem_fogo else "Metade da gasolina. Escolhe."},
		{"quem": "Davi", "txt": "…", "opcoes": ops},
	]
	if escolhas.get("nina") == "ajudou":
		falas.insert(1, {"quem": "Nina", "txt": "Deixa eles passarem, Tião. Eles me ajudaram."})
		falas.insert(2, {"quem": "Tião", "txt": "Nina?! …Tá. Mas a regra é a regra."})
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
	r.append("Rádio: " + ("você contou a verdade à Marta." if escolhas.get("radio") == "verdade" else "você mentiu sobre uma criança. Marta vai perguntar por ela."))
	match escolhas.get("nina", ""):
		"ajudou": r.append("Nina: você a ajudou. Ela vai lembrar.")
		"recusou": r.append("Nina: você a deixou sangrando.")
		"roubou": r.append("Nina: você a roubou. Ela sobreviveu… e vai contar para os outros.")
		_: r.append("Nina: vocês nunca se encontraram.")
	match escolhas.get("ponte", ""):
		"arma": r.append("Ponte: você entregou sua arma ao Tião.")
		"gasolina": r.append("Ponte: você deu metade da gasolina.")
		"ameaca": r.append("Ponte: você ameaçou o Tião. A Marta vai saber.")
	if escolhas.get("acampou", false):
		r.append("Você sobreviveu a uma noite barricado numa casa.")
	return r
