#!/usr/bin/env python3
"""SkyStation: YouTube para TV (Fase 6.3). Abre youtube.com/tv em tela cheia no WebKitGTK,
se apresentando como uma smart TV: a interface é a das TVs, feita para direcional + OK + voltar.

Controle: este app lê o controle e "digita" as teclas que o site entende (setas, Enter, Esc),
pelo teclado virtual do Wayland (wtype). Direcional/analógico = navegar, A = abrir, B = voltar,
Start = pausar/continuar, L1/R1 = voltar/avançar no vídeo.
Sair: botão Home do controle -> Fechar, ou Ctrl+Q.
"""
import os
import sys

if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
    _bus = os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), "bus")
    if os.path.exists(_bus):
        os.environ["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=" + _bus
    elif not os.environ.get("SKY_DBUS_WRAPPED"):
        os.environ["SKY_DBUS_WRAPPED"] = "1"
        os.execvp("dbus-run-session", ["dbus-run-session", "--", sys.executable] + sys.argv)
if os.environ.get("LIBGL_ALWAYS_SOFTWARE") == "1":
    os.environ.setdefault("WEBKIT_DISABLE_DMABUF_RENDERER", "1")

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("WebKit", "6.0")
from gi.repository import Gdk, Gtk, WebKit  # noqa: E402

import shutil  # noqa: E402
import subprocess  # noqa: E402
import threading  # noqa: E402
import time  # noqa: E402


class Pad:
    """Estado do controle -> teclas. Sem E/S, para poder testar: eventos entram, nomes de tecla saem."""
    BOTOES = {"SOUTH": "Return", "EAST": "Escape", "START": "space", "TL": "Left", "TR": "Right"}

    def __init__(self):
        self.dir = {"x": 0, "y": 0}        # direcional (hat) e analógico somados
        self.hat = {"x": 0, "y": 0}
        self.stick = {"x": 0, "y": 0}
        self.held = None                   # direção segurada, para repetir
        self.next = 0.0

    def button(self, name, down):
        return [self.BOTOES[name]] if down and name in self.BOTOES else []

    def axis(self, kind, ax, value, now):
        """kind: "hat" (-1/0/1) ou "stick" (-1.0..1.0)."""
        v = value if kind == "hat" else (1 if value > 0.6 else -1 if value < -0.6 else 0)
        (self.hat if kind == "hat" else self.stick)[ax] = v
        new = self.hat[ax] or self.stick[ax]
        if new == self.dir[ax]:
            return []
        self.dir[ax] = new
        key = self._key()
        self.held, self.next = key, now + 0.45
        return [key] if key else []

    def _key(self):
        if self.dir["y"]:
            return "Up" if self.dir["y"] < 0 else "Down"
        if self.dir["x"]:
            return "Left" if self.dir["x"] < 0 else "Right"
        return None

    def tick(self, now):
        if self.held and now >= self.next:
            self.next = now + 0.14
            return [self.held]
        return []


def pad_worker():
    """Lê os controles (evdev) e envia as teclas com o wtype."""
    try:
        import evdev
        import select
    except ImportError:
        return
    wtype = shutil.which("wtype")
    if not wtype:
        return
    E = evdev.ecodes
    botoes = {E.BTN_SOUTH: "SOUTH", E.BTN_EAST: "EAST", E.BTN_START: "START", E.BTN_TL: "TL", E.BTN_TR: "TR"}
    pad, devs, scan = Pad(), {}, 0.0
    while True:
        now = time.monotonic()
        if now >= scan:
            scan = now + 4.0
            for path in evdev.list_devices():
                if path in devs:
                    continue
                try:
                    d = evdev.InputDevice(path)
                    keys = d.capabilities().get(E.EV_KEY, [])
                    nome = d.name.lower()
                    if E.BTN_SOUTH in keys and "touchpad" not in nome and "motion" not in nome:
                        devs[path] = d
                    else:
                        d.close()
                except OSError:
                    pass
        out = []
        try:
            ready, _, _ = select.select(list(devs.values()), [], [], 0.05) if devs else ([], [], [])
            if not devs:
                time.sleep(0.5)
            for d in ready:
                for ev in d.read():
                    if ev.type == E.EV_KEY and ev.code in botoes and ev.value in (0, 1):
                        out += pad.button(botoes[ev.code], ev.value == 1)
                    elif ev.type == E.EV_ABS and ev.code in (E.ABS_HAT0X, E.ABS_HAT0Y):
                        out += pad.axis("hat", "x" if ev.code == E.ABS_HAT0X else "y", ev.value, time.monotonic())
                    elif ev.type == E.EV_ABS and ev.code in (E.ABS_X, E.ABS_Y):
                        info = d.absinfo(ev.code)
                        mid, half = (info.max + info.min) / 2, max(1, (info.max - info.min) / 2)
                        out += pad.axis("stick", "x" if ev.code == E.ABS_X else "y", (ev.value - mid) / half, time.monotonic())
        except OSError:                       # controle desconectou (ou o menu Home pegou o controle)
            for path, d in list(devs.items()):
                try:
                    d.absinfo(E.ABS_X) if E.EV_ABS in d.capabilities() else d.name
                except OSError:
                    devs.pop(path, None)
            pad = Pad()
            time.sleep(0.3)
        out += pad.tick(time.monotonic())
        for key in out:
            subprocess.run([wtype, "-k", key], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


URL = "https://www.youtube.com/tv"
UA = "Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) 85.0.4183.93/6.0 TV Safari/537.36"
DATA = os.path.expanduser("~/.local/share/skystation/youtube")   # mantém o login entre as sessões


def on_activate(app):
    win = Gtk.ApplicationWindow(application=app, title="YouTube")
    os.makedirs(DATA, exist_ok=True)
    session = WebKit.NetworkSession.new(DATA, os.path.join(DATA, "cache"))
    session.get_cookie_manager().set_persistent_storage(
        os.path.join(DATA, "cookies.sqlite"), WebKit.CookiePersistentStorage.SQLITE)
    view = WebKit.WebView(network_session=session)
    st = view.get_settings()
    st.set_user_agent(UA)
    st.set_enable_media_stream(False)
    st.set_media_playback_requires_user_gesture(False)
    st.set_hardware_acceleration_policy(WebKit.HardwareAccelerationPolicy.ALWAYS)
    view.set_background_color(Gdk.RGBA())
    win.set_child(view)
    keys = Gtk.EventControllerKey()

    def on_key(_c, keyval, _code, state):
        if keyval == Gdk.KEY_q and state & Gdk.ModifierType.CONTROL_MASK:
            app.quit()
            return True
        return False

    keys.connect("key-pressed", on_key)
    win.add_controller(keys)
    win.fullscreen()
    win.present()
    view.load_uri(URL)
    view.grab_focus()
    threading.Thread(target=pad_worker, daemon=True).start()


app = Gtk.Application(application_id="br.skystation.youtube")
app.connect("activate", on_activate)
sys.exit(app.run([]))
