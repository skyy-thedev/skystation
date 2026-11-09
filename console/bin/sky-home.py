#!/usr/bin/env python3
"""SkyStation: botão Home.

Roda em segundo plano durante toda a sessão (iniciado pelo sky-shell, dentro do cage)
e escuta todos os controles e teclados, sem atrapalhar ninguém.

Com um jogo aberto:
  - TOQUE no Home (ou Select+Start, ou F12): o jogo PAUSA e abre o menu por cima,
    com "Voltar ao jogo" e "Fechar jogo".
  - SEGURAR 1,5 s: fecha o jogo direto (saída de emergência, funciona mesmo se o menu falhar).

Como o menu funciona por baixo:
  1. SIGSTOP no grupo de processos do jogo: ele congela (imagem, som e lógica).
  2. grab() em todos os controles/teclados: só o SkyStation recebe os botões enquanto
     o menu está aberto. Sem isso, o "A" que você aperta no menu chegaria ao jogo depois.
  3. sky-overlay.py desenha o menu; este processo manda para ele qual item está selecionado.
  4. Ao escolher: SIGCONT (o jogo continua de onde parou) ou fechamento em duas etapas
     (SIGTERM, e SIGKILL se em 3 s ele não fechou).
"""
import os
import select
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
OVERLAY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sky-overlay.py")

TRIGGERS = {E.BTN_MODE, E.BTN_SELECT, E.BTN_START, E.KEY_F12}
NAV_UP = {E.KEY_UP, E.BTN_DPAD_UP, E.KEY_W}
NAV_DOWN = {E.KEY_DOWN, E.BTN_DPAD_DOWN, E.KEY_S}
ACCEPT = {E.BTN_SOUTH, E.KEY_ENTER, E.KEY_KPENTER, E.KEY_SPACE}
BACK = {E.BTN_EAST, E.KEY_ESC, E.KEY_BACKSPACE, E.BTN_MODE, E.KEY_F12, E.BTN_START}
ITEMS = ["Voltar ao jogo", "Fechar jogo"]


def log(msg):
    print(time.strftime("%H:%M:%S"), "sky-home:", msg, flush=True)


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
        title = ""
        try:
            with open(TITLE_FILE) as f:
                title = f.read().strip()
        except OSError:
            pass
        self.sel = 0
        try:
            self.overlay = subprocess.Popen([sys.executable, OVERLAY, title or "Jogo"],
                                            stdin=subprocess.PIPE, text=True)
        except OSError as e:
            log(f"não consegui abrir o overlay: {e}; voltando ao jogo")
            self.overlay = None
            self.choose(0)
            return
        self.send(f"sel {self.sel}")

    def menu_open(self):
        return self.menu_pid is not None

    def choose(self, idx):
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
            if idx == 1:
                close_game(pid)
            else:
                log("voltando ao jogo")
                signal_group(pid, signal.SIGCONT)
        # Só solta os controles depois que todos os botões forem soltos (no máx. 1,5 s),
        # para o jogo não receber o "soltar" de um botão que ele nunca viu ser apertado.
        self.ungrab_at = time.monotonic() + 1.5

    def menu_key(self, code):
        if code in NAV_UP:
            self.sel = (self.sel - 1) % len(ITEMS)
            self.send(f"sel {self.sel}")
        elif code in NAV_DOWN:
            self.sel = (self.sel + 1) % len(ITEMS)
            self.send(f"sel {self.sel}")
        elif code in ACCEPT:
            self.choose(self.sel)
        elif code in BACK:
            self.choose(0)

    def menu_abs(self, path, dev, ev):
        if ev.code == E.ABS_HAT0Y:
            v = ev.value
        elif ev.code == E.ABS_Y:
            try:
                info = dev.absinfo(E.ABS_Y)
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
            self.menu_key(E.KEY_UP if v < 0 else E.KEY_DOWN)
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
                self.choose(0)

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
