# Clonar o SkyStation da VM para o pendrive / cartão SD / SSD

Resultado: a mídia vira um SkyStation que dá boot direto em um PC (sem VM), no notebook
(i5-4200U) ou no PC atual (Ryzen 5 5500U), sem precisar reinstalar nada.

> ⚠️ A gravação **apaga tudo** que estiver na mídia de destino. Confira duas vezes o
> dispositivo no Rufus antes de gravar.

## Parte 1: na VM, deixar tudo pronto

No tty2 da VM (**Ctrl Direito + F2**, usuário `sky`):

```
sudo bash /mnt/skystation/setup/fase5-4.sh      # garante a versão mais nova (pode repetir sem problema)
skystation-vm video auto                        # modo de vídeo padrão (no PC de verdade a GPU funciona)
skystation-vm resolucao auto                    # resolução padrão da tela
cp -v /mnt/skystation/roms/ps1/* ~/skystation/roms/ps1/   # leva os jogos para dentro do sistema
sudo poweroff
```

Por que copiar os jogos: a pasta compartilhada (`/mnt/skystation`) só existe na VM.
A BIOS em `~/skystation/bios/ps1` já está dentro do sistema e vai junto.

Espere a VM **desligar por completo**. Não use "Salvar estado".

## Parte 2: no Windows, gerar a imagem

A VM tem um snapshot: o estado atual (com todas as fases) fica no disco diferencial dentro de
`Snapshots`, **não** no `SkyStation.vdi`. Por isso o comando usa o identificador desse disco.
O VirtualBox junta o snapshot com o disco base e gera uma imagem completa.

Abra o **Prompt de Comando** e rode (uma linha só):

```
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" clonemedium disk 8f64b14a-b3e4-4fa5-805c-69f240b187e0 "D:\SkyStation\skystation.img" --format RAW
```

- Gera um arquivo de ~27 GB (o tamanho virtual do disco). Leva alguns minutos.
- Tamanho: o disco da VM tem 25,3 GiB; um pendrive de 32 GB tem ~28,6 GiB reais. **Cabe.**

## Parte 3: gravar no pendrive

1. Baixe o **Rufus** (rufus.ie), versão portátil.
2. Coloque o pendrive (SanDisk Cruzer Blade 32 GB).
3. No Rufus:
   - **Dispositivo:** o pendrive (confira nome e tamanho!).
   - **Seleção de boot:** SELECIONAR → `D:\SkyStation\skystation.img`.
   - Se perguntar o modo de gravação: **DD**.
4. **INICIAR**. O Cruzer Blade é USB 2.0: a gravação leva uns 20 a 30 minutos.

## Parte 4: primeiro boot no PC

### Antes: Secure Boot e BitLocker

O SkyStation não é assinado para o Secure Boot, então ele precisa estar **desligado** na BIOS.

> ⚠️ **Se o Windows desse PC usa BitLocker** (comum em notebooks com Windows 11), desligar o
> Secure Boot pode fazer o Windows pedir a **chave de recuperação do BitLocker** no próximo boot.
> Antes de mexer, confira em *Configurações → Privacidade e segurança → Criptografia do dispositivo*
> e, se estiver ativo, anote a chave (account.microsoft.com/devices/recoverykey).
> Depois dos testes, é só religar o Secure Boot.

### Dar o boot

1. Com o pendrive conectado, ligue o PC apertando a tecla do **menu de boot**
   (depende da marca: F12 Lenovo/Dell/Acer, F9 HP, Esc ou F8 Asus, F11 MSI).
2. Escolha a entrada **UEFI** do pendrive (algo como "UEFI: SanDisk").
3. Deve aparecer o logo do SkyStation e depois o launcher.

### Ajustes do primeiro boot

Vá para outro terminal (**Ctrl+Alt+F2**), entre como `sky` e rode:

```
sudo skystation-expandir      # faz o sistema ocupar o pendrive inteiro
nmtui                         # Wi-Fi: "Ativar uma conexão" (ou use Configurações → Wi-Fi no launcher)
logout
```

Volte ao console com **Ctrl+Alt+F1**.

## Se algo der errado

- **O pendrive não aparece no menu de boot:** confira na BIOS se o modo é **UEFI** e se o
  **Secure Boot** está **desligado**.
- **Tela preta ou erro:** tire uma foto e me mande.
- **Ver o boot com texto (diagnóstico):** segure **Shift** ao ligar e escolha a entrada de recuperação.
