import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#08070b"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tqq-lock"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    property string wallpaperPath: ""
    property string clockText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, d MMMM")
    property string statusText: "Press Enter to unlock"
    property string pendingPassword: ""
    property bool unlockVisible: false
    property bool authenticating: false
    property bool failed: false

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
        Qt.callLater(function() { root.forceActiveFocus(); });
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.clockText = Qt.formatDateTime(new Date(), "HH:mm");
            root.dateText = Qt.formatDateTime(new Date(), "dddd, d MMMM");
        }
    }

    Process {
        id: wallpaperProcess
        command: ["cat", (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/tqq-niri-rice/current-wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: root.wallpaperPath = text.trim()
        }
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired) {
                pam.respond(root.pendingPassword);
                root.pendingPassword = "";
            }
        }
        onCompleted: function(result) {
            root.authenticating = false;
            if (result === PamResult.Success) {
                root.statusText = "Unlocked";
                Qt.quit();
            } else {
                root.pendingPassword = "";
                root.failed = true;
                root.statusText = result === PamResult.MaxTries
                    ? "Authentication limit reached. Try another method or wait."
                    : "Incorrect password. Try again.";
                root.showUnlock();
                passwordField.forceActiveFocus();
            }
        }
        onError: function(error) {
            console.warn("TQQ lock PAM error:", error);
            root.statusText = "Authentication error";
            root.failed = true;
            root.authenticating = false;
        }
    }

    Shortcut {
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: root.showUnlock()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (root.unlockVisible && !root.authenticating) {
                root.unlockVisible = false;
                root.statusText = "Press Enter to unlock";
                root.failed = false;
            }
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.wallpaperPath.length ? "file://" + root.wallpaperPath : ""
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

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 13
        Text {
            text: root.clockText
            color: "#faf5f8"
            font.pixelSize: 82
            font.weight: Font.DemiBold
            font.letterSpacing: -2
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            text: root.dateText
            color: "#d7cbd4"
            font.pixelSize: 17
            Layout.alignment: Qt.AlignHCenter
        }
        Rectangle {
            Layout.preferredWidth: 360
            Layout.preferredHeight: root.unlockVisible ? 190 : 42
            Layout.alignment: Qt.AlignHCenter
            radius: 19
            color: root.unlockVisible ? "#d91a1720" : "transparent"
            border.width: root.unlockVisible ? 1 : 0
            border.color: "#55ffffff"
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.unlockVisible ? 18 : 0
                visible: root.unlockVisible
                opacity: root.unlockVisible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Text {
                    text: "WELCOME BACK"
                    color: "#d8a6c2"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.7
                    Layout.alignment: Qt.AlignHCenter
                }
                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    color: "#faf5f8"
                    placeholderTextColor: "#9e94a2"
                    selectByMouse: true
                    enabled: !root.authenticating
                    onAccepted: root.authenticate()
                    background: Rectangle {
                        radius: 11
                        color: "#261f2b"
                        border.width: passwordField.activeFocus ? 1 : 0
                        border.color: "#d8a6c2"
                    }
                }
                Button {
                    text: root.authenticating ? "VERIFYING…" : "UNLOCK"
                    Layout.fillWidth: true
                    enabled: !root.authenticating
                    onClicked: root.authenticate()
                    contentItem: Text {
                        text: parent.text
                        color: "#241823"
                        font.bold: true
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { radius: 10; color: "#d8a6c2" }
                }
            }
        }
        Text {
            text: root.statusText
            color: root.failed ? "#ef9ba8" : "#aaa0ad"
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 35
        text: "TQQ  ·  SECURE SESSION"
        color: "#91ffffff"
        font.pixelSize: 10
        font.letterSpacing: 2
    }

    Component.onCompleted: {
        wallpaperProcess.running = true;
    }
}
