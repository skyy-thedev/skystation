extends CharacterBody2D
## Um zumbi. Vaga à toa até ver ou ouvir o jogador; aí persegue e morde.

var main: Node2D
var hp := 40.0
var hp_max := 40.0
var vel := 75.0
var dano := 9.0
var corredor := false
var alerta := false
var vagar := Vector2.ZERO
var t_vagar := 0.0
var t_olhar := 0.0
var t_ataque := 0.0
var t_flash := 0.0
var t_perdeu := 0.0
var empurrao := Vector2.ZERO
var frente := Vector2.RIGHT
var fase := 0.0
var cor := Color("6f8f5a")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	var forma := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13
	forma.shape = c
	add_child(forma)
	fase = randf() * TAU
	cor = Color("b5524a") if corredor else Color.from_hsv(randf_range(0.22, 0.30), 0.35, randf_range(0.42, 0.55))


func ouvir(origem: Vector2) -> void:
	alerta = true
	t_perdeu = 6.0
	vagar = (origem - global_position).normalized()


func levar_dano(q: float, forca: Vector2) -> void:
	hp -= q
	t_flash = 0.12
	empurrao += forca
	alerta = true
	t_perdeu = 8.0
	main.sangue(global_position, 6.0 + q * 0.15)
	if hp <= 0.0:
		main.zumbi_morreu(self)


func _physics_process(d: float) -> void:
	if not main.jogando():
		return
	fase += d * (9.0 if alerta else 4.0)
	t_flash = max(0.0, t_flash - d)
	t_ataque = max(0.0, t_ataque - d)
	var j: CharacterBody2D = main.jogador
	var para := j.global_position - global_position
	var dist := para.length()

	t_olhar -= d
	if t_olhar <= 0.0:
		t_olhar = 0.3
		if dist < main.raio_visao() and _ve(j):
			alerta = true
			t_perdeu = 5.0
		elif alerta:
			t_perdeu -= 0.3
			if t_perdeu <= 0.0:
				alerta = false

	var desejo := Vector2.ZERO
	if alerta:
		desejo = para.normalized() * vel
	else:
		t_vagar -= d
		if t_vagar <= 0.0:
			t_vagar = randf_range(1.5, 4.0)
			vagar = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
		desejo = vagar * vel * 0.35
	velocity = desejo + empurrao
	empurrao = empurrao.move_toward(Vector2.ZERO, 1400.0 * d)
	if desejo.length() > 1.0:
		frente = frente.slerp(desejo.normalized(), clamp(8.0 * d, 0.0, 1.0))
	move_and_slide()

	if dist < 34.0 and t_ataque <= 0.0:
		t_ataque = 0.9
		j.receber_dano(dano)
	queue_redraw()


func _ve(j: Node2D) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, j.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _draw() -> void:
	var lado := frente.orthogonal()
	var bal := sin(fase) * 4.0
	draw_circle(Vector2(3, 5), 15, Color(0, 0, 0, 0.35))
	var c := Color.WHITE if t_flash > 0.0 else cor
	# braços esticados para a frente, balançando
	draw_line(lado * 9, lado * 9 + frente * (20 + bal), c.darkened(0.15), 6, true)
	draw_line(-lado * 9, -lado * 9 + frente * (20 - bal), c.darkened(0.15), 6, true)
	draw_circle(Vector2.ZERO, 13, c.darkened(0.25) if not corredor else c)
	draw_circle(frente * 3, 8, c.lightened(0.1))
	# olhos (vermelhos quando te viu)
	var olho := Color(1, 0.2, 0.15) if alerta else Color(0.9, 0.9, 0.6)
	draw_circle(frente * 7 + lado * 3, 1.8, olho)
	draw_circle(frente * 7 - lado * 3, 1.8, olho)
	if hp < hp_max:
		draw_rect(Rect2(-14, -24, 28, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -24, 28 * max(0.0, hp / hp_max), 4), Color("e85d5d"))
