#!/usr/bin/env python3
"""SkyStation Navegador: navegador simples para testes (GTK 4 + WebKitGTK 6).

Teclado e mouse:
  Ctrl+L        ir para a barra de endereço
  Alt+← / Alt+→ voltar / avançar
  F5            recarregar
  Ctrl+H        página inicial
  Ctrl+Q        sair (ou o botão Home do controle -> "Fechar jogo")
"""
import os
import sys
import urllib.parse

# O WebKit conversa com outros serviços pelo D-Bus de sessão. Dentro do console nem sempre
# a variável vem pronta: usa o barramento do usuário (systemd) ou cria um só para o navegador.
if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
    _bus = os.path.join(os.environ.get("XDG_RUNTIME_DIR", ""), "bus")
    if os.path.exists(_bus):
        os.environ["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=" + _bus
    elif not os.environ.get("SKY_DBUS_WRAPPED"):
        os.environ["SKY_DBUS_WRAPPED"] = "1"
        os.execvp("dbus-run-session", ["dbus-run-session", "--", sys.executable] + sys.argv)

# Na VM (renderização por software) o WebKit precisa deste ajuste para não abrir páginas em branco.
if os.environ.get("LIBGL_ALWAYS_SOFTWARE") == "1":
    os.environ.setdefault("WEBKIT_DISABLE_DMABUF_RENDERER", "1")

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("WebKit", "6.0")
from gi.repository import Gdk, Gtk, WebKit  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
HOME_PAGE = "file://" + os.path.join(HERE, "inicio.html")

CSS = """
window, .barra { background: #060918; }
.barra { padding: 8px 12px; }
.barra button { background: #121a3a; color: #eef2ff; border: 1px solid #26335f;
                border-radius: 10px; min-width: 40px; min-height: 36px; font-weight: bold; }
.barra button:hover { background: #1c2752; }
.barra entry { background: #121a3a; color: #eef2ff; border: 1px solid #26335f;
               border-radius: 10px; min-height: 36px; caret-color: #4fd1ff; }
.barra entry:focus-within { border-color: #4fd1ff; }
.marca { color: #4fd1ff; font-weight: 800; font-size: 16px; margin: 0 10px 0 4px; }
progressbar trough, progressbar progress { min-height: 3px; }
progressbar progress { background: #4fd1ff; }
"""


def normalize(text):
    """Endereço, domínio solto ou busca."""
    t = text.strip()
    if not t:
        return HOME_PAGE
    if t.startswith(("http://", "https://", "file://", "about:")):
        return t
    if " " not in t and "." in t:
        return "https://" + t
    return "https://www.google.com/search?q=" + urllib.parse.quote_plus(t)


class Navegador(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="SkyStation Navegador")
        self.set_default_size(1280, 720)

        self.view = WebKit.WebView()
        settings = self.view.get_settings()
        # Na VM (sem aceleração 3D) a composição por GPU deixa páginas em branco: desliga.
        if os.environ.get("LIBGL_ALWAYS_SOFTWARE") == "1":
            settings.set_hardware_acceleration_policy(WebKit.HardwareAccelerationPolicy.NEVER)
        settings.set_enable_smooth_scrolling(True)

        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        bar.add_css_class("barra")
        marca = Gtk.Label(label="SkyStation")
        marca.add_css_class("marca")
        bar.append(marca)

        self.btn_back = self._button("←", lambda *_: self.view.go_back(), bar)
        self.btn_fwd = self._button("→", lambda *_: self.view.go_forward(), bar)
        self._button("⟳", lambda *_: self.view.reload(), bar)
        self._button("⌂", lambda *_: self.view.load_uri(HOME_PAGE), bar)

        self.entry = Gtk.Entry()
        self.entry.set_hexpand(True)
        self.entry.set_placeholder_text("Digite um endereço ou pesquise")
        self.entry.connect("activate", self.on_go)
        bar.append(self.entry)
        self._button("Ir", self.on_go, bar)
        self._button("✕", lambda *_: app.quit(), bar)

        self.progress = Gtk.ProgressBar()
        self.progress.set_visible(False)

        self.view.set_vexpand(True)
        self.view.connect("notify::uri", self.on_uri)
        self.view.connect("notify::estimated-load-progress", self.on_progress)
        self.view.connect("load-changed", self.on_load_changed)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.append(bar)
        box.append(self.progress)
        box.append(self.view)
        self.set_child(box)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self.on_key)
        self.add_controller(keys)

        self.view.load_uri(HOME_PAGE)
        self.fullscreen()

    def _button(self, label, cb, parent):
        b = Gtk.Button(label=label)
        b.connect("clicked", cb)
        parent.append(b)
        return b

    def on_go(self, *_):
        self.view.load_uri(normalize(self.entry.get_text()))
        self.view.grab_focus()

    def on_uri(self, *_):
        uri = self.view.get_uri() or ""
        self.entry.set_text("" if uri == HOME_PAGE else uri)

    def on_progress(self, *_):
        p = self.view.get_estimated_load_progress()
        self.progress.set_fraction(p)
        self.progress.set_visible(p < 1.0)

    def on_load_changed(self, *_):
        self.btn_back.set_sensitive(self.view.can_go_back())
        self.btn_fwd.set_sensitive(self.view.can_go_forward())

    def on_key(self, _ctrl, keyval, _code, state):
        ctrl = bool(state & Gdk.ModifierType.CONTROL_MASK)
        alt = bool(state & Gdk.ModifierType.ALT_MASK)
        if ctrl and keyval in (Gdk.KEY_l, Gdk.KEY_L):
            self.entry.grab_focus()
            self.entry.select_region(0, -1)
        elif alt and keyval == Gdk.KEY_Left:
            self.view.go_back()
        elif alt and keyval == Gdk.KEY_Right:
            self.view.go_forward()
        elif keyval == Gdk.KEY_F5:
            self.view.reload()
        elif ctrl and keyval in (Gdk.KEY_h, Gdk.KEY_H):
            self.view.load_uri(HOME_PAGE)
        elif ctrl and keyval in (Gdk.KEY_q, Gdk.KEY_Q):
            self.get_application().quit()
        else:
            return False
        return True


def main():
    app = Gtk.Application(application_id="br.skystation.Navegador")

    def activate(a):
        provider = Gtk.CssProvider()
        try:
            provider.load_from_string(CSS)          # GTK >= 4.12
        except AttributeError:
            provider.load_from_data(CSS, -1)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        Navegador(a).present()

    app.connect("activate", activate)
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
