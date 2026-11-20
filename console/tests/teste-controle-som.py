#!/usr/bin/env python3
"""Teste do sky-controle-som (som no alto-falante do controle): acha a saída de som do controle Sony no
PipeWire (pactl falso), toca no controle certo de cada jogador (pw-play falso) e o modo servidor que o
DEADZONE usa. Não precisa de controle, de PipeWire nem de som.

    python3 console/tests/teste-controle-som.py
"""
import os
import stat
import subprocess
import sys
import tempfile

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")
RAIZ = tempfile.mkdtemp(prefix="skysom-")
FALSOS = os.path.join(RAIZ, "bin")
LOG = os.path.join(RAIZ, "tocou.log")
os.makedirs(FALSOS)
passos = 0


def ok(cond, msg):
    global passos
    if not cond:
        raise AssertionError(msg)
    passos += 1
    print("  ok  " + msg, flush=True)


def falso(nome, corpo):
    p = os.path.join(FALSOS, nome)
    with open(p, "w") as f:
        f.write("#!/bin/sh\n" + corpo + "\n")
    os.chmod(p, os.stat(p).st_mode | stat.S_IEXEC)


falso("pactl", """cat <<'X'
41\talsa_output.pci-0000_00_1f.3.analog-stereo\tPipeWire\ts32le 2ch 48000Hz\tRUNNING
57\talsa_output.usb-Sony_Interactive_Entertainment_Wireless_Controller-00.analog-stereo\tPipeWire\ts16le 2ch 32000Hz\tIDLE
63\talsa_output.usb-Sony_Interactive_Entertainment_DualSense_Wireless_Controller-00.analog-surround-40\tPipeWire\ts16le 4ch 48000Hz\tIDLE
X""")
falso("pw-play", 'echo "$@" >> "%s"' % LOG)
ENV = dict(os.environ, PATH=FALSOS + ":" + os.environ.get("PATH", ""))
PROG = [sys.executable, os.path.join(BIN, "sky-controle-som")]
WAV = os.path.join(RAIZ, "gemido.wav")
open(WAV, "wb").write(b"RIFF0000WAVE")


def rodar(*args, entrada=None):
    return subprocess.run(PROG + list(args), env=ENV, capture_output=True, text=True, input=entrada, timeout=20)


def log(minimo=0):
    # o pw-play roda solto (Popen): espera ele escrever
    import time
    for _ in range(100):
        linhas = open(LOG).read().splitlines() if os.path.exists(LOG) else []
        if len(linhas) >= minimo:
            return linhas
        time.sleep(0.05)
    return linhas


print("sky-controle-som")
r = rodar("lista")
linhas = [l for l in r.stdout.splitlines() if l and l[0].isdigit()]
ok(r.returncode == 0 and len(linhas) == 2, "lista só as saídas dos controles Sony (2), não a placa de som do PC")
ok("DualSense" in linhas[0] and "Wireless_Controller-00" in linhas[1], "ordem estável (por nome): controle 1, controle 2")

r = rodar("tocar", WAV, "0.5", "2")
ok(r.returncode == 0, "tocar no controle 2")
ult = log(1)[-1]
ok("--target" in ult and "Wireless_Controller-00" in ult and "0.50" in ult and WAV in ult, "pw-play recebeu a saída do controle 2, o volume e o arquivo")

r = rodar("tocar", WAV, "0.8", "9")
ok("Wireless_Controller-00" in log(2)[-1], "jogador sem controle com som: usa o último que existe")

r = rodar("tocar", os.path.join(RAIZ, "nao-existe.wav"), "0.8", "1")
ok(r.returncode == 1, "arquivo que não existe: não toca, sai com erro")

antes = len(log())
r = rodar("servidor", entrada="tocar %s 0.7 1\ntocar %s 1.4 2\nlixo\nsair\n" % (WAV, WAV))
ok(r.stdout.startswith("controles 2"), "servidor avisa quantos controles têm som")
novos = log(antes + 2)[antes:]
ok(len(novos) == 2, "servidor tocou as 2 linhas válidas e ignorou o lixo")
ok("1.00" in novos[1], "volume acima de 1 é limitado a 1")

falso("pactl", "echo")
r = rodar("lista")
ok(r.returncode == 0 and r.stdout.strip() == "", "sem controle no cabo: lista vazia (o jogo toca na TV)")

print("tudo certo (%d verificações)" % passos)
