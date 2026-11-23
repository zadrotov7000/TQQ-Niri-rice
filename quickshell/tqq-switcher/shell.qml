import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tqq-window-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    property var windows: []
    property int selectedIndex: 0
    property bool loading: true
    property color bg: "#151219"
    property color surface: "#211d26"
    property color surfaceHigh: "#302a36"
    property color fg: "#f5f0f5"
    property color muted: "#aaa0ad"
    property color accent: "#d8a6c2"

    function loadWindows() {
        windowsProcess.running = false;
        windowsProcess.running = true;
    }
    function selectedWindow() {
        if (windows.length === 0) return null;
        return windows[Math.max(0, Math.min(selectedIndex, windows.length - 1))];
    }
    function moveSelection(step) {
        if (windows.length === 0) { loadWindows(); return; }
        selectedIndex = (selectedIndex + step + windows.length) % windows.length;
        idleTimer.restart();
    }
    function commitSelection() {
        const entry = selectedWindow();
        if (entry && entry.id !== undefined)
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(entry.id)]);
        Qt.quit();
    }
    function closeWithoutSwitch() {
        idleTimer.stop();
        Qt.quit();
    }

    Component.onCompleted: {
        paletteProcess.running = true;
        loadWindows();
    }

    IpcHandler {
        target: "tqq-switcher"
        function next(): void { root.moveSelection(1); }
        function previous(): void { root.moveSelection(-1); }
        function close(): void { root.closeWithoutSwitch(); }
    }

    Process {
        id: paletteProcess
        command: ["cat", (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/tqq-niri-rice/colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    root.bg = p.background || root.bg;
                    root.surface = p.surface || root.surface;
                    root.surfaceHigh = p.surface_variant || root.surfaceHigh;
                    root.fg = p.foreground || root.fg;
                    root.muted = p.muted || root.muted;
                    root.accent = p.primary || root.accent;
                } catch (error) {
                    console.warn("TQQ switcher: using fallback palette", error);
                }
            }
        }
    }

    Process {
        id: windowsProcess
        command: ["niri", "msg", "--json", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    const payload = response.Ok || response.ok || response;
                    const list = payload.Windows || payload.windows || payload;
                    if (!Array.isArray(list))
                        throw new Error("Niri returned an unknown windows response");
                    root.windows = list.filter(function(item) { return item && item.id !== undefined; });
                    const focused = root.windows.findIndex(function(item) { return item.is_focused; });
                    const direction = Quickshell.env("TQQ_SWITCH_DIRECTION") === "previous" ? -1 : 1;
                    root.selectedIndex = root.windows.length > 1
                        ? (Math.max(0, focused) + direction + root.windows.length) % root.windows.length
                        : 0;
                    root.loading = false;
                    if (root.windows.length > 0) idleTimer.restart();
                    else Qt.quit();
                } catch (error) {
                    console.warn("TQQ switcher: could not parse Niri windows:", error);
                    root.loading = false;
                    Qt.quit();
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) console.warn("TQQ switcher:", text.trim())
        }
    }

    Timer {
        id: idleTimer
        interval: 850
        repeat: false
        onTriggered: root.commitSelection()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.closeWithoutSwitch()
    }
    Shortcut {
        sequence: "Tab"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(1)
    }
    Shortcut {
        sequence: "Shift+Tab"
        context: Qt.ApplicationShortcut
        onActivated: root.moveSelection(-1)
    }

    Rectangle {
        anchors.fill: parent
        color: "#99070a10"
        opacity: root.loading ? 0.45 : 0.72
        MouseArea { anchors.fill: parent; onClicked: root.commitSelection() }
    }

    Item {
        anchors.centerIn: parent
        width: 760
        height: 540

        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: 520
            radius: 260
            color: Qt.alpha(root.bg, 0.84)
            border.width: 1
            border.color: Qt.alpha(root.accent, 0.45)
        }

        Repeater {
            model: root.windows
            delegate: Rectangle {
                required property var modelData
                required property int index
                property real angle: (index / Math.max(1, root.windows.length)) * Math.PI * 2 - Math.PI / 2
                property real orbitRadius: root.windows.length <= 4 ? 165 : 208
                width: 172
                height: 78
                x: 380 + Math.cos(angle) * orbitRadius - width / 2
                y: 270 + Math.sin(angle) * orbitRadius - height / 2
                radius: 16
                color: index === root.selectedIndex ? Qt.alpha(root.accent, 0.23) : Qt.alpha(root.surface, 0.92)
                border.width: index === root.selectedIndex ? 2 : 1
                border.color: index === root.selectedIndex ? root.accent : Qt.alpha(root.muted, 0.18)
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 3
                    Text { text: modelData.app_id || "Application"; color: index === root.selectedIndex ? root.accent : root.muted; font.pixelSize: 9; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: modelData.title || "Untitled window"; color: root.fg; font.pixelSize: 11; font.bold: index === root.selectedIndex; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.selectedIndex = index; root.commitSelection(); }
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 214
            height: 214
            radius: 107
            color: root.surfaceHigh
            border.width: 2
            border.color: root.accent
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 9
                Text { text: "TQQ  /  WINDOW SWITCHER"; color: root.accent; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1; Layout.alignment: Qt.AlignHCenter }
                Text {
                    text: {
                        const item = root.selectedWindow();
                        return item ? (item.app_id || "Window") : (root.loading ? "Loading…" : "No windows");
                    }
                    color: root.fg
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: {
                        const item = root.selectedWindow();
                        return item ? (item.title || "Untitled window") : " ";
                    }
                    color: root.muted
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    maximumLineCount: 2
                }
                Text { text: root.windows.length ? (root.selectedIndex + 1) + " / " + root.windows.length : " "; color: root.accent; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }
}
