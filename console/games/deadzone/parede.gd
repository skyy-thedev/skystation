extends StaticBody2D
## Um pedaço de parede em 2.5D: a base (que colide e faz sombra na luz) e, por cima, a face da frente e o
## topo, desenhados "em pé". A origem é o pé da parede, então o Godot ordena com o resto pelo Y.
## Quando um jogador está atrás (ao norte), a parede fica meio transparente para ele não sumir.

const ALTURA := 58.0
const A := preload("res://arte.gd")

var main: Node2D
var tam := Vector2(64, 14)    # base: largura x profundidade
var cor := Color("3a3a40")
var topo := Color("5a5a62")
var visivel := true
var transp := 1.0


func _ready() -> void:
	collision_layer = 1
	var f := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = tam
	f.shape = s
	f.position = Vector2(0, -tam.y / 2)
	add_child(f)
	var oc := LightOccluder2D.new()
	var pol := OccluderPolygon2D.new()
	var a := Vector2(-tam.x / 2, -tam.y)
	pol.polygon = PackedVector2Array([a, Vector2(tam.x / 2, -tam.y), Vector2(tam.x / 2, 0), Vector2(-tam.x / 2, 0)])
	oc.occluder = pol
	add_child(oc)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _process(_d: float) -> void:
	if not visivel:
		return
	var alvo := 1.0
	for j in main.jogadores:
		var p: Vector2 = j.global_position - global_position
		if p.y < 0.0 and p.y > -ALTURA - tam.y - 30.0 and absf(p.x) < tam.x / 2 + 22.0:
			alvo = 0.35
	if absf(alvo - transp) > 0.01:
		transp = move_toward(transp, alvo, 0.08)
		queue_redraw()


func _draw() -> void:
	if not visivel:
		return
	var w := tam.x
	var p := tam.y
	var a := transp
	draw_rect(Rect2(-w / 2 + 6, -p + 4, w, p + 8), Color(0, 0, 0, 0.32 * a))          # sombra no chão
	draw_rect(Rect2(-w / 2, -ALTURA, w, ALTURA), Color(cor, a))                        # face da frente
	var tx := A.tex("chao/parede_concreto.png" if cor.s < 0.12 else "chao/parede_tijolo.png", 128)
	if tx:
		# a textura "anda" junto com o mundo (x global), então pedaços vizinhos emendam
		var ox := fposmod(global_position.x - w / 2, 128.0)
		draw_texture_rect_region(tx, Rect2(-w / 2, -ALTURA, w, ALTURA), Rect2(ox, 30, w, ALTURA),
			Color(cor.lightened(0.55), a), false, false)
	draw_rect(Rect2(-w / 2, -ALTURA - p, w, p), Color(topo, a))                        # topo
	draw_line(Vector2(-w / 2, -ALTURA), Vector2(w / 2, -ALTURA), Color(1, 1, 1, 0.10 * a), 2)
	draw_line(Vector2(-w / 2, -8), Vector2(w / 2, -8), Color(0, 0, 0, 0.25 * a), 3)     # rodapé
