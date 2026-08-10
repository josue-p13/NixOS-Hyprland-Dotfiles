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
        onActivated: audioManager.active = false
    }

    // State bindings
    readonly property bool active: audioManager.active

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

    // Sidebar Tab Selection
    property string selectedTab: "sinks" // "sinks" for Salida, "sources" for Entrada

    function getDeviceIcon(name, type) {
        var n = name.toLowerCase();
        if (type === "sources") {
            return "󰍬";
        }
        if (n.indexOf("headphone") !== -1 || n.indexOf("headset") !== -1 || n.indexOf("buds") !== -1 || n.indexOf("pods") !== -1 || n.indexOf("airpods") !== -1) {
            return "󰋋";
        }
        if (n.indexOf("speaker") !== -1 || n.indexOf("altavoz") !== -1) {
            return "󰕾";
        }
        if (n.indexOf("hdmi") !== -1 || n.indexOf("displayport") !== -1 || n.indexOf("monitor") !== -1 || n.indexOf("tv") !== -1) {
            return "󰍹";
        }
        return "󰕾";
    }

    // Outer visual shell
    Item {
        id: visualRoot
        anchors.fill: parent
        focus: true
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                audioManager.active = false;
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
                color: root.c_blue
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

            // Outer Close Button (top-right)
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
                    onClicked: audioManager.active = false
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
                    text: "Dispositivos de Audio"
                }

                // Scan / Refresh Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: scanMa.containsMouse ? hexToRgba(root.c_blue, 0.2) : "transparent"
                    border.color: scanMa.containsMouse ? root.c_blue : "transparent"
                    border.width: 1

                    Text {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "󰑓"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 16
                        color: audioManager.scanning ? root.c_blue : root.c_fg

                        RotationAnimator {
                            target: scanIcon
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: audioManager.scanning
                        }
                    }

                    MouseArea {
                        id: scanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: audioManager.refresh()
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

                // Left Panel: Sidebar
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
                            text: "CATEGORÍAS"
                            Layout.bottomMargin: 4
                            Layout.leftMargin: 8
                        }

                        // Output Tab
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: root.selectedTab === "sinks" ? hexToRgba(root.c_blue, 0.15) : (outMa.containsMouse ? hexToRgba(root.c_fg, 0.05) : "transparent")
                            border.color: root.selectedTab === "sinks" ? root.c_blue : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                Text {
                                    text: "󰕾"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 16
                                    color: root.selectedTab === "sinks" ? root.c_blue : root.c_fg
                                }
                                Text {
                                    text: "Salida"
                                    font.family: "JetBrains Mono"
                                    font.bold: root.selectedTab === "sinks"
                                    font.pixelSize: 14
                                    color: root.selectedTab === "sinks" ? root.c_blue : root.c_fg
                                }
                            }

                            MouseArea {
                                id: outMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedTab = "sinks"
                            }
                        }

                        // Input Tab
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: root.selectedTab === "sources" ? hexToRgba(root.c_blue, 0.15) : (inMa.containsMouse ? hexToRgba(root.c_fg, 0.05) : "transparent")
                            border.color: root.selectedTab === "sources" ? root.c_blue : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                Text {
                                    text: "󰍬"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 16
                                    color: root.selectedTab === "sources" ? root.c_blue : root.c_fg
                                }
                                Text {
                                    text: "Entrada"
                                    font.family: "JetBrains Mono"
                                    font.bold: root.selectedTab === "sources"
                                    font.pixelSize: 14
                                    color: root.selectedTab === "sources" ? root.c_blue : root.c_fg
                                }
                            }

                            MouseArea {
                                id: inMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedTab = "sources"
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Right Panel: Device List Switcher
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    ScrollView {
                        anchors.fill: parent
                        clip: true

                        ListView {
                            id: deviceListView
                            model: {
                                var filtered = [];
                                var data = audioManager.devices;
                                for (var i = 0; i < data.length; i++) {
                                    var dev = data[i];
                                    if (dev.type === root.selectedTab) {
                                        filtered.push(dev);
                                    }
                                }
                                return filtered;
                            }
                            spacing: 12
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                width: ListView.view.width - 12
                                height: 80
                                radius: 14
                                color: modelData.isDefault ? hexToRgba(root.c_blue, 0.08) : (devMa.containsMouse ? hexToRgba(root.c_fg, 0.04) : root.c_mantle)
                                border.color: modelData.isDefault ? root.c_blue : (devMa.containsMouse ? hexToRgba(root.c_fg, 0.1) : "transparent")
                                border.width: 1

                                MouseArea {
                                    id: devMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!modelData.isDefault) {
                                            audioManager.setDefaultDevice(modelData.id);
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    // Mute Button and Icon
                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 20
                                        color: modelData.muted ? hexToRgba(root.c_red, 0.1) : hexToRgba(root.c_blue, 0.1)
                                        border.color: modelData.muted ? hexToRgba(root.c_red, 0.3) : hexToRgba(root.c_blue, 0.3)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 18
                                            color: modelData.muted ? root.c_red : root.c_blue
                                            text: modelData.muted ? "󰝟" : root.getDeviceIcon(modelData.name, modelData.type)
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                audioManager.setMute(modelData.id, !modelData.muted);
                                            }
                                        }
                                    }

                                    // Name, Status Badge, Slider
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                font.family: "JetBrains Mono"
                                                font.bold: modelData.isDefault
                                                font.pixelSize: 14
                                                color: root.c_fg
                                                text: modelData.name || "Dispositivo desconocido"
                                                elide: Text.ElideRight
                                            }

                                            // Default Pill
                                            Rectangle {
                                                visible: modelData.isDefault
                                                width: 86
                                                height: 18
                                                radius: 9
                                                color: hexToRgba(root.c_blue, 0.2)
                                                border.color: root.c_blue
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    font.family: "JetBrains Mono"
                                                    font.bold: true
                                                    font.pixelSize: 9
                                                    color: root.c_blue
                                                    text: "Predeterminado"
                                                }
                                            }
                                        }

                                        // Volume Control Slider
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12
                                            visible: !modelData.muted

                                            Slider {
                                                Layout.fillWidth: true
                                                from: 0.0
                                                to: 1.0
                                                value: modelData.volume
                                                onMoved: {
                                                    audioManager.setVolume(modelData.id, value);
                                                }

                                                background: Rectangle {
                                                    x: parent.leftPadding
                                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                                    implicitWidth: 200
                                                    implicitHeight: 4
                                                    width: parent.availableWidth
                                                    height: implicitHeight
                                                    radius: 2
                                                    color: hexToRgba(root.c_fg, 0.1)

                                                    Rectangle {
                                                        width: parent.parent.visualPosition * parent.width
                                                        height: parent.height
                                                        color: root.c_blue
                                                        radius: 2
                                                    }
                                                }

                                                handle: Rectangle {
                                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                                    implicitWidth: 14
                                                    implicitHeight: 14
                                                    radius: 7
                                                    color: parent.hovered || parent.pressed ? root.c_blue : root.c_fg
                                                    border.color: hexToRgba(root.c_bg, 0.5)
                                                    border.width: 1
                                                }
                                            }

                                            // Volume text percentage
                                            Text {
                                                font.family: "JetBrains Mono"
                                                font.pixelSize: 11
                                                color: root.c_blue
                                                text: Math.round(modelData.volume * 100) + "%"
                                                horizontalAlignment: Text.AlignRight
                                                Layout.preferredWidth: 32
                                            }
                                        }

                                        // Muted Label
                                        Text {
                                            Layout.fillWidth: true
                                            font.family: "JetBrains Mono"
                                            font.pixelSize: 11
                                            color: root.c_red
                                            text: "Silenciado"
                                            visible: modelData.muted
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
