extends Node2D
## Enfeite do mapa (Kombi largada, caminhão tombado, poste, orelhão, mato seco).
## Não tem interação: só a arte, a sombra na luz e, se for grande, colisão.

const A := preload("res://arte.gd")

var nome := "poste"
var largura := 80.0
var bloco := Vector2.ZERO     # colisão (largura x profundidade), zero = atravessa
var espelho := false


func _ready() -> void:
	if bloco != Vector2.ZERO:
		var c := StaticBody2D.new()
		var f := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = bloco
		f.shape = s
		f.position = Vector2(0, -bloco.y / 2)
		c.add_child(f)
		add_child(c)


func _draw() -> void:
	A.peca(self, nome, largura, 8.0, Color.WHITE, espelho)


func desenhar_sombra(ci: CanvasItem) -> void:
	## chamada pelo grupo de sombras do sol (main._desenhar_sombras)
	A.sombra_peca(ci, nome, largura, position, 8.0, espelho)
