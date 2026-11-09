#!/usr/bin/env python3
"""SkyStation: tela do menu Home (só desenha).

Quem lê os controles é o sky-home.py (que "segura" todos os dispositivos enquanto o menu
está aberto); ele manda para cá, pela entrada padrão:
    items [json]     -> textos dos itens
    sel <n>          -> item selecionado
    vol <0-100> <0|1>-> volume atual e mudo
    info {json}      -> bateria, controles, temperatura e hora
    msg <texto>      -> aviso rápido (ex.: "Estado salvo")
    quit             -> fechar
Uso: sky-overlay.py <título do jogo> [foto da tela congelada]
"""
import json
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
    """Foto do jogo congelado, desfocada e escurecida (ou um degradê, se não houver foto)."""
    W, H = size
    surf = pygame.Surface(size)
    try:
        if path and os.path.exists(path):
            img = pygame.image.load(path).convert()
            small = pygame.transform.smoothscale(img, (max(1, W // 12), max(1, H // 12)))
            surf = pygame.transform.smoothscale(small, size)       # "desfoque" barato
            shade = pygame.Surface(size, pygame.SRCALPHA)
            shade.fill((4, 8, 23, 170))
            surf.blit(shade, (0, 0))
            return surf
    except pygame.error:
        pass
    for y in range(H):
        k = y / max(1, H - 1)
        surf.fill((int(4 + 9 * k), int(8 + 18 * k), int(23 + 51 * k)), (0, y, W, 1))
    return surf


def battery_icon(screen, x, y, s, cap, charging, color):
    w, h = int(30 * s), int(15 * s)
    pygame.draw.rect(screen, color, (x, y, w, h), width=max(1, int(2 * s)), border_radius=int(3 * s))
    pygame.draw.rect(screen, color, (x + w, y + h // 4, int(3 * s), h // 2))
    fill = WARN if cap <= 15 and not charging else color
    inner = int((w - 6 * s) * max(0, min(100, cap)) / 100)
    pygame.draw.rect(screen, fill, (x + int(3 * s), y + int(3 * s), inner, h - int(6 * s)))


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else "Jogo"
    shot = sys.argv[2] if len(sys.argv) > 2 else ""
    q = queue.Queue()
    threading.Thread(target=reader, args=(q,), daemon=True).start()

    # Só vídeo e fontes: nada de áudio ou joystick (os controles estão com o sky-home).
    pygame.display.init()
    pygame.font.init()
    screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    pygame.display.set_caption("SkyStation - pausa")
    pygame.mouse.set_visible(False)
    W, H = screen.get_size()
    s = H / 720
    names = "notosans,dejavusans,liberationsans,opensans"
    f_tag = pygame.font.SysFont(names, int(17 * s), bold=True)
    f_title = pygame.font.SysFont(names, int(34 * s), bold=True)
    f_item = pygame.font.SysFont(names, int(24 * s))
    f_item_on = pygame.font.SysFont(names, int(26 * s), bold=True)
    f_small = pygame.font.SysFont(names, int(16 * s))
    accent = accent_from_theme()
    bg = background(shot, (W, H))
    clock = pygame.time.Clock()

    items = ["Voltar ao jogo", "Fechar jogo"]
    sel, vol, muted, info = 0, -1, False, {}
    msg, msg_t = "", 0.0
    t0 = time.monotonic()

    while True:
        try:
            while True:
                cmd = q.get_nowait()
                if cmd == "quit":
                    pygame.quit()
                    return
                head, _, rest = cmd.partition(" ")
                if head == "items":
                    items = json.loads(rest) or items
                elif head == "sel":
                    sel = int(rest) % len(items)
                elif head == "vol":
                    v, m = rest.split()
                    vol, muted = int(v), m == "1"
                elif head == "info":
                    info = json.loads(rest)
                elif head == "msg":
                    msg, msg_t = rest, time.monotonic()
        except queue.Empty:
            pass
        except (ValueError, json.JSONDecodeError):
            pass
        pygame.event.pump()

        appear = min(1.0, (time.monotonic() - t0) / 0.18)
        screen.blit(bg, (0, 0))
        # painel lateral esquerdo
        pw = int(460 * s)
        panel = pygame.Surface((pw, H), pygame.SRCALPHA)
        for x in range(pw):
            a = int(205 * (1 - (x / pw) ** 3))
            panel.fill((3, 6, 18, a), (x, 0, 1, H))
        screen.blit(panel, (int(-40 * s * (1 - appear)), 0))
        x0 = int(56 * s)
        screen.blit(f_tag.render("PAUSADO", True, accent), (x0, int(70 * s)))
        name = title if len(title) <= 26 else title[:25] + "…"
        screen.blit(f_title.render(name, True, WHITE), (x0, int(94 * s)))

        y = int(180 * s)
        for i, item in enumerate(items):
            on = i == sel
            if on:
                bar = pygame.Surface((pw - int(70 * s), int(48 * s)), pygame.SRCALPHA)
                bar.fill((*accent, 40))
                screen.blit(bar, (x0 - int(18 * s), y - int(9 * s)))
                pygame.draw.rect(screen, accent, (x0 - int(18 * s), y - int(9 * s), int(4 * s), int(48 * s)))
            font = f_item_on if on else f_item
            screen.blit(font.render(item, True, WHITE if on else MUTED), (x0, y))
            if item == "Volume":
                bx, bw = x0 + int(118 * s), int(200 * s)
                by = y + int(13 * s)
                pygame.draw.rect(screen, (60, 70, 100), (bx, by, bw, int(6 * s)), border_radius=int(3 * s))
                if vol >= 0:
                    pygame.draw.rect(screen, DIM if muted else accent, (bx, by, int(bw * vol / 100), int(6 * s)),
                                     border_radius=int(3 * s))
                    screen.blit(f_small.render("mudo" if muted else f"{vol}%", True, MUTED),
                                (bx + bw + int(12 * s), y + int(2 * s)))
                if on:
                    screen.blit(f_small.render("◀ ▶", True, accent), (bx + bw // 2 - int(16 * s), y - int(16 * s)))
            y += int(56 * s)

        # rodapé: bateria, controles, temperatura, hora
        fy = H - int(70 * s)
        fx = x0
        if "bateria" in info:
            cap, chg = info["bateria"]
            battery_icon(screen, fx, fy + int(3 * s), s, cap, chg, WHITE)
            txt = f"{cap}%" + (" ⚡" if chg else "")
            screen.blit(f_small.render(txt, True, WHITE), (fx + int(40 * s), fy))
            fx += int(110 * s)
        for cap, chg in info.get("controles", []):
            screen.blit(f_small.render("Controle", True, MUTED), (fx, fy))
            fx += int(70 * s)
            battery_icon(screen, fx, fy + int(3 * s), s, cap, chg, MUTED)
            screen.blit(f_small.render(f"{cap}%", True, MUTED), (fx + int(40 * s), fy))
            fx += int(90 * s)
        if "temp" in info:
            t = info["temp"]
            screen.blit(f_small.render(f"{t} °C", True, WARN if t >= 85 else MUTED), (fx, fy))
            fx += int(80 * s)
        screen.blit(f_small.render(info.get("hora", time.strftime("%H:%M")), True, MUTED), (fx, fy))
        hint = f_small.render("A  confirmar     B / Home  voltar ao jogo", True, DIM)
        screen.blit(hint, (x0, fy + int(30 * s)))

        if msg and time.monotonic() - msg_t < 2.5:
            surf = f_item.render(msg, True, WHITE)
            r = surf.get_rect(center=(W // 2 + pw // 4, H - int(120 * s)))
            box = pygame.Surface((r.w + int(40 * s), r.h + int(20 * s)), pygame.SRCALPHA)
            box.fill((0, 0, 0, 150))
            screen.blit(box, (r.x - int(20 * s), r.y - int(10 * s)))
            screen.blit(surf, r)

        pygame.display.flip()
        clock.tick(30)


if __name__ == "__main__":
    main()
