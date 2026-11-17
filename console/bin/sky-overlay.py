#!/usr/bin/env python3
"""SkyStation: tela do menu Home dentro do jogo (só desenha). Fase 8.1: visual no padrão do launcher.

Como no PS3, apertar Home no meio do jogo abre a barra cruzada por cima da imagem congelada:
categorias na horizontal (Jogo, Troféus, Notificações, Amigos, Ajustes, Energia) e itens na
vertical. Tudo é desenhado com antialiasing: ícones, cantos e brilhos são feitos em tamanho
4x e reduzidos (supersampling) e ficam guardados em cache, então o custo por quadro é baixo.

Quem lê os controles é o sky-home.py (que "segura" todos os dispositivos enquanto o menu
está aberto); ele manda para cá, pela entrada padrão, uma linha por comando:
    cats [json]      -> categorias: [{"id","title","icon","items":[{"t","sub"?,"kind"?,"acao"?,...}]}]
                        kind: "acao" (padrão) | "slider" | "trofeu" | "info" | "notif"
    sel <c> <i>      -> categoria e item selecionados
    vol <0-100> <0|1>-> volume atual e mudo
    bri <0-100|-1>   -> brilho atual (-1 = sem controle de brilho)
    info {json}      -> bateria, controles, temperatura e hora
    msg <texto>      -> aviso rápido (ex.: "Estado salvo")
    kb {json}        -> teclado virtual aberto (estado do skyteclado.Teclado.estado()); "kb" sozinho fecha
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

WHITE = (242, 246, 255)
MUTED = (169, 182, 216)
DIM = (109, 123, 163)
WARN = (255, 170, 90)
NIVEIS = {"bronze": (214, 140, 80), "prata": (205, 214, 230), "ouro": (255, 205, 70), "platina": (170, 220, 255)}
THEMES = {  # cores dos temas do launcher: (destaque, fundo escuro, fundo claro)
    "noite": ((79, 209, 255), (4, 8, 23), (13, 26, 74)),
    "oceano": ((95, 220, 255), (2, 18, 32), (6, 60, 92)),
    "aurora": ((84, 240, 184), (3, 16, 22), (10, 58, 60)),
    "crepusculo": ((255, 122, 208), (18, 6, 28), (70, 22, 80)),
    "brasa": ((255, 154, 82), (22, 8, 6), (84, 30, 14)),
    "grafite": ((207, 216, 234), (10, 11, 15), (38, 42, 54)),
}
SS = 4   # supersampling dos ícones e formas
ACOES_ICONE = {"resume": "play", "save": "save", "load": "load", "shot": "camera", "close": "x",
               "suspend": "moon", "reboot": "refresh", "poweroff": "power", "limpar": "trash",
               "volume": "speaker", "brilho": "sun", "amigo": "friends", "voltar_amigos": "friends",
               "escrever": "bell", "rapida": "bell", "convidar": "pad"}


def reader(q):
    for line in sys.stdin:
        q.put(line.rstrip("\n"))
    q.put("quit")


def theme():
    try:
        with open(os.path.expanduser("~/.config/skystation/tema")) as f:
            key = f.read().strip()
    except OSError:
        key = "auto"
    if key not in THEMES:
        h = time.localtime().tm_hour
        key = "oceano" if 6 <= h < 11 else "aurora" if 11 <= h < 17 else "crepusculo" if 17 <= h < 20 else "noite"
    return THEMES[key]


def mix(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


def blur(surf, k=8):
    """Desfoque barato: reduz e amplia duas vezes (smoothscale é bilinear)."""
    w, h = surf.get_size()
    for f in (k, max(1, k // 2)):
        small = pygame.transform.smoothscale(surf, (max(1, w // f), max(1, h // f)))
        surf = pygame.transform.smoothscale(small, (w, h))
    return surf


# ------------------------------------------------------------------ formas com antialiasing (cache)
_cache = {}


def rrect(w, h, r, color, alpha=255, border=None, bw=0):
    """Retângulo arredondado suave (desenhado em 4x e reduzido)."""
    key = ("rr", w, h, r, color, alpha, border, bw)
    if key not in _cache:
        big = pygame.Surface((max(1, w * SS), max(1, h * SS)), pygame.SRCALPHA)
        pygame.draw.rect(big, (*color, alpha), (0, 0, w * SS, h * SS), border_radius=r * SS)
        if border and bw:
            pygame.draw.rect(big, border, (0, 0, w * SS, h * SS), width=bw * SS, border_radius=r * SS)
        _cache[key] = pygame.transform.smoothscale(big, (max(1, w), max(1, h)))
    return _cache[key]


def glow(w, h, color, alpha):
    """Mancha de luz suave (fundo do item e da categoria selecionados)."""
    key = ("gl", w, h, color, alpha)
    if key not in _cache:
        pad = h
        s = pygame.Surface((w + pad * 2, h + pad * 2), pygame.SRCALPHA)
        pygame.draw.rect(s, (*color, alpha), (pad, pad, w, h), border_radius=h // 2)
        _cache[key] = blur(s, 8)
    return _cache[key]


def icon(kind, size, color):
    """Ícones no mesmo desenho do launcher (preenchidos), com antialiasing."""
    key = ("ic", kind, size, color)
    if key in _cache:
        return _cache[key]
    S = size * SS
    sf = pygame.Surface((S, S), pygame.SRCALPHA)
    c = (S / 2, S / 2)
    col = (*color, 255)
    hole = (0, 0, 0, 0)
    lw = max(2, int(S * 0.08))

    def P(x, y):
        return (c[0] + x * S, c[1] + y * S)

    def circ(x, y, r, colr=col, w=0):
        pygame.draw.circle(sf, colr, P(x, y), r * S, w)

    def rect(x, y, w, h, colr=col, r=0, width=0):
        pygame.draw.rect(sf, colr, pygame.Rect(P(x, y), (w * S, h * S)), width, border_radius=int(r * S))

    def line(a, b, w=lw, colr=col):
        pygame.draw.line(sf, colr, P(*a), P(*b), w)
        pygame.draw.circle(sf, colr, P(*a), w / 2)
        pygame.draw.circle(sf, colr, P(*b), w / 2)

    def arc(x, y, r, a0, a1, w=lw):
        n = 40
        pts = [P(x + math.cos(a0 + (a1 - a0) * i / n) * r, y - math.sin(a0 + (a1 - a0) * i / n) * r)
               for i in range(n + 1)]
        pygame.draw.lines(sf, col, False, pts, w)
        for p in (pts[0], pts[-1]):
            pygame.draw.circle(sf, col, p, w / 2)

    if kind == "pad":
        rect(-0.44, -0.20, 0.88, 0.40, r=0.18)
        circ(-0.28, 0.14, 0.17)
        circ(0.28, 0.14, 0.17)
        rect(-0.33, -0.03, 0.16, 0.05, hole)
        rect(-0.275, -0.085, 0.05, 0.16, hole)
        for ox, oy in ((0.25, -0.06), (0.33, 0.01), (0.17, 0.01), (0.25, 0.08)):
            circ(ox, oy, 0.035, hole)
    elif kind == "trophy":
        pygame.draw.polygon(sf, col, [P(-0.26, -0.36), P(0.26, -0.36), P(0.18, 0.04), P(-0.18, 0.04)])
        arc(-0.26, -0.2, 0.12, math.pi * 0.5, math.pi * 1.5)
        arc(0.26, -0.2, 0.12, -math.pi * 0.5, math.pi * 0.5)
        rect(-0.045, 0.04, 0.09, 0.2)
        rect(-0.2, 0.23, 0.4, 0.1, r=0.03)
    elif kind == "gear":
        for i in range(8):
            a = i * math.tau / 8
            line((math.cos(a) * 0.3, math.sin(a) * 0.3), (math.cos(a) * 0.44, math.sin(a) * 0.44), int(S * 0.14))
        circ(0, 0, 0.33)
        circ(0, 0, 0.14, hole)
    elif kind == "power":
        arc(0, 0.02, 0.33, math.pi / 2 + 0.62, math.pi / 2 - 0.62 + math.tau, int(lw * 1.25))
        line((0, -0.42), (0, -0.04), int(lw * 1.25))
    elif kind == "bell":
        pygame.draw.polygon(sf, col, [P(-0.30, 0.20), P(-0.22, 0.05), P(-0.22, -0.12), P(-0.12, -0.28),
                                      P(0.12, -0.28), P(0.22, -0.12), P(0.22, 0.05), P(0.30, 0.20)])
        circ(0, -0.17, 0.2)
        rect(-0.34, 0.16, 0.68, 0.08, r=0.04)
        circ(0, 0.31, 0.07)
        circ(0, -0.39, 0.045)
    elif kind == "friends":
        circ(-0.14, -0.16, 0.15)
        pygame.draw.ellipse(sf, col, pygame.Rect(P(-0.38, 0.04), (0.48 * S, 0.42 * S)))
        rect(-0.38, 0.25, 0.48, 0.2, hole)
        circ(0.2, -0.1, 0.12)
        pygame.draw.ellipse(sf, col, pygame.Rect(P(0.02, 0.08), (0.38 * S, 0.34 * S)))
        rect(0.02, 0.26, 0.38, 0.2, hole)
    elif kind == "lock":
        rect(-0.24, -0.04, 0.48, 0.38, r=0.06)
        arc(0, -0.04, 0.15, 0, math.pi)
        circ(0, 0.13, 0.05, hole)
    elif kind == "info":
        pygame.draw.circle(sf, col, P(0, 0), 0.4 * S, lw)
        circ(0, -0.18, 0.055)
        line((0, -0.04), (0, 0.22), int(lw * 1.2))
    elif kind == "disc":
        pygame.draw.circle(sf, col, P(0, 0), 0.42 * S, lw)
        circ(0, 0, 0.1, col, lw)
    elif kind == "drive":
        rect(-0.42, -0.2, 0.84, 0.4, r=0.08, width=lw)
        circ(0.26, 0, 0.05)
        line((-0.28, 0), (0.06, 0))
    elif kind == "battery":
        rect(-0.38, -0.18, 0.68, 0.36, r=0.07, width=lw)
        rect(0.3, -0.08, 0.08, 0.16)
        rect(-0.3, -0.1, 0.38, 0.2)
    elif kind == "download":
        line((0, -0.36), (0, 0.1), int(lw * 1.2))
        pygame.draw.polygon(sf, col, [P(-0.18, 0.0), P(0.18, 0.0), P(0, 0.22)])
        line((-0.34, 0.34), (0.34, 0.34), int(lw * 1.2))
    elif kind == "monitor":
        rect(-0.42, -0.32, 0.84, 0.52, r=0.05, width=lw)
        line((0, 0.2), (0, 0.34))
        line((-0.18, 0.36), (0.18, 0.36))
    elif kind == "usb":
        line((0, 0.38), (0, -0.26))
        pygame.draw.polygon(sf, col, [P(0, -0.42), P(-0.1, -0.24), P(0.1, -0.24)])
        line((0, 0.12), (-0.2, -0.02))
        circ(-0.2, -0.06, 0.06)
        line((0, 0.2), (0.2, 0.06))
        rect(0.15, -0.02, 0.1, 0.1)
    elif kind == "thermo":
        rect(-0.08, -0.38, 0.16, 0.5, r=0.08, width=lw)
        circ(0, 0.22, 0.14)
    elif kind == "speaker":
        pygame.draw.polygon(sf, col, [P(-0.36, -0.12), P(-0.18, -0.12), P(0.02, -0.32), P(0.02, 0.32),
                                      P(-0.18, 0.12), P(-0.36, 0.12)])
        arc(0.06, 0, 0.18, -0.9, 0.9)
        arc(0.06, 0, 0.32, -0.9, 0.9)
    elif kind == "sun":
        circ(0, 0, 0.17)
        for i in range(8):
            a = i * math.tau / 8
            line((math.cos(a) * 0.28, math.sin(a) * 0.28), (math.cos(a) * 0.4, math.sin(a) * 0.4))
    elif kind == "play":
        pygame.draw.polygon(sf, col, [P(-0.16, -0.3), P(0.3, 0), P(-0.16, 0.3)])
    elif kind == "x":
        line((-0.22, -0.22), (0.22, 0.22), int(lw * 1.2))
        line((0.22, -0.22), (-0.22, 0.22), int(lw * 1.2))
    elif kind == "save":
        rect(-0.32, -0.34, 0.64, 0.68, r=0.06, width=lw)
        rect(-0.16, -0.34, 0.32, 0.2)
        rect(-0.2, 0.08, 0.4, 0.2, r=0.03, width=lw)
    elif kind == "load":
        arc(0, 0, 0.32, math.pi * 0.35, math.pi * 1.9, int(lw * 1.1))
        tip = P(math.cos(math.pi * 0.35) * 0.32, -math.sin(math.pi * 0.35) * 0.32)
        pygame.draw.polygon(sf, col, [(tip[0] - S * 0.14, tip[1] - S * 0.06), (tip[0] + S * 0.06, tip[1] - S * 0.14),
                                      (tip[0] + S * 0.04, tip[1] + S * 0.08)])
    elif kind == "camera":
        rect(-0.42, -0.2, 0.84, 0.5, r=0.1, width=lw)
        rect(-0.16, -0.3, 0.32, 0.1)
        pygame.draw.circle(sf, col, P(0, 0.05), 0.14 * S, lw)
    elif kind == "moon":
        circ(0, 0, 0.33)
        circ(0.15, -0.12, 0.29, hole)
    elif kind == "refresh":
        arc(0, 0, 0.32, math.pi * 0.65, math.pi * 2.45, int(lw * 1.1))
    elif kind == "trash":
        rect(-0.24, -0.18, 0.48, 0.5, r=0.05, width=lw)
        line((-0.32, -0.24), (0.32, -0.24))
        rect(-0.1, -0.34, 0.2, 0.08, r=0.03)
        line((-0.08, -0.06), (-0.08, 0.2))
        line((0.08, -0.06), (0.08, 0.2))
    else:
        pygame.draw.circle(sf, col, P(0, 0), 0.3 * S, lw)
    out = pygame.transform.smoothscale(sf, (size, size))
    _cache[key] = out
    return out


def make_background(path, size, base_dark, base_light, accent):
    """Jogo congelado desfocado + véu escuro + a "onda" do XMB, desenhados uma vez só."""
    W, H = size
    surf = pygame.Surface(size)
    ok = False
    try:
        if path and os.path.exists(path):
            img = pygame.image.load(path).convert()
            surf = blur(pygame.transform.smoothscale(img, size), 10)
            ok = True
    except pygame.error:
        pass
    veil = pygame.Surface(size, pygame.SRCALPHA)
    for y in range(H):
        k = y / max(1, H - 1)
        veil.fill((*mix(base_dark, base_light, 0.30 + 0.5 * k), 205 if ok else 255), (0, y, W, 1))
    surf.blit(veil, (0, 0))
    # onda: várias curvas finas desenhadas em 2x e reduzidas (antialiasing), com um brilho em volta
    ow, oh = W * 2, H * 2
    wave = pygame.Surface((ow, oh), pygame.SRCALPHA)
    for i in range(9):
        pts = []
        amp = oh * (0.045 + 0.011 * i)
        ph = i * 0.38
        for x in range(0, ow + 16, 16):
            u = x / ow
            y = oh * 0.80 + math.sin(u * 5.2 + ph) * amp + math.sin(u * 11.0 + ph * 2.1) * amp * 0.25 - i * oh * 0.008
            pts.append((x, y))
        forte = i in (3, 4)
        pygame.draw.lines(wave, (*mix(accent, WHITE, 0.3), 70 if forte else 28), False, pts, 3 if forte else 2)
    wave = pygame.transform.smoothscale(wave, size)
    surf.blit(blur(wave.copy(), 6), (0, 0))
    surf.blit(wave, (0, 0))
    return surf


_txt = {}


def render(font, text, color):
    """8.1.3: texto renderizado uma vez e reaproveitado (render de fonte é o que mais pesava por quadro)."""
    key = (id(font), text, color)
    sf = _txt.get(key)
    if sf is None:
        if len(_txt) > 600:
            _txt.clear()
        sf = _txt[key] = font.render(text, True, color)
    return sf


def fit(font, text, max_w):
    if font.size(text)[0] <= max_w:
        return text
    while text and font.size(text + "…")[0] > max_w:
        text = text[:-1]
    return text + "…"


def ease(cur, target, dt, speed=13.0):
    return target + (cur - target) * math.exp(-speed * dt)


def shadow_text(screen, font, txt, color, pos, alpha=255):
    sh = render(font, txt, (0, 0, 0))
    sh.set_alpha(int(alpha * 0.45))
    screen.blit(sh, (pos[0], pos[1] + 2))
    sf = render(font, txt, color)
    sf.set_alpha(alpha)
    screen.blit(sf, pos)
    return sf.get_width()


_AVATARES = {}


def avatar_img(id_, tamanho):
    """Ícone de perfil da SkyNetwork (PNG em ../avatares), já no tamanho; None se não existe."""
    chave = (id_, tamanho)
    if chave not in _AVATARES:
        img = None
        if id_.isidentifier():
            p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "avatares", id_ + ".png")
            try:
                img = pygame.transform.smoothscale(pygame.image.load(p).convert_alpha(), (tamanho, tamanho))
            except (pygame.error, FileNotFoundError, OSError):
                img = None
        _AVATARES[chave] = img
    return _AVATARES[chave]


def quebrar(font, texto, largura):
    """Quebra o texto em linhas que cabem na largura (por palavra; palavra enorme é cortada)."""
    linhas, atual = [], ""
    for palavra in str(texto).split():
        while font.size(palavra)[0] > largura and len(palavra) > 1:
            corte = len(palavra)
            while corte > 1 and font.size(palavra[:corte])[0] > largura:
                corte -= 1
            if atual:
                linhas.append(atual)
                atual = ""
            linhas.append(palavra[:corte])
            palavra = palavra[corte:]
        tentativa = (atual + " " + palavra).strip()
        if font.size(tentativa)[0] <= largura:
            atual = tentativa
        else:
            linhas.append(atual)
            atual = palavra
    if atual:
        linhas.append(atual)
    return linhas or [""]


def desenhar_conversa(screen, msgs, x0, y0, x1, y1, s, accent, F):
    """Fase 10: a conversa com um amigo, em balões, de baixo para cima (a mais nova embaixo)."""
    f_msg, f_q = F(18), F(12)
    largura = x1 - x0
    screen.blit(rrect(largura, y1 - y0, int(20 * s), (0, 0, 0), 90, (*accent, 50), 1), (x0, y0))
    pad = int(16 * s)
    max_b = int(largura * 0.8)
    y = y1 - pad
    for m in reversed(msgs):
        linhas = quebrar(f_msg, m.get("texto", ""), max_b - 2 * pad)[:6]
        lh = f_msg.get_linesize()
        bw = min(max_b, max(f_msg.size(l)[0] for l in linhas) + 2 * pad)
        bh = len(linhas) * lh + int(16 * s)
        quando = m.get("quando", "")
        qh = f_q.get_linesize() if quando else 0
        if y - bh - qh - int(10 * s) < y0 + pad:
            break
        y -= qh
        if m.get("sistema"):
            bx, cor_f, cor_t, alfa = x0 + (largura - bw) // 2, (255, 255, 255), MUTED, 0
        elif m.get("minha"):
            bx, cor_f, cor_t, alfa = x1 - pad - bw, accent, WHITE, 70
        else:
            bx, cor_f, cor_t, alfa = x0 + pad, (255, 255, 255), WHITE, 34
        if quando:
            q = render(f_q, quando, DIM)
            screen.blit(q, (bx + (bw - q.get_width() if m.get("minha") else 0), y))
        y -= bh
        if alfa:
            screen.blit(rrect(bw, bh, int(14 * s), cor_f, alfa), (bx, y))
        for i, l in enumerate(linhas):
            screen.blit(render(f_msg, l, cor_t), (bx + pad, y + int(8 * s) + i * lh))
        y -= int(10 * s)


def desenhar_teclado(screen, kb, W, H, s, accent, dark, F):
    """Teclado virtual (Fase 10): painel na parte de baixo, com o texto em cima e as teclas embaixo."""
    linhas = kb.get("linhas", [])
    if not linhas:
        return
    f_tit, f_txt, f_key, f_cnt = F(16), F(26), F(22, True), F(13)
    cols = max(len(r) for r in linhas)
    kw, kh, gap = int(74 * s), int(54 * s), int(8 * s)
    grid_w = cols * kw + (cols - 1) * gap
    pad = int(26 * s)
    campo_h = int(70 * s)
    painel_w = grid_w + 2 * pad
    painel_h = pad + int(22 * s) + campo_h + int(16 * s) + len(linhas) * (kh + gap) - gap + pad
    px = (W - painel_w) // 2
    py = H - painel_h - int(70 * s)
    # escurece o menu atrás: o teclado é o foco
    sombra = pygame.Surface((W, H), pygame.SRCALPHA)
    sombra.fill((0, 0, 0, 120))
    screen.blit(sombra, (0, 0))
    screen.blit(rrect(painel_w, painel_h, int(22 * s), mix(dark, (0, 0, 0), 0.25), 235, (*accent, 120), 1), (px, py))
    y = py + pad
    screen.blit(render(f_tit, fit(f_tit, kb.get("titulo", ""), painel_w - 2 * pad), MUTED), (px + pad, y))
    cnt = render(f_cnt, f"{len(kb.get('texto', ''))}/{kb.get('limite', 280)}", DIM)
    screen.blit(cnt, (px + painel_w - pad - cnt.get_width(), y + int(3 * s)))
    y += int(22 * s)
    screen.blit(rrect(grid_w, campo_h, int(14 * s), (255, 255, 255), 22, (*accent, 90), 1), (px + pad, y))
    texto = kb.get("texto", "")
    # mostra o fim do texto (onde está o cursor) quando ele não cabe
    vis = texto
    while vis and f_txt.size(vis + "|")[0] > grid_w - int(36 * s):
        vis = vis[1:]
    piscando = int(time.monotonic() * 2) % 2 == 0
    ts = render(f_txt, (("…" if vis != texto else "") + vis) + ("|" if piscando else " "), WHITE)
    if not texto:
        ts = render(f_txt, "Escreva com o controle…" if not piscando else "|", DIM)
    screen.blit(ts, (px + pad + int(18 * s), y + (campo_h - ts.get_height()) // 2))
    y += campo_h + int(16 * s)
    r_sel, c_sel = kb.get("r", 0), kb.get("c", 0)
    for r, row in enumerate(linhas):
        n = len(row)
        # linhas com menos teclas (a última) usam teclas mais largas, ocupando a mesma largura
        w_k = (grid_w - (n - 1) * gap) / n
        for c, k in enumerate(row):
            x = px + pad + int(c * (w_k + gap))
            on = r == r_sel and c == c_sel
            especial = r == len(linhas) - 1
            ativo = (k == "⇧" and kb.get("shift")) or (k == "ABC" and kb.get("simbolos"))
            if on:
                gl = glow(int(w_k), kh, accent, 70)
                screen.blit(gl, (x - kh, y - kh))
                fundo = rrect(int(w_k), kh, int(12 * s), accent, 255)
                cor = dark
            else:
                fundo = rrect(int(w_k), kh, int(12 * s), (255, 255, 255), 46 if ativo else (20 if especial else 30))
                cor = accent if ativo else (MUTED if especial else WHITE)
            screen.blit(fundo, (x, y))
            if k == "Enviar" and not on:
                screen.blit(rrect(int(w_k), kh, int(12 * s), accent, 70), (x, y))
                cor = WHITE
            ks = render(f_key, k, cor)
            screen.blit(ks, (x + (int(w_k) - ks.get_width()) // 2, y + (kh - ks.get_height()) // 2))
        y += kh + gap


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
        display = pygame.display.set_mode((1280, 720))
    else:
        display = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    pygame.display.set_caption("SkyStation - Home")
    pygame.mouse.set_visible(False)
    # Fase 9.3: no gamescope o menu precisa ser "overlay" para aparecer por cima do jogo congelado
    if os.environ.get("SKY_COMPOSITOR") == "gamescope":
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import skygamescope
            ok = skygamescope.marcar_overlay(pygame.display.get_wm_info().get("window"))
            print("sky-overlay: overlay do gamescope " + ("marcado" if ok else "NÃO marcado"), file=sys.stderr, flush=True)
        except Exception as e:
            print(f"sky-overlay: não consegui marcar o overlay: {e!r}", file=sys.stderr, flush=True)
    W, H = display.get_size()
    # 8.1.1: no Wayland (cage) a tela do SDL tem canal alfa e o compositor RESPEITA esse alfa. Desenhando
    # direto nela, o texto e os brilhos viravam caixas (o alfa da tela caía para 0 em volta deles). Agora
    # tudo é desenhado numa tela de trabalho SEM alfa (24 bits) e copiado inteiro no fim de cada quadro.
    screen = pygame.Surface((W, H), 0, 24)
    tela_com_alfa = bool(display.get_masks()[3]) or bool(display.get_flags() & pygame.SRCALPHA)
    s = H / 720
    names = "opensans,notosans,dejavusans,liberationsans"

    def F(px, b=False):
        return pygame.font.SysFont(names, max(10, int(px * s)), bold=b)

    f_tag, f_game, f_cat = F(13, True), F(21, True), F(20)
    f_item, f_item_on, f_sub, f_small = F(22), F(23, True), F(15), F(14)
    f_clock, f_date = F(30, True), F(15)
    accent, dark, light = theme()
    bg = make_background(shot, (W, H), dark, light, accent)
    clock = pygame.time.Clock()

    cats = [{"id": "jogo", "title": "Jogo", "icon": "pad", "items": [{"t": "Voltar ao jogo", "acao": "resume"}]}]
    sc, si = 0, 0
    vol, muted, bri, info = -1, False, -1, {}
    msg, msg_t = "", 0.0
    kb = None       # Fase 10: teclado virtual (dicionário do skyteclado) ou None
    t0 = last = time.monotonic()
    cam_x, cam_y = 0.0, 0.0
    sujo, minuto = True, ""
    dias = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
    meses = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

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
                elif head == "kb":
                    kb = json.loads(rest) if rest.strip() else None
                sujo = True
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
        appear = min(1.0, (now - t0) / 0.25)
        ap = 1 - (1 - appear) ** 3
        # 8.1.3: só redesenha quando algo muda (animação, comando, aviso, minuto). Parado, não gasta nada.
        if time.strftime("%H:%M") != minuto:
            minuto, sujo = time.strftime("%H:%M"), True
        animando = abs(cam_x - sc) > 0.003 or abs(cam_y - si) > 0.003 or appear < 1.0 \
            or (msg and now - msg_t < 2.8) or kb is not None
        if not (sujo or animando):
            clock.tick(30)
            continue
        if not animando:
            cam_x, cam_y = float(sc), float(si)
        sujo = False

        screen.blit(bg, (0, 0))
        mx = int(64 * s)

        # ---- topo esquerdo: o jogo em andamento
        tg = render(f_tag, "EM JOGO" if title else "SKYSTATION", accent)
        screen.blit(rrect(tg.get_width() + int(20 * s), int(24 * s), int(12 * s), accent, 40), (mx, int(40 * s)))
        screen.blit(tg, (mx + int(10 * s), int(40 * s) + (int(24 * s) - tg.get_height()) // 2))
        shadow_text(screen, f_game, fit(f_game, title or "Menu do sistema", int(600 * s)), WHITE, (mx, int(70 * s)))

        # ---- topo direito: hora, data, bateria, controles, temperatura (como no launcher)
        lt = time.localtime()
        hora = info.get("hora", time.strftime("%H:%M"))
        cs = render(f_clock, hora, WHITE)
        cx = W - mx - cs.get_width()
        shadow_text(screen, f_clock, hora, WHITE, (cx, int(34 * s)))
        ds = render(f_date, f"{dias[lt.tm_wday]}, {lt.tm_mday} de {meses[lt.tm_mon - 1]}", MUTED)
        screen.blit(ds, (W - mx - ds.get_width(), int(76 * s)))
        rx = cx - int(28 * s)
        cy = int(54 * s)

        def chip(txt, ic_kind, cor):
            nonlocal rx
            t_ = render(f_sub, txt, cor)
            rx -= t_.get_width()
            screen.blit(t_, (rx, cy - t_.get_height() // 2))
            if ic_kind:
                ic_ = icon(ic_kind, int(28 * s), cor)
                rx -= ic_.get_width() + int(2 * s)
                screen.blit(ic_, (rx, cy - ic_.get_height() // 2))
            rx -= int(20 * s)

        if "bateria" in info:
            cap, chg = info["bateria"]
            chip(f"{cap}%" + (" ⚡" if chg else ""), "battery", WARN if cap <= 15 and not chg else MUTED)
        for cap, chg in info.get("controles", []):
            chip(f"{cap}%" + (" ⚡" if chg else ""), "pad", WARN if cap <= 15 and not chg else MUTED)
        if "temp" in info:
            chip(f"{info['temp']}°C", "thermo", WARN if info["temp"] >= 85 else MUTED)

        # ---- barra cruzada: a categoria selecionada fica fixa numa coluna, como no XMB
        col_x = int(W * 0.27)
        row_y = int(H * 0.33) + int(14 * s * (1 - ap))
        step = int(132 * s)
        for k, cat in enumerate(cats):
            cxk = col_x + (k - cam_x) * step
            if cxk < -step or cxk > W + step:
                continue
            d = min(1.0, abs(k - cam_x))
            on = k == sc
            size = int((72 - 26 * d) * s)
            if on:
                gl = glow(int(64 * s), int(64 * s), accent, 80)
                gl.set_alpha(int(255 * ap))
                screen.blit(gl, (cxk - gl.get_width() / 2, row_y - gl.get_height() / 2))
            ic = icon(cat.get("icon", "pad"), size, WHITE if on else MUTED).copy()
            ic.set_alpha(int(255 * (1 - 0.5 * d) * ap))
            screen.blit(ic, (cxk - size / 2, row_y - size / 2))
            if on:
                lbl = render(f_cat, cat["title"], WHITE)
                lbl.set_alpha(int(255 * ap))
                screen.blit(lbl, (cxk - lbl.get_width() / 2, row_y + int(46 * s)))

        # ---- itens da categoria na vertical (cartão de vidro no selecionado)
        items = cats[sc].get("items", [])
        si = max(0, min(si, len(items) - 1)) if items else 0
        base_y = row_y + int(112 * s)
        gap = int(62 * s)
        ix = col_x - int(38 * s)
        conversa = cats[sc].get("conversa")
        lw = int(640 * s) if conversa is None else int(430 * s)
        if conversa is not None:
            desenhar_conversa(screen, conversa, ix + lw + int(36 * s), int(118 * s), W - mx,
                              H - int(84 * s), s, accent, F)
        hh = int(54 * s)
        for i, it in enumerate(items):
            # como no PS3: os itens antes do selecionado sobem para cima da fileira de categorias
            off = i - cam_y
            iy = base_y + off * gap
            if off < 0:
                acima = row_y - int(84 * s) + (off + 1) * gap
                iy = iy + (acima - iy) * min(1.0, -off)
            if iy > H - int(80 * s) or iy < int(120 * s) or row_y - int(58 * s) < iy < row_y + int(72 * s):
                continue
            on = i == si
            alpha = int(255 * max(0.22, 1 - 0.2 * abs(i - cam_y)) * ap)
            kind = it.get("kind", "acao")
            top = iy - hh // 2
            if on:
                gl = glow(lw, hh, accent, 40)
                gl.set_alpha(alpha)
                screen.blit(gl, (ix - hh, top - hh))
                screen.blit(rrect(lw, hh, int(14 * s), (255, 255, 255), 18, (*accent, 110), 1), (ix, top))
            if kind == "trofeu":
                cor = NIVEIS.get(it.get("nivel", ""), MUTED) if it.get("ganho") else DIM
                ic = icon("trophy" if it.get("ganho") else "lock", int(30 * s), cor)
            elif kind == "notif":
                ic = icon(it.get("icone", "info"), int(28 * s), accent if on else MUTED)
            elif kind == "info":
                ic = icon("info", int(24 * s), DIM)
            elif it.get("avatar") and avatar_img(it["avatar"], int(40 * s)) is not None:
                ic = avatar_img(it["avatar"], int(40 * s))
                if it.get("apagado"):
                    ic = ic.copy()
                    ic.set_alpha(120)
            else:
                ic = icon(ACOES_ICONE.get(it.get("acao", ""), "play"), int(24 * s), accent if on else MUTED)
            ic = ic.copy()
            ic.set_alpha(alpha)
            screen.blit(ic, (ix + int(30 * s) - ic.get_width() // 2, iy - ic.get_height() // 2))
            tx = ix + int(62 * s)
            font = f_item_on if on else f_item
            cor_txt = WHITE if on else MUTED
            if kind == "info" or (kind == "trofeu" and not it.get("ganho")):
                cor_txt = MUTED if on else DIM
            has_sub = bool(on and it.get("sub"))
            room = lw - int(90 * s) - (int(330 * s) if kind == "slider" else 0)
            ts = render(font, fit(font, it["t"], room), cor_txt)
            ts.set_alpha(alpha)
            ty = iy - ts.get_height() // 2 - (int(9 * s) if has_sub else 0)
            screen.blit(ts, (tx, ty))
            if it.get("novo"):
                nv = render(f_tag, "NOVO", dark)
                bx = tx + ts.get_width() + int(12 * s)
                screen.blit(rrect(nv.get_width() + int(14 * s), int(22 * s), int(11 * s), accent),
                            (bx, iy - int(11 * s) - (int(9 * s) if has_sub else 0)))
                screen.blit(nv, (bx + int(7 * s), iy - nv.get_height() // 2 - (int(9 * s) if has_sub else 0)))
            if has_sub:
                ss = render(f_small, fit(f_small, it["sub"], lw - int(90 * s)), MUTED)
                screen.blit(ss, (tx, iy + int(4 * s)))
            if kind == "slider":
                is_vol = it.get("id") == "volume"
                val = vol if is_vol else bri
                txt = ("mudo" if muted else f"{vol}%") if is_vol else (f"{bri}%" if bri >= 0 else "—")
                bw, bh = int(220 * s), int(8 * s)
                bx = ix + lw - bw - int(84 * s)
                by = iy - bh // 2
                screen.blit(rrect(bw, bh, bh // 2, (255, 255, 255), 40), (bx, by))
                if val > 0:
                    fw = max(bh, int(bw * val / 100))
                    screen.blit(rrect(fw, bh, bh // 2, DIM if (is_vol and muted) else accent), (bx, by))
                    screen.blit(rrect(int(18 * s), int(18 * s), int(9 * s), WHITE), (bx + fw - int(9 * s), iy - int(9 * s)))
                vt = render(f_sub, txt, WHITE if on else MUTED)
                screen.blit(vt, (bx + bw + int(18 * s), iy - vt.get_height() // 2))

        # ---- rodapé: botões no estilo do launcher (pílula com a tecla + ação)
        sel_kind = items[si].get("kind", "acao") if items else ""
        sel_acao = items[si].get("acao", "") if items else ""
        if kb:
            hints = [("A", "Tecla"), ("B", "Apagar"), ("Y", "Espaço"), ("X", "Maiúscula"), ("Start", "Enviar"),
                     ("Home", "Cancelar")]
        elif sel_acao == "amigo":
            hints = [("◀ ▶", "Categorias"), ("A", "Conversar"), ("B", "Voltar ao jogo")]
        elif cats[sc].get("id") == "amigos" and sel_acao in ("voltar_amigos", "escrever", "rapida", "convidar", "nada"):
            hints = [("A", "Escrever" if sel_acao == "escrever" else "Confirmar"), ("B", "Voltar aos amigos")]
        elif sel_kind == "slider":
            hints = [("◀ ▶", "Ajustar"), ("L1 R1", "Categorias"), ("B", "Voltar ao jogo")]
        else:
            hints = [("◀ ▶", "Categorias"), ("A", "Apagar" if sel_kind == "notif" else "Confirmar"),
                     ("B", "Voltar ao jogo")]
        x = W - mx
        yb = H - int(44 * s)
        for k, label in reversed(hints):
            lt_ = render(f_sub, label, MUTED)
            x -= lt_.get_width()
            screen.blit(lt_, (x, yb - lt_.get_height() // 2))
            ks = render(f_tag, k, WHITE)
            pw = max(int(24 * s), ks.get_width() + int(14 * s))
            x -= pw + int(8 * s)
            screen.blit(rrect(pw, int(24 * s), int(12 * s), (255, 255, 255), 40), (x, yb - int(12 * s)))
            screen.blit(ks, (x + (pw - ks.get_width()) // 2, yb - ks.get_height() // 2))
            x -= int(26 * s)

        if kb:
            desenhar_teclado(screen, kb, W, H, s, accent, dark, F)

        if msg and now - msg_t < 2.5:
            fade = min(1.0, (2.5 - (now - msg_t)) / 0.3)
            surf = render(f_item, msg, WHITE)
            bw_, bh_ = surf.get_width() + int(56 * s), surf.get_height() + int(24 * s)
            box = rrect(bw_, bh_, bh_ // 2, (0, 0, 0), 170, (*accent, 140), 1).copy()
            box.set_alpha(int(255 * fade))
            bxp, byp = (W - bw_) // 2, H - int(130 * s)
            screen.blit(box, (bxp, byp))
            surf.set_alpha(int(255 * fade))
            screen.blit(surf, (bxp + int(28 * s), byp + int(12 * s)))

        display.blit(screen, (0, 0))
        if tela_com_alfa:   # garante alfa 255 em todos os pixels (janela 100% opaca para o compositor)
            display.fill((0, 0, 0, 255), special_flags=pygame.BLEND_RGBA_MAX)
        pygame.display.flip()
        clock.tick(60 if animando else 30)


if __name__ == "__main__":
    main()
