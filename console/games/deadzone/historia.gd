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
var etapas: Array = ETAPAS        # a lista de objetivos (o coop troca pela dele)

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
	if modo == "sobrevivencia" or concluido:
		return ""
	return etapas[etapa]["obj"]


func alvo() -> Variant:
	if modo == "sobrevivencia" or concluido:
		return null
	var a: String = etapas[etapa]["alvo"]
	if a == "":
		return null
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
		_q("c1_abertura", 0, {"quem": "", "txt": "2032. Angra dos Reis. O reator experimental falhou numa terça-feira à tarde."}),
		_q("c1_abertura", 1, {"quem": "", "txt": "A nuvem verde chegou a São Paulo antes do jornal da noite. Ninguém sabia o que era. Todo mundo filmou."}),
		_q("c1_abertura", 2, {"quem": "", "txt": "Quem respirou, mudou."}),
		_q("c1_abertura", 3, {"quem": "", "txt": "Quem chegou a tempo num bunker fechou a porta. E não abriu mais para ninguém."}),
		_q("c1_contrato", 0, {"quem": "", "txt": "Um ano depois. Bunker de Sumaré, interior de São Paulo."}),
		_q("c1_contrato", 0, {"quem": "Rocha", "txt": "Corvo. Você é o melhor mercenário que sobrou. E o mais barato."}),
		_q("c1_contrato", 0, {"quem": "Corvo", "txt": "Os outros três morreram. Isso me deixa caro. Qual é o serviço?"}),
		_q("c1_contrato", 0, {"quem": "Rocha", "txt": "Uma entrega. Daqui até o Bunker do Rio de Janeiro."}),
		_q("c1_contrato", 0, {"quem": "Corvo", "txt": "Quinhentos quilômetros. Duas capitais queimadas. Uma serra. Que carga?"}),
		_q("c1_contrato", 1, {"quem": "Rocha", "txt": "Ela. O nome é Iara. Não faz pergunta e não deixa ninguém encostar nela."}),
		_q("c1_contrato", 1, {"quem": "Iara", "txt": "Oi! Eu tô ouvindo, tá? O vidro não é à prova de som."}),
		_q("c1_contrato", 1, {"quem": "Corvo", "txt": "Eu não levo criança."}),
		_q("c1_contrato", 1, {"quem": "Iara", "txt": "E eu não ando com tiozão que fede a cigarro. Olha só: já temos uma coisa em comum."}),
		{"quem": "Rocha", "cara": "sorriso", "txt": "O pagamento: um lugar no Bunker do Rio. Comida, água limpa, ar filtrado. Pra sempre."},
		{"quem": "Corvo", "cara": "neutro", "txt": "…", "opcoes": [
			{"txt": "\"Fechado.\"", "set": {"contrato": "aceitou"}, "seguir": [
				{"quem": "Rocha", "cara": "rindo", "txt": "Sabia que dava pra contar com a sua ganância."}]},
			{"txt": "\"Metade adiantada.\"", "set": {"contrato": "adiantado"}, "faz": _adiantamento, "seguir": [
				{"quem": "Rocha", "cara": "duvida", "txt": "Você não muda. Leva seis balas. É o que sobrou no cofre."}]},
			{"txt": "\"Quem é ela de verdade?\"", "set": {"contrato": "perguntou"}, "seguir": [
				{"quem": "Rocha", "cara": "culpado", "txt": "Alguém que vale mais que nós dois juntos. Pega o equipamento e some."},
				{"quem": "Iara", "cara": "triste", "txt": "(baixinho) Eu também queria saber o que eu sou pra eles."}]},
		]},
	], _depois_intro)


func _q(pagina: String, quadro: int, f: Dictionary) -> Dictionary:
	## fala mostrada em cima de um quadro de HQ (arte/hq/<pagina>.jpg). Sem a imagem, vira fala normal.
	var r := f.duplicate()
	r["hq"] = pagina
	r["q"] = quadro
	return r


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

func tiao_pode_chamar() -> bool:
	return modo == "historia" and not concluido and etapa >= 4


func capitulo() -> Dictionary:
	## o que a tela de fim de capítulo mostra
	if vendeu():
		return {"titulo": "CAPÍTULO 1 CONCLUÍDO", "sub": "A Carga · Sumaré", "cor": "vermelho",
			"fim": ["Sozinho na Anhanguera. O pagamento do Tião pesa no banco do carona, vazio.", "Este caminho termina aqui. Ou não?"]}
	return {"titulo": "CAPÍTULO 1 CONCLUÍDO", "sub": "A Carga · Sumaré", "cor": "azul",
		"fim": ["A cancela sobe. À frente, a Anhanguera e, depois dela, São Paulo — por baixo da terra.",
			"Capítulo 2 — São Paulo: o metrô. Em breve."]}


func evento(nome: String, dados: Dictionary) -> void:
	if modo != "historia" or concluido:
		return
	match nome:
		"revirou":
			revirados += 1
			if etapa == 1 and dados.get("tipo", "") == "arsenal":
				_proxima()
				dizer([
					{"quem": "Corvo", "txt": "Faca, seis balas, iodo pra radiação. Não é a Teimosa, mas corta. Já atravessei estado com menos."},
					{"quem": "Iara", "cara": "deboche", "txt": "Você sempre narra o que tá fazendo? Parece tio gravando vídeo."},
					{"quem": "Corvo", "cara": "irritado", "txt": "Só quando tem plateia. Regra um: fica perto. Regra dois: se eu mandar esperar (✕ perto de você), você espera."},
					{"quem": "Iara", "cara": "rindo", "txt": "E a regra três?"},
					{"quem": "Corvo", "cara": "neutro", "txt": "Não tem regra três. Ninguém chega na três."},
				])
		"saiu":
			if etapa == 2:
				_proxima()
				dizer([
					_q("c1_contrato", 2, {"quem": "Iara", "txt": "Faz um ano que eu não vejo o céu."}),
					_q("c1_contrato", 2, {"quem": "Corvo", "txt": "Não se acostuma. Aqui em cima tudo quer te matar. Até o ar."}),
					{"quem": "Corvo", "cara": "preocupado", "txt": "Ouviu esse estalo? Contador geiger. Quanto mais rápido, mais radiação. A gente contorna."},
					{"quem": "Iara", "cara": "deboche", "txt": "Os torrados lá fora gemem igual panela de pressão. Vou chamar de Queimados. Os rápidos são os Corredores."},
					{"quem": "Corvo", "cara": "neutro", "txt": "Dá nome se quiser. Só não dá carinho."},
				])
		"gasolina":
			if etapa == 4:
				_proxima()
				dizer([
					{"quem": "Corvo", "txt": "Dez litros. Agora um carro que ainda pegue. Os bons piscam o farol."},
					{"quem": "Iara", "cara": "rindo", "txt": "Tipo vaga-lume. Fofo."},
				])
		"abasteceu":
			if etapa == 5:
				_proxima()
				dizer([
					{"quem": "Iara", "cara": "rindo", "txt": "Ele pegou! Ele pegou mesmo!"},
					{"quem": "Corvo", "cara": "sorriso", "txt": "Cinto. Pedágio da Anhanguera, ao norte. Depois disso, São Paulo."},
					{"quem": "Iara", "cara": "deboche", "txt": "Posso escolher a música?"},
					{"quem": "Corvo", "cara": "neutro", "txt": "Não tem rádio. Não tem música. E não tem você escolhendo."},
				])
		"iara_mordida":
			if not revelado and etapa >= 2 and main.estado == main.JOGANDO:
				_revelacao("Um deles pegou o braço da Iara!", false)
		"dormiu":
			if secundario != "":
				secundario = ""
				escolhas["acampou"] = true


func _proxima() -> void:
	etapa = mini(etapa + 1, etapas.size() - 1)
	main.aviso("Novo objetivo: " + etapas[etapa]["obj"], Color("9db4ff"))
	for j in main.jogadores:
		j.ganhar_xp(20)
	if modo == "historia" and etapa == 4 and not falou.has("nina_criada"):
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

func _revelacao(como: String, hq := true) -> void:
	## hq = a emboscada da sala do rádio (tem página de quadrinho). Mordida no meio da rua = só retratos.
	revelado = true
	var pg := "c1_mordida_arma" if hq else ""
	var arma := [
		_talvez(hq, "c1_mordida_arma", 1, {"quem": "Iara", "cara": "chorando", "txt": "Faz. Se for pra virar uma daquelas coisas… faz."}),
		_talvez(hq, "c1_mordida_arma", 1, {"quem": "Corvo", "cara": "preocupado", "txt": "Vou contar. Um minuto, cinco, dez. Se você mudar, eu não erro."}),
		_talvez(hq, "c1_mordida_arma", 2, {"quem": "", "txt": "Dez minutos. Nada acontece."}),
		_talvez(hq, "c1_mordida_arma", 2, {"quem": "Iara", "cara": "triste", "txt": "Eu não viro. Nunca virei. Essa é a terceira mordida."}),
	]
	var esperou := [
		_talvez(hq, "c1_mordida_mao", 1, {"quem": "Iara", "cara": "chorando", "txt": "Fica comigo. Por favor. Não me deixa sozinha."}),
		_talvez(hq, "c1_mordida_mao", 1, {"quem": "Corvo", "cara": "preocupado", "txt": "Tô aqui. Respira. Conta comigo: um… dois…"}),
		_talvez(hq, "c1_mordida_mao", 2, {"quem": "Iara", "cara": "triste", "txt": "Eu não viro. Nunca virei. Essa é a terceira mordida."}),
	]
	dizer([
		_talvez(hq, pg, 0, {"quem": "", "txt": como}),
		_talvez(hq, pg, 0, {"quem": "Iara", "cara": "medo", "txt": "Ele… ele me mordeu."}),
		_talvez(hq, pg, 0, {"quem": "Corvo", "cara": "grito", "txt": "Mostra o braço. AGORA."}),
		{"quem": "Corvo", "cara": "medo", "txt": "…", "opcoes": [
			{"txt": "Apontar a arma para ela", "set": {"mordida": "arma"}, "seguir": arma},
			{"txt": "Segurar a mão dela e esperar", "set": {"mordida": "esperou"}, "seguir": esperou},
		]},
		{"quem": "Corvo", "cara": "preocupado", "txt": "Imune."},
		{"quem": "Iara", "cara": "triste", "txt": "Por isso o Rio me quer. Tem um hospital lá. Querem me abrir pra descobrir por quê."},
		{"quem": "Iara", "cara": "determinada", "txt": "Minha avó dizia que o sangue guarani lembra de tudo. Acho que o meu lembra como não morrer."},
		{"quem": "Corvo", "cara": "neutro", "txt": "…", "opcoes": [
			{"txt": "\"Contrato é contrato. Vamos pro Rio.\"", "set": {"rumo": "contrato"}, "seguir": [
				{"quem": "Iara", "cara": "brava", "txt": "Claro. Eu sou só a carga. Esqueci."}]},
			{"txt": "\"Ninguém vai te abrir enquanto eu estiver vivo.\"", "set": {"rumo": "protetor"}, "seguir": [
				{"quem": "Iara", "cara": "triste", "txt": "…Você nem me conhece."},
				{"quem": "Corvo", "cara": "neutro", "txt": "Conheço o suficiente. Eu tinha uma filha da sua idade. Bia. Também falava demais."}]},
		]},
	])


func _talvez(hq: bool, pagina: String, quadro: int, f: Dictionary) -> Dictionary:
	return _q(pagina, quadro, f) if hq and pagina != "" else f


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
		{"quem": "Rádio", "txt": "Chhh… Bunker Rio, aqui é a Dra. Helena Vasconcelos. Identifique-se, meu bem."},
		{"quem": "Corvo", "txt": "Corvo. Escolta do Bunker Sumaré. Tô com a carga."},
		{"quem": "Helena", "cara": "calma", "txt": "Que alívio. Ela está bem? Algum arranhão, alguma mordida? Qualquer coisa, você me avisa na hora, tá bom?"},
		{"quem": "Corvo", "cara": "irritado", "txt": "Por quê?"},
		{"quem": "Helena", "cara": "fria", "txt": "Porque esse é o meu trabalho, meu bem. Rota: pedágio da Anhanguera, depois São Paulo por baixo, pelo metrô. A superfície da capital está quente demais."},
		{"quem": "Iara", "cara": "brava", "txt": "Pergunta se ela vai me dar pirulito depois da agulha."},
		{"quem": "Corvo", "cara": "neutro", "txt": "…", "opcoes": [
			{"txt": "\"Ela chega inteira. Palavra.\"", "set": {"helena": "promessa"}, "seguir": [
				{"quem": "Helena", "cara": "calma", "txt": "Vou cobrar essa palavra, Corvo."}]},
			{"txt": "\"O que ela tem de tão especial?\"", "set": {"helena": "desconfia"}, "seguir": [
				{"quem": "Helena", "cara": "fria", "txt": "Entregue a garota e talvez eu te conte. Talvez."}]},
		]},
		{"quem": "Helena", "cara": "calma", "txt": "E cuidado no pedágio. Tem um tal de Tião lá. Ele escuta este rádio também. Câmbio, meu bem."},
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
				dizer([{"quem": "Rocha", "cara": "bravo", "txt": "Ainda aqui? A estrada não fica mais segura enquanto você enrola."}])


func _nina() -> void:
	if falou.has("nina"):
		dizer([{"quem": "Nina", "cara": "rindo", "txt": "Vai logo, coroa. A noite aqui come gente."}])
		return
	falou["nina"] = true
	var tem_bandagem := false
	for j in main.jogadores:
		if j.tem("bandagem"):
			tem_bandagem = true
	var ops := []
	if tem_bandagem:
		ops.append({"txt": "Dar uma bandagem", "set": {"nina": "ajudou"}, "faz": _dar_bandagem, "seguir": [
			{"quem": "Nina", "cara": "rindo", "txt": "Valeu, coroa. Tá ligado que quase ninguém faz mais isso?"},
			{"quem": "Nina", "cara": "rindo", "txt": "No pátio da garagem tem um carro que ainda pega. Marquei no teu mapa. Só falta a gasosa."},
			{"quem": "Nina", "cara": "medo", "txt": "E se forem pela Serra, procura as trilhas dos índios. Se aparecer um moleque de uma perna só assobiando, segue ele. Não pergunta. Segue."},
			{"quem": "Iara", "cara": "rindo", "txt": "O Saci? Minha avó contava essa!"},
			{"quem": "Nina", "cara": "rindo", "txt": "Tua avó era das minhas."},
		]})
	ops.append({"txt": "\"Não tenho nada pra você.\"", "set": {"nina": "recusou"}, "seguir": [
		{"quem": "Nina", "cara": "brava", "txt": "Suave. Ninguém tem nada mesmo. Mundo lindo esse."},
		{"quem": "Iara", "cara": "brava", "txt": "A gente podia ter ajudado."},
	]})
	ops.append({"txt": "\"Passa a mochila.\"", "set": {"nina": "roubou"}, "faz": _roubar_nina, "seguir": [
		{"quem": "Nina", "cara": "brava", "txt": "…Toma. Espero que te engasgue, monstro."},
		{"quem": "Iara", "cara": "triste", "txt": "…"},
	]})
	dizer([
		{"quem": "Nina", "cara": "medo", "txt": "Ô, ô, abaixa isso aí! Tô viva, mano, tô viva! Só o braço que tá aberto."},
		{"quem": "Nina", "cara": "dor", "txt": "Tem bandagem aí? Na moral, eu pago depois. Com juros." if tem_bandagem else "Tem alguma coisa pra estancar isso? Pano, fita, sei lá, qualquer coisa."},
		{"quem": "Corvo", "cara": "neutro", "txt": "…", "opcoes": ops},
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
		dizer([{"quem": "Tião", "cara": "locutor", "txt": "Freguês sem carro é freguês a pé! Volta com carro e gasolina, que o Tião abre a cancela."}])
		return
	if etapa == 6 and not _de_carro_perto():
		dizer([{"quem": "Tião", "cara": "ganancia", "txt": "Cadê o carro, freguês? Volta com ele que a gente conversa."}])
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
			"seguir": [{"quem": "Tião", "cara": "ganancia", "txt": "Boa escolha! Arma é o que mais falta do lado de lá."}] + _saida()})
	ops.append({"txt": "Dar metade da gasolina", "set": {"ponte": "gasolina"}, "faz": _metade_gasolina,
		"seguir": [{"quem": "Tião", "cara": "ganancia", "txt": "Metade! Dá pra chegar em São Paulo… se você não se perder, freguês."}] + _saida()})
	ops.append({"txt": "Ameaçar: \"Abre a cancela, Tião.\"", "set": {"ponte": "ameaca"}, "seguir": [
		{"quem": "Tião", "cara": "assustado", "txt": "Calma, calma, CALMA! Tá aberta! Mas a doutora do rádio vai ficar sabendo disso, viu?"}] + _saida()})
	ops.append({"txt": "Entregar a Iara", "set": {"ponte": "vendeu"}, "seguir": [
		{"quem": "Iara", "cara": "grito", "txt": "Corvo…? Corvo, não. NÃO!"},
		{"quem": "Tião", "cara": "ganancia", "txt": "Homem de negócios! Toma a sua liberdade, freguês."},
		_q("c1_pedagio_vendeu", 2, {"quem": "", "txt": "O carro segue sozinho para o norte. No retrovisor, a Iara para de gritar."})]})
	var falas := [
		_q("c1_pedagio", 0, {"quem": "Tião", "txt": "Atenção, meu povo! Aqui é o Tião, na Rádio Pedágio AM, a única que ainda toca! E olha só: freguês novo!"}),
		_q("c1_pedagio", 0, {"quem": "Tião", "txt": "Carro bonito, hein, freguês? Pedágio do Tião: ninguém passa de graça."}),
		{"quem": "Tião", "cara": "ganancia", "txt": "E essa mocinha aí… é a menina que a doutora do Rio procura? O rádio não fala de outra coisa. Ela vale um bunker inteiro."},
		{"quem": "Iara", "cara": "medo", "txt": "Corvo…"},
		{"quem": "Tião", "cara": "locutor", "txt": "Escolhe: sua arma de fogo, metade da gasolina… ou a menina. Promoção de hoje!" if tem_fogo else "Escolhe: metade da gasolina… ou a menina. Promoção de hoje!"},
		{"quem": "Corvo", "cara": "irritado", "txt": "…", "opcoes": ops},
	]
	if escolhas.get("nina") == "ajudou":
		falas.insert(2, {"quem": "Nina", "cara": "rindo", "txt": "Deixa eles passarem, Tião. Eles me ajudaram."})
		falas.insert(3, {"quem": "Tião", "cara": "assustado", "txt": "Nina?! …Tá, tá. Mas regra é regra, minha filha."})
	dizer(falas, main.fim_capitulo)


func _saida() -> Array:
	## fim do capítulo quando a Iara segue no carro
	return [
		_q("c1_pedagio", 1, {"quem": "Iara", "txt": "Você ia me trocar? Fala a verdade."}),
		_q("c1_pedagio", 1, {"quem": "Corvo", "txt": "Pensei. Três segundos."}),
		_q("c1_pedagio", 1, {"quem": "Iara", "txt": "…E aí?"}),
		_q("c1_pedagio", 1, {"quem": "Corvo", "txt": "E aí que eu sou ruim de conta."}),
		_q("c1_pedagio", 2, {"quem": "", "txt": "A cancela sobe. Atrás deles, a Rádio Pedágio AM toca para ninguém. Na frente: São Paulo."}),
	]


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
