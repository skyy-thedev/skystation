extends Control
## SkyStation Launcher — interface "barra cruzada" (Fase 5.5 + 5.6)
##
## Categorias na horizontal (Sistema, Jogos, PS1, PS2, Apps, Energia) e itens na vertical,
## sobre um fundo de ondas animado por shader. Tudo é desenhado em _draw (leve: um nó só
## para a interface inteira) e os sons são sintetizados na hora (nenhum arquivo de áudio).
##
## Jogos: /opt/skystation/games e ~/skystation/games (uma pasta por jogo, com game.json).
## ROMs:  ~/skystation/roms/<sistema>, /mnt/skystation/roms/<sistema> (VM) e
##        /mnt/skyroms/<sistema> (pendrive de jogos com o rótulo SKYROMS, ou a pasta SKYROMS
##        do HD/SSD do PC — Fase 7.6, montada pelo skystation-skyroms-hd).
##
## Fase 5.6: bateria (console e controles), avisos do sky-notify, brilho e volume, saída de som,
## descanso de tela, capas automáticas, tempo de jogo + Recentes, Capturas, aviso de nova versão,
## música ambiente e modo econômico na bateria.

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
	"ps3": {"badge": "PS3", "name": "PlayStation 3", "color": "#e8eefc", "exts": []},   # lista vem do sky-ps3
	"psp": {"badge": "PSP", "name": "PlayStation Portable", "color": "#9aa7c7",
		"exts": ["iso", "cso"]},
	"snes": {"badge": "SNES", "name": "Super Nintendo", "color": "#b06cf0",
		"exts": ["sfc", "smc"]},
	"n64": {"badge": "N64", "name": "Nintendo 64", "color": "#3fbf6b",
		"exts": ["z64", "n64", "v64"]},
	# Fase 7.1
	"gc": {"badge": "GC", "name": "GameCube", "color": "#7b68ee", "icon": "discG", "exts": ["iso", "gcm", "rvz", "gcz", "ciso"]},
	"wii": {"badge": "Wii", "name": "Nintendo Wii", "color": "#7fd4ff", "icon": "discW", "exts": ["iso", "wbfs", "rvz", "gcz", "ciso", "wad"]},
	"x360": {"badge": "360", "name": "Xbox 360 (experimental)", "color": "#8fd14f", "icon": "discX", "exts": ["iso", "zar", "xex"]},
	"nds": {"badge": "DS", "name": "Nintendo DS", "color": "#c9d2e6", "icon": "cartD", "exts": ["nds", "dsi"]},
	"3ds": {"badge": "3DS", "name": "Nintendo 3DS", "color": "#ff6b6b", "icon": "cart3", "exts": ["3ds", "cci", "cxi", "3dsx"]},
	"gba": {"badge": "GBA", "name": "Game Boy Advance", "color": "#9d7bff", "icon": "cartA", "exts": ["gba"]},
	"gb": {"badge": "GB", "name": "Game Boy / Color", "color": "#9bbc0f", "icon": "cartB", "exts": ["gb", "gbc"]},
	"nes": {"badge": "NES", "name": "Nintendinho (NES)", "color": "#e0483e", "icon": "cartN", "exts": ["nes"]},
	"md": {"badge": "MD", "name": "Mega Drive", "color": "#4a90d9", "icon": "cartM", "exts": ["md", "gen", "smd", "bin"]},
}
const EXTRA_SYS := ["gc", "wii", "x360", "nds", "3ds", "gba", "gb", "nes", "md"]
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
var skyroms_nome: String = "pendrive SKYROMS"   # Fase 7.6: ou "HD (pasta SKYROMS)"
var skyroms_rw: bool = true                     # HD do Windows hibernado: só leitura
var skyroms_hd: bool = false

# Fase 5.6
const SKY_BIN := "/opt/skystation/bin"
const IDLE_DIM := 300.0          # 5 min parado no menu: escurece
const IDLE_OFF_BAT := 1200.0     # 20 min na bateria: desliga
const IDLE_OFF_AC := 3600.0      # 60 min na tomada: desliga
var sounds_dir: String = ""
var bat_cap: int = -1
var bat_charging: bool = false
var on_battery: bool = false
var pad_bats: Array = []         # [[capacidade, carregando]]
var temp_c: int = -1
var events_pos: int = -1
var reload_at: float = -1.0
var covers_at: float = 6.0
var covers_busy: bool = false
var playtime: Dictionary = {}
var shots: Array = []            # caminhos das capturas (mais nova primeiro)
var viewer_open: bool = false
var viewer_idx: int = 0
var viewer_tex: Texture2D = null
var slider_kind: String = ""     # "", "volume", "brilho"
var slider_val: int = 0
var slider_t: float = 0.0
var idle_t: float = 0.0
var dimmed: bool = false
var dim_t: float = 0.0
var saved_brightness: int = -1
var off_countdown: float = -1.0
var music: AudioStreamPlayer = null
var music_on: bool = true
var audio_out_txt: String = ""
var update_sha: String = ""
var update_check_at: float = 20.0
var bg_threads: Array = []
var toast_icon: String = ""

# Fase 5.7
var disk_detail: String = ""
var recv_open: bool = false      # tela "Central web" aberta (o serviço roda em segundo plano, Fase 7.0)
var recv_poll: float = 0.0
var central: Dictionary = {}     # estado do serviço: ip, pin, qr, recebendo, log
var central_on: bool = false
var storage_data: Dictionary = {}   # tela Armazenamento (vazio = fechada)
var job_thread: Thread = null
var job_cancel_hint: bool = false
var confirm_delete: bool = false


# ---------------------------------------------------------------- ciclo de vida

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN   # console: o ponteiro só aparece nos apps que usam mouse
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
	_apply_tv_scale()
	_make_glow()
	logo_tex = _load_tex(ProjectSettings.globalize_path("res://logo.png"))  # a mesma logo da tela de boot
	sounds_dir = ProjectSettings.globalize_path("res://").path_join("../sounds").simplify_path()
	_make_sounds()
	_make_music()
	_load_state()
	_reload_games()
	_refresh_status()
	version_txt = _read_text("/opt/skystation/VERSION", "")
	_bg(_run_json.bind(SKY_BIN + "/sky-config", ["audio", "list"]), _on_audio)
	if FileAccess.file_exists(conf_dir + "/intro.off"):
		intro_t = INTRO_LEN
	else:
		_play("chime")


func _exit_tree() -> void:
	update_stop = true
	if busy_thread != null and busy_thread.is_started():
		busy_thread.wait_to_finish()
	for th in bg_threads + [job_thread]:
		if th != null and th.is_started():
			th.wait_to_finish()


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
	_poll_events()
	if reload_at > 0.0 and t >= reload_at:
		reload_at = -1.0
		_reload_games()
	if covers_at > 0.0 and t >= covers_at:
		covers_at = -1.0
		_fetch_covers()
	if update_check_at > 0.0 and t >= update_check_at:
		update_check_at = t + 6.0 * 3600.0
		_check_update()
	_tick_music(delta)
	_tick_idle(delta)
	slider_t = move_toward(slider_t, 1.0 if slider_kind != "" else 0.0, delta * 8.0)

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
	if job_thread != null and Input.is_action_just_pressed("sky_back") and busy_msg != "Cancelando…":
		_write_text(run_dir + "/cancelar-job", "1")   # B cancela copiar disco / compactar
		busy_msg = "Cancelando…"
		queue_redraw()
	if busy_msg == "" and not dimmed:
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


func _input(event: InputEvent) -> void:
	# qualquer botão/tecla "acorda" o console (e não faz mais nada se a tela estava escura)
	var real := event is InputEventKey or event is InputEventJoypadButton \
		or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5)
	if not real or not event.is_pressed() and not event is InputEventJoypadMotion:
		return
	idle_t = 0.0
	off_countdown = -1.0
	if dimmed:
		_wake()
		cooldown = 0.4
		get_viewport().set_input_as_handled()


func _handle_input(delta: float) -> void:
	if cooldown > 0.0:
		return
	if panel_open == false and not recv_open and storage_data.is_empty():
		_tick_secret(delta)
	if slider_kind != "":
		_slider_input(delta)
		return
	if viewer_open:
		_viewer_input()
		return
	if recv_open:
		recv_poll -= delta
		if recv_poll <= 0.0:
			recv_poll = 0.5
			_read_central()
		if Input.is_action_just_pressed("sky_menu"):
			_central_off()
		elif Input.is_action_just_pressed("sky_back") or Input.is_action_just_pressed("sky_accept"):
			_close_receive()
		return
	if not storage_data.is_empty():
		if Input.is_action_just_pressed("sky_back") or Input.is_action_just_pressed("sky_accept"):
			storage_data = {}
			_play("back")
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

# ---------------------------------------------------------------- perfis e troféus (Fase 6.3)
var profiles: Array = []
var profile_id: String = ""
var profile_name: String = ""
var trophies: Dictionary = {}


func _sky_json(tool: String, args: Array) -> Dictionary:
	var out: Array = []
	if not FileAccess.file_exists(SKY_BIN + "/" + tool):
		return {}
	OS.execute(SKY_BIN + "/" + tool, args, out)
	var d = JSON.parse_string(str(out[0]).strip_edges()) if not out.is_empty() and str(out[0]).begins_with("{") else null
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _load_profile(args: Array = ["listar"]) -> void:
	var d := _sky_json("sky-perfis", args)
	if d.has("perfis"):
		profiles = d["perfis"]
		profile_id = str(d.get("atual", ""))
		for p in profiles:
			if str(p["id"]) == profile_id:
				profile_name = str(p["nome"])
	if d.has("error"):
		_toast(str(d["error"]), 3.5)
	trophies = _sky_json("sky-trofeus", ["listar"])


func _next_profile() -> void:
	if profiles.size() < 2:
		_toast("Só há um perfil. Use \"Novo perfil\" para criar outro", 3.5)
		return
	var i := 0
	for k in profiles.size():
		if str(profiles[k]["id"]) == profile_id:
			i = k
	_load_profile(["usar", str(profiles[(i + 1) % profiles.size()]["id"])])
	_reload_games()
	_toast("Perfil: " + profile_name, 2.5, "pad")


func _reload_games() -> void:
	if profile_id == "":
		_load_profile()
	else:
		trophies = _sky_json("sky-trofeus", ["listar"])
	var pt_txt := _read_text(home_dir + "/skystation/saves/tempo.json", "{}")
	var pt = JSON.parse_string(pt_txt) if pt_txt.begins_with("{") else {}
	playtime = pt if typeof(pt) == TYPE_DICTIONARY else {}
	shots.clear()
	var sd := DirAccess.open(home_dir + "/skystation/capturas")
	if sd != null:
		for f in sd.get_files():
			if f.get_extension().to_lower() == "png":
				shots.append(home_dir + "/skystation/capturas/" + f)
	shots.sort()
	shots.reverse()
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


# Fase 7.6: o que está em /mnt/skyroms é o pendrive ou a pasta SKYROMS do HD do PC?
func _skyroms_check() -> void:
	var src := ""
	for line in _read_text("/proc/mounts", "").split("\n"):
		var p := line.split(" ", false)
		if p.size() > 1 and p[1] == "/mnt/skyroms":
			src = p[0]  # montagens repetidas: a última é a que aparece
	skyroms_present = src != ""
	var hd := {}
	for line in _read_text("/run/skystation/skyroms-hd", "").split("\n"):
		var i := line.find("=")
		if i > 0:
			hd[line.substr(0, i)] = line.substr(i + 1)
	skyroms_hd = skyroms_present and hd.get("estado", "") == "ok" and hd.get("dev", "") == src
	skyroms_nome = "HD (pasta SKYROMS)" if skyroms_hd else "pendrive SKYROMS"
	skyroms_rw = not (skyroms_hd and hd.get("modo", "") == "ro")


func _scan_roms() -> void:
	_skyroms_check()
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
				var where := skyroms_nome if base == "/mnt/skyroms" else "armazenamento interno"
				var g := {
					"id": sys_id + "-" + stem.validate_filename().replace(" ", "_"),
					"dir": rdir, "sys": sys_id,
					"title": title, "type": "retro",
					"exec": "sky-emu %s %s" % [sys_id, _shq(path)], "path": path,
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
	_scan_ps3()
	_scan_disc(tag_re)


var ps3_info: Dictionary = {}
var running_id: String = ""


func _scan_ps3() -> void:
	# Fase 7.0: jogos de PS3 são pastas ou .iso; o sky-ps3 lê nome, código e ícone de dentro do jogo.
	ps3_info = _sky_json("sky-ps3", ["listar"])
	var info: Dictionary = ROM_SYSTEMS["ps3"]
	for j in ps3_info.get("jogos", []):
		var path := str(j.get("path", ""))
		var onde := str(j.get("onde", ""))
		var where: String = {"skyroms": skyroms_nome, "rpcs3": "instalado no RPCS3"}.get(onde, "armazenamento interno")
		var key := str(j.get("id", ""))
		if key == "":
			key = str(j.get("arquivo", "")).validate_filename().replace(" ", "_")
		games.append({
			"id": "ps3-" + key, "dir": path.get_base_dir(), "sys": "ps3",
			"title": str(j.get("titulo", "")), "type": "retro",
			"exec": "sky-emu ps3 %s" % _shq(path), "path": "" if onde == "rpcs3" else path,
			"description": "%s  ·  %s  ·  %s%s" % [info["name"], str(j.get("formato", "")), where,
				("  ·  " + str(j.get("id", ""))) if str(j.get("id", "")) != "" else ""],
			"color": Color.from_string(info["color"], Color("4fd1ff")),
			"order": 50, "cover": _load_tex(str(j.get("capa", ""))),
		})


func _scan_disc(tag_re: RegEx) -> void:
	# Fase 5.8: o sky-notify identifica o disco no leitor e escreve disco.json.
	var txt := _read_text(run_dir + "/disco.json", "")
	var d = JSON.parse_string(txt) if txt.begins_with("{") else null
	if typeof(d) != TYPE_DICTIONARY or not d.get("disco", false):
		return
	var sys_id := str(d.get("sistema", ""))
	if not ROM_SYSTEMS.has(sys_id):
		return
	var info: Dictionary = ROM_SYSTEMS[sys_id]
	var serial := str(d.get("serial", "")).validate_filename()
	var title := tag_re.sub(str(d.get("titulo", "")), "", true).strip_edges()
	if title == "":
		title = "Disco de " + str(info["badge"])
	games.append({
		"id": sys_id + "-disco-" + (serial if serial != "" else "sem-codigo"),
		"dir": home_dir + "/skystation", "sys": sys_id,
		"title": title, "type": "retro", "disco": true,
		"exec": "sky-emu %s disco %s" % [sys_id, _shq(serial)], "path": "",
		"description": "%s  ·  Disco no leitor%s" % [info["name"], ("  ·  " + serial) if serial != "" else ""],
		"color": Color.from_string(info["color"], Color("4fd1ff")),
		"order": 0, "cover": _load_tex(str(d.get("capa", ""))),
	})


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
	if g["sys"] == "ps2" and _ps2_speed(g["id"]) != "auto":
		sub += "  ·  Desempenho: " + SPEED_NAMES[_ps2_speed(g["id"])]
	var pt: Dictionary = playtime.get(g["id"], {})
	if not pt.is_empty():
		sub += "  ·  " + _fmt_time(int(pt.get("seconds", 0))) + " jogados  ·  " + _fmt_when(int(pt.get("last", 0)))
	var fav: bool = favs.has(g["id"])
	return {"title": ("★ " if fav else "") + str(g["title"]), "sub": sub, "desc": g["description"], "kind": "game",
		"game": g, "color": g["color"], "cover": g["cover"], "glyph": "", "fav": fav}


var favs: Array = []


func _load_favs() -> Array:
	var txt := _read_text(home_dir + "/skystation/saves/favoritos.json", "[]")
	var d = JSON.parse_string(txt) if txt.begins_with("[") else []
	return d if typeof(d) == TYPE_ARRAY else []


func _toggle_fav(game_id: String) -> void:
	var f := _load_favs()
	if f.has(game_id):
		f.erase(game_id)
		_toast("Tirado dos favoritos", 2.0, "disc")
	else:
		f.append(game_id)
		_toast("Favorito: aparece no topo da lista", 2.5, "disc")
	_write_text(home_dir + "/skystation/saves/favoritos.json", JSON.stringify(f))
	_reload_games()


func _act(title: String, sub: String, action: String, glyph: String, color: Color = Color(0, 0, 0, 0)) -> Dictionary:
	return {"title": title, "sub": sub, "desc": "", "kind": "action", "action": action,
		"glyph": glyph, "color": color, "cover": null}


func _build_cats() -> void:
	var c_sys := {"id": "sistema", "title": "Sistema", "icon": "gear", "items": []}
	var c_games := {"id": "jogos", "title": "Jogos", "icon": "pad", "items": []}
	var c_ps1 := {"id": "ps1", "title": "PS1", "icon": "disc1", "items": []}
	var c_ps2 := {"id": "ps2", "title": "PS2", "icon": "disc2", "items": []}
	var c_ps3 := {"id": "ps3", "title": "PS3", "icon": "disc3", "items": []}
	var c_psp := {"id": "psp", "title": "PSP", "icon": "discP", "items": []}
	var c_snes := {"id": "snes", "title": "SNES", "icon": "cartS", "items": []}
	var c_n64 := {"id": "n64", "title": "N64", "icon": "cart64", "items": []}
	var by_sys := {"ps1": c_ps1, "ps2": c_ps2, "snes": c_snes, "n64": c_n64, "psp": c_psp, "ps3": c_ps3}
	var c_extra: Array = []
	for sid in EXTRA_SYS:
		var ce := {"id": sid, "title": ROM_SYSTEMS[sid]["badge"], "icon": ROM_SYSTEMS[sid]["icon"], "items": []}
		by_sys[sid] = ce
		c_extra.append(ce)
	var c_pc := {"id": "pc", "title": "PC", "icon": "monitor", "items": []}
	var c_apps := {"id": "apps", "title": "Apps", "icon": "apps", "items": []}
	var c_power := {"id": "energia", "title": "Energia", "icon": "power", "items": []}
	var c_recent := {"id": "recentes", "title": "Recentes", "icon": "clock", "items": []}
	var c_shots := {"id": "capturas", "title": "Capturas", "icon": "camera", "items": []}

	favs = _load_favs()
	for g in games:
		var it := _game_item(g)
		match str(g["type"]):
			"retro":
				by_sys.get(g["sys"], c_ps1)["items"].append(it)
				if g.get("disco", false):
					c_games["items"].insert(0, it)  # como no PS3: o disco aparece no topo de Jogos
			"windows":
				c_pc["items"].append(it)
			"app", "ferramenta":
				c_apps["items"].append(it)
			_:
				c_games["items"].append(it)

	var hint_roms := "Copie para ~/skystation/roms/%s, para o pendrive SKYROMS ou para a pasta SKYROMS do HD do PC"
	var hd_estado := _read_text("/run/skystation/skyroms-hd", "")
	if hd_estado.contains("estado=bitlocker"):
		hint_roms += "  (o HD do PC está criptografado com BitLocker: desative-o no Windows para o SkyStation ler)"
	if c_ps1["items"].is_empty():
		c_ps1["items"].append(_act("Nenhum jogo de PS1", hint_roms % "ps1", "", "disc"))
	if c_ps2["items"].is_empty():
		c_ps2["items"].append(_act("Nenhum jogo de PS2", hint_roms % "ps2", "", "disc"))
	if c_games["items"].is_empty():
		c_games["items"].append(_act("Nenhum jogo", "Pastas com game.json em ~/skystation/games", "", "pad"))

	c_sys["items"] = [
		_act("Perfil: " + profile_name, "A troca para o próximo perfil. Cada um tem saves, favoritos e troféus próprios", "profile", "pad"),
		_act("Wi-Fi", "Redes sem fio", "settings:0", "wifi"),
		_act("Bluetooth", "Parear controles e fones", "settings:1", "bt"),
		_act("Volume", "Ajuste com ◀ ▶", "slider:volume", "sound"),
		_act("Saída de som", audio_out_txt, "audio_out", "speaker"),
		_act("Brilho da tela", "Ajuste com ◀ ▶", "slider:brilho", "sun"),
		_act("Tema de cores", _theme_name(), "theme", "palette"),
		_act("Música ambiente", "Ligada" if music_on else "Desligada", "music", "note"),
		_act("Sons da interface", "Ligados" if sounds_on else "Desligados", "sounds", "note"),
		_act("Bateria e temperatura", _power_txt(), "power_info", "battery"),
		_act("Armazenamento", disk_txt, "storage", "drive"),
		_act("Central web (celular/PC)", _central_txt(), "receive", "download"),
		_act("Modo TV", _tv_txt(), "tv", "monitor"),
		_act("Som de ligar", "Ligado" if not FileAccess.file_exists(conf_dir + "/ligar.off") else "Desligado", "boot_sound", "note"),
		_act("Ligar pelo controle", _wake_txt(), "wake_pad", "pad"),
		_act("Gestos no touchpad", _touch_txt(), "touchpad", "pad"),
		_act("Este aparelho", _hw_txt(), "hwprofile", "info"),
		_act("Medição de FPS", "Ligada: contador e log nos jogos" if _fps_on() else "Desligada", "fps", "gauge"),
		_act("Informações do sistema", "Hardware e versão", "settings:3", "info"),
		_act("Atualizar o SkyStation", _update_txt(), "update", "refresh"),
	]
	if profiles.size() < 4 and not profiles.is_empty():
		c_sys["items"].insert(1, _act("Novo perfil", "Cria outro jogador (o nome pode ser trocado na Central web → Saves)", "profile_new", "pad"))
	var prev := _read_text("/opt/skystation.anterior/VERSION", "").strip_edges()
	if prev != "":
		c_sys["items"].append(_act("Voltar à versão anterior", "Se a atualização deu problema: volta para " + prev, "rollback", "refresh"))
	# Favoritos (Fase 6.1) primeiro em cada lista, na mesma ordem de antes
	for c in [c_games, c_ps1, c_ps2, c_ps3, c_psp, c_snes, c_n64, c_pc] + c_extra:
		var fav_items: Array = c["items"].filter(func(i): return i.get("fav", false))
		if not fav_items.is_empty():
			c["items"] = fav_items + c["items"].filter(func(i): return not i.get("fav", false))
	# Recentes: os 8 últimos jogados (que ainda existem)
	var by_id := {}
	for g in games:
		by_id[g["id"]] = g
	var recent_ids := playtime.keys().filter(func(k): return by_id.has(k))
	recent_ids.sort_custom(func(a, b): return int(playtime[a].get("last", 0)) > int(playtime[b].get("last", 0)))
	for k in recent_ids.slice(0, 8):
		c_recent["items"].append(_game_item(by_id[k]))
	# Capturas de tela
	for path in shots.slice(0, 40):
		var name: String = str(path).get_file().get_basename()
		var parts := name.split("_")
		var when := parts[-1] if parts.size() > 1 else ""
		var who := "_".join(parts.slice(0, parts.size() - 1)) if parts.size() > 1 else name
		var it := {"title": _shot_title(who), "sub": _shot_date(when), "desc": "", "kind": "shot",
			"path": path, "glyph": "camera", "color": Color(0, 0, 0, 0), "cover": null}
		c_shots["items"].append(it)
	# Desligar fica por último: um "A" sem querer ao entrar na categoria não desliga nada.
	c_power["items"] = [
		_act("Modo de espera", "Desliga a tela; o controle ou o botão de ligar acordam o console", "suspend", "moon"),
		_act("Recarregar jogos", "Procura jogos e ROMs de novo", "reload", "search"),
		_act("Reiniciar a interface", "Reabre o SkyStation sem reiniciar", "restart_ui", "refresh"),
		_act("Reiniciar", "Reinicia o console", "reboot", "refresh"),
		_act("Desligar", "Desliga o console", "poweroff", "power"),
	]

	var old_id: String = cats[cat]["id"] if not cats.is_empty() and cat < cats.size() else "jogos"
	cats = [c_sys]
	if not c_recent["items"].is_empty():
		cats.append(c_recent)
	cats += [c_games, c_ps1, c_ps2]
	if c_ps3["items"].is_empty() and ps3_info.get("emulador", false):
		var falta := "Envie o PS3UPDAT.PUP pela Central web (Sistema: Firmware do PS3). " if not ps3_info.get("firmware", false) and not ps3_info.get("pup", false) else ""
		c_ps3["items"].append(_act("Nenhum jogo de PS3", falta + "Jogos: pasta do disco ou .iso em ~/skystation/roms/ps3 ou SKYROMS/ps3", "", "disc"))
	for c in [c_ps3, c_psp, c_snes, c_n64] + c_extra:   # só aparecem quando há jogos
		if not c["items"].is_empty():
			cats.append(c)
	if not c_pc["items"].is_empty():
		cats.append(c_pc)
	cats.append(c_apps)
	var tl: Array = trophies.get("trofeus", [])
	if not tl.is_empty():
		var c_tro := {"id": "trofeus", "title": "Troféus", "icon": "trophy", "items": []}
		var tier := {"bronze": Color("#cd7f32"), "prata": Color("#c0c8d8"), "ouro": Color("#ffd24a"), "platina": Color("#9fe8ff")}
		tl.sort_custom(func(x, y): return int(x["ganho"]) > int(y["ganho"]))
		for tr in tl:
			var got := int(tr["ganho"]) > 0
			var when := ("Conquistado " + _fmt_when(int(tr["ganho"]))) if got else "Bloqueado"
			var it := _act(str(tr["nome"]), "%s  ·  %s  ·  %s" % [str(tr["desc"]), str(tr["nivel"]).capitalize(), when], "", "trophy",
				tier.get(str(tr["nivel"]), WHITE) if got else Color(1, 1, 1, 0.25))
			c_tro["items"].append(it)
		cats.append(c_tro)
	if not c_shots["items"].is_empty():
		cats.append(c_shots)
	cats.append(c_power)
	cat = 1
	for i in cats.size():
		if cats[i]["id"] == "jogos":
			cat = i
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
				"music":
					it["sub"] = "Ligada" if music_on else "Desligada"
				"power_info":
					it["sub"] = _power_txt()
				"audio_out":
					it["sub"] = audio_out_txt
				"update":
					it["sub"] = _update_txt()
				"boot_sound":
					it["sub"] = "Desligado" if FileAccess.file_exists(conf_dir + "/ligar.off") else "Ligado"
				"wake_pad":
					it["sub"] = _wake_txt()
				"tv":
					it["sub"] = _tv_txt()
				"receive":
					it["sub"] = _central_txt()
				"touchpad":
					it["sub"] = _touch_txt()
				"hwprofile":
					it["sub"] = _hw_txt()


# ---------------------------------------------------------------- ações

func _activate() -> void:
	var it := _cur()
	if it.is_empty():
		return
	if it["kind"] == "game":
		_play("accept")
		_launch(it["game"])
		return
	if it["kind"] == "shot":
		_play("accept")
		_open_viewer()
		return
	var action: String = str(it.get("action", ""))
	if action == "":
		_play("back")
		return
	_play("accept")
	if action.begins_with("settings:"):
		_open_settings(int(action.split(":")[1]))
		return
	if action.begins_with("slider:"):
		_open_slider(action.split(":")[1])
		return
	match action:
		"storage":
			_open_storage()
		"power_info":
			_refresh_status()
			_toast(_power_txt(), 2.8, "battery")
		"audio_out":
			_bg(_run_json.bind(SKY_BIN + "/sky-config", ["audio", "next"]), _on_audio_announce)
		"receive":
			_open_receive()
		"suspend":
			_suspend()
		"boot_sound":
			_toggle_file(conf_dir + "/ligar.off")
			if not FileAccess.file_exists(conf_dir + "/ligar.off"):
				_play_file("ligar")
		"tv":
			_toggle_file(conf_dir + "/tv-grande.off")
			_apply_tv_scale()
			_toast("Interface maior na TV: " + ("desligada" if FileAccess.file_exists(conf_dir + "/tv-grande.off") else "ligada"), 2.5, "monitor")
		"profile":
			_next_profile()
		"profile_new":
			_load_profile(["criar"])
			_next_profile()
		"touchpad":
			_toggle_file(conf_dir + "/touchpad.off")
			_refresh_sys_items()
		"hwprofile":
			# Automático -> Leve -> Potente -> Automático (vale para o próximo jogo aberto)
			var cur := _read_text(conf_dir + "/perfil", "")
			if cur == "":
				_write_text(conf_dir + "/perfil", "leve")
			elif cur == "leve":
				_write_text(conf_dir + "/perfil", "potente")
			else:
				DirAccess.remove_absolute(conf_dir + "/perfil")
			_play("accept")
			_refresh_sys_items()
		"wake_pad":
			_toggle_file(conf_dir + "/acordar.off")
			_toast("Vale a partir do próximo minuto (o sistema aplica sozinho)", 3.0, "pad")
		"music":
			music_on = not music_on
			if music_on:
				DirAccess.remove_absolute(conf_dir + "/musica.off")
			else:
				_write_text(conf_dir + "/musica.off", "1")
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
		"rollback":
			_start_update(true)
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
	running_id = str(g["id"])
	busy_msg = "Abrindo %s…" % running_title
	queue_redraw()
	# Enquanto o jogo roda: sem redesenho, no máximo 4 checagens por segundo.
	OS.low_processor_usage_mode = true
	Engine.max_fps = 4
	bg.visible = false
	if music != null:
		music.stop()


func _on_game_closed() -> void:
	running_pid = -1
	busy_msg = ""
	bg.visible = true
	OS.low_processor_usage_mode = false
	_apply_power_mode()
	_report_exit()
	reload_at = t + 0.3   # tempo de jogo e capturas novas
	idle_t = 0.0
	cooldown = 0.5
	hold_dir = _nav_dir()
	_refresh_status()


func _report_exit() -> void:
	var msg := _read_text(run_dir + "/last_msg", "")
	var code := _read_text(run_dir + "/last_exit", "-1").to_int()
	var by_home := FileAccess.file_exists(run_dir + "/home_closed")
	if by_home:
		DirAccess.remove_absolute(run_dir + "/home_closed")
	if msg != "":
		_toast(msg, 7.0)
	elif by_home or code == 143:
		_toast("Jogo fechado pelo botão Home")
	elif code > 0:
		var why: String = EXIT_CODES.get(code, "o programa terminou com erro")
		var last := _last_log_line(running_id)
		_toast("Erro E%d: %s%s" % [code, why, ("  ·  " + last) if last != "" else ""], 9.0, "info")


# Códigos de saída (Fase 7.2). Acima de 128 = 128 + número do sinal que matou o processo.
const EXIT_CODES := {
	1: "o emulador/jogo relatou um erro", 2: "opção ou arquivo inválido", 3: "o SkyStation não conseguiu preparar o jogo",
	97: "a pasta do jogo não existe mais", 124: "demorou demais e foi encerrado",
	126: "sem permissão para executar o programa", 127: "programa/emulador não encontrado (não instalado?)",
	132: "instrução ilegal (SIGILL): este processador não suporta o emulador",
	134: "o emulador abortou (SIGABRT): erro interno dele",
	135: "erro de leitura (SIGBUS): arquivo ou mídia com defeito",
	136: "erro de cálculo (SIGFPE) no emulador",
	137: "encerrado à força (SIGKILL): provável falta de memória",
	139: "falha de memória (SIGSEGV) no emulador ou no driver de vídeo",
	141: "canal fechado (SIGPIPE)", 255: "erro geral ao iniciar",
}


func _last_log_line(game_id: String) -> String:
	# última linha útil do log do jogo, para o aviso de erro dizer o motivo (log completo em ~/.local/state/skystation/games)
	if game_id == "":
		return ""
	var txt := _read_text(home_dir + "/.local/state/skystation/games/" + game_id + ".log", "")
	var lines := txt.split("\n", false)
	for i in range(lines.size() - 1, -1, -1):
		var l := lines[i].strip_edges()
		if l != "" and not l.begins_with("===") and not l.begins_with("gamemode"):
			return l.left(110)
	return ""


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


func _start_update(rollback: bool = false) -> void:
	if busy_thread != null:
		return
	UPD_REQ = "/var/lib/skystation/pedidos/" + ("reverter" if rollback else "atualizar")
	busy_msg = "Voltando para a versão anterior…" if rollback else "Baixando a versão mais nova do SkyStation…"
	busy_thread = Thread.new()
	busy_thread.start(_update_worker)


const UPD_DIR := "/var/lib/skystation/atualizar"
var UPD_REQ := "/var/lib/skystation/pedidos/atualizar"
var update_stop: bool = false


func _update_worker() -> void:
	# Fase 5.7.2: sem sudo. O menu cria um pedido e o systemd roda a atualização como root.
	if not DirAccess.dir_exists_absolute(UPD_REQ.get_base_dir()):
		var out: Array = []
		var code := OS.execute("sudo", ["-n", "/usr/local/bin/skystation-atualizar", "--github"], out, true)
		call_deferred("_update_done", code, "\n".join(out))
		return
	var estado := UPD_DIR + "/estado"
	var antes := FileAccess.get_modified_time(estado) if FileAccess.file_exists(estado) else 0
	var f := FileAccess.open(UPD_REQ, FileAccess.WRITE)
	if f == null:
		call_deferred("_update_done", 1, "não consegui fazer o pedido de atualização")
		return
	f.store_string("1\n")
	f.close()
	var esperou := 0.0
	var comecou := false
	while not update_stop:
		OS.delay_msec(500)
		esperou += 0.5
		var mudou := FileAccess.file_exists(estado) and FileAccess.get_modified_time(estado) > antes
		var st := _read_text(estado, "").strip_edges() if mudou else ""
		if st == "rodando":
			comecou = true
			var ult := _last_line(_read_text(UPD_DIR + "/log", ""))
			if ult != "":
				call_deferred("_update_progress", ult)
		elif st == "ok" or st == "erro":
			var txt := _read_text(UPD_DIR + "/log", "")
			call_deferred("_update_done", 0 if st == "ok" else 1, txt)
			return
		if not comecou and esperou > 15.0:
			call_deferred("_update_done", 1, "o serviço de atualização não respondeu. Rode uma vez no terminal: sudo skystation-atualizar")
			return
		if esperou > 1500.0:
			call_deferred("_update_done", 1, "a atualização demorou demais. Confira a internet e tente de novo")
			return


func _last_line(txt: String) -> String:
	var ult := ""
	for l in txt.split("\n"):
		if l.strip_edges() != "":
			ult = l.strip_edges()
	return ult


func _update_progress(line: String) -> void:
	if busy_thread == null:
		return
	if line.begins_with("==> "):
		line = line.substr(4)
	busy_msg = "Atualizando: " + line.left(70)


func _update_done(code: int, out: String) -> void:
	busy_thread.wait_to_finish()
	busy_thread = null
	if code == 0:
		busy_msg = "Pronto! Reabrindo o SkyStation…"
		quit_at = t + 2.0
		_play("chime")
	else:
		busy_msg = ""
		var line := _last_line(out)
		if out.contains("a password is required") or (code == 1 and line == ""):
			line = "falta permissão. Rode uma vez no terminal: sudo skystation-atualizar"
		_toast("Não foi possível atualizar: " + line, 7.0)


# ---------------------------------------------------------------- painel de opções (Y / Start)

func _toggle_panel() -> void:
	panel_open = not panel_open
	if panel_open:
		var it := _cur()
		panel_items = []
		if it.get("kind", "") == "game":
			panel_items.append(["Jogar", "play"])
			if not it["game"].get("disco", false):
				panel_items.append(["Tirar dos favoritos" if it.get("fav", false) else "Favoritar ★", "fav"])
			if it["game"].get("disco", false):
				panel_items.append(["Copiar disco para o console", "copy_disc:interno"])
				if skyroms_present and skyroms_rw:
					panel_items.append(["Copiar disco para o " + skyroms_nome, "copy_disc:skyroms"])
				panel_items.append(["Ejetar disco", "eject"])
			if it["game"].get("sys", "") == "ps2":
				panel_items.append(["Desempenho: " + SPEED_NAMES[_ps2_speed(it["game"]["id"])], "ps2_speed"])
			var gpath := str(it["game"].get("path", ""))
			if gpath != "":
				if gpath.begins_with("/mnt/skyroms/"):
					if skyroms_rw:
						panel_items.append(["Mover para o console", "move:interno"])
				elif skyroms_present and skyroms_rw and not gpath.begins_with("/mnt/skystation/"):
					panel_items.append(["Mover para o " + skyroms_nome, "move:skyroms"])
				if it["game"].get("sys", "") == "ps2" and gpath.get_extension().to_lower() == "iso":
					panel_items.append(["Conferir cópia", "verify"])
				if it["game"].get("sys", "") in ["ps1", "ps2"] and gpath.get_extension().to_lower() in ["cue", "iso", "img"]:
					panel_items.append(["Compactar (CHD): ocupa menos espaço", "compress"])
				panel_items.append(["Apagar jogo", "delete_game"])
		if it.get("kind", "") == "shot":
			panel_items.append(["Ver captura", "play"])
			panel_items.append(["Apagar captura", "delete_shot"])
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
	if a != "delete_game":
		confirm_delete = false
	if a.begins_with("copy_disc:"):
		_run_job(["copiar-disco", a.split(":")[1]], "Copiando o disco…")
		return
	if a == "verify":
		_run_job(["conferir", str(_cur()["game"]["path"])], "Conferindo a cópia…")
		return
	if a == "compress":
		var itc := _cur()
		_run_job(["compactar", str(itc["game"]["path"])], "Compactando " + str(itc.get("title", "")) + "…")
		return
	if a == "fav":
		_toggle_fav(str(_cur()["game"]["id"]))
		return
	if a == "ps2_speed":
		_cycle_ps2_speed(str(_cur()["game"]["id"]))
		return
	if a.begins_with("move:"):
		var it := _cur()
		_run_job(["mover", str(it["game"]["path"]), a.split(":")[1]], "Movendo " + str(it.get("title", "")) + "…")
		return
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
		"delete_game":
			var it := _cur()
			if not confirm_delete:
				confirm_delete = true
				panel_open = true
				panel_items = [["Confirmar: apagar " + str(it.get("title", "")), "delete_game"], ["Cancelar", "close"]]
				panel_sel = 1
				return
			confirm_delete = false
			_run_job(["apagar", str(it["game"]["path"])], "Apagando " + str(it.get("title", "")) + "…")
		"eject":
			if FileAccess.file_exists(SKY_BIN + "/sky-disco"):
				OS.create_process(SKY_BIN + "/sky-disco", ["ejetar"])
				_toast("Ejetando o disco…", 2.0, "disc")
		"delete_shot":
			var it := _cur()
			if it.get("kind", "") == "shot":
				DirAccess.remove_absolute(str(it["path"]))
				_reload_games()
				_toast("Captura apagada", 2.0, "camera")
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
	_read_central()
	status_t = 5.0
	pads = Input.get_connected_joypads().size()
	wifi_q = -1
	var wl := _read_text("/proc/net/wireless", "")
	for line in wl.split("\n"):
		if line.contains(":") and not line.contains("|"):
			var parts := line.split(" ", false)
			if parts.size() > 2:
				wifi_q = int(parts[2].replace(".", ""))
	_skyroms_check()
	var mounts := ["/"]
	if skyroms_present:
		mounts.append("/mnt/skyroms")
	var out: Array = []
	if OS.execute("df", PackedStringArray(["-B1", "--output=avail,size"] + mounts), out, false) == 0 and out.size() > 0:
		var lines: PackedStringArray = str(out[0]).strip_edges().split("\n")
		var free_t := 0.0
		var size_t := 0.0
		var parts: Array = []
		for i in range(1, lines.size()):
			var nums := lines[i].split(" ", false)
			if nums.size() >= 2:
				free_t += float(nums[0])
				size_t += float(nums[1])
				parts.append("%s %.1f de %.1f GB livres" % ["Sistema" if i == 1 else "SKYROMS",
					float(nums[0]) / 1e9, float(nums[1]) / 1e9])
		disk_txt = "%.1f GB livres de %.1f GB" % [free_t / 1e9, size_t / 1e9]
		if parts.size() > 1:
			disk_txt += "  (sistema + SKYROMS)"
		disk_detail = "  ·  ".join(parts)
	_read_power()
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
	# Lê linha a linha: arquivos de /proc e /sys dizem ter tamanho 0 (ou 4096) e o
	# get_file_as_string() confia nesse tamanho.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return default
	var lines := PackedStringArray()
	while true:
		var line := f.get_line()
		if f.eof_reached() and line == "":
			break
		lines.append(line)
		if f.eof_reached():
			break
	return "\n".join(lines).strip_edges()


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
		f.close()


func _toast(msg: String, seconds: float = 2.8, icon: String = "") -> void:
	toast_msg = msg
	toast_t = seconds
	toast_icon = icon


# ---------------------------------------------------------------- Fase 5.6: utilidades

func _bg(work: Callable, done: Callable) -> void:
	# roda "work" numa thread e chama "done" com o resultado de volta na thread principal
	var th := Thread.new()
	bg_threads.append(th)
	th.start(_bg_worker.bind(th, work, done))


func _bg_worker(th: Thread, work: Callable, done: Callable) -> void:
	var r = work.call()
	call_deferred("_bg_done", th, done, r)


func _bg_done(th: Thread, done: Callable, r) -> void:
	th.wait_to_finish()
	bg_threads.erase(th)
	done.call(r)


func _run_json(cmd: String, args: Array) -> Dictionary:
	var out: Array = []
	if OS.execute(cmd, PackedStringArray(args), out, false) < 0 or out.is_empty():
		return {"ok": false}
	var lines: PackedStringArray = str(out[0]).strip_edges().split("\n")
	if not lines[-1].begins_with("{"):
		return {"ok": false}
	var data = JSON.parse_string(lines[-1])
	return data if typeof(data) == TYPE_DICTIONARY else {"ok": false}


func _play_file(name: String) -> void:
	if not sounds_on:
		return
	var path := sounds_dir.path_join(name + ".wav")
	if FileAccess.file_exists(path):
		OS.create_process("pw-play", [path])


func _fmt_time(secs: int) -> String:
	if secs < 60:
		return "menos de 1 min"
	var h := secs / 3600
	var m := (secs % 3600) / 60
	return ("%d h %02d min" % [h, m]) if h > 0 else ("%d min" % m)


func _fmt_when(epoch: int) -> String:
	if epoch <= 0:
		return ""
	var today := int(Time.get_unix_time_from_system() / 86400.0 + Time.get_time_zone_from_system()["bias"] / 1440.0)
	var day := int(epoch / 86400.0 + Time.get_time_zone_from_system()["bias"] / 1440.0)
	match today - day:
		0:
			return "hoje"
		1:
			return "ontem"
	if today - day < 7:
		return "há %d dias" % (today - day)
	var d := Time.get_datetime_dict_from_unix_time(epoch)
	return "%d de %s" % [d["day"], MONTHS[d["month"] - 1]]


func _shot_title(game_id: String) -> String:
	for g in games:
		if g["id"] == game_id:
			return str(g["title"])
	return game_id.replace("_", " ").replace("-", " ").capitalize()


func _shot_date(stamp: String) -> String:
	# 20261109-195233 -> 9 de nov, 19:52
	if stamp.length() < 13:
		return stamp
	return "%d de %s, %s:%s" % [stamp.substr(6, 2).to_int(), MONTHS[clampi(stamp.substr(4, 2).to_int() - 1, 0, 11)],
		stamp.substr(9, 2), stamp.substr(11, 2)]


func _power_txt() -> String:
	var parts: Array = []
	if bat_cap >= 0:
		parts.append("Console %d%% %s" % [bat_cap, "(carregando)" if bat_charging else "(bateria)"])
	else:
		parts.append("Na tomada")
	for p in pad_bats:
		parts.append("Controle %d%%" % int(p[0]))
	if temp_c >= 0:
		parts.append("CPU %d °C" % temp_c)
	return "  ·  ".join(parts)


func _update_txt() -> String:
	if update_sha != "":
		return "Nova versão disponível!"
	return ("Versão " + version_txt) if version_txt != "" else "Baixar a versão mais nova"


func _read_power() -> void:
	bat_cap = -1
	pad_bats = []
	var ac := -1
	var ps_root := OS.get_environment("SKY_SYSFS") + "/sys/class/power_supply"  # SKY_SYSFS: só para testes
	var da := DirAccess.open(ps_root)
	if da != null:
		for d in da.get_directories():
			var base := ps_root + "/" + d
			var typ := _read_text(base + "/type", "")
			if typ == "Mains":
				ac = _read_text(base + "/online", "0").to_int()
			elif typ == "Battery":
				var cap := _read_text(base + "/capacity", "")
				if not cap.is_valid_int():
					continue
				var st := _read_text(base + "/status", "")
				var chg := st == "Charging" or st == "Full"
				if _read_text(base + "/scope", "") == "Device":
					pad_bats.append([cap.to_int(), chg])
				elif bat_cap < 0:
					bat_cap = cap.to_int()
					bat_charging = chg or st == "Not charging"
	var was := on_battery
	on_battery = bat_cap >= 0 and (ac == 0 or (ac < 0 and not bat_charging))
	temp_c = -1
	var tz := DirAccess.open("/sys/class/thermal")
	if tz != null:
		for z in tz.get_directories():
			if _read_text("/sys/class/thermal/%s/type" % z, "") in ["x86_pkg_temp", "acpitz"]:
				var v := _read_text("/sys/class/thermal/%s/temp" % z, "")
				if v.is_valid_int():
					temp_c = maxi(temp_c, v.to_int() / 1000)
	if was != on_battery:
		_apply_power_mode()


func _apply_power_mode() -> void:
	# Na bateria: menu a 30 quadros por segundo e ondas mais simples (a CPU fica econômica
	# pelo próprio sistema; ver skystation-energia). Na tomada: tudo no máximo.
	if running_pid != -1:
		return
	var eco := low_gfx or on_battery
	Engine.max_fps = 30 if eco else 0
	bg_mat.set_shader_parameter("strands", 5 if low_gfx else (7 if on_battery else 11))


func _poll_events() -> void:
	var path := run_dir + "/events.jsonl"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var length := f.get_length()
	if events_pos < 0 or length < events_pos:
		events_pos = length   # na abertura, ignora os avisos antigos
		return
	if length == events_pos:
		return
	f.seek(events_pos)
	var txt := f.get_buffer(length - events_pos).get_string_from_utf8()
	events_pos = length
	for line in txt.split("\n", false):
		var ev = JSON.parse_string(line)
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var kind := str(ev.get("kind", ""))
		var text := str(ev.get("text", ""))
		if kind == "jogos":
			reload_at = t + 0.8
			covers_at = t + 3.0
			continue
		if kind == "tv":
			_apply_tv_scale()
			_refresh_sys_items()
		if Time.get_unix_time_from_system() - float(ev.get("t", 0)) > 20.0:
			continue   # aviso antigo (chegou durante um jogo): não mostra fora de hora
		var icons := {"central": "download", "controle": "pad", "usb": "usb", "pendrive": "drive", "jogo": "disc", "disco": "disc", "tv": "monitor", "trofeu": "trophy",
			"bateria": "battery", "energia": "battery", "calor": "thermo"}
		_toast(text, 3.5, str(icons.get(kind, "info")))
		if kind in ["controle", "energia", "bateria"]:
			status_t = 0.0  # atualiza bateria/controles na tela já


func _fetch_covers() -> void:
	if covers_busy or not FileAccess.file_exists(SKY_BIN + "/sky-capas"):
		return
	covers_busy = true
	_bg(_run_json.bind(SKY_BIN + "/sky-capas", []), _on_covers)


func _on_covers(r: Dictionary) -> void:
	covers_busy = false
	var n := int(r.get("baixadas", 0))
	if n > 0:
		_reload_games()
		_toast("%d capa(s) nova(s) baixada(s)" % n, 3.0, "disc")
		_play_file("atualizacao")


func _check_update() -> void:
	var cur := ""
	var m := RegEx.create_from_string("\\(([0-9a-f]{7})\\)").search(version_txt)
	if m != null:
		cur = m.get_string(1)
	if cur == "":
		return  # instalado pela pasta da VM: não há commit para comparar
	_bg(_fetch_remote_sha, _on_remote_sha.bind(cur))


func _fetch_remote_sha() -> String:
	var out: Array = []
	OS.execute("curl", ["-fsSL", "--max-time", "10",
		"https://api.github.com/repos/skyy-thedev/skystation/commits/main"], out, false)
	if out.is_empty():
		return ""
	var data = JSON.parse_string(str(out[0]))
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	return str(data.get("sha", "")).substr(0, 7)


func _on_remote_sha(sha: String, cur: String) -> void:
	if sha != "" and sha != cur and sha != update_sha:
		update_sha = sha
		_refresh_sys_items()
		_toast("Nova versão do SkyStation disponível: Sistema → Atualizar", 5.0, "refresh")
		_play_file("atualizacao")


func _on_audio_announce(r: Dictionary) -> void:
	_on_audio(r, true)


func _on_audio(r: Dictionary, announce: bool = false) -> void:
	if not r.get("ok", false):
		if announce:
			_toast("Não consegui trocar a saída de som", 3.0, "speaker")
		return
	audio_out_txt = str(r.get("current", ""))
	_refresh_sys_items()
	if announce:
		_toast("Saída de som: " + audio_out_txt, 2.5, "speaker")


# ---------------------------------------------------------------- Fase 5.7: espera, receber, mover

func _toggle_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	else:
		_write_text(path, "1")
	_refresh_sys_items()


# ---------------------------------------------------------------- Modo TV (Fase 6.0)

func _tv_output() -> String:
	# Saída externa conectada (HDMI/DP/VGA). eDP/LVDS é a tela do próprio notebook.
	var base := OS.get_environment("SKY_SYSFS") + "/sys/class/drm" if OS.get_environment("SKY_SYSFS") != "" else "/sys/class/drm"
	var da := DirAccess.open(base)
	if da == null:
		return ""
	for d in da.get_directories():
		var m := RegEx.create_from_string("^card\\d+-((HDMI|DP|DVI|VGA)-.+)$").search(d)
		if m != null and _read_text(base + "/" + d + "/status", "").strip_edges() == "connected":
			return m.get_string(1)
	return ""


func _tv_txt() -> String:
	var o := _tv_output()
	var big := "interface maior: " + ("não" if FileAccess.file_exists(conf_dir + "/tv-grande.off") else "sim")
	if o == "":
		return "Ligue um cabo HDMI: imagem e som vão para a TV sozinhos  ·  " + big
	return "TV conectada (%s): imagem e som na TV  ·  %s" % [o, big]


func _apply_tv_scale() -> void:
	# Na TV o jogador fica longe: tudo 20% maior (o layout se ajusta ao espaço que sobra).
	var big := _tv_output() != "" and not FileAccess.file_exists(conf_dir + "/tv-grande.off")
	get_window().content_scale_factor = 1.2 if big else 1.0


const SPEED_NAMES := {"auto": "Automático", "normal": "Normal", "rapido": "Rápido", "maximo": "Máximo"}
const SPEED_ORDER := ["auto", "normal", "rapido", "maximo"]


func _ps2_speed(game_id: String) -> String:
	var txt := _read_text(conf_dir + "/ps2-desempenho.json", "{}")
	var d = JSON.parse_string(txt) if txt.begins_with("{") else {}
	return str(d.get(game_id, "auto")) if typeof(d) == TYPE_DICTIONARY else "auto"


func _cycle_ps2_speed(game_id: String) -> void:
	var txt := _read_text(conf_dir + "/ps2-desempenho.json", "{}")
	var d = JSON.parse_string(txt) if txt.begins_with("{") else {}
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
	var cur := str(d.get(game_id, "auto"))
	var nxt: String = SPEED_ORDER[(SPEED_ORDER.find(cur) + 1) % SPEED_ORDER.size()]
	if nxt == "auto":
		d.erase(game_id)
	else:
		d[game_id] = nxt
	_write_text(conf_dir + "/ps2-desempenho.json", JSON.stringify(d))
	var why := {"auto": "o console escolhe: Rápido nos jogos conhecidos como pesados", "normal": "velocidade real do PS2", "rapido": "mais FPS, quase sem efeito colateral",
		"maximo": "o máximo de FPS; alguns jogos engasgam ou falham"}
	_toast("Desempenho: %s (%s)" % [SPEED_NAMES[nxt], why[nxt]], 3.5, "gauge")
	_reload_games()


func _hw_txt() -> String:
	# Fase 7.4: o mesmo pendrive liga em aparelhos diferentes; mostra o que foi detectado neste.
	var forced := _read_text(conf_dir + "/perfil", "")
	var threads := OS.get_processor_count()
	var auto_p := "Potente" if threads >= 8 else "Leve"
	var mem: int = int(OS.get_memory_info().get("physical", 0))
	var perfil: String = ("Automático (%s)" % auto_p) if forced == "" else forced.capitalize() + " (fixado)"
	return "%s  ·  %d threads  ·  %d GB  ·  Qualidade: %s. A = trocar" % [OS.get_processor_name().left(34), threads,
		int(round(float(mem) / 1073741824.0)), perfil]


func _touch_txt() -> String:
	if FileAccess.file_exists(conf_dir + "/touchpad.off"):
		return "Desligados"
	return "Ligados: 2 dedos no touchpad do DS4. Esquerda = brilho, direita = volume"


# Segredo de desenvolvedor (Fase 6.2): segurar L3 + R3 (os dois analógicos apertados) por 2 s abre o terminal.
var secret_t: float = 0.0


func _tick_secret(delta: float) -> void:
	var held := false
	for j in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(j, JOY_BUTTON_LEFT_STICK) and Input.is_joy_button_pressed(j, JOY_BUTTON_RIGHT_STICK):
			held = true
	secret_t = secret_t + delta if held else 0.0
	if secret_t < 2.0:
		return
	secret_t = -5.0   # não dispara de novo enquanto os botões continuam apertados
	var out: Array = []
	if OS.execute("sh", ["-c", "command -v foot"], out) != 0:
		_toast("Terminal não instalado: rode a Fase 6.2", 4.0)
		return
	_launch({"id": "terminal", "dir": home_dir, "exec": "foot", "title": "Terminal", "type": "app", "sys": ""})


func _wake_txt() -> String:
	if FileAccess.file_exists(conf_dir + "/acordar.off"):
		return "Desligado"
	return "Ligado: no modo de espera, o controle liga o console"


func _suspend() -> void:
	_play("back")
	if music != null:
		music.stop()
	busy_msg = "Modo de espera…"
	queue_redraw()
	# espera a tela desenhar a mensagem antes de dormir; ao acordar, limpa
	await get_tree().create_timer(0.6).timeout
	OS.execute("systemctl", ["suspend"])
	await get_tree().create_timer(1.5).timeout
	busy_msg = ""
	idle_t = 0.0
	dimmed = false
	status_t = 0.0


func _central_txt() -> String:
	if central_on:
		return "Ligada em segundo plano: envie jogos e use o teclado do celular a qualquer hora"
	return "Desligada. Abra para ligar: enviar jogos, biblioteca, capturas, saves, teclado"


func _read_central() -> void:
	# O serviço (sky-receber servir) mantém este arquivo na RAM; some quando ele é desligado.
	var txt := _read_text(run_dir + "/central.json", "")
	var d = JSON.parse_string(txt) if txt.begins_with("{") else null
	var on := typeof(d) == TYPE_DICTIONARY and DirAccess.dir_exists_absolute("/proc/%d" % int(d.get("pid", 0)))
	if on:
		central = d
	if on != central_on:
		central_on = on
		_refresh_sys_items()


func _open_receive() -> void:
	if recv_open or not FileAccess.file_exists(SKY_BIN + "/sky-receber"):
		return
	var r := _sky_json("sky-receber", ["ligar"])
	if r.is_empty() or not r.get("ativa", false):
		_toast("Não consegui ligar a Central web", 3.0, "download")
		return
	central = r
	central_on = true
	recv_open = true
	recv_poll = 0.5
	_refresh_sys_items()


func _central_off() -> void:
	_sky_json("sky-receber", ["desligar"])
	central_on = false
	recv_open = false
	_play("back")
	_toast("Central web desligada", 2.5, "download")
	_refresh_sys_items()


func _pipe_reader(pipe: FileAccess, cb: String) -> void:
	# lê a saída de um processo linha a linha (numa thread) e repassa para a tela
	while pipe.is_open():
		var line := pipe.get_line()
		if line == "" and pipe.eof_reached():
			break
		if line != "":
			call_deferred(cb, line)
	call_deferred(cb, "{\"evento\": \"fim\"}")


func _close_receive() -> void:
	recv_open = false
	_play("back")
	_toast("Central web continua ligada em segundo plano", 3.0, "download")


func _run_job(args: Array, title: String) -> void:
	if job_thread != null:
		return
	var info := OS.execute_with_pipe(SKY_BIN + "/sky-jogos", PackedStringArray(args))
	if info.is_empty():
		_toast("Não consegui iniciar", 3.0, "drive")
		return
	busy_msg = title
	job_cancel_hint = args[0] in ["copiar-disco", "compactar", "conferir"]
	job_thread = Thread.new()
	job_thread.start(_pipe_reader.bind(info["stdio"], "_on_job_line"))


func _on_job_line(line: String) -> void:
	var ev = JSON.parse_string(line) if line.begins_with("{") else null
	if typeof(ev) != TYPE_DICTIONARY:
		return
	if ev.has("etapa"):
		busy_msg = str(ev["etapa"]) + "…"
	if ev.has("p"):
		var base := busy_msg.split("  ")[0]
		busy_msg = "%s  %d%%" % [base, int(float(ev["p"]) * 100)]
		if ev.has("v"):   # velocidade e tempo restante (Fase 7.2)
			var falta := int(ev.get("falta", 0))
			busy_msg += "  ·  %.1f MB/s  ·  faltam %s" % [float(ev["v"]) / 1e6,
				("%d min" % int(round(falta / 60.0))) if falta > 90 else ("%d s" % falta)]
	elif ev.has("ok"):
		busy_msg = ""
		if ev["ok"]:
			_toast(str(ev.get("message", "Pronto")), 3.0, "drive")
			_play_file("salvo")
		else:
			_toast(str(ev.get("error", "Erro")), 5.0, "drive")
			_play_file("alerta")
		_reload_games()
		_refresh_status()
	elif str(ev.get("evento", "")) == "fim":
		if job_thread != null:
			job_thread.wait_to_finish()
			job_thread = null
		if busy_msg != "":
			busy_msg = ""


func _draw_receive(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	var r := Rect2(w * 0.12, h * 0.14, w * 0.76, h * 0.72)
	_rrect(r, Color(palette[1].darkened(0.3), 0.94), 22, Color(accent, 0.45), 1)
	var x := r.position.x + 48.0
	var y := r.position.y + 62.0
	_icon("download", Vector2(x + 14, y - 12), 34.0, accent)
	_text("Central web", Vector2(x + 48, y), 26, WHITE, true)
	y += 56.0
	var recv_qr: Array = central.get("qr", []) if typeof(central.get("qr", [])) == TYPE_ARRAY else []
	var recv_ip := str(central.get("ip", ""))
	var recv_cur := str(central.get("recebendo", ""))
	var recv_log: Array = central.get("log", []) if typeof(central.get("log", [])) == TYPE_ARRAY else []
	var tw := r.size.x - 96.0 - (270.0 if not recv_qr.is_empty() else 0.0)
	_text("1.  No celular ou PC (mesmo Wi-Fi), abra:", Vector2(x, y), 18, MUTED, false, tw)
	y += 54.0
	var url := ("http://%s:8080" % recv_ip) if recv_ip != "" else "sem rede: conecte o Wi-Fi em Sistema"
	_text(url, Vector2(x + 24, y), 40 if recv_qr.is_empty() else 32, accent, true, tw - 24)
	y += 54.0
	_text("2.  Digite o PIN:", Vector2(x, y), 18, MUTED)
	_text(str(central.get("pin", "")), Vector2(x + 190, y + 6), 40, WHITE, true)
	y += 48.0
	_text("3.  Pode fechar: ela continua ligada.", Vector2(x, y), 18, MUTED, false, tw)
	y += 46.0
	if recv_cur != "":
		_text("Recebendo:  " + recv_cur, Vector2(x, y), 18, WHITE, false, r.size.x - 96)
		y += 30.0
	for line in recv_log:
		_text(str(line), Vector2(x, y), 16, MUTED, false, r.size.x - 96)
		y += 26.0
	_text("B  fechar (continua ligada)      Y / Menu  desligar a central (o PIN muda ao religar)", Vector2(x, r.end.y - 28), 15, DIM)
	# QR code: aponte a câmera do celular (o PIN já vai junto)
	var n := recv_qr.size()
	if n > 0:
		var side := minf(r.size.y * 0.42, 230.0)
		var cell := floorf(side / n)
		var q0 := Vector2(r.end.x - 48.0 - cell * n, r.position.y + 44.0)
		draw_rect(Rect2(q0 - Vector2(10, 10), Vector2(cell * n + 20, cell * n + 20)), Color.WHITE)
		for iy in n:
			var row := str(recv_qr[iy])
			for ix in row.length():
				if row[ix] == "1":
					draw_rect(Rect2(q0.x + ix * cell, q0.y + iy * cell, cell, cell), Color.BLACK)
		_text("ou aponte a câmera", Vector2(q0.x - 10, q0.y + cell * n + 34), 15, MUTED, false, cell * n + 20,
			HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------- tela Armazenamento (Fase 6.2)

const STORAGE_COLORS := ["#8b7cf6", "#4f8cff", "#b06cf0", "#3fbf6b", "#ffb347", "#54f0b8", "#ff7a9c", "#7d8aa8"]


func _open_storage() -> void:
	var out: Array = []
	if FileAccess.file_exists(SKY_BIN + "/sky-jogos"):
		OS.execute(SKY_BIN + "/sky-jogos", ["uso"], out)
	var d = JSON.parse_string(str(out[0]).strip_edges()) if not out.is_empty() and str(out[0]).begins_with("{") else null
	if typeof(d) != TYPE_DICTIONARY or not d.get("ok", false):
		_refresh_status()
		_toast(disk_detail, 4.0, "drive")
		return
	storage_data = d
	_play("accept")


func _gb(b: float) -> String:
	return ("%.1f GB" % (b / 1e9)) if b >= 1e9 else ("%d MB" % int(b / 1e6))


func _draw_storage(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	var r := Rect2(w * 0.12, h * 0.14, w * 0.76, h * 0.72)
	_rrect(r, Color(palette[1].darkened(0.3), 0.94), 22, Color(accent, 0.45), 1)
	var x := r.position.x + 48.0
	var y := r.position.y + 62.0
	var bw := r.size.x - 96.0
	_icon("drive", Vector2(x + 14, y - 12), 34.0, accent)
	_text("Armazenamento", Vector2(x + 48, y), 26, WHITE, true)
	var total := float(storage_data.get("total", 1))
	var free := float(storage_data.get("livre", 0))
	y += 50.0
	_text("Console:  %s livres de %s" % [_gb(free), _gb(total)], Vector2(x, y), 20, WHITE)
	y += 18.0
	_rrect(Rect2(x, y, bw, 26), Color(1, 1, 1, 0.08), 8)
	var items: Array = storage_data.get("itens", [])
	var px := x
	for i in items.size():
		var seg := bw * float(items[i][1]) / total
		if seg >= 1.0:
			draw_rect(Rect2(px, y, seg, 26), Color.from_string(STORAGE_COLORS[i % STORAGE_COLORS.size()], WHITE))
		px += seg
	y += 58.0
	for i in items.size():
		var col := Color.from_string(STORAGE_COLORS[i % STORAGE_COLORS.size()], WHITE)
		var cx := x + (i % 2) * bw * 0.5
		draw_rect(Rect2(cx, y - 14, 14, 14), col)
		_text("%s   %s" % [str(items[i][0]), _gb(float(items[i][1]))], Vector2(cx + 26, y), 18, MUTED)
		if i % 2 == 1 or i == items.size() - 1:
			y += 32.0
	var sk = storage_data.get("skyroms")
	if typeof(sk) == TYPE_DICTIONARY:
		y += 22.0
		var st := float(sk.get("total", 1))
		var sf := float(sk.get("livre", 0))
		_text("%s:  %s livres de %s%s" % ["HD (pasta SKYROMS)" if skyroms_hd else "Pendrive SKYROMS", _gb(sf), _gb(st),
			"" if skyroms_rw else "  ·  só leitura"], Vector2(x, y), 20, WHITE)
		y += 18.0
		_rrect(Rect2(x, y, bw, 18), Color(1, 1, 1, 0.08), 6)
		draw_rect(Rect2(x, y, bw * (st - sf) / st, 18), accent)
	_text("B  fechar", Vector2(x, r.end.y - 28), 15, DIM)


# ---------------------------------------------------------------- música ambiente

func _make_music() -> void:
	music_on = not FileAccess.file_exists(conf_dir + "/musica.off")
	var path := sounds_dir.path_join("ambiente.ogg")
	if not FileAccess.file_exists(path):
		return
	var st := AudioStreamOggVorbis.load_from_file(path)
	if st == null:
		return
	st.loop = true
	music = AudioStreamPlayer.new()
	music.stream = st
	music.volume_db = -80.0
	add_child(music)


func _tick_music(delta: float) -> void:
	if music == null:
		return
	var want := music_on and running_pid == -1 and intro_t > 2.0 and not dimmed
	var target := -17.0 if want else -60.0
	music.volume_db = move_toward(music.volume_db, target, delta * (12.0 if want else 30.0))
	if want and not music.playing:
		music.play()
	elif not want and music.playing and music.volume_db <= -59.0:
		music.stop()


# ---------------------------------------------------------------- descanso de tela

func _tick_idle(delta: float) -> void:
	if running_pid != -1 or intro_t < INTRO_LEN or busy_msg != "":
		idle_t = 0.0
		return
	idle_t += delta
	dim_t = move_toward(dim_t, 1.0 if dimmed else 0.0, delta * 1.5)
	if not dimmed and idle_t >= IDLE_DIM:
		dimmed = true
		panel_open = false
		slider_kind = ""
		_bg(_run_json.bind(SKY_BIN + "/sky-config", ["brilho", "get"]), _on_dim_brightness)
	var limit := IDLE_OFF_BAT if on_battery else IDLE_OFF_AC
	if dimmed and idle_t >= limit and off_countdown < 0.0:
		off_countdown = 30.0
		_play_file("bateria-baixa")
	if off_countdown >= 0.0:
		off_countdown -= delta
		if off_countdown <= 0.0:
			off_countdown = -1.0
			if on_battery:
				busy_msg = "Desligando por inatividade…"
				OS.execute("systemctl", ["poweroff"])
			else:
				_suspend()   # na tomada: modo de espera (o controle acorda)


func _on_dim_brightness(r: Dictionary) -> void:
	if r.get("ok", false) and dimmed:
		saved_brightness = int(r.get("brilho", -1))
		OS.create_process(SKY_BIN + "/sky-config", ["brilho", "set", "8"])


func _wake() -> void:
	dimmed = false
	idle_t = 0.0
	off_countdown = -1.0
	if saved_brightness > 0:
		OS.create_process(SKY_BIN + "/sky-config", ["brilho", "set", str(saved_brightness)])
		saved_brightness = -1


# ---------------------------------------------------------------- brilho e volume (◀ ▶)

func _open_slider(kind: String) -> void:
	slider_kind = kind
	slider_val = -1
	var args := ["brilho", "get"] if kind == "brilho" else ["volume", "get"]
	_bg(_run_json.bind(SKY_BIN + "/sky-config", args), _on_slider_value.bind(kind))


func _on_slider_value(r: Dictionary, kind: String) -> void:
	if slider_kind != kind:
		return
	if not r.get("ok", false):
		slider_kind = ""
		_toast(str(r.get("error", "Não disponível")), 3.5, "sun" if kind == "brilho" else "sound")
		return
	slider_val = int(r.get(kind, 0))


func _slider_input(delta: float) -> void:
	var d := _nav_dir()
	if d != hold_dir:
		hold_dir = d
		hold_t = 0.3
		if d.x != 0:
			_slider_step(d.x)
	elif d.x != 0:
		hold_t -= delta
		if hold_t <= 0.0:
			hold_t = 0.06
			_slider_step(d.x)
	if Input.is_action_just_pressed("sky_back") or Input.is_action_just_pressed("sky_accept") \
			or Input.is_action_just_pressed("sky_menu"):
		slider_kind = ""
		_play("back")


func _slider_step(dir: int) -> void:
	if slider_val < 0:
		return
	var lo := 5 if slider_kind == "brilho" else 0
	var nv := clampi(slider_val + dir * 5, lo, 100)
	if nv == slider_val:
		return
	slider_val = nv
	_play("tick")
	if slider_kind == "brilho":
		OS.create_process(SKY_BIN + "/sky-config", ["brilho", "set", str(nv)])
	else:
		OS.create_process("wpctl", ["set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "%d%%" % nv])


# ---------------------------------------------------------------- capturas

func _open_viewer() -> void:
	var it := _cur()
	viewer_idx = maxi(0, shots.find(it.get("path", "")))
	_viewer_load()
	viewer_open = viewer_tex != null


func _viewer_load() -> void:
	viewer_tex = null
	if viewer_idx >= 0 and viewer_idx < shots.size():
		var img := Image.load_from_file(str(shots[viewer_idx]))
		if img != null and not img.is_empty():
			viewer_tex = ImageTexture.create_from_image(img)


func _viewer_input() -> void:
	var d := _nav_dir()
	if d != hold_dir:
		hold_dir = d
		if d.x != 0 and shots.size() > 1:
			viewer_idx = wrapi(viewer_idx + d.x, 0, shots.size())
			_viewer_load()
			_play("tick")
	if Input.is_action_just_pressed("sky_back") or Input.is_action_just_pressed("sky_accept"):
		viewer_open = false
		viewer_tex = null
		_play("back")


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
	if viewer_open:
		_draw_viewer(w, h)
	elif recv_open:
		_draw_receive(w, h)
	elif not storage_data.is_empty():
		_draw_storage(w, h)
	else:
		_draw_header(w, h, a)
		_draw_xmb(w, h, a)
		_draw_footer(w, h, a)
		if panel_t > 0.0:
			_draw_panel(w, h)
		if slider_t > 0.0:
			_draw_slider(w, h)
	if toast_t > 0.0:
		var ta: float = clamp(toast_t, 0.0, 1.0) * a
		var icon_w := 34.0 if toast_icon != "" else 0.0
		# avisos longos (erros com código) quebram em linhas em vez de sair da tela
		var maxw := w - 96.0 - 48.0 - icon_w
		var tsz := font.get_multiline_string_size(toast_msg, HORIZONTAL_ALIGNMENT_LEFT, maxw, 18)
		var tw := minf(tsz.x, maxw) + 48.0 + icon_w
		var r := Rect2(w - tw - 48.0, 100, tw, maxf(44.0, tsz.y + 18.0))   # canto superior direito, como as notificações de console
		_rrect(r, Color(0, 0, 0, 0.62 * ta), 22, Color(accent, 0.55 * ta), 1)
		if toast_icon != "":
			_icon(toast_icon, Vector2(r.position.x + 32, r.position.y + 22), 24.0, Color(accent, ta))
		draw_multiline_string(font, Vector2(r.position.x + 24 + icon_w, r.position.y + 29), toast_msg,
			HORIZONTAL_ALIGNMENT_LEFT, maxw, 18, -1, Color(WHITE, ta))
	if dim_t > 0.0:
		_draw_dim(w, h)
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
	if profile_name != "":   # perfil e troféus
		var who := profile_name
		if int(trophies.get("total", 0)) > 0:
			who += "   %d/%d troféus" % [int(trophies.get("ganhos", 0)), int(trophies.get("total", 0))]
		_text(who, Vector2(54, 84), 15, Color(MUTED, a))

	var dt := Time.get_datetime_dict_from_system()
	var clock := "%02d:%02d" % [dt["hour"], dt["minute"]]
	var date := "%s, %d de %s" % [WEEKDAYS[dt["weekday"]], dt["day"], MONTHS[dt["month"] - 1]]
	var cw := font_bold.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_text_shadow(clock, Vector2(w - 56 - cw, 60), 30, Color(WHITE, a), true)
	var dw := font.get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(date, Vector2(w - 56 - dw, 82), 15, Color(MUTED, a))

	# status: bateria, controles (com bateria) e Wi-Fi
	var x := w - 70.0 - maxf(cw, dw) - 30.0
	if bat_cap >= 0:
		var tw := font.get_string_size("%d%%" % bat_cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_text("%d%%" % bat_cap, Vector2(x - tw + 14, 62), 15, Color(WHITE, 0.9 * a))
		_battery(Vector2(x - tw - 30, 49), bat_cap, bat_charging, a)
		x -= tw + 62.0
	if pads > 0:
		_icon("pad", Vector2(x, 50), 30.0, Color(WHITE, 0.85 * a))
		if pads > 1:
			_text(str(pads), Vector2(x + 14, 66), 13, Color(accent, a), true)
		for i in pad_bats.size():  # nível do controle: 4 tracinhos embaixo do ícone
			var cap: int = int(pad_bats[i][0])
			var lvl := clampi(int(ceil(cap / 25.0)), 1, 4)
			for k in 4:
				var col := Color(accent, a) if k < lvl else Color(WHITE, 0.2 * a)
				if cap <= 15 and not pad_bats[i][1]:
					col = Color(Color("ffaa5a"), a) if k < lvl else col
				draw_rect(Rect2(x - 12 + k * 6.5, 68 + i * 6, 5, 3), col)
		x -= 46.0
	if wifi_q >= 0:
		var bars: int = 1 + int(clamp(wifi_q, 0, 70) / 18)
		for i in 4:
			var bh := 6.0 + i * 5.0
			var col := Color(WHITE, 0.9 * a) if i < bars else Color(WHITE, 0.25 * a)
			draw_rect(Rect2(x - 12 + i * 7, 62 - bh, 5, bh), col)
		x -= 46.0
	if central_on:   # Central web ligada em segundo plano
		_icon("download", Vector2(x, 50), 26.0, Color(accent, 0.95 * a))


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
	if it["kind"] == "shot":
		_draw_shot_item(it, c, sel, a)
		return
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
		var gcol: Color = it["color"] if it.get("kind", "") == "action" and it["color"].a > 0.0 else WHITE
		_icon(str(it["glyph"]), c, ih * 0.72, Color(gcol, a * (gcol.a if gcol != WHITE else 1.0)))

	var tx := c.x + maxf(iw, 66.0) / 2.0 + 26.0
	var ts := int(20 + 8 * sel)
	_text_shadow(str(it["title"]), Vector2(tx, c.y + (ts * 0.35 if sel < 0.5 else -4.0)), ts,
		Color(WHITE, a), sel > 0.5, size.x - tx - 60)
	if sel > 0.5 and str(it["sub"]) != "":
		_text(str(it["sub"]), Vector2(tx, c.y + 24), 16, Color(accent.lightened(0.25), a * sel))
	if is_cur and sel > 0.8 and str(it.get("desc", "")) != "" and it["kind"] == "game":
		draw_multiline_string(font, Vector2(tx, c.y + 50), str(it["desc"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 80, 15, 2,
			Color(MUTED, a * sel))


func _draw_shot_item(it: Dictionary, c: Vector2, sel: float, a: float) -> void:
	var ih := 54.0 + 46.0 * sel
	var iw := ih * 16.0 / 9.0
	var r := Rect2(c.x - iw / 2.0, c.y - ih / 2.0, iw, ih)
	if not it.has("thumb"):
		it["thumb"] = null
		var img := Image.load_from_file(str(it["path"]))  # carrega só quando aparece na tela
		if img != null and not img.is_empty():
			img.resize(320, int(320.0 * img.get_height() / max(1, img.get_width())), Image.INTERPOLATE_BILINEAR)
			it["thumb"] = ImageTexture.create_from_image(img)
	if sel > 0.5:
		_glow(c, iw * 0.8, Color(accent, 0.6 * sel * a))
	_rrect(r.grow(2), Color(0, 0, 0, 0.5 * a), 8)
	if it["thumb"] != null:
		_draw_cover(it["thumb"], r, a)
	_rrect(r, Color(0, 0, 0, 0), 7, Color(1, 1, 1, 0.25 * a + 0.4 * sel * a), 2 if sel > 0.5 else 1)
	var tx := c.x + iw / 2.0 + 24.0
	var ts := int(20 + 6 * sel)
	_text_shadow(str(it["title"]), Vector2(tx, c.y + (ts * 0.35 if sel < 0.5 else -4.0)), ts, Color(WHITE, a),
		sel > 0.5, size.x - tx - 60)
	if sel > 0.5:
		_text(str(it["sub"]), Vector2(tx, c.y + 24), 16, Color(accent.lightened(0.25), a * sel))


func _draw_viewer(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.92))
	if viewer_tex != null:
		var ts := viewer_tex.get_size()
		var k: float = minf((w - 80.0) / ts.x, (h - 120.0) / ts.y)
		var sz := ts * k
		draw_texture_rect(viewer_tex, Rect2((w - sz.x) / 2.0, (h - sz.y) / 2.0 - 10.0, sz.x, sz.y), false)
	var name := str(shots[viewer_idx]).get_file().get_basename() if viewer_idx < shots.size() else ""
	var parts := name.split("_")
	var info := "%s  ·  %s   (%d de %d)" % [_shot_title("_".join(parts.slice(0, maxi(1, parts.size() - 1)))),
		_shot_date(parts[-1]), viewer_idx + 1, shots.size()]
	_text(info, Vector2(0, h - 26), 16, MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
	_text("◀ ▶  anterior / próxima      B  voltar      Y (na lista)  apagar", Vector2(0, 34), 14, DIM, false, w,
		HORIZONTAL_ALIGNMENT_CENTER)


func _draw_slider(w: float, h: float) -> void:
	var e := slider_t * slider_t * (3.0 - 2.0 * slider_t)
	var pw := 520.0
	var r := Rect2((w - pw) / 2.0, h - 150.0 + (1.0 - e) * 40.0, pw, 96)
	_rrect(r, Color(palette[1].darkened(0.4), 0.92 * e), 18, Color(accent, 0.5 * e), 1)
	var kind := slider_kind if slider_kind != "" else "volume"
	_icon("sun" if kind == "brilho" else "sound", r.position + Vector2(44, 48), 34.0, Color(WHITE, e))
	_text("Brilho da tela" if kind == "brilho" else "Volume", r.position + Vector2(82, 36), 18, Color(WHITE, e), true)
	var bar := Rect2(r.position.x + 82, r.position.y + 54, pw - 180, 8)
	_rrect(bar, Color(1, 1, 1, 0.15 * e), 4)
	if slider_val >= 0:
		_rrect(Rect2(bar.position, Vector2(bar.size.x * slider_val / 100.0, 8)), Color(accent, e), 4)
		_text("%d%%" % slider_val, Vector2(bar.end.x + 16, bar.position.y + 10), 18, Color(WHITE, e), true)
	_text("◀ ▶ ajustar     A / B  pronto", Vector2(r.position.x, r.end.y + 24), 14, Color(DIM, e), false, pw,
		HORIZONTAL_ALIGNMENT_CENTER)


func _draw_dim(w: float, h: float) -> void:
	# descanso de tela: escurece, mostra só a hora; aperte qualquer botão para voltar
	var e := dim_t
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.78 * e))
	var dt := Time.get_datetime_dict_from_system()
	var clock := "%02d:%02d" % [dt["hour"], dt["minute"]]
	var drift := Vector2(sin(t * 0.05) * 60.0, cos(t * 0.037) * 30.0)   # anda devagar (protege a tela)
	_text(clock, Vector2(0, h / 2.0 + 10) + drift, 72, Color(WHITE, 0.55 * e), true, w, HORIZONTAL_ALIGNMENT_CENTER)
	var date := "%s, %d de %s" % [WEEKDAYS[dt["weekday"]], dt["day"], MONTHS[dt["month"] - 1]]
	_text(date, Vector2(0, h / 2.0 + 46) + drift, 18, Color(MUTED, 0.5 * e), false, w, HORIZONTAL_ALIGNMENT_CENTER)
	if off_countdown >= 0.0:
		_text(("Desligando" if on_battery else "Entrando em modo de espera") +
			" por inatividade em %d s — aperte qualquer botão" % int(ceil(off_countdown)),
			Vector2(0, h - 60), 18, Color(Color("ffaa5a"), e), false, w, HORIZONTAL_ALIGNMENT_CENTER)


func _battery(p: Vector2, cap: int, charging: bool, a: float) -> void:
	var col := Color(WHITE, 0.9 * a)
	_rrect(Rect2(p, Vector2(26, 13)), Color(0, 0, 0, 0), 3, col, 2)
	draw_rect(Rect2(p + Vector2(26, 4), Vector2(3, 5)), col)
	var fill := Color(Color("ffaa5a"), a) if cap <= 15 and not charging else Color(accent, a)
	draw_rect(Rect2(p + Vector2(3, 3), Vector2(20.0 * clampi(cap, 0, 100) / 100.0, 7)), fill)
	if charging:  # raio
		draw_colored_polygon(PackedVector2Array([p + Vector2(14, -2), p + Vector2(8, 7), p + Vector2(13, 7),
			p + Vector2(11, 15), p + Vector2(18, 5), p + Vector2(13, 5)]), Color(WHITE, a))


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
		var sk_txt := "Pendrive de jogos conectado"
		if skyroms_hd:
			sk_txt = "Jogos do HD (SKYROMS)" + ("" if skyroms_rw else " · só leitura")
		_text(sk_txt, Vector2(86, h - 40), 14, Color(MUTED, a))


func _draw_panel(w: float, h: float) -> void:
	var e := panel_t * panel_t * (3.0 - 2.0 * panel_t)
	var pw := 380.0
	var x := w - pw * e
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35 * e))
	draw_texture_rect(side_tex, Rect2(x, 0, pw, h), false, Color(palette[1].darkened(0.35), e))
	draw_line(Vector2(x, 0), Vector2(x, h), Color(accent, 0.35 * e), 1.0)
	# Muitas opções (disco, PS2) ou interface maior na TV: aperta o espaçamento para caber tudo.
	var step := clampf((h * 0.88 - 60.0) / maxf(1.0, panel_items.size()), 40.0, 54.0)
	var y0 := clampf(h * 0.30, 60.0, h - step * panel_items.size() + 10.0)
	for i in panel_items.size():
		var y := y0 + i * step
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
	if job_thread != null and job_cancel_hint and busy_msg != "Cancelando…":
		_text("B  cancelar", Vector2(0, c.y + 108), 15, DIM, false, w, HORIZONTAL_ALIGNMENT_CENTER)


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
		"disc", "disc1", "disc2", "disc3", "discP", "discG", "discW", "discX":
			draw_arc(c, s * 0.42, 0, TAU, 64, col, lw, true)
			draw_arc(c, s * 0.30, -0.6, 0.9, 24, Color(col, col.a * 0.45), lw * 0.6, true)
			draw_circle(c, s * 0.10, col, false, lw * 0.8, true)
			if kind != "disc":
				var n := kind.substr(4)
				draw_circle(c + Vector2(s * 0.30, s * 0.30), s * 0.17, col, true, -1.0, true)
				_text(n, Vector2(c.x + s * 0.30 - s * 0.17, c.y + s * 0.30 + s * 0.09), int(s * 0.24),
					Color(palette[1], 1.0) if not palette.is_empty() else Color.BLACK, true, s * 0.34,
					HORIZONTAL_ALIGNMENT_CENTER)
		"trophy":
			var cup := PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.36), c + Vector2(s * 0.26, -s * 0.36),
				c + Vector2(s * 0.18, s * 0.04), c + Vector2(-s * 0.18, s * 0.04)])
			draw_colored_polygon(cup, col)
			draw_arc(c + Vector2(-s * 0.26, -s * 0.2), s * 0.12, PI * 0.5, PI * 1.5, 12, col, lw, true)
			draw_arc(c + Vector2(s * 0.26, -s * 0.2), s * 0.12, -PI * 0.5, PI * 0.5, 12, col, lw, true)
			draw_rect(Rect2(c.x - s * 0.04, c.y + s * 0.04, s * 0.08, s * 0.2), col)
			draw_rect(Rect2(c.x - s * 0.2, c.y + s * 0.24, s * 0.4, s * 0.1), col)
		"cartS", "cart64", "cartD", "cart3", "cartA", "cartB", "cartN", "cartM":
			_rrect(Rect2(c.x - s * 0.36, c.y - s * 0.40, s * 0.72, s * 0.80), Color(0, 0, 0, 0), 5, col, int(lw))
			draw_line(c + Vector2(-s * 0.22, -s * 0.22), c + Vector2(s * 0.22, -s * 0.22), Color(col, col.a * 0.5), lw)
			var ctxt: String = {"cartS": "S", "cart64": "64", "cartD": "DS", "cart3": "3D", "cartA": "A", "cartB": "GB", "cartN": "N", "cartM": "M"}.get(kind, "")
			_text(ctxt, Vector2(c.x - s * 0.36, c.y + s * 0.24), int(s * 0.34), col, true,
				s * 0.72, HORIZONTAL_ALIGNMENT_CENTER)
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
		"speaker":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.38, -s * 0.13), c + Vector2(-s * 0.2, -s * 0.13),
				c + Vector2(0, -s * 0.33), c + Vector2(0, s * 0.33), c + Vector2(-s * 0.2, s * 0.13),
				c + Vector2(-s * 0.38, s * 0.13)]), col)
			_rrect(Rect2(c.x + s * 0.12, c.y - s * 0.3, s * 0.26, s * 0.6), Color(0, 0, 0, 0), int(s * 0.06), col, int(lw))
		"sun":
			draw_circle(c, s * 0.17, col, true, -1.0, true)
			for i in 8:
				var ang := i * TAU / 8.0
				var dir := Vector2(cos(ang), sin(ang))
				draw_line(c + dir * s * 0.27, c + dir * s * 0.40, col, lw, true)
		"battery":
			_rrect(Rect2(c.x - s * 0.38, c.y - s * 0.18, s * 0.68, s * 0.36), Color(0, 0, 0, 0), int(s * 0.07), col, int(lw))
			draw_rect(Rect2(c.x + s * 0.30, c.y - s * 0.08, s * 0.08, s * 0.16), col)
			draw_rect(Rect2(c.x - s * 0.30, c.y - s * 0.10, s * 0.38, s * 0.20), col)
		"clock":
			draw_arc(c, s * 0.38, 0, TAU, 48, col, lw, true)
			draw_line(c, c + Vector2(0, -s * 0.24), col, lw, true)
			draw_line(c, c + Vector2(s * 0.17, s * 0.06), col, lw, true)
		"camera":
			_rrect(Rect2(c.x - s * 0.42, c.y - s * 0.22, s * 0.84, s * 0.52), Color(0, 0, 0, 0), int(s * 0.1), col, int(lw))
			draw_rect(Rect2(c.x - s * 0.16, c.y - s * 0.32, s * 0.32, s * 0.1), col)
			draw_arc(c + Vector2(0, s * 0.04), s * 0.15, 0, TAU, 32, col, lw, true)
		"usb":
			draw_line(c + Vector2(0, s * 0.38), c + Vector2(0, -s * 0.28), col, lw, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.42), c + Vector2(-s * 0.09, -s * 0.26),
				c + Vector2(s * 0.09, -s * 0.26)]), col)
			draw_line(c + Vector2(0, s * 0.12), c + Vector2(-s * 0.2, -s * 0.02), col, lw, true)
			draw_circle(c + Vector2(-s * 0.2, -s * 0.06), s * 0.06, col, true, -1.0, true)
			draw_line(c + Vector2(0, s * 0.2), c + Vector2(s * 0.2, s * 0.06), col, lw, true)
			draw_rect(Rect2(c.x + s * 0.15, c.y - s * 0.02, s * 0.1, s * 0.1), col)
		"moon":
			draw_circle(c, s * 0.34, col, true, -1.0, true)
			draw_circle(c + Vector2(s * 0.16, -s * 0.12), s * 0.30,
				Color(palette[1], 1.0) if not palette.is_empty() else Color.BLACK, true, -1.0, true)
		"download":
			draw_line(c + Vector2(0, -s * 0.36), c + Vector2(0, s * 0.12), col, lw * 1.2, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, s * 0.0), c + Vector2(s * 0.18, s * 0.0),
				c + Vector2(0, s * 0.22)]), col)
			draw_line(c + Vector2(-s * 0.34, s * 0.34), c + Vector2(s * 0.34, s * 0.34), col, lw * 1.2, true)
		"thermo":
			_rrect(Rect2(c.x - s * 0.08, c.y - s * 0.38, s * 0.16, s * 0.5), Color(0, 0, 0, 0), int(s * 0.08), col, int(lw))
			draw_circle(c + Vector2(0, s * 0.22), s * 0.14, col, true, -1.0, true)
		_:
			draw_circle(c, s * 0.3, col, false, lw, true)
