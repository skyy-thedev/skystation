#!/usr/bin/env python3
"""Teste dos benchmarks (Fase 11.7): sky-bench com um log falso do MangoHud e sky-sysmon.
Não precisa do MangoHud nem do console.

    python3 console/tests/teste-bench.py
"""
import csv
import os
import subprocess
import sys
import tempfile
import time

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")
RAIZ = tempfile.mkdtemp(prefix="skybench-")
passos = 0


def ok(cond, msg):
    global passos
    if not cond:
        raise AssertionError(msg)
    passos += 1
    print("  ok  " + msg, flush=True)


def log_falso(path, trechos):
    """trechos: lista de (segundos, fps, temp, mhz). Uma linha por quadro, como o MangoHud."""
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["os", "cpu", "gpu", "ram", "kernel", "driver", "cpuscheduler"])
        w.writerow(["SkyStation", "teste", "teste", "1", "1", "", ""])
        w.writerow(["fps", "frametime", "cpu_load", "cpu_power", "gpu_load", "cpu_temp", "gpu_temp", "gpu_core_clock",
                    "gpu_mem_clock", "gpu_vram_used", "gpu_power", "ram_used", "swap_used", "process_rss", "cpu_mhz",
                    "elapsed"])
        t = 1e9
        for segs, fps, temp, mhz in trechos:
            fim = t + segs * 1e9
            while t < fim:
                ft = 1000.0 / fps
                w.writerow([fps, ft, 50, 10, 40, temp, 70, 1800, 85, 0.9, 20, 3.5, 0, 0, mhz, int(t)])
                t += ft * 1e6
        # um engasgo isolado de 200 ms no meio de quadros normais
        w.writerow([5, 200, 50, 10, 40, 70, 70, 1800, 85, 0.9, 20, 3.5, 0, 0, 4000, int(t + 200e6)])
        t += 200e6
        for _ in range(60):
            t += 16.7e6
            w.writerow([60, 16.7, 50, 10, 40, 70, 70, 1800, 85, 0.9, 20, 3.5, 0, 0, 4000, int(t)])


def bench(*args, env=None):
    r = subprocess.run([sys.executable, os.path.join(BIN, "sky-bench"), *args], capture_output=True, text=True,
                       timeout=60, env=env)
    ok(r.returncode == 0, f"sky-bench {args[0]} terminou sem erro ({r.stderr.strip()[:200]})")
    return r.stdout


print("sky-bench")
pasta = os.path.join(RAIZ, "benchmarks")
os.makedirs(pasta)
# resumo.csv no formato antigo (Fase 8.2): tem de virar resumo-antigo.csv
with open(os.path.join(pasta, "resumo.csv"), "w") as f:
    f.write("data;jogo;id;emulador;minutos;fps_mediano\n2026-11-16 00:12;Velho;x;rpcs3;1;30\n")
inicio = int(time.time()) - 5
log_falso(os.path.join(pasta, "rpcs3_2026-11-20_10-00-00.csv"),
          [(120, 60, 70, 4000), (60, 20, 97, 3000)])
run = os.path.join(RAIZ, "run", "skystation")
os.makedirs(run)
with open(os.path.join(run, "game.ajustes"), "w") as f:
    f.write("RPCS3 BCUS98111: Frame limit: 30\n")
env = dict(os.environ, XDG_RUNTIME_DIR=os.path.join(RAIZ, "run"))
bench("fechar", pasta, str(inicio), "ps3-BCUS98111", "God of War III", env=env)
nomes = os.listdir(pasta)
ok(any("· God of War III (rpcs3).csv" in n for n in nomes), "o log ganhou o nome do jogo")
ok("resumo-antigo.csv" in nomes, "o resumo.csv antigo foi guardado como resumo-antigo.csv")
with open(os.path.join(pasta, "resumo.csv"), encoding="utf-8") as f:
    linhas = list(csv.DictReader(f, delimiter=";"))
ok(len(linhas) == 1, "uma linha nova no resumo.csv")
r = linhas[0]
ok(2.9 <= float(r["minutos"]) <= 3.1, f"tempo jogado ~3 min ({r['minutos']})")
# 2 min a 60 + 1 min a 20 = (7200 + 1200) / 180 s ≈ 46,7 FPS (a mediana das linhas daria 60)
ok(45 <= float(r["fps_medio"]) <= 48, f"FPS médio ponderado pelo tempo ({r['fps_medio']})")
ok(19 <= float(r["fps_min"]) <= 21 and 59 <= float(r["fps_max"]) <= 61, f"pior e melhor segundo ({r['fps_min']}, {r['fps_max']})")
ok(float(r["fps_1pct_low"]) <= 21, f"1% low pega o trecho lento ({r['fps_1pct_low']})")
ok(float(r["engasgos_min"]) > 0, f"o engasgo de 200 ms foi contado ({r['engasgos_min']}/min)")
ok(r["meta"] == "60" and 30 <= int(r["pct_abaixo_meta"]) <= 36, f"tempo abaixo de 60 FPS ~1/3 ({r['pct_abaixo_meta']}%)")
ok(r["gargalo"] == "temperatura", f"gargalo: temperatura (97 °C e clock caindo) — veio {r['gargalo']}")
ok("Frame limit" in r["ajustes"], "ajustes do perfil anotados")
det = os.path.join(pasta, "detalhes")
ok(os.path.isdir(det) and any(n.endswith(".txt") for n in os.listdir(det)), "detalhes em blocos de 5 min")
txt = open(os.path.join(det, os.listdir(det)[0]), encoding="utf-8").read()
ok("travadas acima de 50 ms (1)" in txt and "200 ms" in txt, "a travada de 200 ms aparece com a hora nos detalhes")
saida = bench("relatorio", pasta)
ok("1 partidas" in saida, "relatório refeito com os CSVs da pasta")

print("sky-sysmon")
r = subprocess.run([sys.executable, os.path.join(BIN, "sky-sysmon"), "uma-vez"], capture_output=True, text=True,
                   timeout=30)
ok(r.returncode == 0 and "cpu_pct" in r.stdout, f"uma amostra do sistema ({r.stderr.strip()[:200]})")
sis = os.path.join(pasta, "sistema")
os.makedirs(sis)
with open(os.path.join(sis, "sistema-2026-11-20.csv"), "w", newline="", encoding="utf-8") as f:
    sys.path.insert(0, BIN)
    import importlib.machinery
    import importlib.util
    ld = importlib.machinery.SourceFileLoader("sysmon", os.path.join(BIN, "sky-sysmon"))
    spec = importlib.util.spec_from_loader("sysmon", ld)
    sm = importlib.util.module_from_spec(spec)
    ld.exec_module(sm)
    w = csv.DictWriter(f, fieldnames=sm.CAB, delimiter=";")
    w.writeheader()
    for i in range(30):
        base = {k: 0 for k in sm.CAB}
        base.update(hora="10:00:%02d" % i, estado="menu" if i < 20 else "jogo", fps_menu=58 if i < 20 else "",
                    ms_pior_menu=30, cpu_pct=12, cpu_temp=60, ram_mb=900, cpu_menu=9.5, mb_menu=180, cpu_rede=0.4,
                    mb_rede=25)
        w.writerow(base)
r = subprocess.run([sys.executable, os.path.join(BIN, "sky-sysmon"), "resumo", pasta], capture_output=True,
                   text=True, timeout=30)
ok(r.returncode == 0 and "2 linhas" in r.stdout, f"resumo do sistema por estado ({r.stdout.strip()} {r.stderr[:200]})")
with open(os.path.join(sis, "resumo-sistema.csv"), encoding="utf-8") as f:
    rs = list(csv.DictReader(f, delimiter=";"))
menu = next(x for x in rs if x["estado"] == "menu")
ok(menu["fps_menu_mediano"] == "58.0" and menu["mais_cpu"].startswith("menu 9.5%"), f"menu: FPS e quem gasta CPU ({menu})")

print(f"\n{passos} verificações ok")
