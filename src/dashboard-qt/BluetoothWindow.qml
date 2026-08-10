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
        onActivated: bluetoothManager.active = false
    }

    // State bindings
    readonly property bool active: bluetoothManager.active

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

    property real introProgress: window.opacityValue
    property real windowScale: window.scaleValue
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: window.visible
    }

    // Bluetooth Info Management
    property string activeMac: ""
    property string activeName: ""
    property int activeBattery: 0
    property string activeIcon: "bluetooth"
    property bool isConnected: false

    ListModel {
        id: btListModel
    }

    Connections {
        target: bluetoothManager
        function onDevicesChanged() {
            btListModel.clear();
            var data = bluetoothManager.devices;
            var connFound = false;

            for (var i = 0; i < data.length; i++) {
                var dev = data[i];
                if (dev.connected) {
                    window.activeMac = dev.mac;
                    window.activeName = dev.name;
                    window.activeBattery = dev.battery;
                    window.activeIcon = dev.icon;
                    window.isConnected = true;
                    connFound = true;
                } else {
                    btListModel.append({
                        mac: dev.mac,
                        name: dev.name,
                        icon: dev.icon,
                        paired: dev.paired
                    });
                }
            }

            if (!connFound) {
                window.isConnected = false;
                window.activeMac = "";
                window.activeName = "";
                window.activeBattery = 0;
                window.activeIcon = "bluetooth";
            }
        }
    }

    function getDeviceUnicodeIcon(iconName) {
        if (iconName === "headset") return "🎧";
        if (iconName === "audio") return "🔊";
        if (iconName === "phone") return "📱";
        if (iconName === "mouse") return "🖱";
        if (iconName === "keyboard") return "⌨";
        if (iconName === "gamepad") return "🎮";
        return "";
    }

    // Outer visual shell
    Item {
        id: visualRoot
        anchors.fill: parent
        focus: true
        Keys.onPressed: {
            if (event.key === Qt.Key_Escape) {
                bluetoothManager.active = false;
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
                color: window.c_purple
            }
            Rectangle {
                width: parent.width * 0.9
                height: width
                radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * -150
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * -100
                opacity: 0.04
                color: window.c_blue
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
                    onClicked: bluetoothManager.active = false
                }
            }

            // Top Header: Title, Power Switch, Scan Indicator
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
                    color: window.c_fg
                    text: "Configuración de Bluetooth"
                }

                // Scan / Refresh Button
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: scanMa.containsMouse ? hexToRgba(window.c_purple, 0.2) : "transparent"
                    border.color: scanMa.containsMouse ? window.c_purple : "transparent"
                    border.width: 1
                    visible: bluetoothManager.bluetoothPower

                    Text {
                        id: scanIcon
                        anchors.centerIn: parent
                        text: "󰑓"
                        font.pixelSize: 16
                        color: bluetoothManager.scanning ? window.c_purple : window.c_fg

                        RotationAnimator {
                            target: scanIcon
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: bluetoothManager.scanning
                        }
                    }

                    MouseArea {
                        id: scanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bluetoothManager.refresh()
                    }
                }

                // Power Switch
                Switch {
                    checked: bluetoothManager.bluetoothPower
                    onCheckedChanged: {
                        if (checked !== bluetoothManager.bluetoothPower) {
                            bluetoothManager.setBluetoothPower(checked);
                        }
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
                visible: bluetoothManager.bluetoothPower

                // Left Panel: Active/Connected Device Info
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 320
                    color: hexToRgba(window.c_mantle, 0.4)
                    border.color: hexToRgba(window.c_fg, 0.1)
                    border.width: 1
                    radius: 16
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16
                        visible: window.isConnected

                        // Connection Card Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: hexToRgba(window.c_purple, 0.15)
                                border.color: window.c_purple
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    font.pixelSize: 22
                                    color: window.c_purple
                                    text: window.getDeviceUnicodeIcon(window.activeIcon)
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Text {
                                    font.family: "JetBrains Mono"
                                    font.bold: true
                                    font.pixelSize: 15
                                    color: window.c_fg
                                    text: window.activeName
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 200
                                }
                                Text {
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    color: window.c_purple
                                    text: "Conectado"
                                }
                            }
                        }

                        // Technical Details List
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: hexToRgba(window.c_fg, 0.1)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { font.family: "JetBrains Mono"; font.pixelSize: 12; color: window.c_gray; text: "Dirección MAC:" }
                                Item { Layout.fillWidth: true }
                                Text { font.family: "JetBrains Mono"; font.pixelSize: 11; color: window.c_fg; text: window.activeMac }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { font.family: "JetBrains Mono"; font.pixelSize: 12; color: window.c_gray; text: "Batería:" }
                                Item { Layout.fillWidth: true }
                                Text { font.family: "JetBrains Mono"; font.pixelSize: 12; color: window.activeBattery > 0 ? window.c_green : window.c_gray; text: window.activeBattery > 0 ? (window.activeBattery + "%") : "N/D" }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Disconnect Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: 19
                            color: disMa.containsMouse ? hexToRgba(window.c_red, 0.2) : hexToRgba(window.c_red, 0.1)
                            border.color: window.c_red
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                font.family: "JetBrains Mono"
                                font.bold: true
                                font.pixelSize: 13
                                color: window.c_red
                                text: "Desconectar"
                            }

                            MouseArea {
                                id: disMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bluetoothManager.disconnectDevice(window.activeMac)
                            }
                        }
                    }

                    // Empty State: No Bluetooth Connected
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: !window.isConnected

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.pixelSize: 44
                            color: window.c_gray
                            text: "󰂲"
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.bold: true
                            font.pixelSize: 14
                            color: window.c_fg
                            text: "Sin Conexión"
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            color: window.c_gray
                            text: "Selecciona un dispositivo para conectar"
                        }
                    }
                }

                // Right Panel: Discovered Devices List / ScrollView
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    ScrollView {
                        anchors.fill: parent
                        clip: true

                        ListView {
                            model: btListModel
                            spacing: 8
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                width: ListView.view.width - 12
                                height: 44
                                radius: 10
                                color: rowMa.containsMouse ? hexToRgba(window.c_fg, 0.06) : window.c_mantle
                                border.color: rowMa.containsMouse ? hexToRgba(window.c_fg, 0.15) : "transparent"
                                border.width: 1

                                property bool isConnecting: bluetoothManager.connectingMac === model.mac

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    // Device icon
                                    Text {
                                        font.pixelSize: 16
                                        color: rowMa.containsMouse ? window.c_purple : window.c_fg
                                        text: window.getDeviceUnicodeIcon(model.icon)
                                    }

                                    // Device Name
                                    Text {
                                        Layout.fillWidth: true
                                        font.family: "JetBrains Mono"
                                        font.bold: rowMa.containsMouse
                                        font.pixelSize: 13
                                        color: window.c_fg
                                        text: model.name || "Dispositivo desconocido"
                                        elide: Text.ElideRight
                                    }

                                    // Status Badge (Emparejado / Disponible)
                                    Text {
                                        font.family: "JetBrains Mono"
                                        font.pixelSize: 10
                                        color: window.c_gray
                                        text: model.paired ? "Emparejado" : "Disponible"
                                    }

                                    // Loading Spinner if connecting
                                    Rectangle {
                                        width: 16
                                        height: 16
                                        color: "transparent"
                                        visible: isConnecting

                                        Text {
                                            id: spin
                                            anchors.centerIn: parent
                                            text: "󰑓"
                                            font.pixelSize: 14
                                            color: window.c_purple
                                            RotationAnimator {
                                                target: spin
                                                from: 0; to: 360
                                                duration: 800
                                                loops: Animation.Infinite
                                                running: isConnecting
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        bluetoothManager.connectDevice(model.mac);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bluetooth Disabled State
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16
                visible: !bluetoothManager.bluetoothPower

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.pixelSize: 54
                    color: window.c_gray
                    text: "󰂲"
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: "JetBrains Mono"
                    font.bold: true
                    font.pixelSize: 15
                    color: window.c_fg
                    text: "Bluetooth Desactivado"
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    color: window.c_gray
                    text: "Activa el interruptor en la parte superior para buscar dispositivos"
                }
            }
        }
    }
}
