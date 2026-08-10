import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.layershell 1.0 as LayerShell
import org.kde.layershell 1.0 as LS

ApplicationWindow {
    id: window
    visible: false
    width: 840
    height: 480
    color: "transparent"

    // Wayland Layer Shell bindings
    LayerShell.Window.layer: LS.Window.LayerOverlay
    LayerShell.Window.anchors: LS.Window.AnchorTop
    LayerShell.Window.margins.top: window.topMarginValue
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: active ? LS.Window.KeyboardInteractivityExclusive : LS.Window.KeyboardInteractivityNone

    Shortcut {
        sequence: "Escape"
        onActivated: monitorManager.active = false
    }

    // State bindings
    readonly property bool active: monitorManager.active

    onActiveChanged: {
        if (active) {
            showAnim.start()
            visualRoot.forceActiveFocus()
        } else {
            hideAnim.start()
        }
    }

    property real topMarginValue: 15
    property real scaleValue: 0.85
    property real opacityValue: 0.0

    SequentialAnimation {
        id: showAnim
        ScriptAction { script: { window.visible = true; } }
        ParallelAnimation {
            NumberAnimation { target: window; property: "topMarginValue"; to: 50; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "scaleValue"; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: window; property: "opacityValue"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "topMarginValue"; to: 15; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "scaleValue"; to: 0.85; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "opacityValue"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { window.visible = false; } }
    }

    // Gruvbox Palette integration via ThemeManager
    readonly property color c_bg: themeManager.colors["background"] || "#282828"
    readonly property color c_fg: themeManager.colors["foreground"] || "#ebdbb2"

    function getThemeColor(name, fallback) {
        if (themeManager.colors && themeManager.colors["colors"]) {
            var val = themeManager.colors["colors"][name];
            if (val) return val;
        }
        return fallback;
    }

    readonly property color c_red: getThemeColor("color1", "#fb4934")
    readonly property color c_green: getThemeColor("color2", "#b8bb26")
    readonly property color c_yellow: getThemeColor("color3", "#fabd2f")
    readonly property color c_blue: getThemeColor("color4", "#83a598")
    readonly property color c_purple: getThemeColor("color5", "#d3869b")
    readonly property color c_orange: getThemeColor("color6", "#fe8019")
    readonly property color c_gray: getThemeColor("color8", "#928374")
    readonly property color c_mantle: getThemeColor("color0", "#1d2021")
    readonly property color c_crust: getThemeColor("color0", "#151718")

    function hexToRgba(hex, alpha) {
        if (!hex) return Qt.rgba(40/255.0, 40/255.0, 40/255.0, alpha);
        var hexStr = hex.toString().replace("#", "");
        if (hexStr.length === 8) {
            hexStr = hexStr.substring(0, 6);
        }
        if (hexStr.length !== 6) return Qt.rgba(40/255.0, 40/255.0, 40/255.0, alpha);
        var r = parseInt(hexStr.substring(0, 2), 16) / 255.0;
        var g = parseInt(hexStr.substring(2, 4), 16) / 255.0;
        var b = parseInt(hexStr.substring(4, 6), 16) / 255.0;
        return Qt.rgba(r, g, b, alpha);
    }

    // UI state
    property int activeEditIndex: 0
    property int activeFocusIndex: 0 // 0: Res, 1: Clock, 2: Frame, 3: Apply
    property real uiScale: 0.12 // scale down physical coordinates for drag layout

    ListModel {
        id: monitorsModel
    }

    Connections {
        target: monitorManager
        function onMonitorsChanged() {
            monitorsModel.clear();
            var data = monitorManager.monitors;
            var minX = 999999;
            var minY = 999999;

            for (var i = 0; i < data.length; i++) {
                var m = data[i];
                if (m.disabled) continue;
                if (m.x < minX) minX = m.x;
                if (m.y < minY) minY = m.y;
            }
            if (minX === 999999) minX = 0;
            if (minY === 999999) minY = 0;

            for (var i = 0; i < data.length; i++) {
                var m = data[i];
                var normalizedX = (m.x - minX) * window.uiScale;
                var normalizedY = (m.y - minY) * window.uiScale;

                monitorsModel.append({
                    name: m.name,
                    description: m.description,
                    resW: m.width,
                    resH: m.height,
                    sysScale: m.scale,
                    rate: Math.round(m.refreshRate).toString(),
                    uiX: normalizedX,
                    uiY: normalizedY,
                    transform: m.transform,
                    focused: m.focused,
                    disabled: m.disabled,
                    availableModes: m.availableModes
                });

                if (m.focused) {
                    window.activeEditIndex = monitorsModel.count - 1;
                }
            }
            if (window.activeEditIndex >= monitorsModel.count && monitorsModel.count > 0) {
                window.activeEditIndex = 0;
            }
            window.forceLayoutUpdate();
        }
    }

    property var resList: [
        {w: 3840, h: 2160, l: "4K",   accent: window.c_purple},
        {w: 2560, h: 1440, l: "QHD",  accent: window.c_purple},
        {w: 1920, h: 1080, l: "FHD",  accent: window.c_blue},
        {w: 1600, h: 900,  l: "HD+",  accent: window.c_blue},
        {w: 1366, h: 768,  l: "WXGA", accent: window.c_yellow},
        {w: 1280, h: 720,  l: "HD",   accent: window.c_orange},
        {w: 1024, h: 768,  l: "XGA",  accent: window.c_green},
        {w: 800,  h: 600,  l: "SVGA", accent: window.c_red}
    ]

    property color selectedResAccent: window.c_purple
    property color selectedRateAccent: window.c_blue

    property int currentTransform: (monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count) ? monitorsModel.get(window.activeEditIndex).transform : 0
    property bool currentIsPortrait: currentTransform === 1 || currentTransform === 3

    property real currentSimW: {
        if (monitorsModel.count === 0 || window.activeEditIndex >= monitorsModel.count) return 1920;
        var mon = monitorsModel.get(window.activeEditIndex);
        return currentIsPortrait ? mon.resH : mon.resW;
    }
    property real currentSimH: {
        if (monitorsModel.count === 0 || window.activeEditIndex >= monitorsModel.count) return 1080;
        var mon = monitorsModel.get(window.activeEditIndex);
        return currentIsPortrait ? mon.resW : mon.resH;
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: window.visible
    }

    property real introProgress: window.opacityValue
    property real monitorScale: window.scaleValue
    property real uiYOffset: 0
    property real screenLight: window.opacityValue

    property bool applyHovered: false
    property bool applyPressed: false

    onActiveEditIndexChanged: {
        menuTransitionAnim.restart();
    }

    // Snapping / Layout Arithmetic
    function isOverlapping(ax, ay, aw, ah, bx, by, bw, bh) {
        return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
    }

    function isOverlappingAny(x, y, w, h, skipIdx) {
        for (var i = 0; i < monitorsModel.count; i++) {
            if (i === skipIdx) continue;
            var m = monitorsModel.get(i);
            if (m.disabled) continue;
            var isP = m.transform === 1 || m.transform === 3;
            var mW = ((isP ? m.resH : m.resW) / m.sysScale) * window.uiScale;
            var mH = ((isP ? m.resW : m.resH) / m.sysScale) * window.uiScale;
            if (isOverlapping(x, y, w, h, m.uiX, m.uiY, mW, mH)) return true;
        }
        return false;
    }

    function getPerimeterSnap(pX, pY, sX, sY, sW, sH, mW, mH, snapT) {
        var edges = [
            { x1: sX - mW, x2: sX + sW, y1: sY - mH, y2: sY - mH }, // Top Edge
            { x1: sX - mW, x2: sX + sW, y1: sY + sH, y2: sY + sH }, // Bottom Edge
            { x1: sX - mW, x2: sX - mW, y1: sY - mH, y2: sY + sH }, // Left Edge
            { x1: sX + sW, x2: sX + sW, y1: sY - mH, y2: sY + sH }  // Right Edge
        ];

        var bestX = pX;
        var bestY = pY;
        var minDist = 999999;

        for (var i = 0; i < 4; i++) {
            var e = edges[i];

            var cx = Math.max(e.x1, Math.min(pX, e.x2));
            var cy = Math.max(e.y1, Math.min(pY, e.y2));

            if (Math.abs(cx - sX) < snapT) cx = sX;
            if (Math.abs(cx - (sX + sW - mW)) < snapT) cx = sX + sW - mW;
            if (Math.abs(cx - (sX + sW/2 - mW/2)) < snapT) cx = sX + sW/2 - mW/2;

            if (Math.abs(cy - sY) < snapT) cy = sY;
            if (Math.abs(cy - (sY + sH - mH)) < snapT) cy = sY + sH - mH;
            if (Math.abs(cy - (sY + sH/2 - mH/2)) < snapT) cy = sY + sH/2 - mH/2;

            var dist = Math.hypot(pX - cx, pY - cy);
            if (dist < minDist) {
                minDist = dist;
                bestX = cx;
                bestY = cy;
            }
        }
        return { x: bestX, y: bestY };
    }

    function forceLayoutUpdate() {
        if (monitorsModel.count < 2) return;

        var mIdx = window.activeEditIndex;
        if (mIdx >= monitorsModel.count) return;
        var mModel = monitorsModel.get(mIdx);
        if (mModel.disabled) return;
        var isP = mModel.transform === 1 || mModel.transform === 3;
        var mW = ((isP ? mModel.resH : mModel.resW) / mModel.sysScale) * window.uiScale;
        var mH = ((isP ? mModel.resW : mModel.resH) / mModel.sysScale) * window.uiScale;

        var bestX = mModel.uiX;
        var bestY = mModel.uiY;
        var bestDist = 999999;

        for (var i = 0; i < monitorsModel.count; i++) {
            if (i === mIdx) continue;
            var sModel = monitorsModel.get(i);
            if (sModel.disabled) continue;
            var sIsP = sModel.transform === 1 || sModel.transform === 3;
            var sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * window.uiScale;
            var sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * window.uiScale;

            var snapped = window.getPerimeterSnap(
                mModel.uiX, mModel.uiY,
                sModel.uiX, sModel.uiY,
                sW, sH, mW, mH, 20
            );

            var dist = Math.hypot(snapped.x - mModel.uiX, snapped.y - mModel.uiY);
            if (dist < bestDist) {
                bestDist = dist;
                bestX = snapped.x;
                bestY = snapped.y;
            }
        }

        monitorsModel.setProperty(mIdx, "uiX", bestX);
        monitorsModel.setProperty(mIdx, "uiY", bestY);
    }

    Timer {
        id: delayedLayoutUpdate
        interval: 10
        running: false
        repeat: false
        onTriggered: window.forceLayoutUpdate()
    }

    // Action execution
    function triggerApply() {
        if (monitorsModel.count === 0) return;

        var applyConfigs = [];
        for (var i = 0; i < monitorsModel.count; i++) {
            var m = monitorsModel.get(i);
            applyConfigs.push({
                name: m.name,
                disabled: m.disabled,
                resW: m.resW,
                resH: m.resH,
                rate: m.rate,
                x: Math.round(m.uiX / window.uiScale),
                y: Math.round(m.uiY / window.uiScale),
                sysScale: m.sysScale,
                transform: m.transform
            });
        }
        monitorManager.applyConfig(applyConfigs);
    }

    // Outer visual shell
    Item {
        id: visualRoot
        anchors.fill: parent
        focus: true
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                monitorManager.active = false;
                event.accepted = true;
            }
        }
        scale: 0.95 + (0.05 * window.introProgress)
        opacity: window.introProgress

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: window.c_bg
            border.color: hexToRgba(window.c_fg, 0.15)
            border.width: 1
            clip: true

            // Glowing backgrounds
            Rectangle {
                width: parent.width * 0.8
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * 150
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * 100
                opacity: 0.05
                color: window.selectedResAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }
            Rectangle {
                width: parent.width * 0.9
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * -150
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * -100
                opacity: 0.05
                color: window.selectedRateAccent
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            // Outer Close Button (top-right)
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: closeMa.containsMouse ? hexToRgba(window.c_red, 0.2) : hexToRgba(window.c_fg, 0.05)
                border.color: closeMa.containsMouse ? window.c_red : "transparent"
                border.width: 1
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 16
                anchors.rightMargin: 16
                z: 100

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "JetBrains Mono"
                    font.pixelSize: 14
                    color: closeMa.containsMouse ? window.c_red : window.c_fg
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: monitorManager.active = false
                }
            }

            // Left Side Visual Area
            Item {
                id: leftVisualArea
                width: 380
                height: 400
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20

                // Mode 1: Single Monitor layout
                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count === 1

                    Item {
                        id: singleMonitorZoom
                        anchors.centerIn: parent
                        width: 380
                        height: 320

                        property real baseScale: Math.min(1.0, Math.min(2200 / window.currentSimW, 1400 / Math.max(1, window.currentSimH)))
                        scale: baseScale * window.monitorScale
                        opacity: window.introProgress

                        Rectangle {
                            id: deskSurface
                            width: 1000
                            height: 14
                            radius: 6
                            anchors.top: standBase.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: window.c_mantle
                            border.color: hexToRgba(window.c_fg, 0.1)
                            border.width: 1
                        }

                        Rectangle {
                            id: standBase
                            width: 130
                            height: 8
                            radius: 4
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 30
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: window.c_gray
                        }

                        Rectangle {
                            id: standNeck
                            width: 34
                            height: 70
                            anchors.bottom: standBase.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: hexToRgba(window.c_fg, 0.1)
                        }

                        Rectangle {
                            id: screenBezel
                            width: 320 * (window.currentSimW / 1920.0)
                            height: 200 * (window.currentSimH / 1080.0)
                            anchors.bottom: standNeck.top
                            anchors.bottomMargin: -10
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: 12
                            color: window.c_crust
                            border.color: hexToRgba(window.c_fg, 0.15)
                            border.width: 2

                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 10
                                radius: 6
                                color: (monitorsModel.count > 0 && monitorsModel.get(0).disabled) ? "#32302f" : window.c_bg
                                clip: true

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    rotation: window.currentTransform * 90

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.pixelSize: 32
                                        color: (monitorsModel.count > 0 && monitorsModel.get(0).disabled) ? window.c_gray : window.selectedResAccent
                                        text: "󰍹"
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: "JetBrains Mono"
                                        font.bold: true
                                        font.pixelSize: 13
                                        color: window.c_fg
                                        text: monitorsModel.count > 0 ? monitorsModel.get(0).name : "Unknown"
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        color: window.c_gray
                                        text: (monitorsModel.count > 0 && monitorsModel.get(0).disabled) ? "Apagada" : (window.currentSimW + "x" + window.currentSimH + " @ " + (monitorsModel.count > 0 ? monitorsModel.get(0).rate : "60") + "Hz")
                                    }
                                }
                            }
                        }
                    }
                }

                // Mode 2: Multi-Monitor arrangement canvas
                Item {
                    anchors.fill: parent
                    visible: monitorsModel.count > 1

                    Rectangle {
                        id: multiMonitorCanvas
                        anchors.fill: parent
                        color: hexToRgba(window.c_mantle, 0.4)
                        border.color: hexToRgba(window.c_fg, 0.1)
                        border.width: 1
                        radius: 16
                        clip: true

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            text: "Arrastra y acopla las pantallas"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: window.c_gray
                        }

                        // Target scale & offset to center screens in visual canvas
                        property real targetScale: {
                            if (monitorsModel.count < 2) return 1.0;
                            var minX = 999999, minY = 999999, maxX = -999999, maxY = -999999;
                            for (var i = 0; i < monitorsModel.count; i++) {
                                var m = monitorsModel.get(i);
                                if (m.disabled) continue;
                                var isP = m.transform === 1 || m.transform === 3;
                                var w = ((isP ? m.resH : m.resW) / m.sysScale) * window.uiScale;
                                var h = ((isP ? m.resW : m.resH) / m.sysScale) * window.uiScale;

                                minX = Math.min(minX, m.uiX);
                                minY = Math.min(minY, m.uiY);
                                maxX = Math.max(maxX, m.uiX + w);
                                maxY = Math.max(maxY, m.uiY + h);
                            }
                            var reqW = (maxX - minX) + 60;
                            var reqH = (maxY - minY) + 60;
                            return Math.min(1.2, Math.min(340 / reqW, 240 / reqH));
                        }

                        property real offsetX: {
                            if (monitorsModel.count < 2) return 0;
                            var minX = 999999, maxX = -999999;
                            for (var i = 0; i < monitorsModel.count; i++) {
                                var m = monitorsModel.get(i);
                                if (m.disabled) continue;
                                var isP = m.transform === 1 || m.transform === 3;
                                var w = ((isP ? m.resH : m.resW) / m.sysScale) * window.uiScale;
                                minX = Math.min(minX, m.uiX);
                                maxX = Math.max(maxX, m.uiX + w);
                            }
                            var centerX = minX + (maxX - minX) / 2;
                            return 190 - (centerX * targetScale);
                        }

                        property real offsetY: {
                            if (monitorsModel.count < 2) return 0;
                            var minY = 999999, maxY = -999999;
                            for (var i = 0; i < monitorsModel.count; i++) {
                                var m = monitorsModel.get(i);
                                if (m.disabled) continue;
                                var isP = m.transform === 1 || m.transform === 3;
                                var h = ((isP ? m.resW : m.resH) / m.sysScale) * window.uiScale;
                                minY = Math.min(minY, m.uiY);
                                maxY = Math.max(maxY, m.uiY + h);
                            }
                            var centerY = minY + (maxY - minY) / 2;
                            return 170 - (centerY * targetScale);
                        }

                        Item {
                            id: dragContainerNode
                            x: multiMonitorCanvas.offsetX
                            y: multiMonitorCanvas.offsetY
                            scale: multiMonitorCanvas.targetScale
                            transformOrigin: Item.TopLeft

                            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                            Repeater {
                                model: monitorsModel
                                delegate: Item {
                                    id: monitorWrapper
                                    property bool isActive: window.activeEditIndex === index
                                    property bool isPortrait: model.transform === 1 || model.transform === 3

                                    // Display Card
                                    Rectangle {
                                        id: monitorCard
                                        x: model.uiX
                                        y: model.uiY
                                        width: Math.max(50, (isPortrait ? model.resH : model.resW) / model.sysScale * window.uiScale)
                                        height: Math.max(30, (isPortrait ? model.resW : model.resH) / model.sysScale * window.uiScale)
                                        radius: 8
                                        color: model.disabled ? "#3c3836" : (isActive ? window.c_mantle : window.c_crust)
                                        border.color: model.disabled ? window.c_gray : (isActive ? window.selectedResAccent : hexToRgba(window.c_fg, 0.2))
                                        border.width: isActive ? 2 : 1
                                        z: isActive ? 5 : 1
                                        opacity: model.disabled ? 0.5 : 1.0

                                        Behavior on x { id: xAnim; NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on y { id: yAnim; NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                                        Behavior on width { NumberAnimation { duration: 300 } }
                                        Behavior on height { NumberAnimation { duration: 300 } }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 1
                                            rotation: model.transform * 90

                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.pixelSize: parent.height > 50 ? 20 : 14
                                                color: model.disabled ? window.c_gray : (isActive ? window.selectedResAccent : window.c_fg)
                                                text: "󰍹"
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Bold
                                                font.pixelSize: parent.height > 50 ? 11 : 9
                                                color: window.c_fg
                                                text: model.name
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 8
                                                color: window.c_gray
                                                text: model.disabled ? "OFF" : (model.resW + "x" + model.resH)
                                            }
                                        }
                                    }

                                    // Ghost Dragger handles actual mouse events to trigger perimeter snapping
                                    Item {
                                        id: ghostDrag
                                        x: model.uiX
                                        y: model.uiY
                                        width: monitorCard.width
                                        height: monitorCard.height
                                        z: isActive ? 10 : 2
                                        visible: !model.disabled

                                        MouseArea {
                                            id: ghostMa
                                            anchors.fill: parent
                                            drag.target: ghostDrag
                                            drag.axis: Drag.XAndYAxis

                                            onPressed: {
                                                window.activeEditIndex = index;
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                                xAnim.enabled = false;
                                                yAnim.enabled = false;
                                            }

                                            onPositionChanged: {
                                                if (drag.active && monitorsModel.count >= 2) {
                                                    var mW = monitorCard.width;
                                                    var mH = monitorCard.height;
                                                    var padding = 50;

                                                    var boundMinX = 999999, boundMinY = 999999;
                                                    var boundMaxX = -999999, boundMaxY = -999999;

                                                    for (var j = 0; j < monitorsModel.count; j++) {
                                                        if (j === index) continue;
                                                        var sModel = monitorsModel.get(j);
                                                        if (sModel.disabled) continue;
                                                        var sIsP = sModel.transform === 1 || sModel.transform === 3;
                                                        var sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * window.uiScale;
                                                        var sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * window.uiScale;

                                                        boundMinX = Math.min(boundMinX, sModel.uiX - mW - padding);
                                                        boundMinY = Math.min(boundMinY, sModel.uiY - mH - padding);
                                                        boundMaxX = Math.max(boundMaxX, sModel.uiX + sW + padding);
                                                        boundMaxY = Math.max(boundMaxY, sModel.uiY + sH + padding);
                                                    }

                                                    if (boundMinX === 999999) { boundMinX = -200; boundMinY = -200; boundMaxX = 500; boundMaxY = 500; }

                                                    ghostDrag.x = Math.max(boundMinX, Math.min(ghostDrag.x, boundMaxX));
                                                    ghostDrag.y = Math.max(boundMinY, Math.min(ghostDrag.y, boundMaxY));

                                                    var bestX = ghostDrag.x;
                                                    var bestY = ghostDrag.y;
                                                    var bestDist = 999999;

                                                    for (var j = 0; j < monitorsModel.count; j++) {
                                                        if (j === index) continue;
                                                        var sModel = monitorsModel.get(j);
                                                        if (sModel.disabled) continue;
                                                        var sIsP = sModel.transform === 1 || sModel.transform === 3;
                                                        var sW = ((sIsP ? sModel.resH : sModel.resW) / sModel.sysScale) * window.uiScale;
                                                        var sH = ((sIsP ? sModel.resW : sModel.resH) / sModel.sysScale) * window.uiScale;

                                                        var snapped = window.getPerimeterSnap(
                                                            ghostDrag.x, ghostDrag.y,
                                                            sModel.uiX, sModel.uiY,
                                                            sW, sH, mW, mH, 20
                                                        );

                                                        var dist = Math.hypot(ghostDrag.x - snapped.x, ghostDrag.y - snapped.y);
                                                        if (dist < bestDist) {
                                                            bestDist = dist;
                                                            bestX = snapped.x;
                                                            bestY = snapped.y;
                                                        }
                                                    }

                                                    if (!window.isOverlappingAny(bestX, bestY, mW, mH, index)) {
                                                        monitorsModel.setProperty(index, "uiX", bestX);
                                                        monitorsModel.setProperty(index, "uiY", bestY);
                                                    }
                                                }
                                            }

                                            onReleased: {
                                                xAnim.enabled = true;
                                                yAnim.enabled = true;
                                                ghostDrag.x = model.uiX;
                                                ghostDrag.y = model.uiY;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Right Side Interactive Panel
            Item {
                anchors.left: leftVisualArea.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                anchors.rightMargin: 30
                height: 420

                opacity: window.introProgress

                SequentialAnimation {
                    id: menuTransitionAnim
                    ParallelAnimation {
                        ScaleAnimator {
                            target: rightSideContainer
                            from: 0.98; to: 1.0
                            duration: 200; easing.type: Easing.OutSine
                        }
                    }
                }

                ColumnLayout {
                    id: rightSideContainer
                    anchors.fill: parent
                    spacing: 12

                    // Title & Description
                    ColumnLayout {
                        spacing: 2
                        Text {
                            font.family: "JetBrains Mono"
                            font.bold: true
                            font.pixelSize: 18
                            color: window.c_fg
                            text: (monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count) ? "Pantalla: " + monitorsModel.get(window.activeEditIndex).name : "Pantalla"
                        }
                        Text {
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: window.c_gray
                            text: (monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count) ? monitorsModel.get(window.activeEditIndex).description : ""
                        }
                    }

                    // Enable/Disable Switch Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count

                        Text {
                            font.family: "JetBrains Mono"
                            font.bold: true
                            font.pixelSize: 13
                            color: window.c_fg
                            text: "Habilitar Pantalla:"
                        }

                        Item { Layout.fillWidth: true }

                        Switch {
                            id: activeSwitch
                            checked: (monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count) ? !monitorsModel.get(window.activeEditIndex).disabled : true
                            onCheckedChanged: {
                                if (monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count) {
                                    monitorsModel.setProperty(window.activeEditIndex, "disabled", !checked);
                                }
                            }
                        }
                    }

                    // Resolution grid section
                    GridLayout {
                        id: resGrid
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8
                        enabled: activeSwitch.checked

                        Repeater {
                            model: window.resList
                            delegate: Rectangle {
                                property var modelData: window.resList[index]
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 10

                                property bool isSel: {
                                    if (monitorsModel.count === 0 || window.activeEditIndex >= monitorsModel.count) return false;
                                    var activeMon = monitorsModel.get(window.activeEditIndex);
                                    return activeMon.resW === modelData.w && activeMon.resH === modelData.h;
                                }
                                property color accentColor: modelData.accent

                                color: isSel ? hexToRgba(accentColor, 0.18) : (resMa.containsMouse ? hexToRgba(window.c_fg, 0.08) : window.c_mantle)
                                border.color: isSel ? accentColor : (resMa.containsMouse ? hexToRgba(window.c_fg, 0.2) : "transparent")
                                border.width: isSel ? 2 : 1

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6

                                    Text {
                                        font.family: "JetBrains Mono"
                                        font.bold: isSel
                                        font.pixelSize: 13
                                        color: isSel ? accentColor : window.c_fg
                                        text: modelData.l
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        color: isSel ? window.c_fg : window.c_gray
                                        text: modelData.w + "x" + modelData.h
                                    }
                                }

                                MouseArea {
                                    id: resMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count) {
                                            window.selectedResAccent = accentColor;
                                            monitorsModel.setProperty(window.activeEditIndex, "resW", modelData.w);
                                            monitorsModel.setProperty(window.activeEditIndex, "resH", modelData.h);
                                            delayedLayoutUpdate.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Rotation Dial & Refresh Rate Slider Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20
                        enabled: activeSwitch.checked

                        // Clock dial for transformation/rotation
                        Rectangle {
                            id: clockDial
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 100
                            radius: 50
                            color: window.c_mantle
                            border.color: window.selectedResAccent
                            border.width: 2

                            // 4 direction indicators (0, 90, 180, 270)
                            Repeater {
                                model: 4
                                Item {
                                    anchors.fill: parent
                                    rotation: index * 90
                                    Rectangle {
                                        width: 4
                                        height: 8
                                        radius: 2
                                        color: window.currentTransform === index ? window.selectedResAccent : hexToRgba(window.c_fg, 0.2)
                                        anchors.top: parent.top
                                        anchors.topMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Item {
                                anchors.fill: parent
                                rotation: window.currentTransform * 90
                                Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                                Rectangle {
                                    width: 4
                                    height: 30
                                    radius: 2
                                    color: window.selectedResAccent
                                    anchors.bottom: parent.verticalCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: window.c_bg
                                    border.color: window.selectedResAccent
                                    border.width: 3
                                    anchors.centerIn: parent
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                function updateAngle(mx, my) {
                                    var dx = mx - width / 2;
                                    var dy = my - height / 2;
                                    if (Math.hypot(dx, dy) < 10) return;

                                    var snap = 0;
                                    if (Math.abs(dx) > Math.abs(dy)) {
                                        snap = dx > 0 ? 1 : 3;
                                    } else {
                                        snap = dy > 0 ? 2 : 0;
                                    }
                                    if (monitorsModel.count > 0 && window.activeEditIndex < monitorsModel.count) {
                                        monitorsModel.setProperty(window.activeEditIndex, "transform", snap);
                                        delayedLayoutUpdate.restart();
                                    }
                                }
                                onPressed: (mouse) => updateAngle(mouse.x, mouse.y)
                                onPositionChanged: (mouse) => { if (pressed) updateAngle(mouse.x, mouse.y) }
                            }
                        }

                        // Refresh rate custom slider
                        Item {
                            id: sliderContainer
                            Layout.fillWidth: true
                            height: 100

                            property var rates: [60, 75, 120, 144, 180, 240]
                            property var rateColors: [window.c_red, window.c_orange, window.c_yellow, window.c_green, window.c_blue, window.c_purple]

                            property int currentIndex: {
                                if (monitorsModel.count === 0 || window.activeEditIndex >= monitorsModel.count) return 0;
                                var currentVal = parseInt(monitorsModel.get(window.activeEditIndex).rate) || 60;
                                var closestIdx = 0;
                                var minDiff = 9999;
                                for (var i = 0; i < rates.length; i++) {
                                    var diff = Math.abs(rates[i] - currentVal);
                                    if (diff < minDiff) {
                                        minDiff = diff;
                                        closestIdx = i;
                                    }
                                }
                                return closestIdx;
                            }

                            property real visualPct: currentIndex / (rates.length - 1)

                            onCurrentIndexChanged: {
                                if (!sliderMa.pressed) visualPct = currentIndex / (rates.length - 1);
                            }

                            function updateSelectionVisual(idx) {
                                if (monitorsModel.count === 0 || window.activeEditIndex >= monitorsModel.count) return;
                                visualPct = idx / (rates.length - 1);
                                monitorsModel.setProperty(window.activeEditIndex, "rate", rates[idx].toString());
                                window.selectedRateAccent = rateColors[idx];
                            }

                            Rectangle {
                                id: track
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: -10
                                height: 8
                                radius: 4
                                color: window.c_mantle

                                Rectangle {
                                    width: Math.max(0, knob.x + knob.width / 2)
                                    height: parent.height
                                    radius: parent.radius
                                    color: window.selectedRateAccent
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Rectangle {
                                    id: knob
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: window.c_fg
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: (sliderContainer.visualPct * parent.width) - width / 2

                                    Behavior on x {
                                        enabled: !sliderMa.pressed
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                    border.width: 3
                                    border.color: hexToRgba(window.selectedRateAccent, 0.4)
                                }
                            }

                            Repeater {
                                model: sliderContainer.rates.length
                                Item {
                                    x: track.x + (index / (sliderContainer.rates.length - 1)) * track.width
                                    y: track.y + 16
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: sliderContainer.rates[index] + "Hz"
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        font.weight: sliderContainer.currentIndex === index ? Font.Bold : Font.Normal
                                        color: sliderContainer.currentIndex === index ? window.selectedRateAccent : window.c_gray
                                    }
                                }
                            }

                            MouseArea {
                                id: sliderMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                function updateSelection(mouseX, snapToGrid) {
                                    var pct = (mouseX - track.x) / track.width;
                                    pct = Math.max(0, Math.min(1, pct));
                                    var idx = Math.round(pct * (sliderContainer.rates.length - 1));

                                    if (snapToGrid) {
                                        sliderContainer.visualPct = idx / (sliderContainer.rates.length - 1);
                                    } else {
                                        sliderContainer.visualPct = pct;
                                    }
                                    sliderContainer.updateSelectionVisual(idx);
                                }

                                onPressed: (mouse) => updateSelection(mouse.x, false)
                                onPositionChanged: (mouse) => { if (pressed) updateSelection(mouse.x, false) }
                                onReleased: (mouse) => updateSelection(mouse.x, true)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Apply Button
                    Rectangle {
                        id: applyBtn
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 42
                        radius: 21

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: window.selectedResAccent }
                            GradientStop { position: 1.0; color: window.selectedRateAccent }
                        }

                        scale: window.applyPressed ? 0.95 : (applyMa.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                font.pixelSize: 16
                                color: window.c_bg
                                text: "󰸵"
                            }
                            Text {
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                font.pixelSize: 13
                                color: window.c_bg
                                text: monitorsModel.count > 1 ? "Aplicar Todo" : "Aplicar"
                            }
                        }

                        MouseArea {
                            id: applyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: window.applyPressed = true
                            onReleased: window.applyPressed = false
                            onClicked: window.triggerApply()
                        }
                    }
                }
            }
        }
    }
}
