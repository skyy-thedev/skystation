#!/usr/bin/env python3
"""Teste do menu Home dentro do jogo (Fase 10): conversa com um amigo e teclado virtual.

Simula os botões do controle chamando o sky-home.py por dentro (sem tela, sem controle de
verdade e sem rede: o sky-cloud é trocado por uma versão de mentira que anota o que foi pedido).

    python3 console/tests/teste-home.py      (precisa de python-evdev)
"""
import importlib.machinery
import json
import os
import shutil
import sys
import tempfile

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")
RAIZ = tempfile.mkdtemp(prefix="skyhome-")
os.environ["HOME"] = RAIZ
os.environ["XDG_RUNTIME_DIR"] = os.path.join(RAIZ, "run")
RUN = os.path.join(RAIZ, "run", "skystation")
os.makedirs(RUN)
os.makedirs(os.path.join(RAIZ, ".config/skystation"))
sys.path.insert(0, BIN)
passos = 0


def ok(cond, msg):
    global passos
    if not cond:
        raise AssertionError(msg)
    passos += 1
    print("  ok  " + msg, flush=True)


# ------------------------------------------------------------ teclado sozinho
import skyteclado  # noqa: E402

t = skyteclado.Teclado("Teste")
ok(t.tecla() == "q", "o teclado começa no q")
t.mover(0, 3)
ok(t.r == 4 and t.tecla() == "⇧", "descer até a última linha cai numa tecla especial")
t.mover(0, -1)
ok(t.r == 3 and t.c == 0, "voltar da última linha mantém a coluna proporcional")
t.mover(-1, 0)
ok(t.tecla() == "?", "andar para a esquerda da primeira tecla dá a volta")
for _ in "abc":
    pass
t = skyteclado.Teclado("Teste")
t.maiuscula()
t.apertar()
t.apertar()
ok(t.texto == "Qq", "maiúscula vale para uma letra só")
ok(not t.espaco() or t.texto == "Qq ", "espaço depois de texto") or None
ok(not skyteclado.Teclado("x").espaco(), "espaço no começo é ignorado")
t.pagina()
t.r, t.c = 1, 0
t.apertar()
ok(t.texto.endswith("á"), "página de símbolos tem os acentos do português")
ok(t.linhas()[4][1] == "ABC", "na página de símbolos o botão volta para ABC")
cheio = skyteclado.Teclado("x", "a" * 280)
ok(not cheio.digitar("b") and len(cheio.texto) == 280, "o limite de 280 caracteres é respeitado")
vazio = skyteclado.Teclado("x")
ok(not vazio.enviar() and not vazio.enviado, "mensagem vazia não é enviada")
ok(skyteclado.tecla_fisica("KEY_A") == "a" and skyteclado.tecla_fisica("KEY_A", True) == "A"
   and skyteclado.tecla_fisica("KEY_SEMICOLON") == "ç" and skyteclado.tecla_fisica("BTN_SOUTH") == "",
   "teclado de verdade: letras, ç e botões do controle")

# ------------------------------------------------------------ menu Home com o controle simulado
try:
    from evdev import ecodes as E
except ImportError:
    print("python-evdev não instalado: parte do menu Home pulada")
    sys.exit(0)

home = importlib.machinery.SourceFileLoader("sky_home", os.path.join(BIN, "sky-home.py")).load_module()

open(os.path.join(RAIZ, ".config/skystation/rede.json"), "w").write("{}")
with open(os.path.join(RUN, "net.json"), "w") as f:
    json.dump({"online": True, "amigos": [
        {"id": "pB", "apelido": "Bart", "status": "jogando", "jogo": "Metal Gear Rising", "sistema": "x360"},
        {"id": "pC", "apelido": "Caio", "status": "offline"}],
        "mensagens": [{"id": "m1", "de": {"id": "pB", "apelido": "Bart"}, "texto": "Bora jogar?", "lida": False}]}, f)
with open(os.path.join(RUN, "game.title"), "w") as f:
    f.write("inFamous")

pedidos = []


class HomeTeste(home.Home):
    def __init__(self):
        super().__init__()
        self.linhas = []

    def send(self, line):
        self.linhas.append(line)

    def cloud(self, *args, timeout=12):
        pedidos.append(args)
        if args[0] == "conversa":
            return {"ok": True, "mensagens": [{"texto": "Bora jogar?", "minha": False, "enviadaEm": "2026-11-17T10:00:00Z"}]}
        if args[0] in ("mensagem", "convidar"):
            return {"ok": True, "message": "Mensagem enviada" if args[0] == "mensagem" else "Convite enviado"}
        return {"ok": True}

    def processar(self):
        import time
        for _ in range(50):          # espera a thread de "rede" terminar
            if not self.fila.empty():
                break
            time.sleep(0.02)
        while not self.fila.empty():
            self.fila.get_nowait()()

    def ultimo(self, prefixo):
        return next((l for l in reversed(self.linhas) if l.startswith(prefixo)), "")


h = HomeTeste()
ok(not os.path.exists(os.path.join(RUN, "menu.aberto")), "o Home começa sem a marca de menu aberto")
h.menu = True
h.menu_pid = 4242
itens = h.amigos_items()
acoes = [(a, it.get("fid")) for a, it in itens]
ok(acoes[0] == ("amigo", "pB") and "Bora jogar?" in itens[0][1]["t"], "a mensagem nova aparece primeiro e abre a conversa")
ok(("amigo", "pC") in acoes and all(a == "amigo" for a, _ in acoes), "cada amigo é um item que abre a conversa")
h.cats = [{"id": "jogo", "title": "Jogo", "icon": "pad", "items": [("resume", {"t": "Voltar ao jogo"})]},
          {"id": "amigos", "title": "Amigos", "icon": "friends", "items": itens}]
h.cat, h.items = 1, itens
h.sel = [f for _, f in acoes].index("pB", 1)

h.menu_key(E.BTN_SOUTH)
ok(h.amigo == ("pB", "Bart") and h.cats[1]["title"] == "Bart", "A no amigo abre a conversa")
ok(h.items[h.sel][0] == "escrever", "o cursor já cai em Escrever mensagem")
ok(any(i[1].get("t", "").startswith("Convidar para inFamous") for i in h.items), "com jogo aberto dá para convidar para ele")
ok(not any(a == "jogar_junto" for a, _ in h.items), "jogo de PS3 não oferece jogar junto online (só RetroArch)")
with open(os.path.join(RUN, "game.sys"), "w") as f:
    f.write("snes")
ok(any(a == "jogar_junto" for a, _ in h.conversa_items("pB", "Bart")), "jogo de SNES oferece jogar junto online")
os.remove(os.path.join(RUN, "game.sys"))
h.processar()
ok(h.cats[1]["conversa"][0]["texto"] == "Bora jogar?" and ("lidas", "pB") in pedidos, "a conversa carrega e é marcada como lida")
ok('"conversa"' in h.ultimo("cats ") and "Bora jogar?" in h.ultimo("cats "), "a conversa vai para a tela")

h.menu_key(E.BTN_SOUTH)
ok(h.kb is not None and h.ultimo("kb ").startswith("kb {"), "A em Escrever abre o teclado na tela")
for code in (E.KEY_O, E.KEY_I):
    h.menu_key(code)
h.menu_key(E.BTN_TR)                  # R1: espaço
h.menu_key(E.BTN_TL2)                 # L2: maiúscula
h.menu_key(E.BTN_SOUTH)               # o cursor está no "q": com maiúscula vira "Q"
ok(json.loads(h.ultimo("kb ")[3:])["texto"] == "oi Q", "teclado de verdade, R1 (espaço), L2 (maiúscula) e ✕ (tecla)")
h.menu_key(E.BTN_WEST)
ok(h.kb.texto == "oi ", "□ apaga a última letra")
h.menu_key(E.BTN_NORTH)
ok(h.kb.simbolos, "△ troca para os símbolos")
h.menu_key(E.BTN_NORTH)
h.menu_key(E.KEY_W)
ok(h.kb.texto == "oi w", "com o teclado aberto, W de um teclado de verdade digita (não navega)")
h.menu_key(E.BTN_TR2)
ok(h.kb is None and h.ultimo("kb") == "kb", "R2 envia e fecha o teclado")
h.processar()
ok(("mensagem", "pB", "oi w") in pedidos, "a mensagem foi para o sky-cloud")
ok(h.ultimo("msg ") == "msg Mensagem enviada", "aviso de mensagem enviada")

h.menu_key(E.BTN_SOUTH)               # abre o teclado de novo
h.menu_key(E.KEY_X)
h.menu_key(E.BTN_EAST)                # ○ cancela, mesmo com texto
ok(h.kb is None, "○ cancela o teclado sem enviar")
h.menu_key(E.BTN_SOUTH)
h.menu_key(E.KEY_ESC)
ok(h.kb is None and h.menu, "Esc/Home fecha só o teclado, o menu continua aberto")

rapida = next(i for i, (a, _) in enumerate(h.items) if a == "rapida")
h.sel = rapida
h.menu_key(E.BTN_SOUTH)
h.processar()
ok(("mensagem", "pB", "Bora jogar?") in pedidos, "mensagem rápida")
conv = next(i for i, (a, _) in enumerate(h.items) if a == "convidar")
h.sel = conv
h.menu_key(E.BTN_SOUTH)
h.processar()
ok(("convidar", "pB") in pedidos and h.ultimo("msg ") == "msg Convite enviado", "convite para o jogo aberto")

h.menu_key(E.BTN_EAST)
ok(h.amigo is None and h.menu and h.cats[1]["title"] == "Amigos" and "conversa" not in h.cats[1],
   "B dentro da conversa volta à lista de amigos (sem fechar o menu)")
h.menu_key(E.BTN_SOUTH)               # abre de novo
h.menu_key(E.BTN_TL)                  # L1: outra categoria
ok(h.amigo is None and h.cat == 0, "trocar de categoria fecha a conversa")

home.marcar_menu(True)
ok(os.path.exists(os.path.join(RUN, "menu.aberto")), "menu aberto fica marcado para o sky-toast")
home.marcar_menu(False)
ok(not os.path.exists(os.path.join(RUN, "menu.aberto")), "e a marca some ao fechar")

shutil.rmtree(RAIZ, ignore_errors=True)
print(f"\nTudo certo: {passos} verificações.")
