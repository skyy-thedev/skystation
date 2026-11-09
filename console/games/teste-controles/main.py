"""SkyStation: Teste de Controles (ferramenta do launcher).

Prova que a cadeia toda funciona: boot -> login automático -> cage -> app em tela cheia.
Também já testa os controles (vai ser útil na Fase 4).

Teclas:
  ESC         sai do app (o console reabre sozinho)
  P           desliga o sistema
  Start+Select no controle (segurar 2 s) também desliga
"""
import math
import random
import subprocess
import sys
import time

import pygame

CYAN = (79, 209, 255)
WHITE = (238, 242, 255)
MUTED = (148, 163, 200)
DIM = (90, 104, 145)
PANEL = (18, 26, 58)


def font(size, bold=False):
    return pygame.font.SysFont("dejavusans", size, bold=bold)


def make_background(w, h):
    bg = pygame.Surface((w, h))
    top, bot = (6, 9, 24), (16, 22, 52)
    for y in range(h):
        k = y / max(1, h - 1)
        c = tuple(int(top[i] * (1 - k) + bot[i] * k) for i in range(3))
        pygame.draw.line(bg, c, (0, y), (w, y))
    return bg


def main():
    pygame.init()
    pygame.joystick.init()
    screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    pygame.display.set_caption("SkyStation")
    pygame.mouse.set_visible(False)
    W, H = screen.get_size()
    s = H / 1080  # escala para qualquer resolução

    bg = make_background(W, H)
    rnd = random.Random(7)
    stars = [(rnd.random() * W, rnd.random() * H, rnd.choice([1, 1, 2, 2, 3]),
              rnd.random() * 6.28, 0.5 + rnd.random() * 1.5, 6 + rnd.random() * 14) for _ in range(220)]

    f_logo = font(int(150 * s), bold=True)
    f_sub = font(int(34 * s))
    f_txt = font(int(28 * s))
    f_small = font(int(22 * s))

    logo_a = f_logo.render("Sky", True, WHITE)
    logo_b = f_logo.render("Station", True, CYAN)
    sub = f_sub.render("Teste de controles", True, MUTED)

    joys = {}
    last_input = "nenhuma ainda: aperte qualquer tecla ou botão"
    start = time.time()
    combo_since = None
    clock = pygame.time.Clock()

    def poweroff():
        pygame.quit()
        subprocess.run(["systemctl", "poweroff"])
        sys.exit(0)

    while True:
        t = time.time() - start
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                pygame.quit()
                sys.exit(0)
            elif ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    pygame.quit()
                    sys.exit(0)
                if ev.key == pygame.K_p:
                    poweroff()
                last_input = f"teclado: {pygame.key.name(ev.key)}"
            elif ev.type == pygame.JOYDEVICEADDED:
                j = pygame.joystick.Joystick(ev.device_index)
                joys[j.get_instance_id()] = j
                last_input = f"controle conectado: {j.get_name()}"
            elif ev.type == pygame.JOYDEVICEREMOVED:
                j = joys.pop(ev.instance_id, None)
                last_input = "controle desconectado" + (f": {j.get_name()}" if j else "")
            elif ev.type == pygame.JOYBUTTONDOWN:
                last_input = f"controle: botão {ev.button}"
                if ev.button == 1 and combo_since is None:  # B volta ao launcher
                    pygame.quit()
                    sys.exit(0)
            elif ev.type == pygame.JOYHATMOTION and ev.value != (0, 0):
                last_input = f"controle: direcional {ev.value}"
            elif ev.type == pygame.JOYAXISMOTION and abs(ev.value) > 0.6:
                last_input = f"controle: eixo {ev.axis} = {ev.value:+.2f}"

        # Start+Select segurados por 2 s desligam (botões 6 e 7 no padrão Xbox/SDL)
        held = any(j.get_numbuttons() > 7 and j.get_button(6) and j.get_button(7) for j in joys.values())
        if held:
            combo_since = combo_since or time.time()
            if time.time() - combo_since > 2:
                poweroff()
        else:
            combo_since = None

        # ---------- desenho ----------
        screen.blit(bg, (0, 0))
        for sx, sy, r, ph, sp, drift in stars:
            x = (sx - t * drift) % W
            a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * sp + ph))
            c = tuple(int(v * a) for v in (200, 220, 255))
            pygame.draw.circle(screen, c, (int(x), int(sy)), r)

        fade = min(1.0, t / 1.2)
        lw = logo_a.get_width() + logo_b.get_width()
        lx = (W - lw) // 2
        ly = int(H * 0.26)
        for surf, x in ((logo_a, lx), (logo_b, lx + logo_a.get_width())):
            surf.set_alpha(int(255 * fade))
            screen.blit(surf, (x, ly))
        sub.set_alpha(int(255 * fade))
        screen.blit(sub, ((W - sub.get_width()) // 2, ly + logo_a.get_height() + int(10 * s)))

        # painel de status
        pw, ph = int(900 * s), int(230 * s)
        px, py = (W - pw) // 2, int(H * 0.58)
        panel = pygame.Surface((pw, ph), pygame.SRCALPHA)
        pygame.draw.rect(panel, PANEL + (220,), panel.get_rect(), border_radius=int(22 * s))
        pygame.draw.rect(panel, CYAN + (110,), panel.get_rect(), width=2, border_radius=int(22 * s))
        screen.blit(panel, (px, py))
        names = [j.get_name() for j in joys.values()]
        lines = [
            (f"Controles conectados: {len(names)}", WHITE),
            (("   " + " · ".join(names)) if names else "   conecte um controle USB para testar", MUTED),
            (f"Última entrada: {last_input}", CYAN),
        ]
        for i, (txt, col) in enumerate(lines):
            screen.blit(f_txt.render(txt, True, col), (px + int(40 * s), py + int(34 * s) + i * int(58 * s)))

        clock_txt = f_txt.render(time.strftime("%H:%M"), True, MUTED)
        screen.blit(clock_txt, (W - clock_txt.get_width() - int(50 * s), int(40 * s)))

        hint = f_small.render("ESC / B  voltar ao SkyStation     P  desligar", True, DIM)
        screen.blit(hint, ((W - hint.get_width()) // 2, H - int(70 * s)))

        pygame.display.flip()
        clock.tick(60)


if __name__ == "__main__":
    main()
