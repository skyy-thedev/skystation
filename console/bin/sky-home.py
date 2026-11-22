#!/usr/bin/env python3
"""SkyStation: botão Home.

Roda em segundo plano durante toda a sessão (iniciado pelo sky-shell, dentro do cage)
e escuta todos os controles e teclados, sem atrapalhar ninguém.

Com um jogo aberto:
  - TOQUE no Home (ou Select+Start, ou F12): o jogo PAUSA e abre o menu por cima, no estilo
    do XMB do PS3 (Fase 8.0): categorias na horizontal — Jogo (voltar, salvar/carregar estado,
    captura, fechar), Troféus (com os NOVOS desta partida), Amigos (SkyNetwork), Ajustes
    (volume e brilho) e Energia. ◀ ▶ (ou L1/R1) troca de categoria; ▲ ▼ escolhe o item.
  - SEGURAR 1,5 s (com ou sem jogo): menu de energia — Fechar jogo, Modo de espera, Reiniciar,
    Desligar o console (Fase 7.2).
  - CONTINUAR SEGURANDO até 5 s: fecha o jogo direto (saída de emergência, mesmo se o menu falhar).
  - 13.22: categoria Controles (e "Desligar este controle" em Energia): desliga um controle Bluetooth pelo
    console (o DualShock/DualSense apaga a luz e desliga). Serve para arrumar a ordem dos jogadores: desligue
    os dois e ligue de novo, primeiro o do Jogador 1.
  - 13.23: o console lembra a ordem dos controles (~/.config/skystation/controles-ordem.json, pelo endereço
    Bluetooth). Os emuladores numeram os jogadores na ordem em que os controles conectaram; se um controle
    lembrado como Jogador 2 conectar antes do Jogador 1 (fora de jogo), o console desliga o Jogador 2 e avisa
    para ligá-lo de novo, e a ordem volta a ser a lembrada. "Tornar este controle o Jogador 1"
    (Home → Controles) muda a memória.

Como o menu funciona por baixo:
  1. SIGSTOP no grupo de processos do jogo: ele congela (imagem, som e lógica).
  2. grab() em todos os controles/teclados: só o SkyStation recebe os botões enquanto
     o menu está aberto. Sem isso, o "A" que você aperta no menu chegaria ao jogo depois.
  3. sky-overlay.py desenha o menu; este processo manda para ele qual item está selecionado.
  4. Ao escolher: SIGCONT (o jogo continua de onde parou) ou fechamento em duas etapas
     (SIGTERM, e SIGKILL se em 3 s ele não fechou).
"""
import glob
import json
import os
import queue
import re
import select
import shutil
import signal
import subprocess
import sys
import threading
import time

try:
    import evdev
    from evdev import ecodes as E
except ImportError:
    print("sky-home: python-evdev não instalado; botão Home desativado", file=sys.stderr)
    sys.exit(0)

HOLD = 1.5
HOLD_KILL = 5.0
RUN = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "skystation")
PID_FILE = os.path.join(RUN, "game.pid")
TITLE_FILE = os.path.join(RUN, "game.title")
NETPLAY_SIS = {"ps1", "snes", "n64", "nes", "md", "gba", "gb"}   # sistemas do RetroArch com netplay
SHOT = os.path.join(RUN, "pause.png")
OVERLAY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sky-overlay.py")
SOUNDS = "/opt/skystation/sounds"
CAPTURAS = os.path.expanduser("~/skystation/capturas")
RA_FIFO = os.path.join(RUN, "retroarch.cmd")   # comandos do RetroArch pela entrada padrão (sky-emu)
PLAYER = next((p for p in ("pw-play", "paplay", "aplay") if shutil.which(p)), None)

TRIGGERS = {E.BTN_MODE, E.BTN_SELECT, E.BTN_START, E.KEY_F12}
NAV_UP = {E.KEY_UP, E.BTN_DPAD_UP, E.KEY_W}
NAV_DOWN = {E.KEY_DOWN, E.BTN_DPAD_DOWN, E.KEY_S}
NAV_LEFT = {E.KEY_LEFT, E.BTN_DPAD_LEFT, E.KEY_A}
NAV_RIGHT = {E.KEY_RIGHT, E.BTN_DPAD_RIGHT, E.KEY_D}
CAT_PREV = {E.BTN_TL, E.KEY_PAGEUP, E.KEY_Q}
CAT_NEXT = {E.BTN_TR, E.KEY_PAGEDOWN, E.KEY_E}
SKY_BIN = os.path.dirname(os.path.abspath(__file__))
ACCEPT = {E.BTN_SOUTH, E.KEY_ENTER, E.KEY_KPENTER, E.KEY_SPACE}
BACK = {E.BTN_EAST, E.KEY_ESC, E.KEY_BACKSPACE, E.BTN_MODE, E.KEY_F12, E.BTN_START}
SKY_CLOUD = os.path.join(SKY_BIN, "sky-cloud")
RAPIDAS = ["Bora jogar?", "Entra aí!", "GG!", "Já volto", "Agora não dá"]
# Teclado virtual (Fase 10): direcional só do controle e das setas; W/A/S/D de um teclado de verdade digitam
KB_UP = {E.KEY_UP, E.BTN_DPAD_UP}
KB_DOWN = {E.KEY_DOWN, E.BTN_DPAD_DOWN}
KB_LEFT = {E.KEY_LEFT, E.BTN_DPAD_LEFT}
KB_RIGHT = {E.KEY_RIGHT, E.BTN_DPAD_RIGHT}


def log(msg):
    print(time.strftime("%H:%M:%S"), "sky-home:", msg, flush=True)


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def play(name):
    if PLAYER and not os.path.exists(os.path.expanduser("~/.config/skystation/avisos.off")):
        path = os.path.join(SOUNDS, name + ".wav")
        if os.path.exists(path):
            subprocess.Popen([PLAYER, path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def get_volume():
    try:
        out = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True,
                             text=True, timeout=2).stdout
        m = re.search(r"([\d.]+)", out)
        return int(round(float(m.group(1)) * 100)) if m else -1, "MUTED" in out
    except (OSError, subprocess.SubprocessError):
        return -1, False


def change_volume(delta):
    sign = "+" if delta > 0 else "-"
    subprocess.run(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", f"{abs(delta)}%{sign}"],
                   capture_output=True, timeout=2)
    subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"], capture_output=True, timeout=2)


def get_brightness():
    try:
        out = subprocess.run(["brightnessctl", "-m"], capture_output=True, text=True, timeout=2)
        if out.returncode == 0:
            return int(out.stdout.strip().split(",")[3].rstrip("%"))
    except (OSError, subprocess.SubprocessError, IndexError, ValueError):
        pass
    return -1


def change_brightness(delta):
    v = get_brightness()
    if v < 0:
        return
    v = max(5, min(100, v + delta))   # nunca apaga a tela de vez
    subprocess.run(["brightnessctl", "-q", "set", f"{v}%"], capture_output=True, timeout=2)


def trophies():
    """Troféus do perfil; os ganhos depois do começo desta partida vêm marcados como NOVO."""
    try:
        out = subprocess.run([sys.executable, os.path.join(SKY_BIN, "sky-trofeus"), "listar"],
                             capture_output=True, text=True, timeout=5)
        d = json.loads(out.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        return 0, 0, []
    try:
        inicio = int(read(os.path.join(RUN, "game.start"), "0"))
    except ValueError:
        inicio = 0
    lst = d.get("trofeus", [])
    lst.sort(key=lambda t: (-(t["ganho"] >= inicio > 0), -bool(t["ganho"]), -t["ganho"]))
    items = [{"t": t["nome"], "sub": t["desc"], "kind": "trofeu", "nivel": t["nivel"], "ganho": bool(t["ganho"]),
              "novo": bool(t["ganho"]) and inicio > 0 and t["ganho"] >= inicio} for t in lst]
    return d.get("ganhos", 0), d.get("total", 0), items


ICONE_NOTIF = {"central": "download", "controle": "pad", "usb": "usb", "pendrive": "drive", "jogo": "disc",
               "disco": "disc", "tv": "monitor", "trofeu": "trophy", "bateria": "battery", "energia": "battery",
               "calor": "thermo"}


def quando(t):
    d = max(0, int(time.time() - float(t or 0)))
    if d < 60:
        return "agora"
    if d < 3600:
        return f"há {d // 60} min"
    if d < 86400:
        return f"há {d // 3600} h"
    return time.strftime("%d/%m %H:%M", time.localtime(float(t)))


def marcar_menu(aberto):
    p = os.path.join(RUN, "menu.aberto")
    try:
        if aberto:
            open(p, "w").close()
        elif os.path.exists(p):
            os.remove(p)
    except OSError:
        pass


def quando_iso(iso):
    """'2026-11-17T10:37:39.716Z' -> 'agora', 'há 5 min', 'ontem 21:40'…"""
    try:
        import calendar
        t = calendar.timegm(time.strptime(str(iso)[:19], "%Y-%m-%dT%H:%M:%S"))
    except (ValueError, TypeError):
        return ""
    return quando(t)


def status_info():
    """Bateria do console e dos controles, temperatura e hora, para o rodapé do menu."""
    info = {"hora": time.strftime("%H:%M")}
    pads = []
    for d in glob.glob("/sys/class/power_supply/*"):
        if read(os.path.join(d, "type")) != "Battery" or not read(os.path.join(d, "capacity")).isdigit():
            continue
        cap = int(read(os.path.join(d, "capacity")))
        charging = read(os.path.join(d, "status")) in ("Charging", "Full")
        if read(os.path.join(d, "scope")) == "Device":
            pads.append([cap, charging])
        elif "bateria" not in info:
            info["bateria"] = [cap, charging]
    if pads:
        info["controles"] = pads
    temps = []
    for z in glob.glob("/sys/class/thermal/thermal_zone*"):
        if read(os.path.join(z, "type")) in ("x86_pkg_temp", "acpitz"):
            v = read(os.path.join(z, "temp"))
            if v.isdigit():
                temps.append(int(v) / 1000)
    if temps:
        info["temp"] = round(max(temps))
    return info


def controles():
    """13.22: controles ligados, na ordem em que os emuladores (SDL) contam: Jogador 1, Jogador 2…
    [{"path", "nome", "mac" (Bluetooth) ou "", "bateria" ou None}]"""
    lst = []
    for path in sorted(evdev.list_devices(), key=lambda p: int(re.sub(r"\D", "", p) or 0)):
        try:
            dev = evdev.InputDevice(path)
        except OSError:
            continue
        try:
            caps = dev.capabilities()
            keys = set(caps.get(E.EV_KEY, []))
            # o controle de verdade (não o sensor de movimento nem o touchpad do DS4, que são outros devices)
            if E.BTN_SOUTH not in keys or E.EV_ABS not in caps or "Motion" in dev.name or "Touchpad" in dev.name:
                continue
            mac = (dev.uniq or "").strip().lower()
            mac = mac if re.fullmatch(r"([0-9a-f]{2}:){5}[0-9a-f]{2}", mac) and dev.info.bustype == 0x05 else ""
            bat = None
            for d in glob.glob("/sys/class/power_supply/*"):
                if mac and mac.replace(":", "") in os.path.basename(d).lower().replace(":", "").replace("_", ""):
                    v = read(os.path.join(d, "capacity"))
                    bat = int(v) if v.isdigit() else None
            lst.append({"path": path, "nome": dev.name, "mac": mac, "bateria": bat})
        finally:
            dev.close()
    return lst


ORDEM = os.path.expanduser("~/.config/skystation/controles-ordem.json")


def ordem_ler():
    try:
        with open(ORDEM) as f:
            d = json.load(f)
        return [str(m) for m in d.get("ordem", [])] if isinstance(d, dict) else []
    except (OSError, ValueError):
        return []


def ordem_gravar(lst):
    try:
        os.makedirs(os.path.dirname(ORDEM), exist_ok=True)
        with open(ORDEM + ".tmp", "w") as f:
            json.dump({"ordem": lst[:8]}, f)
        os.replace(ORDEM + ".tmp", ORDEM)
    except OSError:
        pass


def aviso(texto):
    """Mesmo caminho dos avisos do console: o menu mostra (e o sky-toast, por cima de um jogo)."""
    try:
        with open(os.path.join(RUN, "events.jsonl"), "a") as f:
            f.write(json.dumps({"t": time.time(), "kind": "controle", "text": texto}, ensure_ascii=False) + "\n")
    except OSError:
        pass


def desligar_controle(mac):
    """Desconecta do Bluetooth: o DualShock 4 / DualSense / 8BitDo desligam sozinhos ao perder a conexão."""
    try:
        r = subprocess.run(["bluetoothctl", "disconnect", mac], capture_output=True, text=True, timeout=10)
        ok = r.returncode == 0 and "fail" not in (r.stdout + r.stderr).lower()
    except (OSError, subprocess.SubprocessError):
        ok = False
    log(f"desligar controle {mac}: {'ok' if ok else 'falhou'}")
    return ok


def game_pid():
    try:
        with open(PID_FILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError):
        return None


def signal_group(pid, sig):
    try:
        os.killpg(pid, sig)
        return True
    except ProcessLookupError:
        return False


def close_game(pid):
    log(f"fechando jogo (grupo {pid})")
    signal_group(pid, signal.SIGCONT)  # um processo congelado não consegue tratar o SIGTERM
    if not signal_group(pid, signal.SIGTERM):
        return

    def finish():
        time.sleep(3)
        if signal_group(pid, 0):
            log("jogo não respondeu em 3 s: SIGKILL")
            signal_group(pid, signal.SIGKILL)

    threading.Thread(target=finish, daemon=True).start()


def combo(pressed):
    return (E.BTN_MODE in pressed
            or (E.BTN_SELECT in pressed and E.BTN_START in pressed)
            or E.KEY_F12 in pressed)


class Home:
    def __init__(self):
        self.devices = {}       # caminho -> InputDevice
        self.pressed = {}       # caminho -> teclas/botões pressionados
        self.axis = {}          # (caminho, eixo) -> -1/0/1 (para navegar com analógico)
        self.since = None
        self.fired = False
        self.menu_pid = None
        self.menu = False       # algum menu aberto (com ou sem jogo)
        self.power = False      # é o menu de energia (segurar Home)
        self.hold0 = None       # desde quando o Home está sendo segurado sem soltar
        self.overlay = None
        self.sel = 0
        self.grabbed = False
        self.ungrab_at = None
        self.items = []         # [(ação, {"t": texto, ...})] da categoria atual
        self.cats = []
        self.cat = 0
        self.info_at = 0.0
        self.amigo = None       # Fase 10: conversa aberta (id do amigo) dentro da categoria Amigos
        self.kb = None          # teclado virtual aberto (skyteclado.Teclado)
        self.fila = queue.Queue()   # resultados das threads de rede, aplicados no laço principal
        self.origem = None      # 13.22: caminho do controle que abriu o menu ("Desligar este controle")
        self.ordem_at = 0.0     # 13.23: última conferência da ordem dos controles
        self.reconectar = {}    # mac -> quando foi desligado para voltar na ordem (não repete em seguida)
        marcar_menu(False)      # sobra de uma sessão anterior que caiu com o menu aberto

    # ---------------------------------------------------------- dispositivos
    def scan(self):
        found = {}
        for path in evdev.list_devices():
            if path in self.devices:
                found[path] = self.devices[path]
                continue
            try:
                dev = evdev.InputDevice(path)
                keys = set(dev.capabilities().get(E.EV_KEY, []))
                if keys & TRIGGERS:
                    found[path] = dev
                    log(f"vigiando {dev.name}")
                    if self.grabbed:
                        self._grab(dev)
                else:
                    dev.close()
            except OSError:
                pass
        for path, dev in self.devices.items():
            if path not in found:
                try:
                    dev.close()
                except OSError:
                    pass
        self.devices = found
        self.pressed = {p: self.pressed.get(p, set()) for p in found}

    def _grab(self, dev):
        try:
            dev.grab()
        except OSError:
            pass

    def grab_all(self, on):
        for dev in self.devices.values():
            try:
                dev.grab() if on else dev.ungrab()
            except OSError:
                pass
        self.grabbed = on

    # ---------------------------------------------------------- menu
    def send(self, line):
        if self.overlay and self.overlay.poll() is None:
            try:
                self.overlay.stdin.write(line + "\n")
                self.overlay.stdin.flush()
            except (BrokenPipeError, OSError):
                pass

    def send_cats(self):
        self.send("cats " + json.dumps([{"id": c["id"], "title": c["title"], "icon": c["icon"],
                                         "conversa": c.get("conversa"),
                                         "items": [dict(it, acao=a) for a, it in c["items"]]} for c in self.cats],
                                       ensure_ascii=False))
        self.send(f"sel {self.cat} {self.sel}")

    def cat_index(self, cid):
        return next((k for k, c in enumerate(self.cats) if c["id"] == cid), 0)

    def amigos_items(self):
        """Fase 10: amigos da SkyNetwork (o sky-net mantém o net.json em dia)."""
        def info(t, sub=""):
            return ("nada", {"t": t, "kind": "info", "sub": sub})
        try:
            with open(os.path.join(RUN, "net.json"), encoding="utf-8") as f:
                net = json.load(f)
        except (OSError, ValueError):
            net = None
        if not os.path.exists(os.path.expanduser("~/.config/skystation/rede.json")) or net is None:
            return [info("SkyNetwork", "Entre na rede em Sistema → SkyNetwork, no menu principal")]
        if not net.get("online"):
            return [info("Sem conexão com a SkyNetwork", "Os amigos voltam a aparecer quando a internet voltar")]
        ordem = {"jogando": 0, "online": 1, "ausente": 2, "offline": 3}
        estado = {"online": "Online", "ausente": "Ausente", "offline": "Offline"}
        items = []
        novas = {}
        for m in net.get("mensagens", []):
            if not m.get("lida"):
                de = str(m.get("de", {}).get("id", ""))
                novas[de] = novas.get(de, 0) + 1
        for m in reversed(net.get("mensagens", [])[-5:]):
            if not m.get("lida"):
                de = m.get("de", {})
                items.append(("amigo", {"t": str(de.get("apelido", "?")) + ": " + str(m.get("texto", "")),
                                        "sub": "A para responder", "fid": str(de.get("id", "")),
                                        "nome": str(de.get("apelido", "?")), "avatar": str(de.get("avatar", ""))}))
        for a in sorted(net.get("amigos", []), key=lambda a: (ordem.get(a.get("status"), 9), a.get("apelido", ""))):
            if a.get("status") == "jogando":
                sub = "Jogando " + str(a.get("jogo") or "") + (("  ·  " + str(a["sistema"]).upper()) if a.get("sistema") else "")
            else:
                sub = estado.get(a.get("status"), "Offline")
            n = novas.get(str(a.get("id", "")), 0)
            if n:
                sub += f"  ·  {n} nova(s)"
            items.append(("amigo", {"t": str(a.get("apelido", "?")), "sub": sub + "  ·  A para conversar",
                                    "fid": str(a.get("id", "")), "nome": str(a.get("apelido", "?")),
                                    "avatar": str(a.get("avatar", "")), "apagado": a.get("status") == "offline"}))
        if not items:
            items = [info("Nenhum amigo ainda", "Adicione pelo código em Sistema → SkyNetwork")]
        return items

    # ---------------------------------------------------------- conversa e teclado (Fase 10)
    def cloud(self, *args, timeout=12):
        """Roda o sky-cloud e devolve o JSON da última linha."""
        try:
            out = subprocess.run([sys.executable, SKY_CLOUD, *args], capture_output=True, text=True, timeout=timeout)
            return json.loads(out.stdout.strip().splitlines()[-1])
        except (OSError, subprocess.SubprocessError, ValueError, IndexError):
            return {"ok": False, "error": "A SkyNetwork não respondeu"}

    def em_thread(self, fn, depois):
        """fn() roda numa thread (rede); depois(resultado) roda no laço principal."""
        def run():
            r = fn()
            self.fila.put(lambda: depois(r))
        threading.Thread(target=run, daemon=True).start()

    def conversa_balao(self, msgs):
        """As mensagens viram balões no painel à direita do menu (sky-overlay)."""
        if msgs is None:
            return [{"texto": "Carregando a conversa…", "sistema": True}]
        if not msgs:
            return [{"texto": "Nenhuma mensagem ainda. Diga oi!", "sistema": True}]
        out = []
        for m in msgs[-12:]:
            txt = str(m.get("texto", ""))
            if m.get("tipo") == "convite":
                txt = "Convite: " + txt
            out.append({"texto": txt, "minha": bool(m.get("minha")), "quando": quando_iso(m.get("enviadaEm"))})
        return out

    def conversa_items(self, fid, nome):
        items = [("voltar_amigos", {"t": "Voltar aos amigos"})]
        items.append(("escrever", {"t": "Escrever mensagem…", "sub": "Teclado na tela, com o controle"}))
        for r in RAPIDAS:
            items.append(("rapida", {"t": "Enviar: " + r, "texto": r}))
        if self.menu_pid:
            titulo = read(TITLE_FILE) or "este jogo"
            if read(os.path.join(RUN, "game.sys")) in NETPLAY_SIS:
                # Fase 11.4: abre uma sala do RetroArch e manda o convite com ela
                items.append(("jogar_junto", {"t": f"Jogar {titulo} junto, online",
                                              "sub": f"{nome} entra como jogador 2 pela internet"}))
            items.append(("convidar", {"t": f"Convidar para {titulo}"}))
        return items

    def abrir_amigo(self, fid, nome):
        self.amigo = (fid, nome)
        k = self.cat_index("amigos")
        self.cats[k]["items"] = self.conversa_items(fid, nome)
        self.cats[k]["conversa"] = self.conversa_balao(None)
        self.cats[k]["title"] = nome
        self.items = self.cats[k]["items"]
        self.sel = 1   # cai em "Escrever mensagem…"
        self.send_cats()
        self.carregar_conversa()

    def carregar_conversa(self):
        if not self.amigo:
            return
        fid, nome = self.amigo

        def buscar():
            r = self.cloud("conversa", fid)
            self.cloud("lidas", fid, timeout=6)
            return r

        def mostrar(r):
            if not self.menu or self.amigo != (fid, nome):
                return
            k = self.cat_index("amigos")
            self.cats[k]["conversa"] = self.conversa_balao(r.get("mensagens", []) if r.get("ok") else [])
            self.send_cats()
            if not r.get("ok"):
                self.send("msg " + r.get("error", "Não consegui abrir a conversa"))
        self.em_thread(buscar, mostrar)

    def fechar_amigo(self):
        self.amigo = None
        k = self.cat_index("amigos")
        self.cats[k]["title"] = "Amigos"
        self.cats[k].pop("conversa", None)
        self.cats[k]["items"] = self.amigos_items()
        if self.cat == k:
            self.items = self.cats[k]["items"]
            self.sel = 0
        self.send_cats()

    def enviar_mensagem(self, texto, convite=False):
        if not self.amigo:
            return
        fid = self.amigo[0]
        self.send("msg Enviando…")
        args = ("convidar", fid) if convite else ("mensagem", fid, texto)

        def depois(r):
            play("salvo" if r.get("ok") else "alerta")
            self.send("msg " + (r.get("message") if r.get("ok") else r.get("error", "Não consegui enviar")))
            self.carregar_conversa()
        self.em_thread(lambda: self.cloud(*args), depois)

    def kb_abrir(self):
        import skyteclado
        self.kb = skyteclado.Teclado("Mensagem para " + (self.amigo[1] if self.amigo else ""))
        self.kb_enviar_estado()

    def kb_enviar_estado(self):
        self.send("kb " + json.dumps(self.kb.estado(), ensure_ascii=False) if self.kb else "kb")

    def kb_fechar(self):
        self.kb = None
        self.kb_enviar_estado()

    def kb_key(self, code, shift=False):
        import skyteclado
        t = self.kb
        if code in KB_UP:
            t.mover(0, -1)
        elif code in KB_DOWN:
            t.mover(0, 1)
        elif code in KB_LEFT:
            t.mover(-1, 0)
        elif code in KB_RIGHT:
            t.mover(1, 0)
        # como no PS4/PS5: ✕ digita, □ apaga, △ símbolos, ○ cancela, R2 (ou Options) envia,
        # L2 maiúsculas, R1 espaço
        elif code == E.BTN_SOUTH:
            t.apertar()
        elif code in (E.BTN_WEST, E.BTN_TL, E.KEY_BACKSPACE):
            t.apagar()
        elif code in (E.BTN_NORTH, E.BTN_SELECT):
            t.pagina()
        elif code == E.BTN_TL2:
            t.maiuscula()
        elif code in (E.BTN_TR, E.KEY_SPACE):
            t.espaco()
        elif code in (E.BTN_TR2, E.BTN_START, E.KEY_ENTER, E.KEY_KPENTER):
            t.enviar()
        elif code in (E.BTN_EAST, E.BTN_MODE, E.KEY_ESC, E.KEY_F12):
            self.kb_fechar()
            return
        else:
            nome = E.KEY.get(code, "")
            if isinstance(nome, list):
                nome = nome[0]
            t.digitar(skyteclado.tecla_fisica(str(nome), shift))
        if t.enviado:
            texto = t.texto
            self.kb_fechar()
            self.enviar_mensagem(texto)
            return
        play("navegar")
        self.kb_enviar_estado()

    def notif_items(self):
        try:
            import skyhist
            lst = skyhist.load()
        except Exception:
            lst = []
        if not lst:
            return [("nada", {"t": "Nenhuma notificação", "kind": "info",
                              "sub": "Os avisos do console aparecem aqui"})]
        items = [("limpar", {"t": "Limpar todas", "sub": f"{len(lst)} notificação(ões)"})]
        for n in lst[:30]:
            items.append(("notif", {"t": n["text"], "sub": quando(n.get("t", 0)) + "  ·  A para apagar",
                                    "kind": "notif", "icone": ICONE_NOTIF.get(n.get("kind", ""), "info"),
                                    "nid": n.get("id")}))
        return items

    def open_menu(self, pid, power=False, aba=""):
        log("menu de energia aberto" if power else "menu Home aberto")
        self.amigo = None
        self.kb = None
        self.menu_pid = pid
        self.menu, self.power = True, power
        if pid:
            signal_group(pid, signal.SIGSTOP)
        self.grab_all(True)
        self.ungrab_at = None
        marcar_menu(True)        # o sky-toast (gamescope) esconde os avisos enquanto o menu está aberto
        title = read(TITLE_FILE)
        # foto da tela congelada: vira o fundo do menu e pode ser salva como captura
        shot = ""
        if shutil.which("grim"):
            try:
                if os.path.exists(SHOT):
                    os.remove(SHOT)
                subprocess.run(["grim", SHOT], timeout=3, capture_output=True)
                shot = SHOT if os.path.exists(SHOT) else ""
            except (OSError, subprocess.SubprocessError):
                shot = ""
        # Fase 8.0: categorias do XMB. Cada item: (ação, {"t": texto, ...})
        jogo = [("resume", {"t": "Voltar ao jogo" if pid else "Voltar"})]
        if pid and read(os.path.join(RUN, "game.sys")) in ("ps1", "snes", "n64", "psp", "gc", "wii", "nds", "3ds", "gba", "gb", "nes", "md"):
            jogo += [("save", {"t": "Salvar estado"}), ("load", {"t": "Carregar estado"})]
        if shot:
            jogo.append(("shot", {"t": "Salvar captura de tela"}))
        if pid:
            jogo.append(("close", {"t": "Fechar jogo", "sub": "O que não foi salvo no jogo será perdido"}))
        ganhos, total, trof = trophies()
        trof_items = [("trofeu", it) for it in trof] or [("nada", {"t": "Nenhum troféu ainda", "kind": "info"})]
        if total:
            trof_items.insert(0, ("nada", {"t": f"{ganhos} de {total} troféus", "kind": "info",
                                           "sub": f"{round(100 * ganhos / total)}% conquistados neste perfil"}))
        self.cats = [
            {"id": "jogo", "title": "Jogo", "icon": "pad", "items": jogo},
            {"id": "trofeus", "title": "Troféus", "icon": "trophy", "items": trof_items},
            {"id": "notificacoes", "title": "Notificações", "icon": "bell", "items": self.notif_items()},
            {"id": "amigos", "title": "Amigos", "icon": "friends", "items": self.amigos_items()},
            {"id": "ajustes", "title": "Ajustes", "icon": "gear",
             "items": [("volume", {"t": "Volume", "kind": "slider", "id": "volume"}),
                       ("brilho", {"t": "Brilho", "kind": "slider", "id": "brilho"})]},
            {"id": "controles", "title": "Controles", "icon": "pad", "items": self.controles_items()},
            {"id": "energia", "title": "Energia", "icon": "power",
             "items": ([("close", {"t": "Fechar jogo"})] if pid and power else []) +
                      ([("pad_off", {"t": "Desligar este controle", "sub": "Os outros continuam ligados",
                                     "mac": self.mac_origem()})] if self.mac_origem() else []) +
                      [("suspend", {"t": "Modo de espera"}), ("reboot", {"t": "Reiniciar o console"}),
                       ("poweroff", {"t": "Desligar o console"})]},
        ]
        # segurar Home abre direto em Energia; o toque abre em Jogo (como no PS3)
        self.cat = len(self.cats) - 1 if power else (self.cat_index(aba) if aba else 0)
        self.sel = 0
        self.items = self.cats[self.cat]["items"]
        try:
            self.overlay = subprocess.Popen([sys.executable, OVERLAY, (title or "Jogo") if pid else "", shot],
                                            stdin=subprocess.PIPE, text=True)
        except OSError as e:
            log(f"não consegui abrir o overlay: {e}; voltando ao jogo")
            self.overlay = None
            self.choose("resume")
            return
        self.send_cats()
        vol, muted = get_volume()
        self.send(f"vol {vol} {int(muted)}")
        self.send(f"bri {get_brightness()}")
        self.send("info " + json.dumps(status_info(), ensure_ascii=False))
        self.info_at = time.monotonic()

    def menu_open(self):
        return self.menu

    # ---------------------------------------------------------- 13.22: controles
    def conferir_ordem(self):
        bt = [c["mac"] for c in controles() if c["mac"]]
        if not bt:
            return
        memoria = ordem_ler()
        novos = [m for m in bt if m not in memoria]
        if novos:                           # controle novo: entra no fim da fila, na ordem em que conectou
            memoria += novos
            ordem_gravar(memoria)
        if len(bt) < 2 or game_pid():       # no meio de um jogo não desliga ninguém
            return
        # o mais prioritário dos ligados tem de ser o primeiro; quem vier antes dele desliga e volta depois
        alvo = min(bt, key=memoria.index)
        if bt[0] == alvo:
            return
        antes = bt[:bt.index(alvo)]
        if any(time.monotonic() - self.reconectar.get(m, -999.0) < 60 for m in antes):
            return                          # já foi desligado há pouco: não insiste
        for m in antes:
            self.reconectar[m] = time.monotonic()
            log(f"ordem: {m} conectou antes do Jogador 1 ({alvo}); desligando para voltar depois")
            threading.Thread(target=desligar_controle, args=(m,), daemon=True).start()
        aviso("Controle do Jogador 2 desligado para manter o Jogador 1: ligue ele de novo")
        play("controle-off")

    def mac_origem(self):
        return next((c["mac"] for c in controles() if c["path"] == self.origem and c["mac"]), "")

    def controles_items(self):
        lst = controles()
        if not lst:
            return [("nada", {"t": "Nenhum controle ligado", "kind": "info"})]
        items = [("nada", {"t": "A ordem dos controles é a dos jogadores", "kind": "info",
                           "sub": "O console lembra quem é o Jogador 1 e mantém essa ordem"})]
        mac = self.mac_origem()
        if mac and len(lst) > 1:
            if ordem_ler()[:1] == [mac]:
                items.append(("nada", {"t": "Este controle é o Jogador 1", "kind": "info",
                                       "sub": "Lembrado pelo console"}))
            else:
                items.append(("pad_p1", {"t": "Tornar este controle o Jogador 1",
                                         "sub": "O outro desliga: ligue ele de novo para ser o Jogador 2",
                                         "mac": mac}))
        for k, c in enumerate(lst):
            este = "  (este)" if c["path"] == self.origem else ""
            bat = f"  ·  bateria {c['bateria']}%" if c["bateria"] is not None else ""
            if c["mac"]:
                items.append(("pad_off", {"t": f"Desligar o controle {k + 1}{este}", "mac": c["mac"],
                                          "sub": f"Jogador {k + 1}: {c['nome']}{bat}"}))
            else:
                items.append(("nada", {"t": f"Controle {k + 1}{este}: {c['nome']}", "kind": "info",
                                       "sub": f"Jogador {k + 1}  ·  ligado por cabo: para desligar, tire o cabo"}))
        return items

    def desligar(self, mac):
        if not mac:
            return
        if mac == self.mac_origem():
            # o controle que está mexendo no menu vai sumir: fecha o menu antes (o jogo continua)
            self.choose("resume")
            threading.Thread(target=desligar_controle, args=(mac,), daemon=True).start()
            return
        self.send("msg Desligando o controle…")

        def run():
            ok = desligar_controle(mac)
            time.sleep(0.8)                  # o controle some da lista um instante depois

            def depois():
                if not self.menu_open():
                    return
                k = self.cat_index("controles")
                self.cats[k]["items"] = self.controles_items()
                if self.cat == k:
                    self.items = self.cats[k]["items"]
                    self.sel = min(self.sel, len(self.items) - 1)
                self.send_cats()
                self.send("msg " + ("Controle desligado" if ok else "Não consegui desligar esse controle"))
            self.fila.put(depois)
        threading.Thread(target=run, daemon=True).start()

    def energia(self, action, pid):
        """Modo de espera / reiniciar / desligar. Com jogo aberto, fecha o jogo do jeito certo antes."""
        def run():
            if pid and action != "suspend":
                close_game(pid)
                for _ in range(50):
                    if not signal_group(pid, 0):
                        break
                    time.sleep(0.1)
                time.sleep(1.5)          # o sky-run ainda grava o tempo de jogo e a cópia dos saves
            log(f"energia: {action}")
            subprocess.run(["systemctl", action], capture_output=True)
        threading.Thread(target=run, daemon=True).start()

    def choose(self, action):
        pid = self.menu_pid
        self.menu_pid = None
        self.menu = self.power = False
        self.amigo = None
        self.kb = None
        marcar_menu(False)
        if self.overlay:
            self.send("quit")
            try:
                self.overlay.wait(timeout=1.5)
            except subprocess.TimeoutExpired:
                self.overlay.kill()
            self.overlay = None
        if action in ("suspend", "reboot", "poweroff"):
            if pid and action == "suspend":
                signal_group(pid, signal.SIGCONT)
            self.energia(action, pid)
        elif pid:
            if action == "close":
                try:                      # o launcher mostra "fechado pelo Home" em vez de código de erro
                    open(os.path.join(RUN, "home_closed"), "w").close()
                except OSError:
                    pass
                close_game(pid)
            else:
                log("voltando ao jogo")
                signal_group(pid, signal.SIGCONT)
        # Só solta os controles depois que todos os botões forem soltos (no máx. 1,5 s),
        # para o jogo não receber o "soltar" de um botão que ele nunca viu ser apertado.
        self.ungrab_at = time.monotonic() + 1.5

    def retroarch(self, command):
        """Descongela o jogo por um instante para o RetroArch executar o comando (salvar/carregar)."""
        pid = self.menu_pid
        if not pid:
            return False
        signal_group(pid, signal.SIGCONT)
        try:
            fd = os.open(RA_FIFO, os.O_WRONLY | os.O_NONBLOCK)
            try:
                os.write(fd, (command + "\n").encode())
            finally:
                os.close(fd)
            time.sleep(0.6)
            return True
        except OSError as e:
            log(f"comando {command} falhou: {e}")
            return False
        finally:
            if command != "LOAD_STATE":
                signal_group(pid, signal.SIGSTOP)

    def activate(self):
        action = self.items[self.sel][0]
        if action in ("resume", "close", "suspend", "reboot", "poweroff"):
            self.choose(action)
        elif action == "save":
            ok = self.retroarch("SAVE_STATE")
            play("salvo" if ok else "alerta")
            self.send("msg " + ("Estado salvo" if ok else "Não consegui salvar o estado"))
        elif action == "load":
            if self.retroarch("LOAD_STATE"):
                play("carregado")
            self.choose("resume")
        elif action == "pad_off":
            self.desligar(self.items[self.sel][1].get("mac", ""))
        elif action == "pad_p1":
            mac = self.items[self.sel][1].get("mac", "")
            if mac:
                ordem_gravar([mac] + [m for m in ordem_ler() if m != mac])
                # quem estiver conectado antes dele desliga e volta depois (a ordem dos emuladores é a de conexão)
                antes = []
                for c in controles():
                    if c["mac"] == mac:
                        break
                    if c["mac"]:
                        antes.append(c["mac"])
                for m in antes:
                    self.reconectar[m] = time.monotonic()
                    threading.Thread(target=desligar_controle, args=(m,), daemon=True).start()
                play("salvo")
                self.choose("resume")
                aviso("Este controle agora é o Jogador 1" +
                      (": ligue o outro de novo para ser o Jogador 2" if antes else ""))
        elif action == "notif":
            try:
                import skyhist
                skyhist.remove(self.items[self.sel][1].get("nid"))
            except Exception:
                pass
            self.refresh_notifs("Notificação apagada")
        elif action == "limpar":
            try:
                import skyhist
                skyhist.clear()
            except Exception:
                pass
            self.refresh_notifs("Notificações limpas")
        elif action == "amigo":
            it = self.items[self.sel][1]
            if it.get("fid"):
                self.abrir_amigo(it["fid"], it.get("nome", "Amigo"))
        elif action == "voltar_amigos":
            self.fechar_amigo()
        elif action == "escrever":
            self.kb_abrir()
        elif action == "rapida":
            self.enviar_mensagem(self.items[self.sel][1]["texto"])
        elif action == "convidar":
            self.enviar_mensagem("", convite=True)
        elif action == "jogar_junto" and self.amigo:
            # a sala só abre com o jogo rodando: volta ao jogo e o sky-netplay faz o resto em segundo
            # plano (abre a sala, acha no lobby e manda o convite; o aviso aparece quando terminar)
            fid = self.amigo[0]
            self.send("msg Abrindo a sala…")
            play("salvo")
            self.choose("resume")
            try:
                subprocess.Popen([sys.executable, os.path.join(SKY_BIN, "sky-netplay"), "hospedar", fid],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            except OSError:
                pass
        elif action == "trofeu":
            it = self.items[self.sel][1]
            self.send("msg " + (it["sub"] if it.get("ganho") else "Ainda não conquistado: " + it["sub"]))
        elif action == "shot":
            os.makedirs(CAPTURAS, exist_ok=True)
            gid = read(os.path.join(RUN, "game.id"), "jogo")
            dest = os.path.join(CAPTURAS, f"{gid}_{time.strftime('%Y%m%d-%H%M%S')}.png")
            try:
                shutil.copyfile(SHOT, dest)
                play("captura")
                self.send("msg Captura salva em Capturas")
            except OSError:
                self.send("msg Não consegui salvar a captura")

    def refresh_notifs(self, msg):
        k = self.cat_index("notificacoes")
        self.cats[k]["items"] = self.notif_items()
        self.items = self.cats[k]["items"]
        self.sel = min(self.sel, len(self.items) - 1)
        self.send_cats()
        self.send("msg " + msg)

    def set_cat(self, k):
        if self.amigo:
            self.fechar_amigo()           # sair da categoria Amigos fecha a conversa
        self.cat = k % len(self.cats)
        self.items = self.cats[self.cat]["items"]
        self.sel = 0
        play("navegar")
        self.send(f"sel {self.cat} {self.sel}")

    def menu_key(self, code, shift=False):
        if self.kb is not None:
            self.kb_key(code, shift)
            return
        n = len(self.items)
        action = self.items[self.sel][0] if n else ""
        if code in NAV_UP and n:
            self.sel = (self.sel - 1) % n
            self.send(f"sel {self.cat} {self.sel}")
        elif code in NAV_DOWN and n:
            self.sel = (self.sel + 1) % n
            self.send(f"sel {self.cat} {self.sel}")
        elif code in CAT_PREV:
            self.set_cat(self.cat - 1)
        elif code in CAT_NEXT:
            self.set_cat(self.cat + 1)
        elif code in NAV_LEFT or code in NAV_RIGHT:
            up = code in NAV_RIGHT
            if action == "volume":
                change_volume(5 if up else -5)
                vol, muted = get_volume()
                self.send(f"vol {vol} {int(muted)}")
            elif action == "brilho":
                change_brightness(10 if up else -10)
                self.send(f"bri {get_brightness()}")
            else:
                self.set_cat(self.cat + (1 if up else -1))
        elif code in ACCEPT and n:
            self.activate()
        elif code in BACK:
            if self.amigo and code in (E.BTN_EAST, E.KEY_ESC, E.KEY_BACKSPACE):
                self.fechar_amigo()       # B dentro da conversa volta à lista de amigos
            else:
                self.choose("resume")

    def menu_abs(self, path, dev, ev):
        if ev.code in (E.ABS_HAT0Y, E.ABS_HAT0X):
            v = ev.value
        elif ev.code in (E.ABS_Y, E.ABS_X):
            try:
                info = dev.absinfo(ev.code)
                mid = (info.max + info.min) / 2
                half = max(1, (info.max - info.min) / 2)
                n = (ev.value - mid) / half
            except OSError:
                return
            v = -1 if n < -0.6 else (1 if n > 0.6 else 0)
        else:
            return
        key = (path, ev.code)
        if v != self.axis.get(key, 0) and v != 0:
            if ev.code in (E.ABS_HAT0Y, E.ABS_Y):
                self.menu_key(E.KEY_UP if v < 0 else E.KEY_DOWN)
            else:
                self.menu_key(E.KEY_LEFT if v < 0 else E.KEY_RIGHT)
        self.axis[key] = v

    # ---------------------------------------------------------- laço principal
    def run(self):
        log("iniciado")
        last_scan = 0.0
        while True:
            now = time.monotonic()
            if now - last_scan > 2.0:
                self.scan()
                last_scan = now

            fds = {dev.fd: path for path, dev in self.devices.items()}
            ready = []
            if fds:
                try:
                    ready, _, _ = select.select(list(fds), [], [], 0.05)
                except (OSError, ValueError):
                    last_scan = 0.0
            else:
                time.sleep(0.5)

            for fd in ready:
                path = fds[fd]
                dev = self.devices.get(path)
                if dev is None:
                    continue
                try:
                    events = dev.read()
                    for ev in events:
                        if ev.type == E.EV_KEY:
                            if ev.value:
                                self.pressed[path].add(ev.code)
                            else:
                                self.pressed[path].discard(ev.code)
                            if self.menu_open() and ev.value == 1:
                                shift = bool(self.pressed[path] & {E.KEY_LEFTSHIFT, E.KEY_RIGHTSHIFT})
                                self.menu_key(ev.code, shift)
                        elif ev.type == E.EV_ABS and self.menu_open():
                            self.menu_abs(path, dev, ev)
                except OSError:
                    last_scan = 0.0

            # resultados de rede (conversa carregada, mensagem enviada)
            while True:
                try:
                    acao = self.fila.get_nowait()
                except queue.Empty:
                    break
                try:
                    acao()
                except Exception as e:      # nunca derruba o botão Home
                    log(f"erro ao aplicar resultado: {e!r}")

            # Fase 8.1: deslize no touchpad (sky-notify) pede o menu já na aba Notificações
            pedido = os.path.join(RUN, "home.pedido")
            if os.path.exists(pedido):
                try:
                    os.remove(pedido)
                except OSError:
                    pass
                pid = game_pid()
                if pid and not self.menu_open():
                    self.open_menu(pid, aba="notificacoes")
                elif self.menu_open():
                    self.set_cat(self.cat_index("notificacoes"))

            # overlay morreu sozinho? volta ao jogo para não deixá-lo congelado
            if self.menu_open() and (self.overlay is None or self.overlay.poll() is not None):
                log("overlay fechou inesperadamente; voltando ao jogo")
                self.overlay = None
                self.choose("resume")

            # rodapé do menu (bateria, temperatura, hora) a cada 2 s
            if self.menu_open() and time.monotonic() - self.info_at > 2.0:
                self.info_at = time.monotonic()
                self.send("info " + json.dumps(status_info(), ensure_ascii=False))

            # 13.23: mantém a ordem lembrada dos controles (fora de jogo e de menu, a cada 3 s)
            if not self.menu_open() and time.monotonic() - self.ordem_at > 3.0:
                self.ordem_at = time.monotonic()
                try:
                    self.conferir_ordem()
                except Exception as e:      # nunca derruba o botão Home
                    log(f"ordem dos controles: {e!r}")

            # soltar os controles depois de fechar o menu
            if self.grabbed and not self.menu_open() and self.ungrab_at is not None:
                if not any(self.pressed.values()) or time.monotonic() > self.ungrab_at:
                    self.grab_all(False)
                    self.ungrab_at = None

            active = any(combo(s) for s in self.pressed.values())
            if not active:
                self.hold0 = None
            if self.menu_open() or self.grabbed:
                # saída de emergência: Home segurado sem soltar por 5 s fecha o jogo, com menu ou sem
                if self.menu_open() and self.hold0 and self.menu_pid and time.monotonic() - self.hold0 >= HOLD_KILL:
                    self.hold0 = None
                    self.choose("close")
                self.since, self.fired = None, False
                continue

            # toque curto -> menu do jogo | segurar 1,5 s -> menu de energia
            if active:
                if self.since is None:
                    self.origem = next((p for p, s in self.pressed.items() if combo(s)), None)
                self.since = self.since or time.monotonic()
                if not self.fired and time.monotonic() - self.since >= HOLD:
                    self.fired = True
                    self.hold0 = self.since
                    self.open_menu(game_pid(), power=True)
            else:
                if self.since is not None and not self.fired:
                    pid = game_pid()
                    if pid:
                        self.open_menu(pid)
                self.since, self.fired = None, False


if __name__ == "__main__":
    Home().run()
