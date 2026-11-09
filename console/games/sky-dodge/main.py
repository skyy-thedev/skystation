"""Sky Dodge: primeiro jogo autoral do SkyStation.

Desvie dos meteoros. Funciona com teclado ou controle.
  Mover:    setas / A-D / direcional / analógico
  Começar:  Enter / Espaço / botão A
  Sair:     Esc / botão B / Start  (volta para o launcher)
"""
import math
import random
import sys

import pygame

CYAN = (79, 209, 255)
WHITE = (238, 242, 255)
MUTED = (148, 163, 200)
PINK = (244, 114, 182)
AMBER = (251, 191, 36)


def main():
    pygame.init()
    pygame.joystick.init()
    screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    pygame.display.set_caption("Sky Dodge")
    pygame.mouse.set_visible(False)
    W, H = screen.get_size()
    s = H / 720
    clock = pygame.time.Clock()
    f_big = pygame.font.Font(None, int(110 * s))
    f_mid = pygame.font.Font(None, int(44 * s))
    f_small = pygame.font.Font(None, int(32 * s))

    rnd = random.Random()
    stars = [(rnd.random() * W, rnd.random() * H, rnd.choice([1, 1, 2]), 20 + rnd.random() * 60) for _ in range(150)]
    joys = {}

    best = 0
    state = "title"  # title | play | over
    px, score, speed, meteors, spawn_t = W / 2, 0.0, 1.0, [], 0.0

    def reset():
        return W / 2, 0.0, 1.0, [], 0.0

    while True:
        dt = clock.tick(60) / 1000.0
        start_pressed = False
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                return
            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    return
                if ev.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER):
                    start_pressed = True
            elif ev.type == pygame.JOYDEVICEADDED:
                j = pygame.joystick.Joystick(ev.device_index)
                joys[j.get_instance_id()] = j
            elif ev.type == pygame.JOYDEVICEREMOVED:
                joys.pop(ev.instance_id, None)
            elif ev.type == pygame.JOYBUTTONDOWN:
                if ev.button == 0:
                    start_pressed = True
                elif ev.button in (1, 7):  # B ou Start
                    return

        # entrada horizontal: teclado + direcional + analógico
        keys = pygame.key.get_pressed()
        mx = 0.0
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            mx -= 1
        if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            mx += 1
        for j in joys.values():
            if j.get_numhats():
                mx += j.get_hat(0)[0]
            if j.get_numaxes():
                ax = j.get_axis(0)
                if abs(ax) > 0.25:
                    mx += ax
        mx = max(-1.0, min(1.0, mx))

        if state in ("title", "over") and start_pressed:
            px, score, speed, meteors, spawn_t = reset()
            state = "play"

        if state == "play":
            px = max(30 * s, min(W - 30 * s, px + mx * 620 * s * dt))
            score += dt * 10
            speed = 1.0 + score / 60
            spawn_t -= dt
            if spawn_t <= 0:
                spawn_t = max(0.12, 0.55 - score / 300)
                r = rnd.uniform(14, 34) * s
                meteors.append([rnd.uniform(r, W - r), -r, r, rnd.uniform(220, 320) * s, rnd.uniform(0, 6.28)])
            for m in meteors:
                m[1] += m[3] * speed * dt
                m[4] += dt * 2
            meteors = [m for m in meteors if m[1] < H + 60 * s]
            py = H - 90 * s
            for m in meteors:
                if math.hypot(m[0] - px, m[1] - py) < m[2] + 18 * s:
                    state = "over"
                    best = max(best, int(score))
                    break

        # ---------- desenho ----------
        screen.fill((6, 9, 24))
        for i, (sx, sy, r, sp) in enumerate(stars):
            y = (sy + (pygame.time.get_ticks() / 1000) * sp * (speed if state == "play" else 0.4)) % H
            pygame.draw.circle(screen, (150, 170, 220), (int(sx), int(y)), r)

        for m in meteors:
            pygame.draw.circle(screen, (120, 84, 60), (int(m[0]), int(m[1])), int(m[2]))
            pygame.draw.circle(screen, (165, 118, 82), (int(m[0] - m[2] * 0.25), int(m[1] - m[2] * 0.25)), int(m[2] * 0.45))
            for k in range(1, 4):  # rastro de fogo acima do meteoro
                pygame.draw.circle(screen, (200 - k * 40, 110 - k * 25, 40), (int(m[0]), int(m[1] - m[2] - k * 9 * s)), max(1, int(m[2] * (0.5 - k * 0.12))))

        if state != "title":
            py = H - 90 * s
            pts = [(px, py - 26 * s), (px - 22 * s, py + 20 * s), (px, py + 10 * s), (px + 22 * s, py + 20 * s)]
            pygame.draw.polygon(screen, CYAN, pts)
            flame = 10 + 6 * math.sin(pygame.time.get_ticks() / 40)
            pygame.draw.polygon(screen, PINK, [(px - 8 * s, py + 16 * s), (px + 8 * s, py + 16 * s), (px, py + (16 + flame) * s)])
            sc = f_mid.render(f"{int(score)}", True, WHITE)
            screen.blit(sc, (W / 2 - sc.get_width() / 2, 24 * s))

        def center(surf, y):
            screen.blit(surf, (W / 2 - surf.get_width() / 2, y))

        if state == "title":
            center(f_big.render("SKY DODGE", True, CYAN), H * 0.30)
            center(f_mid.render("desvie dos meteoros", True, MUTED), H * 0.30 + 100 * s)
            center(f_small.render("A / Enter  começar        B / Esc  voltar ao SkyStation", True, MUTED), H * 0.72)
        elif state == "over":
            center(f_big.render("FIM DE JOGO", True, PINK), H * 0.30)
            center(f_mid.render(f"pontos: {int(score)}    recorde: {best}", True, WHITE), H * 0.30 + 100 * s)
            center(f_small.render("A / Enter  de novo        B / Esc  voltar", True, MUTED), H * 0.72)

        pygame.display.flip()


if __name__ == "__main__":
    main()
    pygame.quit()
    sys.exit(0)
