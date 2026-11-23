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
    property bool physicsActive: false
    property real dragOriginX: 0
    property real dragOriginY: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property real targetX: 0
    property real targetY: 0
    property real offsetX: 0
    property real offsetY: 0
    property real velocityX: 0
    property real velocityY: 0
    property double lastTick: 0
    property real influenceRadius: Math.max(260, Math.min(width, height) * 0.38)
    property color accent: "#d8a6c2"
    property color fg: "#f5f0f5"
    property color muted: "#aaa0ad"

    function pointInsidePolygon(x, y, polygon) {
        let inside = false;
        for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
            const xi = polygon[i].x, yi = polygon[i].y;
            const xj = polygon[j].x, yj = polygon[j].y;
            const intersects = ((yi > y) !== (yj > y))
                && (x < (xj - xi) * (y - yi) / ((yj - yi) || 0.0001) + xi);
            if (intersects) inside = !inside;
        }
        return inside;
    }

    function influenceAt(x, y) {
        const distance = Math.hypot(x - dragOriginX, y - dragOriginY);
        const t = Math.max(0, Math.min(1, distance / Math.max(1, influenceRadius)));
        const radial = 1.0 - t * t * (3.0 - 2.0 * t);
        return 0.22 + 0.78 * radial;
    }

    function visiblePolygon() {
        const result = [];
        const moving = dragging || physicsActive;
        for (let i = 0; i < selectedPoints.length; i++) {
            const p = selectedPoints[i];
            const weight = moving ? influenceAt(p.x, p.y) : 0;
            result.push(Qt.point(p.x + offsetX * weight, p.y + offsetY * weight));
        }
        return result;
    }

    function refreshSelectionTextures() {
        selectionMask.requestPaint();
        selectionTexture.scheduleUpdate();
        outlineCanvas.requestPaint();
    }

    function resetSelection() {
        points = [];
        selectedPoints = [];
        hasSelection = false;
        selecting = false;
        dragging = false;
        physicsActive = false;
        targetX = 0;
        targetY = 0;
        offsetX = 0;
        offsetY = 0;
        velocityX = 0;
        velocityY = 0;
        physicsTimer.stop();
        refreshSelectionTextures();
    }

    function finishDrag() {
        dragging = false;
        targetX = 0;
        targetY = 0;
        physicsActive = true;
        lastTick = Date.now();
        physicsTimer.restart();
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

    Rectangle {
        anchors.fill: parent
        color: "#111014"
        z: -3
    }

    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: root.wallpaperPath.length ? "file://" + root.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Ready) selectionTexture.scheduleUpdate()
    }

    ShaderEffectSource {
        id: wallpaperTexture
        anchors.fill: parent
        sourceItem: wallpaperImage
        hideSource: true
        live: true
        smooth: true
    }

    Canvas {
        id: selectionMask
        anchors.fill: parent
        renderStrategy: Canvas.Threaded
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!root.hasSelection || root.selectedPoints.length < 3)
                return;
            ctx.beginPath();
            ctx.moveTo(root.selectedPoints[0].x, root.selectedPoints[0].y);
            for (let i = 1; i < root.selectedPoints.length; i++)
                ctx.lineTo(root.selectedPoints[i].x, root.selectedPoints[i].y);
            ctx.closePath();
            ctx.fillStyle = "#ffffff";
            ctx.fill();
        }
    }

    ShaderEffectSource {
        id: selectionTexture
        anchors.fill: parent
        sourceItem: selectionMask
        hideSource: true
        live: true
        smooth: true
        opacity: 0
    }

    ShaderEffect {
        id: squishySurface
        anchors.fill: parent
        z: 1
        mesh: GridMesh { resolution: Qt.size(128, 72) }
        property var source: wallpaperTexture
        property var maskSource: selectionTexture
        property vector2d viewportSize: Qt.vector2d(root.width, root.height)
        property vector2d dragOrigin: Qt.vector2d(root.dragOriginX, root.dragOriginY)
        property vector2d displacement: Qt.vector2d(root.offsetX, root.offsetY)
        property real influenceRadius: root.influenceRadius
        vertexShader: "squishy.vert.qsb"
        fragmentShader: "squishy.frag.qsb"
        blending: true
        cullMode: ShaderEffect.NoCulling
        onStatusChanged: {
            if (status === ShaderEffect.Error)
                console.warn("TQQ Squishy shader error:", log);
        }
    }

    Canvas {
        id: outlineCanvas
        anchors.fill: parent
        z: 2
        renderStrategy: Canvas.Threaded
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

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

            if (root.hasSelection && root.selectedPoints.length > 2) {
                const polygon = root.visiblePolygon();
                ctx.beginPath();
                ctx.moveTo(polygon[0].x, polygon[0].y);
                for (let i = 1; i < polygon.length; i++)
                    ctx.lineTo(polygon[i].x, polygon[i].y);
                ctx.closePath();
                ctx.strokeStyle = root.accent;
                ctx.lineWidth = 1.7;
                ctx.setLineDash([7, 5]);
                ctx.stroke();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 3
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: false
        preventStealing: true

        onPressed: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.selecting = true;
                root.points = [Qt.point(mouse.x, mouse.y)];
                outlineCanvas.requestPaint();
            } else if (mouse.button === Qt.RightButton && root.hasSelection
                       && root.pointInsidePolygon(mouse.x, mouse.y, root.visiblePolygon())) {
                root.dragging = true;
                root.physicsActive = true;
                root.dragOriginX = mouse.x;
                root.dragOriginY = mouse.y;
                root.dragStartX = mouse.x - root.offsetX;
                root.dragStartY = mouse.y - root.offsetY;
                root.targetX = root.offsetX;
                root.targetY = root.offsetY;
                root.lastTick = Date.now();
                physicsTimer.restart();
            }
        }

        onPositionChanged: function(mouse) {
            if (root.selecting) {
                const last = root.points[root.points.length - 1];
                if (Math.hypot(mouse.x - last.x, mouse.y - last.y) >= 5) {
                    const next = root.points.slice();
                    next.push(Qt.point(mouse.x, mouse.y));
                    root.points = next;
                    outlineCanvas.requestPaint();
                }
            } else if (root.dragging) {
                root.targetX = mouse.x - root.dragStartX;
                root.targetY = mouse.y - root.dragStartY;
                outlineCanvas.requestPaint();
            }
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton && root.selecting) {
                root.selecting = false;
                if (root.points.length >= 5) {
                    root.selectedPoints = root.points.slice();
                    root.hasSelection = true;
                }
                root.refreshSelectionTextures();
            } else if (mouse.button === Qt.RightButton && root.dragging) {
                root.finishDrag();
            }
        }

        onCanceled: {
            if (root.selecting) {
                root.selecting = false;
                root.points = [];
                outlineCanvas.requestPaint();
            }
            if (root.dragging)
                root.finishDrag();
        }
    }

    Timer {
        id: physicsTimer
        interval: 16
        repeat: true
        onTriggered: {
            const now = Date.now();
            const dt = root.lastTick > 0
                ? Math.min(0.033, Math.max(0.008, (now - root.lastTick) / 1000))
                : 0.016;
            root.lastTick = now;

            const stiffness = 185.0;
            const damping = 22.0;
            root.velocityX += ((root.targetX - root.offsetX) * stiffness - root.velocityX * damping) * dt;
            root.velocityY += ((root.targetY - root.offsetY) * stiffness - root.velocityY * damping) * dt;
            root.offsetX += root.velocityX * dt;
            root.offsetY += root.velocityY * dt;
            outlineCanvas.requestPaint();

            if (!root.dragging
                    && Math.abs(root.targetX - root.offsetX) < 0.16
                    && Math.abs(root.targetY - root.offsetY) < 0.16
                    && Math.abs(root.velocityX) < 0.8
                    && Math.abs(root.velocityY) < 0.8) {
                root.targetX = 0;
                root.targetY = 0;
                root.offsetX = 0;
                root.offsetY = 0;
                root.velocityX = 0;
                root.velocityY = 0;
                root.physicsActive = false;
                stop();
                outlineCanvas.requestPaint();
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 22
        width: 330
        height: 76
        radius: 16
        color: "#dd151219"
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.6)
        z: 5
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4
            Text {
                text: "TQQ  /  SQUISHY PHYSICS"
                color: root.accent
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1.1
            }
            Text {
                text: root.hasSelection
                    ? "ПКМ — потянуть область · отпусти — пружинный возврат"
                    : "ЛКМ — обвести область · ПКМ — потянуть её"
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
        z: 6
        Text {
            anchors.centerIn: parent
            text: "×"
            color: root.fg
            font.pixelSize: 21
        }
        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
    }

    Connections {
        target: root
        function onOffsetXChanged() { outlineCanvas.requestPaint(); }
        function onOffsetYChanged() { outlineCanvas.requestPaint(); }
        function onWallpaperPathChanged() { selectionTexture.scheduleUpdate(); }
    }
}
