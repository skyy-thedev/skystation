extends Node
## Coop online do DEADZONE (0.8). Um console é o ANFITRIÃO: roda o jogo de verdade (zumbis, história,
## tiros, saves). O outro é o CONVIDADO: gera a mesma cidade pela semente, não simula nada e só mostra
## o que o anfitrião manda; os botões dele viajam até o anfitrião e viram o jogador 2 de lá.
##
## Transporte: ENet (UDP) direto, sem servidor no meio. O anfitrião abre a porta 24680, tenta UPnP no
## roteador e anota todos os endereços que tem (IPv6, rede local, IP público). O convite da SkyNetwork
## (sky-netplay hospedar) leva a lista; o convidado tenta todos ao mesmo tempo e fica com o primeiro que
## responder. Na mesma rede (Wi-Fi de casa) a sala aparece sozinha: o anfitrião anuncia na porta 24681.
##
## Canais: 0 = confiável (handshake, eventos, objetos, estado lento); 1 = rápido e descartável
## (fotos do mundo 20x por segundo, controle do convidado 60x por segundo).

const PORTA := 24680
const PORTA_LAN := 24681
const VERSAO := "dz-0.8"
const CANAIS := 2
const ACOES := ["esquerda", "direita", "cima", "baixo", "atirar", "golpe", "correr", "arremessar", "interagir",
	"recarregar", "curar", "mochila", "arma_prox", "arma_ant", "luz", "tocha", "pausa", "voltar", "m_cima",
	"m_baixo", "m_esq", "m_dir", "aba_esq", "aba_dir", "agachar"]
const MODOS := {"coop_cr": "Corvo e Rocha — O Preço do Ar", "coop_in": "Iara e Nina — Fuga", "sobrevivencia": "Sobrevivência"}
const TIPOS_ZUMBI := ["andarilho", "corredor", "brutamontes", "policial", "irradiado"]
# o que do jogador muda pouco (vai no pacote lento) e o que nunca vai (nós, coisas só do anfitrião)
const JOG_LENTO := ["mochila", "armas", "pentes", "nome", "personagem", "fuma", "vel_mult", "ruido_mult", "cor_roupa",
	"cor_cabelo", "vip", "nivel", "xp", "forca", "gasolina", "hp_max"]
const JOG_FORA := ["main", "lanterna", "aura", "carro", "perto", "interacao", "n", "mouse_t", "mira_rede"]
const SONS_LOCAIS := ["geiger", "coracao"]   # o convidado já toca sozinho (vêm do estado)

var main: Node2D
var papel := ""                  # "" (offline), "host" ou "cliente"
var con: ENetConnection
var outro: ENetPacketPeer        # o outro console (já aceito)
var porta := PORTA
var senha := ""
var senha_fixa := ""             # testes: senha conhecida de antemão
var modo_sala := "coop_cr"
var status := ""                 # linha de situação para a tela
var enderecos: Array = []        # host: onde dá para me achar
var upnp_ok := false
var _upnp_th: Thread
var _upnp: UPNP
var lan: PacketPeerUDP
var t_lan := 0.0
var salas_lan := {}              # "ip:porta" -> {nome, modo, senha, ip, porta, t}
var menu_sel := 0
var amigos: Array = []           # da SkyNetwork (net.json): para convidar
var convites: Array = []         # convites do DEADZONE recebidos
var t_net := 0.0
var convidados := {}             # amigo -> hora do convite (não repetir)
# host
var t_snap := 0.0
var t_lento := 0.0
var _ult_obj := {}               # rid -> estado já mandado
var _ult_lento := PackedByteArray()
var _ult_carro := {}             # índice -> estado já mandado
var t_carros_full := 0.0
var _proximo_rid := 0
var _esperando: Array = []       # conectados que ainda não disseram "oi"
var _cont := PackedInt32Array()  # contador de apertos já aplicado (por ação)
var _apertado := PackedByteArray()
var _soltar: Array = []            # toque rápido: quadro de física em que apertou (-1 = nada)
var mira_remota := Vector2.ZERO
# cliente
var _tentativas: Array = []      # peers tentando ao mesmo tempo
var t_conectar := 0.0
var _meus_cont := PackedInt32Array()
var t_mouse := 0.0
var t_in := 0.0
var _zids := {}                  # id -> zumbi
var t_sem_pacote := 0.0
var foto := 0                    # quantas fotos do mundo chegaram (testes)
var motivo := ""                 # por que a sessão acabou (aparece no título)


func _ready() -> void:
	_cont.resize(ACOES.size())
	_apertado.resize(ACOES.size())
	_soltar.resize(ACOES.size())
	_soltar.fill(-1)
	_meus_cont.resize(ACOES.size())


func host() -> bool:
	return papel == "host"


func cliente() -> bool:
	return papel == "cliente"


func conectado() -> bool:
	return outro != null


func online() -> bool:
	return papel != ""


# ---------------------------------------------------------------- caminhos do console

static func run_dir() -> String:
	var x := OS.get_environment("XDG_RUNTIME_DIR")
	return (x if x != "" else "/tmp") + "/skystation"


static func sky_bin() -> String:
	var b := OS.get_environment("DEADZONE_SKY_BIN")
	return b if b != "" else "/opt/skystation/bin"


func _ler_json(caminho: String) -> Variant:
	if not FileAccess.file_exists(caminho):
		return null
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _gravar_json(caminho: String, dados: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados))


func meu_nome() -> String:
	var net: Variant = _ler_json(run_dir() + "/net.json")
	if net is Dictionary and net.get("eu") is Dictionary and str(net["eu"].get("apelido", "")) != "":
		return str(net["eu"]["apelido"])
	var u := OS.get_environment("USER")
	return u if u != "" else "SkyStation"


# ---------------------------------------------------------------- anfitrião: abrir a sala

func abrir_sala(m: String) -> bool:
	fechar("")
	con = ENetConnection.new()
	var err := ERR_CANT_CREATE
	for k in 6:                                  # porta ocupada (outro jogo?): tenta as próximas
		porta = PORTA + k * 2
		err = con.create_host_bound("*", porta, 4, CANAIS)
		if err == OK:
			break
	if err != OK:
		con = null
		status = "Não consegui abrir a porta da sala."
		return false
	con.compress(ENetConnection.COMPRESS_ZSTD)
	papel = "host"
	modo_sala = m
	var cr := Crypto.new()
	senha = senha_fixa if senha_fixa != "" else cr.generate_random_bytes(4).hex_encode()
	main._nova_partida(m)
	main.estado = main.SALA
	_proximo_rid = main.objetos.size()
	enderecos = _enderecos_locais()
	upnp_ok = false
	status = "Sala aberta. Procurando o roteador (UPnP)…"
	_gravar_sala()
	_abrir_lan()
	if OS.get_environment("DEADZONE_SEM_UPNP") == "":
		_upnp_th = Thread.new()
		_upnp_th.start(_upnp_abrir)
	else:
		status = "Sala aberta (rede local)."
	return true


func _enderecos_locais() -> Array:
	var v4: Array = []
	var v6: Array = []
	for a in IP.get_local_addresses():
		var s := str(a)
		if s.contains(":"):
			var l := s.to_lower()
			# só IPv6 global: link-local (fe80), local (fc/fd) e loopback não servem pela internet
			if not (l.begins_with("fe80") or l.begins_with("fc") or l.begins_with("fd") or l == "::1" or l.contains("%")):
				v6.append(s)
		elif not (s.begins_with("127.") or s.begins_with("169.254.")):
			v4.append(s)
	return v6 + v4


func _upnp_abrir() -> void:
	var u := UPNP.new()
	if u.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_upnp_fim", false, "")
		return
	var gw := u.get_gateway()
	if gw == null or not gw.is_valid_gateway() or u.add_port_mapping(porta, porta, "DEADZONE", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_upnp_fim", false, "")
		return
	_upnp = u
	call_deferred("_upnp_fim", true, u.query_external_address())


func _upnp_fim(ok: bool, ip: String) -> void:
	if _upnp_th:
		_upnp_th.wait_to_finish()
		_upnp_th = null
	if not host():
		return
	upnp_ok = ok
	if ok and ip != "" and not enderecos.has(ip):
		enderecos.push_front(ip)
	status = "Sala aberta: o roteador abriu a porta (UPnP)." if ok else \
		"Sala aberta. O roteador não abriu a porta: pela internet só via IPv6 (ou abra a UDP %d)." % porta
	_gravar_sala()


func _gravar_sala() -> void:
	_gravar_json(run_dir() + "/deadzone-sala.json", {"porta": porta, "senha": senha, "enderecos": enderecos,
		"upnp": upnp_ok, "modo": modo_sala, "nome": meu_nome(), "versao": VERSAO})


func _abrir_lan() -> void:
	lan = PacketPeerUDP.new()
	lan.set_broadcast_enabled(true)
	lan.set_dest_address("255.255.255.255", PORTA_LAN)


func fechar(por := "") -> void:
	## acaba a sessão (os dois lados); "por" aparece na tela do título
	if outro:
		outro.peer_disconnect_later()
		if con:
			con.flush()
	if con:
		for p in con.get_peers():
			p.peer_disconnect_now()
		con.destroy()
	con = null
	outro = null
	_tentativas.clear()
	_esperando.clear()
	if lan:
		lan.close()
		lan = null
	if host():
		DirAccess.remove_absolute(run_dir() + "/deadzone-sala.json")
		if _upnp:
			_upnp.delete_port_mapping(porta, "UDP")
			_upnp = null
	if _upnp_th:
		_upnp_th.wait_to_finish()
		_upnp_th = null
	_ult_obj.clear()
	_ult_carro.clear()
	_ult_lento = PackedByteArray()
	_zids.clear()
	papel = ""
	if por != "":
		motivo = por
		main.aviso(por, Color("ff9f43"))


func _exit_tree() -> void:
	fechar("")


# ---------------------------------------------------------------- convidado: entrar

func entrar(alvos: Array, p_senha: String) -> void:
	## alvos: [[ip, porta], ...] — todos tentados juntos
	fechar("")
	con = ENetConnection.new()
	if con.create_host(maxi(1, alvos.size()), CANAIS) != OK:
		con = null
		motivo = "Não consegui usar a rede."
		return
	con.compress(ENetConnection.COMPRESS_ZSTD)
	papel = "cliente"
	senha = p_senha
	for a in alvos:
		var p := con.connect_to_host(str(a[0]), int(a[1]), CANAIS)
		if p:
			_tentativas.append(p)
	t_conectar = 10.0
	status = "Conectando à sala (%d endereço%s)…" % [_tentativas.size(), "" if _tentativas.size() == 1 else "s"]
	main.estado = main.CONECTANDO
	if _tentativas.is_empty():
		fechar("Endereço inválido.")
		main.estado = main.ONLINE


static func alvos_da_sala(sala: Dictionary) -> Array:
	var p := int(sala.get("porta", PORTA))
	var r: Array = []
	for ip in [sala.get("ip", "")] + Array(sala.get("alternativos", [])):
		if str(ip) != "" and not r.any(func(x): return x[0] == str(ip)):
			r.append([str(ip), p])
	return r


func entrar_convite_pendente() -> bool:
	## o launcher grava deadzone-entrar.json quando o jogador aceita um convite na SkyNetwork
	var arq := run_dir() + "/deadzone-entrar.json"
	var d: Variant = _ler_json(arq)
	DirAccess.remove_absolute(arq)
	if not d is Dictionary or alvos_da_sala(d).is_empty():
		return false
	entrar(alvos_da_sala(d), str(d.get("senha", "")))
	return true


func linha_de_comando() -> void:
	## --sala=coop_cr (abre a sala) · --entrar=IP,PORTA,SENHA (entra direto) · convite aceito no launcher
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sala="):
			senha_fixa = OS.get_environment("DEADZONE_SENHA")
			abrir_sala(a.substr(7))
			return
		if a.begins_with("--entrar="):
			var p := a.substr(9).split(",")
			if p.size() >= 2:
				entrar([[p[0], int(p[1])]], p[2] if p.size() > 2 else "")
			return
	entrar_convite_pendente()


# ---------------------------------------------------------------- laço

func _input(e: InputEvent) -> void:
	if cliente() and e is InputEventMouseMotion:
		t_mouse = 2.0


func _process(d: float) -> void:
	if lan == null and main.estado == main.ONLINE:
		_ouvir_lan()
	if main.estado in [main.ONLINE, main.SALA]:
		t_net -= d
		if t_net <= 0.0:
			t_net = 3.0
			_ler_net()
	if con == null:
		return
	_servico()
	if con == null:
		return
	if host():
		_host_quadro(d)
	elif cliente():
		_cliente_quadro(d)


func _servico() -> void:
	while con:
		var ev: Array = con.service(0)
		var tipo: int = ev[0]
		if tipo == ENetConnection.EVENT_NONE:
			break
		var p: ENetPacketPeer = ev[1]
		match tipo:
			ENetConnection.EVENT_ERROR:
				fechar("Erro de rede.")
				_voltar_menu()
				return
			ENetConnection.EVENT_CONNECT:
				_conectou(p)
			ENetConnection.EVENT_DISCONNECT:
				_caiu(p)
			ENetConnection.EVENT_RECEIVE:
				var dados := p.get_packet()
				var m: Variant = bytes_to_var(dados)
				if m is Array and m.size() == 2 and m[0] is String:
					_mensagem(p, m[0], m[1])


func _mandar(p: ENetPacketPeer, tipo: String, dados: Variant, rapido := false) -> void:
	if p == null:
		return
	var b := var_to_bytes([tipo, dados])
	if rapido:
		p.send(1, b, ENetPacketPeer.FLAG_UNRELIABLE_FRAGMENT)
	else:
		p.send(0, b, ENetPacketPeer.FLAG_RELIABLE)


func _conectou(p: ENetPacketPeer) -> void:
	if host():
		_esperando.append(p)                     # espera o "oi" com a senha
		return
	if outro != null or not _tentativas.has(p):
		p.peer_disconnect_now()
		return
	outro = p                                    # o primeiro endereço que respondeu vence
	for q in _tentativas:
		if q != p:
			q.peer_disconnect_now()
	_tentativas.clear()
	status = "Conectado. Entrando na sala…"
	_mandar(p, "oi", {"versao": VERSAO, "senha": senha, "nome": meu_nome()})


func _caiu(p: ENetPacketPeer) -> void:
	_esperando.erase(p)
	if host():
		if p == outro:
			outro = null
			_tirar_p2()
			main.aviso("O parceiro caiu da sala. A sala continua aberta para ele voltar.", Color("ff9f43"))
		return
	if p == outro or (outro == null and _tentativas.has(p)):
		_tentativas.erase(p)
		if p == outro or _tentativas.is_empty():
			var era: bool = p == outro
			fechar("A conexão com a sala caiu." if era else "Não achei a sala em nenhum endereço.")
			_voltar_menu()


func _voltar_menu() -> void:
	if main.estado in [main.CONECTANDO, main.SALA]:
		main.estado = main.ONLINE
	elif main.estado != main.ONLINE:
		main._nova_partida("historia")
		main.estado = main.ONLINE              # a tela do coop online mostra o motivo
	menu_sel = 0


func _mensagem(p: ENetPacketPeer, tipo: String, dados: Variant) -> void:
	if host():
		match tipo:
			"oi":
				_oi(p, dados)
			"in":
				if p == outro and dados is Dictionary:
					_aplicar_controle(dados)
		return
	if p != outro:
		return
	t_sem_pacote = 0.0
	match tipo:
		"bem_vindo":
			_bem_vindo(dados)
		"nao":
			fechar(str(dados))
			_voltar_menu()
		"s":
			_aplicar_foto(dados)
		"o":
			_aplicar_objetos(dados)
		"l":
			_aplicar_lento(dados)
		"e":
			for ev in dados:
				_evento_cliente(ev[0], ev[1])
		"fim":
			fechar(str(dados))
			_voltar_menu()


# ---------------------------------------------------------------- anfitrião

func _oi(p: ENetPacketPeer, d: Variant) -> void:
	_esperando.erase(p)
	if not d is Dictionary or str(d.get("versao", "")) != VERSAO:
		_mandar(p, "nao", "Versões diferentes do DEADZONE: atualizem os dois consoles.")
		p.peer_disconnect_later()
		return
	if str(d.get("senha", "")) != senha:
		_mandar(p, "nao", "Senha da sala errada.")
		p.peer_disconnect_later()
		return
	if outro != null:
		_mandar(p, "nao", "A sala já está cheia.")
		p.peer_disconnect_later()
		return
	outro = p
	_ult_obj.clear()
	_ult_carro.clear()
	_ult_lento = PackedByteArray()
	_cont.fill(-1)
	_apertado.fill(0)
	_soltar.fill(-1)
	var nome := str(d.get("nome", "Amigo")).substr(0, 24)
	var novo: bool = main.estado == main.SALA
	if novo:
		main.estado = main.JOGANDO
	var j: Node2D = main.entrar_remoto()
	_mandar(p, "bem_vindo", {"modo": main.modo, "semente": main.semente, "anfitriao": meu_nome()})
	_mandar(p, "e", [["manchas", main.manchas]])
	if novo:
		main.historia.iniciar()
	main.aviso("%s entrou na sala como %s!" % [nome, j.nome], Color("ffd166"))
	_mandar_lento(true)
	_mandar_objetos()


func _tirar_p2() -> void:
	if main.jogadores.size() < 2:
		return
	var j: Node2D = main.jogadores[1]
	if j.carro:
		j.carro.sair(j)
	main.jogadores.erase(j)
	j.queue_free()
	for i in ACOES.size():
		if _apertado[i]:
			_injetar(i, false, 0.0)
	_apertado.fill(0)
	if main.estado in [main.MOCHILA, main.CONVERSA] and main.menu_dono == 2:
		main.estado = main.JOGANDO


func expulsar() -> void:
	## o convidado escolheu "Sair da sala" no menu de pausa
	if outro:
		_mandar(outro, "fim", "Você saiu da sala.")
		outro.peer_disconnect_later()
		outro = null
		_tirar_p2()


func _host_quadro(d: float) -> void:
	# anúncio na rede local
	if lan:
		t_lan -= d
		if t_lan <= 0.0:
			t_lan = 1.0
			lan.put_packet(JSON.stringify({"dz": VERSAO, "nome": meu_nome(), "modo": modo_sala, "porta": porta,
				"senha": senha, "cheia": outro != null}).to_utf8_buffer())
	if main.estado == main.TITULO:
		if outro:
			_mandar(outro, "fim", "O anfitrião fechou a sala.")
		fechar("")
		return
	if outro == null:
		return
	# soltar os botões que foram só um toque, depois de a física ter visto o aperto (2 passos)
	for i in ACOES.size():
		if _soltar[i] >= 0 and Engine.get_physics_frames() - int(_soltar[i]) >= 2:
			_soltar[i] = -1
			_injetar(i, false, 0.0)
	t_snap -= d
	if t_snap <= 0.0:
		t_snap = 0.05
		_mandar(outro, "s", _foto(), true)
	t_lento -= d
	if t_lento <= 0.0:
		t_lento = 0.25
		_mandar_lento(false)
		_mandar_objetos()
	_soltar_eventos()


func _injetar(i: int, apertado: bool, forca: float) -> void:
	var e := InputEventAction.new()
	e.action = "p2_" + ACOES[i]
	e.pressed = apertado
	e.strength = forca if apertado else 0.0
	Input.parse_input_event(e)
	_apertado[i] = 1 if apertado else 0


func _aplicar_controle(c: Dictionary) -> void:
	var f: PackedFloat32Array = c.get("f", PackedFloat32Array())
	var n: PackedInt32Array = c.get("c", PackedInt32Array())
	if f.size() != ACOES.size() or n.size() != ACOES.size():
		return
	for i in ACOES.size():
		var s: float = clampf(f[i], 0.0, 1.0)
		if _cont[i] < 0:
			_cont[i] = n[i]                          # primeiro pacote: só sincroniza o contador
		if n[i] != _cont[i]:
			_cont[i] = n[i]
			if _apertado[i]:
				_injetar(i, false, 0.0)             # soltar e apertar de novo: vira "acabou de apertar"
			_injetar(i, true, maxf(s, 1.0))
			if s < 0.3:
				_soltar[i] = Engine.get_physics_frames()   # foi um toque rápido: solta daqui a pouco
		elif s >= 0.3:
			if not _apertado[i] or absf(s - Input.get_action_strength("p2_" + ACOES[i])) > 0.03:
				_injetar(i, true, s)
		elif _apertado[i] and _soltar[i] < 0:
			_injetar(i, false, 0.0)
	var m: Vector2 = c.get("m", Vector2.ZERO)
	mira_remota = m if m.length() <= 1.5 else m.normalized()
	if main.jogadores.size() > 1:
		main.jogadores[1].mira_rede = mira_remota


# eventos (som, avisos, sangue…): juntados e mandados uma vez por quadro
var _fila: Array = []


func evento(tipo: String, dados: Variant) -> void:
	if host() and outro != null:
		_fila.append([tipo, dados])


func _soltar_eventos() -> void:
	if _fila.is_empty() or outro == null:
		return
	_mandar(outro, "e", _fila)
	_fila = []


func rid(o: Node) -> int:
	if not o.has_meta("rid"):
		o.set_meta("rid", _proximo_rid)
		_proximo_rid += 1
	return int(o.get_meta("rid"))


static func props_de(no: Object) -> Array:
	var r: Array = []
	for p in no.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			r.append(p["name"])
	return r


static func limpo(v: Variant) -> Variant:
	## tira o que não atravessa a rede (nós, funções): o resto vai como está
	match typeof(v):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
		TYPE_DICTIONARY:
			var r := {}
			for k in v:
				var x: Variant = limpo(v[k])
				if x != null or v[k] == null:
					r[k] = x
			return r
		TYPE_ARRAY:
			var a: Array = []
			for x in v:
				a.append(limpo(x))
			return a
	return v


var _props_jog: Array = []


func _jog_rapido(j: Node2D) -> Dictionary:
	if _props_jog.is_empty():
		_props_jog = props_de(j).filter(func(k): return not (k in JOG_LENTO or k in JOG_FORA))
	var r := {"pos": j.global_position, "carro": main.carros.find(j.carro) if j.carro else -1}
	for k in _props_jog:
		r[k] = limpo(j.get(k))
	if not j.interacao.is_empty():
		r["inter"] = {"t": j.interacao["t"], "total": j.interacao["total"]}
	return r


func _foto() -> Dictionary:
	var js: Array = []
	for j in main.jogadores:
		js.append(_jog_rapido(j))
	var zs := PackedFloat32Array()
	for z in main.zumbis:
		if not is_instance_valid(z):
			continue
		var id := rid(z)
		var fl := (1 if z.alerta else 0) | (2 if z.alvo != null else 0)
		zs.append_array([id, maxi(0, TIPOS_ZUMBI.find(z.tipo)), z.global_position.x, z.global_position.y, z.frente.angle(),
			z.fase, z.hp, z.hp_max, z.t_flash, z.t_fogo, z.suspeita, z.t_exclama, fl])
	# carros: só os que mudaram (e todos a cada 2 s, para corrigir pacote perdido)
	t_carros_full -= 0.05
	var todos := t_carros_full <= 0.0
	if todos:
		t_carros_full = 2.0
	var cs: Array = []
	for i in main.carros.size():
		var c: Node2D = main.carros[i]
		var e := [i, c.global_position, c.angulo, c.vel, c.combustivel, c.vida, c.saqueado, c.tanque, c.funciona,
			main.jogadores.find(c.motorista) + 1, main.jogadores.find(c.carona) + 1]
		var ch := var_to_bytes(e)
		if todos or _ult_carro.get(i) != ch:
			_ult_carro[i] = ch
			cs.append(e)
	var ns: Array = []
	for n in main.npcs:
		if is_instance_valid(n):
			ns.append([n.id, n.global_position, n.olhar, n.sumir])
	var ondas: Array = []
	for o in main.ondas:
		ondas.append([o["pos"], o["raio"], o["t"]])
	return {"j": js, "z": zs, "c": cs, "n": ns,
		"m": [main.estado, main.tempo, main.dia, main.mortes, main.fase_alerta, main.t_fase, main.menu_sel, main.menu_dono,
			main.mochila_aba, ondas, main.tremor]}


func _mandar_lento(forcar: bool) -> void:
	var js: Array = []
	for j in main.jogadores:
		var r := {}
		for k in JOG_LENTO:
			r[k] = limpo(j.get(k))
		js.append(r)
	var h := {}
	for k in props_de(main.historia):
		if k != "main":
			h[k] = limpo(main.historia.get(k))
	var locais := {}
	for k in main.locais:
		if typeof(main.locais[k]) in [TYPE_VECTOR2, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			locais[k] = main.locais[k]
	var pacote := {"j": js, "h": h, "locais": locais, "motivo_fim": main.motivo_fim, "novo_recorde": main.novo_recorde,
		"recorde": main.recorde}
	var b := var_to_bytes(pacote)
	if forcar or b != _ult_lento:
		_ult_lento = b
		_mandar(outro, "l", pacote)


func _estado_obj(o: Node2D) -> Array:
	return [o.tipo, o.global_position, o.aberto, o.madeira, o.usos, snappedf(o.vida, 0.5), limpo(o.garantido),
		o.has_meta("so_garantido")]


func _mandar_objetos() -> void:
	var mudou: Array = []
	var vivos := {}
	for o in main.objetos:
		if not is_instance_valid(o) or o.is_queued_for_deletion():
			continue
		var id := rid(o)
		vivos[id] = true
		var e := _estado_obj(o)
		if _ult_obj.get(id) != e:
			_ult_obj[id] = e
			mudou.append([id] + e)
	var sumiu: Array = []
	for id in _ult_obj.keys():
		if not vivos.has(id):
			sumiu.append(id)
			_ult_obj.erase(id)
	if not mudou.is_empty() or not sumiu.is_empty():
		_mandar(outro, "o", {"m": mudou, "x": sumiu})


# ---------------------------------------------------------------- convidado

func _bem_vindo(d: Dictionary) -> void:
	status = "Na sala de %s." % str(d.get("anfitriao", "amigo"))
	main._nova_partida(str(d["modo"]), int(d["semente"]))     # mesma semente = mesma cidade (rid = índice)
	main.entrar_remoto()
	for j in main.jogadores:
		j.process_mode = Node.PROCESS_MODE_DISABLED         # quem mexe é o anfitrião
	for c in main.carros:
		c.process_mode = Node.PROCESS_MODE_DISABLED
	main.estado = main.JOGANDO
	main.aviso("Conectado! Você é %s." % main.jogadores[1].nome, Color("ffd166"))


func _cliente_quadro(d: float) -> void:
	if outro == null:
		t_conectar -= d
		if t_conectar <= 0.0:
			fechar("Não achei a sala (o amigo está atrás de um roteador fechado?).")
			_voltar_menu()
		return
	t_sem_pacote += d
	if t_sem_pacote > 12.0:
		fechar("A sala parou de responder.")
		_voltar_menu()
		return
	t_mouse = maxf(0.0, t_mouse - d)
	# o controle daqui vai para o jogador 2 de lá (os apertos contam sempre; o pacote sai até 60x/s)
	var f := PackedFloat32Array()
	f.resize(ACOES.size())
	for i in ACOES.size():
		var a: String = "p1_" + ACOES[i]
		f[i] = Input.get_action_strength(a)
		if Input.is_action_just_pressed(a):
			_meus_cont[i] += 1
	t_in -= d
	if t_in > 0.0:
		return
	t_in = 1.0 / 60.0
	var mira := Vector2.ZERO
	var dev: int = main.dispositivo(1)
	if dev >= 0:
		var rs := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
		if rs.length() > 0.35:
			mira = rs
	if mira == Vector2.ZERO and t_mouse > 0.0 and main.jogadores.size() > 1:
		mira = (main.get_global_mouse_position() - main.jogadores[1].global_position).normalized()
	_mandar(outro, "in", {"f": f, "c": _meus_cont, "m": mira}, true)


func _quadro_visual(d: float) -> void:
	## o que o convidado anima sozinho entre uma foto e outra (main._process chama)
	main._ciclo()
	for fg in main.fogos:
		fg["t"] -= d
		fg["luz"].energy = 1.2 + randf() * 0.4
		if fg["t"] <= 0.0:
			fg["luz"].queue_free()
	main.fogos = main.fogos.filter(func(fg): return fg["t"] > 0.0)
	for j in main.jogadores:
		if is_instance_valid(j):
			j._procurar()
	if main.estado == main.TITULO:
		fechar("O anfitrião fechou a sala.")
		main.estado = main.TITULO


func _aplicar_foto(s: Dictionary) -> void:
	if main.jogadores.size() < 2:
		return
	foto += 1
	var m: Array = s["m"]
	main.estado = m[0]
	main.tempo = m[1]
	main.dia = m[2]
	main.mortes = m[3]
	main.fase_alerta = m[4]
	main.t_fase = m[5]
	main.menu_sel = m[6]
	main.menu_dono = m[7]
	main.mochila_aba = m[8]
	main.ondas = m[9].map(func(o): return {"pos": o[0], "raio": o[1], "t": o[2]})
	main.tremor = maxf(main.tremor, m[10])
	var js: Array = s["j"]
	for i in mini(js.size(), main.jogadores.size()):
		var j: Node2D = main.jogadores[i]
		var r: Dictionary = js[i]
		for k in r:
			match k:
				"pos":
					j.global_position = r[k]
				"carro":
					j.carro = main.carros[r[k]] if r[k] >= 0 and r[k] < main.carros.size() else null
				"inter":
					pass
				_:
					j.set(k, r[k])
		j.interacao = r.get("inter", {})
		j._luzes(0.0)
		j.queue_redraw()
	# zumbis: cria os novos, mexe os conhecidos, apaga os que sumiram
	var zs: PackedFloat32Array = s["z"]
	var vistos := {}
	var k := 0
	while k + 13 <= zs.size():
		var id := int(zs[k])
		vistos[id] = true
		var z: Node2D = _zids.get(id)
		if z == null or not is_instance_valid(z):
			z = CharacterBody2D.new()
			z.set_script(preload("res://zumbi.gd"))
			z.main = main
			z.tipo = TIPOS_ZUMBI[clampi(int(zs[k + 1]), 0, TIPOS_ZUMBI.size() - 1)]
			z.position = Vector2(zs[k + 2], zs[k + 3])
			z.process_mode = Node.PROCESS_MODE_DISABLED
			main.mundo.add_child(z)
			main.zumbis.append(z)
			_zids[id] = z
		z.global_position = Vector2(zs[k + 2], zs[k + 3])
		z.frente = Vector2.from_angle(zs[k + 4])
		z.fase = zs[k + 5]
		z.hp = zs[k + 6]
		z.hp_max = zs[k + 7]
		z.t_flash = zs[k + 8]
		z.t_fogo = zs[k + 9]
		z.suspeita = zs[k + 10]
		z.t_exclama = zs[k + 11]
		var fl := int(zs[k + 12])
		z.alerta = fl & 1 != 0
		z.alvo = main.jogadores[0] if fl & 2 else null
		z.queue_redraw()
		k += 13
	for id in _zids.keys():
		if not vistos.has(id):
			var z: Node2D = _zids[id]
			_zids.erase(id)
			main.zumbis.erase(z)
			if is_instance_valid(z):
				z.queue_free()
	for e in s["c"]:
		var i: int = e[0]
		if i >= main.carros.size():
			continue
		var c: Node2D = main.carros[i]
		c.global_position = e[1]
		c.angulo = e[2]
		c.vel = e[3]
		c.combustivel = e[4]
		c.vida = e[5]
		c.saqueado = e[6]
		c.tanque = e[7]
		c.funciona = e[8]
		c.motorista = main.jogadores[e[9] - 1] if e[9] > 0 and e[9] <= main.jogadores.size() else null
		c.carona = main.jogadores[e[10] - 1] if e[10] > 0 and e[10] <= main.jogadores.size() else null
		if c.farol:
			c.farol.visible = c.motorista != null
			c.farol.rotation = c.angulo
		c.queue_redraw()
	var ns := {}
	for n in s["n"]:
		ns[n[0]] = n
	for n in main.npcs.duplicate():
		if not is_instance_valid(n) or not ns.has(n.id):
			main.npcs.erase(n)
			if is_instance_valid(n):
				n.queue_free()
	for id in ns:
		var e: Array = ns[id]
		var no: Node2D = null
		for n in main.npcs:
			if n.id == id:
				no = n
		if no == null:
			no = main._npc(id, e[1])
		no.global_position = e[1]
		no.sumir = e[3]


func _aplicar_lento(l: Dictionary) -> void:
	var js: Array = l["j"]
	for i in mini(js.size(), main.jogadores.size()):
		for k in js[i]:
			main.jogadores[i].set(k, js[i][k])
	for k in l["h"]:
		main.historia.set(k, l["h"][k])
	for k in l["locais"]:
		main.locais[k] = l["locais"][k]
	main.motivo_fim = l["motivo_fim"]
	main.novo_recorde = l["novo_recorde"]
	main.recorde = l["recorde"]


func _aplicar_objetos(o: Dictionary) -> void:
	var por_id := {}
	for x in main.objetos:
		if is_instance_valid(x) and x.has_meta("rid"):
			por_id[int(x.get_meta("rid"))] = x
	for e in o["m"]:
		var id: int = e[0]
		var x: Node2D = por_id.get(id)
		if x == null:
			x = preload("res://objeto.gd").new()
			x.main = main
			x.tipo = e[1]
			x.position = e[2]
			x.set_meta("rid", id)
			if e[8]:
				x.set_meta("so_garantido", true)
			main.mundo.add_child(x)
			main.objetos.append(x)
		x.aberto = e[3]
		x.madeira = e[4]
		x.usos = e[5]
		x.vida = e[6]
		x.garantido = e[7]
		x.queue_redraw()
	for id in o["x"]:
		var x: Node2D = por_id.get(int(id))
		if x:
			main.objetos.erase(x)
			x.queue_free()


func _evento_cliente(tipo: String, d: Variant) -> void:
	match tipo:
		"som":
			main.sons.tocar(d[0], d[1], d[2], d[3])
		"ono":
			main.onomato(d[0], d[1], d[2], d[3])
		"aviso":
			main.aviso(d[0], d[1])
		"sangue":
			main.manchas.append(d)
			if main.manchas.size() > 260:
				main.manchas.pop_front()
			main.camada_sangue.queue_redraw()
		"manchas":
			main.manchas = d
			main.camada_sangue.queue_redraw()
		"tremer":
			main.tremer(d)
		"fogo":
			var l: PointLight2D = main.nova_luz(Color(1.0, 0.55, 0.2), 2.2, false)
			l.position = d
			main.mundo.add_child(l)
			main.fogos.append({"pos": d, "t": 5.0, "luz": l})
		"voar":
			main.hud.voar(d[0], d[1], d[2])


# ---------------------------------------------------------------- menus (título → coop online, sala, conectando)

func _ouvir_lan() -> void:
	lan = PacketPeerUDP.new()
	if lan.bind(PORTA_LAN) != OK:
		lan = null


func _ler_lan(d: float) -> void:
	if lan == null or host():
		return
	while lan.get_available_packet_count() > 0:
		var b := lan.get_packet()
		var ip := lan.get_packet_ip()
		var m: Variant = JSON.parse_string(b.get_string_from_utf8())
		if m is Dictionary and str(m.get("dz", "")) == VERSAO:
			var chave := "%s:%d" % [ip, int(m.get("porta", PORTA))]
			salas_lan[chave] = {"nome": str(m.get("nome", "?")), "modo": str(m.get("modo", "")), "senha": str(m.get("senha", "")),
				"ip": ip, "porta": int(m.get("porta", PORTA)), "cheia": bool(m.get("cheia", false)), "t": 3.0}
	for c in salas_lan.keys():
		salas_lan[c]["t"] -= d
		if salas_lan[c]["t"] <= 0.0:
			salas_lan.erase(c)


func _ler_net() -> void:
	## amigos (para convidar) e convites do DEADZONE (para entrar), do arquivo que o sky-net mantém
	amigos = []
	convites = []
	var net: Variant = _ler_json(run_dir() + "/net.json")
	if not net is Dictionary:
		return
	for a in net.get("amigos", []):
		if a is Dictionary and str(a.get("status", "offline")) not in ["offline", ""]:
			amigos.append(a)
	var agora := Time.get_unix_time_from_system()
	for m in net.get("mensagens", []):
		if not m is Dictionary or str(m.get("tipo", "")) != "netplay" or str(m.get("sistema", "")) != "deadzone":
			continue
		var quando := Time.get_unix_time_from_datetime_string(str(m.get("enviadaEm", "")).substr(0, 19))
		if quando > 0 and agora - quando <= 1800 and m.get("sala") is Dictionary:
			convites.append(m)


func opcoes() -> Array:
	var ops: Array = []
	if main.estado == main.ONLINE:
		for m in MODOS:
			ops.append({"id": "abrir:" + m, "txt": "Abrir sala: " + MODOS[m]})
		for c in salas_lan:
			var s: Dictionary = salas_lan[c]
			ops.append({"id": "lan:" + c, "txt": "Entrar na sala de %s (mesma rede) · %s%s" % [s["nome"], MODOS.get(s["modo"], s["modo"]),
				" · cheia" if s["cheia"] else ""]})
		for m in convites:
			ops.append({"id": "conv:" + str(m.get("id", "")), "txt": "Entrar: convite de %s (SkyNetwork)" % str(m.get("de", {}).get("apelido", "amigo"))})
		ops.append({"id": "voltar", "txt": "Voltar"})
	elif main.estado == main.SALA:
		for a in amigos:
			var ja := convidados.has(str(a.get("id", "")))
			ops.append({"id": "convidar:" + str(a.get("id", "")), "txt": "%s %s" % ["Convidado:" if ja else "Convidar", str(a.get("apelido", "?"))]})
		ops.append({"id": "fechar", "txt": "Fechar a sala"})
	else:
		ops.append({"id": "cancelar", "txt": "Cancelar"})
	return ops


func menu(d: float) -> void:
	## main._process chama nos estados ONLINE, SALA e CONECTANDO
	_ler_lan(d)
	var ops := opcoes()
	menu_sel = clampi(menu_sel, 0, ops.size() - 1)
	if main.apertou("m_cima"):
		menu_sel = wrapi(menu_sel - 1, 0, ops.size())
		main.sons.tocar("ui", null, -10.0)
	elif main.apertou("m_baixo"):
		menu_sel = wrapi(menu_sel + 1, 0, ops.size())
		main.sons.tocar("ui", null, -10.0)
	elif main.apertou("voltar"):
		_escolher("voltar" if main.estado == main.ONLINE else ("fechar" if main.estado == main.SALA else "cancelar"))
	elif main.apertou("interagir"):
		main.sons.tocar("ui_ok", null, -8.0)
		_escolher(ops[menu_sel]["id"])


func _escolher(id: String) -> void:
	if id.begins_with("abrir:"):
		if abrir_sala(id.substr(6)):
			menu_sel = 0
	elif id.begins_with("lan:"):
		var s: Dictionary = salas_lan.get(id.substr(4), {})
		if not s.is_empty():
			entrar([[s["ip"], s["porta"]]], s["senha"])
	elif id.begins_with("conv:"):
		for m in convites:
			if str(m.get("id", "")) == id.substr(5):
				entrar(alvos_da_sala(m["sala"]), str(m["sala"].get("senha", "")))
				if m.get("de") is Dictionary:      # marca a conversa como lida
					OS.create_process(sky_bin() + "/sky-cloud", ["lidas", str(m["de"].get("id", ""))])
	elif id.begins_with("convidar:"):
		var fid := id.substr(9)
		var prog := sky_bin() + "/sky-netplay"
		if not FileAccess.file_exists(prog):
			main.aviso("Convite pela SkyNetwork só no console (sky-netplay não encontrado).", Color("ff8a8a"))
			return
		OS.create_process(prog, ["hospedar", fid])
		convidados[fid] = Time.get_ticks_msec()
		main.aviso("Mandando o convite… quando o amigo aceitar, ele entra aqui.", Color("9db4ff"))
	elif id == "fechar":
		fechar("Sala fechada.")
		main._nova_partida("historia")
		main.estado = main.ONLINE
		menu_sel = 0
	elif id == "cancelar":
		fechar("")
		main.estado = main.ONLINE
		menu_sel = 0
	elif id == "voltar":
		if lan:
			lan.close()
			lan = null
		main.estado = main.TITULO
		main.menu_sel = 0


func desenhar(hud: Control, w: float, h: float) -> void:
	hud._fundo("titulo", w, h)
	hud.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.62))
	hud._logo(Vector2(w / 2, h * 0.14), 96)
	var titulo := "Coop online"
	var linhas: Array = []
	match main.estado:
		main.ONLINE:
			linhas = ["Abra uma sala e convide um amigo da SkyNetwork, ou entre na sala de alguém.",
				"Na mesma rede (Wi-Fi de casa) as salas aparecem sozinhas aqui embaixo."]
			if motivo != "":
				linhas.append(motivo)
		main.SALA:
			titulo = "Sala aberta · " + MODOS.get(modo_sala, modo_sala)
			linhas = [status, "Esperando o parceiro… Convide um amigo online abaixo (ou pelo menu Home → Amigos → Jogar junto)."]
			if not enderecos.is_empty():
				linhas.append("Endereços: %s · porta UDP %d" % [", ".join(enderecos.slice(0, 3)), porta])
			if amigos.is_empty():
				linhas.append("Nenhum amigo online agora na SkyNetwork.")
		main.CONECTANDO:
			titulo = "Entrando na sala"
			linhas = [status]
	var lt: float = hud.fonte_tit.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	hud._bangers(titulo, Vector2(w / 2 - lt / 2, h * 0.27), 44, hud.AMARELO, 6)
	var y := h * 0.33
	for l in linhas:
		hud._txt(str(l), Vector2(0, y), 17, Color(1, 1, 1, 0.85), w, HORIZONTAL_ALIGNMENT_CENTER)
		y += 26
	var ops := opcoes()
	y = maxf(y + 30, h * 0.47)
	for i in ops.size():
		var sel: bool = i == menu_sel
		if sel:
			hud.draw_rect(Rect2(w / 2 - 320, y - 30, 640, 42), Color(1, 1, 1, 0.12))
		hud._txt(ops[i]["txt"], Vector2(0, y), 21, Color.WHITE if sel else Color(1, 1, 1, 0.55), w, HORIZONTAL_ALIGNMENT_CENTER)
		y += 44
	hud._txt("✕ escolher · ○ voltar", Vector2(0, h - 40), 15, hud.AZUL, w, HORIZONTAL_ALIGNMENT_CENTER)
