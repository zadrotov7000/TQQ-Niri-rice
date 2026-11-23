import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#08070b"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tqq-squishy"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focusable: true

    property string wallpaperPath: ""
    property var points: []
    property var selectedPoints: []
    property bool selecting: false
    property bool hasSelection: false
    property bool dragging: false
    property real patchX: 0
    property real patchY: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property color accent: "#d8a6c2"
    property color fg: "#f5f0f5"
    property color muted: "#aaa0ad"

    function pointInsidePolygon(x, y, polygon) {
        let inside = false;
        for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
            const xi = polygon[i].x, yi = polygon[i].y;
            const xj = polygon[j].x, yj = polygon[j].y;
            const intersect = ((yi > y) !== (yj > y))
                && (x < (xj - xi) * (y - yi) / ((yj - yi) || 0.0001) + xi);
            if (intersect) inside = !inside;
        }
        return inside;
    }

    function resetSelection() {
        points = [];
        selectedPoints = [];
        hasSelection = false;
        patchX = 0;
        patchY = 0;
        canvas.requestPaint();
    }

    Process {
        id: wallpaperProcess
        command: ["cat", (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/tqq-niri-rice/current-wallpaper"]
        stdout: StdioCollector { onStreamFinished: root.wallpaperPath = text.trim() }
    }
    Process {
        id: paletteProcess
        command: ["cat", (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/tqq-niri-rice/colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    root.accent = p.primary || root.accent;
                    root.fg = p.foreground || root.fg;
                    root.muted = p.muted || root.muted;
                } catch (error) { }
            }
        }
    }

    Component.onCompleted: {
        wallpaperProcess.running = true;
        paletteProcess.running = true;
    }

    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Backspace"; context: Qt.ApplicationShortcut; onActivated: root.resetSelection() }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (root.wallpaperPath.length)
                ctx.drawImage("file://" + root.wallpaperPath, 0, 0, width, height);
            else {
                ctx.fillStyle = "#111014";
                ctx.fillRect(0, 0, width, height);
            }

            if (root.hasSelection && root.selectedPoints.length > 2) {
                ctx.save();
                ctx.beginPath();
                ctx.moveTo(root.selectedPoints[0].x, root.selectedPoints[0].y);
                for (let i = 1; i < root.selectedPoints.length; i++)
                    ctx.lineTo(root.selectedPoints[i].x, root.selectedPoints[i].y);
                ctx.closePath();
                ctx.fillStyle = "rgba(10, 8, 14, 0.22)";
                ctx.fill();
                ctx.clip();
                if (root.wallpaperPath.length)
                    ctx.drawImage("file://" + root.wallpaperPath, root.patchX, root.patchY, width, height);
                ctx.restore();

                ctx.save();
                ctx.translate(root.patchX, root.patchY);
                ctx.beginPath();
                ctx.moveTo(root.selectedPoints[0].x, root.selectedPoints[0].y);
                for (let i = 1; i < root.selectedPoints.length; i++)
                    ctx.lineTo(root.selectedPoints[i].x, root.selectedPoints[i].y);
                ctx.closePath();
                ctx.strokeStyle = root.accent;
                ctx.lineWidth = 2;
                ctx.setLineDash([7, 5]);
                ctx.stroke();
                ctx.restore();
            }

            if (root.selecting && root.points.length > 1) {
                ctx.beginPath();
                ctx.moveTo(root.points[0].x, root.points[0].y);
                for (let i = 1; i < root.points.length; i++)
                    ctx.lineTo(root.points[i].x, root.points[i].y);
                ctx.strokeStyle = root.accent;
                ctx.lineWidth = 2;
                ctx.setLineDash([6, 5]);
                ctx.stroke();
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            onPressed: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.selecting = true;
                    root.points = [Qt.point(mouse.x, mouse.y)];
                } else if (mouse.button === Qt.RightButton && root.hasSelection
                           && root.pointInsidePolygon(mouse.x - root.patchX, mouse.y - root.patchY, root.selectedPoints)) {
                    root.dragging = true;
                    root.dragStartX = mouse.x - root.patchX;
                    root.dragStartY = mouse.y - root.patchY;
                }
            }
            onPositionChanged: function(mouse) {
                if (root.selecting) {
                    const next = root.points.slice();
                    next.push(Qt.point(mouse.x, mouse.y));
                    root.points = next;
                    canvas.requestPaint();
                } else if (root.dragging) {
                    root.patchX = mouse.x - root.dragStartX;
                    root.patchY = mouse.y - root.dragStartY;
                    canvas.requestPaint();
                }
            }
            onReleased: function(mouse) {
                if (mouse.button === Qt.LeftButton && root.selecting) {
                    root.selecting = false;
                    if (root.points.length >= 5) {
                        root.selectedPoints = root.points.slice();
                        root.hasSelection = true;
                    }
                    canvas.requestPaint();
                } else if (mouse.button === Qt.RightButton && root.dragging) {
                    root.dragging = false;
                    root.patchX = 0;
                    root.patchY = 0;
                }
            }
        }
    }

    Behavior on patchX { SpringAnimation { spring: 4.2; damping: 0.22; mass: 0.85; epsilon: 0.5 } }
    Behavior on patchY { SpringAnimation { spring: 4.2; damping: 0.22; mass: 0.85; epsilon: 0.5 } }

    Connections {
        target: root
        function onPatchXChanged() { canvas.requestPaint(); }
        function onPatchYChanged() { canvas.requestPaint(); }
        function onWallpaperPathChanged() { canvas.requestPaint(); }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 22
        width: 290
        height: 72
        radius: 16
        color: "#dd151219"
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.6)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4
            Text { text: "TQQ  /  SQUISHY PHYSICS"; color: root.accent; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1 }
            Text {
                text: root.hasSelection ? "ПКМ удерживать и тянуть · Backspace — заново" : "ЛКМ обведи область · ПКМ потяни её"
                color: root.fg
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 22
        width: 38
        height: 38
        radius: 12
        color: "#dd151219"
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.45)
        Text { anchors.centerIn: parent; text: "×"; color: root.fg; font.pixelSize: 21 }
        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
    }
}
