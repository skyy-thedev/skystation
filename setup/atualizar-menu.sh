#!/bin/bash
# SkyStation: roda como root pelo skystation-atualizar.service.
# O menu do console só cria um arquivo-pedido (sem sudo, sem senha); o systemd vê o pedido
# e chama este script, que escreve o andamento em /var/lib/skystation/atualizar/.
#   pedidos/atualizar -> baixa e instala a versão mais nova
#   pedidos/reverter  -> troca /opt/skystation pela versão anterior (Fase 6.1); pedir de novo desfaz
D=/var/lib/skystation/atualizar
P=/var/lib/skystation/pedidos
install -d -m 755 "$D"
estado() { echo "$1" > "$D/estado.new" && mv -f "$D/estado.new" "$D/estado"; }
estado rodando
if [ -e "$P/reverter" ]; then
    rm -f "$P/reverter" "$P/atualizar"
    if [ -f /opt/skystation.anterior/VERSION ]; then
        {
            echo "==> Voltando para a versão $(cat /opt/skystation.anterior/VERSION)"
            rm -rf /opt/skystation.troca
            mv /opt/skystation /opt/skystation.troca && mv /opt/skystation.anterior /opt/skystation \
                && mv /opt/skystation.troca /opt/skystation.anterior && echo "Versão anterior restaurada"
            # emuladores instalados depois daquela versão continuam valendo (não fazem parte da "versão")
            cp -n /opt/skystation.anterior/emu/cores/*.so /opt/skystation/emu/cores/ 2>/dev/null || true
        } > "$D/log" 2>&1 && estado ok || estado erro
    else
        echo "não há versão anterior guardada" > "$D/log"; estado erro
    fi
    exit 0
fi
rm -f "$P/atualizar"
if /usr/local/bin/skystation-atualizar --github > "$D/log" 2>&1; then
    estado ok
else
    estado erro
fi
