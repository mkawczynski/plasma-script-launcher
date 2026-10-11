import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "TreeUtils.js" as TreeUtils

Item {
    id: view

    property var tree: []
    property string title
    property bool active: false
    signal launch(var node)
    signal closeRequested

    // List mode: stack of opened drawers. Tree mode: expanded drawer keys.
    property var path: []
    property var expandedMap: ({})

    readonly property bool treeMode: Plasmoid.configuration.viewMode === 1
    readonly property bool custom: Plasmoid.configuration.useCustomColors
    readonly property color baseText: custom && Plasmoid.configuration.textColor
                                      ? Plasmoid.configuration.textColor : Kirigami.Theme.textColor
    readonly property color baseBg: custom && Plasmoid.configuration.backgroundColor
                                    ? Plasmoid.configuration.backgroundColor : "transparent"
    readonly property color hiColor: custom && Plasmoid.configuration.highlightColor
                                     ? Plasmoid.configuration.highlightColor : Kirigami.Theme.highlightColor
    readonly property color hiText: custom && Plasmoid.configuration.textColor
                                    ? Plasmoid.configuration.textColor : Kirigami.Theme.highlightedTextColor

    readonly property var rows: buildRows(tree, path, expandedMap, treeMode)

    Layout.preferredWidth: Kirigami.Units.gridUnit * Plasmoid.configuration.popupWidth
    Layout.preferredHeight: Kirigami.Units.gridUnit * Plasmoid.configuration.popupHeight
    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: Kirigami.Units.gridUnit * 8

    onTreeChanged: {
        path = [];
        expandedMap = ({});
    }
    onActiveChanged: {
        if (active) {
            path = [];
            setCurrent(-1);
            list.forceActiveFocus();
        }
    }
    Component.onCompleted: list.forceActiveFocus()

    function buildRows(nodes, pathStack, expanded, isTree) {
        const out = [];
        if (!isTree) {
            const cur = pathStack.length ? pathStack[pathStack.length - 1].children : nodes;
            for (let i = 0; i < cur.length; ++i)
                out.push({ node: cur[i], depth: 0, key: "" + i });
            return out;
        }
        const walk = (list, depth, prefix) => {
            for (let i = 0; i < list.length; ++i) {
                const key = prefix + "/" + i;
                out.push({ node: list[i], depth: depth, key: key });
                if (list[i].type === "drawer" && expanded[key])
                    walk(list[i].children || [], depth + 1, key);
            }
        };
        walk(nodes, 0, "");
        return out;
    }

    function setExpanded(key, value) {
        const m = Object.assign({}, expandedMap);
        if (value)
            m[key] = true;
        else
            delete m[key];
        expandedMap = m;
    }

    // Deferred, because a model change resets the ListView's current index.
    function setCurrent(i) {
        Qt.callLater(() => list.currentIndex = i);
    }

    function expandAndEnter(index) {
        const row = rows[index];
        setExpanded(row.key, true);
        if (row.node.children && row.node.children.length > 0)
            setCurrent(index + 1);
        else
            setCurrent(index);
    }

    function activate(index) {
        if (index < 0 || index >= rows.length)
            return;
        const row = rows[index];
        if (row.node.type === "drawer") {
            if (treeMode) {
                if (expandedMap[row.key])
                    setExpanded(row.key, false);
                else
                    expandAndEnter(index);
            } else {
                path = path.concat([row.node]);
                setCurrent(0);
            }
        } else {
            launch(row.node);
        }
    }

    function goUp() {
        if (!treeMode && path.length > 0) {
            path = path.slice(0, -1);
            setCurrent(0);
        } else {
            closeRequested();
        }
    }

    function parentIndex(index) {
        const depth = rows[index].depth;
        for (let i = index - 1; i >= 0; --i)
            if (rows[i].depth < depth)
                return i;
        return -1;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2
            color: view.baseBg

            PlasmaComponents.Label {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.bold: true
                text: view.title
                color: view.baseText
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        RowLayout {
            visible: !view.treeMode && view.path.length > 0
            Layout.fillWidth: true
            PlasmaComponents.ToolButton {
                icon.name: "go-previous"
                onClicked: {
                    view.goUp();
                    list.forceActiveFocus();
                }
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.bold: true
                text: view.path.map(n => n.name).join(" › ")
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: view.rows
            focus: true
            keyNavigationEnabled: false
            highlightMoveDuration: 0
            currentIndex: -1

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Up:
                    if (count > 0)
                        currentIndex = currentIndex <= 0 ? count - 1 : currentIndex - 1;
                    break;
                case Qt.Key_Down:
                    if (count > 0)
                        currentIndex = currentIndex < 0 || currentIndex >= count - 1 ? 0 : currentIndex + 1;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (currentIndex < 0)
                        currentIndex = count > 0 ? 0 : -1;
                    else
                        view.activate(currentIndex);
                    break;
                case Qt.Key_Escape:
                    if (view.treeMode)
                        view.closeRequested();
                    else
                        view.goUp();
                    break;
                case Qt.Key_Backspace:
                    if (view.treeMode && currentIndex >= 0) {
                        const r = view.rows[currentIndex];
                        if (r.node.type === "drawer" && view.expandedMap[r.key])
                            view.setExpanded(r.key, false);
                        else if (view.parentIndex(currentIndex) >= 0)
                            currentIndex = view.parentIndex(currentIndex);
                    } else {
                        view.goUp();
                    }
                    break;
                case Qt.Key_Right:
                    if (currentIndex >= 0 && view.rows[currentIndex].node.type === "drawer") {
                        const r = view.rows[currentIndex];
                        if (!view.treeMode)
                            view.activate(currentIndex);
                        else if (!view.expandedMap[r.key])
                            view.expandAndEnter(currentIndex);
                    }
                    break;
                case Qt.Key_Left:
                    if (view.treeMode && currentIndex >= 0) {
                        const r = view.rows[currentIndex];
                        if (r.node.type === "drawer" && view.expandedMap[r.key])
                            view.setExpanded(r.key, false);
                        else if (view.parentIndex(currentIndex) >= 0)
                            currentIndex = view.parentIndex(currentIndex);
                    } else if (!view.treeMode && view.path.length > 0) {
                        view.goUp();
                    }
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                readonly property var node: modelData.node
                readonly property bool selected: ListView.isCurrentItem

                width: ListView.view.width
                height: Kirigami.Units.gridUnit * 2
                radius: Kirigami.Units.cornerRadius
                color: selected ? view.hiColor : (node.bg ? node.bg : view.baseBg)

                readonly property color fg: node.color ? node.color : (selected ? view.hiText : view.baseText)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.smallSpacing + modelData.depth * Kirigami.Units.gridUnit * 1.2
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        visible: view.treeMode
                        opacity: node.type === "drawer" ? 1 : 0
                        source: view.expandedMap[modelData.key] ? "go-down" : "go-next"
                        color: item.fg
                        isMask: true
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                    }
                    Kirigami.Icon {
                        source: TreeUtils.defaultIcon(node)
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: node.name
                        color: item.fg
                        elide: Text.ElideRight
                    }
                    Kirigami.Icon {
                        visible: !view.treeMode && node.type === "drawer"
                        source: "go-next"
                        color: item.fg
                        isMask: true
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: list.currentIndex = item.index
                    onClicked: {
                        list.currentIndex = item.index;
                        view.activate(item.index);
                    }
                }
            }

            PlasmaComponents.Label {
                anchors.centerIn: parent
                visible: list.count === 0
                width: parent.width - Kirigami.Units.gridUnit * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: i18n("No launchers. Add them in the widget settings.")
            }
        }
    }
}
