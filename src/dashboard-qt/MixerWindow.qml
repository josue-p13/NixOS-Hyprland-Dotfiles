import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.layershell 1.0 as LayerShell
import org.kde.layershell 1.0 as LS

ApplicationWindow {
    id: root
    visible: false
    width: 840
    height: 480
    color: "transparent"

    // Wayland Layer Shell bindings
    LayerShell.Window.layer: LS.Window.LayerOverlay
    LayerShell.Window.anchors: LS.Window.AnchorTop
    LayerShell.Window.margins.top: root.topMarginValue
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: active ? LS.Window.KeyboardInteractivityExclusive : LS.Window.KeyboardInteractivityNone

    Shortcut {
        sequence: "Escape"
        onActivated: mixerManager.active = false
    }

    // State bindings
    readonly property bool active: mixerManager.active

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
        ScriptAction { script: { root.visible = true; } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "topMarginValue"; to: 50; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "scaleValue"; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "opacityValue"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "topMarginValue"; to: 15; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "scaleValue"; to: 0.85; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "opacityValue"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.visible = false; } }
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

    property real introProgress: root.opacityValue
    property real windowScale: root.scaleValue
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: root.visible
    }

    // Sidebar selection (Salida vs Entrada)
    property string selectedTab: "Salida" // "Salida" (playback) or "Entrada" (capture/recording)

    function getAppIcon(name) {
        var n = name.toLowerCase();
        if (n.indexOf("spotify") !== -1) return "";
        if (n.indexOf("brave") !== -1 || n.indexOf("chrome") !== -1 || n.indexOf("firefox") !== -1 || n.indexOf("chromium") !== -1) return "󰖟";
        if (n.indexOf("steam") !== -1) return "󰓓";
        if (n.indexOf("discord") !== -1) return "󰙯";
        if (n.indexOf("cava") !== -1) return "󰓃";
        if (n.indexOf("vlc") !== -1 || n.indexOf("mpv") !== -1) return "󰕼";
        if (n.indexOf("obs") !== -1) return "󰕧";
        return "󰎆";
    }

    // Outer visual shell
    Item {
        id: visualRoot
        anchors.fill: parent
        focus: true
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                mixerManager.active = false;
                event.accepted = true;
            }
        }
        scale: 0.95 + (0.05 * root.introProgress)
        opacity: root.introProgress

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.c_bg
            border.color: hexToRgba(root.c_fg, 0.15)
            border.width: 1
            clip: true

            // Glowing backgrounds
            Rectangle {
                width: parent.width * 0.8
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 150
                y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 100
                opacity: 0.05
                color: root.c_orange
            }
            Rectangle {
                width: parent.width * 0.9
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * -150
                y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * -100
                opacity: 0.04
                color: root.c_yellow
            }

            // Close Button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: closeMa.containsMouse ? hexToRgba(root.c_red, 0.2) : hexToRgba(root.c_fg, 0.05)
                border.color: closeMa.containsMouse ? root.c_red : "transparent"
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
                    color: closeMa.containsMouse ? root.c_red : root.c_fg
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mixerManager.active = false
                }
            }

            // Top Header: Title and Scan Indicator
            RowLayout {
                id: topHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 20
                anchors.leftMargin: 24
                spacing: 16

                Text {
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 20
                    color: root.c_fg
                    text: "Mezclador de Volumen"
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: scanMa.containsMouse ? hexToRgba(root.c_orange, 0.2) : "transparent"
                    border.color: scanMa.containsMouse ? root.c_orange : "transparent"
                    border.width: 1

                    Text {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "󰑓"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 16
                        color: mixerManager.scanning ? root.c_orange : root.c_fg

                        RotationAnimator {
                            target: scanIcon
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: mixerManager.scanning
                        }
                    }

                    MouseArea {
                        id: scanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mixerManager.refresh()
                    }
                }
            }

            // Main Content Layout
            RowLayout {
                anchors.top: topHeader.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                spacing: 24

                // Left Panel: Sidebar (Tabs for Input/Output app streams)
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 200
                    color: hexToRgba(root.c_mantle, 0.4)
                    border.color: hexToRgba(root.c_fg, 0.1)
                    border.width: 1
                    radius: 16
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            font.family: "JetBrains Mono"
                            font.bold: true
                            font.pixelSize: 12
                            color: root.c_gray
                            text: "CANALES"
                            Layout.bottomMargin: 4
                            Layout.leftMargin: 8
                        }

                        // Playback Tab
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: root.selectedTab === "Salida" ? hexToRgba(root.c_orange, 0.15) : (outMa.containsMouse ? hexToRgba(root.c_fg, 0.05) : "transparent")
                            border.color: root.selectedTab === "Salida" ? root.c_orange : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                Text {
                                    text: "󰕾"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 16
                                    color: root.selectedTab === "Salida" ? root.c_orange : root.c_fg
                                }
                                Text {
                                    text: "Reproducción"
                                    font.family: "JetBrains Mono"
                                    font.bold: root.selectedTab === "Salida"
                                    font.pixelSize: 13
                                    color: root.selectedTab === "Salida" ? root.c_orange : root.c_fg
                                }
                            }

                            MouseArea {
                                id: outMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedTab = "Salida"
                            }
                        }

                        // Recording Tab
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: root.selectedTab === "Entrada" ? hexToRgba(root.c_orange, 0.15) : (inMa.containsMouse ? hexToRgba(root.c_fg, 0.05) : "transparent")
                            border.color: root.selectedTab === "Entrada" ? root.c_orange : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                Text {
                                    text: "󰍬"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 16
                                    color: root.selectedTab === "Entrada" ? root.c_orange : root.c_fg
                                }
                                Text {
                                    text: "Grabación"
                                    font.family: "JetBrains Mono"
                                    font.bold: root.selectedTab === "Entrada"
                                    font.pixelSize: 13
                                    color: root.selectedTab === "Entrada" ? root.c_orange : root.c_fg
                                }
                            }

                            MouseArea {
                                id: inMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedTab = "Entrada"
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Info status
                        Text {
                            Layout.fillWidth: true
                            Layout.margins: 8
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10
                            color: root.c_gray
                            text: "Monitoreo por PipeWire"
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Right Panel: App Streams List
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    // Empty State: No active applications
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: deviceListView.count === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.pixelSize: 44
                            color: root.c_gray
                            text: "󰝟"
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.bold: true
                            font.pixelSize: 14
                            color: root.c_fg
                            text: "Sin aplicaciones activas"
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: root.c_gray
                            text: "Inicia la reproducción de sonido para controlarla"
                        }
                    }

                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        visible: deviceListView.count > 0

                        ListView {
                            id: deviceListView
                            width: parent.width
                            model: {
                                var filtered = [];
                                var data = mixerManager.streams;
                                for (var i = 0; i < data.length; i++) {
                                    var str = data[i];
                                    if (str.type === root.selectedTab) {
                                        filtered.push(str);
                                    }
                                }
                                return filtered;
                            }
                            spacing: 12
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                width: deviceListView.width - 16
                                height: 90
                                radius: 14
                                color: devMa.containsMouse ? hexToRgba(root.c_fg, 0.04) : hexToRgba(root.c_mantle, 0.6)
                                border.color: devMa.containsMouse ? hexToRgba(root.c_fg, 0.15) : hexToRgba(root.c_fg, 0.05)
                                border.width: 1

                                MouseArea {
                                    id: devMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 16

                                    // App Icon (Left)
                                    Rectangle {
                                        width: 44
                                        height: 44
                                        radius: 22
                                        color: modelData.muted ? hexToRgba(root.c_red, 0.1) : hexToRgba(root.c_orange, 0.1)
                                        border.color: modelData.muted ? hexToRgba(root.c_red, 0.3) : hexToRgba(root.c_orange, 0.3)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 22
                                            color: modelData.muted ? root.c_red : root.c_orange
                                            text: root.getAppIcon(modelData.name)
                                        }
                                    }

                                    // Details & Slider (Middle)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        // Name and ID/Type
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                font.family: "JetBrains Mono"
                                                font.bold: true
                                                font.pixelSize: 14
                                                color: root.c_fg
                                                text: modelData.name || "Aplicación"
                                                elide: Text.ElideRight
                                            }

                                            // ID badge
                                            Rectangle {
                                                width: 50
                                                height: 18
                                                radius: 9
                                                color: hexToRgba(root.c_gray, 0.15)
                                                border.color: hexToRgba(root.c_gray, 0.3)
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: 9
                                                    color: root.c_gray
                                                    text: "ID: " + modelData.id
                                                }
                                            }
                                        }

                                        // Slider or Muted message
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            visible: !modelData.muted
                                            Layout.preferredHeight: 24

                                            Slider {
                                                id: volSlider
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 20
                                                from: 0.0
                                                to: 1.0
                                                value: modelData.volume
                                                onMoved: {
                                                    mixerManager.setVolume(modelData.id, value);
                                                }

                                                background: Rectangle {
                                                    x: volSlider.leftPadding
                                                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                                    implicitWidth: 200
                                                    implicitHeight: 4
                                                    width: volSlider.availableWidth
                                                    height: implicitHeight
                                                    radius: 2
                                                    color: hexToRgba(root.c_fg, 0.1)

                                                    Rectangle {
                                                        width: volSlider.visualPosition * parent.width
                                                        height: parent.height
                                                        color: root.c_orange
                                                        radius: 2
                                                    }
                                                }

                                                handle: Rectangle {
                                                    x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                                                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                                                    implicitWidth: 14
                                                    implicitHeight: 14
                                                    radius: 7
                                                    color: volSlider.hovered || volSlider.pressed ? root.c_orange : root.c_fg
                                                    border.color: hexToRgba(root.c_bg, 0.5)
                                                    border.width: 1
                                                }
                                            }

                                            // Volume text percentage
                                            Text {
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 11
                                                color: root.c_orange
                                                text: Math.round(modelData.volume * 100) + "%"
                                                horizontalAlignment: Text.AlignRight
                                                Layout.preferredWidth: 36
                                            }
                                        }

                                        // Muted message
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            visible: modelData.muted
                                            Layout.preferredHeight: 24

                                            Text {
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 12
                                                color: root.c_red
                                                text: "󰝟 Silenciado"
                                            }
                                        }
                                    }

                                    // Mute Action Button (Right)
                                    Rectangle {
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: muteBtnMa.containsMouse ? (modelData.muted ? hexToRgba(root.c_orange, 0.15) : hexToRgba(root.c_red, 0.15)) : hexToRgba(root.c_fg, 0.05)
                                        border.color: muteBtnMa.containsMouse ? (modelData.muted ? root.c_orange : root.c_red) : "transparent"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 16
                                            color: modelData.muted ? root.c_red : (muteBtnMa.containsMouse ? root.c_red : root.c_orange)
                                            text: modelData.muted ? "󰝟" : "󰕾"
                                        }

                                        MouseArea {
                                            id: muteBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                mixerManager.setMute(modelData.id, !modelData.muted);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
