extends CharacterBody2D
## Um zumbi. Vaga até ver ou ouvir alguém; aí persegue e morde. Barricada no caminho: ele soca até cair.
## Tipos: andarilho (comum), corredor (rápido, aparece do dia 2), brutamontes (aguenta muito, do dia 3)
## e policial (perto da delegacia; às vezes deixa balas). Lanterna acesa à noite: eles te veem de longe.

var main: Node2D
var tipo := "andarilho"
var hp := 40.0
var hp_max := 40.0
var vel := 75.0
var dano := 9.0
var alerta := false
var alvo: Node = null
var vagar := Vector2.ZERO
var t_vagar := 0.0
var t_olhar := 0.0
var t_ataque := 0.0
var t_flash := 0.0
var t_perdeu := 0.0
var t_fogo := 0.0
var empurrao := Vector2.ZERO
var frente := Vector2.RIGHT
var fase := 0.0
var cor := Color("6f8f5a")
var destino := Vector2.ZERO   # para onde foi o barulho


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	var forma := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 15.0 if tipo == "brutamontes" else 11.0
	forma.shape = c
	add_child(forma)
	fase = randf() * TAU
	match tipo:
		"corredor":
			cor = Color("b5524a")
		"brutamontes":
			cor = Color("5d6b4a")
		"policial":
			cor = Color("4a5d7a")
		_:
			cor = Color.from_hsv(randf_range(0.20, 0.30), 0.35, randf_range(0.40, 0.55))


func ouvir(origem: Vector2) -> void:
	if not alerta:
		destino = origem
	t_perdeu = maxf(t_perdeu, 4.0)
	alerta = true


func levar_dano(q: float, forca: Vector2) -> void:
	hp -= q
	t_flash = 0.12
	empurrao += forca * (0.35 if tipo == "brutamontes" else 1.0)
	alerta = true
	t_perdeu = 8.0
	main.sangue(global_position, 6.0 + q * 0.15)
	if hp <= 0.0:
		main.zumbi_morreu(self)


func pegar_fogo() -> void:
	t_fogo = 4.0


func _physics_process(d: float) -> void:
	if not main.jogando():
		return
	fase += d * (9.0 if alerta else 4.0)
	t_flash = maxf(0.0, t_flash - d)
	t_ataque = maxf(0.0, t_ataque - d)
	if t_fogo > 0.0:
		t_fogo -= d
		hp -= 14.0 * d
		if hp <= 0.0:
			main.zumbi_morreu(self)
			return

	t_olhar -= d
	if t_olhar <= 0.0:
		t_olhar = 0.3
		_olhar()

	var desejo := Vector2.ZERO
	if alvo and alerta:
		var para: Vector2 = alvo.global_position - global_position
		desejo = para.normalized() * vel
		destino = alvo.global_position
	elif alerta and destino != Vector2.ZERO:
		var para := destino - global_position
		if para.length() < 30.0:
			destino = Vector2.ZERO
		else:
			desejo = para.normalized() * vel * 0.8
	else:
		t_vagar -= d
		if t_vagar <= 0.0:
			t_vagar = randf_range(1.5, 4.0)
			vagar = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
		desejo = vagar * vel * 0.35
	velocity = desejo + empurrao
	empurrao = empurrao.move_toward(Vector2.ZERO, 1400.0 * d)
	if desejo.length() > 1.0:
		frente = frente.slerp(desejo.normalized(), clampf(8.0 * d, 0.0, 1.0))
	move_and_slide()

	# soca barricada que estiver no caminho
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c.has_meta("porta") and t_ataque <= 0.0 and alerta:
			t_ataque = 1.0
			c.get_meta("porta").bater(dano * (2.5 if tipo == "brutamontes" else 1.0))

	if alvo and t_ataque <= 0.0 and alvo.global_position.distance_to(global_position) < 32.0 and alvo.pode_ser_mordido():
		t_ataque = 0.9 if tipo != "brutamontes" else 1.4
		alvo.receber_dano(dano)
	queue_redraw()


func _olhar() -> void:
	var melhor: Node = null
	var menor := 1e9
	for j in main.jogadores:
		if not j.pode_ser_mordido():
			continue
		var dist: float = j.global_position.distance_to(global_position)
		var raio: float = main.raio_visao(j)
		if dist < raio and dist < menor and _ve(j):
			melhor = j
			menor = dist
	if melhor:
		alvo = melhor
		alerta = true
		t_perdeu = 5.0
	elif alerta:
		t_perdeu -= 0.3
		if t_perdeu <= 0.0:
			alerta = false
			alvo = null


func _ve(j: Node2D) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, j.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _draw() -> void:
	# a origem é o pé; o corpo é desenhado "em pé", para cima (2.5D)
	var lado := frente.orthogonal()
	var bal := sin(fase) * 4.0
	var esc := 1.35 if tipo == "brutamontes" else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(esc, esc))
	draw_circle(Vector2(2, 2), 13, Color(0, 0, 0, 0.35))
	var c := Color.WHITE if t_flash > 0.0 else cor
	var corpo := Vector2(0, -16)
	# pernas
	draw_line(lado * 5 + Vector2(0, -2), lado * 5 + frente * bal * 0.6 + Vector2(0, -12), c.darkened(0.45), 5, true)
	draw_line(-lado * 5 + Vector2(0, -2), -lado * 5 - frente * bal * 0.6 + Vector2(0, -12), c.darkened(0.45), 5, true)
	# braços esticados para a frente
	draw_line(corpo + lado * 9, corpo + lado * 9 + frente * (20 + bal), c.darkened(0.15), 5, true)
	draw_line(corpo - lado * 9, corpo - lado * 9 + frente * (20 - bal), c.darkened(0.15), 5, true)
	draw_circle(corpo, 12, c.darkened(0.25))
	var cabeca := corpo + Vector2(0, -12) + frente * 3
	draw_circle(cabeca, 8, c.lightened(0.12))
	var olho := Color(1, 0.2, 0.15) if alerta else Color(0.9, 0.9, 0.6)
	draw_circle(cabeca + frente * 4 + lado * 3, 1.8, olho)
	draw_circle(cabeca + frente * 4 - lado * 3, 1.8, olho)
	if tipo == "policial":
		draw_rect(Rect2(cabeca + Vector2(-8, -9), Vector2(16, 5)), Color("1f2a44"))
	if t_fogo > 0.0:
		for k in 3:
			draw_circle(corpo + Vector2(randf_range(-8, 8), randf_range(-14, 4)), randf_range(4, 8), Color(1, randf_range(0.4, 0.8), 0.1, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0)
	if hp < hp_max:
		draw_rect(Rect2(-14, -52 * esc, 28, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -52 * esc, 28 * maxf(0.0, hp / hp_max), 4), Color("e85d5d"))
