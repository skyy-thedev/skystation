extends Control
## A tela por cima do jogo: barras, arma, objetivo e seta, avisos, conversa com escolhas, mochila e
## criação de itens, pausa, título e fins. Só desenha; quem decide é o main.gd.

const D := preload("res://dados.gd")

var main: Node2D
var fonte: Font
var fade := 0.0             # tela preta que some aos poucos (fim, capítulo, dormir)
var fade_texto := ""
var so_fade := false
var t := 0.0

const AMARELO := Color("ffd166")
const VERMELHO := Color("e85d5d")
const VERDE := Color("7ff0c4")
const AZUL := Color("9db4ff")
const CORES_FALA := {"Davi": Color("8fb8e8"), "Lia": Color("f0a07a"), "Rádio": Color("b0b0b0"), "Marta": Color("c7a6ff"),
	"Nina": Color("d38fe0"), "Tião": Color("e0c070")}


func _ready() -> void:
	fonte = ThemeDB.fallback_font


func _process(d: float) -> void:
	t += d
	if fade > 0.0 and not so_fade and main.estado in [main.FIM, main.CAPITULO]:
		fade = maxf(0.0, fade - d * 0.6)


func _txt(s: String, p: Vector2, tam: int, cor := Color.WHITE, larg := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(fonte, p + Vector2(1, 2), s, al, larg, tam, Color(0, 0, 0, 0.65 * cor.a))
	draw_string(fonte, p, s, al, larg, tam, cor)


func _botao(qual: String, c: Vector2, cor := Color(1, 1, 1, 0.9)) -> void:
	match qual:
		"cruz":
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), cor, 2.0, true)
			draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), cor, 2.0, true)
		"bola":
			draw_arc(c, 6.5, 0, TAU, 24, cor, 2.0, true)
		"quadrado":
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), cor, false, 2.0)
		"triangulo":
			draw_polyline(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 6), c + Vector2(-7, 6), c + Vector2(0, -7)]), cor, 2.0, true)
		_:
			draw_string(fonte, c + Vector2(-10, 5), qual, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cor)


func _barra(p: Vector2, larg: float, v: float, cor: Color, rotulo: String) -> void:
	draw_rect(Rect2(p, Vector2(larg, 9)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(p, Vector2(larg * clampf(v, 0, 1), 9)), cor)
	_txt(rotulo, p + Vector2(0, -4), 13, Color(1, 1, 1, 0.8))


func _painel(r: Rect2) -> void:
	draw_rect(r, Color(0.02, 0.03, 0.05, 0.82))
	draw_rect(r, Color(1, 1, 1, 0.18), false, 1.5)


func _tela(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


func _draw() -> void:
	var w := size.x
	var h := size.y
	if main.estado == main.TITULO:
		_titulo(w, h)
		return
	if main.jogadores.is_empty():
		return
	_vinheta(w, h)
	for j in main.jogadores:
		_jogador(j, w, h)
	_topo(w, h)
	_seta(w, h)
	_prompts()
	var y := h * 0.26
	for a in main.avisos:
		var cor: Color = a["cor"]
		cor.a *= clampf(a["t"], 0.0, 1.0)
		_txt(a["texto"], Vector2(0, y), 19, cor, w, HORIZONTAL_ALIGNMENT_CENTER)
		y += 28
	match main.estado:
		main.CONVERSA:
			_conversa(w, h)
		main.MOCHILA:
			_mochila(w, h)
		main.PAUSA:
			_pausa(w, h)
		main.FIM:
			_fim(w, h)
		main.CAPITULO:
			_capitulo(w, h)


func _vinheta(w: float, h: float) -> void:
	var perigo := 0.0
	for j in main.jogadores:
		perigo = maxf(perigo, maxf(1.0 - j.hp / j.hp_max * 2.5, j.t_dano * 2.0))
	if perigo <= 0.0:
		return
	for i in 6:
		var e := 30.0 + i * 22
		var c := Color(0.6, 0, 0, 0.06 * perigo)
		draw_rect(Rect2(0, 0, w, e), c)
		draw_rect(Rect2(0, h - e, w, e), c)
		draw_rect(Rect2(0, 0, e, h), c)
		draw_rect(Rect2(w - e, 0, e, h), c)


func _jogador(j: Node, w: float, h: float) -> void:
	var dir: bool = j.n == 2
	var x := w - 290.0 if dir else 30.0
	_txt("%s · nível %d" % [j.nome, j.nivel], Vector2(x, 28), 16, j.cor_roupa.lightened(0.45))
	_barra(Vector2(x, 48), 240, j.hp / j.hp_max, VERMELHO, "Vida %d/%d" % [ceili(maxf(j.hp, 0.0)), int(j.hp_max)])
	_barra(Vector2(x, 80), 180, j.estamina / 100.0, Color("4fd1ff"), "Fôlego")
	_barra(Vector2(x, 112), 180, j.fome / 100.0, Color("f0a35e"), "Fome")
	_barra(Vector2(x, 144), 180, float(j.xp) / j.xp_proximo(), AMARELO, "Experiência")
	# arma e munição (embaixo)
	var bx := w - 300.0 if (not dir and main.jogadores.size() == 1) or dir else 30.0
	if main.jogadores.size() > 1:
		bx = 30.0 if not dir else w - 300.0
	var info: Dictionary = D.ARMAS[j.arma]
	var by := h - 100.0
	_txt("Na mão  (←→ troca)", Vector2(bx, by), 13, Color(1, 1, 1, 0.5))
	if info.has("municao"):
		var rec := "  recarregando…" if j.t_recarga > 0.0 else ""
		_txt("%s   %d / %d%s" % [info["nome"], int(j.pentes.get(j.arma, 0)), j.qtd(info["municao"]), rec], Vector2(bx, by + 30), 26)
	else:
		_txt(info["nome"], Vector2(bx, by + 30), 26)
	var luz := ""
	if j.tocha_t > 0.0:
		luz = "Tocha %ds" % ceili(j.tocha_t)
	else:
		luz = "Lanterna %d%%%s" % [int(j.bateria), " (acesa)" if j.luz_on else ""]
	var extra := []
	extra.append(luz)
	extra.append("Bandagens %d" % j.qtd("bandagem"))
	if j.tem("galao"):
		extra.append("Galão %.0f L" % j.gasolina)
	if j.tem("molotov"):
		extra.append("Molotov %d" % j.qtd("molotov"))
	_txt("  ·  ".join(extra), Vector2(bx, by + 56), 14, Color(1, 1, 1, 0.75))
	if j.carro and j.carro.motorista == j:
		_txt("Gasolina %.0f L  ·  %d km/h" % [j.carro.combustivel, int(absf(j.carro.vel) * 0.25)], Vector2(bx, by - 26), 16, AMARELO)


func _topo(w: float, _h: float) -> void:
	var n: float = main.noite()
	var rel := "Noite" if n > 0.5 else ("Entardecer" if main.tempo > 160.0 else "Dia")
	var cx := w / 2.0
	_txt("Dia %d · %s" % [main.dia, rel], Vector2(0, 32), 20, AMARELO if n < 0.5 else AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
	# relógio do dia: barra fina
	draw_rect(Rect2(cx - 90, 42, 180, 4), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(cx - 90, 42, 180 * main.tempo / main.CICLO, 4), AZUL if n > 0.5 else AMARELO)
	_txt("%d zumbis abatidos" % main.mortes, Vector2(0, 66), 13, Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	var obj: String = main.historia.objetivo()
	var y := 92.0
	if obj != "":
		_txt("OBJETIVO", Vector2(0, y), 12, Color(1, 1, 1, 0.55), w, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(obj, Vector2(0, y + 20), 16, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
		y += 44
	if main.historia.secundario != "":
		_txt(main.historia.secundario, Vector2(0, y), 14, Color("ff9f43"), w, HORIZONTAL_ALIGNMENT_CENTER)


func _seta(w: float, h: float) -> void:
	var alvo = main.historia.alvo()
	if alvo == null:
		return
	var tela := _tela(alvo)
	var centro := Vector2(w, h) / 2.0
	var dentro := Rect2(Vector2(60, 60), Vector2(w - 120, h - 120))
	var dist: float = alvo.distance_to(main.jogadores[0].global_position)
	if dentro.has_point(tela):
		var y := tela.y - 80 + sin(t * 4.0) * 5.0
		draw_colored_polygon(PackedVector2Array([Vector2(tela.x - 10, y), Vector2(tela.x + 10, y), Vector2(tela.x, y + 14)]), AMARELO)
		return
	# a seta anda pela borda, longe das barras do topo e da arma embaixo
	var area := Rect2(Vector2(80, 190), Vector2(w - 160, h - 330))
	centro = area.get_center()
	var dir := (tela - centro).normalized()
	var p := centro + dir * minf((area.size.x / 2) / maxf(absf(dir.x), 0.01), (area.size.y / 2) / maxf(absf(dir.y), 0.01))
	var a := dir.angle()
	var pts := PackedVector2Array([p + Vector2.from_angle(a) * 18, p + Vector2.from_angle(a + 2.5) * 14, p + Vector2.from_angle(a - 2.5) * 14])
	draw_colored_polygon(pts, AMARELO)
	_txt("%d m" % int(dist / 32.0), p + Vector2(-30, 34), 14, AMARELO, 60, HORIZONTAL_ALIGNMENT_CENTER)


func _prompts() -> void:
	if main.estado != main.JOGANDO:
		return
	for j in main.jogadores:
		if j.caido or not j.perto or not is_instance_valid(j.perto) or not j.interacao.is_empty():
			continue
		var o: Object = j.perto
		var r: String = o.rotulo(j)
		var ok: bool = o.disponivel(j)
		var p := _tela(o.global_position) + Vector2(0, -90)
		var tw := fonte.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_rect(Rect2(p.x - tw / 2 - 28, p.y - 18, tw + 44, 26), Color(0, 0, 0, 0.6))
		if ok:
			_botao("cruz", Vector2(p.x - tw / 2 - 12, p.y - 5))
		_txt(r, Vector2(p.x - tw / 2 + 2, p.y), 15, Color.WHITE if ok else Color(1, 1, 1, 0.55))


func _conversa(w: float, h: float) -> void:
	var f: Dictionary = main.historia.fala_atual()
	if f.is_empty():
		return
	var ops: Array = f.get("opcoes", [])
	var alt := 150.0 + ops.size() * 34.0
	var r := Rect2(w * 0.12, h - alt - 30, w * 0.76, alt)
	_painel(r)
	var quem: String = f["quem"]
	_txt(quem, r.position + Vector2(28, 38), 20, CORES_FALA.get(quem, Color.WHITE))
	draw_multiline_string(fonte, r.position + Vector2(28, 72), f["txt"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 19, 3, Color.WHITE)
	if ops.is_empty():
		_botao("cruz", r.end + Vector2(-90, -24))
		_txt("Continuar", r.end + Vector2(-76, -18), 14, Color(1, 1, 1, 0.7))
	else:
		for i in ops.size():
			var y := r.position.y + 112 + i * 34
			var sel: bool = i == main.historia.opcao
			if sel:
				draw_rect(Rect2(r.position.x + 18, y - 22, r.size.x - 36, 30), Color(1, 1, 1, 0.12))
			_txt(("▶  " if sel else "    ") + ops[i]["txt"], Vector2(r.position.x + 28, y), 17, AMARELO if sel else Color(1, 1, 1, 0.75))


func _mochila(w: float, h: float) -> void:
	var j: Node = main.jogadores[main.menu_dono - 1]
	var r := Rect2(w * 0.18, h * 0.12, w * 0.64, h * 0.74)
	_painel(r)
	_txt("Mochila de " + j.nome, r.position + Vector2(28, 40), 22, j.cor_roupa.lightened(0.45))
	var abas := ["Mochila", "Criar"]
	for i in 2:
		var x := r.position.x + r.size.x - 240 + i * 120
		var sel: bool = i == main.mochila_aba
		draw_rect(Rect2(x, r.position.y + 16, 110, 34), Color(1, 1, 1, 0.16 if sel else 0.04))
		_txt(abas[i], Vector2(x, r.position.y + 40), 17, Color.WHITE if sel else Color(1, 1, 1, 0.5), 110, HORIZONTAL_ALIGNMENT_CENTER)
	var lista: Array = main.itens_mochila(j) if main.mochila_aba == 0 else D.RECEITAS
	var y0 := r.position.y + 90
	var cabem := int((r.size.y - 150) / 32)
	var ini := clampi(main.menu_sel - cabem + 1, 0, maxi(0, lista.size() - cabem))
	if lista.is_empty():
		_txt("Vazia. Revire armários, carros e caixas.", Vector2(r.position.x + 28, y0 + 20), 16, Color(1, 1, 1, 0.6))
	for k in mini(cabem, lista.size() - ini):
		var i := ini + k
		var it: Dictionary = lista[i]
		var y := y0 + k * 32
		var sel: bool = i == main.menu_sel
		if sel:
			draw_rect(Rect2(r.position.x + 18, y - 22, r.size.x * 0.55, 30), Color(1, 1, 1, 0.12))
		var nome := ""
		var cor := Color.WHITE
		if main.mochila_aba == 0:
			if it.has("arma"):
				nome = D.nome(it["arma"]) + ("   (na mão)" if it["arma"] == j.arma else "")
				cor = AMARELO
			else:
				nome = "%s  x%d" % [D.nome(it["item"]), it["q"]]
		else:
			nome = D.nome(it["faz"])
			cor = Color.WHITE if main.pode_criar(j, it) else Color(1, 1, 1, 0.4)
		_txt(nome, Vector2(r.position.x + 30, y), 17, cor)
	# detalhe do item escolhido
	if not lista.is_empty():
		var it: Dictionary = lista[clampi(main.menu_sel, 0, lista.size() - 1)]
		var dx := r.position.x + r.size.x * 0.62
		var linhas: Array = []
		if main.mochila_aba == 0:
			if it.has("arma"):
				var a: Dictionary = D.ARMAS[it["arma"]]
				linhas = ["Dano %d · %s" % [a["dano"], "corpo a corpo" if a.get("corpo", false) else "%s" % D.nome(a["municao"])],
					"Barulho: " + ("alto" if a["barulho"] > 500 else ("médio" if a["barulho"] > 100 else "baixo")), "✕ pôr na mão"]
				if a.get("corta", false):
					linhas.insert(1, "Corta lenha de árvores")
			else:
				var info: Dictionary = D.ITENS.get(it["item"], {})
				if info.has("fome"):
					linhas.append("Fome +%d" % info["fome"])
				if info.has("cura"):
					linhas.append("Vida +%d" % info["cura"])
				if info.has("dica"):
					linhas.append(info["dica"])
				if info.get("tipo", "") in ["comida", "cura", "luz"]:
					linhas.append("✕ usar")
				elif info.get("tipo", "") == "material":
					linhas.append("Material para criar itens")
		else:
			linhas.append("Precisa de:")
			for k in it["usa"]:
				linhas.append("  %s  %d/%d" % [D.nome(k), j.qtd(k), it["usa"][k]])
			if it.has("gasolina"):
				linhas.append("  Gasolina  %.0f/%d L" % [j.gasolina, it["gasolina"]])
			if it.has("dica"):
				linhas.append(it["dica"])
			linhas.append("✕ criar" if main.pode_criar(j, it) else "Faltam materiais")
		for i in linhas.size():
			_txt(linhas[i], Vector2(dx, y0 + i * 26), 15, Color(1, 1, 1, 0.8), r.end.x - dx - 20)
	_botao("L1", Vector2(r.position.x + 40, r.end.y - 24))
	_botao("R1", Vector2(r.position.x + 70, r.end.y - 24))
	_txt("trocar aba", Vector2(r.position.x + 86, r.end.y - 18), 14, Color(1, 1, 1, 0.6))
	_botao("cruz", Vector2(r.position.x + 200, r.end.y - 24))
	_txt("usar / criar", Vector2(r.position.x + 214, r.end.y - 18), 14, Color(1, 1, 1, 0.6))
	_botao("triangulo", Vector2(r.position.x + 340, r.end.y - 24))
	_txt("fechar", Vector2(r.position.x + 354, r.end.y - 18), 14, Color(1, 1, 1, 0.6))


func _controles(p: Vector2) -> void:
	var lista := [["R2", "Atirar/usar arma"], ["R1", "Golpe"], ["L2", "Correr"], ["L1", "Molotov"],
		["cruz", "Usar (segure)"], ["quadrado", "Recarregar"], ["bola", "Bandagem"], ["triangulo", "Mochila e criar"],
		["←→", "Trocar arma"], ["↑", "Lanterna"], ["↓", "Tocha"], ["Opt", "Pausa"]]
	for i in lista.size():
		var q := p + Vector2((i % 4) * 190, int(i / 4) * 28)
		_botao(lista[i][0], q + Vector2(10, -6))
		_txt(lista[i][1], q + Vector2(28, 0), 14, Color(1, 1, 1, 0.8))


func _titulo(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	_txt("ZONA MORTA", Vector2(0, h * 0.24), 72, VERMELHO, w, HORIZONTAL_ALIGNMENT_CENTER)
	_txt("Versão 0.2 · Jogo oficial da SkyStation", Vector2(0, h * 0.24 + 40), 17, Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	var ops := ["História: Capítulo 1 — O Sinal", "Sobrevivência (sem fim)", "Sair"]
	for i in ops.size():
		var y := h * 0.42 + i * 44
		var sel: bool = i == main.menu_sel
		if sel:
			draw_rect(Rect2(w / 2 - 230, y - 30, 460, 42), Color(1, 1, 1, 0.12))
		_txt(ops[i], Vector2(0, y), 22, Color.WHITE if sel else Color(1, 1, 1, 0.55), w, HORIZONTAL_ALIGNMENT_CENTER)
	var coop := "Segundo controle conectado: Lia (jogador 2) entra junto!" if Input.get_connected_joypads().has(1) \
		else "Coop: conecte um segundo controle e aperte Options para a Lia entrar."
	_txt(coop, Vector2(0, h * 0.42 + 150), 15, AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
	if main.recorde["dias"] > 0:
		_txt("Recorde: %d dias · %d zumbis · nível %d" % [main.recorde["dias"], main.recorde["mortes"], main.recorde["nivel"]],
			Vector2(0, h * 0.42 + 176), 15, AMARELO, w, HORIZONTAL_ALIGNMENT_CENTER)
	_controles(Vector2(w / 2 - 380, h * 0.80))


func _pausa(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.65))
	_txt("Pausa", Vector2(0, h * 0.26), 40, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
	var ops := ["Continuar", "Recomeçar", "Voltar ao título", "Sair do jogo"]
	for i in ops.size():
		var y := h * 0.38 + i * 44
		if i == main.menu_sel:
			draw_rect(Rect2(w / 2 - 170, y - 30, 340, 42), Color(1, 1, 1, 0.12))
		_txt(ops[i], Vector2(0, y), 21, Color.WHITE if i == main.menu_sel else Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	_controles(Vector2(w / 2 - 380, h * 0.74))


func _fim(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0.12, 0, 0, 0.75))
	var nivel: int = main.jogadores[0].nivel
	_txt("VOCÊS MORRERAM" if main.jogadores.size() > 1 else "VOCÊ MORREU", Vector2(0, h * 0.36), 56, VERMELHO, w, HORIZONTAL_ALIGNMENT_CENTER)
	_txt("Sobreviveu %d dia(s) · %d zumbis · nível %d" % [main.dia, main.mortes, nivel], Vector2(0, h * 0.36 + 50), 21, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
	if main.novo_recorde:
		_txt("Novo recorde!", Vector2(0, h * 0.36 + 84), 20, AMARELO, w, HORIZONTAL_ALIGNMENT_CENTER)
	_botao("cruz", Vector2(w / 2 - 70, h * 0.62 - 6))
	_txt("Voltar ao título", Vector2(w / 2 - 56, h * 0.62), 18)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, fade))


func _capitulo(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.92))
	if so_fade:
		_txt(fade_texto, Vector2(0, h * 0.5), 24, Color(1, 1, 1, 0.8), w, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_txt("CAPÍTULO 1 CONCLUÍDO", Vector2(0, h * 0.2), 44, AMARELO, w, HORIZONTAL_ALIGNMENT_CENTER)
	_txt("O Sinal", Vector2(0, h * 0.2 + 38), 20, Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	var y := h * 0.36
	_txt("Suas escolhas:", Vector2(0, y), 18, Color(1, 1, 1, 0.7), w, HORIZONTAL_ALIGNMENT_CENTER)
	for l in main.historia.resumo():
		y += 34
		_txt(l, Vector2(0, y), 18, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
	y += 60
	_txt("O portão range. Do outro lado, vinte quilômetros de estrada e a Estação Norte.", Vector2(0, y), 17, AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
	_txt("Capítulo 2 — Estação Norte: em breve.", Vector2(0, y + 30), 17, AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
	_txt("%d dia(s) · %d zumbis · nível %d" % [main.dia, main.mortes, main.jogadores[0].nivel], Vector2(0, y + 70), 15, Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	_botao("cruz", Vector2(w / 2 - 70, h * 0.88 - 6))
	_txt("Voltar ao título", Vector2(w / 2 - 56, h * 0.88), 18)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, fade))
