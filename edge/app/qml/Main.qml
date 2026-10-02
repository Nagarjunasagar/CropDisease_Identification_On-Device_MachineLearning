import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia

ApplicationWindow {
    id: win
    width: 1280
    height: 780
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    title: "CroHeal Edge"
    color: theme.bg
    font.family: "Inter"

    QtObject {
        id: theme
        readonly property color bg: "#0E1311"
        readonly property color panel: "#151C19"
        readonly property color raised: "#1B2420"
        readonly property color line: "#26322D"
        readonly property color text: "#E8EFEA"
        readonly property color muted: "#9DB0A6"
        readonly property color leaf: "#6BCB77"     // healthy / accent
        readonly property color amber: "#F2A33A"    // disease detected
        readonly property color slate: "#8FA3B0"    // not sure
        readonly property color danger: "#FF6B5E"
    }

    // ------------------------------------------------------------ state
    readonly property var guide: analyzer.hasResult ? analyzer.info(analyzer.topLabel) : null
    readonly property bool healthy: analyzer.topLabel === "healthy"
    readonly property color verdictColor: !analyzer.hasResult ? theme.muted
                                          : analyzer.uncertain ? theme.slate
                                          : healthy ? theme.leaf : theme.amber
    readonly property bool hasCamera: devices.videoInputs.length > 0

    MediaDevices { id: devices }
    CaptureSession {
        id: session
        camera: Camera {
            id: camera
            cameraDevice: devices.defaultVideoInput
            active: analyzer.live
        }
        videoOutput: videoOut
    }
    Component.onCompleted: {
        analyzer.videoSink = videoOut.videoSink
        if (startLive && hasCamera) analyzer.live = true
    }

    FileDialog {
        id: openDialog
        title: "Choose a leaf photo"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.bmp)"]
        onAccepted: analyzer.analyzeFile(selectedFile)
    }

    // ------------------------------------------------------------ layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                width: 30; height: 30; radius: 8
                color: theme.leaf
                Text { anchors.centerIn: parent; text: "✿"; color: theme.bg; font.pixelSize: 17 }
            }
            Text { text: "CroHeal"; color: theme.text; font.pixelSize: 20; font.weight: Font.DemiBold }
            Text { text: "Edge"; color: theme.leaf; font.pixelSize: 20; font.weight: Font.Light }
            Item { Layout.fillWidth: true }
            Rectangle {
                radius: 14
                color: theme.panel
                border.color: theme.line
                implicitHeight: 28
                implicitWidth: modelText.implicitWidth + 24
                Text {
                    id: modelText
                    anchors.centerIn: parent
                    color: analyzer.ready ? theme.muted : theme.danger
                    font.pixelSize: 12
                    text: analyzer.ready
                          ? analyzer.modelName + "  ·  " + analyzer.inputSize + " px  ·  LiteRT + XNNPACK"
                          : (analyzer.error || "Loading model…")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // ---------------------------------------------------- viewer
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                Rectangle {
                    id: viewer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 16
                    color: theme.panel
                    border.color: theme.line
                    clip: true

                    VideoOutput {
                        id: videoOut
                        anchors.fill: parent
                        anchors.margins: 1
                        fillMode: VideoOutput.PreserveAspectFit
                        visible: analyzer.live
                    }
                    Image {
                        id: still
                        anchors.fill: parent
                        anchors.margins: 1
                        fillMode: Image.PreserveAspectFit
                        source: analyzer.stillImage
                        visible: !analyzer.live && analyzer.stillImage != ""
                        asynchronous: true
                        autoTransform: true
                    }

                    // Region the model actually sees: the centred square crop.
                    Item {
                        id: roi
                        readonly property rect content: analyzer.live
                            ? videoOut.contentRect
                            : Qt.rect((still.width - still.paintedWidth) / 2, (still.height - still.paintedHeight) / 2,
                                      still.paintedWidth, still.paintedHeight)
                        readonly property real side: Math.min(content.width, content.height)
                        visible: side > 0 && (analyzer.live || still.visible)
                        x: 1 + content.x + (content.width - side) / 2
                        y: 1 + content.y + (content.height - side) / 2
                        width: side
                        height: side

                        Repeater {
                            model: 4
                            delegate: Item {
                                required property int index
                                readonly property bool isRight: index % 2 === 1
                                readonly property bool isBottom: index > 1
                                width: 28; height: 28
                                x: isRight ? roi.width - width : 0
                                y: isBottom ? roi.height - height : 0
                                Rectangle { width: parent.width; height: 3; radius: 1.5; color: win.verdictColor
                                            y: isBottom ? parent.height - height : 0 }
                                Rectangle { width: 3; height: parent.height; radius: 1.5; color: win.verdictColor
                                            x: isRight ? parent.width - width : 0 }
                            }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            radius: 10
                            color: "#B30E1311"
                            implicitWidth: roiLabel.implicitWidth + 16
                            implicitHeight: 22
                            Text {
                                id: roiLabel
                                anchors.centerIn: parent
                                text: "model input · centre crop → " + analyzer.inputSize + "×" + analyzer.inputSize
                                color: theme.muted
                                font.pixelSize: 11
                            }
                        }
                    }

                    // empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: !analyzer.live && analyzer.stillImage == ""
                        spacing: 10
                        width: Math.min(parent.width - 80, 420)
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Point the camera at a single tomato leaf"
                            color: theme.text; font.pixelSize: 18; font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            color: theme.muted; font.pixelSize: 13
                            text: hasCamera
                                  ? "Start the live camera, or open a photo. Everything runs on this device."
                                  : "No camera detected. Open a photo to analyse it on this device."
                        }
                    }

                    // mode pill
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 14
                        radius: 12
                        implicitHeight: 26
                        implicitWidth: modeRow.implicitWidth + 20
                        color: "#B30E1311"
                        visible: analyzer.live || still.visible
                        Row {
                            id: modeRow
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: analyzer.live ? theme.danger : theme.muted
                                SequentialAnimation on opacity {
                                    running: analyzer.live; loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 700 }
                                    NumberAnimation { to: 1.0; duration: 700 }
                                }
                            }
                            Text {
                                color: theme.text; font.pixelSize: 12; font.weight: Font.DemiBold
                                text: analyzer.live ? "LIVE  " + analyzer.fps.toFixed(1) + " fps" : "STILL IMAGE"
                            }
                        }
                    }

                }

                // toolbar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    PillButton {
                        text: analyzer.live ? "Pause camera" : "Live camera"
                        primary: !analyzer.live
                        enabled: hasCamera && analyzer.ready
                        onClicked: analyzer.live = !analyzer.live
                    }
                    PillButton {
                        text: "Open image…"
                        enabled: analyzer.ready
                        onClicked: openDialog.open()
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        color: theme.muted
                        font.pixelSize: 12
                        text: hasCamera ? (devices.defaultVideoInput.description || "Camera ready") : "No camera detected"
                    }
                }
            }

            // ---------------------------------------------------- result panel
            Rectangle {
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                radius: 16
                color: theme.panel
                border.color: theme.line

                ScrollView {
                    id: scroll
                    anchors.fill: parent
                    anchors.margins: 20
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: scroll.availableWidth
                        spacing: 18

                        // verdict
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            Rectangle {
                                width: 48; height: 48; radius: 12
                                color: Qt.rgba(win.verdictColor.r, win.verdictColor.g, win.verdictColor.b, 0.16)
                                Text {
                                    anchors.centerIn: parent
                                    color: win.verdictColor
                                    font.pixelSize: 24; font.weight: Font.Bold
                                    text: !analyzer.hasResult ? "–" : analyzer.uncertain ? "?" : healthy ? "✓" : "!"
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    color: theme.text; font.pixelSize: 22; font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    text: !analyzer.hasResult ? "No result yet"
                                          : analyzer.uncertain ? "Not sure" : guide.name
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: theme.muted; font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    text: !analyzer.hasResult ? "Waiting for an image"
                                          : analyzer.uncertain ? "Retake closer, in daylight, one leaf filling the square"
                                          : healthy ? "No disease detected" : guide.type + " · " + guide.cause
                                }
                            }
                        }

                        // top-3
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: analyzer.hasResult
                            Repeater {
                                model: analyzer.scores
                                delegate: ScoreBar {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    label: modelData.name
                                    value: modelData.p
                                    emphasis: index === 0
                                    barColor: index === 0 ? win.verdictColor : theme.line.lighter(1.8)
                                    trackColor: theme.raised
                                }
                            }
                        }

                        // stats
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: analyzer.hasResult
                            StatTile { title: "INFERENCE"; value: analyzer.inferenceMs.toFixed(1); unit: "ms" }
                            StatTile { title: "PREPROCESS"; value: analyzer.preprocessMs.toFixed(1); unit: "ms" }
                            StatTile {
                                title: analyzer.live ? "THROUGHPUT" : "CONFIDENCE"
                                value: analyzer.live ? analyzer.fps.toFixed(1) : (analyzer.confidence * 100).toFixed(0)
                                unit: analyzer.live ? "fps" : "%"
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.line; visible: guideCol.visible }

                        ColumnLayout {
                            id: guideCol
                            Layout.fillWidth: true
                            spacing: 16
                            visible: analyzer.hasResult && !analyzer.uncertain && guide !== null
                            GuideSection {
                                Layout.fillWidth: true
                                title: healthy ? "What healthy looks like" : "Symptoms"
                                items: guide ? guide.symptoms : []
                                textColor: theme.text; mutedColor: theme.muted; accent: win.verdictColor
                            }
                            GuideSection {
                                Layout.fillWidth: true
                                title: healthy ? "Keep it healthy" : "What to do"
                                items: guide ? guide.management : []
                                textColor: theme.text; mutedColor: theme.muted; accent: win.verdictColor
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.muted
                            opacity: 0.8
                            font.pixelSize: 11
                            text: analyzer.disclaimer
                        }
                    }
                }
            }
        }
    }
}
