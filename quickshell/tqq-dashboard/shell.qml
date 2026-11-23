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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    property string clockText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
    property string systemInfo: "Loading system information…"
    property string networkInfo: "Checking network…"
    property string bluetoothInfo: "Checking Bluetooth…"
    property string mediaInfo: "No active player"
    property string audioInfo: "Audio status unavailable"
    property string weatherRegion: "Detecting region…"
    property string weatherTemperature: "—"
    property string weatherDescription: "Weather unavailable"
    property real volumeLevel: 0.5
    property var monthCursor: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property int selectedDay: new Date().getDate()
    property var calendarCells: buildCalendar()

    function buildCalendar() {
        const first = new Date(monthCursor.getFullYear(), monthCursor.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        const days = new Date(monthCursor.getFullYear(), monthCursor.getMonth() + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const day = i - offset + 1;
            cells.push(day > 0 && day <= days ? day : 0);
        }
        return cells;
    }

    function shiftMonth(amount) {
        monthCursor = new Date(monthCursor.getFullYear(), monthCursor.getMonth() + amount, 1);
        calendarCells = buildCalendar();
    }

    function refresh() {
        stats.running = false; stats.running = true;
        network.running = false; network.running = true;
        bluetooth.running = false; bluetooth.running = true;
        media.running = false; media.running = true;
        audio.running = false; audio.running = true;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.clockText = Qt.formatDateTime(new Date(), "HH:mm");
            root.dateText = Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy");
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: stats
        command: ["bash", "-lc", "printf 'CPU LOAD  '; awk '{print $1}' /proc/loadavg; printf 'MEMORY    '; free -h | awk '/Mem:/ {print $3 \" / \" $2}'; printf 'ROOT DISK '; df -h / | awk 'NR==2 {print $3 \" / \" $2 \"  ·  \" $5}'; printf 'UPTIME    '; uptime -p; if command -v sensors >/dev/null 2>&1; then printf 'THERMAL   '; sensors 2>/dev/null | awk '/Package id 0:|Tctl:/ {print $4; exit}'; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.systemInfo = text }
    }

    Process {
        id: network
        command: ["bash", "-lc", "if command -v nmcli >/dev/null 2>&1; then nmcli -t -f TYPE,STATE,CONNECTION device status | awk -F: '$2==\"connected\" {print $1 \" · \" $3; found=1} END {if (!found) print \"No active connection\"}'; else echo 'NetworkManager not installed'; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.networkInfo = text.trim() }
    }

    Process {
        id: bluetooth
        command: ["bash", "-lc", "if command -v bluetoothctl >/dev/null 2>&1; then bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print \"Bluetooth \" $2}'; else echo 'Bluetooth tools unavailable'; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.bluetoothInfo = text.trim() || "Bluetooth unavailable" }
    }

    Process {
        id: media
        command: ["bash", "-lc", "if command -v playerctl >/dev/null 2>&1; then playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null || echo 'No active player'; else echo 'playerctl not installed'; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.mediaInfo = text.trim() }
    }

    Process {
        id: audio
        command: ["bash", "-lc", "if command -v wpctl >/dev/null 2>&1; then wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; else echo 'PipeWire audio unavailable'; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/Volume:\\s*([0-9.]+)/);
                if (match) root.volumeLevel = Math.max(0, Math.min(1, Number(match[1])));
                root.audioInfo = match ? "Output volume · " + Math.round(Number(match[1]) * 100) + "%" : text.trim();
            }
        }
    }

    Process {
        id: regionProcess
        command: ["tqq-region", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim();
                if (value.length > 0) {
                    root.weatherRegion = value;
                    regionField.text = value;
                    weatherProcess.running = true;
                }
            }
        }
    }

    Process {
        id: weatherProcess
        command: ["tqq-region", "weather"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const current = data.current_condition[0];
                    root.weatherTemperature = current.temp_C + "°";
                    root.weatherDescription = current.weatherDesc[0].value;
                } catch (error) {
                    root.weatherTemperature = "—";
                    root.weatherDescription = "Weather unavailable";
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }

    Rectangle {
        anchors.fill: parent
        color: "#c008060b"
        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
    }

    Rectangle {
        id: panel
        width: Math.min(parent.width - 36, 1040)
        height: Math.min(parent.height - 36, 700)
        anchors.centerIn: parent
        radius: 26
        color: "#f0120e17"
        border.color: "#704d293b"
        border.width: 1
        MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = false } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 2
                    Text { text: root.clockText; color: "#f6edf2"; font.pixelSize: 42; font.weight: Font.DemiBold }
                    Text { text: root.dateText; color: "#b9aab6"; font.pixelSize: 14 }
                }
                Item { Layout.fillWidth: true }
                Text { text: "TQQ  /  CONTROL CENTER"; color: "#e7a4b7"; font.pixelSize: 11; font.bold: true }
                Button {
                    text: "×"
                    onClicked: Qt.quit()
                    background: Rectangle { radius: 12; color: "#30202d" }
                    contentItem: Text { text: parent.text; color: "#f6edf2"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: width > 760 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 260
                    radius: 18
                    color: "#241b27"
                    border.color: "#503b4a"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "CALENDAR"; color: "#e7a4b7"; font.pixelSize: 11; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Button { text: "‹"; onClicked: root.shiftMonth(-1) }
                            Text { text: Qt.formatDate(root.monthCursor, "MMMM yyyy"); color: "#f6edf2"; font.pixelSize: 14; font.bold: true }
                            Button { text: "›"; onClicked: root.shiftMonth(1) }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 5
                            columnSpacing: 5
                            Repeater {
                                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    color: "#9b8998"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                            Repeater {
                                model: root.calendarCells
                                delegate: Rectangle {
                                    required property int modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 8
                                    color: modelData === root.selectedDay && root.monthCursor.getMonth() === new Date().getMonth() && root.monthCursor.getFullYear() === new Date().getFullYear() ? "#754052" : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData > 0 ? modelData : ""
                                        color: parent.color === "transparent" ? "#e5dce3" : "#ffffff"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Text { text: "Your local calendar · month navigation"; color: "#9b8998"; font.pixelSize: 11 }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 260
                    radius: 18
                    color: "#241b27"
                    border.color: "#503b4a"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        spacing: 10
                        Text { text: "SYSTEM MONITOR"; color: "#e7a4b7"; font.pixelSize: 11; font.bold: true }
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: root.systemInfo
                            color: "#f6edf2"
                            font.pixelSize: 14
                            font.family: "monospace"
                            wrapMode: Text.WordWrap
                            verticalAlignment: Text.AlignVCenter
                        }
                        Button { text: "Refresh system info"; onClicked: root.refresh() }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 190
                    radius: 18
                    color: "#241b27"
                    border.color: "#503b4a"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        spacing: 9
                        Text { text: "MEDIA"; color: "#e7a4b7"; font.pixelSize: 11; font.bold: true }
                        Text { Layout.fillWidth: true; text: root.mediaInfo || "No active player"; color: "#f6edf2"; font.pixelSize: 14; elide: Text.ElideRight }
                        RowLayout {
                            Layout.fillWidth: true
                            Button { text: "Previous"; onClicked: Quickshell.execDetached(["playerctl", "previous"]) }
                            Button { text: "Play / Pause"; onClicked: Quickshell.execDetached(["playerctl", "play-pause"]) }
                            Button { text: "Next"; onClicked: Quickshell.execDetached(["playerctl", "next"]) }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 190
                    radius: 18
                    color: "#241b27"
                    border.color: "#503b4a"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 17
                        spacing: 9
                        Text { text: "QUICK SETTINGS"; color: "#e7a4b7"; font.pixelSize: 11; font.bold: true }
                        Text { text: root.audioInfo; color: "#f6edf2"; font.pixelSize: 13 }
                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: 1
                            value: root.volumeLevel
                            onMoved: {
                                root.volumeLevel = value;
                                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", value.toFixed(2)]);
                            }
                        }
                        Text { text: root.networkInfo + "   /   " + root.bluetoothInfo; color: "#c9bbc6"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        RowLayout {
                            Layout.fillWidth: true
                            Button { text: "Audio"; onClicked: Quickshell.execDetached(["pavucontrol"]) }
                            Button { text: "Network"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
                            Button { text: "Bluetooth"; onClicked: Quickshell.execDetached(["blueman-manager"]) }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "TQQ Dashboard"; color: "#9b8998"; font.pixelSize: 11 }
                Item { Layout.fillWidth: true }
                Text { text: "ESC to close  ·  Super + Shift + Space to open"; color: "#9b8998"; font.pixelSize: 11 }
            }
        }
    }
}
