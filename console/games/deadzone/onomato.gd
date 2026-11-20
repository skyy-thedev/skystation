extends Node2D
## Onomatopeia de quadrinho no mundo ("BLAM!", "POW!"): estoura grande, assenta, sobe um pouco e some.

const A := preload("res://arte.gd")

var texto := "POW!"
var cor := Color("ffd166")
var tam := 34
var t := 0.0
const VIDA := 0.75


func _ready() -> void:
	z_index = 40
	rotation = randf_range(-0.28, 0.28)


func _process(d: float) -> void:
	t += d
	position.y -= 26.0 * d
	if t >= VIDA:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var f := A.fonte("Bangers-Regular.ttf")
	# estoura em 0,1 s (passa do tamanho e volta), depois some no fim
	var e := lerpf(0.3, 1.2, t / 0.08) if t < 0.08 else lerpf(1.2, 1.0, clampf((t - 0.08) / 0.08, 0.0, 1.0))
	var a := clampf((VIDA - t) / 0.25, 0.0, 1.0)
	var w := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(e, e))
	var p := Vector2(-w / 2, tam * 0.35)
	draw_string_outline(f, p + Vector2(3, 4), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 9, Color(0, 0, 0, 0.5 * a))
	draw_string_outline(f, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 8, Color(0.07, 0.06, 0.05, a))
	draw_string(f, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(cor, a))
	draw_set_transform(Vector2.ZERO)
