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
const SECTIONS := ["Wi-Fi", "Bluetooth", "Som", "Sistema", "SkyNetwork"]
const SKY_CLOUD := "/opt/skystation/bin/sky-cloud"
const SKY_PS3 := "/opt/skystation/bin/sky-ps3"
const NET_RAPIDAS := ["Bora jogar?", "Entra aí!", "GG!", "Já volto", "Agora não dá"]

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
var kb_mode: String = "wifi"   # o que o OK do teclado faz: wifi | net_entrar | net_amigo | net_vincular | net_msg

# Fase 10: SkyNetwork
var net_amigo: String = ""     # id do amigo aberto (submenu de mensagens); "" = tela principal
var net_msg: String = ""       # resultado da última ação: continua na tela depois de recarregar a lista
var net_conta_id: String = ""  # Fase 10.5: ID digitado, esperando a senha (criar/entrar na conta)
var net_rpcn_senha: String = ""  # Fase 11.5: senha RPCN digitada, esperando o token
var kb_mascara: bool = false   # teclado mostra • no lugar do texto (senhas)

# Grade de ícones de perfil (como no site): 16 ícones, A escolhe, B volta
var grade_open: bool = false
var grade_sel: int = 0
var grade_lista: Array = []    # [{"id", "nome", "cor"}]
var grade_tex: Dictionary = {}
var grade_atual: String = ""
var acao_pendente: String = ""  # o launcher pediu para abrir direto numa ação (ex.: adicionar amigo)

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
	net_amigo = ""
	net_msg = ""
	cmd_queue.clear()
	joy_prev = _joy_buttons()  # o "A" que abriu esta tela não pode valer aqui
	_load_section()


func abrir_acao(acao: String) -> void:
	# chamado pelo launcher logo depois de open(4): vai direto ao que o jogador escolheu na
	# categoria SkyNetwork do menu (adicionar amigo, criar/entrar na conta, trocar o ícone…)
	column = 1
	acao_pendente = ""
	match acao:
		"net_add", "net_conta_criar", "net_conta_entrar", "net_entrar", "net_conta_senha", "ps3_rpcn":
			_activate_acao({"action": acao})
		"net_icones", "ps3_rpcn_opcoes":
			acao_pendente = acao   # a grade precisa do ícone atual: abre quando o estado chegar


func abrir_amigo(id: String) -> void:
	# chamado pelo launcher logo depois de open(4): abre direto as mensagens daquele amigo
	net_amigo = id
	column = 1


func _close() -> void:
	visible = false
	closed.emit()


# ---------------------------------------------------------------- entrada

func _joy_buttons() -> Dictionary:
	var st := {"up": false, "down": false, "left": false, "right": false,
		"a": false, "b": false, "x": false, "y": false, "start": false,
		"l1": false, "r1": false, "l2": false, "r2": false}
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
		st["l1"] = st["l1"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER)
		st["r1"] = st["r1"] or Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER)
		st["l2"] = st["l2"] or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5
		st["r2"] = st["r2"] or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5
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
			c = "b"
		KEY_BACKSPACE:
			c = "x" if kb_open else "b"
		KEY_Y:
			if not kb_open:
				c = "y"
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
		elif grade_open:
			_grade_command(c)
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
	elif c == "y" and column == 1 and not items.is_empty() and items[item]["action"] == "bt_dev":
		var opts: Dictionary = items[item].duplicate()
		opts["action"] = "bt_opts"
		items[item] = opts
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
		4:
			status = "Consultando a SkyNetwork…"
			_async_net(["estado"], _on_net.bind(4))


func _activate() -> void:
	if items.is_empty():
		return
	_activate_acao(items[item])


func _activate_acao(it: Dictionary) -> void:
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
		"bt_dev":
			# 8.1.3: A num aparelho pareado = conectar/desconectar direto; opções ficam no Triângulo (Y)
			status = ("Desconectando %s…" if it["connected"] else "Conectando %s… (ligue o aparelho)") % it["name"]
			_async(["bt", "disconnect" if it["connected"] else "connect", it["arg"]], _on_result.bind(section))
		"bt_opts":
			var mac: String = it["arg"]
			var nm: String = it["name"]
			items = [
				{"text": "← Voltar à lista", "action": "bt_back"},
				{"text": ("Desconectar  " + nm) if it["connected"] else ("Conectar  " + nm),
					"action": "bt_cmd", "arg": ["disconnect" if it["connected"] else "connect", mac]},
				{"text": "Esquecer este aparelho", "action": "bt_forget", "arg": mac, "name": nm},
			]
			item = 1
			status = nm + "  (" + mac + ")"
		"bt_back":
			_load_section()
		"bt_cmd":
			status = "Aguarde…"
			_async(["bt"] + it["arg"], _on_result.bind(section))
		"bt_forget":
			# confirmação: o mesmo item pede um segundo A
			if it.get("confirm", false):
				status = "Esquecendo %s…" % it["name"]
				_async(["bt", "remove", it["arg"]], _on_result.bind(section))
			else:
				it["confirm"] = true
				it["text"] = "Confirmar: esquecer %s?  (aperte A de novo)" % it["name"]
		"vol_up":
			_set_volume(volume + 10)
		"vol_down":
			_set_volume(volume - 10)
		"vol_mute":
			_async(["volume", "mute"], _on_volume.bind(section))
		"net_entrar":
			_kb_start("Código de convite da SkyNetwork", "")
			kb_mode = "net_entrar"
			kb_shift = true
		"net_add":
			_kb_start("ID SkyNetwork do amigo (ou o código de amigo dele)", "")
			kb_mode = "net_amigo"
		"net_icones":
			_grade_abrir()
		"ps3_rpcn":
			# Fase 11.5: a conta RPCN é criada uma vez no RPCS3 com interface (ele manda o token por
			# e-mail); aqui só digitamos ID, senha e token, nessa ordem
			_kb_start("ID da sua conta RPCN (criada no RPCS3: Configuração > RPCN)", "")
			kb_mode = "rpcn_id"
		"ps3_rpcn_opcoes":
			items = [
				{"text": "← Voltar", "action": "bt_back"},
				{"text": "Trocar a conta RPCN", "action": "ps3_rpcn"},
				{"text": "Desligar o online do PS3 neste console", "action": "ps3_rpcn_sair"},
			]
			item = 1
			status = "Online do PS3 (RPCN)"
			column = 1
		"ps3_rpcn_sair":
			if it.get("confirm", false):
				status = "Desligando…"
				_async_net(["rpcn-sair"], _on_net_result.bind(section), "", SKY_PS3)
			else:
				it["confirm"] = true
				it["text"] = "Confirmar: desligar o online do PS3?  (aperte A de novo)"
		"net_conta_criar", "net_conta_entrar":
			_kb_start(("Escolha o seu ID SkyNetwork: 3 a 16 letras minúsculas, números ou _" if it["action"] == "net_conta_criar"
				else "O seu ID SkyNetwork"), "")
			kb_mode = "net_conta_id_criar" if it["action"] == "net_conta_criar" else "net_conta_id_entrar"
		"net_conta_senha":
			_kb_start("Senha nova da conta (mínimo 6 caracteres)", "")
			kb_mode = "net_conta_senha"
			kb_mascara = true
		"net_vincular":
			_kb_start("Código gerado no outro console (8 letras ou números)", "")
			kb_mode = "net_vincular"
			kb_shift = true
		"net_escrever":
			_kb_start("Mensagem para " + str(it["name"]), str(it["arg"]))
			kb_mode = "net_msg"
		"net_amigo":
			net_amigo = str(it["arg"])
			net_msg = ""
			_load_section()
			column = 1
		"net_voltar":
			net_amigo = ""
			net_msg = ""
			_load_section()
			column = 1
		"net_cmd":
			status = "Aguarde…"
			_async_net(it["arg"], _on_net_result.bind(section))
		"net_confirmar":
			# ações sem volta pedem um segundo A no mesmo item
			if it.get("confirm", false):
				status = "Aguarde…"
				if it.get("voltar", false):
					net_amigo = ""
				_async_net(it["arg"], _on_net_result.bind(section))
			else:
				it["confirm"] = true
				it["text"] = "Confirmar: " + str(it["text"]) + "?  (aperte A de novo)"


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
		if d.get("connected", false):
			t += "   · conectado"
		elif d["paired"]:
			t += "   · pareado"
		# Fase 8.1: aparelho já pareado abre as opções (desconectar, esquecer…); novo vai direto parear
		items.append({"text": t, "action": "bt_dev" if d["paired"] else "bt_pair", "arg": d["mac"],
			"name": str(d["name"]), "connected": d.get("connected", false)})
	status = "%d dispositivo(s)  ·  A conecta/desconecta  ·  Triângulo (Y): opções e esquecer" % (items.size() - 1)
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


# ---------------------------------------------------------------- Fase 10: SkyNetwork

func _nulo(v) -> String:
	return "" if v == null else str(v)


func _on_net(data: Dictionary, sec: int) -> void:
	if sec != section:
		return
	items = []
	status = net_msg
	if acao_pendente == "ps3_rpcn_opcoes":   # vale com ou sem SkyNetwork: o RPCN é outra rede
		acao_pendente = ""
		_activate_acao({"action": "ps3_rpcn_opcoes"})
		return
	if not data.get("ok", false):
		status = str(data.get("error", "Não consegui consultar a SkyNetwork"))
		return
	if not data.get("conectado", false):
		net_amigo = ""
		items.append({"text": "Entrar na SkyNetwork  (digitar o código de convite)", "action": "net_entrar"})
		items.append({"text": "Com a rede você vê o que os amigos jogam, troca mensagens", "action": "info"})
		items.append({"text": "e guarda os saves na nuvem.", "action": "info"})
		if status == "":
			status = str(data.get("error", "Peça o código de convite a quem cuida da rede"))
		return
	var eu: Dictionary = data.get("eu", {})
	var amigos: Array = data.get("amigos", [])
	if net_amigo != "":
		for a in amigos:
			if str(a.get("id", "")) == net_amigo:
				_net_itens_amigo(a)
				return
		net_amigo = ""   # deixou de ser amigo: volta para a tela principal
	if not data.get("online", false):
		items.append({"text": "Sem conexão com a SkyNetwork agora", "action": "info"})
	else:
		var conta: String = _nulo(eu.get("usuario"))
		if conta != "":
			items.append({"text": "%s   ·   Meu ID SkyNetwork:  %s" % [_nulo(eu.get("apelido")), conta], "action": "info"})
		else:
			items.append({"text": "%s   ·   Meu código de amigo:  %s   (crie um ID para ser achado pelo nome)" % [
				_nulo(eu.get("apelido")), _nulo(eu.get("codigo"))], "action": "info"})
		grade_atual = _nulo(eu.get("avatar"))
		items.append({"text": "Ícone do perfil: %s   (A abre a grade)" % _nome_avatar(grade_atual), "action": "net_icones"})
		if conta == "":
			items.append({"text": "Criar conta SkyNetwork  (ID e senha para o site e outros consoles)", "action": "net_conta_criar"})
			items.append({"text": "Já tenho conta: entrar com ID e senha", "action": "net_conta_entrar"})
		else:
			items.append({"text": "Perfil no site:  %s/u/%s" % [str(data.get("url", "")).replace("https://", ""), conta], "action": "info"})
			items.append({"text": "Trocar a senha da conta", "action": "net_conta_senha"})
	for c in data.get("conflitos", []):
		var chave: String = str(c.get("chave", ""))
		items.append({"text": "Conflito em %s: ficar com o save da nuvem (de %s)" % [_nulo(c.get("titulo")), _nulo(c.get("console"))],
			"action": "net_cmd", "arg": ["resolver", chave, "nuvem"]})
		items.append({"text": "Conflito em %s: ficar com o save deste console" % _nulo(c.get("titulo")),
			"action": "net_cmd", "arg": ["resolver", chave, "console"]})
	for p in data.get("pedidos", []):
		var quem: String = _nulo(p.get("de", {}).get("apelido"))
		items.append({"text": "Aceitar o pedido de amizade de " + quem, "action": "net_cmd", "arg": ["aceitar", str(p.get("amizadeId", ""))]})
		items.append({"text": "Recusar o pedido de " + quem, "action": "net_cmd", "arg": ["recusar", str(p.get("amizadeId", ""))]})
	items.append({"text": "Adicionar amigo  (pelo ID SkyNetwork ou código dele)", "action": "net_add"})
	for a in amigos:
		var sit: String = _nulo(a.get("status"))
		var txt: String = "Offline"
		if sit == "jogando":
			txt = "Jogando " + _nulo(a.get("jogo"))
		elif sit == "online":
			txt = "Online"
		elif sit == "ausente":
			txt = "Ausente"
		items.append({"text": "%s   ·   %s" % [_nulo(a.get("apelido")), txt], "action": "net_amigo", "arg": str(a.get("id", ""))})
	for p in data.get("enviados", []):
		items.append({"text": "Pedido enviado para %s (aguardando)" % _nulo(p.get("para", {}).get("apelido")), "action": "info"})
	var inv: bool = eu.get("invisivel", false)
	items.append({"text": "Invisível: " + ("ligado  (os amigos veem você offline)" if inv else "desligado"),
		"action": "net_cmd", "arg": ["invisivel", "off" if inv else "on"]})
	var nuvem: bool = data.get("nuvem", true)
	items.append({"text": "Saves na nuvem: " + ("ligados" if nuvem else "desligados"),
		"action": "net_cmd", "arg": ["nuvem", "off" if nuvem else "on"]})
	var pend: int = int(data.get("pendentes", 0))
	if pend > 0:
		items.append({"text": "%d save(s) esperando a internet para subir" % pend, "action": "info"})
	if data.get("vinculado", false):
		items.append({"text": "Desvincular: este perfil volta a ser só deste console", "action": "net_confirmar", "arg": ["desvincular"]})
	else:
		items.append({"text": "Usar este perfil em outro console  (gerar código)", "action": "net_cmd", "arg": ["codigo-vinculo"]})
		items.append({"text": "Já tenho perfil em outro console  (digitar o código)", "action": "net_vincular"})
	items.append({"text": "Sair da SkyNetwork neste console", "action": "net_confirmar", "arg": ["sair"]})
	item = clamp(item, 0, items.size() - 1)
	if acao_pendente == "net_icones":
		acao_pendente = ""
		_grade_abrir()


func _net_itens_amigo(a: Dictionary) -> void:
	var id: String = str(a.get("id", ""))
	var nome: String = _nulo(a.get("apelido"))
	items = [{"text": "← Voltar à SkyNetwork", "action": "net_voltar"}]
	for m in NET_RAPIDAS:
		items.append({"text": "Enviar:  " + m, "action": "net_cmd", "arg": ["mensagem", id, m]})
	items.append({"text": "Escrever mensagem…", "action": "net_escrever", "arg": id, "name": nome})
	items.append({"text": "Desfazer a amizade com " + nome, "action": "net_confirmar", "voltar": true,
		"arg": ["recusar", str(a.get("amizadeId", ""))]})
	item = clamp(item, 1, items.size() - 1)
	# as mensagens que ele mandou (o sky-net guarda as recentes no net.json) aparecem na linha de baixo
	var recebidas: PackedStringArray = PackedStringArray()
	var arq: String = OS.get_environment("XDG_RUNTIME_DIR") + "/skystation/net.json"
	var net = JSON.parse_string(FileAccess.get_file_as_string(arq)) if FileAccess.file_exists(arq) else null
	if typeof(net) == TYPE_DICTIONARY:
		for m in net.get("mensagens", []):
			if typeof(m) == TYPE_DICTIONARY and str(m.get("de", {}).get("id", "")) == id:
				recebidas.append(_nulo(m.get("texto")))
	if status == "":
		if recebidas.is_empty():
			status = "Conversa com " + nome
		else:
			status = nome + ":  " + "   |   ".join(recebidas.slice(max(0, recebidas.size() - 3)))
			_async_net(["lidas", id], _on_net_quieto)


func _nome_avatar(id: String) -> String:
	var lista = JSON.parse_string(FileAccess.get_file_as_string("/opt/skystation/avatares/avatares.json")) \
		if FileAccess.file_exists("/opt/skystation/avatares/avatares.json") else null
	if typeof(lista) == TYPE_ARRAY:
		for a in lista:
			if typeof(a) == TYPE_DICTIONARY and str(a.get("id", "")) == id:
				return str(a.get("nome", id))
	return id if id != "" else "Estrela cadente"


func _on_net_quieto(_data: Dictionary) -> void:
	pass


func _on_net_result(data: Dictionary, sec: int) -> void:
	net_msg = str(data.get("message", "Pronto")) if data.get("ok", false) else str(data.get("error", "Falhou"))
	status = net_msg
	if sec == section:
		var onde := item
		_load_section()
		item = onde
		status = net_msg


func _async_net(args: Array, cb: Callable, senha: String = "", prog: String = SKY_CLOUD) -> void:
	var th := Thread.new()
	threads.append(th)
	th.start(_worker_net.bind(args, cb, th, senha, prog))


func _worker_net(args: Array, cb: Callable, th: Thread, senha: String = "", prog: String = SKY_CLOUD) -> void:
	var output := []
	var code: int
	if senha != "":
		# a senha vai por variável de ambiente (na linha de comando qualquer programa a veria)
		code = OS.execute("/usr/bin/env", PackedStringArray(["SKY_SENHA=" + senha, prog] + args), output, false)
	else:
		code = OS.execute(prog, PackedStringArray(args), output, false)
	var data = null
	if output.size() > 0:
		var linhas: PackedStringArray = str(output[0]).strip_edges().split("\n")
		data = JSON.parse_string(linhas[linhas.size() - 1])
	if typeof(data) != TYPE_DICTIONARY:
		data = {"ok": false, "error": "a SkyNetwork não respondeu (código %d)" % code}
	call_deferred("_finish", th, cb, data)


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


# ---------------------------------------------------------------- grade de ícones de perfil

func _grade_abrir() -> void:
	var lista = JSON.parse_string(FileAccess.get_file_as_string("/opt/skystation/avatares/avatares.json")) \
		if FileAccess.file_exists("/opt/skystation/avatares/avatares.json") else null
	grade_lista = lista if typeof(lista) == TYPE_ARRAY else []
	if grade_lista.is_empty():
		status = "Não achei os ícones de perfil (atualize o SkyStation)"
		return
	grade_sel = 0
	for i in grade_lista.size():
		if str(grade_lista[i].get("id", "")) == grade_atual:
			grade_sel = i
	grade_open = true


func _grade_tex(id: String) -> Texture2D:
	if not grade_tex.has(id):
		var tex: Texture2D = null
		var path := "/opt/skystation/avatares/%s.png" % id
		if id.is_valid_identifier() and FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
		grade_tex[id] = tex
	return grade_tex[id]


const GRADE_COLS := 8


func _grade_command(c: String) -> void:
	var n := grade_lista.size()
	match c:
		"left":
			grade_sel = max(0, grade_sel - 1)
		"right":
			grade_sel = min(n - 1, grade_sel + 1)
		"up":
			if grade_sel >= GRADE_COLS:
				grade_sel -= GRADE_COLS
		"down":
			grade_sel = min(n - 1, grade_sel + GRADE_COLS)
		"a", "start":
			var id := str(grade_lista[grade_sel].get("id", ""))
			grade_open = false
			if id != "" and id != grade_atual:
				grade_atual = id
				status = "Trocando o ícone…"
				_async_net(["icone", id], _on_net_result.bind(section))
		"b", "y":
			grade_open = false


func _draw_grade() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))
	var cel := 116.0
	var gap := 18.0
	var cols := GRADE_COLS
	var rows := int(ceil(grade_lista.size() / float(cols)))
	var gw := cols * cel + (cols - 1) * gap
	var x0 := (w - gw) / 2.0
	var y0 := (h - rows * (cel + gap)) / 2.0 + 10.0
	_text("Ícone do perfil", Vector2(x0, y0 - 64), 30, WHITE)
	var nome := str(grade_lista[grade_sel].get("nome", "")) if grade_sel < grade_lista.size() else ""
	_text(nome, Vector2(x0, y0 - 26), 20, CYAN, gw)
	for i in grade_lista.size():
		var r := Rect2(x0 + (i % cols) * (cel + gap), y0 + int(i / cols) * (cel + gap), cel, cel)
		var id := str(grade_lista[i].get("id", ""))
		var on := i == grade_sel
		if on:
			draw_rect(r.grow(7), Color(CYAN, 0.9))
		elif id == grade_atual:
			draw_rect(r.grow(4), Color(WHITE, 0.35))
		var tex := _grade_tex(id)
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			draw_rect(r, Color.from_string(str(grade_lista[i].get("cor", "#4fd1ff")), CYAN))
	_text("Direcional  escolher      ✕  usar este ícone      ○  voltar", Vector2(x0, y0 + rows * (cel + gap) + 30), 16, DIM)


# ---------------------------------------------------------------- teclado virtual

func _kb_start(title: String, ssid: String) -> void:
	kb_open = true
	kb_text = ""
	kb_title = title
	kb_ssid = ssid
	kb_mode = "wifi"
	kb_mascara = false
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
		# como no PS4/PS5: ✕ digita, □ apaga, △ símbolos, ○ cancela, R2 (ou Options) conclui,
		# L2 maiúsculas, R1 espaço
		"a":
			_kb_press()
		"x", "l1":
			kb_text = kb_text.substr(0, max(0, kb_text.length() - 1))
		"y":
			kb_symbols = not kb_symbols
		"l2":
			kb_shift = not kb_shift
		"r1":
			kb_text += " "
		"start", "r2":
			_kb_ok()
		"b":
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
	var modo: String = kb_mode
	var texto: String = kb_text.strip_edges()
	match modo:
		"net_entrar":
			status = "Entrando na SkyNetwork…"
			_async_net(["entrar", texto], _on_net_result.bind(section))
		"net_amigo":
			status = "Procurando o jogador…"
			_async_net(["amigo", texto], _on_net_result.bind(section))
		"net_vincular":
			status = "Vinculando o perfil…"
			_async_net(["vincular", texto], _on_net_result.bind(section))
		"net_msg":
			if texto != "":
				status = "Enviando…"
				_async_net(["mensagem", kb_ssid, texto], _on_net_result.bind(section))
		"net_conta_id_criar", "net_conta_id_entrar":
			if texto == "":
				return
			net_conta_id = texto.to_lower()
			var criar: bool = modo == "net_conta_id_criar"
			_kb_start(("Crie uma senha para @%s (mínimo 6 caracteres)" if criar else "Senha da conta @%s") % net_conta_id, "")
			kb_mode = "net_conta_criar" if criar else "net_conta_entrar"
			kb_mascara = true
		"net_conta_criar", "net_conta_entrar":
			status = "Criando a conta…" if modo == "net_conta_criar" else "Entrando na conta…"
			_async_net(["conta-criar" if modo == "net_conta_criar" else "conta-entrar", net_conta_id],
				_on_net_result.bind(section), kb_text)
		"rpcn_id":
			if texto == "":
				return
			net_conta_id = texto
			_kb_start("Senha da conta RPCN %s" % texto, "")
			kb_mode = "rpcn_senha"
			kb_mascara = true
		"rpcn_senha":
			if kb_text == "":
				return
			net_rpcn_senha = kb_text
			_kb_start("Token da conta RPCN (16 letras e números que chegaram por e-mail)", "")
			kb_mode = "rpcn_token"
			kb_shift = true
		"rpcn_token":
			status = "Ligando o online do PS3…"
			_async_net(["rpcn-entrar", net_conta_id, texto], _on_net_result.bind(section), net_rpcn_senha, SKY_PS3)
			net_rpcn_senha = ""
		"net_conta_senha":
			status = "Trocando a senha…"
			_async_net(["conta-senha"], _on_net_result.bind(section), kb_text)
		_:
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
	var dica := "Direcional  navegar      A  escolher      B  voltar"
	if section == 4 and column == 1 and net_amigo == "" and not items.is_empty() and items[item]["action"] == "net_amigo":
		dica = "A  mensagens e opções deste amigo      B  voltar"
	if section == 1 and column == 1 and not items.is_empty() and items[item]["action"] == "bt_dev":
		dica = "A  conectar/desconectar      Triângulo (Y)  opções e esquecer      B  voltar"
	_text(dica, Vector2(48, h - 44), 16, DIM)

	if kb_open:
		_draw_keyboard()
	elif grade_open:
		_draw_grade()


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
	_text(("•".repeat(kb_text.length()) if kb_mascara else kb_text) + "_", Vector2(x0 + 20, y0 - 44), 28, WHITE, total_w - 40)

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
	_text("✕ digitar    □ apagar    △ símbolos    L2 maiúsculas    R1 espaço    R2 concluir    ○ cancelar",
		Vector2(x0, y0 + 5 * (kh + gap) + 22), 15, MUTED, total_w)
