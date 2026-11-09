#!/usr/bin/env python3
"""SkyStation: tela do menu Home (só desenha).

Quem lê os controles é o sky-home.py (que "segura" todos os dispositivos enquanto o menu
está aberto); ele manda para cá, pela entrada padrão:
    sel <n>   -> item selecionado
    quit      -> fechar
"""
import queue
import sys
import threading

import pygame

CYAN = (79, 209, 255)
WHITE = (238, 242, 255)
MUTED = (148, 163, 200)
DIM = (90, 104, 145)
ITEMS = ["Voltar ao jogo", "Fechar jogo"]


def reader(q):
    for line in sys.stdin:
        q.put(line.strip())
    q.put("quit")


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else "Jogo"
    q = queue.Queue()
    threading.Thread(target=reader, args=(q,), daemon=True).start()

    # Só vídeo e fontes: nada de áudio ou joystick (os controles estão com o sky-home).
    pygame.display.init()
    pygame.font.init()
    screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    pygame.display.set_caption("SkyStation - pausa")
    pygame.mouse.set_visible(False)
    W, H = screen.get_size()
    s = H / 720
    f_tag = pygame.font.Font(None, int(26 * s))
    f_title = pygame.font.Font(None, int(56 * s))
    f_item = pygame.font.Font(None, int(40 * s))
    f_hint = pygame.font.Font(None, int(24 * s))
    clock = pygame.time.Clock()
    sel = 0

    while True:
        try:
            while True:
                cmd = q.get_nowait()
                if cmd == "quit":
                    pygame.quit()
                    return
                if cmd.startswith("sel "):
                    sel = int(cmd.split()[1]) % len(ITEMS)
        except queue.Empty:
            pass
        except ValueError:
            pass
        pygame.event.pump()

        screen.fill((6, 9, 24))
        pw, ph = int(560 * s), int(290 * s)
        px, py = (W - pw) // 2, (H - ph) // 2
        pygame.draw.rect(screen, (18, 26, 58), (px, py, pw, ph), border_radius=int(22 * s))
        pygame.draw.rect(screen, CYAN, (px, py, pw, ph), width=2, border_radius=int(22 * s))

        tag = f_tag.render("PAUSADO", True, CYAN)
        screen.blit(tag, (px + int(40 * s), py + int(34 * s)))
        name = title if len(title) <= 28 else title[:27] + "…"
        screen.blit(f_title.render(name, True, WHITE), (px + int(40 * s), py + int(62 * s)))

        for i, item in enumerate(ITEMS):
            y = py + int(150 * s) + i * int(62 * s)
            on = i == sel
            if on:
                pygame.draw.rect(screen, (30, 44, 90), (px + int(26 * s), y - int(10 * s), pw - int(52 * s), int(52 * s)),
                                 border_radius=int(14 * s))
            txt = f_item.render(item, True, CYAN if on else MUTED)
            screen.blit(txt, (px + int(48 * s), y))

        hint = f_hint.render("A  confirmar      B / Home  voltar ao jogo", True, DIM)
        screen.blit(hint, (W // 2 - hint.get_width() // 2, py + ph + int(24 * s)))
        pygame.display.flip()
        clock.tick(30)


if __name__ == "__main__":
    main()
