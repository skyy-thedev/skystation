extends Node
## Todos os sons do jogo, sintetizados na hora (sem arquivos de áudio): ruído, senos, envelopes e filtros
## simples. Gerados uma vez no começo e guardados como AudioStreamWAV. A música fica em musica.gd.

const TAXA := 22050

var main: Node2D
var bancos := {}            # nome -> Array[AudioStreamWAV] (variações)
var rng := RandomNumberGenerator.new()
var loops := {}             # nome -> AudioStreamPlayer (sons contínuos não posicionais)
var t_geiger := 0.0
var t_coracao := 0.0
var t_passos := {}
## som no mundo que também "aparece escrito", como no gibi: nome do som -> [texto, cor, tamanho, tremor da tela]
const ONOMATO := {
	"tiro_pistola": [["BLAM!", "BANG!"], Color("ffd166"), 30, 2.0],
	"tiro_espingarda": [["BUUM!", "KA-BLAM!"], Color("ff9f43"), 40, 6.0],
	"tiro_rifle": [["KRAK!", "PÁ!"], Color("ffe66d"), 34, 3.5],
	"acerto": [["POW!", "TUM!", "PAF!"], Color("f7f3e3"), 28, 1.5],
	"machado": [["TCHAC!"], Color("f7f3e3"), 28, 0.0],
	"martelo": [["TOC!", "TOC TOC!"], Color("f2d27a"), 24, 0.0],
	"vidro": [["CRASH!"], Color("9ad1ff"), 30, 0.0],
	"molotov": [["FWUUSH!"], Color("ff7b3a"), 38, 3.0],
	"mordida": [["NHAC!"], Color("ff5c5c"), 30, 0.0],
	"buzina": [["BI-BIII!"], Color("ffd166"), 30, 0.0],
	"grito": [["AAARGH!"], Color("b6ff6b"), 26, 0.0],
}
var t_onomato := {}


func _ready() -> void:
	rng.seed = 2032
	_gerar()
	for nome in ["vento", "estatica"]:
		var p := AudioStreamPlayer.new()
		p.stream = bancos[nome][0]
		p.volume_db = -80.0
		add_child(p)
		p.play()
		loops[nome] = p


# ---------------------------------------------------------------- tocar

func tocar(nome: String, onde: Variant = null, vol := 0.0, tom := 1.0) -> void:
	if not bancos.has(nome) or main == null:
		return
	var lista: Array = bancos[nome]
	var s: AudioStreamWAV = lista[rng.randi_range(0, lista.size() - 1)]
	if onde == null:
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = vol
		p.pitch_scale = tom * rng.randf_range(0.96, 1.04)
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		return
	# som no mundo: só toca se estiver perto da câmera (economiza o processador do console)
	var cam_pos: Vector2 = main.cam.global_position
	var pos: Vector2 = onde
	if pos.distance_to(cam_pos) > 1600.0:
		return
	_onomato(nome, pos)
	var p2 := AudioStreamPlayer2D.new()
	p2.stream = s
	p2.volume_db = vol
	p2.pitch_scale = tom * rng.randf_range(0.94, 1.06)
	p2.max_distance = 1500.0
	p2.attenuation = 1.6
	p2.global_position = pos
	main.add_child(p2)
	p2.play()
	p2.finished.connect(p2.queue_free)


func _onomato(nome: String, pos: Vector2) -> void:
	if not ONOMATO.has(nome) or not main.has_method("onomato"):
		return
	var agora := Time.get_ticks_msec()
	if agora - int(t_onomato.get(nome, -1000)) < 140:      # rajada: um só texto
		return
	t_onomato[nome] = agora
	var o: Array = ONOMATO[nome]
	var textos: Array = o[0]
	main.onomato(textos[rng.randi_range(0, textos.size() - 1)], pos + Vector2(rng.randf_range(-18, 18), -58), o[1], o[2])
	if o[3] > 0.0 and pos.distance_to(main.cam.global_position) < 700.0:
		main.tremer(o[3])


func passo(quem: Node2D, correndo: bool) -> void:
	var id := quem.get_instance_id()
	var agora := Time.get_ticks_msec()
	if agora - int(t_passos.get(id, 0)) < (230 if correndo else 380):
		return
	t_passos[id] = agora
	tocar("passo", quem.global_position, -14.0 if not correndo else -9.0)


func _process(d: float) -> void:
	if main == null or main.jogadores.is_empty():
		_ajustar("vento", -80.0, d)
		_ajustar("estatica", -80.0, d)
		return
	_ajustar("vento", -20.0 + main.noite() * 6.0 if main.estado != main.TITULO else -26.0, d)
	_ajustar("estatica", -14.0 if main.estado == main.CONVERSA and main.historia.no_radio else -80.0, d)
	if not main.jogando():
		return
	# contador geiger: estalos cada vez mais rápidos perto da radiação
	var nivel: float = 0.0
	for j in main.jogadores:
		nivel = maxf(nivel, main.radiacao_em(j.global_position))
	if nivel > 0.0:
		t_geiger -= d
		if t_geiger <= 0.0:
			t_geiger = rng.randf_range(0.02, 0.5) / (0.2 + nivel * 3.0)
			tocar("geiger", null, -16.0 + nivel * 6.0)
	# coração quando a vida está baixa
	var pior := 1.0
	for j in main.jogadores:
		pior = minf(pior, j.hp / j.hp_max)
	if pior < 0.3:
		t_coracao -= d
		if t_coracao <= 0.0:
			t_coracao = 0.55 + pior * 1.5
			tocar("coracao", null, -6.0)


func _ajustar(nome: String, alvo: float, d: float) -> void:
	var p: AudioStreamPlayer = loops[nome]
	p.volume_db = move_toward(p.volume_db, alvo, 40.0 * d)


# ---------------------------------------------------------------- síntese

func _wav(amostras: PackedFloat32Array, loop := false, pico := 0.85) -> AudioStreamWAV:
	# normaliza: todo som sai com o mesmo pico; o volume relativo fica no tocar(..., vol)
	var maior := 0.0
	for v in amostras:
		maior = maxf(maior, absf(v))
	if maior > 0.0:
		var k := pico / maior
		for i in amostras.size():
			amostras[i] *= k
	var bytes := PackedByteArray()
	bytes.resize(amostras.size() * 2)
	for i in amostras.size():
		bytes.encode_s16(i * 2, int(clampf(amostras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = amostras.size()
	return w


func _buf(seg: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seg * TAXA))
	return b


func _add(nome: String, w: AudioStreamWAV) -> void:
	if not bancos.has(nome):
		bancos[nome] = []
	bancos[nome].append(w)


func _ruido_filtrado(seg: float, corte: float, decai: float, ganho := 1.0, ataque := 0.002) -> PackedFloat32Array:
	## ruído com passa-baixa de 1 polo e envelope ataque/decaimento exponencial
	var b := _buf(seg)
	var a := clampf(corte / TAXA * 6.28, 0.0, 1.0)
	var y := 0.0
	for i in b.size():
		var t := float(i) / TAXA
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		var env := minf(t / ataque, 1.0) * exp(-t * decai)
		b[i] = y * env * ganho
	return b


func _misturar(a: PackedFloat32Array, b: PackedFloat32Array, gb := 1.0) -> PackedFloat32Array:
	var r := a.duplicate()
	if b.size() > r.size():
		r.resize(b.size())
	for i in b.size():
		r[i] += b[i] * gb
	return r


func _seno(seg: float, f0: float, f1: float, decai: float, ganho := 1.0) -> PackedFloat32Array:
	var b := _buf(seg)
	var fase := 0.0
	for i in b.size():
		var t := float(i) / TAXA
		var f := lerpf(f0, f1, t / seg)
		fase += TAU * f / TAXA
		b[i] = sin(fase) * exp(-t * decai) * ganho
	return b


func _gemido(seg: float, f0: float, f1: float, aspereza: float, ganho := 0.7) -> PackedFloat32Array:
	## "voz" de zumbi: dente de serra grave com vibrato, passando por dois filtros (formantes) + respiração
	var b := _buf(seg)
	var fase := 0.0
	var bp1 := [0.0, 0.0]
	var bp2 := [0.0, 0.0]
	var f_a := 520.0
	var f_b := 1150.0
	for i in b.size():
		var t := float(i) / TAXA
		var u := t / seg
		var f := lerpf(f0, f1, u) * (1.0 + 0.05 * sin(TAU * 5.5 * t) + rng.randf_range(-0.02, 0.02) * aspereza)
		fase = fmod(fase + f / TAXA, 1.0)
		var serra := fase * 2.0 - 1.0 + rng.randf_range(-1.0, 1.0) * 0.25 * aspereza
		# dois ressonadores simples (formantes "oh")
		var s1 := _ressoar(serra, f_a, 0.92, bp1)
		var s2 := _ressoar(serra, f_b, 0.9, bp2)
		var env := sin(PI * clampf(u, 0.0, 1.0)) * (0.7 + 0.3 * sin(TAU * 2.3 * t))
		b[i] = (s1 * 0.8 + s2 * 0.45) * env * ganho
	return _misturar(b, _ruido_filtrado(seg, 1800.0, 1.2, 0.08, seg * 0.4))


func _ressoar(x: float, f: float, r: float, m: Array) -> float:
	var w := TAU * f / TAXA
	var y: float = x * (1.0 - r) + 2.0 * r * cos(w) * m[0] - r * r * m[1]
	m[1] = m[0]
	m[0] = y
	return y


func _gerar() -> void:
	# tiros: estalo de ruído + "soco" grave
	_add("tiro_pistola", _wav(_misturar(_ruido_filtrado(0.35, 6000.0, 22.0, 0.9), _seno(0.25, 140.0, 50.0, 14.0, 0.8))))
	_add("tiro_espingarda", _wav(_misturar(_ruido_filtrado(0.6, 3500.0, 9.0, 1.0), _seno(0.4, 90.0, 35.0, 8.0, 1.0))))
	_add("tiro_rifle", _wav(_misturar(_ruido_filtrado(0.7, 9000.0, 12.0, 1.0), _seno(0.3, 200.0, 60.0, 12.0, 0.7))))
	_add("seco", _wav(_ruido_filtrado(0.05, 7000.0, 120.0, 0.5)))                       # gatilho sem bala
	var clique := _ruido_filtrado(0.04, 8000.0, 150.0, 0.6)
	var recarga := _buf(0.45)
	for i in clique.size():
		recarga[i] += clique[i]
		recarga[i + int(0.3 * TAXA)] += clique[i] * 1.2
	_add("recarga", _wav(recarga))
	for k in 3:
		_add("golpe", _wav(_ruido_filtrado(0.22, 900.0 + k * 300.0, 10.0, 0.5, 0.08)))   # vulto
		_add("acerto", _wav(_misturar(_ruido_filtrado(0.15, 1200.0, 30.0, 0.9), _seno(0.15, 120.0 - k * 15.0, 60.0, 25.0, 0.8))))
		_add("passo", _wav(_misturar(_ruido_filtrado(0.08, 500.0 + k * 150.0, 50.0, 0.7), _seno(0.06, 90.0, 60.0, 50.0, 0.3))))
	# zumbis: quatro gemidos, um rosnado de alerta e o grito do corredor
	_add("gemido", _wav(_gemido(1.4, 105.0, 85.0, 1.0)))
	_add("gemido", _wav(_gemido(1.1, 125.0, 95.0, 0.7)))
	_add("gemido", _wav(_gemido(1.7, 90.0, 110.0, 1.2)))
	_add("gemido", _wav(_gemido(0.9, 140.0, 100.0, 0.9)))
	_add("rosnado", _wav(_gemido(0.7, 160.0, 120.0, 1.6, 0.9)))
	_add("grito", _wav(_gemido(0.8, 340.0, 260.0, 1.4, 0.8)))
	_add("brutamontes", _wav(_gemido(1.6, 62.0, 50.0, 1.4, 1.0)))
	_add("mordida", _wav(_misturar(_ruido_filtrado(0.25, 2500.0, 14.0, 0.8), _seno(0.2, 180.0, 70.0, 16.0, 0.5))))
	_add("dor", _wav(_gemido(0.35, 220.0, 170.0, 0.6, 0.6)))
	# mundo
	_add("pegar", _wav(_misturar(_seno(0.12, 880.0, 880.0, 25.0, 0.35), _seno(0.18, 1320.0, 1320.0, 18.0, 0.25))))
	_add("ui", _wav(_seno(0.06, 1100.0, 1300.0, 40.0, 0.25)))
	_add("ui_ok", _wav(_misturar(_seno(0.1, 700.0, 700.0, 25.0, 0.3), _seno(0.14, 1050.0, 1050.0, 20.0, 0.25))))
	_add("lanterna", _wav(_ruido_filtrado(0.03, 6000.0, 200.0, 0.5)))
	for k in 2:
		_add("martelo", _wav(_misturar(_ruido_filtrado(0.18, 800.0, 25.0, 0.9), _seno(0.18, 160.0 + k * 30.0, 90.0, 22.0, 0.9))))
		_add("machado", _wav(_misturar(_ruido_filtrado(0.25, 1500.0, 18.0, 0.9), _seno(0.25, 110.0 + k * 20.0, 70.0, 14.0, 0.9))))
	_add("abrir", _wav(_misturar(_seno(0.45, 180.0, 260.0, 4.0, 0.25), _ruido_filtrado(0.45, 900.0, 5.0, 0.35, 0.1))))
	var buzina := _buf(0.7)
	for i in buzina.size():
		var t := float(i) / TAXA
		var env := minf(t * 40.0, 1.0) * minf((0.7 - t) * 20.0, 1.0)
		buzina[i] = (signf(sin(TAU * 415.0 * t)) * 0.25 + signf(sin(TAU * 523.0 * t)) * 0.2) * env
	_add("buzina", _wav(buzina))
	# motor: 1 s com número inteiro de ciclos, para emendar sem estalo
	var motor := _buf(1.0)
	for i in motor.size():
		var t := float(i) / TAXA
		motor[i] = (sin(TAU * 42.0 * t) * 0.5 + sin(TAU * 84.0 * t) * 0.25 + sin(TAU * 126.0 * t + 1.0) * 0.15 + signf(sin(TAU * 21.0 * t)) * 0.08) * 0.6
	_add("motor", _wav(motor, true))
	# fogo (crepitar) e vento: laços
	var fogo := _ruido_filtrado(2.0, 1200.0, 0.0, 0.25, 0.001)
	for k in 30:
		var at := rng.randi_range(0, fogo.size() - 600)
		for i in 500:
			fogo[at + i] += rng.randf_range(-1, 1) * exp(-i / 60.0) * 0.8
	_add("fogo", _wav(fogo, true))
	var vento := _buf(4.0)
	var y := 0.0
	for i in vento.size():
		var t := float(i) / TAXA
		y += 0.02 * (rng.randf_range(-1, 1) - y)
		vento[i] = y * (0.6 + 0.4 * sin(TAU * 0.25 * t)) * 1.6
	_add("vento", _wav(vento, true))
	var est := _ruido_filtrado(1.0, 4000.0, 0.0, 0.25, 0.001)
	_add("estatica", _wav(est, true))
	_add("geiger", _wav(_ruido_filtrado(0.012, 9000.0, 500.0, 0.9, 0.0005)))
	var coracao := _misturar(_seno(0.15, 60.0, 45.0, 20.0, 1.0), _buf(0.4))
	var batida2 := _seno(0.15, 55.0, 40.0, 22.0, 0.8)
	for i in batida2.size():
		coracao[i + int(0.22 * TAXA)] += batida2[i]
	_add("coracao", _wav(coracao))
	_add("molotov", _wav(_misturar(_ruido_filtrado(0.15, 5000.0, 30.0, 0.6), _ruido_filtrado(1.2, 700.0, 2.5, 0.7, 0.05))))
	_add("vidro", _wav(_misturar(_seno(0.3, 2600.0, 2400.0, 14.0, 0.3), _ruido_filtrado(0.2, 8000.0, 25.0, 0.6))))
	_add("salvo", _wav(_misturar(_misturar(_seno(0.5, 523.0, 523.0, 5.0, 0.25), _seno(0.5, 659.0, 659.0, 5.0, 0.2)), _seno(0.6, 784.0, 784.0, 4.0, 0.2))))
