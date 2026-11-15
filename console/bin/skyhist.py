"""SkyStation: histórico de notificações (Fase 8.1).

Cada aviso que aparece na tela (controle conectado, troféu, jogo recebido, bateria…) também
fica guardado em ~/skystation/notificacoes.json, para a central de notificações (deslizar o
touchpad do controle de cima para baixo, como no Android) mostrar os recentes, abrir a seção
de cada um e limpar um por um ou todos.

    import skyhist
    skyhist.add("controle", "DualShock 4 conectado")
    skyhist.load()            # mais novas primeiro
    skyhist.remove(id) / skyhist.clear()
"""
import json
import os
import time

PATH = os.path.join(os.path.expanduser("~"), "skystation", "notificacoes.json")
MAX = 80
# avisos internos (recarregar a lista, volume pelo touchpad, abrir o painel) não entram no histórico
FORA = {"jogos", "ajuste", "painel"}


def load():
    try:
        with open(PATH) as f:
            d = json.load(f)
        return [n for n in d if isinstance(n, dict) and "text" in n] if isinstance(d, list) else []
    except (OSError, ValueError):
        return []


def _save(lst):
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    tmp = PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(lst[:MAX], f, ensure_ascii=False)
    os.replace(tmp, PATH)   # troca atômica: quem lê nunca vê o arquivo pela metade


def add(kind, text):
    if kind in FORA or not text:
        return
    try:
        lst = load()
        now = time.time()
        nid = int(now * 1000)
        usados = {n.get("id") for n in lst}
        while nid in usados:          # dois avisos no mesmo milissegundo (ex.: vários troféus juntos)
            nid += 1
        lst.insert(0, {"id": nid, "t": now, "kind": kind, "text": text})
        _save(lst)
    except OSError:
        pass


def remove(nid):
    try:
        _save([n for n in load() if n.get("id") != nid])
    except OSError:
        pass


def clear():
    try:
        _save([])
    except OSError:
        pass
