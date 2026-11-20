extends Node
## Trilha do DEADZONE em três camadas que sobem e descem com o jogo:
##   tema   — "Estrada Morta" (Am, 70 bpm): título, quadrinhos e fim de capítulo
##   tensao — zumbido grave e vento de cordas enquanto se explora
##   perigo — pulso de cordas que cresce com o número de zumbis atrás de você
## Se existir arte/musica/<nome>.ogg (ou .wav), toca o arquivo: é onde entram as gravações do Sky no violão.
## Sem arquivo, a música é sintetizada: o violão do tema usa Karplus-Strong (corda dedilhada feita com um
## ruído curto que passa repetidas vezes por uma linha de atraso com filtro). A síntese roda numa thread
## na primeira vez e fica guardada em user://, então nas próximas o jogo abre na hora.

const TAXA := 22050
const BPM := 70.0
const VERSAO_CACHE := 1
const CAMADAS := ["tema", "tensao", "perigo"]

var main: Node2D
var tocadores := {}        # nome -> AudioStreamPlayer
var prontos := {}          # nome -> true quando o stream chegou
var _tarefa := -1
var _pcm := {}             # resultado da thread (nome -> PackedByteArray)
var _mutex := Mutex.new()


func _ready() -> void:
	for nome in CAMADAS:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		tocadores[nome] = p
		var arquivo := _arquivo_do_sky(nome)
		if arquivo:
			_usar(nome, arquivo)
	var faltam: Array = CAMADAS.filter(func(n): return not prontos.has(n))
	if faltam.is_empty():
		return
	# o que já foi sintetizado antes vem do cache; o resto é feito numa thread
	var gerar: Array = []
	for nome in faltam:
		var b := FileAccess.get_file_as_bytes(_cache(nome))
		if b.size() > 0:
			_usar(nome, _wav(b))
		else:
			gerar.append(nome)
	if not gerar.is_empty():
		_tarefa = WorkerThreadPool.add_task(_sintetizar.bind(gerar), false, "musica")


func pronta() -> bool:
	return prontos.size() == CAMADAS.size()


func _arquivo_do_sky(nome: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var p := ProjectSettings.globalize_path("res://arte/musica/%s.%s" % [nome, ext])
		if FileAccess.file_exists(p):
			var s: AudioStream = AudioStreamOggVorbis.load_from_file(p) if ext == "ogg" else AudioStreamWAV.load_from_file(p)
			if s:
				if s is AudioStreamOggVorbis:
					s.loop = true
				elif s is AudioStreamWAV:
					s.loop_mode = AudioStreamWAV.LOOP_FORWARD
					s.loop_end = int(s.get_length() * s.mix_rate)
				return s
	return null


func _cache(nome: String) -> String:
	return "user://musica_v%d_%s.pcm" % [VERSAO_CACHE, nome]


func _usar(nome: String, s: AudioStream) -> void:
	tocadores[nome].stream = s
	prontos[nome] = true


func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = bytes.size() / 2
	return w


# ---------------------------------------------------------------- mixagem

func _process(d: float) -> void:
	if _tarefa >= 0 and WorkerThreadPool.is_task_completed(_tarefa):
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
		_mutex.lock()
		for nome in _pcm:
			var f := FileAccess.open(_cache(nome), FileAccess.WRITE)
			if f:
				f.store_buffer(_pcm[nome])
				f.close()
			_usar(nome, _wav(_pcm[nome]))
		_pcm.clear()
		_mutex.unlock()
	if main == null:
		return
	var alvo := {"tema": -80.0, "tensao": -80.0, "perigo": -80.0}
	match main.estado:
		main.TITULO:
			alvo["tema"] = -9.0
		main.CAPITULO:
			alvo["tema"] = -8.0
		main.CONVERSA:
			if main.historia.fala_atual().has("hq"):
				alvo["tema"] = -13.0
			else:
				alvo["tensao"] = -27.0
		main.JOGANDO, main.PAUSA, main.MOCHILA:
			alvo["tensao"] = -24.0 + main.noite() * 5.0
			var n := perseguidores()
			if main.fase_alerta == "EVASÃO":
				alvo["perigo"] = -32.0                 # ainda procurando você
			if n > 0:
				alvo["perigo"] = -24.0 + minf(n, 6) * 2.4
				alvo["tensao"] -= 4.0
	for nome in CAMADAS:
		var p: AudioStreamPlayer = tocadores[nome]
		if not prontos.has(nome):
			continue
		# sobe rápido (o perigo chega de repente) e desce devagar (o susto demora a passar)
		var vel := 60.0 if alvo[nome] > p.volume_db else 14.0
		p.volume_db = move_toward(p.volume_db, alvo[nome], vel * d)
		if p.volume_db > -79.0 and not p.playing:
			p.play()
		elif p.volume_db <= -79.0 and p.playing:
			p.stop()


func perseguidores() -> int:
	var n := 0
	for z in main.zumbis:
		if is_instance_valid(z) and z.alerta and z.alvo != null:
			for j in main.jogadores:
				if j.global_position.distance_to(z.global_position) < 650.0:
					n += 1
					break
	return n


# ---------------------------------------------------------------- síntese (thread)

func _sintetizar(nomes: Array) -> void:
	for nome in nomes:
		var a: PackedFloat32Array
		match nome:
			"tema":
				a = _tema()
			"tensao":
				a = _tensao()
			"perigo":
				a = _perigo()
		var b := _pcm16(a)
		_mutex.lock()
		_pcm[nome] = b
		_mutex.unlock()


func _pcm16(a: PackedFloat32Array) -> PackedByteArray:
	var maior := 0.0
	for v in a:
		maior = maxf(maior, absf(v))
	var k := 0.8 / maior if maior > 0.0 else 1.0
	var b := PackedByteArray()
	b.resize(a.size() * 2)
	for i in a.size():
		b.encode_s16(i * 2, int(clampf(a[i] * k, -1.0, 1.0) * 32000.0))
	return b


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


func _corda(saida: PackedFloat32Array, inicio: int, midi: int, vol: float, dur: float, brilho := 0.5) -> void:
	## Karplus-Strong: ruído do tamanho de um período, realimentado com média de vizinhos (perde agudos)
	var n := maxi(2, int(round(TAXA / _hz(midi))))
	var linha := PackedFloat32Array()
	linha.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = midi * 7919 + inicio
	var ant := 0.0
	for i in n:
		# ruído já um pouco filtrado: ataque de dedo, não de palheta
		var r := rng.randf_range(-1.0, 1.0)
		ant = ant + (r - ant) * brilho
		linha[i] = ant
	var total := mini(int(dur * TAXA), saida.size() - inicio)
	var idx := 0
	var decai := 0.4985 + 0.0013 * clampf((60.0 - midi) / 30.0, -1.0, 1.0)   # graves soam mais
	for i in total:
		var atual := linha[idx]
		var prox := linha[(idx + 1) % n]
		linha[idx] = (atual + prox) * decai
		var env := 1.0 if i < total - 800 else float(total - i) / 800.0
		saida[inicio + i] += atual * vol * env
		idx = (idx + 1) % n


const ACORDES := {
	"Am": [45, 52, 57, 60, 64], "F": [41, 48, 53, 57, 60], "C": [48, 52, 55, 60, 64],
	"G": [43, 47, 50, 55, 59], "E": [40, 47, 52, 56, 59], "Dm": [50, 57, 62, 65, 69],
}


func _tema() -> PackedFloat32Array:
	## cifra que o Sky vai tocar: verso Am F C G | Am F E E, refrão F G Am Am | F G E E, final Dm Am E Am
	var forma := ["Am", "F", "C", "G", "Am", "F", "E", "E",
		"F", "G", "Am", "Am", "F", "G", "E", "E",
		"Am", "F", "C", "G", "Dm", "Am", "E", "Am"]
	var colcheia := 60.0 / BPM / 2.0
	var saida := PackedFloat32Array()
	saida.resize(int((forma.size() * 8 * colcheia + 0.2) * TAXA))
	# dedilhado: baixo, 3a, 2a, 1a, 2a, 3a, 2a, 1a (as três cordas de cima do acorde)
	var padrao := [0, 2, 3, 4, 3, 2, 3, 4]
	for c in forma.size():
		var notas: Array = ACORDES[forma[c]]
		var ultimo := c == forma.size() - 1
		for k in 8:
			if ultimo and k > 0:
				break                                   # o último Am fica soando sozinho
			var t := (c * 8 + k) * colcheia
			var corda: int = padrao[k]
			var vol := 0.9 if k == 0 else (0.55 if k == 4 else 0.42)
			var dur := 2.4 if (k == 0 or ultimo) else 1.3
			# humano: um tiquinho fora do tempo
			var jitter := int(sin(c * 3.1 + k * 1.7) * 0.012 * TAXA)
			_corda(saida, maxi(0, int(t * TAXA) + jitter), notas[corda], vol, dur, 0.55 if k == 0 else 0.4)
	# um eco curto de sala (a gravação vai ter o ambiente de verdade)
	var atraso := int(0.19 * TAXA)
	for i in range(atraso, saida.size()):
		saida[i] += saida[i - atraso] * 0.22
	return saida


func _tensao() -> PackedFloat32Array:
	## zumbido em lá (A1 + E2) com batimento lento e "vento" de ruído filtrado; laço perfeito de 13,7 s
	var seg := 16.0 * 60.0 / BPM
	var saida := PackedFloat32Array()
	var n := int(seg * TAXA)
	saida.resize(n)
	# frequências múltiplas de 1/seg: o fim encaixa no começo sem clique
	var base: float = round(55.0 * seg) / seg
	var quinta: float = round(82.4 * seg) / seg
	var bat: float = round(55.6 * seg) / seg
	var rng := RandomNumberGenerator.new()
	rng.seed = 2033
	var lp := 0.0
	for i in n:
		var t := float(i) / TAXA
		var onda := sin(TAU * base * t) * 0.5 + sin(TAU * bat * t) * 0.35 + sin(TAU * quinta * t) * 0.18
		var resp := 0.6 + 0.4 * sin(TAU * t / seg * 2.0)            # a respiração do drone (2 por laço)
		lp += (rng.randf_range(-1, 1) - lp) * 0.02
		var vento := lp * (0.5 + 0.5 * sin(TAU * t / seg * 3.0 + 1.0))
		saida[i] = onda * resp * 0.6 + vento * 1.4
	# junta o fim no começo (o ruído não é periódico)
	var cf := int(0.5 * TAXA)
	for i in cf:
		var k := float(i) / cf
		saida[i] = saida[i] * k + saida[n - cf + i] * (1.0 - k)
	saida.resize(n - cf)
	return saida


func _perigo() -> PackedFloat32Array:
	## cordas graves em semicolcheia (Am → F → E), duas voltas; dá a pressa de fugir
	var semi := 60.0 / BPM / 4.0
	var forma := [[45, 57], [45, 57], [41, 53], [40, 52]]
	var saida := PackedFloat32Array()
	var n := int(forma.size() * 16 * semi * TAXA)
	saida.resize(n)
	var fase := [0.0, 0.0, 0.0]
	for c in forma.size():
		for k in 16:
			var ini := int((c * 16 + k) * semi * TAXA)
			var fim := mini(n, int((c * 16 + k + 1) * semi * TAXA))
			var acento := 1.0 if k % 4 == 0 else 0.6
			for i in range(ini, fim):
				var tl := float(i - ini) / TAXA
				var env := minf(1.0, tl * 200.0) * exp(-tl * 9.0) * acento
				var v := 0.0
				for j in 2:
					var f := _hz(forma[c][j])
					fase[j] = fmod(fase[j] + f / TAXA, 1.0)
					v += (fase[j] * 2.0 - 1.0) * (0.6 if j == 0 else 0.35)    # dente de serra: corda áspera
				saida[i] = v * env
	# filtro passa-baixa simples para tirar o chiado da serra
	var lp := 0.0
	for i in n:
		lp += (saida[i] - lp) * 0.18
		saida[i] = lp
	return saida
