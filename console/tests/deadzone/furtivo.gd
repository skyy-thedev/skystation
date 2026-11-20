extends SceneTree
## DEADZONE 0.6: furtividade (cone de visão, "!", fases de alerta), abate silencioso, agachar,
## uso de item com tempo (e interrompido por dano) e a mochila em grade.
var m: Node
var n := 0
var z: Node
var falhas := 0
var hp0 := 0.0
var viu := false
var furtivo_ok := false
var evasao := false
var apertou := false
var alerta := false


func _initialize() -> void:
	Engine.max_fps = 60
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _ok(c: bool, msg: String) -> void:
	print(("  ok  " if c else "FALHOU ") + msg)
	if not c:
		falhas += 1


func _longe() -> void:
	for o in m.zumbis:
		o.global_position = Vector2(-9000, -9000)
		o.alvo = null
		o.alerta = false
		o.suspeita = 0.0


func _novo(p: Vector2, frente: Vector2) -> Node:
	var antes: int = m.zumbis.size()
	m._nascer_zumbi(p, "andarilho")
	var tent := 0
	while m.zumbis.size() == antes and tent < 40:      # o lugar estava ocupado: nasce em outro e vem
		tent += 1
		m._nascer_zumbi(Vector2(randf_range(4, 60), randf_range(4, 60)) * m.T, "andarilho")
	var o: Node = m.zumbis[m.zumbis.size() - 1]
	o.global_position = p
	o.frente = frente
	return o


func _process(_d: float) -> bool:
	n += 1
	var j = m.jogadores[0]
	m.t_spawn = 999.0                 # ninguém nasce no meio do teste
	if n > 200 and n < 650:
		evasao = evasao or m.fase_alerta in ["EVASÃO", "CAUTELA"]
	if n >= 6 and n <= 20 and not apertou and is_instance_valid(z):
		z.global_position = j.global_position + Vector2(36, 0)   # segura o zumbi no lugar
		z.frente = Vector2.RIGHT
		if m.alvo_furtivo(j) == z:
			furtivo_ok = true
			apertou = true
			Input.action_press("p1_golpe")
	if n > 16 and n < 200 and is_instance_valid(z):
		viu = viu or z.alvo == j
		alerta = alerta or m.fase_alerta == "ALERTA"
	match n:
		5:
			m.estado = m.JOGANDO
			m.tempo = 60.0
			_longe()
			# meio de uma rua em pé (sem parede entre nós e o zumbi), longe de carros
			var rua: float = (m.QUADRA + 2) * m.T
			j.global_position = Vector2(rua, 9 * m.T)
			for c in m.carros:
				if c.global_position.distance_to(j.global_position) < 500.0:
					c.global_position += Vector2(3000, 0)
			for c in m.mundo.get_children():
				if c.get_script() == preload("res://deco.gd") and c.position.distance_to(j.global_position) < 450.0:
					c.position += Vector2(9000, 9000)
			if m.vip:
				m.vip.global_position = j.global_position + Vector2(-2000, 0)
				m.vip.esperar = true
			# zumbi de costas, colado
			z = _novo(j.global_position + Vector2(36, 0), Vector2.RIGHT)
			z.set_physics_process(false)
		22:
			Input.action_release("p1_golpe")
			_ok(furtivo_ok, "zumbi de costas e colado: dá para abater em silêncio")
		24:
			_ok(not is_instance_valid(z) or z.hp <= 0.0 or not m.zumbis.has(z), "R1 por trás abate na hora")
			_ok(m.fase_alerta == "", "abate silencioso não dispara alerta")
			# zumbi de frente, a 200 px, de dia
			_longe()
			z = _novo(j.global_position + Vector2(0, 200), Vector2.UP)
		30:
			_ok(z.alvo == null, "ver não é caçar: no começo ele só desconfia")
		200:
			_ok(viu, "depois de um tempo te vendo: \"!\" e caça")
			_ok(alerta, "fase ALERTA no radar")
			# some da vista
			_longe()                  # todo mundo some (os zumbis longe demais também são reciclados pelo jogo)
		650:
			_ok(evasao, "perdeu de vista: EVASÃO, depois CAUTELA")
			_longe()
			# zumbi de costas a 150 px: não vê
			z = _novo(j.global_position + Vector2(0, 150), Vector2.DOWN)
			z.set_physics_process(false)
			z.t_olhar = 0.0
		690:
			for k in 6:
				z._olhar()
		710:
			_ok(z.alvo == null and z.suspeita < 0.3, "fora do cone (atrás dele) ele não te vê")
			_longe()
			# agachar
			Input.action_press("p1_agachar")
		712:
			Input.action_release("p1_agachar")
		714:
			_ok(j.agachado, "R3 agacha")
			# bandagem leva tempo
			j.hp = 40.0
			j.mochila["bandagem"] = 2
			Input.action_press("p1_curar")
		716:
			Input.action_release("p1_curar")
			hp0 = j.hp
			_ok(not j.uso.is_empty() and j.hp == hp0, "○ começa a enfaixar (a vida ainda não subiu)")
		810:
			_ok(j.uso.is_empty() and j.hp > hp0 and j.qtd("bandagem") == 1, "terminou de enfaixar: vida subiu, gastou 1")
			j.usar_item("bandagem")
		820:
			j.receber_dano(5.0)
			_ok(j.uso.is_empty() and j.qtd("bandagem") == 1, "levar dano interrompe o uso (não gasta)")
			# mochila em grade
			m.estado = m.MOCHILA
			m.menu_dono = 1
			m.mochila_aba = 0
			m.menu_sel = 0
			j.mochila["pano"] = 1
			j.mochila["madeira"] = 1
			j.mochila["pilhas"] = 1
		822: Input.action_press("p1_m_dir")
		824:
			Input.action_release("p1_m_dir")
			_ok(m.menu_sel == 1, "→ anda uma carta")
			Input.action_press("p1_aba_dir")
		826:
			Input.action_release("p1_aba_dir")
			_ok(m.mochila_aba == 1 and m.menu_sel == 0, "R1 troca para a aba Criar")
		840:
			print("RESULTADO: %s" % ("tudo certo" if falhas == 0 else "%d falha(s)" % falhas))
			quit(1 if falhas else 0)
	return false
