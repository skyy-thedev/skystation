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
│   ├── fase5-6.sh    portátil (bateria, energia, brilho), avisos com som, capturas, capas, tempo de jogo
│   ├── energia.sh    perfil da CPU na tomada/bateria + acordar pelo controle (skystation-energia)
│   ├── fase5-7.sh    som de ligar, modo de espera, receber jogos pelo Wi-Fi, mover jogos
│   ├── som-ligar.sh  som de ligar no começo do boot (serviço skystation-som-ligar)
│   ├── fase5-8.sh    jogar direto do disco (acesso ao leitor: udev + módulo sg)
│   ├── fase6-0.sh    desempenho por jogo (PS2), Modo TV, Central web, copiar disco (cdrdao, chdman)
│   ├── fase7-0.sh    Central web em segundo plano, som de ligar na TV, PS3 (RPCS3), boot em outro PC
│   ├── fase7-1.sh    GameCube, Wii, DS, 3DS, GB/GBA, NES, Mega Drive (RetroArch) e Xbox 360 (Xenia)
│   ├── atualizar-menu.sh  "Atualizar o SkyStation" do menu, sem sudo (serviço + .path do systemd)
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
    ├── sounds/       sons de aviso e música ambiente (originais, gerados por tools/gerar-sons.py)
    ├── bin/          sky-run (executor), sky-home.py + sky-overlay.py (botão Home),
    │                 sky-notify (avisos com som), sky-capas (capas automáticas),
    │                 sky-receber (página para enviar jogos pelo Wi-Fi), sky-jogos (mover/apagar),
    │                 sky-disco (identifica o disco no leitor, nome e capa),
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

## Recursos da Fase 5.6

- **Bateria:** nível do console e dos controles no topo da tela e no menu Home. Na bateria o menu
  roda a 30 quadros e a CPU fica econômica; aviso em 15 % e 5 %; em 3 % o jogo é fechado do jeito
  certo e o console desliga sozinho.
- **Avisos com som** (`sky-notify`): controle conectado/desconectado, USB, pendrive de jogos, jogo
  novo, carregador, bateria fraca, temperatura alta. Silenciar: `touch ~/.config/skystation/avisos.off`.
- **Menu Home (no jogo):** salvar/carregar estado (PS1), salvar captura de tela, volume, bateria,
  temperatura e hora. As capturas aparecem na categoria **Capturas** (`~/skystation/capturas`).
- **Sistema:** volume e brilho (◀ ▶), saída de som (alto-falantes ou TV), música ambiente.
- **Descanso de tela:** escurece após 5 min parado no menu; desliga após 20 min (bateria) ou 60 min.
- **Capas automáticas:** baixadas do acervo libretro-thumbnails pelo nome do arquivo.
- **Tempo de jogo e Recentes:** `~/skystation/saves/tempo.json`.
- **Nova versão:** o console confere o GitHub a cada 6 h e avisa em Sistema → Atualizar.

## Recursos da Fase 5.7

- **Som de ligar:** toca no começo do boot (antes da animação terminar). Sistema → Som de ligar.
- **Modo de espera:** Energia → Modo de espera. O console dorme e acorda pelo **controle** (USB ou
  Bluetooth, se a placa permitir) ou pelo botão de ligar. Na tomada, o descanso de tela também
  entra em modo de espera em vez de desligar. Desligado de verdade, só o botão liga.
- **Receber jogos pelo Wi-Fi:** Sistema → Receber jogos pelo Wi-Fi mostra um endereço e um PIN;
  no PC/celular, abra o endereço e arraste os arquivos (escolha PS1/PS2 e console/SKYROMS).
- **Mover / apagar jogo:** no jogo, botão Y → Mover para o pendrive SKYROMS (ou para o console),
  Apagar jogo (pede confirmação). O jogo inteiro vai junto (.cue + .bin, capa).
- **Espaço total:** Sistema → Armazenamento soma o sistema e o SKYROMS.
- **Atualizar pelo menu (5.7.2):** o menu só cria um pedido em `/var/lib/skystation/pedidos/`;
  o systemd (`skystation-atualizar.path` → `.service`) roda a atualização como root e o menu
  mostra o andamento. Instalado sozinho pelo `sudo skystation-atualizar`.
- **BIOS do PS2 (5.7.1):** envie pelo Wi-Fi escolhendo "BIOS do PS2" (vai sempre para o console), ou
  deixe o arquivo de 4 MB em `SKYROMS/bios/`: ao abrir um jogo de PS2 ela é copiada sozinha.

## Jogar do disco (Fase 5.8)

Coloque o disco no leitor: em poucos segundos toca um som, aparece o aviso e o jogo surge no
**topo de Jogos** (e em PS1/PS2) com nome e capa. A = jogar, Y → Ejetar disco.

- **Como reconhece:** o `sky-disco` lê o `SYSTEM.CNF` do disco (`BOOT2` = PS2, `BOOT` = PS1) e o
  código do jogo (ex.: SLUS-20946). O nome vem da base Redump da libretro-database (baixada uma vez
  para `~/.cache/skystation/discos/`); sem internet aparece o código.
- **PS2:** PCSX2 com `-disc /dev/sr0`.
- **PS1:** o core PCSX-ReARMed lê o CD por comandos SCSI (`cdrom://driveN.cue` → `/dev/sgN`),
  inclusive as faixas de áudio. Saves e estados de cada disco ficam em `saves/ps1/disco/<código>/`.
- **Permissão:** `fase5-8.sh` carrega o módulo `sg` e libera `/dev/sr*` e `/dev/sg*` do leitor
  para o usuário do console (grupo `optical` + `uaccess`).

## Fase 5.9 e 6.0

- **Desempenho por jogo (PS2):** botão Y no jogo → Desempenho: Normal / Rápido / Máximo.
  Rápido = EE Cycle Rate -1 + MTVU; Máximo = EE Cycle Rate -2 + EE Cycle Skip 1 + MTVU.
  Fica em `~/.config/skystation/ps2-desempenho.json` e é aplicado pelo `sky-pcsx2-ini`.
- **Modo TV:** o cage roda com `-m last`: ligou o HDMI, a imagem vai para a TV (a tela do notebook
  apaga); tirou, volta. O `sky-notify` troca o som para o HDMI (e volta) e avisa com som próprio.
  Na TV a interface fica 20% maior (Sistema → Modo TV liga/desliga). `~/.config/skystation/tv-som.off`
  impede a troca de som.
- **Central web:** Sistema → Central web. Abas Enviar, Jogos (capa, tamanho, mover, apagar),
  Capturas (ver/baixar) e Saves (backup .zip). Só funciona com a tela aberta e com o PIN.
- **Copiar disco:** Y no disco → Copiar para o console/SKYROMS. PS2 vira `.iso`; PS1 é lido em modo
  cru pelo `cdrdao` (com faixas de áudio) e compactado em `.chd`.
- **Compactar (CHD):** Y em um jogo `.cue`/`.iso` → converte com `chdman`, confere e apaga o original.

## Fase 6.1

- **Favoritos:** Y no jogo → Favoritar ★. Favoritos ficam no topo de Jogos/PS1/PS2
  (`~/.config/skystation/favoritos.json`).
- **Cópias automáticas dos saves:** depois de cada partida o `sky-backup` guarda um `.zip` em
  `~/skystation/backups` se algum save mudou (10 mais recentes). Baixar/restaurar: Central web → Saves.
- **Voltar à versão anterior:** cada atualização guarda a versão em uso em `/opt/skystation.anterior`;
  Sistema → Voltar à versão anterior troca as duas (pedir de novo desfaz).
- **PS2 no perfil leve:** mistura de cores no mínimo e sem pontilhado (menos carga na GPU integrada).

## Fase 6.2

- **QR code na Central web:** a tela mostra um QR com o endereço e o PIN embutidos.
- **Celular como teclado:** Central web → Teclado digita no console (via `wtype`).
- **Terminal secreto:** segurar L3 + R3 por 2 s no menu abre o `foot`. Home fecha.
- **Armazenamento:** Sistema → Armazenamento mostra uma barra com o que cada coisa ocupa.
- **Gestos no touchpad do DS4:** dois dedos deslizando; esquerda = brilho, direita = volume.
  Vale no menu e nos jogos. Desligar: Sistema → Gestos no touchpad.
- **SNES e N64:** `roms/snes` (.sfc, .smc) e `roms/n64` (.z64, .n64, .v64), cores Snes9x e
  Mupen64Plus-Next no RetroArch, com salvar/carregar estado. As categorias aparecem quando há jogos.

## Fase 6.3

- **Perfis:** até 4 jogadores, cada um com saves, estados, cópias, tempo de jogo, favoritos e troféus.
  `~/skystation/saves`, `states` e `backups` são atalhos para `~/skystation/perfis/<id>/…`
  (`sky-perfis`). Trocar: Sistema → Perfil. Renomear: Central web → Saves.
- **Troféus:** 17 troféus do SkyStation por perfil (`sky-trofeus`), conferidos depois de cada
  partida, com aviso e som. Categoria Troféus no menu e contagem no topo da tela.
- **YouTube:** app que abre `youtube.com/tv` no WebKitGTK com identificação de smart TV.
- **Moonlight:** app para jogar por streaming os jogos do PC (o PC precisa do Sunshine).

## Fase 6.4 e 6.5

- **Cópia de disco robusta (6.4):** vigia de progresso (desiste após minutos sem ler), B cancela,
  setores ilegíveis de DVD preenchidos com zeros (até 256); o `cdrdao` não trava mais no meio.
- **Sessão (6.4):** se o cage cair ao fechar, o console reabre sozinho (máx. 3 em 5 min).
- **PSP (6.5):** `roms/psp` (.iso, .cso), core PPSSPP no RetroArch, apoio em `bios/psp/PPSSPP`.
- **Desempenho automático no PS2 (6.5):** padrão "Automático": jogos de uma lista de títulos
  pesados abrem em Rápido; os outros em Normal. Y no jogo troca (Automático/Normal/Rápido/Máximo).
- **Conferir cópia (6.5):** Y num jogo de PS2 em `.iso` compara tamanho + CRC32 com o registro Redump.
- **Diagnóstico:** com Medição de FPS ligada, o PCSX2 mostra velocidade e uso de EE/GS/VU/GPU.

## Fase 7.0

- **Central web em segundo plano:** `sky-receber servir` roda como serviço da sessão (aberto pelo
  `sky-shell`), não mais só com a tela aberta. Liga/desliga em Sistema → Central web
  (`~/.config/skystation/central.json`); ligada, volta a cada boot com o mesmo PIN de 6 dígitos.
  Estado em `$XDG_RUNTIME_DIR/skystation/central.json`; avisos (jogo recebido, PIN errado) vão para
  `events.jsonl`. 5 PINs errados bloqueiam aquele aparelho por 1 min (dobra a cada 5, até 15 min).
- **Som de ligar na TV:** `skystation-som-ligar` espera a TV se apresentar no HDMI (ELD) e toca lá
  (`ligar-tv.wav`, com 1 s de silêncio antes). Sem TV, ou com "som na TV" desligado, sai no console.
- **PS3 (RPCS3):** só em PC com 6+ threads — a ideia é dar boot com o pendrive num PC mais forte.
  Jogos em `roms/ps3` ou `SKYROMS/ps3`: a pasta do disco (com `PS3_GAME`) ou um `.iso`. Firmware:
  `PS3UPDAT.PUP` (site oficial da PlayStation) em `bios/ps3`, instalado sozinho na primeira vez.
  `sky-ps3` lista os jogos (nome/ícone do `PARAM.SFO`), configura o controle ligado na hora
  (DualShock/DualSense direto pelo hidraw; outros pelo evdev) e usa um usuário do RPCS3 por perfil,
  com os saves dentro de `saves/ps3`. Central web: envia `.iso`, a pasta inteira do jogo ou o firmware.
  Forçar em PC fraco: `touch ~/.config/skystation/ps3-forcar`.
- **Boot em outro PC:** firmware e Vulkan para AMD/Intel, imagem de boot sem `autodetect`, redes
  Wi-Fi salvas liberadas para qualquer placa. No outro PC: desligar o Secure Boot.

## Fase 7.1

- **Mais consoles (cores do RetroArch):** GameCube e Wii (`dolphin`, apoio em `bios/dolphin`),
  Nintendo DS (`melondsds`/`melonds`/`desmume`), 3DS (`azahar`/`citra`), Game Boy/Color (`gambatte`),
  GBA (`mgba`), NES (`nestopia`/`fceumm`), Mega Drive (`genesis_plus_gx`). Pastas `roms/<gc|wii|nds|3ds|gba|gb|nes|md>`.
  O `sky-emu` usa o primeiro core instalado da lista; salvar/carregar estado pelo menu Home vale para todos.
- **Xbox 360 (experimental):** Xenia Canary para Linux em `/opt/xenia`, `roms/x360` (.iso, .zar).
  Só em PC com 6+ threads (`touch ~/.config/skystation/x360-forcar` para forçar).
- As categorias novas só aparecem quando há jogos. Nada disso foi testado em hardware ainda.

## Fase 7.2

- **Velocidade nas transferências:** MB/s e tempo restante ao mover jogos, copiar/conferir disco
  (`sky-jogos` manda `v` e `falta` junto do progresso) e nos envios da Central web (página e tela do console).
- **Erros com código:** quando um jogo fecha com erro, o aviso mostra `E<código>`, o que ele significa
  (ex.: E139 = falha de memória/SIGSEGV, E127 = emulador não instalado) e a última linha do log do jogo.
  Códigos acima de 128 são 128 + o sinal que encerrou o processo. O terminal de erro da sessão também explica.
- **Menu de energia:** segurar o Home 1,5 s (com ou sem jogo) abre Voltar / Fechar jogo / Modo de espera /
  Reiniciar / Desligar. Continuar segurando até 5 s fecha o jogo direto (saída de emergência).
- **Ponteiro do mouse** escondido no menu do console; continua nos apps que usam mouse (Navegador, terminal).
- **Revisão:** avisos longos e descrições quebram em linhas; "Voltar à versão anterior" não perde
  emuladores instalados depois; avisos antigos não aparecem fora de hora.

## Fase 7.4

- **Qualidade por aparelho:** o mesmo pendrive liga no notebook antigo (perfil leve) e no Ryzen (potente).
  No potente, o `sky-emu` gera `~/.config/skystation/core-options.cfg` a cada jogo com resolução interna
  maior para PSP (3x), GameCube/Wii (2x), N64 (1280x960), 3DS (2x) e PS1 melhorado; o PS2 já usava
  Vulkan em 2x. No leve fica tudo no original.
- **Sistema → Este aparelho:** mostra processador, threads, memória e o perfil; A alterna
  Automático / Leve / Potente (`~/.config/skystation/perfil`).

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
- [x] Fase 5.6: bateria do console e dos controles, modo econômico, avisos com som, brilho/volume,
      saída de som, descanso de tela, menu Home com salvar/carregar estado e captura, capas
      automáticas, tempo de jogo + Recentes, Capturas, aviso de nova versão, música ambiente
- [x] Fase 5.7: som de ligar, modo de espera com "ligar pelo controle", receber jogos pelo Wi-Fi,
      mover jogos console ⇄ SKYROMS, apagar jogo, espaço total (sistema + SKYROMS)
- [x] Fase 5.8: jogar direto do disco (PS1 em CD, PS2 em DVD/CD), com nome, capa e ejetar
- [x] Fase 5.9: desempenho por jogo no PS2 (Normal / Rápido / Máximo)
- [x] Fase 6.0: Modo TV automático, Central web (biblioteca, capturas, backup dos saves),
      copiar disco para o console, compactar jogo em CHD
- [ ] Porta USB ao lado do HDMI sem energia (provável defeito físico)
- [ ] Drive de DVD: jogar PS1/PS2 direto do disco ou copiar para .chd
- [ ] SSD SATA no lugar do pendrive
- [ ] Case impressa em 3D (protótipo v0.1 em hardware/case)
- [ ] Fase 6: ISO próprio do SkyStation
- [x] Fase 7.0: Central web em segundo plano, som de ligar na TV, PS3 pelo RPCS3 em PC forte (não testado em hardware)
- [x] Fase 7.1: GameCube, Wii, DS, 3DS, GB/GBC/GBA, NES, Mega Drive e Xbox 360 experimental (não testado em hardware)
- [x] Fase 7.2: velocidade nas transferências, erros com código, menu de energia no Home, ponteiro escondido, revisão
- [x] Fase 7.4: qualidade por aparelho (perfil potente para o Ryzen) e item "Este aparelho"

## Saídas de emergência

- **Outro terminal:** `Ctrl Direito + F2` na VM (`Ctrl+Alt+F2` no notebook real) abre um login normal.
- **Desligar o modo console:** a partir do tty2, `touch ~/.skystation-off` e reinicie.
  Para voltar ao modo console: `rm ~/.skystation-off`.
- **Vídeo/resolução:** `skystation-vm status`, `skystation-vm video software`, `skystation-vm resolucao auto` (depois `logout`).
- **Log do console:** `~/.local/state/skystation/session.log`
- **Controle/USB/Bluetooth:** `sudo skystation-diag-controle` (salva em `~/skystation/diag-controle.txt`)
