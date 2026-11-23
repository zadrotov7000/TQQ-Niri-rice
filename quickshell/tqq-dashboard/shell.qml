import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tqq-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true

    property string clockText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
    property string systemInfo: "Reading system information…"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.clockText = Qt.formatDateTime(new Date(), "HH:mm")
            root.dateText = Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
        }
    }

    Process {
        id: stats
        command: ["bash", "-lc", "printf 'CPU  '; awk -v RS='' '{print $1}' /proc/loadavg; printf 'RAM  '; free -h | awk '/Mem:/ {print $3 " / " $2}'; printf 'DISK '; df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}'; if command -v sensors >/dev/null 2>&1; then printf 'TEMP '; sensors 2>/dev/null | awk '/Package id 0:|Tctl:/ {print $4; exit}'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.systemInfo = text
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    Rectangle {
        anchors.fill: parent
        color: "#9908060b"

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }
    }

    Rectangle {
        id: panel
        width: Math.min(parent.width - 40, 900)
        height: Math.min(parent.height - 60, 590)
        anchors.centerIn: parent
        radius: 24
        color: "#f0120e17"
        border.color: "#704d293b"
        border.width: 1

        MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = false } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 2
                    Text { text: root.clockText; color: "#f6edf2"; font.pixelSize: 42; font.weight: Font.DemiBold }
                    Text { text: root.dateText; color: "#b9aab6"; font.pixelSize: 14 }
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "×"
                    onClicked: Qt.quit()
                    background: Rectangle { radius: 12; color: "#30202d" }
                    contentItem: Text { text: parent.text; color: "#f6edf2"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 650 ? 3 : 2
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: [
                        ["CPU / RAM / DISK", "Live system information"],
                        ["WEATHER", "Weather provider can be configured later"],
                        ["CALENDAR", "Today · " + Qt.formatDate(new Date(), "d MMMM")]
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 112
                        radius: 17
                        color: "#241b27"
                        border.color: "#503b4a"
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            Text { text: modelData[0]; color: "#e7a4b7"; font.pixelSize: 11; font.bold: true }
                            Text { text: modelData[1]; color: "#f6edf2"; font.pixelSize: 15; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 17
                color: "#201923"
                border.color: "#503b4a"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10
                    Text { text: "SYSTEM MONITOR"; color: "#e7a4b7"; font.pixelSize: 11; font.bold: true }
                    Text { text: root.systemInfo; color: "#f6edf2"; font.pixelSize: 14; font.family: "monospace" }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Button { text: "Open audio"; onClicked: Quickshell.execDetached(["pavucontrol"]) }
                        Button { text: "Network settings"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
                        Button { text: "Bluetooth"; onClicked: Quickshell.execDetached(["blueman-manager"]) }
                        Item { Layout.fillWidth: true }
                        Button { text: "Refresh"; onClicked: stats.running = true }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button { text: "Previous"; onClicked: Quickshell.execDetached(["playerctl", "previous"]) }
                Button { text: "Play / Pause"; onClicked: Quickshell.execDetached(["playerctl", "play-pause"]) }
                Button { text: "Next"; onClicked: Quickshell.execDetached(["playerctl", "next"]) }
                Item { Layout.fillWidth: true }
                Text { text: "Media controls · MPRIS"; color: "#b9aab6"; font.pixelSize: 12 }
            }
        }
    }
}
