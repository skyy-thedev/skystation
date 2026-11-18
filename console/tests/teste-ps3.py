#!/usr/bin/env python3
"""Teste do online do PS3 (RPCN, Fase 11.5): conta guardada no rpcn.yml e a seção Net do config.yml
do RPCS3. Não precisa de rede nem do RPCS3.

    python3 console/tests/teste-ps3.py
"""
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")
RAIZ = tempfile.mkdtemp(prefix="skyps3-")
RP = os.path.join(RAIZ, "rpcs3")
passos = 0


def ok(cond, msg):
    global passos
    if not cond:
        raise AssertionError(msg)
    passos += 1
    print("  ok  " + msg, flush=True)


def ps3(*args, senha=None):
    env = dict(os.environ, HOME=RAIZ, SKY_RPCS3_DIR=RP)
    env.pop("SKY_SENHA", None)
    if senha is not None:
        env["SKY_SENHA"] = senha
    r = subprocess.run([sys.executable, os.path.join(BIN, "sky-ps3"), *args], env=env,
                       capture_output=True, text=True, timeout=30)
    try:
        return json.loads(r.stdout.strip().splitlines()[-1])
    except (IndexError, ValueError):
        raise AssertionError(f"sky-ps3 {args}: saída inesperada\n{r.stdout}\n{r.stderr}")


def ler(nome):
    with open(os.path.join(RP, nome)) as f:
        return f.read()


try:
    ok(ps3("rpcn") == {"ok": True, "conta": False, "npid": ""}, "sem conta RPCN no começo")
    ok(not ps3("rpcn-entrar", "sk", "ABCDEFGH12345678", senha="x")["ok"], "ID curto demais é recusado")
    ok(not ps3("rpcn-entrar", "skystation", "ABCDEFGH12345678")["ok"], "sem senha é recusado")
    ok(not ps3("rpcn-entrar", "skystation", "curto", senha="x")["ok"], "token errado é recusado")
    ok(not os.path.exists(os.path.join(RP, "rpcn.yml")), "nada é gravado quando a conta é recusada")

    # config.yml que o RPCS3 já tinha: as outras seções e chaves ficam como estavam
    os.makedirs(RP)
    with open(os.path.join(RP, "config.yml"), "w") as f:
        f.write("Core:\n  PPU Decoder: Recompiler (LLVM)\nNet:\n  Internet enabled: Disconnected\n"
                "  IP address: 0.0.0.0\n  PSN status: Disconnected\n  PSN Country: br\nMiscellaneous:\n"
                "  Exit RPCS3 when process finishes: true\n")
    senha = 'se:nha "difícil" #1'
    r = ps3("rpcn-entrar", "skystation", "abcd-efgh-1234-5678", senha=senha)
    ok(r["ok"] and r["npid"] == "skystation", "conta RPCN aceita (token com traços e minúsculas)")
    yml = ler("rpcn.yml")
    ok('NPID: "skystation"' in yml and 'Token: "ABCDEFGH12345678"' in yml and "Host: \"np.rpcs3.net\"" in yml
       and "Official RPCN Server|np.rpcs3.net" in yml, "rpcn.yml no formato do RPCS3")
    ok(json.loads(yml.split("Password: ", 1)[1].splitlines()[0]) == senha, "senha com : # e aspas guardada inteira")
    ok(stat.S_IMODE(os.stat(os.path.join(RP, "rpcn.yml")).st_mode) == 0o600, "rpcn.yml só o dono lê")
    cfg = ler("config.yml")
    ok("  Internet enabled: Connected" in cfg and "  PSN status: RPCN" in cfg, "internet e RPCN ligados no RPCS3")
    ok("  PPU Decoder: Recompiler (LLVM)" in cfg and "  PSN Country: br" in cfg and "  IP address: 0.0.0.0" in cfg
       and "Exit RPCS3 when process finishes" in cfg and cfg.count("Net:") == 1, "o resto do config.yml continua igual")
    ok(ps3("rpcn") == {"ok": True, "conta": True, "npid": "skystation"}, "estado mostra a conta")

    # o RPCS3 regrava o rpcn.yml do jeito dele (sem aspas, com IPv6): a gente continua lendo
    with open(os.path.join(RP, "rpcn.yml"), "w") as f:
        f.write("Version: 2\nHost: np.rpcs3.net\nNPID: skystation\nPassword: 'it''s'\nToken: ABCDEFGH12345678\n"
                "Hosts: Official RPCN Server|np.rpcs3.net\nExperimental IPv6 support: true\n")
    ok(ps3("rpcn")["conta"], "lê o rpcn.yml gravado pelo próprio RPCS3")

    r = ps3("rpcn-sair")
    ok(r["ok"] and not ps3("rpcn")["conta"], "sair apaga a conta deste console")
    yml = ler("rpcn.yml")
    ok("it's" not in yml and "ABCDEFGH" not in yml and "Experimental IPv6 support: true" in yml,
       "senha e token somem; as outras opções ficam")
    cfg = ler("config.yml")
    ok("  PSN status: Disconnected" in cfg and "  Internet enabled: Disconnected" in cfg,
       "sem conta o RPCS3 não tenta entrar no RPCN")

    # config.yml sem a seção Net (o que o SkyStation criava antes): ganha a seção no fim
    with open(os.path.join(RP, "config.yml"), "w") as f:
        f.write("Miscellaneous:\n  Exit RPCS3 when process finishes: true\n")
    ps3("rpcn-entrar", "outra_conta", "ZZZZZZZZZZZZZZZZ", senha="123456")
    cfg = ler("config.yml")
    ok(cfg.endswith("Net:\n  Internet enabled: Connected\n  PSN status: RPCN\n")
       and cfg.startswith("Miscellaneous:\n  Exit RPCS3"), "seção Net criada quando não existe")
    print(f"\nTudo certo: {passos} verificações.")
except AssertionError as e:
    print("\nFALHOU: " + str(e))
    sys.exit(1)
finally:
    shutil.rmtree(RAIZ, ignore_errors=True)
