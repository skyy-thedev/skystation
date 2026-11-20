extends RefCounted
## Gera a Vila Aurora a cada partida: 4x4 quadras separadas por ruas. Cada quadra vira casas, mercado,
## delegacia, posto, garagem ou praça. Ao norte, depois do rio, a ponte do Tião (o fim do Capítulo 1).

const T := 64
const MAPA := 72
const QUADRA := 18

var m: Node2D
var rng: RandomNumberGenerator


func gerar(main: Node2D) -> void:
	m = main
	rng = main.rng
	var lado := MAPA * T
	# bordas do mapa (invisíveis); a de cima tem o vão da ponte
	var e := 30.0
	_parede_h(Rect2(-e, lado, lado + 2 * e, e), false)
	_parede_v(Rect2(-e, -12 * T, e, lado + 12 * T), false)
	_parede_v(Rect2(lado, -12 * T, e, lado + 12 * T), false)
	_parede_h(Rect2(0, -e, 36 * T, e), false)
	_parede_h(Rect2(40 * T, -e, lado - 40 * T, e), false)
	_ponte()

	var n := MAPA / QUADRA
	var inicio := Vector2i(1, 2)
	var longe: Array = []
	for by in n:
		for bx in n:
			if absi(bx - inicio.x) + absi(by - inicio.y) >= 3:
				longe.append(Vector2i(bx, by))
	var delegacia: Vector2i = longe[rng.randi_range(0, longe.size() - 1)]
	var papeis := ["mercado", "posto", "garagem", "garagem", "praca", "praca", "praca",
		"casas", "casas", "casas", "casas", "casas", "casas", "casas"]
	_embaralhar(papeis)
	for by in n:
		for bx in n:
			var b := Vector2i(bx, by)
			var r := Rect2((bx * QUADRA + 4) * T, (by * QUADRA + 4) * T, (QUADRA - 4) * T, (QUADRA - 4) * T)
			if b == inicio:
				_bunker(r)
			elif b == delegacia:
				_delegacia(r)
			else:
				match papeis.pop_back():
					"mercado": _mercado(r)
					"posto": _posto(r)
					"garagem": _garagem(r)
					"praca": _praca(r)
					_: _casas(r, false)
	# carros abandonados pelas ruas (alguns são viaturas; um ou dois ainda funcionam)
	var funcionais := 1
	for i in 46:
		var vertical := rng.randf() < 0.5
		var faixa := rng.randi_range(0, n - 1) * QUADRA
		var ao_longo := rng.randf_range(3.0, MAPA - 3.0) * T
		var p := Vector2(faixa * T + rng.randf_range(0.9, 3.1) * T, ao_longo) if vertical \
			else Vector2(ao_longo, faixa * T + rng.randf_range(0.9, 3.1) * T)
		if p.distance_to(m.locais["inicio"]) < 400:
			continue
		var c := _carro(p, PI / 2 if vertical else 0.0, rng.randf() < 0.1, funcionais > 0 and rng.randf() < 0.06)
		if c and c.funciona:
			funcionais -= 1
	_radiacao(n, inicio)
	_enfeites(n)


func _embaralhar(a: Array) -> void:
	## embaralha com o rng da partida (o shuffle() do Godot usa outro sorteio e quebraria o save)
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = a[i]
		a[i] = a[j]
		a[j] = x


# ---------------------------------------------------------------- peças

func _parede_h(r: Rect2, visivel := true, cor := Color("3a3a40"), topo := Color("5a5a62")) -> void:
	var p := preload("res://parede.gd").new()
	p.main = m
	p.tam = r.size
	p.visivel = visivel
	p.cor = cor
	p.topo = topo
	p.position = Vector2(r.get_center().x, r.end.y)
	m.mundo.add_child(p)


func _parede_v(r: Rect2, visivel := true, cor := Color("3a3a40"), topo := Color("5a5a62")) -> void:
	# paredes de pé são cortadas em pedaços de 64 px para o 2.5D ordenar certo com quem passa do lado
	var y := r.position.y
	while y < r.end.y - 0.5:
		var h := minf(64.0, r.end.y - y)
		_parede_h(Rect2(r.position.x, y, r.size.x, h), visivel, cor, topo)
		y += h


func _objeto(tipo: String, p: Vector2, extra := {}) -> Node2D:
	var o := preload("res://objeto.gd").new()
	o.main = m
	o.tipo = tipo
	o.position = p
	for k in extra:
		o.set(k, extra[k])
	m.mundo.add_child(o)
	m.objetos.append(o)
	return o


func _carro(p: Vector2, ang: float, viatura := false, funciona := false) -> Node2D:
	var r := Rect2(p - Vector2(70, 70), Vector2(140, 140))
	for b in m.bloqueios:
		if b.intersects(r):
			return null
	m.bloqueios.append(r)
	var c := preload("res://carro.gd").new()
	c.main = m
	c.position = p
	c.angulo = ang + (PI if rng.randf() < 0.5 else 0.0) + rng.randf_range(-0.25, 0.25)
	c.viatura = viatura
	c.funciona = funciona
	c.tanque = rng.randf_range(3, 9) if rng.randf() < 0.5 else 0.0
	var cores := [Color("8d2b2b"), Color("2b4f8d"), Color("b0b4b8"), Color("3f3f3f"), Color("c9a227"), Color("4b6b3a")]
	c.cor = cores[rng.randi_range(0, cores.size() - 1)]
	m.mundo.add_child(c)
	m.carros.append(c)
	return c


func _construcao(r: Rect2, tipo: String, portas: int, cor: Color, topo: Color, piso: Color, vao := 1.5) -> int:
	## paredes com vão de porta (cada porta vira um ponto para barricar). Devolve o índice da construção.
	var idx: int = m.predios.size()
	m.predios.append({"r": r, "tipo": tipo, "piso": piso, "portas": []})
	var e := 14.0
	var lados := [0, 1, 2, 3]
	_embaralhar(lados)
	var com_porta := lados.slice(0, portas)
	for lado in 4:
		var horiz := lado == 0 or lado == 2
		var a := r.position if lado != 1 and lado != 2 else (Vector2(r.end.x, r.position.y) if lado == 1 else Vector2(r.position.x, r.end.y))
		if lado == 3:
			a = r.position
		var comp := r.size.x if horiz else r.size.y
		if lado in com_porta:
			var largura := vao * T
			var meio := rng.randf_range(T, comp - T - largura)
			_segmento(a, horiz, meio, e, cor, topo)
			var depois := a + (Vector2(meio + largura, 0) if horiz else Vector2(0, meio + largura))
			_segmento(depois, horiz, comp - meio - largura, e, cor, topo)
			var centro := a + (Vector2(meio + largura / 2, 0) if horiz else Vector2(0, meio + largura / 2))
			var pt := _objeto("porta", centro + (Vector2(0, e / 2) if horiz else Vector2.ZERO), {"horiz": horiz, "largura": largura, "casa": idx})
			m.predios[idx]["portas"].append(pt)
		else:
			_segmento(a, horiz, comp, e, cor, topo)
	return idx


func _segmento(a: Vector2, horiz: bool, comp: float, e: float, cor: Color, topo: Color) -> void:
	if comp < 4:
		return
	if horiz:
		_parede_h(Rect2(a.x - e / 2, a.y - e / 2, comp + e, e), true, cor, topo)
	else:
		_parede_v(Rect2(a.x - e / 2, a.y + e / 2, e, comp - e), true, cor, topo)


func _dentro(r: Rect2, margem := 48.0) -> Vector2:
	return r.position + Vector2(rng.randf_range(margem, r.size.x - margem), rng.randf_range(margem + 30, r.size.y - margem))


# ---------------------------------------------------------------- quadras

func _casas(b: Rect2, inicial: bool) -> void:
	var lote := b.size / 2
	var primeira := true
	for ly in 2:
		for lx in 2:
			var l := Rect2(b.position + Vector2(lx, ly) * lote, lote)
			if not inicial and rng.randf() < 0.25:
				_quintal(l)
				continue
			var w := rng.randi_range(5, 6) * T
			var h := rng.randi_range(5, 6) * T
			var r := Rect2(l.position + Vector2(rng.randf_range(0.4, l.size.x / T - w / T - 0.4) * T, rng.randf_range(0.4, l.size.y / T - h / T - 0.4) * T), Vector2(w, h))
			var paleta := [[Color("7a4b3a"), Color("9a6b5a")], [Color("6b6f4a"), Color("8b8f6a")], [Color("4a5f6f"), Color("6a7f8f")], [Color("8a7a5a"), Color("aa9a7a")]]
			var cor: Array = paleta[rng.randi_range(0, 3)]
			var idx := _construcao(r, "casa", 1 if rng.randf() < 0.6 else 2, cor[0], cor[1], Color("6b5642"))
			var ini := inicial and primeira
			_objeto("cama", r.position + Vector2(56, 120), {"casa": idx})
			_objeto("armario", r.position + Vector2(r.size.x - 50, 52), {"garantido": [["arma:taco", 1], ["enlatado", 1]] if ini else []})
			_objeto("geladeira", r.position + Vector2(r.size.x - 110, 52), {"garantido": [["carne_crua", 1]] if ini else []})
			if rng.randf() < 0.5 or ini:
				_objeto("armario", r.position + Vector2(50, r.size.y - 30), {"garantido": [["pano", 2], ["madeira", 1]] if ini else []})
			if ini:
				m.locais["inicio"] = r.get_center() + Vector2(20, 30)
				m.locais["casa_inicial"] = idx
				primeira = false
			elif rng.randf() < 0.25:
				m.locais.get_or_add("casas_nina", []).append(r.get_center())


func _quintal(l: Rect2) -> void:
	for i in rng.randi_range(2, 5):
		_arvore(_dentro(l, 70))
	if rng.randf() < 0.3:
		_objeto("mochila", _dentro(l, 70))


func _arvore(p: Vector2) -> void:
	for o in m.objetos:
		if o.tipo == "arvore" and o.position.distance_to(p) < 70:
			return
	_objeto("arvore", p)
	m.bloqueios.append(Rect2(p - Vector2(24, 24), Vector2(48, 48)))


func _praca(b: Rect2) -> void:
	for i in rng.randi_range(12, 18):
		_arvore(_dentro(b, 80))
	if rng.randf() < 0.6:
		_objeto("mochila", _dentro(b, 120))


func _mercado(b: Rect2) -> void:
	var r := Rect2(b.position + Vector2(T, T), Vector2(12 * T, 10 * T))
	var idx := _construcao(r, "mercado", 2, Color("b8a77e"), Color("d6c69c"), Color("8a8a80"), 2.0)
	for ly in 3:
		for lx in 4:
			if rng.randf() < 0.85:
				_objeto("prateleira", r.position + Vector2(130 + lx * 170, 160 + ly * 170))
	m.locais["mercado"] = r.get_center()
	m.predios[idx]["nome"] = "Mercado"


func _delegacia(b: Rect2) -> void:
	var r := Rect2(b.position + Vector2(T, T * 2), Vector2(12 * T, 9 * T))
	var idx := _construcao(r, "delegacia", 2, Color("2f3e56"), Color("4a5d7a"), Color("5c6470"))
	# sala do arsenal (parede interna com passagem)
	var x := r.position.x + 8 * T
	_parede_v(Rect2(x - 7, r.position.y + 7, 14, 2.5 * T), true, Color("2f3e56"), Color("4a5d7a"))
	_parede_v(Rect2(x - 7, r.position.y + 4 * T, 14, r.size.y - 4 * T - 7), true, Color("2f3e56"), Color("4a5d7a"))
	for i in rng.randi_range(2, 3):
		_objeto("arsenal", Vector2(x + 60 + i * 60, r.position.y + 70))
	_objeto("radio", r.position + Vector2(3 * T, 2 * T), {})
	m.locais["radio"] = r.position + Vector2(3 * T, 2 * T)
	m.locais["delegacia"] = r.get_center()
	_objeto("armario", r.position + Vector2(60, r.size.y - 40))
	_objeto("armario", r.position + Vector2(5 * T, r.size.y - 40))
	m.predios[idx]["nome"] = "Delegacia"
	# viaturas no estacionamento da frente
	for i in 2:
		_carro(Vector2(r.position.x + 2 * T + i * 3 * T, b.position.y + T * 0.9), 0.0, true)
	m.locais["policiais"] = r.get_center()


func _posto(b: Rect2) -> void:
	m.predios.append({"r": Rect2(b.position + Vector2(T, T), Vector2(10 * T, 6 * T)), "tipo": "patio", "piso": Color("6e6e6a"), "portas": []})
	for i in 2:
		_objeto("bomba", b.position + Vector2(3 * T + i * 4 * T, 4 * T))
	var loja := Rect2(b.position + Vector2(2 * T, 8 * T), Vector2(6 * T, 5 * T))
	_construcao(loja, "loja", 1, Color("a03a2a"), Color("c05a4a"), Color("8a8a80"))
	_objeto("prateleira", loja.position + Vector2(130, 120))
	_objeto("prateleira", loja.position + Vector2(250, 230))
	for i in 2:
		_carro(b.position + Vector2(3 * T + i * 4 * T, 6 * T), 0.0)
	m.locais["posto"] = b.position + Vector2(5 * T, 4 * T)


func _garagem(b: Rect2) -> void:
	var r := Rect2(b.position + Vector2(T * 2, T * 2), Vector2(8 * T, 6 * T))
	var idx := _construcao(r, "garagem", 1, Color("5a5a52"), Color("7a7a72"), Color("6a6a66"), 2.2)
	_objeto("ferramentas", r.position + Vector2(60, 60))
	_objeto("ferramentas", r.position + Vector2(r.size.x - 60, 60))
	m.predios[idx]["nome"] = "Garagem"
	# no pátio da garagem: um carro que ainda funciona (sem gasolina) e outros quebrados
	var c := _carro(b.position + Vector2(5 * T, 10.5 * T), 0.0, false, not m.locais.has("carro_bom"))
	if c and c.funciona:
		m.locais["carro_bom"] = c
	_carro(b.position + Vector2(10 * T, 11.5 * T), PI / 2)
	_arvore(b.position + Vector2(12 * T, 2 * T))


func _ponte() -> void:
	# rio de y = -11T a -1T; a ponte é a continuação da rua de x = 36T a 40T, com o portão do Tião
	var cor := Color("6b6b70")
	var topo := Color("8a8a90")
	_parede_v(Rect2(36 * T - 14, -12 * T, 14, 12 * T), true, cor, topo)
	_parede_v(Rect2(40 * T, -12 * T, 14, 12 * T), true, cor, topo)
	_parede_h(Rect2(36 * T, -8 * T, 4 * T, 18), true, Color("5a3d22"), Color("7a5a3a"))   # portão
	m.locais["ponte"] = Vector2(38 * T, -6.4 * T)


func _bunker(b: Rect2) -> void:
	## Bunker de Sumaré: concreto, porta de aço, o Comandante Rocha, o armário do equipamento e as camas
	var r := Rect2(b.position + Vector2(2 * T, 3 * T), Vector2(10 * T, 7 * T))
	var idx := _construcao(r, "bunker", 1, Color("3b3e42"), Color("5c6066"), Color("2f3236"), 1.6)
	m.predios[idx]["nome"] = "Bunker Sumaré"
	for p in m.predios[idx]["portas"]:
		p.aco = true
	m.locais["bunker"] = idx
	m.locais["inicio"] = r.position + Vector2(4.5 * T, 4 * T)
	m.locais["rocha"] = r.position + Vector2(7.5 * T, 2.2 * T)
	m.locais["iara"] = r.position + Vector2(5.5 * T, 4.3 * T)
	m.locais["saida_bunker"] = (m.predios[idx]["portas"][0] as Node2D).position
	m.locais["casa_inicial"] = idx
	_objeto("cama", r.position + Vector2(60, 140), {"casa": idx})
	_objeto("cama", r.position + Vector2(140, 140), {"casa": idx})
	var arm := _objeto("arsenal", r.position + Vector2(r.size.x - 70, r.size.y - 40),
		{"garantido": [["balas_9mm", 6], ["bandagem", 2], ["pilhas", 1], ["iodo", 2], ["arma:faca", 1]]})
	arm.set_meta("so_garantido", true)
	m.locais["armario_bunker"] = arm.position
	_objeto("geladeira", r.position + Vector2(r.size.x - 150, r.size.y - 40), {"garantido": [["enlatado", 2], ["agua", 2]]})
	_objeto("radio", r.position + Vector2(r.size.x - 90, 70), {})
	# fora do bunker, umas casas para começar a revirar
	var lote := Rect2(b.position + Vector2(0, 10.5 * T), Vector2(b.size.x, 3.5 * T))
	for i in 3:
		_arvore(lote.position + Vector2(rng.randf_range(80, lote.size.x - 80), rng.randf_range(60, lote.size.y - 40)))


func _radiacao(n: int, inicio: Vector2i) -> void:
	## zonas quentes: tambores vazando, um caminhão tombado. O contador geiger avisa antes.
	var feitas := 0
	var tentativas := 0
	while feitas < 4 and tentativas < 40:
		tentativas += 1
		var bx := rng.randi_range(0, n - 1)
		var by := rng.randi_range(0, n - 1)
		if absi(bx - inicio.x) + absi(by - inicio.y) < 2:
			continue
		# no cruzamento das ruas ou no meio de uma quadra
		var c := Vector2((bx * QUADRA + 2) * T, (by * QUADRA + 2) * T) if rng.randf() < 0.5 \
			else Vector2((bx * QUADRA + 11) * T, (by * QUADRA + 11) * T)
		var raio := rng.randf_range(260.0, 420.0)
		m.radiacao.append({"pos": c, "raio": raio, "forca": rng.randf_range(0.6, 1.0)})
		for k in rng.randi_range(3, 5):
			var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, raio * 0.5)
			if not m._ocupado(p):
				_objeto("tambor", p)
		feitas += 1


# ---------------------------------------------------------------- enfeites (só arte)

func _deco(nome: String, p: Vector2, larg: float, bloco := Vector2.ZERO, r: RandomNumberGenerator = null) -> void:
	var d := preload("res://deco.gd").new()
	d.nome = nome
	d.position = p
	d.largura = larg
	d.bloco = bloco
	d.espelho = r != null and r.randf() < 0.5
	m.mundo.add_child(d)
	if bloco != Vector2.ZERO:
		m.bloqueios.append(Rect2(p - Vector2(bloco.x / 2, bloco.y), bloco).grow(16))


func _na_rua(p: Vector2) -> bool:
	var q := float(QUADRA * T)
	return fposmod(p.x, q) < 4 * T + 14 or fposmod(p.y, q) < 4 * T + 14


func _enfeites(n: int) -> void:
	## usa um sorteio próprio: o mapa de quem já tem save continua igual
	var r := RandomNumberGenerator.new()
	r.seed = rng.seed + 7919
	var lado := MAPA * T
	# postes e orelhões na beira das ruas
	for k in n:
		var x := float(k * QUADRA * T + 4 * T + 10)
		var y := 5.0 * T
		while y < lado - 2 * T:
			var p1 := Vector2(x, y)
			var p2 := Vector2(y, x)
			for p in [p1, p2]:
				if fposmod(p.x if p == p2 else p.y, QUADRA * T) > 5 * T and not m._ocupado(p):
					if r.randf() < 0.22:
						_deco("orelhao", p, 34.0, Vector2(16, 10), r)
					else:
						_deco("poste", p, 54.0, Vector2(10, 8), r)
			y += r.randf_range(6.0, 9.0) * T
	# Kombis largadas no meio da rua
	var kombis := 0
	var tent := 0
	while kombis < 7 and tent < 60:
		tent += 1
		var faixa := r.randi_range(0, n - 1) * QUADRA
		var ao_longo := r.randf_range(5.0, MAPA - 5.0) * T
		var p := Vector2(faixa * T + 2 * T, ao_longo) if r.randf() < 0.5 else Vector2(ao_longo, faixa * T + 2 * T)
		var caixa := Rect2(p - Vector2(80, 70), Vector2(160, 90))
		if m.bloqueios.any(func(b): return b.intersects(caixa)) or p.distance_to(m.locais["inicio"]) < 500:
			continue
		_deco("kombi", p, 130.0, Vector2(110, 34), r)
		kombis += 1
	# caminhão tombado espalhando tambores numa zona quente
	if not m.radiacao.is_empty():
		var z: Dictionary = m.radiacao[r.randi_range(0, m.radiacao.size() - 1)]
		var p: Vector2 = z["pos"] + Vector2(r.randf_range(-60, 60), r.randf_range(-60, 60))
		if not m._ocupado(p):
			_deco("caminhao_tombado", p, 190.0, Vector2(150, 40), r)
	# mato seco
	var mato := 0
	tent = 0
	while mato < 70 and tent < 400:
		tent += 1
		var p := Vector2(r.randf_range(T, lado - T), r.randf_range(T, lado - T))
		if _na_rua(p) or m._ocupado(p) or m.predios.any(func(pr): return pr["r"].grow(30).has_point(p)):
			continue
		_deco("arbusto", p, r.randf_range(56.0, 84.0), Vector2.ZERO, r)
		mato += 1
