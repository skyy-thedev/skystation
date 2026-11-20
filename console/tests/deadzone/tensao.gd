extends SceneTree
## DEADZONE 0.7: ruído do jogador (os zumbis ouvem), tensão (mira treme), cigarro (acalma, tira vida)
## e as duplas do coop com histórias próprias.
var m: Node
var n := 0
var falhas := 0
var z: Node
var hp0 := 0.0
var tens0 := 0.0


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
	while m.zumbis.size() == antes and tent < 40:
		tent += 1
		m._nascer_zumbi(Vector2(randf_range(4, 60), randf_range(4, 60)) * m.T, "andarilho")
	var o: Node = m.zumbis[m.zumbis.size() - 1]
	o.global_position = p
	o.frente = frente
	return o


func _rua(j: Node) -> void:
	var rua: float = (m.QUADRA + 2) * m.T
	j.global_position = Vector2(rua, 9 * m.T)
	for c in m.carros:
		if c.global_position.distance_to(j.global_position) < 600.0:
			c.global_position += Vector2(3000, 0)
	for c in m.mundo.get_children():
		if c.get_script() == preload("res://deco.gd") and c.position.distance_to(j.global_position) < 600.0:
			c.position += Vector2(9000, 9000)


func _process(_d: float) -> bool:
	n += 1
	m.t_spawn = 999.0
	var j = m.jogadores[0]
	match n:
		5:
			m.estado = m.JOGANDO
			m.tempo = 60.0
			_longe()
			_rua(j)
			if m.vip:
				m.vip.global_position = j.global_position + Vector2(-2500, 0)
				m.vip.esperar = true
			_ok(j.personagem == "corvo" and j.fuma and j.qtd("cigarro") > 0, "Corvo começa com cigarro (fumante)")
			# zumbi de costas, a 100 px: não vê, mas ouve passos
			z = _novo(j.global_position + Vector2(0, 100), Vector2.DOWN)
			z.set_physics_process(false)
			Input.action_press("p1_esquerda")
		30:
			_ok(j.ruido > 100.0, "andando faz barulho (raio %.0f)" % j.ruido)
		70:
			Input.action_release("p1_esquerda")
			_ok(z.alerta and z.alvo == null, "o zumbi de costas ouviu os passos e veio ver (\"?\")")
			z.set_physics_process(true)
			_longe()
			Input.action_press("p1_agachar")
		72:
			Input.action_release("p1_agachar")
			Input.action_press("p1_cima")
		100:
			_ok(j.agachado and j.ruido < 60.0, "agachado quase não faz barulho (raio %.0f)" % j.ruido)
			Input.action_release("p1_cima")
			Input.action_press("p1_agachar")
		102:
			Input.action_release("p1_agachar")
			# tensão: zumbi caçando
			j.tensao = 0.0
			j.nicotina = 100.0
			z = _novo(j.global_position + Vector2(0, 140), Vector2.UP)
			z._avistar(j)
		220:
			_ok(j.tensao > 25.0, "caçado por um zumbi, a tensão sobe (%.0f)" % j.tensao)
			j.tensao = 100.0
			_ok(j.tremor_mira() > 0.2, "em pânico a mira foge (%.2f rad)" % j.tremor_mira())
			_longe()
			# cigarro
			tens0 = j.tensao
			j.hp = 80.0
			j.usar_item("cigarro")
		340:
			_ok(j.fumando > 0.0 and j.tensao < tens0, "fumando: a tensão cai (%.0f)" % j.tensao)
			j.tensao = 100.0
			_ok(j.tremor_mira() < 0.2, "com o cigarro a mão firma (%.2f rad)" % j.tremor_mira())
			hp0 = j.hp
			j.t_trago = 29.9
		350:
			_ok(j.hp <= hp0 - 1.0 + 0.01, "a cada 30 s fumando: -1 de vida (%.1f → %.1f)" % [hp0, j.hp])
			# abstinência: sem nicotina a tensão não desce de um piso
			j.fumando = 0.0
			j.nicotina = 0.0
			j.tensao = 0.0
		356:
			_ok(j.tensao > 20.0, "fumante sem nicotina fica tenso (%.0f)" % j.tensao)
			# coop: Corvo e Rocha
			m._nova_partida("coop_cr")
			m.estado = m.JOGANDO
			m._novo_jogador(2, m.jogadores[0].global_position + Vector2(40, 0))
		360:
			var a = m.jogadores[0]
			var b = m.jogadores[1]
			_ok(a.personagem == "corvo" and b.personagem == "rocha", "coop: Corvo e Rocha jogáveis")
			_ok(b.hp_max > a.hp_max and b.fuma, "Rocha: mais vida, também fuma")
			_ok(m.vip == null, "sem Iara controlada pelo jogo no coop")
			_ok(not m.npcs.any(func(o): return o.id == "rocha"), "no coop do Rocha ele não é NPC")
			_ok(m.historia.objetivo().begins_with("Peguem o equipamento"), "história do coop: \"%s\"" % m.historia.objetivo())
			m.historia.dizer([])
			m.estado = m.JOGANDO
			m.historia.evento("revirou", {"tipo": "arsenal", "obj": null})
		364:
			_ok(m.historia.etapa == 1, "arsenal → próximo objetivo do coop")
			# coop: Iara e Nina
			m._nova_partida("coop_in")
			m.estado = m.JOGANDO
			m._novo_jogador(2, m.jogadores[0].global_position + Vector2(40, 0))
		368:
			var a = m.jogadores[0]
			var b = m.jogadores[1]
			_ok(a.personagem == "iara" and a.vip and not a.fuma, "coop: Iara jogável (imune, não fuma)")
			_ok(b.personagem == "nina" and b.vel_mult > 1.0, "coop: Nina jogável (mais rápida)")
			_ok(m.historia.objetivo().begins_with("Saiam do bunker"), "fuga começa no bunker")
			a.usar_item("cigarro")
			_ok(a.uso.is_empty(), "a Iara não fuma")
		372:
			print("RESULTADO: %s" % ("tudo certo" if falhas == 0 else "%d falha(s)" % falhas))
			quit(1 if falhas else 0)
	return false
