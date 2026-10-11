import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support
import "TreeUtils.js" as TreeUtils

KCM.SimpleKCM {
    id: page

    property string cfg_treeJson
    property string cfg_treeJsonDefault

    readonly property int rowH: Kirigami.Units.gridUnit * 2
    readonly property int indent: Kirigami.Units.gridUnit * 1.5

    property var items: []
    property int sel: -1
    readonly property var current: sel >= 0 && sel < items.length ? items[sel] : null
    property string lastJson: ""

    // Drag state
    property int dragFrom: -1
    property int dropIndex: 0
    property int dropDepth: 0

    function reload() {
        if (cfg_treeJson === lastJson)
            return;
        lastJson = cfg_treeJson;
        items = TreeUtils.flatten(TreeUtils.parse(cfg_treeJson));
        sel = Math.min(sel, items.length - 1);
    }
    onCfg_treeJsonChanged: reload()
    Component.onCompleted: reload()

    function commit(newItems, newSel) {
        items = TreeUtils.normalize(newItems);
        if (newSel !== undefined)
            sel = newSel;
        lastJson = TreeUtils.serialize(items);
        cfg_treeJson = lastJson;
    }

    function setField(name, value) {
        const copy = items.slice();
        copy[sel] = Object.assign({}, copy[sel], { [name]: value });
        commit(copy);
    }

    function addNode(type) {
        const n = TreeUtils.newNode(type, type === "drawer" ? i18n("New drawer") : i18n("New launcher"));
        let at = items.length;
        n.depth = 0;
        if (sel >= 0) {
            at = TreeUtils.blockEnd(items, sel);
            n.depth = items[sel].type === "drawer" ? items[sel].depth + 1 : items[sel].depth;
        }
        const copy = items.slice();
        copy.splice(at, 0, n);
        commit(copy, at);
    }

    function removeSelected() {
        if (sel < 0)
            return;
        const copy = items.slice();
        copy.splice(sel, TreeUtils.blockEnd(items, sel) - sel);
        commit(copy, Math.min(sel, copy.length - 1));
    }

    function move(from, k, depth) {
        const r = TreeUtils.moveBlock(items, from, k, depth);
        commit(r.items, r.index);
    }

    // Deepest level allowed when inserting the dragged block before index k.
    function maxDepthAt(k, from) {
        const end = TreeUtils.blockEnd(items, from);
        let prev = k - 1;
        if (prev >= from && prev < end)
            prev = from - 1;
        if (prev < 0)
            return 0;
        return items[prev].type === "drawer" ? items[prev].depth + 1 : items[prev].depth;
    }

    function moveUp() {
        if (sel < 0)
            return;
        const d = items[sel].depth;
        for (let i = sel - 1; i >= 0; --i) {
            if (items[i].depth < d)
                return;
            if (items[i].depth === d) {
                move(sel, i, d);
                return;
            }
        }
    }

    function moveDown() {
        if (sel < 0)
            return;
        const end = TreeUtils.blockEnd(items, sel);
        if (end < items.length && items[end].depth === items[sel].depth)
            move(sel, TreeUtils.blockEnd(items, end), items[sel].depth);
    }

    function indentSel() {
        if (sel >= 0)
            move(sel, sel, items[sel].depth + 1);
    }

    function outdentSel() {
        if (sel < 0 || items[sel].depth === 0)
            return;
        const d = items[sel].depth - 1;
        let k = TreeUtils.blockEnd(items, sel);
        while (k < items.length && items[k].depth > d)
            k++;
        move(sel, k, d);
    }

    property var pendingImport: null
    property var ops: ({})

    function localPath(url) {
        return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
    }

    function showMessage(text, type) {
        message.text = text;
        message.type = type;
        message.visible = true;
    }

    function exportTo(url) {
        const cmd = "printf '%s\\n' " + TreeUtils.shellQuote(TreeUtils.exportJson(TreeUtils.unflatten(items))) +
                    " > " + TreeUtils.shellQuote(localPath(url));
        ops[cmd] = "export";
        io.connectSource(cmd);
    }

    function importFrom(url) {
        const cmd = "cat -- " + TreeUtils.shellQuote(localPath(url));
        ops[cmd] = "import";
        io.connectSource(cmd);
    }

    function applyImport(replace) {
        const added = TreeUtils.flatten(pendingImport);
        pendingImport = null;
        if (replace) {
            commit(added, added.length ? 0 : -1);
        } else {
            commit(items.concat(added), items.length);
        }
        showMessage(i18n("Launchers imported."), Kirigami.MessageType.Positive);
    }

    P5Support.DataSource {
        id: io
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            const op = page.ops[source];
            delete page.ops[source];
            const ok = data["exit code"] === 0;
            if (op === "export") {
                page.showMessage(ok ? i18n("Launchers exported.") : i18n("Could not write the file."),
                                 ok ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error);
            } else if (op === "import") {
                const parsed = ok ? TreeUtils.parseImport(data["stdout"]) : null;
                if (!parsed) {
                    page.showMessage(i18n("The file could not be read or is not a valid launcher definition."),
                                     Kirigami.MessageType.Error);
                } else if (page.items.length === 0) {
                    page.pendingImport = parsed;
                    page.applyImport(true);
                } else {
                    page.pendingImport = parsed;
                    importDialog.open();
                }
            }
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.InlineMessage {
            id: message
            Layout.fillWidth: true
            showCloseButton: true
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                icon.name: "list-add"
                text: i18n("Launcher")
                onClicked: page.addNode("script")
            }
            QQC2.Button {
                icon.name: "folder-new"
                text: i18n("Drawer")
                onClicked: page.addNode("drawer")
            }
            QQC2.Button {
                icon.name: "edit-delete"
                text: i18n("Remove")
                enabled: page.sel >= 0
                onClicked: page.removeSelected()
            }
            QQC2.Button {
                icon.name: "document-import"
                text: i18n("Import...")
                onClicked: importFileDialog.open()
            }
            QQC2.Button {
                icon.name: "document-export"
                text: i18n("Export...")
                enabled: page.items.length > 0
                onClicked: exportFileDialog.open()
            }
            QQC2.ToolButton {
                icon.name: "go-up"
                enabled: page.sel >= 0
                onClicked: page.moveUp()
                QQC2.ToolTip.text: i18n("Move up")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "go-down"
                enabled: page.sel >= 0
                onClicked: page.moveDown()
                QQC2.ToolTip.text: i18n("Move down")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "go-previous"
                enabled: page.sel >= 0
                onClicked: page.outdentSel()
                QQC2.ToolTip.text: i18n("Move out of drawer")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "go-next"
                enabled: page.sel >= 0
                onClicked: page.indentSel()
                QQC2.ToolTip.text: i18n("Put into the drawer above")
                QQC2.ToolTip.visible: hovered
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Drag the handle to reorder; moving right/left changes nesting.")
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 14
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: page.items
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: page.rowH
                    color: index === page.sel ? Qt.alpha(Kirigami.Theme.highlightColor, 0.35) : "transparent"
                    opacity: page.dragFrom === index ? 0.4 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.sel = row.index
                    }

                    RowLayout {
                        x: Kirigami.Units.smallSpacing + modelData.depth * page.indent
                        height: parent.height
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            id: handle
                            source: "handle-sort"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small

                            MouseArea {
                                property real startX
                                anchors.fill: parent
                                anchors.margins: -Kirigami.Units.smallSpacing
                                cursorShape: Qt.SizeAllCursor
                                preventStealing: true
                                onPressed: mouse => {
                                    page.sel = row.index;
                                    page.dragFrom = row.index;
                                    page.dropIndex = row.index;
                                    page.dropDepth = row.modelData.depth;
                                    startX = mapToItem(list.contentItem, mouse.x, mouse.y).x;
                                }
                                onPositionChanged: mouse => {
                                    if (page.dragFrom < 0)
                                        return;
                                    const p = mapToItem(list.contentItem, mouse.x, mouse.y);
                                    page.dropIndex = Math.max(0, Math.min(page.items.length, Math.round(p.y / page.rowH)));
                                    const wanted = row.modelData.depth + Math.round((p.x - startX) / (page.indent * 0.6));
                                    page.dropDepth = Math.max(0, Math.min(wanted, page.maxDepthAt(page.dropIndex, page.dragFrom)));
                                }
                                onReleased: {
                                    const from = page.dragFrom;
                                    page.dragFrom = -1;
                                    if (from >= 0)
                                        page.move(from, page.dropIndex, page.dropDepth);
                                }
                                onCanceled: page.dragFrom = -1
                            }
                        }
                        Kirigami.Icon {
                            source: TreeUtils.defaultIcon(modelData)
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        QQC2.Label {
                            text: modelData.name || i18n("(unnamed)")
                            font.bold: modelData.type === "drawer"
                        }
                    }
                }

                Rectangle {
                    visible: page.dragFrom >= 0
                    z: 10
                    height: 2
                    color: Kirigami.Theme.highlightColor
                    x: Kirigami.Units.smallSpacing + page.dropDepth * page.indent
                    width: list.width - x
                    y: page.dropIndex * page.rowH - 1
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        Kirigami.FormLayout {
            id: form
            Layout.fillWidth: true
            enabled: page.current !== null

            QQC2.TextField {
                Kirigami.FormData.label: i18n("Name:")
                text: page.current ? page.current.name : ""
                onTextEdited: page.setField("name", text)
            }
            IconField {
                Kirigami.FormData.label: i18n("Icon:")
                value: page.current ? page.current.icon : ""
                fallback: page.current ? TreeUtils.defaultIcon(page.current) : "system-run"
                onPicked: name => page.setField("icon", name)
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Type:")
                visible: page.current !== null
                model: [i18n("Script"), i18n("File to run"), i18n("Drawer")]
                readonly property var types: ["script", "file", "drawer"]
                currentIndex: page.current ? types.indexOf(page.current.type) : 0
                onActivated: index => {
                    const copy = page.items.slice();
                    copy[page.sel] = Object.assign({}, copy[page.sel], { type: types[index] });
                    // Only drawers may have children: the former subtree gets flattened by normalize().
                    page.commit(copy);
                }
            }
            QQC2.ScrollView {
                id: scriptScroll
                Kirigami.FormData.label: i18n("Script:")
                visible: page.current && page.current.type === "script"
                Layout.fillWidth: true
                // Fixed size so that the content never grows the view; it scrolls instead.
                implicitWidth: Kirigami.Units.gridUnit * 20
                implicitHeight: Kirigami.Units.gridUnit * 8
                Layout.minimumWidth: Kirigami.Units.gridUnit * 10
                Layout.minimumHeight: scriptArea.fontMetrics.height * 4 + Kirigami.Units.largeSpacing * 2
                Layout.preferredHeight: Kirigami.Units.gridUnit * 8
                Layout.maximumHeight: Kirigami.Units.gridUnit * 8
                clip: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AsNeeded
                QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

                QQC2.TextArea {
                    id: scriptArea
                    readonly property FontMetrics fontMetrics: FontMetrics { font: scriptArea.font }
                    font.family: "monospace"
                    wrapMode: TextEdit.NoWrap
                    placeholderText: "#!/usr/bin/env bash\nnotify-send hello"
                    text: page.current ? page.current.command : ""
                    onTextChanged: {
                        if (activeFocus && page.current && text !== page.current.command)
                            page.setField("command", text);
                    }
                }
            }
            RowLayout {
                Kirigami.FormData.label: i18n("File:")
                visible: page.current && page.current.type === "file"
                QQC2.TextField {
                    Layout.fillWidth: true
                    placeholderText: "~/bin/skrypt.sh"
                    text: page.current ? page.current.path : ""
                    onTextEdited: page.setField("path", text)
                }
                QQC2.Button {
                    icon.name: "document-open"
                    onClicked: fileDialog.open()
                }
            }
            QQC2.CheckBox {
                Kirigami.FormData.label: i18n("Terminal:")
                visible: page.current && page.current.type !== "drawer"
                text: i18n("Run in terminal")
                checked: page.current ? page.current.terminal === true : false
                onToggled: page.setField("terminal", checked)
            }
            ColorField {
                Kirigami.FormData.label: i18n("Text color:")
                value: page.current ? page.current.color : ""
                emptyText: i18n("From widget")
                onPicked: c => page.setField("color", c)
            }
            ColorField {
                Kirigami.FormData.label: i18n("Background color:")
                value: page.current ? page.current.bg : ""
                emptyText: i18n("From widget")
                onPicked: c => page.setField("bg", c)
            }
        }
    }

    FileDialog {
        id: fileDialog
        onAccepted: page.setField("path", decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, "")))
    }

    FileDialog {
        id: importFileDialog
        fileMode: FileDialog.OpenFile
        nameFilters: [i18n("Launcher definitions (*.json)"), i18n("All files (*)")]
        onAccepted: page.importFrom(selectedFile)
    }
    FileDialog {
        id: exportFileDialog
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [i18n("Launcher definitions (*.json)")]
        onAccepted: page.exportTo(selectedFile)
    }

    Kirigami.PromptDialog {
        id: importDialog
        title: i18n("Import launchers")
        subtitle: i18n("Replace the current launchers or append the imported ones?")
        standardButtons: QQC2.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: i18n("Replace")
                icon.name: "edit-undo"
                onTriggered: {
                    page.applyImport(true);
                    importDialog.close();
                }
            },
            Kirigami.Action {
                text: i18n("Append")
                icon.name: "list-add"
                onTriggered: {
                    page.applyImport(false);
                    importDialog.close();
                }
            }
        ]
        onRejected: page.pendingImport = null
    }
}
