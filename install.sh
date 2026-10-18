#!/bin/sh
# Ставит или обновляет САНБОЙ ШАМАН:
#   curl -fsSL https://raw.githubusercontent.com/cybertatar/sunnyshamanlang/main/install.sh | sh
# Свежая сборка из рабочей ветки: … | SHAMAN_RELEASE=nightly sh
set -eu

RELEASE="${SHAMAN_RELEASE:-latest}"
URL="https://github.com/cybertatar/sunnyshamanlang/releases/download/$RELEASE/SunboyShaman.zip"
APP="/Applications/САНБОЙ ШАМАН.app"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ "$(uname -m)" != "arm64" ]; then
  echo "САНБОЙ ШАМАН собран для Mac на Apple Silicon (M1 и новее), на этом Mac он не запустится."
  exit 1
fi

echo "Шаман собирается в путь…"
curl -fsSL "$URL" -o "$TMP/app.zip"
ditto -x -k "$TMP/app.zip" "$TMP"

# Закрываем старую версию и сбрасываем выданный ей доступ: у новой сборки другая
# подпись, и старая галочка в «Универсальном доступе» перестаёт действовать.
pkill -x SunboyShaman 2>/dev/null || true
tccutil reset Accessibility ru.cybertatar.sunboyshaman >/dev/null 2>&1 || true
tccutil reset ListenEvent ru.cybertatar.sunboyshaman >/dev/null 2>&1 || true

echo "Ставлю в «Программы»…"
rm -rf "$APP"
ditto "$TMP/САНБОЙ ШАМАН.app" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

open "$APP"
echo "Готово! Осталось включить «САНБОЙ ШАМАН» в окне «Универсальный доступ», которое сейчас откроется."
