import QtQuick
import QtQuick.Layouts

// One labelled probability bar.
ColumnLayout {
    id: root
    property string label
    property real value: 0
    property bool emphasis: false
    property color barColor: "#6BCB77"
    property color trackColor: "#26322D"
    property color textColor: "#E8EFEA"
    property color mutedColor: "#9DB0A6"
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: root.label
            color: root.emphasis ? root.textColor : root.mutedColor
            font.pixelSize: root.emphasis ? 15 : 13
            font.weight: root.emphasis ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            text: (root.value * 100).toFixed(root.value < 0.1 ? 1 : 0) + "%"
            color: root.emphasis ? root.textColor : root.mutedColor
            font.pixelSize: 13
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: root.emphasis ? 8 : 5
        radius: height / 2
        color: root.trackColor
        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: root.barColor
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }
}
