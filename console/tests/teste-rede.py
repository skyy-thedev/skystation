#!/usr/bin/env python3
"""Teste do lado do console da SkyNetwork: dois "consoles" de mentira (duas pastas HOME) conversando
com um servidor de verdade.

    SKY_REDE_URL=http://localhost:3000 SKY_CONVITE=... python3 console/tests/teste-rede.py

Passa por: entrar na rede, amizade, presença, avisos, mensagens, troféus, saves na nuvem
(enviar, baixar, conflito, sem internet), e o mesmo perfil em dois consoles.
"""
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.request

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")
URL = os.environ.get("SKY_REDE_URL", "http://localhost:3000")
CONVITE = os.environ.get("SKY_CONVITE", "")
RAIZ = tempfile.mkdtemp(prefix="skyteste-")
passos = 0
TOKENS = []
CONTAS = []   # (ID, senha) criadas no teste: excluídas no fim pelo site


def ok(cond, msg):
    global passos
    if not cond:
        raise AssertionError(msg)
    passos += 1
    print("  ok  " + msg, flush=True)


class Console:
    def __init__(self, nome, jogador):
        self.home = os.path.join(RAIZ, nome)
        self.run = os.path.join(self.home, "run", "skystation")
        os.makedirs(self.run)
        os.makedirs(os.path.join(self.home, "skystation/perfis"))
        os.makedirs(os.path.join(self.home, "skystation/saves"))
        with open(os.path.join(self.home, "skystation/perfis/perfis.json"), "w") as f:
            json.dump({"atual": "p1", "perfis": [{"id": "p1", "nome": jogador, "cor": "#4fd1ff"}]}, f)

    def env(self, url=URL):
        e = dict(os.environ, HOME=self.home, XDG_RUNTIME_DIR=os.path.join(self.home, "run"), SKY_REDE_URL=url)
        return e

    def sky(self, *args, prog="sky-cloud", url=URL, senha=None):
        env = self.env(url)
        if senha is not None:
            env["SKY_SENHA"] = senha
        r = subprocess.run([sys.executable, os.path.join(BIN, prog), *args], env=env,
                           capture_output=True, text=True, timeout=120)
        try:
            return json.loads(r.stdout.strip().splitlines()[-1])
        except (IndexError, ValueError):
            raise AssertionError(f"{prog} {args}: saída inesperada\n{r.stdout}\n{r.stderr}")

    def save(self, rel):
        return os.path.join(self.home, "skystation/saves", rel)

    def escrever(self, rel, dados):
        os.makedirs(os.path.dirname(self.save(rel)), exist_ok=True)
        with open(self.save(rel), "wb") as f:
            f.write(dados)

    def ler(self, rel):
        with open(self.save(rel), "rb") as f:
            return f.read()

    def jogo(self, gid=None, titulo="", sis=""):
        for n, v in (("game.pid", str(os.getpid())), ("game.id", gid), ("game.title", titulo), ("game.sys", sis)):
            p = os.path.join(self.run, n)
            if gid is None:
                if os.path.exists(p):
                    os.remove(p)
            else:
                with open(p, "w") as f:
                    f.write(v)

    def net(self):
        with open(os.path.join(self.run, "net.json")) as f:
            return json.load(f)

    def eventos(self):
        try:
            with open(os.path.join(self.run, "events.jsonl")) as f:
                return [json.loads(x)["text"] for x in f if x.strip()]
        except OSError:
            return []

    def token(self):
        with open(os.path.join(self.home, ".config/skystation/rede.json")) as f:
            return json.load(f)["token"]


CRASH = ("ps1-Crash_Bandicoot", "Crash Bandicoot", "sky-emu ps1 '/roms/ps1/Crash Bandicoot.chd'")
A = Console("a", "Sky")
B = Console("b", "Bart")
try:
    # ------------------------------------------------------------ entrar na rede
    ok(A.sky("estado")["conectado"] is False, "fora da rede: estado responde sem erro")
    ok(A.sky("antes", *CRASH)["ok"], "fora da rede: abrir jogo não faz nada (e não trava)")
    ok(A.sky("entrar", "convite-errado")["ok"] is False, "convite errado é recusado")
    ea = A.sky("entrar", CONVITE)
    ok(ea["ok"] and len(ea["codigo"]) == 6, "console A entra na rede e recebe o código de amigo")
    modo = stat.S_IMODE(os.stat(os.path.join(A.home, ".config/skystation/rede.json")).st_mode)
    ok(modo == 0o600, "o arquivo com o token só pode ser lido pelo dono")
    eb = B.sky("entrar", CONVITE)
    ok(eb["ok"], "console B entra na rede")
    TOKENS[:] = [A.token(), B.token()]
    ok(A.sky("entrar", CONVITE)["message"].startswith("Este console já"), "entrar de novo não registra outro console")

    # ------------------------------------------------------------ amizade
    ok(A.sky("amigo", "zzzzzz")["ok"] is False, "código de amigo inexistente dá erro legível")
    # Fase 9.1: ficha do jogo (sem rede para fora no teste, a ficha pode vir vazia, mas o caminho funciona)
    with open(os.path.join(A.run, "biblioteca.json"), "w") as f:
        json.dump([{"id": "ps2-God_of_War_(USA)", "sis": "ps2", "titulo": "God of War"}], f)
    fi = A.sky(prog="sky-fichas")
    meta = os.path.join(A.home, ".cache/skystation/fichas/ps2-God_of_War__USA_.json")
    ok(fi["ok"] and fi["tentadas"] == 1 and os.path.exists(meta), "sky-fichas baixa a ficha dos jogos da biblioteca")
    with open(meta) as f:
        ok(json.load(f).get("situacao") == "perfeito", "a ficha traz a situação do catálogo de testados")
    ok(A.sky(prog="sky-fichas")["tentadas"] == 0, "ficha já baixada não é pedida de novo")
    ok("Pedido enviado para Bart" in A.sky("amigo", eb["codigo"].lower())["message"], "A pede amizade a B")
    sb = B.sky("estado")
    ok(sb["online"] and len(sb["pedidos"]) == 1 and sb["pedidos"][0]["de"]["apelido"] == "Sky", "B vê o pedido de A")
    ok(B.sky("aceitar", sb["pedidos"][0]["amizadeId"])["ok"], "B aceita")
    sa = A.sky("estado")
    ok(len(sa["amigos"]) == 1 and sa["eu"]["codigo"] == ea["codigo"], "A vê B na lista de amigos")
    idA, idB = sa["eu"]["id"], sb["eu"]["id"]

    # ------------------------------------------------------------ presença
    B.jogo("ps2-gow2", "God of War II", "ps2")
    ok(B.sky("uma-vez", prog="sky-net")["ok"], "sky-net de B sincroniza com um jogo aberto")
    ok(A.sky("uma-vez", prog="sky-net")["amigos"] == 1, "sky-net de A sincroniza")
    am = A.net()["amigos"][0]
    ok(am["status"] == "jogando" and am["jogo"] == "God of War II" and am["sistema"] == "ps2", "net.json de A mostra B jogando God of War II")
    ok(A.sky("invisivel", "on")["ok"] and B.sky("uma-vez", prog="sky-net")["ok"] and B.net()["amigos"][0]["status"] == "offline",
       "A invisível aparece offline para B")
    A.sky("invisivel", "off")

    # ------------------------------------------------------------ avisos (o serviço ligado o tempo todo)
    auxiliar = (
        "import importlib.machinery, sys, os\n"
        f"sys.path.insert(0, {BIN!r})\n"
        f"m = importlib.machinery.SourceFileLoader('skynet_servico', os.path.join({BIN!r}, 'sky-net')).load_module()\n"
        "r = m.Rede(); cfg = m.skynet.config()\n"
        "assert r.sincronizar(cfg)[0]\n"
        "print('pronto', flush=True); sys.stdin.readline()\n"
        "assert r.sincronizar(cfg)[0]\n"
        "print('fim', flush=True)\n")
    p = subprocess.Popen([sys.executable, "-c", auxiliar], env=A.env(), stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    ok(p.stdout.readline().strip() == "pronto", "serviço de A fez a primeira sincronização")
    ok(A.eventos() == [], "na primeira sincronização nada é despejado na tela")
    ok(B.sky("mensagem", idA, "Bora", "jogar?")["ok"], "B manda mensagem para A")
    B.jogo("x360-mgr", "Metal Gear Rising", "x360")
    B.sky("uma-vez", prog="sky-net")
    ok(B.sky("convidar", idA)["ok"], "B convida A para o jogo aberto")
    with open(os.path.join(B.home, "skystation/saves/trofeus.json"), "w") as f:
        json.dump({"primeira": 1794880000}, f)
    B.sky("uma-vez", prog="sky-net")
    p.stdin.write("\n"); p.stdin.flush()
    ok(p.stdout.readline().strip() == "fim" and p.wait(30) == 0, "serviço de A fez a segunda sincronização")
    ev = A.eventos()
    ok("Bart: Bora jogar?" in ev, "A recebe o aviso da mensagem")
    ok("Bart está jogando Metal Gear Rising" in ev, "A recebe o aviso de que B começou outro jogo")
    ok("Bart chamou você para jogar Metal Gear Rising" in ev, "A recebe o convite")
    ok(any(e.startswith("Bart ganhou o troféu de bronze: Primeira partida") for e in ev), "A recebe o troféu de B")
    ok(A.net()["naoLidas"] == 2 and len(A.net()["mensagens"]) == 2, "net.json de A guarda as mensagens")
    ok(A.sky("lidas", idB)["ok"] and A.sky("uma-vez", prog="sky-net")["ok"] and A.net()["naoLidas"] == 0, "A marca como lidas")
    B.jogo(None)

    # ------------------------------------------------------------ saves na nuvem
    A.escrever("ps1/Crash Bandicoot.srm", b"save-1 do console A")
    A.escrever("ps1/Crash Bandicoot 2.srm", b"outro jogo, nao deve subir junto")
    ok(A.sky("antes", *CRASH)["message"] == "sem save na nuvem", "antes do jogo: nada na nuvem ainda")
    ok(A.sky("depois", *CRASH)["message"] == "enviado", "depois do jogo: save enviado")
    ok(A.sky("depois", *CRASH)["message"] == "save não mudou", "sem mudança, nada é enviado de novo")
    ok(A.sky("antes", *CRASH)["message"] == "save em dia", "abrir de novo: save em dia")

    cod = A.sky("codigo-vinculo")
    ok(cod["ok"] and len(cod["codigo"]) == 8, "A gera o código para usar o perfil em outro console")
    ok(B.sky("vincular", "AAAAAAAA")["ok"] is False, "código de vínculo errado é recusado")
    ok("agora é Sky" in B.sky("vincular", cod["codigo"])["message"], "console B passa a usar o perfil de A")
    ok(B.sky("estado")["vinculado"] is True and B.sky("estado")["eu"]["id"] == idA, "estado de B mostra o perfil vinculado")

    r = B.sky("antes", *CRASH)
    ok(r["message"] == "baixado" and B.ler("ps1/Crash Bandicoot.srm") == b"save-1 do console A", "console B baixa o save ao abrir o jogo")
    ok(not os.path.exists(B.save("ps1/Crash Bandicoot 2.srm")), "só o save DESTE jogo veio junto")
    B.escrever("ps1/Crash Bandicoot.srm", b"save-2, jogado no console B")
    ok(B.sky("depois", *CRASH)["message"] == "enviado", "console B joga e envia")
    ok(A.sky("antes", *CRASH)["message"] == "baixado" and A.ler("ps1/Crash Bandicoot.srm") == b"save-2, jogado no console B",
       "console A continua de onde B parou")
    ok(len(os.listdir(os.path.join(A.home, "skystation/nuvem-antes"))) == 1, "o save que estava em A foi guardado antes da troca")

    # conflito: os dois jogaram sem sincronizar
    A.escrever("ps1/Crash Bandicoot.srm", b"save-3A")
    B.escrever("ps1/Crash Bandicoot.srm", b"save-3B")
    ok(B.sky("depois", *CRASH)["message"] == "enviado", "B envia primeiro")
    r = A.sky("antes", *CRASH)
    ok(r.get("conflito") is True and A.ler("ps1/Crash Bandicoot.srm") == b"save-3A", "A detecta o conflito e NÃO mexe no save local")
    ok(A.sky("depois", *CRASH)["message"].startswith("conflito pendente"), "com conflito aberto, nada é enviado por cima")
    ca = A.sky("estado")["conflitos"]
    ok(len(ca) == 1 and ca[0]["titulo"] == "Crash Bandicoot", "o conflito aparece no estado, para a tela mostrar")
    ok(any("Conflito de save em Crash Bandicoot" in e for e in A.eventos()), "e vira aviso na tela")
    ok(A.sky("resolver", ca[0]["chave"], "nuvem")["ok"] and A.ler("ps1/Crash Bandicoot.srm") == b"save-3B", "resolver com a nuvem")
    ok(A.sky("estado")["conflitos"] == [], "conflito resolvido some da lista")
    A.escrever("ps1/Crash Bandicoot.srm", b"save-4A")
    B.escrever("ps1/Crash Bandicoot.srm", b"save-4B")
    B.sky("depois", *CRASH)
    ok(A.sky("depois", *CRASH)["message"] == "conflito", "conflito também é pego na hora de enviar")
    ok(A.sky("resolver", A.sky("estado")["conflitos"][0]["chave"], "console")["ok"], "resolver com o save deste console")
    ok(B.sky("antes", *CRASH)["message"] == "baixado" and B.ler("ps1/Crash Bandicoot.srm") == b"save-4A",
       "B (que não jogou depois do próprio envio) recebe o save escolhido em A")

    # sem internet
    A.escrever("ps1/Crash Bandicoot.srm", b"save-5A, sem internet")
    ok(A.sky("antes", *CRASH, url="http://127.0.0.1:9")["ok"], "sem internet: o jogo abre mesmo assim")
    ok(A.sky("depois", *CRASH, url="http://127.0.0.1:9")["ok"] is False, "sem internet: o envio falha…")
    ok(A.sky("estado")["pendentes"] == 1, "…e fica anotado como pendente")
    ok(A.sky("pendentes")["enviados"] == 1 and A.sky("estado")["pendentes"] == 0, "com a internet de volta, o pendente sobe")
    ok(B.sky("antes", *CRASH)["message"] == "baixado" and B.ler("ps1/Crash Bandicoot.srm") == b"save-5A, sem internet", "e chega ao outro console")

    # PS2 (cartões) e PS3 (pastas do jogo)
    A.escrever("ps2/Mcd001.ps2", os.urandom(20000))
    ok(A.sky("depois", "ps2-gow2", "God of War II", "sky-emu ps2 /roms/gow2.iso")["message"] == "enviado", "PS2: os cartões de memória sobem")
    ok(B.sky("antes", "ps2-outro", "Outro jogo de PS2", "sky-emu ps2 /roms/outro.iso")["message"] == "baixado"
       and B.ler("ps2/Mcd001.ps2") == A.ler("ps2/Mcd001.ps2"), "PS2: qualquer jogo de PS2 traz os cartões no outro console")
    A.escrever("ps3/BLUS30490-SAVE00/PARAM.SFO", b"sfo")
    A.escrever("ps3/BLUS30490-SAVE00/DATA.BIN", os.urandom(5000))
    A.escrever("ps3/BLES00001-OUTRO/DATA.BIN", b"outro jogo")
    PS3 = ("ps3-BLUS30490", "inFamous", "sky-emu ps3 /roms/ps3/inFamous")
    ok(A.sky("depois", *PS3)["message"] == "enviado", "PS3: as pastas de save do jogo sobem")
    ok(B.sky("antes", *PS3)["message"] == "baixado" and B.ler("ps3/BLUS30490-SAVE00/DATA.BIN") == A.ler("ps3/BLUS30490-SAVE00/DATA.BIN")
       and not os.path.exists(B.save("ps3/BLES00001-OUTRO")), "PS3: chegam inteiras, e só as daquele jogo")
    # Xbox 360: só saves (00000001) e o perfil do Xbox (FFFE07D1); DLC e atualizações ficam no console
    XB = "x360/0000000000000000/"
    A.escrever(XB + "FFFE07D1/00010000/0000000000000000/Account", b"perfil do xbox")
    A.escrever(XB + "4D5307E6/00000001/save-mgr/SAVEDATA", os.urandom(3000))
    A.escrever(XB + "4D5307E6/00000002/dlc-gigante/DLC.bin", b"dlc nao sobe")
    A.escrever(XB + "4D5307E6/000B0000/update/TU.bin", b"atualizacao nao sobe")
    MGR = ("x360-mgr", "Metal Gear Rising", "sky-emu x360 /roms/mgr.iso")
    ok(A.sky("depois", *MGR)["message"] == "enviado", "Xbox 360: os saves sobem")
    B.escrever(XB + "4D5307E6/00000002/dlc-gigante/DLC.bin", b"dlc do console B")
    ok(B.sky("antes", "x360-outro", "Outro jogo de 360", "sky-emu x360 /roms/outro.iso")["message"] == "baixado"
       and B.ler(XB + "4D5307E6/00000001/save-mgr/SAVEDATA") == A.ler(XB + "4D5307E6/00000001/save-mgr/SAVEDATA")
       and B.ler(XB + "FFFE07D1/00010000/0000000000000000/Account") == b"perfil do xbox",
       "Xbox 360: save e perfil chegam no outro console")
    ok(not os.path.exists(B.save(XB + "4D5307E6/000B0000/update/TU.bin")), "Xbox 360: atualização de jogo não vai para a nuvem")
    ok(B.ler(XB + "4D5307E6/00000002/dlc-gigante/DLC.bin") == b"dlc do console B", "Xbox 360: a DLC do outro console fica intacta")
    ok(A.sky("antes", "n64-x", "Jogo de terminal", "sky-run-terminal")["message"] == "nada a fazer", "comando que não é emulador é ignorado")
    ok(A.sky("nuvem", "off")["ok"] and A.sky("depois", *CRASH)["message"] == "nada a fazer" and A.sky("nuvem", "on")["ok"], "dá para desligar os saves na nuvem")

    # um .zip malicioso não escreve fora da pasta do jogo
    sys.path.insert(0, BIN)
    import importlib.machinery
    nuvem = importlib.machinery.SourceFileLoader("sky_cloud", os.path.join(BIN, "sky-cloud")).load_module()
    u = nuvem.unidade(*CRASH)
    ok(nuvem.pertence(u, "ps1/Crash Bandicoot.srm") and not nuvem.pertence(u, "ps1/../../.bashrc")
       and not nuvem.pertence(u, "/etc/passwd") and not nuvem.pertence(u, "ps2/Mcd001.ps2"), "caminhos de fora da unidade são recusados")
    ux = nuvem.unidade(*MGR)
    ok(nuvem.pertence(ux, "x360/0000000000000000/4D5307E6/00000001/a/b") and not nuvem.pertence(ux, "x360/0000000000000000/4D5307E6/00000002/dlc"),
       "Xbox 360: um .zip não consegue gravar DLC nem nada fora dos saves")

    # ------------------------------------------------------------ troféus e saída
    req = urllib.request.Request(URL + "/api/trofeus", headers={"Authorization": "Bearer " + A.token(), "X-Perfil": "p1"})
    ok(json.load(urllib.request.urlopen(req))["trofeus"] == [], "A ainda não tem troféus no servidor")
    ok(B.sky("desvincular")["ok"] and B.sky("estado")["eu"]["id"] == idB, "B desfaz o vínculo e volta ao próprio perfil")
    req = urllib.request.Request(URL + "/api/trofeus", headers={"Authorization": "Bearer " + B.token(), "X-Perfil": "p1"})
    ok(len(json.load(urllib.request.urlopen(req))["trofeus"]) == 1, "o troféu de B está no servidor")
    # ------------------------------------------------------------ conta pessoal e ícone
    import secrets
    ID = "teste_" + secrets.token_hex(3)
    ok(A.sky("conta")["usuario"] is None, "o perfil de A ainda não tem conta")
    ok(A.sky("conta-criar", ID, senha="123")["ok"] is False, "senha curta é recusada")
    ok(A.sky("conta-criar", ID)["ok"] is False, "sem senha é recusado")
    r = A.sky("conta-criar", ID.upper(), senha="senha-do-A")
    ok(r["ok"] and r["usuario"] == ID, "A cria a conta pessoal")
    CONTAS.append([ID, "senha-do-A"])
    ok(A.sky("conta-criar", ID + "x", senha="senha-do-A")["ok"] is False, "não cria duas contas no mesmo perfil")
    ok(A.sky("icone", "cometa")["avatar"] == "cometa", "troca o ícone pelo nome")
    ok(A.sky("icone", "proximo")["avatar"] != "cometa", "A no ícone passa para o próximo")
    ok(A.sky("icone", "dragao")["ok"] is False, "ícone que não existe é recusado")
    A.sky("icone", "robo")
    ok(A.sky("uma-vez", prog="sky-net")["ok"] and A.net()["eu"]["avatar"] == "robo" and A.net()["eu"]["usuario"] == ID,
       "o net.json leva ID e ícone (o launcher desenha)")
    B.sky("uma-vez", prog="sky-net")
    ok(B.net()["amigos"][0]["avatar"] == "robo", "o amigo B vê o ícone de A")
    ok(B.sky("conta-entrar", ID, senha="errada!")["ok"] is False, "entrar com senha errada é recusado")
    r = B.sky("conta-entrar", ID, senha="senha-do-A")
    ok(r["ok"] and B.sky("estado")["eu"]["usuario"] == ID, "B entra com a conta de A (ID e senha)")
    ok(B.sky("conta-senha", senha="senha-nova")["ok"], "o console troca a senha da conta (esqueci a senha)")
    CONTAS[-1][1] = "senha-nova"
    ok(B.sky("desvincular")["ok"] and B.sky("estado")["eu"]["id"] == idB, "B volta ao próprio perfil")

    ok(A.sky("sair")["ok"] and A.sky("estado")["conectado"] is False, "sair da rede")
    print(f"\nTudo certo: {passos} verificações.")
except AssertionError as e:
    print("\nFALHOU: " + str(e))
    sys.exit(1)
finally:
    for tok in TOKENS or [c.token() for c in (A, B) if os.path.exists(os.path.join(c.home, ".config/skystation/rede.json"))]:
        try:   # remove os consoles de teste do servidor
            urllib.request.urlopen(urllib.request.Request(URL + "/api/eu", method="DELETE",
                                                          headers={"Authorization": "Bearer " + tok}), timeout=20)
        except Exception:
            pass
    for usuario, senha in CONTAS:   # contas sobrevivem ao console: exclui pelo site
        try:
            cab = {"Content-Type": "application/json"}
            r = urllib.request.urlopen(urllib.request.Request(
                URL + "/api/web/entrar", data=json.dumps({"usuario": usuario, "senha": senha}).encode(),
                headers=cab, method="POST"), timeout=20)
            # o cookie é "Secure" (só HTTPS); o teste roda em HTTP local, então vai à mão
            cookie = r.headers.get("Set-Cookie", "").split(";")[0]
            urllib.request.urlopen(urllib.request.Request(
                URL + "/api/web/eu", data=json.dumps({"senha": senha}).encode(),
                headers={**cab, "Cookie": cookie}, method="DELETE"), timeout=20)
        except Exception as e:
            print("FALHOU: não consegui excluir a conta de teste", usuario, e)
            sys.exit(1)
    shutil.rmtree(RAIZ, ignore_errors=True)
