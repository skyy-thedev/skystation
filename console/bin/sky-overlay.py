#!/usr/bin/env python3
"""SkyStation: tela do menu Home dentro do jogo (só desenha). Fase 8.0: estilo XMB do PS3.

Como no PS3, apertar Home no meio do jogo abre a barra cruzada por cima da imagem congelada:
categorias na horizontal (Jogo, Troféus, Amigos, Ajustes, Energia) e itens na vertical.

Quem lê os controles é o sky-home.py (que "segura" todos os dispositivos enquanto o menu
está aberto); ele manda para cá, pela entrada padrão, uma linha por comando:
    cats [json]      -> categorias: [{"id","title","icon","items":[{"t","sub"?,"kind"?,...}]}]
                        kind: "acao" (padrão) | "slider" (volume/brilho) | "trofeu" | "info"
    sel <c> <i>      -> categoria e item selecionados
    vol <0-100> <0|1>-> volume atual e mudo
    bri <0-100|-1>   -> brilho atual (-1 = sem controle de brilho)
    info {json}      -> bateria, controles, temperatura e hora
    msg <texto>      -> aviso rápido (ex.: "Estado salvo")
    quit             -> fechar
Uso: sky-overlay.py <título do jogo> [foto da tela congelada]
Teste sem tela:  SDL_VIDEODRIVER=dummy SKY_OVERLAY_PNG=/tmp/x.png sky-overlay.py "Jogo" < comandos
"""
import json
import math
import os
import queue
import sys
import threading
import time

import pygame

ACCENT = (79, 209, 255)
WHITE = (242, 246, 255)
MUTED = (169, 182, 216)
DIM = (109, 123, 163)
WARN = (255, 170, 90)
NIVEIS = {"bronze": (205, 127, 50), "prata": (200, 210, 225), "ouro": (255, 205, 70), "platina": (170, 220, 255)}


def reader(q):
    for line in sys.stdin:
        q.put(line.rstrip("\n"))
    q.put("quit")


def accent_from_theme():
    # mesma cor de destaque do tema escolhido no launcher
    themes = {"noite": (79, 209, 255), "oceano": (95, 220, 255), "aurora": (84, 240, 184),
              "crepusculo": (255, 122, 208), "brasa": (255, 154, 82), "grafite": (207, 216, 234)}
    try:
        with open(os.path.expanduser("~/.config/skystation/tema")) as f:
            key = f.read().strip()
    except OSError:
        key = "auto"
    if key == "auto":
        h = time.localtime().tm_hour
        key = "oceano" if 6 <= h < 11 else "aurora" if 11 <= h < 17 else "crepusculo" if 17 <= h < 20 else "noite"
    return themes.get(key, ACCENT)


def background(path, size):
    """Foto do jogo congelado, levemente desfocada e escurecida, como no PS3 (ou um degradê)."""
    W, H = size
    surf = pygame.Surface(size)
    try:
        if path and os.path.exists(path):
            img = pygame.image.load(path).convert()
            small = pygame.transform.smoothscale(img, (max(1, W // 6), max(1, H // 6)))
            surf = pygame.transform.smoothscale(small, size)       # "desfoque" barato
            shade = pygame.Surface(size, pygame.SRCALPHA)
            for y in range(H):                                     # mais escuro no meio (onde fica o menu)
                k = abs(y / max(1, H - 1) - 0.45)
                shade.fill((2, 6, 20, int(205 - 90 * k)), (0, y, W, 1))
            surf.blit(shade, (0, 0))
            return surf
    except pygame.error:
        pass
    for y in range(H):
        k = y / max(1, H - 1)
        surf.fill((int(4 + 9 * k), int(8 + 18 * k), int(23 + 51 * k)), (0, y, W, 1))
    return surf


# ------------------------------------------------------------------ ícones (desenhados, sem imagens)
def icon(screen, kind, c, r, col, width=None):
    """Ícone simples centrado em c, com "raio" r."""
    x, y = c
    w = width or max(2, int(r * 0.14))
    if kind == "pad":
        body = pygame.Rect(0, 0, int(r * 1.9), int(r * 1.1))
        body.center = (x, y)
        pygame.draw.rect(screen, col, body, w, border_radius=int(r * 0.5))
        pygame.draw.line(screen, col, (x - r * 0.62, y), (x - r * 0.28, y), w)
        pygame.draw.line(screen, col, (x - r * 0.45, y - r * 0.17), (x - r * 0.45, y + r * 0.17), w)
        pygame.draw.circle(screen, col, (int(x + r * 0.42), int(y - r * 0.1)), max(2, int(r * 0.09)))
        pygame.draw.circle(screen, col, (int(x + r * 0.6), int(y + r * 0.1)), max(2, int(r * 0.09)))
    elif kind == "trophy":
        cup = [(x - r * 0.55, y - r * 0.7), (x + r * 0.55, y - r * 0.7), (x + r * 0.4, y + r * 0.05),
               (x, y + r * 0.25), (x - r * 0.4, y + r * 0.05)]
        pygame.draw.polygon(screen, col, cup, w)
        pygame.draw.arc(screen, col, (x - r * 0.95, y - r * 0.65, r * 0.6, r * 0.6), 1.2, 4.6, w)
        pygame.draw.arc(screen, col, (x + r * 0.35, y - r * 0.65, r * 0.6, r * 0.6), -1.5, 1.9, w)
        pygame.draw.line(screen, col, (x, y + r * 0.25), (x, y + r * 0.6), w)
        pygame.draw.line(screen, col, (x - r * 0.4, y + r * 0.7), (x + r * 0.4, y + r * 0.7), w)
    elif kind == "friends":
        pygame.draw.circle(screen, col, (int(x - r * 0.3), int(y - r * 0.35)), int(r * 0.28), w)
        pygame.draw.arc(screen, col, (x - r * 0.85, y, r * 1.1, r * 1.1), 0.2, math.pi - 0.2, w)
        pygame.draw.circle(screen, col, (int(x + r * 0.42), int(y - r * 0.2)), int(r * 0.22), w)
        pygame.draw.arc(screen, col, (x + r * 0.02, y + r * 0.12, r * 0.85, r * 0.9), 0.3, math.pi - 0.6, w)
    elif kind == "gear":
        pygame.draw.circle(screen, col, (x, y), int(r * 0.42), w)
        pygame.draw.circle(screen, col, (x, y), int(r * 0.15), w)
        for k in range(8):
            a = k * math.pi / 4
            pygame.draw.line(screen, col, (x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45),
                             (x + math.cos(a) * r * 0.72, y + math.sin(a) * r * 0.72), w + 2)
    elif kind == "power":
        # anel aberto em cima (o arco vai no sentido anti-horário de "start" até "stop")
        pygame.draw.arc(screen, col, (x - r * 0.62, y - r * 0.55, r * 1.24, r * 1.24),
                        math.pi / 2 + 0.55, math.pi / 2 - 0.55 + 2 * math.pi, w)
        pygame.draw.line(screen, col, (x, y - r * 0.75), (x, y), w + 1)
    elif kind == "lock":
        pygame.draw.rect(screen, col, (x - r * 0.45, y - r * 0.05, r * 0.9, r * 0.7), w, border_radius=int(r * 0.12))
        pygame.draw.arc(screen, col, (x - r * 0.3, y - r * 0.55, r * 0.6, r * 0.8), 0, math.pi, w)


def battery_icon(screen, x, y, s, cap, charging, color):
    w, h = int(30 * s), int(15 * s)
    pygame.draw.rect(screen, color, (x, y, w, h), width=max(1, int(2 * s)), border_radius=int(3 * s))
    pygame.draw.rect(screen, color, (x + w, y + h // 4, int(3 * s), h // 2))
    fill = WARN if cap <= 15 and not charging else color
    inner = int((w - 6 * s) * max(0, min(100, cap)) / 100)
    pygame.draw.rect(screen, fill, (x + int(3 * s), y + int(3 * s), inner, h - int(6 * s)))


def ease(cur, target, dt, speed=14.0):
    return target + (cur - target) * math.exp(-speed * dt)


def fit(font, text, max_w):
    if font.size(text)[0] <= max_w:
        return text
    while text and font.size(text + "…")[0] > max_w:
        text = text[:-1]
    return text + "…"


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else ""
    shot = sys.argv[2] if len(sys.argv) > 2 else ""
    png_out = os.environ.get("SKY_OVERLAY_PNG", "")   # teste sem tela: grava a última imagem
    q = queue.Queue()
    threading.Thread(target=reader, args=(q,), daemon=True).start()

    # Só vídeo e fontes: nada de áudio ou joystick (os controles estão com o sky-home).
    pygame.display.init()
    pygame.font.init()
    if os.environ.get("SDL_VIDEODRIVER") == "dummy":
        screen = pygame.display.set_mode((1280, 720))
    else:
        screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    pygame.display.set_caption("SkyStation - Home")
    pygame.mouse.set_visible(False)
    W, H = screen.get_size()
    s = H / 720
    names = "notosans,dejavusans,liberationsans,opensans"
    f_tag = pygame.font.SysFont(names, int(15 * s), bold=True)
    f_game = pygame.font.SysFont(names, int(20 * s), bold=True)
    f_cat = pygame.font.SysFont(names, int(19 * s))
    f_item = pygame.font.SysFont(names, int(22 * s))
    f_item_on = pygame.font.SysFont(names, int(24 * s), bold=True)
    f_sub = pygame.font.SysFont(names, int(15 * s))
    f_clock = pygame.font.SysFont(names, int(30 * s), bold=True)
    accent = accent_from_theme()
    bg = background(shot, (W, H))
    clock = pygame.time.Clock()

    cats = [{"id": "jogo", "title": "Jogo", "icon": "pad", "items": [{"t": "Voltar ao jogo"}]}]
    sc, si = 0, 0
    vol, muted, bri, info = -1, False, -1, {}
    msg, msg_t = "", 0.0
    t0 = last = time.monotonic()
    cam_x, cam_y = 0.0, 0.0          # animação: posição "visual" que persegue a seleção
    dirty_png = 0

    while True:
        try:
            while True:
                cmd = q.get_nowait()
                if cmd == "quit":
                    if png_out:
                        pygame.image.save(screen, png_out)
                    pygame.quit()
                    return
                head, _, rest = cmd.partition(" ")
                if head == "cats":
                    cats = json.loads(rest) or cats
                elif head == "sel":
                    a, b = rest.split()
                    sc, si = int(a) % len(cats), int(b)
                elif head == "vol":
                    v, m = rest.split()
                    vol, muted = int(v), m == "1"
                elif head == "bri":
                    bri = int(rest)
                elif head == "info":
                    info = json.loads(rest)
                elif head == "msg":
                    msg, msg_t = rest, time.monotonic()
                dirty_png = 3
        except queue.Empty:
            pass
        except (ValueError, json.JSONDecodeError):
            pass
        pygame.event.pump()

        now = time.monotonic()
        dt = min(0.1, now - last)
        last = now
        cam_x = ease(cam_x, sc, dt)
        cam_y = ease(cam_y, si, dt)
        appear = min(1.0, (now - t0) / 0.22)

        screen.blit(bg, (0, 0))

        # --- topo: jogo em andamento (esquerda) e relógio/bateria (direita), como no PS3
        x0 = int(64 * s)
        screen.blit(f_tag.render("EM JOGO" if title else "SKYSTATION", True, accent), (x0, int(36 * s)))
        screen.blit(f_game.render(fit(f_game, title or "Menu", int(560 * s)), True, WHITE), (x0, int(56 * s)))
        hora = info.get("hora", time.strftime("%H:%M"))
        cs = f_clock.render(hora, True, WHITE)
        screen.blit(cs, (W - x0 - cs.get_width(), int(34 * s)))
        rx = W - x0 - cs.get_width() - int(24 * s)
        if "bateria" in info:
            cap, chg = info["bateria"]
            t = f_sub.render(f"{cap}%" + (" ⚡" if chg else ""), True, MUTED)
            rx -= t.get_width()
            screen.blit(t, (rx, int(46 * s)))
            rx -= int(40 * s)
            battery_icon(screen, rx, int(48 * s), s, cap, chg, MUTED)
        for cap, chg in info.get("controles", []):
            rx -= int(80 * s)
            icon(screen, "pad", (rx + int(14 * s), int(55 * s)), 12 * s, MUTED, max(2, int(2 * s)))
            screen.blit(f_sub.render(f"{cap}%", True, MUTED), (rx + int(32 * s), int(46 * s)))
        if "temp" in info:
            t = info["temp"]
            ts = f_sub.render(f"{t} °C", True, WARN if t >= 85 else MUTED)
            rx -= ts.get_width() + int(24 * s)
            screen.blit(ts, (rx, int(46 * s)))

        # --- barra cruzada: categorias na horizontal; a selecionada fica fixa numa coluna
        col_x = int(W * 0.30)
        row_y = int(H * 0.30) + int(18 * s * (1 - appear))
        step = int(150 * s)
        for k, cat in enumerate(cats):
            cx = col_x + (k - cam_x) * step
            if cx < -step or cx > W + step:
                continue
            on = k == sc
            d = min(1.0, abs(k - cam_x))
            r = (34 - 10 * d) * s
            a = int(255 * (1 - 0.55 * d) * appear)
            col = accent if on else MUTED
            ic = pygame.Surface((int(r * 3), int(r * 3)), pygame.SRCALPHA)
            icon(ic, cat.get("icon", "pad"), (int(r * 1.5), int(r * 1.5)), r, (*col, 255))
            ic.set_alpha(a)
            screen.blit(ic, (cx - r * 1.5, row_y - r * 1.5))
            if on:
                lbl = f_cat.render(cat["title"], True, WHITE)
                lbl.set_alpha(int(255 * appear))
                screen.blit(lbl, (cx - lbl.get_width() / 2, row_y + 40 * s))

        # --- itens da categoria selecionada, na vertical (o selecionado logo abaixo do ícone)
        items = cats[sc].get("items", [])
        if items:
            si = max(0, min(si, len(items) - 1))
        base_y = row_y + int(96 * s)
        gap = int(54 * s)
        ix = col_x - int(26 * s)
        for i, it in enumerate(items):
            iy = base_y + (i - cam_y) * gap
            if iy < row_y + 60 * s or iy > H - 80 * s:
                continue
            on = i == si
            dist = abs(i - cam_y)
            alpha = int(255 * max(0.25, 1 - 0.18 * dist) * appear)
            kind = it.get("kind", "acao")
            text_x = ix + int(52 * s)
            # marcador à esquerda (troféu com a cor do nível, cadeado se ainda não ganhou)
            if kind == "trofeu":
                cor = NIVEIS.get(it.get("nivel", ""), MUTED) if it.get("ganho") else DIM
                mk = pygame.Surface((int(40 * s), int(40 * s)), pygame.SRCALPHA)
                icon(mk, "trophy" if it.get("ganho") else "lock", (int(20 * s), int(20 * s)), 15 * s, (*cor, 255))
                mk.set_alpha(alpha)
                screen.blit(mk, (ix, iy - int(4 * s)))
            elif on:
                pygame.draw.circle(screen, accent, (ix + int(22 * s), int(iy + 15 * s)), int(4 * s))
            if on:
                glow = pygame.Surface((int(560 * s), int(gap - 6 * s)), pygame.SRCALPHA)
                for gx in range(glow.get_width()):
                    glow.fill((*accent, int(46 * (1 - gx / glow.get_width()) ** 1.5)), (gx, 0, 1, glow.get_height()))
                screen.blit(glow, (ix - int(10 * s), iy - int(10 * s)))
            font = f_item_on if on else f_item
            cor_txt = WHITE if on else MUTED
            if kind in ("info",) or (kind == "trofeu" and not it.get("ganho")):
                cor_txt = MUTED if on else DIM
            ts = font.render(fit(font, it["t"], int(520 * s)), True, cor_txt)
            ts.set_alpha(alpha)
            screen.blit(ts, (text_x, iy))
            tw = ts.get_width()
            if it.get("novo"):
                nv = f_tag.render("NOVO", True, (10, 14, 30))
                bx = text_x + tw + int(12 * s)
                pygame.draw.rect(screen, accent, (bx, iy + int(4 * s), nv.get_width() + int(12 * s), int(22 * s)),
                                 border_radius=int(6 * s))
                screen.blit(nv, (bx + int(6 * s), iy + int(6 * s)))
            if on and it.get("sub"):
                ss = f_sub.render(fit(f_sub, it["sub"], int(520 * s)), True, MUTED)
                screen.blit(ss, (text_x, iy + int(30 * s)))
            if kind == "slider":
                val, txt = (vol, "mudo" if muted else f"{vol}%") if it.get("id") == "volume" else \
                           (bri, f"{bri}%" if bri >= 0 else "sem controle")
                bx, bw = text_x + max(tw, int(110 * s)) + int(20 * s), int(200 * s)
                by = iy + int(13 * s)
                pygame.draw.rect(screen, (60, 70, 100), (bx, by, bw, int(6 * s)), border_radius=int(3 * s))
                if val >= 0:
                    pygame.draw.rect(screen, DIM if (muted and it.get("id") == "volume") else accent,
                                     (bx, by, int(bw * val / 100), int(6 * s)), border_radius=int(3 * s))
                screen.blit(f_sub.render(txt, True, MUTED), (bx + bw + int(12 * s), iy + int(2 * s)))
                if on:
                    screen.blit(f_sub.render("◀ ▶", True, accent), (bx + bw // 2 - int(16 * s), iy - int(16 * s)))

        # --- rodapé com os botões, à direita como no PS3
        hint = "◀ ▶  categorias     A  confirmar     B / Home  voltar ao jogo"
        if items and items[min(si, len(items) - 1)].get("kind") == "slider":
            hint = "◀ ▶  ajustar     L1 R1  categorias     B / Home  voltar ao jogo"
        hs = f_sub.render(hint, True, DIM)
        screen.blit(hs, (W - x0 - hs.get_width(), H - int(46 * s)))

        if msg and now - msg_t < 2.5:
            surf = f_item.render(msg, True, WHITE)
            r = surf.get_rect(center=(W // 2, H - int(110 * s)))
            box = pygame.Surface((r.w + int(48 * s), r.h + int(22 * s)), pygame.SRCALPHA)
            box.fill((0, 0, 0, 160))
            screen.blit(box, (r.x - int(24 * s), r.y - int(11 * s)))
            screen.blit(surf, r)

        pygame.display.flip()
        if png_out and dirty_png:
            dirty_png -= 1
        clock.tick(30)


if __name__ == "__main__":
    main()
