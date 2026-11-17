"""SkyStation: conversa com o servidor da SkyNetwork (Fases 9.4 e 10).

Biblioteca usada pelo sky-cloud (saves na nuvem, entrar na rede) e pelo sky-net (amigos, presença,
mensagens). Só a biblioteca padrão do Python: nada para instalar no console.

    import skynet
    cfg = skynet.config()                      # {} se o console ainda não entrou na rede
    status, dados = skynet.api("POST", "/api/sync", {"presenca": {...}}, perfil="p1")
    skynet.aviso("amigo", "Bart entrou online")  # aparece na tela, no histórico e toca o som

Onde ficam as coisas:
    ~/.config/skystation/rede.json   endereço do servidor e o token deste console (não vai para a nuvem)
    $XDG_RUNTIME_DIR/skystation/net.json   o que o sky-net sabe agora (o launcher e o menu Home leem)
"""
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

HOME = os.path.expanduser("~")
SKY = os.path.join(HOME, "skystation")
CONF_DIR = os.path.join(HOME, ".config/skystation")
CONF = os.path.join(CONF_DIR, "rede.json")
RUN = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "skystation")
NET_JSON = os.path.join(RUN, "net.json")
SOUNDS = "/opt/skystation/sounds"
# O servidor oficial do SkyStation. Outro servidor: "url" no rede.json ou a variável SKY_REDE_URL.
URL_PADRAO = "https://skyntwk.vercel.app"
AGENTE = "SkyStation-console/1"


def ler_json(path, padrao=None):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return padrao


def gravar_json(path, dados, modo=None):
    """Troca atômica: quem lê nunca vê o arquivo pela metade, nem se a luz cair no meio."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent=1)
    if modo is not None:
        os.chmod(tmp, modo)
    os.replace(tmp, path)


def config():
    c = ler_json(CONF, {})
    return c if isinstance(c, dict) else {}


def gravar_config(c):
    gravar_json(CONF, c, 0o600)     # tem o token: só o dono lê


def url_base(cfg=None):
    cfg = config() if cfg is None else cfg
    return (os.environ.get("SKY_REDE_URL") or cfg.get("url") or URL_PADRAO).rstrip("/")


def conectado(cfg=None):
    cfg = config() if cfg is None else cfg
    return bool(cfg.get("token"))


def api(metodo, caminho, corpo=None, perfil=None, cfg=None, timeout=8, token=True):
    """Chama o servidor. Devolve (status, dados). Sem rede: (0, {"erro": "sem_rede", ...})."""
    cfg = config() if cfg is None else cfg
    cab = {"User-Agent": AGENTE, "Accept": "application/json"}
    dados = None
    if corpo is not None:
        dados = json.dumps(corpo).encode()
        cab["Content-Type"] = "application/json"
    if token and cfg.get("token"):
        cab["Authorization"] = "Bearer " + cfg["token"]
    if perfil:
        cab["X-Perfil"] = perfil
    req = urllib.request.Request(url_base(cfg) + caminho, data=dados, method=metodo, headers=cab)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, _json(r.read())
    except urllib.error.HTTPError as e:
        return e.code, _json(e.read()) or {"erro": "http", "mensagem": f"O servidor respondeu {e.code}."}
    except (urllib.error.URLError, OSError, ValueError) as e:
        return 0, {"erro": "sem_rede", "mensagem": "Sem conexão com a SkyNetwork.", "detalhe": str(e)}


def _json(bruto):
    try:
        d = json.loads(bruto.decode("utf-8", "replace"))
        return d if isinstance(d, dict) else {}
    except ValueError:
        return {}


def mensagem(dados, padrao="Não deu certo."):
    return str(dados.get("mensagem") or padrao)


# ---------------------------------------------------------------- ícones de perfil

def avatares():
    """[{"id", "nome", "cor"}] dos ícones do SkyStation (console/avatares/avatares.json)."""
    for base in (os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "avatares"),
                 "/opt/skystation/avatares"):
        lst = ler_json(os.path.join(base, "avatares.json"))
        if lst:
            return lst
    return [{"id": "estrela", "nome": "Estrela cadente", "cor": "#4fd1ff"}]


def avatar_png(id_):
    for base in (os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "avatares"),
                 "/opt/skystation/avatares"):
        p = os.path.join(base, f"{id_}.png")
        if os.path.exists(p):
            return p
    return ""


# ---------------------------------------------------------------- perfis

def perfis():
    """(id do perfil em uso, lista de perfis do console). Sem perfis ainda: ("p1", [Jogador 1])."""
    d = ler_json(os.path.join(SKY, "perfis/perfis.json"), {})
    lst = d.get("perfis") if isinstance(d, dict) else None
    if not lst:
        return "p1", [{"id": "p1", "nome": "Jogador 1", "cor": "#4fd1ff"}]
    return str(d.get("atual") or lst[0]["id"]), lst


def enviar_perfis(cfg=None, invisivel=None):
    """Manda os perfis do console ao servidor (cria os novos, atualiza nome e cor).
    `invisivel` (True/False) muda só o perfil em uso. Devolve (status, dados)."""
    atual, lst = perfis()
    corpo = []
    for p in lst[:4]:
        item = {"localId": str(p["id"]), "apelido": (str(p.get("nome") or "Jogador").strip() or "Jogador")[:24]}
        cor = str(p.get("cor", ""))
        if len(cor) == 7 and cor.startswith("#"):
            item["cor"] = cor
        if invisivel is not None and str(p["id"]) == atual:
            item["invisivel"] = bool(invisivel)
        corpo.append(item)
    return api("PUT", "/api/perfis", {"perfis": corpo}, cfg=cfg)


# ---------------------------------------------------------------- avisos

def avisos_ligados():
    return not os.path.exists(os.path.join(CONF_DIR, "avisos.off"))


def tocar(som):
    arq = os.path.join(SOUNDS, som + ".wav")
    player = shutil.which("pw-play") or shutil.which("aplay")
    if player and os.path.exists(arq) and avisos_ligados():
        try:
            subprocess.Popen([player, arq], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass


def aviso(tipo, texto, som=None, historico=True):
    """Mesmo caminho dos outros avisos do console: uma linha no events.jsonl (o launcher mostra na
    tela), uma entrada na central de notificações e, se pedido, um som."""
    try:
        os.makedirs(RUN, exist_ok=True)
        with open(os.path.join(RUN, "events.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": time.time(), "kind": tipo, "text": texto}, ensure_ascii=False) + "\n")
    except OSError:
        pass
    if historico:
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import skyhist
            skyhist.add(tipo, texto)
        except Exception:
            pass
    if som:
        tocar(som)


def saida(dados):
    """Os comandos respondem com uma linha JSON no fim (o launcher lê a última linha)."""
    print(json.dumps(dados, ensure_ascii=False), flush=True)
    return 0 if dados.get("ok") else 1
