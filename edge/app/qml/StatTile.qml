import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string title
    property string value
    property string unit
    property color textColor: "#E8EFEA"
    property color mutedColor: "#9DB0A6"
    radius: 10
    color: "#1B2420"
    implicitHeight: 64
    Layout.fillWidth: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2
        Text { text: root.title; color: root.mutedColor; font.pixelSize: 11; font.letterSpacing: 0.6 }
        Row {
            spacing: 3
            Text { id: valueText; text: root.value; color: root.textColor; font.pixelSize: 20; font.weight: Font.DemiBold }
            Text { text: root.unit; color: root.mutedColor; font.pixelSize: 12; anchors.baseline: valueText.baseline }
        }
    }
}
