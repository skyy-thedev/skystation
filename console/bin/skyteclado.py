"""SkyStation: teclado virtual para escrever com o controle (menu Home dentro do jogo).

Só a lógica (sem tela e sem controle), para poder ser testada sozinha. O sky-home.py traduz os
botões em chamadas daqui e manda o estado para o sky-overlay.py desenhar.

    t = Teclado("Mensagem para Bart")
    t.mover(0, 1)          # direcional: (dx, dy)
    t.apertar()            # A: digita a tecla selecionada (ou executa ⇧, 123, espaço, ⌫, Enviar)
    t.apagar()             # B
    t.espaco()             # Y
    t.maiuscula()          # X
    t.digitar("a")         # teclado de verdade
    t.estado()             # {"titulo", "texto", "linhas", "r", "c", "shift", "simbolos"} -> desenho
    t.enviado              # True depois de "Enviar" (ou Start): o texto está em t.texto

Duas páginas: letras (com ç) e símbolos (com os acentos do português: á é í ó ú ã õ â ê ô à ü).
A última linha é igual nas duas: ⇧  123/ABC  espaço  ⌫  Enviar.
"""

LETRAS = [
    list("1234567890"),
    list("qwertyuiop"),
    list("asdfghjklç"),
    list("zxcvbnm,.?"),
]
SIMBOLOS = [
    list("!@#$%&*()-"),
    list("áéíóúãõâêô"),
    list("àüÁÉÍÓÚÃÕÇ"),
    list("'\":;/+=_!?"),
]
SHIFT, PAGINA, ESPACO, APAGAR, ENVIAR = "⇧", "123", "espaço", "⌫", "Enviar"
ULTIMA = [SHIFT, PAGINA, ESPACO, APAGAR, ENVIAR]
LIMITE = 280   # o mesmo do servidor


class Teclado:
    def __init__(self, titulo, texto="", limite=LIMITE):
        self.titulo = titulo
        self.texto = texto[:limite]
        self.limite = limite
        self.r, self.c = 1, 0          # começa no "q"
        self.shift = False
        self.simbolos = False
        self.enviado = False

    # ------------------------------------------------------------ desenho
    def linhas(self):
        base = SIMBOLOS if self.simbolos else LETRAS
        rows = [[k.upper() if self.shift and not self.simbolos else k for k in row] for row in base]
        ultima = list(ULTIMA)
        ultima[1] = "ABC" if self.simbolos else "123"
        return rows + [ultima]

    def estado(self):
        return {"titulo": self.titulo, "texto": self.texto, "linhas": self.linhas(), "r": self.r, "c": self.c,
                "shift": self.shift, "simbolos": self.simbolos, "limite": self.limite}

    def tecla(self):
        return self.linhas()[self.r][self.c]

    # ------------------------------------------------------------ navegação
    def mover(self, dx, dy):
        rows = self.linhas()
        if dy:
            antes = len(rows[self.r])
            self.r = (self.r + dy) % len(rows)
            depois = len(rows[self.r])
            if antes != depois:
                # mantém a posição proporcional (a última linha tem 5 teclas, as outras 10)
                self.c = round(self.c * (depois - 1) / max(1, antes - 1))
        if dx:
            self.c = (self.c + dx) % len(rows[self.r])

    # ------------------------------------------------------------ ações
    def digitar(self, ch):
        if ch and len(self.texto) + len(ch) <= self.limite:
            self.texto += ch
            if self.shift and not self.simbolos:
                self.shift = False      # maiúscula vale para uma letra, como no celular
            return True
        return False

    def apagar(self):
        if self.texto:
            self.texto = self.texto[:-1]
            return True
        return False

    def espaco(self):
        # sem espaço no começo nem dois seguidos
        if self.texto and not self.texto.endswith(" "):
            return self.digitar(" ")
        return False

    def maiuscula(self):
        self.shift = not self.shift

    def pagina(self):
        self.simbolos = not self.simbolos
        self.shift = False

    def enviar(self):
        if self.texto.strip():
            self.texto = self.texto.strip()
            self.enviado = True
            return True
        return False

    def apertar(self):
        """A: o que a tecla selecionada faz. Devolve True se algo mudou."""
        k = self.tecla()
        if k == SHIFT:
            self.maiuscula()
            return True
        if k in ("123", "ABC"):
            self.pagina()
            return True
        if k == ESPACO:
            return self.espaco()
        if k == APAGAR:
            return self.apagar()
        if k == ENVIAR:
            return self.enviar()
        return self.digitar(k)


# Teclado de verdade (evdev) -> caractere. Só o básico: letras, números e pontuação comum.
def tecla_fisica(nome, shift=False):
    """`nome` é o nome evdev (ex.: "KEY_A"). Devolve o caractere ou ""."""
    if not nome.startswith("KEY_"):
        return ""
    k = nome[4:]
    if len(k) == 1 and k.isalpha():
        return k.upper() if shift else k.lower()
    if len(k) == 1 and k.isdigit():
        return "!@#$%¨&*()"["1234567890".index(k)] if shift else k
    extra = {"COMMA": ",<", "DOT": ".>", "SLASH": ";:", "MINUS": "-_", "EQUAL": "=+",
             "APOSTROPHE": "~^", "SEMICOLON": "çÇ", "RO": "/?"}
    if k in extra:
        return extra[k][1 if shift else 0]
    return ""
