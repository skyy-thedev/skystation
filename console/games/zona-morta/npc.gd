extends CharacterBody2D
## Pessoa viva (Nina, Tião…). Não luta: fala. O que ela diz e as escolhas ficam em historia.gd.

var main: Node2D
var id := "nina"
var nome := "Nina"
var roupa := Color("8e5ba8")
var cabelo := Color("1b1b1b")
var olhar := Vector2.DOWN
var fase := 0.0
var sumir := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var f := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 11
	f.shape = c
	add_child(f)


func alcance() -> float:
	return 80.0


func rotulo(_j: Node) -> String:
	return "" if sumir else "Falar com " + nome


func disponivel(j: Node) -> bool:
	return rotulo(j) != ""


func tempo(_j: Node) -> float:
	return 0.2


func usar(_j: Node) -> void:
	main.historia.falar(id)


func levar_dano(_q: float, _f: Vector2) -> void:
	main.historia.atacou_npc(id)


func _process(d: float) -> void:
	fase += d * 2.0
	var mais_perto: Node2D = null
	for j in main.jogadores:
		if mais_perto == null or j.global_position.distance_to(global_position) < mais_perto.global_position.distance_to(global_position):
			mais_perto = j
	if mais_perto and mais_perto.global_position.distance_to(global_position) < 300:
		olhar = (mais_perto.global_position - global_position).normalized()
	if sumir:
		modulate.a = maxf(0.0, modulate.a - d)
		if modulate.a <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(2, 2), 13, Color(0, 0, 0, 0.35))
	var corpo := Vector2(0, -18 + sin(fase) * 0.8)
	draw_line(Vector2(5, -2), Vector2(5, -12), Color("2b2d42"), 6, true)
	draw_line(Vector2(-5, -2), Vector2(-5, -12), Color("2b2d42"), 6, true)
	draw_circle(corpo, 12, roupa)
	var cab := corpo + Vector2(0, -14) + olhar * 2
	draw_circle(cab, 8, Color("c99a6e"))
	draw_circle(cab - olhar * 2 + Vector2(0, -3), 7, cabelo)
	# marcador: tem conversa
	if not sumir and main.historia.tem_conversa(id):
		var y := -66 + sin(fase * 2.0) * 3
		draw_circle(Vector2(0, y), 9, Color(1, 0.82, 0.4, 0.95))
		draw_string(ThemeDB.fallback_font, Vector2(-4, y + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1))
