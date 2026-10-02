import QtQuick

// Theme-matched button (avoids depending on a particular Controls style).
Rectangle {
    id: root
    property string text
    property bool primary: false
    property color accent: "#6BCB77"
    property color surface: "#1B2420"
    property color line: "#26322D"
    property color textColor: "#E8EFEA"
    signal clicked()

    implicitWidth: label.implicitWidth + 36
    implicitHeight: 40
    radius: 20
    opacity: enabled ? 1.0 : 0.4
    color: primary ? (mouse.pressed ? Qt.darker(accent, 1.2) : mouse.containsMouse ? Qt.lighter(accent, 1.08) : accent)
                   : (mouse.pressed ? Qt.darker(surface, 1.2) : mouse.containsMouse ? Qt.lighter(surface, 1.3) : surface)
    border.color: primary ? "transparent" : line
    Accessible.role: Accessible.Button
    Accessible.name: text

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? "#0E1311" : root.textColor
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
