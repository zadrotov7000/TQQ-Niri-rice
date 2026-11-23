import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

WlSessionLock {
    id: sessionLock
    locked: true

    property string wallpaperPath: ""
    property string clockText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, d MMMM")
    property string statusText: "ENTER YOUR PASSWORD"
    property string pendingPassword: ""
    property bool unlockVisible: true
    property bool authenticating: false
    property bool failed: false

    property string profileAvatar: ""
    property string profileName: Quickshell.env("USER") || "User"
    property string weatherTemp: "—"
    property string weatherDesc: "Weather unavailable"
    property string weatherWind: "—"
    property string weatherHumidity: "—"
    property var calendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property var calendarDays: makeCalendar()

    function makeCalendar() {
        const first = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        const count = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 0).getDate();
        const days = [];
        for (let i = 0; i < 42; ++i) {
            const number = i - offset + 1;
            days.push(number >= 1 && number <= count ? number : 0);
        }
        return days;
    }

    function shiftMonth(step) {
        calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + step, 1);
        calendarDays = makeCalendar();
    }

    function showUnlock() {
        if (unlockVisible) {
            passwordField.forceActiveFocus();
            return;
        }
        unlockVisible = true;
        Qt.callLater(function() { passwordField.forceActiveFocus(); });
    }

    function authenticate() {
        if (authenticating || passwordField.text.length === 0)
            return;
        pendingPassword = passwordField.text;
        passwordField.text = "";
        statusText = "Verifying…";
        failed = false;
        authenticating = true;
        if (!pam.start()) {
            authenticating = false;
            pendingPassword = "";
            statusText = "Authentication could not be started";
            failed = true;
        }
    }

    Component.onCompleted: {
        wallpaperProcess.running = true;
        avatarProcess.running = true;
        weatherProcess.running = true;
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            sessionLock.clockText = Qt.formatDateTime(new Date(), "HH:mm");
            sessionLock.dateText = Qt.locale("en_US").toString(new Date(), "dddd, d MMMM");
        }
    }

    Process {
        id: wallpaperProcess
        command: ["cat", (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/tqq-niri-rice/current-wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: sessionLock.wallpaperPath = text.trim()
        }
    }


    Timer {
        interval: 900000
        repeat: true
        running: true
        onTriggered: weatherProcess.running = true
    }

    Process {
        id: avatarProcess
        command: ["tqq-avatar", "get"]
        stdout: StdioCollector {
            onStreamFinished: sessionLock.profileAvatar = text.trim()
        }
    }

    Process {
        id: weatherProcess
        command: ["tqq-region", "weather"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    const now = result.current_condition[0];
                    sessionLock.weatherTemp = now.temp_C + "°";
                    sessionLock.weatherDesc = now.weatherDesc[0].value;
                    sessionLock.weatherWind = now.windspeedKmph + " km/h";
                    sessionLock.weatherHumidity = now.humidity + "%";
                } catch (error) {
                    sessionLock.weatherTemp = "—";
                    sessionLock.weatherDesc = "Weather unavailable";
                }
            }
        }
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired) {
                pam.respond(sessionLock.pendingPassword);
                sessionLock.pendingPassword = "";
            }
        }
        onCompleted: function(result) {
            sessionLock.authenticating = false;
            if (result === PamResult.Success) {
                sessionLock.statusText = "Unlocked";
                sessionLock.locked = false;
                Qt.callLater(function() { Qt.quit(); });
            } else {
                sessionLock.pendingPassword = "";
                sessionLock.failed = true;
                sessionLock.statusText = result === PamResult.MaxTries
                    ? "Authentication limit reached. Try another method or wait."
                    : "Incorrect password. Try again.";
                sessionLock.showUnlock();
                passwordField.forceActiveFocus();
            }
        }
        onError: function(error) {
            console.warn("TQQ lock PAM error:", error);
            sessionLock.statusText = "Authentication error";
            sessionLock.failed = true;
            sessionLock.authenticating = false;
        }
    }

    WlSessionLockSurface {
        id: lockSurface
        color: "#08070b"

        Image {
            id: wallpaper
            anchors.fill: parent
            source: sessionLock.wallpaperPath.length ? "file://" + sessionLock.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            blurEnabled: true
            blur: 0.78
            blurMax: 40
            brightness: -0.30
            saturation: 0.82
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#50070910" }
                GradientStop { position: 0.55; color: "#99070910" }
                GradientStop { position: 1.0; color: "#cc070910" }
            }
        }

        // Upper-left: clock and date.
        Rectangle {
            id: clockPanel
            width: Math.min(360, parent.width * 0.27)
            height: 196
            x: Math.max(42, parent.width * 0.046)
            y: Math.max(50, parent.height * 0.075)
            radius: 23
            color: "#78111018"
            border.width: 1
            border.color: "#44ffffff"

            Column {
                anchors.fill: parent
                anchors.margins: 25
                spacing: 12
                Text {
                    text: "LOCAL TIME"
                    color: "#e3a8c8"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }
                Text {
                    text: sessionLock.clockText
                    color: "#fff9fd"
                    font.pixelSize: 81
                    font.weight: Font.Light
                    font.letterSpacing: -3
                }
                Text {
                    text: sessionLock.dateText
                    color: "#e1d4e0"
                    font.pixelSize: 16
                }
            }
        }

        // Lower-left: the same weather source as Control Center.
        Rectangle {
            id: weatherPanel
            width: clockPanel.width
            height: 205
            x: clockPanel.x
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(48, parent.height * 0.08)
            radius: 23
            color: "#78111018"
            border.width: 1
            border.color: "#44ffffff"

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 10
                Text {
                    text: "WEATHER"
                    color: "#e3a8c8"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }
                Row {
                    spacing: 13
                    Text {
                        text: "☁"
                        color: "#faf1fc"
                        font.pixelSize: 48
                    }
                    Text {
                        text: sessionLock.weatherTemp
                        color: "#fff9fd"
                        font.pixelSize: 54
                        font.weight: Font.Light
                    }
                }
                Text {
                    text: sessionLock.weatherDesc
                    color: "#f1e4ef"
                    font.pixelSize: 15
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: "WIND  " + sessionLock.weatherWind + "     HUMIDITY  " + sessionLock.weatherHumidity
                    color: "#c7b9c9"
                    font.pixelSize: 11
                }
            }
        }

        // Center: user image and the PAM-backed password entry.
        Rectangle {
            id: profileCard
            width: Math.min(340, Math.max(270, parent.width * 0.26))
            height: 452
            anchors.centerIn: parent
            radius: 25
            color: "#af14121d"
            border.width: 1
            border.color: "#66e3a8c8"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 13

                Item { Layout.preferredHeight: 5 }
                Rectangle {
                    Layout.preferredWidth: 136
                    Layout.preferredHeight: 136
                    Layout.alignment: Qt.AlignHCenter
                    radius: 68
                    color: "#352334"
                    clip: true
                    border.width: 2
                    border.color: "#e3a8c8"

                    Image {
                        id: lockAvatarImage
                        anchors.fill: parent
                        anchors.margins: 3
                        visible: false
                        source: sessionLock.profileAvatar.length > 0 ? "file://" + sessionLock.profileAvatar : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        asynchronous: true
                    }
                    Rectangle {
                        id: lockAvatarMask
                        anchors.fill: lockAvatarImage
                        radius: width / 2
                        color: "white"
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: lockAvatarImage
                        source: lockAvatarImage
                        maskEnabled: true
                        maskSource: lockAvatarMask
                        visible: sessionLock.profileAvatar.length > 0
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: sessionLock.profileAvatar.length === 0
                        text: sessionLock.profileName.slice(0, 1).toUpperCase()
                        color: "#e9bfd5"
                        font.pixelSize: 66
                        font.weight: Font.Light
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: sessionLock.profileName
                    color: "#fff8fc"
                    font.pixelSize: 24
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "SESSION LOCKED"
                    color: "#bfaeba"
                    font.pixelSize: 10
                    font.letterSpacing: 2
                }
                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    placeholderText: "Enter password"
                    echoMode: TextInput.Password
                    color: "#faf5f8"
                    placeholderTextColor: "#ab9bae"
                    horizontalAlignment: TextInput.AlignHCenter
                    enabled: !sessionLock.authenticating
                    onAccepted: sessionLock.authenticate()
                    background: Rectangle {
                        radius: 12
                        color: "#322532"
                        border.width: 1
                        border.color: passwordField.activeFocus ? "#e3a8c8" : "#685365"
                    }
                }
                Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 41
                    text: sessionLock.authenticating ? "VERIFYING…" : "UNLOCK"
                    enabled: !sessionLock.authenticating
                    onClicked: sessionLock.authenticate()
                    contentItem: Text {
                        text: parent.text
                        color: "#261422"
                        font.bold: true
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: "#e3a8c8"; radius: 11 }
                }
                Text {
                    Layout.fillWidth: true
                    text: sessionLock.statusText
                    color: sessionLock.failed ? "#ff9eae" : "#a99dab"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Item { Layout.fillHeight: true }
            }
        }

        // Right: fully local calendar, with month navigation.
        Rectangle {
            id: calendarPanel
            width: Math.min(330, parent.width * 0.25)
            height: 430
            anchors.right: parent.right
            anchors.rightMargin: Math.max(40, parent.width * 0.046)
            anchors.verticalCenter: parent.verticalCenter
            radius: 23
            color: "#78111018"
            border.width: 1
            border.color: "#44ffffff"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 21
                spacing: 13
                Text {
                    text: "CALENDAR"
                    color: "#e3a8c8"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: "‹"
                        onClicked: sessionLock.shiftMonth(-1)
                        background: Rectangle { radius: 8; color: "#332837" }
                        contentItem: Text { text: parent.text; color: "#f9eaf2"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 18 }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: Qt.locale("en_US").toString(sessionLock.calendarMonth, "MMMM yyyy")
                        color: "#fbf0f9"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: "›"
                        onClicked: sessionLock.shiftMonth(1)
                        background: Rectangle { radius: 8; color: "#332837" }
                        contentItem: Text { text: parent.text; color: "#f9eaf2"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 18 }
                    }
                }
                GridLayout {
                    columns: 7
                    columnSpacing: 5
                    rowSpacing: 8
                    Layout.alignment: Qt.AlignHCenter
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        delegate: Text {
                            required property var modelData
                            text: modelData
                            color: "#a99dab"
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            Layout.preferredWidth: 32
                        }
                    }
                    Repeater {
                        model: sessionLock.calendarDays
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            property bool isToday: modelData === new Date().getDate()
                                && sessionLock.calendarMonth.getMonth() === new Date().getMonth()
                                && sessionLock.calendarMonth.getFullYear() === new Date().getFullYear()
                            color: isToday ? "#d8a6c2" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData === 0 ? "" : String(modelData)
                                color: parent.isToday ? "#261422" : "#f2e5f1"
                                font.bold: parent.isToday
                                font.pixelSize: 12
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    text: "LOCAL CALENDAR"
                    color: "#a99dab"
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Component.onCompleted: Qt.callLater(function() {
            sessionLock.unlockVisible = true;
            passwordField.forceActiveFocus();
        })

        Shortcut {
            sequence: "Return"
            context: Qt.ApplicationShortcut
            onActivated: sessionLock.showUnlock()
        }
        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: {
                if (!sessionLock.authenticating) {
                    passwordField.text = "";
                    sessionLock.failed = false;
                    sessionLock.statusText = "ENTER YOUR PASSWORD";
                }
            }
        }

    }
}
