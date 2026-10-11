import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_icon
    property string cfg_title
    property string cfg_terminalCommand
    property int cfg_viewMode
    property bool cfg_useCustomColors
    property string cfg_textColor
    property string cfg_backgroundColor
    property string cfg_highlightColor
    property int cfg_popupWidth
    property int cfg_popupHeight

    property string cfg_iconDefault
    property string cfg_titleDefault
    property string cfg_terminalCommandDefault
    property int cfg_viewModeDefault
    property bool cfg_useCustomColorsDefault
    property string cfg_textColorDefault
    property string cfg_backgroundColorDefault
    property string cfg_highlightColorDefault
    property int cfg_popupWidthDefault
    property int cfg_popupHeightDefault

    Kirigami.FormLayout {
        IconField {
            Kirigami.FormData.label: i18n("Panel icon:")
            value: page.cfg_icon
            onPicked: name => page.cfg_icon = name || "folder"
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Title:")
            placeholderText: i18n("Script Launcher")
            text: page.cfg_title
            onTextEdited: page.cfg_title = text
        }

        QQC2.TextField {
            Kirigami.FormData.label: i18n("Terminal:")
            placeholderText: i18n("KDE default terminal")
            text: page.cfg_terminalCommand
            onTextEdited: page.cfg_terminalCommand = text
        }
        QQC2.Label {
            text: i18n("Custom command must include the flag that runs a program, e.g. \"konsole -e\" or \"gnome-terminal --\".")
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("View:")
            model: [i18n("List (enter drawers)"), i18n("Tree")]
            currentIndex: page.cfg_viewMode
            onActivated: index => page.cfg_viewMode = index
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Window width:")
            from: 12
            to: 60
            value: page.cfg_popupWidth
            onValueModified: page.cfg_popupWidth = value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Window height:")
            from: 8
            to: 60
            value: page.cfg_popupHeight
            onValueModified: page.cfg_popupHeight = value
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Colors:")
            text: i18n("Use custom colors")
            checked: page.cfg_useCustomColors
            onToggled: page.cfg_useCustomColors = checked
        }
        ColorField {
            Kirigami.FormData.label: i18n("Text color:")
            enabled: page.cfg_useCustomColors
            value: page.cfg_textColor
            onPicked: c => page.cfg_textColor = c
        }
        ColorField {
            Kirigami.FormData.label: i18n("Entry background color:")
            enabled: page.cfg_useCustomColors
            value: page.cfg_backgroundColor
            onPicked: c => page.cfg_backgroundColor = c
        }
        ColorField {
            Kirigami.FormData.label: i18n("Highlight color:")
            enabled: page.cfg_useCustomColors
            value: page.cfg_highlightColor
            onPicked: c => page.cfg_highlightColor = c
        }
        QQC2.Label {
            text: i18n("Colors of individual entries can be overridden in the \"Launchers\" tab.")
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
        }
    }
}
