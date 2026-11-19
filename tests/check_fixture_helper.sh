#!/bin/sh
# Testes NÃO destrutivos de tests/with_en_fixtures.sh: roda o helper de uma CÓPIA do repositório num diretório
# temporário próprio (nunca o repositório real) e confere que destinos perigosos são recusados sem apagar nada.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd -P)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/work/repo"
(cd "$REPO" && tar --exclude=./_site --exclude=./.jekyll-cache --exclude=./.git -cf - .) | (cd "$T/work/repo" && tar -xf -)
H="$T/work/repo/tests/with_en_fixtures.sh"
fail=0
refuse() {  # $1 = destino, $2 = descrição
  if sh "$H" "$1" >/dev/null 2>&1; then echo "FAIL $2: aceito"; fail=1; else echo "ok   $2: recusado"; fi
}
refuse "$T/work/repo" "o próprio repositório"
refuse "$T/work" "ancestral do repositório"
refuse "$T/work/repo/tests/out" "dentro do repositório"
mkdir -p "$T/alheio" && echo dado > "$T/alheio/arquivo"
refuse "$T/alheio" "diretório existente não criado pelo helper"
[ -f "$T/work/repo/_config.yml" ] && [ -f "$T/alheio/arquivo" ] && echo "ok   nada foi apagado" || { echo "FAIL algo foi apagado"; fail=1; }
sh "$H" "$T/novo" >/dev/null && [ -f "$T/novo/.with-en-fixtures" ] && echo "ok   destino novo criado" || { echo "FAIL destino novo"; fail=1; }
sh "$H" "$T/novo" >/dev/null && echo "ok   destino do próprio helper recriado" || { echo "FAIL recriar"; fail=1; }
exit $fail
