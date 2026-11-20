extends SceneTree
## Regressão de 20/nov: o leitor do cano (_pipe_reader) ficava girando para sempre depois que o
## processo terminava, gastando um núcleo inteiro (o Godot 4.5 nunca marca eof_reached no cano).
## Roda o leitor de verdade do main.gd e exige que ele termine logo depois do processo.

func _init() -> void:
	var menu = load("res://main.gd").new()
	var t0 := Time.get_ticks_msec()
	var info := OS.execute_with_pipe("sh", PackedStringArray(["-c", "echo '{\"a\": 1}'; sleep 0.3; echo fim"]))
	var th := Thread.new()
	th.start(menu._pipe_reader.bind(info["stdio"], "_on_job_line", int(info["pid"])))
	while th.is_alive() and Time.get_ticks_msec() - t0 < 5000:
		OS.delay_msec(50)
	var ms := Time.get_ticks_msec() - t0
	if th.is_alive():
		print("RESULTADO: falhou — o leitor continuou girando depois do processo (", ms, " ms)")
		quit(1)
		return
	th.wait_to_finish()
	print("RESULTADO: tudo certo — o leitor terminou em ", ms, " ms")
	menu.free()
	quit(0)
