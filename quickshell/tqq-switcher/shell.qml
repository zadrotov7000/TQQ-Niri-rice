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
    property int pendingSteps: 0
    property bool commitPending: false
    property bool finished: false
    property bool hadFocus: false
    property real reveal: 0
    property real backdropOpacity: 0
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
        if (finished || commitPending) return;
        if (loading) { pendingSteps += step; return; }
        if (windows.length === 0) return;
        selectedIndex = (selectedIndex + step + windows.length) % windows.length;
    }
    function commitSelection() {
        if (finished) return;
        if (loading) { commitPending = true; return; }
        finished = true;
        const entry = selectedWindow();
        if (entry && entry.id !== undefined)
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(entry.id)]);
        Qt.quit();
    }
    function closeWithoutSwitch() {
        finished = true;
        Qt.quit();
    }

    Component.onCompleted: {
        paletteProcess.running = true;
        openAnimation.start();
        keyboard.forceActiveFocus();
        loadWindows();
    }

    ParallelAnimation {
        id: openAnimation
        NumberAnimation {
            target: root
            property: "reveal"
            from: 0
            to: 1
            duration: 390
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "backdropOpacity"
            from: 0
            to: 0.72
            duration: 280
            easing.type: Easing.OutCubic
        }
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
                        ? ((Math.max(0, focused) + direction + root.pendingSteps) % root.windows.length + root.windows.length) % root.windows.length
                        : 0;
                    root.loading = false;
                    if (root.windows.length === 0) root.closeWithoutSwitch();
                    else if (root.commitPending) root.commitSelection();
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

    function desktopEntry(window) {
        if (!window || !window.app_id) return null;
        const id = String(window.app_id).replace(/\.desktop$/, "");
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id);
    }

    function applicationName(window) {
        const entry = desktopEntry(window);
        return entry && entry.name ? entry.name : (window ? window.app_id || "Application" : "");
    }

    function applicationIcon(window) {
        if (!window) return "";
        const entry = desktopEntry(window);
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : (window.app_id || ""), true) || "";
    }

    Item {
        id: keyboard
        anchors.fill: parent
        focus: true
        onActiveFocusChanged: {
            if (activeFocus) root.hadFocus = true;
            else if (root.hadFocus && !root.finished && !root.commitPending)
                root.closeWithoutSwitch();
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.closeWithoutSwitch();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                root.commitSelection();
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                event.accepted = true;
                if (!event.isAutoRepeat)
                    root.moveSelection(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
            }
        }
        Keys.onReleased: function(event) {
            if (event.key === Qt.Key_Alt && !event.isAutoRepeat) {
                event.accepted = true;
                root.commitSelection();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#99070a10"
        opacity: root.backdropOpacity
        MouseArea { anchors.fill: parent; onClicked: root.closeWithoutSwitch() }
    }

    Item {
        id: wheel
        anchors.centerIn: parent
        width: Math.max(120, Math.min(parent.width - 36, parent.height - 36, 520))
        height: width
        property real band: width * 0.24
        property real orbit: (width - band) / 2
        property int visibleCount: Math.min(root.windows.length, 16)
        property int startIndex: root.windows.length > visibleCount
            ? (root.selectedIndex - Math.floor(visibleCount / 2) + root.windows.length) % root.windows.length : 0
        property real nodeSize: Math.min(band * 0.74,
            2 * orbit * Math.sin(Math.PI / Math.max(2, visibleCount)) * 0.76)
        opacity: root.reveal
        scale: 0.86 + 0.14 * root.reveal

        // A true annulus: the middle is open, icons sit inside the thick band.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: wheel.band
            border.color: Qt.alpha(root.bg, 0.94)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(root.accent, 0.48)
        }
        Rectangle {
            anchors.centerIn: parent
            width: wheel.width - 2 * wheel.band
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(root.accent, 0.32)
        }

        Repeater {
            model: wheel.visibleCount
            delegate: Rectangle {
                id: tile
                required property int index
                property int windowIndex: (wheel.startIndex + index) % Math.max(1, root.windows.length)
                property var entry: root.windows[windowIndex]
                property bool chosen: windowIndex === root.selectedIndex
                property real angle: index * Math.PI * 2 / Math.max(1, wheel.visibleCount) - Math.PI / 2
                width: wheel.nodeSize
                height: width
                x: wheel.width / 2 + Math.cos(angle) * wheel.orbit - width / 2
                y: wheel.height / 2 + Math.sin(angle) * wheel.orbit - height / 2
                radius: width / 2
                color: chosen ? Qt.alpha(root.accent, 0.28) : Qt.alpha(root.surface, 0.82)
                border.width: chosen ? 2 : 1
                border.color: chosen ? root.accent : Qt.alpha(root.muted, 0.16)
                scale: chosen ? 1.12 : 1
                z: chosen ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 100 } }

                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width: tile.width * 0.66
                    height: width
                    sourceSize.width: Math.ceil(width)
                    sourceSize.height: Math.ceil(height)
                    source: root.applicationIcon(tile.entry)
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: root.applicationName(tile.entry).slice(0, 1).toUpperCase() || "?"
                    color: tile.chosen ? root.accent : root.fg
                    font.pixelSize: Math.max(12, tile.width * 0.43)
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedIndex = tile.windowIndex;
                        root.commitSelection();
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            width: wheel.width - 2 * wheel.band - 24
            spacing: 6
            Text {
                width: parent.width
                text: root.loading ? "Loading…" : root.applicationName(root.selectedWindow())
                color: root.fg
                font.pixelSize: Math.max(11, Math.min(19, wheel.width * 0.038))
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.selectedWindow() ? root.selectedWindow().title || "" : ""
                color: root.muted
                font.pixelSize: Math.max(9, Math.min(12, wheel.width * 0.025))
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.windows.length ? (root.selectedIndex + 1) + " / " + root.windows.length : ""
                color: root.accent
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
