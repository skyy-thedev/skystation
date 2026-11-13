
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
        case "$code" in
            139) motivo="falha de memória (SIGSEGV) na interface ou no driver de vídeo" ;;
            134) motivo="a interface abortou (SIGABRT)" ;;
            137) motivo="encerrado à força: provável falta de memória" ;;
            127) motivo="programa não encontrado: rode sudo skystation-atualizar" ;;
            *)   motivo="veja o log abaixo" ;;
        esac
        echo "  SkyStation saiu com erro E$code: $motivo."
        echo "  Log: ~/.local/state/skystation/session.log"
        echo "  Você está num terminal normal. Para tentar de novo: logout"
        echo ""
    fi
fi
# <<< SKYSTATION <<<
