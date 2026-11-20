extends RefCounted
## Arte desenhada (as imagens geradas por IA e recortadas por tools/deadzone_fatiar.py).
## Carrega direto do PNG/JPG em arte/, sem depender do importador do Godot, e guarda em cache.
## Se um arquivo faltar, devolve null e quem chamou cai no desenho antigo (formas simples).

static var _cache := {}
static var _fontes := {}


static func tex(rel: String, lado_max := 0) -> Texture2D:
	## rel: "pecas/armario.png". lado_max > 0 reduz a imagem (fica mais nítida que reduzir na hora de desenhar)
	var k := "%s@%d" % [rel, lado_max]
	if _cache.has(k):
		return _cache[k]
	var t: Texture2D = null
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path("res://arte/" + rel)) == OK:
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
