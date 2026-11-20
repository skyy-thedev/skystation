extends RefCounted
## Arte desenhada (as imagens geradas por IA e recortadas por tools/deadzone_fatiar.py).
## Carrega direto do PNG/JPG em arte/, sem depender do importador do Godot, e guarda em cache.
## Se um arquivo faltar, devolve null e quem chamou cai no desenho antigo (formas simples).

static var _cache := {}
static var _fontes := {}
## sol: quanto a sombra anda no chão por pixel de altura (main._ciclo atualiza) e a força dela
static var sol_v := Vector2(-0.31, 0.17)
static var sol_a := 0.4


static func tex(rel: String, lado_max := 0) -> Texture2D:
	## rel: "pecas/armario.png". lado_max > 0 reduz a imagem (fica mais nítida que reduzir na hora de desenhar)
	var k := "%s@%d" % [rel, lado_max]
	if _cache.has(k):
		return _cache[k]
	var t: Texture2D = null
	var img := Image.new()
	var caminho := ProjectSettings.globalize_path("res://arte/" + rel)
	if FileAccess.file_exists(caminho) and img.load(caminho) == OK:
		if lado_max > 0 and maxi(img.get_width(), img.get_height()) > lado_max:
			var e := float(lado_max) / maxi(img.get_width(), img.get_height())
			img.resize(maxi(1, int(img.get_width() * e)), maxi(1, int(img.get_height() * e)), Image.INTERPOLATE_LANCZOS)
		t = ImageTexture.create_from_image(img)
	_cache[k] = t
	return t


static func fonte(nome: String) -> Font:
	if _fontes.has(nome):
		return _fontes[nome]
	var f := FontFile.new()
	if f.load_dynamic_font(ProjectSettings.globalize_path("res://arte/fontes/" + nome)) != OK:
		_fontes[nome] = ThemeDB.fallback_font
		return ThemeDB.fallback_font
	f.fallbacks = [ThemeDB.fallback_font]     # símbolos (✕ ▶ ·) que a fonte de quadrinho não tem
	_fontes[nome] = f
	return f


static func peca(ci: CanvasItem, nome: String, largura: float, base := 0.0, mod := Color.WHITE, espelho := false) -> bool:
	## desenha uma peça com o "pé" (base da imagem) na origem do nó. Devolve false se a imagem não existe.
	var t := tex("pecas/%s.png" % nome, int(largura * 1.6))
	if t == null:
		return false
	var s := largura / t.get_width()
	var h := t.get_height() * s
	var r := Rect2(-largura / 2, base - h, largura, h)
	if espelho:
		r = Rect2(largura / 2, base - h, -largura, h)
	ci.draw_texture_rect(t, r, false, mod)
	return true


static func boneco(ci: CanvasItem, nome: String, frente: Vector2, fase: float, andando: bool, altura: float,
		mod := Color.WHITE, quatro_lados := true) -> bool:
	## personagem desenhado (rodada 3 da arte). nome = "personagens/corvo" ou "zumbis/corredor".
	## quatro_lados: arquivos _baixo/_cima/_esq/_dir; senão _frente/_lado (o lado esquerdo é o direito espelhado).
	## A animação de andar é feita aqui: pulinho, balanço e um leve achatamento a cada passo.
	## Sem o arquivo, devolve false e o boneco antigo é desenhado.
	var dir := ""
	var espelho := false
	if quatro_lados:
		if absf(frente.x) > absf(frente.y):
			dir = "dir" if frente.x > 0.0 else "esq"
		else:
			dir = "baixo" if frente.y >= 0.0 else "cima"
	else:
		if absf(frente.x) > absf(frente.y) * 0.8:
			dir = "lado"
			espelho = frente.x < 0.0
		else:
			dir = "frente"
	var lado_max := int(altura * 2.2)
	var t := tex("%s_%s.png" % [nome, dir], lado_max)
	if t == null and dir == "esq":
		t = tex("%s_dir.png" % nome, lado_max)
		espelho = true
	if t == null and dir == "cima":
		t = tex("%s_baixo.png" % nome, lado_max)
	if t == null:
		return false
	var pulo := absf(sin(fase)) * 3.5 if andando else 0.0
	var resp := sin(fase * 0.35) * 0.012 if not andando else 0.0      # parado: respira
	var giro := sin(fase) * 0.07 if andando else 0.0
	var h := altura
	var w := t.get_width() * h / t.get_height()
	var esc := Vector2(1.0 + pulo * 0.008, 1.0 - pulo * 0.01 + resp)
	if sol_a > 0.02:
		sombra(ci, t, Rect2(-w / 2, -h, w, h), Vector2.ZERO, Color(0, 0, 0, sol_a * 0.85), espelho)
	if espelho:
		esc.x = -esc.x
	ci.draw_set_transform(Vector2(0, -pulo), giro, esc)
	ci.draw_texture_rect(t, Rect2(-w / 2, -h, w, h), false, mod)
	ci.draw_set_transform(Vector2.ZERO)
	return true


static func sombra(ci: CanvasItem, t: Texture2D, r: Rect2, origem: Vector2, cor: Color, espelho := false) -> void:
	## a silhueta da imagem "deitada" no chão na direção do sol: o ponto a h px de altura vai para
	## origem + sol_v * h. É só uma matriz com cisalhamento; a imagem é a mesma, pintada de preto.
	var x := Vector2(-1, 0) if espelho else Vector2(1, 0)
	ci.draw_set_transform_matrix(Transform2D(x, Vector2(-sol_v.x, -sol_v.y), origem))
	ci.draw_texture_rect(t, r, false, cor)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func sombra_peca(ci: CanvasItem, nome: String, largura: float, origem: Vector2, base := 0.0, espelho := false) -> void:
	var t := tex("pecas/%s.png" % nome, int(largura * 1.6))
	if t == null:
		return
	var h := t.get_height() * largura / t.get_width()
	sombra(ci, t, Rect2(-largura / 2, base - h, largura, h), origem, Color.BLACK, espelho)
