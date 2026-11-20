#!/usr/bin/env python3
"""Fase 13.2: sky-security com compactados de mentira.

Jogo limpo instala; jogo com programa escondido (.exe, .sh, nome disfarçado) vai para a quarentena e
não é instalado; PS4 com .dll (jogo Unity) passa; liberar devolve o arquivo e ele instala.
Usa o 7-Zip de verdade se tiver (o GitHub tem); senão um 7z de mentira que só entende .zip.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.normpath(os.path.join(AQUI, "..", "bin"))
TMP = tempfile.mkdtemp(prefix="skysec-")
HOME = os.path.join(TMP, "home")
ROMS = os.path.join(HOME, "skystation", "roms")
env = dict(os.environ, HOME=HOME, XDG_RUNTIME_DIR=os.path.join(TMP, "run"), PATH=os.environ["PATH"])
os.makedirs(env["XDG_RUNTIME_DIR"])

if not shutil.which("7z"):
    falso = os.path.join(TMP, "falso-bin")
    os.makedirs(falso)
    with open(os.path.join(falso, "7z"), "w") as f:
        f.write(f"""#!{sys.executable}
import sys, zipfile, os
a = sys.argv[1:]
arq = a[-1]
z = zipfile.ZipFile(arq)
if a[0] == "l":
    for i in z.infolist():
        print("Path = " + i.filename); print("Size = " + str(i.file_size)); print()
elif a[0] == "x":
    dest = [x[2:] for x in a if x.startswith("-o")][0]
    z.extractall(dest)
""")
    os.chmod(os.path.join(falso, "7z"), 0o755)
    env["PATH"] = falso + os.pathsep + env["PATH"]
    print("(sem 7-Zip aqui: usando um de mentira)")
env["PATH"] = env["PATH"]
# o ClamAV, se existir na máquina de teste, não deve atrasar nem mudar o resultado
sem_clam = os.path.join(TMP, "sem-clam")
os.makedirs(sem_clam)
for nome in ("clamscan", "clamdscan"):
    with open(os.path.join(sem_clam, nome), "w") as f:
        f.write("#!/bin/sh\nexit 2\n")
    os.chmod(os.path.join(sem_clam, nome), 0o755)
env["PATH"] = sem_clam + os.pathsep + env["PATH"]


def zipar(sistema, nome, arquivos):
    pasta = os.path.join(ROMS, sistema)
    os.makedirs(pasta, exist_ok=True)
    caminho = os.path.join(pasta, nome)
    with zipfile.ZipFile(caminho, "w") as z:
        for n, conteudo in arquivos.items():
            z.writestr(n, conteudo)
    velho = time.time() - 600            # "terminou de baixar" há 10 min
    os.utime(caminho, (velho, velho))
    return caminho


def roda(*args):
    r = subprocess.run([sys.executable, os.path.join(BIN, args[0])] + list(args[1:]),
                       capture_output=True, text=True, env=env, timeout=120)
    assert r.returncode in (0, 1), r.stderr
    return json.loads(r.stdout.strip().splitlines()[-1])


falhas = 0


def confere(cond, msg):
    global falhas
    print(("ok   " if cond else "FALHOU ") + msg)
    falhas += 0 if cond else 1


# nomes soltos (a regra em si)
sys.path.insert(0, BIN)
import importlib.machinery
SEG = importlib.machinery.SourceFileLoader("sky_security_t", os.path.join(BIN, "sky-security")).load_module()
confere(SEG.suspeito("Jogo.iso.exe"), "nome disfarçado .iso.exe")
confere(SEG.suspeito("jogo‮osi.exe"), "caractere invisível RLO")
confere(SEG.suspeito("Crack/setup.EXE"), "maiúsculas e subpasta")
confere(SEG.suspeito("instalar.sh"), "script de Linux")
confere(not SEG.suspeito("Track 01.bin"), ".bin de jogo passa")
confere(not SEG.suspeito("SLUS_200.62"), "nome de PS2 passa")
confere(not SEG.suspeito("Media/Managed/Assembly-CSharp.dll", "ps4"), ".dll em PS4 (Unity) passa")
confere(SEG.suspeito("Media/Managed/Assembly-CSharp.dll", "ps2"), ".dll em PS2 não passa")
confere(SEG.suspeito("../../.bashrc"), "caminho que sai da pasta")

# instalação de verdade
limpo = zipar("ps2", "God of War.zip", {"God of War.iso": b"\0" * 2048, "readme.html": "<a>site</a>"})
virus = zipar("dreamcast", "Sonic Adventure.zip", {"Sonic.cdi": b"\0" * 2048, "Sonic.cdi.exe": b"MZ"})
script = zipar("psp", "Patapon.zip", {"Patapon.iso": b"\0" * 2048, "instalar.sh": "#!/bin/sh\nrm -rf ~\n"})
unity = zipar("ps4", "Jogo Unity.zip", {"CUSA00001/eboot.bin": b"\x7fELF", "CUSA00001/sce_sys/param.sfo": b"x",
                                        "CUSA00001/Media/Managed/Assembly-CSharp.dll": b"MZ"})
r = roda("sky-instalar", "rodar")
print("   ", r)
confere(os.path.exists(os.path.join(ROMS, "ps2", "God of War.iso")), "jogo limpo instalado")
confere(not os.path.exists(limpo), "compactado limpo apagado depois de instalar")
confere(not os.path.exists(os.path.join(ROMS, "dc", "Sonic.cdi")) and
        not os.path.exists(os.path.join(ROMS, "dreamcast", "Sonic.cdi")), "jogo com .exe NÃO instalado")
confere(not os.path.exists(virus) and not os.path.exists(script), "os dois suspeitos saíram da pasta do jogo")
confere(os.path.isdir(os.path.join(ROMS, "ps4", "CUSA00001")) or os.path.isdir(os.path.join(ROMS, "ps4", "Jogo Unity")),
        "PS4 com .dll (Unity) instalado")
confere(any("sky-security" in e["erro"] for e in r["erros"]), "erro diz que foi o sky-security")

q = roda("sky-security", "quarentena")["itens"]
confere(len(q) == 2, f"2 itens na quarentena ({len(q)})")
confere(os.path.exists(os.path.join(ROMS, "seguranca", "eventos.log")), "log em SKYROMS/seguranca/eventos.log")
falhas_json = os.path.join(HOME, ".cache/skystation/instalar-falhas.json")
confere(not os.path.exists(falhas_json) or "Sonic" not in open(falhas_json).read(), "bloqueado não vira 'falha'")

# liberar o Patapon (você confia): volta para a pasta e instala
pat = [i for i in q if "Patapon" in i["id"]][0]
confere(roda("sky-security", "liberar", pat["id"])["ok"], "liberar devolve o arquivo")
confere(os.path.exists(script), "Patapon.zip de volta na pasta psp")
roda("sky-instalar", "rodar")
confere(os.path.exists(os.path.join(ROMS, "psp", "Patapon")), "liberado instala na próxima rodada")

son = [i for i in roda("sky-security", "quarentena")["itens"] if "Sonic" in i["id"]][0]
confere(roda("sky-security", "apagar", son["id"])["ok"], "apagar tira da quarentena")
confere(roda("sky-security", "quarentena")["itens"] == [], "quarentena vazia no fim")

shutil.rmtree(TMP, ignore_errors=True)
print("tudo certo" if not falhas else f"{falhas} falha(s)")
sys.exit(1 if falhas else 0)
