extends SceneTree
var m: Node
var n := 0
var arm
var z
var falhas := 0
func _initialize() -> void:
	Engine.max_fps = 60
	m = load("res://main.tscn").instantiate()
	root.add_child(m)
func _ok(c: bool, msg: String) -> void:
	print(("  ok  " if c else "FALHOU ") + msg)
	if not c:
		falhas += 1
func _process(_d: float) -> bool:
	n += 1
	var j = m.jogadores[0]
	match n:
		5:
			m.estado = m.JOGANDO
			for o in m.objetos:
				if o.tipo == "armario" and not o.aberto:
					arm = o; break
			j.global_position = arm.global_position + Vector2(0, 30)
		8: Input.action_press("p1_interagir")
		80:
			Input.action_release("p1_interagir")
			_ok(arm.aberto, "segurar ✕ revira o armário")
		81: Input.action_press("p1_luz")
		83:
			Input.action_release("p1_luz")
			_ok(j.luz_on, "↑ liga a lanterna")
		85:
			j.arma = "pistola"; j.pentes["pistola"] = 3; j.mochila["balas_9mm"] = 2
			j.global_position = Vector2(38 * 64, 2 * 64)
			for zz in m.zumbis.duplicate(): zz.queue_free()
			m.zumbis.clear()
			m._nascer_zumbi(j.global_position + Vector2(160, 0))
			z = m.zumbis[-1] if not m.zumbis.is_empty() else null
			j.mira = Vector2.RIGHT
		87: Input.action_press("p1_atirar")
		110:
			Input.action_release("p1_atirar")
			_ok(z == null or not is_instance_valid(z) or z.hp < z.hp_max, "R2 atira e acerta o zumbi")
			_ok(int(j.pentes["pistola"]) < 3, "gasta bala do pente (%d)" % j.pentes["pistola"])
		111: Input.action_press("p1_recarregar")
		113: Input.action_release("p1_recarregar")
		200:
			_ok(int(j.pentes["pistola"]) > 0 or j.qtd("balas_9mm") == 0, "□ recarrega")
		201: Input.action_press("p1_mochila")
		203:
			Input.action_release("p1_mochila")
			_ok(m.estado == m.MOCHILA, "△ abre a mochila")
		204: Input.action_press("p1_mochila")
		206:
			Input.action_release("p1_mochila")
			_ok(m.estado == m.JOGANDO, "△ fecha a mochila")
			print("RESULTADO: %s" % ("tudo certo" if falhas == 0 else "%d falha(s)" % falhas))
			quit(1 if falhas else 0)
			return true
	return false
