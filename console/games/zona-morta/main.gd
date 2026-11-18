extends Node2D
## Zona Morta — protótipo 0.1. Cidade gerada a cada partida, ciclo de dia e noite, caixas para revirar,
## zumbis que enxergam e ouvem, e o sobrevivente sobe de nível. Tudo desenhado por código.

const T := 64                 # tamanho de um "bloco" do mapa, em pixels
const MAPA := 72              # o mapa tem MAPA x MAPA blocos (4608 px de lado)
const QUADRA := 18            # a cada 18 blocos, uma rua de 4
const CICLO := 240.0          # um dia inteiro em segundos (dia 150 s, entardecer, noite 60 s, amanhecer)
const RECORDE := "user://recorde.json"

enum { TITULO, JOGANDO, PAUSA, FIM }

var estado := TITULO
var rng := RandomNumberGenerator.new()
var jogador: CharacterBody2D
var zumbis: Array = []
var caixas: Array = []        # {pos: Vector2, aberta: bool}
var itens: Array = []         # coisas no chão: {pos, tipo, q}
var predios: Array = []       # Rect2 dos prédios (zumbis não nascem dentro… quase nunca)
var bloqueios: Array = []     # Rect2 de carros e árvores
var paredes: Array = []       # Rect2 desenhados
var arvores: Array = []       # {pos, r}
var carros: Array = []        # {r: Rect2, cor}
var manchas: Array = []       # sangue no chão {pos, r, a}

var tempo := 20.0             # segundos dentro do dia
var dia := 1
var mortes := 0
var t_spawn := 0.0
var busca := {}               # caixa sendo revirada {caixa, t}
var avisos: Array = []        # {texto, cor, t}
var tremor := 0.0
var menu_sel := 0
var recorde := {"dias": 0, "mortes": 0, "nivel": 0}
var novo_recorde := false

var mundo: Node2D
var chao: Node2D
var camada_sangue: Node2D
var camada_obj: Node2D
var camada_copas: Node2D
var cam: Camera2D
var escuro: CanvasModulate
var luz: PointLight2D
var hud: Control
var fonte: Font


func _ready() -> void:
	_acoes()
	fonte = ThemeDB.fallback_font
	_ler_recorde()
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_desenhar_hud)
	ui.add_child(hud)
	_nova_partida()
	estado = TITULO


# ---------------------------------------------------------------- controles

func _acoes() -> void:
	# como num jogo de PlayStation: L analógico anda, R analógico mira, R2 atira, R1 golpeia,
	# ✕ revira/confirma, □ recarrega, △ bandagem, L1 come, L2 corre, Options pausa
	# k = tecla, m = botão do mouse, j = botão do controle, e = eixo do controle [eixo, sentido]
	var mapa := {
		"esquerda": {"k": [KEY_A, KEY_LEFT], "e": [[JOY_AXIS_LEFT_X, -1.0]], "j": [JOY_BUTTON_DPAD_LEFT]},
		"direita": {"k": [KEY_D, KEY_RIGHT], "e": [[JOY_AXIS_LEFT_X, 1.0]], "j": [JOY_BUTTON_DPAD_RIGHT]},
		"cima": {"k": [KEY_W, KEY_UP], "e": [[JOY_AXIS_LEFT_Y, -1.0]], "j": [JOY_BUTTON_DPAD_UP]},
		"baixo": {"k": [KEY_S, KEY_DOWN], "e": [[JOY_AXIS_LEFT_Y, 1.0]], "j": [JOY_BUTTON_DPAD_DOWN]},
		"atirar": {"k": [KEY_K], "m": [MOUSE_BUTTON_LEFT], "e": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
		"golpe": {"k": [KEY_SPACE, KEY_J], "m": [MOUSE_BUTTON_RIGHT], "j": [JOY_BUTTON_RIGHT_SHOULDER]},
		"interagir": {"k": [KEY_E, KEY_ENTER], "j": [JOY_BUTTON_A]},
		"recarregar": {"k": [KEY_R], "j": [JOY_BUTTON_X]},
		"curar": {"k": [KEY_H], "j": [JOY_BUTTON_Y]},
		"comer": {"k": [KEY_F], "j": [JOY_BUTTON_LEFT_SHOULDER]},
		"correr": {"k": [KEY_SHIFT], "e": [[JOY_AXIS_TRIGGER_LEFT, 1.0]], "j": [JOY_BUTTON_LEFT_STICK]},
		"pausa": {"k": [KEY_ESCAPE, KEY_P], "j": [JOY_BUTTON_START]},
		"voltar": {"k": [KEY_BACKSPACE], "j": [JOY_BUTTON_B]},
	}
	for nome in mapa:
		if InputMap.has_action(nome):
			continue
		InputMap.add_action(nome, 0.3)
		var m: Dictionary = mapa[nome]
		for t in m.get("k", []):
			var k := InputEventKey.new()
			k.physical_keycode = t
			InputMap.action_add_event(nome, k)
		for t in m.get("m", []):
			var mb := InputEventMouseButton.new()
			mb.button_index = t
			InputMap.action_add_event(nome, mb)
		for t in m.get("j", []):
			var b := InputEventJoypadButton.new()
			b.button_index = t
			b.device = -1
			InputMap.action_add_event(nome, b)
		for t in m.get("e", []):
			var ax := InputEventJoypadMotion.new()
			ax.axis = t[0]
			ax.axis_value = t[1]
			ax.device = -1
			InputMap.action_add_event(nome, ax)


func jogando() -> bool:
	return estado == JOGANDO


# ---------------------------------------------------------------- partida

func _nova_partida() -> void:
	if mundo:
		mundo.queue_free()
	zumbis.clear()
	caixas.clear()
	itens.clear()
	predios.clear()
	bloqueios.clear()
	paredes.clear()
	arvores.clear()
	carros.clear()
	manchas.clear()
	avisos.clear()
	busca = {}
	tempo = 20.0
	dia = 1
	mortes = 0
	novo_recorde = false
	rng.randomize()

	mundo = Node2D.new()
	add_child(mundo)
	move_child(mundo, 0)
	chao = Node2D.new()
	chao.draw.connect(_desenhar_chao.bind(chao))
	mundo.add_child(chao)
	camada_sangue = Node2D.new()
	camada_sangue.draw.connect(_desenhar_sangue.bind(camada_sangue))
	mundo.add_child(camada_sangue)
	camada_obj = Node2D.new()
	camada_obj.draw.connect(_desenhar_objetos.bind(camada_obj))
	mundo.add_child(camada_obj)

	_gerar_cidade()

	jogador = CharacterBody2D.new()
	jogador.set_script(load("res://jogador.gd"))
	jogador.main = self
	jogador.position = Vector2(QUADRA * 2 + 2, QUADRA * 2 + 2) * T
	mundo.add_child(jogador)

	camada_copas = Node2D.new()
	camada_copas.draw.connect(_desenhar_copas.bind(camada_copas))
	mundo.add_child(camada_copas)

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.zoom = Vector2(1.35, 1.35)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAPA * T
	cam.limit_bottom = MAPA * T
	jogador.add_child(cam)
	cam.make_current()

	escuro = CanvasModulate.new()
	mundo.add_child(escuro)
	luz = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	luz.texture = tex
	luz.texture_scale = 1.6
	luz.color = Color(1.0, 0.92, 0.78)
	luz.shadow_enabled = true
	luz.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	jogador.add_child(luz)

	for i in 14:
		_nascer_zumbi(true)
	_ciclo(0.0)


func _gerar_cidade() -> void:
	var lado := MAPA * T
	var e := 24.0
	for r in [Rect2(-e, -e, lado + 2 * e, e), Rect2(-e, lado, lado + 2 * e, e), Rect2(-e, 0, e, lado), Rect2(lado, 0, e, lado)]:
		_parede(r, false)
	var n := MAPA / QUADRA
	for by in n:
		for bx in n:
			var bloco := Rect2((bx * QUADRA + 4) * T, (by * QUADRA + 4) * T, (QUADRA - 4) * T, (QUADRA - 4) * T)
			if bx == 2 and by == 2:
				_praca(bloco)             # o ponto de partida é uma praça, para respirar
				continue
			var s := rng.randf()
			if s < 0.62:
				_predio(bloco)
			elif s < 0.82:
				_praca(bloco)
			else:
				_estacionamento(bloco)
	# carros abandonados pelas ruas
	for i in 40:
		var vertical := rng.randf() < 0.5
		var faixa := rng.randi_range(0, n - 1) * QUADRA
		var ao_longo := rng.randf_range(2.0, MAPA - 2.0) * T
		var p := Vector2(faixa * T + rng.randf_range(0.6, 3.4) * T, ao_longo) if vertical else Vector2(ao_longo, faixa * T + rng.randf_range(0.6, 3.4) * T)
		if p.distance_to(Vector2(QUADRA * 2 + 2, QUADRA * 2 + 2) * T) < 300:
			continue
		_carro(p, vertical)


func _predio(bloco: Rect2) -> void:
	var w := rng.randi_range(7, 12) * T
	var h := rng.randi_range(7, 12) * T
	var r := Rect2(bloco.position + Vector2(rng.randi_range(1, int(bloco.size.x / T) - w / T - 1), rng.randi_range(1, int(bloco.size.y / T) - h / T - 1)) * Vector2(T, T), Vector2(w, h))
	predios.append(r)
	var e := 14.0
	var porta := rng.randi_range(0, 3)
	var lados := [
		[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
		[Vector2(r.position.x, r.end.y), r.end], [r.position, Vector2(r.position.x, r.end.y)],
	]
	for i in 4:
		var a: Vector2 = lados[i][0]
		var b: Vector2 = lados[i][1]
		var horiz := absf(a.y - b.y) < 1.0
		var comp := (b - a).length()
		if i == porta:
			var meio := rng.randf_range(T * 1.5, comp - T * 2.5)
			_segmento(a, horiz, meio, e)
			_segmento(a + (Vector2(meio + T * 1.6, 0) if horiz else Vector2(0, meio + T * 1.6)), horiz, comp - meio - T * 1.6, e)
		else:
			_segmento(a, horiz, comp, e)
	# parede interna com passagem
	if w >= 9 * T and rng.randf() < 0.7:
		var x := r.position.x + roundf(w / 2.0 / T) * T
		var vao := rng.randf_range(T, h - 2.5 * T)
		_parede(Rect2(x - e / 2, r.position.y, e, vao), true)
		_parede(Rect2(x - e / 2, r.position.y + vao + 1.6 * T, e, h - vao - 1.6 * T), true)
	for i in rng.randi_range(1, 3):
		var p := r.position + Vector2(rng.randf_range(40, w - 40), rng.randf_range(40, h - 40))
		caixas.append({"pos": p, "aberta": false})


func _segmento(a: Vector2, horiz: bool, comp: float, e: float) -> void:
	if comp <= 2:
		return
	if horiz:
		_parede(Rect2(a.x, a.y - e / 2, comp, e), true)
	else:
		_parede(Rect2(a.x - e / 2, a.y, e, comp), true)


func _parede(r: Rect2, visivel: bool) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 1
	corpo.position = r.get_center()
	var f := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	f.shape = s
	corpo.add_child(f)
	var oc := LightOccluder2D.new()
	var pol := OccluderPolygon2D.new()
	var m := r.size / 2
	pol.polygon = PackedVector2Array([-m, Vector2(m.x, -m.y), m, Vector2(-m.x, m.y)])
	oc.occluder = pol
	corpo.add_child(oc)
	mundo.add_child(corpo)
	if visivel:
		paredes.append(r)


func _praca(bloco: Rect2) -> void:
	for i in rng.randi_range(6, 12):
		var p := bloco.position + Vector2(rng.randf_range(60, bloco.size.x - 60), rng.randf_range(60, bloco.size.y - 60))
		if p.distance_to(Vector2(QUADRA * 2 + 2, QUADRA * 2 + 2) * T) < 220:
			continue
		var r := rng.randf_range(34, 52)
		arvores.append({"pos": p, "r": r})
		var corpo := StaticBody2D.new()
		corpo.position = p
		var f := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 14
		f.shape = c
		corpo.add_child(f)
		mundo.add_child(corpo)
		bloqueios.append(Rect2(p - Vector2(20, 20), Vector2(40, 40)))
	if rng.randf() < 0.5:
		caixas.append({"pos": bloco.get_center() + Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200)), "aberta": false})


func _estacionamento(bloco: Rect2) -> void:
	for i in rng.randi_range(4, 9):
		var p := bloco.position + Vector2(rng.randf_range(100, bloco.size.x - 100), rng.randf_range(100, bloco.size.y - 100))
		_carro(p, rng.randf() < 0.5)


func _carro(centro: Vector2, vertical: bool) -> void:
	var tam := Vector2(58, 118) if vertical else Vector2(118, 58)
	var r := Rect2(centro - tam / 2, tam)
	for b in bloqueios:
		if b.grow(16).intersects(r):
			return
	var cores := [Color("8d2b2b"), Color("2b4f8d"), Color("c0c0c0"), Color("3f3f3f"), Color("c9a227"), Color("e0e0e0")]
	carros.append({"r": r, "cor": cores[rng.randi_range(0, cores.size() - 1)], "v": vertical})
	bloqueios.append(r)
	var corpo := StaticBody2D.new()
	corpo.position = centro
	var f := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = tam
	f.shape = s
	corpo.add_child(f)
	mundo.add_child(corpo)
	if rng.randf() < 0.25:   # porta-malas aberto
		caixas.append({"pos": centro + (Vector2(0, tam.y / 2 + 22) if vertical else Vector2(tam.x / 2 + 22, 0)), "aberta": false})


# ---------------------------------------------------------------- zumbis

func _nascer_zumbi(inicio := false) -> void:
	var p := Vector2.ZERO
	for tentativa in 20:
		p = Vector2(rng.randf_range(2, MAPA - 2), rng.randf_range(2, MAPA - 2)) * T
		var d := p.distance_to(jogador.global_position) if jogador else 9999.0
		if d < (900.0 if inicio else 780.0) or d > 2200.0:
			continue
		var livre := true
		for b in bloqueios:
			if b.grow(20).has_point(p):
				livre = false
				break
		if livre:
			for w in paredes:
				if w.grow(24).has_point(p):
					livre = false
					break
		if livre:
			break
		p = Vector2.ZERO
	if p == Vector2.ZERO:
		return
	var z := CharacterBody2D.new()
	z.set_script(load("res://zumbi.gd"))
	z.main = self
	z.position = p
	z.corredor = dia >= 2 and rng.randf() < minf(0.08 + dia * 0.03, 0.35)
	z.hp_max = 40.0 + (dia - 1) * 6.0
	z.hp = z.hp_max
	z.vel = rng.randf_range(62, 88) * (1.9 if z.corredor else 1.0) + (dia - 1) * 3.0
	z.dano = 8.0 + (dia - 1) * 1.5
	mundo.add_child(z)
	mundo.move_child(z, camada_obj.get_index() + 1)
	zumbis.append(z)


func zumbi_morreu(z: Node2D) -> void:
	if not zumbis.has(z):
		return
	zumbis.erase(z)
	mortes += 1
	jogador.ganhar_xp(12 if z.corredor else 10)
	sangue(z.global_position, 22.0)
	if rng.randf() < 0.14:
		itens.append({"pos": z.global_position, "tipo": "municao", "q": rng.randi_range(2, 4)})
	elif rng.randf() < 0.04:
		itens.append({"pos": z.global_position, "tipo": "bandagem", "q": 1})
	camada_obj.queue_redraw()
	z.queue_free()


func raio_visao() -> float:
	return 300.0 if _noite() > 0.5 else 430.0


func barulho(origem: Vector2, raio: float) -> void:
	for z in zumbis:
		if z.global_position.distance_to(origem) < raio:
			z.ouvir(origem)


func mira_assistida(de: Vector2, dir: Vector2) -> Vector2:
	# ajuda na mira com o controle: puxa o tiro para o zumbi mais perto do centro (até 12°)
	var melhor := dir
	var menor := 0.21
	for z in zumbis:
		var v: Vector2 = z.global_position - de
		if v.length() > 600.0:
			continue
		var ang := absf(dir.angle_to(v))
		if ang < menor:
			menor = ang
			melhor = v.normalized()
	return melhor


func sangue(p: Vector2, r: float) -> void:
	manchas.append({"pos": p + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), "r": r, "a": rng.randf() * TAU})
	if manchas.size() > 260:
		manchas.pop_front()
	camada_sangue.queue_redraw()


func tremer(q: float) -> void:
	tremor = maxf(tremor, q)


func aviso(texto: String, cor := Color.WHITE) -> void:
	avisos.append({"texto": texto, "cor": cor, "t": 2.8})
	if avisos.size() > 4:
		avisos.pop_front()


# ---------------------------------------------------------------- laço

func _process(d: float) -> void:
	match estado:
		TITULO:
			if Input.is_action_just_pressed("interagir") or Input.is_action_just_pressed("pausa"):
				estado = JOGANDO
				aviso("Dia 1. Revire as caixas e aguente a noite.", Color("ffd166"))
		JOGANDO:
			if Input.is_action_just_pressed("pausa"):
				estado = PAUSA
				menu_sel = 0
			else:
				_jogar(d)
		PAUSA:
			_menu(["Continuar", "Recomeçar", "Sair do jogo"])
		FIM:
			if Input.is_action_just_pressed("interagir"):
				_nova_partida()
				estado = JOGANDO
			elif Input.is_action_just_pressed("voltar"):
				get_tree().quit()
	for a in avisos:
		a["t"] -= d
	avisos = avisos.filter(func(a): return a["t"] > 0.0)
	if tremor > 0.0 and cam:
		tremor = maxf(0.0, tremor - 30.0 * d)
		cam.offset = Vector2(randf_range(-tremor, tremor), randf_range(-tremor, tremor))
	if camada_copas:
		camada_copas.queue_redraw()
	hud.queue_redraw()


func _menu(opcoes: Array) -> void:
	if Input.is_action_just_pressed("cima"):
		menu_sel = wrapi(menu_sel - 1, 0, opcoes.size())
	elif Input.is_action_just_pressed("baixo"):
		menu_sel = wrapi(menu_sel + 1, 0, opcoes.size())
	elif Input.is_action_just_pressed("voltar") or Input.is_action_just_pressed("pausa"):
		estado = JOGANDO
	elif Input.is_action_just_pressed("interagir"):
		match menu_sel:
			0:
				estado = JOGANDO
			1:
				_nova_partida()
				estado = JOGANDO
			2:
				get_tree().quit()


func _jogar(d: float) -> void:
	var antes := tempo
	tempo += d
	if tempo >= CICLO:
		tempo -= CICLO
		dia += 1
		jogador.ganhar_xp(25)
		aviso("Amanheceu. Dia %d: os zumbis estão mais fortes." % dia, Color("ffd166"))
	if antes < 150.0 and tempo >= 150.0:
		aviso("Está escurecendo. Ache um lugar seguro.", Color("ff9f43"))
	_ciclo(d)

	# população: mais zumbis à noite e a cada dia
	var alvo := mini(int((16 + dia * 3) * (1.0 + _noite() * 1.2)), 70)
	t_spawn -= d
	if t_spawn <= 0.0 and zumbis.size() < alvo:
		t_spawn = 0.6 if _noite() > 0.5 else 1.4
		_nascer_zumbi()
	for z in zumbis.duplicate():   # longe demais: some (e nasce outro perto)
		if z.global_position.distance_to(jogador.global_position) > 2600.0 and not z.alerta:
			zumbis.erase(z)
			z.queue_free()

	# itens no chão: pega ao passar por cima
	for it in itens.duplicate():
		if it["pos"].distance_to(jogador.global_position) < 30.0:
			_pegar(it["tipo"], it["q"])
			itens.erase(it)
			camada_obj.queue_redraw()

	# revirar caixa: segure ✕ perto dela
	var perto: Variant = caixa_perto()
	if busca.is_empty():
		if perto and Input.is_action_just_pressed("interagir"):
			busca = {"caixa": perto, "t": 0.0}
	else:
		if not Input.is_action_pressed("interagir") or busca["caixa"]["pos"].distance_to(jogador.global_position) > 70.0:
			busca = {}
		else:
			busca["t"] += d
			if busca["t"] >= 1.0:
				_abrir(busca["caixa"])
				busca = {}


func interromper_busca() -> void:
	busca = {}


func caixa_perto() -> Variant:
	for c in caixas:
		if not c["aberta"] and c["pos"].distance_to(jogador.global_position) < 56.0:
			return c
	return null


func _abrir(c: Dictionary) -> void:
	c["aberta"] = true
	camada_obj.queue_redraw()
	jogador.ganhar_xp(5)
	var s := rng.randf()
	if s < 0.42:
		_pegar("municao", rng.randi_range(3, 8))
	elif s < 0.66:
		_pegar("bandagem", 1)
	elif s < 0.92:
		_pegar("comida", rng.randi_range(1, 2))
	else:
		_pegar("municao", 12)
		_pegar("bandagem", 1)
	barulho(c["pos"], 180.0)


func _pegar(tipo: String, q: int) -> void:
	match tipo:
		"municao":
			jogador.reserva += q
			aviso("+%d balas" % q, Color("ffd166"))
		"bandagem":
			jogador.bandagens += q
			aviso("+%d bandagem" % q, Color("7ff0c4"))
		"comida":
			jogador.comida += q
			aviso("+%d lata de comida" % q, Color("7ff0c4"))


func _noite() -> float:
	# 0 = dia claro, 1 = noite fechada
	if tempo < 150.0:
		return 0.0
	if tempo < 165.0:
		return (tempo - 150.0) / 15.0
	if tempo < 225.0:
		return 1.0
	return 1.0 - (tempo - 225.0) / 15.0


func _ciclo(_d: float) -> void:
	var n := _noite()
	var dia_cor := Color(1.0, 0.97, 0.92)
	var noite_cor := Color(0.10, 0.12, 0.20)
	escuro.color = dia_cor.lerp(noite_cor, n)
	luz.energy = n * 1.25
	luz.visible = n > 0.02


func fim_de_jogo() -> void:
	if estado != JOGANDO:
		return
	estado = FIM
	if dia > recorde["dias"] or (dia == recorde["dias"] and mortes > recorde["mortes"]):
		recorde = {"dias": dia, "mortes": mortes, "nivel": jogador.nivel}
		novo_recorde = true
		var f := FileAccess.open(RECORDE, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(recorde))


func _ler_recorde() -> void:
	if FileAccess.file_exists(RECORDE):
		var r = JSON.parse_string(FileAccess.get_file_as_string(RECORDE))
		if typeof(r) == TYPE_DICTIONARY:
			recorde = {"dias": int(r.get("dias", 0)), "mortes": int(r.get("mortes", 0)), "nivel": int(r.get("nivel", 0))}


# ---------------------------------------------------------------- desenho do mundo

func _desenhar_chao(n: Node2D) -> void:
	var lado := MAPA * T
	n.draw_rect(Rect2(0, 0, lado, lado), Color("4a5a3a"))   # mato
	# grama com manchas
	var r2 := RandomNumberGenerator.new()
	r2.seed = 7
	for i in 900:
		var p := Vector2(r2.randf() * lado, r2.randf() * lado)
		n.draw_circle(p, r2.randf_range(8, 30), Color(0.25, 0.32, 0.2, 0.25))
	# ruas e calçadas
	for i in range(0, MAPA, QUADRA):
		var x := i * T
		n.draw_rect(Rect2(x - 10, 0, 4 * T + 20, lado), Color("8a8a84"))
		n.draw_rect(Rect2(0, x - 10, lado, 4 * T + 20), Color("8a8a84"))
	for i in range(0, MAPA, QUADRA):
		var x := i * T
		n.draw_rect(Rect2(x, 0, 4 * T, lado), Color("3a3c40"))
		n.draw_rect(Rect2(0, x, lado, 4 * T), Color("3a3c40"))
	for i in range(0, MAPA, QUADRA):
		var x := i * T + 2 * T
		var y := 0
		while y < lado:
			n.draw_rect(Rect2(x - 3, y, 6, 36), Color(0.9, 0.8, 0.3, 0.55))
			n.draw_rect(Rect2(y, x - 3, 36, 6), Color(0.9, 0.8, 0.3, 0.55))
			y += 90
	# piso dos prédios
	for r in predios:
		n.draw_rect(r, Color("5b4a3a"))
		var y2: float = r.position.y
		while y2 < r.end.y:
			n.draw_line(Vector2(r.position.x, y2), Vector2(r.end.x, y2), Color(0, 0, 0, 0.12), 2)
			y2 += 22


func _desenhar_sangue(n: Node2D) -> void:
	for m in manchas:
		var p: Vector2 = m["pos"]
		var r: float = m["r"]
		n.draw_circle(p, r, Color(0.35, 0.03, 0.03, 0.55))
		n.draw_circle(p + Vector2.from_angle(m["a"]) * r * 0.8, r * 0.45, Color(0.35, 0.03, 0.03, 0.5))


func _desenhar_objetos(n: Node2D) -> void:
	for c in carros:
		var r: Rect2 = c["r"]
		n.draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.35))
		n.draw_rect(r, c["cor"])
		var vidro := r.grow(-10)
		if c["v"]:
			n.draw_rect(Rect2(vidro.position.x, vidro.position.y + 18, vidro.size.x, 22), Color(0.15, 0.2, 0.25))
			n.draw_rect(Rect2(vidro.position.x, vidro.end.y - 30, vidro.size.x, 16), Color(0.15, 0.2, 0.25))
		else:
			n.draw_rect(Rect2(vidro.position.x + 18, vidro.position.y, 22, vidro.size.y), Color(0.15, 0.2, 0.25))
			n.draw_rect(Rect2(vidro.end.x - 30, vidro.position.y, 16, vidro.size.y), Color(0.15, 0.2, 0.25))
	for c in caixas:
		var p: Vector2 = c["pos"]
		var r := Rect2(p - Vector2(15, 12), Vector2(30, 24))
		n.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.3))
		n.draw_rect(r, Color("7a5a33") if not c["aberta"] else Color("4a3a26"))
		n.draw_rect(r, Color("2e2213"), false, 2)
		if not c["aberta"]:
			n.draw_line(r.position, r.end, Color("2e2213"), 2)
			n.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Color("2e2213"), 2)
	for it in itens:
		var p: Vector2 = it["pos"]
		var cor := Color("ffd166") if it["tipo"] == "municao" else Color("7ff0c4")
		n.draw_circle(p, 9, Color(0, 0, 0, 0.4))
		n.draw_rect(Rect2(p - Vector2(6, 4), Vector2(12, 8)), cor)
	for w in paredes:
		n.draw_rect(Rect2(w.position + Vector2(4, 6), w.size), Color(0, 0, 0, 0.3))
		n.draw_rect(w, Color("2a2a2e"))
		n.draw_rect(w, Color("4a4a50"), false, 2)


func _desenhar_copas(n: Node2D) -> void:
	# copas por cima de tudo; ficam transparentes quando o jogador passa embaixo
	for a in arvores:
		var p: Vector2 = a["pos"]
		var r: float = a["r"]
		var al := 0.35 if jogador and p.distance_to(jogador.global_position) < r else 0.95
		n.draw_circle(p + Vector2(8, 10), r, Color(0, 0, 0, 0.25 * al))
		n.draw_circle(p, r, Color(0.16, 0.30, 0.15, al))
		n.draw_circle(p - Vector2(r * 0.25, r * 0.25), r * 0.6, Color(0.22, 0.40, 0.2, al))


# ---------------------------------------------------------------- HUD

func _texto(t: String, p: Vector2, tam: int, cor := Color.WHITE, larg := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	hud.draw_string(fonte, p + Vector2(1, 2), t, al, larg, tam, Color(0, 0, 0, 0.6 * cor.a))
	hud.draw_string(fonte, p, t, al, larg, tam, cor)


func _botao(qual: String, c: Vector2) -> void:
	var cor := Color(1, 1, 1, 0.9)
	match qual:
		"cruz":
			hud.draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), cor, 2.0, true)
			hud.draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), cor, 2.0, true)
		"bola":
			hud.draw_arc(c, 6.5, 0, TAU, 24, cor, 2.0, true)
		"quadrado":
			hud.draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), cor, false, 2.0)
		"triangulo":
			hud.draw_polyline(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 6), c + Vector2(-7, 6), c + Vector2(0, -7)]), cor, 2.0, true)
		_:
			hud.draw_string(fonte, c + Vector2(-9, 5), qual, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cor)


func _barra(p: Vector2, larg: float, v: float, cor: Color, rotulo: String) -> void:
	hud.draw_rect(Rect2(p, Vector2(larg, 10)), Color(0, 0, 0, 0.55))
	hud.draw_rect(Rect2(p, Vector2(larg * clampf(v, 0, 1), 10)), cor)
	_texto(rotulo, p + Vector2(0, -5), 13, Color(1, 1, 1, 0.8))


func _desenhar_hud() -> void:
	var w := hud.size.x
	var h := hud.size.y
	if estado == TITULO:
		hud.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
		_texto("ZONA MORTA", Vector2(0, h * 0.40), 64, Color("e85d5d"), w, HORIZONTAL_ALIGNMENT_CENTER)
		_texto("Protótipo 0.1 · SkyStation", Vector2(0, h * 0.40 + 40), 18, Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
		if recorde["dias"] > 0:
			_texto("Recorde: %d dias · %d zumbis · nível %d" % [recorde["dias"], recorde["mortes"], recorde["nivel"]],
				Vector2(0, h * 0.40 + 76), 16, Color("ffd166"), w, HORIZONTAL_ALIGNMENT_CENTER)
		_botao("cruz", Vector2(w / 2 - 50, h * 0.66 - 6))
		_texto("Começar", Vector2(w / 2 - 34, h * 0.66), 20)
		_controles(Vector2(w / 2 - 300, h * 0.76))
		return
	var j := jogador
	# vinheta vermelha quando a vida está baixa ou acabou de apanhar
	var perigo := maxf(1.0 - j.hp / j.hp_max * 2.5, j.t_dano * 2.0)
	if perigo > 0.0:
		for i in 6:
			var e := 30.0 + i * 22
			hud.draw_rect(Rect2(0, 0, w, e), Color(0.6, 0, 0, 0.06 * perigo))
			hud.draw_rect(Rect2(0, h - e, w, e), Color(0.6, 0, 0, 0.06 * perigo))
			hud.draw_rect(Rect2(0, 0, e, h), Color(0.6, 0, 0, 0.06 * perigo))
			hud.draw_rect(Rect2(w - e, 0, e, h), Color(0.6, 0, 0, 0.06 * perigo))
	# barras
	_barra(Vector2(30, 40), 240, j.hp / j.hp_max, Color("e85d5d"), "Vida %d/%d" % [ceili(maxf(j.hp, 0.0)), int(j.hp_max)])
	_barra(Vector2(30, 76), 180, j.estamina / 100.0, Color("4fd1ff"), "Fôlego")
	_barra(Vector2(30, 112), 180, j.fome / 100.0, Color("f0a35e"), "Fome")
	_barra(Vector2(30, 148), 180, float(j.xp) / j.xp_proximo(), Color("ffd166"), "Nível %d" % j.nivel)
	# munição e mochila
	var carregando := "  recarregando…" if j.t_recarga > 0.0 else ""
	_texto("%d / %d%s" % [j.municao, j.reserva, carregando], Vector2(w - 260, h - 70), 30, Color.WHITE)
	_texto("Pistola", Vector2(w - 260, h - 98), 14, Color(1, 1, 1, 0.6))
	_botao("triangulo", Vector2(w - 252, h - 32))
	_texto("Bandagens %d" % j.bandagens, Vector2(w - 238, h - 26), 15)
	_botao("L1", Vector2(w - 116, h - 32))
	_texto("Comida %d" % j.comida, Vector2(w - 100, h - 26), 15)
	# dia e hora
	var n := _noite()
	var rel := "Noite" if n > 0.5 else ("Entardecer" if tempo > 140.0 else "Dia")
	_texto("Dia %d · %s" % [dia, rel], Vector2(w - 300, 46), 22, Color("ffd166") if n < 0.5 else Color("9db4ff"), 270, HORIZONTAL_ALIGNMENT_RIGHT)
	_texto("%d zumbis abatidos" % mortes, Vector2(w - 300, 72), 15, Color(1, 1, 1, 0.7), 270, HORIZONTAL_ALIGNMENT_RIGHT)
	# caixa por perto
	if estado == JOGANDO:
		var c: Variant = caixa_perto()
		if c:
			var sp: Vector2 = get_viewport().get_canvas_transform() * (c["pos"] as Vector2)
			if busca.is_empty():
				_botao("cruz", sp + Vector2(-46, -40))
				_texto("Revirar (segure)", sp + Vector2(-34, -34), 15)
			else:
				hud.draw_rect(Rect2(sp + Vector2(-40, -44), Vector2(80, 8)), Color(0, 0, 0, 0.6))
				hud.draw_rect(Rect2(sp + Vector2(-40, -44), Vector2(80 * busca["t"], 8)), Color("ffd166"))
	# avisos
	var y := h * 0.30
	for a in avisos:
		var al := clampf(a["t"], 0.0, 1.0)
		var cor: Color = a["cor"]
		cor.a = al
		_texto(a["texto"], Vector2(0, y), 20, cor, w, HORIZONTAL_ALIGNMENT_CENTER)
		y += 30
	if estado == PAUSA:
		hud.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.6))
		_texto("Pausa", Vector2(0, h * 0.32), 40, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
		var ops := ["Continuar", "Recomeçar", "Sair do jogo"]
		for i in ops.size():
			var py := h * 0.44 + i * 46
			if i == menu_sel:
				hud.draw_rect(Rect2(w / 2 - 160, py - 30, 320, 42), Color(1, 1, 1, 0.12))
			_texto(ops[i], Vector2(0, py), 22, Color.WHITE if i == menu_sel else Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
		_controles(Vector2(w / 2 - 300, h * 0.78))
	elif estado == FIM:
		hud.draw_rect(Rect2(0, 0, w, h), Color(0.15, 0, 0, 0.7))
		_texto("VOCÊ MORREU", Vector2(0, h * 0.36), 56, Color("e85d5d"), w, HORIZONTAL_ALIGNMENT_CENTER)
		_texto("Sobreviveu %d dia(s) · %d zumbis · nível %d" % [dia, mortes, j.nivel], Vector2(0, h * 0.36 + 50), 22, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
		if novo_recorde:
			_texto("Novo recorde!", Vector2(0, h * 0.36 + 84), 20, Color("ffd166"), w, HORIZONTAL_ALIGNMENT_CENTER)
		_botao("cruz", Vector2(w / 2 - 150, h * 0.62 - 6))
		_texto("Tentar de novo", Vector2(w / 2 - 134, h * 0.62), 18)
		_botao("bola", Vector2(w / 2 + 40, h * 0.62 - 6))
		_texto("Sair", Vector2(w / 2 + 56, h * 0.62), 18)


func _controles(p: Vector2) -> void:
	var lista := [["R2", "Atirar"], ["R1", "Golpe"], ["quadrado", "Recarregar"], ["triangulo", "Bandagem"],
		["L1", "Comer"], ["L2", "Correr"], ["cruz", "Revirar caixa"], ["Opt", "Pausa"]]
	for i in lista.size():
		var q := p + Vector2((i % 4) * 160, int(i / 4) * 30)
		_botao(lista[i][0], q + Vector2(8, -6))
		_texto(lista[i][1], q + Vector2(26, 0), 15, Color(1, 1, 1, 0.8))
