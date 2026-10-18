#!/usr/bin/env bash
# Собирает «САНБОЙ ШАМАН.app» для Apple Silicon: dist/SunboyShaman.zip и установщик dist/SunboyShaman.dmg.
# Нужен macOS с Xcode или Command Line Tools (xcode-select --install): scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
NAME="САНБОЙ ШАМАН"
APP="dist/$NAME.app"

swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SunboyShaman" "$APP/Contents/MacOS/SunboyShaman"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"

# Подпись без сертификата разработчика (ad-hoc): для запуска на своём Mac этого хватает.
codesign --force --sign - --identifier ru.cybertatar.sunboyshaman "$APP"
codesign --verify --verbose "$APP"

(cd dist && ditto -c -k --keepParent "$NAME.app" SunboyShaman.zip)

# Образ диска: окно с фоном, где шамана перетаскивают в «Программы».
python3 -m venv dist/venv
dist/venv/bin/pip install -q "dmgbuild>=1.6,<2"
tiffutil -cathidpicheck Resources/dmg-background.png Resources/dmg-background@2x.png -out dist/dmg-background.tiff
dist/venv/bin/dmgbuild -s scripts/dmg.py "$NAME" dist/SunboyShaman.dmg
echo "Готово: dist/SunboyShaman.zip, dist/SunboyShaman.dmg"
