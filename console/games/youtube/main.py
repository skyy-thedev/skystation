#!/usr/bin/env python3
"""SkyStation: YouTube para TV (Fase 6.3). Abre youtube.com/tv em tela cheia no WebKitGTK,
se apresentando como uma smart TV: a interface é a das TVs, feita para direcional + OK + voltar.

Controle: o próprio site lê o controle (Gamepad API do WebKit). Teclado: setas, Enter, Esc.
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


app = Gtk.Application(application_id="br.skystation.youtube")
app.connect("activate", on_activate)
sys.exit(app.run([]))
