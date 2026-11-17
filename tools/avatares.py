#!/usr/bin/env python3
"""SkyStation: gera os ícones de perfil da SkyNetwork (desenhos próprios do SkyStation).

Uma fonte só para o site e o console:
    server/public/avatares/<id>.svg     o site usa direto
    server/src/lib/avatares.json        lista (id, nome) para o servidor validar e o site mostrar
    console/avatares/<id>.png           256 px, para o launcher (Godot) e o menu Home (pygame)
    console/avatares/avatares.json      a mesma lista, para o console

    python3 tools/avatares.py           (precisa do rsvg-convert, pacote librsvg)

Cada ícone: um círculo com degradê e um desenho branco por cima, no estilo dos ícones do launcher.
"""
import json
import os
import shutil
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_DIR = os.path.join(RAIZ, "server/public/avatares")
PNG_DIR = os.path.join(RAIZ, "console/avatares")
W = "#f4f8ff"   # branco do desenho
S = 'stroke="%s" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" fill="none"' % W

# id, nome, cor de cima, cor de baixo, desenho (SVG num quadro de 256x256, centro em 128,128)
AVATARES = [
    ("estrela", "Estrela cadente", "#4fd1ff", "#1b3fa8",
     f'<path d="M58 172 L118 112" {S} opacity=".55"/><path d="M48 140 L98 118" {S} opacity=".35"/>'
     f'<path d="M84 196 L116 146" {S} opacity=".35"/>'
     f'<path fill="{W}" d="M160 62 L172 96 L208 98 L180 120 L190 155 L160 135 L130 155 L140 120 L112 98 L148 96 Z"/>'),
    ("cometa", "Cometa", "#ff9a52", "#a12d4a",
     f'<path fill="{W}" opacity=".35" d="M60 72 L156 140 L140 160 Z"/><path fill="{W}" opacity=".6" d="M84 64 L162 128 L150 146 Z"/>'
     f'<circle cx="166" cy="150" r="30" fill="{W}"/>'),
    ("planeta", "Planeta", "#54f0b8", "#0f5e6a",
     f'<circle cx="128" cy="128" r="46" fill="{W}"/>'
     f'<ellipse cx="128" cy="134" rx="92" ry="26" {S} transform="rotate(-18 128 128)"/>'
     f'<path d="M84 150 A46 46 0 0 0 172 150" fill="#0f5e6a" opacity=".25"/>'),
    ("lua", "Lua", "#a9b6ff", "#262a6b",
     f'<mask id="m-lua"><rect width="256" height="256" fill="#fff"/><circle cx="162" cy="102" r="56" fill="#000"/></mask>'
     f'<circle cx="128" cy="128" r="62" fill="{W}" mask="url(#m-lua)"/>'
     f'<circle cx="180" cy="168" r="6" fill="{W}"/><circle cx="196" cy="140" r="4" fill="{W}"/>'),
    ("foguete", "Foguete", "#ff7ad0", "#4a1a7a",
     f'<path fill="{W}" d="M128 46 C160 72 166 116 160 160 L96 160 C90 116 96 72 128 46 Z"/>'
     f'<circle cx="128" cy="106" r="16" fill="#4a1a7a"/>'
     f'<path fill="{W}" d="M96 132 L70 170 L98 166 Z M160 132 L186 170 L158 166 Z"/>'
     f'<path fill="#ffd166" d="M108 168 L128 212 L148 168 Z"/>'),
    ("controle", "Controle", "#4fd1ff", "#0d1a4a",
     f'<path fill="{W}" d="M72 96 H184 C210 96 224 120 222 150 C220 178 200 190 184 176 L164 158 H92 L72 176 C56 190 36 178 34 150 C32 120 46 96 72 96 Z"/>'
     f'<rect x="72" y="120" width="12" height="36" rx="3" fill="#0d1a4a"/><rect x="60" y="132" width="36" height="12" rx="3" fill="#0d1a4a"/>'
     f'<circle cx="176" cy="124" r="8" fill="#0d1a4a"/><circle cx="192" cy="140" r="8" fill="#0d1a4a"/>'
     f'<circle cx="160" cy="140" r="8" fill="#0d1a4a"/><circle cx="176" cy="156" r="8" fill="#0d1a4a"/>'),
    ("raio", "Raio", "#ffd166", "#b3541e",
     f'<path fill="{W}" d="M142 40 L76 140 H122 L104 216 L180 106 H134 Z"/>'),
    ("onda", "Onda", "#5fdcff", "#063c5c",
     f'<path d="M40 112 C64 88 88 88 112 112 S160 136 184 112 S208 88 216 96" {S}/>'
     f'<path d="M40 148 C64 124 88 124 112 148 S160 172 184 148 S208 124 216 132" {S} opacity=".7"/>'
     f'<path d="M40 184 C64 160 88 160 112 184 S160 208 184 184" {S} opacity=".4"/>'),
    ("montanha", "Montanha", "#8fd14f", "#1d4d2a",
     f'<circle cx="170" cy="82" r="20" fill="#ffd166"/>'
     f'<path fill="{W}" d="M34 196 L102 92 L142 150 L162 122 L222 196 Z"/>'
     f'<path fill="#1d4d2a" opacity=".35" d="M102 92 L88 114 L102 108 L116 118 Z"/>'),
    ("chama", "Chama", "#ff9a52", "#8c1d1d",
     f'<path fill="{W}" d="M128 40 C140 84 188 98 186 150 C184 190 156 214 128 214 C100 214 72 190 72 152 C72 122 92 104 104 88 C106 112 116 124 126 128 C120 96 118 66 128 40 Z"/>'
     f'<path fill="#ff9a52" d="M128 132 C140 152 156 160 154 182 C152 198 140 206 128 206 C114 206 102 196 102 180 C102 162 118 154 128 132 Z"/>'),
    ("cristal", "Cristal", "#c58bff", "#3b1a6e",
     f'<path fill="{W}" d="M128 42 L190 104 L128 214 L66 104 Z"/>'
     f'<path fill="#3b1a6e" opacity=".25" d="M128 42 L128 214 L66 104 Z"/>'
     f'<path d="M66 104 H190 M100 104 L128 42 L156 104 L128 214" stroke="#3b1a6e" stroke-opacity=".35" stroke-width="5" fill="none"/>'),
    ("gato", "Gato", "#ffb36b", "#6b3a1e",
     f'<path fill="{W}" d="M64 76 L96 104 H160 L192 76 L194 140 C194 186 164 210 128 210 C92 210 62 186 62 140 Z"/>'
     f'<ellipse cx="104" cy="144" rx="10" ry="14" fill="#6b3a1e"/><ellipse cx="152" cy="144" rx="10" ry="14" fill="#6b3a1e"/>'
     f'<path fill="#ff7a9c" d="M120 170 H136 L128 180 Z"/>'
     f'<path d="M84 176 L44 170 M84 186 L46 192 M172 176 L212 170 M172 186 L210 192" stroke="{W}" stroke-width="5" stroke-linecap="round"/>'),
    ("raposa", "Raposa", "#ff8a3d", "#7a2a12",
     f'<path fill="{W}" d="M52 70 L100 104 H156 L204 70 L188 136 L128 206 L68 136 Z"/>'
     f'<path fill="#ff8a3d" d="M68 136 L100 120 L128 150 L156 120 L188 136 L128 206 Z"/>'
     f'<circle cx="104" cy="132" r="9" fill="#7a2a12"/><circle cx="152" cy="132" r="9" fill="#7a2a12"/>'
     f'<circle cx="128" cy="194" r="9" fill="#7a2a12"/>'),
    ("coruja", "Coruja", "#9ad0ff", "#2a3a6b",
     f'<path fill="{W}" d="M70 80 L96 96 H160 L186 80 L190 160 C190 196 162 214 128 214 C94 214 66 196 66 160 Z"/>'
     f'<circle cx="104" cy="132" r="22" fill="#2a3a6b"/><circle cx="152" cy="132" r="22" fill="#2a3a6b"/>'
     f'<circle cx="104" cy="132" r="9" fill="#ffd166"/><circle cx="152" cy="132" r="9" fill="#ffd166"/>'
     f'<path fill="#ffb36b" d="M120 158 H136 L128 172 Z"/>'),
    ("robo", "Robô", "#cfd8ea", "#2b3346",
     f'<path d="M128 72 V52" {S}/><circle cx="128" cy="46" r="10" fill="#4fd1ff"/>'
     f'<rect x="66" y="72" width="124" height="104" rx="26" fill="{W}"/>'
     f'<rect x="84" y="102" width="88" height="40" rx="18" fill="#2b3346"/>'
     f'<circle cx="108" cy="122" r="9" fill="#4fd1ff"/><circle cx="148" cy="122" r="9" fill="#4fd1ff"/>'
     f'<path d="M100 196 H156" {S}/><path d="M56 112 V136 M200 112 V136" {S}/>'),
    ("fantasma", "Fantasma", "#b9a6ff", "#2e1f5e",
     f'<path fill="{W}" d="M68 120 C68 82 96 54 128 54 C160 54 188 82 188 120 V206 L166 188 L148 206 L128 188 L108 206 L90 188 L68 206 Z"/>'
     f'<ellipse cx="108" cy="122" rx="10" ry="14" fill="#2e1f5e"/><ellipse cx="148" cy="122" rx="10" ry="14" fill="#2e1f5e"/>'
     f'<ellipse cx="128" cy="154" rx="12" ry="8" fill="#2e1f5e"/>'),
]


def svg(id_, cor1, cor2, desenho):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">'
            f'<defs><linearGradient id="g-{id_}" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{cor1}"/><stop offset="1" stop-color="{cor2}"/></linearGradient>'
            f'<radialGradient id="b-{id_}" cx=".3" cy=".25" r=".8"><stop offset="0" stop-color="#fff" stop-opacity=".28"/>'
            f'<stop offset=".6" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>'
            f'<circle cx="128" cy="128" r="126" fill="url(#g-{id_})"/><circle cx="128" cy="128" r="126" fill="url(#b-{id_})"/>'
            f'{desenho}'
            f'<circle cx="128" cy="128" r="123" fill="none" stroke="#fff" stroke-opacity=".22" stroke-width="5"/></svg>\n')


def main():
    if not shutil.which("rsvg-convert"):
        sys.exit("precisa do rsvg-convert (pacote librsvg)")
    os.makedirs(SVG_DIR, exist_ok=True)
    os.makedirs(PNG_DIR, exist_ok=True)
    lista = []
    for id_, nome, c1, c2, desenho in AVATARES:
        caminho = os.path.join(SVG_DIR, id_ + ".svg")
        with open(caminho, "w") as f:
            f.write(svg(id_, c1, c2, desenho))
        subprocess.run(["rsvg-convert", "-w", "256", "-h", "256", "-o", os.path.join(PNG_DIR, id_ + ".png"), caminho],
                       check=True)
        lista.append({"id": id_, "nome": nome, "cor": c1})
    for destino in (os.path.join(RAIZ, "server/src/lib/avatares.json"), os.path.join(PNG_DIR, "avatares.json")):
        with open(destino, "w") as f:
            json.dump(lista, f, ensure_ascii=False, indent=1)
            f.write("\n")
    print(f"{len(lista)} ícones gerados")


if __name__ == "__main__":
    main()
