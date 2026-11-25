#!/usr/bin/env python3
"""SkyStation 13.18: emuladores e apps do sistema pela SkyStore. Comando: skystation-emuladores

  skystation-emuladores estado              JSON com cada item: instalado, versão nova, cópia verificada, tarefa
  skystation-emuladores pedir <ação> <id>   (jogador) pede uma tarefa ao serviço root; a SkyStore usa
  skystation-emuladores pedidos             (root, pelo systemd) faz as tarefas pedidas
  skystation-emuladores <ação> <id|todos>   (root) faz agora: instalar | atualizar | reinstalar | restaurar | voltar
                                            (voltar = troca pela versão de antes da última atualização)
  skystation-emuladores verificar <id>      (jogador, pelo sky-run) guarda a cópia verificada do emulador

Fontes: só os sites oficiais (releases no GitHub de cada projeto, buildbot do libretro, repositório da NVIDIA,
pacman do Arch). Nada de espelhos.

Cópia verificada: quando um jogo roda 2 min ou mais e fecha sem travar, o emulador que ele usou é guardado em
SKYROMS/emuladores/verificados/<id>.tar.gz (uma cópia por emulador, a última que funcionou). O sha256 fica no
pendrive do sistema (~/skystation/emuladores/verificados.json), fora do alcance do Windows: na hora de
restaurar, um arquivo trocado no HD é recusado.
"""
import hashlib
import json
import os
import pwd
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

USUARIO = "sky"
VAR = "/var/lib/skystation/emuladores"           # tarefas e a lista de versões novas (root grava, todos leem)
PEDIDOS = "/var/lib/skystation/pedidos"
LOG = "/var/log/skystation-instalar.log"
CORES = "/opt/skystation/emu/cores"
BUILDBOT = "https://buildbot.libretro.com/nightly/linux/x86_64/latest"
AGENTE = "SkyStation/13.18 (+https://github.com/skyy-thedev/skystation)"
ACOES = ("instalar", "atualizar", "reinstalar", "restaurar", "voltar")
SEMANA = 7 * 86400

# tipo: emulador | app.  jeito: appimage (release no GitHub) | xenia | nucleos | manual | pacman | flatpak
CATALOGO = [
    {"id": "rpcs3", "nome": "RPCS3", "sistema": "PS3", "jeito": "appimage", "pasta": "/opt/rpcs3",
     "repo": "RPCS3/rpcs3-binaries-linux", "filtro": r"linux.*\.AppImage$", "fora": "aarch64|arm64",
     "resumo": "Emulador de PlayStation 3"},
    {"id": "pcsx2", "nome": "PCSX2", "sistema": "PS2", "jeito": "appimage", "pasta": "/opt/pcsx2",
     "repo": "PCSX2/pcsx2", "filtro": r"linux-appimage-x64-Qt\.AppImage$", "so_estavel": True,
     "resumo": "Emulador de PlayStation 2"},
    {"id": "cemu", "nome": "Cemu", "sistema": "Wii U", "jeito": "appimage", "pasta": "/opt/cemu",
     "repo": "cemu-project/Cemu", "filtro": r"x86_64\.AppImage$", "resumo": "Emulador de Wii U"},
    {"id": "vita3k", "nome": "Vita3K", "sistema": "PS Vita", "jeito": "appimage", "pasta": "/opt/vita3k",
     "repo": "Vita3K/Vita3K", "filtro": r"\.AppImage$", "preferido": "x86_64", "resumo": "Emulador de PS Vita"},
    {"id": "shadps4", "nome": "shadPS4", "sistema": "PS4", "jeito": "appimage", "pasta": "/opt/shadps4",
     "repo": "shadps4-emu/shadPS4", "filtro": r"linux.*(\.zip|\.AppImage|\.tar\.gz)$", "preferido": "sdl",
     "resumo": "Emulador de PlayStation 4 (experimental)"},
    {"id": "xemu", "nome": "xemu", "sistema": "Xbox", "jeito": "appimage", "pasta": "/opt/xemu",
     "repo": "xemu-project/xemu", "filtro": r"x86_64\.AppImage$", "resumo": "Emulador do Xbox original"},
    {"id": "xenia", "nome": "Xenia Canary", "sistema": "Xbox 360", "jeito": "xenia", "pasta": "/opt/xenia",
     "programa": "xenia_canary", "repos": ["xenia-canary/xenia-canary", "xenia-canary/xenia-canary-releases"],
     "resumo": "Emulador de Xbox 360 (experimental)"},
    {"id": "xenia-edge", "nome": "Xenia Edge", "sistema": "Xbox 360", "jeito": "xenia", "pasta": "/opt/xenia-edge",
     "programa": "xenia_edge", "repos": ["has207/xenia-edge"],
     "resumo": "Segundo emulador de Xbox 360, para jogos que travam no Canary"},
    {"id": "moonlight", "nome": "Moonlight", "sistema": "PC", "jeito": "appimage", "pasta": "/opt/moonlight",
     "repo": "moonlight-stream/moonlight-qt", "filtro": r"x86_64\.AppImage$", "resumo": "Jogar os jogos do seu PC pela rede"},
    {"id": "nucleos", "nome": "Núcleos do RetroArch", "sistema": "PS1, PSP, SNES, N64, GBA, DS, 3DS e outros",
     "jeito": "nucleos", "pasta": CORES, "resumo": "Emuladores dos consoles clássicos (libretro)"},
    {"id": "switch", "nome": "Switch (Eden/Citron)", "sistema": "Switch", "jeito": "manual", "pasta": "/opt/switch",
     "resumo": "Só testes. Você baixa no site oficial e põe em SKYROMS/emuladores"},
    {"id": "youtube", "nome": "YouTube", "tipo": "app", "jeito": "pacman", "jogo": "youtube",
     "pacotes": ["webkitgtk-6.0", "gst-libav", "gst-plugins-good", "gst-plugins-bad"],
     "resumo": "YouTube na TV, com o controle"},
    {"id": "xcloud", "nome": "Xbox Cloud Gaming", "tipo": "app", "jeito": "pacman", "jogo": "xcloud",
     "pacotes": ["chromium"], "resumo": "Jogos do Game Pass pela nuvem"},
    {"id": "geforcenow", "nome": "GeForce NOW", "tipo": "app", "jeito": "flatpak", "jogo": "geforcenow",
     "flatpak": "com.nvidia.geforcenow", "resumo": "Jogos do seu Steam/Epic pela nuvem da NVIDIA"},
    # 13.27: jogos de PC de verdade (Proton/Wine traduzem o DirectX direto para a placa de vídeo, sem emular)
    {"id": "steam", "nome": "Steam", "tipo": "app", "jeito": "flatpak", "jogo": "steam", "remoto": "flathub",
     "flatpak": "com.valvesoftware.Steam", "acesso": ["/mnt/pc"],
     "resumo": "Seus jogos da Steam (os do Windows também, pelo Proton)"},
    {"id": "heroic", "nome": "Heroic (Epic e GOG)", "tipo": "app", "jeito": "flatpak", "jogo": "heroic", "remoto": "flathub",
     "flatpak": "com.heroicgameslauncher.hgl", "acesso": ["/mnt/pc"],
     "resumo": "Seus jogos da Epic Games e da GOG"},
    # 13.38: a geração de quadros do Lossless Scaling no Linux (lsfg-vk), como camada Vulkan dos Flatpaks
    # (Steam e Heroic). Usa o Lossless.dll do SEU Lossless Scaling comprado na Steam: nada dele vem daqui.
    {"id": "lsfg", "nome": "Geração de quadros (Lossless Scaling)", "tipo": "app", "jeito": "flatpak",
     "remoto": "flathub", "flatpak": "org.freedesktop.Platform.VulkanLayer.lsfgvk//25.08",
     "ramos": ["24.08", "25.08"],
     "resumo": "Frame generation 2x a 4x nos jogos de PC (precisa do Lossless Scaling na sua Steam)"},
]
LSFG_APPS = ["com.valvesoftware.Steam", "com.heroicgameslauncher.hgl"]
POR_ID = {e["id"]: e for e in CATALOGO}


def item(i):
    e = POR_ID.get(i)
    if not e:
        raise SystemExit(json.dumps({"ok": False, "error": f"não conheço {i}"}))
    return e


def casa_usuario():
    try:
        return pwd.getpwnam(USUARIO).pw_dir
    except KeyError:
        return os.path.expanduser("~")


def registro_verificados():
    return os.path.join(casa_usuario(), "skystation/emuladores/verificados.json")


def ler_json(p, padrao):
    try:
        with open(p) as f:
            return json.load(f)
    except (OSError, ValueError):
        return padrao


def gravar_json(p, d, modo=0o644):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, ensure_ascii=False)
    os.chmod(tmp, modo)
    os.replace(tmp, p)


def anota(msg):
    try:
        with open(LOG, "a") as f:
            f.write(f"[{time.strftime('%F %T')}] emuladores: {msg}\n")
    except OSError:
        pass


# ---------------------------------------------------------------- o que está instalado

def versao_instalada(e):
    """Versão instalada (texto), "" se não está instalado."""
    j = e["jeito"]
    if j == "pacman":
        if not shutil.which("pacman"):
            return ""
        r = subprocess.run(["pacman", "-Q", *e["pacotes"]], capture_output=True, text=True)
        if r.returncode != 0:
            return ""
        return r.stdout.split("\n")[0].split()[-1]          # a versão do principal
    if j == "flatpak":
        if not shutil.which("flatpak"):
            return ""
        r = subprocess.run(["flatpak", "info", "--show-commit", e["flatpak"]], capture_output=True, text=True)
        return r.stdout.strip()[:10] if r.returncode == 0 else ""
    pasta = e["pasta"]
    if j == "nucleos":
        if not os.path.isdir(pasta) or not any(n.endswith("_libretro.so") for n in os.listdir(pasta)):
            return ""
    elif j == "xenia":
        if not os.path.exists(os.path.join(pasta, e["programa"])):
            return ""
    elif not os.access(os.path.join(pasta, "AppRun"), os.X_OK):
        return ""
    try:
        return open(os.path.join(pasta, ".skystation-versao")).read().strip() or "?"
    except OSError:
        pass
    try:                                     # instalado antes da 13.18: o nome do arquivo baixado tem a versão
        v = versao_do_arquivo(open(os.path.join(pasta, ".skystation-url")).read().strip())
        if v:
            return v
    except OSError:
        pass
    try:
        if j == "manual":
            return open(os.path.join(pasta, "ORIGEM")).read().strip()
    except OSError:
        pass
    return "?"                               # instalado, versão desconhecida


# ---------------------------------------------------------------- versões novas (sites oficiais)

def versao_do_arquivo(url):
    """rpcs3-v0.0.38-18000-abc_linux64.AppImage -> 0.0.38-18000"""
    m = re.search(r"v?(\d+\.\d+(?:\.\d+)*(?:-\d+)?)", os.path.basename(url))
    return m.group(1) if m else ""


def _get(url, timeout=12):
    req = urllib.request.Request(url, headers={"User-Agent": AGENTE, "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def release_nova(e):
    """(versão, url do pacote) mais novo no GitHub do projeto, ou None."""
    repos = e.get("repos") or [e["repo"]]
    for repo in repos:
        try:
            rels = json.loads(_get(f"https://api.github.com/repos/{repo}/releases?per_page=10"))
        except (OSError, ValueError):
            continue
        for rel in rels if isinstance(rels, list) else []:
            if rel.get("draft") or (e.get("so_estavel") and rel.get("prerelease")):
                continue
            urls = [a.get("browser_download_url", "") for a in rel.get("assets", [])]
            filtro = e.get("filtro") or r"linux.*(\.tar\.(gz|xz|zst)|\.zip|\.7z|\.AppImage)$"
            fora = e.get("fora", "") + "|debug|dbg|symbols|\\.sha256|\\.zsync|aarch64|arm64"
            boas = [u for u in urls if re.search(filtro, u, re.I) and not re.search(fora.strip("|"), u, re.I)]
            if e.get("preferido"):
                pref = [u for u in boas if re.search(e["preferido"], u, re.I)]
                boas = pref or boas
            if boas:
                versao = (rel.get("tag_name") or rel.get("name") or "?").strip()
                if not re.search(r"\d", versao) or len(versao) > 24:   # "continuous" (Vita3K), hash de commit
                    versao = versao_do_arquivo(boas[0]) or \
                        (versao[:12] + " " + str(rel.get("published_at", ""))[:10]).strip()
                return versao, boas[0]
    return None


def versoes_novas(forcar=False):
    """{id: versão nova} dos emuladores do GitHub. Guardado por 6 h (o GitHub limita 60 consultas/hora)."""
    cache = os.path.join(VAR, "novos.json") if os.geteuid() == 0 else \
        os.path.join(os.path.expanduser("~"), ".cache/skystation/emuladores-novos.json")
    d = ler_json(cache, {})
    if not forcar and time.time() - d.get("_t", 0) < 6 * 3600:
        return d
    if not forcar:                           # quem roda como root já pode ter perguntado há pouco
        outro = ler_json(os.path.join(VAR, "novos.json"), {})
        if time.time() - outro.get("_t", 0) < 6 * 3600:
            return outro
    novo = {"_t": time.time()}
    falhas = 0
    for e in CATALOGO:
        if e["jeito"] in ("appimage", "xenia"):
            r = release_nova(e)
            if r:
                novo[e["id"]] = r[0]
            else:
                falhas += 1
                if falhas >= 2 and len(novo) == 1:
                    break                    # sem internet (ou GitHub fora): não fica esperando um por um
    if len(novo) > 1:
        try:
            gravar_json(cache, novo)
        except OSError:
            pass
        return novo
    return d                                 # sem internet: fica o que já sabia


# ---------------------------------------------------------------- estado (para a SkyStore)

def tarefa(i):
    return ler_json(os.path.join(VAR, f"tarefa-{i}.json"), {})


def estado(rede=True):
    novos = versoes_novas() if rede else {}
    ver = ler_json(registro_verificados(), {})
    itens = []
    for e in CATALOGO:
        tem = versao_instalada(e)
        nova = novos.get(e["id"], "")
        v = ver.get(e["id"], {})
        arq = v.get("arquivo", "")
        anterior = ""
        if e.get("pasta") and e["jeito"] not in ("nucleos", "manual") and os.path.isdir(e["pasta"] + ".anterior"):
            anterior = versao_instalada(dict(e, pasta=e["pasta"] + ".anterior"))
        itens.append({
            "id": e["id"], "nome": e["nome"], "tipo": e.get("tipo", "emulador"), "sistema": e.get("sistema", ""),
            "resumo": e["resumo"], "jeito": e["jeito"], "instalado": tem, "nova": nova,
            "atualizar": bool(tem and nova and tem != nova),
            "verificado": v.get("versao", "") if arq and os.path.exists(arq) else "",
            "verificado_tam": v.get("tamanho", 0), "verificado_em": v.get("quando", 0),
            "jogo": e.get("jogo", ""), "tarefa": tarefa(e["id"]), "anterior": anterior,
        })
    return {"ok": True, "itens": itens}


# ---------------------------------------------------------------- pedidos (jogador -> serviço root)

def pedir(acao, i):
    if acao not in ACOES or (i != "todos" and i not in POR_ID):
        return {"ok": False, "error": "pedido inválido"}
    os.makedirs(PEDIDOS, exist_ok=True)
    p = os.path.join(PEDIDOS, f"emuladores-{i}")
    with open(p + ".tmp", "w") as f:
        f.write(f"{acao} {time.time():.3f}\n")
    os.replace(p + ".tmp", p)        # o systemd (.path) vê o arquivo e chama "skystation-emuladores pedidos"
    return {"ok": True, "pedido": p}


def pedidos():
    feitos = 0
    while True:
        arqs = sorted(n for n in os.listdir(PEDIDOS) if n.startswith("emuladores-") and not n.endswith(".tmp")) \
            if os.path.isdir(PEDIDOS) else []
        if not arqs or feitos > 40:
            return
        for n in arqs:
            p = os.path.join(PEDIDOS, n)
            try:
                acao = open(p).read().split()[0]
            except (OSError, IndexError):
                acao = ""
            try:
                os.remove(p)
            except OSError:
                pass
            alvo = n[len("emuladores-"):]
            if acao == "semanal":                       # o atualizar.sh: só o que não foi conferido há 7 dias
                fazer("atualizar", "todos", semanal=True)
            elif acao in ACOES and (alvo == "todos" or alvo in POR_ID):
                fazer(acao, alvo)
            feitos += 1


# ---------------------------------------------------------------- tarefas (root)

class Tarefa:
    def __init__(self, e, acao):
        self.e, self.acao, self.p = e, acao, os.path.join(VAR, f"tarefa-{e['id']}.json")
        self.marca(acao, 0.0)

    def marca(self, etapa, p=-1.0, **extra):
        d = {"id": self.e["id"], "acao": self.acao, "etapa": etapa, "p": round(p, 3), "t": time.time(), "fim": False}
        d.update(extra)
        try:
            gravar_json(self.p, d)
        except OSError:
            pass

    def fim(self, ok, msg):
        anota(f"{self.e['id']} {self.acao}: {'ok' if ok else 'ERRO'} {msg}")
        self.marca("Pronto" if ok else "Erro", 1.0 if ok else -1.0, fim=True, ok=ok, message=msg)
        return ok


def baixar(url, dest, t, etapa):
    req = urllib.request.Request(url, headers={"User-Agent": AGENTE})
    with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
        total = int(r.headers.get("Content-Length") or 0)
        feito, ultimo = 0, 0.0
        while True:
            parte = r.read(1 << 20)
            if not parte:
                break
            f.write(parte)
            feito += len(parte)
            if total and time.monotonic() - ultimo > 0.5:
                ultimo = time.monotonic()
                t.marca(etapa, 0.8 * feito / total)
    return feito


def extrair_appimage(img, dest_tmp):
    """Extrai o AppImage (o console não usa FUSE). Devolve a pasta com AppRun ou None."""
    os.chmod(img, 0o755)
    trab = os.path.dirname(img)
    with open(LOG, "a") as log:
        subprocess.run([img, "--appimage-extract"], cwd=trab, stdout=log, stderr=log, stdin=subprocess.DEVNULL,
                       timeout=900)
    for d in ("AppDir", "squashfs-root"):
        cand = os.path.realpath(os.path.join(trab, d))
        if os.path.exists(os.path.join(cand, "AppRun")):
            shutil.move(cand, dest_tmp)
            return dest_tmp
    os.makedirs(dest_tmp, exist_ok=True)         # não extraiu: roda o AppImage no modo extrair-e-rodar
    shutil.move(img, os.path.join(dest_tmp, "programa.AppImage"))
    with open(os.path.join(dest_tmp, "AppRun"), "w") as f:
        f.write('#!/bin/sh\n# SkyStation: o AppImage não pôde ser extraído; roda sem FUSE.\n'
                'export APPIMAGE_EXTRACT_AND_RUN=1\nexec "$(dirname "$(readlink -f "$0")")/programa.AppImage" "$@"\n')
    os.chmod(os.path.join(dest_tmp, "AppRun"), 0o755)
    return dest_tmp


def desempacotar(pacote, pasta):
    os.makedirs(pasta, exist_ok=True)
    for cmd in (["bsdtar", "-xf", pacote, "-C", pasta], ["tar", "-xf", pacote, "-C", pasta],
                ["unzip", "-o", "-q", pacote, "-d", pasta]):
        if shutil.which(cmd[0]) and subprocess.run(cmd, capture_output=True).returncode == 0:
            return True
    return False


def trocar(pasta, nova, versao, url=""):
    """Põe a versão nova no lugar; a atual fica em <pasta>.anterior (para voltar se der problema)."""
    with open(os.path.join(nova, ".skystation-versao"), "w") as f:
        f.write(versao + "\n")
    if url:
        with open(os.path.join(nova, ".skystation-url"), "w") as f:
            f.write(url + "\n")
    subprocess.run(["chmod", "-R", "a+rX", nova])
    ant = pasta + ".anterior"
    shutil.rmtree(ant, ignore_errors=True)
    if os.path.exists(pasta):
        os.replace(pasta, ant)
    os.replace(nova, pasta)


def fazer_appimage(e, t, forcar):
    t.marca("Procurando a versão nova", 0.02)
    r = release_nova(e)
    if not r:
        return t.fim(False, "Não achei a versão Linux no site oficial agora (sem internet?)")
    versao, url = r
    tem = versao_instalada(e)
    if tem == versao and not forcar:
        return t.fim(True, f"{e['nome']} já está na versão mais nova ({versao})")
    tmp = tempfile.mkdtemp(prefix=f"skystation-{e['id']}.", dir="/var/tmp")
    try:
        pacote = os.path.join(tmp, "pacote")
        baixar(url, pacote, t, f"Baixando {e['nome']} {versao}")
        if os.path.getsize(pacote) < 5_000_000:
            return t.fim(False, "O download veio incompleto")
        t.marca("Instalando", 0.85)
        if re.search(r"\.appimage$", url, re.I):
            img = os.path.join(tmp, "programa.AppImage")
            os.replace(pacote, img)
        else:
            x = os.path.join(tmp, "x")
            if not desempacotar(pacote, x):
                return t.fim(False, "Não consegui abrir o pacote baixado")
            achados = [os.path.join(d, n) for d, _, ns in os.walk(x) for n in ns if n.lower().endswith(".appimage")]
            if not achados:
                return t.fim(False, "O pacote não tem AppImage")
            img = os.path.join(tmp, "programa.AppImage")
            shutil.move(achados[0], img)
        nova = e["pasta"] + ".novo"
        shutil.rmtree(nova, ignore_errors=True)
        if not extrair_appimage(img, nova) or not os.access(os.path.join(nova, "AppRun"), os.X_OK):
            shutil.rmtree(nova, ignore_errors=True)
            return t.fim(False, "Não consegui extrair o AppImage")
        trocar(e["pasta"], nova, versao, url)
        verbo = "atualizado" if tem else "instalado"
        return t.fim(True, f"{e['nome']} {verbo}: {versao}")
    except (OSError, subprocess.SubprocessError) as err:
        return t.fim(False, f"Falhou: {err}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


GUARDAR_XENIA = ("portable.txt", "config", "cache", "cache_host", "content")   # ajustes por jogo e cache


def fazer_xenia(e, t, forcar):
    t.marca("Procurando a versão nova", 0.02)
    r = release_nova(e)
    if not r:
        return t.fim(False, "Não achei a versão Linux no site oficial agora (sem internet?)")
    versao, url = r
    tem = versao_instalada(e)
    if tem == versao and not forcar:
        return t.fim(True, f"{e['nome']} já está na versão mais nova ({versao})")
    tmp = tempfile.mkdtemp(prefix=f"skystation-{e['id']}.", dir="/var/tmp")
    try:
        pacote = os.path.join(tmp, os.path.basename(url))
        baixar(url, pacote, t, f"Baixando {e['nome']} {versao}")
        t.marca("Instalando", 0.85)
        x = os.path.join(tmp, "x")
        if url.lower().endswith(".appimage"):
            if not extrair_appimage(pacote, x):
                return t.fim(False, "Não consegui extrair o AppImage")
        elif not desempacotar(pacote, x):
            return t.fim(False, "Não consegui abrir o pacote baixado")
        prog = None                                  # o maior executável ELF com "xenia" no nome
        cands = sorted(((os.path.getsize(os.path.join(d, n)), os.path.join(d, n)) for d, _, ns in os.walk(x)
                        for n in ns if "xenia" in n.lower() and not os.path.islink(os.path.join(d, n))), reverse=True)
        for _, c in cands:
            with open(c, "rb") as f:
                if f.read(4) == b"\x7fELF":
                    prog = c
                    break
        if not prog and os.path.exists(os.path.join(x, "AppRun")):
            prog = os.path.join(x, "AppRun")
        if not prog:
            return t.fim(False, "Baixei, mas não achei o programa no pacote")
        nova = os.path.dirname(prog)
        os.chmod(prog, 0o755)
        if os.path.basename(prog) != e["programa"] and not os.path.lexists(os.path.join(nova, e["programa"])):
            os.symlink(os.path.basename(prog), os.path.join(nova, e["programa"]))
        for n in os.listdir(e["pasta"]) if os.path.isdir(e["pasta"]) else []:   # ajustes do jogador
            if n in GUARDAR_XENIA or n.endswith(".toml"):
                alvo = os.path.join(nova, n)
                if os.path.isdir(alvo):
                    shutil.rmtree(alvo)
                shutil.copytree(os.path.join(e["pasta"], n), alvo, symlinks=True) \
                    if os.path.isdir(os.path.join(e["pasta"], n)) else shutil.copy2(os.path.join(e["pasta"], n), alvo)
        open(os.path.join(nova, "portable.txt"), "a").close()
        destino = e["pasta"] + ".novo"
        shutil.rmtree(destino, ignore_errors=True)
        shutil.move(nova, destino)
        trocar(e["pasta"], destino, versao, url)
        subprocess.run(["chown", "-R", f"{USUARIO}:{USUARIO}", e["pasta"]])   # o Xenia grava ao lado do programa
        return t.fim(True, f"{e['nome']} {'atualizado' if tem else 'instalado'}: {versao}")
    except (OSError, subprocess.SubprocessError) as err:
        return t.fim(False, f"Falhou: {err}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def fazer_nucleos(e, t, forcar):
    if not os.path.isdir(CORES):
        return t.fim(False, "Os núcleos vêm com a instalação do SkyStation (Fase 4)")
    nomes = sorted(n for n in os.listdir(CORES) if n.endswith("_libretro.so"))
    if not nomes:
        return t.fim(False, "Nenhum núcleo instalado")
    tmp = tempfile.mkdtemp(prefix="skystation-nucleos.", dir="/var/tmp")
    trocados, falhas = 0, []
    try:
        for k, n in enumerate(nomes):
            t.marca(f"Baixando {n.replace('_libretro.so', '')}", 0.95 * k / len(nomes))
            z = os.path.join(tmp, n + ".zip")
            try:
                req = urllib.request.Request(f"{BUILDBOT}/{n}.zip", headers={"User-Agent": AGENTE})
                with urllib.request.urlopen(req, timeout=60) as r, open(z, "wb") as f:
                    shutil.copyfileobj(r, f)
                subprocess.run(["unzip", "-o", "-q", z, "-d", tmp], check=True, capture_output=True)
                novo = os.path.join(tmp, n)
                with open(novo, "rb") as f:
                    if f.read(4) != b"\x7fELF":
                        raise OSError("não é um núcleo")
                os.chmod(novo, 0o644)
                os.replace(novo, os.path.join(CORES, n))      # mesmo disco? se não, o replace falha e copia
                trocados += 1
            except (OSError, subprocess.CalledProcessError):
                try:
                    shutil.copy2(os.path.join(tmp, n), os.path.join(CORES, n))
                    trocados += 1
                except OSError:
                    falhas.append(n.replace("_libretro.so", ""))
        versao = time.strftime("%Y.%m.%d")
        with open(os.path.join(CORES, ".skystation-versao"), "w") as f:
            f.write(versao + "\n")
        os.chmod(os.path.join(CORES, ".skystation-versao"), 0o644)
        msg = f"{trocados} núcleos atualizados ({versao})" + (f"; falharam: {', '.join(falhas)}" if falhas else "")
        return t.fim(trocados > 0, msg)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def fazer_pacman(e, t, forcar):
    t.marca("Instalando pelo sistema", -1.0)
    # sem -y: atualizar só um pacote sem o resto quebra o Arch. Versões novas chegam com a atualização do sistema.
    cmd = ["pacman", "-S", "--noconfirm"] + ([] if forcar else ["--needed"]) + e["pacotes"]
    with open(LOG, "a") as log:
        r = subprocess.run(cmd, stdout=log, stderr=log, timeout=1800)
    if r.returncode != 0:
        return t.fim(False, "O sistema não conseguiu instalar agora. Atualize o SkyStation e tente de novo.")
    return t.fim(True, f"{e['nome']} pronto")


def fazer_flatpak(e, t, forcar):
    if e["id"] == "lsfg":
        return fazer_lsfg(e, t, forcar)
    if e.get("remoto") == "flathub":
        return fazer_flathub(e, t, forcar)
    t.marca("Baixando pela NVIDIA (alguns minutos)", -1.0)
    nuvem = "/usr/local/bin/skystation-nuvem"
    if forcar and shutil.which("flatpak") and versao_instalada(e):
        with open(LOG, "a") as log:
            subprocess.run(["flatpak", "uninstall", "-y", "--noninteractive", e["flatpak"]], stdout=log, stderr=log)
    r = subprocess.run([nuvem], timeout=3600) if os.access(nuvem, os.X_OK) else None
    if r is None or r.returncode != 0 or not versao_instalada(e):
        return t.fim(False, "Não consegui instalar o app agora (veja espaço livre e internet). A versão web continua.")
    return t.fim(True, f"{e['nome']} pronto")


def lsfg_acessos(log):
    """Steam e Heroic enxergam a config do lsfg-vk (que o SkyStation escreve) e o Lossless.dll.
    Só leitura: o jogo nunca altera nem copia o arquivo do Lossless Scaling."""
    casa = casa_usuario()
    conf = os.path.join(casa, ".config/lsfg-vk")
    os.makedirs(conf, exist_ok=True)
    try:
        u = pwd.getpwnam(USUARIO)
        os.chown(conf, u.pw_uid, u.pw_gid)
    except (KeyError, OSError):
        pass
    steam_common = os.path.join(casa, ".var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Lossless Scaling")
    for app in LSFG_APPS:
        if subprocess.run(["flatpak", "info", app], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
            continue
        subprocess.run(["flatpak", "override", "--system", f"--filesystem={conf}:ro", f"--filesystem={steam_common}:ro",
                        f"--env=LSFGVK_CONFIG={conf}/conf.toml", app], stdout=log, stderr=log)


def fazer_lsfg(e, t, forcar):
    """Instala a camada do lsfg-vk do Flathub nos dois runtimes que a Steam e o Heroic usam (24.08 e 25.08)."""
    with open(LOG, "a") as log:
        if not shutil.which("flatpak"):
            return t.fim(False, "Instale a Steam ou o Heroic primeiro (aba Apps)")
        subprocess.run(["flatpak", "remote-add", "--system", "--if-not-exists", "flathub",
                        "https://dl.flathub.org/repo/flathub.flatpakrepo"], stdout=log, stderr=log, timeout=300)
        base = e["flatpak"].split("//")[0]
        ok = True
        for i, ramo in enumerate(e["ramos"]):
            ref = f"{base}//{ramo}"
            t.marca(f"Baixando a camada ({ramo})", 0.1 + 0.4 * i)
            if forcar:
                subprocess.run(["flatpak", "uninstall", "--system", "-y", "--noninteractive", ref], stdout=log, stderr=log)
            tem = subprocess.run(["flatpak", "info", ref], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
            r = subprocess.run(["flatpak", "update" if tem else "install", "--system", "-y", "--noninteractive"] +
                               ([] if tem else ["flathub"]) + [ref], stdout=log, stderr=log, timeout=1800)
            ok = ok and r.returncode == 0
        t.marca("Liberando a Steam e o Heroic", 0.9)
        lsfg_acessos(log)
    if not ok or not versao_instalada(e):
        return t.fim(False, "Não consegui baixar a camada agora (internet ou espaço). Tente de novo.")
    return t.fim(True, "Pronto: ligue a Geração de quadros nas opções de cada jogo de PC (botão Y)")


def fazer_flathub(e, t, forcar):
    """13.27: app do Flathub (Steam, Heroic). Atualiza se já tem; dá acesso às bibliotecas de PC do HD (/mnt/pc)."""
    livre = shutil.disk_usage("/var/lib").free if os.path.isdir("/var/lib/flatpak") else shutil.disk_usage("/").free
    if livre < 4 * 1024 ** 3:
        return t.fim(False, "Precisa de 4 GB livres no pendrive do sistema para instalar")
    with open(LOG, "a") as log:
        if not shutil.which("flatpak"):
            t.marca("Instalando o Flatpak", -1.0)
            subprocess.run(["pacman", "-S", "--needed", "--noconfirm", "flatpak"], stdout=log, stderr=log, timeout=900)
        subprocess.run(["flatpak", "remote-add", "--system", "--if-not-exists", "flathub",
                        "https://dl.flathub.org/repo/flathub.flatpakrepo"], stdout=log, stderr=log, timeout=300)
        tem = bool(versao_instalada(e))
        if tem and forcar:
            t.marca("Removendo para reinstalar", -1.0)
            subprocess.run(["flatpak", "uninstall", "--system", "-y", "--noninteractive", e["flatpak"]], stdout=log, stderr=log)
            tem = False
        t.marca(("Atualizando " if tem else "Baixando ") + e["nome"] + " (pode levar vários minutos)", -1.0)
        cmd = ["flatpak", "update" if tem else "install", "--system", "-y", "--noninteractive"] + \
            ([] if tem else ["flathub"]) + [e["flatpak"]]
        r = subprocess.run(cmd, stdout=log, stderr=log, timeout=5400)
        for pasta in e.get("acesso", []):    # a Steam/Heroic enxergam os jogos do HD do Windows
            subprocess.run(["flatpak", "override", "--system", "--filesystem=" + pasta, e["flatpak"]], stdout=log, stderr=log)
        if e["flatpak"] in LSFG_APPS and versao_instalada(POR_ID["lsfg"]):
            lsfg_acessos(log)              # instalou a Steam/Heroic depois da geração de quadros
    if r.returncode != 0 or not versao_instalada(e):
        return t.fim(False, "Não consegui instalar agora (internet ou espaço). Tente de novo.")
    # depois de instalar, procura de novo as bibliotecas do HD (o skystation-pcjogos cria os jogos no menu)
    pcj = "/usr/local/bin/skystation-pcjogos"
    if os.access(pcj, os.X_OK):
        subprocess.run([pcj], timeout=300, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return t.fim(True, f"{e['nome']} pronto")


def restaurar(e, t):
    """Volta a cópia verificada (a última versão que rodou jogo sem travar)."""
    v = ler_json(registro_verificados(), {}).get(e["id"], {})
    arq, sha = v.get("arquivo", ""), v.get("sha256", "")
    if not arq or not os.path.exists(arq) or not sha:
        return t.fim(False, "Ainda não há cópia verificada deste emulador (ela é feita depois de jogar 2 min)")
    t.marca("Conferindo a cópia", 0.05)
    h = hashlib.sha256()
    with open(arq, "rb") as f:
        for parte in iter(lambda: f.read(1 << 20), b""):
            h.update(parte)
    if h.hexdigest() != sha:
        return t.fim(False, "A cópia verificada foi alterada fora do SkyStation: recusada por segurança")
    t.marca("Restaurando", 0.5)
    nova = e["pasta"] + ".novo"
    shutil.rmtree(nova, ignore_errors=True)
    os.makedirs(nova)
    try:
        with tarfile.open(arq, "r:*") as tf:
            tf.extractall(nova, filter="tar")     # sem caminhos para fora, mantém permissões de execução
        subprocess.run(["chown", "-R", "root:root", nova])
        trocar(e["pasta"], nova, v.get("versao", "?"))
        if e["jeito"] == "xenia":
            subprocess.run(["chown", "-R", f"{USUARIO}:{USUARIO}", e["pasta"]])
    except (OSError, tarfile.TarError) as err:
        shutil.rmtree(nova, ignore_errors=True)
        return t.fim(False, f"Não consegui restaurar: {err}")
    return t.fim(True, f"{e['nome']} restaurado para a versão verificada {v.get('versao', '')}")


def voltar(e, t):
    ant = e["pasta"] + ".anterior"
    if not os.path.isdir(ant):
        return t.fim(False, "Não há versão anterior guardada")
    troca = e["pasta"] + ".troca"
    shutil.rmtree(troca, ignore_errors=True)
    if os.path.exists(e["pasta"]):
        os.replace(e["pasta"], troca)
    os.replace(ant, e["pasta"])
    if os.path.exists(troca):
        os.replace(troca, ant)                     # a que deu problema fica como "anterior" (dá para desfazer)
    return t.fim(True, f"{e['nome']} voltou para a versão {versao_instalada(e)}")


def fazer(acao, alvo, semanal=False):
    if os.geteuid() != 0:
        raise SystemExit("Rode com sudo (ou peça pela SkyStore).")
    os.makedirs(VAR, exist_ok=True)
    os.chmod(VAR, 0o755)
    if alvo == "todos":
        ok = True
        for e in CATALOGO:
            if e["jeito"] in ("manual", "pacman", "flatpak") or not versao_instalada(e):
                continue                                  # "todos" = atualizar os emuladores que já estão aqui
            marca = os.path.join(e["pasta"], ".skystation-versao")
            if semanal and os.path.exists(marca) and time.time() - os.path.getmtime(marca) < SEMANA:
                continue
            ok = fazer("atualizar", e["id"]) and ok
            if os.path.exists(marca):
                os.utime(marca)                           # conferido agora (mesmo sem versão nova)
        return ok
    e = item(alvo)
    t = Tarefa(e, acao)
    if acao == "restaurar":
        return restaurar(e, t)
    if acao == "voltar":
        return voltar(e, t)
    if e["jeito"] == "manual":
        return t.fim(False, "O Switch não é baixado pelo SkyStation: baixe o Eden ou o Citron no site oficial, "
                            "ponha em SKYROMS/emuladores e rode a Fase 13. Para voltar uma versão que funcionava, "
                            "use Restaurar cópia verificada.")
    forcar = acao == "reinstalar"
    try:
        return {"appimage": fazer_appimage, "xenia": fazer_xenia, "nucleos": fazer_nucleos,
                "pacman": fazer_pacman, "flatpak": fazer_flatpak}[e["jeito"]](e, t, forcar)
    except Exception as err:                              # nunca deixa a tarefa "andando" para sempre na loja
        return t.fim(False, f"Falhou: {err}")


# ---------------------------------------------------------------- cópia verificada (jogador, pelo sky-run)

def verificar(i):
    e = POR_ID.get(i)
    if not e or e["jeito"] in ("pacman", "flatpak"):
        return {"ok": False, "error": "sem cópia para esse item"}
    tem = versao_instalada(e)
    if not tem:
        return {"ok": False, "error": "não instalado"}
    if tem == "?":                    # instalado antes da 13.18 (sem número de versão): a data da pasta serve
        tem = "de " + time.strftime("%d/%m/%Y", time.localtime(os.path.getmtime(e["pasta"])))
    reg_p = registro_verificados()
    reg = ler_json(reg_p, {})
    atual = reg.get(i, {})
    if atual.get("versao") == tem and os.path.exists(atual.get("arquivo", "")):
        return {"ok": True, "message": "já verificada"}
    pasta_hd = "/mnt/skyroms/emuladores/verificados"
    if not os.access("/mnt/skyroms", os.W_OK):
        return {"ok": False, "error": "SKYROMS só leitura"}
    os.makedirs(pasta_hd, exist_ok=True)
    final = os.path.join(pasta_hd, f"{i}.tar.gz")
    tmp = final + ".parcial"
    h = hashlib.sha256()

    class Hasher:                     # calcula o sha256 enquanto grava (um só passe pelo HD)
        def __init__(self, f):
            self.f = f

        def write(self, b):
            h.update(b)
            return self.f.write(b)

        def flush(self):
            self.f.flush()

    def fora(ti):                     # caches e logs não entram na cópia
        n = os.path.basename(ti.name)
        if n in ("cache", "cache_host", "content", "shadercache") or n.endswith(".log"):
            return None
        return ti
    try:
        with open(tmp, "wb") as bruto:
            with tarfile.open(fileobj=Hasher(bruto), mode="w|gz", compresslevel=3) as tf:
                for n in sorted(os.listdir(e["pasta"])):
                    tf.add(os.path.join(e["pasta"], n), arcname=n, filter=fora)
        os.replace(tmp, final)
    except OSError as err:
        try:
            os.remove(tmp)
        except OSError:
            pass
        return {"ok": False, "error": str(err)}
    reg[i] = {"versao": tem, "arquivo": final, "sha256": h.hexdigest(), "tamanho": os.path.getsize(final),
              "quando": int(time.time())}
    gravar_json(reg_p, reg)
    return {"ok": True, "message": f"cópia verificada de {e['nome']} {tem} guardada"}


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else "estado"
    if cmd == "estado":
        print(json.dumps(estado(rede="--sem-rede" not in a), ensure_ascii=False))
    elif cmd == "pedir" and len(a) == 3:
        print(json.dumps(pedir(a[1], a[2]), ensure_ascii=False))
    elif cmd == "pedidos":
        pedidos()
    elif cmd == "verificar" and len(a) == 2:
        print(json.dumps(verificar(a[1]), ensure_ascii=False))
    elif cmd in ACOES and len(a) == 2:
        sys.exit(0 if fazer(cmd, a[1]) else 1)
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
