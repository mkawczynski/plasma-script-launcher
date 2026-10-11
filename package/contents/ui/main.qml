import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "TreeUtils.js" as TreeUtils

PlasmoidItem {
    id: root

    readonly property var tree: TreeUtils.parse(Plasmoid.configuration.treeJson)

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: Plasmoid.configuration.icon
    readonly property string titleText: Plasmoid.configuration.title || i18n("Script Launcher")
    toolTipMainText: titleText

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }

    function run(node) {
        const cmd = TreeUtils.isEmpty(node)
            ? TreeUtils.notifyCommand(node.name || i18n("Launcher"),
                                      i18n("Action started, but no script or file is defined."),
                                      TreeUtils.defaultIcon(node), i18n("Script Launcher"))
            : TreeUtils.launchCommand(node, {
                terminal: Plasmoid.configuration.terminalCommand,
                closeMessage: i18n("Press Enter to close...")
            });
        if (cmd)
            runner.connectSource(cmd);
    }

    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.configuration.icon || "folder"
            active: parent.containsMouse
        }
    }

    fullRepresentation: LauncherView {
        tree: root.tree
        title: root.titleText
        active: root.expanded
        onLaunch: node => {
            root.expanded = false;
            root.run(node);
        }
        onCloseRequested: root.expanded = false
    }
}
