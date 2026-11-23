import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

//@ pragma AppId tqq-wifi

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tqq-wifi"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    property color bg: "#151219"
    property color surface: "#211d26"
    property color surfaceHigh: "#302a36"
    property color fg: "#f5f0f5"
    property color muted: "#aaa0ad"
    property color accent: "#d8a6c2"
    property color accentForeground: "#241823"

    property var networks: []
    property var selectedNetwork: null
    property string password: ""
    property string message: "Scanning for nearby networks…"
    property string connectError: ""
    property string connectOutput: ""
    property bool scanning: false
    property bool connecting: false
    property bool passwordPrompt: false
    property bool showPassword: false
    property bool closing: false
    property real scrimOpacity: 0

    function closePanel() {
        if (closing)
            return;
        closing = true;
        closeAnimation.start();
    }

    function splitNmcliLine(line) {
        const fields = [];
        let field = "";
        let escaped = false;

        for (let i = 0; i < line.length; i++) {
            const character = line[i];
            if (escaped) {
                field += character;
                escaped = false;
            } else if (character === "\\") {
                escaped = true;
            } else if (character === ":") {
                fields.push(field);
                field = "";
            } else {
                field += character;
            }
        }

        if (escaped)
            field += "\\";
        fields.push(field);
        return fields;
    }

    function parseNetworks(output) {
        const found = [];
        const bySsid = Object.create(null);

        for (const line of output.split("\n")) {
            if (!line.trim())
                continue;

            const fields = splitNmcliLine(line);
            if (fields.length < 4)
                continue;

            const inUse = fields[0].trim() === "*";
            const ssid = fields[1].trim();
            const signal = Math.max(0, Math.min(100, Number(fields[2]) || 0));
            const security = fields[3].trim();

            if (!ssid)
                continue;

            const entry = {
                ssid: ssid,
                signal: signal,
                security: security,
                secured: security !== "" && security !== "--",
                connected: inUse
            };

            if (!bySsid[ssid]) {
                bySsid[ssid] = entry;
                found.push(entry);
            } else if (signal > bySsid[ssid].signal || inUse) {
                const index = found.indexOf(bySsid[ssid]);
                if (index >= 0)
                    found[index] = entry;
                bySsid[ssid] = entry;
            }
        }

        found.sort(function(a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signal - a.signal;
        });

        root.networks = found;
        root.scanning = false;

        if (found.length === 0)
            root.message = "No networks found. Try scanning again.";
        else
            root.message = found.length + " networks nearby";

        if (root.selectedNetwork) {
            const refreshed = found.find(function(item) {
                return item.ssid === root.selectedNetwork.ssid;
            });
            if (refreshed)
                root.selectedNetwork = refreshed;
        }
    }

    function scanNetworks() {
        if (scanProcess.running || connecting)
            return;

        scanning = true;
        message = "Scanning for nearby networks…";
        scanProcess.command = [
            "nmcli", "--terse", "--escape", "yes",
            "--fields", "IN-USE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list", "--rescan", "yes"
        ];
        scanProcess.running = true;
    }

    function chooseNetwork(network) {
        if (connecting)
            return;

        selectedNetwork = network;
        password = "";
        connectError = "";
        showPassword = false;

        if (network.connected) {
            message = "Already connected to " + network.ssid;
            passwordPrompt = false;
            return;
        }

        if (network.secured) {
            passwordPrompt = true;
            passwordField.forceActiveFocus();
        } else {
            passwordPrompt = false;
            connectToSelected();
        }
    }

    function connectToSelected() {
        if (!selectedNetwork || connecting)
            return;

        if (selectedNetwork.secured && password.length === 0) {
            passwordPrompt = true;
            connectError = "Enter the network password to continue.";
            passwordField.forceActiveFocus();
            return;
        }

        connecting = true;
        connectError = "";
        connectOutput = "";
        message = "Connecting to " + selectedNetwork.ssid + "…";

        const args = [
            "nmcli", "--wait", "25",
            "device", "wifi", "connect", selectedNetwork.ssid
        ];
        if (selectedNetwork.secured)
            args.push("password", password);

        connectProcess.command = args;
        connectProcess.running = true;
    }

    Component.onCompleted: {
        paletteProcess.running = true;
        openAnimation.start();
        scanNetworks();
    }

    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: root; property: "scrimOpacity"; to: 0.62; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnimation
        NumberAnimation { target: root; property: "scrimOpacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "scale"; to: 0.96; duration: 200; easing.type: Easing.InCubic }
        onFinished: Qt.quit()
    }

    Process {
        id: paletteProcess
        command: [
            "cat",
            (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
                + "/tqq-niri-rice/colors.json"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const palette = JSON.parse(text);
                    root.bg = palette.background || root.bg;
                    root.surface = palette.surface || root.surface;
                    root.surfaceHigh = palette.surface_variant || root.surfaceHigh;
                    root.fg = palette.foreground || root.fg;
                    root.muted = palette.muted || root.muted;
                    root.accent = palette.primary || root.accent;
                    root.accentForeground = palette.on_primary || root.accentForeground;
                } catch (error) {
                    console.warn("TQQ Wi-Fi: using fallback palette", error);
                }
            }
        }
    }

    Process {
        id: scanProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseNetworks(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0 && root.networks.length === 0)
                    root.message = text.trim();
            }
        }
        onExited: function(exitCode, exitStatus) {
            root.scanning = false;
            if (exitCode !== 0 && root.networks.length === 0 && root.message.indexOf("Scanning") === 0)
                root.message = "Couldn't scan networks. Check that NetworkManager is running.";
        }
    }

    Process {
        id: connectProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.connectOutput = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: root.connectError = text.trim()
        }
        onExited: function(exitCode) {
            root.connecting = false;
            root.password = "";

            if (exitCode === 0) {
                root.passwordPrompt = false;
                root.message = "Connected to " + (root.selectedNetwork ? root.selectedNetwork.ssid : "network");
                root.scanNetworks();
            } else {
                root.connectError = root.connectError || root.connectOutput || "Connection failed. Check the password and try again.";
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.passwordPrompt) {
                root.passwordPrompt = false;
                root.password = "";
                root.connectError = "";
            } else {
                root.closePanel();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#99070a10"
        opacity: root.scrimOpacity
        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 36, 590)
        height: Math.min(parent.height - 36, 690)
        radius: 25
        color: root.bg
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.55)
        opacity: 0
        scale: 0.96
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 23
            spacing: 15

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 43
                    height: 43
                    radius: 14
                    color: Qt.alpha(root.accent, 0.16)
                    border.width: 1
                    border.color: Qt.alpha(root.accent, 0.35)
                    Text {
                        anchors.centerIn: parent
                        text: "⌁"
                        color: root.accent
                        font.pixelSize: 27
                        font.bold: true
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "TQQ  /  CONNECTIVITY"
                        color: root.accent
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.5
                    }
                    Text {
                        text: "Wi-Fi networks"
                        color: root.fg
                        font.pixelSize: 22
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    radius: 10
                    color: root.surface
                    border.width: 1
                    border.color: Qt.alpha(root.accent, 0.18)
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        color: root.scanning ? root.accent : root.muted
                        font.pixelSize: 23
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.scanning && !root.connecting
                        onClicked: root.scanNetworks()
                    }
                }

                Rectangle {
                    radius: 10
                    color: root.surface
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.fg
                        font.pixelSize: 22
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.closePanel()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 86
                radius: 17
                color: root.surface
                border.width: 1
                border.color: Qt.alpha(root.accent, 0.16)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 17
                    anchors.rightMargin: 17
                    spacing: 14

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 15
                        color: Qt.alpha(root.accent, 0.14)
                        Text {
                            anchors.centerIn: parent
                            text: "◉"
                            color: root.accent
                            font.pixelSize: 25
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "CURRENT CONNECTION"
                            color: root.muted
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                        Text {
                            text: {
                                const active = root.networks.find(function(item) { return item.connected; });
                                return active ? active.ssid : "Not connected";
                            }
                            color: root.fg
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        radius: 9
                        color: root.networks.some(function(item) { return item.connected; })
                            ? Qt.alpha("#75d6a0", 0.14) : Qt.alpha(root.muted, 0.12)
                        Layout.preferredWidth: 86
                        Layout.preferredHeight: 27
                        Text {
                            anchors.centerIn: parent
                            text: root.networks.some(function(item) { return item.connected; }) ? "CONNECTED" : "OFFLINE"
                            color: root.networks.some(function(item) { return item.connected; }) ? "#8ed9ac" : root.muted
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.6
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.scanning ? "SEARCHING NEARBY" : "AVAILABLE NETWORKS"
                    color: root.muted
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.1
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.networks.length + " FOUND"
                    color: root.muted
                    font.pixelSize: 9
                }
            }

            ListView {
                id: networkList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 7
                model: root.networks
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: networkCard
                    required property var modelData
                    width: ListView.view.width
                    height: 68
                    property int signalValue: modelData.signal
                    radius: 14
                    color: modelData.connected ? Qt.alpha(root.accent, 0.13) : root.surface
                    border.width: modelData.connected ? 1 : 0
                    border.color: Qt.alpha(root.accent, 0.45)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 15
                        spacing: 12

                        Rectangle {
                            width: 38
                            height: 38
                            radius: 12
                            color: modelData.connected ? Qt.alpha(root.accent, 0.20) : root.surfaceHigh

                            Text {
                                anchors.centerIn: parent
                                text: modelData.secured ? "⌑" : "⌁"
                                color: modelData.connected ? root.accent : root.fg
                                font.pixelSize: 21
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: modelData.ssid
                                color: root.fg
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.connected ? "Connected · " + (modelData.security || "Open")
                                    : (modelData.secured ? modelData.security : "Open network")
                                color: root.muted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        ColumnLayout {
                            spacing: 3
                            Text {
                                text: modelData.signal + "%"
                                color: root.fg
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignRight
                            }
                            Row {
                                spacing: 2
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 4
                                        height: 5 + index * 3
                                        radius: 2
                                        anchors.bottom: parent.bottom
                                        color: networkCard.signalValue >= (index + 1) * 25
                                            ? root.accent : Qt.alpha(root.muted, 0.28)
                                    }
                                }
                            }
                        }

                        Text {
                            text: modelData.connected ? "✓" : "›"
                            color: modelData.connected ? "#8ed9ac" : root.accent
                            font.pixelSize: 21
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.connecting
                        onClicked: root.chooseNetwork(modelData)
                    }
                }

                footer: Item {
                    width: networkList.width
                    height: root.networks.length === 0 ? 76 : 8
                    visible: root.networks.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: root.message
                        color: root.muted
                        font.pixelSize: 12
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.passwordPrompt ? 128 : 38
                radius: 14
                color: root.passwordPrompt ? root.surfaceHigh : "transparent"
                border.width: root.passwordPrompt ? 1 : 0
                border.color: Qt.alpha(root.accent, 0.35)
                visible: root.passwordPrompt || root.connecting || root.connectError.length > 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.passwordPrompt ? 12 : 0
                    spacing: 7
                    visible: root.passwordPrompt || root.connecting || root.connectError.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.connecting ? "CONNECTING…" : "CONNECT TO " + (root.selectedNetwork ? root.selectedNetwork.ssid : "NETWORK")
                            color: root.fg
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 0.5
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.connecting ? "…" : root.connectError
                            color: root.connectError.length > 0 ? "#f0a0a8" : root.muted
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            Layout.maximumWidth: 200
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.passwordPrompt
                        spacing: 8
                        TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            placeholderText: "Network password"
                            text: root.password
                            onTextChanged: root.password = text
                            echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                            color: root.fg
                            placeholderTextColor: root.muted
                            selectByMouse: true
                            onAccepted: root.connectToSelected()
                            background: Rectangle {
                                radius: 9
                                color: root.bg
                                border.width: passwordField.activeFocus ? 1 : 0
                                border.color: root.accent
                            }
                        }
                        Button {
                            text: root.showPassword ? "Hide" : "Show"
                            onClicked: root.showPassword = !root.showPassword
                            contentItem: Text {
                                text: parent.text
                                color: root.muted
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: root.bg; radius: 9 }
                        }
                        Button {
                            text: "Connect"
                            enabled: !root.connecting
                            onClicked: root.connectToSelected()
                            contentItem: Text {
                                text: parent.text
                                color: root.accentForeground
                                font.pixelSize: 10
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: root.accent; radius: 9 }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.connecting ? "Connecting…" : root.message
                    color: root.muted
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "ESC  CLOSE"
                    color: root.muted
                    font.pixelSize: 9
                    font.letterSpacing: 0.6
                }
            }
        }
    }
}
