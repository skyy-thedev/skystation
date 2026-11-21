#!/bin/sh
# DEADZONE 0.8: dois jogos ao mesmo tempo no mesmo computador, um abre a sala e o outro entra.
# Uso: GODOT=./godot sh console/tests/deadzone/online.sh   (a partir da raiz do repositório)
set -u
G="${GODOT:-godot}"
JOGO=console/games/deadzone
cp console/tests/deadzone/online.gd "$JOGO/zz_online.gd"
TMP=$(mktemp -d)
mkdir -p "$TMP/h" "$TMP/c" "$TMP/run"
export XDG_RUNTIME_DIR="$TMP/run" DEADZONE_SEM_UPNP=1 DEADZONE_SENHA=teste
HOME="$TMP/h" DZ_PAPEL=host timeout 150 "$G" --headless --path "$JOGO" --script res://zz_online.gd -- --sala=coop_cr \
	>"$TMP/host.log" 2>&1 &
HOST=$!
sleep 4
HOME="$TMP/c" DZ_PAPEL=cliente timeout 140 "$G" --headless --path "$JOGO" --script res://zz_online.gd -- \
	--entrar=127.0.0.1,24680,teste >"$TMP/cliente.log" 2>&1
C=$?
wait $HOST
H=$?
echo "=== anfitrião"; grep -E "ok|FALHOU|RESULTADO|SCRIPT ERROR|ERROR" "$TMP/host.log" | head -60
echo "=== convidado"; grep -E "ok|FALHOU|RESULTADO|SCRIPT ERROR|ERROR" "$TMP/cliente.log" | head -60
rm -f "$JOGO/zz_online.gd"
grep -q "RESULTADO: tudo certo" "$TMP/host.log" && grep -q "RESULTADO: tudo certo" "$TMP/cliente.log" \
	&& [ "$H" = 0 ] && [ "$C" = 0 ] && echo "ONLINE: tudo certo" && exit 0
echo "ONLINE: falhou (logs em $TMP)"
exit 1
