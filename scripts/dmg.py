# Настройки окна установщика для dmgbuild (вызывает scripts/build-app.sh).
# Координаты иконок совпадают со стрелкой на фоне, см. tools/sprites/dmg_background.py.

import unicodedata

app = "dist/САНБОЙ ШАМАН.app"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = app + "/Contents/Resources/AppIcon.icns"
background = "dist/dmg-background.tiff"

window_rect = ((200, 120), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
# «Й» файловая система образа может хранить разложенной (И + бреве): пишем раскладку
# для обеих форм имени, иначе Finder не узнает иконку и поставит её куда попало.
icon_locations = {
    unicodedata.normalize("NFC", "САНБОЙ ШАМАН.app"): (160, 200),
    unicodedata.normalize("NFD", "САНБОЙ ШАМАН.app"): (160, 200),
    "Applications": (480, 200),
}

format = "UDZO"
