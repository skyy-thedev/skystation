extends CharacterBody2D
## Carro. Os quebrados só servem para revirar o porta-malas e tirar gasolina do tanque; os que funcionam
## (chave no contato, farol piscando) andam se tiverem gasolina. Viatura = carro da polícia (loot melhor).

const D := preload("res://dados.gd")
const A := preload("res://arte.gd")

var main: Node2D
var viatura := false
var funciona := false
var combustivel := 0.0        # litros no carro que funciona
var tanque := 0.0             # litros que dá para tirar (carro quebrado)
var saqueado := false
var cor := Color("8d2b2b")
var angulo := 0.0             # para onde o carro aponta (radianos)
var vel := 0.0
var motorista: Node = null
var carona: Node = null
var vida := 220.0
var t_pisca := 0.0
var farol: PointLight2D
var t_buzina := 0.0
var motor: AudioStreamPlayer2D

const TAM := Vector2(118, 58)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
	var f := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = TAM
	f.shape = s
	add_child(f)
	rotation = 0.0
	f.rotation = angulo
	set_meta("forma", f)
	farol = main.nova_luz(Color(1.0, 0.95, 0.8), 2.4, true, true)
	farol.visible = false
	add_child(farol)
	motor = AudioStreamPlayer2D.new()
	motor.max_distance = 1400.0
	motor.volume_db = -6.0
	add_child(motor)


func alcance() -> float:
	return 90.0


func rotulo(j: Node) -> String:
	if motorista == j or carona == j:
		return "Sair do carro"
	if funciona:
		if combustivel > 0.5:
			if motorista == null:
				return "Dirigir"
			if carona == null:
				return "Ir de carona"
			return ""
		if j.tem("galao") and j.gasolina > 0.0:
			return "Abastecer (%.0f L)" % j.gasolina
		return "Sem gasolina: traga um galão"
	if not saqueado:
		return "Revirar a viatura" if viatura else "Revirar o porta-malas"
	if tanque > 0.0 and j.tem("galao") and j.gasolina < 10.0:
		return "Tirar gasolina do tanque"
	return ""


func disponivel(j: Node) -> bool:
	var r := rotulo(j)
	return r != "" and not r.begins_with("Sem gasolina")


func tempo(j: Node) -> float:
	var r := rotulo(j)
	if r.begins_with("Revirar"):
		return 1.0
	if r.begins_with("Abastecer") or r.begins_with("Tirar"):
		return 1.8
	return 0.25


func usar(j: Node) -> void:
	var r := rotulo(j)
	if r == "Sair do carro":
		sair(j)
	elif r == "Dirigir":
		motorista = j
		j.entrar_carro(self)
		main.historia.evento("dirigiu", {})
	elif r == "Ir de carona":
		carona = j
		j.entrar_carro(self)
	elif r.begins_with("Abastecer"):
		combustivel += j.gasolina
		main.aviso("Carro abastecido: %.0f L" % combustivel, Color("ffd166"))
		j.gasolina = 0.0
		main.historia.evento("abasteceu", {})
	elif r.begins_with("Revirar"):
		saqueado = true
		var achou := D.sortear("viatura" if viatura else "porta_malas", main.rng)
		if achou.is_empty():
			main.aviso("Nada útil aqui.", Color(1, 1, 1, 0.7))
		for a in achou:
			j.receber(a[0], a[1])
		main.historia.evento("revirou", {"tipo": "carro"})
	elif r.begins_with("Tirar"):
		var q: float = minf(tanque, 10.0 - j.gasolina)
		tanque -= q
		j.gasolina += q
		main.aviso("+%.0f L no galão" % q, Color("ffd166"))
		main.historia.evento("gasolina", {})
	queue_redraw()


func sair(j: Node) -> void:
	if motorista == j:
		motorista = null
	if carona == j:
		carona = null
	j.sair_carro(self)
	farol.visible = motorista != null


func _physics_process(d: float) -> void:
	t_pisca += d
	if motorista == null:
		if motor.playing:
			motor.stop()
		vel = move_toward(vel, 0.0, 400.0 * d)
		if absf(vel) > 1.0:
			_mover(d)
		if funciona:
			queue_redraw()   # farol piscando: "este funciona"
		return
	if not main.jogando():
		if motor.playing:
			motor.stream_paused = true
		return
	motor.stream_paused = false
	if not motor.playing and combustivel > 0.0:
		motor.stream = main.sons.bancos["motor"][0]
		motor.play()
	if combustivel <= 0.0 and motor.playing:
		motor.stop()
	motor.pitch_scale = 0.75 + absf(vel) / 520.0 * 1.3
	var c: Dictionary = motorista.controle()
	var acel: float = c["acelera"]
	var freio: float = c["freia"]
	if combustivel <= 0.0:
		acel = 0.0
	vel += (acel * 520.0 - freio * (700.0 if vel > 0 else 300.0)) * d
	vel = clampf(vel, -160.0, 520.0)
	vel = move_toward(vel, 0.0, 90.0 * d)
	if absf(vel) > 10.0:
		angulo += c["mover"].x * d * 2.4 * clampf(absf(vel) / 200.0, 0.0, 1.0) * signf(vel)
	combustivel = maxf(0.0, combustivel - absf(vel) * d * 0.0028)
	if combustivel <= 0.0 and acel > 0.0:
		main.aviso("Acabou a gasolina!", Color("ff6b6b"))
	_mover(d)
	farol.visible = true
	farol.rotation = angulo
	main.barulho(global_position, 200.0 + absf(vel) * 1.3)   # motor chama atenção
	if c["buzina"] and t_buzina <= 0.0:
		t_buzina = 1.0
		main.barulho(global_position, 1400.0)
		main.sons.tocar("buzina", global_position)
	t_buzina -= d
	queue_redraw()


func _mover(d: float) -> void:
	var forma: CollisionShape2D = get_meta("forma")
	forma.rotation = angulo
	var col := move_and_collide(Vector2.from_angle(angulo) * vel * d)
	if col:
		var outro := col.get_collider()
		if outro and outro.has_method("levar_dano"):
			if absf(vel) > 90.0:
				outro.levar_dano(absf(vel) * 0.35, Vector2.from_angle(angulo) * absf(vel) * 1.4)
				main.sons.tocar("acerto", global_position, 0.0, 0.7)
				main.tremer(3.0)
				vel *= 0.85
		else:
			if absf(vel) > 200.0:
				main.tremer(6.0)
			vel *= -0.25


func _draw() -> void:
	if _draw_arte():
		return
	# 2.5D: sombra no chão, chassi, cabine com vidros e teto, tudo girado para onde o carro aponta
	var w := TAM.x
	var h := TAM.y
	draw_set_transform(Vector2(6, 8), angulo)
	draw_rect(Rect2(-w / 2, -h / 2, w, h), Color(0, 0, 0, 0.35))
	var corpo := cor if (funciona or not viatura) else Color("1f2a44")
	if viatura:
		corpo = Color("e8e8e8")
	for camada in [[-6.0, corpo.darkened(0.35)], [-14.0, corpo]]:
		draw_set_transform(Vector2(0, camada[0]), angulo)
		draw_rect(Rect2(-w / 2, -h / 2, w, h), camada[1])
	draw_set_transform(Vector2(0, -14), angulo)
	if viatura:
		draw_rect(Rect2(-w / 2, -h / 2, 30, h), Color("1f2a44"))
		draw_rect(Rect2(w / 2 - 30, -h / 2, 30, h), Color("1f2a44"))
	draw_rect(Rect2(-12, -h / 2 + 5, 46, h - 10), Color(0.12, 0.16, 0.2))   # para-brisa e vidros
	draw_set_transform(Vector2(0, -26), angulo)
	draw_rect(Rect2(-22, -h / 2 + 7, 34, h - 14), corpo.lightened(0.08))        # teto
	if viatura:
		var on := fmod(t_pisca, 0.6) < 0.3 and motorista != null
		draw_rect(Rect2(-8, -12, 8, 10), Color(1, 0.2, 0.2) if on else Color(0.5, 0.1, 0.1))
		draw_rect(Rect2(-8, 2, 8, 10), Color(0.2, 0.4, 1) if not on else Color(0.1, 0.15, 0.5))
	draw_set_transform(Vector2(0, -14), angulo)
	var farol_cor := Color(1, 0.95, 0.7)
	if funciona and motorista == null and fmod(t_pisca, 2.0) > 1.6:
		farol_cor = Color(1, 1, 0.6, 1)
	elif not funciona:
		farol_cor = Color(0.4, 0.4, 0.35)
	elif motorista == null:
		farol_cor = Color(0.6, 0.6, 0.5)
	draw_rect(Rect2(w / 2 - 6, -h / 2 + 5, 6, 10), farol_cor)
	draw_rect(Rect2(w / 2 - 6, h / 2 - 15, 6, 10), farol_cor)
	draw_rect(Rect2(-w / 2, -h / 2 + 5, 5, 9), Color(0.7, 0.1, 0.1))
	draw_rect(Rect2(-w / 2, h / 2 - 14, 5, 9), Color(0.7, 0.1, 0.1))
	if saqueado and not funciona:
		draw_rect(Rect2(-w / 2 - 14, -h / 2 + 4, 14, h - 8), corpo.darkened(0.2))   # porta-malas aberto
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_arte() -> bool:
	## a arte é um carro em 3/4 virado para a direita: espelha quando ele aponta para a esquerda
	## e inclina o resto do ângulo (em pé ou deitado, ele continua parecendo um carro de quadrinho)
	var nome := "viatura" if viatura else ("carro_bom" if funciona else "carro_quebrado")
	var t := A.tex("pecas/%s.png" % nome, 240)
	if t == null:
		return false
	var esq := cos(angulo) < 0.0
	var inc := angulo - PI if esq else angulo
	inc = wrapf(inc, -PI, PI)
	var larg := 150.0
	var alt := t.get_height() * larg / t.get_width()
	# sombra do sol: mancha escura deslocada para o lado da sombra (o carro tem ~40 px de altura)
	if A.sol_a > 0.02:
		var luz: Texture2D = main.tex_luz
		var c := A.sol_v * 26.0 + Vector2(0, 2)
		draw_texture_rect(luz, Rect2(c - Vector2(95, 40), Vector2(190, 80)), false, Color(0, 0, 0, A.sol_a * 1.4))
	draw_texture_rect(main.tex_luz, Rect2(-80, -26, 160, 52), false, Color(0, 0, 0, 0.55))   # contato com o chão
	draw_set_transform(Vector2(0, 4), inc, Vector2(-1, 1) if esq else Vector2.ONE)
	var mod := Color.WHITE
	if saqueado and not funciona:
		mod = Color(0.7, 0.68, 0.65)
	draw_texture_rect(t, Rect2(-larg / 2, -alt + 22, larg, alt), false, mod)
	if viatura and motorista != null:
		var on := fmod(t_pisca, 0.6) < 0.3
		draw_circle(Vector2(-4, -alt + 34), 6, Color(1, 0.2, 0.2, 0.9) if on else Color(0.2, 0.4, 1, 0.9))
	if funciona and motorista == null and fmod(t_pisca, 2.0) > 1.6:
		draw_circle(Vector2(larg / 2 - 10, -6), 9, Color(1, 1, 0.6, 0.85))   # farol piscando: "eu ainda pego"
	draw_set_transform(Vector2.ZERO, 0.0)
	return true
