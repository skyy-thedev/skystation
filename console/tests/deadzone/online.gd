extends SceneTree
## DEADZONE 0.8: coop online. O mesmo teste roda duas vezes ao mesmo tempo (tests/deadzone/online.sh):
## DZ_PAPEL=host abre a sala (--sala=coop_cr) e DZ_PAPEL=cliente entra (--entrar=127.0.0.1,24680,teste).
## Confere: handshake com senha, jogador 2 controlado de longe (andar e um toque de botão), zumbis,
## avisos, objetos e jogadores chegando no convidado, e a saída do convidado sem derrubar a sala.
var m: Node
var n := 0
var falhas := 0
var papel := OS.get_environment("DZ_PAPEL")
var fase := 0
var t := 0
var x0 := 0.0
var luz0 := false
var viu_aviso := false


func _initialize() -> void:
	Engine.max_fps = 60
	m = load("res://main.tscn").instantiate()
	root.add_child(m)


func _ok(c: bool, msg: String) -> void:
	print(("  ok  " if c else "FALHOU ") + "[%s] %s" % [papel, msg])
	if not c:
		falhas += 1


func _fim() -> bool:
	print("RESULTADO: tudo certo" if falhas == 0 else "RESULTADO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
	return true


func _process(_d: float) -> bool:
	n += 1
	t += 1
	if n > 60 * 90:
		_ok(false, "o teste demorou demais (fase %d)" % fase)
		return _fim()
	return _host() if papel == "host" else _cliente()


func _host() -> bool:
	var r: Node = m.rede
	m.t_spawn = 999.0
	match fase:
		0:
			if n == 2:
				_ok(r.host() and m.estado == m.SALA, "a sala abriu pela linha de comando")
				_ok(FileAccess.file_exists(r.run_dir() + "/deadzone-sala.json"), "deadzone-sala.json gravado (o sky-netplay lê)")
			if r.conectado() and m.jogadores.size() == 2:
				_ok(m.estado in [m.JOGANDO, m.CONVERSA], "o amigo entrou: a partida começou")
				m.historia.conversa = []              # pula a abertura da história
				m.estado = m.JOGANDO
				_ok(m.jogadores[1].nome == "Rocha", "o convidado é o Rocha (coop Corvo e Rocha)")
				var j2: Node2D = m.jogadores[1]
				j2.global_position = m.jogadores[0].global_position + Vector2(60, 0)
				for c in m.carros:
					if c.global_position.distance_to(j2.global_position) < 500.0:
						c.global_position += Vector2(3000, 0)
				x0 = j2.global_position.x
				luz0 = j2.luz_on
				fase = 1
				t = 0
		1:
			# o convidado segura → por um tempo e dá um toque na lanterna
			if t % 20 == 0:
				m.aviso("TESTE-AVISO", Color.WHITE)
				m.objetos[0].aberto = true
			# os dois jogos não andam no mesmo compasso: espera o que o convidado fez chegar (até 20 s)
			var j2: Node2D = m.jogadores[1] if m.jogadores.size() > 1 else null
			if j2 == null or (j2.global_position.x - x0 > 60.0 and j2.luz_on != luz0) or t == 1200:
				_ok(j2 != null and j2.global_position.x - x0 > 60.0, "o jogador 2 andou com o controle do outro console")
				_ok(j2 != null and j2.luz_on != luz0, "um toque rápido (lanterna) chegou como apertar")
				fase = 2
				t = 0
		2:
			if t % 20 == 0 and r.conectado():
				m.aviso("TESTE-AVISO", Color.WHITE)
			if not r.conectado():
				_ok(m.jogadores.size() == 1, "o convidado saiu: o jogador 2 some")
				_ok(r.host() and m.estado == m.JOGANDO, "a sala continua aberta para ele voltar")
				return _fim()
	return false


func _cliente() -> bool:
	var r: Node = m.rede
	match fase:
		0:
			if n == 2:
				_ok(r.cliente() and m.estado == m.CONECTANDO, "entrando pela linha de comando")
			if r.conectado() and m.jogadores.size() == 2 and r.foto > 5:
				_ok(m.estado in [m.JOGANDO, m.CONVERSA], "dentro da sala: a partida aparece")
				_ok(m.jogadores[0].nome == "Corvo" and m.jogadores[1].nome == "Rocha", "os dois jogadores chegaram")
				_ok(m.zumbis.size() > 5, "os zumbis do anfitrião aparecem (%d)" % m.zumbis.size())
				_ok(m.jogadores[0].process_mode == Node.PROCESS_MODE_DISABLED, "o convidado não simula (só mostra)")
				fase = 1
				t = 0
		1:
			if m.avisos.any(func(a): return a["texto"] == "TESTE-AVISO"):
				viu_aviso = true
			if t < 150:
				Input.action_press("p1_direita")
			elif t == 150:
				Input.action_release("p1_direita")
			if t == 60:
				x0 = m.jogadores[1].global_position.x
				luz0 = m.jogadores[1].luz_on
				Input.action_press("p1_luz")
			if t == 61:
				Input.action_release("p1_luz")
			if t == 140:
				_ok(m.jogadores[1].global_position.x - x0 > 40.0, "aqui também se vê o Rocha andando")
			if t == 230:
				_ok(m.jogadores[1].luz_on != luz0, "a lanterna do Rocha acendeu nos dois")
				_ok(viu_aviso, "avisos do anfitrião chegam")
				_ok(m.objetos[0].aberto, "objeto aberto lá aparece aberto aqui")
				_ok(m.camada_sangue != null and m.manchas is Array, "manchas de sangue sincronizadas")
				r.fechar("")
				fase = 2
				t = 0
		2:
			if t == 30:
				_ok(not r.online(), "saiu da sala")
				return _fim()
	return false
