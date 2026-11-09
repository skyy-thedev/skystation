extends Control
## SkyStation Launcher (Fase 3)
##
## Lê os jogos de /opt/skystation/games e ~/skystation/games (uma pasta por jogo, com game.json),
## mostra uma fileira de capas navegável por teclado ou controle e abre o jogo escolhido como
## um processo separado. O cage exibe a janela mais recente; quando o jogo fecha, o launcher volta.

const TYPE_NAMES := {
	"autoral": "AUTORAL", "retro": "RETRÔ", "windows": "WINDOWS",
	"linux": "LINUX", "ferramenta": "FERRAMENTA", "app": "APLICATIVO",
}
const CYAN := Color("4fd1ff")
const WHITE := Color("eef2ff")
const MUTED := Color("94a3c8")
const DIM := Color("5a6891")
const PANEL_BG := Color("121a3a")

# Sistemas emulados: pasta em ~/skystation/roms/<sistema>/ e extensões aceitas.
# (.bin de PS1 só aparece se não houver um .cue com o mesmo nome: aí o jogo abre pelo .cue)
const ROM_SYSTEMS := {
	"ps1": {"badge": "PLAYSTATION", "color": "#8b5cf6", "exts": ["cue", "chd", "pbp", "m3u", "iso", "img", "bin"]},
	"ps2": {"badge": "PLAYSTATION 2", "color": "#3b82f6", "exts": ["iso", "chd", "cso", "gz"]},
}

const TILE_W := 210.0
const TILE_H := 280.0
const TILE_GAP := 40.0
const ROW_Y := 150.0

var games: Array = []
var tiles: Array = []
var sel: int = 0
var sel_smooth: float = 0.0

var running_pid: int = -1
var running_title: String = ""
var cooldown: float = 0.0

var menu_open: bool = false
var menu_sel: int = 0
var menu_items: Array = ["Voltar", "Configurações", "Medição de FPS", "Recarregar jogos", "Reiniciar", "Desligar"]
var settings: Control = null
var home_dir: String = OS.get_environment("HOME")
var conf_dir: String = home_dir + "/.config/skystation"
var run_dir: String = OS.get_environment("XDG_RUNTIME_DIR") + "/skystation"

var hold_dir: Vector2i = Vector2i.ZERO
var hold_t: float = 0.0

var stars: Array = []
var t: float = 0.0

var logo_box: HBoxContainer
var clock_lbl: Label
var ring: Panel
var title_lbl: Label
var type_lbl: Label
var desc_lbl: Label
var hint_lbl: Label
var empty_lbl: Label
var overlay: ColorRect
var overlay_lbl: Label
var menu_panel: Panel
var menu_labels: Array = []
var toast_lbl: Label
var toast_t: float = 0.0


# ---------------------------------------------------------------- ciclo de vida

func _ready() -> void:
	_setup_actions()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 160:
		stars.append([rng.randf(), rng.randf(), rng.randf_range(0.8, 2.2),
			rng.randf() * TAU, rng.randf_range(0.5, 1.8), rng.randf_range(0.004, 0.012)])
	_build_ui()
	_reload_games()


func _process(delta: float) -> void:
	t += delta
	clock_lbl.text = Time.get_time_string_from_system().substr(0, 5)

	if running_pid != -1:
		if not OS.is_process_running(running_pid):
			_on_game_closed()
		return  # enquanto o jogo roda, o launcher ignora entradas (controles são globais)

	if settings != null and settings.visible:
		return  # a tela de Configurações cuida da entrada enquanto estiver aberta

	queue_redraw()
	cooldown = max(0.0, cooldown - delta)
	if toast_t > 0.0:
		toast_t -= delta
		toast_lbl.modulate.a = clamp(toast_t, 0.0, 1.0)

	_handle_input(delta)
	_layout(delta)


func _draw() -> void:
	var steps := 24
	for i in steps:
		var c := Color("06091a").lerp(Color("111838"), float(i) / steps)
		draw_rect(Rect2(0, size.y * i / steps, size.x, size.y / steps + 1.0), c)
	for st in stars:
		var x: float = fposmod(st[0] - t * st[5], 1.0) * size.x
		var y: float = st[1] * size.y
		var a: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * st[4] + st[3]))
		draw_circle(Vector2(x, y), st[2] * 0.6, Color(0.8, 0.87, 1.0, a))


# ---------------------------------------------------------------- entradas

func _add_action(action: String, keys: Array, buttons: Array, axis: int = -1, axis_dir: float = 0.0) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.5)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var ja := InputEventJoypadMotion.new()
		ja.axis = axis
		ja.axis_value = axis_dir
		InputMap.action_add_event(action, ja)


func _setup_actions() -> void:
	_add_action("sky_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("sky_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("sky_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("sky_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("sky_accept", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_add_action("sky_back", [KEY_BACKSPACE], [JOY_BUTTON_B])
	_add_action("sky_menu", [KEY_ESCAPE, KEY_M], [JOY_BUTTON_START, JOY_BUTTON_Y])


func _nav_dir() -> Vector2i:
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


func _handle_input(delta: float) -> void:
	if cooldown > 0.0:
		return
	# Direcionais com repetição ao segurar (vale para teclado, d-pad e analógico).
	var d := _nav_dir()
	if d != hold_dir:
		hold_dir = d
		hold_t = 0.35
		if d != Vector2i.ZERO:
			_move(d)
	elif d != Vector2i.ZERO:
		hold_t -= delta
		if hold_t <= 0.0:
			hold_t = 0.12
			_move(d)

	if Input.is_action_just_pressed("sky_menu"):
		_set_menu(not menu_open)
	elif Input.is_action_just_pressed("sky_back"):
		if menu_open:
			_set_menu(false)
	elif Input.is_action_just_pressed("sky_accept"):
		if menu_open:
			_menu_choose()
		else:
			_launch()


func _move(d: Vector2i) -> void:
	if menu_open:
		if d.y != 0:
			menu_sel = wrapi(menu_sel + d.y, 0, menu_items.size())
			_update_menu()
		return
	if d.x != 0 and not games.is_empty():
		var n: int = clamp(sel + d.x, 0, games.size() - 1)
		if n != sel:
			sel = n
			_update_info()


# ---------------------------------------------------------------- jogos

func _reload_games() -> void:
	for tile in tiles:
		tile.queue_free()
	tiles.clear()
	games.clear()
	var bases := ["/opt/skystation/games", OS.get_environment("HOME") + "/skystation/games"]
	for base in bases:
		var da := DirAccess.open(base)
		if da == null:
			continue
		for sub in da.get_directories():
			var g = _read_game(base + "/" + sub, sub)
			if g != null:
				games.append(g)
	_scan_roms()
	games.sort_custom(_game_less)
	for g in games:
		var tile := _make_tile(g)
		add_child(tile)
		move_child(tile, ring.get_index())  # capas ficam atrás do anel de seleção
		tiles.append(tile)
	sel = clamp(sel, 0, max(0, games.size() - 1))
	sel_smooth = float(sel)
	empty_lbl.visible = games.is_empty()
	_update_info()


func _game_less(a: Dictionary, b: Dictionary) -> bool:
	if a["order"] != b["order"]:
		return a["order"] < b["order"]
	return a["title"].naturalnocasecmp_to(b["title"]) < 0


func _read_game(gdir: String, fallback_name: String):
	var jpath := gdir + "/game.json"
	if not FileAccess.file_exists(jpath):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(jpath))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("SkyStation: game.json inválido em " + jpath)
		return null
	var cmd := str(data.get("exec", ""))
	if cmd == "":
		push_warning("SkyStation: game.json sem 'exec' em " + jpath)
		return null
	var g := {
		"id": fallback_name,
		"dir": gdir,
		"title": str(data.get("title", fallback_name)),
		"type": str(data.get("type", "linux")),
		"exec": cmd,
		"description": str(data.get("description", "")),
		"color": Color.from_string(str(data.get("color", "#4fd1ff")), CYAN),
		"order": int(data.get("order", 100)),
		"cover": null,
	}
	var cover_path := gdir + "/" + str(data.get("cover", "cover.png"))
	if FileAccess.file_exists(cover_path):
		var img := Image.load_from_file(cover_path)
		if img != null:
			g["cover"] = ImageTexture.create_from_image(img)
	return g


func _scan_roms() -> void:
	var bases := [home_dir + "/skystation/roms", "/mnt/skystation/roms"]
	var tag_re := RegEx.new()
	tag_re.compile("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")  # remove "(USA)", "[SLUS-00594]" etc.
	for base in bases:
		for sys_id in ROM_SYSTEMS:
			var info: Dictionary = ROM_SYSTEMS[sys_id]
			var rdir: String = base + "/" + sys_id
			var da := DirAccess.open(rdir)
			if da == null:
				continue
			var files := da.get_files()
			for f in files:
				var ext: String = f.get_extension().to_lower()
				if not info["exts"].has(ext):
					continue
				if ext == "bin" and (files.has(f.get_basename() + ".cue") or files.has(f.get_basename() + ".CUE")):
					continue
				var path: String = rdir + "/" + f
				var stem: String = f.get_basename()
				var title: String = tag_re.sub(stem, "", true).strip_edges()
				if title == "":
					title = stem
				var g := {
					"id": sys_id + "-" + stem.validate_filename().replace(" ", "_"),
					"dir": rdir,
					"title": title,
					"type": "retro",
					"badge": info["badge"],
					"exec": "sky-emu %s %s" % [sys_id, _shq(path)],
					"description": "%s  ·  %s" % [info["badge"].capitalize(), f],
					"color": Color.from_string(info["color"], CYAN),
					"order": 50,
					"cover": null,
				}
				for cpath in [rdir + "/covers/" + stem + ".png", rdir + "/" + stem + ".png"]:
					if FileAccess.file_exists(cpath):
						var img := Image.load_from_file(cpath)
						if img != null:
							g["cover"] = ImageTexture.create_from_image(img)
						break
				games.append(g)


func _shq(s: String) -> String:
	# Aspas simples à prova de nomes com apóstrofo (ex.: "Tony Hawk's").
	return "'" + s.replace("'", "'\\''") + "'"


func _launch() -> void:
	if games.is_empty():
		return
	var g: Dictionary = games[sel]
	var pid: int
	if FileAccess.file_exists("/opt/skystation/bin/sky-run"):
		# Fase 4+: sky-run cuida de GameMode, MangoHud, log, sessão própria e código de saída.
		pid = OS.create_process("/opt/skystation/bin/sky-run", [g["dir"], g["exec"], g["id"], g["title"]])
	else:
		var cmd := "cd \"%s\" && exec %s" % [g["dir"], g["exec"]]
		pid = OS.create_process("/bin/sh", ["-c", cmd])
	if pid <= 0:
		_toast("Não consegui abrir " + g["title"])
		return
	running_pid = pid
	running_title = g["title"]
	overlay_lbl.text = "Abrindo %s…" % running_title
	overlay.visible = true
	# Enquanto o jogo roda, o launcher praticamente dorme: sem redesenho e no máximo 4 checagens/s.
	OS.low_processor_usage_mode = true
	Engine.max_fps = 4


func _on_game_closed() -> void:
	running_pid = -1
	overlay.visible = false
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	_report_exit()
	cooldown = 0.5  # evita que o botão usado para sair do jogo dispare algo aqui
	hold_dir = _nav_dir()


func _report_exit() -> void:
	var msg := ""
	if FileAccess.file_exists(run_dir + "/last_msg"):
		msg = FileAccess.get_file_as_string(run_dir + "/last_msg").strip_edges()
	var code := -1
	if FileAccess.file_exists(run_dir + "/last_exit"):
		code = FileAccess.get_file_as_string(run_dir + "/last_exit").strip_edges().to_int()
	if msg != "":
		_toast(msg, 6.0)
	elif code == 143 or code == 137:
		_toast("Jogo fechado pelo botão Home")
	elif code > 0:
		_toast("O jogo fechou com erro (código %d)" % code, 5.0)


func _open_settings() -> void:
	if settings == null:
		# load() em vez de preload(): se settings.gd tiver algum erro, só esta tela falha,
		# o launcher continua funcionando.
		var script = load("res://settings.gd")
		if script == null or not script.can_instantiate():
			_toast("Configurações indisponíveis (erro no script)", 4.0)
			return
		settings = script.new()
		settings.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(settings)
		settings.closed.connect(_on_settings_closed)
	settings.open()


func _on_settings_closed() -> void:
	cooldown = 0.35
	hold_dir = _nav_dir()


func _fps_on() -> bool:
	return FileAccess.file_exists(conf_dir + "/mangohud.on")


func _toggle_fps() -> void:
	DirAccess.make_dir_recursive_absolute(conf_dir)
	if _fps_on():
		DirAccess.remove_absolute(conf_dir + "/mangohud.on")
		_toast("Medição de FPS desligada")
	else:
		var f := FileAccess.open(conf_dir + "/mangohud.on", FileAccess.WRITE)
		if f != null:
			f.store_string("1\n")
			f.close()
		_toast("Medição de FPS ligada: contador na tela + log em ~/skystation/benchmarks")
	_update_menu()


# ---------------------------------------------------------------- menu

func _set_menu(open: bool) -> void:
	menu_open = open
	menu_sel = 0
	menu_panel.visible = open
	_update_menu()


func _update_menu() -> void:
	for i in menu_labels.size():
		var lbl: Label = menu_labels[i]
		var on := i == menu_sel
		var item: String = menu_items[i]
		if item == "Medição de FPS":
			item += ": " + ("ligada" if _fps_on() else "desligada")
		lbl.text = ("›  " if on else "    ") + item
		lbl.add_theme_color_override("font_color", CYAN if on else MUTED)


func _menu_choose() -> void:
	match menu_items[menu_sel]:
		"Voltar":
			_set_menu(false)
		"Configurações":
			_set_menu(false)
			_open_settings()
		"Medição de FPS":
			_toggle_fps()
		"Recarregar jogos":
			_set_menu(false)
			_reload_games()
			_toast("%d jogo(s) encontrado(s)" % games.size())
		"Reiniciar":
			OS.execute("systemctl", ["reboot"])
		"Desligar":
			OS.execute("systemctl", ["poweroff"])


# ---------------------------------------------------------------- interface

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	logo_box = HBoxContainer.new()
	logo_box.add_theme_constant_override("separation", 0)
	logo_box.add_child(_label("Sky", 30, WHITE))
	logo_box.add_child(_label("Station", 30, CYAN))
	logo_box.position = Vector2(48, 30)
	add_child(logo_box)

	clock_lbl = _label("", 22, MUTED)
	add_child(clock_lbl)

	ring = Panel.new()
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = CYAN
	rs.set_border_width_all(4)
	rs.set_corner_radius_all(22)
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring)

	type_lbl = _label("", 15, CYAN)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(type_lbl)
	title_lbl = _label("", 34, WHITE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_lbl)
	desc_lbl = _label("", 18, MUTED)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(desc_lbl)

	hint_lbl = _label("A / Enter  Jogar        Start / Esc  Menu        Segure Home ou F12  Fechar jogo", 16, DIM)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_lbl)

	empty_lbl = _label("Nenhum jogo encontrado.\nColoque pastas com game.json em ~/skystation/games", 22, MUTED)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.visible = false
	add_child(empty_lbl)

	toast_lbl = _label("", 18, WHITE)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.modulate.a = 0.0
	add_child(toast_lbl)

	menu_panel = Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(PANEL_BG, 0.96)
	ms.border_color = Color(CYAN, 0.5)
	ms.set_border_width_all(2)
	ms.set_corner_radius_all(18)
	menu_panel.add_theme_stylebox_override("panel", ms)
	menu_panel.size = Vector2(440, 70 + 48 * menu_items.size())
	var mt := _label("Menu", 24, WHITE)
	mt.position = Vector2(32, 22)
	menu_panel.add_child(mt)
	for i in menu_items.size():
		var ml := _label("", 22, MUTED)
		ml.position = Vector2(32, 72 + 48 * i)
		menu_panel.add_child(ml)
		menu_labels.append(ml)
	menu_panel.visible = false
	add_child(menu_panel)

	overlay = ColorRect.new()
	overlay.color = Color(0.01, 0.02, 0.06, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay_lbl = _label("", 30, WHITE)
	overlay_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_lbl)
	add_child(overlay)


func _make_tile(g: Dictionary) -> Panel:
	var p := Panel.new()
	var col: Color = g["color"]
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.55)
	sb.border_color = col.darkened(0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.clip_contents = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(TILE_W, TILE_H)
	p.pivot_offset = p.size / 2.0

	if g["cover"] != null:
		var tr := TextureRect.new()
		tr.texture = g["cover"]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tr)
	else:
		var words: PackedStringArray = str(g["title"]).split(" ", false)
		var ini := ""
		for w in words.slice(0, 2):
			ini += w.substr(0, 1).to_upper()
		var il := _label(ini, 72, col.lightened(0.3))
		il.set_anchors_preset(Control.PRESET_FULL_RECT)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		il.offset_bottom = -40
		p.add_child(il)

	var strip := ColorRect.new()
	strip.color = Color(0.02, 0.04, 0.11, 0.78)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -46
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := _label(g["title"], 17, WHITE)
	tl.set_anchors_preset(Control.PRESET_FULL_RECT)
	tl.offset_left = 14
	tl.offset_right = -10
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.clip_text = true
	strip.add_child(tl)
	p.add_child(strip)
	return p


func _update_info() -> void:
	if games.is_empty():
		title_lbl.text = ""
		type_lbl.text = ""
		desc_lbl.text = ""
		return
	var g: Dictionary = games[sel]
	title_lbl.text = g["title"]
	type_lbl.text = g.get("badge", TYPE_NAMES.get(g["type"], str(g["type"]).to_upper()))
	type_lbl.add_theme_color_override("font_color", g["color"])
	desc_lbl.text = g["description"]


func _toast(msg: String, seconds: float = 2.5) -> void:
	toast_lbl.text = msg
	toast_t = seconds


func _layout(delta: float) -> void:
	var k := 1.0 - exp(-delta * 12.0)
	sel_smooth = lerp(sel_smooth, float(sel), k)
	var cx := size.x * 0.5
	for i in tiles.size():
		var tile: Panel = tiles[i]
		var on := i == sel
		tile.position = Vector2(cx - TILE_W / 2.0 + (i - sel_smooth) * (TILE_W + TILE_GAP), ROW_Y)
		var target := 1.08 if on else 0.9
		tile.scale = tile.scale.lerp(Vector2.ONE * target, k)
		tile.modulate.a = lerp(tile.modulate.a, 1.0 if on else 0.55, k)

	ring.visible = not tiles.is_empty()
	if ring.visible:
		var tile: Panel = tiles[sel]
		var half := Vector2(TILE_W, TILE_H) * tile.scale.x / 2.0 + Vector2(8, 8)
		var center := tile.position + tile.pivot_offset
		ring.position = center - half
		ring.size = half * 2.0
		var pulse := 0.75 + 0.25 * sin(t * 4.0)
		ring.modulate.a = pulse

	var info_y := ROW_Y + TILE_H * 1.08 + 34.0
	type_lbl.position = Vector2(0, info_y)
	type_lbl.size = Vector2(size.x, 20)
	title_lbl.position = Vector2(0, info_y + 22)
	title_lbl.size = Vector2(size.x, 44)
	desc_lbl.position = Vector2(size.x * 0.2, info_y + 70)
	desc_lbl.size = Vector2(size.x * 0.6, 60)

	clock_lbl.position = Vector2(size.x - 110, 36)
	hint_lbl.position = Vector2(0, size.y - 46)
	hint_lbl.size = Vector2(size.x, 24)
	empty_lbl.position = Vector2(0, size.y * 0.42)
	empty_lbl.size = Vector2(size.x, 80)
	toast_lbl.position = Vector2(0, size.y - 90)
	toast_lbl.size = Vector2(size.x, 24)
	menu_panel.position = (size - menu_panel.size) / 2.0
