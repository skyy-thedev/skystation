extends CharacterBody2D
## O sobrevivente. Os números ficam aqui; quem decide o que acontece no mundo é o main.gd.

const VEL := 190.0
const VEL_CORRENDO := 300.0
const PENTE := 8

var main: Node2D
var hp := 100.0
var hp_max := 100.0
var estamina := 100.0
var fome := 100.0
var municao := 8        # balas no pente
var reserva := 16       # balas na mochila
var bandagens := 1
var comida := 1
var nivel := 1
var xp := 0
var forca := 1.0        # multiplica o dano do golpe (sobe de nível)

var mira := Vector2.RIGHT
var t_golpe := 0.0
var t_tiro := 0.0
var t_recarga := 0.0
var t_dano := 0.0       # piscar vermelho ao apanhar
var golpe_anim := 0.0
var tiro_fim := Vector2.ZERO
var tiro_anim := 0.0
var passo := 0.0
var mouse_t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	var forma := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13
	forma.shape = c
	add_child(forma)


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
		forca += 0.15
		main.aviso("Nível %d!  Vida máxima %d, golpe mais forte" % [nivel, hp_max], Color("ffd166"))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse_t = 2.0


func _physics_process(d: float) -> void:
	if not main.jogando():
		return
	t_golpe = max(0.0, t_golpe - d)
	t_tiro = max(0.0, t_tiro - d)
	t_dano = max(0.0, t_dano - d)
	golpe_anim = max(0.0, golpe_anim - d)
	tiro_anim = max(0.0, tiro_anim - d)
	mouse_t = max(0.0, mouse_t - d)

	var mover := Input.get_vector("esquerda", "direita", "cima", "baixo")
	var correndo := Input.is_action_pressed("correr") and mover.length() > 0.2 and estamina > 1.0
	if correndo:
		estamina = max(0.0, estamina - 28.0 * d)
	else:
		estamina = min(100.0, estamina + 16.0 * d)
	velocity = mover * (VEL_CORRENDO if correndo else VEL)
	move_and_slide()
	if mover.length() > 0.2:
		passo += d * (14.0 if correndo else 9.0)
		if correndo and int(passo) % 6 == 0:
			main.barulho(global_position, 260.0)   # correr faz barulho

	# mira: analógico direito > mouse > direção do movimento
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.35:
		mira = rs.normalized()
	elif mouse_t > 0.0:
		mira = (get_global_mouse_position() - global_position).normalized()
	elif mover.length() > 0.2:
		mira = mover.normalized()

	fome = max(0.0, fome - 0.42 * d)
	if fome <= 0.0:
		receber_dano(1.2 * d, false)

	if t_recarga > 0.0:
		t_recarga -= d
		if t_recarga <= 0.0:
			var q: int = min(PENTE - municao, reserva)
			municao += q
			reserva -= q

	if Input.is_action_just_pressed("golpe"):
		golpear()
	if Input.is_action_pressed("atirar") and t_tiro <= 0.0:
		atirar()
	if Input.is_action_just_pressed("recarregar"):
		recarregar()
	if Input.is_action_just_pressed("curar"):
		if bandagens > 0 and hp < hp_max:
			bandagens -= 1
			hp = min(hp_max, hp + 40)
			main.aviso("Bandagem: +40 de vida", Color("7ff0c4"))
		elif bandagens == 0:
			main.aviso("Sem bandagens", Color("ff8a8a"))
	if Input.is_action_just_pressed("comer"):
		if comida > 0 and fome < 98:
			comida -= 1
			fome = min(100.0, fome + 45)
			main.aviso("Comeu uma lata: +45 de fome", Color("7ff0c4"))
		elif comida == 0:
			main.aviso("Sem comida", Color("ff8a8a"))
	queue_redraw()


func golpear() -> void:
	if t_golpe > 0.0 or estamina < 8.0:
		return
	t_golpe = 0.42
	golpe_anim = 0.18
	estamina -= 12.0
	var dano := 22.0 * forca
	for z in main.zumbis:
		var v: Vector2 = z.global_position - global_position
		if v.length() < 64.0 and abs(mira.angle_to(v)) < 1.1:
			z.levar_dano(dano, v.normalized() * 320.0)
	main.barulho(global_position, 150.0)


func atirar() -> void:
	if t_recarga > 0.0:
		return
	if municao <= 0:
		recarregar()
		return
	t_tiro = 0.32
	municao -= 1
	var dir: Vector2 = main.mira_assistida(global_position, mira)
	var ate := global_position + dir * 640.0
	var q := PhysicsRayQueryParameters2D.create(global_position, ate, 1 | 2, [get_rid()])
	q.hit_from_inside = true   # zumbi colado em você também leva o tiro
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	tiro_fim = ate
	if r:
		tiro_fim = r["position"]
		if r["collider"].has_method("levar_dano"):
			r["collider"].levar_dano(45.0, dir * 260.0)
	tiro_anim = 0.07
	main.barulho(global_position, 720.0)   # tiro chama a vizinhança inteira
	main.tremer(5.0)


func recarregar() -> void:
	if t_recarga > 0.0 or municao >= PENTE:
		return
	if reserva <= 0:
		main.aviso("Sem munição: procure caixas", Color("ff8a8a"))
		return
	t_recarga = 1.1


func receber_dano(q: float, piscar := true) -> void:
	hp -= q
	if piscar:
		t_dano = 0.25
		main.tremer(4.0)
	main.interromper_busca()
	if hp <= 0.0:
		main.fim_de_jogo()


func _draw() -> void:
	var a := mira.angle()
	var andando := velocity.length() > 10.0
	var bal := sin(passo) * 3.0 if andando else 0.0
	# sombra
	draw_circle(Vector2(3, 5), 15, Color(0, 0, 0, 0.35))
	# pernas (balançam ao andar)
	var lado := mira.orthogonal()
	draw_line(lado * 6 + mira * bal, lado * 6 + mira * (bal - 2), Color("2b2d42"), 7, true)
	draw_line(-lado * 6 - mira * bal, -lado * 6 - mira * (bal + 2), Color("2b2d42"), 7, true)
	# corpo (jaqueta) e mochila
	draw_circle(-mira * 9, 9, Color("6b4f2a"))
	draw_circle(Vector2.ZERO, 13, Color("3a6ea5") if t_dano <= 0.0 else Color("ff6b6b"))
	# arma: taco no golpe, pistola o resto do tempo
	if golpe_anim > 0.0:
		var g := a + lerpf(-1.1, 1.1, 1.0 - golpe_anim / 0.18)
		draw_line(Vector2.from_angle(g) * 8, Vector2.from_angle(g) * 40, Color("c9a26b"), 6, true)
		draw_arc(Vector2.ZERO, 46, a - 1.1, a + 1.1, 16, Color(1, 1, 1, 0.25), 3, true)
	else:
		draw_line(mira * 8 + lado * 7, mira * 24 + lado * 7, Color("1d1d1d"), 5, true)
	# cabeça
	draw_circle(mira * 2, 8, Color("e0b48a"))
	draw_circle(mira * 4 - mira.orthogonal() * 0.0, 3, Color("3b2a1a"))
	if tiro_anim > 0.0:
		var de := mira * 26 + lado * 7
		draw_line(de, to_local(tiro_fim), Color(1, 0.9, 0.5, 0.9), 2, true)
		draw_circle(de, 7, Color(1, 0.85, 0.4, 0.8))
