extends Node2D
## DEADZONE — o "maestro": cria a cidade, os jogadores (coop local até 2), os zumbis, o dia e a noite,
## e passa a vez para a história (historia.gd) e para a tela (hud.gd). Tudo desenhado por código, em 2.5D:
## o mundo é ordenado pelo Y (quem está mais embaixo na tela aparece na frente).

const D := preload("res://dados.gd")
const T := 64
const MAPA := 72
const QUADRA := 18
const CICLO := 300.0      # dia 180 s, entardecer 20 s, noite 85 s, amanhecer 15 s
const RECORDE := "user://recorde.json"
const SAVE := "user://save.json"

enum { TITULO, JOGANDO, PAUSA, FIM, CONVERSA, MOCHILA, CAPITULO }

var estado := TITULO
var rng := RandomNumberGenerator.new()
var jogadores: Array = []
var zumbis: Array = []
var objetos: Array = []
var carros: Array = []
var npcs: Array = []
var predios: Array = []
var bloqueios: Array = []
var locais := {}
var manchas: Array = []
var fogos: Array = []         # molotov queimando {pos, t, luz}
var avisos: Array = []
var radiacao: Array = []      # zonas quentes {pos, raio, forca}
var vip: Node2D = null        # a Iara (IA) no jogo solo da história
var semente := 0
var n_gerados := 0            # objetos criados pela cidade (o save conta por índice)
var motivo_fim := ""

var tempo := 40.0
var dia := 1
var mortes := 0
var t_spawn := 0.0
var tremor := 0.0
var menu_sel := 0
var menu_dono := 1            # quem abriu a mochila
var mochila_aba := 0          # 0 = mochila, 1 = criar
var avisou_noite := false
var recorde := {"dias": 0, "mortes": 0, "nivel": 0}
var novo_recorde := false
var modo := "historia"

var mundo: Node2D
var chao: Node2D
var camada_sangue: Node2D
var cam: Camera2D
var escuro: CanvasModulate
var hud: Control
var historia: Node
var sons: Node
var tex_luz: Texture2D
var tex_cone: Texture2D


func _ready() -> void:
	_acoes()
	_ler_recorde()
	tex_luz = _textura_luz(false)
	tex_cone = _textura_luz(true)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hud = Control.new()
	hud.set_script(preload("res://hud.gd"))
	hud.main = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	sons = Node.new()
	sons.set_script(preload("res://sons.gd"))
	sons.main = self
	add_child(sons)
	_nova_partida()
	estado = TITULO


# ---------------------------------------------------------------- controles (jogador 1 e 2)

func _acoes() -> void:
	# padrão PlayStation: L anda, R mira, R2 usa a arma, R1 golpe, L2 corre, L1 molotov, ✕ usar (segure),
	# □ recarrega, ○ bandagem, △ mochila, setas ←→ trocam arma, ↑ lanterna, ↓ tocha, Options pausa
	var mapa := {
		"esquerda": {"k": [KEY_A, KEY_LEFT], "e": [[JOY_AXIS_LEFT_X, -1.0]]},
		"direita": {"k": [KEY_D, KEY_RIGHT], "e": [[JOY_AXIS_LEFT_X, 1.0]]},
		"cima": {"k": [KEY_W, KEY_UP], "e": [[JOY_AXIS_LEFT_Y, -1.0]]},
		"baixo": {"k": [KEY_S, KEY_DOWN], "e": [[JOY_AXIS_LEFT_Y, 1.0]]},
		"atirar": {"k": [KEY_K], "m": [MOUSE_BUTTON_LEFT], "e": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
		"golpe": {"k": [KEY_SPACE, KEY_J], "m": [MOUSE_BUTTON_RIGHT], "j": [JOY_BUTTON_RIGHT_SHOULDER]},
		"correr": {"k": [KEY_SHIFT], "e": [[JOY_AXIS_TRIGGER_LEFT, 1.0]], "j": [JOY_BUTTON_LEFT_STICK]},
		"arremessar": {"k": [KEY_G], "j": [JOY_BUTTON_LEFT_SHOULDER]},
		"interagir": {"k": [KEY_E, KEY_ENTER], "j": [JOY_BUTTON_A]},
		"recarregar": {"k": [KEY_R], "j": [JOY_BUTTON_X]},
		"curar": {"k": [KEY_H], "j": [JOY_BUTTON_B]},
		"mochila": {"k": [KEY_TAB, KEY_I], "j": [JOY_BUTTON_Y]},
		"arma_prox": {"k": [KEY_3], "j": [JOY_BUTTON_DPAD_RIGHT]},
		"arma_ant": {"k": [KEY_1], "j": [JOY_BUTTON_DPAD_LEFT]},
		"luz": {"k": [KEY_F], "j": [JOY_BUTTON_DPAD_UP]},
		"tocha": {"k": [KEY_T], "j": [JOY_BUTTON_DPAD_DOWN]},
		"pausa": {"k": [KEY_ESCAPE, KEY_P], "j": [JOY_BUTTON_START]},
		"voltar": {"k": [KEY_BACKSPACE], "j": [JOY_BUTTON_B]},
		"m_cima": {"k": [KEY_W, KEY_UP], "j": [JOY_BUTTON_DPAD_UP], "e": [[JOY_AXIS_LEFT_Y, -1.0]]},
		"m_baixo": {"k": [KEY_S, KEY_DOWN], "j": [JOY_BUTTON_DPAD_DOWN], "e": [[JOY_AXIS_LEFT_Y, 1.0]]},
		"m_esq": {"k": [KEY_A, KEY_LEFT], "j": [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER]},
		"m_dir": {"k": [KEY_D, KEY_RIGHT], "j": [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER]},
	}
	for n in [1, 2]:
		for nome in mapa:
			var acao := "p%d_%s" % [n, nome]
			if InputMap.has_action(acao):
				continue
			InputMap.add_action(acao, 0.35)
			var m: Dictionary = mapa[nome]
			if n == 1:    # teclado e mouse só para o jogador 1
				for t in m.get("k", []):
					var k := InputEventKey.new()
					k.physical_keycode = t
					InputMap.action_add_event(acao, k)
				for t in m.get("m", []):
					var mb := InputEventMouseButton.new()
					mb.button_index = t
					InputMap.action_add_event(acao, mb)
			for t in m.get("j", []):
				var b := InputEventJoypadButton.new()
				b.button_index = t
				b.device = n - 1
				InputMap.action_add_event(acao, b)
			for t in m.get("e", []):
				var ax := InputEventJoypadMotion.new()
				ax.axis = t[0]
				ax.axis_value = t[1]
				ax.device = n - 1
				InputMap.action_add_event(acao, ax)


func dispositivo(n: int) -> int:
	return n - 1 if Input.get_connected_joypads().has(n - 1) else -1


func apertou(acao: String) -> bool:
	## qualquer um dos dois jogadores (menus)
	return Input.is_action_just_pressed("p1_" + acao) or Input.is_action_just_pressed("p2_" + acao)


func jogando() -> bool:
	return estado == JOGANDO


# ---------------------------------------------------------------- luzes

func _textura_luz(cone: bool) -> Texture2D:
	var tam := 256
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := Vector2(tam / 2.0, tam / 2.0)
	for y in tam:
		for x in tam:
			var v := Vector2(x, y) - c
			var dist := v.length() / (tam / 2.0)
			var a := clampf(1.0 - dist, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			if cone:
				var ang := absf(v.angle())
				var borda := clampf((0.42 - ang) / 0.18, 0.0, 1.0)
				a = a * borda
				a = maxf(a, clampf(1.0 - dist * 9.0, 0.0, 1.0) * 0.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func nova_luz(cor: Color, escala: float, sombra: bool, cone := false) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex_cone if cone else tex_luz
	l.texture_scale = escala * (2.4 if cone else 1.0)
	l.color = cor
	l.energy = 1.0
	l.shadow_enabled = sombra
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	return l


# ---------------------------------------------------------------- partida

func _limpar() -> void:
	if mundo:
		mundo.queue_free()
		mundo = null
	if escuro:
		escuro.queue_free()
	for lista in [jogadores, zumbis, objetos, carros, npcs, predios, bloqueios, manchas, fogos, avisos, radiacao]:
		lista.clear()
	vip = null
	motivo_fim = ""
	locais = {}
	if historia:
		historia.queue_free()


func _nova_partida(p_modo := "historia", p_semente := -1) -> void:
	_limpar()
	modo = p_modo
	tempo = 40.0
	dia = 1
	mortes = 0
	avisou_noite = false
	novo_recorde = false
	# a mesma semente gera a mesma cidade: é assim que o save reconstrói o mapa
	semente = p_semente if p_semente >= 0 else randi() % 1000000000
	rng.seed = semente

	historia = Node.new()
	historia.set_script(preload("res://historia.gd"))
	historia.main = self
	historia.modo = modo
	add_child(historia)

	mundo = Node2D.new()
	mundo.y_sort_enabled = true
	add_child(mundo)
	move_child(mundo, 0)
	chao = Node2D.new()
	chao.z_index = -10
	chao.draw.connect(_desenhar_chao)
	mundo.add_child(chao)
	camada_sangue = Node2D.new()
	camada_sangue.z_index = -9
	camada_sangue.draw.connect(_desenhar_sangue)
	mundo.add_child(camada_sangue)
	escuro = CanvasModulate.new()
	add_child(escuro)

	preload("res://cidade.gd").new().gerar(self)
	n_gerados = objetos.size()
	rng.seed = semente + 7     # daqui para frente o sorteio não precisa repetir

	_novo_jogador(1, locais["inicio"])
	_npc("rocha", locais["rocha"])
	if modo == "historia":
		vip = CharacterBody2D.new()
		vip.set_script(preload("res://vip.gd"))
		vip.main = self
		vip.position = locais["iara"]
		mundo.add_child(vip)
	cam.limit_left = 0
	cam.limit_top = -12 * T
	cam.limit_right = MAPA * T
	cam.limit_bottom = MAPA * T
	cam.global_position = locais["inicio"]
	cam.reset_smoothing()

	# a delegacia não está vazia
	for i in 4:
		_nascer_zumbi(locais["policiais"] + Vector2(rng.randf_range(-300, 300), rng.randf_range(-260, 260)), "policial")
	for i in 16:
		_nascer_zumbi()
	_npc("tiao", locais["ponte"])
	_ciclo()


func _novo_jogador(n: int, p: Vector2) -> Node2D:
	var j := CharacterBody2D.new()
	j.set_script(preload("res://jogador.gd"))
	j.main = self
	j.n = n
	if n == 2 and modo == "historia":
		j.nome = "Iara"              # no coop, o jogador 2 é a carga
		j.vip = true
		j.hp_max = 80.0
		j.hp = 80.0
		j.cor_roupa = Color("2f6b4f")
		j.cor_cabelo = Color("1b1410")
	elif n == 2:
		j.nome = "Lia"
		j.cor_roupa = Color("b5523a")
		j.cor_cabelo = Color("7a3b1a")
	j.position = p
	j.mochila = {"bandagem": 1}
	if n == 1:
		j.armas = ["punhos", "pistola"]
		j.arma = "punhos"
		j.pentes = {"pistola": 3}
	else:
		j.armas = ["punhos", "faca"]
		j.arma = "faca"
	mundo.add_child(j)
	jogadores.append(j)
	return j


func _entrar_p2() -> void:
	if jogadores.size() >= 2 or not Input.get_connected_joypads().has(1):
		return
	var p1: Node2D = jogadores[0]
	var onde := p1.global_position + Vector2(40, 10)
	if vip:
		onde = vip.global_position
		vip.queue_free()
		vip = null
	var j := _novo_jogador(2, onde)
	j.luz_on = p1.luz_on
	aviso("%s entrou no jogo (coop)!" % j.nome, Color("ffd166"))


func _npc(id: String, p: Vector2) -> Node2D:
	var n := CharacterBody2D.new()
	n.set_script(preload("res://npc.gd"))
	n.main = self
	n.id = id
	match id:
		"tiao":
			n.nome = "Tião"
			n.roupa = Color("6b5a2a")
			n.cabelo = Color("9a9a9a")
		"nina":
			n.nome = "Nina"
		"rocha":
			n.nome = "Comandante Rocha"
			n.roupa = Color("3d4a2e")
			n.cabelo = Color("2a2a2a")
	n.position = p
	mundo.add_child(n)
	npcs.append(n)
	return n


func criar_npc(id: String) -> void:
	if id == "nina":
		var casas: Array = locais.get("casas_nina", [])
		var p: Vector2 = casas[rng.randi_range(0, casas.size() - 1)] if not casas.is_empty() else locais["mercado"]
		_npc("nina", p)
		aviso("Você ouve alguém pedindo ajuda numa casa por perto…", Color("9db4ff"))
		locais["nina"] = p


func interativos() -> Array:
	var r: Array = objetos.filter(func(o): return is_instance_valid(o))
	r.append_array(carros)
	r.append_array(npcs.filter(func(o): return is_instance_valid(o)))
	for j in jogadores:
		if j.caido:
			r.append(j)
	if vip:
		r.append(vip)
	return r


func alvos() -> Array:
	## quem os zumbis podem morder: os jogadores e a Iara
	var r: Array = jogadores.duplicate()
	if vip:
		r.append(vip)
	return r


func vip_morreu() -> void:
	motivo_fim = "A Iara morreu. A missão acabou."
	fim_de_jogo()


func radiacao_em(p: Vector2) -> float:
	var n := 0.0
	for z in radiacao:
		var dist: float = p.distance_to(z["pos"])
		if dist < z["raio"]:
			n = maxf(n, (1.0 - dist / z["raio"]) * z["forca"])
	return n


# ---------------------------------------------------------------- zumbis

func _nascer_zumbi(onde := Vector2.ZERO, tipo := "") -> void:
	var p := onde
	if p == Vector2.ZERO:
		for tentativa in 20:
			p = Vector2(rng.randf_range(2, MAPA - 2), rng.randf_range(2, MAPA - 2)) * T
			var perto_demais := false
			var longe_demais := true
			for j in jogadores:
				var dist: float = p.distance_to(j.global_position)
				if dist < 820.0:
					perto_demais = true
				if dist < 2200.0:
					longe_demais = false
			if jogadores.is_empty():
				perto_demais = p.distance_to(locais["inicio"]) < 900.0
				longe_demais = false
			if perto_demais or longe_demais or _ocupado(p):
				p = Vector2.ZERO
				continue
			break
	if p == Vector2.ZERO or _ocupado(p):
		return
	var z := CharacterBody2D.new()
	z.set_script(preload("res://zumbi.gd"))
	z.main = self
	z.position = p
	if tipo == "":
		var s := rng.randf()
		tipo = "andarilho"
		if radiacao_em(p) > 0.15 and s < 0.6:
			tipo = "irradiado"
		elif dia >= 3 and s < 0.08:
			tipo = "brutamontes"
		elif dia >= 2 and s < 0.08 + minf(0.04 + dia * 0.03, 0.3):
			tipo = "corredor"
	z.tipo = tipo
	match tipo:
		"corredor":
			z.hp_max = 32.0 + dia * 4.0
			z.vel = rng.randf_range(140, 165)
		"brutamontes":
			z.hp_max = 180.0 + dia * 20.0
			z.vel = 58.0
			z.dano = 22.0
		"irradiado":
			z.hp_max = 75.0 + dia * 8.0
			z.vel = rng.randf_range(55, 75)
			z.dano = 12.0
		_:
			z.hp_max = 40.0 + (dia - 1) * 6.0
			z.vel = rng.randf_range(60, 86) + (dia - 1) * 3.0
	z.hp = z.hp_max
	z.dano = maxf(z.dano, 8.0 + (dia - 1) * 1.5)
	mundo.add_child(z)
	zumbis.append(z)


func _ocupado(p: Vector2) -> bool:
	if locais.has("bunker") and predios.size() > locais["bunker"] and predios[locais["bunker"]]["r"].grow(80).has_point(p):
		return true
	for b in bloqueios:
		if b.grow(10).has_point(p):
			return true
	for pr in predios:
		var r: Rect2 = pr["r"]
		if r.grow(18).has_point(p) and not r.grow(-30).has_point(p):
			return true      # em cima da parede
	return false


func zumbi_morreu(z: Node2D) -> void:
	if not zumbis.has(z):
		return
	zumbis.erase(z)
	mortes += 1
	for j in jogadores:
		j.ganhar_xp(14 if z.tipo == "brutamontes" else 10)
	sangue(z.global_position, 22.0)
	if z.tipo == "policial" and rng.randf() < 0.45:
		_largar("balas_9mm", rng.randi_range(1, 3), z.global_position)
	elif rng.randf() < 0.05:
		_largar("bandagem", 1, z.global_position)
	z.queue_free()


func _largar(item: String, q: int, p: Vector2) -> void:
	var o: Node2D = preload("res://objeto.gd").new()
	o.main = self
	o.tipo = "mochila"
	o.garantido = [[item, q]]
	o.position = p
	o.set_meta("so_garantido", true)
	mundo.add_child(o)
	objetos.append(o)


func raio_visao(j: Node) -> float:
	var n := noite()
	var base := lerpf(430.0, 260.0, n)
	if n > 0.3 and j.luz_chamativa():
		base += 220.0 * n        # luz acesa no escuro chama atenção
	return base


func barulho(origem: Vector2, raio: float) -> void:
	for z in zumbis:
		if z.global_position.distance_to(origem) < raio:
			z.ouvir(origem)


func mira_assistida(de: Vector2, dir: Vector2, alcance: float) -> Vector2:
	## ajuda na mira com o controle: puxa o tiro para o zumbi mais perto do centro (até 12°)
	var melhor := dir
	var menor := 0.21
	for z in zumbis:
		var v: Vector2 = z.global_position - de
		if v.length() > alcance:
			continue
		var ang := absf(dir.angle_to(v))
		if ang < menor:
			menor = ang
			melhor = v.normalized()
	return melhor


func molotov(p: Vector2) -> void:
	var l := nova_luz(Color(1.0, 0.55, 0.2), 2.2, false)
	l.position = p
	mundo.add_child(l)
	fogos.append({"pos": p, "t": 5.0, "luz": l})
	sons.tocar("molotov", p)
	barulho(p, 500.0)
	tremer(5.0)


func sangue(p: Vector2, r: float) -> void:
	manchas.append({"pos": p + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), "r": r, "a": rng.randf() * TAU})
	if manchas.size() > 260:
		manchas.pop_front()
	camada_sangue.queue_redraw()


func tremer(q: float) -> void:
	tremor = maxf(tremor, q)


func aviso(texto: String, cor := Color.WHITE) -> void:
	avisos.append({"texto": texto, "cor": cor, "t": 3.0})
	if avisos.size() > 5:
		avisos.pop_front()


# ---------------------------------------------------------------- coop

func coleira(j: Node2D) -> void:
	## no coop os dois não podem se afastar demais (a câmera mostra os dois)
	if jogadores.size() < 2:
		return
	var outro: Node2D = jogadores[1] if j == jogadores[0] else jogadores[0]
	if outro.carro:
		return
	var v: Vector2 = j.global_position - outro.global_position
	if v.length() > 900.0:
		j.global_position = outro.global_position + v.normalized() * 900.0


func jogador_caiu(j: Node) -> void:
	if jogadores.size() > 1:
		j.caido = true
		j.t_caido = 30.0
		aviso("%s caiu! Segure ✕ perto para reanimar" % j.nome, Color("ff6b6b"))
		if jogadores.all(func(x): return x.caido):
			fim_de_jogo()
	else:
		fim_de_jogo()


func jogador_morreu(_j: Node) -> void:
	fim_de_jogo()


# ---------------------------------------------------------------- acampar

func dormir(cama: Node, j: Node) -> void:
	if tempo < 170.0:
		aviso("Ainda é dia. Durma quando escurecer.", Color(1, 1, 1, 0.8))
		return
	var p: Dictionary = predios[cama.casa]
	for porta in p["portas"]:
		if not porta.tabuas:
			aviso("Barricade todas as portas desta casa antes de dormir (%d)." % p["portas"].size(), Color("ff9f43"))
			return
	var r: Rect2 = p["r"]
	for z in zumbis:
		if r.has_point(z.global_position):
			aviso("Tem zumbi dentro da casa!", Color("ff6b6b"))
			return
	for o in jogadores:
		if o != j and not r.has_point(o.global_position) and not o.caido:
			aviso("Espere %s entrar na casa." % o.nome, Color("ff9f43"))
			return
	if vip and not r.has_point(vip.global_position):
		if vip.global_position.distance_to(j.global_position) < 450.0:
			vip.global_position = cama.global_position + Vector2(70, 0)
		else:
			aviso("Espere a Iara entrar na casa.", Color("ff9f43"))
			return
	# a noite passa: as barricadas aguentam (ou não)
	estado = CAPITULO
	hud.fade = 1.0
	hud.fade_texto = "Vocês dormem com um olho aberto…" if jogadores.size() > 1 else "Você dorme com um olho aberto…"
	hud.so_fade = true
	await get_tree().create_timer(2.2).timeout
	tempo = 2.0
	dia += 1
	avisou_noite = false
	for porta in p["portas"]:
		if rng.randf() < 0.15 * dia:
			porta.bater(60.0)
	for o in alvos():
		o.hp = minf(o.hp_max, o.hp + 35.0)
	for o in jogadores:
		o.fome = maxf(10.0, o.fome - 25.0)
		o.estamina = 100.0
	for z in zumbis:
		z.queue_free()
	zumbis.clear()
	historia.evento("dormiu", {})
	hud.so_fade = false
	hud.fade = 0.0
	estado = JOGANDO
	aviso("Dia %d. Sobreviveram à noite: +35 de vida." % dia, Color("7ff0c4"))
	# dormir salva: esta cama vira o ponto de retorno
	salvar(cama.global_position)
	aviso("Progresso salvo. Esta cama é o seu ponto de retorno.", Color("ffd166"))
	sons.tocar("salvo", null, -6.0)


# ---------------------------------------------------------------- salvar e carregar

func tem_save() -> bool:
	return FileAccess.file_exists(SAVE)


func ler_save() -> Dictionary:
	if not tem_save():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return d if typeof(d) == TYPE_DICTIONARY else {}


func salvar(spawn: Vector2) -> void:
	var js: Array = []
	for j in jogadores:
		js.append({"n": j.n, "hp": j.hp, "hp_max": j.hp_max, "estamina": j.estamina, "fome": j.fome, "nivel": j.nivel,
			"xp": j.xp, "forca": j.forca, "mochila": j.mochila, "armas": j.armas, "arma": j.arma, "pentes": j.pentes,
			"gasolina": j.gasolina, "bateria": j.bateria, "rad": j.rad})
	var obs: Array = []
	for i in mini(n_gerados, objetos.size()):
		var o = objetos[i]
		if not is_instance_valid(o):
			continue
		if o.aberto or o.tabuas or o.madeira < 4 or o.usos < 3:
			obs.append({"i": i, "aberto": o.aberto, "tabuas": o.tabuas != null, "vida": o.vida, "madeira": o.madeira, "usos": o.usos})
	var cs: Array = []
	for i in carros.size():
		var c = carros[i]
		cs.append({"i": i, "x": c.global_position.x, "y": c.global_position.y, "angulo": c.angulo, "combustivel": c.combustivel,
			"tanque": c.tanque, "saqueado": c.saqueado})
	var ns: Array = []
	for n in npcs:
		if is_instance_valid(n) and n.id == "nina" and not n.sumir:
			ns.append({"id": n.id, "x": n.global_position.x, "y": n.global_position.y})
	var dados := {
		"versao": 1, "modo": modo, "semente": semente, "dia": dia, "tempo": tempo, "mortes": mortes,
		"spawn": [spawn.x, spawn.y], "historia": historia.estado_salvo(), "jogadores": js,
		"vip": {"hp": vip.hp} if vip else null, "objetos": obs, "carros": cs, "npcs": ns,
		"objetivo": historia.objetivo(),
	}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados))


func carregar() -> bool:
	var d := ler_save()
	if d.is_empty():
		return false
	_nova_partida(d.get("modo", "historia"), int(d["semente"]))
	dia = int(d["dia"])
	tempo = float(d["tempo"])
	mortes = int(d.get("mortes", 0))
	historia.restaurar(d.get("historia", {}))
	var spawn := Vector2(d["spawn"][0], d["spawn"][1])
	var js: Array = d.get("jogadores", [])
	for dj in js:
		if int(dj["n"]) == 2:
			if not Input.get_connected_joypads().has(1):
				continue
			_entrar_p2()
		var j = jogadores[int(dj["n"]) - 1] if jogadores.size() >= int(dj["n"]) else null
		if j == null:
			continue
		for k in ["hp", "hp_max", "estamina", "fome", "forca", "gasolina", "bateria", "rad"]:
			j.set(k, float(dj[k]))
		j.nivel = int(dj["nivel"])
		j.xp = int(dj["xp"])
		j.mochila = {}
		for k in dj["mochila"]:
			j.mochila[k] = int(dj["mochila"][k])
		j.armas = Array(dj["armas"])
		j.arma = dj["arma"]
		j.pentes = {}
		for k in dj["pentes"]:
			j.pentes[k] = int(dj["pentes"][k])
		j.global_position = spawn + Vector2(60 * (int(dj["n"]) - 1), 40)
	if vip:
		vip.global_position = spawn + Vector2(-60, 40)
		if d.get("vip") != null:
			vip.hp = float(d["vip"]["hp"])
	for o in d.get("objetos", []):
		var i := int(o["i"])
		if i >= objetos.size():
			continue
		var ob = objetos[i]
		ob.aberto = o["aberto"]
		ob.madeira = int(o["madeira"])
		ob.usos = int(o["usos"])
		if o["tabuas"] and not ob.tabuas:
			ob.barricar()
			ob.vida = float(o["vida"])
		ob.queue_redraw()
	for c in d.get("carros", []):
		var i := int(c["i"])
		if i >= carros.size():
			continue
		var car = carros[i]
		car.global_position = Vector2(c["x"], c["y"])
		car.angulo = float(c["angulo"])
		car.combustivel = float(c["combustivel"])
		car.tanque = float(c["tanque"])
		car.saqueado = c["saqueado"]
		car.queue_redraw()
	for n in d.get("npcs", []):
		_npc(n["id"], Vector2(n["x"], n["y"]))
	# zumbis recomeçam longe da cama
	for z in zumbis:
		z.queue_free()
	zumbis.clear()
	cam.global_position = spawn
	cam.reset_smoothing()
	_ciclo()
	estado = JOGANDO
	aviso("Você acorda na cama. Dia %d." % dia, Color("ffd166"))
	return true


# ---------------------------------------------------------------- laço

func _process(d: float) -> void:
	match estado:
		TITULO:
			_menu_titulo()
		JOGANDO:
			if apertou("pausa") and not (Input.is_action_just_pressed("p2_pausa") and jogadores.size() < 2):
				estado = PAUSA
				menu_sel = 0
			elif Input.is_action_just_pressed("p1_mochila") or (Input.is_action_just_pressed("p2_mochila") and jogadores.size() > 1):
				menu_dono = 2 if Input.is_action_just_pressed("p2_mochila") and jogadores.size() > 1 else 1
				estado = MOCHILA
				menu_sel = 0
			else:
				_jogar(d)
			if Input.is_action_just_pressed("p2_pausa") and jogadores.size() < 2:
				_entrar_p2()
		PAUSA:
			_menu(["Continuar", "Recomeçar", "Voltar ao título", "Sair do jogo"])
		CONVERSA:
			if apertou("m_cima"):
				historia.comando("cima")
			elif apertou("m_baixo"):
				historia.comando("baixo")
			elif apertou("interagir"):
				historia.comando("ok")
		MOCHILA:
			_menu_mochila()
		FIM, CAPITULO:
			if not hud.so_fade and hud.fade <= 0.05:
				if estado == FIM and tem_save() and apertou("interagir"):
					carregar()                       # volta para a última cama
				elif apertou("interagir") or (estado == FIM and apertou("voltar")):
					_nova_partida(modo)
					estado = TITULO
					menu_sel = 0
	for a in avisos:
		a["t"] -= d
	avisos = avisos.filter(func(a): return a["t"] > 0.0)
	_camera(d)
	hud.queue_redraw()


func opcoes_titulo() -> Array:
	var ops: Array = []
	var d := ler_save()
	if not d.is_empty():
		var o: String = d.get("objetivo", "")
		ops.append({"id": "continuar", "txt": "Continuar — dia %d%s" % [int(d["dia"]), (" · " + o) if o != "" else " · sobrevivência"]})
	ops.append({"id": "historia", "txt": "Nova história: Capítulo 1 — A Carga"})
	ops.append({"id": "sobrevivencia", "txt": "Sobrevivência (sem fim)"})
	ops.append({"id": "sair", "txt": "Sair"})
	return ops


func _menu_titulo() -> void:
	var ops := opcoes_titulo()
	menu_sel = clampi(menu_sel, 0, ops.size() - 1)
	if apertou("m_cima"):
		menu_sel = wrapi(menu_sel - 1, 0, ops.size())
		sons.tocar("ui", null, -10.0)
	elif apertou("m_baixo"):
		menu_sel = wrapi(menu_sel + 1, 0, ops.size())
		sons.tocar("ui", null, -10.0)
	elif apertou("interagir"):
		sons.tocar("ui_ok", null, -8.0)
		match ops[menu_sel]["id"]:
			"continuar":
				carregar()
			"historia", "sobrevivencia":
				var m: String = ops[menu_sel]["id"]
				if m != modo or historia.etapa > 0:
					_nova_partida(m)
				estado = JOGANDO
				if Input.get_connected_joypads().has(1):
					_entrar_p2()
				historia.iniciar()
			"sair":
				get_tree().quit()


func _menu(ops: Array) -> void:
	if apertou("m_cima"):
		menu_sel = wrapi(menu_sel - 1, 0, ops.size())
	elif apertou("m_baixo"):
		menu_sel = wrapi(menu_sel + 1, 0, ops.size())
	elif apertou("voltar") or apertou("pausa"):
		estado = JOGANDO
	elif apertou("interagir"):
		match menu_sel:
			0:
				estado = JOGANDO
			1:
				var com_p2 := jogadores.size() > 1
				_nova_partida(modo)
				estado = JOGANDO
				if com_p2:
					_entrar_p2()
				historia.iniciar()
			2:
				_nova_partida(modo)
				estado = TITULO
				menu_sel = 0
			3:
				get_tree().quit()


func itens_mochila(j: Node) -> Array:
	var r: Array = []
	for a in j.armas:
		r.append({"arma": a})
	var chaves: Array = j.mochila.keys()
	chaves.sort()
	for k in chaves:
		r.append({"item": k, "q": j.mochila[k]})
	return r


func pode_criar(j: Node, rec: Dictionary) -> bool:
	for k in rec["usa"]:
		if j.qtd(k) < rec["usa"][k]:
			return false
	if rec.has("gasolina") and j.gasolina < rec["gasolina"]:
		return false
	if rec.get("arma", false) and j.tem_arma(rec["faz"]):
		return false
	return true


func _menu_mochila() -> void:
	var p := "p%d_" % menu_dono
	var j: Node = jogadores[menu_dono - 1]
	var lista: Array = itens_mochila(j) if mochila_aba == 0 else D.RECEITAS
	if Input.is_action_just_pressed(p + "mochila") or Input.is_action_just_pressed(p + "voltar") or Input.is_action_just_pressed(p + "pausa"):
		estado = JOGANDO
		return
	if Input.is_action_just_pressed(p + "m_esq") or Input.is_action_just_pressed(p + "m_dir"):
		mochila_aba = 1 - mochila_aba
		menu_sel = 0
		return
	if lista.is_empty():
		return
	menu_sel = clampi(menu_sel, 0, lista.size() - 1)
	if Input.is_action_just_pressed(p + "m_cima"):
		menu_sel = wrapi(menu_sel - 1, 0, lista.size())
	elif Input.is_action_just_pressed(p + "m_baixo"):
		menu_sel = wrapi(menu_sel + 1, 0, lista.size())
	elif Input.is_action_just_pressed(p + "interagir"):
		if mochila_aba == 0:
			var it: Dictionary = lista[menu_sel]
			if it.has("arma"):
				j.arma = it["arma"]
				aviso("%s: %s na mão" % [j.nome, D.nome(it["arma"])], Color(1, 1, 1, 0.8))
			else:
				j.usar_item(it["item"])
		else:
			var rec: Dictionary = lista[menu_sel]
			if not pode_criar(j, rec):
				aviso("Faltam materiais.", Color("ff8a8a"))
				return
			for k in rec["usa"]:
				j.gastar(k, rec["usa"][k])
			if rec.has("gasolina"):
				j.gasolina -= rec["gasolina"]
			if rec.get("colocar", false):
				var o: Node2D = preload("res://objeto.gd").new()
				o.main = self
				o.tipo = rec["faz"]
				o.position = j.global_position + j.mira * 50.0
				mundo.add_child(o)
				objetos.append(o)
				aviso("Fogueira acesa.", Color("ff9f43"))
				estado = JOGANDO
			elif rec.get("arma", false):
				j.receber("arma:" + rec["faz"], 1)
			else:
				j.receber(rec["faz"], rec["q"])


func _jogar(d: float) -> void:
	var antes := tempo
	tempo += d
	if tempo >= CICLO:
		tempo -= CICLO
		dia += 1
		avisou_noite = false
		for j in jogadores:
			j.ganhar_xp(25)
		aviso("Amanheceu. Dia %d: os zumbis estão mais fortes." % dia, Color("ffd166"))
	historia.checar_saida()
	if antes < 175.0 and tempo >= 175.0 and not avisou_noite:
		avisou_noite = true
		aviso("Está escurecendo. Ache um lugar seguro, acenda a lanterna (↑).", Color("ff9f43"))
		historia.entardecer()
	_ciclo()

	var n := noite()
	var alvo := mini(int((14 + dia * 3) * (1.0 + n * 1.3)), 60)
	t_spawn -= d
	if t_spawn <= 0.0 and zumbis.size() < alvo:
		t_spawn = 0.5 if n > 0.5 else 1.3
		_nascer_zumbi()
	for z in zumbis.duplicate():
		var longe := true
		for j in jogadores:
			if z.global_position.distance_to(j.global_position) < 2600.0:
				longe = false
		if longe and not z.alerta:
			zumbis.erase(z)
			z.queue_free()

	for f in fogos:
		f["t"] -= d
		f["luz"].energy = 1.2 + randf() * 0.4
		for z in zumbis:
			if z.global_position.distance_to(f["pos"]) < 90.0:
				z.pegar_fogo()
		for j in jogadores:
			if j.global_position.distance_to(f["pos"]) < 70.0:
				j.receber_dano(10.0 * d, false)
		if f["t"] <= 0.0:
			f["luz"].queue_free()
	fogos = fogos.filter(func(f): return f["t"] > 0.0)
	if not fogos.is_empty():
		camada_sangue.queue_redraw()

	# Tião chama quando alguém chega perto da ponte
	if modo == "historia" and not historia.concluido and historia.etapa >= 4 and not historia.falou.has("tiao_chamou"):
		for j in jogadores:
			var p: Vector2 = j.carro.global_position if j.carro else j.global_position
			if p.y < 2 * T and absf(p.x - 38 * T) < 4 * T:
				historia.falou["tiao_chamou"] = true
				aviso("Tião: \"Ei! Chega mais, motorista! Desce do carro e vem falar comigo.\"", Color("ffd166"))


func _camera(d: float) -> void:
	if jogadores.is_empty():
		return
	var soma := Vector2.ZERO
	var minimo := Vector2(1e9, 1e9)
	var maximo := Vector2(-1e9, -1e9)
	for j in jogadores:
		var p: Vector2 = j.carro.global_position if j.carro else j.global_position
		soma += p
		minimo = minimo.min(p)
		maximo = maximo.max(p)
	cam.global_position = soma / jogadores.size() + Vector2(0, -20)
	var dirigindo: bool = jogadores.any(func(j): return j.carro != null)
	var base := 1.0 if dirigindo else 1.35
	var tam := get_viewport_rect().size
	var esp := (maximo - minimo) + Vector2(420, 360)
	var z := minf(base, minf(tam.x / esp.x, tam.y / esp.y))
	z = maxf(z, 0.7)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), clampf(d * 3.0, 0.0, 1.0))
	if tremor > 0.0:
		tremor = maxf(0.0, tremor - 30.0 * d)
		cam.offset = Vector2(randf_range(-tremor, tremor), randf_range(-tremor, tremor))
	else:
		cam.offset = Vector2.ZERO


func noite() -> float:
	## 0 = dia claro, 1 = noite fechada
	if tempo < 180.0:
		return 0.0
	if tempo < 200.0:
		return (tempo - 180.0) / 20.0
	if tempo < 285.0:
		return 1.0
	return 1.0 - (tempo - 285.0) / 15.0


func _ciclo() -> void:
	var n := noite()
	var dia_cor := Color(1.0, 0.97, 0.92)
	var tarde := Color(0.95, 0.72, 0.55)
	var noite_cor := Color(0.07, 0.08, 0.15)
	var c := dia_cor.lerp(noite_cor, n)
	if tempo > 160.0 and tempo < 200.0:
		c = dia_cor.lerp(tarde, clampf((tempo - 160.0) / 20.0, 0.0, 1.0)).lerp(noite_cor, n)
	escuro.color = c


func fim_de_jogo() -> void:
	if estado == FIM:
		return
	estado = FIM
	hud.fade = 1.0
	hud.fade_texto = ""
	var nivel: int = jogadores[0].nivel
	if dia > recorde["dias"] or (dia == recorde["dias"] and mortes > recorde["mortes"]):
		recorde = {"dias": dia, "mortes": mortes, "nivel": nivel}
		novo_recorde = true
		var f := FileAccess.open(RECORDE, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(recorde))


func fim_capitulo() -> void:
	historia.concluido = true
	estado = CAPITULO
	hud.fade = 1.0
	hud.fade_texto = ""


func _ler_recorde() -> void:
	if FileAccess.file_exists(RECORDE):
		var r = JSON.parse_string(FileAccess.get_file_as_string(RECORDE))
		if typeof(r) == TYPE_DICTIONARY:
			recorde = {"dias": int(r.get("dias", 0)), "mortes": int(r.get("mortes", 0)), "nivel": int(r.get("nivel", 0))}


# ---------------------------------------------------------------- chão (desenhado uma vez)

func _desenhar_chao() -> void:
	var n := chao
	var lado := MAPA * T
	# rio e ponte
	n.draw_rect(Rect2(-T, -13 * T, lado + 2 * T, 13 * T), Color("1f3a4a"))
	var r2 := RandomNumberGenerator.new()
	r2.seed = 3
	for i in 260:
		var p := Vector2(r2.randf() * lado, -r2.randf() * 11.5 * T - 0.5 * T)
		n.draw_line(p, p + Vector2(r2.randf_range(20, 60), 0), Color(0.5, 0.7, 0.8, 0.25), 2)
	n.draw_rect(Rect2(-T, -1.2 * T, lado + 2 * T, 1.2 * T), Color("3b4a2e"))
	n.draw_rect(Rect2(36 * T, -12 * T, 4 * T, 12 * T), Color("4a4a4e"))
	var y := -12.0 * T
	while y < 0:
		n.draw_line(Vector2(36 * T, y), Vector2(40 * T, y), Color(0, 0, 0, 0.2), 2)
		y += 24
	# mato
	n.draw_rect(Rect2(0, 0, lado, lado), Color("4a5a3a"))
	r2.seed = 7
	for i in 1100:
		var p := Vector2(r2.randf() * lado, r2.randf() * lado)
		n.draw_circle(p, r2.randf_range(8, 30), Color(0.25, 0.32, 0.2, 0.25))
	# calçadas, ruas e faixas
	for i in range(0, MAPA, QUADRA):
		var x := i * T
		n.draw_rect(Rect2(x - 12, 0, 4 * T + 24, lado), Color("8a8a84"))
		n.draw_rect(Rect2(0, x - 12, lado, 4 * T + 24), Color("8a8a84"))
	for i in range(0, MAPA, QUADRA):
		var x := i * T
		n.draw_rect(Rect2(x, 0, 4 * T, lado), Color("3a3c40"))
		n.draw_rect(Rect2(0, x, lado, 4 * T), Color("3a3c40"))
	for i in range(0, MAPA, QUADRA):
		var x := i * T + 2 * T
		var yy := 0
		while yy < lado:
			n.draw_rect(Rect2(x - 3, yy, 6, 36), Color(0.9, 0.8, 0.3, 0.5))
			n.draw_rect(Rect2(yy, x - 3, 36, 6), Color(0.9, 0.8, 0.3, 0.5))
			yy += 90
	# rachaduras e lixo
	r2.seed = 11
	for i in 500:
		var p := Vector2(r2.randf() * lado, r2.randf() * lado)
		n.draw_line(p, p + Vector2(r2.randf_range(-30, 30), r2.randf_range(-30, 30)), Color(0, 0, 0, 0.18), 2)
	# zonas de radiação: chão manchado e plantas mortas
	for z in radiacao:
		var c: Vector2 = z["pos"]
		var raio: float = z["raio"]
		for k in 6:
			n.draw_circle(c, raio * (1.0 - k * 0.15), Color(0.55, 0.6, 0.1, 0.05))
		r2.seed = int(c.x + c.y)
		for k in 40:
			var p := c + Vector2.from_angle(r2.randf() * TAU) * r2.randf() * raio
			n.draw_circle(p, r2.randf_range(4, 14), Color(0.35, 0.4, 0.05, 0.35))
		# piso das construções
	for p in predios:
		var r: Rect2 = p["r"]
		n.draw_rect(r, p["piso"])
		if p["tipo"] == "casa":
			var yy: float = r.position.y
			while yy < r.end.y:
				n.draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(0, 0, 0, 0.12), 2)
				yy += 22
		elif p["tipo"] != "patio":
			var xx: float = r.position.x
			while xx < r.end.x:
				n.draw_line(Vector2(xx, r.position.y), Vector2(xx, r.end.y), Color(0, 0, 0, 0.08), 1)
				xx += 48
		if p.has("nome"):
			n.draw_string(ThemeDB.fallback_font, r.position + Vector2(20, r.size.y - 20), p["nome"].to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.12))


func _desenhar_sangue() -> void:
	var n := camada_sangue
	for m in manchas:
		var p: Vector2 = m["pos"]
		var r: float = m["r"]
		n.draw_circle(p, r, Color(0.35, 0.03, 0.03, 0.55))
		n.draw_circle(p + Vector2.from_angle(m["a"]) * r * 0.8, r * 0.45, Color(0.35, 0.03, 0.03, 0.5))
	for f in fogos:
		for k in 8:
			var a: float = k * TAU / 8 + f["t"]
			n.draw_circle(f["pos"] + Vector2.from_angle(a) * randf_range(10, 60), randf_range(10, 22), Color(1, randf_range(0.35, 0.7), 0.1, 0.7))
