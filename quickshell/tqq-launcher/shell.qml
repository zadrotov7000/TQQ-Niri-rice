import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tqq-app-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    property color bg: "#17131a"
    property color surface: "#28212c"
    property color surfaceHigh: "#392d3c"
    property color fg: "#f5f0f5"
    property color muted: "#aaa0ad"
    property color accent: "#d8a6c2"
    property color accentForeground: "#241823"
    property bool closing: false
    property var selectedEntry: null

    function closeLauncher() {
        if (closing) return;
        closing = true;
        closeTimer.start();
    }
    function launchSelected() {
        if (!selectedEntry) return;
        selectedEntry.execute();
        closeLauncher();
    }

    Component.onCompleted: {
        paletteProcess.running = true;
        searchField.forceActiveFocus();
    }
    Timer { id: closeTimer; interval: 230; onTriggered: Qt.quit() }

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
                    console.warn("TQQ launcher: using fallback palette", error);
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: root.closeLauncher()
    }

    Rectangle {
        anchors.fill: parent
        color: "#44000000"
        opacity: root.closing ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: root.closeLauncher() }
    }

    Rectangle {
        id: panel
        width: Math.min(620, parent.width * 0.72)
        height: Math.min(510, parent.height * 0.72)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(74, parent.height * 0.13)
        radius: 20
        color: root.bg
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.58)
        opacity: root.closing ? 0 : 1
        scale: root.closing ? 0.94 : 1
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Component.onCompleted: { opacity = 0; scale = 0.94; appearTimer.start(); }

        Timer {
            id: appearTimer
            interval: 1
            onTriggered: { panel.opacity = 1; panel.scale = 1; }
        }
        MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = false } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text { text: "TQQ"; color: root.accent; font.pixelSize: 13; font.bold: true; font.letterSpacing: 1.5 }
                Text { text: "APPLICATION LAUNCHER"; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1.2 }
                Item { Layout.fillWidth: true }
                Text { text: "ESC"; color: root.muted; font.pixelSize: 10 }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 13
                color: root.surface
                border.width: searchField.activeFocus ? 1 : 0
                border.color: root.accent
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 17
                    anchors.rightMargin: 17
                    spacing: 12
                    Text { text: "⌕"; color: root.accent; font.pixelSize: 25 }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search applications..."
                        color: root.fg
                        placeholderTextColor: root.muted
                        font.pixelSize: 16
                        background: Item {}
                        selectByMouse: true
                        onTextChanged: { appList.currentIndex = 0; appList.positionViewAtBeginning(); }
                        Keys.onReturnPressed: root.launchSelected()
                        Keys.onEnterPressed: root.launchSelected()
                        Keys.onDownPressed: appList.incrementCurrentIndex()
                        Keys.onUpPressed: appList.decrementCurrentIndex()
                    }
                }
            }
            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 5
                model: DesktopEntries.applications
                currentIndex: 0
                onCurrentIndexChanged: if (currentItem) root.selectedEntry = currentItem.entry
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    required property var modelData
                    property var entry: modelData
                    width: ListView.view.width
                    height: matches ? 54 : 0
                    visible: matches
                    radius: 11
                    color: ListView.isCurrentItem ? root.surfaceHigh : "transparent"
                    property bool matches: {
                        const query = searchField.text.trim().toLowerCase();
                        if (!query) return true;
                        const name = (entry.name || "").toLowerCase();
                        const generic = (entry.genericName || "").toLowerCase();
                        const comment = (entry.comment || "").toLowerCase();
                        const keywords = (entry.keywords || []).join(" ").toLowerCase();
                        return name.includes(query) || generic.includes(query) || comment.includes(query) || keywords.includes(query);
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 13
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 9
                            color: root.surface
                            Text { anchors.centerIn: parent; text: (entry.name || "?").substring(0, 1).toUpperCase(); color: root.accent; font.pixelSize: 15; font.bold: true }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: entry.name || "Unknown application"; color: root.fg; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: entry.genericName || entry.comment || entry.id; color: root.muted; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Text { text: "↵"; color: ListView.isCurrentItem ? root.accent : root.muted; font.pixelSize: 15 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onEntered: appList.currentIndex = index
                        onClicked: { entry.execute(); root.closeLauncher(); }
                    }
                }
            }
            Text {
                text: "↑  ↓  Navigate     ENTER  Launch     ESC  Close"
                color: root.muted
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    onClosingChanged: {
        if (closing) return;
        if (appList.currentItem) selectedEntry = appList.currentItem.entry;
    }
}
