extends CharacterBody2D
## Um sobrevivente (Davi = jogador 1, Lia = jogador 2 no coop). Cada um lê o próprio controle pelas ações
## "p1_…" / "p2_…" que o main.gd cria. Mochila, armas, lanterna/tocha, gasolina, carro e "caído" no coop.

const D := preload("res://dados.gd")
const VEL := 185.0
const VEL_CORRENDO := 295.0

var main: Node2D
var n := 1
var nome := "Corvo"
var vip := false                        # jogador 2 no coop é a Iara: mordida não transforma, radiação não pega
var rad := 0.0                          # radiação acumulada (0–100)
var cor_roupa := Color("3a6ea5")
var cor_cabelo := Color("3b2a1a")
var hp := 100.0
var hp_max := 100.0
var estamina := 100.0
var fome := 100.0
var nivel := 1
var xp := 0
var forca := 1.0

var mochila := {}                       # item -> quantidade
var armas: Array = ["punhos"]
var arma := "punhos"
var pentes := {}                        # arma de fogo -> balas no pente
var gasolina := 0.0                     # litros no galão
var bateria := 100.0                    # lanterna
var luz_on := false
var tocha_t := 0.0                      # segundos de tocha acesa (0 = usando a lanterna)

var mira := Vector2.RIGHT
var t_ataque := 0.0
var t_recarga := 0.0
var t_dano := 0.0
var golpe_anim := 0.0
var tiros: Array = []                   # rastros {de, ate, t}
var passo := 0.0
var mouse_t := 0.0

var carro: Node = null
var caido := false
var t_caido := 0.0
var interacao := {}                     # {obj, t, total}
var perto: Object = null                # o que dá para usar agora (para o HUD)

var lanterna: PointLight2D
var aura: PointLight2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	var forma := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11
	forma.shape = c
	add_child(forma)
	lanterna = main.nova_luz(Color(1.0, 0.96, 0.85), 2.5, true, true)
	lanterna.position = Vector2(0, -6)
	add_child(lanterna)
	lanterna.visible = false
	aura = main.nova_luz(Color(1.0, 0.9, 0.75), 0.5, false)
	aura.energy = 0.55
	add_child(aura)


func p(acao: String) -> String:
	return "p%d_%s" % [n, acao]


func controle() -> Dictionary:
	var mover := Input.get_vector(p("esquerda"), p("direita"), p("cima"), p("baixo"))
	return {
		"mover": mover,
		"acelera": Input.get_action_strength(p("atirar")),
		"freia": Input.get_action_strength(p("correr")),
		"buzina": Input.is_action_just_pressed(p("recarregar")),
	}


# ---------------------------------------------------------------- mochila

func qtd(item: String) -> int:
	return int(mochila.get(item, 0))


func tem(item: String) -> bool:
	return qtd(item) > 0


func tem_arma(a: String) -> bool:
	return armas.has(a)


func gastar(item: String, q: int) -> void:
	mochila[item] = qtd(item) - q
	if mochila[item] <= 0:
		mochila.erase(item)


func receber(item: String, q: int, avisar := true) -> void:
	if item.begins_with("arma:"):
		var a := item.substr(5)
		if armas.has(a):
			var m: String = D.ARMAS[a].get("municao", "")
			if m != "":
				receber(m, 2 + randi() % 3)      # arma repetida: aproveita as balas
			elif avisar:
				main.aviso("%s: outra %s (já tinha)" % [nome, D.nome(a)], Color(1, 1, 1, 0.7))
			return
		armas.append(a)
		if D.ARMAS[a].has("pente"):
			pentes[a] = randi_range(0, 2)
		if avisar:
			main.aviso("%s achou: %s!" % [nome, D.nome(a)], Color("ffd166"))
		if _melhor(a):
			arma = a
		main.historia.evento("arma", {"arma": a})
		return
	mochila[item] = qtd(item) + q
	if avisar:
		main.aviso("%s: +%d %s" % [nome, q, D.nome(item)], Color("7ff0c4"))
		main.sons.tocar("pegar", null, -8.0)
	main.historia.evento("item", {"item": item})


func _melhor(a: String) -> bool:
	var ordem := ["punhos", "faca", "taco", "machado", "pistola", "espingarda", "rifle"]
	return ordem.find(a) > ordem.find(arma) and (not D.ARMAS[a].has("municao") or arma == "punhos")


func melhor_corpo() -> String:
	var m := "punhos"
	for a in ["faca", "taco", "machado"]:
		if armas.has(a) and D.ARMAS[a]["dano"] > D.ARMAS[m]["dano"]:
			m = a
	return m


func trocar_arma(dir: int) -> void:
	var i := armas.find(arma)
	arma = armas[wrapi(i + dir, 0, armas.size())]
	t_recarga = 0.0
	main.aviso("%s: %s" % [nome, D.nome(arma)], Color(1, 1, 1, 0.8))


func usar_item(item: String) -> void:
	var info: Dictionary = D.ITENS.get(item, {})
	match info.get("tipo", ""):
		"comida":
			gastar(item, 1)
			fome = minf(100.0, fome + info.get("fome", 0))
			hp = minf(hp_max, hp + info.get("cura", 0))
			if info.has("enjoo"):
				hp = maxf(1.0, hp - info["enjoo"])
				main.aviso("%s comeu carne crua e passou mal." % nome, Color("ff8a8a"))
			else:
				main.aviso("%s comeu: %s" % [nome, info["nome"]], Color("7ff0c4"))
		"cura":
			if info.has("rad"):
				if rad <= 0.0:
					main.aviso("Sem radiação no corpo", Color(1, 1, 1, 0.7))
					return
				gastar(item, 1)
				rad = maxf(0.0, rad - info["rad"])
				main.aviso("%s tomou iodo: radiação %d" % [nome, int(rad)], Color("7ff0c4"))
				return
			if hp >= hp_max:
				main.aviso("Vida já está cheia", Color(1, 1, 1, 0.7))
				return
			gastar(item, 1)
			hp = minf(hp_max, hp + info["cura"])
			main.aviso("%s: +%d de vida" % [nome, info["cura"]], Color("7ff0c4"))
		"luz":
			if item == "pilhas":
				gastar(item, 1)
				bateria = 100.0
				main.aviso("Lanterna com pilhas novas", Color("ffd166"))
			elif item == "tocha":
				gastar(item, 1)
				tocha_t = 150.0
				luz_on = true
				main.aviso("Tocha acesa", Color("ff9f43"))


func xp_proximo() -> int:
	return 40 + nivel * 30


func ganhar_xp(q: int) -> void:
	xp += q
	while xp >= xp_proximo():
		xp -= xp_proximo()
		nivel += 1
		hp_max += 10
		hp = hp_max
		estamina = 100
		forca += 0.12
		main.aviso("%s subiu para o nível %d! Mais vida e golpe mais forte" % [nome, nivel], Color("ffd166"))


# ---------------------------------------------------------------- carro e coop

func entrar_carro(c: Node) -> void:
	carro = c
	visible = false
	collision_layer = 0
	collision_mask = 0
	interacao = {}


func sair_carro(c: Node) -> void:
	carro = null
	visible = true
	collision_layer = 4
	collision_mask = 1 | 2
	global_position = c.global_position + Vector2.from_angle(c.angulo + PI / 2) * 60.0


func pode_ser_mordido() -> bool:
	return carro == null and not caido and hp > 0.0


func receber_dano(q: float, piscar := true) -> void:
	if caido or carro:
		return
	hp -= q
	if piscar:
		t_dano = 0.25
		main.tremer(4.0)
		main.sons.tocar("dor", global_position, -4.0, 1.25 if vip else 0.9)
		if vip:
			main.historia.evento("iara_mordida", {})
	interacao = {}
	if hp <= 0.0:
		hp = 0.0
		main.jogador_caiu(self)


# ---------------------------------------------------------------- interação (✕ segurado)

func rotulo(j: Node) -> String:
	return "Reanimar " + nome if caido and j != self else ""


func disponivel(j: Node) -> bool:
	return rotulo(j) != ""


func alcance() -> float:
	return 60.0


func tempo(_j: Node) -> float:
	return 2.2


func usar(_j: Node) -> void:
	caido = false
	hp = hp_max * 0.35
	main.aviso("%s levantou!" % nome, Color("7ff0c4"))


func _procurar() -> void:
	perto = null
	var menor := 1e9
	for o in main.interativos():
		if o == self or not is_instance_valid(o):
			continue
		var dist: float = o.global_position.distance_to(global_position)
		if dist < o.alcance() and dist < menor and o.rotulo(self) != "":
			perto = o
			menor = dist


# ---------------------------------------------------------------- laço

func _unhandled_input(e: InputEvent) -> void:
	if n == 1 and e is InputEventMouseMotion:
		mouse_t = 2.0


func _physics_process(d: float) -> void:
	if not main.jogando():
		return
	t_ataque = maxf(0.0, t_ataque - d)
	t_dano = maxf(0.0, t_dano - d)
	golpe_anim = maxf(0.0, golpe_anim - d)
	mouse_t = maxf(0.0, mouse_t - d)
	for t in tiros:
		t["t"] -= d
	tiros = tiros.filter(func(t): return t["t"] > 0.0)
	_luzes(d)
	fome = maxf(0.0, fome - 0.35 * d)
	if fome <= 0.0 and not caido:
		receber_dano(1.0 * d, false)
	# radiação: acumula nas zonas quentes; acima de 50 começa a tirar vida (a Iara é imune)
	if not vip and carro == null:
		rad = minf(100.0, rad + main.radiacao_em(global_position) * 9.0 * d)
	if rad > 50.0 and not caido:
		receber_dano((rad - 50.0) / 50.0 * 1.6 * d, false)

	if caido:
		t_caido -= d
		if t_caido <= 0.0:
			main.jogador_morreu(self)
		queue_redraw()
		return
	if carro:
		global_position = carro.global_position
		if Input.is_action_just_pressed(p("interagir")):
			carro.sair(self)
		return

	var c := controle()
	var mover: Vector2 = c["mover"]
	var correndo := Input.is_action_pressed(p("correr")) and mover.length() > 0.2 and estamina > 1.0
	estamina = clampf(estamina + (-26.0 if correndo else 15.0) * d, 0.0, 100.0)
	velocity = mover * (VEL_CORRENDO if correndo else VEL)
	move_and_slide()
	main.coleira(self)
	if mover.length() > 0.2:
		passo += d * (14.0 if correndo else 9.0)
		main.sons.passo(self, correndo)
		if correndo:
			main.barulho(global_position, 240.0)

	# mira: analógico direito > mouse (jogador 1) > direção do movimento
	var dev: int = main.dispositivo(n)
	var rs := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)) if dev >= 0 else Vector2.ZERO
	if rs.length() > 0.35:
		mira = rs.normalized()
	elif n == 1 and mouse_t > 0.0:
		mira = (get_global_mouse_position() - global_position).normalized()
	elif mover.length() > 0.2:
		mira = mover.normalized()

	if t_recarga > 0.0:
		t_recarga -= d
		if t_recarga <= 0.0:
			_terminar_recarga()

	if Input.is_action_pressed(p("atirar")) and t_ataque <= 0.0:
		atacar(arma)
	if Input.is_action_just_pressed(p("golpe")) and t_ataque <= 0.0:
		atacar(melhor_corpo())
	if Input.is_action_just_pressed(p("recarregar")):
		recarregar()
	if Input.is_action_just_pressed(p("curar")):
		if tem("bandagem"):
			usar_item("bandagem")
		elif tem("kit_medico"):
			usar_item("kit_medico")
		else:
			main.aviso("%s: sem bandagem" % nome, Color("ff8a8a"))
	if Input.is_action_just_pressed(p("arremessar")):
		arremessar()
	if Input.is_action_just_pressed(p("arma_prox")):
		trocar_arma(1)
	if Input.is_action_just_pressed(p("arma_ant")):
		trocar_arma(-1)
	if Input.is_action_just_pressed(p("luz")):
		if tocha_t <= 0.0 and bateria <= 0.0:
			main.aviso("Lanterna sem pilha: use pilhas ou acenda uma tocha", Color("ff8a8a"))
		else:
			luz_on = not luz_on
			main.sons.tocar("lanterna", null, -6.0)
	if Input.is_action_just_pressed(p("tocha")) and tocha_t <= 0.0:
		if tem("tocha"):
			usar_item("tocha")
		else:
			main.aviso("%s: sem tocha (crie com madeira e pano)" % nome, Color("ff8a8a"))

	# ✕: segurar para usar o que estiver perto
	_procurar()
	if interacao.is_empty():
		if perto and Input.is_action_just_pressed(p("interagir")) and perto.disponivel(self):
			interacao = {"obj": perto, "t": 0.0, "total": perto.tempo(self)}
	else:
		var o: Object = interacao["obj"]
		if not is_instance_valid(o) or not Input.is_action_pressed(p("interagir")) \
				or o.global_position.distance_to(global_position) > o.alcance() + 20.0:
			interacao = {}
		else:
			interacao["t"] += d
			if interacao["t"] >= interacao["total"]:
				interacao = {}
				o.usar(self)
	queue_redraw()


func _luzes(d: float) -> void:
	if tocha_t > 0.0:
		tocha_t -= d
		if tocha_t <= 0.0:
			main.aviso("%s: a tocha apagou" % nome, Color("ff9f43"))
			luz_on = false
	elif luz_on:
		bateria = maxf(0.0, bateria - 0.55 * d)
		if bateria <= 0.0:
			luz_on = false
			main.aviso("%s: a lanterna apagou (sem pilha)" % nome, Color("ff8a8a"))
	var noite: float = main.noite()
	var com_tocha := tocha_t > 0.0
	lanterna.visible = luz_on and not com_tocha and carro == null
	lanterna.rotation = mira.angle()
	var fraca := 0.55 if bateria < 15.0 and randf() < 0.15 else 1.0
	lanterna.energy = (0.25 + noite * 1.25) * fraca
	aura.visible = carro == null
	if com_tocha:
		aura.color = Color(1.0, 0.6, 0.28)
		aura.texture_scale = 1.6
		aura.energy = 0.9 + sin(Time.get_ticks_msec() * 0.012) * 0.1
	else:
		aura.color = Color(1.0, 0.9, 0.75)
		aura.texture_scale = 0.45
		aura.energy = 0.25 + noite * 0.35


func luz_chamativa() -> bool:
	## lanterna/tocha acesa de noite: os zumbis te veem de mais longe
	return (luz_on or tocha_t > 0.0) and carro == null


# ---------------------------------------------------------------- combate

func atacar(a: String) -> void:
	var info: Dictionary = D.ARMAS[a]
	if info.get("corpo", false):
		if estamina < 5.0:
			return
		t_ataque = info["cad"]
		golpe_anim = 0.18
		estamina -= info["folego"]
		var dano: float = info["dano"] * forca
		var acertou := false
		for z in main.zumbis:
			var v: Vector2 = z.global_position - global_position
			if v.length() < info["alcance"] and absf(mira.angle_to(v)) < 1.1:
				z.levar_dano(dano, v.normalized() * 320.0)
				acertou = true
		main.sons.tocar("acerto" if acertou else "golpe", global_position, -2.0 if acertou else -8.0)
		main.barulho(global_position, info["barulho"])
		return
	if t_recarga > 0.0:
		return
	if int(pentes.get(a, 0)) <= 0:
		main.sons.tocar("seco", global_position, -6.0)
		recarregar()
		t_ataque = 0.3
		return
	pentes[a] = int(pentes[a]) - 1
	t_ataque = info["cad"]
	var base: Vector2 = main.mira_assistida(global_position, mira, info["alcance"])
	for k in info["chumbos"]:
		var dir := base.rotated(randf_range(-info["abertura"], info["abertura"]))
		var ate: Vector2 = global_position + dir * info["alcance"]
		var q := PhysicsRayQueryParameters2D.create(global_position, ate, 1 | 2, [get_rid()])
		q.hit_from_inside = true
		var r := get_world_2d().direct_space_state.intersect_ray(q)
		var fim := ate
		if r:
			fim = r["position"]
			if r["collider"].has_method("levar_dano") and r["collider"] != self:
				r["collider"].levar_dano(info["dano"], dir * 240.0)
		tiros.append({"de": global_position, "ate": fim, "t": 0.07})
	main.barulho(global_position, info["barulho"])
	main.sons.tocar("tiro_" + a, global_position, 0.0 if a == "pistola" else 3.0)
	main.tremer(4.0 if a == "pistola" else 8.0)


func recarregar() -> void:
	var info: Dictionary = D.ARMAS[arma]
	if not info.has("pente") or t_recarga > 0.0:
		return
	if int(pentes.get(arma, 0)) >= info["pente"]:
		return
	if qtd(info["municao"]) <= 0:
		main.aviso("%s: sem %s" % [nome, D.nome(info["municao"]).to_lower()], Color("ff8a8a"))
		return
	t_recarga = info["recarga"]
	main.sons.tocar("recarga", global_position, -4.0)


func _terminar_recarga() -> void:
	var info: Dictionary = D.ARMAS[arma]
	if not info.has("pente"):
		return
	var falta: int = info["pente"] - int(pentes.get(arma, 0))
	var q: int = mini(falta, qtd(info["municao"]))
	pentes[arma] = int(pentes.get(arma, 0)) + q
	gastar(info["municao"], q)


func arremessar() -> void:
	if not tem("molotov"):
		main.aviso("%s: sem molotov (crie com garrafa, pano e gasolina)" % nome, Color("ff8a8a"))
		return
	gastar("molotov", 1)
	main.sons.tocar("vidro", global_position + mira * 280.0)
	main.molotov(global_position + mira * 280.0)


# ---------------------------------------------------------------- desenho (a origem é o pé)

func _draw() -> void:
	var lado := mira.orthogonal()
	var andando := velocity.length() > 10.0
	var bal := sin(passo) * 3.0 if andando else 0.0
	draw_circle(Vector2(2, 2), 13, Color(0, 0, 0, 0.35))
	if caido:
		draw_rect(Rect2(-22, -10, 44, 16), cor_roupa.darkened(0.3))
		draw_circle(Vector2(20, -4), 8, Color("e0b48a"))
		draw_string(ThemeDB.fallback_font, Vector2(-40, -24), "%s caído: %.0f s" % [nome, t_caido], HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color("ff8a8a"))
		return
	var corpo := Vector2(0, -18)
	draw_line(lado * 5 + Vector2(0, -2), lado * 5 + mira * bal + Vector2(0, -12), Color("2b2d42"), 6, true)
	draw_line(-lado * 5 + Vector2(0, -2), -lado * 5 - mira * bal + Vector2(0, -12), Color("2b2d42"), 6, true)
	# mochila atrás quando ele olha para baixo, na frente quando olha para cima
	if mira.y > 0.0:
		draw_circle(corpo - mira * 8 + Vector2(0, -2), 9, Color("6b4f2a"))
	draw_circle(corpo, 12, cor_roupa if t_dano <= 0.0 else Color("ff6b6b"))
	if mira.y <= 0.0:
		draw_circle(corpo - mira * 8 + Vector2(0, -2), 9, Color("6b4f2a"))
	var mao := corpo + lado * 8 + mira * 6
	var info: Dictionary = D.ARMAS[arma]
	if golpe_anim > 0.0:
		var arma_g := melhor_corpo() if not info.get("corpo", false) else arma
		var a := mira.angle() + lerpf(-1.1, 1.1, 1.0 - golpe_anim / 0.18)
		var comp := 40.0 if arma_g in ["taco", "machado"] else 24.0
		draw_line(corpo + Vector2.from_angle(a) * 8, corpo + Vector2.from_angle(a) * comp, Color("c9a26b"), 5, true)
		if arma_g == "machado":
			draw_circle(corpo + Vector2.from_angle(a) * comp, 6, Color("9aa3ab"))
	elif not info.get("corpo", false):
		var comp := 18.0 if arma == "pistola" else 30.0
		draw_line(mao, mao + mira * comp, Color("1d1d1d"), 4 if arma == "pistola" else 5, true)
	elif arma != "punhos":
		draw_line(mao, mao + mira * 18 + Vector2(0, -10), Color("c9a26b"), 4, true)
	if tocha_t > 0.0:
		var t := corpo - lado * 9 + mira * 6
		draw_line(t + Vector2(0, 6), t + Vector2(0, -10), Color("5a3d22"), 4)
		draw_circle(t + Vector2(0, -14), 5 + sin(Time.get_ticks_msec() * 0.02) * 1.5, Color(1, 0.6, 0.15, 0.95))
	var cab := corpo + Vector2(0, -14) + mira * 2
	draw_circle(cab, 8, Color("e0b48a"))
	draw_circle(cab - mira * 2 + Vector2(0, -3), 7, cor_cabelo)
	for t in tiros:
		draw_line(to_local(t["de"]) + Vector2(0, -18) + mira * 20, to_local(t["ate"]) + Vector2(0, -12), Color(1, 0.9, 0.5, 0.9), 2, true)
		draw_circle(to_local(t["de"]) + Vector2(0, -18) + mira * 22, 6, Color(1, 0.85, 0.4, 0.8))
	if not interacao.is_empty():
		var f: float = interacao["t"] / interacao["total"]
		draw_rect(Rect2(-24, -64, 48, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-24, -64, 48 * f, 6), Color("ffd166"))
	if main.jogadores.size() > 1:
		draw_string(ThemeDB.fallback_font, Vector2(-20, -70), "P%d" % n, HORIZONTAL_ALIGNMENT_CENTER, 40, 12, cor_roupa.lightened(0.4))
