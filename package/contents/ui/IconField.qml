import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.iconthemes as KIconThemes
import org.kde.kirigami as Kirigami

RowLayout {
    id: field

    property string value
    property string fallback: "folder"
    signal picked(string name)

    QQC2.Button {
        icon.name: field.value || field.fallback
        text: field.value || i18n("Default")
        onClicked: dialog.open()
    }
    QQC2.ToolButton {
        icon.name: "edit-clear"
        visible: field.value !== ""
        onClicked: field.picked("")
        QQC2.ToolTip.text: i18n("Restore default icon")
        QQC2.ToolTip.visible: hovered
    }

    KIconThemes.IconDialog {
        id: dialog
        onIconNameChanged: iconName => {
            if (iconName)
                field.picked(iconName);
        }
    }
}
