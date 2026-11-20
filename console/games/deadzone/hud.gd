extends Control
## A tela por cima do jogo: barras, arma, objetivo e seta, avisos, conversa com escolhas, mochila e
## criação de itens, pausa, título e fins. Só desenha; quem decide é o main.gd.

const D := preload("res://dados.gd")
const A := preload("res://arte.gd")

var main: Node2D
var fonte: Font
var fonte_tit: Font         # Bangers: títulos e nomes, cara de capa de gibi
var hq_chave := ""          # quadro de HQ na tela agora (o zoom lento recomeça a cada quadro)
var hq_t := 0.0
var fade := 0.0             # tela preta que some aos poucos (fim, capítulo, dormir)
var fade_texto := ""
var so_fade := false
var t := 0.0

const AMARELO := Color("ffd166")
const VERMELHO := Color("e85d5d")
const VERDE := Color("7ff0c4")
const AZUL := Color("9db4ff")
const CORES_FALA := {"Corvo": Color("8fb8e8"), "Iara": Color("8fe0b0"), "Lia": Color("f0a07a"), "Rádio": Color("b0b0b0"),
	"Helena": Color("c7a6ff"), "Rocha": Color("c9b48a"), "Nina": Color("d38fe0"), "Tião": Color("e0c070")}
## retrato de cada um (arte/retratos/<prefixo>_<cara>.png) e a cara padrão
const RETRATO := {"Corvo": ["corvo", "neutro"], "Iara": ["iara", "deboche"], "Rocha": ["rocha", "severo"],
	"Helena": ["helena", "calma"], "Nina": ["nina", "rindo"], "Tião": ["tiao", "locutor"]}
## quadros de cada página de HQ (x, y, largura, altura em fração da página), medidos pelas calhas brancas
const QUADROS := {
	"c1_abertura": [[0.009, 0.009, 0.981, 0.381], [0.009, 0.399, 0.489, 0.589], [0.503, 0.399, 0.487, 0.276], [0.503, 0.684, 0.487, 0.304]],
	"c1_contrato": [[0.008, 0.01, 0.487, 0.981], [0.503, 0.01, 0.488, 0.483], [0.503, 0.505, 0.488, 0.486]],
	"c1_mordida_arma": [[0.008, 0.01, 0.983, 0.483], [0.008, 0.507, 0.487, 0.484], [0.504, 0.507, 0.487, 0.484]],
	"c1_mordida_mao": [[0.008, 0.01, 0.983, 0.455], [0.009, 0.477, 0.488, 0.514], [0.503, 0.477, 0.488, 0.514]],
	"c1_pedagio": [[0.015, 0.023, 0.971, 0.421], [0.015, 0.456, 0.48, 0.521], [0.505, 0.456, 0.48, 0.521]],
	"c1_pedagio_vendeu": [[0.015, 0.023, 0.971, 0.336], [0.015, 0.372, 0.971, 0.288], [0.015, 0.673, 0.971, 0.304]],
}
## ícone de cada item e arma na mochila (arte/icones)
const ICONE := {"enlatado": "lata", "salgadinho": "lata", "carne_crua": "carne_crua", "carne_assada": "carne_assada",
	"agua": "agua", "bandagem": "bandagem", "kit_medico": "bandagem", "iodo": "iodo", "madeira": "madeira", "pano": "pano",
	"sucata": "sucata", "garrafa": "molotov", "pilhas": "pilha", "tocha": "tocha", "galao": "galao", "molotov": "molotov",
	"balas_9mm": "bala_pistola", "cartuchos": "cartucho", "balas_rifle": "pente_rifle",
	"faca": "faca", "taco": "taco", "machado": "machado", "pistola": "pistola", "espingarda": "espingarda", "rifle": "rifle"}
const PAPEL := Color("f3e9cd")
const TINTA := Color("17130f")


func _ready() -> void:
	fonte = A.fonte("ComicNeue-Bold.ttf")
	fonte_tit = A.fonte("Bangers-Regular.ttf")


func _process(d: float) -> void:
	t += d
	var fa: Dictionary = main.historia.fala_atual() if main.estado == main.CONVERSA else {}
	var k := "%s/%s" % [fa.get("hq", ""), fa.get("q", 0)] if fa.has("hq") else ""
	if k != hq_chave:
		hq_chave = k
		hq_t = 0.0
	hq_t += d
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
	if j.rad > 0.5:
		_barra(Vector2(x, 176), 180, j.rad / 100.0, Color("b8e04a"), "Radiação %d%s" % [int(j.rad), "  (tome iodo!)" if j.rad > 50 else ""])
	var vip = main.vip
	if vip and j.n == 1:
		_barra(Vector2(x, 208 if j.rad > 0.5 else 176), 180, vip.hp / vip.hp_max, Color("8fe0b0"), "Iara%s" % ("  (esperando)" if vip.esperar else ""))
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


func _icone(nome: String, r: Rect2, mod := Color.WHITE) -> void:
	if not ICONE.has(nome):
		return
	var tx := A.tex("icones/%s.png" % ICONE[nome], 128)
	if tx == null:
		return
	var e := minf(r.size.x / tx.get_width(), r.size.y / tx.get_height())
	var tam := Vector2(tx.get_width(), tx.get_height()) * e
	draw_texture_rect(tx, Rect2(r.get_center() - tam / 2, tam), false, mod)


func _caixa_quadrinho(r: Rect2, cor := PAPEL) -> void:
	draw_rect(Rect2(r.position + Vector2(6, 7), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, cor)
	draw_rect(r, TINTA, false, 4.0)


func _nome(quem: String, p: Vector2, tam := 34) -> void:
	var cor: Color = CORES_FALA.get(quem, Color.WHITE)
	draw_string_outline(fonte_tit, p, quem.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 8, TINTA)
	draw_string(fonte_tit, p, quem.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor.lightened(0.15))


func _retrato(f: Dictionary) -> Texture2D:
	var quem: String = f.get("quem", "")
	if not RETRATO.has(quem):
		return null
	var r: Array = RETRATO[quem]
	var tx := A.tex("retratos/%s_%s.png" % [r[0], f.get("cara", r[1])], 300)
	return tx if tx else A.tex("retratos/%s_%s.png" % [r[0], r[1]], 300)


func _conversa(w: float, h: float) -> void:
	var f: Dictionary = main.historia.fala_atual()
	if f.is_empty():
		return
	if f.has("hq") and QUADROS.has(f["hq"]) and A.tex("hq/%s.jpg" % f["hq"]) != null:
		_hq(f, w, h)
		return
	if f["quem"] == "":
		# narração: tela escura e uma caixa de legenda de gibi no meio
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.84))
		var larg := w * 0.62
		var lin := fonte.get_multiline_string_size(f["txt"], HORIZONTAL_ALIGNMENT_LEFT, larg - 56, 26).y
		var r := Rect2(w / 2 - larg / 2, h * 0.45 - lin / 2 - 28, larg, lin + 56)
		_caixa_quadrinho(r, Color("f2d27a"))
		draw_multiline_string(fonte, r.position + Vector2(28, 44), f["txt"], HORIZONTAL_ALIGNMENT_LEFT, larg - 56, 26, -1, TINTA)
		_botao("cruz", Vector2(w - 150, h - 46))
		_txt("Continuar", Vector2(w - 136, h - 40), 15, Color(1, 1, 1, 0.7))
		return
	var ops: Array = f.get("opcoes", [])
	var quem: String = f["quem"]
	var foto := _retrato(f)
	var esq := w * 0.08
	var alt := 160.0 + ops.size() * 36.0
	var com_foto := 230.0 if foto else 0.0
	var r := Rect2(esq + com_foto, h - alt - 34, w * 0.84 - com_foto, alt)
	if foto:
		var fr := Rect2(esq, h - 34 - 270, 250, 270)
		_caixa_quadrinho(fr, Color("2a2622"))
		draw_texture_rect(foto, fr.grow(-6), false)
		draw_rect(fr, TINTA, false, 5.0)
	_caixa_quadrinho(r)
	_nome(quem, r.position + Vector2(26, -10), 38)
	draw_multiline_string(fonte, r.position + Vector2(28, 58), f["txt"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 23, -1, TINTA)
	if ops.is_empty():
		_botao("cruz", r.end + Vector2(-100, -22), TINTA)
		draw_string(fonte, r.end + Vector2(-86, -16), "Continuar", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.1, 0.1, 0.8))
	else:
		for i in ops.size():
			var y := r.position.y + 118 + i * 36
			var sel: bool = i == main.historia.opcao
			if sel:
				draw_rect(Rect2(r.position.x + 16, y - 26, r.size.x - 32, 34), Color("ffd166"))
				draw_rect(Rect2(r.position.x + 16, y - 26, r.size.x - 32, 34), TINTA, false, 2.0)
			draw_string(fonte, Vector2(r.position.x + 30, y), ("▶  " if sel else "     ") + ops[i]["txt"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				TINTA if sel else Color(0.2, 0.18, 0.15, 0.8))


func _hq(f: Dictionary, w: float, h: float) -> void:
	## um quadro da página de HQ em tela cheia, com zoom lento; legenda em caixa amarela, fala em balão
	var tx := A.tex("hq/%s.jpg" % f["hq"])
	var qs: Array = QUADROS[f["hq"]]
	var q: Array = qs[clampi(int(f.get("q", 0)), 0, qs.size() - 1)]
	var ts := Vector2(tx.get_width(), tx.get_height())
	var src := Rect2(q[0] * ts.x, q[1] * ts.y, q[2] * ts.x, q[3] * ts.y).grow(-3)
	draw_rect(Rect2(0, 0, w, h), Color("0b0a09"))
	var fala: bool = f.get("quem", "") != ""
	var area := Rect2(36, 28, w - 72, h - (210.0 if fala else 90.0))
	var e := minf(area.size.x / src.size.x, area.size.y / src.size.y)
	var dest := Rect2(area.get_center() - src.size * e / 2, src.size * e)
	# zoom lento (Ken Burns): a janela da imagem encolhe uns 6% em 10 s
	var z := 1.0 + minf(hq_t, 10.0) * 0.006
	var src2 := Rect2(src.get_center() - src.size / z / 2, src.size / z)
	draw_texture_rect_region(tx, dest, src2)
	draw_rect(dest, TINTA, false, 6.0)
	draw_rect(dest.grow(3), Color(1, 1, 1, 0.85), false, 2.0)
	if not fala:
		if f.get("txt", "") != "":
			var larg := minf(dest.size.x * 0.5, 520.0)
			var lin := fonte.get_multiline_string_size(f["txt"], HORIZONTAL_ALIGNMENT_LEFT, larg - 36, 22).y
			var r := Rect2(dest.position + Vector2(18, 18), Vector2(larg, lin + 34))
			_caixa_quadrinho(r, Color("f2d27a"))
			draw_multiline_string(fonte, r.position + Vector2(18, 34), f["txt"], HORIZONTAL_ALIGNMENT_LEFT, larg - 36, 22, -1, TINTA)
	else:
		var r := Rect2(w * 0.12, h - 170, w * 0.76, 132)
		# balão branco com o rabicho apontando para o quadro
		var bx := r.position.x + r.size.x * 0.22
		var bico := PackedVector2Array([Vector2(bx, r.position.y + 2), Vector2(bx + 44, r.position.y + 2), Vector2(bx + 4, r.position.y - 34)])
		draw_colored_polygon(bico, Color.WHITE)
		draw_polyline(PackedVector2Array([bico[0], bico[2], bico[1]]), TINTA, 4.0)
		draw_rect(Rect2(r.position + Vector2(6, 7), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, Color.WHITE)
		draw_rect(r, TINTA, false, 4.0)
		draw_rect(Rect2(bx + 4, r.position.y - 2, 36, 6), Color.WHITE)
		_nome(f["quem"], r.position + Vector2(24, 40), 30)
		draw_multiline_string(fonte, r.position + Vector2(24, 76), f["txt"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48, 23, -1, TINTA)
	var a := clampf(1.0 - hq_t * 3.0, 0.0, 1.0)
	if a > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, a))     # cada quadro novo entra com um fade curto
	_botao("cruz", Vector2(w - 150, h - 22), Color(1, 1, 1, 0.8))
	_txt("Continuar", Vector2(w - 136, h - 16), 14, Color(1, 1, 1, 0.6))


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
		_icone(it.get("arma", it.get("item", it.get("faz", ""))), Rect2(r.position.x + 24, y - 25, 30, 30))
		_txt(nome, Vector2(r.position.x + 62, y), 17, cor)
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
		_icone(it.get("arma", it.get("item", it.get("faz", ""))), Rect2(dx, y0 - 22, 130, 96))
		for i in linhas.size():
			_txt(linhas[i], Vector2(dx, y0 + 96 + i * 26), 15, Color(1, 1, 1, 0.8), r.end.x - dx - 20)
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


func _fundo(nome: String, w: float, h: float, escuro := 0.0) -> void:
	var tx := A.tex("telas/%s.jpg" % nome)
	if tx == null:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.8))
		return
	# cobre a tela toda sem distorcer (corta as sobras)
	var ts := Vector2(tx.get_width(), tx.get_height())
	var e := maxf(w / ts.x, h / ts.y)
	var src := Rect2((ts - Vector2(w, h) / e) / 2, Vector2(w, h) / e)
	draw_texture_rect_region(tx, Rect2(0, 0, w, h), src)
	if escuro > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, escuro))


func _logo(c: Vector2, tam: int) -> void:
	var tw := fonte_tit.get_string_size("DEADZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var p := c - Vector2(tw / 2, 0)
	draw_string(fonte_tit, p + Vector2(7, 9), "DEADZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.8))
	draw_string_outline(fonte_tit, p, "DEADZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 14, TINTA)
	draw_string(fonte_tit, p, "DEADZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color("aaff3c"))


func _titulo(w: float, h: float) -> void:
	_fundo("titulo", w, h)
	draw_rect(Rect2(0, h * 0.33, w, h * 0.67), Color(0, 0, 0, 0.5))
	_logo(Vector2(w / 2, h * 0.2), 132)
	_txt("Versão 0.5 (demo) · Jogo oficial da SkyStation · Brasil, 2033", Vector2(0, h * 0.2 + 44), 18, Color(1, 1, 1, 0.8), w, HORIZONTAL_ALIGNMENT_CENTER)
	var ops: Array = main.opcoes_titulo()
	for i in ops.size():
		var y := h * 0.40 + i * 44
		var sel: bool = i == main.menu_sel
		if sel:
			draw_rect(Rect2(w / 2 - 280, y - 30, 560, 42), Color(1, 1, 1, 0.12))
		_txt(ops[i]["txt"], Vector2(0, y), 21, Color.WHITE if sel else Color(1, 1, 1, 0.55), w, HORIZONTAL_ALIGNMENT_CENTER)
	var y2 := h * 0.40 + ops.size() * 44 + 12
	var coop := "Segundo controle conectado: no coop o jogador 2 é a Iara!" if Input.get_connected_joypads().has(1) \
		else "Coop: conecte um segundo controle e aperte Options para jogar com a Iara."
	_txt(coop, Vector2(0, y2), 15, AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
	if main.recorde["dias"] > 0:
		_txt("Recorde na sobrevivência: %d dias · %d zumbis · nível %d" % [main.recorde["dias"], main.recorde["mortes"], main.recorde["nivel"]],
			Vector2(0, y2 + 26), 15, AMARELO, w, HORIZONTAL_ALIGNMENT_CENTER)
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
	_fundo("game_over", w, h, 0.2)
	draw_rect(Rect2(0, h * 0.16, w, h * 0.58), Color(0.1, 0, 0, 0.62))
	var nivel: int = main.jogadores[0].nivel
	var titulo := "VOCÊS MORRERAM" if main.jogadores.size() > 1 else "VOCÊ MORREU"
	if main.motivo_fim != "":
		titulo = "MISSÃO FRACASSADA"
		_txt(main.motivo_fim, Vector2(0, h * 0.36 - 64), 20, Color(1, 1, 1, 0.8), w, HORIZONTAL_ALIGNMENT_CENTER)
	var tw := fonte_tit.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	draw_string_outline(fonte_tit, Vector2(w / 2 - tw / 2, h * 0.36 + 8), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 12, TINTA)
	draw_string(fonte_tit, Vector2(w / 2 - tw / 2, h * 0.36 + 8), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, VERMELHO)
	_txt("Sobreviveu %d dia(s) · %d zumbis · nível %d" % [main.dia, main.mortes, nivel], Vector2(0, h * 0.36 + 50), 21, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
	if main.novo_recorde:
		_txt("Novo recorde!", Vector2(0, h * 0.36 + 84), 20, AMARELO, w, HORIZONTAL_ALIGNMENT_CENTER)
	if main.tem_save():
		_botao("cruz", Vector2(w / 2 - 190, h * 0.62 - 6))
		_txt("Voltar à última cama", Vector2(w / 2 - 176, h * 0.62), 18)
		_botao("bola", Vector2(w / 2 + 60, h * 0.62 - 6))
		_txt("Título", Vector2(w / 2 + 76, h * 0.62), 18)
	else:
		_botao("cruz", Vector2(w / 2 - 70, h * 0.62 - 6))
		_txt("Voltar ao título", Vector2(w / 2 - 56, h * 0.62), 18)
		_txt("Dica: dormir numa cama (casa barricada, à noite) salva o jogo.", Vector2(0, h * 0.62 + 40), 15, Color(1, 1, 1, 0.55), w, HORIZONTAL_ALIGNMENT_CENTER)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, fade))


func _capitulo(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.92))
	if so_fade:
		_txt(fade_texto, Vector2(0, h * 0.5), 24, Color(1, 1, 1, 0.8), w, HORIZONTAL_ALIGNMENT_CENTER)
		return
	_txt("CAPÍTULO 1 CONCLUÍDO", Vector2(0, h * 0.16), 44, AMARELO, w, HORIZONTAL_ALIGNMENT_CENTER)
	_txt("A Carga · Sumaré", Vector2(0, h * 0.16 + 38), 20, Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	var y := h * 0.29
	_txt("Suas escolhas:", Vector2(0, y), 18, Color(1, 1, 1, 0.7), w, HORIZONTAL_ALIGNMENT_CENTER)
	for l in main.historia.resumo():
		y += 30
		_txt(l, Vector2(0, y), 17, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
	y += 50
	if main.historia.vendeu():
		_txt("Sozinho na Anhanguera. O pagamento do Tião pesa no banco do carona, vazio.", Vector2(0, y), 17, VERMELHO, w, HORIZONTAL_ALIGNMENT_CENTER)
		_txt("Este caminho termina aqui. Ou não?", Vector2(0, y + 30), 17, VERMELHO, w, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_txt("A cancela sobe. À frente, a Anhanguera e, depois dela, São Paulo — por baixo da terra.", Vector2(0, y), 17, AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
		_txt("Capítulo 2 — São Paulo: o metrô. Em breve.", Vector2(0, y + 30), 17, AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
	_txt("%d dia(s) · %d zumbis · nível %d" % [main.dia, main.mortes, main.jogadores[0].nivel], Vector2(0, y + 70), 15, Color(1, 1, 1, 0.6), w, HORIZONTAL_ALIGNMENT_CENTER)
	_botao("cruz", Vector2(w / 2 - 70, h * 0.88 - 6))
	_txt("Voltar ao título", Vector2(w / 2 - 56, h * 0.88), 18)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, fade))
