extends Node2D
## Tudo que fica parado no mapa e dá para usar com ✕: armários, geladeiras, prateleiras, cofres da polícia,
## caixas de ferramentas, camas, o rádio, a bomba do posto, árvores, portas (barricadas) e fogueiras.
## A origem do nó é o "pé" do objeto: o Godot ordena pelo Y e quem está mais embaixo é desenhado na frente (2.5D).

const D := preload("res://dados.gd")
const A := preload("res://arte.gd")
## peça desenhada para cada tipo: [arquivo, largura no mundo]
const SPRITE := {"armario": ["armario", 62.0], "geladeira": ["geladeira", 44.0], "prateleira": ["prateleira", 70.0],
	"arsenal": ["armario", 56.0], "ferramentas": ["ferramentas", 46.0], "radio": ["radio", 66.0],
	"tambor": ["tambor", 44.0], "bomba": ["bomba", 46.0], "cama": ["cama", 88.0], "fogueira": ["fogueira", 62.0]}
const LOOT := ["armario", "geladeira", "prateleira", "arsenal", "ferramentas", "mochila", "tambor"]

var main: Node2D
var tipo := "armario"
var aberto := false
var garantido: Array = []     # itens que sempre estão aqui (a casa do começo, por exemplo)
var casa := -1                # índice da construção (camas e portas)
var horiz := true             # portas: o vão é horizontal?
var largura := 96.0           # portas: tamanho do vão
var madeira := 4              # árvores: quantas vezes ainda dá para cortar
var aco := false              # porta de aço do bunker: tranca sem madeira e aguenta muito mais
var usos := 3                 # bomba do posto: litros acabam
var vida := 0.0               # barricada / fogueira (segundos)
var tabuas: StaticBody2D      # a barricada em si
var luz: PointLight2D
var fase := 0.0
var cor := Color.WHITE


func _ready() -> void:
	fase = randf() * TAU
	match tipo:
		"armario", "geladeira", "arsenal", "prateleira":
			_corpo(Vector2(40 if tipo != "prateleira" else 70, 22))
		"ferramentas", "radio":
			_corpo(Vector2(36, 20))
		"bomba":
			_corpo(Vector2(30, 30))
		"tambor":
			_corpo_redondo(14)
			luz = main.nova_luz(Color(0.5, 1.0, 0.35), 0.9, false)
			luz.position = Vector2(0, -30)
			luz.energy = 0.7
			add_child(luz)
		"arvore":
			_corpo_redondo(13)
		"fogueira":
			vida = 200.0
			luz = main.nova_luz(Color(1.0, 0.62, 0.3), 1.9, false)
			luz.position = Vector2(0, -10)
			add_child(luz)
			var som := AudioStreamPlayer2D.new()
			som.stream = main.sons.bancos["fogo"][0]
			som.max_distance = 900.0
			som.volume_db = -8.0
			som.autoplay = true
			add_child(som)


func _corpo(tam: Vector2) -> void:
	var c := StaticBody2D.new()
	var f := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = tam
	f.shape = s
	f.position = Vector2(0, -tam.y / 2)
	c.add_child(f)
	add_child(c)


func _corpo_redondo(r: float) -> void:
	var c := StaticBody2D.new()
	var f := CollisionShape2D.new()
	var s := CircleShape2D.new()
	s.radius = r
	f.shape = s
	c.add_child(f)
	var oc := LightOccluder2D.new()
	var pol := OccluderPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(Vector2.from_angle(i * TAU / 8) * r)
	pol.polygon = pts
	oc.occluder = pol
	c.add_child(oc)
	add_child(c)


# ---------------------------------------------------------------- interação

func alcance() -> float:
	return largura * 0.6 + 30.0 if tipo == "porta" else (70.0 if tipo == "fogueira" else 58.0)


func rotulo(j: Node) -> String:
	match tipo:
		"armario", "geladeira", "prateleira", "arsenal", "ferramentas", "mochila", "tambor":
			if aberto:
				return ""
			return {"armario": "Revirar armário", "geladeira": "Abrir geladeira", "prateleira": "Revirar prateleira",
				"arsenal": "Abrir armário de equipamento", "ferramentas": "Abrir caixa de ferramentas",
				"mochila": "Revirar mochila", "tambor": "Revirar o tambor (radioativo!)"}[tipo]
		"arvore":
			if madeira <= 0:
				return ""
			return "Cortar lenha" if j.tem_arma("machado") else "Precisa de um machado"
		"bomba":
			if usos <= 0:
				return "Bomba seca"
			if not j.tem("galao"):
				return "Precisa de um galão"
			return "Encher o galão" if j.gasolina < 10.0 else "Galão já está cheio"
		"porta":
			if aco:
				return "Destrancar a porta de aço" if tabuas else "Trancar a porta de aço"
			if tabuas:
				return "Desmontar barricada (+1 madeira)"
			return "Barricar a porta (2 madeira)" if j.qtd("madeira") >= 2 else "Barricar: precisa de 2 madeira"
		"cama":
			return "Acampar e dormir"
		"radio":
			return main.historia.rotulo_radio()
		"fogueira":
			return "Assar carne" if j.qtd("carne_crua") > 0 else ""
	return ""


func disponivel(j: Node) -> bool:
	var r := rotulo(j)
	return r != "" and not r.begins_with("Precisa") and not r.ends_with("seca") and not r.begins_with("Barricar:") \
		and not r.ends_with("cheio")


func tempo(_j: Node) -> float:
	match tipo:
		"arvore":
			return 1.4
		"porta":
			return 0.4 if tabuas else 1.6
		"bomba":
			return 1.5
		"cama", "radio":
			return 0.3
		"fogueira":
			return 1.8
	return 0.8


func usar(j: Node) -> void:
	match tipo:
		"armario", "geladeira", "prateleira", "arsenal", "ferramentas", "mochila", "tambor":
			aberto = true
			main.sons.tocar("abrir", global_position, -6.0)
			var achou: Array = garantido.duplicate()
			if not has_meta("so_garantido"):
				achou.append_array(D.sortear("armario" if tipo == "mochila" else tipo, main.rng))
			if achou.is_empty():
				main.aviso("Nada útil aqui.", Color(1, 1, 1, 0.7))
			for a in achou:
				j.receber(a[0], a[1])
			if tipo == "tambor":
				j.rad = minf(100.0, j.rad + 18.0)
			main.historia.evento("revirou", {"tipo": tipo, "obj": self})
			main.barulho(global_position, 120.0)
		"arvore":
			madeira -= 2
			j.receber("madeira", 2)
			main.sons.tocar("machado", global_position)
			main.barulho(global_position, 260.0)
			main.tremer(2.0)
		"bomba":
			var q: float = minf(10.0 - j.gasolina, 10.0)
			j.gasolina = 10.0
			usos -= 1
			main.aviso("Galão cheio: %.0f L de gasolina" % q, Color("ffd166"))
			main.historia.evento("gasolina", {})
		"porta":
			main.sons.tocar("martelo", global_position)
			if aco:
				if tabuas:
					tabuas.queue_free()
					tabuas = null
				else:
					barricar()
			elif tabuas:
				tabuas.queue_free()
				tabuas = null
				j.receber("madeira", 1)
			elif j.qtd("madeira") >= 2:
				j.gastar("madeira", 2)
				barricar()
				main.barulho(global_position, 300.0)
		"cama":
			main.dormir(self, j)
		"radio":
			main.historia.usar_radio()
		"fogueira":
			j.gastar("carne_crua", 1)
			j.receber("carne_assada", 1)
	queue_redraw()


func barricar() -> void:
	vida = 600.0 if aco else 160.0
	tabuas = StaticBody2D.new()
	tabuas.collision_layer = 1
	var f := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(largura, 16) if horiz else Vector2(16, largura)
	f.shape = s
	tabuas.add_child(f)
	tabuas.set_meta("porta", self)
	add_child(tabuas)
	queue_redraw()


func bater(q: float) -> void:
	## zumbi mordendo a barricada
	if not tabuas:
		return
	vida -= q
	main.tremer(1.0)
	main.sons.tocar("martelo", global_position, -8.0, 0.7)
	if vida <= 0.0:
		tabuas.queue_free()
		tabuas = null
		main.aviso("Uma barricada caiu!", Color("ff6b6b"))
	queue_redraw()


func _process(d: float) -> void:
	if tipo == "fogueira":
		fase += d * 9.0
		vida -= d
		luz.energy = 1.15 + sin(fase) * 0.12 + sin(fase * 2.3) * 0.08
		if vida <= 0.0:
			queue_free()
		queue_redraw()
	elif tipo == "radio":
		fase += d * 4.0
		queue_redraw()


# ---------------------------------------------------------------- desenho 2.5D

func _caixa(base: Vector2, alt: float, cor_lado: Color, cor_topo: Color) -> void:
	## um bloco: a face da frente (de pé) e o tampo, deslocado para cima pela altura
	var w := base.x
	var p := base.y
	draw_rect(Rect2(-w / 2 + 4, -p + 6, w, p), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-w / 2, -alt, w, alt), cor_lado)
	draw_rect(Rect2(-w / 2, -alt - p, w, p), cor_topo)
	draw_rect(Rect2(-w / 2, -alt - p, w, p + alt), Color(0, 0, 0, 0.5), false, 1.5)


func _draw() -> void:
	if _draw_arte():
		return
	var t := 0.45 if aberto else 1.0
	match tipo:
		"armario":
			_caixa(Vector2(40, 18), 46, Color("6d4c2f").darkened(1.0 - t * 0.3 - 0.7), Color("8a6440"))
			draw_line(Vector2(0, -46), Vector2(0, -2), Color(0, 0, 0, 0.4), 1.5)
			if aberto:
				draw_rect(Rect2(-18, -44, 16, 40), Color(0.05, 0.04, 0.03))
		"geladeira":
			_caixa(Vector2(36, 20), 58, Color("c9ced3"), Color("e8ecef"))
			draw_line(Vector2(-14, -40), Vector2(-14, -28), Color(0.3, 0.3, 0.3), 2)
			if aberto:
				draw_rect(Rect2(-16, -56, 30, 52), Color(0.85, 0.92, 1.0, 0.6))
		"prateleira":
			_caixa(Vector2(70, 18), 38, Color("4d5560"), Color("6b7480"))
			for k in 3:
				draw_line(Vector2(-33, -10 - k * 12), Vector2(33, -10 - k * 12), Color(0, 0, 0, 0.35), 1.5)
			if not aberto:
				for k in 5:
					draw_rect(Rect2(-30 + k * 13, -20, 9, 9), Color.from_hsv(k * 0.17, 0.6, 0.8))
		"arsenal":
			_caixa(Vector2(40, 20), 56, Color("39424d"), Color("56616e"))
			for k in 3:
				draw_line(Vector2(-14 + k * 8, -50), Vector2(-14 + k * 8, -40), Color(0, 0, 0, 0.5), 2)
			draw_circle(Vector2(12, -28), 3, Color("ffd166") if not aberto else Color(0.3, 0.3, 0.3))
		"ferramentas":
			_caixa(Vector2(36, 18), 18, Color("a5302b") if not aberto else Color("5a2421"), Color("c8433d"))
		"mochila":
			draw_circle(Vector2(3, 2), 13, Color(0, 0, 0, 0.3))
			draw_circle(Vector2(0, -8), 12, Color("4a5d3a") if not aberto else Color("2e3a24"))
			draw_rect(Rect2(-7, -10, 14, 8), Color("3b4a2e"))
		"cama":
			draw_rect(Rect2(-30, -46, 64, 96), Color(0, 0, 0, 0.3))
			_caixa(Vector2(60, 90), 10, Color("5b4636"), Color("8c7b6b"))
			draw_rect(Rect2(-26, -96, 52, 22), Color("e9e4dc"))
			draw_rect(Rect2(-28, -70, 56, 58), Color("5f7fa8"))
		"radio":
			_caixa(Vector2(64, 30), 26, Color("6b4f2a"), Color("8a6a40"))
			_caixa(Vector2(30, 14), 14, Color("2a2a2a"), Color("444"))
			draw_line(Vector2(10, -60), Vector2(18, -84), Color(0.7, 0.7, 0.7), 2)
			var pisca: bool = sin(fase) > 0.0 and main.historia.radio_ativo()
			draw_circle(Vector2(-8, -48), 3, Color(1, 0.2, 0.2) if pisca else Color(0.3, 0.1, 0.1))
		"tambor":
			draw_circle(Vector2(0, 0), 26, Color(0.4, 1.0, 0.3, 0.12))
			_caixa(Vector2(28, 18), 38, Color("8a7a1a") if not aberto else Color("4a4210"), Color("b0a030"))
			draw_rect(Rect2(-14, -26, 28, 6), Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(0, -14), 5, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(0, -56), 4, Color(0.5, 1, 0.3, 0.6))
		"bomba":
			_caixa(Vector2(30, 26), 52, Color("c0392b"), Color("e74c3c"))
			draw_rect(Rect2(-10, -66, 20, 12), Color(0.1, 0.1, 0.1))
			draw_string(ThemeDB.fallback_font, Vector2(-12, -56), "%d" % usos, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffd166"))
		"arvore":
			if madeira <= 0:
				draw_circle(Vector2(0, 0), 13, Color("5a3d22"))
				draw_circle(Vector2(0, 0), 9, Color("8a6a46"))
				return
			draw_circle(Vector2(18, 10), 44, Color(0, 0, 0, 0.25))
			draw_rect(Rect2(-8, -46, 16, 46), Color("5a3d22"))
			var al := 1.0
			for j in main.jogadores:
				if j.global_position.y < global_position.y and j.global_position.distance_to(global_position + Vector2(0, -70)) < 60:
					al = 0.35
			var verde := Color(0.15, 0.30, 0.14, al) if madeira >= 4 else Color(0.20, 0.30, 0.12, al)
			draw_circle(Vector2(0, -72), 44, verde)
			draw_circle(Vector2(-12, -84), 28, Color(0.22, 0.40, 0.19, al))
			draw_circle(Vector2(14, -66), 22, Color(0.18, 0.34, 0.16, al))
		"porta":
			if aco:
				var cor := Color("6a7078") if tabuas else Color(0.3, 0.32, 0.35, 0.5)
				if horiz:
					draw_rect(Rect2(-largura / 2, -56, largura, 56), cor)
				else:
					draw_rect(Rect2(-8, -largura / 2 - 40, 16, largura), cor)
				return
			if tabuas:
				var n := 4
				var a := clampf(vida / 160.0, 0.3, 1.0)
				for k in n:
					var off := (k - n / 2.0 + 0.5) * (largura / n)
					if horiz:
						draw_rect(Rect2(off - largura / n / 2 + 2, -34, largura / n - 4, 40), Color(0.55 * a + 0.1, 0.40 * a + 0.05, 0.22 * a))
					else:
						draw_rect(Rect2(-8, off - largura / n / 2 + 2 - 20, 16, largura / n - 4), Color(0.55 * a + 0.1, 0.40 * a + 0.05, 0.22 * a))
				if horiz:
					draw_line(Vector2(-largura / 2, -26), Vector2(largura / 2, -10), Color("3d2a16"), 5)
		"fogueira":
			draw_circle(Vector2(0, 0), 22, Color(0.1, 0.08, 0.06))
			for k in 6:
				var a := k * TAU / 6
				draw_line(Vector2.from_angle(a) * 18, Vector2.from_angle(a + 0.4) * 4, Color("5a3d22"), 5)
			var f := 0.8 + sin(fase) * 0.2
			draw_circle(Vector2(0, -8), 12 * f, Color(1.0, 0.45, 0.1, 0.9))
			draw_circle(Vector2(0, -12), 7 * f, Color(1.0, 0.8, 0.3, 0.95))


func _draw_arte() -> bool:
	## versão desenhada (arte/pecas). false = usa as formas antigas
	if SPRITE.has(tipo):
		var sp: Array = SPRITE[tipo]
		var mod := Color.WHITE
		if aberto:
			mod = Color(0.62, 0.6, 0.58)          # já revirado: fica apagado
		if tipo == "arsenal":
			mod = mod * Color(0.7, 0.8, 1.0)       # armário da polícia: frio, azulado
		if tipo == "fogueira":
			mod = Color(1, 1, 1, clampf(vida / 30.0, 0.35, 1.0))
		var base := 6.0 if tipo != "cama" else 46.0
		if not A.peca(self, sp[0], sp[1], base, mod):
			return false
		if tipo == "radio" and main.historia.radio_ativo() and sin(fase) > 0.0:
			draw_circle(Vector2(-6, -48), 4, Color(1, 0.25, 0.2))
		if tipo == "tambor":
			draw_circle(Vector2(0, 0), 28, Color(0.4, 1.0, 0.3, 0.10))
		if tipo == "fogueira":
			var f := 0.8 + sin(fase) * 0.2
			draw_circle(Vector2(0, -22), 10 * f, Color(1.0, 0.75, 0.3, 0.35))
		if tipo == "bomba":
			draw_string(ThemeDB.fallback_font, Vector2(-30, -78), "%d L" % (usos * 10), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color("ffd166"))
		return true
	match tipo:
		"arvore":
			if madeira <= 0:
				return false
			var al := 1.0
			for j in main.jogadores:
				if j.global_position.y < global_position.y and j.global_position.distance_to(global_position + Vector2(0, -90)) < 80:
					al = 0.35
			var mod := Color(1, 1, 1, al) if madeira >= 4 else Color(0.85, 0.85, 0.7, al)
			return A.peca(self, "arvore", 170.0, 14.0, mod)
		"porta":
			if not horiz:
				return false
			if aco:
				if tabuas:
					return A.peca(self, "porta_bunker", largura + 20.0, 8.0)
				return false
			if tabuas:
				var a := clampf(vida / 160.0, 0.45, 1.0)
				return A.peca(self, "barricada", largura, 10.0, Color(a, a, a))
			return false
	return false
