extends CharacterBody2D
## Iara, a "carga": no jogo solo ela anda sozinha (segue o Corvo, foge dos zumbis, entra no carro junto).
## No coop quem joga com ela é o jogador 2 (aí ela é um jogador.gd com vip = true e este nó nem existe).
## Mordida não transforma a Iara — esse é o segredo dela. Mas mordida dói: se a vida acabar, ela cai.

const A := preload("res://arte.gd")

var main: Node2D
var nome := "Iara"
var hp := 80.0
var hp_max := 80.0
var caido := false
var t_caido := 0.0
var esperar := false          # o Corvo mandou ela esperar
var carro: Node = null
var mira := Vector2.DOWN
var passo := 0.0
var t_dano := 0.0
var t_preso := 0.0
var vip := true
var cor_roupa := Color("2f6b4f")
var nivel := 1


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var f := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10
	f.shape = c
	add_child(f)


func lider() -> Node2D:
	return main.jogadores[0] if not main.jogadores.is_empty() else null


func pode_ser_mordido() -> bool:
	return carro == null and not caido and visible


func luz_chamativa() -> bool:
	return false


func receber_dano(q: float, _piscar := true) -> void:
	if caido or carro:
		return
	hp -= q
	t_dano = 0.25
	main.sons.tocar("dor", global_position, -4.0, 1.5)
	main.historia.evento("iara_mordida", {})
	if hp <= 0.0:
		hp = 0.0
		caido = true
		t_caido = 40.0
		main.aviso("A Iara caiu! Segure ✕ perto dela antes que seja tarde", Color("ff6b6b"))


# ---------------------------------------------------------------- interação (✕)

func alcance() -> float:
	return 60.0


func rotulo(_j: Node) -> String:
	if caido:
		return "Levantar a Iara"
	return "Iara: vem comigo" if esperar else "Iara: espera aqui"


func disponivel(j: Node) -> bool:
	return rotulo(j) != ""


func tempo(_j: Node) -> float:
	return 2.0 if caido else 0.2


func usar(_j: Node) -> void:
	if caido:
		caido = false
		hp = hp_max * 0.4
		main.aviso("Iara: \"Tô bem… tô bem.\"", Color("7ff0c4"))
		return
	esperar = not esperar
	main.aviso("Iara: \"%s\"" % ("Tá, eu espero. Não demora." if esperar else "Tô do seu lado."), Color("9ad9b8"))


# ---------------------------------------------------------------- laço

func _physics_process(d: float) -> void:
	if not main.jogando():
		return
	t_dano = maxf(0.0, t_dano - d)
	var l := lider()
	if l == null:
		return
	if caido:
		t_caido -= d
		if t_caido <= 0.0:
			main.vip_morreu()
		queue_redraw()
		return
	# carro: entra junto quando o Corvo dirige, sai quando ele sai
	if l.carro and carro == null and not esperar and global_position.distance_to(l.carro.global_position) < 600.0:
		carro = l.carro
		visible = false
		collision_layer = 0
	if carro:
		global_position = carro.global_position
		if l.carro != carro:
			global_position = carro.global_position + Vector2.from_angle(carro.angulo - PI / 2) * 60.0
			carro = null
			visible = true
			collision_layer = 4
		return

	var alvo := global_position
	if not esperar:
		alvo = l.global_position - l.mira * 55.0 + l.mira.orthogonal() * 35.0
	# zumbi perto: ela foge para trás do Corvo
	var fuga := Vector2.ZERO
	for z in main.zumbis:
		var v: Vector2 = global_position - z.global_position
		if v.length() < 150.0:
			fuga += v.normalized() * (150.0 - v.length())
	var desejo := Vector2.ZERO
	var dist := alvo.distance_to(global_position)
	if fuga.length() > 1.0:
		desejo = (fuga.normalized() * 0.7 + (l.global_position - global_position).normalized() * 0.5).normalized() * 250.0
	elif dist > 40.0:
		desejo = (alvo - global_position).normalized() * (270.0 if dist > 260.0 else 190.0)
	velocity = desejo
	move_and_slide()
	if desejo.length() > 10.0:
		mira = desejo.normalized()
		passo += d * 10.0
		main.sons.passo(self, desejo.length() > 220.0)
	elif not esperar:
		mira = (l.global_position - global_position).normalized()
	# ficou presa (barricada, parede) e longe demais: ela "dá a volta" e aparece atrás do Corvo
	if not esperar and l.global_position.distance_to(global_position) > 520.0 and velocity.length() < 40.0:
		t_preso += d
		if t_preso > 2.0:
			global_position = l.global_position - l.mira * 60.0
			t_preso = 0.0
	else:
		t_preso = 0.0
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(2, 2), 12, Color(0, 0, 0, 0.35))
	if caido:
		draw_rect(Rect2(-20, -9, 40, 14), cor_roupa.darkened(0.3))
		draw_circle(Vector2(18, -4), 7, Color("b98a62"))
		draw_string(ThemeDB.fallback_font, Vector2(-40, -24), "Iara caída: %.0f s" % t_caido, HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color("ff8a8a"))
		return
	var mod := Color(1.6, 0.5, 0.5) if t_dano > 0.0 else Color.WHITE
	if A.boneco(self, "personagens/iara", mira, passo, velocity.length() > 10.0, 64.0, mod):
		_draw_rotulos()
		return
	var lado := mira.orthogonal()
	var bal := sin(passo) * 3.0 if velocity.length() > 10.0 else 0.0
	var corpo := Vector2(0, -16)
	draw_line(lado * 4 + Vector2(0, -2), lado * 4 + mira * bal + Vector2(0, -11), Color("3b3a4a"), 5, true)
	draw_line(-lado * 4 + Vector2(0, -2), -lado * 4 - mira * bal + Vector2(0, -11), Color("3b3a4a"), 5, true)
	draw_circle(corpo, 10, cor_roupa if t_dano <= 0.0 else Color("ff6b6b"))
	var cab := corpo + Vector2(0, -12) + mira * 2
	draw_circle(cab, 7, Color("b98a62"))
	# capuz verde e trança
	draw_arc(cab, 8, PI * 0.9, PI * 2.1, 12, cor_roupa.darkened(0.2), 4)
	draw_line(cab - mira * 5, cab - mira * 5 + Vector2(0, 12), Color("1b1410"), 3)
	_draw_rotulos()


func _draw_rotulos() -> void:
	if esperar:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -78), "esperando", HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(1, 1, 1, 0.7))
	if hp < hp_max:
		draw_rect(Rect2(-14, -72, 28, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -72, 28 * hp / hp_max, 4), Color("7ff0c4"))
