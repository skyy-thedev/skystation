#!/usr/bin/env python3
"""SkyStation: botão Home.

Roda em segundo plano durante toda a sessão (iniciado pelo sky-shell, dentro do cage)
e escuta todos os controles e teclados, sem atrapalhar ninguém.

Com um jogo aberto:
  - TOQUE no Home (ou Select+Start, ou F12): o jogo PAUSA e abre o menu por cima:
    Voltar ao jogo, Salvar/Carregar estado (PS1), Salvar captura de tela, Volume e Fechar jogo,
    com bateria, temperatura e hora no rodapé (Fase 5.6).
  - SEGURAR 1,5 s: fecha o jogo direto (saída de emergência, funciona mesmo se o menu falhar).

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
RUN = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "skystation")
PID_FILE = os.path.join(RUN, "game.pid")
TITLE_FILE = os.path.join(RUN, "game.title")
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
ACCEPT = {E.BTN_SOUTH, E.KEY_ENTER, E.KEY_KPENTER, E.KEY_SPACE}
BACK = {E.BTN_EAST, E.KEY_ESC, E.KEY_BACKSPACE, E.BTN_MODE, E.KEY_F12, E.BTN_START}


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
        self.overlay = None
        self.sel = 0
        self.grabbed = False
        self.ungrab_at = None
        self.items = []         # [(ação, texto)]
        self.info_at = 0.0

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

    def open_menu(self, pid):
        log("menu Home aberto")
        self.menu_pid = pid
        signal_group(pid, signal.SIGSTOP)
        self.grab_all(True)
        self.ungrab_at = None
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
        self.items = [("resume", "Voltar ao jogo")]
        if read(os.path.join(RUN, "game.sys")) in ("ps1", "snes", "n64", "psp"):
            self.items += [("save", "Salvar estado"), ("load", "Carregar estado")]
        if shot:
            self.items.append(("shot", "Salvar captura de tela"))
        self.items += [("volume", "Volume"), ("close", "Fechar jogo")]
        self.sel = 0
        try:
            self.overlay = subprocess.Popen([sys.executable, OVERLAY, title or "Jogo", shot],
                                            stdin=subprocess.PIPE, text=True)
        except OSError as e:
            log(f"não consegui abrir o overlay: {e}; voltando ao jogo")
            self.overlay = None
            self.choose("resume")
            return
        self.send("items " + json.dumps([t for _, t in self.items], ensure_ascii=False))
        self.send(f"sel {self.sel}")
        vol, muted = get_volume()
        self.send(f"vol {vol} {int(muted)}")
        self.send("info " + json.dumps(status_info(), ensure_ascii=False))
        self.info_at = time.monotonic()

    def menu_open(self):
        return self.menu_pid is not None

    def choose(self, action):
        pid = self.menu_pid
        self.menu_pid = None
        if self.overlay:
            self.send("quit")
            try:
                self.overlay.wait(timeout=1.5)
            except subprocess.TimeoutExpired:
                self.overlay.kill()
            self.overlay = None
        if pid:
            if action == "close":
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
        if action in ("resume", "close"):
            self.choose(action)
        elif action == "save":
            ok = self.retroarch("SAVE_STATE")
            play("salvo" if ok else "alerta")
            self.send("msg " + ("Estado salvo" if ok else "Não consegui salvar o estado"))
        elif action == "load":
            if self.retroarch("LOAD_STATE"):
                play("carregado")
            self.choose("resume")
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

    def menu_key(self, code):
        n = len(self.items)
        if code in NAV_UP:
            self.sel = (self.sel - 1) % n
            self.send(f"sel {self.sel}")
        elif code in NAV_DOWN:
            self.sel = (self.sel + 1) % n
            self.send(f"sel {self.sel}")
        elif code in NAV_LEFT or code in NAV_RIGHT:
            if self.items[self.sel][0] == "volume":
                change_volume(5 if code in NAV_RIGHT else -5)
                vol, muted = get_volume()
                self.send(f"vol {vol} {int(muted)}")
        elif code in ACCEPT:
            self.activate()
        elif code in BACK:
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
                                self.menu_key(ev.code)
                        elif ev.type == E.EV_ABS and self.menu_open():
                            self.menu_abs(path, dev, ev)
                except OSError:
                    last_scan = 0.0

            # overlay morreu sozinho? volta ao jogo para não deixá-lo congelado
            if self.menu_open() and (self.overlay is None or self.overlay.poll() is not None):
                log("overlay fechou inesperadamente; voltando ao jogo")
                self.overlay = None
                self.choose("resume")

            # rodapé do menu (bateria, temperatura, hora) a cada 2 s
            if self.menu_open() and time.monotonic() - self.info_at > 2.0:
                self.info_at = time.monotonic()
                self.send("info " + json.dumps(status_info(), ensure_ascii=False))

            # soltar os controles depois de fechar o menu
            if self.grabbed and not self.menu_open() and self.ungrab_at is not None:
                if not any(self.pressed.values()) or time.monotonic() > self.ungrab_at:
                    self.grab_all(False)
                    self.ungrab_at = None

            if self.menu_open() or self.grabbed:
                self.since, self.fired = None, False
                continue

            # toque curto -> menu | segurar 1,5 s -> fecha direto
            active = any(combo(s) for s in self.pressed.values())
            if active:
                self.since = self.since or time.monotonic()
                if not self.fired and time.monotonic() - self.since >= HOLD:
                    pid = game_pid()
                    if pid:
                        close_game(pid)
                    self.fired = True
            else:
                if self.since is not None and not self.fired:
                    pid = game_pid()
                    if pid:
                        self.open_menu(pid)
                self.since, self.fired = None, False


if __name__ == "__main__":
    Home().run()
