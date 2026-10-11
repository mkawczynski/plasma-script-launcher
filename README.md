# Script Launcher (KDE Plasma 6)

Widget panelu: ikona → lista/drzewo uruchamiaczy (skrypty bash/sh/fish lub pliki).

Instalacja / aktualizacja:

    kpackagetool6 -t Plasma/Applet -i package   # lub -u przy aktualizacji

Następnie: prawy klik na panelu → Dodaj widgety → „Uruchamiacz skryptów”.
Wiele instancji widgetu ma niezależne konfiguracje. Po aktualizacji: `plasmashell --replace &`.

Ustawienia: ikona, widok (lista/drzewo), rozmiar okna, kolory (widget + nadpisanie per wpis),
edytor drzewa (przeciąganie uchwytu zmienia kolejność, poziomo – zagnieżdżenie).

Klawisze: ↑/↓ nawigacja, Enter uruchamia/wchodzi w szufladę, Backspace/Esc – w górę lub zamknięcie
(w widoku drzewa: →/← rozwija/zwija, Esc zamyka).

## Tłumaczenia

Teksty w kodzie są po angielsku (domyślnie), tłumaczenia: pl, de, es, fr, it, pt_BR, ru, uk, cs, nl, ja, zh_CN.
Źródłem tłumaczeń jest `tools/i18n.py` – po zmianie tekstów `i18n("...")` lub dodaniu języka uruchom
`python3 tools/i18n.py` (generuje `po/*.po`, skompilowane `package/contents/locale/*/LC_MESSAGES/*.mo` oraz
lokalizowane `Name[..]`/`Description[..]` w `metadata.json`; wymaga `msgfmt`), a potem zaktualizuj paczkę.


cd package && zip -r ../org.kde.plasma.scriptlauncher.plasmoid . && cd ..