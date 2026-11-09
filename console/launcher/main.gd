extends Control
## SkyStation Launcher — interface "barra cruzada" (Fase 5.5)
##
## Categorias na horizontal (Sistema, Jogos, PS1, PS2, Apps, Energia) e itens na vertical,
## sobre um fundo de ondas animado por shader. Tudo é desenhado em _draw (leve: um nó só
## para a interface inteira) e os sons são sintetizados na hora (nenhum arquivo de áudio).
##
## Jogos: /opt/skystation/games e ~/skystation/games (uma pasta por jogo, com game.json).
## ROMs:  ~/skystation/roms/<sistema>, /mnt/skystation/roms/<sistema> (VM) e
##        /mnt/skyroms/<sistema> (pendrive de jogos com o rótulo SKYROMS).

# ---------------------------------------------------------------- constantes

const WHITE := Color("f2f6ff")
const MUTED := Color("a9b6d8")
const DIM := Color("6d7ba3")

const TYPE_NAMES := {
	"autoral": "Jogo autoral", "retro": "Retrô", "windows": "Jogo de PC (Windows)",
	"linux": "Jogo para Linux", "ferramenta": "Ferramenta", "app": "Aplicativo",
}
const ROM_SYSTEMS := {
	"ps1": {"badge": "PS1", "name": "PlayStation", "color": "#8b7cf6",
		"exts": ["cue", "chd", "pbp", "m3u", "iso", "img", "bin"]},
	"ps2": {"badge": "PS2", "name": "PlayStation 2", "color": "#4f8cff",
		"exts": ["iso", "chd", "cso", "gz"]},
}
const ROM_BASES := ["/mnt/skyroms", "/mnt/skystation/roms"]  # + ~/skystation/roms

# Paletas do fundo: [topo, base, cor da onda, destaque]
const THEMES := {
	"noite": ["Noite", Color("040817"), Color("0d1a4a"), Color("6fc8ff"), Color("4fd1ff")],
	"oceano": ["Oceano", Color("021320"), Color("0b4a78"), Color("7fe3ff"), Color("5fdcff")],
	"aurora": ["Aurora", Color("02140f"), Color("0b4f45"), Color("8dffd2"), Color("54f0b8")],
	"crepusculo": ["Crepúsculo", Color("120518"), Color("4a1650"), Color("ffa4e0"), Color("ff7ad0")],
	"brasa": ["Brasa", Color("160604"), Color("5a1a0c"), Color("ffb27a"), Color("ff9a52")],
	"grafite": ["Grafite", Color("0a0b0e"), Color("2c3039"), Color("dfe6f5"), Color("cfd8ea")],
}
const THEME_ORDER := ["auto", "noite", "oceano", "aurora", "crepusculo", "brasa", "grafite"]

const INTRO_LEN := 3.4
const MONTHS := ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
const WEEKDAYS := ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]

const BG_SHADER := """
shader_type canvas_item;
uniform vec3 col_top : source_color = vec3(0.016, 0.031, 0.09);
uniform vec3 col_bot : source_color = vec3(0.05, 0.10, 0.29);
uniform vec3 wave_col : source_color = vec3(0.44, 0.78, 1.0);
uniform float intensity = 1.0;
uniform float sparkle = 1.0;
uniform int strands = 9;
uniform float aspect = 1.7778;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Altura da onda em x (0..1): duas senoides lentas que se cruzam.
float wave_y(float x, float t, float k) {
	return 0.60
		+ 0.075 * sin(x * 4.1 + t * 0.55 + k * 0.9)
		+ 0.035 * sin(x * 9.3 - t * 0.83 + k * 2.1)
		+ 0.020 * sin(x * 17.0 + t * 1.30 - k * 1.3);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec3 col = mix(col_top, col_bot, smoothstep(0.0, 1.0, uv.y));

	// brilho difuso atrás da onda
	float base = wave_y(uv.x, t * 0.7, 0.0);
	col += wave_col * 0.10 * exp(-pow((uv.y - base) * 4.0, 2.0)) * intensity;
	// "lençol": área macia entre dois fios da onda
	float a = wave_y(uv.x, t, 0.0);
	float b = wave_y(uv.x, t * 0.9, 3.0) + 0.05;
	float lo = min(a, b);
	float hi = max(a, b);
	float sheet = smoothstep(lo - 0.004, lo + 0.03, uv.y) * (1.0 - smoothstep(hi - 0.03, hi + 0.004, uv.y));
	col += wave_col * 0.10 * sheet * intensity;

	// fios: cada um é uma interpolação torcida entre as duas bordas
	float lines = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= strands) { break; }
		float f = float(i) / max(float(strands - 1), 1.0);
		float twist = 0.5 + 0.5 * sin(uv.x * 3.0 + t * 0.4 + f * 6.2831);
		float y = mix(a, b, mix(f, twist, 0.55));
		float d = abs(uv.y - y) * 720.0;          // distância em "pixels" (720p)
		lines += exp(-d * d * 0.35) * (0.55 + 0.45 * sin(uv.x * 6.0 + f * 9.0 - t));
	}
	col += wave_col * lines * 0.20 * intensity;

	// partículas subindo devagar
	vec2 g = vec2(uv.x * aspect, uv.y + t * 0.012) * vec2(26.0, 26.0);
	vec2 id = floor(g);
	float h = hash(id);
	vec2 c = fract(g) - vec2(0.5) - (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.6;
	float sp = step(0.93, h) * exp(-dot(c, c) * 140.0) * (0.45 + 0.55 * sin(t * 1.7 + h * 50.0));
	col += mix(vec3(1.0), wave_col, 0.4) * sp * 0.65 * sparkle;

	// vinheta
	vec2 v = (uv - 0.5) * vec2(1.15, 1.0);
	col *= mix(0.62, 1.0, smoothstep(0.95, 0.25, length(v)));
	COLOR = vec4(col, 1.0);
}
"""

# ---------------------------------------------------------------- estado

var cats: Array = []          # [{id, title, icon, items: [...]}]
var cat: int = 1
var cat_smooth: float = 1.0
var item_sel: Dictionary = {}     # id da categoria -> item selecionado
var item_smooth: float = 0.0

var games: Array = []
var running_pid: int = -1
var running_title: String = ""
var cooldown: float = 0.0
var hold_dir: Vector2i = Vector2i.ZERO
var hold_t: float = 0.0

var panel_open: bool = false
var panel_t: float = 0.0
var panel_sel: int = 0
var panel_items: Array = []

var settings: Control = null
var home_dir: String = OS.get_environment("HOME")
var conf_dir: String = home_dir + "/.config/skystation"
var run_dir: String = OS.get_environment("XDG_RUNTIME_DIR") + "/skystation"

var t: float = 0.0
var intro_t: float = 0.0
var ui_alpha: float = 0.0
var toast_msg: String = ""
var toast_t: float = 0.0
var busy_msg: String = ""
var busy_thread: Thread = null
var quit_at: float = -1.0

var theme_key: String = "auto"
var palette: Array = []
var accent: Color = Color("4fd1ff")
var sounds_on: bool = true
var low_gfx: bool = false

var bg: ColorRect
var bg_mat: ShaderMaterial
var font: Font
var font_bold: Font
var players: Dictionary = {}
var sfx: Dictionary = {}
var styles: Dictionary = {}
var glow_tex: GradientTexture2D
var side_tex: GradientTexture2D
var logo_tex: Texture2D = null

var status_t: float = 0.0
var wifi_q: int = -1
var pads: int = 0
var disk_txt: String = ""
var version_txt: String = ""
var skyroms_present: bool = false


# ---------------------------------------------------------------- ciclo de vida

func _ready() -> void:
	_setup_actions()
	font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = font
	fv.variation_embolden = 0.6
	font_bold = fv

	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	low_gfx = OS.get_environment("LIBGL_ALWAYS_SOFTWARE") == "1" or adapter.contains("llvmpipe") \
		or adapter.contains("softpipe") or FileAccess.file_exists(conf_dir + "/visual.leve")
	if OS.get_environment("SKY_VISUAL") == "alto":
		low_gfx = false
	if low_gfx:
		Engine.max_fps = 30

	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true  # a interface (desenhada em _draw) fica por cima do fundo
	var sh := Shader.new()
	sh.code = BG_SHADER
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = sh
	bg.material = bg_mat
	add_child(bg)
	bg_mat.set_shader_parameter("strands", 5 if low_gfx else 11)
	bg_mat.set_shader_parameter("sparkle", 0.0 if low_gfx else 1.0)

	sounds_on = not FileAccess.file_exists(conf_dir + "/sons.off")
	theme_key = _read_text(conf_dir + "/tema", "auto")
	if not THEME_ORDER.has(theme_key):
		theme_key = "auto"
	_apply_theme(true)
	_make_glow()
	logo_tex = _load_tex(ProjectSettings.globalize_path("res://logo.png"))  # a mesma logo da tela de boot
	_make_sounds()
	_load_state()
	_reload_games()
	_refresh_status()
	version_txt = _read_text("/opt/skystation/VERSION", "")
	if FileAccess.file_exists(conf_dir + "/intro.off"):
		intro_t = INTRO_LEN
	else:
		_play("chime")


func _exit_tree() -> void:
	if busy_thread != null and busy_thread.is_started():
		busy_thread.wait_to_finish()


func _process(delta: float) -> void:
	t += delta
	if running_pid != -1:
		if not OS.is_process_running(running_pid):
			_on_game_closed()
		return  # enquanto o jogo roda, o launcher praticamente dorme

	if quit_at > 0.0 and t >= quit_at:
		get_tree().quit()  # sessão termina com código 0: o login automático reabre o console
		return

	intro_t += delta
	ui_alpha = clamp((intro_t - 2.2) / 0.8, 0.0, 1.0)
	bg_mat.set_shader_parameter("intensity", clamp(intro_t / 1.6, 0.0, 1.0))
	bg_mat.set_shader_parameter("aspect", size.x / max(size.y, 1.0))

	status_t -= delta
	if status_t <= 0.0:
		_refresh_status()

	if toast_t > 0.0:
		toast_t -= delta
	queue_redraw()

	if settings != null and settings.visible:
		return
	cooldown = max(0.0, cooldown - delta)
	if intro_t < INTRO_LEN:
		if Input.is_action_just_pressed("sky_accept") or Input.is_action_just_pressed("sky_back") \
				or Input.is_action_just_pressed("sky_menu"):
			intro_t = INTRO_LEN
			cooldown = 0.25
		return
	if busy_msg == "":
		_handle_input(delta)
	var k := 1.0 - exp(-delta * 11.0)
	cat_smooth = lerp(cat_smooth, float(cat), k)
	item_smooth = lerp(item_smooth, float(_cur_item()), k)
	panel_t = move_toward(panel_t, 1.0 if panel_open else 0.0, delta * 6.0)


# ---------------------------------------------------------------- entradas

func _add_action(action: String, keys: Array, buttons: Array, axis: int = -1, axis_dir: float = 0.0) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.5)
	for kc in keys:
		var e := InputEventKey.new()
		e.physical_keycode = kc
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
	_add_action("sky_back", [KEY_BACKSPACE, KEY_ESCAPE], [JOY_BUTTON_B])
	_add_action("sky_menu", [KEY_M, KEY_TAB], [JOY_BUTTON_START, JOY_BUTTON_Y])


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
	var d := _nav_dir()
	if d != hold_dir:
		hold_dir = d
		hold_t = 0.38
		if d != Vector2i.ZERO:
			_move(d)
	elif d != Vector2i.ZERO:
		hold_t -= delta
		if hold_t <= 0.0:
			hold_t = 0.11
			_move(d)

	if Input.is_action_just_pressed("sky_menu"):
		_toggle_panel()
	elif Input.is_action_just_pressed("sky_back"):
		if panel_open:
			_toggle_panel()
	elif Input.is_action_just_pressed("sky_accept"):
		if panel_open:
			_panel_choose()
		else:
			_activate()


func _move(d: Vector2i) -> void:
	if panel_open:
		if d.y != 0 and not panel_items.is_empty():
			panel_sel = wrapi(panel_sel + d.y, 0, panel_items.size())
			_play("tick")
		return
	if d.x != 0:
		var n: int = clamp(cat + d.x, 0, cats.size() - 1)
		if n != cat:
			cat = n
			item_smooth = float(_cur_item())
			_play("swoosh")
			_save_state()
	elif d.y != 0:
		var items: Array = cats[cat]["items"]
		var n: int = clamp(_cur_item() + d.y, 0, max(0, items.size() - 1))
		if n != _cur_item():
			item_sel[cats[cat]["id"]] = n
			_play("tick")
			_save_state()


func _cur_item() -> int:
	if cats.is_empty():
		return 0
	var items: Array = cats[cat]["items"]
	return clamp(int(item_sel.get(cats[cat]["id"], 0)), 0, max(0, items.size() - 1))


func _cur() -> Dictionary:
	if cats.is_empty():
		return {}
	var items: Array = cats[cat]["items"]
	if items.is_empty():
		return {}
	return items[_cur_item()]


# ---------------------------------------------------------------- jogos e categorias

func _reload_games() -> void:
	games.clear()
	for base in ["/opt/skystation/games", home_dir + "/skystation/games"]:
		var da := DirAccess.open(base)
		if da == null:
			continue
		for sub in da.get_directories():
			var g = _read_game(base + "/" + sub, sub)
			if g != null:
				games.append(g)
	_scan_roms()
	games.sort_custom(_game_less)
	_build_cats()


func _game_less(a: Dictionary, b: Dictionary) -> bool:
	if a["order"] != b["order"]:
		return a["order"] < b["order"]
	return str(a["title"]).naturalnocasecmp_to(str(b["title"])) < 0


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
		return null
	var g := {
		"id": fallback_name, "dir": gdir, "sys": "",
		"title": str(data.get("title", fallback_name)),
		"type": str(data.get("type", "linux")),
		"exec": cmd,
		"description": str(data.get("description", "")),
		"color": Color.from_string(str(data.get("color", "#4fd1ff")), Color("4fd1ff")),
		"order": int(data.get("order", 100)),
		"cover": null,
	}
	g["cover"] = _load_tex(gdir + "/" + str(data.get("cover", "cover.png")))
	return g


func _scan_roms() -> void:
	var tag_re := RegEx.new()
	tag_re.compile("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")  # tira "(USA)", "[SLUS-00594]" etc.
	var seen := {}
	for base in [home_dir + "/skystation/roms"] + ROM_BASES:
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
				var stem: String = f.get_basename()
				var key: String = sys_id + "/" + stem.to_lower()
				if seen.has(key):
					continue  # o mesmo jogo em duas pastas aparece uma vez só
				seen[key] = true
				var path: String = rdir + "/" + f
				var title: String = tag_re.sub(stem, "", true).strip_edges()
				if title == "":
					title = stem
				var where := "pendrive SKYROMS" if base == "/mnt/skyroms" else "armazenamento interno"
				var g := {
					"id": sys_id + "-" + stem.validate_filename().replace(" ", "_"),
					"dir": rdir, "sys": sys_id,
					"title": title, "type": "retro",
					"exec": "sky-emu %s %s" % [sys_id, _shq(path)],
					"description": "%s  ·  %s  ·  %s" % [info["name"], f.get_extension().to_upper(), where],
					"color": Color.from_string(info["color"], Color("4fd1ff")),
					"order": 50, "cover": null,
				}
				for cpath in [rdir + "/covers/" + stem + ".png", rdir + "/covers/" + stem + ".jpg",
						rdir + "/" + stem + ".png"]:
					var tex := _load_tex(cpath)
					if tex != null:
						g["cover"] = tex
						break
				games.append(g)


func _load_tex(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	if img.get_height() > 512:  # capas grandes: reduz para poupar memória de vídeo
		img.resize(int(img.get_width() * 512.0 / img.get_height()), 512, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _shq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"


func _game_item(g: Dictionary) -> Dictionary:
	var sub: String = TYPE_NAMES.get(g["type"], str(g["type"]))
	if g["sys"] != "":
		sub = ROM_SYSTEMS[g["sys"]]["name"]
	return {"title": g["title"], "sub": sub, "desc": g["description"], "kind": "game",
		"game": g, "color": g["color"], "cover": g["cover"], "glyph": ""}


func _act(title: String, sub: String, action: String, glyph: String, color: Color = Color(0, 0, 0, 0)) -> Dictionary:
	return {"title": title, "sub": sub, "desc": "", "kind": "action", "action": action,
		"glyph": glyph, "color": color, "cover": null}


func _build_cats() -> void:
	var c_sys := {"id": "sistema", "title": "Sistema", "icon": "gear", "items": []}
	var c_games := {"id": "jogos", "title": "Jogos", "icon": "pad", "items": []}
	var c_ps1 := {"id": "ps1", "title": "PS1", "icon": "disc1", "items": []}
	var c_ps2 := {"id": "ps2", "title": "PS2", "icon": "disc2", "items": []}
	var c_pc := {"id": "pc", "title": "PC", "icon": "monitor", "items": []}
	var c_apps := {"id": "apps", "title": "Apps", "icon": "apps", "items": []}
	var c_power := {"id": "energia", "title": "Energia", "icon": "power", "items": []}

	for g in games:
		var it := _game_item(g)
		match str(g["type"]):
			"retro":
				(c_ps2 if g["sys"] == "ps2" else c_ps1)["items"].append(it)
			"windows":
				c_pc["items"].append(it)
			"app", "ferramenta":
				c_apps["items"].append(it)
			_:
				c_games["items"].append(it)

	var hint_roms := "Copie para ~/skystation/roms/%s ou para o pendrive SKYROMS"
	if c_ps1["items"].is_empty():
		c_ps1["items"].append(_act("Nenhum jogo de PS1", hint_roms % "ps1", "", "disc"))
	if c_ps2["items"].is_empty():
		c_ps2["items"].append(_act("Nenhum jogo de PS2", hint_roms % "ps2", "", "disc"))
	if c_games["items"].is_empty():
		c_games["items"].append(_act("Nenhum jogo", "Pastas com game.json em ~/skystation/games", "", "pad"))

	c_sys["items"] = [
		_act("Wi-Fi", "Redes sem fio", "settings:0", "wifi"),
		_act("Bluetooth", "Parear controles e fones", "settings:1", "bt"),
		_act("Som", "Volume e mudo", "settings:2", "sound"),
		_act("Informações do sistema", "Hardware e versão", "settings:3", "info"),
		_act("Armazenamento", disk_txt, "storage", "drive"),
		_act("Tema de cores", _theme_name(), "theme", "palette"),
		_act("Sons da interface", "Ligados" if sounds_on else "Desligados", "sounds", "note"),
		_act("Medição de FPS", "Ligada: contador e log nos jogos" if _fps_on() else "Desligada", "fps", "gauge"),
		_act("Atualizar o SkyStation", ("Versão " + version_txt) if version_txt != "" else "Baixar a versão mais nova", "update", "refresh"),
	]
	# Desligar fica por último: um "A" sem querer ao entrar na categoria não desliga nada.
	c_power["items"] = [
		_act("Recarregar jogos", "Procura jogos e ROMs de novo", "reload", "search"),
		_act("Reiniciar a interface", "Reabre o SkyStation sem reiniciar", "restart_ui", "refresh"),
		_act("Reiniciar", "Reinicia o console", "reboot", "refresh"),
		_act("Desligar", "Desliga o console", "poweroff", "power"),
	]

	var old_id: String = cats[cat]["id"] if not cats.is_empty() and cat < cats.size() else "jogos"
	cats = [c_sys, c_games, c_ps1, c_ps2]
	if not c_pc["items"].is_empty():
		cats.append(c_pc)
	cats.append(c_apps)
	cats.append(c_power)
	cat = 1
	for i in cats.size():
		if cats[i]["id"] == old_id:
			cat = i
	if c_apps["items"].is_empty():
		cats.erase(c_apps)
		cat = min(cat, cats.size() - 1)
	cat_smooth = float(cat)
	item_smooth = float(_cur_item())


func _refresh_sys_items() -> void:
	# Atualiza só os textos dinâmicos da categoria Sistema (sem perder a posição).
	for c in cats:
		if c["id"] != "sistema":
			continue
		for it in c["items"]:
			match str(it.get("action", "")):
				"storage":
					it["sub"] = disk_txt
				"theme":
					it["sub"] = _theme_name()
				"sounds":
					it["sub"] = "Ligados" if sounds_on else "Desligados"
				"fps":
					it["sub"] = "Ligada: contador e log nos jogos" if _fps_on() else "Desligada"


# ---------------------------------------------------------------- ações

func _activate() -> void:
	var it := _cur()
	if it.is_empty():
		return
	if it["kind"] == "game":
		_play("accept")
		_launch(it["game"])
		return
	var action: String = str(it.get("action", ""))
	if action == "":
		_play("back")
		return
	_play("accept")
	if action.begins_with("settings:"):
		_open_settings(int(action.split(":")[1]))
		return
	match action:
		"storage":
			_refresh_status()
			_toast("Livre: " + disk_txt)
		"theme":
			var i := THEME_ORDER.find(theme_key)
			theme_key = THEME_ORDER[(i + 1) % THEME_ORDER.size()]
			_write_text(conf_dir + "/tema", theme_key)
			_apply_theme(false)
		"sounds":
			sounds_on = not sounds_on
			if sounds_on:
				DirAccess.remove_absolute(conf_dir + "/sons.off")
				_play("accept")
			else:
				_write_text(conf_dir + "/sons.off", "1")
		"fps":
			_toggle_fps()
		"update":
			_start_update()
		"reload":
			_reload_games()
			_toast("%d jogo(s) encontrado(s)" % games.size())
		"restart_ui":
			busy_msg = "Reabrindo o SkyStation…"
			quit_at = t + 0.8
		"reboot":
			busy_msg = "Reiniciando…"
			OS.execute("systemctl", ["reboot"])
		"poweroff":
			busy_msg = "Desligando…"
			OS.execute("systemctl", ["poweroff"])
	_refresh_sys_items()


func _launch(g: Dictionary) -> void:
	var pid: int
	if FileAccess.file_exists("/opt/skystation/bin/sky-run"):
		pid = OS.create_process("/opt/skystation/bin/sky-run", [g["dir"], g["exec"], g["id"], g["title"]])
	else:
		pid = OS.create_process("/bin/sh", ["-c", "cd \"%s\" && exec %s" % [g["dir"], g["exec"]]])
	if pid <= 0:
		_toast("Não consegui abrir " + str(g["title"]))
		return
	running_pid = pid
	running_title = g["title"]
	busy_msg = "Abrindo %s…" % running_title
	queue_redraw()
	# Enquanto o jogo roda: sem redesenho, no máximo 4 checagens por segundo.
	OS.low_processor_usage_mode = true
	Engine.max_fps = 4
	bg.visible = false


func _on_game_closed() -> void:
	running_pid = -1
	busy_msg = ""
	bg.visible = true
	OS.low_processor_usage_mode = false
	Engine.max_fps = 30 if low_gfx else 0
	_report_exit()
	cooldown = 0.5
	hold_dir = _nav_dir()
	_refresh_status()


func _report_exit() -> void:
	var msg := _read_text(run_dir + "/last_msg", "")
	var code := _read_text(run_dir + "/last_exit", "-1").to_int()
	if msg != "":
		_toast(msg, 6.0)
	elif code == 143 or code == 137:
		_toast("Jogo fechado pelo botão Home")
	elif code > 0:
		_toast("O jogo fechou com erro (código %d)" % code, 5.0)


func _open_settings(section: int = -1) -> void:
	if settings == null:
		var script = load("res://settings.gd")
		if script == null or not script.can_instantiate():
			_toast("Configurações indisponíveis (erro no script)", 4.0)
			return
		settings = script.new()
		settings.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(settings)
		settings.closed.connect(_on_settings_closed)
	settings.set("CYAN", accent)  # Configurações na mesma cor de destaque do tema
	settings.open(section)


func _on_settings_closed() -> void:
	cooldown = 0.35
	hold_dir = _nav_dir()
	_play("back")


func _fps_on() -> bool:
	return FileAccess.file_exists(conf_dir + "/mangohud.on")


func _toggle_fps() -> void:
	if _fps_on():
		DirAccess.remove_absolute(conf_dir + "/mangohud.on")
		_toast("Medição de FPS desligada")
	else:
		_write_text(conf_dir + "/mangohud.on", "1")
		_toast("Medição de FPS ligada: contador na tela + log em ~/skystation/benchmarks")


func _start_update() -> void:
	if busy_thread != null:
		return
	busy_msg = "Baixando a versão mais nova do SkyStation…"
	busy_thread = Thread.new()
	busy_thread.start(_update_worker)


func _update_worker() -> void:
	var out: Array = []
	var code := OS.execute("sudo", ["-n", "/usr/local/bin/skystation-atualizar", "--github"], out, true)
	call_deferred("_update_done", code, "\n".join(out))


func _update_done(code: int, out: String) -> void:
	busy_thread.wait_to_finish()
	busy_thread = null
	if code == 0:
		busy_msg = "Atualizado! Reabrindo o SkyStation…"
		quit_at = t + 2.0
		_play("chime")
	else:
		busy_msg = ""
		var line := ""
		for l in out.split("\n"):
			if l.strip_edges() != "":
				line = l.strip_edges()
		if out.contains("password") or out.contains("senha") or code == 1 and line == "":
			line = "Falta permissão: rode a Fase 5.5 uma vez pelo terminal"
		_toast("Não foi possível atualizar: " + line, 7.0)


# ---------------------------------------------------------------- painel de opções (Y / Start)

func _toggle_panel() -> void:
	panel_open = not panel_open
	if panel_open:
		var it := _cur()
		panel_items = []
		if it.get("kind", "") == "game":
			panel_items.append(["Jogar", "play"])
		panel_items.append(["Medição de FPS: " + ("ligada" if _fps_on() else "desligada"), "fps"])
		panel_items.append(["Tema: " + _theme_name(), "theme"])
		panel_items.append(["Recarregar jogos", "reload"])
		panel_items.append(["Configurações", "settings"])
		panel_items.append(["Fechar", "close"])
		panel_sel = 0
		_play("accept")
	else:
		_play("back")


func _panel_choose() -> void:
	var a: String = panel_items[panel_sel][1]
	panel_open = false
	match a:
		"play":
			_activate()
		"fps":
			_toggle_fps()
			_refresh_sys_items()
		"theme":
			var i := THEME_ORDER.find(theme_key)
			theme_key = THEME_ORDER[(i + 1) % THEME_ORDER.size()]
			_write_text(conf_dir + "/tema", theme_key)
			_apply_theme(false)
			_refresh_sys_items()
		"reload":
			_reload_games()
			_toast("%d jogo(s) encontrado(s)" % games.size())
		"settings":
			_open_settings(-1)
		_:
			_play("back")


# ---------------------------------------------------------------- tema, status, estado

func _theme_name() -> String:
	if theme_key == "auto":
		return "Automático (" + str(THEMES[_auto_theme()][0]) + ")"
	return str(THEMES[theme_key][0])


func _auto_theme() -> String:
	var h: int = Time.get_datetime_dict_from_system()["hour"]
	if h >= 6 and h < 11:
		return "oceano"
	if h >= 11 and h < 17:
		return "aurora"
	if h >= 17 and h < 20:
		return "crepusculo"
	return "noite"


func _apply_theme(instant: bool) -> void:
	var key := _auto_theme() if theme_key == "auto" else theme_key
	palette = THEMES[key]
	accent = palette[4]
	bg_mat.set_shader_parameter("col_top", palette[1])
	bg_mat.set_shader_parameter("col_bot", palette[2])
	bg_mat.set_shader_parameter("wave_col", palette[3])
	if not instant:
		_toast("Tema: " + _theme_name())


func _refresh_status() -> void:
	status_t = 5.0
	pads = Input.get_connected_joypads().size()
	wifi_q = -1
	var wl := _read_text("/proc/net/wireless", "")
	for line in wl.split("\n"):
		if line.contains(":") and not line.contains("|"):
			var parts := line.split(" ", false)
			if parts.size() > 2:
				wifi_q = int(parts[2].replace(".", ""))
	var out: Array = []
	if OS.execute("df", ["-B1", "--output=avail,size", home_dir], out, false) == 0 and out.size() > 0:
		var lines: PackedStringArray = str(out[0]).strip_edges().split("\n")
		if lines.size() >= 2:
			var nums := lines[1].split(" ", false)
			if nums.size() >= 2:
				disk_txt = "%.1f GB livres de %.1f GB" % [float(nums[0]) / 1e9, float(nums[1]) / 1e9]
	var present := DirAccess.dir_exists_absolute("/mnt/skyroms/ps1") or DirAccess.dir_exists_absolute("/mnt/skyroms/ps2")
	if present != skyroms_present:
		skyroms_present = present
		if not cats.is_empty():
			_reload_games()
			_toast("Pendrive de jogos conectado" if present else "Pendrive de jogos removido")
	if theme_key == "auto" and not palette.is_empty() and palette != THEMES[_auto_theme()]:
		_apply_theme(true)
	_refresh_sys_items()


func _load_state() -> void:
	var data = JSON.parse_string(_read_text(conf_dir + "/ui.json", "{}"))
	if typeof(data) == TYPE_DICTIONARY:
		var sel = data.get("items", {})
		if typeof(sel) == TYPE_DICTIONARY:
			item_sel = sel
		var last := str(data.get("cat", "jogos"))
		cats = [{"id": last, "items": []}]  # o _build_cats procura esta categoria
		cat = 0


func _save_state() -> void:
	_write_text(conf_dir + "/ui.json", JSON.stringify({"cat": cats[cat]["id"], "items": item_sel}))


func _read_text(path: String, default: String) -> String:
	if not FileAccess.file_exists(path):
		return default
	return FileAccess.get_file_as_string(path).strip_edges()


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
		f.close()


func _toast(msg: String, seconds: float = 2.8) -> void:
	toast_msg = msg
	toast_t = seconds


# ---------------------------------------------------------------- sons (sintetizados)

func _make_sounds() -> void:
	sfx["tick"] = _synth([[1975.0, 1.0], [3950.0, 0.25]], 0.07, 0.002, 0.018, 0.22)
	sfx["swoosh"] = _synth([[740.0, 1.0], [1480.0, 0.35], [1110.0, 0.4]], 0.12, 0.004, 0.04, 0.2)
	sfx["accept"] = _synth_seq([[988.0, 0.0], [1480.0, 0.06]], 0.22, 0.25)
	sfx["back"] = _synth_seq([[1175.0, 0.0], [784.0, 0.06]], 0.2, 0.2)
	sfx["chime"] = _chime()
	for k in sfx:
		var p := AudioStreamPlayer.new()
		p.stream = sfx[k]
		p.volume_db = -2.0 if k == "chime" else -9.0
		add_child(p)
		players[k] = p


func _play(key: String) -> void:
	if not sounds_on or not players.has(key):
		return
	var p: AudioStreamPlayer = players[key]
	p.play()


func _pcm(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.stereo = false
	st.data = data
	return st


func _synth(partials: Array, dur: float, attack: float, decay: float, vol: float) -> AudioStreamWAV:
	var rate := 32000
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var tt := float(i) / rate
		var env: float = min(1.0, tt / attack) * exp(-tt / decay)
		var v := 0.0
		for p in partials:
			v += sin(TAU * float(p[0]) * tt) * float(p[1])
		s[i] = v * env * vol
	return _pcm(s, rate)


func _synth_seq(notes: Array, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 32000
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	for note in notes:
		var f: float = note[0]
		var start := int(float(note[1]) * rate)
		for i in range(start, n):
			var tt := float(i - start) / rate
			var env: float = min(1.0, tt / 0.004) * exp(-tt / 0.05)
			s[i] += (sin(TAU * f * tt) + 0.3 * sin(TAU * f * 2.0 * tt)) * env * vol
	return _pcm(s, rate)


func _chime() -> AudioStreamWAV:
	# Acorde de abertura do SkyStation (original): Lá maior com nona, notas entrando em cascata,
	# ataque suave e um eco curto. ~2,6 s.
	var rate := 22050
	var dur := 2.6
	var n := int(dur * rate)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes := [[220.0, 0.00, 0.30], [329.63, 0.08, 0.22], [440.0, 0.16, 0.20],
		[554.37, 0.26, 0.17], [659.25, 0.36, 0.15], [987.77, 0.50, 0.10], [1318.5, 0.62, 0.06]]
	for note in notes:
		var f: float = note[0]
		var start := int(float(note[1]) * rate)
		var amp: float = note[2]
		for i in range(start, n):
			var tt := float(i - start) / rate
			var env: float = min(1.0, tt / 0.12) * exp(-tt / 1.1)
			var v := sin(TAU * f * tt) + 0.25 * sin(TAU * f * 2.0 * tt + 0.3) + 0.08 * sin(TAU * f * 3.0 * tt)
			v *= 1.0 + 0.06 * sin(TAU * 5.0 * tt)  # vibrato leve
			s[i] += v * env * amp
	var d1 := int(0.19 * rate)
	for i in range(n - 1, d1 - 1, -1):  # eco
		s[i] += s[i - d1] * 0.28
	for i in n:
		var fade: float = min(1.0, float(n - i) / (0.3 * rate))
		s[i] = tanh(s[i] * 0.9) * 0.55 * fade
	return _pcm(s, rate)


# ---------------------------------------------------------------- desenho

func _make_glow() -> void:
	# Brilho radial macio (curva gaussiana), usado no halo da logo e da categoria.
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in 9:
		var x := float(i) / 8.0
		offs.append(x)
		cols.append(Color(1, 1, 1, exp(-x * x * 4.5) * (1.0 - x)))
	g.offsets = offs
	g.colors = cols
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 256
	glow_tex.height = 256
	# degradê do painel lateral (transparente → escuro), sem faixas
	var g2 := Gradient.new()
	g2.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g2.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.92)])
	side_tex = GradientTexture2D.new()
	side_tex.gradient = g2
	side_tex.width = 256
	side_tex.height = 4


func _glow(c: Vector2, radius: float, col: Color) -> void:
	draw_texture_rect(glow_tex, Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


func _sb(key: String, col: Color, radius: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var k := "%s|%s|%d|%s|%d" % [key, col.to_html(), radius, border.to_html(), bw]
	if styles.has(k):
		return styles[k]
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if styles.size() > 400:
		styles.clear()
	styles[k] = s
	return s


func _rrect(r: Rect2, col: Color, radius: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	draw_style_box(_sb("r", col, radius, border, bw), r)


func _text(s: String, pos: Vector2, fsize: int, col: Color, bold: bool = false, width: float = -1.0,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := font_bold if bold else font
	if width > 0.0:
		draw_string(f, pos, s, align, width, fsize, col, TextServer.JUSTIFICATION_NONE)
	else:
		draw_string(f, pos, s, align, -1, fsize, col)


func _text_shadow(s: String, pos: Vector2, fsize: int, col: Color, bold: bool = false, width: float = -1.0,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_text(s, pos + Vector2(0, 2), fsize, Color(0, 0, 0, col.a * 0.45), bold, width, align)
	_text(s, pos, fsize, col, bold, width, align)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if running_pid != -1:
		draw_rect(Rect2(Vector2.ZERO, size), Color(palette[1] if not palette.is_empty() else Color.BLACK))
		_draw_busy(w, h)
		return
	_draw_intro(w, h)
	if ui_alpha <= 0.0:
		return
	if settings != null and settings.visible:
		return  # Configurações abertas: só o fundo de ondas fica atrás delas
	var a := ui_alpha
	_draw_header(w, h, a)
	_draw_xmb(w, h, a)
	_draw_footer(w, h, a)
	if panel_t > 0.0:
		_draw_panel(w, h)
	if toast_t > 0.0:
		var ta: float = clamp(toast_t, 0.0, 1.0) * a
		var tw := font.get_string_size(toast_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 48.0
		var r := Rect2((w - tw) / 2.0, h - 112, tw, 42)
		_rrect(r, Color(0, 0, 0, 0.55 * ta), 21, Color(accent, 0.5 * ta), 1)
		_text(toast_msg, Vector2(r.position.x + 24, r.position.y + 28), 18, Color(WHITE, ta))
	if busy_msg != "":
		_draw_busy(w, h)


func _draw_intro(w: float, h: float) -> void:
	if intro_t >= INTRO_LEN:
		return
	# Continua a tela de boot: mesma logo, mesmo lugar e tamanho em pixels. O fundo de ondas do
	# launcher aparece por trás (0 → 0,9 s), a logo brilha, e depois sobe e some (2,2 → 3,0 s)
	# enquanto a barra de categorias entra.
	var leave: float = clamp((intro_t - 2.2) / 0.8, 0.0, 1.0)
	var e_out := leave * leave * (3.0 - 2.0 * leave)
	var reveal: float = clamp(intro_t / 0.9, 0.0, 1.0)
	var px: float = size.y / max(1.0, float(DisplayServer.window_get_size().y))  # unidades por pixel real
	var center := Vector2(w / 2.0, h / 2.0 - 20.0 * px)
	center.y -= e_out * h * 0.18
	var la := 1.0 - e_out
	# fundo da tela de boot sumindo
	draw_rect(Rect2(0, 0, w, h), Color(Color("040817"), 1.0 - reveal))
	if la <= 0.0:
		return
	var pulse := 0.85 + 0.15 * sin(intro_t * 3.0)
	var flash: float = clamp(1.0 - absf(intro_t - 1.2) / 0.4, 0.0, 1.0)  # lampejo quando o acorde toca
	_glow(center, 420.0, Color(accent, (0.20 * pulse + 0.18 * flash) * la))
	if logo_tex != null:
		var lsize := logo_tex.get_size() * px * (1.0 - 0.25 * e_out)
		var r := Rect2(center - lsize / 2.0, lsize)
		draw_texture_rect(logo_tex, r, false, Color(1, 1, 1, la))
		if flash > 0.0:
			draw_texture_rect(logo_tex, r, false, Color(1.4, 1.4, 1.4, 0.35 * flash * la))
	else:
		var big := 64
		var sky_w := font_bold.get_string_size("Sky", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		var sta_w := font_bold.get_string_size("Station", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		var x0 := center.x - (sky_w + sta_w) / 2.0
		_text("Sky", Vector2(x0, center.y + 22), big, Color(WHITE, la), true)
		_text("Station", Vector2(x0 + sky_w, center.y + 22), big, Color(accent, la), true)
	var tag_a: float = clamp((intro_t - 0.9) / 0.6, 0.0, 1.0) * la
	_text("seu console, do seu jeito", Vector2(0, center.y + 92.0 * px), 19, Color(MUTED, tag_a), false, w,
		HORIZONTAL_ALIGNMENT_CENTER)


func _draw_header(w: float, _h: float, a: float) -> void:
	_text_shadow("Sky", Vector2(52, 58), 26, Color(WHITE, a), true)
	var sw := font_bold.get_string_size("Sky", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_text_shadow("Station", Vector2(52 + sw, 58), 26, Color(accent, a), true)

	var dt := Time.get_datetime_dict_from_system()
	var clock := "%02d:%02d" % [dt["hour"], dt["minute"]]
	var date := "%s, %d de %s" % [WEEKDAYS[dt["weekday"]], dt["day"], MONTHS[dt["month"] - 1]]
	var cw := font_bold.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_text_shadow(clock, Vector2(w - 56 - cw, 60), 30, Color(WHITE, a), true)
	var dw := font.get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(date, Vector2(w - 56 - dw, 82), 15, Color(MUTED, a))

	# status: controles e Wi-Fi
	var x := w - 70.0 - maxf(cw, dw) - 30.0
	if pads > 0:
		_icon("pad", Vector2(x, 50), 30.0, Color(WHITE, 0.85 * a))
		if pads > 1:
			_text(str(pads), Vector2(x + 14, 66), 13, Color(accent, a), true)
		x -= 46.0
	if wifi_q >= 0:
		var bars: int = 1 + int(clamp(wifi_q, 0, 70) / 18)
		for i in 4:
			var bh := 6.0 + i * 5.0
			var col := Color(WHITE, 0.9 * a) if i < bars else Color(WHITE, 0.25 * a)
			draw_rect(Rect2(x - 12 + i * 7, 62 - bh, 5, bh), col)


func _cat_x(i: float, w: float) -> float:
	var anchor := w * 0.25
	var gap: float = clamp(w * 0.115, 130.0, 190.0)
	return anchor + (i - cat_smooth) * gap


func _draw_xmb(w: float, h: float, a: float) -> void:
	var bar_y: float = h * 0.30
	var anchor := w * 0.25

	# categorias
	for i in cats.size():
		var x := _cat_x(float(i), w)
		if x < -100 or x > w + 100:
			continue
		var dist: float = abs(float(i) - cat_smooth)
		var on: float = clamp(1.0 - dist, 0.0, 1.0)
		var s := 46.0 + 22.0 * on
		var ca := a * (0.45 + 0.55 * on) * clampf(1.4 - dist * 0.25, 0.0, 1.0)
		if on > 0.3:
			_glow(Vector2(x, bar_y), 90.0, Color(palette[3], 0.30 * on * a))
		_icon(str(cats[i]["icon"]), Vector2(x, bar_y), s, Color(WHITE, ca))
		if on > 0.05:
			var title: String = cats[i]["title"]
			_text_shadow(title, Vector2(x - 120, bar_y + s / 2.0 + 30), 18, Color(WHITE, on * a), true, 240,
				HORIZONTAL_ALIGNMENT_CENTER)

	if cats.is_empty():
		return
	var items: Array = cats[cat]["items"]
	var cur := _cur_item()
	var col_x := anchor
	var sel_y := bar_y + 128.0
	for j in items.size():
		var off := float(j) - item_smooth
		var y: float
		if off < -0.5:
			y = bar_y - 92.0 + (off + 1.0) * 74.0      # itens acima da barra (já passados)
		elif off <= 0.5:
			y = sel_y + off * 160.0
		else:
			y = sel_y + 120.0 + (off - 1.0) * 74.0
		if y < -60.0 or y > h + 60.0:
			continue
		var sel: float = clamp(1.0 - abs(off) * 1.6, 0.0, 1.0)
		var ia := a * (0.5 + 0.5 * sel)
		if off < -0.5:
			ia = a * 0.35
		ia *= clampf((h - 90.0 - y) / 70.0, 0.0, 1.0)  # some suavemente perto do rodapé
		_draw_item(items[j], Vector2(col_x, y), sel, ia, j == cur)


func _draw_item(it: Dictionary, c: Vector2, sel: float, a: float, is_cur: bool) -> void:
	var game: bool = it["kind"] == "game"
	var ih := 58.0 + 46.0 * sel if game else 44.0 + 22.0 * sel
	var iw := ih * 0.75 if game else ih
	var r := Rect2(c.x - iw / 2.0, c.y - ih / 2.0, iw, ih)
	var col: Color = it["color"]
	if col.a == 0.0:
		col = accent
	if game:
		if sel > 0.5:  # brilho atrás do item selecionado
			_glow(c, ih * 1.25, Color(col.lightened(0.2), 0.9 * sel * a))
		var cover: Texture2D = it["cover"]
		if cover != null:
			_rrect(r.grow(2), Color(0, 0, 0, 0.5 * a), 10)
			_draw_cover(cover, r, a)
			_rrect(r, Color(0, 0, 0, 0), 9, Color(1, 1, 1, 0.22 * a + 0.4 * sel * a), 2 if sel > 0.5 else 1)
		else:
			_rrect(r, Color(col.darkened(0.45), 0.92 * a), 10, Color(col.lightened(0.2), 0.7 * a), 2)
			var ini := ""
			for word in str(it["title"]).split(" ", false).slice(0, 2):
				ini += word.substr(0, 1).to_upper()
			var fs := int(ih * 0.32)
			_text(ini, Vector2(r.position.x, c.y + fs * 0.35), fs, Color(col.lightened(0.45), a), true, iw,
				HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_icon(str(it["glyph"]), c, ih * 0.72, Color(WHITE, a))

	var tx := c.x + maxf(iw, 66.0) / 2.0 + 26.0
	var ts := int(20 + 8 * sel)
	_text_shadow(str(it["title"]), Vector2(tx, c.y + (ts * 0.35 if sel < 0.5 else -4.0)), ts,
		Color(WHITE, a), sel > 0.5, size.x - tx - 60)
	if sel > 0.5 and str(it["sub"]) != "":
		_text(str(it["sub"]), Vector2(tx, c.y + 24), 16, Color(accent.lightened(0.25), a * sel))
	if is_cur and sel > 0.8 and str(it.get("desc", "")) != "" and it["kind"] == "game":
		_text(str(it["desc"]), Vector2(tx, c.y + 50), 15, Color(MUTED, a * sel), false, size.x - tx - 80)


func _draw_cover(tex: Texture2D, r: Rect2, a: float) -> void:
	# recorta a capa para caber no retângulo sem distorcer ("cover")
	var ts := tex.get_size()
	var target := r.size.x / r.size.y
	var src := Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y > target:
		var nw := ts.y * target
		src = Rect2((ts.x - nw) / 2.0, 0, nw, ts.y)
	else:
		var nh := ts.x / target
		src = Rect2(0, (ts.y - nh) / 2.0, ts.x, nh)
	draw_texture_rect_region(tex, r.grow(-1), src, Color(1, 1, 1, a))


func _draw_footer(w: float, h: float, a: float) -> void:
	var hints := [["A", "Abrir"], ["B", "Voltar"], ["Y", "Opções"]]
	var x := w - 60.0
	for i in range(hints.size() - 1, -1, -1):
		var label: String = hints[i][1]
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		x -= lw
		_text(label, Vector2(x, h - 40), 15, Color(MUTED, a))
		x -= 30.0
		draw_circle(Vector2(x + 11, h - 45), 11.0, Color(WHITE, 0.16 * a))
		_text(str(hints[i][0]), Vector2(x, h - 40), 13, Color(WHITE, 0.9 * a), true, 22, HORIZONTAL_ALIGNMENT_CENTER)
		x -= 26.0
	if skyroms_present:
		_icon("drive", Vector2(64, h - 46), 22.0, Color(accent, 0.8 * a))
		_text("Pendrive de jogos conectado", Vector2(86, h - 40), 14, Color(MUTED, a))


func _draw_panel(w: float, h: float) -> void:
	var e := panel_t * panel_t * (3.0 - 2.0 * panel_t)
	var pw := 380.0
	var x := w - pw * e
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35 * e))
	draw_texture_rect(side_tex, Rect2(x, 0, pw, h), false, Color(palette[1].darkened(0.35), e))
	draw_line(Vector2(x, 0), Vector2(x, h), Color(accent, 0.35 * e), 1.0)
	var y0 := h * 0.30
	for i in panel_items.size():
		var y := y0 + i * 54.0
		var on := i == panel_sel
		if on:
			_rrect(Rect2(x + 22, y - 32, pw - 44, 46), Color(accent, 0.16 * e), 10, Color(accent, 0.5 * e), 1)
		_text(str(panel_items[i][0]), Vector2(x + 44, y), 20, Color(WHITE if on else MUTED, e), on)


func _draw_busy(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	var c := Vector2(w / 2.0, h / 2.0 - 30)
	for i in 10:
		var ang := t * 4.0 + i * TAU / 10.0
		draw_circle(c + Vector2(cos(ang), sin(ang)) * 26.0, 4.0, Color(accent, float(i + 1) / 10.0))
	_text(busy_msg, Vector2(0, c.y + 72), 22, WHITE, false, w, HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------- ícones vetoriais (originais)

func _icon(kind: String, c: Vector2, s: float, col: Color) -> void:
	var lw: float = max(2.0, s * 0.07)
	match kind:
		"gear":
			for i in 8:
				var ang := i * TAU / 8.0
				var dir := Vector2(cos(ang), sin(ang))
				var p1 := c + dir * s * 0.30
				var p2 := c + dir * s * 0.46
				draw_line(p1, p2, col, s * 0.16, true)
			draw_circle(c, s * 0.34, col, true, -1.0, true)
			draw_circle(c, s * 0.15, Color(palette[1], 1.0) if not palette.is_empty() else Color.BLACK, true, -1.0, true)
		"pad":
			var body := Rect2(c.x - s * 0.46, c.y - s * 0.22, s * 0.92, s * 0.44)
			_rrect(body, col, int(s * 0.2))
			draw_circle(c + Vector2(-s * 0.30, s * 0.16), s * 0.17, col, true, -1.0, true)
			draw_circle(c + Vector2(s * 0.30, s * 0.16), s * 0.17, col, true, -1.0, true)
			var hole := Color(palette[1], 1.0) if not palette.is_empty() else Color.BLACK
			draw_rect(Rect2(c.x - s * 0.33, c.y - s * 0.03, s * 0.16, s * 0.05), hole)
			draw_rect(Rect2(c.x - s * 0.275, c.y - s * 0.085, s * 0.05, s * 0.16), hole)
			for o in [Vector2(0.25, -0.05), Vector2(0.33, 0.02), Vector2(0.17, 0.02), Vector2(0.25, 0.09)]:
				draw_circle(c + o * s, s * 0.035, hole, true, -1.0, true)
		"disc", "disc1", "disc2":
			draw_arc(c, s * 0.42, 0, TAU, 64, col, lw, true)
			draw_arc(c, s * 0.30, -0.6, 0.9, 24, Color(col, col.a * 0.45), lw * 0.6, true)
			draw_circle(c, s * 0.10, col, false, lw * 0.8, true)
			if kind != "disc":
				var n := "1" if kind == "disc1" else "2"
				draw_circle(c + Vector2(s * 0.30, s * 0.30), s * 0.17, col, true, -1.0, true)
				_text(n, Vector2(c.x + s * 0.30 - s * 0.17, c.y + s * 0.30 + s * 0.09), int(s * 0.24),
					Color(palette[1], 1.0) if not palette.is_empty() else Color.BLACK, true, s * 0.34,
					HORIZONTAL_ALIGNMENT_CENTER)
		"monitor":
			_rrect(Rect2(c.x - s * 0.42, c.y - s * 0.32, s * 0.84, s * 0.52), Color(0, 0, 0, 0), 4, col, int(lw))
			draw_line(c + Vector2(0, s * 0.2), c + Vector2(0, s * 0.34), col, lw)
			draw_line(c + Vector2(-s * 0.18, s * 0.36), c + Vector2(s * 0.18, s * 0.36), col, lw, true)
		"apps":
			for ix in 2:
				for iy in 2:
					_rrect(Rect2(c.x - s * 0.36 + ix * s * 0.40, c.y - s * 0.36 + iy * s * 0.40, s * 0.32, s * 0.32),
						col, int(s * 0.08))
		"power":
			draw_arc(c, s * 0.34, -PI / 2.0 + 0.62, PI * 1.5 - 0.62, 48, col, lw * 1.2, true)
			draw_line(c + Vector2(0, -s * 0.44), c + Vector2(0, -s * 0.06), col, lw * 1.2, true)
		"wifi":
			for i in 3:
				draw_arc(c + Vector2(0, s * 0.22), s * (0.18 + i * 0.15), -PI * 0.78, -PI * 0.22, 24, col, lw, true)
			draw_circle(c + Vector2(0, s * 0.22), s * 0.06, col, true, -1.0, true)
		"bt":
			var pts := PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.18), c + Vector2(s * 0.2, s * 0.16),
				c + Vector2(0, s * 0.36), c + Vector2(0, -s * 0.36), c + Vector2(s * 0.2, -s * 0.16),
				c + Vector2(-s * 0.2, s * 0.18)])
			draw_polyline(pts, col, lw, true)
		"sound":
			var sp := PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.12), c + Vector2(-s * 0.2, -s * 0.12),
				c + Vector2(0, -s * 0.32), c + Vector2(0, s * 0.32), c + Vector2(-s * 0.2, s * 0.12),
				c + Vector2(-s * 0.36, s * 0.12)])
			draw_colored_polygon(sp, col)
			draw_arc(c + Vector2(s * 0.04, 0), s * 0.18, -0.9, 0.9, 16, col, lw, true)
			draw_arc(c + Vector2(s * 0.04, 0), s * 0.32, -0.9, 0.9, 16, col, lw, true)
		"info":
			draw_arc(c, s * 0.40, 0, TAU, 48, col, lw, true)
			draw_circle(c + Vector2(0, -s * 0.18), s * 0.05, col, true, -1.0, true)
			draw_line(c + Vector2(0, -s * 0.06), c + Vector2(0, s * 0.22), col, lw * 1.2, true)
		"drive":
			_rrect(Rect2(c.x - s * 0.42, c.y - s * 0.2, s * 0.84, s * 0.4), Color(0, 0, 0, 0), int(s * 0.08), col, int(lw))
			draw_circle(c + Vector2(s * 0.26, 0), s * 0.05, col, true, -1.0, true)
			draw_line(c + Vector2(-s * 0.28, 0), c + Vector2(s * 0.06, 0), col, lw, true)
		"palette":
			draw_arc(c, s * 0.40, 0, TAU, 48, col, lw, true)
			var cols := [Color("ff7ad0"), Color("54f0b8"), Color("5fdcff"), Color("ff9a52")]
			for i in 4:
				var ang := -PI * 0.75 + i * PI * 0.42
				draw_circle(c + Vector2(cos(ang), sin(ang)) * s * 0.22, s * 0.08, Color(cols[i], col.a), true, -1.0, true)
		"note":
			draw_circle(c + Vector2(-s * 0.14, s * 0.22), s * 0.12, col, true, -1.0, true)
			draw_line(c + Vector2(-s * 0.03, s * 0.22), c + Vector2(-s * 0.03, -s * 0.34), col, lw, true)
			draw_line(c + Vector2(-s * 0.03, -s * 0.34), c + Vector2(s * 0.22, -s * 0.22), col, lw, true)
		"gauge":
			draw_arc(c + Vector2(0, s * 0.1), s * 0.38, PI, TAU, 32, col, lw, true)
			draw_line(c + Vector2(0, s * 0.1), c + Vector2(s * 0.2, -s * 0.16), col, lw, true)
			draw_circle(c + Vector2(0, s * 0.1), s * 0.06, col, true, -1.0, true)
		"refresh":
			draw_arc(c, s * 0.34, -PI * 0.35, PI * 1.45, 40, col, lw * 1.1, true)
			var tip := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * s * 0.34
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.02, -s * 0.15),
				tip + Vector2(s * 0.14, s * 0.04), tip + Vector2(-s * 0.13, s * 0.06)]), col)
		"search":
			draw_arc(c + Vector2(-s * 0.06, -s * 0.06), s * 0.24, 0, TAU, 32, col, lw, true)
			draw_line(c + Vector2(s * 0.12, s * 0.12), c + Vector2(s * 0.34, s * 0.34), col, lw * 1.3, true)
		_:
			draw_circle(c, s * 0.3, col, false, lw, true)
