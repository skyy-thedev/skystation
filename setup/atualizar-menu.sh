#!/bin/bash
# SkyStation: roda como root pelo skystation-atualizar.service.
# O menu do console só cria um arquivo-pedido (sem sudo, sem senha); o systemd vê o pedido
# e chama este script, que escreve o andamento em /var/lib/skystation/atualizar/.
D=/var/lib/skystation/atualizar
P=/var/lib/skystation/pedidos/atualizar
install -d -m 755 "$D"
rm -f "$P"
estado() { echo "$1" > "$D/estado.new" && mv -f "$D/estado.new" "$D/estado"; }
estado rodando
if /usr/local/bin/skystation-atualizar --github > "$D/log" 2>&1; then
    estado ok
else
    estado erro
fi
