# Perfis de controle do RetroArch (udev)

Copiados de <https://github.com/libretro/retroarch-joypad-autoconfig> (pasta `udev/`, licença MIT,
ver `LICENSE-libretro-autoconfig`). O pacote oficial do Arch deixou de existir, então o SkyStation
traz os perfis junto: funciona offline e na versão que testamos.

Alteração do SkyStation: removidas as linhas `input_menu_toggle_*` e `input_screenshot_*`.
No console, o botão PS/Guide pertence ao **menu Home do SkyStation** (sky-home.py);
se o RetroArch também abrisse o menu dele, os dois apareceriam juntos.
