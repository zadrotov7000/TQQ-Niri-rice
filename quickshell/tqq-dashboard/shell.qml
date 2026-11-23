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
    WlrLayershell.namespace: "tqq-control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    property string clockText: Qt.formatDateTime(new Date(), "HH:mm:ss")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy")
    property string shortDate: Qt.formatDateTime(new Date(), "ddd, d MMM")
    property string weatherRegion: "Detecting region…"
    property string weatherTemperature: "—"
    property string weatherDescription: "Weather unavailable"
    property string feelsLike: "—"
    property string windText: "—"
    property string humidityText: "—"
    property string cloudText: "—"
    property var forecast: []
    property string systemInfo: "Loading system information…"
    property string networkInfo: "Offline"
    property string bluetoothInfo: "Bluetooth unavailable"
    property string mediaInfo: "No active player"
    property string volumeText: "—"
    property real volumeLevel: 0.5
    property int brightnessLevel: 50
    property bool brightnessAvailable: false
    property real panelOffset: -1000
    property bool closing: false

    property color bg: "#111014"
    property color surface: "#211e25"
    property color surfaceHigh: "#302b35"
    property color fg: "#f4f0f5"
    property color muted: "#aaa1ae"
    property color accent: "#d8a6c2"
    property color accentForeground: "#241823"

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
        brightness.running = false; brightness.running = true;
    }

    function loadWeather() {
        weatherProcess.running = false;
        weatherProcess.running = true;
    }

    function closePanel() {
        if (closing) return;
        closing = true;
        closeAnimation.start();
    }

    // Win+Shift+Space and the Waybar clock call the same animated close.
    IpcHandler {
        target: "tqqControlCenter"
        function close(): void { root.closePanel(); }
        function ready(): bool { return true; }
    }

    Component.onCompleted: {
        paletteProcess.running = true;
        regionProcess.running = true;
        refresh();
        panelOffset = -panel.height;
        panel.opacity = 0;
        openAnimation.start();
    }

    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: root; property: "panelOffset"; to: 0; duration: 520; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: closeAnimation
        NumberAnimation { target: root; property: "panelOffset"; to: -panel.height; duration: 380; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InCubic }
        onFinished: Qt.quit()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.clockText = Qt.formatDateTime(new Date(), "HH:mm:ss");
            root.dateText = Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy");
            root.shortDate = Qt.formatDateTime(new Date(), "ddd, d MMM");
        }
    }
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: root.loadWeather()
    }

    Process {
        id: paletteProcess
        command: ["cat", (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/tqq-niri-rice/colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    root.bg = p.background;
                    root.surface = p.surface;
                    root.surfaceHigh = p.surface_variant;
                    root.fg = p.foreground;
                    root.muted = p.muted;
                    root.accent = p.primary;
                    root.accentForeground = p.on_primary;
                } catch (error) {
                    console.warn("TQQ palette unavailable; using fallback colors:", error);
                }
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
                    root.loadWeather();
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
                    root.feelsLike = current.FeelsLikeC + "°";
                    root.windText = current.windspeedKmph + " km/h";
                    root.humidityText = current.humidity + "%";
                    root.cloudText = current.cloudcover + "%";
                    const hours = data.weather[0].hourly;
                    const nowHour = new Date().getHours();
                    const next = [];
                    for (let i = 0; i < hours.length; i++) {
                        const h = parseInt(hours[i].time, 10) / 100;
                        if (h >= nowHour && next.length < 4)
                            next.push({ time: hours[i].time, temp: hours[i].tempC, code: hours[i].weatherCode });
                    }
                    root.forecast = next;
                } catch (error) {
                    root.weatherTemperature = "—";
                    root.weatherDescription = "Weather unavailable";
                    root.forecast = [];
                }
            }
        }
    }
    Process {
        id: stats
        command: ["bash", "-lc", "printf 'CPU LOAD  '; awk '{print $1}' /proc/loadavg; printf 'MEMORY    '; free -h | awk '/Mem:/ {print $3 \" / \" $2}'; printf 'ROOT DISK '; df -h / | awk 'NR==2 {print $5 \" used\"}'; if command -v sensors >/dev/null 2>&1; then printf 'THERMAL   '; sensors 2>/dev/null | awk '/Package id 0:|Tctl:/ {print $4; exit}'; fi"]
        stdout: StdioCollector { onStreamFinished: root.systemInfo = text.trim() }
    }
    Process {
        id: network
        command: ["bash", "-lc", "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\" {print $3; found=1} END {if (!found) print \"Offline\"}'"]
        stdout: StdioCollector { onStreamFinished: root.networkInfo = text.trim() }
    }
    Process {
        id: bluetooth
        command: ["bash", "-lc", "bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; found=1} END {if (!found) print \"Unavailable\"}'"]
        stdout: StdioCollector { onStreamFinished: root.bluetoothInfo = text.trim() }
    }
    Process {
        id: media
        command: ["bash", "-lc", "playerctl metadata --format '{{artist}} — {{title}}' 2>/dev/null || echo 'No active player'"]
        stdout: StdioCollector { onStreamFinished: root.mediaInfo = text.trim() }
    }
    Process {
        id: audio
        command: ["bash", "-lc", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/Volume:\\s*([0-9.]+)/);
                if (match) {
                    root.volumeLevel = Math.max(0, Math.min(1, Number(match[1])));
                    root.volumeText = Math.round(root.volumeLevel * 100) + "%";
                }
            }
        }
    }
    Process {
        id: brightness
        command: ["bash", "-lc", "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f5 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim(), 10);
                root.brightnessAvailable = !isNaN(value);
                if (!isNaN(value))
                    root.brightnessLevel = Math.max(0, Math.min(100, value));
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.closePanel()
    }

    Popup {
        id: powerPopup
        x: panel.x + panel.width - width - 22
        y: panel.y + 52
        width: 220
        padding: 12
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: 17
            color: root.surface
            border.width: 1
            border.color: Qt.alpha(root.accent, 0.55)
        }
        contentItem: ColumnLayout {
            spacing: 6
            Text {
                text: "POWER"
                color: root.muted
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1.3
                Layout.leftMargin: 7
                Layout.bottomMargin: 3
            }
            Button {
                text: "Lock screen"
                Layout.fillWidth: true
                onClicked: {
                    powerPopup.close();
                    root.closePanel();
                    Quickshell.execDetached(["tqq-lock-screen"]);
                }
                background: Rectangle { radius: 9; color: parent.hovered ? root.surfaceHigh : "transparent" }
                contentItem: Text { text: parent.text; color: root.fg; font.pixelSize: 12; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Log out"
                Layout.fillWidth: true
                onClicked: {
                    powerPopup.close();
                    root.closePanel();
                    Quickshell.execDetached(["niri", "msg", "action", "quit"]);
                }
                background: Rectangle { radius: 9; color: parent.hovered ? root.surfaceHigh : "transparent" }
                contentItem: Text { text: parent.text; color: root.fg; font.pixelSize: 12; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Suspend"
                Layout.fillWidth: true
                onClicked: {
                    powerPopup.close();
                    root.closePanel();
                    Quickshell.execDetached(["sh", "-lc", "tqq-lock-screen & sleep 1; systemctl suspend"]);
                }
                background: Rectangle { radius: 9; color: parent.hovered ? root.surfaceHigh : "transparent" }
                contentItem: Text { text: parent.text; color: root.fg; font.pixelSize: 12; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Restart…"
                Layout.fillWidth: true
                onClicked: {
                    powerPopup.close();
                    rebootDialog.open();
                }
                background: Rectangle { radius: 9; color: parent.hovered ? root.surfaceHigh : "transparent" }
                contentItem: Text { text: parent.text; color: root.fg; font.pixelSize: 12; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "Power off…"
                Layout.fillWidth: true
                onClicked: {
                    powerPopup.close();
                    poweroffDialog.open();
                }
                background: Rectangle { radius: 9; color: parent.hovered ? root.surfaceHigh : "transparent" }
                contentItem: Text { text: parent.text; color: root.fg; font.pixelSize: 12; leftPadding: 10; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    Dialog {
        id: rebootDialog
        title: "Restart this computer?"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: Quickshell.execDetached(["systemctl", "reboot"])
        contentItem: Text { text: "Your open applications will be closed."; color: root.fg; wrapMode: Text.WordWrap }
    }

    Dialog {
        id: poweroffDialog
        title: "Power off this computer?"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: Quickshell.execDetached(["systemctl", "poweroff"])
        contentItem: Text { text: "Your open applications will be closed."; color: root.fg; wrapMode: Text.WordWrap }
    }

    Dialog {
        id: regionDialog
        title: "Weather location"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: {
            const city = regionField.text.trim();
            if (city.length > 0) {
                Quickshell.execDetached(["tqq-region", "set", city]);
                root.weatherRegion = city;
                root.loadWeather();
            }
        }
        contentItem: ColumnLayout {
            implicitWidth: 310
            Text {
                text: "Detected from your system time zone by default. Enter any city to change the forecast."
                color: root.muted
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            TextField {
                id: regionField
                placeholderText: "City, e.g. Copenhagen"
                Layout.fillWidth: true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#33000000"
        MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(58, parent.height * 0.075) + root.panelOffset
        width: Math.min(parent.width * 0.62, 1040)
        height: Math.min(parent.height * 0.76, parent.height - Math.max(58, parent.height * 0.075) - 28)
        opacity: 0
        radius: 22
        color: root.bg
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.55)
        clip: true
        MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = false } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    radius: 12
                    color: root.surface
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 36
                    Text { anchors.centerIn: parent; text: "⚙"; color: root.accent; font.bold: true; font.pixelSize: 19 }
                }
                Text { text: root.mediaInfo; color: root.fg; font.pixelSize: 12; elide: Text.ElideRight; Layout.maximumWidth: 250 }
                Item { Layout.fillWidth: true }
                Text { text: root.clockText; color: root.fg; font.pixelSize: 14; font.bold: true }
                Text { text: root.shortDate; color: root.muted; font.pixelSize: 11 }
                Rectangle {
                    radius: 10
                    color: root.surface
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 220
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        Text { text: "◉  " + root.networkInfo; color: root.fg; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: "BT " + root.bluetoothInfo; color: root.muted; font.pixelSize: 10 }
                    }
                }
                Rectangle {
                    radius: 10
                    color: root.surface
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 92
                    Text { anchors.centerIn: parent; text: "◖ " + root.volumeText; color: root.fg; font.pixelSize: 11 }
                }
                Button {
                    text: "⏻"
                    onClicked: powerPopup.open()
                    background: Rectangle { radius: 9; color: root.surfaceHigh }
                    contentItem: Text { text: parent.text; color: root.fg; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: "×"
                    onClicked: root.closePanel()
                    background: Rectangle { radius: 9; color: root.surfaceHigh }
                    contentItem: Text { text: parent.text; color: root.fg; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 18

                Rectangle {
                    Layout.preferredWidth: panel.width * 0.245
                    Layout.fillHeight: true
                    radius: 16
                    color: Qt.alpha(root.surface, 0.76)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: Qt.formatDate(root.monthCursor, "MMMM yyyy").toUpperCase(); color: root.fg; font.pixelSize: 15; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Button { text: "‹"; onClicked: root.shiftMonth(-1); palette.buttonText: root.fg; background: Rectangle { color: root.surfaceHigh; radius: 7 } }
                            Button { text: "›"; onClicked: root.shiftMonth(1); palette.buttonText: root.fg; background: Rectangle { color: root.surfaceHigh; radius: 7 } }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 10
                            columnSpacing: 3
                            Repeater {
                                model: ["MO","TU","WE","TH","FR","SA","SU"]
                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    text: modelData
                                    color: "#FFFFFF"
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            Repeater {
                                model: root.calendarCells
                                delegate: Rectangle {
                                    required property int modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    radius: 8
                                    color: modelData === root.selectedDay && root.monthCursor.getMonth() === new Date().getMonth() && root.monthCursor.getFullYear() === new Date().getFullYear() ? root.accent : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData > 0 ? modelData : ""
                                        color: parent.color === "transparent" ? "#FFFFFF" : root.accentForeground
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Text { text: "LOCAL CALENDAR"; color: root.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10
                        Item { Layout.fillHeight: true }
                        Text {
                            Layout.fillWidth: true
                            text: root.clockText
                            color: root.fg
                            font.pixelSize: Math.min(100, panel.height * 0.19)
                            font.weight: Font.Light
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.dateText
                            color: root.muted
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            Button {
                                text: "‹"
                                onClicked: Quickshell.execDetached(["playerctl", "previous"])
                                background: Rectangle {
                                    color: root.surface
                                    radius: 8
                                }
                                contentItem: Text {
                                    text: "‹"
                                    color: root.fg
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            Button {
                                text: "Ⅱ"
                                onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
                                background: Rectangle {
                                    color: root.accent
                                    radius: 8
                                }
                                contentItem: Text {
                                    text: "Ⅱ"
                                    color: root.accentForeground
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            Button {
                                text: "›"
                                onClicked: Quickshell.execDetached(["playerctl", "next"])
                                background: Rectangle {
                                    color: root.surface
                                    radius: 8
                                }
                                contentItem: Text {
                                    text: "›"
                                    color: root.fg
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        Text { Layout.fillWidth: true; text: root.mediaInfo; color: root.muted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                        Item { Layout.fillHeight: true }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: panel.width * 0.255
                    Layout.fillHeight: true
                    radius: 16
                    color: Qt.alpha(root.surface, 0.76)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: root.weatherRegion.toUpperCase(); color: root.muted; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            Button {
                                text: "···"
                                onClicked: regionDialog.open()
                                background: Rectangle { color: root.surfaceHigh; radius: 7 }
                                contentItem: Text { text: parent.text; color: root.fg; horizontalAlignment: Text.AlignHCenter }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Text { text: root.weatherTemperature; color: root.fg; font.pixelSize: 76; font.weight: Font.Light }
                        Text { text: root.weatherDescription; color: root.fg; font.pixelSize: 17 }
                        Text { text: "Feels like " + root.feelsLike; color: root.muted; font.pixelSize: 11 }
                        Item { Layout.fillHeight: true }
                        Text { text: "HOURLY FORECAST"; color: root.muted; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: root.forecast
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 86
                                    radius: 10
                                    color: root.surfaceHigh
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        Text { text: String(modelData.time).padStart(4, "0").slice(0,2) + ":00"; color: root.muted; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "☁"; color: root.fg; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: modelData.temp + "°"; color: root.fg; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    {label:"WIND",value:root.windText},
                                    {label:"HUMIDITY",value:root.humidityText},
                                    {label:"CLOUD",value:root.cloudText}
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 55
                                    radius: 9
                                    color: root.surfaceHigh
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        Text { text: modelData.label; color: root.muted; font.pixelSize: 8; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: modelData.value; color: root.fg; font.pixelSize: 12; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: 13
                    color: Qt.alpha(root.surface, 0.8)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        Text { text: "SYSTEM"; color: root.accent; font.pixelSize: 9; font.bold: true }
                        Text { text: root.systemInfo.replace(/\n/g, "    ·    "); color: root.fg; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 205
                    Layout.preferredHeight: 72
                    radius: 14
                    color: Qt.alpha(root.surface, 0.88)
                    border.width: 1
                    border.color: Qt.alpha(root.accent, 0.16)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "◖"; color: root.accent; font.pixelSize: 15 }
                            Text { text: "VOLUME"; color: root.fg; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8 }
                            Item { Layout.fillWidth: true }
                            Text { text: root.volumeText; color: root.muted; font.pixelSize: 10 }
                        }
                        Slider {
                            id: volumeSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            from: 0
                            to: 1
                            value: root.volumeLevel
                            onMoved: {
                                root.volumeLevel = value;
                                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", value.toFixed(2)]);
                            }
                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: 5
                                radius: 3
                                color: root.surfaceHigh
                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: "#82d9e5" }
                                        GradientStop { position: 1; color: root.accent }
                                    }
                                }
                            }
                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: 13
                                height: 13
                                radius: 7
                                color: root.fg
                                border.width: 2
                                border.color: root.accent
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 205
                    Layout.preferredHeight: 72
                    radius: 14
                    color: Qt.alpha(root.surface, 0.88)
                    border.width: 1
                    border.color: Qt.alpha(root.accent, 0.16)
                    opacity: root.brightnessAvailable ? 1 : 0.62
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "☼"; color: root.accent; font.pixelSize: 17 }
                            Text { text: "BRIGHTNESS"; color: root.fg; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8 }
                            Item { Layout.fillWidth: true }
                            Text { text: root.brightnessAvailable ? root.brightnessLevel + "%" : "N/A"; color: root.muted; font.pixelSize: 10 }
                        }
                        Slider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            from: 1
                            to: 100
                            value: root.brightnessLevel
                            enabled: root.brightnessAvailable
                            onMoved: {
                                root.brightnessLevel = Math.round(value);
                                Quickshell.execDetached(["brightnessctl", "set", Math.round(value) + "%"]);
                            }
                            background: Rectangle {
                                x: brightnessSlider.leftPadding
                                y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                width: brightnessSlider.availableWidth
                                height: 5
                                radius: 3
                                color: root.surfaceHigh
                                Rectangle {
                                    width: brightnessSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: "#f4d58d" }
                                        GradientStop { position: 1; color: root.accent }
                                    }
                                }
                            }
                            handle: Rectangle {
                                x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                                y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                width: 13
                                height: 13
                                radius: 7
                                color: root.fg
                                border.width: 2
                                border.color: root.accent
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "CONTROL CENTER"; color: root.muted; font.pixelSize: 9; font.letterSpacing: 1 }
                Item { Layout.fillWidth: true }
                Text { text: "ESC TO CLOSE"; color: root.muted; font.pixelSize: 9 }
            }
        }
    }
}
