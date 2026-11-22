extends Control
## SkyStation 13.25: a SkyNetwork em tela cheia, no jeito do PS4.
##
## Abas Amigos / Mensagens / Pedidos / Perfil (L1/R1). Amigos em grade com o ícone grande e o que estão
## jogando; A abre a página do amigo (Mensagem, Convidar para jogar, Entrar no jogo, Remover). A conversa
## mostra os balões das duas pessoas, respostas rápidas e o teclado na tela. O Perfil troca ícone, nome,
## "sobre mim" e aparecer como invisível.
##
## Os dados vêm do net.json (o sky-net sincroniza a cada 30 s) e as ações passam pelo sky-cloud, em threads:
## a tela nunca congela esperando a internet.

signal closed
signal abrir_jogo(jogo_id: String)
signal abrir_netplay(msg_id: String)
signal abrir_config(secao: int)

const SKY_CLOUD := "/opt/skystation/bin/sky-cloud"
const AVATARES := "/opt/skystation/avatares"
const WHITE := Color("f2f6ff")
const MUTED := Color("a9b6d8")
const DIM := Color("6b7799")
const VERDE := Color("54f0b8")
const AMARELO := Color("ffcc66")
const ABAS := ["Amigos", "Mensagens", "Pedidos", "Perfil"]
const RAPIDAS := ["Bora jogar?", "Entra aí!", "GG!", "Já volto", "Agora não dá"]
const KB_LETRAS := ["1234567890", "qwertyuiop", "asdfghjkl@", "zxcvbnm.-_"]
const KB_SIMBOLOS := ["1234567890", "!?#$%&*()+", "=[]{}<>/\\|", ";:'\",.~^-_"]
const GRADE_COLS := 8

var accent := Color("4fd1ff")
var font: Font
var font_bold: Font
var run_dir: String = OS.get_environment("XDG_RUNTIME_DIR") + "/skystation"

var aba: int = 0
var tela: String = ""          # "" = as abas | "amigo" | "conversa"
var alvo: String = ""          # id do amigo aberto
var sel: int = 0               # item escolhido na aba
var bsel: int = 0              # botão escolhido (página do amigo, pedidos, conversa)
var confirmar: String = ""     # ação esperando o segundo A ("remover:<id>")
var net: Dictionary = {}
var net_t: float = 0.0
var conta: Dictionary = {}
var conversa: Array = []
var conversa_t: float = 0.0
var aviso: String = ""
var aviso_t: float = 0.0
var t: float = 0.0
var hold_dir: Vector2i = Vector2i.ZERO
var hold_t: float = 0.0
var threads: Array = []
var tex_cache: Dictionary = {}
var avatares: Array = []

var kb_open: bool = false
var kb_texto: String = ""
var kb_titulo: String = ""
var kb_modo: String = ""
var kb_row: int = 1
var kb_col: int = 0
var kb_shift: bool = false
var kb_simb: bool = false
var kb_max: int = 280

var grade_open: bool = false
var grade_sel: int = 0


func _ready() -> void:
	font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = font
	fv.variation_embolden = 0.6
	font_bold = fv
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var lista = JSON.parse_string(FileAccess.get_file_as_string(AVATARES + "/avatares.json")) \
		if FileAccess.file_exists(AVATARES + "/avatares.json") else null
	avatares = lista if typeof(lista) == TYPE_ARRAY else []


func abrir(qual_aba: int = 0, amigo: String = "", cor: Color = Color("4fd1ff")) -> void:
	accent = cor
	visible = true
	aba = clampi(qual_aba, 0, ABAS.size() - 1)
	tela = ""
	sel = 0
	bsel = 0
	confirmar = ""
	kb_open = false
	grade_open = false
	hold_dir = _dir()
	_ler_net()
	_carregar_conta()
	if amigo != "":
		_abrir_amigo(amigo)


func _fechar() -> void:
	visible = false
	closed.emit()


# ---------------------------------------------------------------- dados

func _ler_net() -> void:
	net_t = 0.0
	var txt := FileAccess.get_file_as_string(run_dir + "/net.json") if FileAccess.file_exists(run_dir + "/net.json") else ""
	var d = JSON.parse_string(txt) if txt.begins_with("{") else null
	net = d if typeof(d) == TYPE_DICTIONARY else {}


func _n(v) -> String:
	return "" if v == null else str(v)


func _eu() -> Dictionary:
	return net.get("eu", {}) if typeof(net.get("eu")) == TYPE_DICTIONARY else {}


func _amigos() -> Array:
	var ordem := {"jogando": 0, "online": 1, "ausente": 2, "offline": 3}
	var lst: Array = []
	for a in net.get("amigos", []):
		if typeof(a) == TYPE_DICTIONARY:
			lst.append(a)
	lst.sort_custom(func(x, y):
		var ox := int(ordem.get(_n(x.get("status")), 9))
		var oy := int(ordem.get(_n(y.get("status")), 9))
		return ox < oy if ox != oy else _n(x.get("apelido")).nocasecmp_to(_n(y.get("apelido"))) < 0)
	return lst


func _amigo(id: String) -> Dictionary:
	for a in net.get("amigos", []):
		if typeof(a) == TYPE_DICTIONARY and _n(a.get("id")) == id:
			return a
	return {}


func _recebidas(de: String = "") -> Array:
	var out: Array = []
	for m in net.get("mensagens", []):
		if typeof(m) == TYPE_DICTIONARY and (de == "" or _n(m.get("de", {}).get("id")) == de):
			out.append(m)
	return out


func _nao_lidas(de: String = "") -> int:
	var n := 0
	for m in _recebidas(de):
		if not m.get("lida", false):
			n += 1
	return n


func _pedidos() -> Array:
	return net.get("pedidosRecebidos", []) if typeof(net.get("pedidosRecebidos")) == TYPE_ARRAY else []


func _enviados() -> Array:
	return net.get("pedidosEnviados", []) if typeof(net.get("pedidosEnviados")) == TYPE_ARRAY else []


func _situacao(a: Dictionary) -> String:
	match _n(a.get("status")):
		"jogando":
			var s := "Jogando " + _n(a.get("jogo"))
			if _n(a.get("sistema")) != "":
				s += "  ·  " + _n(a.get("sistema")).to_upper()
			return s
		"online":
			return "Online"
		"ausente":
			return "Ausente"
	var visto := _n(a.get("vistoEm"))
	return "Offline" + (("  ·  visto " + _ha(visto)) if visto != "" else "")


func _ha(iso: String) -> String:
	var q := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	if q <= 0:
		return ""
	var s := int(Time.get_unix_time_from_system() - q)
	if s < 90:
		return "agora"
	if s < 3600:
		return "há %d min" % (s / 60)
	if s < 86400:
		return "há %d h" % (s / 3600)
	return "há %d dias" % (s / 86400)


func _cor_status(a: Dictionary) -> Color:
	match _n(a.get("status")):
		"jogando":
			return accent
		"online":
			return VERDE
		"ausente":
			return AMARELO
	return Color(DIM, 0.0)


# ---------------------------------------------------------------- ações (sky-cloud em thread)

func _cloud(args: Array, cb: Callable = Callable()) -> void:
	var th := Thread.new()
	threads.append(th)
	th.start(_trabalho.bind(args, cb, th))


func _trabalho(args: Array, cb: Callable, th: Thread) -> void:
	var out := []
	var code := OS.execute(SKY_CLOUD, PackedStringArray(args), out, false)
	var d = null
	if not out.is_empty():
		var linhas: PackedStringArray = str(out[0]).strip_edges().split("\n")
		var ultima := linhas[linhas.size() - 1]
		d = JSON.parse_string(ultima) if ultima.begins_with("{") else null
	if typeof(d) != TYPE_DICTIONARY:
		d = {"ok": false, "error": "a SkyNetwork não respondeu (código %d)" % code}
	call_deferred("_terminou", th, cb, d)


func _terminou(th: Thread, cb: Callable, d: Dictionary) -> void:
	th.wait_to_finish()
	threads.erase(th)
	if cb.is_valid():
		cb.call(d)


func _resultado(d: Dictionary) -> void:
	_avisar(str(d.get("message", "Pronto")) if d.get("ok", false) else str(d.get("error", "Não deu certo")))
	_pedir_sync()


func _avisar(txt: String) -> void:
	aviso = txt
	aviso_t = 4.0


func _pedir_sync() -> void:
	# o sky-net vê este arquivo e sincroniza na hora (em vez de esperar 30 s)
	var f := FileAccess.open(run_dir + "/net.agora", FileAccess.WRITE)
	if f != null:
		f.store_string(str(Time.get_unix_time_from_system()))
	net_t = 0.7


func _carregar_conta() -> void:
	_cloud(["conta"], func(d: Dictionary):
		if d.get("ok", false):
			conta = d)


func _abrir_amigo(id: String) -> void:
	alvo = id
	tela = "amigo"
	bsel = 0
	confirmar = ""


func _abrir_conversa(id: String) -> void:
	alvo = id
	tela = "conversa"
	bsel = 0
	conversa = []
	conversa_t = 0.0
	_carregar_conversa()
	if _nao_lidas(id) > 0:
		_cloud(["lidas", id], func(_d): _pedir_sync())


func _carregar_conversa() -> void:
	conversa_t = 6.0
	var quem := alvo
	_cloud(["conversa", quem], func(d: Dictionary):
		if tela == "conversa" and alvo == quem and d.get("ok", false):
			conversa = d.get("mensagens", []))


func _enviar(texto: String) -> void:
	if texto.strip_edges() == "" or alvo == "":
		return
	conversa.append({"minha": true, "texto": texto, "tipo": "texto", "enviando": true})
	var quem := alvo
	_cloud(["mensagem", quem, texto], func(d: Dictionary):
		if not d.get("ok", false):
			_avisar(str(d.get("error", "Não consegui enviar")))
		if tela == "conversa" and alvo == quem:
			_carregar_conversa())


func _convidar(id: String) -> void:
	_avisar("Enviando o convite…")
	_cloud(["convidar", id], _resultado)


func _convite_de(id: String) -> Dictionary:
	# o convite mais recente (até 30 min) desse amigo, para "Entrar no jogo"
	var agora := Time.get_unix_time_from_system()
	var melhor: Dictionary = {}
	for m in _recebidas(id):
		var tipo := _n(m.get("tipo"))
		if tipo != "convite" and tipo != "netplay":
			continue
		var q := Time.get_unix_time_from_datetime_string(_n(m.get("enviadaEm")).substr(0, 19))
		if q > 0 and agora - q <= 1800 and (tipo == "netplay" or _n(m.get("jogoId")) != ""):
			melhor = m
	return melhor


# ---------------------------------------------------------------- entrada

func _dir() -> Vector2i:
	var d := Vector2i.ZERO
	if Input.is_action_pressed("sky_left"):
		d.x -= 1
	if Input.is_action_pressed("sky_right"):
		d.x += 1
	if Input.is_action_pressed("sky_up"):
		d.y -= 1
	if Input.is_action_pressed("sky_down"):
		d.y += 1
	return d


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	aviso_t = maxf(0.0, aviso_t - delta)
	net_t -= delta
	if net_t <= 0.0:
		_ler_net()
		net_t = 1.0
	if tela == "conversa":
		conversa_t -= delta
		if conversa_t <= 0.0:
			_carregar_conversa()
	var d := _dir()
	var passo := Vector2i.ZERO
	if d != hold_dir:
		hold_dir = d
		hold_t = 0.36
		passo = d
	elif d != Vector2i.ZERO:
		hold_t -= delta
		if hold_t <= 0.0:
			hold_t = 0.1
			passo = d
	if kb_open:
		_kb_entrada(passo)
	elif grade_open:
		_grade_entrada(passo)
	else:
		_entrada(passo)
	queue_redraw()


func _input(event: InputEvent) -> void:
	# teclado de verdade: digita direto no teclado da tela
	if not visible or not kb_open or not (event is InputEventKey) or not event.is_pressed():
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_kb_ok()
		KEY_BACKSPACE:
			kb_texto = kb_texto.substr(0, maxi(0, kb_texto.length() - 1))
		KEY_ESCAPE:
			kb_open = false
		_:
			if k.unicode >= 32 and kb_texto.length() < kb_max:
				kb_texto += String.chr(k.unicode)
	get_viewport().set_input_as_handled()


func _som(qual: String) -> void:
	var p := get_parent()
	if p != null and p.has_method("_play"):
		p.call("_play", qual)


func _entrada(passo: Vector2i) -> void:
	if Input.is_action_just_pressed("sky_back"):
		_som("back")
		if confirmar != "":
			confirmar = ""
		elif tela != "":
			tela = ""
			bsel = 0
		else:
			_fechar()
		return
	if tela == "" and (Input.is_action_just_pressed("sky_l1") or Input.is_action_just_pressed("sky_r1")):
		aba = wrapi(aba + (1 if Input.is_action_just_pressed("sky_r1") else -1), 0, ABAS.size())
		sel = 0
		bsel = 0
		confirmar = ""
		_som("swoosh")
		return
	match tela:
		"amigo":
			_entrada_amigo(passo)
		"conversa":
			_entrada_conversa(passo)
		_:
			match aba:
				0:
					_entrada_amigos(passo)
				1:
					_entrada_lista(passo, _conversas().size())
					if Input.is_action_just_pressed("sky_accept") and not _conversas().is_empty():
						_som("accept")
						_abrir_conversa(_n(_conversas()[sel].get("id")))
				2:
					_entrada_pedidos(passo)
				3:
					_entrada_perfil(passo)


func _entrada_lista(passo: Vector2i, n: int) -> void:
	if passo.y != 0 and n > 0:
		var novo := clampi(sel + passo.y, 0, n - 1)
		if novo != sel:
			sel = novo
			bsel = 0
			confirmar = ""
			_som("tick")


func _entrada_amigos(passo: Vector2i) -> void:
	var n := _amigos().size() + 1   # + "Adicionar amigo"
	var cols := 5
	var novo := sel
	if passo.x != 0:
		novo = clampi(sel + passo.x, 0, n - 1)
	elif passo.y != 0:
		novo = clampi(sel + passo.y * cols, 0, n - 1)
	if novo != sel:
		sel = novo
		_som("tick")
	if Input.is_action_just_pressed("sky_accept"):
		_som("accept")
		var lst := _amigos()
		if sel < lst.size():
			_abrir_amigo(_n(lst[sel].get("id")))
		else:
			_kb("Adicionar amigo: ID SkyNetwork (ex.: sky) ou código de amigo", "amigo", 40)


func _botoes_amigo() -> Array:
	var b: Array = [["Mensagem", "msg"], ["Convidar para jogar", "convidar"]]
	if not _convite_de(alvo).is_empty():
		b.insert(0, ["Entrar no jogo", "entrar"])
	b.append(["Confirmar: remover?" if confirmar == "remover" else "Remover amigo", "remover"])
	return b


func _entrada_amigo(passo: Vector2i) -> void:
	var b := _botoes_amigo()
	if passo.x != 0:
		var novo := clampi(bsel + passo.x, 0, b.size() - 1)
		if novo != bsel:
			bsel = novo
			confirmar = ""
			_som("tick")
	if not Input.is_action_just_pressed("sky_accept"):
		return
	_som("accept")
	var a := _amigo(alvo)
	match str(b[clampi(bsel, 0, b.size() - 1)][1]):
		"msg":
			_abrir_conversa(alvo)
		"convidar":
			_convidar(alvo)
		"entrar":
			var c := _convite_de(alvo)
			if _n(c.get("tipo")) == "netplay":
				abrir_netplay.emit(_n(c.get("id")))
			else:
				abrir_jogo.emit(_n(c.get("jogoId")))
		"remover":
			if confirmar != "remover":
				confirmar = "remover"
				return
			confirmar = ""
			_cloud(["recusar", _n(a.get("amizadeId"))], _resultado)
			tela = ""
			sel = 0


func _chips_conversa() -> Array:
	var c: Array = [["Escrever…", "escrever"]]
	for r in RAPIDAS:
		c.append([r, "rapida"])
	c.append(["Convidar para jogar", "convidar"])
	return c


func _entrada_conversa(passo: Vector2i) -> void:
	var c := _chips_conversa()
	if passo.x != 0:
		bsel = clampi(bsel + passo.x, 0, c.size() - 1)
		_som("tick")
	if not Input.is_action_just_pressed("sky_accept"):
		return
	_som("accept")
	match str(c[bsel][1]):
		"escrever":
			_kb("Mensagem para " + _n(_amigo(alvo).get("apelido")), "msg", 280)
		"rapida":
			_enviar(str(c[bsel][0]))
		"convidar":
			_convidar(alvo)
			conversa_t = 1.5


func _linhas_pedidos() -> Array:
	var l: Array = []
	for p in _pedidos():
		l.append({"tipo": "recebido", "p": p})
	for p in _enviados():
		l.append({"tipo": "enviado", "p": p})
	l.append({"tipo": "adicionar"})
	return l


func _entrada_pedidos(passo: Vector2i) -> void:
	var l := _linhas_pedidos()
	_entrada_lista(passo, l.size())
	sel = clampi(sel, 0, l.size() - 1)
	var linha: Dictionary = l[sel]
	if passo.x != 0 and linha["tipo"] == "recebido":
		bsel = clampi(bsel + passo.x, 0, 1)
		_som("tick")
	if not Input.is_action_just_pressed("sky_accept"):
		return
	_som("accept")
	match str(linha["tipo"]):
		"recebido":
			var id := _n(linha["p"].get("amizadeId"))
			_cloud(["aceitar" if bsel == 0 else "recusar", id], _resultado)
		"enviado":
			_cloud(["recusar", _n(linha["p"].get("amizadeId"))], _resultado)
		"adicionar":
			_kb("Adicionar amigo: ID SkyNetwork (ex.: sky) ou código de amigo", "amigo", 40)


func _linhas_perfil() -> Array:
	var eu := _eu()
	var l: Array = [["Trocar ícone", "icone"], ["Nome que os amigos veem: " + _n(eu.get("apelido")), "apelido"],
		["Sobre mim: " + (_n(conta.get("bio")) if _n(conta.get("bio")) != "" else "(vazio)"), "bio"],
		["Aparecer como: " + ("Invisível" if eu.get("invisivel", false) else "Online"), "invisivel"]]
	if _n(eu.get("usuario")) == "":
		l.append(["Criar ou entrar com um ID SkyNetwork", "config"])
	l.append(["Mais opções: saves na nuvem, senha, outro console, sair", "config"])
	return l


func _entrada_perfil(passo: Vector2i) -> void:
	var l := _linhas_perfil()
	_entrada_lista(passo, l.size())
	if not Input.is_action_just_pressed("sky_accept"):
		return
	_som("accept")
	match str(l[sel][1]):
		"icone":
			grade_sel = 0
			for i in avatares.size():
				if _n(avatares[i].get("id")) == _n(_eu().get("avatar")):
					grade_sel = i
			grade_open = not avatares.is_empty()
		"apelido":
			_kb("Nome que os amigos veem", "apelido", 24)
			kb_texto = _n(_eu().get("apelido"))
		"bio":
			_kb("Sobre mim (até 140 letras)", "bio", 140)
			kb_texto = _n(conta.get("bio"))
		"invisivel":
			var on: bool = not _eu().get("invisivel", false)
			_cloud(["invisivel", "on" if on else "off"], _resultado)
		"config":
			abrir_config.emit(4)


# ---------------------------------------------------------------- teclado na tela (✕ digita, □ apaga, △ símbolos,
# L2 maiúsculas, R1 espaço, Start conclui, ○ cancela; teclado de verdade também digita)

func _kb(titulo: String, modo: String, maximo: int) -> void:
	kb_open = true
	kb_texto = ""
	kb_titulo = titulo
	kb_modo = modo
	kb_max = maximo
	kb_row = 1
	kb_col = 0
	kb_shift = false
	kb_simb = false


func _kb_entrada(passo: Vector2i) -> void:
	var linhas := 5
	if passo.y != 0:
		kb_row = clampi(kb_row + passo.y, 0, linhas - 1)
		kb_col = clampi(kb_col, 0, (3 if kb_row == 4 else 9))
		_som("tick")
	elif passo.x != 0:
		kb_col = clampi(kb_col + passo.x, 0, 3 if kb_row == 4 else 9)
		_som("tick")
	if Input.is_action_just_pressed("sky_back"):
		kb_open = false
		_som("back")
	elif Input.is_action_just_pressed("sky_accept"):
		if kb_row < 4:
			var ch: String = (KB_SIMBOLOS if kb_simb else KB_LETRAS)[kb_row][kb_col]
			if kb_shift and not kb_simb:
				ch = ch.to_upper()
			if kb_texto.length() < kb_max:
				kb_texto += ch
		else:
			match kb_col:
				0:
					kb_shift = not kb_shift
				1:
					kb_simb = not kb_simb
				2:
					kb_texto += " "
				3:
					_kb_ok()
	elif Input.is_action_just_pressed("sky_x"):
		kb_texto = kb_texto.substr(0, maxi(0, kb_texto.length() - 1))
	elif Input.is_action_just_pressed("sky_r1"):
		kb_texto += " "
	elif Input.is_action_just_pressed("sky_l1"):
		kb_shift = not kb_shift
	elif Input.is_action_just_pressed("sky_menu"):
		_kb_ok()


func _kb_ok() -> void:
	kb_open = false
	var txt := kb_texto.strip_edges()
	if txt == "":
		return
	match kb_modo:
		"msg":
			_enviar(txt)
		"amigo":
			_avisar("Procurando " + txt + "…")
			_cloud(["amigo", txt], _resultado)
		"apelido":
			_cloud(["apelido", txt], _resultado)
		"bio":
			_cloud(["bio", txt], func(d: Dictionary):
				_resultado(d)
				_carregar_conta())


func _grade_entrada(passo: Vector2i) -> void:
	var n := avatares.size()
	if passo.x != 0:
		grade_sel = clampi(grade_sel + passo.x, 0, n - 1)
	elif passo.y != 0:
		grade_sel = clampi(grade_sel + passo.y * GRADE_COLS, 0, n - 1)
	if passo != Vector2i.ZERO:
		_som("tick")
	if Input.is_action_just_pressed("sky_back"):
		grade_open = false
	elif Input.is_action_just_pressed("sky_accept"):
		grade_open = false
		var id := _n(avatares[grade_sel].get("id"))
		_avisar("Trocando o ícone…")
		_cloud(["icone", id], _resultado)


# ---------------------------------------------------------------- desenho

var estilos: Dictionary = {}


func _rr(r: Rect2, cor: Color, raio: int, borda: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	var k := "%s|%d|%s|%d" % [cor.to_html(), raio, borda.to_html(), bw]
	if not estilos.has(k):
		var sb := StyleBoxFlat.new()
		sb.bg_color = cor
		sb.set_corner_radius_all(raio)
		sb.border_color = borda
		sb.set_border_width_all(bw)
		sb.anti_aliasing = true
		estilos[k] = sb
	draw_style_box(estilos[k], r)


func _tx(s: String, pos: Vector2, tam: int, cor: Color, negrito: bool = false, larg: float = -1.0,
		al: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font_bold if negrito else font, pos, s, al, larg, tam, cor, TextServer.JUSTIFICATION_NONE)


func _tex(id: String) -> Texture2D:
	if not tex_cache.has(id):
		var tx: Texture2D = null
		var p := "%s/%s.png" % [AVATARES, id]
		if id != "" and id.is_valid_identifier() and FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tx = ImageTexture.create_from_image(img)
		tex_cache[id] = tx
	return tex_cache[id]


func _avatar(c: Vector2, raio: float, id: String, nome: String, cor: String, status: Color = Color(0, 0, 0, 0),
		apagado: bool = false) -> void:
	var tx := _tex(id)
	var a := 0.55 if apagado else 1.0
	if tx != null:
		draw_texture_rect(tx, Rect2(c - Vector2(raio, raio), Vector2(raio, raio) * 2.0), false, Color(1, 1, 1, a))
	else:
		draw_circle(c, raio, Color(Color.from_string(cor, accent), 0.85 * a))
		var letra := nome.substr(0, 1).to_upper() if nome != "" else "?"
		var tam := int(raio * 1.05)
		_tx(letra, Vector2(c.x - raio, c.y + tam * 0.36), tam, Color(WHITE, a), true, raio * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	if status.a > 0.0:   # anel e bolinha de status, como no PS4
		draw_arc(c, raio + 4.0, 0, TAU, 64, Color(status, 0.9), 3.0, true)
		var b := c + Vector2(raio * 0.70, raio * 0.70)
		draw_circle(b, maxf(6.0, raio * 0.17) + 3.0, Color("0b1020"))
		draw_circle(b, maxf(6.0, raio * 0.17), status)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.08, 0.90))
	_desenha_topo(w)
	match tela:
		"amigo":
			_desenha_amigo(w, h)
		"conversa":
			_desenha_conversa(w, h)
		_:
			_desenha_abas(w)
			match aba:
				0:
					_desenha_amigos(w, h)
				1:
					_desenha_conversas(w, h)
				2:
					_desenha_pedidos(w, h)
				3:
					_desenha_perfil(w, h)
	if grade_open:
		_desenha_grade(w, h)
	if kb_open:
		_desenha_teclado(w, h)
	_desenha_rodape(w, h)   # por último: as dicas dos botões ficam visíveis também no teclado e na grade
	if aviso_t > 0.0 and aviso != "":
		var a := minf(1.0, aviso_t * 2.0)
		var tw := font.get_string_size(aviso, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 48.0
		var r := Rect2(w - tw - 56.0, 104, tw, 46)
		_rr(r, Color(0, 0, 0, 0.75 * a), 23, Color(accent, 0.6 * a), 1)
		_tx(aviso, r.position + Vector2(24, 30), 18, Color(WHITE, a))


func _desenha_topo(w: float) -> void:
	_tx("Sky", Vector2(56, 64), 28, WHITE, true)
	var sw := font_bold.get_string_size("Sky", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	_tx("Network", Vector2(56 + sw, 64), 28, accent, true)
	var eu := _eu()
	var nome := _n(eu.get("apelido"))
	if nome == "":
		return
	var online: bool = net.get("online", false)
	var sit := "Invisível" if eu.get("invisivel", false) else ("Online" if online else "Sem conexão")
	var cor := DIM if eu.get("invisivel", false) or not online else VERDE
	var x := w - 70.0
	_avatar(Vector2(x, 52), 26, _n(eu.get("avatar")), nome, _n(eu.get("cor")), cor)
	var linha2 := sit + (("  ·  @" + _n(eu.get("usuario"))) if _n(eu.get("usuario")) != "" else "")
	var fim := x - 46.0
	_tx(nome, Vector2(fim - 400, 50), 19, WHITE, true, 400, HORIZONTAL_ALIGNMENT_RIGHT)
	_tx(linha2, Vector2(fim - 400, 72), 14, MUTED, false, 400, HORIZONTAL_ALIGNMENT_RIGHT)


func _desenha_abas(w: float) -> void:
	var x := 56.0
	var y := 128.0
	for k in ABAS.size():
		var nome: String = ABAS[k]
		var on := k == aba
		var tam := 22
		var tw := font_bold.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		_tx(nome, Vector2(x, y), tam, WHITE if on else Color(MUTED, 0.8), on)
		var n := 0
		if k == 1:
			n = _nao_lidas()
		elif k == 2:
			n = _pedidos().size()
		if n > 0:
			var bc := Vector2(x + tw + 16, y - 8)
			draw_circle(bc, 12, Color("e05260"))
			_tx(str(n), Vector2(bc.x - 12, bc.y + 6), 14, WHITE, true, 24, HORIZONTAL_ALIGNMENT_CENTER)
			tw += 26
		if on:
			_rr(Rect2(x, y + 12, tw, 4), accent, 2)
		x += tw + 48.0
	draw_line(Vector2(56, y + 26), Vector2(w - 56, y + 26), Color(1, 1, 1, 0.10), 1.0)
	_tx("L1 / R1", Vector2(w - 56 - 80, y), 15, DIM, false, 80, HORIZONTAL_ALIGNMENT_RIGHT)


func _sem_rede(w: float, h: float) -> bool:
	if not net.has("eu") and not net.get("online", false):
		var msg := "Sem conexão com a SkyNetwork agora."
		if net.get("convidado", false):
			msg = "Jogando como convidado: escolha um usuário em Trocar de usuário para usar a SkyNetwork."
		_tx(msg, Vector2(0, h * 0.45), 22, MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
		return true
	return false


func _desenha_amigos(w: float, h: float) -> void:
	if _sem_rede(w, h):
		return
	var lst := _amigos()
	var on_n := 0
	for a in lst:
		if _n(a.get("status")) != "offline":
			on_n += 1
	_tx("%d amigos  ·  %d online" % [lst.size(), on_n], Vector2(56, 196), 17, MUTED)
	var cols := 5
	var gap := 26.0
	var cw := (w - 112.0 - gap * (cols - 1)) / cols
	var ch := 250.0
	var y0 := 220.0
	var linha_sel := int(sel / cols)
	var visiveis := maxi(1, int((h - y0 - 90.0) / (ch + gap)))
	var primeira := clampi(linha_sel - visiveis + 1, 0, 9999)
	for k in lst.size() + 1:
		var lin := int(k / cols) - primeira
		if lin < 0 or lin >= visiveis:
			continue
		var r := Rect2(56.0 + (k % cols) * (cw + gap), y0 + lin * (ch + gap), cw, ch)
		var on := k == sel
		_rr(r, Color(1, 1, 1, 0.14 if on else 0.05), 22, Color(accent, 0.9) if on else Color(0, 0, 0, 0), 2 if on else 0)
		var c := Vector2(r.get_center().x, r.position.y + 92)
		if k == lst.size():
			draw_circle(c, 58, Color(1, 1, 1, 0.08))
			_tx("+", Vector2(c.x - 58, c.y + 22), 64, Color(WHITE, 0.8), true, 116, HORIZONTAL_ALIGNMENT_CENTER)
			_tx("Adicionar amigo", Vector2(r.position.x, r.end.y - 62), 19, WHITE, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			_tx("Pelo ID ou código", Vector2(r.position.x, r.end.y - 36), 14, MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var a: Dictionary = lst[k]
		var off := _n(a.get("status")) == "offline"
		_avatar(c, 58, _n(a.get("avatar")), _n(a.get("apelido")), _n(a.get("cor")), _cor_status(a), off)
		var novas := _nao_lidas(_n(a.get("id")))
		if novas > 0:
			draw_circle(c + Vector2(-46, -46), 14, Color("e05260"))
			_tx(str(novas), c + Vector2(-60, -40), 15, WHITE, true, 28, HORIZONTAL_ALIGNMENT_CENTER)
		_tx(_n(a.get("apelido")), Vector2(r.position.x + 10, r.end.y - 62), 19, WHITE if not off else MUTED, true,
			r.size.x - 20, HORIZONTAL_ALIGNMENT_CENTER)
		var sit := _situacao(a)
		_tx(sit, Vector2(r.position.x + 10, r.end.y - 36), 14, accent if _n(a.get("status")) == "jogando" else MUTED,
			false, r.size.x - 20, HORIZONTAL_ALIGNMENT_CENTER)


func _conversas() -> Array:
	# uma linha por amigo: quem mandou mensagem por último fica em cima
	var lst: Array = []
	for a in _amigos():
		var rec := _recebidas(_n(a.get("id")))
		var ultima: Dictionary = rec[rec.size() - 1] if not rec.is_empty() else {}
		lst.append({"id": _n(a.get("id")), "a": a, "ultima": ultima, "quando": _n(ultima.get("enviadaEm"))})
	lst.sort_custom(func(x, y): return str(x["quando"]) > str(y["quando"]))
	return lst


func _desenha_linha(r: Rect2, on: bool) -> void:
	_rr(r, Color(1, 1, 1, 0.13 if on else 0.04), 18, Color(accent, 0.85) if on else Color(0, 0, 0, 0), 2 if on else 0)


func _desenha_conversas(w: float, h: float) -> void:
	if _sem_rede(w, h):
		return
	var lst := _conversas()
	if lst.is_empty():
		_tx("Adicione amigos para conversar com eles.", Vector2(0, h * 0.45), 22, MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var rh := 92.0
	var y0 := 190.0
	var cabe := maxi(1, int((h - y0 - 90.0) / (rh + 12)))
	var primeira := clampi(sel - cabe + 1, 0, maxi(0, lst.size() - cabe))
	for k in range(primeira, mini(lst.size(), primeira + cabe)):
		var it: Dictionary = lst[k]
		var a: Dictionary = it["a"]
		var r := Rect2(w * 0.16, y0 + (k - primeira) * (rh + 12), w * 0.68, rh)
		_desenha_linha(r, k == sel)
		_avatar(Vector2(r.position.x + 52, r.get_center().y), 32, _n(a.get("avatar")), _n(a.get("apelido")),
			_n(a.get("cor")), _cor_status(a), _n(a.get("status")) == "offline")
		_tx(_n(a.get("apelido")), Vector2(r.position.x + 104, r.position.y + 38), 20, WHITE, true)
		var u: Dictionary = it["ultima"]
		var prev := _n(u.get("texto")) if not u.is_empty() else "Toque para conversar"
		if _n(u.get("tipo")) == "convite" or _n(u.get("tipo")) == "netplay":
			prev = "Convite: " + prev
		_tx(prev, Vector2(r.position.x + 104, r.position.y + 66), 16, MUTED, false, r.size.x - 260)
		if not u.is_empty():
			_tx(_ha(_n(u.get("enviadaEm"))), Vector2(r.end.x - 160, r.position.y + 38), 14, DIM, false, 136,
				HORIZONTAL_ALIGNMENT_RIGHT)
		var n := _nao_lidas(it["id"])
		if n > 0:
			draw_circle(Vector2(r.end.x - 36, r.position.y + 62), 14, Color("e05260"))
			_tx(str(n), Vector2(r.end.x - 50, r.position.y + 68), 15, WHITE, true, 28, HORIZONTAL_ALIGNMENT_CENTER)


func _desenha_pedidos(w: float, h: float) -> void:
	if _sem_rede(w, h):
		return
	var l := _linhas_pedidos()
	var eu := _eu()
	var meu := "Seu código de amigo: " + _n(eu.get("codigo"))
	if _n(eu.get("usuario")) != "":
		meu += "   ·   ou o seu ID: @" + _n(eu.get("usuario"))
	_tx(meu, Vector2(56, 196), 17, MUTED)
	var rh := 86.0
	var y0 := 222.0
	for k in l.size():
		var linha: Dictionary = l[k]
		var r := Rect2(w * 0.16, y0 + k * (rh + 12), w * 0.68, rh)
		if r.end.y > h - 90:
			break
		var on := k == sel
		_desenha_linha(r, on)
		match str(linha["tipo"]):
			"recebido", "enviado":
				var quem: Dictionary = linha["p"].get("de" if linha["tipo"] == "recebido" else "para", {})
				_avatar(Vector2(r.position.x + 50, r.get_center().y), 30, _n(quem.get("avatar")), _n(quem.get("apelido")),
					_n(quem.get("cor")))
				_tx(_n(quem.get("apelido")), Vector2(r.position.x + 100, r.position.y + 38), 20, WHITE, true)
				_tx("quer ser seu amigo" if linha["tipo"] == "recebido" else "pedido enviado: esperando a resposta",
					Vector2(r.position.x + 100, r.position.y + 64), 15, MUTED)
				var bts: Array = ["Aceitar", "Recusar"] if linha["tipo"] == "recebido" else ["Cancelar pedido"]
				var bx := r.end.x - 24.0
				for i in range(bts.size() - 1, -1, -1):
					var bw := font_bold.get_string_size(bts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40.0
					bx -= bw
					var br := Rect2(bx, r.get_center().y - 21, bw, 42)
					var ativo := on and (bsel == i or bts.size() == 1)
					_rr(br, WHITE if ativo else Color(1, 1, 1, 0.10), 21)
					_tx(bts[i], br.position + Vector2(0, 27), 16, Color("0a0f1c") if ativo else WHITE, true, bw,
						HORIZONTAL_ALIGNMENT_CENTER)
					bx -= 12.0
			"adicionar":
				draw_circle(Vector2(r.position.x + 50, r.get_center().y), 30, Color(1, 1, 1, 0.08))
				_tx("+", Vector2(r.position.x + 20, r.get_center().y + 14), 40, WHITE, true, 60, HORIZONTAL_ALIGNMENT_CENTER)
				_tx("Adicionar amigo", Vector2(r.position.x + 100, r.position.y + 38), 20, WHITE, true)
				_tx("Pelo ID SkyNetwork dele (ex.: sky) ou pelo código de amigo", Vector2(r.position.x + 100, r.position.y + 64), 15, MUTED)


func _desenha_perfil(w: float, h: float) -> void:
	if _sem_rede(w, h):
		return
	var eu := _eu()
	var c := Vector2(w * 0.27, h * 0.40)
	var online: bool = net.get("online", false) and not eu.get("invisivel", false)
	_avatar(c, 110, _n(eu.get("avatar")), _n(eu.get("apelido")), _n(eu.get("cor")), VERDE if online else DIM)
	_tx(_n(eu.get("apelido")), Vector2(c.x - 220, c.y + 160), 30, WHITE, true, 440, HORIZONTAL_ALIGNMENT_CENTER)
	var sub := ("@" + _n(eu.get("usuario"))) if _n(eu.get("usuario")) != "" else "Sem ID SkyNetwork"
	_tx(sub, Vector2(c.x - 220, c.y + 190), 18, accent if _n(eu.get("usuario")) != "" else MUTED, false, 440,
		HORIZONTAL_ALIGNMENT_CENTER)
	var bio := _n(conta.get("bio"))
	if bio != "":
		draw_multiline_string(font, Vector2(c.x - 200, c.y + 226), bio, HORIZONTAL_ALIGNMENT_CENTER, 400, 16, 3, MUTED)
	var l := _linhas_perfil()
	var x0 := w * 0.48
	var rh := 66.0
	var y0 := h * 0.40 - l.size() * (rh + 10) / 2.0
	for k in l.size():
		var r := Rect2(x0, y0 + k * (rh + 10), w * 0.44, rh)
		_desenha_linha(r, k == sel)
		var txt: String = l[k][0]
		var dois := txt.find(": ")
		if dois > 0:
			_tx(txt.substr(0, dois), Vector2(r.position.x + 26, r.position.y + 41), 19, WHITE, k == sel, r.size.x * 0.5)
			_tx(txt.substr(dois + 2), Vector2(r.position.x + r.size.x * 0.52, r.position.y + 41), 18, accent.lerp(WHITE, 0.4),
				false, r.size.x * 0.46)
		else:
			_tx(txt, Vector2(r.position.x + 26, r.position.y + 41), 19, WHITE, k == sel, r.size.x - 52)


func _desenha_amigo(w: float, h: float) -> void:
	var a := _amigo(alvo)
	if a.is_empty():
		_tx("Este amigo não está mais na lista.", Vector2(0, h * 0.45), 22, MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var c := Vector2(w * 0.5, h * 0.33)
	_avatar(c, 100, _n(a.get("avatar")), _n(a.get("apelido")), _n(a.get("cor")), _cor_status(a),
		_n(a.get("status")) == "offline")
	_tx(_n(a.get("apelido")), Vector2(0, c.y + 150), 34, WHITE, true, w, HORIZONTAL_ALIGNMENT_CENTER)
	var u := _n(a.get("usuario"))
	_tx(("@" + u + "   ·   ") if u != "" else "", Vector2(0, c.y + 184), 18, MUTED, false, w * 0.5, HORIZONTAL_ALIGNMENT_RIGHT)
	_tx(_situacao(a), Vector2(w * 0.5, c.y + 184), 18, accent if _n(a.get("status")) == "jogando" else MUTED, false,
		w * 0.5, HORIZONTAL_ALIGNMENT_LEFT)
	var conv := _convite_de(alvo)
	if not conv.is_empty():
		_tx("Convidou você: " + (_n(conv.get("jogo")) if _n(conv.get("jogo")) != "" else "jogar junto") + "  ·  " +
			_ha(_n(conv.get("enviadaEm"))), Vector2(0, c.y + 214), 17, AMARELO, false, w, HORIZONTAL_ALIGNMENT_CENTER)
	# botões, como na página de jogador do PS4
	var b := _botoes_amigo()
	var larg := 0.0
	for x in b:
		larg += font_bold.get_string_size(str(x[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 64.0 + 16.0
	var bx := (w - larg + 16.0) / 2.0
	var by := c.y + 250
	for i in b.size():
		var rot := str(b[i][0])
		var bw := font_bold.get_string_size(rot, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 64.0
		var r := Rect2(bx, by, bw, 54)
		var on := i == bsel
		var perigo := rot.begins_with("Confirmar")
		_rr(r, (Color("e05260") if perigo else WHITE) if on else Color(1, 1, 1, 0.10), 27)
		_tx(rot, r.position + Vector2(0, 35), 18, Color("0a0f1c") if on and not perigo else WHITE, true, bw,
			HORIZONTAL_ALIGNMENT_CENTER)
		bx += bw + 16.0
	# troféus recentes dele (do feed)
	var y := by + 100
	var tem := false
	for tr in net.get("trofeus", []):
		if typeof(tr) != TYPE_DICTIONARY or _n(tr.get("de", {}).get("id")) != alvo:
			continue
		if not tem:
			_tx("Troféus recentes", Vector2(w * 0.3, y), 18, MUTED, true)
			tem = true
		y += 30
		_tx("Troféu: " + _n(tr.get("nome")) + "  ·  " + _n(tr.get("tipo")), Vector2(w * 0.3, y), 17, WHITE)
		if y > h - 120:
			break


func _desenha_conversa(w: float, h: float) -> void:
	var a := _amigo(alvo)
	_avatar(Vector2(96, 166), 34, _n(a.get("avatar")), _n(a.get("apelido")), _n(a.get("cor")), _cor_status(a))
	_tx(_n(a.get("apelido")), Vector2(146, 160), 24, WHITE, true)
	_tx(_situacao(a), Vector2(146, 186), 15, MUTED)
	draw_line(Vector2(56, 214), Vector2(w - 56, 214), Color(1, 1, 1, 0.10), 1.0)
	# balões de baixo para cima (o mais novo embaixo)
	var base := h - 190.0
	var y := base
	var maxw := w * 0.46
	if conversa.is_empty():
		_tx("Diga oi! As mensagens aparecem aqui.", Vector2(0, h * 0.45), 20, MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(conversa.size() - 1, -1, -1):
		var m: Dictionary = conversa[i]
		var txt := _n(m.get("texto"))
		var tipo := _n(m.get("tipo"))
		if tipo == "convite" or tipo == "netplay":
			txt = "Convite  ·  " + txt
		var tam := font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, maxw, 18)
		var bh := tam.y + 26.0
		var bw := minf(maxw, tam.x) + 36.0
		y -= bh + 34.0
		if y < 228:
			break
		var minha: bool = m.get("minha", false)
		var r := Rect2(w - 80.0 - bw if minha else 80.0, y, bw, bh)
		var cor := accent.darkened(0.25) if minha else Color("1d2640")
		if tipo == "convite" or tipo == "netplay":
			cor = Color("b7791f") if not minha else cor
		if m.get("enviando", false):
			cor.a = 0.6
		_rr(r, cor, 20)
		draw_multiline_string(font, r.position + Vector2(18, 31), txt, HORIZONTAL_ALIGNMENT_LEFT, maxw, 18, -1, WHITE)
		var q := _ha(_n(m.get("enviadaEm"))) if not m.get("enviando", false) else "enviando…"
		_tx(q, Vector2(r.position.x, r.end.y + 18), 13, DIM, false, r.size.x,
			HORIZONTAL_ALIGNMENT_RIGHT if minha else HORIZONTAL_ALIGNMENT_LEFT)
	# respostas rápidas e escrever
	var chips := _chips_conversa()
	var x := 56.0
	var cy := h - 150.0
	var larg_total := 0.0
	for c in chips:
		larg_total += font_bold.get_string_size(str(c[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 44.0 + 12.0
	if larg_total > w - 112.0:   # rola para o escolhido ficar visível
		var antes := 0.0
		for i in bsel:
			antes += font_bold.get_string_size(str(chips[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 56.0
		x = clampf(w * 0.5 - antes, w - 56.0 - larg_total, 56.0)
	for i in chips.size():
		var rot := str(chips[i][0])
		var cw := font_bold.get_string_size(rot, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 44.0
		var r := Rect2(x, cy, cw, 46)
		var on := i == bsel
		_rr(r, WHITE if on else Color(1, 1, 1, 0.10), 23)
		_tx(rot, r.position + Vector2(0, 30), 16, Color("0a0f1c") if on else WHITE, on, cw, HORIZONTAL_ALIGNMENT_CENTER)
		x += cw + 12.0


func _desenha_rodape(w: float, h: float) -> void:
	var dicas := "Ⓐ Escolher    Ⓑ " + ("Voltar" if tela != "" else "Fechar") + ("    L1/R1 Trocar de aba" if tela == "" else "")
	if tela == "conversa":
		dicas = "◀ ▶ Escolher    Ⓐ Enviar    Ⓑ Voltar"
	if kb_open:
		dicas = "Ⓐ Digitar    □ Apagar    L1 Maiúsculas    R1 Espaço    Start Concluir    Ⓑ Cancelar"
	_tx(dicas, Vector2(0, h - 40), 16, DIM, false, w, HORIZONTAL_ALIGNMENT_CENTER)


func _desenha_grade(w: float, h: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.04, 0.96))
	_tx("Escolha o seu ícone", Vector2(0, h * 0.16), 30, WHITE, true, w, HORIZONTAL_ALIGNMENT_CENTER)
	var cel := 116.0
	var gap := 22.0
	var gw := GRADE_COLS * cel + (GRADE_COLS - 1) * gap
	var x0 := (w - gw) / 2.0
	var y0 := h * 0.24
	for i in avatares.size():
		var r := Rect2(x0 + (i % GRADE_COLS) * (cel + gap), y0 + int(i / GRADE_COLS) * (cel + gap + 30), cel, cel)
		var on := i == grade_sel
		if on:
			draw_circle(r.get_center(), cel * 0.5 + 8, accent)
		_avatar(r.get_center(), cel * 0.5, _n(avatares[i].get("id")), _n(avatares[i].get("nome")), _n(avatares[i].get("cor")))
		if on:
			_tx(_n(avatares[i].get("nome")), Vector2(r.position.x - 30, r.end.y + 26), 16, WHITE, true, cel + 60,
				HORIZONTAL_ALIGNMENT_CENTER)


func _desenha_teclado(w: float, h: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.04, 0.96))
	var pw := minf(w * 0.7, 1000.0)
	var x0 := (w - pw) / 2.0
	var y0 := h * 0.22
	_tx(kb_titulo, Vector2(x0, y0), 22, WHITE, true, pw)
	var campo := Rect2(x0, y0 + 20, pw, 64)
	_rr(campo, Color("141b30"), 16, Color(accent, 0.8), 2)
	var cursor := "|" if fmod(t, 1.0) < 0.5 else " "
	_tx(kb_texto + cursor, campo.position + Vector2(20, 42), 24, WHITE, false, pw - 120)
	_tx("%d/%d" % [kb_texto.length(), kb_max], campo.position + Vector2(pw - 100, 42), 14, DIM, false, 84,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var linhas: Array = KB_SIMBOLOS if kb_simb else KB_LETRAS
	var kw := (pw - 9 * 10.0) / 10.0
	var kh := 64.0
	var ky := y0 + 110
	for r in 4:
		for c in 10:
			var ch: String = linhas[r][c]
			if kb_shift and not kb_simb:
				ch = ch.to_upper()
			var rr := Rect2(x0 + c * (kw + 10), ky + r * (kh + 10), kw, kh)
			var on := kb_row == r and kb_col == c
			_rr(rr, WHITE if on else Color("1b2238"), 12)
			_tx(ch, rr.position + Vector2(0, 42), 26, Color("0a0f1c") if on else WHITE, on, kw, HORIZONTAL_ALIGNMENT_CENTER)
	var esp := ["Maiúsculas", "Símbolos" if not kb_simb else "Letras", "Espaço", "Concluir"]
	var ew := (pw - 3 * 10.0) / 4.0
	for c in 4:
		var rr := Rect2(x0 + c * (ew + 10), ky + 4 * (kh + 10), ew, kh)
		var on := kb_row == 4 and kb_col == c
		var ligado := (c == 0 and kb_shift) or (c == 1 and kb_simb)
		_rr(rr, WHITE if on else (Color(accent, 0.35) if ligado or c == 3 else Color("1b2238")), 12)
		_tx(esp[c], rr.position + Vector2(0, 40), 19, Color("0a0f1c") if on else WHITE, true, ew, HORIZONTAL_ALIGNMENT_CENTER)


func _exit_tree() -> void:
	for th in threads:
		if th.is_started():
			th.wait_to_finish()
