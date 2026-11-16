"""SkyStation: patches automáticos do RPCS3 por jogo (Fase 8.3).

O RPCS3 tem uma base oficial de "game patches" (desligar MLAA, motion blur, FPS destravado…),
baixada pelo Patch Manager de https://rpcs3.net/compatibility?patch&api=v1&v=1.2. Aqui:

1. baixamos essa base no próprio console (no máximo 1x por semana; sem internet, usa a que já tem);
2. para cada jogo em REGRAS, ligamos os patches cujo NOME bate com as palavras-chave — os nomes,
   hashes PPU e versões vêm da própria base, então nada é digitado à mão;
3. gravamos em ~/.config/rpcs3/patch_config.yml (o mesmo arquivo do Patch Manager), mantendo o que
   o usuário já tinha ligado.

O que foi ligado fica anotado em ~/.config/rpcs3/skystation-patches.txt (e em SKYROMS/diag-patches.txt).
Sem PyYAML no console: os dois arquivos usam um subconjunto simples de YAML (mapas por indentação),
lido e escrito aqui.
"""
import json
import os
import re
import time
import urllib.request

URL = "https://rpcs3.net/compatibility?patch&api=v1&v=1.2"
DESLIGAR = r"^(?!.*\benable\b)"   # "Disable MLAA" sim; um eventual "Enable MLAA" não

# Jogo (código) -> lista de expressões (sem maiúsculas) para os nomes dos patches a ligar.
GOW3 = [DESLIGAR + r".*mlaa", DESLIGAR + r".*motion ?blur", DESLIGAR + r".*(depth of field|\bdof\b)",
        r"unlock.*(fps|frame)|(fps|frame).*unlock"]
REGRAS = {
    # God of War III: recomendações do RPCS3 (desligar MLAA, motion blur e profundidade de campo; FPS destravado)
    "BCUS98111": GOW3,
    "BCES00510": GOW3,
    "BCAS20107": GOW3,
    "BCJS37001": GOW3,
}


def _chave(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        s = s[1:-1]
    return s


def _linhas(texto):
    """(indentação, chave, valor) de cada linha "chave: valor" (ignora listas, comentários e vazias)."""
    for raw in texto.splitlines():
        if not raw.strip() or raw.lstrip().startswith(("#", "-")):
            continue
        ind = len(raw) - len(raw.lstrip(" "))
        corpo = raw.strip()
        if corpo.startswith('"'):
            fim = corpo.find('"', 1)
            if fim < 0:
                continue
            k, resto = corpo[1:fim], corpo[fim + 1:].lstrip()
            if not resto.startswith(":"):
                continue
            v = resto[1:].strip()
        else:
            if ":" not in corpo:
                continue
            k, v = corpo.split(":", 1)
            k, v = k.strip(), v.strip()
        yield ind, _chave(k), v


def ler_base(texto):
    """patch.yml -> [(hash, nome_do_patch, titulo, serial, [versões])]."""
    res = []
    pilha = []   # [(indentação, chave)]
    for ind, k, v in _linhas(texto):
        while pilha and pilha[-1][0] >= ind:
            pilha.pop()
        caminho = [c for _, c in pilha]
        # caminho esperado: [hash, nome, "Games", titulo] e a linha é "SERIAL: [ v1, v2 ]"
        if len(caminho) == 4 and caminho[2] == "Games" and re.match(r"^(PPU|SPU)-", caminho[0]):
            vers = [_chave(x) for x in v.strip("[] ").split(",") if x.strip()] if v.startswith("[") else []
            res.append((caminho[0], caminho[1], caminho[3], k, vers or ["All"]))
        if v == "":
            pilha.append((ind, k))
    return res


def ler_config(texto):
    """patch_config.yml -> {hash: {nome: {titulo: {serial: {versão: {...}}}}}} (só o que importa)."""
    raiz = {}
    pilha = [(-1, raiz)]
    for ind, k, v in _linhas(texto):
        while pilha[-1][0] >= ind:
            pilha.pop()
        alvo = pilha[-1][1]
        if v == "":
            novo = alvo.setdefault(k, {})
            pilha.append((ind, novo))
        else:
            alvo[k] = v
    return raiz


def _q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def escrever_config(cfg):
    out = []

    def rec(d, nivel):
        for k, v in d.items():
            if isinstance(v, dict):
                out.append("  " * nivel + _q(k) + ":")
                rec(v, nivel + 1)
            else:
                out.append("  " * nivel + _q(k) + ": " + v)
    rec(cfg, 0)
    return "\n".join(out) + "\n"


def baixar_base(rp):
    path = os.path.join(rp, "patches", "patch.yml")
    try:
        if time.time() - os.path.getmtime(path) < 7 * 86400:
            return path
    except OSError:
        pass
    try:
        req = urllib.request.Request(URL, headers={"User-Agent": "SkyStation"})
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.loads(r.read().decode("utf-8", "replace"))
        if d.get("return_code") == 0 and d.get("patch"):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path + ".tmp", "w") as f:
                f.write(d["patch"])
            os.replace(path + ".tmp", path)
    except (OSError, ValueError):
        pass   # sem internet: segue com a base que já existir
    return path


def aplicar(rp, serial, skyroms="/mnt/skyroms"):
    """Liga os patches das REGRAS para este jogo. Devolve a lista de nomes ligados."""
    regras = REGRAS.get(serial)
    if not regras:
        return []
    try:
        with open(baixar_base(rp)) as f:
            base = ler_base(f.read())
    except OSError:
        return []
    cfg_path = os.path.join(rp, "patch_config.yml")
    try:
        with open(cfg_path) as f:
            cfg = ler_config(f.read())
    except OSError:
        cfg = {}
    ligados = []
    for h, nome, titulo, ser, vers in base:
        if ser != serial or not any(re.search(rx, nome.lower()) for rx in regras):
            continue
        for v in vers:
            cfg.setdefault(h, {}).setdefault(nome, {}).setdefault(titulo, {}).setdefault(ser, {}) \
               .setdefault(v, {})["Enabled"] = "true"
        ligados.append(f"{nome}  ({h}, {', '.join(vers)})")
    if ligados:
        with open(cfg_path + ".tmp", "w") as f:
            f.write(escrever_config(cfg))
        os.replace(cfg_path + ".tmp", cfg_path)
    nota = f"{time.strftime('%Y-%m-%d %H:%M')}  {serial}: " + ("; ".join(ligados) or "nenhum patch encontrado na base") + "\n"
    for p in (os.path.join(rp, "skystation-patches.txt"), os.path.join(skyroms, "diag-patches.txt")):
        try:
            if os.path.isdir(os.path.dirname(p)) and os.access(os.path.dirname(p), os.W_OK):
                with open(p, "a") as f:
                    f.write(nota)
        except OSError:
            pass
    return ligados
