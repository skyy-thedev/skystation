# SkyStation

Videogame próprio sobre um Linux enxuto (Arch). Projeto hobby.

## Estrutura

```
skystation/
├── setup/            scripts que preparam o sistema
│   ├── fase2.sh      login automático + cage
│   ├── fase3.sh      Godot + launcher + jogos de exemplo
│   ├── fase4.sh      desempenho, estabilidade, emuladores, boot universal
│   ├── fase5.sh      menu Home por cima do jogo, boot silencioso, Configurações
│   ├── fase5-1.sh    boot 100% SkyStation (sem Arch) + navegador
│   ├── fase5-2.sh    codecs do navegador, Snake, PS1 com mais formatos
│   ├── fase5-3.sh    boot com logo SkyStation e sem texto (UKI)
│   ├── fase5-5.sh    visual novo (barra cruzada + boot animado), Bluetooth sem atraso, espaço
│   ├── marca.sh      identidade do sistema (comando skystation-marca, reaplicado pelo pacman)
│   ├── diag.sh       diagnóstico do boot (comando skystation-diag)
│   ├── expandir.sh   ocupa a mídia inteira após clonar (comando skystation-expandir)
│   ├── tamanho.sh / enxugar.sh   medir e enxugar o sistema antes de gerar imagem p/ pendrive pequeno
│   ├── diag-controle.sh          diagnóstico de controles/USB/Bluetooth (skystation-diag-controle)
│   ├── atualizar.sh  "deploy": copia console/ para /opt/skystation
│   └── skystation-atualizar.sh   comando skystation-atualizar (VM: pasta compartilhada; notebook: GitHub)
├── hardware/case/    case impressa em 3D (OpenSCAD paramétrico, STLs, renders) — protótipo v0.1
├── system/           configurações que vão para /etc e para a home (+ tema de boot Plymouth)
├── docs/             guias (clonar para cartão/pendrive)
└── console/          tudo que roda no console (vira /opt/skystation)
    ├── session.sh    abre o cage com o launcher e o vigia do botão Home
    ├── bin/          sky-run (executor), sky-home.py + sky-overlay.py (botão Home),
    │                 sky-shell, sky-emu (emuladores), sky-wine (PC), sky-config (Configurações),
    │                 sky-perfil (leve/potente), sky-pcsx2-ini
    ├── emu/          configuração otimizada do RetroArch e cores
    │   └── autoconfig/udev/  perfis de controle do RetroArch (libretro, MIT)
    ├── launcher/     launcher em Godot 4: main.gd = interface em barra cruzada (categorias na
    │                 horizontal, itens na vertical, fundo de ondas em shader, sons sintetizados),
    │                 settings.gd = Configurações (Wi-Fi, Bluetooth, Som, Sistema)
    ├── games/        um jogo por pasta, cada um com game.json
    │   ├── sky-dodge/        jogo autoral: desvie dos meteoros (Python + pygame)
    │   ├── sky-snake/        jogo autoral: a cobrinha (recorde salvo)
    │   ├── teste-controles/  ferramenta de teste de controles
    │   └── navegador/        navegador próprio (GTK 4 + WebKitGTK), para testes
    └── placeholder/  tela da Fase 2 (plano B se o Godot faltar)
```

## Formato de um jogo (game.json)

```json
{
  "title": "Sky Dodge",
  "type": "autoral",            // autoral | retro | windows | linux | ferramenta
  "exec": "python3 main.py",    // comando, rodado dentro da pasta do jogo
  "cover": "cover.png",         // capa 3:4 (opcional; sem capa aparecem as iniciais)
  "color": "#4fd1ff",           // cor de destaque
  "order": 10,                  // posição na fileira (menor vem antes)
  "description": "Texto que aparece embaixo da capa."
}
```

Jogos ficam em `/opt/skystation/games` (vêm do projeto) ou em `~/skystation/games` (seus).

## ROMs, BIOS e saves (Fase 4)

```
~/skystation/
├── roms/ps1/      .cue+.bin/.chd/.pbp/.m3u/.iso/.img   (aparecem sozinhos no launcher)
├── roms/ps2/      .iso/.chd/.cso
│   └── covers/    capa opcional: mesmo nome do jogo + .png
├── bios/ps1/      opcional (o PCSX-ReARMed tem BIOS interna)
├── bios/ps2/      obrigatória para PS2: extraia do SEU console
├── saves/         memory cards e saves: faça backup desta pasta
├── states/        save states
├── wine/          um "Windows" isolado por jogo de PC
└── benchmarks/    logs do MangoHud (CSV)
```

Na VM também valem as pastas `roms/ps1` e `roms/ps2` dentro da pasta compartilhada.

**Jogo de PC antigo:** pasta em `~/skystation/games/<nome>/` com os arquivos do jogo e um
`game.json` com `"type": "windows"` e `"exec": "sky-wine Jogo.exe"`.

## Pendrive de jogos (SKYROMS)

Para guardar jogos fora do sistema (útil na mídia de 8 GB): formate um pendrive em **exFAT** com o
rótulo **SKYROMS** e crie as pastas `ps1/` e `ps2/` (capas opcionais em `ps1/covers/Nome do Jogo.png`).
Ao conectar, ele monta sozinho em `/mnt/skyroms` e os jogos aparecem no console; ao tirar, somem.
Dica: `.chd` ocupa bem menos que `.bin/.cue` (converta com o `chdman` no PC).

## Visual

- **Temas:** Sistema → Tema de cores (Automático muda com a hora do dia: Oceano, Aurora,
  Crepúsculo, Noite). Também no painel de opções (botão Y / Start).
- **Sons da interface:** Sistema → Sons da interface.
- **Modo leve:** automático quando não há GPU (VM). Para forçar: `touch ~/.config/skystation/visual.leve`.
- **Abertura:** para pular sempre, `touch ~/.config/skystation/intro.off`.

## Controles do console

| Ação | Controle | Teclado |
|---|---|---|
| Navegar / jogar | Direcional + A | Setas + Enter |
| Trocar de categoria / item | Direcional (esq/dir, cima/baixo) | Setas |
| Painel de opções | Start ou Y | M ou Tab |
| Voltar | B | Esc ou Backspace |
| **Pausar o jogo (menu Home)** | **Toque no Home** ou **Select+Start** | **F12** |
| Fechar o jogo direto (emergência) | Segurar Home ou Select+Start (1,5 s) | Segurar F12 |
| Menu do RetroArch | — | F1 |

## Fluxo de trabalho

O código-fonte oficial fica no GitHub: <https://github.com/skyy-thedev/skystation>

- **Notebook / console real:** `sudo skystation-atualizar && logout`
  baixa a versão mais nova do GitHub, instala em `/opt/skystation` e atualiza os comandos `skystation-*`.
- **VM de desenvolvimento:** o mesmo comando usa a pasta compartilhada (`/mnt/skystation`).
  Para forçar o GitHub na VM: `sudo skystation-atualizar --github`.
- **Fase nova:** `sudo bash /opt/skystation-src/setup/faseN.sh` (notebook) ou
  `sudo bash /mnt/skystation/setup/faseN.sh` (VM).
- A versão instalada aparece em `/opt/skystation/VERSION` (data + commit).

**Primeira vez no notebook** (o comando antigo apontava para a pasta da VM):

```
curl -fsSL https://raw.githubusercontent.com/skyy-thedev/skystation/main/setup/skystation-atualizar.sh | sudo bash -s -- --github
```

## Fases

- [x] Fase 1: Arch mínimo na VM (usuário `sky`, teclado br-abnt2, rede ok)
- [x] Fase 2: login automático + cage abrindo um app em tela cheia (pixman na VM sem 3D)
- [x] Fase 3: launcher em Godot + Sky Dodge + teste de controles
- [x] Fase 4: desempenho, botão Home, PS1/PS2/PC, boot universal → testar no notebook
- [x] Fase 5: menu Home por cima do jogo, boot silencioso, Configurações (Wi-Fi, Bluetooth, Som, Sistema)
- [x] Fase 5.1: navegador próprio
- [x] Fase 5.2: Sky Snake, codecs do navegador, PS1 com mais formatos
- [x] Fase 5.3: boot com logo SkyStation (UKI: /etc/kernel/cmdline + splash no preset)
- [x] Fase 5.4: vídeo à prova de falhas + comando skystation-vm (resolução e modo de vídeo)
- [x] Notebook real: boot pelo pendrive (imagem enxuta de 7 GB), PS1 a 60 FPS, 45 °C
- [x] Git: projeto no GitHub; `skystation-atualizar` baixa do GitHub fora da VM
- [x] Controle nos emuladores: perfis de ~440 controles no RetroArch (PS1) e mapeamento SDL no PCSX2 (PS2)
- [x] Fase 5.5: interface em barra cruzada, boot animado, temas, sons, atualizar pelo menu,
      pendrive de jogos SKYROMS, Bluetooth sem economia de energia, cache do pacman automático
- [ ] Porta USB ao lado do HDMI sem energia (provável defeito físico)
- [ ] SSD SATA no lugar do pendrive
- [ ] Case impressa em 3D (protótipo v0.1 em hardware/case)
- [ ] Fase 6: ISO próprio do SkyStation

## Saídas de emergência

- **Outro terminal:** `Ctrl Direito + F2` na VM (`Ctrl+Alt+F2` no notebook real) abre um login normal.
- **Desligar o modo console:** a partir do tty2, `touch ~/.skystation-off` e reinicie.
  Para voltar ao modo console: `rm ~/.skystation-off`.
- **Vídeo/resolução:** `skystation-vm status`, `skystation-vm video software`, `skystation-vm resolucao auto` (depois `logout`).
- **Log do console:** `~/.local/state/skystation/session.log`
- **Controle/USB/Bluetooth:** `sudo skystation-diag-controle` (salva em `~/skystation/diag-controle.txt`)
