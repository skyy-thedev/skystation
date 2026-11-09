"""Sky Snake: segundo jogo autoral do SkyStation.

Coma as estrelas, cresça e não bata nas paredes nem em você mesmo.
  Mover:    setas / WASD / direcional / analógico
  Começar:  Enter / Espaço / botão A
  Sair:     Esc / botão B   (ou o botão Home: pausa com menu)
O recorde fica salvo em ~/skystation/saves/sky-snake.json.
"""
import json
import math
import os
import random
import sys

import pygame

CYAN = (79, 209, 255)
WHITE = (238, 242, 255)
MUTED = (148, 163, 200)
PINK = (244, 114, 182)
AMBER = (251, 191, 36)
BG = (6, 9, 24)
GRID = (14, 20, 46)

COLS, ROWS = 32, 18
SAVE = os.path.expanduser("~/skystation/saves/sky-snake.json")


def load_best():
    try:
        with open(SAVE) as f:
            return int(json.load(f).get("best", 0))
    except (OSError, ValueError):
        return 0


def save_best(best):
    try:
        os.makedirs(os.path.dirname(SAVE), exist_ok=True)
        tmp = SAVE + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"best": best}, f)
        os.replace(tmp, SAVE)  # troca atômica: desligar no meio não corrompe o recorde
    except OSError:
        pass


class Game:
    def __init__(self):
        self.rnd = random.Random()
        self.reset()

    def reset(self):
        cx, cy = COLS // 2, ROWS // 2
        self.snake = [(cx - i, cy) for i in range(4)]  # cabeça primeiro
        self.dir = (1, 0)
        self.queue = []   # curvas pedidas entre um passo e outro (não perde apertos rápidos)
        self.grow = 0
        self.score = 0
        self.step_time = 0.13
        self.acc = 0.0
        self.food = self.new_food()

    def new_food(self):
        free = {(x, y) for x in range(COLS) for y in range(ROWS)} - set(self.snake)
        return self.rnd.choice(sorted(free))

    def turn(self, d):
        last = self.queue[-1] if self.queue else self.dir
        if d != last and (d[0] != -last[0] or d[1] != -last[1]) and len(self.queue) < 3:
            self.queue.append(d)

    def update(self, dt):
        """Avança a cobra. Retorna False quando bate."""
        self.acc += dt
        while self.acc >= self.step_time:
            self.acc -= self.step_time
            if self.queue:
                self.dir = self.queue.pop(0)
            hx, hy = self.snake[0]
            head = (hx + self.dir[0], hy + self.dir[1])
            body = self.snake[:-1] if self.grow == 0 else self.snake
            if not (0 <= head[0] < COLS and 0 <= head[1] < ROWS) or head in body:
                return False
            self.snake.insert(0, head)
            if head == self.food:
                self.score += 1
                self.grow += 2
                self.step_time = max(0.055, self.step_time * 0.97)
                self.food = self.new_food()
            if self.grow:
                self.grow -= 1
            else:
                self.snake.pop()
        return True


def main():
    pygame.init()
    pygame.joystick.init()
    screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    pygame.display.set_caption("Sky Snake")
    pygame.mouse.set_visible(False)
    W, H = screen.get_size()
    cell = min(W // COLS, (H - int(H * 0.1)) // ROWS)
    ox = (W - cell * COLS) // 2
    oy = (H - cell * ROWS) // 2 + int(H * 0.03)
    s = H / 720
    f_big = pygame.font.Font(None, int(110 * s))
    f_mid = pygame.font.Font(None, int(44 * s))
    f_small = pygame.font.Font(None, int(30 * s))
    clock = pygame.time.Clock()

    game = Game()
    best = load_best()
    state = "title"
    joys = {}
    axis_dir = None
    t = 0.0

    def cell_rect(x, y, pad=2):
        return pygame.Rect(ox + x * cell + pad, oy + y * cell + pad, cell - 2 * pad, cell - 2 * pad)

    while True:
        dt = clock.tick(60) / 1000.0
        t += dt
        start = False
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                return
            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    return
                if ev.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER):
                    start = True
                dirs = {pygame.K_UP: (0, -1), pygame.K_w: (0, -1), pygame.K_DOWN: (0, 1), pygame.K_s: (0, 1),
                        pygame.K_LEFT: (-1, 0), pygame.K_a: (-1, 0), pygame.K_RIGHT: (1, 0), pygame.K_d: (1, 0)}
                if ev.key in dirs and state == "play":
                    game.turn(dirs[ev.key])
            elif ev.type == pygame.JOYDEVICEADDED:
                j = pygame.joystick.Joystick(ev.device_index)
                joys[j.get_instance_id()] = j
            elif ev.type == pygame.JOYDEVICEREMOVED:
                joys.pop(ev.instance_id, None)
            elif ev.type == pygame.JOYBUTTONDOWN:
                if ev.button == 0:
                    start = True
                elif ev.button == 1:
                    return
                # alguns controles expõem o direcional como botões 11-14 (layout SDL)
                bdirs = {11: (0, -1), 12: (0, 1), 13: (-1, 0), 14: (1, 0)}
                if ev.button in bdirs and state == "play":
                    game.turn(bdirs[ev.button])
            elif ev.type == pygame.JOYHATMOTION and state == "play":
                hx, hy = ev.value
                if hx:
                    game.turn((hx, 0))
                elif hy:
                    game.turn((0, -hy))
            elif ev.type == pygame.JOYAXISMOTION and ev.axis in (0, 1) and state == "play":
                j = joys.get(ev.instance_id)
                if j:
                    ax, ay = j.get_axis(0), j.get_axis(1)
                    d = None
                    if max(abs(ax), abs(ay)) > 0.6:
                        d = ((1 if ax > 0 else -1), 0) if abs(ax) > abs(ay) else (0, (1 if ay > 0 else -1))
                    if d and d != axis_dir:
                        game.turn(d)
                    axis_dir = d

        if state in ("title", "over") and start:
            game.reset()
            state = "play"
        if state == "play" and not game.update(dt):
            state = "over"
            if game.score > best:
                best = game.score
                save_best(best)

        # ---------- desenho ----------
        screen.fill(BG)
        board = pygame.Rect(ox, oy, cell * COLS, cell * ROWS)
        pygame.draw.rect(screen, GRID, board, border_radius=int(10 * s))
        pygame.draw.rect(screen, (38, 51, 95), board, width=2, border_radius=int(10 * s))

        # estrela (comida) pulsando
        fx, fy = game.food
        pulse = 0.75 + 0.25 * math.sin(t * 6)
        cxp, cyp = ox + fx * cell + cell / 2, oy + fy * cell + cell / 2
        r_out, r_in = cell * 0.46 * pulse, cell * 0.2 * pulse
        pts = []
        for k in range(10):
            ang = -math.pi / 2 + k * math.pi / 5
            r = r_out if k % 2 == 0 else r_in
            pts.append((cxp + r * math.cos(ang), cyp + r * math.sin(ang)))
        pygame.draw.polygon(screen, AMBER, pts)

        # cobra: cabeça ciano, corpo escurecendo até a cauda
        n = len(game.snake)
        for i, (x, y) in enumerate(game.snake):
            k = i / max(1, n - 1)
            col = tuple(int(CYAN[c] * (1 - 0.55 * k) + 20 * k) for c in range(3))
            pygame.draw.rect(screen, col, cell_rect(x, y, 2 if i else 1), border_radius=max(2, cell // 4))
        hx, hy = game.snake[0]
        ex = game.dir
        for side in (-1, 1):  # olhos
            px = ox + hx * cell + cell / 2 + ex[0] * cell * 0.15 + (-ex[1]) * side * cell * 0.18
            py = oy + hy * cell + cell / 2 + ex[1] * cell * 0.15 + ex[0] * side * cell * 0.18
            pygame.draw.circle(screen, BG, (int(px), int(py)), max(2, cell // 9))

        hud = f_mid.render(f"{game.score}", True, WHITE)
        screen.blit(hud, (ox, oy - hud.get_height() - int(8 * s)))
        rec = f_small.render(f"recorde {best}", True, MUTED)
        screen.blit(rec, (ox + cell * COLS - rec.get_width(), oy - rec.get_height() - int(12 * s)))

        def center(surf, y):
            screen.blit(surf, (W // 2 - surf.get_width() // 2, int(y)))

        if state != "play":
            veil = pygame.Surface((W, H), pygame.SRCALPHA)
            veil.fill((4, 6, 18, 190))
            screen.blit(veil, (0, 0))
        if state == "title":
            center(f_big.render("SKY SNAKE", True, CYAN), H * 0.30)
            center(f_mid.render("coma as estrelas, não bata", True, MUTED), H * 0.30 + 100 * s)
            center(f_small.render("A / Enter  começar        B / Esc  voltar ao SkyStation", True, MUTED), H * 0.72)
        elif state == "over":
            center(f_big.render("FIM DE JOGO", True, PINK), H * 0.30)
            novo = "  novo recorde!" if game.score == best and best > 0 else ""
            center(f_mid.render(f"pontos: {game.score}    recorde: {best}{novo}", True, WHITE), H * 0.30 + 100 * s)
            center(f_small.render("A / Enter  de novo        B / Esc  voltar", True, MUTED), H * 0.72)

        pygame.display.flip()


if __name__ == "__main__":
    main()
    pygame.quit()
    sys.exit(0)
