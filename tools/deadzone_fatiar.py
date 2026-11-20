"""Recorta as folhas geradas por IA em peças prontas para o DEADZONE.

Uso: python3 -I fatiar.py PASTA_UPLOADS PASTA_SAIDA
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

UP, OUT = sys.argv[1], sys.argv[2]


def abrir(nome):
    return Image.open(os.path.join(UP, nome + "-image.png")).convert("RGB")


def salvar(im, rel, jpg=False):
    caminho = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    if jpg:
        im.convert("RGB").save(caminho, quality=88, optimize=True)
    else:
        im.save(caminho, optimize=True)
    print(rel, im.size)


def chave_magenta(im):
    """RGB -> RGBA, apagando o fundo magenta e a franja rosada da borda."""
    a = np.asarray(im).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # quanto o pixel "puxa" para magenta (0 = nada, 255 = magenta puro)
    m = np.clip(np.minimum(r, b) - g, 0, 255)
    alfa = np.where(m > 90, 0, 255).astype(np.uint8)
    # fecha 1 px pra dentro: a franja anti-aliased é roxa escura
    alfa = np.asarray(Image.fromarray(alfa).filter(ImageFilter.MinFilter(3)))
    # tira o rosa que sobrou nos pixels de borda
    borda = (m > 25) & (alfa > 0)
    out = a.copy()
    lim = np.maximum(g, 0)
    out[..., 0] = np.where(borda, np.minimum(r, lim + 25), r)
    out[..., 2] = np.where(borda, np.minimum(b, lim + 25), b)
    rgba = np.dstack([out.astype(np.uint8), alfa])
    return Image.fromarray(rgba, "RGBA")


def aparar(im, folga=2):
    bb = im.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    if not bb:
        return im
    l, t, r, b = bb
    return im.crop((max(0, l - folga), max(0, t - folga),
                    min(im.width, r + folga), min(im.height, b + folga)))


def limitar(im, lado):
    """Reduz para caber em lado x lado (nunca amplia)."""
    if max(im.size) > lado:
        im = im.copy()
        im.thumbnail((lado, lado), Image.LANCZOS)
    return im


def sem_roxo(im):
    """Fios finos ficam roxos (mistura com o magenta): vira cinza. Só para peças sem roxo de verdade."""
    a = np.asarray(im).astype(np.int16).copy()
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (np.minimum(r, b) - g) > 10
    cinza = (r + g + b) // 3 * 0.85
    for c in range(3):
        a[..., c] = np.where(m, cinza, a[..., c])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


ROXO_FALSO = ("arte/pecas/poste.png",)


def peca(im, caixa, rel, lado=320, inset=6):
    l, t, r, b = caixa
    c = im.crop((l + inset, t + inset, r - inset, b - inset))
    c = limitar(aparar(chave_magenta(c)), lado)
    if rel in ROXO_FALSO:
        c = sem_roxo(c)
    salvar(c, rel)


# ---------- retratos ----------
def quadro_magenta(im, caixa):
    """Acha o retângulo do quadro dentro de uma célula aproximada."""
    a = np.asarray(im.crop(caixa)).astype(np.int16)
    m = (np.minimum(a[..., 0], a[..., 2]) - a[..., 1]) > 90
    ys, xs = np.where(m)
    l, t, r = xs.min(), ys.min(), xs.max()
    # desce até a borda do quadro (linha quase toda branca ou preta)
    b = ys.max()
    while b + 1 < a.shape[0]:
        linha = a[b + 1, l:r + 1]
        lum = linha.mean(axis=1)
        if ((lum > 235) | (lum < 25)).mean() > 0.9:
            break
        b += 1
    x0, y0 = caixa[0], caixa[1]
    return (x0 + l, y0 + t, x0 + r + 1, y0 + b + 1)


def retratos(nome, cols, rows, chaves):
    im = abrir(nome)
    cw, ch = im.width / cols, im.height / rows
    i = 0
    for y in range(rows):
        for x in range(cols):
            if i >= len(chaves):
                return
            caixa = (int(x * cw), int(y * ch), int((x + 1) * cw), int((y + 1) * ch))
            q = quadro_magenta(im, caixa)
            l, t, r, b = q
            c = chave_magenta(im.crop((l + 3, t + 3, r - 3, b - 1)))
            salvar(limitar(c, 300), "arte/retratos/%s.png" % chaves[i])
            i += 1


R = "corvo_"
retratos("37145d7f", 4, 2, [R + s for s in
         ["neutro", "irritado", "sorriso", "preocupado", "medo", "dor", "ferido", "grito"]])
retratos("d10f9f13", 4, 2, ["iara_" + s for s in
         ["deboche", "rindo", "medo", "triste", "chorando", "brava", "grito", "determinada"]])
retratos("675b5c1c", 4, 2, ["rocha_" + s for s in
         ["severo", "culpado", "duvida", "bravo", "sorriso", "rindo", "aviso", "grito"]])
retratos("453aec8c", 2, 2, ["helena_" + s for s in ["calma", "fria", "surpresa", "triste"]])
retratos("46fad348", 2, 2, ["nina_" + s for s in ["rindo", "dor", "brava", "medo"]])
retratos("88da7f5a", 2, 2, ["tiao_" + s for s in ["locutor", "ganancia", "assustado", "bravo"]])

# ---------- peças do mapa ----------
im = abrir("fd004b56")  # 2 x 3
nomes = ["kombi", "caminhao_tombado", "tambor", "porta_bunker", "bomba", "galao"]
for i, n in enumerate(nomes):
    x, y = i % 2, i // 2
    peca(im, (x * 512, int(y * 559 / 3), (x + 1) * 512, int((y + 1) * 559 / 3)),
         "arte/pecas/%s.png" % n)


def lote_2_4(nome, nomes):
    im = abrir(nome)
    meio = int(im.height * 0.497)
    caixas = [(0, 0, 512, meio), (512, 0, 1024, meio)]
    caixas += [(x * 256, meio, (x + 1) * 256, im.height) for x in range(4)]
    for c, n in zip(caixas, nomes):
        peca(im, c, "arte/pecas/%s.png" % n)


lote_2_4("188701ee", ["armario", "geladeira", "prateleira", "cama", "ferramentas", "radio"])
lote_2_4("828ca52a", ["arvore", "arbusto", "fogueira", "orelhao", "poste", "barricada"])

# ---------- ícones ----------
im = abrir("d5b912cb")
itens = ["lata", "agua", "bandagem", "bala_pistola", "cartucho", "pente_rifle",
         "pilha", "madeira", "pano", "galao", "iodo", "carne_crua",
         "carne_assada", "tocha", "molotov", "sucata"]
for i, n in enumerate(itens):
    x, y = i % 4, i // 4
    peca(im, (x * 256, y * 256, (x + 1) * 256, (y + 1) * 256), "arte/icones/%s.png" % n,
         lado=128, inset=10)
im = abrir("56218c83")
armas = ["faca", "taco", "machado", "facao", "pistola", "espingarda", "rifle", "lanterna"]
rh = im.height / 3
for i, n in enumerate(armas):
    x, y = i % 4, i // 4
    peca(im, (x * 256, int(y * rh), (x + 1) * 256, int((y + 1) * rh)),
         "arte/icones/%s.png" % n, lado=160, inset=6)


# ---------- texturas ----------
def emendavel(im):
    """Mistura a textura com a cópia deslocada meio lado: some a costura."""
    a = np.asarray(im).astype(np.float32)
    n = a.shape[0]
    d = np.roll(np.roll(a, n // 2, 0), n // 2, 1)
    t = np.linspace(-1, 1, n)
    # peso 1 no meio da original, 0 nas bordas (onde entra a deslocada)
    w = np.clip(1.6 - 1.6 * np.maximum(np.abs(t)[:, None], np.abs(t)[None, :]), 0, 1)
    w = w[..., None]
    return Image.fromarray((a * w + d * (1 - w)).astype(np.uint8))


def sem_faixa_amarela(im):
    import cv2
    a = np.asarray(im).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = ((r > 110) & (g > 85) & (r - b > 45)).astype(np.uint8) * 255
    m = cv2.dilate(m, np.ones((5, 5), np.uint8))
    out = cv2.inpaint(np.asarray(im)[..., ::-1].copy(), m, 7, cv2.INPAINT_TELEA)
    return Image.fromarray(out[..., ::-1].copy())


def texturas(nome, nomes):
    im = abrir(nome)
    a = np.asarray(im).astype(np.int16).sum(axis=2)
    W, H = im.size
    for i, n in enumerate(nomes):
        x, y = i % 2, i // 2
        cx0, cy0, cx1, cy1 = x * W // 2, y * H // 2, (x + 1) * W // 2, (y + 1) * H // 2
        sub = a[cy0:cy1, cx0:cx1] > 90
        ys, xs = np.where(sub)
        l, t, r, b = cx0 + xs.min() + 16, cy0 + ys.min() + 16, cx0 + xs.max() - 16, cy0 + ys.max() - 16
        lado = min(r - l, b - t)
        cx, cy = (l + r) // 2, (t + b) // 2
        q = im.crop((cx - lado // 2, cy - lado // 2, cx + lado // 2, cy + lado // 2))
        q = q.resize((256, 256), Image.LANCZOS)
        if n == "chao_asfalto":
            q = sem_faixa_amarela(q)    # repetida a cada tile, a faixa vira um xadrez amarelo
        if n.startswith("chao"):
            q = emendavel(q)
        salvar(q, "arte/chao/%s.png" % n)


texturas("e9edea18", ["chao_asfalto", "chao_mato", "chao_calcada", "chao_madeira"])
texturas("03701ca6", ["chao_concreto", "chao_terra", "parede_tijolo", "parede_concreto"])


# ---------- carros (xadrez falso) ----------
def tirar_xadrez(im):
    a = np.asarray(im).astype(np.int16)
    mx, mn = a.max(axis=2), a.min(axis=2)
    neutro = ((mx - mn) < 16) & (mn > 138)
    # preenche a partir das bordas só por pixels neutros e claros
    from collections import deque
    h, w = neutro.shape
    fundo = np.zeros_like(neutro)
    fila = deque()
    for x in range(w):
        for y in (0, h - 1):
            if neutro[y, x]:
                fundo[y, x] = True
                fila.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if neutro[y, x] and not fundo[y, x]:
                fundo[y, x] = True
                fila.append((y, x))
    while fila:
        y, x = fila.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and neutro[yy, xx] and not fundo[yy, xx]:
                fundo[yy, xx] = True
                fila.append((yy, xx))
    # 2a passada: o brilho do farol tinge o xadrez de laranja; o contorno preto
    # do carro segura a inundação do lado de fora
    claro = (mn > 95) & ((mx - mn) < 75)
    fila = deque(zip(*np.where(fundo)))
    while fila:
        y, x = fila.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and claro[yy, xx] and not fundo[yy, xx]:
                fundo[yy, xx] = True
                fila.append((yy, xx))
    halo = None
    alfa = np.where(fundo, 0, 255).astype(np.uint8)
    img = Image.fromarray(alfa).filter(ImageFilter.MinFilter(3))
    # mantém só o maior bloco (o carro)
    rgba = np.dstack([a.astype(np.uint8), np.asarray(img)])
    return Image.fromarray(rgba, "RGBA"), halo


for nome, n in (("83d4e7e0", "carro_quebrado"), ("89d5a68e", "carro_bom"), ("b1bac46b", "viatura")):
    c, _ = tirar_xadrez(abrir(nome))
    salvar(limitar(aparar(c), 360), "arte/pecas/%s.png" % n)

# ---------- telas e páginas ----------
salvar(abrir("b2654283"), "arte/telas/titulo.jpg", jpg=True)
salvar(abrir("87c1cb0e"), "arte/telas/game_over.jpg", jpg=True)
paginas = {"1741ec96": "c1_abertura", "d8ae3207": "c1_contrato",
           "1098f2b0": "c1_mordida_arma", "137d8ff4": "c1_mordida_mao",
           "da6b8755": "c1_pedagio", "f754d973": "c1_pedagio_vendeu"}
for k, n in paginas.items():
    salvar(abrir(k), "arte/hq/%s.jpg" % n, jpg=True)


# ---------- personagens e zumbis (rodada 3) ----------
def figuras(im, minimo=4000):
    """Separa as figuras de uma folha de turnaround pelo fundo magenta: cada bloco grande = um desenho."""
    from scipy import ndimage
    rgba = chave_magenta(im)
    a = np.asarray(rgba)[..., 3] > 20
    a = ndimage.binary_dilation(a, iterations=4)          # junta facão, alça e mão que ficaram soltos
    lab, n = ndimage.label(a)
    caixas = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        ys, xs = sl
        area = (lab[sl] == i + 1).sum()
        if area >= minimo and (ys.stop - ys.start) > 120:     # linhas da grade e sujeira ficam de fora
            caixas.append((xs.start, ys.start, xs.stop, ys.stop))
    return rgba, sorted(caixas, key=lambda c: (c[1] > im.height * 0.4, c[0]))


def maior_bloco(im):
    """Fica só com o maior pedaço conectado (tira restos da figura vizinha)."""
    from scipy import ndimage
    a = np.asarray(im).copy()
    lab, n = ndimage.label(a[..., 3] > 20)
    if n > 1:
        tam = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        a[..., 3] = np.where(lab == 1 + int(np.argmax(tam)), a[..., 3], 0)
    return aparar(Image.fromarray(a, "RGBA"))


def personagem(nome_arq, prefixo, ordem, altura=300, faixas=None):
    """ordem: direção de cada figura da esquerda para a direita (None = ignora).
    faixas: (x0, x1) de cada figura, para quando duas se encostam (o facão de uma passa na outra)."""
    rgba, cx = figuras(abrir(nome_arq))
    if faixas:
        cx = [(x0, 0, x1, rgba.height) for x0, x1 in faixas]
        rgba_orig = rgba
        rgba = rgba_orig
    assert len(cx) >= len(ordem), (prefixo, len(cx))
    for caixa, d in zip(cx, ordem):
        if d is None:
            continue
        c = maior_bloco(rgba.crop(caixa)) if faixas else aparar(rgba.crop(caixa))
        c = c.resize((max(1, int(c.width * altura / c.height)), altura), Image.LANCZOS) if c.height > altura else c
        salvar(c, "arte/%s_%s.png" % (prefixo, d))


if os.path.exists(os.path.join(UP, "c6ea5058-image.png")):
    personagem("c6ea5058", "personagens/iara", ["baixo", "cima", "esq", "dir"])
    personagem("57f7eef3", "personagens/corvo", ["baixo", "cima", None, "dir"],
               faixas=[(0, 300), (300, 580), (570, 800), (790, 1024)])
    personagem("3a57a35a", "personagens/rocha", ["baixo", "cima", "dir", "esq"])
    personagem("db98d9f1", "personagens/nina", ["baixo", "cima", None, "dir"])
    personagem("a6df28e3", "personagens/tiao", ["baixo", "cima", "dir", None])
    rgba, cx = figuras(abrir("739fee80"))
    tipos = ["andarilho", "corredor", "brutamontes", "policial", "irradiado"]
    assert len(cx) == 10, len(cx)
    for i, caixa in enumerate(cx):
        lado = "frente" if i < 5 else "lado"
        c = aparar(rgba.crop(caixa))
        # todos na mesma tela de 290 px de altura, pé embaixo: o corredor agachado continua mais baixo no jogo
        tela = Image.new("RGBA", (c.width, 290), (0, 0, 0, 0))
        tela.alpha_composite(c, (0, 290 - c.height))
        salvar(tela, "arte/zumbis/%s_%s.png" % (tipos[i % 5], lado))
