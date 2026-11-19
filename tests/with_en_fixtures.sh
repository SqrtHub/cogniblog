#!/bin/sh
# Copia o site para <destino> com os posts em inglês SINTÉTICOS de tests/fixtures/en (só para testes: nunca vão
# para _posts do repositório nem são publicados). Depois: cd <destino> && bundle exec jekyll build &&
# bundle exec ruby tests/check_site.rb _site
set -eu
DEST=$1
SRC=$(cd "$(dirname "$0")/.." && pwd)
rm -rf "$DEST" && mkdir -p "$DEST"
(cd "$SRC" && tar --exclude=./_site --exclude=./.jekyll-cache --exclude=./.git --exclude=./vendor -cf - .) | (cd "$DEST" && tar -xf -)
cp "$SRC"/tests/fixtures/en/_posts/*.md "$DEST/_posts/"
echo "site com fixtures em $DEST"
