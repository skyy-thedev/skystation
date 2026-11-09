extends Control
## SkyStation: Configurações (Wi-Fi, Bluetooth, Som, Sistema).
##
## Aberta pelo launcher (main.gd). Tudo é desenhado em _draw (leve, sem dezenas de nós).
## Os controles são lidos direto do Input, e o teclado físico por eventos, para que letras
## digitadas numa senha não virem navegação (no launcher, W/A/S/D também navegam).
## As consultas ao sistema (sky-config) rodam em threads: a tela nunca congela.

signal closed

const SKY_CONFIG := "/opt/skystation/bin/sky-config"
var CYAN := Color("4fd1ff")  # o launcher troca pela cor do tema
const WHITE := Color("eef2ff")
const MUTED := Color("94a3c8")
const DIM := Color("5a6891")
const PANEL := Color("121a3a")
const INK := Color("06091a")
const SECTIONS := ["Wi-Fi", "Bluetooth", "Som", "Sistema"]

const KB_LETTERS := ["1234567890", "qwertyuiop", "asdfghjkl@", "zxcvbnm.-_"]
const KB_SYMBOLS := ["1234567890", "!#$%&*()+=", "[]{}<>/\\|~", ";:'\",.?`^-"]
const KB_SPECIAL := ["Maiúsc", "Símbolos", "Espaço", "Apagar", "OK"]

var section: int = 0
var column: int = 0  # 0 = lista de seções, 1 = itens da seção
var item: int = 0
var items: Array = []
var status: String = ""
var volume: int = -1
var muted: bool = false

var kb_open: bool = false
var kb_text: String = ""
var kb_title: String = ""
var kb_ssid: String = ""
var kb_row: int = 1
var kb_col: int = 0
var kb_shift: bool = false
var kb_symbols: bool = false

var cmd_queue: Array = []
var joy_prev: Dictionary = {}
var joy_hold: Dictionary = {}
var threads: Array = []
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(start_section: int = -1) -> void:
	visible = true
	column = 0
	if start_section >= 0 and start_section < SECTIONS.size():
		section = start_section
	kb_open = false
	cmd_queue.clear()
	joy_prev = _joy_buttons()  # o "A" que abriu esta tela não pode valer aqui
	_load_section()


func _close() -> void:
	visible = false
	closed.emit()


# ---------------------------------------------------------------- entrada

func _joy_buttons() -> Dictionary:
	var st := {"up": false, "down": false, "left": false, "right": false,
		"a": false, "b": false, "x": false, "y": false, "start": false}
	for dev in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		st["up"] = st["up"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP) or ay < -0.6
		st["down"] = st["down"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN) or ay > 0.6
		st["left"] = st["left"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT) or ax < -0.6
		st["right"] = st["right"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT) or ax > 0.6
		st["a"] = st["a"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_A)
		st["b"] = st["b"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_B)
		st["x"] = st["x"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_X)
		st["y"] = st["y"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_Y)
		st["start"] = st["start"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_START)
	return st


func _poll_joy(delta: float) -> void:
	var st := _joy_buttons()
	for k in st:
		var down: bool = st[k]
		var was: bool = joy_prev.get(k, false)
		if down and not was:
			cmd_queue.append(k)
			joy_hold[k] = 0.35
		elif down and k in ["up", "down", "left", "right"]:
			joy_hold[k] = joy_hold.get(k, 0.35) - delta
			if joy_hold[k] <= 0.0:
				joy_hold[k] = 0.1
				cmd_queue.append(k)
		joy_prev[k] = down


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey) or not event.is_pressed():
		return
	var k := event as InputEventKey
	var c := ""
	match k.keycode:
		KEY_UP:
			c = "up"
		KEY_DOWN:
			c = "down"
		KEY_LEFT:
			c = "left"
		KEY_RIGHT:
			c = "right"
		KEY_ENTER, KEY_KP_ENTER:
			c = "start" if kb_open else "a"
		KEY_ESCAPE:
			c = "y" if kb_open else "b"
		KEY_BACKSPACE:
			c = "b"
		_:
			if kb_open and k.unicode >= 32:
				c = "char:" + String.chr(k.unicode)
			elif not kb_open and k.keycode == KEY_SPACE:
				c = "a"
	if c != "":
		cmd_queue.append(c)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_poll_joy(delta)
	while not cmd_queue.is_empty():
		var c: String = cmd_queue.pop_front()
		if kb_open:
			_kb_command(c)
		else:
			_command(c)
	queue_redraw()


func _command(c: String) -> void:
	if c == "up":
		if column == 0:
			section = wrapi(section - 1, 0, SECTIONS.size())
			_load_section()
		else:
			item = max(0, item - 1)
	elif c == "down":
		if column == 0:
			section = wrapi(section + 1, 0, SECTIONS.size())
			_load_section()
		else:
			item = min(items.size() - 1, item + 1)
	elif c == "right" or (c == "a" and column == 0):
		if not items.is_empty():
			column = 1
			item = clamp(item, 0, items.size() - 1)
	elif c == "left":
		column = 0
	elif c == "a":
		_activate()
	elif c == "b":
		if column == 1:
			column = 0
		else:
			_close()


# ---------------------------------------------------------------- seções

func _load_section() -> void:
	items = []
	item = 0
	status = ""
	match section:
		0:
			items = [{"text": "Procurar redes", "action": "wifi_scan"}]
			status = "Procurando redes…"
			_async(["wifi", "list"], _on_wifi.bind(0))
		1:
			items = [{"text": "Procurar controles (8 s)", "action": "bt_scan"}]
			_async(["bt", "list"], _on_bt.bind(1))
		2:
			_build_sound_items()
			_async(["volume", "get"], _on_volume.bind(2))
		3:
			status = "Lendo informações…"
			_async(["info"], _on_info.bind(3))


func _activate() -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[item]
	match it["action"]:
		"wifi_scan":
			status = "Procurando redes…"
			_async(["wifi", "list"], _on_wifi.bind(section))
		"wifi_join":
			var n: Dictionary = it["arg"]
			if n["secure"]:
				_kb_start("Senha da rede \"%s\"" % n["ssid"], n["ssid"])
			else:
				_wifi_connect(n["ssid"], "")
		"bt_scan":
			status = "Procurando… deixe o controle em modo de pareamento"
			_async(["bt", "scan"], _on_bt.bind(section))
		"bt_pair":
			status = "Pareando %s…" % it["text"]
			_async(["bt", "pair", it["arg"]], _on_result.bind(section))
		"vol_up":
			_set_volume(volume + 10)
		"vol_down":
			_set_volume(volume - 10)
		"vol_mute":
			_async(["volume", "mute"], _on_volume.bind(section))


func _on_wifi(data: Dictionary, sec: int) -> void:
	if sec != section:
		return
	items = [{"text": "Procurar redes de novo", "action": "wifi_scan"}]
	if not data.get("ok", false):
		status = str(data.get("error", "erro"))
		return
	for n in data["networks"]:
		var t: String = str(n["ssid"]) + "   %d%%" % int(n["signal"])
		if n["secure"]:
			t += "   · com senha"
		if n["active"]:
			t += "   · conectada"
		items.append({"text": t, "action": "wifi_join", "arg": n})
	status = "%d rede(s) encontrada(s)" % (items.size() - 1)
	item = clamp(item, 0, items.size() - 1)


func _wifi_connect(ssid: String, password: String) -> void:
	status = "Conectando a %s…" % ssid
	_async(["wifi", "connect", ssid, password], _on_result.bind(section))


func _on_bt(data: Dictionary, sec: int) -> void:
	if sec != section:
		return
	items = [{"text": "Procurar controles (8 s)", "action": "bt_scan"}]
	if not data.get("ok", false):
		status = str(data.get("error", "erro"))
		return
	for d in data["devices"]:
		var t: String = str(d["name"])
		if d["paired"]:
			t += "   · pareado"
		items.append({"text": t, "action": "bt_pair", "arg": d["mac"]})
	status = "%d dispositivo(s)" % (items.size() - 1)
	item = clamp(item, 0, items.size() - 1)


func _on_result(data: Dictionary, sec: int) -> void:
	if data.get("ok", false):
		status = str(data.get("message", "Pronto"))
		if sec == section:
			_load_section()
			status = str(data.get("message", "Pronto"))
	else:
		status = str(data.get("error", "Falhou"))


func _set_volume(v: int) -> void:
	_async(["volume", "set", str(clamp(v, 0, 100))], _on_volume.bind(section))


func _on_volume(data: Dictionary, sec: int) -> void:
	if not data.get("ok", false):
		status = str(data.get("error", "erro"))
		return
	volume = int(data["volume"])
	muted = bool(data["muted"])
	if sec == section:
		_build_sound_items()


func _build_sound_items() -> void:
	var cur := "Volume: %d%%" % volume if volume >= 0 else "Volume: lendo…"
	if muted:
		cur += "   (mudo)"
	var keep := item
	items = [
		{"text": cur, "action": "info"},
		{"text": "Aumentar  (+10%)", "action": "vol_up"},
		{"text": "Diminuir  (−10%)", "action": "vol_down"},
		{"text": "Ligar / desligar o mudo", "action": "vol_mute"},
	]
	item = clamp(keep, 0, items.size() - 1)


func _on_info(data: Dictionary, sec: int) -> void:
	if sec != section:
		return
	items = []
	if not data.get("ok", false):
		status = str(data.get("error", "erro"))
		return
	for pair in data["items"]:
		items.append({"text": "%s:   %s" % [pair[0], pair[1]], "action": "info"})
	status = ""


# ---------------------------------------------------------------- threads

func _async(args: Array, cb: Callable) -> void:
	var th := Thread.new()
	threads.append(th)
	th.start(_worker.bind(args, cb, th))


func _worker(args: Array, cb: Callable, th: Thread) -> void:
	var output := []
	var code := OS.execute(SKY_CONFIG, PackedStringArray(args), output, false)
	var text := ""
	if output.size() > 0:
		text = str(output[0])
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		data = {"ok": false, "error": "resposta inválida do sistema (código %d)" % code}
	call_deferred("_finish", th, cb, data)


func _finish(th: Thread, cb: Callable, data: Dictionary) -> void:
	th.wait_to_finish()
	threads.erase(th)
	cb.call(data)


# ---------------------------------------------------------------- teclado virtual

func _kb_start(title: String, ssid: String) -> void:
	kb_open = true
	kb_text = ""
	kb_title = title
	kb_ssid = ssid
	kb_row = 1
	kb_col = 0
	kb_shift = false
	kb_symbols = false


func _kb_rows() -> Array:
	return KB_SYMBOLS if kb_symbols else KB_LETTERS


func _kb_command(c: String) -> void:
	if c.begins_with("char:"):
		kb_text += c.substr(5)
		return
	match c:
		"up":
			if kb_row == 4:
				kb_row = 3
				kb_col = min(9, kb_col * 2)
			elif kb_row > 0:
				kb_row -= 1
		"down":
			if kb_row == 3:
				kb_row = 4
				kb_col = min(4, int(kb_col / 2.0))
			elif kb_row < 3:
				kb_row += 1
		"left":
			kb_col = max(0, kb_col - 1)
		"right":
			kb_col = min(9 if kb_row < 4 else 4, kb_col + 1)
		"a":
			_kb_press()
		"b":
			kb_text = kb_text.substr(0, max(0, kb_text.length() - 1))
		"x":
			kb_shift = not kb_shift
		"start":
			_kb_ok()
		"y":
			kb_open = false
			status = "Cancelado"


func _kb_press() -> void:
	if kb_row < 4:
		var ch: String = _kb_rows()[kb_row][kb_col]
		if kb_shift and not kb_symbols:
			ch = ch.to_upper()
		kb_text += ch
		return
	match kb_col:
		0:
			kb_shift = not kb_shift
		1:
			kb_symbols = not kb_symbols
		2:
			kb_text += " "
		3:
			kb_text = kb_text.substr(0, max(0, kb_text.length() - 1))
		4:
			_kb_ok()


func _kb_ok() -> void:
	kb_open = false
	_wifi_connect(kb_ssid, kb_text)


# ---------------------------------------------------------------- desenho

func _text(t: String, pos: Vector2, fsize: int, color: Color, width: float = -1.0,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, pos, t, align, width, fsize, color)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# translúcida: o fundo de ondas do launcher continua aparecendo atrás
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.06, 0.62))
	draw_rect(Rect2(0, 0, 300, size.y), Color(0, 0, 0, 0.3))
	_text("Configurações", Vector2(48, 70), 32, WHITE)

	for i in SECTIONS.size():
		var y := 140 + i * 54
		var on := i == section
		if on:
			draw_rect(Rect2(36, y - 34, 236, 48), Color(CYAN, 0.2 if column == 0 else 0.08))
		_text(SECTIONS[i], Vector2(56, y), 22, CYAN if on else MUTED)

	draw_line(Vector2(296, 110), Vector2(296, h - 110), Color(DIM, 0.6), 1.0)
	var x0 := 330.0
	var rows_fit := int((h - 260) / 46.0)
	var first: int = clamp(item - rows_fit + 1, 0, max(0, items.size() - rows_fit))
	for i in range(first, min(items.size(), first + rows_fit)):
		var y := 140 + (i - first) * 46
		var it: Dictionary = items[i]
		var on := column == 1 and i == item
		if on:
			draw_rect(Rect2(x0 - 14, y - 32, w - x0 - 30, 44), Color(CYAN, 0.18))
		var col := MUTED if it["action"] == "info" else WHITE
		if on:
			col = CYAN
		_text(str(it["text"]), Vector2(x0, y), 20, col, w - x0 - 60)

	var st := status
	if not threads.is_empty():
		st = "…  " + st
	_text(st, Vector2(x0, h - 120), 18, MUTED, w - x0 - 60)
	_text("Direcional  navegar      A  escolher      B  voltar", Vector2(48, h - 44), 16, DIM)

	if kb_open:
		_draw_keyboard()


func _draw_keyboard() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var kw := 64.0
	var kh := 52.0
	var gap := 8.0
	var total_w := 10 * kw + 9 * gap
	var x0 := (w - total_w) / 2.0
	var y0 := h - (5 * kh + 4 * gap) - 80
	draw_rect(Rect2(x0, y0 - 124, total_w, 104), PANEL)
	_text(kb_title, Vector2(x0 + 20, y0 - 88), 18, MUTED, total_w - 40)
	_text(kb_text + "_", Vector2(x0 + 20, y0 - 44), 28, WHITE, total_w - 40)

	var rows := _kb_rows()
	for r in 4:
		for c in 10:
			var rect := Rect2(x0 + c * (kw + gap), y0 + r * (kh + gap), kw, kh)
			var on := kb_row == r and kb_col == c
			draw_rect(rect, CYAN if on else PANEL)
			var ch: String = rows[r][c]
			if kb_shift and not kb_symbols:
				ch = ch.to_upper()
			_text(ch, rect.position + Vector2(0, kh * 0.68), 22, INK if on else WHITE, kw,
				HORIZONTAL_ALIGNMENT_CENTER)
	for c in 5:
		var rect := Rect2(x0 + c * (2 * kw + 2 * gap), y0 + 4 * (kh + gap), 2 * kw + gap, kh)
		var on := kb_row == 4 and kb_col == c
		var label: String = KB_SPECIAL[c]
		if c == 0 and kb_shift:
			label = "MAIÚSC"
		if c == 1 and kb_symbols:
			label = "Letras"
		draw_rect(rect, CYAN if on else PANEL.lightened(0.08))
		_text(label, rect.position + Vector2(0, kh * 0.66), 18, INK if on else WHITE, rect.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
	_text("A digitar    B apagar    X maiúsculas    Start OK    Y cancelar    (ou use o teclado)",
		Vector2(x0, y0 + 5 * (kh + gap) + 22), 15, MUTED, total_w)
