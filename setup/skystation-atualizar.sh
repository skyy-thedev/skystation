#!/bin/bash
# SkyStation: atualiza o console.   Uso:  sudo skystation-atualizar [--github]
#  - Na VM (pasta compartilhada /mnt/skystation): usa a pasta do projeto no Windows.
#  - No notebook (ou com --github): baixa a versão mais nova do GitHub.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo."; exit 1; }

REPO="skyy-thedev/skystation"
BRANCH="main"
SRC="/opt/skystation-src"

if [ "${1:-}" != "--github" ] && [ -f /mnt/skystation/setup/atualizar.sh ]; then
    exec bash /mnt/skystation/setup/atualizar.sh
fi

echo "==> Baixando $REPO ($BRANCH) do GitHub"
SHA="$(curl -fsSL --max-time 20 "https://api.github.com/repos/$REPO/commits/$BRANCH" \
       | python3 -c 'import sys,json; print(json.load(sys.stdin)["sha"][:7])' 2>/dev/null || true)"
TMP="$(mktemp -d /opt/skystation-src.XXXXXX)"
if ! curl -fsSL --max-time 120 "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" \
        | tar xz -C "$TMP" --strip-components=1; then
    rm -rf "$TMP"
    echo "Falha no download. Confira a internet (nmtui) e tente de novo."; exit 1
fi
[ -f "$TMP/setup/atualizar.sh" ] || { rm -rf "$TMP"; echo "Download incompleto."; exit 1; }
echo "${SHA:-?}" > "$TMP/.commit"
rm -rf "$SRC"
mv "$TMP" "$SRC"
chmod 755 "$SRC"
echo "==> Versão baixada: ${SHA:-desconhecida}"
exec bash "$SRC/setup/atualizar.sh"
