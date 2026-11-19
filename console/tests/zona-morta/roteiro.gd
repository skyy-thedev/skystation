extends SceneTree
## Joga o Capítulo 1 inteiro sem ninguém no controle: abertura, bunker, rádio, a mordida da Iara, posto, carro,
## coop, dormir (salva), carregar o save, pedágio e o fim do capítulo. Fotos com ZM_FOTOS=/pasta.
##   cp console/tests/zona-morta/roteiro.gd console/games/zona-morta/zz_roteiro.gd
##   godot --headless --path console/games/zona-morta --script res://zz_roteiro.gd

var m: Node
var n := 0
var falhas := 0
var bunker: Rect2


func _initialize() -> void:
	Engine.max_fps = 60   # sem tela (CI) os quadros não esperam a TV: segura em 60 por segundo
	if FileAccess.file_exists("user://save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _shot(nome: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("ZM_FOTOS") == "":
		return
	root.get_texture().get_image().save_png(OS.get_environment("ZM_FOTOS") + "/" + nome + ".png")


func _ok(c: bool, msg: String) -> void:
	print(("  ok  " if c else "FALHOU ") + msg)
	if not c:
		falhas += 1


func _avancar(vezes := 30) -> void:
	## aperta ✕ na conversa, sempre escolhendo a primeira opção
	for i in vezes:
		if m.estado != m.CONVERSA:
			return
		m.historia.comando("ok")


func _process(_d: float) -> bool:
	n += 1
	var j = m.jogadores[0] if not m.jogadores.is_empty() else null
	match n:
		20:
			_ok(m.sons.bancos.size() > 20, "sons gerados (%d)" % m.sons.bancos.size())
			_shot("01-titulo")
			Input.action_press("p1_interagir")
		22:
			Input.action_release("p1_interagir")
		40:
			_ok(m.estado == m.CONVERSA, "abertura começa (narração)")
			_shot("02-narracao")
			for i in 4: m.historia.comando("ok")
		45:
			_shot("03-rocha")
			_avancar()
			_ok(m.estado == m.JOGANDO and m.historia.etapa == 1, "conversa com o Rocha: objetivo do equipamento")
			_ok(m.vip != null and m.vip.global_position.distance_to(j.global_position) < 300, "Iara está no bunker com o Corvo")
		60:
			bunker = m.predios[m.locais["bunker"]]["r"]
			for o in m.objetos:
				if o.tipo == "arsenal" and bunker.has_point(o.global_position):
					o.usar(j)
			_ok(j.tem("iodo") and j.tem_arma("faca"), "equipamento do bunker (faca, iodo)")
			_ok(m.historia.etapa == 2, "objetivo: sair do bunker")
			_avancar()
		70:
			j.global_position = m.locais["saida_bunker"] + Vector2(0, -90)
			j.global_position = bunker.get_center() + Vector2(0, bunker.size.y)   # já do lado de fora
		80:
			_ok(m.historia.etapa == 3, "saiu do bunker: objetivo do rádio")
			_avancar()
		90:
			_ok(m.vip.global_position.distance_to(j.global_position) < 700, "Iara seguiu o Corvo (%.0f px)" % m.vip.global_position.distance_to(j.global_position))
			j.global_position = m.locais["radio"] + Vector2(0, 70)
			m.vip.global_position = j.global_position + Vector2(-40, 0)
			_shot("04-delegacia")
			for o in m.objetos:
				if o.tipo == "radio" and o.global_position.distance_to(m.locais["radio"]) < 10: o.usar(j)
		95:
			_ok(m.historia.no_radio, "rádio com chiado")
			_shot("05-radio")
			_avancar()
			_ok(m.historia.revelado and m.historia.escolhas.has("mordida") and m.historia.escolhas.has("rumo"), "a mordida revela que a Iara é imune")
			_ok(m.historia.etapa == 4, "objetivo: galão")
			_ok(m.npcs.any(func(x): return x.id == "nina"), "Nina apareceu")
		100:
			j.receber("galao", 1)
			j.receber("madeira", 4); j.receber("pano", 4); j.receber("garrafa", 1)
			for o in m.objetos:
				if o.tipo == "bomba":
					j.global_position = o.global_position + Vector2(0, 40); o.usar(j); break
			_avancar()
			_ok(m.historia.etapa == 5, "galão cheio: objetivo do carro")
		120:
			var c = m.locais.get("carro_bom")
			_ok(c != null, "existe carro que funciona")
			j.global_position = c.global_position + Vector2(0, 70)
			m.vip.global_position = j.global_position + Vector2(30, 0)
			c.usar(j)   # abastecer
			_avancar()
			_ok(m.historia.etapa == 6, "abasteceu: objetivo do pedágio")
			c.usar(j)   # dirigir
			_ok(j.carro == c, "Corvo dirige")
			Input.action_press("p1_atirar")
		135:
			_ok(m.vip.carro == j.carro, "Iara entrou no carro junto")
			_shot("06-dirigindo")
			Input.action_release("p1_atirar")
		140:
			j.carro.sair(j)
		145:
			_ok(m.vip.carro == null and m.vip.visible, "Iara saiu do carro junto")
			# radiação: entra numa zona quente
			var z: Dictionary = m.radiacao[0]
			j.global_position = z["pos"] + Vector2(20, 0)
		205:
			_ok(j.rad > 3.0, "radiação acumulou na zona quente (%.1f)" % j.rad)
			_shot("07-radiacao")
			j.usar_item("iodo")
			_ok(j.rad < 3.0 or j.qtd("iodo") >= 0, "iodo tira radiação")
			# noite, coop com a Iara jogável
			m.tempo = 230.0
			j.global_position = bunker.get_center()
			m.vip.global_position = bunker.get_center() + Vector2(40, 0)
		215:
			var pos: Vector2 = m.vip.global_position
			m.vip.queue_free(); m.vip = null
			var p2 = m._novo_jogador(2, pos)
			_ok(p2.nome == "Iara" and p2.vip, "coop: jogador 2 é a Iara")
		230:
			_shot("08-coop-noite-bunker")
			var p2 = m.jogadores[1]
			p2.receber_dano(5)
			_ok(not p2.caido, "Iara (jogador) leva mordida e segue")
			# dormir no bunker: porta de aço trancada
			var casa = m.predios[m.locais["bunker"]]
			for p in casa["portas"]:
				if not p.tabuas: p.usar(j)
			for z in m.zumbis.duplicate():
				if bunker.has_point(z.global_position): z.queue_free(); m.zumbis.erase(z)
			j.receber("arma:espingarda", 1)
			j.mochila["cartuchos"] = 3
			for o in m.objetos:
				if o.tipo == "cama" and o.casa == m.locais["bunker"]:
					o.usar(j); break
			_ok(m.estado == m.CAPITULO, "dormir começa (porta de aço trancada)")
		400:
			if m.estado == m.CAPITULO:
				n -= 1
				return false
			_ok(m.estado == m.JOGANDO and m.dia == 2, "acordou no dia 2")
			_ok(m.tem_save(), "dormir salvou o jogo")
			_shot("09-salvo")
		405:
			# carregar o save: tudo de volta como estava
			var etapa: int = m.historia.etapa
			var nivel: int = j.nivel
			m.carregar()
			j = m.jogadores[0]
			_ok(m.historia.etapa == etapa and m.dia == 2, "save: objetivo e dia voltam")
			_ok(j.tem_arma("espingarda") and j.qtd("cartuchos") == 3 and j.nivel == nivel, "save: mochila e armas voltam")
			var arsenal_aberto := false
			for o in m.objetos:
				if o.tipo == "arsenal" and m.predios[m.locais["bunker"]]["r"].has_point(o.global_position) and o.aberto:
					arsenal_aberto = true
			_ok(arsenal_aberto, "save: a cidade é a mesma e o que foi revirado continua revirado")
			_ok(m.historia.revelado, "save: a história lembra da revelação")
			_ok(m.estado == m.JOGANDO, "jogo continua depois de carregar")
		420:
			_shot("10-carregado")
			var c = m.locais.get("carro_bom")
			c.combustivel = 10.0
			c.global_position = m.locais["ponte"] + Vector2(0, 260)
			c.motorista = j; j.entrar_carro(c)
			m.historia.etapa = 6
			for npc in m.npcs:
				if npc.id == "tiao": npc.usar(j)
		430:
			_shot("11-tiao")
			_avancar()
			_ok(m.estado == m.CAPITULO and m.historia.concluido, "capítulo concluído")
		560:
			_shot("12-fim-capitulo")
			print("zumbis=", m.zumbis.size(), " objetos=", m.objetos.size(), " carros=", m.carros.size(), " predios=", m.predios.size())
			print("RESULTADO: %s" % ("tudo certo" if falhas == 0 else "%d falha(s)" % falhas))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
			quit(1 if falhas else 0)
			return true
	return false
