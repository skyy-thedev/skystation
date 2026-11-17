"""SkyStation: ajuda para rodar dentro do gamescope (Fase 9.3).

O gamescope mostra UMA janela de jogo/app por vez, mas desenha por cima de tudo as janelas X11
marcadas com a propriedade GAMESCOPE_EXTERNAL_OVERLAY = 1 (é assim que o Steam do Steam Deck põe
avisos e o menu por cima dos jogos). Elas não recebem o foco: o jogo continua com o controle.
"""
import os
import shutil
import subprocess


def ativo():
    return os.environ.get("SKY_COMPOSITOR") == "gamescope"


def marcar_overlay(xid):
    """Marca a janela X11 `xid` como overlay do gamescope. Devolve True se deu certo."""
    if not xid or not shutil.which("xprop"):
        return False
    try:
        r = subprocess.run(["xprop", "-id", str(int(xid)), "-f", "GAMESCOPE_EXTERNAL_OVERLAY", "32c",
                            "-set", "GAMESCOPE_EXTERNAL_OVERLAY", "1"], capture_output=True, timeout=3)
        return r.returncode == 0
    except (OSError, subprocess.SubprocessError, ValueError):
        return False
