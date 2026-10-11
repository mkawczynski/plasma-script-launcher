import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

RowLayout {
    id: field

    property string value
    property string emptyText: i18n("Default")
    signal picked(string color)

    QQC2.Button {
        text: field.value || field.emptyText
        onClicked: {
            dialog.selectedColor = field.value || Kirigami.Theme.textColor;
            dialog.open();
        }
        leftPadding: swatch.width + Kirigami.Units.largeSpacing * 2

        Rectangle {
            id: swatch
            x: Kirigami.Units.smallSpacing * 2
            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.gridUnit
            height: width
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor
            color: field.value || "transparent"
        }
    }
    QQC2.ToolButton {
        icon.name: "edit-clear"
        visible: field.value !== ""
        onClicked: field.picked("")
        QQC2.ToolTip.text: i18n("Restore default")
        QQC2.ToolTip.visible: hovered
    }

    ColorDialog {
        id: dialog
        onAccepted: field.picked(selectedColor.toString())
    }
}
