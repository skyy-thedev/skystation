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
var voando: Array = []      # ícones de item pegos voando até a caixa de item: {item, de, dono, t}
var moch_t := 0.0           # tempo desde que a mochila abriu (cartas entram uma a uma)
var moch_sel := -1
var moch_sel_t := 0.0
var estado_antes := -1
var _rng_radar := RandomNumberGenerator.new()

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
	if main.estado != estado_antes:
		if main.estado == main.MOCHILA:
			moch_t = 0.0
		estado_antes = main.estado
	moch_t += d
	if main.menu_sel != moch_sel:
		moch_sel = main.menu_sel
		moch_sel_t = 0.0
	moch_sel_t += d
	for v in voando:
		v["t"] += d
	voando = voando.filter(func(v): return v["t"] < 0.75)
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
	_radar(w, h)
	_topo(w, h)
	_seta(w, h)
	_prompts()
	_furtivo()
	_voando()
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


var _tex_vinheta: Texture2D


func _vinheta(w: float, h: float) -> void:
	# cantos escuros, como lente de câmera: mais forte à noite. Prende o olho no centro da tela.
	if _tex_vinheta == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2((x - 63.5) / 63.5, (y - 63.5) / 63.5).length()
				var a := clampf((d - 0.55) / 0.85, 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, a * a))
		_tex_vinheta = ImageTexture.create_from_image(img)
	draw_texture_rect(_tex_vinheta, Rect2(0, 0, w, h), false, Color(1, 1, 1, 0.55 + 0.35 * main.noite()))
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


func _cartao(r: Rect2, cor := Color(0.07, 0.065, 0.06, 0.86)) -> void:
	## painel de HUD com cara de quadrinho: sombra, fundo escuro, contorno preto grosso e filete claro
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, cor)
	draw_rect(r, TINTA, false, 4.0)
	draw_rect(r.grow(-5), Color(1, 1, 1, 0.08), false, 1.5)


func _bangers(s: String, p: Vector2, tam: int, cor: Color, contorno := 6) -> void:
	draw_string_outline(fonte_tit, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, contorno, TINTA)
	draw_string(fonte_tit, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _vida(p: Vector2, larg: float, alt: float, v: float, n := 10) -> void:
	## vida em gomos, que mudam de cor (verde, amarelo, vermelho piscando)
	var cor := Color("7fe07a") if v > 0.6 else (AMARELO if v > 0.3 else VERMELHO)
	if v <= 0.3 and fmod(t, 0.6) < 0.3:
		cor = cor.lightened(0.35)
	var g := 3.0
	var seg := (larg - g * (n - 1)) / n
	draw_rect(Rect2(p - Vector2(3, 3), Vector2(larg + 6, alt + 6)), TINTA)
	for i in n:
		var r := Rect2(p + Vector2(i * (seg + g), 0), Vector2(seg, alt))
		var f := clampf(v * n - i, 0.0, 1.0)
		draw_rect(r, Color(1, 1, 1, 0.08))
		if f > 0.0:
			draw_rect(Rect2(r.position, Vector2(seg * f, alt)), cor)
			draw_rect(Rect2(r.position, Vector2(seg * f, alt * 0.35)), Color(1, 1, 1, 0.25))


func _fina(p: Vector2, larg: float, v: float, cor: Color, rotulo: String) -> void:
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(larg + 4, 10)), TINTA)
	draw_rect(Rect2(p, Vector2(larg * clampf(v, 0.0, 1.0), 6)), cor)
	draw_string(fonte, p + Vector2(larg + 10, 8), rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))


func _cara_corvo(j: Node) -> String:
	if j.vip:
		if j.hp < j.hp_max * 0.35:
			return "chorando"
		return "medo" if j.t_dano > 0.0 or main.fase_alerta == "ALERTA" else "determinada"
	if j.t_dano > 0.0:
		return "dor"
	if j.hp < j.hp_max * 0.35:
		return "ferido"
	if main.fase_alerta == "ALERTA":
		return "grito"
	if main.fase_alerta != "" or j.agachado:
		return "preocupado"
	return "neutro"


func _jogador(j: Node, w: float, h: float) -> void:
	# cartão de status (canto de cima à esquerda; o do jogador 2 vem embaixo)
	var r := Rect2(22, 20 + (j.n - 1) * 168, 420, 150)
	_cartao(r)
	var foto := A.tex("retratos/%s_%s.png" % ["iara" if j.vip else "corvo", _cara_corvo(j)], 300)
	var fr := Rect2(r.position + Vector2(12, 12), Vector2(126, 126))
	draw_rect(fr, Color("2a2622"))
	if foto:
		draw_texture_rect(foto, fr, false, Color(1, 0.55, 0.55) if j.t_dano > 0.0 else Color.WHITE)
	draw_rect(fr, TINTA, false, 4.0)
	var x := fr.end.x + 14
	_bangers(j.nome.to_upper(), Vector2(x, r.position.y + 42), 30, CORES_FALA.get(j.nome, Color.WHITE))
	draw_string(fonte, Vector2(x + 118, r.position.y + 40), "NÍVEL %d" % j.nivel, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AMARELO)
	_vida(Vector2(x, r.position.y + 56), 250, 18, j.hp / j.hp_max)
	_fina(Vector2(x, r.position.y + 88), 150, j.estamina / 100.0, Color("4fd1ff"), "fôlego")
	_fina(Vector2(x, r.position.y + 106), 150, j.fome / 100.0, Color("f0a35e"), "fome")
	if j.rad > 0.5:
		_fina(Vector2(x, r.position.y + 124), 150, j.rad / 100.0, Color("b8e04a") if j.rad <= 50 else VERMELHO, "radiação%s" % (" · iodo!" if j.rad > 50 else ""))
	else:
		_fina(Vector2(x, r.position.y + 124), 150, float(j.xp) / j.xp_proximo(), AMARELO, "experiência")
	if j.agachado:
		_bangers("AGACHADO", Vector2(r.end.x - 108, r.position.y + 136), 18, Color("9db4ff"), 4)
	# Iara (no solo ela anda sozinha): mini cartão
	var vip = main.vip
	if vip and j.n == 1:
		var ri := Rect2(22, r.end.y + 10, 300, 70)
		_cartao(ri)
		var cara := "deboche"
		if vip.caido:
			cara = "chorando"
		elif vip.t_dano > 0.0:
			cara = "medo"
		var fi := A.tex("retratos/iara_%s.png" % cara, 300)
		var q := Rect2(ri.position + Vector2(8, 8), Vector2(54, 54))
		if fi:
			draw_texture_rect(fi, q, false)
		draw_rect(q, TINTA, false, 3.0)
		_bangers("IARA", Vector2(q.end.x + 10, ri.position.y + 30), 22, CORES_FALA["Iara"], 4)
		if vip.caido:
			_bangers("CAÍDA %.0f s" % vip.t_caido, Vector2(q.end.x + 70, ri.position.y + 30), 20, VERMELHO, 4)
		elif vip.esperar:
			draw_string(fonte, Vector2(q.end.x + 70, ri.position.y + 28), "esperando", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, AMARELO)
		_vida(Vector2(q.end.x + 10, ri.position.y + 40), 200, 12, vip.hp / vip.hp_max, 8)
	_caixas(j, w, h)


func _caixas(j: Node, w: float, h: float) -> void:
	## caixa de ARMA e caixa de ITEM, como no Metal Gear (embaixo, à direita; jogador 2 à esquerda)
	var dir: bool = j.n == 1
	var ra := Rect2(w - 22 - 320, h - 22 - 128, 320, 128) if dir else Rect2(22 + 232, h - 22 - 128, 320, 128)
	var ri := Rect2(ra.position.x - 232, ra.position.y + 20, 220, 108) if dir else Rect2(22, ra.position.y + 20, 220, 108)
	# ARMA
	_cartao(ra)
	var info: Dictionary = D.ARMAS[j.arma]
	var ic := Rect2(ra.position + Vector2(10, 14), Vector2(130, 100))
	var pulo: float = maxf(0.0, j.golpe_anim) * 40.0
	if j.arma != "punhos":
		_icone(j.arma, ic.grow(-4).grow_individual(0, pulo, 0, -pulo))
	else:
		_bangers("✊", ic.get_center() + Vector2(-20, 20), 54, Color(1, 1, 1, 0.8))
	if j.t_recarga > 0.0:
		var f: float = 1.0 - j.t_recarga / maxf(info.get("recarga", 1.0), 0.01)
		draw_arc(ic.get_center(), 40, -PI / 2, -PI / 2 + TAU * f, 40, AMARELO, 6.0, true)
		_bangers("RECARREGANDO", Vector2(ic.position.x, ic.end.y + 6), 16, AMARELO, 4)
	draw_string(fonte, Vector2(ra.position.x + 150, ra.position.y + 26), "ARMA  ←→", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	_bangers(info["nome"].to_upper(), Vector2(ra.position.x + 150, ra.position.y + 54), 26, Color.WHITE)
	if info.has("municao"):
		var pente := int(j.pentes.get(j.arma, 0))
		var cor := Color.WHITE if pente > 0 else VERMELHO
		_bangers("%d" % pente, Vector2(ra.position.x + 150, ra.position.y + 108), 52, cor, 8)
		_bangers("/ %d" % j.qtd(info["municao"]), Vector2(ra.position.x + 150 + 26 * str(pente).length() + 14, ra.position.y + 106), 26, Color(1, 1, 1, 0.7))
	else:
		draw_string(fonte, Vector2(ra.position.x + 150, ra.position.y + 96), "corpo a corpo", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))
	# ITEM: bandagem no ○, e o resto que importa embaixo (luz, molotov, galão)
	_cartao(ri)
	var item := "bandagem" if j.tem("bandagem") or not j.tem("kit_medico") else "kit_medico"
	var qi := Rect2(ri.position + Vector2(10, 10), Vector2(70, 60))
	_icone(item, qi, Color.WHITE if j.tem(item) else Color(1, 1, 1, 0.3))
	_bangers("x%d" % j.qtd(item), Vector2(qi.end.x - 26, qi.end.y + 6), 22, Color.WHITE if j.tem(item) else VERMELHO, 4)
	_botao("bola", Vector2(qi.end.x + 18, ri.position.y + 26))
	draw_string(fonte, Vector2(qi.end.x + 32, ri.position.y + 31), "ITEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	var luz := ""
	if j.tocha_t > 0.0:
		luz = "tocha %ds" % ceili(j.tocha_t)
		_icone("tocha", Rect2(qi.end.x + 10, ri.position.y + 40, 26, 26))
	else:
		luz = "%d%%%s" % [int(j.bateria), " ●" if j.luz_on else ""]
		_fina(Vector2(qi.end.x + 40, ri.position.y + 54), 60, j.bateria / 100.0, AMARELO if j.luz_on else Color(1, 1, 1, 0.4), "")
	draw_string(fonte, Vector2(qi.end.x + 40, ri.position.y + 48), "luz " + luz, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
	var mx := ri.position.x + 12
	for extra in [["molotov", j.qtd("molotov")], ["galao", int(j.gasolina)]]:
		if extra[1] > 0:
			_icone(extra[0], Rect2(mx, ri.end.y - 32, 26, 26))
			draw_string(fonte, Vector2(mx + 28, ri.end.y - 12), str(extra[1]) + (" L" if extra[0] == "galao" else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			mx += 74
	if j.carro and j.carro.motorista == j:
		var rc := Rect2(ra.position.x, ra.position.y - 50, 320, 40)
		_cartao(rc)
		_bangers("%d KM/H" % int(absf(j.carro.vel) * 0.25), rc.position + Vector2(14, 30), 24, AMARELO, 4)
		_fina(Vector2(rc.position.x + 140, rc.position.y + 16), 100, j.carro.combustivel / 40.0, Color("ff9f43"), "%.0f L" % j.carro.combustivel)


func _voando() -> void:
	## item pego: o ícone pula da cabeça do personagem e voa (em arco) até a caixa de item
	for v in voando:
		var k: float = v["t"] / 0.75
		var de: Vector2 = _tela(v["de"])
		var ate := Vector2(size.x - 22 - 320 - 232 + 45, size.y - 22 - 108 + 40) if v["dono"] == 1 else Vector2(22 + 45, size.y - 22 - 108 + 40)
		var e := k * k * (3.0 - 2.0 * k)
		var p := de.lerp(ate, e) + Vector2(0, -sin(k * PI) * 160.0)
		var esc := 1.0 + sin(minf(k * 3.0, 1.0) * PI) * 0.6
		_icone(v["item"], Rect2(p - Vector2(28, 28) * esc, Vector2(56, 56) * esc), Color(1, 1, 1, 1.0 - maxf(0.0, k - 0.85) * 6.0))


func _chave(it: Dictionary) -> String:
	## receitas têm "arma": true (é uma marca); o que vale nelas é o "faz"
	if it.has("faz"):
		return it["faz"]
	return it.get("arma", it.get("item", ""))


func voar(item: String, de: Vector2, dono := 1) -> void:
	if voando.size() < 8:
		voando.append({"item": item, "de": de, "dono": dono, "t": 0.0})


func _furtivo() -> void:
	## mostra o abate silencioso quando dá
	if main.estado != main.JOGANDO:
		return
	for j in main.jogadores:
		var z = main.alvo_furtivo(j)
		if z:
			var p := _tela(z.global_position) + Vector2(-90, -150)
			_cartao(Rect2(p, Vector2(200, 40)), Color(0.35, 0.05, 0.05, 0.9))
			_botao("R1", p + Vector2(22, 20))
			_bangers("ABATE SILENCIOSO", p + Vector2(42, 29), 20, Color.WHITE, 4)


func _radar(w: float, _h: float) -> void:
	## radar do Metal Gear: paredes, zumbis com o cone de visão, Iara, barulhos e o objetivo.
	## Em ALERTA ele embaralha (estática) e só mostra a fase; em EVASÃO/CAUTELA, o tempo que falta.
	var j: Node = main.jogadores[0]
	var tam := 290.0
	var r := Rect2(w - 22 - tam, 20, tam, tam)
	var c := r.get_center()
	var alcance := 1150.0
	var k := (tam / 2.0 - 6.0) / alcance
	var verde := Color("53ff9a")
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, Color(0.01, 0.09, 0.05, 0.86))
	var dentro := r.grow(-6)
	var centro_mundo: Vector2 = j.global_position
	var ver := Rect2(centro_mundo - Vector2(alcance, alcance), Vector2(alcance, alcance) * 2.0)
	var mapa := func(p: Vector2) -> Vector2: return c + (p - centro_mundo) * k
	if main.fase_alerta == "ALERTA":
		# estática
		_rng_radar.seed = int(t * 20.0)
		for i in 140:
			var p := dentro.position + Vector2(_rng_radar.randf() * dentro.size.x, _rng_radar.randf() * dentro.size.y)
			draw_rect(Rect2(p, Vector2(_rng_radar.randf_range(4, 22), 2)), Color(verde, _rng_radar.randf_range(0.1, 0.5)))
		if fmod(t, 0.7) < 0.45:
			_bangers("SEM SINAL", c + Vector2(-62, 12), 32, Color(verde, 0.9), 6)
	else:
		# grade
		for i in range(1, 6):
			var x := dentro.position.x + dentro.size.x * i / 6.0
			var y := dentro.position.y + dentro.size.y * i / 6.0
			draw_line(Vector2(x, dentro.position.y), Vector2(x, dentro.end.y), Color(verde, 0.08), 1.0)
			draw_line(Vector2(dentro.position.x, y), Vector2(dentro.end.x, y), Color(verde, 0.08), 1.0)
		# paredes
		for cs in main.casters:
			var b: Rect2 = cs[0]
			if not ver.intersects(b):
				continue
			var q := Rect2(mapa.call(b.position), b.size * k).intersection(dentro)
			if q.has_area():
				draw_rect(q.grow(0.6), Color(verde, 0.55))
		# barulhos: anéis que crescem
		for o in main.ondas:
			var oc: Vector2 = mapa.call(o["pos"])
			if dentro.has_point(oc):
				var rr: float = o["raio"] * k * (0.3 + o["t"] / 1.2 * 0.7)
				draw_arc(oc, rr, 0, TAU, 32, Color(1, 1, 1, 0.5 * (1.0 - o["t"] / 1.2)), 2.0)
		# zumbis e cones de visão
		for z in main.zumbis:
			if not is_instance_valid(z):
				continue
			var zp: Vector2 = mapa.call(z.global_position)
			if not dentro.grow(-4).has_point(zp):
				continue
			var cor := Color("ff3b3b") if z.alvo != null else (Color("ffb347") if z.alerta else Color("ff6b6b"))
			var raio: float = main.raio_visao(j) * (0.55 if j.agachado else 1.0) * k
			var a0: float = z.frente.angle()
			var pts := PackedVector2Array([zp])
			for s2 in 7:
				var a: float = a0 - z.CONE + z.CONE * 2.0 * s2 / 6.0
				var pp: Vector2 = zp + Vector2.from_angle(a) * raio
				pts.append(Vector2(clampf(pp.x, dentro.position.x, dentro.end.x), clampf(pp.y, dentro.position.y, dentro.end.y)))
			draw_colored_polygon(pts, Color(cor, 0.16 if z.alvo == null else 0.3))
			draw_circle(zp, 4.0, cor)
		# Iara e as pessoas
		if main.vip and is_instance_valid(main.vip):
			var vp: Vector2 = mapa.call(main.vip.global_position)
			if dentro.has_point(vp):
				draw_circle(vp, 5.0, Color("7fd8ff"))
		for o in main.mundo.get_children():
			if o.get_script() == preload("res://npc.gd"):
				var np: Vector2 = mapa.call(o.global_position)
				if dentro.has_point(np):
					draw_circle(np, 4.0, Color.WHITE)
		# objetivo: quadrado amarelo piscando (ou setinha na borda)
		var alvo = main.historia.alvo()
		if alvo != null:
			var ap: Vector2 = mapa.call(alvo)
			var piscar := fmod(t, 0.8) < 0.55
			if dentro.grow(-8).has_point(ap):
				if piscar:
					draw_rect(Rect2(ap - Vector2(6, 6), Vector2(12, 12)), AMARELO, false, 3.0)
			else:
				var d := (ap - c).normalized()
				var borda := c + d * minf((dentro.size.x / 2 - 10) / maxf(absf(d.x), 0.01), (dentro.size.y / 2 - 10) / maxf(absf(d.y), 0.01))
				var an := d.angle()
				draw_colored_polygon(PackedVector2Array([borda + Vector2.from_angle(an) * 10, borda + Vector2.from_angle(an + 2.4) * 8,
					borda + Vector2.from_angle(an - 2.4) * 8]), Color(AMARELO, 1.0 if piscar else 0.5))
	# você: seta branca no meio
	var m: Vector2 = j.mira
	draw_colored_polygon(PackedVector2Array([c + m * 10, c + m.rotated(2.5) * 7, c + m.rotated(-2.5) * 7]), Color.WHITE)
	draw_rect(r, TINTA, false, 4.0)
	draw_rect(r.grow(-5), Color(verde, 0.35), false, 1.5)
	# fase
	if main.fase_alerta != "":
		var rf := Rect2(r.position.x, r.end.y + 8, tam, 42)
		var cor := Color("ff3b3b") if main.fase_alerta == "ALERTA" else AMARELO
		_cartao(rf, Color(cor.darkened(0.75), 0.92))
		var txt: String = main.fase_alerta
		if main.fase_alerta != "ALERTA":
			txt += "  %05.2f" % maxf(0.0, main.t_fase)
		_bangers(txt, rf.position + Vector2(14, 32), 28, cor, 6)


func _topo(w: float, _h: float) -> void:
	var n: float = main.noite()
	var rel := "Noite" if n > 0.5 else ("Entardecer" if main.tempo > 160.0 else "Dia")
	var cx := w / 2.0
	draw_rect(Rect2(cx - 330, 12, 660, 140 if main.historia.objetivo() != "" else 70), Color(0, 0, 0, 0.32))
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
	var dentro := Rect2(Vector2(470, 60), Vector2(w - 820, h - 230))
	var dist: float = alvo.distance_to(main.jogadores[0].global_position)
	if dentro.has_point(tela):
		var y := tela.y - 80 + sin(t * 4.0) * 5.0
		draw_colored_polygon(PackedVector2Array([Vector2(tela.x - 10, y), Vector2(tela.x + 10, y), Vector2(tela.x, y + 14)]), AMARELO)
		return
	# a seta anda pela borda, longe das barras do topo e da arma embaixo
	var area := Rect2(Vector2(80, 300), Vector2(w - 160, h - 480))
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
	var tx: Texture2D = null
	if ICONE.has(nome):
		tx = A.tex("icones/%s.png" % ICONE[nome], 128)
	else:
		tx = A.tex("pecas/%s.png" % nome, 160)       # fogueira, barricada… usam a arte da peça
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
	## mochila em cartas: o painel entra deslizando, as cartas aparecem uma a uma, a escolhida pula
	var j: Node = main.jogadores[main.menu_dono - 1]
	var ent := clampf(moch_t / 0.28, 0.0, 1.0)
	ent = 1.0 - pow(1.0 - ent, 3.0)
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55 * ent))
	var r := Rect2(w * 0.08 + (1.0 - ent) * w * 0.7, h * 0.09, w * 0.84, h * 0.82)
	_cartao(r, Color(0.09, 0.085, 0.08, 0.96))
	_bangers("MOCHILA DO %s" % j.nome.to_upper(), r.position + Vector2(30, 56), 42, AMARELO, 8)
	var abas := ["ITENS", "CRIAR"]
	for i in 2:
		var ra := Rect2(r.end.x - 330 + i * 150, r.position.y + 20, 136, 46)
		var sel: bool = i == main.mochila_aba
		draw_rect(ra, AMARELO if sel else Color(1, 1, 1, 0.08))
		draw_rect(ra, TINTA, false, 4.0)
		_bangers(abas[i], ra.position + Vector2(30, 35), 28, TINTA if sel else Color(1, 1, 1, 0.55), 0 if sel else 4)
	_botao("L1", Vector2(r.end.x - 352, r.position.y + 44))
	_botao("R1", Vector2(r.end.x - 34, r.position.y + 44))
	var lista: Array = main.itens_mochila(j) if main.mochila_aba == 0 else D.RECEITAS
	var grade := Rect2(r.position + Vector2(30, 96), Vector2(r.size.x * 0.6, r.size.y - 150))
	var cols: int = main.MOCHILA_COLS
	var gap := 16.0
	var lado := minf((grade.size.x - gap * (cols - 1)) / cols, 150.0)
	var linhas_vis := maxi(1, int((grade.size.y + gap) / (lado + gap)))
	var sel_lin := int(main.menu_sel / cols)
	var ini_lin := clampi(sel_lin - linhas_vis + 1, 0, maxi(0, int(ceil(lista.size() / float(cols))) - linhas_vis))
	if lista.is_empty():
		_txt("Vazia. Revire armários, carros e caixas.", grade.position + Vector2(10, 40), 20, Color(1, 1, 1, 0.6))
	for i in lista.size():
		var lin := int(i / cols) - ini_lin
		if lin < 0 or lin >= linhas_vis:
			continue
		var it: Dictionary = lista[i]
		var chave: String = _chave(it)
		var cel := Rect2(grade.position + Vector2((i % cols) * (lado + gap), lin * (lado + gap)), Vector2(lado, lado))
		# entra pulando, uma depois da outra
		var ki := clampf((moch_t - 0.12 - i * 0.025) / 0.18, 0.0, 1.0)
		if ki <= 0.0:
			continue
		var esc := lerpf(0.5, 1.0, ki) + sin(ki * PI) * 0.12
		var sel: bool = i == main.menu_sel
		if sel:
			esc += 0.06 + sin(minf(moch_sel_t * 14.0, PI)) * 0.08
		var cc := cel.get_center()
		var cr := Rect2(cc - cel.size * esc / 2.0, cel.size * esc)
		var pode := true
		if main.mochila_aba == 1:
			pode = main.pode_criar(j, it)
		var fundo := Color(0.2, 0.18, 0.15) if not sel else Color("ffd166")
		draw_rect(Rect2(cr.position + Vector2(4, 5), cr.size), Color(0, 0, 0, 0.5 * ki))
		draw_rect(cr, Color(fundo, ki))
		if not sel:
			draw_rect(cr.grow(-6), Color(1, 1, 1, 0.05))
		if chave == "punhos":
			_bangers("✊", cr.get_center() + Vector2(-24, 26), 64, Color(1, 1, 1, ki * 0.85), 6)
		else:
			_icone(chave, cr.grow(-cr.size.x * 0.14), Color(1, 1, 1, ki * (1.0 if pode else 0.3)))
		draw_rect(cr, TINTA, false, 4.0)
		if it.has("q") and main.mochila_aba == 0:
			_bangers("x%d" % it["q"], cr.end + Vector2(-44, -10), 26, Color.WHITE if not sel else TINTA, 5 if not sel else 0)
		if main.mochila_aba == 0 and it.has("arma") and it["arma"] == j.arma:
			draw_rect(Rect2(cr.position + Vector2(0, 8), Vector2(cr.size.x * 0.62, 24)), VERMELHO)
			_bangers("NA MÃO", cr.position + Vector2(8, 28), 18, Color.WHITE, 3)
	# barra de rolagem
	var total_lin := int(ceil(lista.size() / float(cols)))
	if total_lin > linhas_vis:
		var bx := grade.end.x + 8
		draw_rect(Rect2(bx, grade.position.y, 6, grade.size.y), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(bx, grade.position.y + grade.size.y * ini_lin / total_lin, 6, grade.size.y * linhas_vis / total_lin), AMARELO)
	# detalhe
	if not lista.is_empty():
		var it: Dictionary = lista[clampi(main.menu_sel, 0, lista.size() - 1)]
		var chave: String = _chave(it)
		var dx := grade.end.x + 40
		var dw := r.end.x - 30 - dx
		var flut := sin(t * 2.2) * 6.0
		var big := Rect2(dx + dw / 2 - 120, grade.position.y + 10 + flut, 240, 180)
		var bate := 1.0 + sin(minf(moch_sel_t * 10.0, PI)) * 0.1
		_icone(chave, Rect2(big.get_center() - big.size * bate / 2, big.size * bate))
		var nome := D.nome(chave)
		_bangers(nome.to_upper(), Vector2(dx, big.end.y + 50 - flut), 36, Color.WHITE, 7)
		var linhas: Array = []
		if main.mochila_aba == 0:
			if it.has("arma"):
				var a: Dictionary = D.ARMAS[it["arma"]]
				linhas = ["Dano %d · %s" % [a["dano"], "corpo a corpo" if a.get("corpo", false) else D.nome(a["municao"])],
					"Barulho: " + ("ALTO (eles ouvem de longe)" if a["barulho"] > 500 else ("médio" if a["barulho"] > 100 else "baixo"))]
				if a.get("corta", false):
					linhas.append("Corta lenha de árvores")
			else:
				var info: Dictionary = D.ITENS.get(it["item"], {})
				if info.has("fome"):
					linhas.append("Fome +%d" % info["fome"])
				if info.has("cura"):
					linhas.append("Vida +%d" % info["cura"])
				if info.has("dica"):
					linhas.append(info["dica"])
				if info.get("tipo", "") == "material":
					linhas.append("Material para criar itens")
		var y := big.end.y + 84
		for l in linhas:
			draw_multiline_string(fonte, Vector2(dx, y), l, HORIZONTAL_ALIGNMENT_LEFT, dw, 19, -1, Color(1, 1, 1, 0.85))
			y += fonte.get_multiline_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, dw, 19).y + 6
		if main.mochila_aba == 1:
			# receita: ícone de cada material com tenho/preciso
			var x := dx
			for k in it["usa"]:
				var tem: bool = j.qtd(k) >= it["usa"][k]
				_icone(k, Rect2(x, y - 4, 56, 56))
				_bangers("%d/%d" % [j.qtd(k), it["usa"][k]], Vector2(x + 4, y + 70), 22, VERDE if tem else VERMELHO, 4)
				x += 82
			if it.has("gasolina"):
				_icone("galao", Rect2(x, y - 4, 56, 56))
				_bangers("%.0f/%d L" % [j.gasolina, it["gasolina"]], Vector2(x, y + 70), 22, VERDE if j.gasolina >= it["gasolina"] else VERMELHO, 4)
			y += 100
			if it.has("dica"):
				draw_multiline_string(fonte, Vector2(dx, y), it["dica"], HORIZONTAL_ALIGNMENT_LEFT, dw, 17, -1, Color(1, 1, 1, 0.7))
		var acao := ""
		if main.mochila_aba == 1:
			acao = "CRIAR" if main.pode_criar(j, it) else "FALTA MATERIAL"
		elif it.has("arma"):
			acao = "PÔR NA MÃO"
		elif D.ITENS.get(it["item"], {}).get("tipo", "") in ["comida", "cura", "luz"]:
			acao = "USAR"
		if acao != "":
			var rb := Rect2(dx, r.end.y - 96, dw, 52)
			var ok := acao != "FALTA MATERIAL"
			draw_rect(rb, Color("7ff0c4") if ok else Color(1, 1, 1, 0.08))
			draw_rect(rb, TINTA, false, 4.0)
			_botao("cruz", rb.position + Vector2(30, 26), TINTA if ok else Color(1, 1, 1, 0.6))
			_bangers(acao, rb.position + Vector2(54, 38), 30, TINTA if ok else Color(1, 1, 1, 0.5), 0 if ok else 4)
	_botao("triangulo", Vector2(r.position.x + 44, r.end.y - 30))
	draw_string(fonte, Vector2(r.position.x + 62, r.end.y - 24), "fechar      ✛ escolher", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))


func _controles(p: Vector2) -> void:
	var lista := [["R2", "Atirar/usar arma"], ["R1", "Golpe · abate por trás"], ["L2", "Correr"], ["R3", "Agachar"],
		["cruz", "Usar (segure)"], ["quadrado", "Recarregar"], ["bola", "Bandagem"], ["triangulo", "Mochila e criar"],
		["←→", "Trocar arma"], ["↑", "Lanterna"], ["↓", "Tocha"], ["L1", "Molotov"]]
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
	_txt("Versão 0.6 (demo) · Jogo oficial da SkyStation · Brasil, 2033", Vector2(0, h * 0.2 + 44), 18, Color(1, 1, 1, 0.8), w, HORIZONTAL_ALIGNMENT_CENTER)
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
