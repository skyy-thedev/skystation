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
const SECTIONS := ["Wi-Fi", "Bluetooth", "Som", "Sistema", "SkyNetwork", "Usuários"]
const SECTION_DESC := ["Redes sem fio e conexão com a internet", "Parear controles, fones e outros aparelhos",
	"Volume do sistema", "Hardware, versão e armazenamento", "Conta, amigos, mensagens, saves na nuvem e online",
	"Criar, trocar, renomear e excluir usuários; entrar automaticamente; ID SkyNetwork de cada um"]
const SECAO_USUARIOS := 5
const SKY_PERFIS := "/opt/skystation/bin/sky-perfis"
const SKY_CLOUD := "/opt/skystation/bin/sky-cloud"
const SKY_PS3 := "/opt/skystation/bin/sky-ps3"
const NET_RAPIDAS := ["Bora jogar?", "Entra aí!", "GG!", "Já volto", "Agora não dá"]

const KB_LETTERS := ["1234567890", "qwertyuiop", "asdfghjkl@", "zxcvbnm.-_"]
const KB_SYMBOLS := ["1234567890", "!#$%&*()+=", "[]{}<>/\\|~", ";:'\",.?`^-"]
const KB_SPECIAL := ["Maiúsc", "Símbolos", "Espaço", "Apagar", "OK"]

var section: int = 0
var column: int = 0  # 0 = lista de seções, 1 = itens da seção
var direto: bool = false  # aberto por um item do menu: ○ fecha em vez de voltar à lista de seções
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
var net_perfil_alvo: String = ""  # 13.21: login do Jogador 2 (o perfil dele, não o perfil em uso)
var net_alvo_dupla: bool = true    # 13.24: false = só ligar a conta ao usuário (tela Usuários)
var usr_sel: String = ""           # 13.24: usuário aberto na tela Usuários ("" = a lista)
var grade_usr: String = ""         # 13.24: a grade de ícones está escolhendo o ícone deste usuário
var usr_sel_nome: String = ""

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
	direto = false
	if start_section >= 0 and start_section < SECTIONS.size():
		section = start_section
		# como no PS3: o item do menu abre direto a tela dele, e ○ volta ao menu
		column = 1
		direto = true
	kb_open = false
	net_amigo = ""
	net_msg = ""
	net_perfil_alvo = ""
	net_alvo_dupla = true
	usr_sel = ""
	grade_usr = ""
	cmd_queue.clear()
	joy_prev = _joy_buttons()  # o "A" que abriu esta tela não pode valer aqui
	_load_section()


func abrir_acao(acao: String) -> void:
	# chamado pelo launcher logo depois de open(4): vai direto ao que o jogador escolheu na
	# categoria SkyNetwork do menu (adicionar amigo, criar/entrar na conta, trocar o ícone…)
	column = 1
	acao_pendente = ""
	if acao.begins_with("usr_abrir:"):   # 13.24: o launcher abre direto num usuário (ex.: recém-criado)
		usr_sel = acao.substr(10)
		_load_section()
		column = 1
		if acao_pendente == "" and usr_sel != "":
			_kb_start("Nome do usuário", "")
			kb_mode = "usr_nome"
		return
	if acao.begins_with("net_conta_entrar_j2:"):   # 13.21: "Quem vai jogar?" → Jogador 2 entra com o ID dele
		net_perfil_alvo = acao.substr(20)
		net_alvo_dupla = true
		_kb_start("Jogador 2: o seu ID SkyNetwork", "")
		kb_mode = "net_conta_id_entrar"
		return
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
	elif c == "a":
		_activate()
	elif c == "y" and column == 1 and not items.is_empty() and items[item]["action"] == "bt_dev":
		var opts: Dictionary = items[item].duplicate()
		opts["action"] = "bt_opts"
		items[item] = opts
		_activate()
	elif c == "b":
		if column == 1 and section == SECAO_USUARIOS and usr_sel != "":
			usr_sel = ""
			_load_section()
		elif column == 1 and net_amigo != "":
			_activate_acao({"action": "net_voltar"})
		elif column == 1 and not items.is_empty() and items[0]["action"] == "bt_back":
			_load_section()   # sub-tela (opções do aparelho, online do PS3): volta à lista da seção
		elif column == 1 and not direto:
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
		SECAO_USUARIOS:
			_usr_itens()


func _activate() -> void:
	if items.is_empty():
		return
	_activate_acao(items[item])


func _activate_acao(it: Dictionary) -> void:
	if str(it["action"]).begins_with("usr_") and _usr_acao(it):
		return
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
				it["text"] = "Confirmar: esquecer %s?  (confirme de novo)" % it["name"]
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
				it["text"] = "Confirmar: desligar o online do PS3?  (confirme de novo)"
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
				it["text"] = "Confirmar: " + str(it["text"]) + "?  (confirme de novo)"


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
		items.append({"text": "Ícone do perfil: %s" % _nome_avatar(grade_atual), "action": "net_icones"})
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
	items = [{"text": "← Voltar à SkyNetwork", "action": "net_voltar", "titulo": nome}]
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


func _async_net(args: Array, cb: Callable, senha: String = "", prog: String = SKY_CLOUD, env: Array = []) -> void:
	var th := Thread.new()
	threads.append(th)
	th.start(_worker_net.bind(args, cb, th, senha, prog, env))


func _worker_net(args: Array, cb: Callable, th: Thread, senha: String = "", prog: String = SKY_CLOUD, env: Array = []) -> void:
	var output := []
	var code: int
	if senha != "" or not env.is_empty():
		# a senha vai por variável de ambiente (na linha de comando qualquer programa a veria)
		var pre: Array = env.duplicate()
		if senha != "":
			pre.append("SKY_SENHA=" + senha)
		code = OS.execute("/usr/bin/env", PackedStringArray(pre + [prog] + args), output, false)
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
			if grade_usr != "":   # 13.24: ícone de um usuário (e da conta SkyNetwork dele, se tiver)
				var alvo := grade_usr
				grade_usr = ""
				if id != "":
					var d := _usr_cmd(["icone", alvo, id], "Ícone trocado")
					for p in d.get("perfis", []):
						if str(p.get("id", "")) == alvo and _nulo(p.get("usuario")) != "":
							_async_net(["icone", id], _on_usr_result.bind(section), "", SKY_CLOUD, ["SKY_PERFIL=" + alvo])
				return
			if id != "" and id != grade_atual:
				grade_atual = id
				status = "Trocando o ícone…"
				_async_net(["icone", id], _on_net_result.bind(section))
		"b", "y":
			grade_open = false
			grade_usr = ""


func _draw_grade() -> void:
	var w := size.x
	var h := size.y
	var cols := GRADE_COLS
	var rows := int(ceil(grade_lista.size() / float(cols)))
	var gap := 18.0
	var cel: float = min(116.0, (h * 0.76 - 120 - (rows - 1) * gap) / max(1, rows))
	var gw := cols * cel + (cols - 1) * gap
	var x0 := (w - gw) / 2.0
	var y0 := h * 0.115 + 80.0
	var nome := str(grade_lista[grade_sel].get("nome", "")) if grade_sel < grade_lista.size() else ""
	_text(nome, Vector2(0, y0 - 30), 20, WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
	for i in grade_lista.size():
		var r := Rect2(x0 + (i % cols) * (cel + gap), y0 + int(i / cols) * (cel + gap), cel, cel)
		var id := str(grade_lista[i].get("id", ""))
		var on := i == grade_sel
		if on:
			draw_rect(r.grow(8), Color(CYAN.lerp(WHITE, 0.4), 0.35))
			draw_rect(r.grow(6), Color(WHITE, 0.95), false, 2.5)
		elif id == grade_atual:
			draw_rect(r.grow(4), Color(WHITE, 0.35), false, 1.5)
		var tex := _grade_tex(id)
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			draw_rect(r, Color.from_string(str(grade_lista[i].get("cor", "#4fd1ff")), CYAN))


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
			var extra: Array = []
			if net_perfil_alvo != "" and modo == "net_conta_entrar":
				extra = ["SKY_PERFIL=" + net_perfil_alvo]
				if net_alvo_dupla:
					extra.append("SKY_DUPLA=1")
			_async_net(["conta-criar" if modo == "net_conta_criar" else "conta-entrar", net_conta_id],
				_on_net_result.bind(section), kb_text, SKY_CLOUD, extra)
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
		"usr_nome":
			if texto != "" and usr_sel != "":
				_usr_cmd(["renomear", usr_sel, texto.substr(0, 20)], "Nome trocado")
		"usr_criar":
			var d := _usr_cmd(["criar", texto.substr(0, 20)], "Usuário criado")
			var lst: Array = d.get("perfis", [])
			if d.get("ok", false) and not lst.is_empty():
				usr_sel = str(lst[lst.size() - 1].get("id", ""))
				_usr_itens()
		_:
			_wifi_connect(kb_ssid, kb_text)


# ---------------------------------------------------------------- desenho

func _text(t: String, pos: Vector2, fsize: int, color: Color, width: float = -1.0,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, pos, t, align, width, fsize, color)


func _draw() -> void:
	# Fase 11.6: telas no padrão do PS3: o fundo de ondas inteiro, título no alto com uma linha fina,
	# lista no centro com a faixa de brilho no item escolhido e os botões do controle no rodapé
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.30))
	var titulo := "Configurações"
	if column == 1:
		titulo = SECTIONS[section]
		if section == 4 and net_amigo != "" and not items.is_empty():
			titulo = "SkyNetwork  ›  " + str(items[0].get("titulo", "Amigo"))
		if section == SECAO_USUARIOS and usr_sel != "":
			titulo = "Usuários  ›  " + usr_sel_nome
	var dicas := [["cruz", "Confirmar"], ["bola", "Voltar"]]
	if column == 1 and not items.is_empty() and items[item]["action"] == "bt_dev":
		dicas = [["cruz", "Conectar / desconectar"], ["triangulo", "Opções"], ["bola", "Voltar"]]
	if kb_open:
		titulo = "Teclado"
		dicas = [["cruz", "Digitar"], ["quadrado", "Apagar"], ["triangulo", "Símbolos"], ["L2", "Maiúsculas"],
			["R1", "Espaço"], ["R2", "Concluir"], ["bola", "Cancelar"]]
	elif grade_open:
		titulo = "Ícone do perfil"
		dicas = [["cruz", "Usar este ícone"], ["bola", "Voltar"]]
	_moldura(titulo, dicas)

	if kb_open:
		_draw_keyboard()
		return
	if grade_open:
		_draw_grade()
		return

	var lista: Array = []
	var sel := item
	if column == 0:
		for s in SECTIONS:
			lista.append({"text": s, "action": "secao"})
		sel = section
	else:
		lista = items
	_draw_lista(lista, sel)

	var st := status
	if not threads.is_empty():
		st = "Aguarde…  " + st
	if column == 0:
		st = SECTION_DESC[section]
	_text(st, Vector2(0, h * 0.875 - 22), 17, Color(WHITE, 0.7), w, HORIZONTAL_ALIGNMENT_CENTER)


func _moldura(titulo: String, dicas: Array) -> void:
	var w := size.x
	var h := size.y
	var m := w * 0.045
	var topo := h * 0.115
	var base := h * 0.875
	# ícone pequeno antes do título, como as telas de ajuste do PS3
	var c := Vector2(m + 10, topo - 22)
	draw_arc(c, 9, 0, TAU, 28, Color(WHITE, 0.85), 1.6, true)
	draw_circle(c, 3.0, Color(WHITE, 0.85))
	_text(titulo, Vector2(m + 30, topo - 14), 22, WHITE)
	draw_line(Vector2(m - 14, topo), Vector2(w - m + 14, topo), Color(WHITE, 0.55), 1.4, true)
	draw_line(Vector2(m - 14, base), Vector2(w - m + 14, base), Color(WHITE, 0.55), 1.4, true)
	# botões espalhados pelo rodapé (no PS3: à esquerda, no meio e à direita)
	var n := dicas.size()
	var larg: float = (w - 2 * m) / maxi(1, n)
	for i in n:
		var d: Array = dicas[i]
		var tw := font.get_string_size(str(d[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 30.0
		var x: float = m + i * larg
		if n > 1 and n <= 3:
			x = m + (w - 2 * m - tw) * i / float(n - 1)
		var y := base + 34
		_botao(str(d[0]), Vector2(x + 9, y - 6))
		_text(str(d[1]), Vector2(x + 26, y), 16, Color(WHITE, 0.85))


func _botao(qual: String, c: Vector2) -> void:
	# os símbolos do controle desenhados à mão (a fonte padrão não tem ✕ ○ □ △)
	var cor := Color(WHITE, 0.9)
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
			_text(qual, c + Vector2(-9, 5), 13, cor)


func _draw_lista(lista: Array, sel: int) -> void:
	var w := size.x
	var h := size.y
	var topo := h * 0.115
	var base := h * 0.875
	var rh := 50.0
	var area := base - topo - 90.0
	var cabe := maxi(1, int(area / rh))
	var first: int = clamp(sel - cabe + 1, 0, max(0, lista.size() - cabe))
	var n: int = min(cabe, lista.size() - first)
	var y0: float = topo + 40.0 + max(0.0, (area - n * rh) / 2.0)
	var x0 := w * 0.22
	var x1 := w * 0.78
	for k in n:
		var i := first + k
		var it: Dictionary = lista[i]
		var y := y0 + k * rh
		var on := i == sel
		var info: bool = it["action"] == "info"
		if on:
			_faixa(Rect2(x0 - 60, y, x1 - x0 + 120, rh - 6))
		var tam := 22 if on else (18 if info else 20)
		var cor := WHITE if on else (Color(WHITE, 0.5) if info else Color(WHITE, 0.78))
		var txt := str(it["text"])
		# "Nome: valor" vira duas colunas, como as listas de ajustes do PS3
		var dois := txt.find(": ")
		if dois > 0 and dois < 28 and not info and not txt.begins_with("Confirmar") and not txt.contains("http"):
			var xv := x0 + (x1 - x0) * 0.58
			_text(txt.substr(0, dois), Vector2(x0, y + rh * 0.62), tam, cor, xv - x0 - 20)
			_text(txt.substr(dois + 2).strip_edges(), Vector2(xv, y + rh * 0.62), tam, cor.lerp(Color(CYAN.lerp(WHITE, 0.55), cor.a), 0.6), x1 - xv)
		else:
			_text(txt, Vector2(x0, y + rh * 0.62), tam, cor, x1 - x0)
	# setas quando a lista continua acima ou abaixo
	var cx := w / 2.0
	if first > 0:
		draw_polyline(PackedVector2Array([Vector2(cx - 9, y0 - 8), Vector2(cx, y0 - 16), Vector2(cx + 9, y0 - 8)]), Color(WHITE, 0.6), 2.0, true)
	if first + n < lista.size():
		var yb := y0 + n * rh + 6
		draw_polyline(PackedVector2Array([Vector2(cx - 9, yb), Vector2(cx, yb + 8), Vector2(cx + 9, yb)]), Color(WHITE, 0.6), 2.0, true)


func _faixa(r: Rect2) -> void:
	# o brilho do item escolhido: some nas pontas, com fios finos em cima e embaixo
	var meio := r.position.x + r.size.x / 2.0
	var a := Color(WHITE, 0.0)
	var b := Color(WHITE, 0.16)
	var t := r.position.y
	var u := r.end.y
	draw_polygon(PackedVector2Array([Vector2(r.position.x, t), Vector2(meio, t), Vector2(meio, u), Vector2(r.position.x, u)]),
		PackedColorArray([a, b, b, a]))
	draw_polygon(PackedVector2Array([Vector2(meio, t), Vector2(r.end.x, t), Vector2(r.end.x, u), Vector2(meio, u)]),
		PackedColorArray([b, a, a, b]))
	var la := Color(CYAN, 0.0)
	var lb := Color(CYAN.lerp(WHITE, 0.5), 0.7)
	for yy in [t, u]:
		draw_polyline_colors(PackedVector2Array([Vector2(r.position.x, yy), Vector2(meio, yy), Vector2(r.end.x, yy)]),
			PackedColorArray([la, lb, la]), 1.2, true)


func _draw_keyboard() -> void:
	var w := size.x
	var h := size.y
	var kw := 64.0
	var kh := 52.0
	var gap := 8.0
	var total_w := 10 * kw + 9 * gap
	var x0 := (w - total_w) / 2.0
	var y0 := h * 0.875 - (5 * kh + 4 * gap) - 40
	_text(kb_title, Vector2(0, h * 0.115 + 56), 18, Color(WHITE, 0.75), w, HORIZONTAL_ALIGNMENT_CENTER)
	# campo de texto: faixa clara com o cursor, como o teclado do PS3
	var campo := Rect2(x0, h * 0.115 + 76, total_w, 56)
	draw_rect(campo, Color(WHITE, 0.10))
	draw_rect(campo, Color(WHITE, 0.45), false, 1.2)
	_text(("•".repeat(kb_text.length()) if kb_mascara else kb_text) + "_", campo.position + Vector2(18, 38), 26, WHITE, total_w - 36)

	var rows := _kb_rows()
	for r in 4:
		for c in 10:
			var rect := Rect2(x0 + c * (kw + gap), y0 + r * (kh + gap), kw, kh)
			var on := kb_row == r and kb_col == c
			_tecla(rect, on)
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
		_tecla(rect, on)
		_text(label, rect.position + Vector2(0, kh * 0.66), 18, INK if on else WHITE, rect.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)


func _tecla(r: Rect2, on: bool) -> void:
	if on:
		draw_rect(r.grow(2), Color(CYAN.lerp(WHITE, 0.4), 0.5))
		draw_rect(r, Color(WHITE, 0.92))
	else:
		draw_rect(r, Color(WHITE, 0.08))
		draw_rect(r, Color(WHITE, 0.28), false, 1.0)


# ---------------------------------------------------------------- 13.24: Usuários (como no PS4)

func _usr_cmd(args: Array, ok_msg: String = "") -> Dictionary:
	var out := []
	OS.execute(SKY_PERFIS, PackedStringArray(args), out)
	var d = JSON.parse_string(str(out[0]).strip_edges()) if not out.is_empty() and str(out[0]).begins_with("{") else null
	if typeof(d) != TYPE_DICTIONARY:
		status = "Não consegui ler os usuários"
		return {}
	if d.has("error"):
		status = str(d["error"])
	elif ok_msg != "":
		status = ok_msg
	if section == SECAO_USUARIOS and column == 1:
		var onde := item
		_usr_itens(d)
		item = clampi(onde, 0, maxi(0, items.size() - 1))
	return d


func _on_usr_result(data: Dictionary, sec: int) -> void:
	status = str(data.get("message", "Pronto")) if data.get("ok", false) else str(data.get("error", "Falhou"))
	if sec == SECAO_USUARIOS and section == SECAO_USUARIOS:
		var onde := item
		_usr_itens()
		item = clampi(onde, 0, maxi(0, items.size() - 1))


func _usr_itens(d: Dictionary = {}) -> void:
	if d.is_empty() or not d.has("perfis"):
		var out := []
		OS.execute(SKY_PERFIS, PackedStringArray(["listar"]), out)
		var lido = JSON.parse_string(str(out[0]).strip_edges()) if not out.is_empty() and str(out[0]).begins_with("{") else null
		d = lido if typeof(lido) == TYPE_DICTIONARY else {}
	items = []
	var atual := _nulo(d.get("atual"))
	var auto := _nulo(d.get("auto"))
	var lst: Array = d.get("perfis", [])
	var p: Dictionary = {}
	for x in lst:
		if str(x.get("id", "")) == usr_sel:
			p = x
	if usr_sel == "" or p.is_empty():
		usr_sel = ""
		for x in lst:
			var u := _nulo(x.get("usuario"))
			var desc := "jogando agora" if str(x["id"]) == atual else ("@" + u if u != "" else "usuário deste console")
			if u != "" and str(x["id"]) == atual:
				desc = "@" + u + "  ·  jogando agora"
			items.append({"text": "%s: %s" % [str(x.get("nome", "")), desc], "action": "usr_abrir", "arg": str(x["id"])})
		if lst.size() < 4:
			items.append({"text": "Criar usuário", "action": "usr_criar"})
		items.append({"text": "Entrar automaticamente ao ligar: " + _usr_nome(lst, auto, "Não (perguntar quem vai jogar)"),
			"action": "info"})
		if atual == "convidado":
			items.append({"text": "Jogando como convidado agora", "action": "info"})
		status = "Escolha um usuário para ver as opções. Até 4 usuários, cada um com saves e troféus próprios."
		return
	var u := _nulo(p.get("usuario"))
	var eu := str(p["id"]) == atual
	usr_sel_nome = str(p.get("nome", ""))
	if not eu:
		items.append({"text": "Usar como Jogador 1", "action": "usr_usar", "arg": usr_sel})
	items.append({"text": "Nome: " + str(p.get("nome", "")), "action": "usr_renomear"})
	items.append({"text": "Ícone: " + (_nome_avatar(_nulo(p.get("avatar"))) if _nulo(p.get("avatar")) != "" else "inicial do nome"),
		"action": "usr_icone"})
	if u == "":
		items.append({"text": "ID SkyNetwork: entrar com ID e senha", "action": "usr_conta"})
	else:
		items.append({"text": "ID SkyNetwork: @" + u, "action": "info"})
	items.append({"text": "Entrar automaticamente ao ligar: " + ("Sim" if auto == usr_sel else "Não"), "action": "usr_auto"})
	if not eu:
		items.append({"text": "Excluir usuário", "action": "usr_excluir"})
	status = ("Em uso agora como Jogador 1" if eu else "Usuário deste console") + \
		("  ·  conta @" + u if u != "" else "")


func _usr_nome(lst: Array, id: String, padrao: String) -> String:
	for x in lst:
		if str(x.get("id", "")) == id:
			return str(x.get("nome", id))
	return padrao


func _usr_acao(it: Dictionary) -> bool:
	match str(it["action"]):
		"usr_abrir":
			usr_sel = str(it["arg"])
			item = 0
			_usr_itens()
		"usr_criar":
			_kb_start("Nome do novo usuário", "")
			kb_mode = "usr_criar"
			kb_shift = true
		"usr_usar":
			_usr_cmd(["usar", str(it["arg"])], "Agora o Jogador 1 é este usuário")
		"usr_renomear":
			_kb_start("Nome do usuário", "")
			kb_mode = "usr_nome"
			kb_shift = true
		"usr_icone":
			grade_usr = usr_sel
			_grade_abrir()
		"usr_conta":
			net_perfil_alvo = usr_sel
			net_alvo_dupla = false
			_kb_start("ID SkyNetwork deste usuário", "")
			kb_mode = "net_conta_id_entrar"
		"usr_auto":
			var d := _usr_cmd(["listar"])
			var ligar: bool = _nulo(d.get("auto")) != usr_sel
			_usr_cmd(["auto", usr_sel if ligar else "nenhum"],
				"Ao ligar, entra direto com este usuário" if ligar else "Ao ligar, o console pergunta quem vai jogar")
		"usr_excluir":
			if it.get("confirm", false):
				var alvo := usr_sel
				usr_sel = ""
				_usr_cmd(["excluir", alvo], "Usuário excluído (os saves ficaram guardados em perfis/.excluidos)")
			else:
				it["confirm"] = true
				it["text"] = "Confirmar: excluir este usuário?  (confirme de novo)"
		_:
			return false
	return true
