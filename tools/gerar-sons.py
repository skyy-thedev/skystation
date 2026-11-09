#!/usr/bin/env python3
"""SkyStation: gera os sons de aviso e a música ambiente (tudo original, sintetizado).

Uso (no PC de desenvolvimento, precisa de numpy e ffmpeg):  python3 tools/gerar-sons.py
Saída: console/sounds/*.wav (avisos) e console/sounds/ambiente.ogg (música do menu).
Os arquivos gerados vão para o repositório; o console não precisa de numpy.
"""
import os
import subprocess
import wave

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "console", "sounds")
RATE = 44100
TAU = 2 * np.pi


def note(f, dur, amp=0.5, attack=0.004, decay=0.25, harm=(1.0, 0.3, 0.08), vib=0.0):
    t = np.arange(int(dur * RATE)) / RATE
    env = np.minimum(1.0, t / attack) * np.exp(-t / decay)
    v = sum(a * np.sin(TAU * f * (i + 1) * t + i * 0.4) for i, a in enumerate(harm))
    if vib:
        v *= 1 + vib * np.sin(TAU * 5.5 * t)
    return v * env * amp


def seq(parts, dur):
    out = np.zeros(int(dur * RATE))
    for start, sig in parts:
        s = int(start * RATE)
        n = min(len(sig), len(out) - s)
        out[s:s + n] += sig[:n]
    return out


def echo(x, delay=0.12, fb=0.3, n=3):
    out = x.copy()
    d = int(delay * RATE)
    for k in range(1, n + 1):
        out[d * k:] += x[:len(x) - d * k] * (fb ** k)
    return out


def save(name, x, gain=0.8):
    x = np.tanh(x * 1.1) * gain
    fade = min(len(x), int(0.02 * RATE))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32000).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


C5, E5, G5, A5, B5, D6, E6 = 523.25, 659.25, 783.99, 880.0, 987.77, 1174.66, 1318.5
A4, D5, F5s = 440.0, 587.33, 739.99

# controle conectado: dois toques subindo, brilhantes
save("controle-on.wav", echo(seq([(0, note(E5, .25, .5)), (.07, note(B5, .35, .5))], .6), .1, .25))
# controle desconectado: os mesmos, descendo e mais suaves
save("controle-off.wav", echo(seq([(0, note(B5, .25, .4)), (.08, note(E5, .35, .4, decay=.18))], .6), .1, .2))
# dispositivo USB: um "plim" curto
save("usb-on.wav", seq([(0, note(D6, .2, .45, decay=.08)), (.045, note(A5 * 2, .2, .25, decay=.06))], .3))
save("usb-off.wav", seq([(0, note(A5 * 2, .2, .35, decay=.06)), (.05, note(D6 * .75, .2, .3, decay=.08))], .3))
# pendrive de jogos: acorde aberto (três notas em cascata)
save("pendrive-on.wav", echo(seq([(0, note(D5, .5, .4, decay=.3)), (.06, note(A5, .5, .35, decay=.3)),
                                  (.12, note(E6, .5, .3, decay=.3))], .9), .14, .3))
save("pendrive-off.wav", echo(seq([(0, note(E6, .4, .3, decay=.2)), (.07, note(A5, .4, .3, decay=.2)),
                                   (.14, note(D5, .5, .35, decay=.25))], .8), .14, .25))
# jogo novo: arpejo cintilante subindo
arp = [C5, E5, G5, C5 * 2, E5 * 2]
save("jogo-novo.wav", echo(seq([(i * .06, note(f, .5, .32, decay=.22, harm=(1, .15))) for i, f in enumerate(arp)], 1.2), .16, .35))
# capas baixadas / atualização disponível: sino suave
bell = lambda f, a: note(f, 1.4, a, attack=.002, decay=.6, harm=(1, .5, .25, .12))
save("atualizacao.wav", echo(seq([(0, bell(A5, .35)), (.18, bell(E6, .28))], 1.8), .2, .3))
# carregador ligado: varredura subindo
t = np.arange(int(.35 * RATE)) / RATE
f = 500 + 900 * (t / t[-1]) ** 2
sweep = np.sin(TAU * np.cumsum(f) / RATE) * np.minimum(1, t / .01) * np.exp(-t / .2) * .4
save("carregando.wav", seq([(0, sweep), (.25, note(E6, .3, .3, decay=.12))], .7))
save("descarregando.wav", seq([(0, sweep[::-1] * .8)], .4))
# bateria baixa: dois pulsos graves e calmos
low = lambda: note(A4 / 2, .32, .55, attack=.01, decay=.15, harm=(1, .45, .2))
save("bateria-baixa.wav", seq([(0, low()), (.38, low())], .8))
# bateria crítica / calor: três pulsos mais tensos
tense = lambda: note(311.13, .22, .5, attack=.005, decay=.1, harm=(1, .5, .3, .15))
save("alerta.wav", seq([(0, tense()), (.25, tense()), (.5, tense())], .85))
# captura de tela: "clique" de obturador (ruído curto + corpo)
rng = np.random.default_rng(7)
t = np.arange(int(.12 * RATE)) / RATE
click = rng.standard_normal(len(t)) * np.exp(-t / .012) * .35
save("captura.wav", seq([(0, click), (.05, click * .7), (.02, note(1800, .08, .15, decay=.02))], .25))
# estado salvo / carregado
save("salvo.wav", seq([(0, note(G5, .3, .4, decay=.15)), (.08, note(D6, .4, .4, decay=.2))], .6))
save("carregado.wav", seq([(0, note(D6, .3, .4, decay=.15)), (.08, note(G5, .4, .4, decay=.2))], .6))


# ---------------------------------------------------------------- música ambiente
def ambient(seconds=64.0):
    """Pad lento em 4 acordes (16 s cada) + sininhos esparsos + "reverb" por ecos. Loop sem emenda."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    chords = [  # Lá maior com nona / Fá# menor 11 / Ré maior 7+ / Mi suspenso
        [110.0, 220.0, 277.18, 329.63, 493.88],
        [92.5, 185.0, 220.0, 277.18, 329.63],
        [73.42, 146.83, 220.0, 277.18, 369.99],
        [82.41, 164.81, 246.94, 293.66, 369.99],
    ]
    seg = seconds / len(chords)
    for i, ch in enumerate(chords):
        # cada acorde entra suave e sai suave, sobrepondo 4 s com o próximo (e o último com o primeiro)
        center = i * seg + seg / 2
        dist = np.minimum(np.abs(t - center), seconds - np.abs(t - center))
        env = np.clip((seg / 2 + 4 - dist) / 4, 0, 1) ** 2
        for k, f in enumerate(ch):
            det = 1 + (k % 2) * 0.002
            v = np.sin(TAU * f * t) + 0.5 * np.sin(TAU * f * det * 2 * t + k)
            v *= 1 + 0.15 * np.sin(TAU * (0.07 + 0.013 * k) * t + k)   # respiração lenta
            out += v * env * (0.06 if f < 120 else 0.045)
    # sininhos: notas da escala de Lá maior em momentos "aleatórios" fixos
    rng = np.random.default_rng(42)
    scale = [880.0, 987.77, 1108.73, 1318.51, 1479.98]
    for _ in range(26):
        st = rng.uniform(0, seconds - 3)
        f = rng.choice(scale)
        s = int(st * RATE)
        bt = np.arange(int(2.8 * RATE)) / RATE
        b = (np.sin(TAU * f * bt) + 0.3 * np.sin(TAU * f * 2.01 * bt)) * np.exp(-bt / 0.9) * np.minimum(1, bt / .01) * 0.05
        out[s:s + len(b)] += b
    # "reverb": ecos em cascata, dando a volta no loop
    wet = np.zeros(n)
    for d, g in [(0.23, .35), (0.41, .25), (0.67, .18), (1.1, .12), (1.7, .08)]:
        wet += np.roll(out, int(d * RATE)) * g
    out = out + wet
    out = out / np.max(np.abs(out)) * 0.5
    return out


x = ambient()
stereo = np.stack([x, np.roll(x, int(0.011 * RATE))], axis=1)   # leve abertura estéreo
tmp = os.path.join(OUT, "_ambiente.wav")
with wave.open(tmp, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes((stereo * 32000).astype("<i2").tobytes())
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "2",
                os.path.join(OUT, "ambiente.ogg")], check=True)
os.remove(tmp)
print("sons gerados em", os.path.abspath(OUT))
