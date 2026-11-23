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
    property var paintedStrokes: []
    property real brushRadius: 33
    property real brushCursorX: 0
    property real brushCursorY: 0
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
    // Broader, gentler movement around the selected patch.
    property real influenceRadius: Math.min(270, Math.max(125, Math.min(width, height) * 0.29))
    // The grab handle is confined to a small circle around the click point.
    // This limits the DEFORMATION, not the real Wayland mouse cursor.
    property real maxPullDistance: Math.min(46, Math.max(32, Math.min(width, height) * 0.045))
    property real ripplePhase: 0
    property real rippleStrength: 0
    property color accent: "#d8a6c2"
    property color fg: "#f5f0f5"
    property color muted: "#aaa0ad"

    // The paint strokes, not a thin lasso outline, define the animated area.
    // Allow several LMB strokes so a whole cheek can be covered gradually.
    function brushPath(ctx, stroke, radius) {
        if (!stroke || stroke.length === 0) return;
        ctx.beginPath();
        if (stroke.length === 1) {
            ctx.arc(stroke[0].x, stroke[0].y, radius, 0, Math.PI * 2);
            ctx.fill();
            return;
        }
        ctx.moveTo(stroke[0].x, stroke[0].y);
        for (let i = 1; i < stroke.length; i++)
            ctx.lineTo(stroke[i].x, stroke[i].y);
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.lineWidth = 2 * radius;
        ctx.stroke();
    }

    function pointInPaint(x, y) {
        const radiusSquared = brushRadius * brushRadius;
        for (const stroke of paintedStrokes) {
            for (let i = 0; i < stroke.length; i++) {
                const a = stroke[i];
                const b = stroke[Math.min(i + 1, stroke.length - 1)];
                const dx = b.x - a.x;
                const dy = b.y - a.y;
                const denom = dx * dx + dy * dy;
                const t = denom > 0
                    ? Math.max(0, Math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / denom))
                    : 0;
                const px = a.x + dx * t;
                const py = a.y + dy * t;
                if ((x - px) * (x - px) + (y - py) * (y - py) <= radiusSquared)
                    return true;
            }
        }
        return false;
    }

    function setPullTarget(x, y) {
        // Keep the virtual grip inside the capture circle even if the
        // physical cursor moves outside it. No unbounded stretching.
        const rawX = x - dragStartX;
        const rawY = y - dragStartY;
        const length = Math.hypot(rawX, rawY);
        const scale = length > maxPullDistance ? maxPullDistance / length : 1.0;
        const newX = rawX * scale;
        const newY = rawY * scale;
        const impulse = Math.hypot(newX - targetX, newY - targetY);
        rippleStrength = Math.max(rippleStrength, Math.min(0.38, impulse / 140.0));
        targetX = newX;
        targetY = newY;
    }

    function refreshSelectionTextures() {
        selectionMask.requestPaint();
        selectionTexture.scheduleUpdate();
        outlineCanvas.requestPaint();
    }

    function resetSelection() {
        points = [];
        paintedStrokes = [];
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
        ripplePhase = 0;
        rippleStrength = 0;
        physicsTimer.stop();
        refreshSelectionTextures();
    }

    function finishDrag() {
        dragging = false;
        outlineCanvas.requestPaint();
        // Preserve momentum when released, for a small elastic overshoot.
        rippleStrength = Math.max(rippleStrength,
                                  Math.min(0.42, Math.hypot(velocityX, velocityY) / 1300.0));
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
        onStatusChanged: if (status === Image.Ready) wallpaperTexture.scheduleUpdate()
    }

    ShaderEffectSource {
        id: wallpaperTexture
        anchors.fill: parent
        sourceItem: wallpaperImage
        hideSource: true
        // Static texture: refresh only when the wallpaper file changes.
        live: false
        smooth: true
        visible: false
    }

    Canvas {
        id: selectionMask
        anchors.fill: parent
        // The ShaderEffectSource captures this white-on-transparent brush mask.
        // Its hideSource property prevents drawing it over the wallpaper.
        renderStrategy: Canvas.Threaded
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "#ffffff";
            ctx.strokeStyle = "#ffffff";
            for (const stroke of root.paintedStrokes)
                root.brushPath(ctx, stroke, root.brushRadius);
        }
    }

    ShaderEffectSource {
        id: selectionTexture
        anchors.fill: parent
        sourceItem: selectionMask
        hideSource: true
        live: true
        smooth: true
        visible: false
    }

    ShaderEffect {
        id: squishySurface
        anchors.fill: parent
        z: 1
        // Precise per-pixel GPU mask replaces the coarse deforming mesh.
        mesh: GridMesh { resolution: Qt.size(2, 2) }
        property var source: wallpaperTexture
        property var maskSource: selectionTexture
        property vector2d viewportSize: Qt.vector2d(root.width, root.height)
        property vector2d dragOrigin: Qt.vector2d(root.dragOriginX, root.dragOriginY)
        property vector2d displacement: Qt.vector2d(root.offsetX, root.offsetY)
        property real influenceRadius: root.influenceRadius
        property real ripplePhase: root.ripplePhase
        property real rippleStrength: root.rippleStrength
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

            // What is visibly painted red is exactly the animated mask.
            // Previously finished strokes remain selectable while adding more.
            ctx.save();
            const alpha = root.dragging ? 0.20 : 0.27;
            ctx.strokeStyle = "rgba(255, 58, 77, " + alpha + ")";
            ctx.fillStyle = ctx.strokeStyle;
            for (const stroke of root.paintedStrokes)
                root.brushPath(ctx, stroke, root.brushRadius);

            if (root.selecting) {
                ctx.strokeStyle = "rgba(255, 58, 77, 0.48)";
                ctx.fillStyle = ctx.strokeStyle;
                root.brushPath(ctx, root.points, root.brushRadius);

                // Visible brush tip indicates the stroke's real width.
                ctx.beginPath();
                ctx.arc(root.brushCursorX, root.brushCursorY,
                        root.brushRadius, 0, Math.PI * 2);
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = "rgba(255, 160, 165, 0.88)";
                ctx.stroke();
            }
            ctx.restore();

            // Show the mouse's deformation territory only while holding RMB.
            // The handle stops at this boundary although the cursor can
            // freely move beyond it.
            if (root.dragging) {
                ctx.save();
                ctx.strokeStyle = root.accent;
                ctx.globalAlpha = 0.46;
                ctx.lineWidth = 1.5;
                ctx.setLineDash([5, 8]);
                ctx.beginPath();
                ctx.arc(root.dragOriginX, root.dragOriginY,
                        root.maxPullDistance, 0, Math.PI * 2);
                ctx.stroke();

                ctx.globalAlpha = 0.85;
                ctx.setLineDash([]);
                ctx.beginPath();
                ctx.moveTo(root.dragOriginX, root.dragOriginY);
                ctx.lineTo(root.dragOriginX + root.targetX,
                           root.dragOriginY + root.targetY);
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(root.dragOriginX + root.targetX,
                        root.dragOriginY + root.targetY, 5, 0, Math.PI * 2);
                ctx.fillStyle = root.accent;
                ctx.fill();
                ctx.restore();
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
            if (mouse.button === Qt.LeftButton && !root.dragging) {
                // A new brush stroke adds to the previous red-painted region.
                // Stop any prior spring movement before changing the mask.
                physicsTimer.stop();
                root.physicsActive = false;
                root.offsetX = 0;
                root.offsetY = 0;
                root.targetX = 0;
                root.targetY = 0;
                root.velocityX = 0;
                root.velocityY = 0;
                root.rippleStrength = 0;
                root.selecting = true;
                root.points = [Qt.point(mouse.x, mouse.y)];
                root.brushCursorX = mouse.x;
                root.brushCursorY = mouse.y;
                outlineCanvas.requestPaint();
            } else if (mouse.button === Qt.RightButton && root.hasSelection
                       && !root.selecting && root.pointInPaint(mouse.x, mouse.y)) {
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
                outlineCanvas.requestPaint();
            }
        }

        onPositionChanged: function(mouse) {
            if (root.selecting) {
                root.brushCursorX = mouse.x;
                root.brushCursorY = mouse.y;
                const last = root.points[root.points.length - 1];
                if (Math.hypot(mouse.x - last.x, mouse.y - last.y) >= 4) {
                    const next = root.points.slice();
                    next.push(Qt.point(mouse.x, mouse.y));
                    root.points = next;
                    outlineCanvas.requestPaint();
                }
            } else if (root.dragging) {
                root.setPullTarget(mouse.x, mouse.y);
                outlineCanvas.requestPaint();
            }
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.LeftButton && root.selecting) {
                root.selecting = false;
                // A click makes one round dab, a drag makes a thick round stroke.
                // Include the last position even if it moved less than 4px.
                const stroke = root.points.slice();
                if (stroke.length > 0) {
                    const last = stroke[stroke.length - 1];
                    if (Math.hypot(mouse.x - last.x, mouse.y - last.y) >= 1)
                        stroke.push(Qt.point(mouse.x, mouse.y));
                    root.paintedStrokes = root.paintedStrokes.concat([stroke]);
                    root.hasSelection = true;
                }
                root.points = [];
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

            // Soft tracking and a gently damped return without snapping.
            const stiffness = root.dragging ? 100.0 : 72.0;
            const dampingRatio = root.dragging ? 1.02 : 0.78;
            const damping = 2.0 * Math.sqrt(stiffness) * dampingRatio;
            root.velocityX += ((root.targetX - root.offsetX) * stiffness - root.velocityX * damping) * dt;
            root.velocityY += ((root.targetY - root.offsetY) * stiffness - root.velocityY * damping) * dt;
            // Cap sudden pointer impulses so the cheek never jumps sharply.
            const velocity = Math.hypot(root.velocityX, root.velocityY);
            const maxSpeed = 390.0;
            if (velocity > maxSpeed) {
                root.velocityX *= maxSpeed / velocity;
                root.velocityY *= maxSpeed / velocity;
            }
            root.offsetX += root.velocityX * dt;
            root.offsetY += root.velocityY * dt;

            // Do not let spring inertia carry the cheek past its grab circle
            // while RMB is held. On release it may overshoot a little.
            if (root.dragging) {
                const travel = Math.hypot(root.offsetX, root.offsetY);
                if (travel > root.maxPullDistance) {
                    const nx = root.offsetX / travel;
                    const ny = root.offsetY / travel;
                    root.offsetX = nx * root.maxPullDistance;
                    root.offsetY = ny * root.maxPullDistance;
                    const outwardVelocity = root.velocityX * nx + root.velocityY * ny;
                    if (outwardVelocity > 0) {
                        root.velocityX -= outwardVelocity * nx;
                        root.velocityY -= outwardVelocity * ny;
                    }
                }
            }

            // The ripple fades with motion; no always-running physics loop.
            const speed = Math.hypot(root.velocityX, root.velocityY);
            root.ripplePhase += dt * 14.0;
            root.rippleStrength = Math.min(0.45,
                Math.max(root.rippleStrength * Math.exp(-7.0 * dt), speed / 3200.0));
            outlineCanvas.requestPaint();

            if (!root.dragging
                    && Math.abs(root.targetX - root.offsetX) < 0.16
                    && Math.abs(root.targetY - root.offsetY) < 0.16
                    && Math.abs(root.velocityX) < 0.8
                    && Math.abs(root.velocityY) < 0.8
                    && root.rippleStrength < 0.02) {
                root.targetX = 0;
                root.targetY = 0;
                root.offsetX = 0;
                root.offsetY = 0;
                root.velocityX = 0;
                root.velocityY = 0;
                root.rippleStrength = 0;
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
                text: "SQUISHY PHYSICS"
                color: root.accent
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1.1
            }
            Text {
                text: root.selecting
                    ? "LMB: paint the red area with a thick brush"
                    : root.hasSelection
                        ? "LMB: add paint · RMB: pull red area · Backspace: clear"
                        : "LMB: paint the area · RMB: gently pull"
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
