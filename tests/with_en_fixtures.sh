#!/bin/sh
# Copia o site para <destino> com os posts SINTÉTICOS de teste de tests/fixtures/*/_posts (inglês e casos de borda
# do feed; só para testes: nunca vão para _posts do repositório nem são publicados). Depois: cd <destino> &&
# bundle exec jekyll build && bundle exec ruby tests/check_site.rb _site
#
# Segurança: o destino não pode ser o repositório, estar dentro dele ou ser um ancestral dele, e só é apagado se
# não existir, estiver vazio ou tiver sido criado por este script (marcador .with-en-fixtures).
set -eu
[ $# -eq 1 ] && [ -n "$1" ] || { echo "uso: $0 <destino>" >&2; exit 2; }
SRC=$(cd "$(dirname "$0")/.." && pwd -P)
mkdir -p "$(dirname "$1")"
DEST=$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")
case "$DEST/" in
  "$SRC"/*) echo "recusado: o destino está dentro do repositório" >&2; exit 3 ;;
esac
case "$SRC/" in
  "$DEST"/*) echo "recusado: o destino é o repositório ou um ancestral dele" >&2; exit 3 ;;
esac
if [ -e "$DEST" ]; then
  if [ ! -d "$DEST" ] || { [ -n "$(ls -A "$DEST")" ] && [ ! -f "$DEST/.with-en-fixtures" ]; }; then
    echo "recusado: $DEST já existe e não foi criado por este script" >&2; exit 3
  fi
  rm -rf "$DEST"
fi
mkdir -p "$DEST"
(cd "$SRC" && tar --exclude=./_site --exclude=./.jekyll-cache --exclude=./.git --exclude=./vendor -cf - .) | (cd "$DEST" && tar -xf -)
cp "$SRC"/tests/fixtures/*/_posts/*.md "$DEST/_posts/"
touch "$DEST/.with-en-fixtures"
echo "site com fixtures em $DEST"
