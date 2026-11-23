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

    Component.onCompleted: wallpaperProcess.running = true

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            sessionLock.clockText = Qt.formatDateTime(new Date(), "HH:mm");
            sessionLock.dateText = Qt.formatDateTime(new Date(), "dddd, d MMMM");
        }
    }

    Process {
        id: wallpaperProcess
        command: ["cat", (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/tqq-niri-rice/current-wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: sessionLock.wallpaperPath = text.trim()
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

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 13
            Text {
                text: sessionLock.clockText
                color: "#faf5f8"
                font.pixelSize: 82
                font.weight: Font.DemiBold
                font.letterSpacing: -2
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: sessionLock.dateText
                color: "#d7cbd4"
                font.pixelSize: 17
                Layout.alignment: Qt.AlignHCenter
            }
            Rectangle {
                Layout.preferredWidth: 360
                Layout.preferredHeight: sessionLock.unlockVisible ? 190 : 42
                Layout.alignment: Qt.AlignHCenter
                radius: 19
                color: sessionLock.unlockVisible ? "#d91a1720" : "transparent"
                border.width: sessionLock.unlockVisible ? 1 : 0
                border.color: "#55ffffff"
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: sessionLock.unlockVisible ? 18 : 0
                    visible: sessionLock.unlockVisible
                    opacity: sessionLock.unlockVisible ? 1 : 0
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
                        enabled: !sessionLock.authenticating
                        onAccepted: sessionLock.authenticate()
                        background: Rectangle {
                            radius: 11
                            color: "#261f2b"
                            border.width: passwordField.activeFocus ? 1 : 0
                            border.color: "#d8a6c2"
                        }
                    }
                    Button {
                        text: sessionLock.authenticating ? "VERIFYING…" : "UNLOCK"
                        Layout.fillWidth: true
                        enabled: !sessionLock.authenticating
                        onClicked: sessionLock.authenticate()
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
                text: sessionLock.statusText
                color: sessionLock.failed ? "#ef9ba8" : "#aaa0ad"
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

        Shortcut {
            sequence: "Return"
            context: Qt.ApplicationShortcut
            onActivated: sessionLock.showUnlock()
        }
        Shortcut {
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: {
                if (sessionLock.unlockVisible && !sessionLock.authenticating) {
                    sessionLock.unlockVisible = false;
                    sessionLock.statusText = "Press Enter to unlock";
                    sessionLock.failed = false;
                }
            }
        }
    }
}
