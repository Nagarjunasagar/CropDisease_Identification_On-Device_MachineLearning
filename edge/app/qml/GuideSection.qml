import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string title
    property var items: []
    property color textColor: "#E8EFEA"
    property color mutedColor: "#9DB0A6"
    property color accent: "#6BCB77"
    spacing: 6
    visible: items && items.length > 0

    Text {
        text: root.title.toUpperCase()
        color: root.mutedColor
        font.pixelSize: 11
        font.letterSpacing: 1.0
        font.weight: Font.DemiBold
    }
    Repeater {
        model: root.items
        delegate: RowLayout {
            required property string modelData
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 7
                width: 5; height: 5; radius: 2.5
                color: root.accent
            }
            Text {
                text: modelData
                color: root.textColor
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                lineHeight: 1.15
                Layout.fillWidth: true
            }
        }
    }
}
