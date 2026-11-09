
# >>> SKYSTATION >>>
# Ao entrar no tty1 (login automático), abre o console SkyStation.
# Para desativar: touch ~/.skystation-off   (a partir de outro tty, Ctrl+Alt+F2)
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ] && [ ! -f "$HOME/.skystation-off" ]; then
    printf '\033[?25l\033[2J\033[H'      # esconde o cursor e limpa a tela (boot silencioso)
    /opt/skystation/session.sh
    code=$?
    printf '\033[?25h'                      # cursor de volta
    if [ "$code" -eq 0 ]; then
        # Saída normal: encerra a sessão; o getty faz login de novo e o console reabre.
        logout
    else
        echo ""
        echo "  SkyStation saiu com erro ($code)."
        echo "  Log: ~/.local/state/skystation/session.log"
        echo "  Você está num terminal normal. Para tentar de novo: logout"
        echo ""
    fi
fi
# <<< SKYSTATION <<<
