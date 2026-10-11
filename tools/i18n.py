#!/usr/bin/env python3
"""Generates po/*.po, po/template.pot, compiled .mo catalogs and the localized
Name/Description entries in metadata.json.

Source strings in the QML files are English; translations live in this file.
Run from anywhere: python3 tools/i18n.py
"""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / "package"
PO = ROOT / "po"
DOMAIN = "plasma_applet_org.kde.plasma.scriptlauncher"

# Order of the values in every row: pl de es fr it pt_BR ru uk cs nl ja zh_CN
LANGS = ["pl", "de", "es", "fr", "it", "pt_BR", "ru", "uk", "cs", "nl", "ja", "zh_CN"]

T = {
    "General": ["Ogólne", "Allgemein", "General", "Général", "Generale", "Geral", "Общие", "Загальні", "Obecné", "Algemeen", "一般", "常规"],
    "Launchers": ["Uruchamiacze", "Starter", "Lanzadores", "Lanceurs", "Lanciatori", "Lançadores", "Запускатели", "Запускачі", "Spouštěče", "Starters", "ランチャー", "启动项"],
    "Script Launcher": ["Uruchamiacz skryptów", "Skript-Starter", "Lanzador de scripts", "Lanceur de scripts", "Lanciatore di script", "Lançador de scripts", "Запуск скриптов", "Запуск скриптів", "Spouštěč skriptů", "Scriptstarter", "スクリプトランチャー", "脚本启动器"],
    "No launchers. Add them in the widget settings.": [
        "Brak uruchamiaczy. Dodaj je w ustawieniach widgetu.",
        "Keine Starter. Fügen Sie diese in den Einstellungen der Minianwendung hinzu.",
        "No hay lanzadores. Añádalos en la configuración del widget.",
        "Aucun lanceur. Ajoutez-en dans la configuration du composant.",
        "Nessun lanciatore. Aggiungili nelle impostazioni del widget.",
        "Nenhum lançador. Adicione-os nas configurações do widget.",
        "Нет элементов запуска. Добавьте их в настройках виджета.",
        "Немає елементів запуску. Додайте їх у налаштуваннях віджета.",
        "Žádné spouštěče. Přidejte je v nastavení widgetu.",
        "Geen starters. Voeg ze toe in de instellingen van de widget.",
        "ランチャーがありません。ウィジェットの設定で追加してください。",
        "没有启动项。请在小部件设置中添加。"],
    "Default": ["Domyślny", "Standard", "Predeterminado", "Par défaut", "Predefinito", "Padrão", "По умолчанию", "Типово", "Výchozí", "Standaard", "デフォルト", "默认"],
    "Restore default": ["Przywróć domyślny", "Standard wiederherstellen", "Restaurar predeterminado", "Rétablir la valeur par défaut", "Ripristina predefinito", "Restaurar padrão", "Восстановить по умолчанию", "Відновити типове", "Obnovit výchozí", "Standaard herstellen", "デフォルトに戻す", "恢复默认"],
    "Restore default icon": ["Przywróć domyślną ikonę", "Standardsymbol wiederherstellen", "Restaurar icono predeterminado", "Rétablir l'icône par défaut", "Ripristina icona predefinita", "Restaurar ícone padrão", "Восстановить значок по умолчанию", "Відновити типовий значок", "Obnovit výchozí ikonu", "Standaardpictogram herstellen", "デフォルトのアイコンに戻す", "恢复默认图标"],
    "Launcher": ["Uruchamiacz", "Starter", "Lanzador", "Lanceur", "Lanciatore", "Lançador", "Запускатель", "Запускач", "Spouštěč", "Starter", "ランチャー", "启动项"],
    "Drawer": ["Szuflada", "Schublade", "Cajón", "Tiroir", "Cassetto", "Gaveta", "Ящик", "Шухляда", "Zásuvka", "Lade", "ドロワー", "抽屉"],
    "New launcher": ["Nowy uruchamiacz", "Neuer Starter", "Nuevo lanzador", "Nouveau lanceur", "Nuovo lanciatore", "Novo lançador", "Новый запускатель", "Новий запускач", "Nový spouštěč", "Nieuwe starter", "新しいランチャー", "新建启动项"],
    "New drawer": ["Nowa szuflada", "Neue Schublade", "Nuevo cajón", "Nouveau tiroir", "Nuovo cassetto", "Nova gaveta", "Новый ящик", "Нова шухляда", "Nová zásuvka", "Nieuwe lade", "新しいドロワー", "新建抽屉"],
    "Remove": ["Usuń", "Entfernen", "Quitar", "Supprimer", "Rimuovi", "Remover", "Удалить", "Видалити", "Odebrat", "Verwijderen", "削除", "移除"],
    "Move up": ["Przesuń w górę", "Nach oben", "Subir", "Monter", "Sposta su", "Mover para cima", "Вверх", "Вгору", "Posunout nahoru", "Omhoog", "上へ移動", "上移"],
    "Move down": ["Przesuń w dół", "Nach unten", "Bajar", "Descendre", "Sposta giù", "Mover para baixo", "Вниз", "Вниз", "Posunout dolů", "Omlaag", "下へ移動", "下移"],
    "Move out of drawer": ["Wyjmij z szuflady", "Aus Schublade herausnehmen", "Sacar del cajón", "Sortir du tiroir", "Estrai dal cassetto", "Tirar da gaveta", "Вынуть из ящика", "Вийняти з шухляди", "Vyjmout ze zásuvky", "Uit lade halen", "ドロワーから出す", "移出抽屉"],
    "Put into the drawer above": ["Włóż do szuflady powyżej", "In die darüberliegende Schublade legen", "Meter en el cajón superior", "Mettre dans le tiroir au-dessus", "Inserisci nel cassetto sopra", "Colocar na gaveta acima", "Поместить в ящик выше", "Покласти в шухляду вище", "Vložit do zásuvky výše", "In de lade erboven plaatsen", "上のドロワーに入れる", "放入上方的抽屉"],
    "Drag the handle to reorder; moving right/left changes nesting.": [
        "Przeciągnij uchwyt, aby zmienić kolejność; przesunięcie w prawo/lewo zmienia zagnieżdżenie.",
        "Ziehen Sie den Griff, um die Reihenfolge zu ändern; Verschieben nach rechts/links ändert die Verschachtelung.",
        "Arrastre el asa para reordenar; moverla a la derecha o izquierda cambia el anidamiento.",
        "Faites glisser la poignée pour réordonner ; un déplacement à droite/gauche modifie l'imbrication.",
        "Trascina la maniglia per riordinare; spostarla a destra/sinistra cambia l'annidamento.",
        "Arraste a alça para reordenar; mover para a direita/esquerda altera o aninhamento.",
        "Перетащите маркер, чтобы изменить порядок; сдвиг вправо/влево меняет вложенность.",
        "Перетягніть маркер, щоб змінити порядок; зсув праворуч/ліворуч змінює вкладеність.",
        "Přetažením úchytu změníte pořadí; posun doprava/doleva mění zanoření.",
        "Sleep de greep om de volgorde te wijzigen; naar rechts/links verplaatsen wijzigt de nesting.",
        "ハンドルをドラッグして順序を変更します。左右に動かすと階層が変わります。",
        "拖动手柄可调整顺序；向右/向左移动可改变嵌套层级。"],
    "(unnamed)": ["(bez nazwy)", "(unbenannt)", "(sin nombre)", "(sans nom)", "(senza nome)", "(sem nome)", "(без имени)", "(без назви)", "(bez názvu)", "(naamloos)", "(名前なし)", "(未命名)"],
    "Name:": ["Nazwa:", "Name:", "Nombre:", "Nom :", "Nome:", "Nome:", "Название:", "Назва:", "Název:", "Naam:", "名前:", "名称:"],
    "Icon:": ["Ikona:", "Symbol:", "Icono:", "Icône :", "Icona:", "Ícone:", "Значок:", "Значок:", "Ikona:", "Pictogram:", "アイコン:", "图标:"],
    "Type:": ["Typ:", "Typ:", "Tipo:", "Type :", "Tipo:", "Tipo:", "Тип:", "Тип:", "Typ:", "Type:", "種類:", "类型:"],
    "Script": ["Skrypt", "Skript", "Script", "Script", "Script", "Script", "Скрипт", "Скрипт", "Skript", "Script", "スクリプト", "脚本"],
    "File to run": ["Plik do uruchomienia", "Auszuführende Datei", "Archivo a ejecutar", "Fichier à exécuter", "File da eseguire", "Arquivo a executar", "Файл для запуска", "Файл для запуску", "Soubor ke spuštění", "Uit te voeren bestand", "実行するファイル", "要运行的文件"],
    "Script:": ["Skrypt:", "Skript:", "Script:", "Script :", "Script:", "Script:", "Скрипт:", "Скрипт:", "Skript:", "Script:", "スクリプト:", "脚本:"],
    "File:": ["Plik:", "Datei:", "Archivo:", "Fichier :", "File:", "Arquivo:", "Файл:", "Файл:", "Soubor:", "Bestand:", "ファイル:", "文件:"],
    "Text color:": ["Kolor tekstu:", "Textfarbe:", "Color del texto:", "Couleur du texte :", "Colore del testo:", "Cor do texto:", "Цвет текста:", "Колір тексту:", "Barva textu:", "Tekstkleur:", "文字色:", "文字颜色:"],
    "From widget": ["Z widgetu", "Vom Widget", "Del widget", "Du composant", "Dal widget", "Do widget", "Из виджета", "З віджета", "Z widgetu", "Van widget", "ウィジェットから", "来自小部件"],
    "Background color:": ["Kolor tła:", "Hintergrundfarbe:", "Color de fondo:", "Couleur d'arrière-plan :", "Colore di sfondo:", "Cor de fundo:", "Цвет фона:", "Колір тла:", "Barva pozadí:", "Achtergrondkleur:", "背景色:", "背景颜色:"],
    "Panel icon:": ["Ikona na panelu:", "Symbol in der Leiste:", "Icono del panel:", "Icône du panneau :", "Icona del pannello:", "Ícone do painel:", "Значок на панели:", "Значок на панелі:", "Ikona na panelu:", "Paneelpictogram:", "パネルのアイコン:", "面板图标:"],
    "Title:": ["Tytuł:", "Titel:", "Título:", "Titre :", "Titolo:", "Título:", "Заголовок:", "Заголовок:", "Název:", "Titel:", "タイトル:", "标题:"],
    "Terminal:": ["Terminal:", "Terminal:", "Terminal:", "Terminal :", "Terminale:", "Terminal:", "Терминал:", "Термінал:", "Terminál:", "Terminal:", "ターミナル:", "终端:"],
    "KDE default terminal": ["Domyślny terminal KDE", "Standardterminal von KDE", "Terminal predeterminado de KDE", "Terminal par défaut de KDE", "Terminale predefinito di KDE", "Terminal padrão do KDE", "Терминал KDE по умолчанию", "Типовий термінал KDE", "Výchozí terminál KDE", "Standaardterminal van KDE", "KDE のデフォルトターミナル", "KDE 默认终端"],
    "Custom command must include the flag that runs a program, e.g. \"konsole -e\" or \"gnome-terminal --\".": [
        "Własne polecenie musi zawierać opcję uruchamiającą program, np. „konsole -e” lub „gnome-terminal --”.",
        "Ein eigener Befehl muss die Option zum Ausführen eines Programms enthalten, z. B. „konsole -e“ oder „gnome-terminal --“.",
        "El comando personalizado debe incluir la opción que ejecuta un programa, p. ej. «konsole -e» o «gnome-terminal --».",
        "La commande personnalisée doit inclure l'option qui exécute un programme, p. ex. « konsole -e » ou « gnome-terminal -- ».",
        "Il comando personalizzato deve includere l'opzione che esegue un programma, ad es. «konsole -e» o «gnome-terminal --».",
        "O comando personalizado deve incluir a opção que executa um programa, p. ex. \"konsole -e\" ou \"gnome-terminal --\".",
        "Своя команда должна включать параметр запуска программы, например «konsole -e» или «gnome-terminal --».",
        "Власна команда має містити параметр запуску програми, наприклад «konsole -e» або «gnome-terminal --».",
        "Vlastní příkaz musí obsahovat volbu pro spuštění programu, např. „konsole -e“ nebo „gnome-terminal --“.",
        "Een eigen opdracht moet de optie voor het uitvoeren van een programma bevatten, bijv. ‘konsole -e’ of ‘gnome-terminal --’.",
        "カスタムコマンドには、プログラムを実行するオプション (例: 「konsole -e」「gnome-terminal --」) を含めてください。",
        "自定义命令必须包含运行程序的选项，例如“konsole -e”或“gnome-terminal --”。"],
    "Run in terminal": ["Uruchom w terminalu", "In Terminal ausführen", "Ejecutar en terminal", "Exécuter dans un terminal", "Esegui nel terminale", "Executar no terminal", "Запустить в терминале", "Запустити в терміналі", "Spustit v terminálu", "In terminal uitvoeren", "ターミナルで実行", "在终端中运行"],
    "Press Enter to close...": ["Naciśnij Enter, aby zamknąć...", "Zum Schließen Eingabetaste drücken...", "Pulse Intro para cerrar...", "Appuyez sur Entrée pour fermer...", "Premi Invio per chiudere...", "Pressione Enter para fechar...", "Нажмите Enter, чтобы закрыть...", "Натисніть Enter, щоб закрити...", "Zavřete stisknutím Enter...", "Druk op Enter om te sluiten...", "Enter キーを押すと閉じます...", "按 Enter 键关闭..."],
    "Import...": ["Importuj...", "Importieren...", "Importar...", "Importer...", "Importa...", "Importar...", "Импорт...", "Імпорт...", "Importovat...", "Importeren...", "インポート...", "导入..."],
    "Export...": ["Eksportuj...", "Exportieren...", "Exportar...", "Exporter...", "Esporta...", "Exportar...", "Экспорт...", "Експорт...", "Exportovat...", "Exporteren...", "エクスポート...", "导出..."],
    "Launchers imported.": ["Zaimportowano uruchamiacze.", "Starter importiert.", "Lanzadores importados.", "Lanceurs importés.", "Lanciatori importati.", "Lançadores importados.", "Элементы запуска импортированы.", "Запускачі імпортовано.", "Spouštěče byly importovány.", "Starters geïmporteerd.", "ランチャーをインポートしました。", "已导入启动项。"],
    "Launchers exported.": ["Wyeksportowano uruchamiacze.", "Starter exportiert.", "Lanzadores exportados.", "Lanceurs exportés.", "Lanciatori esportati.", "Lançadores exportados.", "Элементы запуска экспортированы.", "Запускачі експортовано.", "Spouštěče byly exportovány.", "Starters geëxporteerd.", "ランチャーをエクスポートしました。", "已导出启动项。"],
    "Could not write the file.": ["Nie udało się zapisać pliku.", "Die Datei konnte nicht geschrieben werden.", "No se pudo escribir el archivo.", "Impossible d'écrire le fichier.", "Impossibile scrivere il file.", "Não foi possível gravar o arquivo.", "Не удалось записать файл.", "Не вдалося записати файл.", "Soubor se nepodařilo zapsat.", "Het bestand kon niet worden geschreven.", "ファイルを書き込めませんでした。", "无法写入文件。"],
    "The file could not be read or is not a valid launcher definition.": ["Nie udało się odczytać pliku lub nie jest to poprawna definicja uruchamiaczy.", "Die Datei konnte nicht gelesen werden oder ist keine gültige Starter-Definition.", "No se pudo leer el archivo o no es una definición de lanzadores válida.", "Impossible de lire le fichier ou ce n'est pas une définition de lanceurs valide.", "Impossibile leggere il file o non è una definizione di lanciatori valida.", "Não foi possível ler o arquivo ou ele não é uma definição de lançadores válida.", "Не удалось прочитать файл, либо это неверное описание элементов запуска.", "Не вдалося прочитати файл, або це некоректне визначення запускачів.", "Soubor se nepodařilo přečíst nebo nejde o platnou definici spouštěčů.", "Het bestand kon niet worden gelezen of is geen geldige starterdefinitie.", "ファイルを読み込めないか、有効なランチャー定義ではありません。", "无法读取文件，或不是有效的启动项定义。"],
    "Launcher definitions (*.json)": ["Definicje uruchamiaczy (*.json)", "Starter-Definitionen (*.json)", "Definiciones de lanzadores (*.json)", "Définitions de lanceurs (*.json)", "Definizioni dei lanciatori (*.json)", "Definições de lançadores (*.json)", "Описания элементов запуска (*.json)", "Визначення запускачів (*.json)", "Definice spouštěčů (*.json)", "Starterdefinities (*.json)", "ランチャー定義 (*.json)", "启动项定义 (*.json)"],
    "All files (*)": ["Wszystkie pliki (*)", "Alle Dateien (*)", "Todos los archivos (*)", "Tous les fichiers (*)", "Tutti i file (*)", "Todos os arquivos (*)", "Все файлы (*)", "Усі файли (*)", "Všechny soubory (*)", "Alle bestanden (*)", "すべてのファイル (*)", "所有文件 (*)"],
    "Import launchers": ["Import uruchamiaczy", "Starter importieren", "Importar lanzadores", "Importer des lanceurs", "Importa lanciatori", "Importar lançadores", "Импорт элементов запуска", "Імпорт запускачів", "Import spouštěčů", "Starters importeren", "ランチャーのインポート", "导入启动项"],
    "Replace the current launchers or append the imported ones?": ["Zastąpić obecne uruchamiacze czy dołączyć zaimportowane?", "Aktuelle Starter ersetzen oder die importierten anhängen?", "¿Reemplazar los lanzadores actuales o añadir los importados?", "Remplacer les lanceurs actuels ou ajouter ceux importés ?", "Sostituire i lanciatori attuali o aggiungere quelli importati?", "Substituir os lançadores atuais ou anexar os importados?", "Заменить текущие элементы запуска или добавить импортированные?", "Замінити поточні запускачі чи додати імпортовані?", "Nahradit stávající spouštěče, nebo připojit importované?", "Huidige starters vervangen of de geïmporteerde toevoegen?", "現在のランチャーを置き換えますか、それとも追加しますか?", "替换当前启动项还是追加导入的启动项?"],
    "Replace": ["Zastąp", "Ersetzen", "Reemplazar", "Remplacer", "Sostituisci", "Substituir", "Заменить", "Замінити", "Nahradit", "Vervangen", "置き換え", "替换"],
    "Append": ["Dołącz", "Anhängen", "Añadir", "Ajouter", "Aggiungi", "Anexar", "Добавить", "Додати", "Připojit", "Toevoegen", "追加", "追加"],
    "View:": ["Widok:", "Ansicht:", "Vista:", "Affichage :", "Vista:", "Exibição:", "Вид:", "Вигляд:", "Zobrazení:", "Weergave:", "表示:", "视图:"],
    "List (enter drawers)": ["Lista (wchodzenie w szuflady)", "Liste (Schubladen öffnen)", "Lista (entrar en los cajones)", "Liste (entrer dans les tiroirs)", "Elenco (entra nei cassetti)", "Lista (entrar nas gavetas)", "Список (вход в ящики)", "Список (вхід у шухляди)", "Seznam (vstup do zásuvek)", "Lijst (laden openen)", "リスト(ドロワーに入る)", "列表(进入抽屉)"],
    "Tree": ["Drzewo", "Baum", "Árbol", "Arborescence", "Albero", "Árvore", "Дерево", "Дерево", "Strom", "Boom", "ツリー", "树形"],
    "Window width:": ["Szerokość okna:", "Fensterbreite:", "Ancho de la ventana:", "Largeur de la fenêtre :", "Larghezza finestra:", "Largura da janela:", "Ширина окна:", "Ширина вікна:", "Šířka okna:", "Vensterbreedte:", "ウィンドウの幅:", "窗口宽度:"],
    "Window height:": ["Wysokość okna:", "Fensterhöhe:", "Alto de la ventana:", "Hauteur de la fenêtre :", "Altezza finestra:", "Altura da janela:", "Высота окна:", "Висота вікна:", "Výška okna:", "Vensterhoogte:", "ウィンドウの高さ:", "窗口高度:"],
    "Colors:": ["Kolory:", "Farben:", "Colores:", "Couleurs :", "Colori:", "Cores:", "Цвета:", "Кольори:", "Barvy:", "Kleuren:", "色:", "颜色:"],
    "Use custom colors": ["Użyj własnych kolorów", "Eigene Farben verwenden", "Usar colores personalizados", "Utiliser des couleurs personnalisées", "Usa colori personalizzati", "Usar cores personalizadas", "Использовать свои цвета", "Використовувати власні кольори", "Použít vlastní barvy", "Eigen kleuren gebruiken", "カスタムカラーを使用", "使用自定义颜色"],
    "Entry background color:": ["Kolor tła wpisu:", "Hintergrundfarbe des Eintrags:", "Color de fondo de la entrada:", "Couleur d'arrière-plan de l'entrée :", "Colore di sfondo della voce:", "Cor de fundo da entrada:", "Цвет фона элемента:", "Колір тла елемента:", "Barva pozadí položky:", "Achtergrondkleur van item:", "項目の背景色:", "条目背景颜色:"],
    "Highlight color:": ["Kolor zaznaczenia:", "Hervorhebungsfarbe:", "Color de resaltado:", "Couleur de surbrillance :", "Colore di evidenziazione:", "Cor de destaque:", "Цвет выделения:", "Колір виділення:", "Barva zvýraznění:", "Markeringskleur:", "強調色:", "高亮颜色:"],
    "Colors of individual entries can be overridden in the \"Launchers\" tab.": [
        "Kolory poszczególnych wpisów można nadpisać w zakładce „Uruchamiacze”.",
        "Die Farben einzelner Einträge können im Reiter „Starter“ überschrieben werden.",
        "Los colores de cada entrada se pueden sustituir en la pestaña «Lanzadores».",
        "Les couleurs de chaque entrée peuvent être remplacées dans l'onglet « Lanceurs ».",
        "I colori delle singole voci possono essere sostituiti nella scheda «Lanciatori».",
        "As cores de cada entrada podem ser substituídas na aba \"Lançadores\".",
        "Цвета отдельных элементов можно переопределить на вкладке «Запускатели».",
        "Кольори окремих елементів можна перевизначити на вкладці «Запускачі».",
        "Barvy jednotlivých položek lze přepsat na kartě „Spouštěče“.",
        "Kleuren van afzonderlijke items kunnen worden overschreven op het tabblad ‘Starters’.",
        "個々の項目の色は「ランチャー」タブで上書きできます。",
        "可在“启动项”选项卡中覆盖各条目的颜色。"],
    "Action started, but no script or file is defined.": [
        "Uruchomiono akcję, ale nie zdefiniowano skryptu ani pliku.",
        "Aktion gestartet, aber es ist kein Skript und keine Datei definiert.",
        "Acción iniciada, pero no se ha definido ningún script ni archivo.",
        "Action lancée, mais aucun script ni fichier n'est défini.",
        "Azione avviata, ma non è definito alcuno script o file.",
        "Ação iniciada, mas nenhum script ou arquivo foi definido.",
        "Действие запущено, но скрипт или файл не заданы.",
        "Дію запущено, але скрипт або файл не задано.",
        "Akce byla spuštěna, ale není definován žádný skript ani soubor.",
        "Actie gestart, maar er is geen script of bestand gedefinieerd.",
        "アクションを開始しましたが、スクリプトもファイルも定義されていません。",
        "操作已启动，但未定义脚本或文件。"],
}

DESCRIPTION = [
    "Ikona na panelu otwierająca konfigurowalne drzewo uruchamiaczy skryptów i plików",
    "Symbol in der Leiste, das einen konfigurierbaren Baum aus Skript- und Datei-Startern öffnet",
    "Icono del panel que abre un árbol configurable de lanzadores de scripts y archivos",
    "Icône du panneau ouvrant une arborescence configurable de lanceurs de scripts et de fichiers",
    "Icona del pannello che apre un albero configurabile di lanciatori di script e file",
    "Ícone do painel que abre uma árvore configurável de lançadores de scripts e arquivos",
    "Значок на панели, открывающий настраиваемое дерево запуска скриптов и файлов",
    "Значок на панелі, що відкриває настроюване дерево запуску скриптів і файлів",
    "Ikona na panelu otevírající konfigurovatelný strom spouštěčů skriptů a souborů",
    "Paneelpictogram dat een configureerbare boom met script- en bestandsstarters opent",
    "設定可能なスクリプト/ファイルランチャーのツリーを開くパネルアイコン",
    "在面板上打开可配置的脚本和文件启动项树的图标",
]


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def source_strings():
    found = []
    files = sorted((PKG / "contents/ui").glob("*.qml")) + sorted((PKG / "contents/config").glob("*.qml"))
    for f in files:
        for m in re.finditer(r'i18n\("((?:[^"\\]|\\.)*)"\)', f.read_text()):
            msg = m.group(1).replace('\\"', '"')
            if msg not in found:
                found.append(msg)
    return found


def main():
    msgs = source_strings()
    missing = [m for m in msgs if m not in T]
    unused = [m for m in T if m not in msgs]
    if missing or unused:
        raise SystemExit(f"Missing translations: {missing}\nUnused translations: {unused}")

    PO.mkdir(exist_ok=True)
    head = ('msgid ""\nmsgstr ""\n"Project-Id-Version: org.kde.plasma.scriptlauncher\\n"\n'
            '"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n'
            '"Content-Transfer-Encoding: 8bit\\n"\n%s')
    (PO / "template.pot").write_text(
        head % '"Language: \\n"\n' + "".join(f'\nmsgid "{esc(m)}"\nmsgstr ""\n' for m in msgs))

    for i, lang in enumerate(LANGS):
        body = head % f'"Language: {lang}\\n"\n' + "".join(
            f'\nmsgid "{esc(m)}"\nmsgstr "{esc(T[m][i])}"\n' for m in msgs)
        po = PO / f"{lang}.po"
        po.write_text(body)
        out = PKG / "contents/locale" / lang / "LC_MESSAGES" / f"{DOMAIN}.mo"
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["msgfmt", "-o", str(out), str(po)], check=True)

    meta_path = PKG / "metadata.json"
    meta = json.loads(meta_path.read_text())
    kp = meta["KPlugin"]
    for k in [k for k in kp if k.startswith(("Name[", "Description["))]:
        del kp[k]
    for i, lang in enumerate(LANGS):
        kp[f"Name[{lang}]"] = T["Script Launcher"][i]
        kp[f"Description[{lang}]"] = DESCRIPTION[i]
    meta_path.write_text(json.dumps(meta, indent=4, ensure_ascii=False) + "\n")
    print(f"{len(msgs)} strings, {len(LANGS)} languages")


if __name__ == "__main__":
    main()
