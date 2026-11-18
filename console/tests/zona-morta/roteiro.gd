extends SceneTree
var m: Node
var n := 0
var log := []
func _initialize() -> void:
	Engine.max_fps = 60   # sem tela (CI) os quadros não esperam a TV: segura em 60 por segundo
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
var falhas := 0
func _shot(nome: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("ZM_FOTOS") == "":
		return
	root.get_texture().get_image().save_png(OS.get_environment("ZM_FOTOS") + "/" + nome + ".png")
func _ok(c: bool, msg: String) -> void:
	print(("  ok  " if c else "FALHOU ") + msg)
	if not c:
		falhas += 1
func _process(_d: float) -> bool:
	n += 1
	var j = m.jogadores[0] if not m.jogadores.is_empty() else null
	match n:
		20: _shot("01-titulo")
		21:
			Input.action_press("p1_interagir")
		23:
			Input.action_release("p1_interagir")
		40:
			_ok(m.estado == m.CONVERSA, "começa com a conversa de abertura")
			_shot("02-conversa")
		41:
			for i in 10: m.historia.comando("ok")
			_ok(m.estado == m.JOGANDO, "conversa termina e o jogo começa")
		60: _shot("03-casa-dia")
		61:
			# revira dois móveis da casa inicial
			var feitos := 0
			for o in m.objetos:
				if o.tipo in ["armario", "geladeira"] and o.global_position.distance_to(j.global_position) < 400 and feitos < 2:
					o.usar(j); feitos += 1
			_ok(j.tem_arma("taco"), "taco garantido na casa inicial")
			_ok(m.historia.etapa == 1, "objetivo avança para o rádio")
		62:
			for i in 10: m.historia.comando("ok")
		70:
			# leva até o rádio
			j.global_position = m.locais["radio"] + Vector2(0, 60)
		90:
			_shot("04-delegacia")
			for o in m.objetos:
				if o.tipo == "radio": o.usar(j)
		95:
			_shot("05-radio-escolha")
			m.historia.comando("ok"); m.historia.comando("ok"); m.historia.comando("ok")
			m.historia.comando("baixo")  # mentira
			m.historia.comando("ok")
			for i in 10: m.historia.comando("ok")
			_ok(m.historia.escolhas.get("radio") == "mentira", "escolha do rádio gravada")
			_ok(m.historia.etapa == 2, "objetivo: gasolina (etapa=%d)" % m.historia.etapa)
			_ok(m.npcs.any(func(x): return x.id == "nina"), "Nina apareceu")
		100:
			j.receber("galao", 1)
			j.receber("madeira", 4); j.receber("pano", 4); j.receber("garrafa", 1); j.receber("sucata", 3)
			for o in m.objetos:
				if o.tipo == "bomba":
					j.global_position = o.global_position + Vector2(0, 40); o.usar(j); break
			_ok(j.gasolina >= 10.0, "galão cheio no posto")
			for i in 10: m.historia.comando("ok")
			_ok(m.historia.etapa == 3, "objetivo: carro (etapa=%d)" % m.historia.etapa)
		110:
			m.estado = m.MOCHILA; m.menu_dono = 1; m.mochila_aba = 1; m.menu_sel = 3
		115: _shot("06-mochila-criar")
		116:
			m.estado = m.JOGANDO
			# cria molotov e tocha
			_ok(m.pode_criar(j, m.D.RECEITAS[3]), "dá para criar molotov com gasolina")
		120:
			var c = m.locais.get("carro_bom")
			_ok(c != null, "existe carro que funciona")
			j.global_position = c.global_position + Vector2(0, 70)
			c.usar(j)   # abastecer
			for i in 10: m.historia.comando("ok")
			_ok(c.combustivel > 5.0, "carro abastecido")
			_ok(m.historia.etapa == 4, "objetivo: ponte")
			c.usar(j)   # dirigir
			_ok(j.carro == c, "entrou no carro")
			Input.action_press("p1_atirar"); Input.action_press("p1_direita")
		160:
			_shot("07-dirigindo")
			Input.action_release("p1_atirar"); Input.action_release("p1_direita")
		170:
			m.tempo = 230.0
			j.carro.sair(j)
			j.luz_on = true
			for i in 6: m._nascer_zumbi(j.global_position + Vector2(260 + i * 30, -120 + i * 40))
		200:
			_shot("08-noite-lanterna")
			j.usar_item("tocha") if j.tem("tocha") else null
		210:
			m._novo_jogador(2, j.global_position + Vector2(80, 30))
			_ok(m.jogadores.size() == 2, "coop: Lia entrou")
		240:
			_shot("09-coop-noite")
			m.jogadores[1].receber_dano(999)
			_ok(m.jogadores[1].caido, "Lia caída (coop)")
			m.jogadores[1].usar(j)
			_ok(not m.jogadores[1].caido, "Davi reanima a Lia")
		250:
			# barricar e dormir na casa inicial
			var casa = m.predios[m.locais["casa_inicial"]]
			for p in casa["portas"]:
				if not p.tabuas: p.barricar()
			for jj in m.jogadores:
				jj.global_position = casa["r"].get_center()
			for z in m.zumbis.duplicate():
				if casa["r"].has_point(z.global_position): z.queue_free(); m.zumbis.erase(z)
			for o in m.objetos:
				if o.tipo == "cama" and o.casa == m.locais["casa_inicial"]:
					o.usar(j)
			_ok(m.estado == m.CAPITULO, "dormir (barricado) começa")
		260: _shot("10-dormindo")
		420:
			if m.estado == m.CAPITULO or m.tempo > 250.0:   # ainda dormindo / amanhecendo
				n -= 1
				return false
			_ok(m.estado == m.JOGANDO and m.dia == 2, "acordou no dia 2 (estado=%d dia=%d tempo=%.1f)" % [m.estado, m.dia, m.tempo])
			_shot("11-casa-barricada")
		430:
			var c = m.locais.get("carro_bom")
			c.global_position = m.locais["ponte"] + Vector2(0, 260)
			c.motorista = j; j.entrar_carro(c)
			m.jogadores[1].global_position = m.locais["ponte"] + Vector2(60, 200)
			m.historia.etapa = 4
			for npc in m.npcs:
				if npc.id == "tiao": npc.usar(j)
		440:
			_shot("12-tiao")
			m.historia.comando("ok"); m.historia.comando("ok"); m.historia.comando("ok"); m.historia.comando("ok")
			m.historia.comando("ok")   # primeira opção
			for i in 6: m.historia.comando("ok")
			_ok(m.estado == m.CAPITULO and m.historia.concluido, "capítulo concluído")
		560:
			_shot("13-fim-capitulo")
			print("zumbis=", m.zumbis.size(), " objetos=", m.objetos.size(), " carros=", m.carros.size(), " predios=", m.predios.size())
			print("RESULTADO: %s" % ("tudo certo" if falhas == 0 else "%d falha(s)" % falhas))
			quit(1 if falhas else 0)
			return true
	return false
